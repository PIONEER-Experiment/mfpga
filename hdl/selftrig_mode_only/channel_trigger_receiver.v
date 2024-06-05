// Finite state machine to handle self triggers from a given channel

// The 5 channels operate asynchronously with respect to each other and the TTC commands

module channel_trigger_receiver (
  // clock and reset
  input wire clk,   // 40 MHz TTC clock
  input wire reset,

  // TTC Channel B resets
  input wire reset_trig_num,

  // trigger interface
  input wire trigger,                    // self trigger signal from channel in 40 MHz domain
  input wire [22:0] thres_ddr3_overflow, // DDR3 overflow threshold
  input wire chan_en,                    // is this channel enabled
  input wire ttc_trigger,                // backplane trigger signal
  input wire ttc_acq_ready,              // channels are ready to acquire/readout data
  output reg [23:0] trig_num,            // global trigger number for this channel
  output reg [19:0] selftriggers_lo,     // number of triggers currently in the lo 1/2 of DDR3 buffer
  output reg [19:0] selftriggers_hi,     // number of triggers currently in the hi 1/2 of DDR3 buffer
  input wire ddr3_buffer,                // the current buffer for collecting triggers in the channels

  // command manager interface
  input wire readout_buffer_changed,

  // set burst count for each channel
  input wire [22:0] burst_count_selftrig,

  // number of bursts stored in the DDR3
  output reg [22:0] stored_bursts_lo,
  output reg [22:0] stored_bursts_hi,

  // status connections
  output reg [1:0] state,               // state of finite state machine

  // error connections
  output wire ddr3_almost_full          // DDR3 overflow warning, combined for all channels
);

  // use array for keeping track of
  // state bits, with one-hot encoding
  parameter IDLE            = 0;
  parameter TRIG_HI         = 1;

  // mux overflow warnings for all channels
  wire [22:0] stored_bursts;
  assign stored_bursts[22:0] = ddr3_buffer ? stored_bursts_hi[22:0] : stored_bursts_lo[22:0];
  assign ddr3_almost_full    = chan_en     ? (stored_bursts[22:0] > thres_ddr3_overflow[22:0]) : 1'b0;

//st -- lkg: this computation should get moved to selftrigger_top, and should disable triggering
//st -- lkg: I believe the reasoning below neglected to consider that there are in principle 12
//st -- lkg: WFD5's that the AMC13 is contending with
  // "full" in asynchronous mode is limited by the AMC13 event size of 2^20 64-bit words
  // for now, assume all channels read with identical parameters and with every trigger.
  // then the total allowed 64 bit word size of 1048576 must be reduced by 5 (# channels) and further
  // reduced by 2 to account for 2 64 words in each burst of 8 adc words -- so 104857 bursts
  // This can be compared to one channel's storage
//st  wire amc13_payload_full;
//st  assign amc13_payload_full = ((104857 - stored_bursts_chan0[22:0]) < chan_en*(burst_count_chan0[22:0] + 1));
  

  reg [ 1:0] nextstate;
  reg [23:0] next_trig_num;
  reg [19:0] next_selftriggers_lo;
  reg [19:0] next_selftriggers_hi;

  // combinational always block
  always @* begin
    nextstate = 2'd0;

//st2 -- don't need with pulse fifo gone    next_queued_triggers[ 3:0] = queued_triggers[ 3:0];
    next_trig_num[23:0]  = trig_num[23:0];
    next_selftriggers_lo = selftriggers_lo;
    next_selftriggers_hi = selftriggers_hi;
//st2 -- don't need with pulse fifo gone    next_queued_trigger  [3:0] = queued_trigger [ 3:0];

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      //st lkg -- will need to determine if I need the ttc_acq_ready
      state[IDLE] : begin
        if (trigger & chan_en) begin
          next_trig_num[23:0] = trig_num[23:0] + 1;       // increment trigger counter, starts at zero
          if ( ddr3_buffer ) begin
             next_selftriggers_hi = selftriggers_hi + 1;
          end
          else begin
             next_selftriggers_lo = selftriggers_lo + 1;
          end
          nextstate[TRIG_HI] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end

      // remain here until the trigger goes low
      state[TRIG_HI] : begin
        // trigger information is now ready for storage
        if (trigger) begin
              nextstate[TRIG_HI] = 1'b1;
        end
        else begin
           nextstate[IDLE] = 1'b1;
        end
      end

    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 5'd1 << IDLE;
    end
    else begin
      state <= nextstate;
    end

    // reset trigger number
    if (reset | reset_trig_num ) begin
      trig_num[23:0] <= 24'd0;
    end
    else begin
      trig_num[23:0] <= next_trig_num[23:0];
    end
    
    // reset the current write buffer count
    if ( reset ) begin
       selftriggers_lo = 20'd0;
       selftriggers_hi = 20'd0;
    end
    else if ( readout_buffer_changed ) begin
       if ( ddr3_buffer ) begin
          selftriggers_hi = 20'd0;
          selftriggers_lo = next_selftriggers_lo;
       end
       else begin
          selftriggers_lo = 20'd0;
          selftriggers_hi = next_selftriggers_hi;
       end
    end

    // reset stored bursts
    if ( reset ) begin
      if ( ddr3_buffer) begin
        stored_bursts_hi[22:0] <= 23'd0;
      end
      else begin
        stored_bursts_lo[22:0] <= 23'd0;
      end
    end
    else if ( readout_buffer_changed ) begin
      stored_bursts_lo[22:0] <= 23'd0;
      stored_bursts_hi[22:0] <= 23'd0;
    end
    else if (trigger & chan_en) begin
      if ( ddr3_buffer) begin
        stored_bursts_hi[22:0] <= stored_bursts_hi[22:0] + (burst_count_selftrig[22:0] + 1);
      end
      else begin
        stored_bursts_hi[22:0] <= stored_bursts_hi[22:0] + (burst_count_selftrig[22:0] + 1);
      end
    end
  end
  
endmodule
