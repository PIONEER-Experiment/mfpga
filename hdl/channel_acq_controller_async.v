// Finite state machine to control triggering of the channels

// Asynchronous mode

module channel_acq_controller_async (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // trigger configuration
  input wire [4:0] chan_en,         // which channels should receive the trigger
  input wire accept_pulse_triggers, // accept front panel triggers select

  // command manager interface
  input wire readout_done, // a readout has completed

  // interface from TTC trigger receiver
  input wire ttc_trigger,          // trigger signal
  input wire [ 4:0] ttc_trig_type, // recognized trigger type (muon fill, laser, pedestal, async readout)
  input wire [23:0] ttc_trig_num,  // trigger number
  output wire ttc_acq_ready,       // channels are ready for a readout
  output reg ttc_acq_activated,

  // interface from pulse trigger receiver
  input wire pulse_trigger, // trigger signal

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
  output reg [3:0] state // state of finite state machine
);

  // state bits
  parameter IDLE           = 0;
  parameter WAIT           = 1;
  parameter STORE_ACQ_INFO = 2;
  parameter READOUT        = 3;
  

  reg [ 4:0] acq_trig_type;     // latched trigger type
  reg [23:0] acq_trig_num;      // latched trigger number
  reg [ 4:0] acq_dones_latched; // latched channel dones reported

  reg [ 3:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg [ 4:0] next_acq_dones_latched;
  reg [ 9:0] next_acq_enable;
  reg [ 4:0] next_acq_trig;
  reg        next_ttc_acq_activated;


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type    [ 4:0] = acq_trig_type    [ 4:0];
    next_acq_trig_num     [23:0] = acq_trig_num     [23:0];
    next_acq_dones_latched[ 4:0] = acq_dones_latched[ 4:0];
    next_ttc_acq_activated       = ttc_acq_activated;

    next_acq_enable[9:0] = 10'd0; // default
    next_acq_trig  [4:0] =  5'd0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // asynchronous readout trigger received
        if (ttc_trigger & async_mode) begin
          next_acq_dones_latched[4:0] = 5'b00000;

          next_acq_trig_type[ 4:0] = ttc_trig_type[ 4:0]; // latch trigger type
          next_acq_trig_num [23:0] = ttc_trig_num [23:0]; // latch trigger number
          next_ttc_acq_activated   = 1'b0;                // clear flag

          nextstate[WAIT] = 1'b1;
        end
        // pass on front panel trigger to channels
        else if (accept_pulse_triggers & async_mode) begin
          // enable lines should be fixed and not set by the trigger type
          next_acq_enable[9:0] = { {2{chan_en[4]}}, {2{chan_en[3]}}, {2{chan_en[2]}}, {2{chan_en[1]}}, {2{chan_en[0]}} };
          next_acq_trig  [4:0] = (pulse_trigger) ? chan_en[4:0] : 5'b00000;
          next_ttc_acq_activated = 1'b1;

          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // end the acquisitions in channels, and
      // wait for channels to report back done
      state[WAIT] : begin
        // update latched channel dones
        next_acq_dones_latched[4:0] = acq_dones_latched[4:0] | acq_dones[4:0];

        // check if all channels report done
        if ((acq_dones_latched[4:0] == chan_en[4:0]) | ~accept_pulse_triggers) begin
          nextstate[STORE_ACQ_INFO] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end
      // store the event information in the FIFO, for the trigger processor
      state[STORE_ACQ_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          nextstate[READOUT] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_ACQ_INFO] = 1'b1;
        end
      end
      // wait for readout to be complete, as reported by command manager
      state[READOUT] : begin
        // readout is finished
        if (readout_done) begin
          nextstate[IDLE] = 1'b1;
        end
        // readout still in progress
        else begin
          nextstate[READOUT] = 1'b1;
        end
      end
    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 4'd1 << IDLE;

      acq_trig_type    [ 4:0] <=  5'd0;
      acq_trig_num     [23:0] <= 24'd0;
      acq_dones_latched[ 4:0] <=  5'd0;
      ttc_acq_activated       <=  1'b0;

      acq_enable[9:0] <= 10'd0;
      acq_trig  [4:0] <=  5'd0;
    end
    else begin
      state <= nextstate;

      acq_trig_type    [ 4:0] <= next_acq_trig_type    [ 4:0];
      acq_trig_num     [23:0] <= next_acq_trig_num     [23:0];
      acq_dones_latched[ 4:0] <= next_acq_dones_latched[ 4:0];
      ttc_acq_activated       <= next_ttc_acq_activated;

      acq_enable[9:0] <= next_acq_enable[9:0];
      acq_trig  [4:0] <= next_acq_trig  [4:0];
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
        nextstate[WAIT] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[STORE_ACQ_INFO] : begin
          fifo_valid      <= 1'b1;
          fifo_data[31:0] <= {3'd0, acq_trig_type[4:0], acq_trig_num[23:0]};
        end
        nextstate[READOUT] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
      endcase
    end
  end

  // outputs based on states
  assign ttc_acq_ready = (state[IDLE] == 1'b1);

endmodule
