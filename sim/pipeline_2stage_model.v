module pipeline_2stage #(parameter WIDTH=1) (input clk, input [WIDTH-1:0] in, output reg [WIDTH-1:0] out); reg [WIDTH-1:0] s; always @(posedge clk) begin s<=in; out<=s; end endmodule
