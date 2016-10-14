# System clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports clkin]

# GTX clock for GigE
create_clock -period 8.000 -name gige_clk [get_ports gtx_clk0]

# TTC clock
create_clock -period 25.000 -name ttc_clk [get_ports ttc_clkp]

# DAQ_Link_7S (README said to include this line)
create_clock -period 4.000 -name DAQ_usrclk [get_pins daq/i_UsrClk/O]
create_clock -period 4.000 -name DAQ_txoutclk [get_pins daq/i_DAQLINK_7S_init/DAQLINK_7S_i/gt0_DAQLINK_7S_i/gtxe2_i/TXOUTCLK]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan1 [get_pins channels/chan1/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan2 [get_pins channels/chan2/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan3 [get_pins channels/chan3/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan4 [get_pins channels/chan4/clock_module/user_clk_buf_i/O]

# Statements to deal with inter-clock timing problems
set_false_path -from [get_cells reset_stretch/signal_out_reg*] -to [get_cells clk50_reset_sync/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][1]*}] -to [get_cells async_mode_clk50_module/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][11]*}] -to [get_cells prog_chan_start_sync/sync2_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][12]*}] -to [get_cells reprog_trigger_sync/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][13]*}] -to [get_cells reprog_trigger_sync/sync1_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_wr_nBytes_reg*] -to [get_cells spi_flash_intf/flash_wr_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_rd_nBytes_reg*] -to [get_cells spi_flash_intf/flash_rd_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_cmd_strobe_reg*] -to [get_cells spi_flash_intf/flash_cmd_sync/sync1_reg*]

# Statements to deal with intra-clock timing problems
set_false_path -from [get_cells command_manager/chan_burst_count_type1_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_burst_count_type2_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_burst_count_type3_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_burst_count_type7_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type1_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type2_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type3_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][6]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][7]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][8]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][9]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][10]*}] -to [get_cells command_manager/daq_data_reg*]

# Separate asynchronous clock domains
set_clock_groups -name async_clks -asynchronous \
	-group [get_clocks -include_generated_clocks clk50] \
	-group [get_clocks -include_generated_clocks gige_clk] \
	-group [get_clocks -include_generated_clocks ttc_clk] \
	-group [get_clocks -include_generated_clocks DAQ_usrclk] \
	-group [get_clocks -include_generated_clocks user_clk_chan0] \
	-group [get_clocks -include_generated_clocks user_clk_chan1] \
	-group [get_clocks -include_generated_clocks user_clk_chan2] \
	-group [get_clocks -include_generated_clocks user_clk_chan3] \
	-group [get_clocks -include_generated_clocks user_clk_chan4] \
	-group [get_clocks -include_generated_clocks ipb/eth/phy/inst/pcs_pma_block_i/transceiver_inst/gtwizard_inst/inst/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]
