// This module stretches the input signal so that it can later be synchronized into a slower clock domain
//
// When the input signal is asserted, it will be kept high for n additional clock cycles
//
// maximum number of extra clock cycles = 16
// (for more, need to increase the number of bits in the counter register and in the n_extra_cycles input)
//
// Robin Bjorkquist, April 2015

module signal_stretch(
	input signal_in,
	input clk,
    input [3:0] n_extra_cycles,
	output reg signal_out
);

reg[3:0] counter = 0'h0;

always @(posedge clk)
begin
    if (signal_in)
        begin
            counter <= n_extra_cycles;
            signal_out <= 1'b1;
        end 
    else if (counter > 4'h0)
        begin
            counter <= counter - 1;
            signal_out <= 1'b1;
        end
    else
        begin
            counter <= 4'h0;
            signal_out <= 1'b0;
        end
end

endmodule