
// Created by fizzim.pl version $Revision: 4.44 on 2014:07:07 at 19:49:22 (www.fizzim.com)

module test (
  output wire chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg chan_tx_fifo_dest,
  output wire chan_tx_fifo_last,
  output wire chan_tx_fifo_valid,
  input wire [31:0] chan_rx_fifo_data,
  input wire chan_rx_fifo_last,
  input wire chan_rx_fifo_valid,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire rst,
  input wire trigger 
);

  // state bits
  parameter 
  IDLE            = 6'b000000, // extra=000 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  READ_RD_RC      = 6'b000001, // extra=000 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_RD_RSN     = 6'b001001, // extra=001 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_RD_VAL     = 6'b010001, // extra=010 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_WR_RC      = 6'b011001, // extra=011 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  READ_WR_RSN     = 6'b100001, // extra=100 chan_tx_fifo_valid=0 chan_tx_fifo_last=0 chan_rx_fifo_ready=1 
  SEND_RD_CC      = 6'b000100, // extra=000 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_RD_CSN     = 6'b001100, // extra=001 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_RD_REG_NUM = 6'b000110, // extra=000 chan_tx_fifo_valid=1 chan_tx_fifo_last=1 chan_rx_fifo_ready=0 
  SEND_WR_CC      = 6'b010100, // extra=010 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_WR_CSN     = 6'b011100, // extra=011 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 
  SEND_WR_DATA    = 6'b001110, // extra=001 chan_tx_fifo_valid=1 chan_tx_fifo_last=1 chan_rx_fifo_ready=0 
  SEND_WR_REG_NUM = 6'b100100; // extra=100 chan_tx_fifo_valid=1 chan_tx_fifo_last=0 chan_rx_fifo_ready=0 

  reg [5:0] state;
  reg [5:0] nextstate;
  reg [3:0] count;
  reg [3:0] next_count;

  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    chan_tx_fifo_data[31:0] = 32'h00000000; // default
    chan_tx_fifo_dest = 0; // default
    next_count[3:0] = count[3:0];
    case (state)
      IDLE           : begin
        if (trigger) begin
          nextstate = SEND_WR_CSN;
        end
      end
      READ_RD_RC     : begin
        if (chan_rx_fifo_valid) begin
          nextstate = READ_RD_VAL;
        end
      end
      READ_RD_RSN    : begin
        if (chan_rx_fifo_valid) begin
          nextstate = READ_RD_RC;
        end
      end
      READ_RD_VAL    : begin
        if (chan_rx_fifo_valid && count==0) begin
          nextstate = IDLE;
        end
        else if (chan_rx_fifo_valid) begin
          nextstate = SEND_RD_CSN;
          next_count[3:0] = count[3:0]-1;
        end
      end
      READ_WR_RC     : begin
        if (chan_rx_fifo_valid && count==4) begin
          nextstate = SEND_RD_CSN;
        end
        else if (chan_rx_fifo_valid) begin
          nextstate = SEND_WR_CSN;
          next_count[3:0] = count[3:0]+1;
        end
      end
      READ_WR_RSN    : begin
        if (chan_rx_fifo_valid) begin
          nextstate = READ_WR_RC;
        end
      end
      SEND_RD_CC     : begin
        chan_tx_fifo_data[31:0] = 32'h2;
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_RD_REG_NUM;
        end
      end
      SEND_RD_CSN    : begin
        chan_tx_fifo_data[31:0] = {28'h0000000,count[3:0]};
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_RD_CC;
        end
      end
      SEND_RD_REG_NUM: begin
        chan_tx_fifo_data[31:0] = {28'h0000001,count[3:0]};
        if (chan_tx_fifo_ready) begin
          nextstate = READ_RD_RSN;
        end
      end
      SEND_WR_CC     : begin
        chan_tx_fifo_data[31:0] = 32'h3;
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_WR_REG_NUM;
        end
      end
      SEND_WR_CSN    : begin
        chan_tx_fifo_data[31:0] = {28'h0000000,count[3:0]};
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_WR_CC;
        end
      end
      SEND_WR_DATA   : begin
        chan_tx_fifo_data[31:0] = {28'hbadf00d,count[3:0]};
        if (chan_tx_fifo_ready) begin
          nextstate = READ_WR_RSN;
        end
      end
      SEND_WR_REG_NUM: begin
        chan_tx_fifo_data[31:0] = {28'h0000001,count[3:0]};
        if (chan_tx_fifo_ready) begin
          nextstate = SEND_WR_DATA;
        end
      end
    endcase
  end

  // Assign reg'd outputs to state bits
  assign chan_rx_fifo_ready = state[0];
  assign chan_tx_fifo_last = state[1];
  assign chan_tx_fifo_valid = state[2];

  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      count[3:0] <= 0;
      end
    else begin
      state <= nextstate;
      count[3:0] <= next_count[3:0];
      end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [119:0] statename;
  always @* begin
    case (state)
      IDLE           :
        statename = "IDLE";
      READ_RD_RC     :
        statename = "READ_RD_RC";
      READ_RD_RSN    :
        statename = "READ_RD_RSN";
      READ_RD_VAL    :
        statename = "READ_RD_VAL";
      READ_WR_RC     :
        statename = "READ_WR_RC";
      READ_WR_RSN    :
        statename = "READ_WR_RSN";
      SEND_RD_CC     :
        statename = "SEND_RD_CC";
      SEND_RD_CSN    :
        statename = "SEND_RD_CSN";
      SEND_RD_REG_NUM:
        statename = "SEND_RD_REG_NUM";
      SEND_WR_CC     :
        statename = "SEND_WR_CC";
      SEND_WR_CSN    :
        statename = "SEND_WR_CSN";
      SEND_WR_DATA   :
        statename = "SEND_WR_DATA";
      SEND_WR_REG_NUM:
        statename = "SEND_WR_REG_NUM";
      default        :
        statename = "XXXXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

