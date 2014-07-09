
// Created by fizzim.pl version 4.42 on 2014:07:09 at 09:36:37 (www.fizzim.com)

module commandManager (
  output wire chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg [3:0] chan_tx_fifo_dest,
  output reg chan_tx_fifo_last,
  output wire chan_tx_fifo_valid,
  output wire ipbus_cmd_ready,
  output reg [31:0] ipbus_resp_data,
  output reg ipbus_resp_last,
  output wire ipbus_resp_valid,
  input wire [31:0] chan_rx_fifo_data,
  input wire chan_rx_fifo_last,
  input wire chan_rx_fifo_valid,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire [31:0] ipbus_cmd_data,
  input wire [3:0] ipbus_cmd_dest,
  input wire ipbus_cmd_last,
  input wire ipbus_cmd_valid,
  input wire ipbus_resp_ready,
  input wire rst 
);
  
  // state bits
  parameter 
  IDLE       = 5'b00000, // extra=0 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_rx_fifo_ready=0 
  CHECK_LAST = 5'b10000, // extra=1 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_rx_fifo_ready=0 
  READ_CMD   = 5'b00100, // extra=0 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_rx_fifo_ready=0 
  READ_RESP  = 5'b00001, // extra=0 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_rx_fifo_ready=1 
  READ_RSN   = 5'b10001, // extra=1 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_rx_fifo_ready=1 
  SEND_CMD   = 5'b00010, // extra=0 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_rx_fifo_ready=0 
  SEND_CSN   = 5'b10010, // extra=1 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_rx_fifo_ready=0 
  SEND_RESP  = 5'b01000; // extra=0 ipbus_resp_valid=1 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_rx_fifo_ready=0 
  
  reg [4:0] state;
  reg [4:0] nextstate;
  reg [31:0] buffer;
  reg [31:0] csn;
  reg [31:0] next_buffer;
  reg [3:0] next_chan_tx_fifo_dest;
  reg next_chan_tx_fifo_last;
  reg [31:0] next_csn;
  reg next_ipbus_resp_last;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    chan_tx_fifo_data[31:0] = 0; // default
    ipbus_resp_data[31:0] = 0; // default
    next_buffer[31:0] = buffer[31:0];
    next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last = chan_tx_fifo_last;
    next_csn[31:0] = csn[31:0];
    next_ipbus_resp_last = ipbus_resp_last;
    case (state)
      IDLE      : begin
        if (ipbus_cmd_valid) begin
          nextstate = SEND_CSN;
          next_chan_tx_fifo_last = 0;
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
        end
      end
      CHECK_LAST: begin
        begin
          nextstate = SEND_CMD;
          next_chan_tx_fifo_last = ipbus_cmd_last;
        end
      end
      READ_CMD  : begin
        if (ipbus_cmd_valid) begin
          nextstate = CHECK_LAST;
          next_buffer[31:0] = ipbus_cmd_data[31:0];
        end
      end
      READ_RESP : begin
        if (chan_rx_fifo_valid) begin
          nextstate = SEND_RESP;
          next_buffer[31:0] = chan_rx_fifo_data[31:0];
          next_ipbus_resp_last = chan_rx_fifo_last;
        end
      end
      READ_RSN  : begin
        if (chan_rx_fifo_valid) begin
          nextstate = READ_RESP;
        end
      end
      SEND_CMD  : begin
        chan_tx_fifo_data[31:0] = buffer[31:0];
        if (chan_tx_fifo_ready && chan_tx_fifo_last) begin
          nextstate = READ_RSN;
        end
        else if (chan_tx_fifo_ready) begin
          nextstate = READ_CMD;
        end
      end
      SEND_CSN  : begin
        chan_tx_fifo_data[31:0] = csn[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = READ_CMD;
        end
      end
      SEND_RESP : begin
        ipbus_resp_data[31:0] = buffer[31:0];
        if (ipbus_resp_ready && ipbus_resp_last) begin
          nextstate = IDLE;
          next_csn[31:0] = csn[31:0]+1;
        end
        else if (ipbus_resp_ready) begin
          nextstate = READ_RESP;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign chan_rx_fifo_ready = state[0];
  assign chan_tx_fifo_valid = state[1];
  assign ipbus_cmd_ready = state[2];
  assign ipbus_resp_valid = state[3];
  
  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      buffer[31:0] <= 0;
      chan_tx_fifo_dest[3:0] <= 0;
      chan_tx_fifo_last <= 0;
      csn[31:0] <= 0;
      ipbus_resp_last <= 0;
      end
    else begin
      state <= nextstate;
      buffer[31:0] <= next_buffer[31:0];
      chan_tx_fifo_dest[3:0] <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last <= next_chan_tx_fifo_last;
      csn[31:0] <= next_csn[31:0];
      ipbus_resp_last <= next_ipbus_resp_last;
      end
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [79:0] statename;
  always @* begin
    case (state)
      IDLE      :
        statename = "IDLE";
      CHECK_LAST:
        statename = "CHECK_LAST";
      READ_CMD  :
        statename = "READ_CMD";
      READ_RESP :
        statename = "READ_RESP";
      READ_RSN  :
        statename = "READ_RSN";
      SEND_CMD  :
        statename = "SEND_CMD";
      SEND_CSN  :
        statename = "SEND_CSN";
      SEND_RESP :
        statename = "SEND_RESP";
      default   :
        statename = "XXXXXXXXXX";
    endcase
  end
  `endif

endmodule

