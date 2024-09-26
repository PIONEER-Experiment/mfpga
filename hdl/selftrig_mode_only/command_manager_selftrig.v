`include "constants.txt"

// Finite state machine for handling commands to Channel FPGA(s).
// 
// Two primary functions:
// 1. Handle configuration via IPbus
// 2. Handle ADC data readout to DAQ link
//
// Originally created using Fizzim

module command_manager_selftrig (
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
  input wire [19:0] selftriggers_chan0_lo, // # of triggers seen per channel in channel lower buffer
  input wire [19:0] selftriggers_chan1_lo, // # of triggers seen per channel in channel lower buffer
  input wire [19:0] selftriggers_chan2_lo, // # of triggers seen per channel in channel lower buffer
  input wire [19:0] selftriggers_chan3_lo, // # of triggers seen per channel in channel lower buffer
  input wire [19:0] selftriggers_chan4_lo, // # of triggers seen per channel in channel lower buffer
  input wire [19:0] selftriggers_chan0_hi, // # of triggers seen per channel in channel upper buffer
  input wire [19:0] selftriggers_chan1_hi, // # of triggers seen per channel in channel upper buffer
  input wire [19:0] selftriggers_chan2_hi, // # of triggers seen per channel in channel upper buffer
  input wire [19:0] selftriggers_chan3_hi, // # of triggers seen per channel in channel upper buffer
  input wire [19:0] selftriggers_chan4_hi, // # of triggers seen per channel in channel upper buffer
  input wire        ddr3_buffer,

  // burst count for channel self trigs -- common to all channels
  output reg [22:0] burst_count_selftrig,  // the burst count -- this is "type 4" in the rest of the firmware world

  // status connections
  input wire [47:0] i2c_mac_adr,        // this board's MAC address
  input wire [ 4:0] chan_en,            // enabled channels, one bit for each channel
  input wire endianness_sel,            // select bit for the endianness of ADC data
  input wire [31:0] thres_data_corrupt, // threshold for data corruption instances
//st  input wire async_mode,                // asynchronous mode flag
//st  input wire cbuf_mode,                 // circular buffer mode flag
(* mark_debug = "true" *) output reg [34:0] state,              // state of finite state machine

  // error connections
  output reg [31:0] cs_mismatch_count, // number of checksum mismatches
  output reg error_data_corrupt,       // data corruption error
  output reg error_trig_num,           // trigger number mismatch between channel and master
  output reg error_trig_type,          // trigger type mismatch between channel and master
  output reg [ 4:0] chan_error_sn,     // command serial number mismatch between channel and master
  output reg [ 4:0] chan_error_rc,     // master received an error response code, one bit for each channel

  // for debugging
  input wire rst_trigger_num
);

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
  parameter CHECK_CHAN_EN         =  8; // 0x 0_0000_0100
  parameter SEND_CHAN_CSN         =  9; // 0x 0_0000_0200
  parameter SEND_CHAN_CC          = 10; // 0x 0_0000_0400
  parameter READ_CHAN_RSN         = 11; // 0x 0_0000_0800
  parameter READ_CHAN_RC          = 12; // 0x 0_0000_1000
  parameter READ_CHAN_INFO1       = 13; // 0x 0_0000_2000
  parameter READ_CHAN_INFO2       = 14; // 0x 0_0000_4000
  parameter READ_CHAN_INFO3       = 15; // 0x 0_0000_8000
  parameter READ_CHAN_INFO4       = 16; // 0x 0_0001_0000
  parameter READY_AMC13_HEADER1   = 17; // 0x 0_0002_0000
  parameter SEND_AMC13_HEADER1    = 18; // 0x 0_0004_0000
  parameter SEND_AMC13_HEADER2    = 19; // 0x 0_0008_0000
  parameter SEND_WFD5_HEADER      = 20; // 0x 0_0010_0000
  parameter SEND_CHAN_HEADER1     = 21; // 0x 0_0020_0000
  parameter SEND_CHAN_HEADER2     = 22; // 0x 0_0040_0000
  parameter READ_CHAN_DATA1       = 23; // 0x 0_0080_0000
  parameter READ_CHAN_DATA2       = 24; // 0x 0_0100_0000
  parameter READ_CHAN_DATA_RESYNC = 25; // 0x 0_0200_0000
  parameter SEND_CHAN_TRAILER1    = 26; // 0x 0_0400_0000
  parameter READY_AMC13_TRAILER   = 27; // 0x 0_0800_0000
  parameter SEND_AMC13_TRAILER    = 28; // 0x 0_1000_0000
  // error state bits
  parameter ERROR_DATA_CORRUPTION = 29; // 0x 0_2000_0000
  parameter ERROR_TRIG_NUM        = 30; // 0x 0_4000_0000  000 0100 0000 0000 0000 0000 0000 0000 0000
  parameter ERROR_TRIG_TYPE       = 31; // 0x 0_8000_0000


  // channel header regs sorted the way they will be used: first chan_trig_num, then burst_count, ...
  reg [23:0] chan_trig_num;     // trigger number from channel header, starts at 1
  reg [22:0] wfm_count;         // number of waveform acquired
  reg [10:0] wfm_cnt_shrt;     // lower 11 bits of above
  reg [11:0] chan_tag;          // channel tag
  reg [ 3:0] chan_xadc_alarms;  // channel alarms from XADC
  reg [31:0] csn;               // channel serial number
  reg [31:0] data_count;        // # of 32-bit data words received from Aurora, per waveform
  reg [ 3:0] data_count_shrt;   // lowest 4 bits of above
  reg [22:0] data_wfm_count;    // # of waveforms received from Aurora
  reg [31:0] ipbus_buf;         // buffer for IPbus data
  reg [31:0] readout_timestamp; // channel data readout timestamp
  reg [ 2:0] num_chan_en;       // number of enabled channels
  reg sent_amc13_header;        // flag to indicate that the AMC13 header has been sent
  reg [13:0] stored_burst_count;// waveform burst count obtained from header

  // regs for channel checksum verification
  reg update_mcs_lsb;           // flag to update the 64 LSBs of the 128-bit master checksum (mcs)
  reg [127:0] master_checksum;  // checksum calculated in this module
  reg [127:0] channel_checksum; // checksum from received channel data

  // regs for asynchronous mode
  reg [22:0] pulse_data_size;   // burst count covering channel headers, waveform headers, waveforms, and checksums
  reg [43:0] pulse_timestamp;   // 44-bit pulse trigger timestamp
  reg [23:0] pulse_trig_num;    // pulse trigger number
  reg [ 1:0] pulse_trig_length; // length of pulse trigger (short or long)
  reg [15:0] pretrigger_count;  // pre-trigger count

  // other internal regs
  reg empty_event;                         // flag to indicate if this should be an empty event
  reg empty_payload;                       // flag to indicate whether to skip the channel payloads
  reg [31:0] ipbus_chan_cmd;               // buffer for issued channel command
  reg [31:0] ipbus_chan_reg;               // buffer for issued channel register
  reg [ 4:0] trig_type_latch;              // latched trigger type from TTC Trigger FIFO
  reg [1:0] cs_error_seen;

  // debugging
  wire [23:0] trig_num_from_channel;

  // for internal regs
  reg next_sent_amc13_header;
  reg next_update_mcs_lsb;
  reg next_empty_event;
  reg next_empty_payload;
  reg [ 34:0] nextstate;
  reg [ 22:0] next_wfm_count;
  reg [ 21:0] next_wfm_gap_length;
  reg [ 11:0] next_chan_tag;
  reg [  3:0] next_chan_xadc_alarms;
  reg [ 31:0] next_csn;
  reg [ 31:0] next_data_count;
  reg [ 22:0] next_data_wfm_count;
  reg [ 31:0] next_ipbus_buf;
  reg [ 23:0] next_chan_trig_num;
  reg [ 31:0] next_readout_timestamp;
  reg [  2:0] next_num_chan_en;
  reg [127:0] next_master_checksum;
  reg [127:0] next_channel_checksum;
  reg [ 31:0] next_cs_mismatch_count;
  reg [ 31:0] next_ipbus_chan_cmd;
  reg [ 31:0] next_ipbus_chan_reg;
  reg [ 22:0] next_pulse_data_size;
  reg [ 43:0] next_pulse_timestamp;
  reg [ 23:0] next_pulse_trig_num;
  reg [  1:0] next_pulse_trig_length;
  reg [127:0] next_s_readout_fifo_tdata;
  reg [ 15:0] next_pretrigger_count;
  reg [  4:0] next_trig_type_latch;
  reg [ 13:0] next_stored_burst_count;
  
  // for external regs
  reg next_chan_tx_fifo_last;
  reg next_ipbus_res_last;
  reg next_daq_valid;
  reg [63:0] next_daq_data;
  reg [ 4:0] next_chan_error_sn;
  reg [ 4:0] next_chan_error_rc;
  reg [ 3:0] next_chan_tx_fifo_dest;
  reg [22:0] next_burst_count_selftrig;

  wire [19:0] event_size_lo, event_size_hi, event_size;

  reg [21:0] delta_trigger, next_delta_trigger, trigger_ticks, next_trigger_ticks;
  ila_master selftriggers_dbg (
    .clk(clk),                // input wire clk
    .probe0(selftriggers_chan0_lo),          // input wire [19 : 0] probe_in0
    .probe1(selftriggers_chan0_hi),          // input wire [19 : 0] probe_in1
    .probe2(master_checksum),                // input wire [127: 0] probe_in2
    .probe3(channel_checksum),               // input wire [127: 0] probe_in3
    //.probe4(selftriggers_chan4_lo),          // input wire [19 : 0] probe_in4
    //.probe5(selftriggers_chan0_hi),          // input wire [19 : 0] probe_in5
    //.probe6(selftriggers_chan1_hi),          // input wire [19 : 0] probe_in6
    //.probe7(selftriggers_chan2_hi),          // input wire [19 : 0] probe_in7
    //.probe8(selftriggers_chan3_hi),          // input wire [19 : 0] probe_in8
    //.probe9(selftriggers_chan4_hi),          // input wire [19 : 0] probe_in9
    .probe4(event_size_lo),                 // input wire [19 : 0] probe_in10
    .probe5(event_size_hi),                 // input wire [19 : 0] probe_in11
    .probe6(event_size),                    // input wire [19 : 0] probe_in12
    .probe7(initiate_readout),              // input wire [ 0 : 0] probe_in13
    .probe8(ddr3_buffer),                   // input wire [ 0 : 0] probe_in14
    .probe9(trig_num_from_channel),         // input wire [23 : 0] probe_in15
    .probe10(event_num),                     // input wire [23 : 0] probe_in16
    .probe11(state),                         // input wire [34 : 0] probe_in17
    .probe12(delta_trigger),                 // input wire [21 : 0] probe_in18
    .probe13(channel_header_last),
    .probe14(channel_header_latch),
    .probe15(data_count[3:0]),
    .probe16(data_wfm_count[3:0]),
    .probe17(wfm_count[3:0]),
    .probe18(chan_rx_fifo_data[31:0]),
    .probe19(chan_rx_fifo_valid),
    .probe20(rst_trigger_num)
  );


// number of 64-bit words to be sent to AMC13, including AMC13 headers and trailer
  // asychronous or self-trigger readout trigger type
  assign event_size_lo = selftriggers_chan0_lo[19:0]+
                         selftriggers_chan1_lo[19:0]+
                         selftriggers_chan2_lo[19:0]+
                         selftriggers_chan3_lo[19:0]+
                         selftriggers_chan4_lo[19:0];
  assign event_size_hi = selftriggers_chan0_hi[19:0]+
                         selftriggers_chan1_hi[19:0]+
                         selftriggers_chan2_hi[19:0]+
                         selftriggers_chan3_hi[19:0]+
                         selftriggers_chan4_hi[19:0];

  // the number of 64 bit words used by the activated channel headers
  wire [4:0] channel_header_words;
  assign channel_header_words = 5*(chan_en[0]+chan_en[1]+chan_en[2]+chan_en[3]+chan_en[4]);

  // the number of 64 bit words words, including waveform header, per self-trigger
  wire [22:0] per_trigger_word_count;
  assign per_trigger_word_count = (burst_count_selftrig*2+2);

  // pipeline the two event sizes to help with timing.  The event_size not used until later in the readout,
  // so there is time for this delay to happen
  wire [19:0] event_size_lo_pipe;
  wire [19:0] event_size_hi_pipe;

  pipeline_2stage #(
    .WIDTH(20)
  ) evs_lo_pip_permanent (
    .clk(clk),
    .in( event_size_lo),
    .out(event_size_lo_pipe)
  );
  pipeline_2stage #(
    .WIDTH(20)
  ) evs_hi_pip_permanent (
    .clk(clk),
    .in( event_size_hi),
    .out(event_size_hi_pipe)
  );

  // the number of triggers, summed over channels, to be read out.  Inactive channels will contribute zero
  reg [19:0] event_triggers;
  always @(posedge clk) begin
     if ( rst ) begin
        event_triggers <= 19'd0;
     end
     else begin
        // we want the event size of the buffer being read, while ddr3_buffer indicates the buffer
        // being written
        event_triggers <= ddr3_buffer ? event_size_lo_pipe : event_size_hi_pipe;
     end
  end
  // the total number of 64 bit words for the TTC readout event, including headers and trailers
  assign event_size = per_trigger_word_count * event_triggers + channel_header_words + 4;


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
  
  // for debugging
  assign trig_num_from_channel[23:0] = chan_rx_fifo_data[23:0];
  reg [31:0] next_channel_header_last,  channel_header_last;
  reg [31:0] next_channel_header_latch, channel_header_latch;

  // comb always block
  always @* begin
    // internal regs
    nextstate = 35'd0;
    next_wfm_count[22:0]             = wfm_count[22:0];
//st    next_wfm_gap_length[21:0]        = wfm_gap_length[21:0];
    next_chan_tag[11:0]              = chan_tag[11:0];
    next_chan_xadc_alarms[3:0]       = chan_xadc_alarms[3:0];
    next_csn[31:0]                   = csn[31:0];
    next_data_count[31:0]            = data_count[31:0];
    next_data_wfm_count[22:0]        = data_wfm_count[22:0];
//st    next_ddr3_start_addr[25:0]       = ddr3_start_addr[25:0];
    next_ipbus_buf[31:0]             = ipbus_buf[31:0];
    next_chan_trig_num[23:0]         = chan_trig_num[23:0];
    next_readout_timestamp[31:0]     = readout_timestamp[31:0] + 1; // increment readout timestamp on each clock cycle
    next_num_chan_en[2:0]            = num_chan_en[2:0];
    next_sent_amc13_header           = sent_amc13_header;
    next_update_mcs_lsb              = update_mcs_lsb;
    next_master_checksum[127:0]      = master_checksum[127:0];
    next_channel_checksum[127:0]     = channel_checksum[127:0];
    next_empty_event                 = empty_event;
    next_empty_payload               = empty_payload;
    next_cs_mismatch_count[31:0]     = cs_mismatch_count[31:0];
    next_ipbus_chan_cmd[31:0]        = ipbus_chan_cmd[31:0];
    next_ipbus_chan_reg[31:0]        = ipbus_chan_reg[31:0];
    next_pulse_data_size[22:0]       = pulse_data_size[22:0];
    next_pulse_timestamp[43:0]       = pulse_timestamp[43:0];
    next_pulse_trig_num[23:0]        = pulse_trig_num[23:0];
    next_pulse_trig_length[1:0]      = pulse_trig_length[1:0];
    next_s_readout_fifo_tdata[127:0] = s_readout_fifo_tdata[127:0];
    next_pretrigger_count[15:0]      = pretrigger_count[15:0];
    next_trig_type_latch[4:0]        = trig_type_latch[4:0];
    next_stored_burst_count[13:0]    = stored_burst_count[13:0];
    next_delta_trigger[21:0]         = delta_trigger[21:0];
    next_trigger_ticks[21:0]         = trigger_ticks[21:0] + 1;
    next_channel_header_last[31:0]   = channel_header_last[31:0] ;
    next_channel_header_latch[31:0]  = channel_header_latch[31:0];

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
    
    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // watch for IPbus commands
        if (ipbus_cmd_valid) begin
          next_chan_tx_fifo_last = 0;
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
          nextstate[SEND_IPBUS_CSN] = 1'b1;
        end
        // watch for unread fill events
        else if (initiate_readout) begin
          next_empty_event = send_empty_event;
          next_empty_payload = skip_payload;
          next_chan_tx_fifo_dest[3:0] = 0;
          next_delta_trigger[21:0] = trigger_ticks[21:0];
          next_trigger_ticks[21:0] = 22'd0;

          if (send_empty_event) begin
            next_daq_valid = 1'b1;
            next_daq_data[63:0] = {8'h00, trig_num[23:0], trig_timestamp[43:32], 20'd4};
            next_trig_type_latch[4:0] = 5'b0; // reserve zero to indicate no buffered data read out
            nextstate[SEND_AMC13_HEADER1] = 1'b1;
          end
          else begin
            next_trig_type_latch[4:0] = trig_type[4:0];
            nextstate[CHECK_CHAN_EN] = 1'b1;
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
      // read response serial number from channel
      state[READ_IPBUS_RSN] : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
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
        else begin
          nextstate[SEND_IPBUS_RES] = 1'b1;
        end
      end

      // =========================
      // event builder state logic
      // =========================

      // check whether this channel number is enabled
      state[CHECK_CHAN_EN] : begin
        if (cs_mismatch_count > thres_data_corrupt) begin
          nextstate[ERROR_DATA_CORRUPTION] = 1'b1;
        end
        else if (chan_tx_fifo_dest[3:0] == 4'h5) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else if (chan_en[chan_tx_fifo_dest] == 1) begin
          next_num_chan_en[2:0] = num_chan_en[2:0] + 1;
          next_chan_tx_fifo_last = 0;
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
          next_chan_tx_fifo_last = 1;
          nextstate[SEND_CHAN_CC] = 1'b1;
        end
        else begin
          nextstate[SEND_CHAN_CSN] = 1'b1;
        end
      end
      // send 'read fill' command code to channel
      state[SEND_CHAN_CC] : begin
        chan_tx_fifo_data[31:0] = 32'h8;

        if (chan_tx_fifo_ready) begin
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
            // an error occured, update status register, and report error
            // ABORT THIS CHANNEL'S READOUT
            next_chan_error_sn[chan_tx_fifo_dest] = 1'b1;

            next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
            next_csn[31:0] = csn[31:0]+1;
            nextstate[CHECK_CHAN_EN] = 1'b1;
          end
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
          if (chan_rx_fifo_data[31:0] == 32'h8) begin
            // everything is good
            nextstate[READ_CHAN_INFO1] = 1'b1;
          end
          else begin
            // an error occured, update status register, and report error
            // ABORT THIS CHANNEL'S READOUT
            next_chan_error_rc[chan_tx_fifo_dest] = 1'b1;

            next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
            next_csn[31:0] = csn[31:0]+1;
            nextstate[CHECK_CHAN_EN] = 1'b1;
          end
        end
        else begin
          nextstate[READ_CHAN_RC] = 1'b1;
        end
      end
      // get trigger number from channel's header word #1 (in channel firmware, this is the 1st of 4 32 bit words from the full header)
      state[READ_CHAN_INFO1] : begin
        if (chan_rx_fifo_valid) begin
          next_channel_header_last[31:0]  = channel_header_latch[31:0];
          next_channel_header_latch[31:0] = chan_rx_fifo_data[31:0];
          
          // check that trigger number from channel header and trigger logic match
          if (event_num[23:0] != chan_rx_fifo_data[23:0]) begin
            // trigger numbers aren't synchronized; throw an error
            nextstate[ERROR_TRIG_NUM] = 1'b1;
          end
          // check that trigger type from channel header and trigger logic match -- this checks that it is not an async mode
          else if (trig_type[2] & (chan_rx_fifo_data[26] != 1'b0)) begin
            // trigger types aren't synchronized; throw an error
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          else begin
            next_pulse_data_size[22:0] = {18'd0, chan_rx_fifo_data[31:27]};

            next_chan_trig_num[23:0] = chan_rx_fifo_data[23:0];
            next_master_checksum[127:0] = {master_checksum[127:32], chan_rx_fifo_data[31:0]};
            nextstate[READ_CHAN_INFO2] = 1'b1;
          end
        end
        else begin
          nextstate[READ_CHAN_INFO1] = 1'b1;
        end
      end
      // get burst count from channel's header word #2 (in channel firmware, this is the 2nd of 4 32 bit words from the full header)
      state[READ_CHAN_INFO2] : begin
        if (chan_rx_fifo_valid) begin
          next_pulse_data_size[22:0]    = {chan_rx_fifo_data[17:0], pulse_data_size[4:0]};
          next_stored_burst_count[13:0] = chan_rx_fifo_data[31:18];

          next_master_checksum[127:0] = {master_checksum[127:64], chan_rx_fifo_data[31:0], master_checksum[31:0]};
          nextstate[READ_CHAN_INFO3] = 1'b1;
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
          nextstate[READ_CHAN_INFO4] = 1'b1;
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
            // trigger types aren't synchronized; throw an error
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          else begin
            next_chan_xadc_alarms[3:0]   = 4'h0;
            next_wfm_count[22:20]        = chan_rx_fifo_data[2:0];
            next_pretrigger_count[15:12] = chan_rx_fifo_data[6:3];

            next_chan_tag[11:0] = chan_rx_fifo_data[25:14];
            next_master_checksum[127:0] = {chan_rx_fifo_data[31:0], master_checksum[95:0]};
            nextstate[READY_AMC13_HEADER1] = 1'b1;
          end
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
            next_daq_data[63:0] = {2'b01, 4'h0, chan_tag[11:0], 7'd0, wfm_count[22:0], pretrigger_count[15:0]};

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
          next_daq_data[63:0] = {39'd0, 1'b1, `MAJOR_REV, `MINOR_REV, `PATCH_REV};
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
          next_daq_data[63:0] = {2'b01, 4'h0, chan_tag[11:0], 7'd0, wfm_count[22:0], pretrigger_count[15:0]};

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
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:26], 3'd0, chan_rx_fifo_data[25:0]};
          end
          // this is the waveform header [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
              // prepare the lower half of the 2nd 64 bit waveform header
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
          end
          // this is the channel checksum [31:0]
          else if ((data_count[31:0] == 0) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
          end
          // this is the channel checksum [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
          end
          // this is an ADC data word
          else begin
            // big-endian data format, can be switched in next state
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
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
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the channel checksum [63:32]
          else if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the channel checksum [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is an ADC data word
          else begin
            // send ADC data in desired endianness:
            //      big-endian when 'endianness_sel' is 0 (default)
            //   little-endian when 'endianness_sel' is 1
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
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the channel checksum [63:32]
          else if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the channel checksum [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is an ADC data word
          else begin
            // send ADC data in desired endianness:
            //      big-endian when 'endianness_sel' is 0 (default)
            //   little-endian when 'endianness_sel' is 1
            next_daq_data[63:0] = (~endianness_sel) ? {chan_rx_fifo_data[31:0], daq_data[31:0]} : {daq_data[7:0], daq_data[15:8], daq_data[23:16], daq_data[31:24], chan_rx_fifo_data[7:0], chan_rx_fifo_data[15:8], chan_rx_fifo_data[23:16], chan_rx_fifo_data[31:24]};
          end

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
        if (daq_ready) begin
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
          next_chan_trig_num[23:0] = 0;
          next_csn[31:0]           = csn[31:0] + 1;
          next_daq_data[63:0]      = 0;
          next_sent_amc13_header   = 0;
          next_num_chan_en[2:0]    = 0; // reset the number of enabled channels for each new trigger
          next_empty_event         = 0;
          next_empty_payload       = 0;

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
      // trigger number mismatch error detected
      state[ERROR_TRIG_NUM] : begin
        nextstate[ERROR_TRIG_NUM] = 1'b1; // hard error, stay here
      end
      // trigger type mismatch error detected
      state[ERROR_TRIG_TYPE] : begin
        nextstate[ERROR_TRIG_TYPE] = 1'b1; // hard error, stay here
      end
    endcase
  end


  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      // reset values
      state <= 35'd1 << IDLE;

      chan_tag[11:0]            <= 0;
      chan_xadc_alarms[3:0]     <= 0;
      wfm_count[22:0]           <= 0;
      chan_tx_fifo_dest[3:0]    <= 0;
      chan_tx_fifo_last         <= 0;
      csn[31:0]                 <= 0;
      daq_data[63:0]            <= 0;
      data_count[31:0]          <= 0;
      data_wfm_count[22:0]      <= 0;
      ipbus_buf[31:0]           <= 0;
      ipbus_res_last            <= 0;
      num_chan_en[2:0]          <= 0;
      sent_amc13_header         <= 0;
      chan_trig_num[23:0]       <= 0;
      readout_timestamp[31:0]   <= 0;
      chan_error_sn[4:0]        <= 0; // clear error upon reset
      chan_error_rc[4:0]        <= 0; // clear error upon reset
      daq_valid                 <= 0;
      update_mcs_lsb            <= 0;
      master_checksum[127:0]    <= 0;
      channel_checksum[127:0]   <= 0;
      empty_event               <= 0;
      empty_payload             <= 0;
      cs_mismatch_count[31:0]   <= 0; // clear soft error count upon reset
      burst_count_selftrig[22:0]<= 23'd100;   // default is 100
      ipbus_chan_cmd[31:0]      <= 0;
      ipbus_chan_reg[31:0]      <= 0;
      pulse_data_size[22:0]     <= 23'd0;
      pulse_trig_num[23:0]      <= 23'd0;
      trig_type_latch[4:0]      <=  5'd0;
      cs_error_seen[1:0]        <= 2'd0;
      wfm_cnt_shrt              <= 11'd0;
      stored_burst_count[13:0]  <= 0;
      delta_trigger[21:0]       <= 22'd0;
      trigger_ticks[21:0]       <= 22'd0;
      
      channel_header_last[31:0]   <= 32'd0;
      channel_header_latch[31:0]  <= 32'd0;
      
    end
    else begin
      state <= nextstate;

      stored_burst_count[13:0]    <= next_stored_burst_count[13:0];
      chan_tag[11:0]              <= next_chan_tag[11:0];
      chan_xadc_alarms[3:0]       <= next_chan_xadc_alarms[3:0];
      wfm_count[22:0]             <= next_wfm_count[22:0];
      chan_tx_fifo_dest[3:0]      <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last           <= next_chan_tx_fifo_last;
      csn[31:0]                   <= next_csn[31:0];
      daq_data[63:0]              <= next_daq_data[63:0];
      data_count[31:0]            <= next_data_count[31:0];
      data_wfm_count[22:0]        <= next_data_wfm_count[22:0];
      ipbus_buf[31:0]             <= next_ipbus_buf[31:0];
      ipbus_res_last              <= next_ipbus_res_last;
      num_chan_en[2:0]            <= next_num_chan_en[2:0];
      sent_amc13_header           <= next_sent_amc13_header;
      chan_trig_num[23:0]         <= next_chan_trig_num[23:0];   
      readout_timestamp[31:0]     <= next_readout_timestamp[31:0];
      chan_error_sn[4:0]          <= next_chan_error_sn[4:0];
      chan_error_rc[4:0]          <= next_chan_error_rc[4:0];
      daq_valid                   <= next_daq_valid;
      update_mcs_lsb              <= next_update_mcs_lsb;
      master_checksum[127:0]      <= next_master_checksum[127:0];
      channel_checksum[127:0]     <= next_channel_checksum[127:0];
      empty_event                 <= next_empty_event;
      empty_payload               <= next_empty_payload;
      cs_mismatch_count[31:0]     <= next_cs_mismatch_count[31:0];
      cs_error_seen[1:0]          <= next_cs_mismatch_count[1:0];
      wfm_cnt_shrt[10:0]          <= next_wfm_count[10:0];
      data_count_shrt[3:0]        <= next_data_count[3:0];
      channel_header_last[31:0]   <= next_channel_header_last[31:0] ;
      channel_header_latch[31:0]  <= next_channel_header_latch[31:0];

      
      delta_trigger[21:0]       <= next_delta_trigger[21:0];
      trigger_ticks[21:0]       <= next_trigger_ticks[21:0];

      
      burst_count_selftrig[22:0]  <= next_burst_count_selftrig[22:0];
      ipbus_chan_cmd[31:0]        <= next_ipbus_chan_cmd[31:0];
      ipbus_chan_reg[31:0]        <= next_ipbus_chan_reg[31:0];
      pulse_data_size[22:0]       <= next_pulse_data_size[22:0];
      pulse_trig_num[23:0]        <= next_pulse_trig_num[23:0];
      pulse_trig_length[1:0]      <= next_pulse_trig_length[1:0];
      pretrigger_count[15:0]      <= next_pretrigger_count[15:0];
      trig_type_latch[4:0]        <= next_trig_type_latch[4:0];
    end
  end


  // datapath sequential always block
  always @(posedge clk) begin
    if (rst) begin
      // reset values
      chan_rx_fifo_ready    <= 0;
      chan_tx_fifo_valid    <= 0;
      daq_header            <= 0;
      daq_trailer           <= 0;
      ipbus_cmd_ready       <= 0;
      ipbus_res_valid       <= 0;
      readout_done          <= 0;
      error_data_corrupt    <= 0;
      error_trig_num        <= 0;
      error_trig_type       <= 0;
    end
    else begin
      // default values
      chan_rx_fifo_ready    <= 0;
      chan_tx_fifo_valid    <= 0;
      daq_header            <= 0;
      daq_trailer           <= 0;
      ipbus_cmd_ready       <= 0;
      ipbus_res_valid       <= 0;
      readout_done          <= 0;
      error_data_corrupt    <= 0;
      error_trig_num        <= 0;
      error_trig_type       <= 0;

      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE] : begin
          ;
        end

        // ======================================
        // configuration manager next state logic
        // ======================================

        nextstate[SEND_IPBUS_CSN] : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_CMD] : begin
          ipbus_cmd_ready <= 1;
        end
        nextstate[CHECK_LAST]     : begin
          ;
        end
        nextstate[SEND_IPBUS_CMD] : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_RSN] : begin
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

        nextstate[CHECK_CHAN_EN]         : begin
          ;
        end
        nextstate[SEND_CHAN_CSN]         : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_CHAN_CC]          : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_CHAN_RSN]         : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_RC]          : begin
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
        nextstate[READY_AMC13_HEADER1]   : begin
          ;
        end
        nextstate[SEND_AMC13_HEADER1]    : begin
          daq_header <= 1;
        end
        nextstate[SEND_AMC13_HEADER2]    : begin
          ;
        end
        nextstate[SEND_WFD5_HEADER]      : begin
          ;
        end
        nextstate[SEND_CHAN_HEADER1]     : begin
          ;
        end
        nextstate[SEND_CHAN_HEADER2]     : begin
          ;
        end
        nextstate[READ_CHAN_DATA1]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA2]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA_RESYNC] : begin
          ;
        end
//st        nextstate[READ_PULSE_FIFO]       : begin
//st          pulse_fifo_tready <= 1;
//st        end
//st        nextstate[READ_READOUT_FIFO]     : begin
//st          m_readout_fifo_tready <= 1;
//st        end
//st        nextstate[STORE_PULSE_INFO]      : begin
//st          s_readout_fifo_tvalid <= 1;
//st        end
        nextstate[SEND_CHAN_TRAILER1]    : begin
          ;
        end
        nextstate[READY_AMC13_TRAILER]   : begin
          ;
        end
        nextstate[SEND_AMC13_TRAILER]    : begin
          daq_trailer  <= 1;
          readout_done <= 1;
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

endmodule
