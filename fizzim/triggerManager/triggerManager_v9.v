
// Created by fizzim.pl version $Revision: 4.44 on 2014:07:25 at 19:15:11 (www.fizzim.com)

module triggerManager (
  output reg fifo_valid,
  output reg [4:0] go,
  output reg [4:0] trig_arm,
  output reg [23:0] trig_num,
  input wire chan_readout_done,
  input wire clk,
  input wire cm_busy,
  input wire [4:0] done,
  input wire fifo_ready,
  input wire reset,
  input wire trigger 
);

  // state bits
  parameter 
  IDLE             = 0, 
  FILL             = 1, 
  STORE_FILLNUM    = 2, 
  TOGGLE_ARM1      = 3, 
  TOGGLE_ARM2      = 4, 
  WAIT_FOR_READOUT = 5; 

  reg [5:0] state;
  reg [5:0] nextstate;
  reg [3:0] count;
  reg [3:0] next_count;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = 6'b000000;
    next_count[3:0] = count[3:0];
    next_trig_num[23:0] = trig_num[23:0];
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]            : begin
        if (trigger && !cm_busy) begin
          nextstate[FILL] = 1'b1;
          next_trig_num[23:0] = trig_num[23:0]+1;
        end
        else begin
          nextstate[IDLE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[FILL]            : begin
        if (done[4:0]==5'b11111) begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[STORE_FILLNUM]   : begin
        if (fifo_ready) begin
          nextstate[WAIT_FOR_READOUT] = 1'b1;
        end
        else begin
          nextstate[STORE_FILLNUM] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[TOGGLE_ARM1]     : begin
        if (count[3:0]==4'b1010) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[TOGGLE_ARM2] = 1'b1;
          next_count[3:0] = count[3:0]+1;
        end
      end
      state[TOGGLE_ARM2]     : begin
        if (count[3:0]==4'b1010) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[TOGGLE_ARM1] = 1'b1;
          next_count[3:0] = count[3:0]+1;
        end
      end
      state[WAIT_FOR_READOUT]: begin
        if (chan_readout_done) begin
          nextstate[TOGGLE_ARM1] = 1'b1;
          next_count[3:0] = count[3:0]+1;
        end
        else begin
          nextstate[WAIT_FOR_READOUT] = 1'b1; // Added because implied_loopback is true
        end
      end
    endcase
  end

  // sequential always block
  always @(posedge clk) begin
    if (reset) begin
      state <= 6'b000001 << IDLE;
      count[3:0] <= 0;
      trig_num[23:0] <= 0;
      end
    else begin
      state <= nextstate;
      count[3:0] <= next_count[3:0];
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
        nextstate[IDLE]            : begin
          ; // case must be complete for onehot
        end
        nextstate[FILL]            : begin
          go[4:0] <= 5'b11111;
        end
        nextstate[STORE_FILLNUM]   : begin
          fifo_valid <= 1;
        end
        nextstate[TOGGLE_ARM1]     : begin
          trig_arm[4:0] <= 5'b00000;
        end
        nextstate[TOGGLE_ARM2]     : begin
          trig_arm[4:0] <= 5'b00000;
        end
        nextstate[WAIT_FOR_READOUT]: begin
          ; // case must be complete for onehot
        end
      endcase
    end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [127:0] statename;
  always @* begin
    case (1'b1)
      state[IDLE]            :
        statename = "IDLE";
      state[FILL]            :
        statename = "FILL";
      state[STORE_FILLNUM]   :
        statename = "STORE_FILLNUM";
      state[TOGGLE_ARM1]     :
        statename = "TOGGLE_ARM1";
      state[TOGGLE_ARM2]     :
        statename = "TOGGLE_ARM2";
      state[WAIT_FOR_READOUT]:
        statename = "WAIT_FOR_READOUT";
      default         :
        statename = "XXXXXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

