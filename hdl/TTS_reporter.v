// Reports the Rider status via TTS to DAQ link
// 
// Outputs the 'Ready' state unless an error has occured

module TTS_reporter (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // status registers
  input wire [31:0] status_reg0, // error

  // TTS state
  output wire [3:0] tts_state
);

  // always report a 'Ready' TTS state
  // unless an error has been detected
  assign tts_state = (status_reg0[31:0] != 32'd0) ? 4'b1100 : 4'b1000;

endmodule
