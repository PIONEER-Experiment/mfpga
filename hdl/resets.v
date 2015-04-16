module resets(
	input wire ipb_rst_in,
	input wire ipb_clk,
	input wire clk50,
	output reg rst_clk50
);

reg[1:0] rst_clk50_sync;
reg[7:0] ipb_rst_stretch;

// stretch the 125MHz reset so that the slower clocks don't miss it
always @(posedge ipb_clk) begin
    if (ipb_rst_in) begin
        ipb_rst_stretch <= 8'hFF;
    end else if (ipb_rst_stretch > 8'h00) begin
        ipb_rst_stretch <= ipb_rst_stretch - 1;
    end
end

always @(posedge clk50) begin
    if (ipb_rst_stretch > 8'h00)
        begin
            rst_clk50_sync[1] <= 1'b1;
        end 
    else 
        begin
            rst_clk50_sync[1] <= 1'b0;
        end

    rst_clk50_sync[0] <= rst_clk50_sync[1];
    rst_clk50 <= rst_clk50_sync[0];
end

endmodule