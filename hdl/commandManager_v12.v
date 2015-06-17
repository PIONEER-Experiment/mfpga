
// Created by fizzim.pl version $Revision: 5.0 on 2015:03:31 at 10:55:00 (www.fizzim.com)

module commandManager (
  output reg busy,
  output reg chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg [3:0] chan_tx_fifo_dest,
  output reg chan_tx_fifo_last,
  output reg chan_tx_fifo_valid,
  output reg [63:0] daq_data,
  output reg daq_header,
  output reg daq_trailer,
  output reg daq_valid,
  output reg ipbus_cmd_ready,
  output reg [31:0] ipbus_res_data,
  output reg ipbus_res_last,
  output reg ipbus_res_valid,
  output reg read_fill_done,
  output reg tm_fifo_ready,
  input wire [4:0] chan_en,
  input wire [31:0] chan_rx_fifo_data,
  input wire chan_rx_fifo_last,
  input wire chan_rx_fifo_valid,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire daq_ready,
  input wire [31:0] ipbus_cmd_data,
  input wire [3:0] ipbus_cmd_dest,
  input wire ipbus_cmd_last,
  input wire ipbus_cmd_valid,
  input wire ipbus_res_ready,
  input wire rst,
  input wire [23:0] tm_fifo_data,
  input wire tm_fifo_valid 
);

  // state bits
  parameter 
  IDLE                        = 0, 
  CHECK_CHAN_EN               = 1, 
  CHECK_LAST                  = 2, 
  GET_TRIG_NUM                = 3, 
  READY_AMC13_TRAILER         = 4, 
  READ_CHAN_BURST_COUNT       = 5, 
  READ_CHAN_DATA1             = 6, 
  READ_CHAN_DATA2             = 7, 
  READ_CHAN_DDR_START_ADDR    = 8, 
  READ_CHAN_RC                = 9, 
  READ_CHAN_RSN               = 10, 
  READ_CHAN_TAG_AND_FILLTYPE  = 11, 
  READ_CHAN_TRIG_NUM          = 12, 
  READ_CHECKSUM               = 13, 
  READ_IPBUS_CMD              = 14, 
  READ_IPBUS_RES              = 15, 
  READ_IPBUS_RSN              = 16, 
  SEND_AMC13_HEADER1          = 17, 
  SEND_AMC13_HEADER2          = 18, 
  SEND_AMC13_TRAILER          = 19, 
  SEND_CHAN_CC                = 20, 
  SEND_CHAN_CSN               = 21, 
  SEND_CHAN_DATA              = 22, 
  SEND_CHAN_HEADER            = 23, 
  SEND_IPBUS_CMD              = 24, 
  SEND_IPBUS_CSN              = 25, 
  SEND_IPBUS_RES              = 26, 
  STORE_CHAN_TAG_AND_FILLTYPE = 27, 
  SEND_CHAN_HEADER2           = 28; 

  reg [28:0] state;
  reg [31:0] burst_count;
  reg [31:0] chan_num_buf;
  reg [31:0] chan_tag_filltype;
  reg [31:0] csn;
  reg [31:0] data_count;
  reg [31:0] ddr_start_addr;
  reg [31:0] ipbus_buf;
  reg [2:0] num_chan_en;
  reg sent_header;
  reg [31:0] trig_num_buf;
  
  reg [28:0] nextstate;
  reg [31:0] next_burst_count;
  reg [31:0] next_chan_num_buf;
  reg [31:0] next_chan_tag_filltype;
  reg [3:0] next_chan_tx_fifo_dest;
  reg next_chan_tx_fifo_last;
  reg [31:0] next_csn;
  reg [63:0] next_daq_data;
  reg [31:0] next_data_count;
  reg [31:0] next_ddr_start_addr;
  reg [31:0] next_ipbus_buf;
  reg next_ipbus_res_last;
  reg [2:0] next_num_chan_en;
  reg next_sent_header;
  reg [31:0] next_trig_num_buf;

  // comb always block
  always @* begin
    nextstate = 29'b00000000000000000000000000000;
    chan_tx_fifo_data[31:0] = 0; // default
    ipbus_res_data[31:0] = 0; // default
    next_burst_count[31:0] = burst_count[31:0];
    next_chan_num_buf[31:0] = chan_num_buf[31:0];
    next_chan_tag_filltype[31:0] = chan_tag_filltype[31:0];
    next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last = chan_tx_fifo_last;
    next_csn[31:0] = csn[31:0];
    next_daq_data[63:0] = daq_data[63:0];
    next_data_count[31:0] = data_count[31:0];
    next_ddr_start_addr[31:0] = ddr_start_addr[31:0];
    next_ipbus_buf[31:0] = ipbus_buf[31:0];
    next_ipbus_res_last = ipbus_res_last;
    next_num_chan_en[2:0] = num_chan_en[2:0];
    next_sent_header = sent_header;
    next_trig_num_buf[31:0] = trig_num_buf[31:0];
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]                       : begin
        if (ipbus_cmd_valid) begin
          nextstate[SEND_IPBUS_CSN] = 1'b1;
          next_chan_tx_fifo_last = 0;
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
        end
        else if (tm_fifo_valid) begin
          nextstate[GET_TRIG_NUM] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[CHECK_CHAN_EN]              : begin
        if (chan_en[chan_tx_fifo_dest] == 1) begin
          nextstate[SEND_CHAN_CSN] = 1'b1;
          next_num_chan_en[2:0] = num_chan_en[2:0]+1;
          next_chan_tx_fifo_last = 0;
        end
        else if (chan_tx_fifo_dest[3:0]==4'h5) begin
          nextstate[READY_AMC13_TRAILER] = 1'b1;
        end
        else begin
          nextstate[CHECK_CHAN_EN] = 1'b1;
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
        end
      end
      state[CHECK_LAST]                 : begin
        begin
          nextstate[SEND_IPBUS_CMD] = 1'b1;
          next_chan_tx_fifo_last = ipbus_cmd_last;
        end
      end
      state[GET_TRIG_NUM]               : begin
        begin
          nextstate[CHECK_CHAN_EN] = 1'b1;
          next_chan_tx_fifo_dest[3:0] = 0;
        end
      end
      state[READY_AMC13_TRAILER]        : begin
        begin
          nextstate[SEND_AMC13_TRAILER] = 1'b1;
          // *2 = 2 64-bit words per burst
          // +2 = 2 64-bit channel header words per channel data set
          // +2 = 2 64-bit channel checksum words per channel data set
          // *num_chan_en = # channels that will send data
          // +3 = 3 (2 AMC13 header + 1 AMC13 trailer) 64-bit words per AMC13 data set

          // burst_count[19:0]   = # 128-bit data words
          // burst_count[19:0]*2 = # 64-bit data words
          next_daq_data[63:0] = {32'h00000000,{{trig_num_buf[7:0],4'h0},(burst_count[19:0]*2+2+2)*num_chan_en+3}};
        end
      end
      state[READ_CHAN_BURST_COUNT]      : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_TAG_AND_FILLTYPE] = 1'b1;
          next_burst_count[31:0] = chan_rx_fifo_data[31:0];
        end
        else begin
          nextstate[READ_CHAN_BURST_COUNT] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_DATA1]            : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_DATA2] = 1'b1;
          next_data_count[31:0] = data_count[31:0]+1;
          next_daq_data[63:0] = {32'h00000000,chan_rx_fifo_data[31:0]};
        end
        else begin
          nextstate[READ_CHAN_DATA1] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_DATA2]            : begin
        if (chan_rx_fifo_valid) begin
          nextstate[SEND_CHAN_DATA] = 1'b1;
          next_data_count[31:0] = data_count[31:0]+1;
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0],daq_data[31:0]};
        end
        else begin
          nextstate[READ_CHAN_DATA2] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_DDR_START_ADDR]   : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_BURST_COUNT] = 1'b1;
          next_ddr_start_addr[31:0] = chan_rx_fifo_data[31:0];
        end
        else begin
          nextstate[READ_CHAN_DDR_START_ADDR] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_RC]               : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_TRIG_NUM] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_RC] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_RSN]              : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_RC] = 1'b1;
        end
        else begin
          nextstate[READ_CHAN_RSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_TAG_AND_FILLTYPE] : begin
        if (chan_rx_fifo_valid) begin
          nextstate[STORE_CHAN_TAG_AND_FILLTYPE] = 1'b1;
          next_chan_tag_filltype[31:0] = chan_rx_fifo_data[31:0];
        end
        else begin
          nextstate[READ_CHAN_TAG_AND_FILLTYPE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHAN_TRIG_NUM]         : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_CHAN_DDR_START_ADDR] = 1'b1;
          next_trig_num_buf[31:0] = chan_rx_fifo_data[31:0];
        end
        else begin
          nextstate[READ_CHAN_TRIG_NUM] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_CHECKSUM]              : begin
        // commented out 'nextstate' logic: will automatically go to CHECK_CHAN_EN
        // this state doesn't do anything any longer since we're sending the checksum as data now
        //if (chan_rx_fifo_valid && chan_rx_fifo_last) begin
          nextstate[CHECK_CHAN_EN] = 1'b1;
          next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0]+1;
          next_daq_data[63:0] = 0;
          next_csn[31:0] = csn[31:0]+1;
        //end
        //else begin
        //  nextstate[READ_CHECKSUM] = 1'b1; // Added because implied_loopback is true
        //end
      end
      state[READ_IPBUS_CMD]             : begin
        if (ipbus_cmd_valid) begin
          nextstate[CHECK_LAST] = 1'b1;
          next_ipbus_buf[31:0] = ipbus_cmd_data[31:0];
        end
        else begin
          nextstate[READ_IPBUS_CMD] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_IPBUS_RES]             : begin
        if (chan_rx_fifo_valid) begin
          nextstate[SEND_IPBUS_RES] = 1'b1;
          next_ipbus_buf[31:0] = chan_rx_fifo_data[31:0];
          next_ipbus_res_last = chan_rx_fifo_last;
        end
        else begin
          nextstate[READ_IPBUS_RES] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_IPBUS_RSN]             : begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_RSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_AMC13_HEADER1]         : begin
        if (daq_ready) begin
          nextstate[SEND_AMC13_HEADER2] = 1'b1;
          next_daq_data[63:0] = 64'h0000000000000001;
        end
        else begin
          nextstate[SEND_AMC13_HEADER1] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_AMC13_HEADER2]         : begin
        if (daq_ready) begin
          nextstate[SEND_CHAN_HEADER] = 1'b1;
          next_daq_data[63:0] = {{{2'b01,12'b0},chan_tag_filltype[17:0]},{11'b0,burst_count[20:0]}};
          next_sent_header = 1;
        end
        else begin
          nextstate[SEND_AMC13_HEADER2] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_AMC13_TRAILER]         : begin
        if (daq_ready) begin
          nextstate[IDLE] = 1'b1;
          next_trig_num_buf[31:0] = 0;
          next_csn[31:0] = csn[31:0]+1;
          next_daq_data[63:0] = 0;
          next_sent_header = 0;
          next_chan_num_buf[31:0] = 0;
          next_burst_count[31:0] = 0;
          next_num_chan_en[2:0] = 0; // Reset the number of enabled channels for each new trigger
        end
        else begin
          nextstate[SEND_AMC13_TRAILER] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_CHAN_CC]               : begin
        chan_tx_fifo_data[31:0] = 32'h8;
        if (chan_tx_fifo_ready) begin
          nextstate[READ_CHAN_RSN] = 1'b1;
        end
        else begin
          nextstate[SEND_CHAN_CC] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_CHAN_CSN]              : begin
        chan_tx_fifo_data[31:0] = csn[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate[SEND_CHAN_CC] = 1'b1;
          next_chan_tx_fifo_last = 1;
        end
        else begin
          nextstate[SEND_CHAN_CSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_CHAN_DATA]             : begin
        // extra '+4' is for sending the channel checksum along with the data
        if (daq_ready && (data_count[31:0] == (burst_count[31:0]*4+4))) begin
          nextstate[READ_CHECKSUM] = 1'b1;
        end
        else if (daq_ready) begin
          nextstate[READ_CHAN_DATA1] = 1'b1;
          next_daq_data[63:0] = 0;
        end
        else begin
          nextstate[SEND_CHAN_DATA] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_CHAN_HEADER]           : begin
        if (daq_ready) begin
          nextstate[SEND_CHAN_HEADER2] = 1'b1;
          next_daq_data[63:0] = {{6'b0,{ddr_start_addr[25:3],3'b0}},{8'b0,trig_num_buf[23:0]}};
        end
        else begin
          nextstate[SEND_CHAN_HEADER] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_CHAN_HEADER2]           : begin
        if (daq_ready) begin
          nextstate[READ_CHAN_DATA1] = 1'b1;
          next_data_count[31:0] = 0;
        end
        else begin
          nextstate[SEND_CHAN_HEADER2] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_CMD]             : begin
        chan_tx_fifo_data[31:0] = ipbus_buf[31:0];
        if (chan_tx_fifo_ready && chan_tx_fifo_last) begin
          nextstate[READ_IPBUS_RSN] = 1'b1;
        end
        else if (chan_tx_fifo_ready) begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
          next_chan_tx_fifo_last = 0;
        end
        else begin
          nextstate[SEND_IPBUS_CMD] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_CSN]             : begin
        chan_tx_fifo_data[31:0] = csn[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_CSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_RES]             : begin
        ipbus_res_data[31:0] = ipbus_buf[31:0];
        if (ipbus_res_ready && ipbus_res_last) begin
          nextstate[IDLE] = 1'b1;
          next_csn[31:0] = csn[31:0]+1;
        end
        else if (ipbus_res_ready) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_RES] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[STORE_CHAN_TAG_AND_FILLTYPE]: begin
        if (!sent_header) begin
          nextstate[SEND_AMC13_HEADER1] = 1'b1;
          next_daq_data[63:0] = {{8'h00,trig_num_buf[23:0]},{12'h000,(burst_count[19:0]*2+2+2)*(chan_en[0]+chan_en[1]+chan_en[2]+chan_en[3]+chan_en[4])+3}};
        end
        else begin
          nextstate[SEND_CHAN_HEADER] = 1'b1;
          next_daq_data[63:0] = {{{2'b01,12'b0},chan_tag_filltype[17:0]},{11'b0,burst_count[20:0]}};
        end
      end
    endcase
  end

  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= 28'b0000000000000000000000000001 << IDLE;
      burst_count[31:0] <= 0;
      chan_num_buf[31:0] <= 0;
      chan_tag_filltype[31:0] <= 0;
      chan_tx_fifo_dest[3:0] <= 0;
      chan_tx_fifo_last <= 0;
      csn[31:0] <= 0;
      daq_data[63:0] <= 0;
      data_count[31:0] <= 0;
      ddr_start_addr[31:0] <= 0;
      ipbus_buf[31:0] <= 0;
      ipbus_res_last <= 0;
      num_chan_en[2:0] <= 0;
      sent_header <= 0;
      trig_num_buf[31:0] <= 0;
      end
    else begin
      state <= nextstate;
      burst_count[31:0] <= next_burst_count[31:0];
      chan_num_buf[31:0] <= next_chan_num_buf[31:0];
      chan_tag_filltype[31:0] <= next_chan_tag_filltype[31:0];
      chan_tx_fifo_dest[3:0] <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last <= next_chan_tx_fifo_last;
      csn[31:0] <= next_csn[31:0];
      daq_data[63:0] <= next_daq_data[63:0];
      data_count[31:0] <= next_data_count[31:0];
      ddr_start_addr[31:0] <= next_ddr_start_addr[31:0];
      ipbus_buf[31:0] <= next_ipbus_buf[31:0];
      ipbus_res_last <= next_ipbus_res_last;
      num_chan_en[2:0] <= next_num_chan_en[2:0];
      sent_header <= next_sent_header;
      trig_num_buf[31:0] <= next_trig_num_buf[31:0];
      end
  end

  // datapath sequential always block
  always @(posedge clk) begin
    if (rst) begin
      busy <= 0;
      chan_rx_fifo_ready <= 0;
      chan_tx_fifo_valid <= 0;
      daq_header <= 0;
      daq_trailer <= 0;
      daq_valid <= 0;
      ipbus_cmd_ready <= 0;
      ipbus_res_valid <= 0;
      read_fill_done <= 0;
      tm_fifo_ready <= 0;
    end
    else begin
      busy <= 1; // default
      chan_rx_fifo_ready <= 0; // default
      chan_tx_fifo_valid <= 0; // default
      daq_header <= 0; // default
      daq_trailer <= 0; // default
      daq_valid <= 0; // default
      ipbus_cmd_ready <= 0; // default
      ipbus_res_valid <= 0; // default
      read_fill_done <= 0; // default
      tm_fifo_ready <= 0; // default
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]                       : begin
          busy <= 0;
        end
        nextstate[CHECK_CHAN_EN]              : begin
          ; // case must be complete for onehot
        end
        nextstate[CHECK_LAST]                 : begin
          ; // case must be complete for onehot
        end
        nextstate[GET_TRIG_NUM]               : begin
          tm_fifo_ready <= 1;
        end
        nextstate[READY_AMC13_TRAILER]        : begin
          ; // case must be complete for onehot
        end
        nextstate[READ_CHAN_BURST_COUNT]      : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA1]            : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DATA2]            : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_DDR_START_ADDR]   : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_RC]               : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_RSN]              : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_TAG_AND_FILLTYPE] : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHAN_TRIG_NUM]         : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_CHECKSUM]              : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_IPBUS_CMD]             : begin
          ipbus_cmd_ready <= 1;
        end
        nextstate[READ_IPBUS_RES]             : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_IPBUS_RSN]             : begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[SEND_AMC13_HEADER1]         : begin
          daq_header <= 1;
          daq_valid <= 1;
        end
        nextstate[SEND_AMC13_HEADER2]         : begin
          daq_valid <= 1;
        end
        nextstate[SEND_AMC13_TRAILER]         : begin
          daq_trailer <= 1;
          daq_valid <= 1;
          read_fill_done <= 1;
        end
        nextstate[SEND_CHAN_CC]               : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_CHAN_CSN]              : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_CHAN_DATA]             : begin
          daq_valid <= 1;
        end
        nextstate[SEND_CHAN_HEADER]           : begin
          daq_valid <= 1;
        end
        nextstate[SEND_CHAN_HEADER2]          : begin
          daq_valid <= 1;
        end
        nextstate[SEND_IPBUS_CMD]             : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_IPBUS_CSN]             : begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_IPBUS_RES]             : begin
          ipbus_res_valid <= 1;
        end
        nextstate[STORE_CHAN_TAG_AND_FILLTYPE]: begin
          ; // case must be complete for onehot
        end
      endcase
    end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [215:0] statename;
  always @* begin
    case (1'b1)
      state[IDLE]                       :
        statename = "IDLE";
      state[CHECK_CHAN_EN]              :
        statename = "CHECK_CHAN_EN";
      state[CHECK_LAST]                 :
        statename = "CHECK_LAST";
      state[GET_TRIG_NUM]               :
        statename = "GET_TRIG_NUM";
      state[READY_AMC13_TRAILER]        :
        statename = "READY_AMC13_TRAILER";
      state[READ_CHAN_BURST_COUNT]      :
        statename = "READ_CHAN_BURST_COUNT";
      state[READ_CHAN_DATA1]            :
        statename = "READ_CHAN_DATA1";
      state[READ_CHAN_DATA2]            :
        statename = "READ_CHAN_DATA2";
      state[READ_CHAN_DDR_START_ADDR]   :
        statename = "READ_CHAN_DDR_START_ADDR";
      state[READ_CHAN_RC]               :
        statename = "READ_CHAN_RC";
      state[READ_CHAN_RSN]              :
        statename = "READ_CHAN_RSN";
      state[READ_CHAN_TAG_AND_FILLTYPE] :
        statename = "READ_CHAN_TAG_AND_FILLTYPE";
      state[READ_CHAN_TRIG_NUM]         :
        statename = "READ_CHAN_TRIG_NUM";
      state[READ_CHECKSUM]              :
        statename = "READ_CHECKSUM";
      state[READ_IPBUS_CMD]             :
        statename = "READ_IPBUS_CMD";
      state[READ_IPBUS_RES]             :
        statename = "READ_IPBUS_RES";
      state[READ_IPBUS_RSN]             :
        statename = "READ_IPBUS_RSN";
      state[SEND_AMC13_HEADER1]         :
        statename = "SEND_AMC13_HEADER1";
      state[SEND_AMC13_HEADER2]         :
        statename = "SEND_AMC13_HEADER2";
      state[SEND_AMC13_TRAILER]         :
        statename = "SEND_AMC13_TRAILER";
      state[SEND_CHAN_CC]               :
        statename = "SEND_CHAN_CC";
      state[SEND_CHAN_CSN]              :
        statename = "SEND_CHAN_CSN";
      state[SEND_CHAN_DATA]             :
        statename = "SEND_CHAN_DATA";
      state[SEND_CHAN_HEADER]           :
        statename = "SEND_CHAN_HEADER";
      state[SEND_CHAN_HEADER2]          :
        statename = "SEND_CHAN_HEADER2";
      state[SEND_IPBUS_CMD]             :
        statename = "SEND_IPBUS_CMD";
      state[SEND_IPBUS_CSN]             :
        statename = "SEND_IPBUS_CSN";
      state[SEND_IPBUS_RES]             :
        statename = "SEND_IPBUS_RES";
      state[STORE_CHAN_TAG_AND_FILLTYPE]:
        statename = "STORE_CHAN_TAG_AND_FILLTYPE";
      default                    :
        statename = "XXXXXXXXXXXXXXXXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

