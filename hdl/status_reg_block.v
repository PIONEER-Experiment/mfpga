`include "constants.txt"

// Register block to hold status of the Rider

module status_reg_block (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // soft error thresholds
  input wire [31:0] thres_data_corrupt,  // data corruption
  input wire [31:0] thres_unknown_ttc,   // unknown TTC broadcast command
  input wire [31:0] thres_ddr3_overflow, // DDR3 overflow

  // soft error counts
  input wire [31:0] unknown_cmd_count,
  input wire [31:0] ddr3_overflow_count,
  input wire [31:0] cs_mismatch_count,

  // hard errors
  input wire error_data_corrupt,
  input wire error_trig_num_from_tt,
  input wire error_trig_type_from_tt,
  input wire error_trig_num_from_cm,
  input wire error_trig_type_from_cm,
  input wire error_pll_unlock,
  input wire error_trig_rate,
  input wire error_unknown_ttc,

  // warnings
  input wire ddr3_overflow_warning,

  // other error signals
  input wire [4:0] chan_error_rc,

  // external clock
  input wire daq_clk_sel,
  input wire daq_clk_en,

  // clock synthesizer
  input wire adcclk_clkin0_stat,
  input wire adcclk_clkin1_stat,
  input wire adcclk_stat_ld,
  input wire adcclk_stat,

  // DAQ link
  input wire daq_almost_full,
  input wire daq_ready,

  // TTC/TTS
  input wire [3:0] tts_state,
  input wire [5:0] ttc_chan_b_info,
  input wire ttc_ready,

  // FSM state
  input wire [30:0] cm_state,
  input wire [ 3:0] ttr_state,
  input wire [ 3:0] cac_state,
  input wire [ 6:0] tp_state,

  // acquisition
  input wire [4:0] acq_readout_pause,
  input wire [1:0] fill_type,
  input wire [4:0] chan_en,
  input wire endianness_sel,

  // trigger
  input wire trig_fifo_full,
  input wire acq_fifo_full,
  input wire [ 3:0] trig_delay,
  input wire [ 7:0] trig_settings,
  input wire [23:0] trig_num,
  input wire [43:0] trig_timestamp,

  // outputs to IPbus
  output wire [31:0] status_reg0,  // firmware version
  output wire [31:0] status_reg1,  // error / warning
  output wire [31:0] status_reg2,  // external clock
  output wire [31:0] status_reg3,  // clock synthesizer
  output wire [31:0] status_reg4,  // DAQ link
  output wire [31:0] status_reg5,  // TTC/TTS
  output wire [31:0] status_reg6,  // FSM state 0
  output wire [31:0] status_reg7,  // FSM state 1
  output wire [31:0] status_reg8,  // acquisition
  output wire [31:0] status_reg9,  // trigger information
  output wire [31:0] status_reg10, // trigger number
  output wire [31:0] status_reg11, // trigger timestamp, LSB
  output wire [31:0] status_reg12, // trigger timestamp, MSB
  output wire [31:0] status_reg13, // data corruption threshold
  output wire [31:0] status_reg14, // data corruption count
  output wire [31:0] status_reg15, // unknown TTC broadcast command threshold
  output wire [31:0] status_reg16, // unknown TTC broadcast command count
  output wire [31:0] status_reg17, // DDR3 overflow threshold
  output wire [31:0] status_reg18  // DDR3 overflow count
);

// Register 00: Firmware version
assign status_reg0 = {1'b1, 7'd0, `MAJOR_REV, `MINOR_REV, `BUILD_REV};

// Register 01: Error
assign status_reg1  = {27'd0, chan_error_rc[4:0], error_trig_type_from_cm, error_trig_type_from_tt, error_trig_num_from_cm, error_trig_num_from_tt, error_data_corrupt, error_trig_rate, error_unknown_ttc, error_pll_unlock};

// Register 02: External clock
assign status_reg2  = {30'd0, daq_clk_sel, daq_clk_en};

// Register 03: Clock synthesizer
assign status_reg3  = {28'd0, adcclk_clkin1_stat, adcclk_clkin0_stat, adcclk_stat_ld, adcclk_stat};

// Register 04: DAQ link
assign status_reg4  = {30'd0, daq_almost_full, daq_ready};

// Register 05: TTC/TTS
assign status_reg5  = {21'd0, tts_state[3:0], ttc_chan_b_info[5:0], ttc_ready};

// Register 06: FSM state 0
assign status_reg6  = {1'd0, cm_state[30:0]};

// Register 07: FSM state 1
assign status_reg7  = {17'd0, tp_state[6:0], cac_state[3:0], ttr_state[3:0]};

// Register 08: Acquisition
assign status_reg8  = {19'd0, endianness_sel, acq_readout_pause[4:0], fill_type[1:0], chan_en[4:0]};

// Register 09: Trigger information
assign status_reg9  = {18'd0, trig_settings[7:0], acq_fifo_full, trig_fifo_full, trig_delay[3:0]};

// Register 10: Trigger number
assign status_reg10 = {8'd0, trig_num[23:0]};

// Register 11: Trigger timestamp, LSB
assign status_reg11 = trig_timestamp[31:0];

// Register 12: Trigger timestamp, MSB
assign status_reg12 = {20'd0, trig_timestamp[43:32]};

// Register 13: Data corruption threshold
assign status_reg13 = thres_data_corrupt[31:0];

// Register 14: Data corruption count
assign status_reg14 = cs_mismatch_count[31:0];

// Register 15: Unknown TTC broadcast command threshold
assign status_reg15 = thres_unknown_ttc[31:0];

// Register 16: Unknown TTC broadcast command count
assign status_reg16 = unknown_cmd_count[31:0];

// Register 17: DDR3 overflow threshold
assign status_reg17 = thres_ddr3_overflow[31:0];

// Register 18: DDR3 overflow count
assign status_reg18 = ddr3_overflow_count[31:0];

endmodule
