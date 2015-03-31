

Warning F17: Flag wait_cntr[3:0] is assigned on transitions, but is also assigned value "0" in state IDLE 


Warning R14: No reset value set for flag wait_cntr[3:0] - using 0 

// Created by fizzim.pl version $Revision: 5.0 on 2015:03:19 at 12:28:50 (www.fizzim.com)

module triggerManager (
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,
  output reg fifo_valid,
  output reg [23:0] trig_num,
  output reg [3:0] wait_cntr,
  input wire [4:0] acq_busy,
  input wire [4:0] acq_done,
  input wire [4:0] chan_en,
  input wire clk,
  input wire fifo_ready,
  input wire [1:0] fill_type,
  input wire reset,
  input wire trigger 
);

  // state bits
  parameter 
  IDLE          = 0, 
  FILL          = 1, 
  STORE_FILLNUM = 2, 
  WAIT          = 3; 

  reg [3:0] state;
  reg [3:0] nextstate;
  reg [23:0] next_trig_num;
  reg [3:0] next_wait_cntr;

  // comb always block
  always @* begin
    nextstate = 4'b0000;
    acq_enable[9:0] = 10'b0000000000; // default
    acq_trig[4:0] = 5'b00000; // default
    next_trig_num[23:0] = trig_num[23:0];
    next_wait_cntr[3:0] = wait_cntr[3:0];
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]         : begin
        // Warning F17: Flag wait_cntr[3:0] is assigned on transitions, but is also assigned value "0" in state IDLE 
        next_wait_cntr[3:0] = 0;
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
        if (acq_done[4:0]==5'b11111) begin
          nextstate[WAIT] = 1'b1;
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
      state[WAIT]         : begin
        acq_enable[9:0] = {5{fill_type[1:0]}};
        if (wait_cntr[3:0]==4'b1111) begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
          next_wait_cntr[3:0] = wait_cntr[3:0]+1;
        end
      end
    endcase
  end

  // sequential always block
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= 4'b0001 << IDLE;
      trig_num[23:0] <= 0;
      // Warning R14: No reset value set for flag wait_cntr[3:0] - using 0 
      wait_cntr[3:0] <= 0;
      end
    else begin
      state <= nextstate;
      trig_num[23:0] <= next_trig_num[23:0];
      wait_cntr[3:0] <= next_wait_cntr[3:0];
      end
  end

  // datapath sequential always block
  always @(posedge clk or posedge reset) begin
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
        nextstate[WAIT]         : begin
          ; // case must be complete for onehot
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
      state[WAIT]         :
        statename = "WAIT";
      default      :
        statename = "XXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

