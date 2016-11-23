// Toggle 2-stage synchronizer to bring asynchronous pulses into a clock domain
// for a 1-bit pulse

module toggle_sync_2stage (
    input  clk_in,               // source clock
    input  clk_out,              // destination clock
    input  [7:0] n_extra_cycles, // cycles to stretch
    input  in,                   // input pulse
    output reg out               // output pulse
);

    wire in_stretch, out_stretch;
    reg sync1, sync2, sync3;

    // signal stretcher
    signal_stretch in_stretch_inst (
        .signal_in(in),
        .clk(clk_in),
        .n_extra_cycles(n_extra_cycles),
        .signal_out(in_stretch)
    );

    // two-stage synchronizer
    sync_2stage out_stretch_inst (
        .clk(clk_out),
        .in(in_stretch),
        .out(out_stretch)
    );

    // level-to-pulse converter
    always @(posedge clk_out) begin
        sync1 <= out_stretch;
        sync2 <= sync1;
        sync3 <= sync2;

        out <= sync2 & ~sync3;
    end

endmodule
