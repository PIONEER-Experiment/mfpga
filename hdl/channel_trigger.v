
module channel_triggers(
	input wire trigger_in,
	output wire[4:0] chan_trigger_out
	);

assign chan_trigger_out[0] = trigger_in;
assign chan_trigger_out[1] = trigger_in;
assign chan_trigger_out[2] = trigger_in;
assign chan_trigger_out[3] = trigger_in;
assign chan_trigger_out[4] = trigger_in;

endmodule