// This module stretches the input signal so that it can later be synchronized into a slower clock domain.
// When the input signal is asserted, it will be kept high for n additional clock cycles.

module signal_stretch (
    input signal_in,
    input clk,
    input [7:0] n_extra_cycles,
    output reg signal_out
);

reg [7:0] counter = 8'h00;

always @(posedge clk)
begin
    if (signal_in) begin
        counter    <= n_extra_cycles;
        signal_out <= 1'b1;
    end 
    else if (counter > 8'h00) begin
        counter    <= counter - 1;
        signal_out <= 1'b1;
    end
    else begin
        counter    <= 8'h00;
        signal_out <= 1'b0;
    end
end

endmodule
