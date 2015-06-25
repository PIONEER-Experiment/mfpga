// Finite state machine to handle triggering of Channel FPGA(s).
// 
// General FSM flow:
// 1. Pass trigger on to enabled Channel FPGA(s)
// 2. Wait for Channel FPGA(s) to report 'done'
// 3. Put the trigger number in FIFO for command manager
//
// Notes:
// 1. Trigger number starts at 1
//
// Originally created using Fizzim

module trigger_manager (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // trigger interface
  input wire trigger,
  input wire [4:0] chan_en,
  input wire [1:0] fill_type,
  output reg [23:0] trig_num,

  // interface to Channel FPGAs
  input wire [4:0] acq_done,
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,

  // interface to trigger number FIFO
  input wire fifo_ready,
  output reg fifo_valid
);

  // state bits
  parameter IDLE          = 0;
  parameter FILL          = 1;
  parameter STORE_FILLNUM = 2;
  
  reg [2:0] state;
  reg [2:0] nextstate;
  reg [23:0] next_trig_num;

  // comb always block
  always @* begin
    nextstate = 3'd0;
    next_trig_num[23:0] = trig_num[23:0];

    acq_enable[9:0] = 10'd0; // default
    acq_trig[4:0] = 5'd0;    // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          next_trig_num[23:0] = trig_num[23:0]+1;
          nextstate[FILL] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // pass trigger and fill type to channels, and
      // wait for channel to report back 'done'
      state[FILL] : begin
        acq_enable[9:0] = { 5{fill_type[1:0]} };
        acq_trig[4:0] = chan_en[4:0];

        if (acq_done[4:0] == acq_trig[4:0]) begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1;
        end
      end
      // store the trigger number in the FIFO, for the command manager
      state[STORE_FILLNUM] : begin
        if (fifo_ready) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
      end
    endcase
  end
  
  // sequential always block
  always @(posedge clk) begin
    if (reset) begin
      state <= 3'b001 << IDLE;
      trig_num[23:0] <= 24'd0;
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
        nextstate[STORE_FILLNUM]: begin
          fifo_valid <= 1;
        end
      endcase
    end
  end

endmodule
