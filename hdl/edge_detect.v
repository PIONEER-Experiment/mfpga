// Simple direct detection of rising and falling edges
// for a 1-bit signal

module edge_detect (
    input wire clk,      // clock
    input wire in,       // input signal
    output wire rising,  // rising edge detect
    output wire falling  // falling edge detect
);
    
    reg level1, level2;

    always @ (posedge clk) begin
        level1 <= in;
        level2 <= level1;
    end

    assign rising  = (~level1 &  level2) ? 1'b1 : 1'b0;
    assign falling = ( level1 & ~level2) ? 1'b1 : 1'b0;

endmodule
