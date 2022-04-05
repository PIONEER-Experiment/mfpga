// simple counting module to count input front panel triggers, as opposed to processed front panel triggers

module ext_trigger_counter (
    // clocks
    input wire ttc_clk, //  40 MHz

    // resets
    input wire reset40,      // in  40 MHz clock domain
    input wire rst_trigger_num,       // from TTC Channel B

    // trigger interface
    input wire ext_trigger,                        // front panel trigger signal
    output reg [31:0] raw_ext_trigger_count        // simple trigger counter
);

  // state bits
  reg [1:0] state;
  parameter IDLE             = 0;
  parameter REARM            = 1;

  // 'next' signals
  reg [ 1:0] nextstate;
  reg [31:0] next_raw_ext_trigger_count;
  
  // combinational always block
  always @* begin
    nextstate = 5'd0;
    next_raw_ext_trigger_count[31:0] = raw_ext_trigger_count[31:0];
    
    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        if (ext_trigger) begin
          next_raw_ext_trigger_count[31:0] = raw_ext_trigger_count[31:0] + 1;
         
          nextstate[REARM] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
     
     // wait here for input trigger to go low before rearming
     state[REARM] : begin
       if (~ext_trigger)
         nextstate[IDLE] = 1'b1;
       else // continue waiting
         nextstate[REARM] = 1'b1;
       end
    endcase
  end

  // sequential always block
  always @(posedge ttc_clk) begin
    // reset state machine
    if (reset40) begin
      state <= 2'd1 << IDLE;
    end
    else begin
      state <= nextstate;
    end

    // reset trigger number
    if (reset40 | rst_trigger_num ) begin
      raw_ext_trigger_count[31:0] <= 32'd0;
    end
    else begin
      raw_ext_trigger_count[31:0] <= next_raw_ext_trigger_count[31:0];
    end
  end

endmodule
