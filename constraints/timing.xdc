# system clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports clkin]

# GTX clock for GigE
create_clock -period 8.000 -name gige_clk [get_ports gtx_clk0]

# TTC clock
create_clock -period 25.000 -name ttc_clk [get_ports ttc_clkp]

# DAQ_Link_7S (README said to include this line)
create_clock -period 4.000 -name DAQ_usrclk [get_pins daq/i_UsrClk/O]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan1 [get_pins channels/chan1/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan2 [get_pins channels/chan2/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan3 [get_pins channels/chan3/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan4 [get_pins channels/chan4/clock_module/user_clk_buf_i/O]

# statements to deal with inter-clock timing problems
set_false_path -from [get_cells reset_stretch/signal_out_reg*] -to [get_cells clk50_reset_sync/sync1_reg*]
set_false_path -from [get_cells ipb/slaves/slave1/reg_reg*] -to [get_cells prog_chan_start_sync/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][12]*}] -to [get_cells reprog_trigger_sync/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][13]*}] -to [get_cells reprog_trigger_sync/sync1_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_wr_nBytes_reg*] -to [get_cells spi_flash_intf/flash_wr_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_rd_nBytes_reg*] -to [get_cells spi_flash_intf/flash_rd_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave4/flash_cmd_strobe_reg*] -to [get_cells spi_flash_intf/flash_cmd_sync/sync1_reg*]

# statements to deal with intra-clock timing problems
set_false_path -from [get_cells command_manager/chan_burst_count_type1_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_burst_count_type2_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_burst_count_type3_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type1_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type2_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells command_manager/chan_wfm_count_type3_reg*] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][6]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][7]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][8]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][9]*}] -to [get_cells command_manager/daq_data_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][10]*}] -to [get_cells command_manager/daq_data_reg*]

# Separate asynchronous clock domains
set_clock_groups -name async_clks -asynchronous -group [get_clocks -include_generated_clocks clk50] -group [get_clocks -include_generated_clocks gige_clk] -group [get_clocks -include_generated_clocks ttc_clk] -group [get_clocks -include_generated_clocks DAQ_usrclk] -group [get_clocks -include_generated_clocks user_clk_chan0] -group [get_clocks -include_generated_clocks user_clk_chan1] -group [get_clocks -include_generated_clocks user_clk_chan2] -group [get_clocks -include_generated_clocks user_clk_chan3] -group [get_clocks -include_generated_clocks user_clk_chan4] -group [get_clocks -include_generated_clocks ipb/eth/phy/inst/pcs_pma_block_i/transceiver_inst/gtwizard_inst/inst/gtwizard_i/gt0_GTWIZARD_i/gtxe2_i/TXOUTCLK]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk125]]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {command_manager/chan_tx_fifo_data[0]} {command_manager/chan_tx_fifo_data[1]} {command_manager/chan_tx_fifo_data[2]} {command_manager/chan_tx_fifo_data[3]} {command_manager/chan_tx_fifo_data[4]} {command_manager/chan_tx_fifo_data[5]} {command_manager/chan_tx_fifo_data[6]} {command_manager/chan_tx_fifo_data[7]} {command_manager/chan_tx_fifo_data[8]} {command_manager/chan_tx_fifo_data[9]} {command_manager/chan_tx_fifo_data[10]} {command_manager/chan_tx_fifo_data[11]} {command_manager/chan_tx_fifo_data[12]} {command_manager/chan_tx_fifo_data[13]} {command_manager/chan_tx_fifo_data[14]} {command_manager/chan_tx_fifo_data[15]} {command_manager/chan_tx_fifo_data[16]} {command_manager/chan_tx_fifo_data[17]} {command_manager/chan_tx_fifo_data[18]} {command_manager/chan_tx_fifo_data[19]} {command_manager/chan_tx_fifo_data[20]} {command_manager/chan_tx_fifo_data[21]} {command_manager/chan_tx_fifo_data[22]} {command_manager/chan_tx_fifo_data[23]} {command_manager/chan_tx_fifo_data[24]} {command_manager/chan_tx_fifo_data[25]} {command_manager/chan_tx_fifo_data[26]} {command_manager/chan_tx_fifo_data[27]} {command_manager/chan_tx_fifo_data[28]} {command_manager/chan_tx_fifo_data[29]} {command_manager/chan_tx_fifo_data[30]} {command_manager/chan_tx_fifo_data[31]}]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list ttc_clk]]
set_property port_width 5 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {trigger_top/channel_acq_controller_async/acq_dones[0]} {trigger_top/channel_acq_controller_async/acq_dones[1]} {trigger_top/channel_acq_controller_async/acq_dones[2]} {trigger_top/channel_acq_controller_async/acq_dones[3]} {trigger_top/channel_acq_controller_async/acq_dones[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 64 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {command_manager/daq_data[0]} {command_manager/daq_data[1]} {command_manager/daq_data[2]} {command_manager/daq_data[3]} {command_manager/daq_data[4]} {command_manager/daq_data[5]} {command_manager/daq_data[6]} {command_manager/daq_data[7]} {command_manager/daq_data[8]} {command_manager/daq_data[9]} {command_manager/daq_data[10]} {command_manager/daq_data[11]} {command_manager/daq_data[12]} {command_manager/daq_data[13]} {command_manager/daq_data[14]} {command_manager/daq_data[15]} {command_manager/daq_data[16]} {command_manager/daq_data[17]} {command_manager/daq_data[18]} {command_manager/daq_data[19]} {command_manager/daq_data[20]} {command_manager/daq_data[21]} {command_manager/daq_data[22]} {command_manager/daq_data[23]} {command_manager/daq_data[24]} {command_manager/daq_data[25]} {command_manager/daq_data[26]} {command_manager/daq_data[27]} {command_manager/daq_data[28]} {command_manager/daq_data[29]} {command_manager/daq_data[30]} {command_manager/daq_data[31]} {command_manager/daq_data[32]} {command_manager/daq_data[33]} {command_manager/daq_data[34]} {command_manager/daq_data[35]} {command_manager/daq_data[36]} {command_manager/daq_data[37]} {command_manager/daq_data[38]} {command_manager/daq_data[39]} {command_manager/daq_data[40]} {command_manager/daq_data[41]} {command_manager/daq_data[42]} {command_manager/daq_data[43]} {command_manager/daq_data[44]} {command_manager/daq_data[45]} {command_manager/daq_data[46]} {command_manager/daq_data[47]} {command_manager/daq_data[48]} {command_manager/daq_data[49]} {command_manager/daq_data[50]} {command_manager/daq_data[51]} {command_manager/daq_data[52]} {command_manager/daq_data[53]} {command_manager/daq_data[54]} {command_manager/daq_data[55]} {command_manager/daq_data[56]} {command_manager/daq_data[57]} {command_manager/daq_data[58]} {command_manager/daq_data[59]} {command_manager/daq_data[60]} {command_manager/daq_data[61]} {command_manager/daq_data[62]} {command_manager/daq_data[63]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {command_manager/event_num[0]} {command_manager/event_num[1]} {command_manager/event_num[2]} {command_manager/event_num[3]} {command_manager/event_num[4]} {command_manager/event_num[5]} {command_manager/event_num[6]} {command_manager/event_num[7]} {command_manager/event_num[8]} {command_manager/event_num[9]} {command_manager/event_num[10]} {command_manager/event_num[11]} {command_manager/event_num[12]} {command_manager/event_num[13]} {command_manager/event_num[14]} {command_manager/event_num[15]} {command_manager/event_num[16]} {command_manager/event_num[17]} {command_manager/event_num[18]} {command_manager/event_num[19]} {command_manager/event_num[20]} {command_manager/event_num[21]} {command_manager/event_num[22]} {command_manager/event_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {command_manager/trig_type[0]} {command_manager/trig_type[1]} {command_manager/trig_type[2]}]]
create_debug_port u_ila_0 probe
set_property port_width 44 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {command_manager/trig_timestamp[0]} {command_manager/trig_timestamp[1]} {command_manager/trig_timestamp[2]} {command_manager/trig_timestamp[3]} {command_manager/trig_timestamp[4]} {command_manager/trig_timestamp[5]} {command_manager/trig_timestamp[6]} {command_manager/trig_timestamp[7]} {command_manager/trig_timestamp[8]} {command_manager/trig_timestamp[9]} {command_manager/trig_timestamp[10]} {command_manager/trig_timestamp[11]} {command_manager/trig_timestamp[12]} {command_manager/trig_timestamp[13]} {command_manager/trig_timestamp[14]} {command_manager/trig_timestamp[15]} {command_manager/trig_timestamp[16]} {command_manager/trig_timestamp[17]} {command_manager/trig_timestamp[18]} {command_manager/trig_timestamp[19]} {command_manager/trig_timestamp[20]} {command_manager/trig_timestamp[21]} {command_manager/trig_timestamp[22]} {command_manager/trig_timestamp[23]} {command_manager/trig_timestamp[24]} {command_manager/trig_timestamp[25]} {command_manager/trig_timestamp[26]} {command_manager/trig_timestamp[27]} {command_manager/trig_timestamp[28]} {command_manager/trig_timestamp[29]} {command_manager/trig_timestamp[30]} {command_manager/trig_timestamp[31]} {command_manager/trig_timestamp[32]} {command_manager/trig_timestamp[33]} {command_manager/trig_timestamp[34]} {command_manager/trig_timestamp[35]} {command_manager/trig_timestamp[36]} {command_manager/trig_timestamp[37]} {command_manager/trig_timestamp[38]} {command_manager/trig_timestamp[39]} {command_manager/trig_timestamp[40]} {command_manager/trig_timestamp[41]} {command_manager/trig_timestamp[42]} {command_manager/trig_timestamp[43]}]]
create_debug_port u_ila_0 probe
set_property port_width 22 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {command_manager/readout_size[0]} {command_manager/readout_size[1]} {command_manager/readout_size[2]} {command_manager/readout_size[3]} {command_manager/readout_size[4]} {command_manager/readout_size[5]} {command_manager/readout_size[6]} {command_manager/readout_size[7]} {command_manager/readout_size[8]} {command_manager/readout_size[9]} {command_manager/readout_size[10]} {command_manager/readout_size[11]} {command_manager/readout_size[12]} {command_manager/readout_size[13]} {command_manager/readout_size[14]} {command_manager/readout_size[15]} {command_manager/readout_size[16]} {command_manager/readout_size[17]} {command_manager/readout_size[18]} {command_manager/readout_size[19]} {command_manager/readout_size[20]} {command_manager/readout_size[21]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {command_manager/trig_num[0]} {command_manager/trig_num[1]} {command_manager/trig_num[2]} {command_manager/trig_num[3]} {command_manager/trig_num[4]} {command_manager/trig_num[5]} {command_manager/trig_num[6]} {command_manager/trig_num[7]} {command_manager/trig_num[8]} {command_manager/trig_num[9]} {command_manager/trig_num[10]} {command_manager/trig_num[11]} {command_manager/trig_num[12]} {command_manager/trig_num[13]} {command_manager/trig_num[14]} {command_manager/trig_num[15]} {command_manager/trig_num[16]} {command_manager/trig_num[17]} {command_manager/trig_num[18]} {command_manager/trig_num[19]} {command_manager/trig_num[20]} {command_manager/trig_num[21]} {command_manager/trig_num[22]} {command_manager/trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {command_manager/chan_rx_fifo_data[0]} {command_manager/chan_rx_fifo_data[1]} {command_manager/chan_rx_fifo_data[2]} {command_manager/chan_rx_fifo_data[3]} {command_manager/chan_rx_fifo_data[4]} {command_manager/chan_rx_fifo_data[5]} {command_manager/chan_rx_fifo_data[6]} {command_manager/chan_rx_fifo_data[7]} {command_manager/chan_rx_fifo_data[8]} {command_manager/chan_rx_fifo_data[9]} {command_manager/chan_rx_fifo_data[10]} {command_manager/chan_rx_fifo_data[11]} {command_manager/chan_rx_fifo_data[12]} {command_manager/chan_rx_fifo_data[13]} {command_manager/chan_rx_fifo_data[14]} {command_manager/chan_rx_fifo_data[15]} {command_manager/chan_rx_fifo_data[16]} {command_manager/chan_rx_fifo_data[17]} {command_manager/chan_rx_fifo_data[18]} {command_manager/chan_rx_fifo_data[19]} {command_manager/chan_rx_fifo_data[20]} {command_manager/chan_rx_fifo_data[21]} {command_manager/chan_rx_fifo_data[22]} {command_manager/chan_rx_fifo_data[23]} {command_manager/chan_rx_fifo_data[24]} {command_manager/chan_rx_fifo_data[25]} {command_manager/chan_rx_fifo_data[26]} {command_manager/chan_rx_fifo_data[27]} {command_manager/chan_rx_fifo_data[28]} {command_manager/chan_rx_fifo_data[29]} {command_manager/chan_rx_fifo_data[30]} {command_manager/chan_rx_fifo_data[31]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {trigger_top/channel_acq_controller_async/acq_trig[0]} {trigger_top/channel_acq_controller_async/acq_trig[1]} {trigger_top/channel_acq_controller_async/acq_trig[2]} {trigger_top/channel_acq_controller_async/acq_trig[3]} {trigger_top/channel_acq_controller_async/acq_trig[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {trigger_top/channel_acq_controller_async/chan_en[0]} {trigger_top/channel_acq_controller_async/chan_en[1]} {trigger_top/channel_acq_controller_async/chan_en[2]} {trigger_top/channel_acq_controller_async/chan_en[3]} {trigger_top/channel_acq_controller_async/chan_en[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 128 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {trigger_top/trigger_processor/trig_fifo_data[0]} {trigger_top/trigger_processor/trig_fifo_data[1]} {trigger_top/trigger_processor/trig_fifo_data[2]} {trigger_top/trigger_processor/trig_fifo_data[3]} {trigger_top/trigger_processor/trig_fifo_data[4]} {trigger_top/trigger_processor/trig_fifo_data[5]} {trigger_top/trigger_processor/trig_fifo_data[6]} {trigger_top/trigger_processor/trig_fifo_data[7]} {trigger_top/trigger_processor/trig_fifo_data[8]} {trigger_top/trigger_processor/trig_fifo_data[9]} {trigger_top/trigger_processor/trig_fifo_data[10]} {trigger_top/trigger_processor/trig_fifo_data[11]} {trigger_top/trigger_processor/trig_fifo_data[12]} {trigger_top/trigger_processor/trig_fifo_data[13]} {trigger_top/trigger_processor/trig_fifo_data[14]} {trigger_top/trigger_processor/trig_fifo_data[15]} {trigger_top/trigger_processor/trig_fifo_data[16]} {trigger_top/trigger_processor/trig_fifo_data[17]} {trigger_top/trigger_processor/trig_fifo_data[18]} {trigger_top/trigger_processor/trig_fifo_data[19]} {trigger_top/trigger_processor/trig_fifo_data[20]} {trigger_top/trigger_processor/trig_fifo_data[21]} {trigger_top/trigger_processor/trig_fifo_data[22]} {trigger_top/trigger_processor/trig_fifo_data[23]} {trigger_top/trigger_processor/trig_fifo_data[24]} {trigger_top/trigger_processor/trig_fifo_data[25]} {trigger_top/trigger_processor/trig_fifo_data[26]} {trigger_top/trigger_processor/trig_fifo_data[27]} {trigger_top/trigger_processor/trig_fifo_data[28]} {trigger_top/trigger_processor/trig_fifo_data[29]} {trigger_top/trigger_processor/trig_fifo_data[30]} {trigger_top/trigger_processor/trig_fifo_data[31]} {trigger_top/trigger_processor/trig_fifo_data[32]} {trigger_top/trigger_processor/trig_fifo_data[33]} {trigger_top/trigger_processor/trig_fifo_data[34]} {trigger_top/trigger_processor/trig_fifo_data[35]} {trigger_top/trigger_processor/trig_fifo_data[36]} {trigger_top/trigger_processor/trig_fifo_data[37]} {trigger_top/trigger_processor/trig_fifo_data[38]} {trigger_top/trigger_processor/trig_fifo_data[39]} {trigger_top/trigger_processor/trig_fifo_data[40]} {trigger_top/trigger_processor/trig_fifo_data[41]} {trigger_top/trigger_processor/trig_fifo_data[42]} {trigger_top/trigger_processor/trig_fifo_data[43]} {trigger_top/trigger_processor/trig_fifo_data[44]} {trigger_top/trigger_processor/trig_fifo_data[45]} {trigger_top/trigger_processor/trig_fifo_data[46]} {trigger_top/trigger_processor/trig_fifo_data[47]} {trigger_top/trigger_processor/trig_fifo_data[48]} {trigger_top/trigger_processor/trig_fifo_data[49]} {trigger_top/trigger_processor/trig_fifo_data[50]} {trigger_top/trigger_processor/trig_fifo_data[51]} {trigger_top/trigger_processor/trig_fifo_data[52]} {trigger_top/trigger_processor/trig_fifo_data[53]} {trigger_top/trigger_processor/trig_fifo_data[54]} {trigger_top/trigger_processor/trig_fifo_data[55]} {trigger_top/trigger_processor/trig_fifo_data[56]} {trigger_top/trigger_processor/trig_fifo_data[57]} {trigger_top/trigger_processor/trig_fifo_data[58]} {trigger_top/trigger_processor/trig_fifo_data[59]} {trigger_top/trigger_processor/trig_fifo_data[60]} {trigger_top/trigger_processor/trig_fifo_data[61]} {trigger_top/trigger_processor/trig_fifo_data[62]} {trigger_top/trigger_processor/trig_fifo_data[63]} {trigger_top/trigger_processor/trig_fifo_data[64]} {trigger_top/trigger_processor/trig_fifo_data[65]} {trigger_top/trigger_processor/trig_fifo_data[66]} {trigger_top/trigger_processor/trig_fifo_data[67]} {trigger_top/trigger_processor/trig_fifo_data[68]} {trigger_top/trigger_processor/trig_fifo_data[69]} {trigger_top/trigger_processor/trig_fifo_data[70]} {trigger_top/trigger_processor/trig_fifo_data[71]} {trigger_top/trigger_processor/trig_fifo_data[72]} {trigger_top/trigger_processor/trig_fifo_data[73]} {trigger_top/trigger_processor/trig_fifo_data[74]} {trigger_top/trigger_processor/trig_fifo_data[75]} {trigger_top/trigger_processor/trig_fifo_data[76]} {trigger_top/trigger_processor/trig_fifo_data[77]} {trigger_top/trigger_processor/trig_fifo_data[78]} {trigger_top/trigger_processor/trig_fifo_data[79]} {trigger_top/trigger_processor/trig_fifo_data[80]} {trigger_top/trigger_processor/trig_fifo_data[81]} {trigger_top/trigger_processor/trig_fifo_data[82]} {trigger_top/trigger_processor/trig_fifo_data[83]} {trigger_top/trigger_processor/trig_fifo_data[84]} {trigger_top/trigger_processor/trig_fifo_data[85]} {trigger_top/trigger_processor/trig_fifo_data[86]} {trigger_top/trigger_processor/trig_fifo_data[87]} {trigger_top/trigger_processor/trig_fifo_data[88]} {trigger_top/trigger_processor/trig_fifo_data[89]} {trigger_top/trigger_processor/trig_fifo_data[90]} {trigger_top/trigger_processor/trig_fifo_data[91]} {trigger_top/trigger_processor/trig_fifo_data[92]} {trigger_top/trigger_processor/trig_fifo_data[93]} {trigger_top/trigger_processor/trig_fifo_data[94]} {trigger_top/trigger_processor/trig_fifo_data[95]} {trigger_top/trigger_processor/trig_fifo_data[96]} {trigger_top/trigger_processor/trig_fifo_data[97]} {trigger_top/trigger_processor/trig_fifo_data[98]} {trigger_top/trigger_processor/trig_fifo_data[99]} {trigger_top/trigger_processor/trig_fifo_data[100]} {trigger_top/trigger_processor/trig_fifo_data[101]} {trigger_top/trigger_processor/trig_fifo_data[102]} {trigger_top/trigger_processor/trig_fifo_data[103]} {trigger_top/trigger_processor/trig_fifo_data[104]} {trigger_top/trigger_processor/trig_fifo_data[105]} {trigger_top/trigger_processor/trig_fifo_data[106]} {trigger_top/trigger_processor/trig_fifo_data[107]} {trigger_top/trigger_processor/trig_fifo_data[108]} {trigger_top/trigger_processor/trig_fifo_data[109]} {trigger_top/trigger_processor/trig_fifo_data[110]} {trigger_top/trigger_processor/trig_fifo_data[111]} {trigger_top/trigger_processor/trig_fifo_data[112]} {trigger_top/trigger_processor/trig_fifo_data[113]} {trigger_top/trigger_processor/trig_fifo_data[114]} {trigger_top/trigger_processor/trig_fifo_data[115]} {trigger_top/trigger_processor/trig_fifo_data[116]} {trigger_top/trigger_processor/trig_fifo_data[117]} {trigger_top/trigger_processor/trig_fifo_data[118]} {trigger_top/trigger_processor/trig_fifo_data[119]} {trigger_top/trigger_processor/trig_fifo_data[120]} {trigger_top/trigger_processor/trig_fifo_data[121]} {trigger_top/trigger_processor/trig_fifo_data[122]} {trigger_top/trigger_processor/trig_fifo_data[123]} {trigger_top/trigger_processor/trig_fifo_data[124]} {trigger_top/trigger_processor/trig_fifo_data[125]} {trigger_top/trigger_processor/trig_fifo_data[126]} {trigger_top/trigger_processor/trig_fifo_data[127]}]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {trigger_top/trigger_processor/acq_fifo_data[0]} {trigger_top/trigger_processor/acq_fifo_data[1]} {trigger_top/trigger_processor/acq_fifo_data[2]} {trigger_top/trigger_processor/acq_fifo_data[3]} {trigger_top/trigger_processor/acq_fifo_data[4]} {trigger_top/trigger_processor/acq_fifo_data[5]} {trigger_top/trigger_processor/acq_fifo_data[6]} {trigger_top/trigger_processor/acq_fifo_data[7]} {trigger_top/trigger_processor/acq_fifo_data[8]} {trigger_top/trigger_processor/acq_fifo_data[9]} {trigger_top/trigger_processor/acq_fifo_data[10]} {trigger_top/trigger_processor/acq_fifo_data[11]} {trigger_top/trigger_processor/acq_fifo_data[12]} {trigger_top/trigger_processor/acq_fifo_data[13]} {trigger_top/trigger_processor/acq_fifo_data[14]} {trigger_top/trigger_processor/acq_fifo_data[15]} {trigger_top/trigger_processor/acq_fifo_data[16]} {trigger_top/trigger_processor/acq_fifo_data[17]} {trigger_top/trigger_processor/acq_fifo_data[18]} {trigger_top/trigger_processor/acq_fifo_data[19]} {trigger_top/trigger_processor/acq_fifo_data[20]} {trigger_top/trigger_processor/acq_fifo_data[21]} {trigger_top/trigger_processor/acq_fifo_data[22]} {trigger_top/trigger_processor/acq_fifo_data[23]} {trigger_top/trigger_processor/acq_fifo_data[24]} {trigger_top/trigger_processor/acq_fifo_data[25]} {trigger_top/trigger_processor/acq_fifo_data[26]} {trigger_top/trigger_processor/acq_fifo_data[27]} {trigger_top/trigger_processor/acq_fifo_data[28]} {trigger_top/trigger_processor/acq_fifo_data[29]} {trigger_top/trigger_processor/acq_fifo_data[30]} {trigger_top/trigger_processor/acq_fifo_data[31]}]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {cm_state[0]} {cm_state[1]} {cm_state[2]} {cm_state[3]} {cm_state[4]} {cm_state[5]} {cm_state[6]} {cm_state[7]} {cm_state[8]} {cm_state[9]} {cm_state[10]} {cm_state[11]} {cm_state[12]} {cm_state[13]} {cm_state[14]} {cm_state[15]} {cm_state[16]} {cm_state[17]} {cm_state[18]} {cm_state[19]} {cm_state[20]} {cm_state[21]} {cm_state[22]} {cm_state[23]} {cm_state[24]} {cm_state[25]} {cm_state[26]} {cm_state[27]} {cm_state[28]} {cm_state[29]} {cm_state[30]} {cm_state[31]}]]
create_debug_port u_ila_0 probe
set_property port_width 128 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {trigger_top/s_pulse_fifo_tdata[0]} {trigger_top/s_pulse_fifo_tdata[1]} {trigger_top/s_pulse_fifo_tdata[2]} {trigger_top/s_pulse_fifo_tdata[3]} {trigger_top/s_pulse_fifo_tdata[4]} {trigger_top/s_pulse_fifo_tdata[5]} {trigger_top/s_pulse_fifo_tdata[6]} {trigger_top/s_pulse_fifo_tdata[7]} {trigger_top/s_pulse_fifo_tdata[8]} {trigger_top/s_pulse_fifo_tdata[9]} {trigger_top/s_pulse_fifo_tdata[10]} {trigger_top/s_pulse_fifo_tdata[11]} {trigger_top/s_pulse_fifo_tdata[12]} {trigger_top/s_pulse_fifo_tdata[13]} {trigger_top/s_pulse_fifo_tdata[14]} {trigger_top/s_pulse_fifo_tdata[15]} {trigger_top/s_pulse_fifo_tdata[16]} {trigger_top/s_pulse_fifo_tdata[17]} {trigger_top/s_pulse_fifo_tdata[18]} {trigger_top/s_pulse_fifo_tdata[19]} {trigger_top/s_pulse_fifo_tdata[20]} {trigger_top/s_pulse_fifo_tdata[21]} {trigger_top/s_pulse_fifo_tdata[22]} {trigger_top/s_pulse_fifo_tdata[23]} {trigger_top/s_pulse_fifo_tdata[24]} {trigger_top/s_pulse_fifo_tdata[25]} {trigger_top/s_pulse_fifo_tdata[26]} {trigger_top/s_pulse_fifo_tdata[27]} {trigger_top/s_pulse_fifo_tdata[28]} {trigger_top/s_pulse_fifo_tdata[29]} {trigger_top/s_pulse_fifo_tdata[30]} {trigger_top/s_pulse_fifo_tdata[31]} {trigger_top/s_pulse_fifo_tdata[32]} {trigger_top/s_pulse_fifo_tdata[33]} {trigger_top/s_pulse_fifo_tdata[34]} {trigger_top/s_pulse_fifo_tdata[35]} {trigger_top/s_pulse_fifo_tdata[36]} {trigger_top/s_pulse_fifo_tdata[37]} {trigger_top/s_pulse_fifo_tdata[38]} {trigger_top/s_pulse_fifo_tdata[39]} {trigger_top/s_pulse_fifo_tdata[40]} {trigger_top/s_pulse_fifo_tdata[41]} {trigger_top/s_pulse_fifo_tdata[42]} {trigger_top/s_pulse_fifo_tdata[43]} {trigger_top/s_pulse_fifo_tdata[44]} {trigger_top/s_pulse_fifo_tdata[45]} {trigger_top/s_pulse_fifo_tdata[46]} {trigger_top/s_pulse_fifo_tdata[47]} {trigger_top/s_pulse_fifo_tdata[48]} {trigger_top/s_pulse_fifo_tdata[49]} {trigger_top/s_pulse_fifo_tdata[50]} {trigger_top/s_pulse_fifo_tdata[51]} {trigger_top/s_pulse_fifo_tdata[52]} {trigger_top/s_pulse_fifo_tdata[53]} {trigger_top/s_pulse_fifo_tdata[54]} {trigger_top/s_pulse_fifo_tdata[55]} {trigger_top/s_pulse_fifo_tdata[56]} {trigger_top/s_pulse_fifo_tdata[57]} {trigger_top/s_pulse_fifo_tdata[58]} {trigger_top/s_pulse_fifo_tdata[59]} {trigger_top/s_pulse_fifo_tdata[60]} {trigger_top/s_pulse_fifo_tdata[61]} {trigger_top/s_pulse_fifo_tdata[62]} {trigger_top/s_pulse_fifo_tdata[63]} {trigger_top/s_pulse_fifo_tdata[64]} {trigger_top/s_pulse_fifo_tdata[65]} {trigger_top/s_pulse_fifo_tdata[66]} {trigger_top/s_pulse_fifo_tdata[67]} {trigger_top/s_pulse_fifo_tdata[68]} {trigger_top/s_pulse_fifo_tdata[69]} {trigger_top/s_pulse_fifo_tdata[70]} {trigger_top/s_pulse_fifo_tdata[71]} {trigger_top/s_pulse_fifo_tdata[72]} {trigger_top/s_pulse_fifo_tdata[73]} {trigger_top/s_pulse_fifo_tdata[74]} {trigger_top/s_pulse_fifo_tdata[75]} {trigger_top/s_pulse_fifo_tdata[76]} {trigger_top/s_pulse_fifo_tdata[77]} {trigger_top/s_pulse_fifo_tdata[78]} {trigger_top/s_pulse_fifo_tdata[79]} {trigger_top/s_pulse_fifo_tdata[80]} {trigger_top/s_pulse_fifo_tdata[81]} {trigger_top/s_pulse_fifo_tdata[82]} {trigger_top/s_pulse_fifo_tdata[83]} {trigger_top/s_pulse_fifo_tdata[84]} {trigger_top/s_pulse_fifo_tdata[85]} {trigger_top/s_pulse_fifo_tdata[86]} {trigger_top/s_pulse_fifo_tdata[87]} {trigger_top/s_pulse_fifo_tdata[88]} {trigger_top/s_pulse_fifo_tdata[89]} {trigger_top/s_pulse_fifo_tdata[90]} {trigger_top/s_pulse_fifo_tdata[91]} {trigger_top/s_pulse_fifo_tdata[92]} {trigger_top/s_pulse_fifo_tdata[93]} {trigger_top/s_pulse_fifo_tdata[94]} {trigger_top/s_pulse_fifo_tdata[95]} {trigger_top/s_pulse_fifo_tdata[96]} {trigger_top/s_pulse_fifo_tdata[97]} {trigger_top/s_pulse_fifo_tdata[98]} {trigger_top/s_pulse_fifo_tdata[99]} {trigger_top/s_pulse_fifo_tdata[100]} {trigger_top/s_pulse_fifo_tdata[101]} {trigger_top/s_pulse_fifo_tdata[102]} {trigger_top/s_pulse_fifo_tdata[103]} {trigger_top/s_pulse_fifo_tdata[104]} {trigger_top/s_pulse_fifo_tdata[105]} {trigger_top/s_pulse_fifo_tdata[106]} {trigger_top/s_pulse_fifo_tdata[107]} {trigger_top/s_pulse_fifo_tdata[108]} {trigger_top/s_pulse_fifo_tdata[109]} {trigger_top/s_pulse_fifo_tdata[110]} {trigger_top/s_pulse_fifo_tdata[111]} {trigger_top/s_pulse_fifo_tdata[112]} {trigger_top/s_pulse_fifo_tdata[113]} {trigger_top/s_pulse_fifo_tdata[114]} {trigger_top/s_pulse_fifo_tdata[115]} {trigger_top/s_pulse_fifo_tdata[116]} {trigger_top/s_pulse_fifo_tdata[117]} {trigger_top/s_pulse_fifo_tdata[118]} {trigger_top/s_pulse_fifo_tdata[119]} {trigger_top/s_pulse_fifo_tdata[120]} {trigger_top/s_pulse_fifo_tdata[121]} {trigger_top/s_pulse_fifo_tdata[122]} {trigger_top/s_pulse_fifo_tdata[123]} {trigger_top/s_pulse_fifo_tdata[124]} {trigger_top/s_pulse_fifo_tdata[125]} {trigger_top/s_pulse_fifo_tdata[126]} {trigger_top/s_pulse_fifo_tdata[127]}]]
create_debug_port u_ila_0 probe
set_property port_width 7 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {tp_state[0]} {tp_state[1]} {tp_state[2]} {tp_state[3]} {tp_state[4]} {tp_state[5]} {tp_state[6]}]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {cac_state[0]} {cac_state[1]} {cac_state[2]} {cac_state[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list trigger_top/trigger_processor/acq_fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list trigger_top/trigger_processor/acq_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list command_manager/chan_rx_fifo_last]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list command_manager/chan_rx_fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list command_manager/chan_rx_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list command_manager/chan_tx_fifo_last]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list command_manager/chan_tx_fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list command_manager/chan_tx_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list command_manager/daq_header]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list command_manager/daq_trailer]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list command_manager/daq_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list command_manager/error_trig_num]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list fp_sw_master_IBUF]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list command_manager/initiate_readout]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list trigger_top/trigger_processor/next_ttc_empty_event]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list trigger_top/readout_done]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list trigger_top/trigger_processor/trig_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list trigger_from_ipbus]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {trigger_top/channel_acq_controller_async/acq_enable[0]}]]
create_debug_port u_ila_1 probe
set_property port_width 5 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {trigger_top/channel_acq_controller_async/acq_dones_latched[0]} {trigger_top/channel_acq_controller_async/acq_dones_latched[1]} {trigger_top/channel_acq_controller_async/acq_dones_latched[2]} {trigger_top/channel_acq_controller_async/acq_dones_latched[3]} {trigger_top/channel_acq_controller_async/acq_dones_latched[4]}]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {ptr_state[0]} {ptr_state[1]} {ptr_state[2]} {ptr_state[3]}]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {caca_state[0]} {caca_state[1]} {caca_state[2]} {caca_state[3]}]]
create_debug_port u_ila_1 probe
set_property port_width 4 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {ttr_state[0]} {ttr_state[1]} {ttr_state[2]} {ttr_state[3]}]]
create_debug_port u_ila_1 probe
set_property port_width 5 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {trigger_top/chan_dones_clk40[0]} {trigger_top/chan_dones_clk40[1]} {trigger_top/chan_dones_clk40[2]} {trigger_top/chan_dones_clk40[3]} {trigger_top/chan_dones_clk40[4]}]]
create_debug_port u_ila_1 probe
set_property port_width 5 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {trigger_top/chan_dones[0]} {trigger_top/chan_dones[1]} {trigger_top/chan_dones[2]} {trigger_top/chan_dones[3]} {trigger_top/chan_dones[4]}]]
create_debug_port u_ila_1 probe
set_property port_width 22 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {trigger_top/readout_size_clk40[0]} {trigger_top/readout_size_clk40[1]} {trigger_top/readout_size_clk40[2]} {trigger_top/readout_size_clk40[3]} {trigger_top/readout_size_clk40[4]} {trigger_top/readout_size_clk40[5]} {trigger_top/readout_size_clk40[6]} {trigger_top/readout_size_clk40[7]} {trigger_top/readout_size_clk40[8]} {trigger_top/readout_size_clk40[9]} {trigger_top/readout_size_clk40[10]} {trigger_top/readout_size_clk40[11]} {trigger_top/readout_size_clk40[12]} {trigger_top/readout_size_clk40[13]} {trigger_top/readout_size_clk40[14]} {trigger_top/readout_size_clk40[15]} {trigger_top/readout_size_clk40[16]} {trigger_top/readout_size_clk40[17]} {trigger_top/readout_size_clk40[18]} {trigger_top/readout_size_clk40[19]} {trigger_top/readout_size_clk40[20]} {trigger_top/readout_size_clk40[21]}]]
create_debug_port u_ila_1 probe
set_property port_width 5 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {trigger_top/chan_en_clk40[0]} {trigger_top/chan_en_clk40[1]} {trigger_top/chan_en_clk40[2]} {trigger_top/chan_en_clk40[3]} {trigger_top/chan_en_clk40[4]}]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list ext_trig_sync]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list trigger_top/channel_acq_controller_async/n_0_0]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list trigger_top/pulse_trigger]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list trigger_top/readout_done_clk40]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list trigger_top/s_pulse_fifo_tready]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list trigger_top/s_pulse_fifo_tvalid]]
create_debug_port u_ila_1 probe
set_property port_width 1 [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list trigger_top/ttc_trigger]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk125]
