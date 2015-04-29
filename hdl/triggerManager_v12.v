
// Created by fizzim.pl version $Revision: 5.0 on 2015:04:20 at 11:17:21 (www.fizzim.com)

module triggerManager (
  (* mark_debug = "true" *) output reg [9:0] acq_enable,
  (* mark_debug = "true" *) output reg [4:0] acq_trig,
  output reg fifo_valid,
  (* mark_debug = "true" *) output reg [23:0] trig_num,
  input wire [4:0] acq_busy,
  (* mark_debug = "true" *) input wire [4:0] acq_done,
  (* mark_debug = "true" *) input wire [4:0] chan_en,
  input wire clk,
  input wire fifo_ready,
  input wire [1:0] fill_type,
  (* mark_debug = "true" *) input wire reset,
  (* mark_debug = "true" *) input wire trigger 
);

  // state bits
  parameter 
  IDLE          = 0, 
  FILL          = 1, 
  STORE_FILLNUM = 2; 

  reg [2:0] state;
  reg [2:0] nextstate;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = 3'b000;
    acq_enable[9:0] = 10'b0000000000; // default
    acq_trig[4:0] = 5'b00000; // default
    next_trig_num[23:0] = trig_num[23:0];
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]         : begin
        if (trigger) begin
          nextstate[FILL] = 1'b1;
          next_trig_num[23:0] = trig_num[23:0]+1;
        end
        else begin
          nextstate[IDLE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[FILL]         : begin
        acq_enable[9:0] = {5{fill_type[1:0]}};
        acq_trig[4:0] = chan_en[4:0];
        if (acq_done[4:0]==acq_trig[4:0]) begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[STORE_FILLNUM]: begin
        if (fifo_ready) begin
          nextstate[IDLE] = 1'b1;
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
      state <= 3'b001 << IDLE;
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
    end
    else begin
      fifo_valid <= 0; // default
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]         : begin
          ; // case must be complete for onehot
        end
        nextstate[FILL]         : begin
          ; // case must be complete for onehot
        end
        nextstate[STORE_FILLNUM]: begin
          fifo_valid <= 1;
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
      state[STORE_FILLNUM]:
        statename = "STORE_FILLNUM";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

