
// Created by fizzim.pl version 4.42 on 2014:04:17 at 13:07:14 (www.fizzim.com)

module triggerManager (
  output reg [7:0] fillNum,
  output wire go,
  input wire clk,
  input wire done,
  input wire reset,
  input wire trigger 
);
  
  // state bits
  parameter 
  RESET = 2'b00, // extra=0 go=0 
  FILL  = 2'b01, // extra=0 go=1 
  IDLE  = 2'b10; // extra=1 go=0 
  
  reg [1:0] state;
  reg [1:0] nextstate;
  
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
        if (done) begin
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
  assign go = state[0];
  
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

