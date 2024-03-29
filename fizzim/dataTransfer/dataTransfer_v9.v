
// Created by fizzim.pl version 4.42 on 2014:07:01 at 18:08:54 (www.fizzim.com)

module dataTransferManager (
  output wire chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg chan_tx_fifo_dest,
  output wire chan_tx_fifo_last,
  output wire chan_tx_fifo_valid,
  output reg [63:0] daq_data,
  output wire daq_header,
  output wire daq_trailer,
  output wire daq_valid,
  output wire tm_fifo_ready,
  input wire [31:0] chan_rx_fifo_data,
  input wire chan_rx_fifo_last,
  input wire chan_rx_fifo_valid,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire daq_ready,
  input wire rst,
  input wire [23:0] tm_fifo_data,
  input wire tm_fifo_valid 
);
  
  // state bits
  parameter 
  IDLE          = 9'b001000000, // extra=00 tm_fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  DATA1         = 9'b000000001, // extra=00 tm_fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  DATA2         = 9'b000100000, // extra=00 tm_fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  HAS_FILLNUM   = 9'b000000000, // extra=00 tm_fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  HEADER1       = 9'b000101000, // extra=00 tm_fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  HEADER2       = 9'b010100000, // extra=01 tm_fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  LAST_DATA1    = 9'b100100000, // extra=10 tm_fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  LAST_DATA2    = 9'b110100000, // extra=11 tm_fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READY_DATA    = 9'b010000001, // extra=01 tm_fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  SEND_COMMAND  = 9'b000000110, // extra=00 tm_fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=1 chan_rx_fifo_ready=0 
  TRAILER       = 9'b000110000, // extra=00 tm_fifo_ready=0 daq_valid=1 daq_trailer=1 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  WAIT_RESPONSE = 9'b100000001; // extra=10 tm_fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  
  reg [8:0] state;
  reg [8:0] nextstate;
  reg chan_num;
  reg [23:0] fill_num;
  reg next_chan_num;
  reg [63:0] next_daq_data;
  reg [23:0] next_fill_num;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    chan_tx_fifo_data[31:0] = 32'h00000000; // default
    chan_tx_fifo_dest = 0; // default
    next_chan_num = chan_num;
    next_daq_data[63:0] = daq_data[63:0];
    next_fill_num[23:0] = fill_num[23:0];
    case (state)
      IDLE         : begin
        if (tm_fifo_valid) begin
          nextstate = HAS_FILLNUM;
          next_fill_num[23:0] = tm_fifo_data[23:0];
        end
      end
      DATA1        : begin
        if (chan_rx_fifo_valid && chan_rx_fifo_last) begin
          nextstate = LAST_DATA2;
          next_daq_data[63:0] = {daq_data[63:32],chan_rx_fifo_data[31:0]};
        end
        else if (chan_rx_fifo_valid) begin
          nextstate = DATA2;
          next_daq_data[63:0] = {daq_data[63:32],chan_rx_fifo_data[31:0]};
        end
      end
      DATA2        : begin
        if (daq_ready) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 0;
        end
      end
      HAS_FILLNUM  : begin
        begin
          nextstate = HEADER1;
          next_daq_data[63:0] = {{8'h00,fill_num[23:0]},32'h00000008};
        end
      end
      HEADER1      : begin
        if (daq_ready) begin
          nextstate = HEADER2;
          next_daq_data[63:0] = 64'h000000000000FFFF;
        end
      end
      HEADER2      : begin
        if (daq_ready) begin
          nextstate = SEND_COMMAND;
        end
      end
      LAST_DATA1   : begin
        if (daq_ready && chan_num==1) begin
          nextstate = TRAILER;
          next_daq_data[63:0] = {32'h00000000,{fill_num[1:0],24'h000008}};
        end
        else if (daq_ready) begin
          nextstate = SEND_COMMAND;
          next_daq_data[63:0] = 0;
          next_chan_num = chan_num+1;
        end
      end
      LAST_DATA2   : begin
        if (daq_ready && chan_num==1) begin
          nextstate = TRAILER;
          next_daq_data[63:0] = {32'h00000000,{fill_num[1:0],24'h000008}};
        end
        else if (daq_ready) begin
          nextstate = SEND_COMMAND;
          next_daq_data[63:0] = 0;
          next_chan_num = chan_num+1;
        end
      end
      READY_DATA   : begin
        if (chan_rx_fifo_valid && chan_rx_fifo_last) begin
          nextstate = LAST_DATA1;
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0],32'h00000000};
        end
        else if (chan_rx_fifo_valid) begin
          nextstate = DATA1;
          next_daq_data[63:0] = {chan_rx_fifo_data[31:0],32'h00000000};
        end
      end
      SEND_COMMAND : begin
        chan_tx_fifo_data[31:0] = 32'hbaadf00d;
        chan_tx_fifo_dest = chan_num;
        if (chan_tx_fifo_ready) begin
          nextstate = WAIT_RESPONSE;
        end
      end
      TRAILER      : begin
        if (daq_ready) begin
          nextstate = IDLE;
          next_daq_data[63:0] = 0;
          next_chan_num = 0;
        end
      end
      WAIT_RESPONSE: begin
        if (chan_rx_fifo_valid) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 0;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign chan_rx_fifo_ready = state[0];
  assign chan_tx_fifo_last = state[1];
  assign chan_tx_fifo_valid = state[2];
  assign daq_header = state[3];
  assign daq_trailer = state[4];
  assign daq_valid = state[5];
  assign tm_fifo_ready = state[6];
  
  // sequential always block
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      chan_num <= 0;
      daq_data[63:0] <= 0;
      fill_num[23:0] <= 0;
      end
    else begin
      state <= nextstate;
      chan_num <= next_chan_num;
      daq_data[63:0] <= next_daq_data[63:0];
      fill_num[23:0] <= next_fill_num[23:0];
      end
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [103:0] statename;
  always @* begin
    case (state)
      IDLE         :
        statename = "IDLE";
      DATA1        :
        statename = "DATA1";
      DATA2        :
        statename = "DATA2";
      HAS_FILLNUM  :
        statename = "HAS_FILLNUM";
      HEADER1      :
        statename = "HEADER1";
      HEADER2      :
        statename = "HEADER2";
      LAST_DATA1   :
        statename = "LAST_DATA1";
      LAST_DATA2   :
        statename = "LAST_DATA2";
      READY_DATA   :
        statename = "READY_DATA";
      SEND_COMMAND :
        statename = "SEND_COMMAND";
      TRAILER      :
        statename = "TRAILER";
      WAIT_RESPONSE:
        statename = "WAIT_RESPONSE";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

