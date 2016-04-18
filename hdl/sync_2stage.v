// Classic 2-stage synchronizer to bring asynchronous signals into a clock domain
// for a signal of width 'WIDTH' which defaults to 1

module sync_2stage #(
  parameter WIDTH = 1
) (
    input  wire clk,
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    
    reg [WIDTH-1:0] sync1, sync2;
    
    always @ (posedge clk) begin
        sync1 <= in;
        sync2 <= sync1;
    end
    assign out = sync2;

endmodule
