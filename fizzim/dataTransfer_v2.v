
// Created by fizzim.pl version 4.42 on 2014:06:10 at 09:55:16 (www.fizzim.com)

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
  READY_HEADER  = 7'b0001000, // extra=000 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  DATA1         = 7'b0011000, // extra=001 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  DATA2         = 7'b0000100, // extra=000 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=0 
  HEADER1       = 7'b0101000, // extra=010 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  HEADER2       = 7'b0000101, // extra=000 fifo_ready=0 daq_valid=1 daq_trailer=0 daq_header=1 
  READY_DATA    = 7'b0111000, // extra=011 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  READY_TRAILER = 7'b1001000, // extra=100 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  TRAILER1      = 7'b1011000, // extra=101 fifo_ready=1 daq_valid=0 daq_trailer=0 daq_header=0 
  TRAILER2      = 7'b0000110; // extra=000 fifo_ready=0 daq_valid=1 daq_trailer=1 daq_header=0 
  
  reg [6:0] state;
  reg [6:0] nextstate;
  reg [63:0] next_daq_data;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    next_daq_data[63:0] = daq_data[63:0];
    case (state)
      READY_HEADER : begin
        if (fifo_valid) begin
          nextstate = HEADER1;
          next_daq_data[63:0] = {fifo_data[31:0],32'h00000000};
        end
      end
      DATA1        : begin
        if (fifo_valid) begin
          nextstate = DATA2;
          next_daq_data[63:0] = {daq_data[63:32],fifo_data[31:0]};
        end
      end
      DATA2        : begin
        // Warning P3: State DATA2 has multiple exit transitions, and transition trans5 has no defined priority 
        // Warning P3: State DATA2 has multiple exit transitions, and transition trans6 has no defined priority 
        if (daq_ready && !fifo_last) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 2;
        end
        else if (daq_ready && fifo_last) begin
          nextstate = READY_TRAILER;
          next_daq_data[63:0] = 3;
        end
      end
      HEADER1      : begin
        if (fifo_valid) begin
          nextstate = HEADER2;
          next_daq_data[63:0] = {daq_data[63:32],fifo_data[31:0]};
        end
      end
      HEADER2      : begin
        if (daq_ready) begin
          nextstate = READY_DATA;
          next_daq_data[63:0] = 1;
        end
      end
      READY_DATA   : begin
        if (fifo_valid) begin
          nextstate = DATA1;
          next_daq_data[63:0] = {fifo_data[31:0],32'h00000000};
        end
      end
      READY_TRAILER: begin
        if (fifo_valid) begin
          nextstate = TRAILER1;
          next_daq_data[63:0] = {fifo_data[31:0],32'h00000000};
        end
      end
      TRAILER1     : begin
        if (fifo_valid) begin
          nextstate = TRAILER2;
          next_daq_data[63:0] = {daq_data[63:32],fifo_data[31:0]};
        end
      end
      TRAILER2     : begin
        if (daq_ready) begin
          nextstate = READY_HEADER;
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
      state <= READY_HEADER;
      daq_data[63:0] <= 0;
      end
    else begin
      state <= nextstate;
      daq_data[63:0] <= next_daq_data[63:0];
      end
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [103:0] statename;
  always @* begin
    case (state)
      READY_HEADER :
        statename = "READY_HEADER";
      DATA1        :
        statename = "DATA1";
      DATA2        :
        statename = "DATA2";
      HEADER1      :
        statename = "HEADER1";
      HEADER2      :
        statename = "HEADER2";
      READY_DATA   :
        statename = "READY_DATA";
      READY_TRAILER:
        statename = "READY_TRAILER";
      TRAILER1     :
        statename = "TRAILER1";
      TRAILER2     :
        statename = "TRAILER2";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

