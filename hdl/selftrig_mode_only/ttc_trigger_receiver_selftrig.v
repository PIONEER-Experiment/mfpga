// Finite state machine to handle incoming TTC triggers
//st lkg --  we will need to add some logic somewhere so that the "acq_ready" means that
//st lkg     the previous readout command has completed
module ttc_trigger_receiver_selftrig (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  input wire ttc_trigger,                // TTC trigger signal
  input wire [ 4:0] trig_type,           // trigger type
  input wire [31:0] trig_settings,       // trigger settings
  input wire [ 4:0] chan_en,             // enabled channels

  // command manager interface
  input wire readout_done, // a readout has completed

  // channel acquisition controller interface
  input wire acq_ready,            // channels are ready to acquire data (or-reduce from 5 channels?)
  input wire acq_activated,        // channels are acquiring date (again, or-reduce)
  output reg acq_trigger,          // trigger signal to trigger the async readout
  output reg [ 4:0] acq_trig_type, // recognized trigger type (async readout)
  output reg [23:0] acq_trig_num,  // trigger number, starts at 1

  // interface to TTC Trigger FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [127:0] fifo_data,

  // status connections
  input wire selftriggers_seen,  // at least one channel has a trigger
  input wire [ 3:0] xadc_alarms,    // XADC alarm signals
(* mark_debug = "true" *) output reg [ 3:0] state,          // state of finite state machine
  output reg [23:0] trig_num,       // global trigger number
  output reg [43:0] trig_timestamp, // global trigger timestamp

  // error connections
  output wire error_trig_rate            // trigger received while acquiring data
);

  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter SEND_TRIGGER    = 1;
  parameter STORE_TRIG_INFO = 2;
//  parameter TRIG_HI         = 3;
  parameter ERROR           = 3;


  reg        empty_event;        // flag for an empty event response
  reg        empty_payload;      // flag for an async readout with no processed triggers
  reg [43:0] trig_timestamp_cnt; // clock cycle count
  reg [23:0] acq_event_cnt;      // # of triggers passed to channel, starts at 1
  reg [ 3:0] acq_xadc_alarms;    // XADC alarm signals

  reg [ 3:0] nextstate;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg        next_empty_event;
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
          // only respond to "async" readout requests in this mode
          if ((trig_type[4:0] != 5'b00100) | ~acq_activated) begin
             next_empty_event = 1'b1; // indicate to send an empty event
           end
           else if (~selftriggers_seen) begin
             next_empty_payload = 1'b1; // indicate to skip channel payloads
          end

          nextstate[SEND_TRIGGER] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // pass trigger et al. to channel acquisition controller, if the trigger type is enabled
      state[SEND_TRIGGER] : begin
        // channels are not ready for data collection
        if (~acq_ready) begin
          //st lkg -- THis can probably be changed to disable self-triggering until acq_ready is asserted
          //st lkg    In that case, we would just wait here to send the trigger (maybe with a timeout)
          nextstate[ERROR] = 1'b1; // throw error
        end
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
      empty_payload             <=  1'b0;
      acq_trig_type      [ 4:0] <=  5'd0;
      acq_xadc_alarms    [ 3:0] <=  4'd0;
//st      ddr3_overflow_count[31:0] <= 32'd0;
    end
    else begin
      state <= nextstate;

      empty_event               <= next_empty_event;
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
          fifo_data[127:0] <= {25'd0, empty_payload, acq_xadc_alarms[3:0], empty_event, acq_trig_type[4:0], acq_event_cnt[23:0], acq_trig_num[23:0], trig_timestamp[43:0]};
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

endmodule
