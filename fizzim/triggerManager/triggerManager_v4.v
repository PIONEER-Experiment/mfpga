
// Created by fizzim.pl version 4.42 on 2014:04:21 at 18:53:48 (www.fizzim.com)

module triggerManager (
  output reg [7:0] fillNum,
  output wire [4:0] go,
  input wire clk,
  input wire [4:0] done,
  input wire reset,
  input wire trigger 
);
  
  // state bits
  parameter 
  RESET = 6'b000000, // extra=0 go[4:0]=00000 
  FILL  = 6'b011111, // extra=0 go[4:0]=11111 
  IDLE  = 6'b100000; // extra=1 go[4:0]=00000 
  
  reg [5:0] state;
  reg [5:0] nextstate;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    fillNum[7:0] = fillNum[7:0]; // default
    case (state)
      RESET: begin
        // Warning C7: Combinational output fillNum[7:0] is assigned on transitions, but has a non-default value "0" in state RESET 
        fillNum[7:0] = 0;
        begin
          nextstate = IDLE;
        end
      end
      FILL : begin
        if (done[4:0]==5'b11111) begin
          nextstate = IDLE;
        end
      end
      IDLE : begin
        if (trigger) begin
          nextstate = FILL;
          fillNum[7:0] = fillNum[7:0]+1;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign go[4:0] = state[4:0];
  
  // sequential always block
  always @(posedge clk or negedge reset) begin
    if (!reset)
      state <= RESET;
    else
      state <= nextstate;
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [39:0] statename;
  always @* begin
    case (state)
      RESET:
        statename = "RESET";
      FILL :
        statename = "FILL";
      IDLE :
        statename = "IDLE";
      default:
        statename = "XXXXX";
    endcase
  end
  `endif

endmodule

