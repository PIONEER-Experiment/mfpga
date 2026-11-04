//`include "constants.txt"

// Finite state machine for handling commands to Channel FPGA(s).
// 
// Two primary functions:
// 1. Handle configuration via IPbus
// 2. Handle ADC data readout to DAQ link
//
// Originally created using Fizzim

module command_manager_selftrigc (
  // user interface clock and reset
  input wire clk,
  input wire rst,

  // interface to TX channel FIFO (through AXI4-Stream TX Switch)
  input wire chan_tx_fifo_ready,
  output reg chan_tx_fifo_valid,
  output reg chan_tx_fifo_last,
  output reg [ 3:0] chan_tx_fifo_dest,
  output reg [31:0] chan_tx_fifo_data,

  // interface to RX channel FIFO (through AXI4-Stream RX Switch)
  input wire chan_rx_fifo_valid,
  input wire chan_rx_fifo_last,
  input wire [31:0] chan_rx_fifo_data,
  output reg chan_rx_fifo_ready,

  // interface to IPbus AXI output
  input wire ipbus_cmd_valid,
  input wire ipbus_cmd_last,
  input wire [ 3:0] ipbus_cmd_dest,
  input wire [31:0] ipbus_cmd_data,
  output reg ipbus_cmd_ready,

  // interface to IPbus AXI input
  input wire ipbus_res_ready,
  output reg ipbus_res_valid,
  output reg ipbus_res_last,
  output reg [31:0] ipbus_res_data,

  // interface to AMC13 DAQ Link
  input wire daq_ready,
  input wire daq_almost_full,
  output reg daq_valid,
  output reg daq_header,
  output reg daq_trailer,
  output reg [63:0] daq_data,

  // interface to trigger processor
  input wire send_empty_event,       // request an empty event
  input wire skip_payload,           // request to skip channel payloads
  input wire initiate_readout,       // request for the channels to be read out
  input wire [23:0] event_num,       // counts the number of ttc triggers passed to the channels
  input wire [23:0] trig_num,        // counts the total number of global triggers, including ignored / empty
  input wire [ 4:0] trig_type,       // trigger type
  input wire [43:0] trig_timestamp,  // trigger timestamp, defined by when trigger is received by trigger receiver module
  input wire [ 3:0] ttc_xadc_alarms, // XADC alarms
  output wire readout_ready,         // ready to readout data, i.e., when in idle state
  output reg  readout_done,          // finished readout flag
  //input wire        accept_self_triggers,
  // (6.8.0: the per-channel trigger-line count records and their FIFO handshake are gone)
  // the waveform count of each fill header seen, for hdr_monitor_selftrigc (status, DDR3 overflow warning)
  output reg         hdr_peek_strobe,    // one clock: a header was peeked (hdr_chan, hdr_wfms valid)
  output reg         hdr_read_strobe,    // one clock: a header was read with its fill (the data follows)
  output reg  [ 2:0] hdr_chan,
  output reg  [22:0] hdr_wfms,

  // burst count for channel self trigs -- common to all channels
  output reg [22:0] burst_count_selftrig,  // the burst count -- this is "type 4" in the rest of the firmware world

  // status connections
  input wire [15:0] i2c_mac_adr,        // portion of this board's MAC address that encode the serial number
  input wire [ 4:0] chan_en,            // enabled channels, one bit for each channel
  input wire endianness_sel,            // select bit for the endianness of ADC data
  input wire [31:0] thres_data_corrupt, // threshold for data corruption instances
  output reg [34:0] state,              // state of finite state machine

  // error connections
  output reg [31:0] cs_mismatch_count, // number of checksum mismatches
  output reg error_data_corrupt,       // data corruption error
  output reg error_trig_num,           // trigger number mismatch between channel and master
  output reg error_trig_type,          // trigger type mismatch between channel and master
  output wire [7:0] trig_num_error_count, // trigger-number mismatches seen (no longer terminal), mod 256
  // error reporting (6.6.10): one-clock pulses to the error capture, and what it needs to record
  output reg  [15:0] err_loss_pulse,     // a data-loss cause, see ERR_L_* below
  output reg  [ 7:0] err_fault_pulse,    // a hardware/path fault cause, see ERR_F_*
  output reg  [ 5:0] err_warn_pulse,     // recovered conditions worth knowing about, see ERR_W_*
  output reg         peeking,            // 6.7.0: in the header-first phase of a readout (status)
  output reg  [ 6:0] chan_err_word,      // the error word a channel put in its fill header (INFO4 [13:7])
  output reg         chan_err_valid,     // ... one clock when a non-zero one was received
  output reg  [31:0] last_rsn_word,      // the last words received from a channel, for the snapshot
  output reg  [31:0] last_rc_word,
  output reg  [31:0] last_info1_word,
  output reg  [31:0] last_info4_word,
  output wire [ 8:0] retry_status,       // {reply_retries[1:0], reissue_retries[1:0], skipped_mask[4:0]}, for the snapshot
  input  wire [ 2:0] err_summary,        // {data_loss, hw_fault, warning} sticky, from the error capture: marked in the WFD5 header word
  output reg [ 4:0] chan_error_sn,     // command serial number mismatch between channel and master
  output reg [ 4:0] chan_error_rc,     // master received an error response code, one bit for each channel

  // for debugging
//  input wire rst_trigger_num
  output wire cs_mismatch_found         // temporary
);

  wire [23:0] event_num_channel;
  assign event_num_channel[23:0] = chan_rx_fifo_data[23:0];
  assign cs_mismatch_found = cs_mismatch_count > 0 ? 1'b1 : 1'b0;

  // idle state bit
  parameter IDLE                  =  0; // 0x 0_0000_0001
  // configuration manager state bits
  parameter SEND_IPBUS_CSN        =  1; // 0x 0_0000_0002
  parameter READ_IPBUS_CMD        =  2; // 0x 0_0000_0004
  parameter CHECK_LAST            =  3; // 0x 0_0000_0008
  parameter SEND_IPBUS_CMD        =  4; // 0x 0_0000_0010
  parameter READ_IPBUS_RSN        =  5; // 0x 0_0000_0020
  parameter READ_IPBUS_RES        =  6; // 0x 0_0000_0040
  parameter SEND_IPBUS_RES        =  7; // 0x 0_0000_0080
  // event builder state bits
  parameter CHECK_SELFTRIG_FIFO   =  8; // 0x 0_0000_0100  (unused since 6.8.0: no count record to wait for)
  parameter CHECK_CHAN_EN         =  9; // 0x 0_0000_0200
  parameter SEND_CHAN_CSN         = 10; // 0x 0_0000_0400
  parameter SEND_CHAN_CC          = 11; // 0x 0_0000_0800
  parameter READ_CHAN_RSN         = 12; // 0x 0_0000_1000
  parameter READ_CHAN_RC          = 13; // 0x 0_0000_2000
  parameter READ_CHAN_INFO1       = 14; // 0x 0_0000_4000
  parameter READ_CHAN_INFO2       = 15; // 0x 0_0000_8000
  parameter READ_CHAN_INFO3       = 16; // 0x 0_0001_0000
  parameter READ_CHAN_INFO4       = 17; // 0x 0_0002_0000
  parameter READY_AMC13_HEADER1   = 18; // 0x 0_0004_0000
  parameter SEND_AMC13_HEADER1    = 19; // 0x 0_0008_0000
  parameter SEND_AMC13_HEADER2    = 20; // 0x 0_0010_0000
  parameter SEND_WFD5_HEADER      = 21; // 0x 0_0020_0000
  parameter SEND_CHAN_HEADER1     = 22; // 0x 0_0040_0000
  parameter SEND_CHAN_HEADER2     = 23; // 0x 0_0080_0000
  parameter READ_CHAN_DATA1       = 24; // 0x 0_0100_0000
  parameter READ_CHAN_DATA2       = 25; // 0x 0_0200_0000
  parameter READ_CHAN_DATA_RESYNC = 26; // 0x 0_0400_0000
  parameter SEND_CHAN_TRAILER1    = 27; // 0x 0_0800_0000
  parameter READY_AMC13_TRAILER   = 28; // 0x 0_1000_0000
  parameter SEND_AMC13_TRAILER    = 29; // 0x 0_2000_0000
  // error state bits
  parameter ERROR_DATA_CORRUPTION = 30; // 0x 0_4000_0000
  parameter ERROR_TRIG_NUM        = 31; // 0x 0_8000_0000
  parameter ERROR_TRIG_TYPE       = 32; // 0x 1_0000_0000
  parameter FLUSH_CHAN            = 33; // 0x 2_0000_0000  drain a skipped channel's RX FIFO to the end of its frame
                                      


  // channel header regs sorted the way they will be used: first chan_trig_num, then burst_count, ...
  //reg [23:0] chan_trig_num;     // trigger number from channel header, starts at 1
  reg [22:0] wfm_count;         // number of waveform acquired
  //reg [10:0] wfm_cnt_shrt;     // lower 11 bits of above
  reg [11:0] chan_tag;          // channel tag
  //reg [ 3:0] chan_xadc_alarms;  // channel alarms from XADC
  reg [31:0] csn;               // channel serial number
  reg [31:0] data_count;        // # of 32-bit data words received from Aurora, per waveform
  //reg [ 3:0] data_count_shrt;   // lowest 4 bits of above
  reg [22:0] data_wfm_count;    // # of waveforms received from Aurora
  reg [31:0] ipbus_buf;         // buffer for IPbus data
  reg [31:0] readout_timestamp; // channel data readout timestamp
  //reg [ 2:0] num_chan_en;       // number of enabled channels
  reg sent_amc13_header;        // flag to indicate that the AMC13 header has been sent
  reg [22:0] stored_burst_count;// waveform burst count obtained from header

  // regs for channel checksum verification
  reg update_mcs_lsb;           // flag to update the 64 LSBs of the 128-bit master checksum (mcs)
reg [127:0] master_checksum;  // checksum calculated in this module
reg [127:0] channel_checksum; // checksum from received channel data

  // regs for asynchronous mode
  reg [22:0] pulse_data_size;   // burst count covering channel headers, waveform headers, waveforms, and checksums
  reg [43:0] pulse_timestamp;   // 44-bit pulse trigger timestamp
  //reg [23:0] pulse_trig_num;    // pulse trigger number
  //reg [ 1:0] pulse_trig_length; // length of pulse trigger (short or long)
  reg [15:0] pretrigger_count;  // pre-trigger count

  // other internal regs
  reg empty_event;                         // flag to indicate if this should be an empty event
  reg empty_payload;                       // flag to indicate whether to skip the channel payloads
  reg [31:0] ipbus_chan_cmd;               // buffer for issued channel command
  reg [31:0] ipbus_chan_reg;               // buffer for issued channel register
  //reg [ 4:0] trig_type_latch;              // latched trigger type from TTC Trigger FIFO
  //reg [1:0] cs_error_seen;

  // debugging
  //wire [23:0] trig_num_from_channel;

  // for internal regs
  //reg updown;
  //reg next_updown;
  reg next_sent_amc13_header;
  reg next_update_mcs_lsb;
  reg next_empty_event;
  reg next_empty_payload;
  reg [ 34:0] nextstate;
  reg [ 22:0] next_wfm_count;
  reg [ 21:0] next_wfm_gap_length;
  reg [ 11:0] next_chan_tag;
  //reg [  3:0] next_chan_xadc_alarms;
  reg [ 31:0] next_csn;
  reg [ 31:0] next_data_count;
  reg [ 22:0] next_data_wfm_count;
  reg [ 31:0] next_ipbus_buf;
  //reg [ 23:0] next_chan_trig_num;
  reg [ 31:0] next_readout_timestamp;
  //reg [  2:0] next_num_chan_en;
  reg [127:0] next_master_checksum;
  reg [127:0] next_channel_checksum;
  reg [ 31:0] next_cs_mismatch_count;
  reg [ 31:0] next_ipbus_chan_cmd;
  reg [ 31:0] next_ipbus_chan_reg;
  reg [ 22:0] next_pulse_data_size;
  reg [ 43:0] next_pulse_timestamp;
  //reg [ 23:0] next_pulse_trig_num;
  //reg [  1:0] next_pulse_trig_length;
  reg [127:0] next_s_readout_fifo_tdata;
  reg [ 15:0] next_pretrigger_count;
  //reg [  4:0] next_trig_type_latch;
  reg [ 22:0] next_stored_burst_count;
  
  // for external regs
  reg next_chan_tx_fifo_last;
  reg next_ipbus_res_last;
  reg next_daq_valid;
  reg [63:0] next_daq_data;
  reg [ 4:0] next_chan_error_sn;
  reg [ 4:0] next_chan_error_rc;
  reg [ 3:0] next_chan_tx_fifo_dest;
  reg [22:0] next_burst_count_selftrig;

  wire [19:0] event_size;
  //reg [127:0] burst_data;
  //reg [127:0] next_burst_data;

  //reg [22:0] setup_time;
  //reg zero_setup_time, inc_setup_time;
  //always @(posedge clk) begin
  //  if ( rst || zero_setup_time )
  //    setup_time <= 23'd0;
  //  else if ( inc_setup_time )
  //    setup_time <= setup_time + 1;
  //end
  

//  reg [21:0] delta_trigger, next_delta_trigger, trigger_ticks, next_trigger_ticks;
//  ila_master selftriggers_dbg (
//    .clk(clk),                // input wire clk
//    .probe0(selftriggers_chan0_lo),          // input wire [19 : 0] probe_in0
//    .probe1(selftriggers_chan0_hi),          // input wire [19 : 0] probe_in1
//    .probe2(master_checksum),                // input wire [127: 0] probe_in2
//    .probe3(channel_checksum),               // input wire [127: 0] probe_in3
//    //.probe4(selftriggers_chan4_lo),          // input wire [19 : 0] probe_in4
//    //.probe5(selftriggers_chan0_hi),          // input wire [19 : 0] probe_in5
//    //.probe6(selftriggers_chan1_hi),          // input wire [19 : 0] probe_in6
//    //.probe7(selftriggers_chan2_hi),          // input wire [19 : 0] probe_in7
//    //.probe8(selftriggers_chan3_hi),          // input wire [19 : 0] probe_in8
//    //.probe9(selftriggers_chan4_hi),          // input wire [19 : 0] probe_in9
//    .probe4(event_size_lo),                 // input wire [19 : 0] probe_in10
//    .probe5(event_size_hi),                 // input wire [19 : 0] probe_in11
//    .probe6(event_size),                    // input wire [19 : 0] probe_in12
//    .probe7(initiate_readout),              // input wire [ 0 : 0] probe_in13
//    .probe8(ddr3_buffer),                   // input wire [ 0 : 0] probe_in14
//    .probe9(trig_num_from_channel),         // input wire [23 : 0] probe_in15
//    .probe10(event_num),                     // input wire [23 : 0] probe_in16
//    .probe11(state),                         // input wire [34 : 0] probe_in17
//    .probe12(delta_trigger),                 // input wire [21 : 0] probe_in18
//    .probe13(channel_header_last),
//    .probe14(channel_header_latch),
//    .probe15(data_count[3:0]),
//    .probe16(data_wfm_count[3:0]),
//    .probe17(wfm_count[3:0]),
//    .probe18(chan_rx_fifo_data[31:0]),
//    .probe19(chan_rx_fifo_valid),
//    .probe20(accept_self_triggers),
//    .probe21(send_empty_event)
//  );
`include "constants.vh"


// number of 64-bit words to be sent to AMC13, including AMC13 headers and trailer
  // asychronous or self-trigger readout trigger type
  // Header first (6.7.0).  Before any read-fill command is issued, the fill header of every
  // enabled channel is peeked (CC_PEEK_HDR, which leaves the header in the channel's FIFO) and the
  // waveform count it carries is summed here.  The event size in the AMC13 header is computed from
  // these sums, so it is exact by construction.  (6.7.x also compared them with the trigger-line
  // count record, as a monitor; the line and the record went in 6.8.0.)  A channel whose header
  // could not be peeked (no reply, wrong fill, error code) is left out of the event entirely: it is
  // not read, and the channel header words are not counted for it.
  reg  [19:0] peeked_trigs, next_peeked_trigs;         // waveform counts summed over the peeked channels
  reg  [ 2:0] peeked_chans, next_peeked_chans;         // how many channels were peeked successfully
  reg  [ 4:0] peek_discard_mask, next_peek_discard_mask; // channels that discarded a stale header at the peek
  reg  [22:0] peeked_count [0:4];                       // the count each channel's header carried (checked at the read)
  reg         peek_word, next_peek_word;                // SEND_CHAN_CC: 0 = the CC, 1 = the expected fill number
  reg         next_peeking;
  // the number of 64 bit words used by the channel headers of the channels in the event
  wire [4:0] channel_header_words;
  assign channel_header_words = 5*peeked_chans;

  // the number of 64 bit words words, including waveform header, per self-trigger
  wire [22:0] per_trigger_word_count;
  assign per_trigger_word_count = (burst_count_selftrig*2+2);

  // the total number of 64 bit words for the TTC readout event, including headers and trailers:
  // from the peeked headers (6.7.0; was from the trigger-line count)
  assign event_size = per_trigger_word_count * peeked_trigs + channel_header_words + 4;

  // this actually gets used to compare the number of 32 bit words, hence the "*4"
  wire [22:0] master_burst_count;
  assign master_burst_count = burst_count_selftrig[22:0]*4+3;

  // this board's serial number
  wire [11:0] board_id;
  assign board_id = (i2c_mac_adr[15:8]-1)*256+i2c_mac_adr[7:0];

  // signals to/from Pulse Readout FIFO
  wire readout_fifo_full;

  wire s_readout_fifo_tready;
  reg s_readout_fifo_tvalid;
  reg [127:0] s_readout_fifo_tdata;

  reg m_readout_fifo_tready;
  wire m_readout_fifo_tvalid;
  wire [127:0] m_readout_fifo_tdata;

  wire rst_n;
  assign rst_n = ~rst;

  // Time-out on the channel's reply to a read-fill command: 2^23 clk125 = 67 ms, counted over
  // READ_CHAN_RSN, READ_CHAN_RC and READ_CHAN_INFO1-4 together, restarted at every (re)try.  The
  // channel's own wait for its fill header is 2^21 clk125 = 16.8 ms (cc_rd_fill_sm), after which
  // it answers with an error code, and its fill-closing states are bounded at 2.6 ms
  // (enable_sm_selftrigc), so a channel that is alive always answers well inside this.  The
  // ordering (ours longer) is what keeps a late reply from being orphaned in the channel's RX
  // FIFO.  (6.6.9: both were seconds, a diagnostic setting from before the state snapshots.)
  reg  [23:0] rsn_wait_cntr;
  wire        rsn_wait_timeout;
  wire        waiting_for_reply = state[READ_CHAN_RSN] | state[READ_CHAN_RC] | state[READ_CHAN_INFO1] |
                                  state[READ_CHAN_INFO2] | state[READ_CHAN_INFO3] | state[READ_CHAN_INFO4];
  assign rsn_wait_timeout = rsn_wait_cntr[23];
  always @(posedge clk) begin
    if ( rst || !waiting_for_reply )
      rsn_wait_cntr[23:0] <= 24'd0;
    else if ( !rsn_wait_timeout )
      rsn_wait_cntr[23:0] <= rsn_wait_cntr[23:0] + 1;
  end
  // Time-out on the data stream: 2^24 clk125 = 134 ms with no word from the channel while in the
  // data states (AMC13 back-pressure is waited out in READ_CHAN_DATA_RESYNC, not here).  A channel
  // that stops mid-fill leaves the event incomplete whatever we do, and its frame has no end we
  // could flush to, so this goes to ERROR_DATA_CORRUPTION, which is visible in the status, instead
  // of hanging silently in READ_CHAN_DATA*.  It is the one remaining terminal state of the readout.
  reg  [24:0] data_wait_cntr;
  wire        data_wait_timeout;
  wire        waiting_for_data = state[READ_CHAN_DATA1] | state[READ_CHAN_DATA2];
  assign data_wait_timeout = data_wait_cntr[24];
  always @(posedge clk) begin
    if ( rst || !waiting_for_data || chan_rx_fifo_valid )
      data_wait_cntr[24:0] <= 25'd0;
    else if ( !data_wait_timeout )
      data_wait_cntr[24:0] <= data_wait_cntr[24:0] + 1;
  end
  // Time-out on an IPbus channel transaction: 2^25 clk125 = 268 ms waiting for the channel's reply
  // in READ_IPBUS_RSN / READ_IPBUS_RES, and the same waiting for the software to take a reply word
  // in SEND_IPBUS_RES.  A channel register access answers in microseconds; the software side of a
  // transaction is a few UDP round trips (some tools take the reply in two dispatches), so the
  // bound is generous there rather than tight.  Without this, one
  // channel that never answers (its command dispatcher parked, or a command it does not know,
  // which it does not answer at all) parks this machine, and since readout_ready = IDLE, that
  // stops the readout and every later IPbus access to every channel: the "register access stops
  // working" symptom.  On a time-out the transaction is abandoned (the software sees one bus
  // time-out, which the IPbus bridge survives) and we return to IDLE.
  reg  [25:0] ipb_wait_cntr;
  wire        ipb_wait_timeout;
  wire        waiting_for_ipbus = state[READ_IPBUS_RSN] | state[READ_IPBUS_RES] | state[SEND_IPBUS_RES];
  assign ipb_wait_timeout = ipb_wait_cntr[25];
  always @(posedge clk) begin
    if ( rst || !waiting_for_ipbus || (chan_rx_fifo_valid & chan_rx_fifo_ready) || (ipbus_res_valid & ipbus_res_ready) )
      ipb_wait_cntr[25:0] <= 26'd0;
    else if ( !ipb_wait_timeout )
      ipb_wait_cntr[25:0] <= ipb_wait_cntr[25:0] + 1;
  end
  // whether the last word taken from the RX FIFO ended its frame (tlast), so that a channel we
  // give up on can be flushed to the end of the frame it had started
  reg rx_last_consumed;
  always @(posedge clk) begin
    if ( rst )                                         rx_last_consumed <= 1'b1;
    else if ( chan_rx_fifo_valid & chan_rx_fifo_ready ) rx_last_consumed <= chan_rx_fifo_last;
  end
  // FLUSH_CHAN bound: 2^16 clocks = 0.5 ms *without a word*; restarted by every word taken, so a
  // frame of any length is flushed as long as the channel keeps streaming it
  reg  [16:0] flush_cntr;
  wire        flush_timeout = flush_cntr[16];
  always @(posedge clk) begin
    if ( rst || !state[FLUSH_CHAN] || (chan_rx_fifo_valid & chan_rx_fifo_ready) ) flush_cntr <= 17'd0;
    else if ( !flush_timeout )                                                   flush_cntr <= flush_cntr + 1;
  end
  // What to do after FLUSH_CHAN, decided on the way in:
  //   FLUSH_NEXT    give up on this channel for this event and go on to the next one
  //   FLUSH_RETRY   read the reply again (a stale frame was in front of the real one)
  //   FLUSH_REISSUE send the read-fill command again (the channel served us an older fill)
  //   FLUSH_IPBUS   read the IPbus reply again (stale frame in front of it)
  //   FLUSH_ABORT   abandon the IPbus transaction and return to IDLE
  // A stale frame in a channel's RX FIFO (its reply to a command we had already given up on) used
  // to cost that channel every later event: each readout popped the stale RSN, skipped the channel,
  // and left the channel's genuine reply behind as the next stale frame.  Retrying after the flush
  // lets the readout recover in the same event; the retry counts are small so that a channel whose
  // serial numbers are simply wrong is still given up on quickly.
  localparam [2:0] FLUSH_NEXT = 3'd0, FLUSH_RETRY = 3'd1, FLUSH_REISSUE = 3'd2, FLUSH_IPBUS = 3'd3, FLUSH_ABORT = 3'd4;
  // Error causes reported to the error capture (status registers 35-49).  Data loss: the event
  // delivered to the DAQ is incomplete or wrong.  Fault: the readout path itself failed.  Warning:
  // something went wrong and was recovered without loss.
  localparam ERR_L_NO_REPLY   = 0,   // channel skipped: no reply to the read-fill command within the bound
            ERR_L_BAD_SN     = 1,   // channel skipped: wrong serial numbers, retries exhausted
            ERR_L_ERR_RC     = 2,   // channel skipped: it answered with an error code (its own header wait expired)
            ERR_L_REPLY_CUT  = 3,   // channel skipped: its reply stopped before the header was complete
            ERR_L_FILL_NUM   = 4,   // channel skipped: fill number mismatch not recoverable
            ERR_L_FILL_TYPE  = 5,   // channel skipped: fill type mismatch
                                    // 6: unused since 6.7.0 (a lost count record is a warning now)
            ERR_L_SIZE_MISMATCH = 7, // the header read for a channel is not the one peeked: event size wrong
            ERR_L_CHAN_LOSS  = 8;   // a channel reported data loss in its fill header
            // 9: readout trigger answered empty mid-run (ttc_trigger_receiver); 10: acquisition controller
            // gave up waiting for a channel's done (channel_acq_controller); set in the top level
  localparam ERR_F_DATA_STALL = 0,   // the channel stopped streaming mid-fill (ERROR_DATA_CORRUPTION)
            ERR_F_FLUSH_CUT  = 1,   // a frame being flushed stopped before its end
            ERR_F_CHAN_FAULT = 2,   // a channel reported a fault in its fill header
            ERR_F_CHECKSUM   = 3;   // the channel's checksum did not match the data received: the data was
                                    // corrupted somewhere between the ADC and here, which is always a fault
  localparam ERR_W_STALE_FRAME = 0,  // a stale frame was flushed and the reply read again (recovered)
            ERR_W_REISSUED    = 1,  // unused from 6.8.0: a fill-number mismatch is terminal (6.6.9-6.7.x: stale header discarded / read fill re-issued)
            ERR_W_IPBUS_ABORT = 2,  // an IPbus transaction was abandoned (no reply, or the software stopped reading)
            ERR_W_IPBUS_STALE = 3,  // a stale frame was flushed in front of an IPbus reply (recovered)
            ERR_W_TRIG_COUNT  = 4,  // 6.7.x only: trigger-line count record != peeked headers (no line since 6.8.0)
            ERR_W_COUNT_LOST  = 5;  // 6.7.x only: the count record never came (no record since 6.8.0)
  reg [15:0] next_err_loss_pulse; reg [7:0] next_err_fault_pulse; reg [5:0] next_err_warn_pulse;
  reg [ 4:0] skipped_mask, next_skipped_mask;   // channels skipped in the event being built
  reg [ 1:0] chan_flags, next_chan_flags;       // {re-issued, stale frame flushed} for the channel being read (channel header word)
  assign retry_status = {reply_retries, reissue_retries, skipped_mask};
  reg [2:0] flush_action, next_flush_action;
  reg [1:0] reply_retries, next_reply_retries;      // stale frames flushed before this channel's reply (per command)
  reg [1:0] reissue_retries, next_reissue_retries;  // read-fill commands re-issued to this channel (per event)
  localparam [1:0] MAX_REPLY_RETRIES = 2'd3, MAX_REISSUE_RETRIES = 2'd3;
  // Trigger-number errors are no longer terminal (6.6.9): the channel is skipped for the event
  // (or asked again, see READ_CHAN_INFO1) and the count below says how often that happened.
  reg [7:0] trig_num_errors;
  

  // for debugging
//  assign trig_num_from_channel[23:0] = chan_rx_fifo_data[23:0];
//  reg [31:0] next_channel_header_last,  channel_header_last;
//  reg [31:0] next_channel_header_latch, channel_header_latch;

  // comb always block
  always @* begin
    // internal regs
    nextstate = 35'd0;
    next_wfm_count[22:0]             = wfm_count[22:0];
    next_chan_tag[11:0]              = chan_tag[11:0];
    //next_chan_xadc_alarms[3:0]       = chan_xadc_alarms[3:0];
    next_csn[31:0]                   = csn[31:0];
    next_data_count[31:0]            = data_count[31:0];
    next_data_wfm_count[22:0]        = data_wfm_count[22:0];
    next_ipbus_buf[31:0]             = ipbus_buf[31:0];
    //next_chan_trig_num[23:0]         = chan_trig_num[23:0];
    next_readout_timestamp[31:0]     = readout_timestamp[31:0] + 1; // increment readout timestamp on each clock cycle
    //next_num_chan_en[2:0]            = num_chan_en[2:0];
    next_sent_amc13_header           = sent_amc13_header;
    //next_updown                      = updown;
    next_update_mcs_lsb              = update_mcs_lsb;
    next_master_checksum[127:0]      = master_checksum[127:0];
    //next_burst_data[127:0]           = burst_data[127:0];
    next_channel_checksum[127:0]     = channel_checksum[127:0];
    next_empty_event                 = empty_event;
    next_empty_payload               = empty_payload;
    next_cs_mismatch_count[31:0]     = cs_mismatch_count[31:0];
    next_ipbus_chan_cmd[31:0]        = ipbus_chan_cmd[31:0];
    next_ipbus_chan_reg[31:0]        = ipbus_chan_reg[31:0];
    next_pulse_data_size[22:0]       = pulse_data_size[22:0];
    next_pulse_timestamp[43:0]       = pulse_timestamp[43:0];
    //next_pulse_trig_num[23:0]        = pulse_trig_num[23:0];
    //next_pulse_trig_length[1:0]      = pulse_trig_length[1:0];
    next_s_readout_fifo_tdata[127:0] = s_readout_fifo_tdata[127:0];
    next_pretrigger_count[15:0]      = pretrigger_count[15:0];
    //next_trig_type_latch[4:0]        = trig_type_latch[4:0];
    next_stored_burst_count[22:0]    = stored_burst_count[22:0];
//    next_delta_trigger[21:0]         = delta_trigger[21:0];
//    next_trigger_ticks[21:0]         = trigger_ticks[21:0] + 1;
//    next_channel_header_last[31:0]   = channel_header_last[31:0] ;
//    next_channel_header_latch[31:0]  = channel_header_latch[31:0];

    // external regs
    next_daq_data[63:0]            = daq_data[63:0];
    next_chan_error_sn[4:0]        = chan_error_sn[4:0];
    next_chan_error_rc[4:0]        = chan_error_rc[4:0];
    next_chan_tx_fifo_dest[3:0]    = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last         = chan_tx_fifo_last;
    next_ipbus_res_last            = ipbus_res_last;
    next_burst_count_selftrig      = burst_count_selftrig;
    next_daq_valid          = 0; // default
    chan_tx_fifo_data[31:0] = 0; // default
    ipbus_res_data[31:0]    = 0; // default
    next_flush_action       = flush_action;
    next_reply_retries      = reply_retries;
    next_reissue_retries    = reissue_retries;
    next_err_loss_pulse     = 16'd0;
    next_err_fault_pulse    = 8'd0;
    next_err_warn_pulse     = 6'd0;
    next_skipped_mask       = skipped_mask;
    next_chan_flags         = chan_flags;
    next_peeking            = peeking;
    next_peeked_trigs       = peeked_trigs;
    next_peeked_chans       = peeked_chans;
    next_peek_discard_mask  = peek_discard_mask;
    next_peek_word          = peek_word;
    
    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // watch for IPbus commands
        if (ipbus_cmd_valid) begin
          next_chan_tx_fifo_last = 0;
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
          next_reply_retries = 2'd0;
          nextstate[SEND_IPBUS_CSN] = 1'b1;
        end
        // watch for unread fill events
        else if (initiate_readout) begin
          next_empty_event = send_empty_event;
          next_empty_payload = skip_payload;
          next_chan_tx_fifo_dest[3:0] = 0;
          next_skipped_mask = 5'd0;
          next_peeking           = 1'b1;     // header-first: peek every channel before reading any
          next_peeked_trigs      = 20'd0;
          next_peeked_chans      = 3'd0;
          next_peek_discard_mask = 5'd0;
          next_peek_word         = 1'b0;
//          next_delta_trigger[21:0] = trigger_ticks[21:0];
//          next_trigger_ticks[21:0] = 22'd0;

          if (send_empty_event) begin
            next_daq_valid = 1'b1;
            next_daq_data[63:0] = {8'h00, trig_num[23:0], trig_timestamp[43:32], 20'd4};
            //next_trig_type_latch[4:0] = 5'b0; // reserve zero to indicate no buffered data read out
            nextstate[SEND_AMC13_HEADER1] = 1'b1;
          end
          else begin
            //next_trig_type_latch[4:0] = trig_type[4:0];
            nextstate[CHECK_CHAN_EN] = 1'b1;   // (6.7.x waited in CHECK_SELFTRIG_FIFO for the count record)
          end
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end

      // =================================
      // configuration manager state logic
      // =================================

      // send command serial number to channel
      state[SEND_IPBUS_CSN] : begin
        chan_tx_fifo_data[31:0] = csn[31:0];

        // check that the Aurora TX FIFO is ready
        if (chan_tx_fifo_ready) begin
          next_ipbus_chan_cmd[31:0] = 32'd0; // reset buffer
          next_ipbus_chan_reg[31:0] = 32'd0; // reset buffer
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_CSN] = 1'b1;
        end
      end
      // read IPbus command
      state[READ_IPBUS_CMD] : begin
        // check that IPbus has data for us
        if (ipbus_cmd_valid) begin
          next_ipbus_buf[31:0] = ipbus_cmd_data[31:0];
          next_ipbus_chan_cmd[31:0] = ipbus_chan_reg[31:0];
          next_ipbus_chan_reg[31:0] = ipbus_cmd_data[31:0];

          // watch for write register commands
          if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0014)) begin
            next_burst_count_selftrig = {9'd0, ipbus_cmd_data[13:0]}; // burst count value, self trigger acquisition
          end
          nextstate[CHECK_LAST] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
      end
      // check if this is the last IPbus command word
      state[CHECK_LAST] : begin
        next_chan_tx_fifo_last = ipbus_cmd_last;
        nextstate[SEND_IPBUS_CMD] = 1'b1;
      end
      // send IPbus command to channel
      state[SEND_IPBUS_CMD] : begin
        chan_tx_fifo_data[31:0] = ipbus_buf[31:0];

        if (chan_tx_fifo_ready & chan_tx_fifo_last) begin
          nextstate[READ_IPBUS_RSN] = 1'b1;
        end
        else if (chan_tx_fifo_ready) begin
          next_chan_tx_fifo_last = 0;
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_CMD] = 1'b1;
        end
      end
      // read response serial number from channel; it must be the CSN we sent.  A stale frame
      // (an earlier reply we gave up on) is flushed and the read tried again; no reply at all
      // within the bound abandons the transaction.
      state[READ_IPBUS_RSN] : begin
        if (chan_rx_fifo_valid) begin
          if (chan_rx_fifo_data[31:0] == csn[31:0]) begin
            nextstate[READ_IPBUS_RES] = 1'b1;
          end
          else begin
            if (chan_tx_fifo_dest < 4'd5) next_chan_error_sn[chan_tx_fifo_dest] = 1'b1;
            if (reply_retries != MAX_REPLY_RETRIES) begin
              next_reply_retries = reply_retries + 1;
              next_flush_action  = FLUSH_IPBUS;
              next_err_warn_pulse[ERR_W_IPBUS_STALE] = 1'b1;
            end
            else begin
              next_flush_action  = FLUSH_ABORT;
              next_err_warn_pulse[ERR_W_IPBUS_ABORT] = 1'b1;
            end
            nextstate[FLUSH_CHAN] = 1'b1;
          end
        end
        else if (ipb_wait_timeout) begin
          if (chan_tx_fifo_dest < 4'd5) next_chan_error_sn[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_ABORT;
          next_err_warn_pulse[ERR_W_IPBUS_ABORT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_RSN] = 1'b1;
        end
      end
      // read response from channel
      state[READ_IPBUS_RES] : begin
        if (chan_rx_fifo_valid) begin
          next_ipbus_buf[31:0] = chan_rx_fifo_data[31:0];
          next_ipbus_res_last = chan_rx_fifo_last;
          nextstate[SEND_IPBUS_RES] = 1'b1;
        end
        else if (ipb_wait_timeout) begin
          // the reply stopped short of its tlast: nothing to flush, the frame is simply incomplete
          if (chan_tx_fifo_dest < 4'd5) next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_ABORT;
          next_err_warn_pulse[ERR_W_IPBUS_ABORT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
      end
      // send response to IPbus
      state[SEND_IPBUS_RES] : begin
        ipbus_res_data[31:0] = ipbus_buf[31:0];

        if (ipbus_res_ready & ipbus_res_last) begin
          next_csn[31:0] = csn[31:0]+1;
          nextstate[IDLE] = 1'b1;
        end
        else if (ipbus_res_ready) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
        else if (ipb_wait_timeout) begin
          // the software stopped taking the reply: drop the rest of the channel's frame
          next_flush_action = FLUSH_ABORT;
          next_err_warn_pulse[ERR_W_IPBUS_ABORT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_RES] = 1'b1;
        end
      end

      // =========================
      // event builder state logic
      // =========================

      // Unused since 6.8.0 (it waited for the trigger-line count record): never entered, and
      // left at once if it ever were.
      state[CHECK_SELFTRIG_FIFO] : begin
        nextstate[CHECK_CHAN_EN] = 1'b1;
      end
      
      // check whether this channel number is enabled
      state[CHECK_CHAN_EN] : begin
        if (cs_mismatch_count > thres_data_corrupt) begin
          nextstate[ERROR_DATA_CORRUPTION] = 1'b1;
        end
        else if ((chan_tx_fifo_dest[3:0] == 4'h5) && peeking) begin
          // every channel has been peeked: the event size is known.  Read the fills of the peeked
          // channels in turn.
          next_peeking = 1'b0;
          next_chan_tx_fifo_dest[3:0] = 0;
          nextstate[CHECK_CHAN_EN] = 1'b1;
        end
        else if ((chan_tx_fifo_dest[3:0] == 4'h5) && !sent_amc13_header) begin
          // every enabled channel was skipped (or none is enabled): send a well-formed empty
          // event rather than a trailer with no header
          next_empty_event = 1'b1;
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {8'h00, trig_num[23:0], trig_timestamp[43:32], 20'd4};
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
        else if (chan_tx_fifo_dest[3:0] == 4'h5) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else if (chan_en[chan_tx_fifo_dest] && !(skipped_mask[chan_tx_fifo_dest] && !peeking)) begin
          // (a channel skipped at the peek is not read: it is not in the event size)
          //next_num_chan_en[2:0] = num_chan_en[2:0] + 1;
          next_chan_tx_fifo_last = 0;
          next_reply_retries   = 2'd0;
          next_reissue_retries = 2'd0;
          next_chan_flags      = {peek_discard_mask[chan_tx_fifo_dest] & ~peeking, 1'b0};
          next_peek_word       = 1'b0;
          nextstate[SEND_CHAN_CSN] = 1'b1;
        end
        else begin
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0] + 1;
          nextstate[CHECK_CHAN_EN] = 1'b1;
        end
      end
      // send command serial number to channel
      state[SEND_CHAN_CSN] : begin
        chan_tx_fifo_data[31:0] = csn[31:0];

        if (chan_tx_fifo_ready) begin
          next_chan_tx_fifo_last = ~peeking;   // the peek command has one more word, the fill number
          nextstate[SEND_CHAN_CC] = 1'b1;
        end
        else begin
          nextstate[SEND_CHAN_CSN] = 1'b1;
        end
      end
      // send the command code to the channel: 'read fill' (0x8), or when peeking 'peek header'
      // (0xB) followed by the fill number we expect (the channel discards older headers itself)
      state[SEND_CHAN_CC] : begin
        chan_tx_fifo_data[31:0] = peek_word ? {8'd0, event_num[23:0]} : (peeking ? 32'hB : 32'h8);

        if (chan_tx_fifo_ready && peeking && !peek_word) begin
          next_peek_word = 1'b1;
          next_chan_tx_fifo_last = 1;
          nextstate[SEND_CHAN_CC] = 1'b1;
        end
        else if (chan_tx_fifo_ready) begin
          next_peek_word = 1'b0;
          nextstate[READ_CHAN_RSN] = 1'b1;
        end
        else begin
          nextstate[SEND_CHAN_CC] = 1'b1;
        end
      end
      // read response serial number from channel
      state[READ_CHAN_RSN] : begin
        if (chan_rx_fifo_valid) begin
          // check that the serial numbers are the same
          if (chan_rx_fifo_data[31:0] == csn[31:0]) begin
            // everything is good
            nextstate[READ_CHAN_RC] = 1'b1;
          end
          else begin
            // a stale frame (a reply to a command we had given up on): flag it, drain it to its
            // tlast, and read again, since the real reply is behind it.  After a few of these the
            // channel's serial numbers are simply wrong and it is skipped for this event.
            next_chan_error_sn[chan_tx_fifo_dest] = 1'b1;
            if (reply_retries != MAX_REPLY_RETRIES) begin
              next_reply_retries = reply_retries + 1;
              next_flush_action  = FLUSH_RETRY;
              next_chan_flags[0] = 1'b1;
              next_err_warn_pulse[ERR_W_STALE_FRAME] = 1'b1;
            end
            else begin
              next_flush_action  = FLUSH_NEXT;
              next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
              next_err_loss_pulse[ERR_L_BAD_SN] = 1'b1;
            end
            nextstate[FLUSH_CHAN] = 1'b1;
          end
        end
        else if (rsn_wait_timeout) begin
          // no response from the channel: give up on it for this event (nothing to flush now; if
          // the reply comes later it is the stale frame handled above at the next readout)
          next_chan_error_sn[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_NO_REPLY] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_RSN] = 1'b1;
        end
      end
      // read response code from channel
      // if complement of '0x8' command code, an error occured in channel
      state[READ_CHAN_RC] : begin
        if (chan_rx_fifo_valid) begin
          // check that the channel didn't report any errors
          if (!peeking && (chan_rx_fifo_data[31:0] == 32'h8)) begin
            // everything is good
            nextstate[READ_CHAN_INFO1] = 1'b1;
          end
          else if (peeking && (chan_rx_fifo_data[7:0] == 8'h0B) && (chan_rx_fifo_data[31:9] == 23'd0)) begin
            // the peek reply.  [8] says the channel discarded an older header to get to this one (a
            // 6.7.x channel does that; from 6.8.0 it returns the older header as it is and the
            // fill-number check below stops the readout).  Either way the fill numbers were out of
            // step: terminal, as in READ_CHAN_INFO1.
            if (chan_rx_fifo_data[8]) begin
              next_peek_discard_mask[chan_tx_fifo_dest] = 1'b1;
              next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
              next_err_loss_pulse[ERR_L_FILL_NUM] = 1'b1;
              nextstate[ERROR_TRIG_NUM] = 1'b1;
            end
            else begin
              nextstate[READ_CHAN_INFO1] = 1'b1;
            end
          end
          else begin
            // an error occured, update status register, and report error
            // ABORT THIS CHANNEL'S READOUT (drain whatever else the channel sent, then move on)
            next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
            next_flush_action = FLUSH_NEXT;
            next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
            next_err_loss_pulse[ERR_L_ERR_RC] = 1'b1;
            nextstate[FLUSH_CHAN] = 1'b1;
          end
        end
        else if (rsn_wait_timeout) begin
          next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_REPLY_CUT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_RC] = 1'b1;
        end
      end
      // Drain the skipped channel's RX FIFO to the end of the frame it had started (the word with
      // tlast), so that nothing stale is left for the next readout or IPbus access.  If the last
      // word taken already ended the frame there is nothing to do.  Bounded (2^16 clocks = 0.5 ms
      // without a word) in case the frame never completes.
      state[FLUSH_CHAN] : begin
        if (rx_last_consumed || flush_timeout || (chan_rx_fifo_valid && chan_rx_fifo_last)) begin
          if (flush_timeout && !rx_last_consumed) next_err_fault_pulse[ERR_F_FLUSH_CUT] = 1'b1;
          case (flush_action)
            FLUSH_RETRY: begin
              nextstate[READ_CHAN_RSN] = 1'b1;           // same command, read the next frame
            end
            FLUSH_REISSUE: begin
              next_csn[31:0] = csn[31:0]+1;              // new command to the same channel
              next_chan_tx_fifo_last = 0;
              nextstate[SEND_CHAN_CSN] = 1'b1;
            end
            FLUSH_IPBUS: begin
              nextstate[READ_IPBUS_RSN] = 1'b1;
            end
            FLUSH_ABORT: begin
              next_csn[31:0] = csn[31:0]+1;
              nextstate[IDLE] = 1'b1;
            end
            default: begin                               // FLUSH_NEXT
              next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
              next_csn[31:0] = csn[31:0]+1;
              nextstate[CHECK_CHAN_EN] = 1'b1;
            end
          endcase
        end
        else begin
          nextstate[FLUSH_CHAN] = 1'b1;
        end
      end
      // get trigger number from channel's header word #1 (in channel firmware, this is the 1st of 4 32 bit words from the full header)
      state[READ_CHAN_INFO1] : begin
        if (chan_rx_fifo_valid) begin
//          next_channel_header_last[31:0]  = channel_header_latch[31:0];
//          next_channel_header_latch[31:0] = chan_rx_fifo_data[31:0];
          
          // check that trigger number from channel header and trigger logic match
          if (event_num[23:0] != chan_rx_fifo_data[23:0]) begin
            // Fill numbers are not in step (at the peek or at the read, older or newer): the channel
            // and the trigger logic disagree about which event this is, and going on risks building
            // an event from uncorrelated fills.  Terminal (6.8.0; 6.6.9-6.7.x re-read or skipped
            // the channel): the readout stops in ERROR_TRIG_NUM, the data loss drives TTS sync-lost and
            // the run is aborted; only a reset gets out of it.
            next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
            next_err_loss_pulse[ERR_L_FILL_NUM] = 1'b1;
            nextstate[ERROR_TRIG_NUM] = 1'b1;
          end
          // check that trigger type from channel header and trigger logic match -- this checks that it is not an async mode
          else if (trig_type[2] & (chan_rx_fifo_data[26] != 1'b0)) begin
            // trigger types aren't synchronized: skip the channel for this event (not terminal, 6.6.9)
            next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
            next_flush_action = FLUSH_NEXT;
            next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
            next_err_loss_pulse[ERR_L_FILL_TYPE] = 1'b1;
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          else begin
            next_pulse_data_size[22:0] = {18'd0, chan_rx_fifo_data[31:27]};

            //next_chan_trig_num[23:0] = chan_rx_fifo_data[23:0];
            next_master_checksum[127:0] = {master_checksum[127:32], chan_rx_fifo_data[31:0]};
            //next_burst_data[127:0]      = {96'd0, chan_rx_fifo_data[31:0]};
            nextstate[READ_CHAN_INFO2] = 1'b1;
            next_stored_burst_count[4:0] = chan_rx_fifo_data[31:27];
          end
        end
        else if (rsn_wait_timeout) begin
          next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_REPLY_CUT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO1] = 1'b1;
        end
      end
      // get highst 18 bits of burst count from channel's header word #2 (in channel firmware, this is the 2nd of 4 32 bit words from the full header)
      state[READ_CHAN_INFO2] : begin
        if (chan_rx_fifo_valid) begin
          next_pulse_data_size[22:0]    = {chan_rx_fifo_data[17:0], pulse_data_size[4:0]};
          next_stored_burst_count[22:0] = {chan_rx_fifo_data[17:0],stored_burst_count[4:0]};

          next_master_checksum[127:0] = {master_checksum[127:64], chan_rx_fifo_data[31:0], master_checksum[31:0]};
          //next_burst_data[127:0]      = {64'd0, chan_rx_fifo_data[31:0], burst_data[31:0]};
          nextstate[READ_CHAN_INFO3] = 1'b1;
        end
        else if (rsn_wait_timeout) begin
          next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_REPLY_CUT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO2] = 1'b1;
        end
      end
      // get DDR3 start address from channel's header word #3 (in channel firmware, this is the 3rd of 4 32 bit words from the full header)
      state[READ_CHAN_INFO3] : begin
        if (chan_rx_fifo_valid) begin
          next_pretrigger_count[11:0] = chan_rx_fifo_data[11:0];
          next_wfm_count[19:0]        = chan_rx_fifo_data[31:12];

          next_master_checksum[127:0] = {master_checksum[127:96], chan_rx_fifo_data[31:0], master_checksum[63:0]};
          //next_burst_data[127:0]      = {32'd0, chan_rx_fifo_data[31:0], burst_data[63:0]};
          nextstate[READ_CHAN_INFO4] = 1'b1;
        end
        else if (rsn_wait_timeout) begin
          next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_REPLY_CUT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO3] = 1'b1;
        end
      end
      // get tag and fill type from channel's header word #4 (in channel firmware, this is the last of 4 32 bit words from the full header)
      state[READ_CHAN_INFO4] : begin
        if (chan_rx_fifo_valid) begin
        // check that trigger type from channel header and trigger logic match
          if (trig_type[2] & (chan_rx_fifo_data[27:26] != 2'b10)) begin
            // trigger types aren't synchronized: skip the channel for this event (not terminal, 6.6.9)
            next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
            next_flush_action = FLUSH_NEXT;
            next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
            next_err_loss_pulse[ERR_L_FILL_TYPE] = 1'b1;
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          else begin
            //next_chan_xadc_alarms[3:0]   = 4'h0;
            next_wfm_count[22:20]        = chan_rx_fifo_data[2:0];
            next_pretrigger_count[15:12] = chan_rx_fifo_data[6:3];

            next_chan_tag[11:0] = chan_rx_fifo_data[25:14];
            next_master_checksum[127:0] = {chan_rx_fifo_data[31:0], master_checksum[95:0]};
            //next_burst_data[127:0]      = {chan_rx_fifo_data[31:0], burst_data[95:0]};
            if (peeking) begin
              // the header is complete: add this channel's waveform count to the event, go on to
              // the next channel (the header stays in the channel's FIFO for the read)
              next_peeked_trigs = peeked_trigs + {chan_rx_fifo_data[2:0], wfm_count[19:0]};
              next_peeked_chans = peeked_chans + 3'd1;
              next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0] + 1;
              next_csn[31:0] = csn[31:0] + 1;
              nextstate[CHECK_CHAN_EN] = 1'b1;
            end
            else begin
              // the channel's error word (6.6.10): [13] it lost data, [12] it had a fault, [11:7] its cause code
              if (chan_rx_fifo_data[13]) next_err_loss_pulse[ERR_L_CHAN_LOSS]   = 1'b1;
              if (chan_rx_fifo_data[12]) next_err_fault_pulse[ERR_F_CHAN_FAULT] = 1'b1;
              // the header must be the one peeked, or the event size already sent is wrong
              if ({chan_rx_fifo_data[2:0], wfm_count[19:0]} != peeked_count[chan_tx_fifo_dest]) next_err_loss_pulse[ERR_L_SIZE_MISMATCH] = 1'b1;
              nextstate[READY_AMC13_HEADER1] = 1'b1;
            end
          end
        end
        else if (rsn_wait_timeout) begin
          next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;
          next_flush_action = FLUSH_NEXT;
          next_skipped_mask[chan_tx_fifo_dest] = 1'b1;
          next_err_loss_pulse[ERR_L_REPLY_CUT] = 1'b1;
          nextstate[FLUSH_CHAN] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO4] = 1'b1;
        end
      end
      // pause to store the channel's tag and fill type
      state[READY_AMC13_HEADER1] : begin
        if (!sent_amc13_header) begin
          next_daq_valid = 1'b1;

          // return empty event format
          if (empty_payload) begin
            next_daq_data[63:0] = {8'h00, trig_num[23:0], trig_timestamp[43:32], 20'd4};
          end
          // return normal event format
          else begin
            next_daq_data[63:0] = {8'd0, trig_num[23:0], trig_timestamp[43:32], event_size[19:0]};
          end

          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
        else if (empty_payload) begin
          next_readout_timestamp[31:0] = 32'd0;

          next_data_count[31:0] = 32'd0;
          next_data_wfm_count[22:0] = 23'd0;
          next_update_mcs_lsb = 0;

          // do not send channel header
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b1;

            // this next line prepares the first 64 bit channel header word
            // [61:60] {read fill re-issued, stale frame flushed} for this channel; [45:39] the channel's
            // error word from its fill header ({lost data, fault, cause code[4:0]}, 6.6.10)
            next_daq_data[63:0] = {2'b01, chan_flags[1:0], 2'b00, chan_tag[11:0], last_info4_word[13:7], wfm_count[22:0], pretrigger_count[15:0]};

          next_readout_timestamp[31:0] = 32'd0;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
        end
      end
      // send the first AMC13 header word
      state[SEND_AMC13_HEADER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          // this next prepares the 2nd AMC13 header word for sending
          next_daq_data[63:0] = {chan_en[4:0], endianness_sel, ttc_xadc_alarms[3:0], (empty_event | empty_payload), trig_type[4:0], trig_timestamp[31:0], 3'd1, 1'b0, board_id[11:0]};
          nextstate[SEND_AMC13_HEADER2] = 1'b1;
        end
        else if (~daq_almost_full) begin
          next_daq_valid = 1'b1;
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b0;
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
      end
      // send the second AMC13 header word
      state[SEND_AMC13_HEADER2] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          // this sends the WFD5 header word -- the bit next to the Major Revision flags this module in self triggering mode
          // [63:61] {data loss, fault, warning} latched so far (error capture), [60:56] channels
          // skipped so far in this event, [55:25] 0, [24] self-trigger image, [23:0] version (6.6.10)
          next_daq_data[63:0] = {err_summary[2:0], skipped_mask[4:0], 31'd0, 1'b1, MAJOR_REV, MINOR_REV, PATCH_REV};
          nextstate[SEND_WFD5_HEADER] = 1'b1;
        end
        else if (~daq_almost_full) begin
          next_daq_valid = 1'b1;
          nextstate[SEND_AMC13_HEADER2] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b0;
          nextstate[SEND_AMC13_HEADER2] = 1'b1;
        end
      end
      // send the WFD5 header word
      state[SEND_WFD5_HEADER] : begin
        if (empty_event) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else if (empty_payload) begin
          next_sent_amc13_header = 1'b1;
          next_readout_timestamp[31:0] = 32'd0;

          next_data_count[31:0] = 32'd0;
          next_data_wfm_count[22:0] = 23'd0;
          next_update_mcs_lsb = 0;

          // do not send channel header
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else if (daq_ready) begin
          next_daq_valid = 1'b1;

         // prepare the first 64-bit channel header word for this channel
          next_daq_data[63:0] = {2'b01, chan_flags[1:0], 2'b00, chan_tag[11:0], last_info4_word[13:7], wfm_count[22:0], pretrigger_count[15:0]};

          next_sent_amc13_header = 1'b1;
          next_readout_timestamp[31:0] = 0;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
        end
        else if (~daq_almost_full) begin
          next_daq_valid = 1'b1;
          nextstate[SEND_WFD5_HEADER] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b0;
          nextstate[SEND_WFD5_HEADER] = 1'b1;
        end
      end  
      // send the first channel header word
      state[SEND_CHAN_HEADER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;

          // prepare the second 64-bit channel header word
          next_daq_data[63:0] = {stored_burst_count[13:0], pulse_data_size[22:0], trig_type[2:0], trig_num[23:0]};
          nextstate[SEND_CHAN_HEADER2] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b1;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
        end
      end
      // send the second channel header word
      state[SEND_CHAN_HEADER2] : begin
        if (daq_ready) begin
          next_data_count[31:0] = 32'd0;
          next_data_wfm_count[22:0] = 23'd0;
          next_update_mcs_lsb = 0;
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b1;
          nextstate[SEND_CHAN_HEADER2] = 1'b1;
        end
      end
      // read the first 32-bit data word from channel
      state[READ_CHAN_DATA1] : begin
        // check if the Aurora RX FIFO has data for us
        if (chan_rx_fifo_valid) begin
          // this is the waveform header [31:0]
          if ((data_count[31:0] == 0) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
              // keep pre- and post-trigger waveform length in units of bursts // st copying the pre-trigger length seems messed up here
              // prepare the lower half of the 1st 64 byte waveform header
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
            //next_burst_data[127:0]      = {96'd0, chan_rx_fifo_data[31:0]};
          end
          // this is the waveform header [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
              // prepare the lower half of the 2nd 64 bit waveform header
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
            //next_burst_data[127:0]      = {32'd0, chan_rx_fifo_data[31:0], burst_data[63:0]};
          end
          // this is the channel checksum [31:0]
          else if ((data_count[31:0] == 0) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
            //next_burst_data[127:0]      = {96'd0, chan_rx_fifo_data[31:0]};
          end
          // this is the channel checksum [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
            //next_burst_data[127:0]      = {32'd0, chan_rx_fifo_data[31:0], burst_data[63:0]};
          end
          // this is an ADC data word
          else begin
            // big-endian data format, can be switched in next state
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
            //if ( updown )
            //  next_burst_data[127:0] = {32'd0, chan_rx_fifo_data[31:0], burst_data[63:0]};
            //else
            //  next_burst_data[127:0] = {96'd0, chan_rx_fifo_data[31:0]};
          end

          // this is the channel checksum [31:0]
          if ((data_count[31:0] == 0) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            next_channel_checksum[127:0] = {96'd0, chan_rx_fifo_data[31:0]};
          end
          // this is the channel checksum [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            next_channel_checksum[127:0] = {32'd0, chan_rx_fifo_data[31:0], channel_checksum[63:0]};
          end
          else begin
            // update least- or most-significant 64-bits of checksum
            // use '~update_mcs_lsb' to determine the 'next' value
            next_master_checksum[127:0] = (~update_mcs_lsb) ? {master_checksum[127:32], (master_checksum[31:0]^chan_rx_fifo_data[31:0])} : {master_checksum[127:96], (master_checksum[95:64]^chan_rx_fifo_data[31:0]), master_checksum[63:0]};
          end

          next_data_count[31:0] = data_count[31:0]+1;
          nextstate[READ_CHAN_DATA2] = 1'b1;
        end
        else if (data_wait_timeout) begin
          next_err_fault_pulse[ERR_F_DATA_STALL] = 1'b1;
          nextstate[ERROR_DATA_CORRUPTION] = 1'b1;   // the channel stopped streaming mid-fill
        end
        else begin
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
      end
      // read the second 32-bit data word from channel, and
      // send the data to the DAQ link to AMC13
      state[READ_CHAN_DATA2] : begin
        // this state's logic ties together the 'ready' and 'valid' signals between the Aurora RX FIFO and DAQ link
        // that allows the data gets sent to the DAQ link directly, increasing data throughput rates

        // DAQ link has flagged that its buffer is almost full
        // grab the Aurora RX FIFO's lastest word, and wait for DAQ link to recover before trying to send it
        if (~daq_ready & chan_rx_fifo_valid) begin
          // this is the waveform header [63:32]
          if ((data_count[31:0] == 1) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // keep waveform header format as it is -- prepare the upper half of the 1st 64 bit waveform header
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0] = {32'd0, burst_data[95:64], chan_rx_fifo_data[31:0], burst_data[31:0]};
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0]      = {chan_rx_fifo_data[31:0], burst_data[95:0]};
          end
          // this is the channel checksum [63:32]
          else if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0] = {64'd0, chan_rx_fifo_data[31:0], burst_data[31:0]};
          end
          // this is the channel checksum [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0]      = {chan_rx_fifo_data[31:0], burst_data[95:0]};
          end
          // this is an ADC data word
          else begin
            // send ADC data in desired endianness:
            //      big-endian when 'endianness_sel' is 0 (default)
            //   little-endian when 'endianness_sel' is 1
            //if ( updown ) begin
            //  next_burst_data[127:0] = {chan_rx_fifo_data[31:0], burst_data[95:0]}; 
            //  next_updown = 0;
            //end
            //else begin
            //  next_burst_data[127:0] = {64'd0, chan_rx_fifo_data[31:0], burst_data[31:0]};
            //  next_updown = 1;
            //end
            next_daq_data[63:0] = (~endianness_sel) ? {chan_rx_fifo_data[31:0], daq_data[31:0]} : {daq_data[7:0], daq_data[15:8], daq_data[23:16], daq_data[31:24], chan_rx_fifo_data[7:0], chan_rx_fifo_data[15:8], chan_rx_fifo_data[23:16], chan_rx_fifo_data[31:24]};
          end

          next_data_count[31:0]     = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
          next_update_mcs_lsb = ~update_mcs_lsb;

          // check whether this data word is the channel checksum
          if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            next_channel_checksum[127:0] = {64'd0, chan_rx_fifo_data[31:0], channel_checksum[31:0]};
          end
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            next_channel_checksum[127:0] = {chan_rx_fifo_data[31:0], channel_checksum[95:0]};
          end
          else begin
            // update least- or most-significant 64-bits of checksum
            // use '~update_mcs_lsb' to determine the 'next' value
            next_master_checksum[127:0] = (~update_mcs_lsb) ? {master_checksum[127:64], (master_checksum[63:32]^chan_rx_fifo_data[31:0]), master_checksum[31:0]} : {(master_checksum[127:96]^chan_rx_fifo_data[31:0]), master_checksum[95:0]};
          end
          nextstate[READ_CHAN_DATA_RESYNC] = 1'b1;
        end
        // we're receiving the last data word
        // send it, and exit to send the channel trailer next
        else if (daq_ready & chan_rx_fifo_valid & (data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
          if (~empty_payload) begin
            next_daq_valid = 1'b1;
          end

          // this is the channel checksum, use big-endian
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};

          next_data_count[31:0]     = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
          next_channel_checksum[127:0] = {chan_rx_fifo_data[31:0], channel_checksum[95:0]};
          
          nextstate[SEND_CHAN_TRAILER1] = 1'b1;
        end
        // we've not received all the data
        // send current data, and continue the readout loop
        else if (daq_ready & chan_rx_fifo_valid) begin
          if (~empty_payload) begin
            next_daq_valid = 1'b1;
          end
          // this is the waveform header [63:32]
          if ((data_count[31:0] == 1) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // keep waveform header format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0] = {32'd0, burst_data[95:64], chan_rx_fifo_data[31:0], burst_data[31:0]};
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0]      = {chan_rx_fifo_data[31:0], burst_data[95:0]};
          end
          // this is the channel checksum [63:32]
          else if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0] = {64'd0, chan_rx_fifo_data[31:0], burst_data[31:0]};
          end
          // this is the channel checksum [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
            //next_burst_data[127:0]      = {chan_rx_fifo_data[31:0], burst_data[95:0]};
          end
          // this is an ADC data word
          else begin
            // send ADC data in desired endianness:
            //      big-endian when 'endianness_sel' is 0 (default)
            //   little-endian when 'endianness_sel' is 1
            next_daq_data[63:0] = (~endianness_sel) ? {chan_rx_fifo_data[31:0], daq_data[31:0]} : {daq_data[7:0], daq_data[15:8], daq_data[23:16], daq_data[31:24], chan_rx_fifo_data[7:0], chan_rx_fifo_data[15:8], chan_rx_fifo_data[23:16], chan_rx_fifo_data[31:24]};
            //if ( updown ) begin
            //  next_burst_data[127:0] = {chan_rx_fifo_data[31:0], burst_data[95:0]}; 
            //  next_updown = 0;
            //end
            //else begin
            //  next_burst_data[127:0] = {64'd0, chan_rx_fifo_data[31:0], burst_data[31:0]};
            //  next_updown = 1;
            //end
          end

          // a burst is 8 samples, or 128 bits.  We read data 32 bits at a time.  Hence the "*4".  There is also a waveform header.
          next_data_count[31:0]     = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count_selftrig[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
          next_update_mcs_lsb = ~update_mcs_lsb;

          // check whether this data word is the channel checksum
          if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            next_channel_checksum[127:0] = {64'd0, chan_rx_fifo_data[31:0], channel_checksum[31:0]};
          end
          else begin
            // update least- or most-significant 64-bits of checksum
            // use '~update_mcs_lsb' to determine the 'next' value
            next_master_checksum[127:0] = (~update_mcs_lsb) ? {master_checksum[127:64], (master_checksum[63:32]^chan_rx_fifo_data[31:0]), master_checksum[31:0]} : {(master_checksum[127:96]^chan_rx_fifo_data[31:0]), master_checksum[95:0]};
          end
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else if (data_wait_timeout) begin
          next_err_fault_pulse[ERR_F_DATA_STALL] = 1'b1;
          nextstate[ERROR_DATA_CORRUPTION] = 1'b1;   // the channel stopped streaming mid-fill
        end
        else begin
          // Aurora RX FIFO doesn't have valid data
          nextstate[READ_CHAN_DATA2] = 1'b1;
        end
      end
      // pause until the DAQ link is ready for more data
      state[READ_CHAN_DATA_RESYNC] : begin
        // we've already received the last data word
        // send it, and exit to send the readout timestamp next
        if (daq_ready & (data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
          if (~empty_payload) begin
            next_daq_valid = 1'b1;
          end
          nextstate[SEND_CHAN_TRAILER1] = 1'b1;
        end
        // we've not received all the data
        // send current data, and continue readout loop
        // ('else': both conditions hold on the last checksum word under back-pressure, and the
        //  one-hot machine must not be sent two ways at once)
        else if (daq_ready) begin
          if (~empty_payload) begin
            next_daq_valid = 1'b1;
          end
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else begin
          // DAQ link buffer is still almost full
          nextstate[READ_CHAN_DATA_RESYNC] = 1'b1;
        end
      end
      // send the channel readout's timestamp
      state[SEND_CHAN_TRAILER1] : begin
        if (daq_ready) begin
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
          next_csn[31:0] = csn[31:0]+1;

          if (~empty_payload) begin
            next_daq_valid = 1'b1;
          end

          // check whether the checksums match
          // if they match, send '0000_0000' in MSB
          if (master_checksum[127:0] == channel_checksum[127:0]) begin
            next_daq_data[63:0] = {32'h0000_0000, readout_timestamp[31:0]};
          end
          // if they don't match, send 'baad_baad' in MSB
          else begin
            next_daq_data[63:0] = {32'hbaad_baad, readout_timestamp[31:0]};
            next_cs_mismatch_count[31:0] = cs_mismatch_count[31:0] + 1; // increment mismatch count
            next_err_fault_pulse[ERR_F_CHECKSUM] = 1'b1;  // the data delivered for this channel is corrupt
          end

          nextstate[CHECK_CHAN_EN] = 1'b1;
        end
        else begin
          // DAQ link buffer is still almost full
          nextstate[SEND_CHAN_TRAILER1] = 1'b1;
        end
      end
      // prepare the AMC13 trailer word
      state[READY_AMC13_TRAILER] : begin
        next_daq_valid = 1'b1;

        // return empty event format
        if (empty_event | empty_payload) begin
          next_daq_data[63:0] = {32'd0, trig_num[7:0], 4'h0, 20'd4};
        end
        // return normal event format
        else begin
          next_daq_data[63:0] = {32'd0, trig_num[7:0], 4'h0, event_size[19:0]};
        end

        nextstate[SEND_AMC13_TRAILER] = 1'b1;
      end
      // send the AMC13 trailer
      state[SEND_AMC13_TRAILER] : begin
        if (daq_ready) begin
          //next_chan_trig_num[23:0] = 0;
          next_csn[31:0]           = csn[31:0] + 1;
          next_daq_data[63:0]      = 0;
          next_sent_amc13_header   = 0;
          //next_num_chan_en[2:0]    = 0; // reset the number of enabled channels for each new trigger
          next_empty_event         = 0;
          next_empty_payload       = 0;
          //next_updown              = 0;

          nextstate[IDLE] = 1'b1;
        end
        else if (~daq_almost_full) begin
          next_daq_valid = 1'b1;
          nextstate[SEND_AMC13_TRAILER] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b0;
          nextstate[SEND_AMC13_TRAILER] = 1'b1;
        end
      end

      // =================
      // error state logic
      // =================

      // data corruption error detected
      state[ERROR_DATA_CORRUPTION] : begin
        nextstate[ERROR_DATA_CORRUPTION] = 1'b1; // hard error, stay here
      end
      // fill (trigger) number mismatch: terminal, see READ_CHAN_INFO1
      state[ERROR_TRIG_NUM] : begin
        nextstate[ERROR_TRIG_NUM] = 1'b1; // hard error, stay here (6.8.0)
      end
      // trigger type mismatch: one clock, then drain the channel's reply and go on to the next channel
      state[ERROR_TRIG_TYPE] : begin
        nextstate[FLUSH_CHAN] = 1'b1;
      end
    endcase
  end


  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      // reset values
      state <= 35'd1 << IDLE;

      chan_tag[11:0]            <= 0;
      //chan_xadc_alarms[3:0]     <= 0;
      wfm_count[22:0]           <= 0;
      chan_tx_fifo_dest[3:0]    <= 0;
      chan_tx_fifo_last         <= 0;
      csn[31:0]                 <= 0;
      daq_data[63:0]            <= 0;
      data_count[31:0]          <= 0;
      data_wfm_count[22:0]      <= 0;
      ipbus_buf[31:0]           <= 0;
      ipbus_res_last            <= 0;
      //num_chan_en[2:0]          <= 0;
      sent_amc13_header         <= 0;
      //chan_trig_num[23:0]       <= 0;
      readout_timestamp[31:0]   <= 0;
      chan_error_sn[4:0]        <= 0; // clear error upon reset
      chan_error_rc[4:0]        <= 0; // clear error upon reset
      daq_valid                 <= 0;
      update_mcs_lsb            <= 0;
      master_checksum[127:0]    <= 0;
      channel_checksum[127:0]   <= 0;
      //burst_data[127:0]         <= 0;
      empty_event               <= 0;
      empty_payload             <= 0;
      cs_mismatch_count[31:0]   <= 0; // clear soft error count upon reset
      burst_count_selftrig[22:0]<= 23'd100;   // default is 100
      ipbus_chan_cmd[31:0]      <= 0;
      ipbus_chan_reg[31:0]      <= 0;
      pulse_data_size[22:0]     <= 23'd0;
      //pulse_trig_num[23:0]      <= 23'd0;
      //trig_type_latch[4:0]      <=  5'd0;
      //cs_error_seen[1:0]        <= 2'd0;
      //wfm_cnt_shrt              <= 11'd0;
      stored_burst_count[22:0]  <= 0;
      flush_action              <= FLUSH_NEXT;
      reply_retries             <= 2'd0;
      reissue_retries           <= 2'd0;
      trig_num_errors           <= 8'd0;
      err_loss_pulse            <= 16'd0;
      err_fault_pulse           <= 8'd0;
      err_warn_pulse            <= 6'd0;
      skipped_mask              <= 5'd0;
      chan_flags                <= 2'd0;
      peeking                   <= 1'b0;
      peeked_trigs              <= 20'd0;
      peeked_chans              <= 3'd0;
      peek_discard_mask         <= 5'd0;
      peek_word                 <= 1'b0;
      hdr_peek_strobe           <= 1'b0;
      hdr_read_strobe           <= 1'b0;
      hdr_chan                  <= 3'd0;
      hdr_wfms                  <= 23'd0;
      chan_err_word             <= 7'd0;
      chan_err_valid            <= 1'b0;
      last_rsn_word             <= 32'd0;
      last_rc_word              <= 32'd0;
      last_info1_word           <= 32'd0;
      last_info4_word           <= 32'd0;
      //updown                    <= 0;
//      delta_trigger[21:0]       <= 22'd0;
//      trigger_ticks[21:0]       <= 22'd0;
      
//      channel_header_last[31:0]   <= 32'd0;
//      channel_header_latch[31:0]  <= 32'd0;
      
    end
    else begin
      state <= nextstate;

      stored_burst_count[22:0]    <= next_stored_burst_count[22:0];
      flush_action                <= next_flush_action;
      reply_retries               <= next_reply_retries;
      reissue_retries             <= next_reissue_retries;
      err_loss_pulse              <= next_err_loss_pulse;
      err_fault_pulse             <= next_err_fault_pulse;
      err_warn_pulse              <= next_err_warn_pulse;
      skipped_mask                <= next_skipped_mask;
      chan_flags                  <= next_chan_flags;
      peeking                     <= next_peeking;
      peeked_trigs                <= next_peeked_trigs;
      peeked_chans                <= next_peeked_chans;
      peek_discard_mask           <= next_peek_discard_mask;
      peek_word                   <= next_peek_word;
      // every header accepted (fill type right), for the status counts and the overflow warning
      hdr_peek_strobe             <= state[READ_CHAN_INFO4] && chan_rx_fifo_valid &&  peeking && nextstate[CHECK_CHAN_EN];
      hdr_read_strobe             <= state[READ_CHAN_INFO4] && chan_rx_fifo_valid && !peeking && nextstate[READY_AMC13_HEADER1];
      hdr_chan                    <= chan_tx_fifo_dest[2:0];
      hdr_wfms                    <= {chan_rx_fifo_data[2:0], wfm_count[19:0]};
      // the waveform count each channel's header carried at the peek, for the check at the read
      if (peeking && state[READ_CHAN_INFO4] && chan_rx_fifo_valid && chan_tx_fifo_dest < 4'd5)
        peeked_count[chan_tx_fifo_dest] <= {chan_rx_fifo_data[2:0], wfm_count[19:0]};
      // the words a channel answered with, kept for the error snapshot and the channel header word
      if (state[READ_CHAN_RSN]   && chan_rx_fifo_valid) last_rsn_word   <= chan_rx_fifo_data;
      if (state[READ_CHAN_RC]    && chan_rx_fifo_valid) last_rc_word    <= chan_rx_fifo_data;
      if (state[READ_CHAN_INFO1] && chan_rx_fifo_valid) last_info1_word <= chan_rx_fifo_data;
      if (state[READ_CHAN_INFO4] && chan_rx_fifo_valid) last_info4_word <= chan_rx_fifo_data;
      chan_err_valid <= !peeking && state[READ_CHAN_INFO4] && chan_rx_fifo_valid && (chan_rx_fifo_data[13:7] != 7'd0);
      if (!peeking && state[READ_CHAN_INFO4] && chan_rx_fifo_valid) chan_err_word <= chan_rx_fifo_data[13:7];
      if (nextstate[ERROR_TRIG_NUM] && !state[ERROR_TRIG_NUM]) trig_num_errors <= trig_num_errors + 8'd1;
      chan_tag[11:0]              <= next_chan_tag[11:0];
      //chan_xadc_alarms[3:0]       <= next_chan_xadc_alarms[3:0];
      wfm_count[22:0]             <= next_wfm_count[22:0];
      chan_tx_fifo_dest[3:0]      <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last           <= next_chan_tx_fifo_last;
      csn[31:0]                   <= next_csn[31:0];
      daq_data[63:0]              <= next_daq_data[63:0];
      data_count[31:0]            <= next_data_count[31:0];
      data_wfm_count[22:0]        <= next_data_wfm_count[22:0];
      ipbus_buf[31:0]             <= next_ipbus_buf[31:0];
      ipbus_res_last              <= next_ipbus_res_last;
      //num_chan_en[2:0]            <= next_num_chan_en[2:0];
      sent_amc13_header           <= next_sent_amc13_header;
      //chan_trig_num[23:0]         <= next_chan_trig_num[23:0];   
      readout_timestamp[31:0]     <= next_readout_timestamp[31:0];
      chan_error_sn[4:0]          <= next_chan_error_sn[4:0];
      chan_error_rc[4:0]          <= next_chan_error_rc[4:0];
      daq_valid                   <= next_daq_valid;
      update_mcs_lsb              <= next_update_mcs_lsb;
      master_checksum[127:0]      <= next_master_checksum[127:0];
      channel_checksum[127:0]     <= next_channel_checksum[127:0];
      //burst_data[127:0]           <= next_burst_data[127:0];
      empty_event                 <= next_empty_event;
      empty_payload               <= next_empty_payload;
      cs_mismatch_count[31:0]     <= next_cs_mismatch_count[31:0];
      //cs_error_seen[1:0]          <= next_cs_mismatch_count[1:0];
      //wfm_cnt_shrt[10:0]          <= next_wfm_count[10:0];
      //data_count_shrt[3:0]        <= next_data_count[3:0];
      //updown                      <= next_updown;
      
//      delta_trigger[21:0]       <= next_delta_trigger[21:0];
//      trigger_ticks[21:0]       <= next_trigger_ticks[21:0];
//
      
      burst_count_selftrig[22:0]  <= next_burst_count_selftrig[22:0];
      ipbus_chan_cmd[31:0]        <= next_ipbus_chan_cmd[31:0];
      ipbus_chan_reg[31:0]        <= next_ipbus_chan_reg[31:0];
      pulse_data_size[22:0]       <= next_pulse_data_size[22:0];
      //pulse_trig_num[23:0]        <= next_pulse_trig_num[23:0];
      //pulse_trig_length[1:0]      <= next_pulse_trig_length[1:0];
      pretrigger_count[15:0]      <= next_pretrigger_count[15:0];
      //trig_type_latch[4:0]        <= next_trig_type_latch[4:0];
    end
  end


  // datapath sequential always block
  always @(posedge clk) begin
    if (rst) begin
      // reset values
      chan_rx_fifo_ready     <= 0;
      chan_tx_fifo_valid     <= 0;
      daq_header             <= 0;
      daq_trailer            <= 0;
      ipbus_cmd_ready        <= 0;
      ipbus_res_valid        <= 0;
      readout_done           <= 0;
      error_data_corrupt     <= 0;
      error_trig_num         <= 0;
      error_trig_type        <= 0;
      //inc_setup_time         <= 0;
      //zero_setup_time        <= 0;
    end
    else begin
      // default values
      chan_rx_fifo_ready     <= 0;
      chan_tx_fifo_valid     <= 0;
      daq_header             <= 0;
      daq_trailer            <= 0;
      ipbus_cmd_ready        <= 0;
      ipbus_res_valid        <= 0;
      readout_done           <= 0;
      error_data_corrupt     <= 0;
      // error_trig_num / error_trig_type are sticky (6.6.9): the states that set them are no
      // longer terminal, so a one-clock pulse would never be seen in the status register.
      // Cleared by reset only.
      //inc_setup_time         <= 0;
      //zero_setup_time        <= 0;

      case (1'b1) // synopsys parallel_case full_case
        //nextstate[IDLE] : begin
        //  ;
        //end

        // ======================================
        // configuration manager next state logic
        // ======================================

        nextstate[SEND_IPBUS_CSN] : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_CMD] : begin
          ipbus_cmd_ready <= 1;
        end
        //nextstate[CHECK_LAST]     : begin
        //  ;
        //end
        nextstate[SEND_IPBUS_CMD] : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_RSN] : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[FLUSH_CHAN] : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_IPBUS_RES] : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[SEND_IPBUS_RES] : begin
          ipbus_res_valid <= 1;
        end

        // ==============================
        // event builder next state logic
        // ==============================

        //nextstate[CHECK_CHAN_EN]         : begin
        //  zero_setup_time <= 1;
        //end
        nextstate[SEND_CHAN_CSN]         : begin
          //inc_setup_time <= 1;
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_CHAN_CC]          : begin
          //inc_setup_time <= 1;
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_CHAN_RSN]         : begin
          //inc_setup_time <= 1;
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_RC]          : begin
          //inc_setup_time <= 1;
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_INFO1]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_INFO2]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_INFO3]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_INFO4]       : begin
          chan_rx_fifo_ready <= 1;
        end
        //nextstate[READY_AMC13_HEADER1]   : begin
        //  ;
        //end
        nextstate[SEND_AMC13_HEADER1]    : begin
          daq_header <= 1;
        end
        //nextstate[SEND_AMC13_HEADER2]    : begin
        //  ;
        //end
        //nextstate[SEND_WFD5_HEADER]      : begin
        //  ;
        //end
        //nextstate[SEND_CHAN_HEADER1]     : begin
        //  ;
        //end
        //nextstate[SEND_CHAN_HEADER2]     : begin
        //  ;
        //end
        nextstate[READ_CHAN_DATA1]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA2]       : begin
          chan_rx_fifo_ready <= 1;
        end
        //nextstate[READ_CHAN_DATA_RESYNC] : begin
        //  ;
        //end
        //nextstate[SEND_CHAN_TRAILER1]    : begin
        //  ;
        //end
        //nextstate[READY_AMC13_TRAILER]   : begin
        //  ;
        //end
        nextstate[SEND_AMC13_TRAILER]    : begin
          daq_trailer            <= 1;
          readout_done           <= 1;
        end

        // ======================
        // error next state logic
        // ======================

        nextstate[ERROR_DATA_CORRUPTION] : begin
          error_data_corrupt <= 1;
        end
        nextstate[ERROR_TRIG_NUM]        : begin
          error_trig_num <= 1;
        end
        nextstate[ERROR_TRIG_TYPE]       : begin
          error_trig_type <= 1;
        end
      endcase
    end
  end

  // outputs based on states
  assign readout_ready = (state[IDLE] == 1'b1);
  assign trig_num_error_count = trig_num_errors;

endmodule
