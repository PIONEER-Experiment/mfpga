// Finite state machine to encode commands that enable / disable
// accepting self-triggers and having active data acquisition in the
// channels

module acq_encode(

  // clock and reset
  input wire clk,   // 125 MHz clock
  input wire reset,

  // channel configuration
  input wire [4:0] chan_en,

  // enabling / status signals
  input accept_self_triggers,
  input wire channels_active,

  // the encoded signal to tell the channels to toggle which enable
  (* mark_debug = "true" *) output wire [4:0] acq_enable_encoded
);

  // a counter for
  (* mark_debug = "true" *) reg [27:0] length_counter;
  reg init_acq_count, init_trig_count, init_gap_count;
  (* mark_debug = "true" *) wire length_counter_zero;
  always @(posedge clk) begin
    if ( reset )
      // zero out the counter
      length_counter[27:0] <= 28'd0;
    else if ( init_acq_count )
      // we need a 64 ns pulse to encode enabling acquisition
      length_counter[27:0] <= 28'd8;
    else if ( init_trig_count )
      // we need a 32 ns pulse to encode enabling self-triggering
      length_counter[27:0] <= 28'd4;
    else if ( init_trig_count )
      // we'll wait a 200 ms between encode pulses
      length_counter[27:0] <= 28'h17D7840;
    else if ( length_counter_zero )
      // if at zero, keep at zero
      length_counter[27:0] <= 28'd0;
    else
      length_counter[27:0] = length_counter[27:0] - 1;
  end
  assign length_counter_zero = (length_counter[27:0] == 28'd0) ? 1'b1 : 1'b0;

  // state bits
  parameter IDLE              =  0;  // 001
  parameter INIT_ENABLE_ACQ   =  1;  // 002
  parameter ENABLE_ACQ        =  2;  // 004
  parameter ACQ_TRIG_GAP      =  3;  // 008
  parameter INIT_ENABLE_TRIG  =  4;  // 010
  parameter ENABLE_TRIG       =  5;  // 020
  parameter WAIT              =  6;  // 040
  parameter DISABLE_TRIG      =  7;  // 080
  parameter INIT_DISABLE_TRIG =  8;  // 100
  parameter TRIG_ACQ_GAP      =  9;  // 200
  parameter DISABLE_ACQ       = 10;  // 400
  parameter INIT_DISABLE_ACQ  = 11;  // 800
  
  (* mark_debug = "true" *) reg [ 4:0] encoded_acq_command;   // for output to the channels
  assign acq_enable_encoded[4:0] = encoded_acq_command;

  (* mark_debug = "true" *) reg [ 11:0]     state;
  reg [ 11:0] nextstate;

  // sync to the local clock
  (* mark_debug = "true" *) wire accept_self_triggers_125;
  sync_2stage sync_ast(
    .clk(clk),
    .in(accept_self_triggers),
    .out(accept_self_triggers_125)
  );
  (* mark_debug = "true" *) wire channels_active_125;
  sync_2stage sync_channels_active (
    .clk(clk),
    .in(channels_active),
    .out(channels_active_125)
  );

  // combinational always block
  always @* begin
    nextstate = 12'd0;

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // go encode the signal to enable
        if ( accept_self_triggers_125  ) begin
          nextstate[INIT_ENABLE_ACQ] = 1'b1;
        end
        else begin
          nextstate[IDLE]        = 1'b1;
        end
      end

      // stay here 1 clock cycle
      state[INIT_ENABLE_ACQ] :
        nextstate[ENABLE_ACQ] = 1'b1;

      state[ENABLE_ACQ] : begin
        // stay here until the counter counts down to keep the signal high
        if (length_counter_zero ) begin
            nextstate[ACQ_TRIG_GAP] = 1'b1;
        end
        else begin
          nextstate[ENABLE_ACQ] = 1'b1;
        end
      end

      state[ACQ_TRIG_GAP] : begin
        // stay here until the counter counts down for a gap between the enables
        if (length_counter_zero ) begin
            nextstate[INIT_ENABLE_TRIG] = 1'b1;
        end
        else begin
          nextstate[ACQ_TRIG_GAP] = 1'b1;
        end
      end

      // stay here 1 clock cycle
      state[INIT_ENABLE_TRIG] :
        nextstate[ENABLE_TRIG] = 1'b1;

      state[ENABLE_TRIG] : begin
        // stay here until the counter counts down to keep the signal high
        if (length_counter_zero ) begin
            nextstate[WAIT] = 1'b1;
        end
        else begin
          nextstate[ENABLE_TRIG] = 1'b1;
        end
      end

      // wait for FC7 to flag done taking triggers
      state[WAIT] : begin
        // keep the enabled channels acquiring data
        if ( ~accept_self_triggers_125 ) begin
          nextstate[INIT_DISABLE_TRIG] = 1'b1;
        end
        else begin
          nextstate[WAIT] = 1'b1;
        end
      end

      // stay here 1 clock cycle
      state[INIT_DISABLE_TRIG] :
        nextstate[DISABLE_TRIG] = 1'b1;

      // encode to disable triggering
      state[DISABLE_TRIG] : begin
        // stay here until the counter counts down to keep the signal high
        if (length_counter_zero ) begin
          nextstate[TRIG_ACQ_GAP] = 1'b1;
        end
        else begin
          nextstate[DISABLE_TRIG] = 1'b1;
        end
      end

      // stay here until channel_acq_controller_selftrig notes readout_done,
      // which means that no channels should be active any longer.  We use the
      // gap so that no self-triggers can sneak in after the final fill readout
      state[TRIG_ACQ_GAP] : begin
        if (channels_active_125) begin
          nextstate[TRIG_ACQ_GAP] = 1'b1;
        end
        else begin
          nextstate[INIT_DISABLE_ACQ] = 1'b1;
        end
      end

      // stay here 1 clock cycle
      state[INIT_DISABLE_ACQ] :
        nextstate[DISABLE_ACQ] = 1'b1;

      // encode to disable acquisition, then return to IDLE
      state[DISABLE_ACQ] : begin
        // stay here until the counter counts down to keep the signal high
        if (length_counter_zero ) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[DISABLE_ACQ] = 1'b1;
        end
      end



    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 12'd1 << IDLE;
    end
    else begin
      state <= nextstate;
    end
  end
  
  // datapath sequential always block
  always @(posedge clk) begin
    // defaults
    init_acq_count  <= 1'b0;
    init_trig_count <= 1'b0;
    init_gap_count  <= 1'b0;
    encoded_acq_command[4:0] <= 5'b00000;

    case (1'b1) // synopsys parallel_case full_case
      nextstate[IDLE] : begin
      end

      nextstate[INIT_ENABLE_ACQ] : begin
        init_acq_count     <=  1'b1;
      end

      nextstate[ENABLE_ACQ] : begin
        encoded_acq_command[4:0] <= chan_en[4:0];
      end

      nextstate[ACQ_TRIG_GAP] : begin
        init_gap_count     <=  1'b1;
      end

      nextstate[INIT_ENABLE_TRIG] : begin
        init_trig_count    <=  1'b1;
      end

      nextstate[ENABLE_TRIG] : begin
        encoded_acq_command[4:0] <= chan_en[4:0];
      end

      nextstate[WAIT] : begin
      end

      nextstate[INIT_DISABLE_TRIG] : begin
        init_trig_count     <=  1'b1;
      end

      nextstate[DISABLE_TRIG] : begin
        encoded_acq_command[4:0] <= chan_en[4:0];
      end

      nextstate[TRIG_ACQ_GAP] : begin
      end

      nextstate[INIT_DISABLE_ACQ] : begin
        init_acq_count     <=  1'b1;
      end

      nextstate[DISABLE_ACQ] : begin
        encoded_acq_command[4:0] <= chan_en[4:0];
      end

    endcase
  end

endmodule

