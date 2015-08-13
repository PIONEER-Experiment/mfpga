// Finite state machine to handle triggering of Channel FPGA(s).
// 
// General FSM flow:
// 1. Pass trigger on to enabled Channel FPGA(s)
// 2. Wait for Channel FPGA(s) to report 'done'
// 3. Put the trigger number in FIFO for command manager
// 4. Put the trigger timestamp in FIFO for command manager
//
// Notes:
// 1. Trigger number starts at 1
// 2. Trigger timestamp is number of clockticks since end of the last reset
// 3. Resetting timestamp or trigger number does NOT return state machine to
// IDLE.
//
// Originally created using Fizzim

module trigger_manager (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // TTC channel B resets
  input wire reset_trig_timestamp,
  input wire reset_trig_num,

  // trigger interface
  input wire trigger,
  input wire [4:0] chan_en,
  input wire [1:0] fill_type,
  output reg [63:0] data_to_fifo, // data we send to the fifo

  // interface to Channel FPGAs
  input wire [4:0] acq_done,
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,

  // interface to trigger information FIFO
  input wire fifo_ready,
  output reg fifo_valid
);

  // state bits
  parameter IDLE           = 0;
  parameter FILL           = 1;
  parameter STORE_FILLNUM  = 2;
  parameter STORE_TRIGTIME = 3;
  
  reg [3:0] state;
  reg [3:0] nextstate;
  reg [63:0] trig_num; // Number of triggers received
  reg [63:0] next_trig_num;
  reg [63:0] trig_timestamp; // Timestamp last trigger was received
  reg [63:0] next_trig_timestamp;
  reg [63:0] counter; // Clock ticks since last reset
  // comb always block
  always @* begin
    nextstate = 4'd0;
    next_trig_num[63:0] = trig_num[63:0];
    next_trig_timestamp[63:0] = trig_timestamp[63:0];

    acq_enable[9:0] = 10'd0; // default
    acq_trig[4:0] = 5'd0;    // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          next_trig_num[63:0] = trig_num[63:0]+1;
          next_trig_timestamp[63:0] = counter[63:0]; // Save timestamp latest trigger is received
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
          nextstate[STORE_TRIGTIME] = 1'b1;
        end
        else begin
          nextstate[STORE_FILLNUM] = 1'b1;
        end
      end
      // store the trigger timestamp in the FIFO, for the command manager
      state[STORE_TRIGTIME] : begin
        if (fifo_ready) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[STORE_TRIGTIME] = 1'b1;
        end
      end
    endcase
  end
  
  // sequential always block
  always @(posedge clk) begin

    if (reset) begin // Reset state machine
      state <= 4'b0001 << IDLE;
    end
    else begin
      state <= nextstate;
    end
  
    if (reset || reset_trig_num) begin // Reset trigger number
      trig_num[63:0] <= 64'd0;
    end
    else begin
      trig_num[63:0] <= next_trig_num[63:0];
    end
    
    if (reset || reset_trig_timestamp) begin // Reset stored trigger timestamp and counter
      counter[63:0] <= 64'b0;
      trig_timestamp[63:0] <= 64'b0;
    end
    else begin
      counter[63:0] <= counter[63:0] +1;
      trig_timestamp[63:0] <= next_trig_timestamp[63:0];
    end

  end
  
  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid <= 0;
      data_to_fifo <= 64'd0; // reset data at the reset
    end
    else begin
      // Make case explicit for all possible states
      // If this isn't done, implementation may assume that fifo_valid should be
      // set to 1 for all cases, even if fifo_valid is set to
      // 0 ahead of case statement
      case (1'b1) // synopsys parallel_case full_case
        // tell fifo we have no valid data
        nextstate[IDLE]: begin
          begin
            fifo_valid <= 0;
            data_to_fifo[63:0] <= 64'd0;
         end
        end
        // tell fifo we have no valid data
        nextstate[FILL]: begin
          begin
            fifo_valid <= 0;
            data_to_fifo[63:0] <= 64'd0;
         end
        end
        // tell fifo we have valid data and give it the trigger number
        nextstate[STORE_FILLNUM]: begin
          begin
            fifo_valid <= 1;
            data_to_fifo[63:0] <= trig_num[63:0];
          end
        end
        // tell fifo we have valid data and give it the trigger timestamp     
        nextstate[STORE_TRIGTIME]: begin
          begin
            fifo_valid <= 1;
            data_to_fifo[63:0] <= trig_timestamp[63:0];
          end
        end
      endcase
    end
  end

endmodule
