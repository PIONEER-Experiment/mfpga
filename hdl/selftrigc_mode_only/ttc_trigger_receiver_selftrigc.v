// Finite state machine to handle incoming TTC triggers
//st lkg --  we will need to add some logic somewhere so that the "acq_ready" means that
//st lkg     the previous readout command has completed
module ttc_trigger_receiver_selftrigc (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  input wire ttc_trigger,                // TTC trigger signal
  input wire [ 4:0] trig_type,           // trigger type
  //input wire [31:0] trig_settings,       // trigger settings
  //input wire [ 4:0] chan_en,             // enabled channels


  // channel acquisition controller interface
  input wire acq_ready,            // channels are ready to acquire data (or-reduce from 5 channels?)
  input wire acq_activated,        // the channel acquisition controller is in ACQUIRE and will act on a trigger
  //input wire accept_self_triggers, // self triggers will be collected when acq_activated allows
  output reg acq_trigger,          // trigger signal to trigger the async readout
  output reg [ 4:0] acq_trig_type, // recognized trigger type (async readout)
  output reg [23:0] acq_trig_num,  // trigger number, starts at 1
  input wire channel_acq_enabled,
  input wire run_active,           // the FC7 has not stopped the run (accept_self_triggers): an empty readout
                                   // trigger while this is high is data loss, after the stop it is the normal end

  // interface to TTC Trigger FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [127:0] fifo_data,

  // status connections
  //input wire selftriggers_seen,  // at least one channel has a trigger
  input wire [ 3:0] xadc_alarms,    // XADC alarm signals
  output reg [ 3:0] state,          // state of finite state machine
  output reg [23:0] trig_num,       // global trigger number
  output reg [43:0] trig_timestamp, // global trigger timestamp

  // error connections
  output wire error_trig_rate,           // trigger received while acquiring data (ERROR state; unreachable since 6.6.9)
  output wire [7:0] triggers_downgraded, // real triggers turned into empty events because the acquisition controller stayed busy
  output reg  empty_midrun               // one clock: a readout trigger was answered empty while the run was active (error capture)
);

  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter SEND_TRIGGER    = 1;
  parameter STORE_TRIG_INFO = 2;
//  parameter TRIG_HI         = 3;
  parameter ERROR           = 3;

wire acq_ready_40;
sync_2stage ar_sync (
  .clk(clk),
  .in(acq_ready),
  .out(acq_ready_40)
);

  reg        empty_event;        // flag for an empty event response
  reg        empty_payload;      // flag for an async readout with no processed triggers
  reg [43:0] trig_timestamp_cnt; // clock cycle count
  reg [23:0] acq_event_cnt;      // # of triggers passed to channel, starts at 1
  reg [ 3:0] acq_xadc_alarms;    // XADC alarm signals

  reg [ 3:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg        next_empty_event;
  // bounded wait for the acquisition controller in SEND_TRIGGER: 2^16 TTC clocks = 1.6 ms
  reg  [16:0] ready_wait_cntr;
  wire        ready_wait_timeout = ready_wait_cntr[16];
  always @(posedge clk) begin
    if (reset || !state[SEND_TRIGGER]) ready_wait_cntr <= 17'd0;
    else if (!ready_wait_timeout)      ready_wait_cntr <= ready_wait_cntr + 1;
  end
  reg  [7:0] ready_wait_timeouts;        // how many readout triggers were answered with an empty event because
                                         // the acquisition controller was busy (either path below; status)
  reg  [7:0] next_ready_wait_timeouts;
  reg        next_empty_midrun;
  reg        next_empty_payload;
  reg [23:0] next_trig_num;
  reg [43:0] next_trig_timestamp;
  reg [23:0] next_acq_event_cnt;
  reg [ 3:0] next_acq_xadc_alarms;
  reg        next_acq_trigger;


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type      [ 4:0] = acq_trig_type      [ 4:0];
    next_acq_trig_num       [23:0] = acq_trig_num       [23:0];
    next_empty_event               = empty_event;
    next_ready_wait_timeouts       = ready_wait_timeouts;
    next_empty_midrun              = 1'b0;
    next_empty_payload             = empty_payload;
    next_trig_num           [23:0] = trig_num           [23:0];
    next_trig_timestamp     [43:0] = trig_timestamp     [43:0];
    next_acq_event_cnt      [23:0] = acq_event_cnt      [23:0];
    next_acq_xadc_alarms    [ 3:0] = acq_xadc_alarms    [ 3:0];
//st    next_ddr3_overflow_count[31:0] = ddr3_overflow_count[31:0];

    next_acq_trigger = 1'b0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (ttc_trigger) begin
          next_acq_trig_num   [23:0] = trig_num[23:0];           // latch trigger number
          next_trig_num       [23:0] = trig_num[23:0] + 1;       // increment trigger counter
          next_acq_trig_type  [ 4:0] = trig_type[4:0];           // latch trigger type
          next_trig_timestamp [43:0] = trig_timestamp_cnt[43:0]; // latch trigger timestamp counter
          next_acq_xadc_alarms[ 3:0] = xadc_alarms[3:0];         // current XADC alarms

          // determine empty_event flag ahead of time;
          // this is to ensure that it has been updated before writing to the FIFO
          // only respond to "async" readout requests in this mode, and only when the channel
          // acquisition controller is in a state to act on the trigger ('acq_activated'): after the
          // end-of-run stop it returns to IDLE once it has flushed the first trigger that follows, and
          // any further trigger (the FC7's final async readout trigger) must become an empty event,
          // otherwise the trigger processor waits for an acquisition record that is never written
          if ((trig_type[4:0] != 5'b00100) | ~channel_acq_enabled | ~acq_activated) begin
             next_empty_event = 1'b1; // indicate to send an empty event
             // a readout trigger that would have been acted on, but for the acquisition
             // controller being busy (in WAIT closing the previous fill, or already past
             // the run end): count it, it is an event with no data in the DAQ stream
             if ((trig_type[4:0] == 5'b00100) & channel_acq_enabled) begin
               next_ready_wait_timeouts = ready_wait_timeouts + 1;
               next_empty_midrun = run_active;
             end
           end

          nextstate[SEND_TRIGGER] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // pass trigger et al. to channel acquisition controller, if the trigger type is enabled
      state[SEND_TRIGGER] : begin
        // An empty event needs nothing from the acquisition controller: store it straight away.
        if (empty_event) begin
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
        // A real readout trigger is passed to the acquisition controller as soon as it can take
        // one (IDLE or ACQUIRE).  While it is still flushing the previous trigger we wait here,
        // bounded; if it has not come back within the bound the trigger is downgraded to an
        // empty event, so that the trigger processor and the DAQ stay in step.  Until 6.6.9 a
        // trigger arriving while the controller was busy sent this machine to ERROR, which
        // stopped every later trigger for good.
        else if (acq_ready) begin
          next_acq_trigger         = 1'b1;                    // pass on the trigger
          next_acq_event_cnt[23:0] = acq_event_cnt[23:0] + 1; // increment accepted event counter
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
        else if (ready_wait_timeout) begin
          next_empty_event = 1'b1;
          next_empty_midrun = run_active;
          next_ready_wait_timeouts = ready_wait_timeouts + 1;
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
        else begin
          nextstate[SEND_TRIGGER] = 1'b1;
        end
      end
      // store the trigger information in the FIFO, for the trigger processor
      state[STORE_TRIG_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          next_empty_event   = 1'b0; // clear the empty event flag
          next_empty_payload = 1'b0; // clear the empty payload flag
          nextstate[IDLE] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
      end

//      // ensure that the TTC trigger signal has gone low
//      state[TRIG_HI] : begin
//         if ( ttc_trigger ) begin
//            nextstate[TRIG_HI] = 1'b1;
//         end
//         else begin
//            nextstate[IDLE] = 1'b1;
//         end
//      end

      // trigger received while acquiring data
      state[ERROR] : begin
        nextstate[ERROR] = 1'b1; // hard error, stay here
      end
    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 4'd1 << IDLE;

      empty_event               <=  1'b0;
      ready_wait_timeouts       <=  8'd0;
      empty_midrun              <=  1'b0;
      empty_payload             <=  1'b0;
      acq_trig_type      [ 4:0] <=  5'd0;
      acq_xadc_alarms    [ 3:0] <=  4'd0;
//st      ddr3_overflow_count[31:0] <= 32'd0;
    end
    else begin
      state <= nextstate;

      empty_event               <= next_empty_event;
      ready_wait_timeouts       <= next_ready_wait_timeouts;
      empty_midrun              <= next_empty_midrun;
      empty_payload             <= next_empty_payload;
      acq_trig_type      [ 4:0] <= next_acq_trig_type      [ 4:0];
      acq_xadc_alarms    [ 3:0] <= next_acq_xadc_alarms    [ 3:0];
      acq_trigger               <= next_acq_trigger;
//st      ddr3_overflow_count[31:0] <= next_ddr3_overflow_count[31:0];
    end

    // reset trigger number
    if (reset | reset_trig_num) begin
      // count starts at 1.
      trig_num     [23:0] <= 24'd1;
      acq_trig_num [23:0] <= 24'd1;
      acq_event_cnt[23:0] <= 24'd1;
    end
    else begin
      trig_num     [23:0] <= next_trig_num     [23:0];
      acq_trig_num [23:0] <= next_acq_trig_num [23:0];
      acq_event_cnt[23:0] <= next_acq_event_cnt[23:0];
    end
    
    // reset trigger timestamp and counter
    if (reset | reset_trig_timestamp) begin
      trig_timestamp    [43:0] <= 44'd0;
      trig_timestamp_cnt[43:0] <= 44'd0;
    end
    else begin
      trig_timestamp    [43:0] <= next_trig_timestamp[43:0];
      trig_timestamp_cnt[43:0] <= trig_timestamp_cnt [43:0] + 1;
    end
  end
  

  // datapath sequential always block
  always @(posedge clk) begin
    if (reset) begin
      fifo_valid       <=   1'b0;
      fifo_data[127:0] <= 128'd0;
    end
    else begin
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE] : begin
          fifo_valid       <=   1'b0;
          fifo_data[127:0] <= 128'd0;
        end
        nextstate[SEND_TRIGGER] : begin
          fifo_valid       <=   1'b0;
          fifo_data[127:0] <= 128'd0;
        end
        nextstate[STORE_TRIG_INFO] : begin
          fifo_valid       <= 1'b1;
          // the empty flags as they will be in STORE_TRIG_INFO (next_*): a trigger downgraded on the way
          // out of SEND_TRIGGER (ready_wait_timeout) sets its flag in the same clock, and was written
          // to the FIFO as a real trigger before 6.8.0
          fifo_data[127:0] <= {25'd0, next_empty_payload, acq_xadc_alarms[3:0], next_empty_event, acq_trig_type[4:0], acq_event_cnt[23:0], acq_trig_num[23:0], trig_timestamp[43:0]};
        end
        nextstate[ERROR] : begin
          fifo_valid       <=   1'b0;
          fifo_data[127:0] <= 128'd0;
        end
      endcase
    end
  end

  // outputs based on states
  assign error_trig_rate = (state[ERROR] == 1'b1);
  assign triggers_downgraded = ready_wait_timeouts;

endmodule
