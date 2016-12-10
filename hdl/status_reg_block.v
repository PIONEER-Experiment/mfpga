`include "constants.txt"

// Register block to hold status of the Rider

module status_reg_block (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // FPGA status
  input wire prog_chan_done,
  input wire async_mode,

  // soft error thresholds
  input wire [31:0] thres_data_corrupt,
  input wire [31:0] thres_unknown_ttc,
  input wire [31:0] thres_ddr3_overflow,

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
  input wire [33:0] cm_state,
  input wire [ 3:0] ttr_state,
  input wire [ 3:0] ptr_state,
  input wire [ 3:0] cac_state,
  input wire [ 3:0] caca_state,
  input wire [ 6:0] tp_state,

  // acquisition
  input wire [4:0] acq_readout_pause,
  input wire [4:0] fill_type,
  input wire [4:0] chan_en,
  input wire endianness_sel,
  input wire [4:0] acq_dones,

  // trigger
  input wire trig_fifo_full,
  input wire acq_fifo_full,
  input wire [31:0] trig_delay,
  input wire [ 2:0] trig_settings,
  input wire [23:0] trig_num,
  input wire [43:0] trig_timestamp,
  input wire [23:0] pulse_trig_num,

  // slow control
  input wire [11:0] i2c_temp,
  input wire [15:0] xadc_temp,
  input wire [15:0] xadc_vccint,
  input wire [15:0] xadc_vccaux,
  input wire [15:0] xadc_vccbram,

  input wire xadc_over_temp,
  input wire xadc_alarm_temp,
  input wire xadc_alarm_vccint,
  input wire xadc_alarm_vccaux,
  input wire xadc_alarm_vccbram,

  // DDR3
  input wire [22:0] stored_bursts_chan0,
  input wire [22:0] stored_bursts_chan1,
  input wire [22:0] stored_bursts_chan2,
  input wire [22:0] stored_bursts_chan3,
  input wire [22:0] stored_bursts_chan4,

  // outputs to IPbus
  output wire [31:0] status_reg00,
  output wire [31:0] status_reg01,
  output wire [31:0] status_reg02,
  output wire [31:0] status_reg03,
  output wire [31:0] status_reg04,
  output wire [31:0] status_reg05,
  output wire [31:0] status_reg06,
  output wire [31:0] status_reg07,
  output wire [31:0] status_reg08,
  output wire [31:0] status_reg09,
  output wire [31:0] status_reg10,
  output wire [31:0] status_reg11,
  output wire [31:0] status_reg12,
  output wire [31:0] status_reg13,
  output wire [31:0] status_reg14,
  output wire [31:0] status_reg15,
  output wire [31:0] status_reg16,
  output wire [31:0] status_reg17,
  output wire [31:0] status_reg18,
  output wire [31:0] status_reg19,
  output wire [31:0] status_reg20,
  output wire [31:0] status_reg21,
  output wire [31:0] status_reg22,
  output wire [31:0] status_reg23,
  output wire [31:0] status_reg24,
  output wire [31:0] status_reg25,
  output wire [31:0] status_reg26,
  output wire [31:0] status_reg27,
  output wire [31:0] status_reg28
);


// Register 00: FPGA status and firmware version
assign status_reg00 = {1'b0, prog_chan_done, async_mode, 5'd0, `MAJOR_REV, `MINOR_REV, `PATCH_REV};

// Register 01: Error
assign status_reg01 = {26'd0, ddr3_overflow_warning, chan_error_rc[4:0], error_trig_type_from_cm, error_trig_type_from_tt, error_trig_num_from_cm, error_trig_num_from_tt, error_data_corrupt, error_trig_rate, error_unknown_ttc, error_pll_unlock};

// Register 02: External clock and temperature
assign status_reg02 = {i2c_temp[11:0], 18'd0, daq_clk_sel, daq_clk_en};

// Register 03: Clock synthesizer
assign status_reg03 = {28'd0, adcclk_clkin1_stat, adcclk_clkin0_stat, adcclk_stat_ld, adcclk_stat};

// Register 04: DAQ link
assign status_reg04 = {30'd0, daq_almost_full, daq_ready};

// Register 05: TTC/TTS
assign status_reg05 = {21'd0, tts_state[3:0], ttc_chan_b_info[5:0], ttc_ready};

// Register 06: FSM state 0
assign status_reg06 = cm_state[31:0];

// Register 07: FSM state 1
assign status_reg07 = {cm_state[33:32], 7'd0, tp_state[6:0], caca_state[3:0], cac_state[3:0], ptr_state[3:0], ttr_state[3:0]};

// Register 08: Acquisition
assign status_reg08 = {11'd0, acq_dones[4:0], endianness_sel, acq_readout_pause[4:0], fill_type[4:0], chan_en[4:0]};

// Register 09: TTC trigger information
assign status_reg09 = {27'd0, trig_settings[2:0], acq_fifo_full, trig_fifo_full};

// Register 10: TTC trigger delay
assign status_reg10 = trig_delay[31:0];

// Register 11: TTC trigger number
assign status_reg11 = {8'd0, trig_num[23:0]};

// Register 12: TTC trigger timestamp, LSB
assign status_reg12 = trig_timestamp[31:0];

// Register 13: TTC trigger timestamp, MSB
assign status_reg13 = {20'd0, trig_timestamp[43:32]};

// Register 14: Front panel trigger number
assign status_reg14 = {8'd0, pulse_trig_num[23:0]};

// Register 15: Data corruption threshold
assign status_reg15 = thres_data_corrupt[31:0];

// Register 16: Data corruption count
assign status_reg16 = cs_mismatch_count[31:0];

// Register 17: Unknown TTC broadcast command threshold
assign status_reg17 = thres_unknown_ttc[31:0];

// Register 18: Unknown TTC broadcast command count
assign status_reg18 = unknown_cmd_count[31:0];

// Register 19: DDR3 overflow threshold
assign status_reg19 = thres_ddr3_overflow[31:0];

// Register 20: DDR3 overflow count
assign status_reg20 = ddr3_overflow_count[31:0];

// Register 21: Channel 0 DDR3 burst count
assign status_reg21 = {7'd0, stored_bursts_chan0[22:0]};

// Register 22: Channel 1 DDR3 burst count
assign status_reg22 = {7'd0, stored_bursts_chan1[22:0]};

// Register 23: Channel 2 DDR3 burst count
assign status_reg23 = {7'd0, stored_bursts_chan2[22:0]};

// Register 24: Channel 3 DDR3 burst count
assign status_reg24 = {7'd0, stored_bursts_chan3[22:0]};

// Register 25: Channel 4 DDR3 burst count
assign status_reg25 = {7'd0, stored_bursts_chan4[22:0]};

// Register 26: XADC temperature and VCCINT
assign status_reg26 = {xadc_vccint[15:0], xadc_temp[15:0]};

// Register 27: XADC VCCAUX and VCCBRAM
assign status_reg27 = {xadc_vccbram[15:0], xadc_vccaux[15:0]};

// Register 28: XADC alarms
assign status_reg28 = {27'd0, xadc_alarm_vccbram, xadc_alarm_vccaux, xadc_alarm_vccint, xadc_alarm_temp, xadc_over_temp};

endmodule
