`timescale 1ns / 1ps

// Classic 2-stage synchronizer to bring asynchronous signals into a clock domain
// for a 1-bit signal

module sync_2stage(
    input wire clk,
    input wire in,
    output wire out
);
    
    reg sync1, sync2;
    
    always @ (posedge clk) begin
        sync1 <= in;
        sync2 <= sync1;
    end
    assign out = sync2;

endmodule
