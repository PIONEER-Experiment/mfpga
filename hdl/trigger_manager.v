// Finite state machine to handle triggering of Channel FPGA(s).
// 
// General FSM flow:
// 1. Send trigger to Channel FPGAs after specified delay
// 2. Wait for Channel FPGA(s) to report 'done'
// 3. Put the trigger number in FIFO for command manager
// 4. Put the trigger timestamp in FIFO for command manager
//
// Notes:
// 1. Trigger number starts at 1
//
// Originally created using Fizzim

module trigger_manager (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  input wire trigger,
  input wire [4:0] chan_en,
  input wire [1:0] fill_type,

  // interface to Channel FPGAs
  input wire [4:0] acq_done,
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,

  // interface to trigger information FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [63:0] fifo_data,


  input wire [3:0] delay_trig // delay between receiving tigger and sending it to channels
);

  // state bits
  parameter IDLE           = 0;
  parameter DELAY          = 1;
  parameter FILL           = 2;
  parameter STORE_FILLNUM  = 3;
  parameter STORE_TRIGTIME = 4;
  
  reg [4:0] state;
  reg [4:0] nextstate;
  reg [63:0] trig_num;            // number of received triggers
  reg [63:0] next_trig_num;
  reg [63:0] trig_timestamp;      // trigger timestamp
  reg [63:0] next_trig_timestamp;
  reg [63:0] trig_timestamp_cnt;  // clock cycle count, since last reset
  reg [63:0] delay_cnt;           // keep track of length of trigger delay 
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
          next_trig_num[63:0] = trig_num[63:0] + 1;
          next_trig_timestamp[63:0] = trig_timestamp_cnt[63:0];
          if(delay_trig[3:0]) begin
            nextstate[DELAY] = 1'b1;
          end
          else begin
            nextstate[FILL] = 1'b1;
          end
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // wait before sending trigger signal to channels
      state[DELAY] : begin
        if (delay_trig[3:0]-delay_cnt[63:0]-1) begin
          nextstate[DELAY] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1;
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
    // reset state machine
    if (reset) begin
      state <= 4'b0001 << IDLE;
    end
    else begin
      state <= nextstate;
    end
  
    //reset delay counter
      if (reset | trigger) begin
        delay_cnt[63:0] <= 64'b0;
      end
      else begin
        delay_cnt[63:0] <= delay_cnt[63:0] + 1;
      end
                                

    // reset trigger number
    if (reset | reset_trig_num) begin
      trig_num[63:0] <= 64'd0;
    end
    else begin
      trig_num[63:0] <= next_trig_num[63:0];
    end
    
    // reset trigger timestamp and its counter
    if (reset | reset_trig_timestamp) begin
      trig_timestamp[63:0] <= 64'b0;
      trig_timestamp_cnt[63:0] <= 64'b0;
    end
    else begin
      trig_timestamp[63:0] <= next_trig_timestamp[63:0];
      trig_timestamp_cnt[63:0] <= trig_timestamp_cnt[63:0] + 1;
    end
  end
  
  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid <= 0;
      fifo_data <= 64'd0;
    end
    else begin
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]: begin
          begin
            fifo_valid <= 0;
            fifo_data[63:0] <= 64'd0;
         end
        end
        nextstate[FILL]: begin
          begin
            fifo_valid <= 0;
            fifo_data[63:0] <= 64'd0;
         end
        end
        nextstate[STORE_FILLNUM]: begin
          begin
            fifo_valid <= 1;
            fifo_data[63:0] <= trig_num[63:0];
          end
        end
        nextstate[STORE_TRIGTIME]: begin
          begin
            fifo_valid <= 1;
            fifo_data[63:0] <= trig_timestamp[63:0];
          end
        end
      endcase
    end
  end

endmodule
