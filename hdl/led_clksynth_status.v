`timescale 1ns / 1ps

// Module to control front panel LED
// for the clock synthesizer status

module led_clksynth_status(
  input clk,
  output red_led,
  output green_led,
  // status input signals
  input adcclk_ld
);

// the LEDs are active low:
//    0 = LED on
//    1 = LED off

// Assignments right now:
//    green LED is on when clock synthesizer PLLs are locked
//    red LED is on otherwise

assign green_led = ~adcclk_ld;
assign red_led = ~green_led;


endmodule
