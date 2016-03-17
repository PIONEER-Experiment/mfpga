// Register block to hold status of the Rider

module status_reg_block (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // error
  input wire [4:0] trig_num_error,
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
  input wire [4:0] tm_state,

  // acquisition
  input wire [4:0] acq_readout_pause,
  input wire [1:0] fill_type,
  input wire [4:0] chan_en,

  // trigger
  input wire trig_info_fifo_full,
  input wire [3:0] trig_delay,
  input wire [63:0] trig_num,
  input wire [63:0] trig_timestamp,

  // outputs to IPbus
  output wire [31:0] status_reg0,  // error
  output wire [31:0] status_reg1,  // external clock
  output wire [31:0] status_reg2,  // clock synthesizer
  output wire [31:0] status_reg3,  // DAQ link
  output wire [31:0] status_reg4,  // TTC/TTS
  output wire [31:0] status_reg5,  // FSM state 0
  output wire [31:0] status_reg6,  // FSM state 1
  output wire [31:0] status_reg7,  // acquisition
  output wire [31:0] status_reg8,  // trigger information
  output wire [31:0] status_reg9,  // trigger number, LSB
  output wire [31:0] status_reg10, // trigger number, MSB
  output wire [31:0] status_reg11, // trigger timestamp, LSB
  output wire [31:0] status_reg12  // trigger timestamp, MSB
);

// Register 00: Error
assign status_reg0  = {22'd0, trig_num_error[4:0], chan_error_rc[4:0]};

// Register 01: External clock
assign status_reg1  = {30'd0, daq_clk_sel, daq_clk_en};

// Register 02: Clock synthesizer
assign status_reg2  = {28'd0, adcclk_clkin1_stat, adcclk_clkin0_stat, adcclk_stat_ld, adcclk_stat};

// Register 03: DAQ link
assign status_reg3  = {30'd0, daq_almost_full, daq_ready};

// Register 04: TTC/TTS
assign status_reg4  = {21'd0, tts_state[3:0], ttc_chan_b_info[5:0], ttc_ready};

// Register 05: FSM state 0
assign status_reg5  = {1'd0, cm_state[30:0]};

// Register 06: FSM state 1
assign status_reg6  = {27'd0, tm_state[4:0]};

// Register 07: Acquisition
assign status_reg7  = {20'd0, acq_readout_pause[4:0], fill_type[1:0], chan_en[4:0]};

// Register 08: Trigger information
assign status_reg8  = {27'd0, trig_info_fifo_full, trig_delay[3:0]};

// Register 09: Trigger number, LSB
assign status_reg9  = trig_num[31:0];

// Register 10: Trigger number, MSB
assign status_reg10 = trig_num[63:32];

// Register 11: Trigger timestamp, LSB
assign status_reg11 = trig_timestamp[31:0];

// Register 12: Trigger timestamp, MSB
assign status_reg12 = trig_timestamp[63:32];

endmodule