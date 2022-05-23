// simple counting module to count input front panel triggers, as opposed to processed front panel triggers

module ext_trigger_counter (
    // clocks
    input wire ttc_clk, //  40 MHz

    // resets
    input wire reset40,      // in  40 MHz clock domain
    input wire rst_trigger_timestamp, // from TTC Channel B

    // trigger interface
    input wire ext_trigger,                        // front panel trigger signal
    output reg [31:0] raw_ext_trigger_count       // simple trigger counter
    //output reg [31:0] ext_trig_delta_t             // time between external triggers (25 ns ticks)
);

  // state bits
  reg [1:0] state;
  parameter IDLE             = 0;
  parameter REARM            = 1;

  // timing counter
  //reg [31:0] time_counter;
  
  // 'next' signals
  reg [ 1:0] nextstate;
  reg [31:0] next_raw_ext_trigger_count;
  //reg [31:0] next_time_counter;
  //reg [31:0] next_ext_trig_delta_t;
  
  // combinational always block
  always @* begin
    nextstate = 2'd0;
    //next_ext_trig_delta_t[31:0] = ext_trig_delta_t[31:0];
    //next_time_counter[31:0]     = time_counter[31:0] + 1;

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (ext_trigger) begin
          next_raw_ext_trigger_count[31:0] = raw_ext_trigger_count[31:0] + 1;
          //next_ext_trig_delta_t[31:0] = time_counter[31:0];
          //next_time_counter[31:0] = 32'd0;
          
          nextstate[REARM] = 1'b1;
        end
        else begin
          next_raw_ext_trigger_count[31:0] = raw_ext_trigger_count[31:0];
          
          nextstate[IDLE] = 1'b1;
        end
      end
     
     // wait here for input trigger to go low before rearming
     state[REARM] : begin
       
       next_raw_ext_trigger_count[31:0] = raw_ext_trigger_count[31:0];
       
       if (~ext_trigger)
         nextstate[IDLE] = 1'b1;
       else // continue waiting
         nextstate[REARM] = 1'b1;
       end
    endcase
  end

  // sequential always block
  always @(posedge ttc_clk) begin
    // reset state machine and time counters
    if (reset40) begin
      state[1:0] <= 2'd1 << IDLE;
    end
    else begin
      state[1:0] <= nextstate[1:0];
    end
    
    if ( reset40 | rst_trigger_timestamp ) begin
      raw_ext_trigger_count[31:0] <= 32'd0;
      //time_counter[31:0] <= 32'd0;
      //ext_trig_delta_t[31:0] <= 32'd0;
    end
    else begin
      //time_counter[31:0] <= next_time_counter[31:0];
      //ext_trig_delta_t[31:0] <= next_ext_trig_delta_t[31:0];
      raw_ext_trigger_count[31:0] <= next_raw_ext_trigger_count[31:0];
    end
  end

endmodule
