`timescale 1ns / 1ps

module led_flasher(
  input clk,
  output led
);
  
// Make a counter to flash an LED
reg [23:0] led_cntr;
reg led_toggle;
always @ (posedge clk) begin
  led_cntr <= led_cntr + 1;
end

always @ (posedge clk) begin
  if (led_cntr == 24'b0) begin
    led_toggle <= ~led_toggle;
  end
end

assign led = led_toggle; 

endmodule