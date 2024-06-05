// Finite state machine to control triggering of the channels
//lkg -- note to self: don't need the pulse trigger pass in or passed out of this module
//lkg -- I believe what we want is to from idle to wait when chan_en (or reduced) is enabled,
//lkg -- then wait until all of hte modules indicate that they have finished reading
// Asynchronous mode

module channel_acq_controller_selftrig (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // trigger configuration
  input wire [4:0] chan_en,         // which channels should receive the trigger
  input wire accept_self_triggers,  // accept self panel triggers in enabled channels

  // command manager interface
  input wire readout_done,            // a readout has completed
  output wire readout_buffer_changed,  // a convenient signal to flag that the readout buffer changed

  // interface from TTC trigger receiver
  input wire ttc_trigger,          // trigger signal
  input wire [ 4:0] ttc_trig_type, // recognized trigger type (muon fill, laser, pedestal, async readout)
  input wire [23:0] ttc_trig_num,  // trigger number
  output wire ttc_acq_ready,       // channels are ready for a readout
  output reg  ttc_acq_activated,

  // interface to Channel FPGAs
  input wire [4:0] acq_dones,
  output reg [4:0] acq_enable,
  output reg [4:0] acq_buffer_write,

  // interface to Acquisition Event FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [31:0] fifo_data,

  // status connections
  output reg [4:0] state // state of finite state machine
);

  // state bits
  parameter IDLE              = 0;
  parameter WAIT              = 1;
  parameter FLIP_DDR3_BUFFERS = 2;
  parameter STORE_ACQ_INFO    = 3;
  parameter READOUT           = 4;
  

  reg [ 4:0] acq_trig_type;     // latched trigger type
  reg [23:0] acq_trig_num;      // latched trigger number
  reg [ 4:0] acq_dones_latched; // latched channel dones reported

  reg [ 4:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg [ 4:0] next_acq_dones_latched;
  reg [ 4:0] next_acq_enable;
  reg [ 4:0] next_acq_buffer_write;
  reg        next_ttc_acq_activated;


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type    [ 4:0] = acq_trig_type    [ 4:0];
    next_acq_trig_num     [23:0] = acq_trig_num     [23:0];
    next_acq_dones_latched[ 4:0] = acq_dones_latched[ 4:0];
    next_ttc_acq_activated       = ttc_acq_activated;
    next_acq_buffer_write [4:0]  = acq_buffer_write[4:0];

    next_acq_enable[4:0] = 5'd0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // readout trigger received -- the ttc_trigger_receiver_selftrig has already filtered out other types of triggers aside from readout
        // we will stop acquisition of channel self-triggers while we wait for any final events in the channels to get written to the DDR3
        if (ttc_trigger ) begin
          next_acq_dones_latched[4:0] = 5'b00000;

          next_acq_trig_type[ 4:0] = ttc_trig_type[ 4:0]; // latch trigger type
          next_acq_trig_num [23:0] = ttc_trig_num [23:0]; // latch trigger number
          next_ttc_acq_activated   = 1'b0;                // clear flag

          nextstate[WAIT] = 1'b1;
        end
        // tell the channels to keep on acquring data if we are accepting triggers
        else if ( accept_self_triggers ) begin
          // enable lines should be fixed and not set by the trigger type
          next_acq_enable[4:0] = chan_en[4:0];
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

        // keep the enabled channels acquiring data
        next_acq_enable[4:0] = chan_en[4:0];

        // check if all channels report done
        if ((acq_dones_latched[4:0] == chan_en[4:0]) | ~accept_self_triggers) begin
          nextstate[FLIP_DDR3_BUFFERS] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end

      // swap the buffers used for reading and writing
      state[FLIP_DDR3_BUFFERS] : begin
      // flip buffer to use
         next_acq_buffer_write[4:0]  = ~acq_buffer_write[4:0];
         nextstate[STORE_ACQ_INFO] = 1'b1;
      end

      // store the event information in the FIFO, for the trigger processor, switch DDR3 buffer
      state[STORE_ACQ_INFO] : begin
        // renable self triggering if we are still taking data
        if ( accept_self_triggers ) begin
          next_acq_enable[4:0] = chan_en[4:0];
        end
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
        // re-enable self triggering if we are still taking data
        if ( accept_self_triggers ) begin
          next_acq_enable[4:0] = chan_en[4:0];
        end
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

      acq_enable[4:0]       <= 5'd0;
      acq_buffer_write[4:0] <= 5'd0;
    end
    else begin
      state <= nextstate;

      acq_trig_type    [ 4:0] <= next_acq_trig_type    [ 4:0];
      acq_trig_num     [23:0] <= next_acq_trig_num     [23:0];
      acq_dones_latched[ 4:0] <= next_acq_dones_latched[ 4:0];
      ttc_acq_activated       <= next_ttc_acq_activated;

      acq_enable[4:0]        <= next_acq_enable[4:0];
      acq_buffer_write[4:0]  <= next_acq_buffer_write[4:0];
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
  assign ttc_acq_ready          = (state[IDLE] == 1'b1);
  assign readout_buffer_changed = (state[FLIP_DDR3_BUFFERS] == 1'b1);
endmodule
