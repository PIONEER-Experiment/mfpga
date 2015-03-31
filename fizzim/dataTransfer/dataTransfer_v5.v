
// Created by fizzim.pl version $Revision: 4.44 on 2014:06:17 at 11:18:40 (www.fizzim.com)

module simpleDataTransfer (
  output reg [63:0] daq_data,
  output wire daq_header,
  output wire daq_trailer,
  output wire daq_valid,
  output wire fifo_ready,
  input wire clk,
  input wire daq_ready,
  input wire [31:0] fifo_data,
  input wire fifo_last,
  input wire fifo_valid,
  input wire rst 
);

  // state bits
  parameter 
  IDLE       = 6'b000000, // extra=00 fifo_ready=0 daq_valid=0 daq_trailer=0 daq_header=0 
  DATA1      = 6'b001000, // extra=00 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  DATA2      = 6'b000100, // extra=00 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 
  HEADER1    = 6'b000101, // extra=00 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=1 
  HEADER2    = 6'b010100, // extra=01 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 
  LAST_DATA1 = 6'b100100, // extra=10 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 
  LAST_DATA2 = 6'b110100, // extra=11 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 
  READY_DATA = 6'b011000, // extra=01 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  TRAILER    = 6'b000110; // extra=00 fifo_ready=0 daq_valid=1 daq_trailer=1 daq_header=0 

  reg [5:0] state;
  reg [5:0] nextstate;
  reg [23:0] trig_num;
  reg [63:0] next_daq_data;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    next_daq_data[63:0] = daq_data[63:0];
    next_trig_num[23:0] = trig_num[23:0];
    case (state)
      IDLE      : begin
        if (fifo_valid) begin
          nextstate = HEADER1;
          next_daq_data[63:0] = {{8'h00,trig_num[23:0]+1},32'h00000008};
          next_trig_num[23:0] = trig_num[23:0]+1;
        end
      end
      DATA1     : begin
        if (fifo_valid && fifo_last) begin
          nextstate = LAST_DATA2;
          next_daq_data[63:0] = {daq_data[63:32],fifo_data[31:0]};
        end
        else if (fifo_valid) begin
          nextstate = DATA2;
          next_daq_data[63:0] = {daq_data[63:32],fifo_data[31:0]};
        end
      end
      DATA2     : begin
        if (daq_ready) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 0;
        end
      end
      HEADER1   : begin
        if (daq_ready) begin
          nextstate = HEADER2;
          next_daq_data[63:0] = 64'h000000000000FFFF;
        end
      end
      HEADER2   : begin
        if (daq_ready) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 0;
        end
      end
      LAST_DATA1: begin
        if (daq_ready) begin
          nextstate = TRAILER;
          next_daq_data[63:0] = {32'h00000000,{trig_num[1:0],24'h000008}};
        end
      end
      LAST_DATA2: begin
        if (daq_ready) begin
          nextstate = TRAILER;
          next_daq_data[63:0] = {32'h00000000,{trig_num[1:0],24'h000008}};
        end
      end
      READY_DATA: begin
        if (fifo_valid && fifo_last) begin
          nextstate = LAST_DATA1;
          next_daq_data[63:0] = {fifo_data[31:0],32'h00000000};
        end
        else if (fifo_valid) begin
          nextstate = DATA1;
          next_daq_data[63:0] = {fifo_data[31:0],32'h00000000};
        end
      end
      TRAILER   : begin
        if (daq_ready) begin
          nextstate = IDLE;
          next_daq_data[63:0] = 0;
        end
      end
    endcase
  end

  // Assign reg'd outputs to state bits
  assign daq_header = state[0];
  assign daq_trailer = state[1];
  assign daq_valid = state[2];
  assign fifo_ready = state[3];

  // sequential always block
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      daq_data[63:0] <= 0;
      trig_num[23:0] <= 0;
      end
    else begin
      state <= nextstate;
      daq_data[63:0] <= next_daq_data[63:0];
      trig_num[23:0] <= next_trig_num[23:0];
      end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [79:0] statename;
  always @* begin
    case (state)
      IDLE      :
        statename = "IDLE";
      DATA1     :
        statename = "DATA1";
      DATA2     :
        statename = "DATA2";
      HEADER1   :
        statename = "HEADER1";
      HEADER2   :
        statename = "HEADER2";
      LAST_DATA1:
        statename = "LAST_DATA1";
      LAST_DATA2:
        statename = "LAST_DATA2";
      READY_DATA:
        statename = "READY_DATA";
      TRAILER   :
        statename = "TRAILER";
      default   :
        statename = "XXXXXXXXXX";
    endcase
  end
  `endif

endmodule

