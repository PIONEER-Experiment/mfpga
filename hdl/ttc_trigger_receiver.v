// Finite state machine to handle incoming TTC triggers

module ttc_trigger_receiver(
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  (* mark_debug = "true" *) input wire trigger,             // trigger signal
  (* mark_debug = "true" *) input wire [1:0] trig_type,     // trigger type (muon fill, laser, pedestal)
  (* mark_debug = "true" *) input wire [7:0] trig_settings, // trigger settings

  // channel acquisition controller interface
  (* mark_debug = "true" *) output reg acq_trigger,          // trigger signal
  (* mark_debug = "true" *) output reg [ 1:0] acq_trig_type, // trigger type (muon fill, laser, pedestal)
  (* mark_debug = "true" *) output reg [23:0] acq_trig_num,  // trigger number, starts at 1

  // interface to TTC Trigger FIFO
  (* mark_debug = "true" *) input wire fifo_ready,
  (* mark_debug = "true" *) output reg fifo_valid,
  (* mark_debug = "true" *) output reg [127:0] fifo_data,

  // status connections
  (* mark_debug = "true" *) output reg [ 2:0] state,         // state of finite state machine
  output reg [23:0] trig_num,      // global trigger number
  output reg [43:0] trig_timestamp // global trigger timestamp
);

  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter SEND_TRIGGER    = 1;
  parameter STORE_TRIG_INFO = 2;


  (* mark_debug = "true" *) reg        empty_event;        // flag for an empty event response
  (* mark_debug = "true" *) reg [43:0] trig_timestamp_cnt; // clock cycle count
  (* mark_debug = "true" *) reg [23:0] acq_event_cnt;      // channel's trigger number, starts at 1

  (* mark_debug = "true" *) reg [ 2:0] nextstate;
  reg [ 1:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;
  reg        next_empty_event;
  reg [23:0] next_trig_num;
  reg [43:0] next_trig_timestamp;
  reg [23:0] next_acq_event_cnt;


  // combinational always block
  always @* begin
    nextstate = 3'd0;

    next_acq_trig_type[ 1:0] = acq_trig_type[ 1:0];
    next_acq_trig_num [23:0] = acq_trig_num [23:0];

    next_empty_event          = empty_event;
    next_trig_num      [23:0] = trig_num      [23:0];
    next_trig_timestamp[43:0] = trig_timestamp[43:0];
    next_acq_event_cnt [23:0] = acq_event_cnt [23:0];

    acq_trigger = 1'b0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          next_acq_trig_num  [23:0] = trig_num[23:0];           // latch trigger number
          next_trig_num      [23:0] = trig_num[23:0] + 1;       // increment trigger counter
          next_acq_trig_type [ 1:0] = trig_type[1:0];           // latch trigger type
          next_trig_timestamp[43:0] = trig_timestamp_cnt[43:0]; // latch trigger timestamp counter

          nextstate[SEND_TRIGGER] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // pass trigger et al. to channel acquisition controller, if the trigger type is enabled
      state[SEND_TRIGGER] : begin
        // 0 = pass trigger, 1 = block trigger
        if (trig_settings[acq_trig_type] == 1'b0) begin
          acq_trigger              = 1'b1;                    // pass on the trigger
          next_acq_event_cnt[23:0] = acq_event_cnt[23:0] + 1; // increment accepted event counter
        end
        else begin
          next_empty_event = 1'b1; // indicate to send an empty event
        end
        nextstate[STORE_TRIG_INFO] = 1'b1;
      end
      // store the trigger information in the FIFO, for the trigger processor
      state[STORE_TRIG_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          next_empty_event = 1'b0; // clear the empty event flag
          nextstate[IDLE] = 1'b1;
        end
        // FIFO is not ready for data word
        else begin
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
      end
    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 3'd1 << IDLE;

      empty_event        <= 1'b0;
      acq_trig_type[1:0] <= 2'd0;
    end
    else begin
      state <= nextstate;

      empty_event        <= next_empty_event;
      acq_trig_type[1:0] <= next_acq_trig_type[1:0];
    end

    // reset trigger number
    if (reset | reset_trig_num) begin
      trig_num     [23:0] <= 24'd0;
      acq_trig_num [23:0] <= 24'd0;
      acq_event_cnt[23:0] <= 24'd0;
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
      fifo_valid <= 1'b0;
      fifo_data <= 128'd0;
    end
    else begin
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]: begin
          fifo_valid <= 1'b0;
          fifo_data[127:0] <= 128'd0;
        end
        nextstate[SEND_TRIGGER]: begin
          fifo_valid <= 1'b0;
          fifo_data[127:0] <= 128'd0;
        end
        nextstate[STORE_TRIG_INFO]: begin
          fifo_valid <= 1'b1;
          fifo_data[127:0] <= {33'd0, empty_event, acq_trig_type[1:0], acq_event_cnt[23:0], acq_trig_num[23:0], trig_timestamp[43:0]};
        end
      endcase
    end
  end

endmodule
