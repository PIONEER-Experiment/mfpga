
// Created by fizzim.pl version $Revision: 4.44 on 2014:07:19 at 11:54:21 (www.fizzim.com)

module triggerManager (
  output reg fifo_valid,
  output reg [4:0] go,
  output reg [4:0] trig_arm,
  output reg [23:0] trig_num,
  input wire clk,
  (* mark_debug = "true" *) input wire cm_busy,
  input wire [4:0] done,
  (* mark_debug = "true" *) input wire fifo_filled,
  input wire fifo_ready,
  input wire reset,
  input wire trigger 
);

  // state bits
  parameter 
  IDLE          = 0, 
  FILL          = 1, 
  SET_TRIG_ARM  = 2, 
  STORE_FILLNUM = 3; 

  (* mark_debug = "true" *) reg [3:0] state;
  (* mark_debug = "true" *) reg [3:0] nextstate;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = 4'b0000;
    next_trig_num[23:0] = trig_num[23:0];
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]         : begin
        if (trigger && !cm_busy) begin
          nextstate[FILL] = 1'b1;
          next_trig_num[23:0] = trig_num[23:0]+1;
        end
        else begin
          nextstate[IDLE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[FILL]         : begin
        if (done[4:0]==5'b11111) begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SET_TRIG_ARM] : begin
        if (!fifo_filled && !cm_busy) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[SET_TRIG_ARM] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[STORE_FILLNUM]: begin
        if (fifo_ready) begin
          nextstate[SET_TRIG_ARM] = 1'b1;
        end
        else begin
          nextstate[STORE_FILLNUM] = 1'b1; // Added because implied_loopback is true
        end
      end
    endcase
  end

  // sequential always block
  always @(posedge clk) begin
    if (reset) begin
      state <= 4'b0001 << IDLE;
      trig_num[23:0] <= 0;
      end
    else begin
      state <= nextstate;
      trig_num[23:0] <= next_trig_num[23:0];
      end
  end

  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid <= 0;
      go[4:0] <= 5'b00000;
      trig_arm[4:0] <= 5'b11111;
    end
    else begin
      fifo_valid <= 0; // default
      go[4:0] <= 5'b00000; // default
      trig_arm[4:0] <= 5'b11111; // default
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]         : begin
          ; // case must be complete for onehot
        end
        nextstate[FILL]         : begin
          go[4:0] <= 5'b11111;
        end
        nextstate[SET_TRIG_ARM] : begin
          trig_arm[4:0] <= 5'b00000;
        end
        nextstate[STORE_FILLNUM]: begin
          fifo_valid <= 1;
          trig_arm[4:0] <= 5'b00000;
        end
      endcase
    end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [103:0] statename;
  always @* begin
    case (1'b1)
      state[IDLE]         :
        statename = "IDLE";
      state[FILL]         :
        statename = "FILL";
      state[SET_TRIG_ARM] :
        statename = "SET_TRIG_ARM";
      state[STORE_FILLNUM]:
        statename = "STORE_FILLNUM";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

