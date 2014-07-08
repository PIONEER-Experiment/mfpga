
// Created by fizzim.pl version 4.42 on 2014:07:08 at 15:27:57 (www.fizzim.com)

module commandManager (
  output wire chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg [3:0] chan_tx_fifo_dest,
  output wire chan_tx_fifo_last,
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
  IDLE         = 8'b00001000, // extra=000 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READ_CC      = 8'b00101000, // extra=001 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READ_LAST    = 8'b01001000, // extra=010 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READ_REG_NUM = 8'b01101000, // extra=011 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READ_RESP    = 8'b00000001, // extra=000 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_RSN     = 8'b00100001, // extra=001 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_VALUE   = 8'b10001000, // extra=100 ipbus_resp_valid=0 ipbus_cmd_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_CC      = 8'b00000100, // extra=000 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_CSN     = 8'b00100100, // extra=001 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_REG_NUM = 8'b01000100, // extra=010 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_RESP    = 8'b00010000, // extra=000 ipbus_resp_valid=1 ipbus_cmd_ready=0 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_VALUE   = 8'b00000110; // extra=000 ipbus_resp_valid=0 ipbus_cmd_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=1 chan_rx_fifo_ready=0 
  
  reg [7:0] state;
  reg [7:0] nextstate;
  reg [31:0] cc;
  reg [31:0] csn;
  reg [31:0] reg_num;
  reg [31:0] resp;
  reg [31:0] value;
  reg [31:0] next_cc;
  reg [3:0] next_chan_tx_fifo_dest;
  reg [31:0] next_csn;
  reg next_ipbus_resp_last;
  reg [31:0] next_reg_num;
  reg [31:0] next_resp;
  reg [31:0] next_value;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    chan_tx_fifo_data[31:0] = 0; // default
    ipbus_resp_data[31:0] = 0; // default
    next_cc[31:0] = cc[31:0];
    next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0];
    next_csn[31:0] = csn[31:0];
    next_ipbus_resp_last = ipbus_resp_last;
    next_reg_num[31:0] = reg_num[31:0];
    next_resp[31:0] = resp[31:0];
    next_value[31:0] = value[31:0];
    case (state)
      IDLE        : begin
        if (ipbus_cmd_valid) begin
          nextstate = READ_CC;
          next_cc[31:0] = ipbus_cmd_data[31:0];
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
        end
      end
      READ_CC     : begin
        if (ipbus_cmd_valid) begin
          nextstate = READ_REG_NUM;
          next_reg_num[31:0] = ipbus_cmd_data[31:0];
        end
      end
      READ_LAST   : begin
        if (!ipbus_cmd_valid) begin
          nextstate = SEND_CSN;
        end
      end
      READ_REG_NUM: begin
        if (ipbus_cmd_valid) begin
          nextstate = READ_VALUE;
          next_value[31:0] = ipbus_cmd_data[31:0];
        end
      end
      READ_RESP   : begin
        if (chan_rx_fifo_valid) begin
          nextstate = SEND_RESP;
          next_resp[31:0] = chan_rx_fifo_data[31:0];
          next_ipbus_resp_last = chan_rx_fifo_last;
        end
      end
      READ_RSN    : begin
        if (chan_rx_fifo_valid) begin
          nextstate = READ_RESP;
        end
      end
      READ_VALUE  : begin
        if (ipbus_cmd_valid) begin
          nextstate = READ_LAST;
        end
      end
      SEND_CC     : begin
        chan_tx_fifo_data[31:0] = cc[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_REG_NUM;
        end
      end
      SEND_CSN    : begin
        chan_tx_fifo_data[31:0] = csn[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_CC;
        end
      end
      SEND_REG_NUM: begin
        chan_tx_fifo_data[31:0] = reg_num[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_VALUE;
        end
      end
      SEND_RESP   : begin
        ipbus_resp_data[31:0] = resp[31:0];
        if (ipbus_resp_ready && ipbus_resp_last) begin
          nextstate = IDLE;
          next_cc[31:0] = 0;
          next_reg_num[31:0] = 0;
          next_chan_tx_fifo_dest[3:0] = 0;
          next_csn[31:0] = csn[31:0]+1;
          next_value[31:0] = 0;
        end
        else if (ipbus_resp_ready) begin
          nextstate = READ_RESP;
        end
      end
      SEND_VALUE  : begin
        chan_tx_fifo_data[31:0] = value[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = READ_RSN;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign chan_rx_fifo_ready = state[0];
  assign chan_tx_fifo_last = state[1];
  assign chan_tx_fifo_valid = state[2];
  assign ipbus_cmd_ready = state[3];
  assign ipbus_resp_valid = state[4];
  
  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      cc[31:0] <= 0;
      chan_tx_fifo_dest[3:0] <= 0;
      csn[31:0] <= 0;
      ipbus_resp_last <= 0;
      reg_num[31:0] <= 0;
      resp[31:0] <= 0;
      value[31:0] <= 0;
      end
    else begin
      state <= nextstate;
      cc[31:0] <= next_cc[31:0];
      chan_tx_fifo_dest[3:0] <= next_chan_tx_fifo_dest[3:0];
      csn[31:0] <= next_csn[31:0];
      ipbus_resp_last <= next_ipbus_resp_last;
      reg_num[31:0] <= next_reg_num[31:0];
      resp[31:0] <= next_resp[31:0];
      value[31:0] <= next_value[31:0];
      end
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [95:0] statename;
  always @* begin
    case (state)
      IDLE        :
        statename = "IDLE";
      READ_CC     :
        statename = "READ_CC";
      READ_LAST   :
        statename = "READ_LAST";
      READ_REG_NUM:
        statename = "READ_REG_NUM";
      READ_RESP   :
        statename = "READ_RESP";
      READ_RSN    :
        statename = "READ_RSN";
      READ_VALUE  :
        statename = "READ_VALUE";
      SEND_CC     :
        statename = "SEND_CC";
      SEND_CSN    :
        statename = "SEND_CSN";
      SEND_REG_NUM:
        statename = "SEND_REG_NUM";
      SEND_RESP   :
        statename = "SEND_RESP";
      SEND_VALUE  :
        statename = "SEND_VALUE";
      default     :
        statename = "XXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

