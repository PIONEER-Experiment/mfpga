// Finite state machine to control triggering of the channels

module channel_acq_controller(
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // trigger configuration
  (* mark_debug = "true" *) input wire [4:0] chan_en,    // which channels should receive the trigger
  (* mark_debug = "true" *) input wire [3:0] trig_delay, // delay between receiving trigger and passing it onto channels

  // interface from TTC trigger receiver
  (* mark_debug = "true" *) input wire trigger,          // trigger signal
  (* mark_debug = "true" *) input wire [ 1:0] trig_type, // trigger type (muon fill, laser, pedestal)
  (* mark_debug = "true" *) input wire [23:0] trig_num,  // trigger number

  // interface to Channel FPGAs
  (* mark_debug = "true" *) input wire [4:0] acq_done,
  (* mark_debug = "true" *) output reg [9:0] acq_enable,
  (* mark_debug = "true" *) output reg [4:0] acq_trig,

  // interface to Acquisition Event FIFO
  (* mark_debug = "true" *) input wire fifo_ready,
  (* mark_debug = "true" *) output reg fifo_valid,
  (* mark_debug = "true" *) output reg [31:0] fifo_data,

  // status connections
  (* mark_debug = "true" *) output reg [3:0] state // state of finite state machine
);

  // state bits
  parameter IDLE           = 0;
  parameter DELAY          = 1;
  parameter FILL           = 2;
  parameter STORE_ACQ_INFO = 3;
  

  (* mark_debug = "true" *) reg [ 1:0] acq_trig_type; // latched trigger type
  (* mark_debug = "true" *) reg [23:0] acq_trig_num;  // latched trigger number

  (* mark_debug = "true" *) reg [ 3:0] nextstate;
  reg [ 1:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;

  (* mark_debug = "true" *) reg [3:0] delay_cnt; // counter to keep track of trigger delay 


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type[ 1:0] = acq_trig_type[ 1:0];
    next_acq_trig_num [23:0] = acq_trig_num [23:0];

    acq_enable[9:0] = 10'd0; // default
    acq_trig  [4:0] =  5'd0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          next_acq_trig_type[ 1:0] = trig_type[ 1:0]; // latch trigger type
          next_acq_trig_num [23:0] = trig_num [23:0]; // latch trigger number

          if (trig_delay[3:0]) begin
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
      // wait before passing trigger signal onto the channels
      state[DELAY] : begin
        if (trig_delay[3:0] - delay_cnt[3:0] - 1) begin
          nextstate[DELAY] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1;
        end
      end
      // pass trigger and fill type to channels, and
      // wait for channel to report back 'done'
      state[FILL] : begin
        acq_enable[9:0] = { 5{acq_trig_type[1:0]} };
        acq_trig  [4:0] = chan_en[4:0];

        if (acq_done[4:0] == acq_trig[4:0]) begin
          nextstate[STORE_ACQ_INFO] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1;
        end
      end
      // store the event information in the FIFO, for the trigger processor
      state[STORE_ACQ_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          nextstate[IDLE] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_ACQ_INFO] = 1'b1;
        end
      end
    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 4'd1 << IDLE;

      acq_trig_type[ 1:0] <=  2'd0;
      acq_trig_num [23:0] <= 24'd0;
    end
    else begin
      state <= nextstate;

      acq_trig_type[ 1:0] <= next_acq_trig_type[ 1:0];
      acq_trig_num [23:0] <= next_acq_trig_num [23:0];
    end

    // reset trigger delay counter
    if (reset | trigger) begin
      delay_cnt[3:0] <= 4'd0;
    end
    else begin
      delay_cnt[3:0] <= delay_cnt[3:0] + 1;
    end
  end
  

  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid <= 1'b0;
      fifo_data <= 32'd0;
    end
    else begin
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]: begin
          fifo_valid <= 1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[DELAY]: begin
          fifo_valid <= 1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[FILL]: begin
          fifo_valid <= 1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[STORE_ACQ_INFO]: begin
          fifo_valid <= 1'b1;
          fifo_data[31:0] <= {6'd0, acq_trig_type[1:0], acq_trig_num[23:0]};
        end
      endcase
    end
  end

endmodule
