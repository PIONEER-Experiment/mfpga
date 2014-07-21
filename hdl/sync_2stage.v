`timescale 1ns / 1ps
// Classic 2-stage synchronizer to bring asynchronous signals
// into a clock domain

module sync_2stage(
    input clk,
    input in,
    output out
    );
    
    reg sync1, sync2;
    
    always @ (posedge clk) begin
        sync1 <= in;
        sync2 <= sync1;
    end
    assign out = sync2;

endmodule
