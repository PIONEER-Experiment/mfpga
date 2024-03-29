// This module provides a 32-bit register with 2 clock enables.

module reg32_ce2 (in, reset, def_value, clk_en1, clk_en2, out, clk);
    input  [31:0] in;
    input  reset;
    input  [31:0] def_value;
    output [31:0] out;
    input  clk;
    input  clk_en1, clk_en2;

    reg [31:0] out;
 
    always @ (posedge clk or posedge reset) begin
        if (reset)
            out <= def_value;
        else if (clk_en1 & clk_en2)
            out <= in;
    end

endmodule
