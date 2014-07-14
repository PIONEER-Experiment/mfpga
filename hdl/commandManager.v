
// Created by fizzim.pl version $Revision: 4.44 on 2014:07:13 at 18:17:56 (www.fizzim.com)

module commandManager (
  output reg [31:0] csn,
  output wire run_dtm,
  output wire run_rtm,
  input wire clk,
  input wire dtm_done,
  input wire ipbus_cmd_valid,
  input wire rst,
  input wire rtm_done,
  input wire tm_fifo_valid 
);

  // state bits
  parameter 
  IDLE      = 4'b0000, // extra=00 run_rtm=0 run_dtm=0 
  START_DTM = 4'b0100, // extra=01 run_rtm=0 run_dtm=0 
  START_RTM = 4'b1000; // extra=10 run_rtm=0 run_dtm=0 

  (* mark_debug = "true" *) reg [3:0] state;
  reg [3:0] nextstate;
  reg [31:0] next_csn;

  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    next_csn[31:0] = csn[31:0];
    case (state)
      IDLE     : begin
        if (ipbus_cmd_valid) begin
          nextstate = START_RTM;
        end
        else if (tm_fifo_valid) begin
          nextstate = START_DTM;
        end
      end
      START_DTM: begin
        if (dtm_done) begin
          nextstate = IDLE;
          next_csn[31:0] = csn[31:0]+1;
        end
      end
      START_RTM: begin
        if (rtm_done) begin
          nextstate = IDLE;
          next_csn[31:0] = csn[31:0]+1;
        end
      end
    endcase
  end

  // Assign reg'd outputs to state bits
  assign run_dtm = state[0];
  assign run_rtm = state[1];

  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      csn[31:0] <= 0;
      end
    else begin
      state <= nextstate;
      csn[31:0] <= next_csn[31:0];
      end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [71:0] statename;
  always @* begin
    case (state)
      IDLE     :
        statename = "IDLE";
      START_DTM:
        statename = "START_DTM";
      START_RTM:
        statename = "START_RTM";
      default  :
        statename = "XXXXXXXXX";
    endcase
  end
  `endif

endmodule

