`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// connect a counter that will keep track of the # of self-triggers in the memory buffer of one channel
// It will be initialized when one switches to the memory buffer that this counter tracks
// It will increment each time the associated channel detects a self trigger

module trigger_counter (
    // inputs
    input clk,
    input init,                   // initialize to zero when one switches to the new memory buffer
    input enable,                 // enable for each trigger to increment
    // outputs
    output reg [19:0] trigger_cnt   // current DDR3 burst memory location for this fill
);

always @(posedge clk) begin
    if (init) begin
        // set to 0 when initialized
        trigger_cnt[19:0] <= #1 20'h00000;
    end
    else if (enable) begin
        // increment
        trigger_cnt[19:0] <= #1 trigger_cnt[19:0] + 1;
    end
end
endmodule

