
// Created by fizzim.pl version 4.42 on 2014:03:09 at 16:02:22 (www.fizzim.com)

module triggerManager (
  output wire go,
  output wire pause,
  output wire prepare,
  input wire clk,
  input wire done,
  input wire ready,
  input wire rst_n,
  input wire trigger 
);
  
  // state bits
  parameter 
  WAIT    = 3'b000, // prepare=0 pause=0 go=0 
  FILL    = 3'b011, // prepare=0 pause=1 go=1 
  PREPARE = 3'b100; // prepare=1 pause=0 go=0 
  
  reg [2:0] state;
  reg [2:0] nextstate;
  
  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    case (state)
      WAIT   : begin
        if (trigger) begin
          nextstate = PREPARE;
        end
      end
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
    endcase
  end
  
  // Assign reg'd outputs to state bits
  assign go = state[0];
  assign pause = state[1];
  assign prepare = state[2];
  
  // sequential always block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= WAIT;
    else
      state <= nextstate;
  end
  
  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [55:0] statename;
  always @* begin
    case (state)
      WAIT   :
        statename = "WAIT";
      FILL   :
        statename = "FILL";
      PREPARE:
        statename = "PREPARE";
      default:
        statename = "XXXXXXX";
    endcase
  end
  `endif

endmodule

