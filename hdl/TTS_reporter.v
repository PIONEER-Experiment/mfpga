// Reports the Rider status via TTS to DAQ link
// 
// Outputs the 'Ready' state unless an error has occured

module tts_reporter (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // error status
  input wire error_ttc_ready,
  input wire error_data_corrupt,
  input wire error_pll_unlock,
  input wire error_trig_rate,
  input wire error_unknown_ttc,

  // sync lost status
  input wire error_trig_num_from_tt,
  input wire error_trig_num_from_cm,
  input wire error_trig_type_from_tt,
  input wire error_trig_type_from_cm,

  // overflow warning status
  input wire overflow_warning_ddr3,

  // TTS state
  output wire [3:0] tts_state
);

  // Available TTS status outputs, in order of priority level
  // --------------------------------------------------------
  // 0000, 1111 -- Disconnected
  // 1100       -- Error
  // 0010       -- Sync Lost
  // 0100       -- Busy
  // 0001       -- Overflow Warning
  // 1000       -- Ready

  // ===== signal combinations =====

  wire error;
  assign error = error_ttc_ready    |
                 error_data_corrupt |
                 error_pll_unlock   |
                 error_trig_rate    |
                 error_unknown_ttc;

  wire sync_lost;
  assign sync_lost = error_trig_num_from_tt  |
                     error_trig_num_from_cm  |
                     error_trig_type_from_tt |
                     error_trig_type_from_cm;

  wire overflow_warning;
  assign overflow_warning = overflow_warning_ddr3;

  // ===== TTS signal assignment =====

  // assign based on priority with nested conditionals
  assign tts_state = (error)            ? 4'b1100 :
                     (sync_lost)        ? 4'b0010 :
                     (overflow_warning) ? 4'b0001 : 
                                          4'b1000;

endmodule
