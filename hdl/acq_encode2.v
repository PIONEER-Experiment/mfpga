// Finite state machine to encode commands that enable / disable
// accepting self-triggers and having active data acquisition in the
// channels

// THis version does not encode the enables for the channel.  The
// channel acquisition lines go high in this version when accept_self_triggers
// goes high.  Locally it still differentiates between acquisition and triggering  

// this version also needs cleaning up after this initial hack.

module acq_encode2(

  // clock and reset
  input wire clk,   // 125 MHz clock
  input wire reset,

  // channel configuration
input wire [4:0] chan_en,

  // enabling / status signals
  input accept_self_triggers,
  input wire channels_active,
  input wire event_readout_pending,

  // the encoded signal to tell the channels to toggle which enable
output wire [4:0] acq_enable_encoded,
  output reg  self_triggering_enabled,
  output reg  channel_acq_enabled,
  output reg  clear_trigger_counts
);

  // a counter for
  reg [28:0] length_counter;
  reg init_gap_count, init_eor_count, init_clear_hold, init_short_hold_count;
  wire length_counter_zero;
  always @(posedge clk) begin
    if ( reset )
      // zero out the counter
      length_counter[28:0] <= 29'd0;
    else if ( init_gap_count )
      // we will wait a 1 us (not 200 ms) between encode pulses
      //length_counter[28:0] <= 28'h17D7840; // 200 ms in 8 ns clock ticks
      length_counter[28:0] <= 29'h7D;        //   1 us in 8 ns clock ticks
    else if ( init_clear_hold )
      // we will hold the clear counters pulse for 1 us 
      length_counter[28:0] <= 29'd128;        //   1 us in 8 ns clock ticks
    else if ( init_eor_count )
      // end-of-run gap before disabling acquisition / zeroing counters
      // (CCC does its final read after 2 s); 62.5M ticks = 0.5 s
//      length_counter[28:0] <= 29'd312500000;        //   2.5 s in 8 ns clock ticks
      length_counter[28:0] <= 29'd62500000;        //   0.5 s in 8 ns clock ticks
    else if ( init_short_hold_count )
      // we will hold the enable-acq / disable-acq pulses for 40 ns
      length_counter[28:0] <= 29'd5;        //   40 ns in 8 ns clock ticks
    else if ( length_counter_zero )
      // if at zero, keep at zero
      length_counter[28:0] <= 29'd0;
    else
      length_counter[28:0] <= length_counter[28:0] - 1;
  end
  assign length_counter_zero = (length_counter[28:0] == 29'd0) ? 1'b1 : 1'b0;

  // state bits
  parameter IDLE              =  0;  // 0001
  parameter ENABLE_ACQ        =  1;  // 0002
  parameter ENABLE_ACQ_HOLD   =  2;  // 0004  hold the enable-acq pulse high for 40 ns
  parameter INIT_GAP          =  3;  // 0008  one cycle to load the gap counter
  parameter ACQ_TRIG_GAP      =  4;  // 0010
  parameter ENABLE_TRIG       =  5;  // 0020
  parameter WAIT              =  6;  // 0040
  parameter DISABLE_TRIG      =  7;  // 0080
  parameter TRIG_ACQ_GAP      =  8;  // 0100
  parameter DISABLE_ACQ       =  9;  // 0200
  parameter PREPARE_TO_END    = 10;  // 0400  hold the disable-acq pulse high for 40 ns
  parameter INIT_TRIGS_GAP    = 11;  // 0800
  parameter CLEAR_TRIGS_GAP   = 12;  // 1000
  parameter CLEAR_TRIGS       = 13;  // 2000
  parameter CLEAR_TRIGS_HOLD  = 14;  // 4000
  
  reg [ 4:0] encoded_acq_command;   // for output to the channels
  assign acq_enable_encoded[4:0] = encoded_acq_command;

  reg [ 14:0]     state;
  reg [ 14:0] nextstate;

  // sync to the local clock
  wire accept_self_triggers_125;
  sync_2stage sync_ast(
    .clk(clk),
    .in(accept_self_triggers),
    .out(accept_self_triggers_125)
  );
  wire channels_active_125;
  sync_2stage sync_channels_active (
    .clk(clk),
    .in(channels_active),
    .out(channels_active_125)
  );
  wire event_readout_pending_125;
  sync_2stage sync_evreadoutpend (
    .clk(clk),
    .in(event_readout_pending),
    .out(event_readout_pending_125)
  );

  // combinational always block
  always @* begin
    nextstate = 15'd0;

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // go encode the signal to enable
        if ( accept_self_triggers_125  ) begin
          nextstate[ENABLE_ACQ] = 1'b1;
        end
        else begin
          nextstate[IDLE]        = 1'b1;
        end
      end

     // stay here 1 clock cycle -- raise the line and start the 40 ns hold counter
      state[ENABLE_ACQ] : begin
        nextstate[ENABLE_ACQ_HOLD] = 1'b1;
      end

      // keep the line high until the hold counter expires. The channel samples
      // this line through a 2-flop synchroniser on an unrelated 125 MHz clock,
      // so a single-clock pulse is not reliably captured.
      state[ENABLE_ACQ_HOLD] : begin
        if (length_counter_zero ) begin
          nextstate[INIT_GAP] = 1'b1;
        end
        else begin
          nextstate[ENABLE_ACQ_HOLD] = 1'b1;
        end
      end

      // stay here 1 clock cycle, line low, to load the gap counter
      state[INIT_GAP] : begin
        nextstate[ACQ_TRIG_GAP] = 1'b1;
      end

      state[ACQ_TRIG_GAP] : begin
        // stay here until the counter counts down for a gap between the enables
        if (length_counter_zero ) begin
            nextstate[ENABLE_TRIG] = 1'b1;
        end
        else begin
          nextstate[ACQ_TRIG_GAP] = 1'b1;
        end
      end

      // stay here 1 clock cycle
      state[ENABLE_TRIG] : begin
        nextstate[WAIT] = 1'b1;
      end

      // wait for FC7 to flag done taking triggers
      state[WAIT] : begin
        // keep the enabled channels acquiring data
        if ( ~accept_self_triggers_125 ) begin
          nextstate[DISABLE_TRIG] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end

      // stay here 1 clock cycle, disabling trigger acceptance. Initialize the gap counter
      state[DISABLE_TRIG] : begin
        nextstate[TRIG_ACQ_GAP] = 1'b1;
      end

      // stay here until channel_acq_controller_selftrig notes readout_done,
      // which means that no channels should be active any longer.  We use the
      // gap so that no self-triggers can sneak in after the final fill readout
      state[TRIG_ACQ_GAP] : begin
        if (channels_active_125 || event_readout_pending_125) begin
          nextstate[TRIG_ACQ_GAP] = 1'b1;
        end
        else begin
          if ( length_counter_zero ) begin
            nextstate[DISABLE_ACQ] = 1'b1;
          end
          else begin
            nextstate[TRIG_ACQ_GAP] = 1'b1;
          end
        end
      end

      // stay here 1 clock cycle.  Disable acquisition and start count for 2.5 s gap to clear
      state[DISABLE_ACQ] : begin
        nextstate[PREPARE_TO_END] = 1'b1;
      end

      // hold the signal to disable for a few cycles
      state[PREPARE_TO_END] : begin
        if ( length_counter_zero ) 
          nextstate[INIT_TRIGS_GAP] = 1'b1;
        else
          nextstate[PREPARE_TO_END] = 1'b1;
      end

      // stay here 1 cycle to initialize the counter
      state[INIT_TRIGS_GAP] : begin
          nextstate[CLEAR_TRIGS_GAP] = 1'b1;
      end

      // wait a bit, clear the trigger counters, then return to IDLE
      state[CLEAR_TRIGS_GAP] : begin
        // stay here until the counter counts down
        if (length_counter_zero ) begin
          nextstate[CLEAR_TRIGS] = 1'b1;
        end
        else begin
          nextstate[CLEAR_TRIGS_GAP] = 1'b1;
        end
      end

      // stay here 1 cycle to start the clear counters signal
      state[CLEAR_TRIGS] : begin
        nextstate[CLEAR_TRIGS_HOLD] = 1'b1;
      end

      // hold the clear counters signal
      state[CLEAR_TRIGS_HOLD] : begin
        if (length_counter_zero ) begin
           nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[CLEAR_TRIGS_HOLD] = 1'b1;
        end
      end



    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 15'd1 << IDLE;
    end
    else begin
      state <= nextstate;
    end
  end
  
  // datapath sequential always block
  always @(posedge clk) begin
    // defaults
    init_clear_hold          <= 1'b0;
    init_gap_count           <= 1'b0;
    init_eor_count           <= 1'b0;
    init_short_hold_count    <= 1'b0;
    encoded_acq_command[4:0] <= 5'b00000;
    clear_trigger_counts     <= 1'b0;
    self_triggering_enabled  <= 1'b0;
    channel_acq_enabled      <= 1'b0;

    if (reset) begin
      self_triggering_enabled <= 1'b0;
      channel_acq_enabled     <= 1'b0;
    end
    else begin

      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE] : begin
        end
  
        nextstate[ENABLE_ACQ] : begin
          encoded_acq_command[4:0] <= chan_en[4:0];
          channel_acq_enabled      <= 1'b1;
          init_short_hold_count    <= 1'b1;
        end

        nextstate[ENABLE_ACQ_HOLD] : begin
          encoded_acq_command[4:0] <= chan_en[4:0];   // hold the pulse high for 40 ns
          channel_acq_enabled      <= 1'b1;
        end

        nextstate[INIT_GAP] : begin
          channel_acq_enabled      <= 1'b1;
          init_gap_count           <= 1'b1;
        end
  
        nextstate[ACQ_TRIG_GAP] : begin
          channel_acq_enabled      <= 1'b1;
        end
  
        nextstate[ENABLE_TRIG] : begin
          encoded_acq_command[4:0] <= chan_en[4:0];
          channel_acq_enabled      <= 1'b1;
          self_triggering_enabled  <= 1'b1;
        end
  
        nextstate[WAIT] : begin
          encoded_acq_command[4:0] <= chan_en[4:0];
          channel_acq_enabled      <= 1'b1;
          self_triggering_enabled  <= 1'b1;
        end
  
        // zero out the enable triggering signal for the channels
        // wait a good long time for a final readout trigger to come before
        // disabling the data acq
        nextstate[DISABLE_TRIG] : begin
          channel_acq_enabled      <= 1'b1;
          init_eor_count           <= 1'b1;
        end
  
        nextstate[TRIG_ACQ_GAP] : begin
          channel_acq_enabled      <= 1'b1;
        end
  
        nextstate[DISABLE_ACQ] : begin
          // the channel will wait for a brief reappearance
          encoded_acq_command[4:0] <= chan_en[4:0];
          init_short_hold_count    <= 1'b1; 
       end

        nextstate[PREPARE_TO_END] : begin
          encoded_acq_command[4:0] <= chan_en[4:0];   // hold the disable-acq pulse high for 40 ns
        end

        nextstate[INIT_TRIGS_GAP] : begin
          init_eor_count      <= 1'b1;
        end
 
        nextstate[CLEAR_TRIGS_GAP] : begin
        end
  
        nextstate[CLEAR_TRIGS] : begin
          init_clear_hold      <= 1'b1;
          clear_trigger_counts <= 1'b1;
        end

        nextstate[CLEAR_TRIGS_HOLD] : begin
          clear_trigger_counts <= 1'b1;
        end

      endcase
    end
  end

endmodule

