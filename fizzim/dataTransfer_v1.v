
// Created by fizzim.pl version 4.42 on 2014:06:09 at 16:33:36 (www.fizzim.com)

module simpleDataTransfer (
  output reg [63:0] data_out,
  output wire header_out,
  output wire ready_in,
  output wire trailer_out,
  output wire valid_out,
  input wire clk,
  input wire [31:0] data_in,
  input wire last_in,
  input wire ready_out,
  input wire rst,
  input wire valid_in 
);
  
  // state bits
  parameter 
  READY_HEADER  = 7'b0000010, // extra=000 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  DATA1         = 7'b0010010, // extra=001 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  DATA2         = 7'b0001000, // extra=000 valid_out=1 trailer_out=0 ready_in=0 header_out=0 
  HEADER1       = 7'b0100010, // extra=010 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  HEADER2       = 7'b0001001, // extra=000 valid_out=1 trailer_out=0 ready_in=0 header_out=1 
  READY_DATA    = 7'b0110010, // extra=011 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  READY_TRAILER = 7'b1000010, // extra=100 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  TRAILER1      = 7'b1010010, // extra=101 valid_out=0 trailer_out=0 ready_in=1 header_out=0 
  TRAILER2      = 7'b0001100; // extra=000 valid_out=1 trailer_out=1 ready_in=0 header_out=0 
  
  reg [6:0] state;
  reg [6:0] nextstate;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    data_out[63:0] = data_out[63:0]; // default
    case (state)
      READY_HEADER : begin
        if (valid_in) begin
          nextstate = HEADER1;
          data_out[63:0] = {data_in[31:0],32'h00000000};
        end
      end
      DATA1        : begin
        if (valid_in) begin
          nextstate = DATA2;
          data_out[63:0] = {data_out[63:32],data_in[31:0]};
        end
      end
      DATA2        : begin
        // Warning P3: State DATA2 has multiple exit transitions, and transition trans5 has no defined priority 
        // Warning P3: State DATA2 has multiple exit transitions, and transition trans6 has no defined priority 
        if (ready_out && !last_in) begin
          nextstate = READY_DATA;
          data_out[63:0] = 0;
        end
        else if (ready_out && last_in) begin
          nextstate = READY_TRAILER;
          data_out[63:0] = 0;
        end
      end
      HEADER1      : begin
        if (valid_in) begin
          nextstate = HEADER2;
          data_out[63:0] = {data_out[63:32],data_in[31:0]};
        end
      end
      HEADER2      : begin
        if (ready_out) begin
          nextstate = READY_DATA;
          data_out[63:0] = 0;
        end
      end
      READY_DATA   : begin
        if (valid_in) begin
          nextstate = DATA1;
          data_out[63:0] = {data_in[31:0],32'h00000000};
        end
      end
      READY_TRAILER: begin
        if (valid_in) begin
          nextstate = TRAILER1;
          data_out[63:0] = {data_in[31:0],32'h00000000};
        end
      end
      TRAILER1     : begin
        if (valid_in) begin
          nextstate = TRAILER2;
          data_out[63:0] = {data_out[63:32],data_in[31:0]};
        end
      end
      TRAILER2     : begin
        if (ready_out) begin
          nextstate = READY_HEADER;
          data_out[63:0] = 0;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign header_out = state[0];
  assign ready_in = state[1];
  assign trailer_out = state[2];
  assign valid_out = state[3];
  
  // sequential always block
  always @(posedge clk or posedge rst) begin
    if (rst)
      state <= READY_HEADER;
    else
      state <= nextstate;
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

