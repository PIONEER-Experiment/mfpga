
// Created by fizzim.pl version $Revision: 5.0 on 2015:02:26 at 13:04:17 (www.fizzim.com)

module triggerManager (
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,
  output wire fifo_valid,
  output reg [23:0] trig_num,
  input wire [4:0] acq_busy,
  input wire [4:0] chan_en,
  input wire clk,
  input wire fifo_ready,
  input wire [1:0] fill_type,
  input wire reset,
  input wire trigger 
);

  // state bits
  parameter 
  IDLE          = 3'b000, // extra=00 fifo_valid=0 
  FILL          = 3'b010, // extra=01 fifo_valid=0 
  PRE_FILL      = 3'b100, // extra=10 fifo_valid=0 
  STORE_FILLNUM = 3'b001; // extra=00 fifo_valid=1 

  reg [2:0] state;
  reg [2:0] nextstate;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = state; // default to hold value because implied_loopback is set
    acq_enable[9:0] = 10'b0000000000; // default
    acq_trig[4:0] = 5'b00000; // default
    next_trig_num[23:0] = trig_num[23:0];
    case (state)
      IDLE         : begin
        if (trigger) begin
          nextstate = PRE_FILL;
          next_trig_num[23:0] = trig_num[23:0]+1;
        end
      end
      FILL         : begin
        if (acq_busy[4:0]==5'b00000) begin
          nextstate = STORE_FILLNUM;
        end
      end
      PRE_FILL     : begin
        acq_enable[9:0] = {5{fill_type[1:0]}};
        acq_trig[4:0] = chan_en[4:0];
        if (acq_busy[4:0]==5'b11111) begin
          nextstate = FILL;
        end
      end
      STORE_FILLNUM: begin
        if (fifo_ready) begin
          nextstate = IDLE;
        end
      end
    endcase
  end

  // Assign reg'd outputs to state bits
  assign fifo_valid = state[0];

  // sequential always block
  always @(posedge clk or negedge reset) begin
    if (reset) begin
      state <= IDLE;
      trig_num[23:0] <= 0;
      end
    else begin
      state <= nextstate;
      trig_num[23:0] <= next_trig_num[23:0];
      end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [103:0] statename;
  always @* begin
    case (state)
      IDLE         :
        statename = "IDLE";
      FILL         :
        statename = "FILL";
      PRE_FILL     :
        statename = "PRE_FILL";
      STORE_FILLNUM:
        statename = "STORE_FILLNUM";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

