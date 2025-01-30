`timescale 1ns / 10ps

module delay_signal (
    // inputs
  input clk,
  input enable,               // generate a delayed pulse when enabled
  input [21:0] delay,         // # of clock cycles of delay
  input trig_pulse,           // initial trigger
  // outputs
  output reg delayed_pulse    // the delayed pulse
);


// Leave the comments containing "synopsys" in your HDL code.

// count down to zero
reg [22:0] counter;
wire cntr_neg;
assign cntr_neg = (counter[22] == 1'b1) ? 1'b1 : 1'b0;
always @ (posedge clk) begin
  if ( trig_pulse ) begin
    counter[22:0] <= {1'b0, delay[21:0]};
  end
  else if ( cntr_neg) begin
    counter[22:0] <= {1'b1,22'b1};
  end
  else begin
    counter[22:0] <= counter[22:0] - 1;
  end
end

// create a flag to indicate whether or not a trigger was seen
reg got_trig;

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [1:0]
    IDLE            = 2'd0,   // 1
    TRIG_WAIT       = 2'd1,   // 2
    GEN_PULSE       = 2'd2;   // 4
    
// Declare current state and next state variables
reg [2:0] /* synopsys enum STATE_TYPE */ CS;
reg [2:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (!enable) begin
        CS <= #1 {3{1'b0}}; // set all state bits to 0
        CS[IDLE] <= #1 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= #1 NS;         // set state bits to next state
end

// combinational always block to determine next state (use blocking [=] assignments)
always @ (CS or cntr_neg or trig_pulse ) begin
    NS = {3{1'b0}}; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Stay in the IDLE state whenever we are not enabled.
        CS[IDLE]: begin
          if (trig_pulse)
            // we have a pulse, wait until we count down to send another pulse
            NS[TRIG_WAIT] = 1'b1;
          else
            NS[IDLE] = 1'b1;
       end

       // Stay in TRIG_WAIT until the delay count has completed
        CS[TRIG_WAIT]: begin
          if (cntr_neg)
            // Go generate the trigger pulse
            NS[GEN_PULSE] = 1'b1;
          else
            // wait here
            NS[TRIG_WAIT] = 1'b1;
        end

        // Generate a 1 clock cycle pulse
        CS[GEN_PULSE]: begin
                NS[IDLE] = 1'b1;
        end

    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
    delayed_pulse    <= #1 1'b0;  // waiting for another trigger + delay

    // next states
    if (NS[IDLE]) begin
    end
    
    if (NS[TRIG_WAIT]) begin
    end

    if (NS[GEN_PULSE]) begin
      delayed_pulse    <= #1 1'b1;  // generate pulse
    end

end

endmodule

