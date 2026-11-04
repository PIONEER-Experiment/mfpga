// Finite state machine to control triggering of the channels

module channel_acq_controller (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // trigger configuration
  input wire [ 4:0] chan_en,    // which channels should receive the trigger
  input wire [31:0] trig_delay, // delay between receiving trigger and passing it onto channels

  // interface from TTC trigger receiver
  input wire trigger,          // trigger signal
  input wire [ 4:0] trig_type, // recognized trigger type (muon fill, laser, pedestal, async readout)
  input wire [23:0] trig_num,  // trigger number
  output wire acq_ready,       // channels are ready to acquire data

  // interface to Channel FPGAs
  input wire [4:0] acq_dones,
  output reg [9:0] acq_enable,
  output reg [4:0] acq_trig,

  // interface to Acquisition Event FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [31:0] fifo_data,

  // status connections
  input wire async_mode, // asynchronous mode select
  input wire cbuf_mode,  // cifcular buffer mode select
  output reg [3:0] state, // state of finite state machine
  output reg wait_gave_up // one clock: the wait for the dones ended on its time-out (6.8.0, error capture)
);

  // state bits
  parameter IDLE           = 0;
  parameter DELAY          = 1;
  parameter FILL           = 2;
  parameter STORE_ACQ_INFO = 3;
  

  reg [ 4:0] acq_trig_type; // latched trigger type
  reg [23:0] acq_trig_num;  // latched trigger number

  reg [ 3:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg [ 9:0] next_acq_enable;
  reg [ 4:0] next_acq_trig;

  reg [31:0] delay_cnt; // counter to keep track of trigger delay 


  // Bound on the wait for every enabled channel's done (6.8.0): 2^23 TTC clocks = 210 ms, far
  // longer than any fill (the longest configurable is ~170 ms).  A channel that never reports done
  // used to hold this machine, and every later trigger, for ever.  On the time-out the event is
  // stored anyway (the readout then finds out what the channels have) and 'wait_gave_up' tells the
  // error capture (data loss).
  reg  [23:0] wait_cntr;
  wire        wait_timeout = wait_cntr[23];
  always @(posedge clk) begin
    if ( reset || !state[FILL] ) wait_cntr <= 24'd0;
    else if ( !wait_timeout )   wait_cntr <= wait_cntr + 1;
    wait_gave_up <= state[FILL] && wait_timeout && (acq_dones[4:0] != chan_en[4:0]);
  end

  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type[ 4:0] = acq_trig_type[ 4:0];
    next_acq_trig_num [23:0] = acq_trig_num [23:0];

    next_acq_enable[9:0] = 10'd0; // default
    next_acq_trig  [4:0] =  5'd0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger & ~async_mode & ~cbuf_mode ) begin
          next_acq_trig_type[ 4:0] = trig_type[ 4:0]; // latch trigger type
          next_acq_trig_num [23:0] = trig_num [23:0]; // latch trigger number

          if (trig_delay[31:0]) begin
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
        if (trig_delay[31:0] - delay_cnt[31:0] - 1) begin
          nextstate[DELAY] = 1'b1;
        end
        else begin
          nextstate[FILL] = 1'b1;
        end
      end
      // pass trigger and fill type to channels, and
      // wait for channel to report back 'done'
      state[FILL] : begin
        next_acq_enable[9:0] = { 5{acq_trig_type[1:0]} };
        next_acq_trig  [4:0] = chan_en[4:0];

        if ((acq_dones[4:0] == chan_en[4:0]) | wait_timeout) begin
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

      acq_trig_type[ 4:0] <=  5'd0;
      acq_trig_num [23:0] <= 24'd0;

      acq_enable[9:0] <= 10'd0;
      acq_trig  [4:0] <=  5'd0;
    end
    else begin
      state <= nextstate;

      acq_trig_type[ 4:0] <= next_acq_trig_type[ 4:0];
      acq_trig_num [23:0] <= next_acq_trig_num [23:0];

      acq_enable[9:0] <= next_acq_enable[9:0];
      acq_trig  [4:0] <= next_acq_trig  [4:0];
    end

    // reset trigger delay counter
    if (reset | trigger) begin
      delay_cnt[31:0] <= 32'd0;
    end
    else begin
      delay_cnt[31:0] <= delay_cnt[31:0] + 1;
    end
  end
  

  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid      <=  1'b0;
      fifo_data[31:0] <= 32'd0;
    end
    else begin
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[DELAY] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[FILL] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[STORE_ACQ_INFO] : begin
          fifo_valid      <= 1'b1;
          fifo_data[31:0] <= {3'd0, acq_trig_type[4:0], acq_trig_num[23:0]};
        end
      endcase
    end
  end

  // outputs based on states
  assign acq_ready = (state[IDLE] == 1'b1);

endmodule
