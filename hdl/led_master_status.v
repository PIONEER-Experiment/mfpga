// Module to control front panel LED
// for the Master FPGA status

module led_master_status (
  input  wire clk,
  output wire red_led,
  output wire green_led,
  // status input signals
  input  wire [3:0] tts_state
);

// the LEDs are active low:
//    0 = LED on
//    1 = LED off

// Assignments right now:
//    green LED is on when TTC/TTS is ready
//              e.g., green means "ready"
//    red LED is on otherwise
//              e.g., red means "not ready" or "error"

assign green_led = ~(tts_state[3:0] == 4'b1000);
assign red_led   = ~green_led;

endmodule
