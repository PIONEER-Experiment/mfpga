// Finite state machine to control triggering of the channels
//lkg -- note to self: don't need the pulse trigger pass in or passed out of this module
//lkg -- I believe what we want is to from idle to wait when chan_en (or reduced) is enabled,
//lkg -- then wait until all of hte modules indicate that they have finished reading
// Asynchronous mode

module channel_acq_controller_selftrigc (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // trigger configuration
  input wire [4:0] chan_en,         // which channels should receive the trigger
  input wire accept_self_triggers,  // accept self triggers in enabled channels

  // command manager interface
  output reg  new_fill_pause_triggers,   // flag there is a new fill and inhibit selftriggers
  output wire selftrigger_fifo_wr_en, 

  // interface from TTC trigger receiver
  input wire ttc_trigger,          // trigger signal
  input wire [ 4:0] ttc_trig_type, // recognized trigger type (muon fill, laser, pedestal, async readout)
  input wire [23:0] ttc_trig_num,  // trigger number
  output wire ttc_acq_ready,       // channels are ready for a readout
  output reg  ttc_acq_activated,

  // interface to Channel FPGAs
  input wire [4:0] acq_dones,
  output reg [4:0] acq_enable,

  // interface to Acquisition Event FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [31:0] fifo_data,

  // status connections
  output reg [5:0] state // state of finite state machine
);

  // state bits
  parameter IDLE              = 0;  // 01
  parameter ACQUIRE           = 1;  // 02
  parameter NEW_DDR3_BUFFER   = 2;  // 04
  parameter TRANSITION        = 3;  // 08
  parameter WAIT              = 4;  // 10
  parameter STORE_ACQ_INFO    = 5;  // 20
  

  reg [ 4:0] acq_trig_type;     // latched trigger type
  reg [23:0] acq_trig_num;      // latched trigger number
  reg [ 4:0] acq_dones_latched; // latched channel dones reported

  reg [ 5:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg [ 4:0] next_acq_dones_latched;
  reg [ 4:0] next_acq_enable;
  reg        next_ddr3_buffer;
  reg        next_ttc_acq_activated;

  wire new_fill_counter_zero;
  reg [4:0] new_fill_counter;
  reg init_new_fill_counter;
  always @(posedge clk) begin
    if ( reset )
      new_fill_counter[4:0] <= 5'd0;
    else if ( init_new_fill_counter )
      new_fill_counter[4:0] <= 5'd4;
    else if ( new_fill_counter_zero )
      // when it hits zero, hold it at zero
      new_fill_counter[4:0] <= 5'd0;
    else
      new_fill_counter[4:0] = new_fill_counter[4:0] - 1;
  end
  assign new_fill_counter_zero = (new_fill_counter[4:0] == 5'd0) ? 1'b1 : 1'b0;

  // delay the fill counter init to use as the fifo write enable
  // that should allow enough to have first latched the numbers of self triggers
  reg [2:0] shift_reg;
  always @(posedge clk) begin
    if ( reset )
      shift_reg[2:0] <= 3'd0;
    else 
      shift_reg <= {shift_reg[1:0], init_new_fill_counter};
  end
  assign selftrigger_fifo_wr_en = shift_reg[2];

  // combinational always block
  always @* begin
    nextstate = 6'd0;

    next_acq_trig_type    [ 4:0] = acq_trig_type    [ 4:0];
    next_acq_trig_num     [23:0] = acq_trig_num     [23:0];
    next_acq_dones_latched[ 4:0] = acq_dones_latched[ 4:0];
    next_ttc_acq_activated       = ttc_acq_activated;
    next_acq_enable       [4:0]  = acq_enable       [4:0];

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // tell the channels to begin acquiring data if we are accepting triggers
        if ( accept_self_triggers  ) begin
          // enable lines should be fixed and not set by the trigger type
          next_acq_enable[4:0] = chan_en[4:0];
          next_ttc_acq_activated = 1'b1;

          nextstate[ACQUIRE] = 1'b1;
        end
        else begin
          nextstate[IDLE]        = 1'b1;
          next_acq_enable[4:0]   = 5'b0;
          next_ttc_acq_activated = 1'b0;
        end
      end

      state[ACQUIRE] : begin
        // readout trigger received -- the ttc_trigger_receiver_selftrig has already filtered out other types of triggers aside from readout
        // we will stop acquisition of channel self-triggers while we wait for any final events in the channels to get written to the DDR3
        // If we are still acquiring data, go to the next buffer and proceed.  If not, we can process the trigger without flipping
        // the buffer
        if (ttc_trigger ) begin
          next_acq_dones_latched[4:0] = 5'b00000;

          next_acq_trig_type[ 4:0] = ttc_trig_type[ 4:0]; // latch trigger type
          next_acq_trig_num [23:0] = ttc_trig_num [23:0]; // latch trigger number
          //next_ttc_acq_activated   = 1'b0;                // clear flag

          // If we are still running, flag the new ddr3 buffer and have the channels proceed.
          // If not, just wait for the readout to complete
          //if ( accept_self_triggers ) begin
            nextstate[NEW_DDR3_BUFFER] = 1'b1;
          //end
          //else begin
          //  nextstate[WAIT] = 1'b1;
          //end
        end
        else begin
          nextstate[ACQUIRE] = 1'b1;
        end
      end

      // start a new buffer for writing.  This will also
      // cause any channel still writing to complete writing, and to
      // let channels know that they should acknowledge being done writing
      state[NEW_DDR3_BUFFER] : begin
      // flag that there is a new buffer to use
         nextstate[TRANSITION] = 1'b1;
      end

      state[TRANSITION] : begin
      // flag that there is a new buffer to use
         if ( new_fill_counter_zero )
            nextstate[WAIT] = 1'b1;
         else
            nextstate[TRANSITION] = 1'b1;
      end

      // wait for channels to report back done
      state[WAIT] : begin
        // update latched channel dones
        next_acq_dones_latched[4:0] = acq_dones_latched[4:0] | (acq_dones[4:0] & chan_en[4:0]);

        // keep the enabled channels acquiring data
        if ( accept_self_triggers ) begin
           next_acq_enable[4:0] = chan_en[4:0];
        end
        else begin
          next_acq_enable[4:0] = 5'b00000;
        end

        // check if all channels report done
        if ( acq_dones_latched[4:0] == chan_en[4:0] ) begin
          nextstate[STORE_ACQ_INFO] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end

      // store the event information in the FIFO, for the trigger processor
      state[STORE_ACQ_INFO] : begin
        // re-enable self triggering if we are still taking data
        if ( accept_self_triggers ) begin
          next_acq_enable[4:0] = chan_en[4:0];
        end
        else begin
          next_acq_enable[4:0] = 5'b00000;
          next_ttc_acq_activated = 1'b0;  // let the ttc trigger receiver know that we are no longer taking events

        end
        // FIFO accepted the data word
        if (fifo_ready) begin
            if ( accept_self_triggers ) begin
              next_acq_enable[4:0] = chan_en[4:0];
              nextstate[ACQUIRE] = 1'b1;
            end
            else begin
              next_acq_enable[4:0] = 5'b00000;
              nextstate[IDLE] = 1'b1;
            end
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
      state <= 6'd1 << IDLE;

      acq_trig_type    [ 4:0] <=  5'd0;
      acq_trig_num     [23:0] <= 24'd0;
      acq_dones_latched[ 4:0] <=  5'd0;
      ttc_acq_activated       <=  1'b0;

      acq_enable[4:0]       <= 5'd0;

    end
    else begin
      state <= nextstate;

      acq_trig_type    [ 4:0] <= next_acq_trig_type    [ 4:0];
      acq_trig_num     [23:0] <= next_acq_trig_num     [23:0];
      acq_dones_latched[ 4:0] <= next_acq_dones_latched[ 4:0];
      ttc_acq_activated       <= next_ttc_acq_activated;

      acq_enable[4:0]        <= next_acq_enable[4:0];

    end
  end
  
  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid      <=  1'b0;
      fifo_data[31:0] <= 32'd0;
      init_new_fill_counter <= 1'b0;
      new_fill_pause_triggers <= 1'b0;
    end
    else begin

      //defaults
      init_new_fill_counter <= 1'b0;
      new_fill_pause_triggers <= 1'b0;

      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[ACQUIRE] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
        end
        nextstate[NEW_DDR3_BUFFER] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
          init_new_fill_counter <= 1'b1;
          new_fill_pause_triggers <= 1'b1;
        end
        nextstate[TRANSITION] : begin
          fifo_valid      <=  1'b0;
          fifo_data[31:0] <= 32'd0;
          new_fill_pause_triggers <= 1'b1;
        end
        nextstate[WAIT] : begin
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
  assign ttc_acq_ready = (state[IDLE] == 1'b1) || (state[ACQUIRE] == 1'b1);
endmodule
