// Toggle 2-stage synchronizer to bring asynchronous pulses into a clock domain
// for a 1-bit pulse

module toggle_sync_2stage (
    input  wire clk_in,  // source clock
    input  wire clk_out, // destination clock
    input  wire in,      // input pulse
    output wire out      // output pulse
);
    
    reg toggle1 = 1'b0;
    reg sync1, sync2, sync3, sync4, sync5;
    
    always @ (posedge clk_in) begin
        if (in) begin
	        toggle1 <= ~toggle1;
	    end
	    else begin
	        toggle1 <= toggle1;
	    end
    end

    always @ (posedge clk_out) begin
        sync1 <= toggle1;
        sync2 <= sync1;
        sync3 <= sync2;
        sync4 <= sync3;
        sync5 <= sync4;
    end

    assign out = sync4^sync5;

endmodule
