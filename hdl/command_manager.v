// Finite state machine for handling commands to Channel FPGA(s).
// 
// Two primary functions:
// 1. Handle configuration via IPbus
// 2. Handle ADC data readout to DAQ link
//
// Implemented error checking:
// 1. Trigger number from trigger info. FIFO and channel header are compared
// 2. Failed channel response code monitored. Abort readout from failed channel.
//    Will produce event size mismatch errors in the AMC13 status registers!
//
// Notes:
// 1. Trigger timestamp from trigger info. FIFO is stored in the AMC13 header as follows:
//    The 12 most significant bits are in the first AMC13 header, in place of the bunch crossing number
//    The 32 least significant bits are in the second AMC13 header, in the user-designated space
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
  output reg [3:0] chan_tx_fifo_dest,
  output reg [31:0] chan_tx_fifo_data,

  // interface to RX channel FIFO (through AXI4-Stream RX Switch)
  input wire chan_rx_fifo_valid,
  input wire chan_rx_fifo_last,
  input wire [31:0] chan_rx_fifo_data,
  output reg chan_rx_fifo_ready,

  // interface to IPbus AXI output
  input wire ipbus_cmd_valid,
  input wire ipbus_cmd_last,
  input wire [3:0] ipbus_cmd_dest,
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

  // interface to trigger information FIFO
  input wire tm_fifo_valid,
  input wire [63:0] tm_fifo_data,
  output reg tm_fifo_ready,

  // status connections
  input wire [4:0] chan_en,        // enabled channels, one bit for each channel
  output reg [4:0] chan_error_rc,  // master received an error response code, one bit for each channel
  output reg [4:0] trig_num_error, // trigger numbers from channel and master aren't synchronized, one bit for each channel
  output reg read_fill_done
);

  // idle state bit
  parameter IDLE                        = 0;
  // configuration manager state bits
  parameter SEND_IPBUS_CSN              = 1;
  parameter READ_IPBUS_CMD              = 2;
  parameter CHECK_LAST                  = 3;
  parameter SEND_IPBUS_CMD              = 4;
  parameter READ_IPBUS_RSN              = 5;
  parameter READ_IPBUS_RES              = 6;
  parameter SEND_IPBUS_RES              = 7;
  // event builder state bits
  parameter GET_TRIG_NUM                = 8;
  parameter WAIT                        = 9;
  parameter GET_TRIG_TIMESTAMP          = 10;
  parameter CHECK_CHAN_EN               = 11;
  parameter SEND_CHAN_CSN               = 12;
  parameter SEND_CHAN_CC                = 13;
  parameter READ_CHAN_RSN               = 14;
  parameter READ_CHAN_RC                = 15;
  parameter READ_CHAN_TRIG_NUM          = 16;
  parameter READ_CHAN_DDR3_START_ADDR   = 17;
  parameter READ_CHAN_BURST_COUNT       = 18;
  parameter READ_CHAN_TAG_AND_FILLTYPE  = 19;
  parameter STORE_CHAN_TAG_AND_FILLTYPE = 20;
  parameter SEND_AMC13_HEADER1          = 21;
  parameter SEND_AMC13_HEADER2          = 22;
  parameter SEND_CHAN_HEADER1           = 23;
  parameter SEND_CHAN_HEADER2           = 24;
  parameter READ_CHAN_DATA1             = 25;
  parameter READ_CHAN_DATA2             = 26;
  parameter READ_CHAN_DATA_RESYNC       = 27;
  parameter SEND_READOUT_TIMESTAMP      = 28;
  parameter READY_AMC13_TRAILER         = 29;
  parameter SEND_AMC13_TRAILER          = 30;


  reg [30:0] state;             // state of finite state machine
  reg [31:0] burst_count;       // burst count for data acquisition, 1 burst count = 8 ADC samples
                                // value obtained from received channel header from Aurora RX FIFO
  reg [31:0] chan_num_buf;      // channel number
  reg [31:0] chan_tag_filltype; // channel tag and fill type
  reg [31:0] csn;               // channel serial number
  reg [31:0] data_count;        // # of 32-bit data words received from Aurora
  reg [31:0] ddr3_start_addr;   // DDR3 start address
  reg [31:0] ipbus_buf;         // buffer for IPbus data
  reg [31:0] trig_num_buf;      // trigger number from channel header, starts at 1
  reg [31:0] fifo_trig_num;     // trigger number from trigger information FIFO, starts at 1
  reg [43:0] trig_timestamp;    // trigger timestamp, defined when trigger is received by trigger manager
  reg [31:0] readout_timestamp; // channel data readout timestamp
  reg [2:0] num_chan_en;        // number of enabled channels
  reg sent_amc13_header;        // flag to indicate that the AMC13 header has been sent

  // regs for channel checksum verification
  reg update_mcs_lsb;           // flag to update the 64 LSBs of the 128-bit master checksum (mcs)
  reg [127:0] master_checksum;  // checksum calculated in this module
  reg [127:0] channel_checksum; // checksum from received channel data
  

  // for internal regs
  reg [30:0] nextstate;
  reg [31:0] next_burst_count;
  reg [31:0] next_chan_num_buf;
  reg [31:0] next_chan_tag_filltype;
  reg [31:0] next_csn;
  reg [31:0] next_data_count;
  reg [31:0] next_ddr3_start_addr;
  reg [31:0] next_ipbus_buf;
  reg [31:0] next_trig_num_buf;
  reg [31:0] next_fifo_trig_num;
  reg [43:0] next_trig_timestamp;
  reg [31:0] next_readout_timestamp;
  reg [2:0] next_num_chan_en;
  reg next_sent_amc13_header;

  reg next_update_mcs_lsb;
  reg [127:0] next_master_checksum;
  reg [127:0] next_channel_checksum;

  // for external regs
  reg [63:0] next_daq_data;
  reg [4:0] next_chan_error_rc;
  reg [4:0] next_trig_num_error;
  reg [3:0] next_chan_tx_fifo_dest;
  reg next_chan_tx_fifo_last;
  reg next_ipbus_res_last;
  reg next_daq_valid;


  // number of 64-bit words to be sent to AMC13, including AMC13 headers and trailer
  wire [19:0] event_size;
  // Explaination for 'event size' calculation:
  // (burst_count[19:0]*2              : 2 64-bit words per burst
  //                   +2              : 2 64-bit channel header words per channel data set
  //                   +2              : 2 64-bit channel checksum words per channel data set
  //                   +1)             : 1 64-bit readout timestamp per channel data set
  //                      *num_chan_en : # channels that will send data
  //                      +3           : 3 (2 AMC13 header + 1 AMC13 trailer) 64-bit words per AMC13 data set
  assign event_size = (burst_count[19:0]*2+2+2+1)*(chan_en[0]+chan_en[1]+chan_en[2]+chan_en[3]+chan_en[4])+3;


  // comb always block
  always @* begin
    nextstate = 31'd0;
    next_burst_count[31:0]       = burst_count[31:0];
    next_chan_num_buf[31:0]      = chan_num_buf[31:0];
    next_chan_tag_filltype[31:0] = chan_tag_filltype[31:0];
    next_csn[31:0]               = csn[31:0];
    next_data_count[31:0]        = data_count[31:0];
    next_ddr3_start_addr[31:0]   = ddr3_start_addr[31:0];
    next_ipbus_buf[31:0]         = ipbus_buf[31:0];
    next_trig_num_buf[31:0]      = trig_num_buf[31:0];
    next_fifo_trig_num[31:0]     = fifo_trig_num[31:0];
    next_trig_timestamp[43:0]    = trig_timestamp[43:0];
    next_readout_timestamp[31:0] = readout_timestamp[31:0] + 1'b1; // increment readout timestamp on each clock cycle
    next_num_chan_en[2:0]        = num_chan_en[2:0];
    next_sent_amc13_header       = sent_amc13_header;

    next_update_mcs_lsb          = update_mcs_lsb;
    next_master_checksum[127:0]  = master_checksum[127:0];
    next_channel_checksum[127:0] = channel_checksum[127:0];

    next_daq_data[63:0]          = daq_data[63:0];
    next_chan_error_rc[4:0]      = chan_error_rc[4:0];
    next_trig_num_error[4:0]     = trig_num_error[4:0];
    next_chan_tx_fifo_dest[3:0]  = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last       = chan_tx_fifo_last;
    next_ipbus_res_last          = ipbus_res_last;

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
        else if (tm_fifo_valid) begin
          next_fifo_trig_num[31:0] = tm_fifo_data[31:0];
          nextstate[GET_TRIG_NUM] = 1'b1;
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
          nextstate[CHECK_LAST] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
      end
      // check if this is the last IPbus command word
      state[CHECK_LAST] : begin
        begin
          next_chan_tx_fifo_last = ipbus_cmd_last;
          nextstate[SEND_IPBUS_CMD] = 1'b1;
        end
      end
      // send IPbus command to channel
      state[SEND_IPBUS_CMD] : begin
        chan_tx_fifo_data[31:0] = ipbus_buf[31:0];

        if (chan_tx_fifo_ready && chan_tx_fifo_last) begin
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

        if (ipbus_res_ready && ipbus_res_last) begin
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

      // get the trigger number from the trigger information FIFO
      state[GET_TRIG_NUM] : begin
        begin
          next_chan_tx_fifo_dest[3:0] = 0;
          nextstate[WAIT] = 1'b1;
        end
      end
      // wait to ensure that FIFO has received the ready signal,
      // and the output data is presenting the trigger timestamp
      state[WAIT] : begin
        if (tm_fifo_valid && !tm_fifo_ready) begin
          next_trig_timestamp[43:0] = tm_fifo_data[43:0];
          nextstate[GET_TRIG_TIMESTAMP] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end
      // get trigger timestamp from trigger information FIFO
      state[GET_TRIG_TIMESTAMP] : begin
        begin
          nextstate[CHECK_CHAN_EN] = 1'b1;
        end
      end
      // check whether this channel number is enabled
      state[CHECK_CHAN_EN] : begin
        if (chan_en[chan_tx_fifo_dest] == 1) begin
          next_num_chan_en[2:0] = num_chan_en[2:0]+1;
          next_chan_tx_fifo_last = 0;
          nextstate[SEND_CHAN_CSN] = 1'b1;
        end
        else if (chan_tx_fifo_dest[3:0] == 4'h5) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else begin
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
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
            nextstate[READ_CHAN_TRIG_NUM] = 1'b1;
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
      state[READ_CHAN_TRIG_NUM] : begin
        if (chan_rx_fifo_valid) begin
          // check that the trigger number from channel header and trigger information FIFO match
          if (fifo_trig_num[31:0] != chan_rx_fifo_data[31:0]) begin
            // trigger numbers aren't synchronized
            // RAISE THE ERROR FLAG
            next_trig_num_error[chan_tx_fifo_dest] = 1'b1;
          end

          next_trig_num_buf[31:0] = chan_rx_fifo_data[31:0];
          next_master_checksum[127:0] = {master_checksum[127:32], chan_rx_fifo_data[31:0]};
          nextstate[READ_CHAN_DDR3_START_ADDR] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_TRIG_NUM] = 1'b1;
        end
      end
      // get DDR3 start address from channel's header word #2
      state[READ_CHAN_DDR3_START_ADDR] : begin
        if (chan_rx_fifo_valid) begin
          next_ddr3_start_addr[31:0] = chan_rx_fifo_data[31:0];
          next_master_checksum[127:0] = {master_checksum[127:64], chan_rx_fifo_data[31:0], master_checksum[31:0]};
          nextstate[READ_CHAN_BURST_COUNT] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_DDR3_START_ADDR] = 1'b1;
        end
      end
      // get burst count from channel's header word #3
      state[READ_CHAN_BURST_COUNT] : begin
        if (chan_rx_fifo_valid) begin
          next_burst_count[31:0] = chan_rx_fifo_data[31:0];
          next_master_checksum[127:0] = {master_checksum[127:96], chan_rx_fifo_data[31:0], master_checksum[63:0]};
          nextstate[READ_CHAN_TAG_AND_FILLTYPE] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_BURST_COUNT] = 1'b1;
        end
      end
      // get tag and fill type from channel's header word #4
      state[READ_CHAN_TAG_AND_FILLTYPE] : begin
        if (chan_rx_fifo_valid) begin
          next_chan_tag_filltype[31:0] = chan_rx_fifo_data[31:0];
          next_master_checksum[127:0] = {chan_rx_fifo_data[31:0], master_checksum[95:0]};
          nextstate[STORE_CHAN_TAG_AND_FILLTYPE] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_TAG_AND_FILLTYPE] = 1'b1;
        end
      end
      // pause to store the channel's tag and fill type
      state[STORE_CHAN_TAG_AND_FILLTYPE] : begin
        if (!sent_amc13_header) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {8'h00, trig_num_buf[23:0], trig_timestamp[43:32], event_size[19:0]};
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
        end
        else begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {2'b01, 12'b0, chan_tag_filltype[17:0], 11'b0, burst_count[20:0]};
          next_readout_timestamp[31:0] = 0;
          nextstate[SEND_CHAN_HEADER1] = 1'b1;
        end
      end
      // send the first AMC13 header word
      state[SEND_AMC13_HEADER1] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {trig_timestamp[31:0], 32'h00000001};
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
          next_daq_data[63:0] = {2'b01, 12'b0, chan_tag_filltype[17:0], 11'b0, burst_count[20:0]};
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
          next_daq_data[63:0] = {6'b0, ddr3_start_addr[25:3], 3'b0, 8'b0, trig_num_buf[23:0]};
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
          next_data_count[31:0] = 0;
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
          next_daq_data[63:0] = {32'h00000000, chan_rx_fifo_data[31:0]};
          next_data_count[31:0] = data_count[31:0]+1;
          nextstate[READ_CHAN_DATA2] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_DATA1] = 1'b1;
        end
      end
      // read the second 32-bit data word from channel and
      // send the data to the DAQ link to AMC13
      state[READ_CHAN_DATA2] : begin
        // this state's logic ties together the 'ready' and 'valid' signals between the Aurora RX FIFO and DAQ link
        // that allows the data gets sent to the DAQ link directly, increasing data throughput rates

        // DAQ link has flagged that its buffer is almost full
        // grab the Aurora RX FIFO's lastest word, and wait for DAQ link to recover before trying to send it
        if (~daq_ready & chan_rx_fifo_valid) begin
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          next_data_count[31:0] = data_count[31:0]+1;
          next_update_mcs_lsb = ~update_mcs_lsb;

          // check whether this data word is the channel checksum
          if (data_count[31:0] == (burst_count[31:0]*4+1)) begin
            next_channel_checksum[127:0] = {64'd0, chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          else begin
            // update least- or most-significant 64-bits of checksum
            // use '~update_mcs_lsb' to determine the 'next' value
            next_master_checksum[127:0] = ~update_mcs_lsb ? {master_checksum[127:64], (master_checksum[63:0]^{chan_rx_fifo_data[31:0], daq_data[31:0]})} : {(master_checksum[127:64]^{chan_rx_fifo_data[31:0], daq_data[31:0]}), master_checksum[63:0]};
          end
          nextstate[READ_CHAN_DATA_RESYNC] = 1'b1;
        end
        // we're receiving the last data word
        // send it, and exit to send the readout timestamp next
        else if (daq_ready & chan_rx_fifo_valid & (data_count[31:0] == (burst_count[31:0]*4+3))) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          next_data_count[31:0] = data_count[31:0]+1;
          next_channel_checksum[127:0] = {chan_rx_fifo_data[31:0], daq_data[31:0], channel_checksum[63:0]};
          nextstate[SEND_READOUT_TIMESTAMP] = 1'b1;
        end
        // we've not received all the data
        // send current data, and continue the readout loop
        else if (daq_ready & chan_rx_fifo_valid) begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0], daq_data[31:0]};
          next_data_count[31:0] = data_count[31:0]+1;
          next_update_mcs_lsb = ~update_mcs_lsb;

          // check whether this data word is the channel checksum
          if (data_count[31:0] == (burst_count[31:0]*4+1)) begin
            next_channel_checksum[127:0] = {64'd0, chan_rx_fifo_data[31:0], daq_data[31:0]};
          end
          else begin
            // update least- or most-significant 64-bits of checksum
            // use '~update_mcs_lsb' to determine the 'next' value
            next_master_checksum[127:0] = ~update_mcs_lsb ? {master_checksum[127:64], (master_checksum[63:0]^{chan_rx_fifo_data[31:0], daq_data[31:0]})} : {(master_checksum[127:64]^{chan_rx_fifo_data[31:0], daq_data[31:0]}), master_checksum[63:0]};
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
        if (daq_ready & (data_count[31:0] == (burst_count[31:0]*4+3))) begin
          next_daq_valid = 1'b1;
          nextstate[SEND_READOUT_TIMESTAMP] = 1'b1;
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
      // send the channel readout's timestamp
      state[SEND_READOUT_TIMESTAMP] : begin
        if (daq_ready) begin
          next_daq_valid = 1'b1;

          // check whether the checksums match
          // if they match, send '0000_0000' in MSB
          if (master_checksum[127:0] == channel_checksum[127:0]) begin
            next_daq_data[63:0] = {32'h0000_0000, readout_timestamp[31:0]};
          end
          // if they don't match, send 'baad_baad' in MSB
          else begin
            next_daq_data[63:0] = {32'hbaad_baad, readout_timestamp[31:0]};
          end

          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
          next_csn[31:0] = csn[31:0]+1;
          nextstate[CHECK_CHAN_EN] = 1'b1;
        end
        else begin
          // DAQ link buffer is still almost full
          nextstate[SEND_READOUT_TIMESTAMP] = 1'b1;
        end
      end
      // prepare the AMC13 trailer word
      state[READY_AMC13_TRAILER] : begin
        begin
          next_daq_valid = 1'b1;
          next_daq_data[63:0] = {32'h00000000, trig_num_buf[7:0], 4'h0, event_size[19:0]};
          nextstate[SEND_AMC13_TRAILER] = 1'b1;
        end
      end
      // send the AMC13 trailer
      state[SEND_AMC13_TRAILER] : begin
        if (daq_ready) begin
          next_trig_num_buf[31:0] = 0;
          next_csn[31:0] = csn[31:0]+1;
          next_daq_data[63:0] = 0;
          next_sent_amc13_header = 0;
          next_chan_num_buf[31:0] = 0;
          next_burst_count[31:0] = 0;
          next_num_chan_en[2:0] = 0; // reset the number of enabled channels for each new trigger
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
    endcase
  end


  // sequential always block
  always @(posedge clk) begin
   
    if (rst) begin
      // reset values
      state <= 31'd1 << IDLE;

      burst_count[31:0]       <= 0;
      chan_num_buf[31:0]      <= 0;
      chan_tag_filltype[31:0] <= 0;
      chan_tx_fifo_dest[3:0]  <= 0;
      chan_tx_fifo_last       <= 0;
      csn[31:0]               <= 0;
      daq_data[63:0]          <= 0;
      data_count[31:0]        <= 0;
      ddr3_start_addr[31:0]   <= 0;
      ipbus_buf[31:0]         <= 0;
      ipbus_res_last          <= 0;
      num_chan_en[2:0]        <= 0;
      sent_amc13_header       <= 0;
      trig_num_buf[31:0]      <= 0;
      fifo_trig_num[31:0]     <= 0;
      trig_timestamp[43:0]    <= 0;
      readout_timestamp[31:0] <= 0;
      chan_error_rc[4:0]      <= 0; // clear error upon reset
      trig_num_error[4:0]     <= 0; // clear error upon reset
      daq_valid               <= 0;

      update_mcs_lsb          <= 0;
      master_checksum[127:0]  <= 0;
      channel_checksum[127:0] <= 0;
    end
    else begin
      state <= nextstate;

      burst_count[31:0]       <= next_burst_count[31:0];
      chan_num_buf[31:0]      <= next_chan_num_buf[31:0];
      chan_tag_filltype[31:0] <= next_chan_tag_filltype[31:0];
      chan_tx_fifo_dest[3:0]  <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last       <= next_chan_tx_fifo_last;
      csn[31:0]               <= next_csn[31:0];
      daq_data[63:0]          <= next_daq_data[63:0];
      data_count[31:0]        <= next_data_count[31:0];
      ddr3_start_addr[31:0]   <= next_ddr3_start_addr[31:0];
      ipbus_buf[31:0]         <= next_ipbus_buf[31:0];
      ipbus_res_last          <= next_ipbus_res_last;
      num_chan_en[2:0]        <= next_num_chan_en[2:0];
      sent_amc13_header       <= next_sent_amc13_header;
      trig_num_buf[31:0]      <= next_trig_num_buf[31:0];
      fifo_trig_num[31:0]     <= next_fifo_trig_num[31:0];
      trig_timestamp[43:0]    <= next_trig_timestamp[43:0];    
      readout_timestamp[31:0] <= next_readout_timestamp[31:0];
      chan_error_rc[4:0]      <= next_chan_error_rc[4:0];
      trig_num_error[4:0]     <= next_trig_num_error[4:0];
      daq_valid               <= next_daq_valid;

      update_mcs_lsb          <= next_update_mcs_lsb;
      master_checksum[127:0]  <= next_master_checksum[127:0];
      channel_checksum[127:0] <= next_channel_checksum[127:0];
    end
  end


  // datapath sequential always block
  always @(posedge clk) begin
    if (rst) begin
      // reset values
      chan_rx_fifo_ready <= 0;
      chan_tx_fifo_valid <= 0;
      daq_header         <= 0;
      daq_trailer        <= 0;
      ipbus_cmd_ready    <= 0;
      ipbus_res_valid    <= 0;
      read_fill_done     <= 0;
      tm_fifo_ready      <= 0;
    end
    else begin
      // default values
      chan_rx_fifo_ready <= 0;
      chan_tx_fifo_valid <= 0;
      daq_header         <= 0;
      daq_trailer        <= 0;
      ipbus_cmd_ready    <= 0;
      ipbus_res_valid    <= 0;
      read_fill_done     <= 0;
      tm_fifo_ready      <= 0;

      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]                        : begin
          ;
        end

        // ======================================
        // configuration manager next state logic
        // ======================================

        nextstate[SEND_IPBUS_CSN]              : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_CMD]              : begin
          ipbus_cmd_ready <= 1;
        end
        nextstate[CHECK_LAST]                  : begin
          ;
        end
        nextstate[SEND_IPBUS_CMD]              : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_IPBUS_RSN]              : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_IPBUS_RES]              : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[SEND_IPBUS_RES]              : begin
          ipbus_res_valid <= 1;
        end

        // ==============================
        // event builder next state logic
        // ==============================

        nextstate[GET_TRIG_NUM]                : begin
          tm_fifo_ready <= 1;
        end
        nextstate[WAIT]                        : begin
          ;
        end
        nextstate[GET_TRIG_TIMESTAMP]          : begin
          tm_fifo_ready <= 1;
        end
        nextstate[CHECK_CHAN_EN]               : begin
          ;
        end
        nextstate[SEND_CHAN_CSN]               : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_CHAN_CC]                : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[READ_CHAN_RSN]               : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_RC]                : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_TRIG_NUM]          : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DDR3_START_ADDR]   : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_BURST_COUNT]       : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_TAG_AND_FILLTYPE]  : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[STORE_CHAN_TAG_AND_FILLTYPE] : begin
          ;
        end
        nextstate[SEND_AMC13_HEADER1]          : begin
          daq_header <= 1;
        end
        nextstate[SEND_AMC13_HEADER2]          : begin
          ;
        end
        nextstate[SEND_CHAN_HEADER1]           : begin
          ;
        end
        nextstate[SEND_CHAN_HEADER2]           : begin
          ;
        end
        nextstate[READ_CHAN_DATA1]             : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA2]             : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA_RESYNC]       : begin
          ;
        end
        nextstate[SEND_READOUT_TIMESTAMP]      : begin
          ;
        end
        nextstate[READY_AMC13_TRAILER]         : begin
          ;
        end
        nextstate[SEND_AMC13_TRAILER]          : begin
          daq_trailer <= 1;
          read_fill_done <= 1;
        end
      endcase
    end
  end

endmodule
