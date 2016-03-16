`timescale 1ns / 1ps

// Module to control front panel LED
// for the Master FPGA status

module led_master_status(
  input wire clk,
  output wire red_led,
  output wire green_led,
  // status input signals
  input wire ttc_ready,
  input wire [4:0] chan_error_rc,
  input wire [4:0] trig_num_error
);

// the LEDs are active low:
//    0 = LED on
//    1 = LED off

// Assignments right now:
//    green LED is on when TTC signal is ready                 AND
//                         channel readout has been successful AND
//                         trigger numbers are synchronized
//              e.g., green means "ready"
//    red LED is on otherwise
//              e.g., red means "not ready" or "error"

assign green_led = ~(ttc_ready & (chan_error_rc[4:0] == 5'd0) & (trig_num_error[4:0] == 5'd0));
assign red_led = ~green_led;


// ===== old flasher code =====

// // Make a counter to flash an LED
// reg [23:0] led_cntr;
// reg led_toggle;
// always @ (posedge clk) begin
//   led_cntr <= led_cntr + 1;
// end
// 
// always @ (posedge clk) begin
//   if (led_cntr == 24'b0)
//     led_toggle <= ~led_toggle;
// end
// 
// // 'led' is OFF if 'in' is HIGH
// // otherwise, 'led' flashes
// reg led_out;
// always @ (posedge clk) begin
//   if (in)
//     led_out <= in;
//   else
//     led_out <= led_toggle;
// end
// 
// assign led = led_out; 

endmodule
