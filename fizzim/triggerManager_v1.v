
// Warning R1: No reset specified 
// Created by fizzim.pl version 4.42 on 2014:02:18 at 18:46:25 (www.fizzim.com)

module triggerManager (
  output wire go,
  output wire pause,
  output wire prepare,
  input wire clk,
  input wire done,
  input wire ready,
  input wire trigger 
);
  
  // state bits
  parameter 
  FILL    = 3'b011, // prepare=0 pause=1 go=1 
  PREPARE = 3'b100, // prepare=1 pause=0 go=0 
  WAIT    = 3'b000; // prepare=0 pause=0 go=0 
  
  reg [2:0] state;
  reg [2:0] nextstate;
  
  // comb always block
  always @* begin
    // Warning I2: Neither implied_loopback nor default_state_is_x attribute is set on state machine - defaulting to implied_loopback to avoid latches being inferred 
    nextstate = state; // default to hold value because implied_loopback is set
    case (state)
      FILL   : begin
        if (done) begin
          nextstate = WAIT;
        end
      end
      PREPARE: begin
        if (ready) begin
          nextstate = FILL;
        end
      end
      WAIT   : begin
        if (trigger) begin
          nextstate = PREPARE;
        end
      end
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign go = state[0];
  assign pause = state[1];
  assign prepare = state[2];
  
  // sequential always block
  always @(posedge clk) begin

      state <= nextstate;
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [55:0] statename;
  always @* begin
    case (state)
      FILL   :
        statename = "FILL";
      PREPARE:
        statename = "PREPARE";
      WAIT   :
        statename = "WAIT";
      default:
        statename = "XXXXXXX";
    endcase
  end
  `endif

endmodule

