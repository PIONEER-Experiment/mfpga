`timescale 1ns / 1ps

// Classic 2-stage synchronizer to bring asynchronous signals into a clock domain
// for a 64-bit signal

module sync_2stage_64bit(
    input wire clk,
    input wire [63:0] in,
    output wire [63:0] out
);
    
    reg [63:0] sync1, sync2;
    
    always @ (posedge clk) begin
        sync1 <= in;
        sync2 <= sync1;
    end
    assign out = sync2;

endmodule
