// Finite state machine to handle incoming front panel triggers

// Asynchronous mode

module pulse_trigger_receiver (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,
  input wire reset_trig_timestamp,

  // trigger interface
  input wire trigger,                    // front panel trigger signal
  input wire [22:0] thres_ddr3_overflow, // DDR3 overflow threshold
  input wire [ 4:0] chan_en,             // enabled channels
  output reg pulse_trigger,              // channel trigger signal
  output reg [23:0] trig_num,            // global trigger number

  // interface to Pulse Trigger FIFO
  input wire fifo_ready,
  output reg fifo_valid,
  output reg [127:0] fifo_data,

  // command manager interface
  input wire readout_done, // a readout has completed

  // set burst count for each channel
  input wire [22:0] burst_count_chan0,
  input wire [22:0] burst_count_chan1,
  input wire [22:0] burst_count_chan2,
  input wire [22:0] burst_count_chan3,
  input wire [22:0] burst_count_chan4,

  // status connections
  output reg [3:0] state, // state of finite state machine

  // error connections
  output reg [31:0] ddr3_overflow_count, // number of triggers received that would overflow DDR3
  output wire ddr3_almost_full           // DDR3 overflow warning, combined for all channels
);

  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter SEND_TRIGGER    = 1;
  parameter WAIT            = 2;
  parameter STORE_TRIG_INFO = 3;


  reg [43:0] trig_timestamp;     // global trigger timestamp
  reg [ 3:0] trig_history;       // record of past trigger levels
  reg [ 3:0] wait_cnt;           // wait state count
  reg [ 1:0] trig_length;        // short or long trigger type
  reg [43:0] trig_timestamp_cnt; // clock cycle count

  // number of bursts yet to be read out of DDR3
  reg [22:0] stored_bursts_chan0;
  reg [22:0] stored_bursts_chan1;
  reg [22:0] stored_bursts_chan2;
  reg [22:0] stored_bursts_chan3;
  reg [22:0] stored_bursts_chan4;

  // mux overflow warnings for all channels
  assign ddr3_almost_full = (stored_bursts_chan0[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan1[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan2[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan3[22:0] > thres_ddr3_overflow[22:0]) |
                            (stored_bursts_chan4[22:0] > thres_ddr3_overflow[22:0]);

  // DDR3 is full in a channel
  // "full" in asynchronous mode is limited by the AMC13 event size of 2^20 64-bit words
  wire ddr3_full;
  assign ddr3_full = ((524288 - stored_bursts_chan0[22:0]) < chan_en[0]*(burst_count_chan0[22:0] + 1)) |
                     ((524288 - stored_bursts_chan1[22:0]) < chan_en[1]*(burst_count_chan1[22:0] + 1)) |
                     ((524288 - stored_bursts_chan2[22:0]) < chan_en[2]*(burst_count_chan2[22:0] + 1)) |
                     ((524288 - stored_bursts_chan3[22:0]) < chan_en[3]*(burst_count_chan3[22:0] + 1)) |
                     ((524288 - stored_bursts_chan4[22:0]) < chan_en[4]*(burst_count_chan4[22:0] + 1));

  reg next_pulse_trigger;
  reg [ 3:0] nextstate;
  reg [ 3:0] next_trig_history;
  reg [ 3:0] next_wait_cnt;
  reg [ 1:0] next_trig_length;
  reg [23:0] next_trig_num;
  reg [43:0] next_trig_timestamp;
  reg [31:0] next_ddr3_overflow_count;


  // combinational always block
  always @* begin
    nextstate = 4'd0;

    next_trig_history       [ 3:0] = trig_history       [ 3:0];
    next_wait_cnt           [ 3:0] = wait_cnt           [ 3:0];
    next_trig_length        [ 1:0] = trig_length        [ 1:0];
    next_trig_num           [23:0] = trig_num           [23:0];
    next_trig_timestamp     [43:0] = trig_timestamp     [43:0];
    next_ddr3_overflow_count[31:0] = ddr3_overflow_count[31:0];

    next_pulse_trigger = 1'b0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (trigger) begin
          // this trigger would overwrite valid data in DDR3, ignore this trigger
          if (ddr3_full) begin
            next_ddr3_overflow_count[31:0] = ddr3_overflow_count[31:0] + 1; // increment overflow error counter

            nextstate[IDLE] = 1'b1;
          end
          // pass along the trigger to channels
          else begin
            next_trig_num      [23:0] = trig_num[23:0] + 1;       // increment trigger counter, starts at zero
            next_trig_timestamp[43:0] = trig_timestamp_cnt[43:0]; // latch trigger timestamp counter
            next_trig_history  [   0] = trigger;                  // start recording trigger level history
            next_wait_cnt      [ 3:0] = wait_cnt[3:0] + 1;

            nextstate[SEND_TRIGGER] = 1'b1;
          end
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // pass trigger et al. to channel acquisition controller (asynchronous)
      state[SEND_TRIGGER] : begin
        next_pulse_trigger     = 1'b1;    // pass on the trigger
        next_trig_history[  1] = trigger; // store trigger level
        next_wait_cnt    [3:0] = wait_cnt[3:0] + 1;

        nextstate[WAIT] = 1'b1;
      end
      // finish monitoring the trigger level to determine if it's short or long
      state[WAIT] : begin
        // wait period is over
        if (wait_cnt[3:0] == 4'd3) begin
          next_wait_cnt[3:0] = wait_cnt[3:0] + 1;
          
          // determine trigger length
          if (~trigger) begin
            next_trig_length[1:0] = 2'b10; // laser only
          end
          else if (trig_history[2:0] == 3'b111) begin
            next_trig_length[1:0] = 2'b01; // Am only
          end
          else begin
            next_trig_length[1:0] = 2'b11; // laser + Am
          end

          // wait one more cycle to ready trigger information
          nextstate[WAIT] = 1'b1;
        end
        else if (wait_cnt[3:0] == 4'd4) begin
          // trigger information is ready for storage
          nextstate[STORE_TRIG_INFO] = 1'b1;
        end
        // keep waiting
        else begin
          next_wait_cnt[3:0] = wait_cnt[3:0] + 1;
          next_trig_history[wait_cnt] = trigger; // store trigger level

          nextstate[WAIT] = 1'b1;
        end
      end
      // store the trigger information in the FIFO, for the trigger processor
      state[STORE_TRIG_INFO] : begin
        // FIFO accepted the data word
        if (fifo_ready) begin
          next_trig_history[3:0] = 4'h0; // reset history
          next_wait_cnt    [3:0] = 4'h0; // reset wait count

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
      state <= 4'd1 << IDLE;

      trig_history       [ 3:0] <=  3'd0;
      wait_cnt           [ 3:0] <=  3'd0;
      trig_length        [ 1:0] <=  2'd0;
      ddr3_overflow_count[31:0] <= 32'd0;

      pulse_trigger <= 1'b0;
    end
    else begin
      state <= nextstate;

      trig_history       [ 3:0] <= next_trig_history       [ 3:0];
      wait_cnt           [ 3:0] <= next_wait_cnt           [ 3:0];
      trig_length        [ 1:0] <= next_trig_length        [ 1:0];
      ddr3_overflow_count[31:0] <= next_ddr3_overflow_count[31:0];

      pulse_trigger <= next_pulse_trigger;
    end

    // reset trigger number
    if (reset | reset_trig_num | readout_done) begin
      trig_num[23:0] <= 24'd0;
    end
    else begin
      trig_num[23:0] <= next_trig_num[23:0];
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
    if (reset | readout_done) begin
      stored_bursts_chan0[22:0] <= 23'd0;
      stored_bursts_chan1[22:0] <= 23'd0;
      stored_bursts_chan2[22:0] <= 23'd0;
      stored_bursts_chan3[22:0] <= 23'd0;
      stored_bursts_chan4[22:0] <= 23'd0;
    end
    else if (pulse_trigger) begin
      stored_bursts_chan0[22:0] <= stored_bursts_chan0[22:0] + chan_en[0]*(burst_count_chan0[22:0] + 1);
      stored_bursts_chan1[22:0] <= stored_bursts_chan1[22:0] + chan_en[1]*(burst_count_chan1[22:0] + 1);
      stored_bursts_chan2[22:0] <= stored_bursts_chan2[22:0] + chan_en[2]*(burst_count_chan2[22:0] + 1);
      stored_bursts_chan3[22:0] <= stored_bursts_chan3[22:0] + chan_en[3]*(burst_count_chan3[22:0] + 1);
      stored_bursts_chan4[22:0] <= stored_bursts_chan4[22:0] + chan_en[4]*(burst_count_chan4[22:0] + 1);
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
        nextstate[WAIT] : begin
          fifo_valid       <=   1'b0;
          fifo_data[127:0] <= 128'd0;
        end
        nextstate[STORE_TRIG_INFO] : begin
          fifo_valid       <= 1'b1;
          fifo_data[127:0] <= {58'd0, trig_length[1:0], trig_num[23:0], trig_timestamp[43:0]};
        end
      endcase
    end
  end

endmodule
