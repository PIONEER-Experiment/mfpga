// Finite state machine to handle incoming TTC triggers

module ttc_trigger_receiver (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  input wire trigger,                    // TTC trigger signal
  input wire [ 4:0] trig_type,           // trigger type
  input wire [31:0] trig_settings,       // trigger settings
  input wire [22:0] thres_ddr3_overflow, // DDR3 overflow threshold
  input wire [ 4:0] chan_en,             // enabled channels
  input wire [23:0] pulse_trig_num,      // pulse trigger number
  input wire pulse_trigger,              // front panel trigger signal to channels

  // command manager interface
  input wire readout_done, // a readout has completed

  // read out size for each channel
  input wire [22:0] readout_size_chan0,
  input wire [22:0] readout_size_chan1,
  input wire [22:0] readout_size_chan2,
  input wire [22:0] readout_size_chan3,
  input wire [22:0] readout_size_chan4,

  // set burst count for each channel
  input wire [22:0] burst_count_chan0,
  input wire [22:0] burst_count_chan1,
  input wire [22:0] burst_count_chan2,
  input wire [22:0] burst_count_chan3,
  input wire [22:0] burst_count_chan4,

  // set waveform count for each channel
  input wire [11:0] wfm_count_chan0,
  input wire [11:0] wfm_count_chan1,
  input wire [11:0] wfm_count_chan2,
  input wire [11:0] wfm_count_chan3,
  input wire [11:0] wfm_count_chan4,

  // channel acquisition controller interface
  input wire acq_ready,            // channels are ready to acquire data
  input wire acq_activated,
  output reg acq_trigger,          // trigger signal
  output reg [ 4:0] acq_trig_type, // recognized trigger type (muon fill, laser, pedestal, async readout)
  output reg [23:0] acq_trig_num,  // trigger number, starts at 1

  // interface to TTC Trigger FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [127:0] fifo_data,

  // status connections
  input wire async_mode,            // asynchronous mode select
  input wire cbuf_mode,             // circular buffer mode select
  input wire cbuf_primed,           // cbuf mode: channels' circular buffers hold a full buffer of this run's data
  input wire accept_pulse_triggers, // accept front panel triggers select
  input wire [ 3:0] xadc_alarms,    // XADC alarm signals
  output reg [ 3:0] state,          // state of finite state machine
  output reg [23:0] trig_num,       // global trigger number
  output reg [43:0] trig_timestamp, // global trigger timestamp

  // number of bursts stored in the DDR3
  output reg [22:0] stored_bursts_chan0,
  output reg [22:0] stored_bursts_chan1,
  output reg [22:0] stored_bursts_chan2,
  output reg [22:0] stored_bursts_chan3,
  output reg [22:0] stored_bursts_chan4,

  // error connections
  output reg [31:0] ddr3_overflow_count, // number of triggers received that would overflow DDR3
  output wire ddr3_almost_full,          // DDR3 overflow warning, combined for all channels
  output wire error_trig_rate,           // a trigger arrived while the channels were still acquiring (sticky since 6.8.0)
  output reg  [7:0] triggers_downgraded, // such triggers, answered with an empty event (6.8.0; mod 256)
  output reg  empty_midrun               // one clock: such a trigger (error capture, data loss)
);

  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter SEND_TRIGGER    = 1;
  parameter STORE_TRIG_INFO = 2;
  parameter ERROR           = 3;

  reg        empty_event;        // flag for an empty event response
  reg        empty_payload;      // flag for an async readout with no processed triggers
  reg        cbuf_blocked;       // flag: trigger arrived before the circular buffers were primed (cbuf mode)
  reg [43:0] trig_timestamp_cnt; // clock cycle count
  reg [23:0] acq_event_cnt;      // channel's trigger number, starts at 1
  reg [ 3:0] acq_xadc_alarms;    // XADC alarm signals

  // burst count of initiated acquisitions
  wire [22:0] acq_size_chan0;
  wire [22:0] acq_size_chan1;
  wire [22:0] acq_size_chan2;
  wire [22:0] acq_size_chan3;
  wire [22:0] acq_size_chan4;

  assign acq_size_chan0 = (burst_count_chan0[22:0] + 1)*wfm_count_chan0[11:0] + 2;
  assign acq_size_chan1 = (burst_count_chan1[22:0] + 1)*wfm_count_chan1[11:0] + 2;
  assign acq_size_chan2 = (burst_count_chan2[22:0] + 1)*wfm_count_chan2[11:0] + 2;
  assign acq_size_chan3 = (burst_count_chan3[22:0] + 1)*wfm_count_chan3[11:0] + 2;
  assign acq_size_chan4 = (burst_count_chan4[22:0] + 1)*wfm_count_chan4[11:0] + 2;

  // mux overflow warnings for all channels
  assign ddr3_almost_full = (stored_bursts_chan0[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan1[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan2[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan3[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan4[22:0] > thres_ddr3_overflow[22:0]);

  // DDR3 is full in a channel
  wire ddr3_full;
  assign ddr3_full = ((8388608 - stored_bursts_chan0[22:0]) < chan_en[0]*acq_size_chan0[22:0]) |
                     ((8388608 - stored_bursts_chan1[22:0]) < chan_en[1]*acq_size_chan1[22:0]) |
                     ((8388608 - stored_bursts_chan2[22:0]) < chan_en[2]*acq_size_chan2[22:0]) |
                     ((8388608 - stored_bursts_chan3[22:0]) < chan_en[3]*acq_size_chan3[22:0]) |
                     ((8388608 - stored_bursts_chan4[22:0]) < chan_en[4]*acq_size_chan4[22:0]);

  reg [ 3:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg        next_empty_event;
  reg        next_empty_payload;
  reg        next_cbuf_blocked;
  reg [23:0] next_trig_num;
  reg [43:0] next_trig_timestamp;
  reg [23:0] next_acq_event_cnt;
  reg [ 3:0] next_acq_xadc_alarms;
  reg [31:0] next_ddr3_overflow_count;
  reg        next_acq_trigger;
  reg        next_empty_midrun;
  // A trigger that arrives while the channels are still acquiring the previous one (acq_ready low)
  // cannot be acted on.  Until 6.8.0 it sent this machine to ERROR, which stopped every later
  // trigger for good and left the trigger processor waiting for an event that never came.  It is
  // now answered with an empty event at once (the acquisition is not delayed: in this image the
  // trigger time is the data's time), counted, reported to the error capture as a data loss, and
  // 'error_trig_rate' is latched so that the TTS still reports a trigger-rate error, as before.
  reg        rate_error_seen;


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_acq_trig_type      [ 4:0] = acq_trig_type      [ 4:0];
    next_acq_trig_num       [23:0] = acq_trig_num       [23:0];
    next_empty_event               = empty_event;
    next_empty_payload             = empty_payload;
    next_cbuf_blocked              = cbuf_blocked;
    next_trig_num           [23:0] = trig_num           [23:0];
    next_trig_timestamp     [43:0] = trig_timestamp     [43:0];
    next_acq_event_cnt      [23:0] = acq_event_cnt      [23:0];
    next_acq_xadc_alarms    [ 3:0] = acq_xadc_alarms    [ 3:0];
    next_ddr3_overflow_count[31:0] = ddr3_overflow_count[31:0];

    next_acq_trigger = 1'b0; // default
    next_empty_midrun = 1'b0;

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          next_acq_trig_num   [23:0] = trig_num[23:0];           // latch trigger number
          next_trig_num       [23:0] = trig_num[23:0] + 1;       // increment trigger counter
          next_acq_trig_type  [ 4:0] = trig_type[4:0];           // latch trigger type
          next_trig_timestamp [43:0] = trig_timestamp_cnt[43:0]; // latch trigger timestamp counter
          next_acq_xadc_alarms[ 3:0] = xadc_alarms[3:0];         // current XADC alarms

          // determine empty_event flag ahead of time;
          // this is to ensure that it has been updated before writing to the FIFO
          if (~async_mode) begin
            // in synchronous mode
            if (~trig_settings[trig_type] | ddr3_full) begin
              next_empty_event = 1'b1; // indicate to send an empty event
            end
            // circular buffer mode: until the channels have written a full
            // buffer since cbuf_acquire rose, a trigger's pre-trigger window
            // would read memory not written this run.  Answer such triggers
            // with an empty event instead of passing them to the channels.
            // Latched here so the decision cannot change between IDLE and
            // SEND_TRIGGER.
            if (cbuf_mode & ~cbuf_primed) begin
              next_empty_event  = 1'b1;
              next_cbuf_blocked = 1'b1;
            end
          end
          else begin
            // in asynchronous mode
            if ((trig_type[4:0] != 5'b00100) | ~acq_activated) begin
              next_empty_event = 1'b1; // indicate to send an empty event
            end
            else if (pulse_trig_num[23:0] == 24'd0) begin
              next_empty_payload = 1'b1; // indicate to skip channel payloads
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
        // pulse trigger to channels is still high
        if (accept_pulse_triggers & async_mode & pulse_trigger) begin
          nextstate[SEND_TRIGGER] = 1'b1; // wait here
        end
        // channels are not ready for data collection: answer with an empty event (see above)
        else if (~acq_ready) begin
          next_empty_event  = 1'b1;
          next_empty_midrun = 1'b1;
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
        // in synchronous mode
        else if (~async_mode) begin
          // check for an allowed trigger
          // 1 = pass trigger, 0 = block trigger
          // (also blocked: cbuf mode before the circular buffers are primed)
          if (~trig_settings[acq_trig_type] | cbuf_blocked) begin
            nextstate[STORE_TRIG_INFO] = 1'b1;
          end
          // this trigger would overwrite valid data in DDR3, in synchronous mode
          else if (ddr3_full) begin
            next_ddr3_overflow_count[31:0] = ddr3_overflow_count[31:0] + 1; // increment overflow error counter
            nextstate[STORE_TRIG_INFO] = 1'b1;
          end
          // pass along the trigger to channel acquisition controller
          else begin
            next_acq_trigger         = 1'b1;                    // pass on the trigger
            next_acq_event_cnt[23:0] = acq_event_cnt[23:0] + 1; // increment accepted event counter
            nextstate[STORE_TRIG_INFO] = 1'b1;
          end
        end
        // in asynchronous mode
        else begin
          // check for an empty event
          if (empty_event) begin
            nextstate[STORE_TRIG_INFO] = 1'b1;
          end
          // this is an asynchronous readout trigger
          // pass along the trigger to channel acquisition controller (async)
          else begin
            next_acq_trigger         = 1'b1;                    // pass on the trigger
            next_acq_event_cnt[23:0] = acq_event_cnt[23:0] + 1; // increment accepted event counter
            nextstate[STORE_TRIG_INFO] = 1'b1;
          end
        end
      end
      // store the trigger information in the FIFO, for the trigger processor
      state[STORE_TRIG_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          next_empty_event   = 1'b0; // clear the empty event flag
          next_empty_payload = 1'b0; // clear the empty payload flag
          next_cbuf_blocked  = 1'b0; // clear the cbuf-not-primed flag
          nextstate[IDLE] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
      end
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
      empty_payload             <=  1'b0;
      cbuf_blocked              <=  1'b0;
      acq_trig_type      [ 4:0] <=  5'd0;
      acq_xadc_alarms    [ 3:0] <=  4'd0;
      ddr3_overflow_count[31:0] <= 32'd0;
      acq_trigger               <=  1'b0;
      empty_midrun              <=  1'b0;
      triggers_downgraded       <=  8'd0;
      rate_error_seen           <=  1'b0;
    end
    else begin
      state <= nextstate;
      empty_midrun              <= next_empty_midrun;
      if (next_empty_midrun) begin
        triggers_downgraded     <= triggers_downgraded + 8'd1;
        rate_error_seen         <= 1'b1;
      end

      empty_event               <= next_empty_event;
      empty_payload             <= next_empty_payload;
      cbuf_blocked              <= next_cbuf_blocked;
      acq_trig_type      [ 4:0] <= next_acq_trig_type      [ 4:0];
      acq_xadc_alarms    [ 3:0] <= next_acq_xadc_alarms    [ 3:0];
      ddr3_overflow_count[31:0] <= next_ddr3_overflow_count[31:0];
      acq_trigger               <= next_acq_trigger;
    end

    // reset trigger number
    if (reset | reset_trig_num) begin
      // start counts at 1
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

    // reset stored bursts
    if (reset | async_mode) begin
      stored_bursts_chan0[22:0] <= 23'd0;
      stored_bursts_chan1[22:0] <= 23'd0;
      stored_bursts_chan2[22:0] <= 23'd0;
      stored_bursts_chan3[22:0] <= 23'd0;
      stored_bursts_chan4[22:0] <= 23'd0;
    end
    else if (acq_trigger & ~empty_event & ~readout_done) begin
      stored_bursts_chan0[22:0] <= stored_bursts_chan0[22:0] + chan_en[0]*acq_size_chan0[22:0];
      stored_bursts_chan1[22:0] <= stored_bursts_chan1[22:0] + chan_en[1]*acq_size_chan1[22:0];
      stored_bursts_chan2[22:0] <= stored_bursts_chan2[22:0] + chan_en[2]*acq_size_chan2[22:0];
      stored_bursts_chan3[22:0] <= stored_bursts_chan3[22:0] + chan_en[3]*acq_size_chan3[22:0];
      stored_bursts_chan4[22:0] <= stored_bursts_chan4[22:0] + chan_en[4]*acq_size_chan4[22:0];
    end
    else if (~acq_trigger & readout_done) begin
      stored_bursts_chan0[22:0] <= stored_bursts_chan0[22:0] - chan_en[0]*readout_size_chan0[22:0];
      stored_bursts_chan1[22:0] <= stored_bursts_chan1[22:0] - chan_en[1]*readout_size_chan1[22:0];
      stored_bursts_chan2[22:0] <= stored_bursts_chan2[22:0] - chan_en[2]*readout_size_chan2[22:0];
      stored_bursts_chan3[22:0] <= stored_bursts_chan3[22:0] - chan_en[3]*readout_size_chan3[22:0];
      stored_bursts_chan4[22:0] <= stored_bursts_chan4[22:0] - chan_en[4]*readout_size_chan4[22:0];
    end
    else if (acq_trigger & ~empty_event & readout_done) begin
      stored_bursts_chan0[22:0] <= stored_bursts_chan0[22:0] + chan_en[0]*acq_size_chan0[22:0] - chan_en[0]*readout_size_chan0[22:0];
      stored_bursts_chan1[22:0] <= stored_bursts_chan1[22:0] + chan_en[1]*acq_size_chan1[22:0] - chan_en[1]*readout_size_chan1[22:0];
      stored_bursts_chan2[22:0] <= stored_bursts_chan2[22:0] + chan_en[2]*acq_size_chan2[22:0] - chan_en[2]*readout_size_chan2[22:0];
      stored_bursts_chan3[22:0] <= stored_bursts_chan3[22:0] + chan_en[3]*acq_size_chan3[22:0] - chan_en[3]*readout_size_chan3[22:0];
      stored_bursts_chan4[22:0] <= stored_bursts_chan4[22:0] + chan_en[4]*acq_size_chan4[22:0] - chan_en[4]*readout_size_chan4[22:0];
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
          // the empty flags as they will be in STORE_TRIG_INFO (next_*): a trigger downgraded on
          // the way out of SEND_TRIGGER sets its flag in the same clock (6.8.0)
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
  assign error_trig_rate = (state[ERROR] == 1'b1) | rate_error_seen;   // ERROR is unreachable since 6.8.0

endmodule
