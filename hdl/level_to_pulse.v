// module to convert an incoming signal to a pulse

module level_to_pulse (
  // clock
  input wire clk,

  input  signal_in,  // multi-clock signal
  output signal_out  // single-clock  signal
);

reg sync1, sync2, sync3;
always @(posedge clk) begin

  sync1 <= signal_in;
  sync2 <= sync1;
  sync3 <= sync2;
end

assign signal_out = sync2 & !sync3;

endmodule
