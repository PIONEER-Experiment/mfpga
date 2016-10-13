// Finite state machine for handling commands to Channel FPGA(s).
// 
// Two primary functions:
// 1. Handle configuration via IPbus
// 2. Handle ADC data readout to DAQ link
//
// Originally created using Fizzim

module command_manager (
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
  input wire send_empty_event,      // request to send an empty event
  input wire initiate_readout,      // request for the channels to be read out
  input wire [23:0] event_num,      // channel's trigger number
  input wire [23:0] trig_num,       // global trigger number, starts at 1
  input wire [ 2:0] trig_type,      // trigger type
  input wire [43:0] trig_timestamp, // trigger timestamp, defined by when trigger is received by trigger receiver module
  input wire [ 2:0] curr_trig_type, // currently set trigger type
  output wire readout_ready,        // ready to readout data, i.e., when in idle state
  output reg  readout_done,         // finished readout flag
  output wire [22:0] readout_size,  // burst count of readout event

  // set burst count for each channel
  output wire [22:0] burst_count_chan0,
  output wire [22:0] burst_count_chan1,
  output wire [22:0] burst_count_chan2,
  output wire [22:0] burst_count_chan3,
  output wire [22:0] burst_count_chan4,

  // set waveform count for each channel
  output wire [11:0] wfm_count_chan0,
  output wire [11:0] wfm_count_chan1,
  output wire [11:0] wfm_count_chan2,
  output wire [11:0] wfm_count_chan3,
  output wire [11:0] wfm_count_chan4,

  // front panel trigger count acknowledged
  input wire [23:0] total_fp_triggers,

  // interface to pulse trigger FIFO (through trigger top)
  input wire pulse_fifo_tvalid,
  input wire [127:0] pulse_fifo_tdata,
  output reg pulse_fifo_tready,

  // status connections
  input wire [47:0] i2c_mac_adr,        // this board's MAC address
  input wire [ 4:0] chan_en,            // enabled channels, one bit for each channel
  input wire endianness_sel,            // select bit for the endianness of ADC data
  input wire [31:0] thres_data_corrupt, // threshold for data corruption instances
  input wire async_mode,                // asynchronous mode flag
  output reg [33:0] state,              // state of finite state machine

  // error connections
  output reg [31:0] cs_mismatch_count, // number of checksum mismatches
  output reg error_data_corrupt,       // data corruption error
  output reg error_trig_num,           // trigger number mismatch between channel and master
  output reg error_trig_type,          // trigger type mismatch between channel and master
  output reg [ 4:0] chan_error_rc      // master received an error response code, one bit for each channel
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
  parameter SEND_CHAN_HEADER1     = 20; // 0x 0_0010_0000
  parameter SEND_CHAN_HEADER2     = 21; // 0x 0_0020_0000
  parameter READ_CHAN_DATA1       = 22; // 0x 0_0040_0000
  parameter READ_CHAN_DATA2       = 23; // 0x 0_0080_0000
  parameter READ_CHAN_DATA_RESYNC = 24; // 0x 0_0100_0000
  parameter READ_PULSE_FIFO       = 25; // 0x 0_0200_0000
  parameter READ_READOUT_FIFO     = 26; // 0x 0_0400_0000
  parameter STORE_PULSE_INFO      = 27; // 0x 0_0800_0000
  parameter SEND_CHAN_TRAILER1    = 28; // 0x 0_1000_0000
  parameter READY_AMC13_TRAILER   = 29; // 0x 0_2000_0000
  parameter SEND_AMC13_TRAILER    = 30; // 0x 0_4000_0000
  // error state bits
  parameter ERROR_DATA_CORRUPTION = 31; // 0x 0_8000_0000
  parameter ERROR_TRIG_NUM        = 32; // 0x 1_0000_0000
  parameter ERROR_TRIG_TYPE       = 33; // 0x 2_0000_0000


  // channel header regs sorted the way they will be used: first chan_trig_num, then fill_type, ...
  reg [23:0] chan_trig_num;     // trigger number from channel header, starts at 1
  reg [ 2:0] fill_type;         // fill type: muon, laser, pedestal, ...
  reg [22:0] burst_count;       // burst count for data acquisition, 1 burst count = 8 ADC samples
  reg [25:0] ddr3_start_addr;   // DDR3 start address (3 LSBs always zero)
  reg [22:0] wfm_count;         // number of waveform acquired
  reg [21:0] wfm_gap_length;    // gap in unit of 2.5 ns between two consecutive waveforms
  reg [15:0] chan_tag;          // channel tag
  reg [31:0] chan_num_buf;      // channel number
  reg [31:0] csn;               // channel serial number
  reg [31:0] data_count;        // # of 32-bit data words received from Aurora, per waveform
  reg [22:0] data_wfm_count;    // # of waveforms received from Aurora
  reg [31:0] ipbus_buf;         // buffer for IPbus data
  reg [31:0] readout_timestamp; // channel data readout timestamp
  reg [ 2:0] num_chan_en;       // number of enabled channels
  reg sent_amc13_header;        // flag to indicate that the AMC13 header has been sent

  // regs for channel checksum verification
  reg update_mcs_lsb;           // flag to update the 64 LSBs of the 128-bit master checksum (mcs)
  reg [127:0] master_checksum;  // checksum calculated in this module
  reg [127:0] channel_checksum; // checksum from received channel data

  // regs for asynchronous mode
  reg [22:0] pulse_data_size;   // burst count covering channel headers, waveform headers, waveforms, and checksums
  reg [43:0] pulse_timestamp;   // 44-bit pulse trigger timestamp
  reg [23:0] pulse_trig_num;    // pulse trigger number
  reg [ 1:0] pulse_trig_length; // length of pulse trigger (short or long)
  reg [11:0] pretrigger_count;  // pre-trigger count

  // other internal regs
  reg empty_event;                         // flag to indicate if this should be an empty event
  reg [22:0] chan_burst_count_type1 [4:0]; // two-dimentional memory for the configured burst counts, trigger type 1
  reg [22:0] chan_burst_count_type2 [4:0]; // two-dimentional memory for the configured burst counts, trigger type 2
  reg [22:0] chan_burst_count_type3 [4:0]; // two-dimentional memory for the configured burst counts, trigger type 3
  reg [22:0] chan_burst_count_type7 [4:0]; // two-dimentional memory for the configured burst counts, trigger type 7
  reg [11:0] chan_wfm_count_type1   [4:0]; // two-dimentional memory for the configured waveform counts, trigger type 1
  reg [11:0] chan_wfm_count_type2   [4:0]; // two-dimentional memory for the configured waveform counts, trigger type 2
  reg [11:0] chan_wfm_count_type3   [4:0]; // two-dimentional memory for the configured waveform counts, trigger type 3
  reg [31:0] ipbus_chan_cmd;               // buffer for issued channel command
  reg [31:0] ipbus_chan_reg;               // buffer for issued channel register
  

  // for internal regs
  reg next_sent_amc13_header;
  reg next_update_mcs_lsb;
  reg next_empty_event;
  reg [ 33:0] nextstate;
  reg [ 22:0] next_burst_count;
  reg [ 31:0] next_chan_num_buf;
  reg [  2:0] next_fill_type;
  reg [ 22:0] next_wfm_count;
  reg [ 21:0] next_wfm_gap_length;
  reg [ 15:0] next_chan_tag;
  reg [ 31:0] next_csn;
  reg [ 31:0] next_data_count;
  reg [ 22:0] next_data_wfm_count;
  reg [ 25:0] next_ddr3_start_addr;
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
  reg [ 11:0] next_pretrigger_count;

  // for external regs
  reg next_chan_tx_fifo_last;
  reg next_ipbus_res_last;
  reg next_daq_valid;
  reg [63:0] next_daq_data;
  reg [ 4:0] next_chan_error_rc;
  reg [ 3:0] next_chan_tx_fifo_dest;
  reg [22:0] next_chan_burst_count_type1 [4:0];
  reg [22:0] next_chan_burst_count_type2 [4:0];
  reg [22:0] next_chan_burst_count_type3 [4:0];
  reg [22:0] next_chan_burst_count_type7 [4:0];
  reg [11:0] next_chan_wfm_count_type1   [4:0];
  reg [11:0] next_chan_wfm_count_type2   [4:0];
  reg [11:0] next_chan_wfm_count_type3   [4:0];


  // number of 64-bit words to be sent to AMC13, including AMC13 headers and trailer
  wire [19:0] event_size_type1, event_size_type2, event_size_type3, event_size_type7;

  // muon fill trigger type
  assign event_size_type1 = ((chan_burst_count_type1[0]*2+2)*chan_wfm_count_type1[0]+5)*chan_en[0]+ 
                            ((chan_burst_count_type1[1]*2+2)*chan_wfm_count_type1[1]+5)*chan_en[1]+ 
                            ((chan_burst_count_type1[2]*2+2)*chan_wfm_count_type1[2]+5)*chan_en[2]+ 
                            ((chan_burst_count_type1[3]*2+2)*chan_wfm_count_type1[3]+5)*chan_en[3]+ 
                            ((chan_burst_count_type1[4]*2+2)*chan_wfm_count_type1[4]+5)*chan_en[4]+3;

  // laser run trigger type
  assign event_size_type2 = ((chan_burst_count_type2[0]*2+2)*chan_wfm_count_type2[0]+5)*chan_en[0]+ 
                            ((chan_burst_count_type2[1]*2+2)*chan_wfm_count_type2[1]+5)*chan_en[1]+ 
                            ((chan_burst_count_type2[2]*2+2)*chan_wfm_count_type2[2]+5)*chan_en[2]+ 
                            ((chan_burst_count_type2[3]*2+2)*chan_wfm_count_type2[3]+5)*chan_en[3]+ 
                            ((chan_burst_count_type2[4]*2+2)*chan_wfm_count_type2[4]+5)*chan_en[4]+3;

  // pedestal run trigger type
  assign event_size_type3 = ((chan_burst_count_type3[0]*2+2)*chan_wfm_count_type3[0]+5)*chan_en[0]+ 
                            ((chan_burst_count_type3[1]*2+2)*chan_wfm_count_type3[1]+5)*chan_en[1]+ 
                            ((chan_burst_count_type3[2]*2+2)*chan_wfm_count_type3[2]+5)*chan_en[2]+ 
                            ((chan_burst_count_type3[3]*2+2)*chan_wfm_count_type3[3]+5)*chan_en[3]+ 
                            ((chan_burst_count_type3[4]*2+2)*chan_wfm_count_type3[4]+5)*chan_en[4]+3;

  // asychronous readout trigger type
  assign event_size_type7 = ((chan_burst_count_type7[0]*2+2)*total_fp_triggers[23:0]+5)*chan_en[0]+ 
                            ((chan_burst_count_type7[1]*2+2)*total_fp_triggers[23:0]+5)*chan_en[1]+ 
                            ((chan_burst_count_type7[2]*2+2)*total_fp_triggers[23:0]+5)*chan_en[2]+ 
                            ((chan_burst_count_type7[3]*2+2)*total_fp_triggers[23:0]+5)*chan_en[3]+ 
                            ((chan_burst_count_type7[4]*2+2)*total_fp_triggers[23:0]+5)*chan_en[4]+3;

  // mux the correct event size for this trigger type
  wire [19:0] event_size;
  assign event_size = (fill_type[2:0] == 3'b001) ? event_size_type1[19:0] :
                      (fill_type[2:0] == 3'b010) ? event_size_type2[19:0] :
                      (fill_type[2:0] == 3'b011) ? event_size_type3[19:0] : 
                      (fill_type[2:0] == 3'b111) ? event_size_type7[19:0] :
                                                   20'hfffff;

  // number of 128-bit bursts read out of DDR3
  assign readout_size = (burst_count[19:0]+1)*wfm_count[11:0]+2;

  // this board's serial number
  wire [12:0] board_id;
  assign board_id = (i2c_mac_adr[15:8]-1)*256+i2c_mac_adr[7:0];


  // determine burst counts for the trigger logic
  assign burst_count_chan0 = (async_mode)                    ? chan_burst_count_type7[0] :
                             (curr_trig_type[2:0] == 3'b001) ? chan_burst_count_type1[0] :
                             (curr_trig_type[2:0] == 3'b010) ? chan_burst_count_type2[0] :
                             (curr_trig_type[2:0] == 3'b011) ? chan_burst_count_type3[0] :
                                                               23'd0;
  assign burst_count_chan1 = (async_mode)                    ? chan_burst_count_type7[1] :
                             (curr_trig_type[2:0] == 3'b001) ? chan_burst_count_type1[1] :
                             (curr_trig_type[2:0] == 3'b010) ? chan_burst_count_type2[1] :
                             (curr_trig_type[2:0] == 3'b011) ? chan_burst_count_type3[1] :
                                                               23'd0;
  assign burst_count_chan2 = (async_mode)                    ? chan_burst_count_type7[2] :
                             (curr_trig_type[2:0] == 3'b001) ? chan_burst_count_type1[2] :
                             (curr_trig_type[2:0] == 3'b010) ? chan_burst_count_type2[2] :
                             (curr_trig_type[2:0] == 3'b011) ? chan_burst_count_type3[2] :
                                                               23'd0;
  assign burst_count_chan3 = (async_mode)                    ? chan_burst_count_type7[3] :
                             (curr_trig_type[2:0] == 3'b001) ? chan_burst_count_type1[3] :
                             (curr_trig_type[2:0] == 3'b010) ? chan_burst_count_type2[3] :
                             (curr_trig_type[2:0] == 3'b011) ? chan_burst_count_type3[3] :
                                                               23'd0;
  assign burst_count_chan4 = (async_mode)                    ? chan_burst_count_type7[4] :
                             (curr_trig_type[2:0] == 3'b001) ? chan_burst_count_type1[4] :
                             (curr_trig_type[2:0] == 3'b010) ? chan_burst_count_type2[4] :
                             (curr_trig_type[2:0] == 3'b011) ? chan_burst_count_type3[4] :
                                                               23'd0;

  // determine waveform counts for the trigger logic
  assign wfm_count_chan0 = (curr_trig_type[2:0] == 3'b001) ? chan_wfm_count_type1[0] :
                           (curr_trig_type[2:0] == 3'b010) ? chan_wfm_count_type2[0] :
                           (curr_trig_type[2:0] == 3'b011) ? chan_wfm_count_type3[0] :
                                                             12'd0;
  assign wfm_count_chan1 = (curr_trig_type[2:0] == 3'b001) ? chan_wfm_count_type1[1] :
                           (curr_trig_type[2:0] == 3'b010) ? chan_wfm_count_type2[1] :
                           (curr_trig_type[2:0] == 3'b011) ? chan_wfm_count_type3[1] :
                                                             12'd0;
  assign wfm_count_chan2 = (curr_trig_type[2:0] == 3'b001) ? chan_wfm_count_type1[2] :
                           (curr_trig_type[2:0] == 3'b010) ? chan_wfm_count_type2[2] :
                           (curr_trig_type[2:0] == 3'b011) ? chan_wfm_count_type3[2] :
                                                             12'd0;
  assign wfm_count_chan3 = (curr_trig_type[2:0] == 3'b001) ? chan_wfm_count_type1[3] :
                           (curr_trig_type[2:0] == 3'b010) ? chan_wfm_count_type2[3] :
                           (curr_trig_type[2:0] == 3'b011) ? chan_wfm_count_type3[3] :
                                                             12'd0;
  assign wfm_count_chan4 = (curr_trig_type[2:0] == 3'b001) ? chan_wfm_count_type1[4] :
                           (curr_trig_type[2:0] == 3'b010) ? chan_wfm_count_type2[4] :
                           (curr_trig_type[2:0] == 3'b011) ? chan_wfm_count_type3[4] :
                                                             12'd0;


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

  // Pulse Readout FIFO : 2048 depth, 1024 almost full threshold, 16-byte data width
  // holds a running copy of the pulse trigger information for multi-channel readout
  pulse_readout_fifo pulse_readout_fifo (
      // writing side
      .s_aclk(clk),                          // input
      .s_aresetn(rst_n),                     // input
      .s_axis_tvalid(s_readout_fifo_tvalid), // input
      .s_axis_tready(s_readout_fifo_tready), // output
      .s_axis_tdata(s_readout_fifo_tdata),   // input  [127:0]

      // reading side
      .m_axis_tvalid(m_readout_fifo_tvalid), // output
      .m_axis_tready(m_readout_fifo_tready), // input
      .m_axis_tdata(m_readout_fifo_tdata),   // output [127:0]
    
      // FIFO almost full port
      .axis_prog_full(readout_fifo_full)     // output
  );


  // comb always block
  always @* begin
    // internal regs
    nextstate = 34'd0;
    next_burst_count[22:0]           = burst_count[22:0];
    next_chan_num_buf[31:0]          = chan_num_buf[31:0];
    next_fill_type[2:0]              = fill_type[2:0];
    next_wfm_count[22:0]             = wfm_count[22:0];
    next_wfm_gap_length[21:0]        = wfm_gap_length[21:0];
    next_chan_tag[15:0]              = chan_tag[15:0];
    next_csn[31:0]                   = csn[31:0];
    next_data_count[31:0]            = data_count[31:0];
    next_data_wfm_count[22:0]        = data_wfm_count[22:0];
    next_ddr3_start_addr[25:0]       = ddr3_start_addr[25:0];
    next_ipbus_buf[31:0]             = ipbus_buf[31:0];
    next_chan_trig_num[23:0]         = chan_trig_num[23:0];
    next_readout_timestamp[31:0]     = readout_timestamp[31:0] + 1; // increment readout timestamp on each clock cycle
    next_num_chan_en[2:0]            = num_chan_en[2:0];
    next_sent_amc13_header           = sent_amc13_header;
    next_update_mcs_lsb              = update_mcs_lsb;
    next_master_checksum[127:0]      = master_checksum[127:0];
    next_channel_checksum[127:0]     = channel_checksum[127:0];
    next_empty_event                 = empty_event;
    next_cs_mismatch_count[31:0]     = cs_mismatch_count[31:0];
    next_ipbus_chan_cmd[31:0]        = ipbus_chan_cmd[31:0];
    next_ipbus_chan_reg[31:0]        = ipbus_chan_reg[31:0];
    next_pulse_data_size[22:0]       = pulse_data_size[22:0];
    next_pulse_timestamp[43:0]       = pulse_timestamp[43:0];
    next_pulse_trig_num[23:0]        = pulse_trig_num[23:0];
    next_pulse_trig_length[1:0]      = pulse_trig_length[1:0];
    next_s_readout_fifo_tdata[127:0] = s_readout_fifo_tdata[127:0];
    next_pretrigger_count[11:0]      = pretrigger_count[11:0];

    // external regs
    next_daq_data[63:0]            = daq_data[63:0];
    next_chan_error_rc[4:0]        = chan_error_rc[4:0];
    next_chan_tx_fifo_dest[3:0]    = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last         = chan_tx_fifo_last;
    next_ipbus_res_last            = ipbus_res_last;
    next_chan_burst_count_type1[0] = chan_burst_count_type1[0];
    next_chan_burst_count_type1[1] = chan_burst_count_type1[1];
    next_chan_burst_count_type1[2] = chan_burst_count_type1[2];
    next_chan_burst_count_type1[3] = chan_burst_count_type1[3];
    next_chan_burst_count_type1[4] = chan_burst_count_type1[4];
    next_chan_burst_count_type2[0] = chan_burst_count_type2[0];
    next_chan_burst_count_type2[1] = chan_burst_count_type2[1];
    next_chan_burst_count_type2[2] = chan_burst_count_type2[2];
    next_chan_burst_count_type2[3] = chan_burst_count_type2[3];
    next_chan_burst_count_type2[4] = chan_burst_count_type2[4];
    next_chan_burst_count_type3[0] = chan_burst_count_type3[0];
    next_chan_burst_count_type3[1] = chan_burst_count_type3[1];
    next_chan_burst_count_type3[2] = chan_burst_count_type3[2];
    next_chan_burst_count_type3[3] = chan_burst_count_type3[3];
    next_chan_burst_count_type3[4] = chan_burst_count_type3[4];
    next_chan_burst_count_type7[0] = chan_burst_count_type7[0];
    next_chan_burst_count_type7[1] = chan_burst_count_type7[1];
    next_chan_burst_count_type7[2] = chan_burst_count_type7[2];
    next_chan_burst_count_type7[3] = chan_burst_count_type7[3];
    next_chan_burst_count_type7[4] = chan_burst_count_type7[4];
    next_chan_wfm_count_type1[0]   = chan_wfm_count_type1[0];
    next_chan_wfm_count_type1[1]   = chan_wfm_count_type1[1];
    next_chan_wfm_count_type1[2]   = chan_wfm_count_type1[2];
    next_chan_wfm_count_type1[3]   = chan_wfm_count_type1[3];
    next_chan_wfm_count_type1[4]   = chan_wfm_count_type1[4];
    next_chan_wfm_count_type2[0]   = chan_wfm_count_type2[0];
    next_chan_wfm_count_type2[1]   = chan_wfm_count_type2[1];
    next_chan_wfm_count_type2[2]   = chan_wfm_count_type2[2];
    next_chan_wfm_count_type2[3]   = chan_wfm_count_type2[3];
    next_chan_wfm_count_type2[4]   = chan_wfm_count_type2[4];
    next_chan_wfm_count_type3[0]   = chan_wfm_count_type3[0];
    next_chan_wfm_count_type3[1]   = chan_wfm_count_type3[1];
    next_chan_wfm_count_type3[2]   = chan_wfm_count_type3[2];
    next_chan_wfm_count_type3[3]   = chan_wfm_count_type3[3];
    next_chan_wfm_count_type3[4]   = chan_wfm_count_type3[4];

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
          next_chan_tx_fifo_dest[3:0] = 0;

          if (send_empty_event) begin
            next_daq_valid = 1'b1;
            next_daq_data[63:0] = {8'h00, trig_num[23:0], trig_timestamp[43:32], 20'd3};
            nextstate[SEND_AMC13_HEADER1] = 1'b1;
          end
          else begin
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
          if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0002)) begin
            next_chan_burst_count_type1[chan_tx_fifo_dest] = ipbus_cmd_data[22:0]; // burst count value, muon fill
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0003)) begin
            next_chan_burst_count_type2[chan_tx_fifo_dest] = ipbus_cmd_data[22:0]; // burst count value, laser fill
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0004)) begin
            next_chan_burst_count_type3[chan_tx_fifo_dest] = ipbus_cmd_data[22:0]; // burst count value, pedestal fill
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0014)) begin
            next_chan_burst_count_type7[chan_tx_fifo_dest] = ipbus_cmd_data[11:0]; // burst count value, asynchronous acquisition
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_000e)) begin
            next_chan_wfm_count_type1[chan_tx_fifo_dest] = ipbus_cmd_data[11:0];   // waveform count value, muon fill
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0010)) begin
            next_chan_wfm_count_type2[chan_tx_fifo_dest] = ipbus_cmd_data[11:0];   // waveform count value, laser fill
          end
          else if ((ipbus_chan_cmd[31:0] == 32'h0000_0003) & (ipbus_chan_reg[31:0] == 32'h0000_0012)) begin
            next_chan_wfm_count_type3[chan_tx_fifo_dest] = ipbus_cmd_data[11:0];   // waveform count value, pedestal fill
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
        else if (chan_en[chan_tx_fifo_dest] == 1) begin
          next_num_chan_en[2:0] = num_chan_en[2:0] + 1;
          next_chan_tx_fifo_last = 0;
          nextstate[SEND_CHAN_CSN] = 1'b1;
        end
        else if (chan_tx_fifo_dest[3:0] == 4'h5) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
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
          nextstate[READ_CHAN_RC] = 1'b1;
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
            // an error occured, update status register, and report error to front panel LED
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
      // get trigger number from channel's header word #1
      state[READ_CHAN_INFO1] : begin
        if (chan_rx_fifo_valid) begin
          // check that trigger number from channel header and trigger logic match
          if (event_num[23:0] != chan_rx_fifo_data[23:0]) begin
            // trigger numbers aren't synchronized; throw an error
            nextstate[ERROR_TRIG_NUM] = 1'b1;
          end
          // check that sync/async mode types match
          else if (trig_type[2] != chan_rx_fifo_data[26]) begin
            // sync/async mode types aren't synchronized; throw an error
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          // in synchronous mode, check that trigger type from channel header and trigger logic match
          else if (~chan_rx_fifo_data[26] & (trig_type[1:0] != chan_rx_fifo_data[25:24])) begin
            // trigger types aren't synchronized; throw an error
            nextstate[ERROR_TRIG_TYPE] = 1'b1;
          end
          else begin
            next_chan_trig_num[23:0] = chan_rx_fifo_data[23: 0];
            next_fill_type[2:0]      = chan_rx_fifo_data[26:24];

            // synchronous mode
            if (~chan_rx_fifo_data[26]) begin
              next_burst_count[22:0] = {18'd0, chan_rx_fifo_data[31:27]};
            end
            // asynchronous mode
            else begin
              next_burst_count[22:0]     = 23'd0;
              next_pulse_data_size[22:0] = {18'd0, chan_rx_fifo_data[31:27]};
            end

            next_master_checksum[127:0] = {master_checksum[127:32], chan_rx_fifo_data[31:0]};
            nextstate[READ_CHAN_INFO2] = 1'b1;
          end
        end
        else begin
          nextstate[READ_CHAN_INFO1] = 1'b1;
        end
      end
      // get burst count from channel's header word #2
      state[READ_CHAN_INFO2] : begin
        if (chan_rx_fifo_valid) begin
          // synchronous mode
          if (~fill_type[2]) begin
            next_burst_count[22:0] = {chan_rx_fifo_data[17:0], burst_count[4:0]};
          end
          // asynchronous mode
          else begin
            next_burst_count[22:0]     = 23'd0;
            next_pulse_data_size[22:0] = {chan_rx_fifo_data[17:0], pulse_data_size[4:0]};
          end

          next_ddr3_start_addr[13:0]  = chan_rx_fifo_data[31:18];
          next_master_checksum[127:0] = {master_checksum[127:64], chan_rx_fifo_data[31:0], master_checksum[31:0]};
          nextstate[READ_CHAN_INFO3] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO2] = 1'b1;
        end
      end
      // get DDR3 start address from channel's header word #3
      state[READ_CHAN_INFO3] : begin
        if (chan_rx_fifo_valid) begin
          next_ddr3_start_addr[25:14] = chan_rx_fifo_data[11:0];

          // synchronous mode
          if (~fill_type[2]) begin
            next_wfm_count[22:0]     = {11'd0, chan_rx_fifo_data[23:12]};
            next_wfm_gap_length[8:0] = chan_rx_fifo_data[31:24];
          end
          // asynchronous mode
          else begin
            next_wfm_count[19:0]     = chan_rx_fifo_data[31:12];
            next_wfm_gap_length[8:0] = 9'd0;
          end

          next_master_checksum[127:0] = {master_checksum[127:96], chan_rx_fifo_data[31:0], master_checksum[63:0]};
          nextstate[READ_CHAN_INFO4] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO3] = 1'b1;
        end
      end
      // get tag and fill type from channel's header word #4
      state[READ_CHAN_INFO4] : begin
        if (chan_rx_fifo_valid) begin
          // synchronous mode
          if (~fill_type[2]) begin
            next_wfm_gap_length[21:9] = chan_rx_fifo_data[13:0];
          end
          // asynchronous mode
          else begin
            next_wfm_gap_length[21:9] = 13'd0;
            next_wfm_count[22:20]     = chan_rx_fifo_data[2:0];
          end

          next_chan_tag[15:0] = chan_rx_fifo_data[29:14];
          next_master_checksum[127:0] = {chan_rx_fifo_data[31:0], master_checksum[95:0]};
          nextstate[READY_AMC13_HEADER1] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_INFO4] = 1'b1;
        end
      end
      // pause to store the channel's tag and fill type
      state[READY_AMC13_HEADER1] : begin
        if (!sent_amc13_header) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {8'd0, trig_num[23:0], trig_timestamp[43:32], event_size[19:0]};
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {2'b01, chan_tag[15:0], wfm_gap_length[21:0], wfm_count[11:0], ddr3_start_addr[25:14]};
          next_readout_timestamp[31:0] = 32'd0;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
        end
      end
      // send the first AMC13 header word
      state[SEND_AMC13_HEADER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {11'd0, endianness_sel, empty_event, fill_type[2:0], trig_timestamp[31:0], 3'd1, board_id[12:0]};
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
        if (empty_event) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else if (daq_ready) begin
          next_daq_valid = 1'b1;

          // synchronous mode
          if (~fill_type[2]) begin
            next_daq_data[63:0] = {2'b01, chan_tag[15:0], wfm_gap_length[21:0], wfm_count[11:0], ddr3_start_addr[25:14]};
          end
          // asynchronous mode
          else begin
            next_daq_data[63:0] = {2'b01, chan_tag[15:0], 22'd0, wfm_count[11:0], 12'd0};
          end

          next_sent_amc13_header = 1'b1;
          next_readout_timestamp[31:0] = 0;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
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
      // send the first channel header word
      state[SEND_CHAN_HEADER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;

          // synchronous mode
          if (~fill_type[2]) begin
            next_daq_data[63:0] = {ddr3_start_addr[13:0], (burst_count[22:0]<<3), fill_type[2:0], trig_num[23:0]};
          end
          // asynchronous mode
          else begin
            next_daq_data[63:0] = {ddr3_start_addr[13:0], (pulse_data_size[22:0]<<3), fill_type[2:0], trig_num[23:0]};
          end

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
            // synchronous mode
            if (~fill_type[2]) begin
              // convert waveform length from # bursts to # samples
              next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:23], (chan_rx_fifo_data[22:0]<<3)};
            end
            // asynchronous mode
            else begin
              // grab total burst and pre-trigger counts
              next_burst_count[22:0] = {12'd0, chan_rx_fifo_data[10:0]};
              next_pretrigger_count[11:0] = chan_rx_fifo_data[22:11];
              // convert pre- and post-trigger waveform length from # bursts to # samples
              next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:23], (chan_rx_fifo_data[22:11]<<1), (chan_rx_fifo_data[10:0]<<3)};
            end
          end
          // this is the waveform header [95:64]
          else if ((data_count[31:0] == 2) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // synchronous mode
            if (~fill_type[2]) begin
              // convert waveform gap from # ADC-clock ticks to # samples
              next_daq_data[63:0] = {31'h0000000, chan_rx_fifo_data[31:12], 1'b0, chan_rx_fifo_data[11:0]};
            end
            // asynchronous mode
            else begin
              next_daq_data[63:0] = {32'h00000000, pulse_timestamp[20:0], chan_rx_fifo_data[10:0]};
            end
          end
          // this is the channel checksum [31:0]
          else if ((data_count[31:0] == 1) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
            // keep channel checksum format as it is
            next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
          end
          // this is the channel checksum [95:64]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] == wfm_count[22:0])) begin
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

          if (fill_type[2] & (data_count[31:0] == 0) & (data_wfm_count[22:0] != wfm_count[22:0]) & (num_chan_en[2:0] == 3'h1)) begin
            // asynchronous trigger readout, start of waveform header, first channel
            nextstate[READ_PULSE_FIFO] = 1'b1;
          end
          else if (fill_type[2] & (data_count[31:0] == 0) & (data_wfm_count[22:0] != wfm_count[22:0]) & (num_chan_en[2:0] > 3'h1)) begin
            // asynchronous trigger readout, start of waveform header, subsequent channel
            nextstate[READ_READOUT_FIFO] = 1'b1;
          end
          else begin
            // synchronous trigger readout
            nextstate[READ_CHAN_DATA2] = 1'b1;
          end
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
            // keep waveform header format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // synchronous mode
            if (~fill_type[2]) begin
              // continue converting waveform gap from # ADC-clock ticks to # samples
              next_daq_data[63:0] = {chan_rx_fifo_data[31:1], daq_data[32:0]};
            end
            // asynchronous mode
            else begin
              next_daq_data[63:0] = {chan_rx_fifo_data[31:30], chan_rx_fifo_data[6:2], pulse_trig_length[1:0], pulse_timestamp[43:21], daq_data[31:0]};
            end
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

          next_data_count[31:0]     = (data_count[31:0] < burst_count[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
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
          next_daq_valid = 1'b1;

          // this is the channel checksum, use big-endian
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};

          next_data_count[31:0]     = (data_count[31:0] < burst_count[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
          next_channel_checksum[127:0] = {chan_rx_fifo_data[31:0], channel_checksum[95:0]};
          nextstate[SEND_CHAN_TRAILER1] = 1'b1;
        end
        // we've not received all the data
        // send current data, and continue the readout loop
        else if (daq_ready & chan_rx_fifo_valid) begin
          next_daq_valid = 1'b1;

          // this is the waveform header [63:32]
          if ((data_count[31:0] == 1) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // keep waveform header format as it is
            next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          // this is the waveform header [127:96]
          else if ((data_count[31:0] == 3) & (data_wfm_count[22:0] != wfm_count[22:0])) begin
            // synchronous mode
            if (~fill_type[2]) begin
              // continue converting waveform gap from # ADC-clock ticks to # samples
              next_daq_data[63:0] = {chan_rx_fifo_data[31:1], daq_data[32:0]};
            end
            // asynchronous mode
            else begin
              next_daq_data[63:0] = {chan_rx_fifo_data[31:30], chan_rx_fifo_data[6:2], pulse_trig_length[1:0], pulse_timestamp[43:21], daq_data[31:0]};
            end
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

          next_data_count[31:0]     = (data_count[31:0] < burst_count[22:0]*4+3) ? data_count[31:0]+1   : 32'b0;
          next_data_wfm_count[22:0] = (data_count[31:0] < burst_count[22:0]*4+3) ? data_wfm_count[22:0] : data_wfm_count[22:0]+1;
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
          next_daq_valid = 1'b1;
          nextstate[SEND_CHAN_TRAILER1] = 1'b1;
        end
        // we've not received all the data
        // send current data, and continue readout loop
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
        else begin
          // DAQ link buffer is still almost full
          nextstate[READ_CHAN_DATA_RESYNC] = 1'b1;
        end
      end
      // grab pulse information from Pulse Trigger FIFO
      state[READ_PULSE_FIFO] : begin
        if (pulse_fifo_tvalid) begin
          next_pulse_timestamp[43:0]  = pulse_fifo_tdata[43: 0];
          next_pulse_trig_num[23:0]   = pulse_fifo_tdata[67:44];
          next_pulse_trig_length[1:0] = pulse_fifo_tdata[69:68];

          if (num_chan_en[2:0] < (chan_en[0]+chan_en[1]+chan_en[2]+chan_en[3]+chan_en[4])) begin
            // store information for next channel readout
            next_s_readout_fifo_tdata[127:0] = pulse_fifo_tdata[127:0];
            nextstate[STORE_PULSE_INFO] = 1'b1;
          end
          else begin
            // this is the final channel to be read out
            nextstate[READ_CHAN_DATA2] = 1'b1;
          end
        end
        else begin
          nextstate[READ_PULSE_FIFO] = 1'b1;
        end
      end
      // grab pulse information from Pulse Redout FIFO
      state[READ_READOUT_FIFO] : begin
        if (m_readout_fifo_tvalid) begin
          next_pulse_timestamp[43:0]  = m_readout_fifo_tdata[43: 0];
          next_pulse_trig_num[23:0]   = m_readout_fifo_tdata[67:44];
          next_pulse_trig_length[1:0] = m_readout_fifo_tdata[69:68];
          
          if (num_chan_en[2:0] < (chan_en[0]+chan_en[1]+chan_en[2]+chan_en[3]+chan_en[4])) begin
            // store information for next channel readout
            next_s_readout_fifo_tdata[127:0] = m_readout_fifo_tdata[127:0];
            nextstate[STORE_PULSE_INFO] = 1'b1;
          end
          else begin
            // this is the final channel to be read out
            nextstate[READ_CHAN_DATA2] = 1'b1;
          end
        end
        else begin
          nextstate[READ_READOUT_FIFO] = 1'b1;
        end
      end
      // put pulse information into Pulse Trigger FIFO
      state[STORE_PULSE_INFO] : begin
        // FIFO accepted the data word
        if (s_readout_fifo_tready) begin
          nextstate[READ_CHAN_DATA2] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_PULSE_INFO] = 1'b1;
        end
      end
      // send the channel readout's timestamp
      state[SEND_CHAN_TRAILER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
          next_csn[31:0] = csn[31:0]+1;

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
        if (empty_event) begin
          next_daq_data[63:0] = {32'd0, trig_num[7:0], 4'h0, 20'd3};
        end
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
          next_chan_num_buf[31:0]  = 0;
          next_num_chan_en[2:0]    = 0; // reset the number of enabled channels for each new trigger
          next_empty_event         = 0;

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
      state <= 33'd1 << IDLE;

      burst_count[22:0]         <= 0;
      chan_num_buf[31:0]        <= 0;
      chan_tag[15:0]            <= 0;
      fill_type[2:0]            <= 0;
      wfm_count[22:0]           <= 0;
      wfm_gap_length[21:0]      <= 0;
      chan_tx_fifo_dest[3:0]    <= 0;
      chan_tx_fifo_last         <= 0;
      csn[31:0]                 <= 0;
      daq_data[63:0]            <= 0;
      data_count[31:0]          <= 0;
      data_wfm_count[22:0]      <= 0;
      ddr3_start_addr[25:0]     <= 0;
      ipbus_buf[31:0]           <= 0;
      ipbus_res_last            <= 0;
      num_chan_en[2:0]          <= 0;
      sent_amc13_header         <= 0;
      chan_trig_num[23:0]       <= 0;
      readout_timestamp[31:0]   <= 0;
      chan_error_rc[4:0]        <= 0; // clear error upon reset
      daq_valid                 <= 0;
      update_mcs_lsb            <= 0;
      master_checksum[127:0]    <= 0;
      channel_checksum[127:0]   <= 0;
      empty_event               <= 0;
      cs_mismatch_count[31:0]   <= 0; // clear soft error count upon reset
      chan_burst_count_type1[0] <= 23'd70000; // channel default is 70,000
      chan_burst_count_type1[1] <= 23'd70000; // channel default is 70,000
      chan_burst_count_type1[2] <= 23'd70000; // channel default is 70,000
      chan_burst_count_type1[3] <= 23'd70000; // channel default is 70,000
      chan_burst_count_type1[4] <= 23'd70000; // channel default is 70,000
      chan_burst_count_type2[0] <= 23'd100;   // channel default is 100
      chan_burst_count_type2[1] <= 23'd100;   // channel default is 100
      chan_burst_count_type2[2] <= 23'd100;   // channel default is 100
      chan_burst_count_type2[3] <= 23'd100;   // channel default is 100
      chan_burst_count_type2[4] <= 23'd100;   // channel default is 100
      chan_burst_count_type3[0] <= 23'd100;   // channel default is 100
      chan_burst_count_type3[1] <= 23'd100;   // channel default is 100
      chan_burst_count_type3[2] <= 23'd100;   // channel default is 100
      chan_burst_count_type3[3] <= 23'd100;   // channel default is 100
      chan_burst_count_type3[4] <= 23'd100;   // channel default is 100
      chan_burst_count_type7[0] <= 23'd10;    // channel default is 10
      chan_burst_count_type7[1] <= 23'd10;    // channel default is 10
      chan_burst_count_type7[2] <= 23'd10;    // channel default is 10
      chan_burst_count_type7[3] <= 23'd10;    // channel default is 10
      chan_burst_count_type7[4] <= 23'd10;    // channel default is 10
      chan_wfm_count_type1[0]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type1[1]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type1[2]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type1[3]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type1[4]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type2[0]   <= 12'd4;     // channel default is 4
      chan_wfm_count_type2[1]   <= 12'd4;     // channel default is 4
      chan_wfm_count_type2[2]   <= 12'd4;     // channel default is 4
      chan_wfm_count_type2[3]   <= 12'd4;     // channel default is 4
      chan_wfm_count_type2[4]   <= 12'd4;     // channel default is 4
      chan_wfm_count_type3[0]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type3[1]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type3[2]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type3[3]   <= 12'd1;     // channel default is 1
      chan_wfm_count_type3[4]   <= 12'd1;     // channel default is 1
      ipbus_chan_cmd[31:0]      <= 0;
      ipbus_chan_reg[31:0]      <= 0;
      pulse_data_size[22:0]     <= 23'd0;
      pulse_timestamp[43:0]     <= 44'd0;
      pulse_trig_num[23:0]      <= 23'd0;
      pulse_trig_length[1:0]    <=  2'd0;
    end
    else begin
      state <= nextstate;

      burst_count[22:0]           <= next_burst_count[22:0];
      chan_num_buf[31:0]          <= next_chan_num_buf[31:0];
      chan_tag[15:0]              <= next_chan_tag[15:0];
      fill_type[2:0]              <= next_fill_type[2:0];
      wfm_count[22:0]             <= next_wfm_count[22:0];
      wfm_gap_length[21:0]        <= next_wfm_gap_length[21:0];
      chan_tx_fifo_dest[3:0]      <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last           <= next_chan_tx_fifo_last;
      csn[31:0]                   <= next_csn[31:0];
      daq_data[63:0]              <= next_daq_data[63:0];
      data_count[31:0]            <= next_data_count[31:0];
      data_wfm_count[22:0]        <= next_data_wfm_count[22:0];
      ddr3_start_addr[25:0]       <= next_ddr3_start_addr[25:0];
      ipbus_buf[31:0]             <= next_ipbus_buf[31:0];
      ipbus_res_last              <= next_ipbus_res_last;
      num_chan_en[2:0]            <= next_num_chan_en[2:0];
      sent_amc13_header           <= next_sent_amc13_header;
      chan_trig_num[23:0]         <= next_chan_trig_num[23:0];   
      readout_timestamp[31:0]     <= next_readout_timestamp[31:0];
      chan_error_rc[4:0]          <= next_chan_error_rc[4:0];
      daq_valid                   <= next_daq_valid;
      update_mcs_lsb              <= next_update_mcs_lsb;
      master_checksum[127:0]      <= next_master_checksum[127:0];
      channel_checksum[127:0]     <= next_channel_checksum[127:0];
      empty_event                 <= next_empty_event;
      cs_mismatch_count[31:0]     <= next_cs_mismatch_count[31:0];
      chan_burst_count_type1[0]   <= next_chan_burst_count_type1[0];
      chan_burst_count_type1[1]   <= next_chan_burst_count_type1[1];
      chan_burst_count_type1[2]   <= next_chan_burst_count_type1[2];
      chan_burst_count_type1[3]   <= next_chan_burst_count_type1[3];
      chan_burst_count_type1[4]   <= next_chan_burst_count_type1[4];
      chan_burst_count_type2[0]   <= next_chan_burst_count_type2[0];
      chan_burst_count_type2[1]   <= next_chan_burst_count_type2[1];
      chan_burst_count_type2[2]   <= next_chan_burst_count_type2[2];
      chan_burst_count_type2[3]   <= next_chan_burst_count_type2[3];
      chan_burst_count_type2[4]   <= next_chan_burst_count_type2[4];
      chan_burst_count_type3[0]   <= next_chan_burst_count_type3[0];
      chan_burst_count_type3[1]   <= next_chan_burst_count_type3[1];
      chan_burst_count_type3[2]   <= next_chan_burst_count_type3[2];
      chan_burst_count_type3[3]   <= next_chan_burst_count_type3[3];
      chan_burst_count_type3[4]   <= next_chan_burst_count_type3[4];
      chan_burst_count_type7[0]   <= next_chan_burst_count_type7[0];
      chan_burst_count_type7[1]   <= next_chan_burst_count_type7[1];
      chan_burst_count_type7[2]   <= next_chan_burst_count_type7[2];
      chan_burst_count_type7[3]   <= next_chan_burst_count_type7[3];
      chan_burst_count_type7[4]   <= next_chan_burst_count_type7[4];
      chan_wfm_count_type1[0]     <= next_chan_wfm_count_type1[0];
      chan_wfm_count_type1[1]     <= next_chan_wfm_count_type1[1];
      chan_wfm_count_type1[2]     <= next_chan_wfm_count_type1[2];
      chan_wfm_count_type1[3]     <= next_chan_wfm_count_type1[3];
      chan_wfm_count_type1[4]     <= next_chan_wfm_count_type1[4];
      chan_wfm_count_type2[0]     <= next_chan_wfm_count_type2[0];
      chan_wfm_count_type2[1]     <= next_chan_wfm_count_type2[1];
      chan_wfm_count_type2[2]     <= next_chan_wfm_count_type2[2];
      chan_wfm_count_type2[3]     <= next_chan_wfm_count_type2[3];
      chan_wfm_count_type2[4]     <= next_chan_wfm_count_type2[4];
      chan_wfm_count_type3[0]     <= next_chan_wfm_count_type3[0];
      chan_wfm_count_type3[1]     <= next_chan_wfm_count_type3[1];
      chan_wfm_count_type3[2]     <= next_chan_wfm_count_type3[2];
      chan_wfm_count_type3[3]     <= next_chan_wfm_count_type3[3];
      chan_wfm_count_type3[4]     <= next_chan_wfm_count_type3[4];
      ipbus_chan_cmd[31:0]        <= next_ipbus_chan_cmd[31:0];
      ipbus_chan_reg[31:0]        <= next_ipbus_chan_reg[31:0];
      pulse_data_size[22:0]       <= next_pulse_data_size[22:0];
      pulse_timestamp[43:0]       <= next_pulse_timestamp[43:0];
      pulse_trig_num[23:0]        <= next_pulse_trig_num[23:0];
      pulse_trig_length[1:0]      <= next_pulse_trig_length[1:0];
      s_readout_fifo_tdata[127:0] <= next_s_readout_fifo_tdata[127:0];
      pretrigger_count[11:0]      <= next_pretrigger_count[11:0];
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
      pulse_fifo_tready     <= 0;
      m_readout_fifo_tready <= 0;
      s_readout_fifo_tvalid <= 0;
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
      pulse_fifo_tready     <= 0;
      m_readout_fifo_tready <= 0;
      s_readout_fifo_tvalid <= 0;

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
        nextstate[READ_PULSE_FIFO]       : begin
          pulse_fifo_tready <= 1;
        end
        nextstate[READ_READOUT_FIFO]     : begin
          m_readout_fifo_tready <= 1;
        end
        nextstate[STORE_PULSE_INFO]      : begin
          s_readout_fifo_tvalid <= 1;
        end
        nextstate[SEND_CHAN_TRAILER1]    : begin
          ;
        end
        nextstate[READY_AMC13_TRAILER]   : begin
          ;
        end
        nextstate[SEND_AMC13_TRAILER]    : begin
          daq_trailer <= 1;
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
