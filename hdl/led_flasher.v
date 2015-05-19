`timescale 1ns / 1ps

module led_flasher(
  input clk,
  output led,
  input in
);

// Make a counter to flash an LED
reg [23:0] led_cntr;
reg led_toggle;
always @ (posedge clk) begin
  led_cntr <= led_cntr + 1;
end

always @ (posedge clk) begin
  if (led_cntr == 24'b0)
    led_toggle <= ~led_toggle;
end

// 'led' is OFF if 'in' is HIGH
// otherwise, 'led' flashes
reg led_out;
always @ (posedge clk) begin
  if (in)
    led_out <= in;
  else
    led_out <= led_toggle;
end

assign led = led_out; 

endmodule
