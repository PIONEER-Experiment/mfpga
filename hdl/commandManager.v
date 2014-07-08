
// Created by fizzim.pl version 4.42 on 2014:07:08 at 11:16:25 (www.fizzim.com)

module commandManager (
  output reg [31:0] chan_tx_fifo_data,
  output reg [3:0] chan_tx_fifo_dest,
  output wire chan_tx_fifo_last,
  output wire chan_tx_fifo_valid,
  output wire ipbus_ready,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire [31:0] ipbus_data,
  input wire [3:0] ipbus_dest,
  input wire ipbus_last,
  input wire ipbus_valid,
  input wire rst 
);
  
  // state bits
  parameter 
  IDLE         = 6'b000100, // extra=000 ipbus_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 
  READ_CC      = 6'b001100, // extra=001 ipbus_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 
  READ_LAST    = 6'b010100, // extra=010 ipbus_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 
  READ_REG_NUM = 6'b011100, // extra=011 ipbus_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 
  READ_VALUE   = 6'b100100, // extra=100 ipbus_ready=1 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 
  SEND_CC      = 6'b000010, // extra=000 ipbus_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 
  SEND_CSN     = 6'b001010, // extra=001 ipbus_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 
  SEND_REG_NUM = 6'b010010, // extra=010 ipbus_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 
  SEND_VALUE   = 6'b000011; // extra=000 ipbus_ready=0 chan_tx_fifo_valid=1 chan_tx_fifo_last=1 
  
  (* mark_debug = "true" *) reg [5:0] state;
  reg [5:0] nextstate;
  reg [31:0] cc;
  reg [31:0] csn;
  reg [31:0] reg_num;
  reg [31:0] value;
  reg [31:0] next_cc;
  reg [3:0] next_chan_tx_fifo_dest;
  reg [31:0] next_csn;
  reg [31:0] next_reg_num;
  reg [31:0] next_value;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    chan_tx_fifo_data[31:0] = 0; // default
    next_cc[31:0] = cc[31:0];
    next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0];
    next_csn[31:0] = csn[31:0];
    next_reg_num[31:0] = reg_num[31:0];
    next_value[31:0] = value[31:0];
    case (state)
      IDLE        : begin
        if (ipbus_valid) begin
          nextstate = READ_CC;
          next_cc[31:0] = ipbus_data[31:0];
          next_chan_tx_fifo_dest[3:0] = ipbus_dest[3:0];
        end
      end
      READ_CC     : begin
        if (ipbus_valid) begin
          nextstate = READ_REG_NUM;
          next_reg_num[31:0] = ipbus_data[31:0];
        end
      end
      READ_LAST   : begin
        if (!ipbus_valid) begin
          nextstate = SEND_CSN;
        end
      end
      READ_REG_NUM: begin
        if (ipbus_valid) begin
          nextstate = READ_VALUE;
          next_value[31:0] = ipbus_data[31:0];
        end
      end
      READ_VALUE  : begin
        if (ipbus_valid) begin
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
      SEND_VALUE  : begin
        chan_tx_fifo_data[31:0] = value[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate = IDLE;
          next_cc[31:0] = 0;
          next_reg_num[31:0] = 0;
          next_chan_tx_fifo_dest[3:0] = 0;
          next_csn[31:0] = csn[31:0]+1;
          next_value[31:0] = 0;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign chan_tx_fifo_last = state[0];
  assign chan_tx_fifo_valid = state[1];
  assign ipbus_ready = state[2];
  
  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      cc[31:0] <= 0;
      chan_tx_fifo_dest[3:0] <= 0;
      csn[31:0] <= 0;
      reg_num[31:0] <= 0;
      value[31:0] <= 0;
      end
    else begin
      state <= nextstate;
      cc[31:0] <= next_cc[31:0];
      chan_tx_fifo_dest[3:0] <= next_chan_tx_fifo_dest[3:0];
      csn[31:0] <= next_csn[31:0];
      reg_num[31:0] <= next_reg_num[31:0];
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
      READ_VALUE  :
        statename = "READ_VALUE";
      SEND_CC     :
        statename = "SEND_CC";
      SEND_CSN    :
        statename = "SEND_CSN";
      SEND_REG_NUM:
        statename = "SEND_REG_NUM";
      SEND_VALUE  :
        statename = "SEND_VALUE";
      default     :
        statename = "XXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

