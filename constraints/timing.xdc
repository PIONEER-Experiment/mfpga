# system clock
create_clock -period 20.000 -name clk50 -waveform {0.000 10.000} [get_ports clkin]

# GTX clock for GigE
create_clock -period 8.000 -name gige_clk [get_ports gtx_clk0]

# TTC clock
create_clock -period 25.000 -name ttc_clk [get_ports ttc_clkp]

# DAQ_Link_7S ReadMe said to include this line
create_clock -period 4.000 -name DAQ_usrclk [get_pins daq/i_UsrClk/O]

# Aurora USER_CLK Constraint : Value is selected based on the line rate (5.0 Gbps) and lane width (4-Byte)
create_clock -period 8.000 -name user_clk_chan0 [get_pins channels/chan0/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan1 [get_pins channels/chan1/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan2 [get_pins channels/chan2/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan3 [get_pins channels/chan3/clock_module/user_clk_buf_i/O]
create_clock -period 8.000 -name user_clk_chan4 [get_pins channels/chan4/clock_module/user_clk_buf_i/O]

# statements to deal with inter-clock timing problems
#     These all have to do with taking ipbus signals (in the 125 MHz clock domain) and transfering them to
#     the slower 50 MHz clock domain. We have ensured that these signals change slowly enough that this
#     won't be a problem (there's no chance of missing a sharp pulse), and that it doesn't matter exactly
#     when the signals arrive.
set_false_path -from [get_cells reset_stretch/signal_out_reg*] -to [get_cells clk50_reset_sync/sync1_reg*]
set_false_path -from [get_cells ipb/slaves/slave7/flash_cmd_strobe_reg*] -to [get_cells spi_flash_intf/flash_cmd_sync/sync1_reg*]
set_false_path -from [get_cells ipb/slaves/slave7/flash_wr_nBytes_reg*] -to [get_cells spi_flash_intf/flash_wr_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave7/flash_rd_nBytes_reg*] -to [get_cells spi_flash_intf/flash_rd_nBytes_sync_reg*]
set_false_path -from [get_cells ipb/slaves/slave1/reg_reg*] -to [get_cells prog_chan_start_sync/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][13]*}] -to [get_cells reprog_trigger_sync1/sync1_reg*]
set_false_path -from [get_cells {ipb/slaves/slave1/reg_reg[0][12]*}] -to [get_cells reprog_trigger_sync0/sync1_reg*]

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
set_property port_width 27 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {command_manager/state[1]} {command_manager/state[2]} {command_manager/state[3]} {command_manager/state[4]} {command_manager/state[5]} {command_manager/state[6]} {command_manager/state[7]} {command_manager/state[8]} {command_manager/state[9]} {command_manager/state[10]} {command_manager/state[11]} {command_manager/state[12]} {command_manager/state[13]} {command_manager/state[14]} {command_manager/state[15]} {command_manager/state[16]} {command_manager/state[17]} {command_manager/state[18]} {command_manager/state[19]} {command_manager/state[20]} {command_manager/state[21]} {command_manager/state[22]} {command_manager/state[23]} {command_manager/state[24]} {command_manager/state[25]} {command_manager/state[26]} {command_manager/state[27]}]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {trigger_top/channel_acq_controller/state[0]} {trigger_top/channel_acq_controller/state[1]} {trigger_top/channel_acq_controller/state[2]} {trigger_top/channel_acq_controller/state[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {trigger_top/channel_acq_controller/trig_type[0]} {trigger_top/channel_acq_controller/trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {trigger_top/trigger_processor/ttc_trig_type[0]} {trigger_top/trigger_processor/ttc_trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {trigger_top/channel_acq_controller/acq_trig[0]} {trigger_top/channel_acq_controller/acq_trig[1]} {trigger_top/channel_acq_controller/acq_trig[2]} {trigger_top/channel_acq_controller/acq_trig[3]} {trigger_top/channel_acq_controller/acq_trig[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {trigger_top/channel_acq_controller/trig_delay[0]} {trigger_top/channel_acq_controller/trig_delay[1]} {trigger_top/channel_acq_controller/trig_delay[2]} {trigger_top/channel_acq_controller/trig_delay[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {trigger_top/channel_acq_controller/acq_done[0]} {trigger_top/channel_acq_controller/acq_done[1]} {trigger_top/channel_acq_controller/acq_done[2]} {trigger_top/channel_acq_controller/acq_done[3]} {trigger_top/channel_acq_controller/acq_done[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 44 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {trigger_top/trigger_processor/ttc_trig_timestamp[0]} {trigger_top/trigger_processor/ttc_trig_timestamp[1]} {trigger_top/trigger_processor/ttc_trig_timestamp[2]} {trigger_top/trigger_processor/ttc_trig_timestamp[3]} {trigger_top/trigger_processor/ttc_trig_timestamp[4]} {trigger_top/trigger_processor/ttc_trig_timestamp[5]} {trigger_top/trigger_processor/ttc_trig_timestamp[6]} {trigger_top/trigger_processor/ttc_trig_timestamp[7]} {trigger_top/trigger_processor/ttc_trig_timestamp[8]} {trigger_top/trigger_processor/ttc_trig_timestamp[9]} {trigger_top/trigger_processor/ttc_trig_timestamp[10]} {trigger_top/trigger_processor/ttc_trig_timestamp[11]} {trigger_top/trigger_processor/ttc_trig_timestamp[12]} {trigger_top/trigger_processor/ttc_trig_timestamp[13]} {trigger_top/trigger_processor/ttc_trig_timestamp[14]} {trigger_top/trigger_processor/ttc_trig_timestamp[15]} {trigger_top/trigger_processor/ttc_trig_timestamp[16]} {trigger_top/trigger_processor/ttc_trig_timestamp[17]} {trigger_top/trigger_processor/ttc_trig_timestamp[18]} {trigger_top/trigger_processor/ttc_trig_timestamp[19]} {trigger_top/trigger_processor/ttc_trig_timestamp[20]} {trigger_top/trigger_processor/ttc_trig_timestamp[21]} {trigger_top/trigger_processor/ttc_trig_timestamp[22]} {trigger_top/trigger_processor/ttc_trig_timestamp[23]} {trigger_top/trigger_processor/ttc_trig_timestamp[24]} {trigger_top/trigger_processor/ttc_trig_timestamp[25]} {trigger_top/trigger_processor/ttc_trig_timestamp[26]} {trigger_top/trigger_processor/ttc_trig_timestamp[27]} {trigger_top/trigger_processor/ttc_trig_timestamp[28]} {trigger_top/trigger_processor/ttc_trig_timestamp[29]} {trigger_top/trigger_processor/ttc_trig_timestamp[30]} {trigger_top/trigger_processor/ttc_trig_timestamp[31]} {trigger_top/trigger_processor/ttc_trig_timestamp[32]} {trigger_top/trigger_processor/ttc_trig_timestamp[33]} {trigger_top/trigger_processor/ttc_trig_timestamp[34]} {trigger_top/trigger_processor/ttc_trig_timestamp[35]} {trigger_top/trigger_processor/ttc_trig_timestamp[36]} {trigger_top/trigger_processor/ttc_trig_timestamp[37]} {trigger_top/trigger_processor/ttc_trig_timestamp[38]} {trigger_top/trigger_processor/ttc_trig_timestamp[39]} {trigger_top/trigger_processor/ttc_trig_timestamp[40]} {trigger_top/trigger_processor/ttc_trig_timestamp[41]} {trigger_top/trigger_processor/ttc_trig_timestamp[42]} {trigger_top/trigger_processor/ttc_trig_timestamp[43]}]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {trigger_top/channel_acq_controller/fifo_data[0]} {trigger_top/channel_acq_controller/fifo_data[1]} {trigger_top/channel_acq_controller/fifo_data[2]} {trigger_top/channel_acq_controller/fifo_data[3]} {trigger_top/channel_acq_controller/fifo_data[4]} {trigger_top/channel_acq_controller/fifo_data[5]} {trigger_top/channel_acq_controller/fifo_data[6]} {trigger_top/channel_acq_controller/fifo_data[7]} {trigger_top/channel_acq_controller/fifo_data[8]} {trigger_top/channel_acq_controller/fifo_data[9]} {trigger_top/channel_acq_controller/fifo_data[10]} {trigger_top/channel_acq_controller/fifo_data[11]} {trigger_top/channel_acq_controller/fifo_data[12]} {trigger_top/channel_acq_controller/fifo_data[13]} {trigger_top/channel_acq_controller/fifo_data[14]} {trigger_top/channel_acq_controller/fifo_data[15]} {trigger_top/channel_acq_controller/fifo_data[16]} {trigger_top/channel_acq_controller/fifo_data[17]} {trigger_top/channel_acq_controller/fifo_data[18]} {trigger_top/channel_acq_controller/fifo_data[19]} {trigger_top/channel_acq_controller/fifo_data[20]} {trigger_top/channel_acq_controller/fifo_data[21]} {trigger_top/channel_acq_controller/fifo_data[22]} {trigger_top/channel_acq_controller/fifo_data[23]} {trigger_top/channel_acq_controller/fifo_data[24]} {trigger_top/channel_acq_controller/fifo_data[25]} {trigger_top/channel_acq_controller/fifo_data[26]} {trigger_top/channel_acq_controller/fifo_data[27]} {trigger_top/channel_acq_controller/fifo_data[28]} {trigger_top/channel_acq_controller/fifo_data[29]} {trigger_top/channel_acq_controller/fifo_data[30]} {trigger_top/channel_acq_controller/fifo_data[31]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {trigger_top/channel_acq_controller/trig_num[0]} {trigger_top/channel_acq_controller/trig_num[1]} {trigger_top/channel_acq_controller/trig_num[2]} {trigger_top/channel_acq_controller/trig_num[3]} {trigger_top/channel_acq_controller/trig_num[4]} {trigger_top/channel_acq_controller/trig_num[5]} {trigger_top/channel_acq_controller/trig_num[6]} {trigger_top/channel_acq_controller/trig_num[7]} {trigger_top/channel_acq_controller/trig_num[8]} {trigger_top/channel_acq_controller/trig_num[9]} {trigger_top/channel_acq_controller/trig_num[10]} {trigger_top/channel_acq_controller/trig_num[11]} {trigger_top/channel_acq_controller/trig_num[12]} {trigger_top/channel_acq_controller/trig_num[13]} {trigger_top/channel_acq_controller/trig_num[14]} {trigger_top/channel_acq_controller/trig_num[15]} {trigger_top/channel_acq_controller/trig_num[16]} {trigger_top/channel_acq_controller/trig_num[17]} {trigger_top/channel_acq_controller/trig_num[18]} {trigger_top/channel_acq_controller/trig_num[19]} {trigger_top/channel_acq_controller/trig_num[20]} {trigger_top/channel_acq_controller/trig_num[21]} {trigger_top/channel_acq_controller/trig_num[22]} {trigger_top/channel_acq_controller/trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {trigger_top/channel_acq_controller/delay_cnt[0]} {trigger_top/channel_acq_controller/delay_cnt[1]} {trigger_top/channel_acq_controller/delay_cnt[2]} {trigger_top/channel_acq_controller/delay_cnt[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 128 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {trigger_top/trigger_processor/trig_fifo_data[0]} {trigger_top/trigger_processor/trig_fifo_data[1]} {trigger_top/trigger_processor/trig_fifo_data[2]} {trigger_top/trigger_processor/trig_fifo_data[3]} {trigger_top/trigger_processor/trig_fifo_data[4]} {trigger_top/trigger_processor/trig_fifo_data[5]} {trigger_top/trigger_processor/trig_fifo_data[6]} {trigger_top/trigger_processor/trig_fifo_data[7]} {trigger_top/trigger_processor/trig_fifo_data[8]} {trigger_top/trigger_processor/trig_fifo_data[9]} {trigger_top/trigger_processor/trig_fifo_data[10]} {trigger_top/trigger_processor/trig_fifo_data[11]} {trigger_top/trigger_processor/trig_fifo_data[12]} {trigger_top/trigger_processor/trig_fifo_data[13]} {trigger_top/trigger_processor/trig_fifo_data[14]} {trigger_top/trigger_processor/trig_fifo_data[15]} {trigger_top/trigger_processor/trig_fifo_data[16]} {trigger_top/trigger_processor/trig_fifo_data[17]} {trigger_top/trigger_processor/trig_fifo_data[18]} {trigger_top/trigger_processor/trig_fifo_data[19]} {trigger_top/trigger_processor/trig_fifo_data[20]} {trigger_top/trigger_processor/trig_fifo_data[21]} {trigger_top/trigger_processor/trig_fifo_data[22]} {trigger_top/trigger_processor/trig_fifo_data[23]} {trigger_top/trigger_processor/trig_fifo_data[24]} {trigger_top/trigger_processor/trig_fifo_data[25]} {trigger_top/trigger_processor/trig_fifo_data[26]} {trigger_top/trigger_processor/trig_fifo_data[27]} {trigger_top/trigger_processor/trig_fifo_data[28]} {trigger_top/trigger_processor/trig_fifo_data[29]} {trigger_top/trigger_processor/trig_fifo_data[30]} {trigger_top/trigger_processor/trig_fifo_data[31]} {trigger_top/trigger_processor/trig_fifo_data[32]} {trigger_top/trigger_processor/trig_fifo_data[33]} {trigger_top/trigger_processor/trig_fifo_data[34]} {trigger_top/trigger_processor/trig_fifo_data[35]} {trigger_top/trigger_processor/trig_fifo_data[36]} {trigger_top/trigger_processor/trig_fifo_data[37]} {trigger_top/trigger_processor/trig_fifo_data[38]} {trigger_top/trigger_processor/trig_fifo_data[39]} {trigger_top/trigger_processor/trig_fifo_data[40]} {trigger_top/trigger_processor/trig_fifo_data[41]} {trigger_top/trigger_processor/trig_fifo_data[42]} {trigger_top/trigger_processor/trig_fifo_data[43]} {trigger_top/trigger_processor/trig_fifo_data[44]} {trigger_top/trigger_processor/trig_fifo_data[45]} {trigger_top/trigger_processor/trig_fifo_data[46]} {trigger_top/trigger_processor/trig_fifo_data[47]} {trigger_top/trigger_processor/trig_fifo_data[48]} {trigger_top/trigger_processor/trig_fifo_data[49]} {trigger_top/trigger_processor/trig_fifo_data[50]} {trigger_top/trigger_processor/trig_fifo_data[51]} {trigger_top/trigger_processor/trig_fifo_data[52]} {trigger_top/trigger_processor/trig_fifo_data[53]} {trigger_top/trigger_processor/trig_fifo_data[54]} {trigger_top/trigger_processor/trig_fifo_data[55]} {trigger_top/trigger_processor/trig_fifo_data[56]} {trigger_top/trigger_processor/trig_fifo_data[57]} {trigger_top/trigger_processor/trig_fifo_data[58]} {trigger_top/trigger_processor/trig_fifo_data[59]} {trigger_top/trigger_processor/trig_fifo_data[60]} {trigger_top/trigger_processor/trig_fifo_data[61]} {trigger_top/trigger_processor/trig_fifo_data[62]} {trigger_top/trigger_processor/trig_fifo_data[63]} {trigger_top/trigger_processor/trig_fifo_data[64]} {trigger_top/trigger_processor/trig_fifo_data[65]} {trigger_top/trigger_processor/trig_fifo_data[66]} {trigger_top/trigger_processor/trig_fifo_data[67]} {trigger_top/trigger_processor/trig_fifo_data[68]} {trigger_top/trigger_processor/trig_fifo_data[69]} {trigger_top/trigger_processor/trig_fifo_data[70]} {trigger_top/trigger_processor/trig_fifo_data[71]} {trigger_top/trigger_processor/trig_fifo_data[72]} {trigger_top/trigger_processor/trig_fifo_data[73]} {trigger_top/trigger_processor/trig_fifo_data[74]} {trigger_top/trigger_processor/trig_fifo_data[75]} {trigger_top/trigger_processor/trig_fifo_data[76]} {trigger_top/trigger_processor/trig_fifo_data[77]} {trigger_top/trigger_processor/trig_fifo_data[78]} {trigger_top/trigger_processor/trig_fifo_data[79]} {trigger_top/trigger_processor/trig_fifo_data[80]} {trigger_top/trigger_processor/trig_fifo_data[81]} {trigger_top/trigger_processor/trig_fifo_data[82]} {trigger_top/trigger_processor/trig_fifo_data[83]} {trigger_top/trigger_processor/trig_fifo_data[84]} {trigger_top/trigger_processor/trig_fifo_data[85]} {trigger_top/trigger_processor/trig_fifo_data[86]} {trigger_top/trigger_processor/trig_fifo_data[87]} {trigger_top/trigger_processor/trig_fifo_data[88]} {trigger_top/trigger_processor/trig_fifo_data[89]} {trigger_top/trigger_processor/trig_fifo_data[90]} {trigger_top/trigger_processor/trig_fifo_data[91]} {trigger_top/trigger_processor/trig_fifo_data[92]} {trigger_top/trigger_processor/trig_fifo_data[93]} {trigger_top/trigger_processor/trig_fifo_data[94]} {trigger_top/trigger_processor/trig_fifo_data[95]} {trigger_top/trigger_processor/trig_fifo_data[96]} {trigger_top/trigger_processor/trig_fifo_data[97]} {trigger_top/trigger_processor/trig_fifo_data[98]} {trigger_top/trigger_processor/trig_fifo_data[99]} {trigger_top/trigger_processor/trig_fifo_data[100]} {trigger_top/trigger_processor/trig_fifo_data[101]} {trigger_top/trigger_processor/trig_fifo_data[102]} {trigger_top/trigger_processor/trig_fifo_data[103]} {trigger_top/trigger_processor/trig_fifo_data[104]} {trigger_top/trigger_processor/trig_fifo_data[105]} {trigger_top/trigger_processor/trig_fifo_data[106]} {trigger_top/trigger_processor/trig_fifo_data[107]} {trigger_top/trigger_processor/trig_fifo_data[108]} {trigger_top/trigger_processor/trig_fifo_data[109]} {trigger_top/trigger_processor/trig_fifo_data[110]} {trigger_top/trigger_processor/trig_fifo_data[111]} {trigger_top/trigger_processor/trig_fifo_data[112]} {trigger_top/trigger_processor/trig_fifo_data[113]} {trigger_top/trigger_processor/trig_fifo_data[114]} {trigger_top/trigger_processor/trig_fifo_data[115]} {trigger_top/trigger_processor/trig_fifo_data[116]} {trigger_top/trigger_processor/trig_fifo_data[117]} {trigger_top/trigger_processor/trig_fifo_data[118]} {trigger_top/trigger_processor/trig_fifo_data[119]} {trigger_top/trigger_processor/trig_fifo_data[120]} {trigger_top/trigger_processor/trig_fifo_data[121]} {trigger_top/trigger_processor/trig_fifo_data[122]} {trigger_top/trigger_processor/trig_fifo_data[123]} {trigger_top/trigger_processor/trig_fifo_data[124]} {trigger_top/trigger_processor/trig_fifo_data[125]} {trigger_top/trigger_processor/trig_fifo_data[126]} {trigger_top/trigger_processor/trig_fifo_data[127]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {trigger_top/channel_acq_controller/acq_trig_type[0]} {trigger_top/channel_acq_controller/acq_trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {trigger_top/trigger_processor/ttc_trig_num[0]} {trigger_top/trigger_processor/ttc_trig_num[1]} {trigger_top/trigger_processor/ttc_trig_num[2]} {trigger_top/trigger_processor/ttc_trig_num[3]} {trigger_top/trigger_processor/ttc_trig_num[4]} {trigger_top/trigger_processor/ttc_trig_num[5]} {trigger_top/trigger_processor/ttc_trig_num[6]} {trigger_top/trigger_processor/ttc_trig_num[7]} {trigger_top/trigger_processor/ttc_trig_num[8]} {trigger_top/trigger_processor/ttc_trig_num[9]} {trigger_top/trigger_processor/ttc_trig_num[10]} {trigger_top/trigger_processor/ttc_trig_num[11]} {trigger_top/trigger_processor/ttc_trig_num[12]} {trigger_top/trigger_processor/ttc_trig_num[13]} {trigger_top/trigger_processor/ttc_trig_num[14]} {trigger_top/trigger_processor/ttc_trig_num[15]} {trigger_top/trigger_processor/ttc_trig_num[16]} {trigger_top/trigger_processor/ttc_trig_num[17]} {trigger_top/trigger_processor/ttc_trig_num[18]} {trigger_top/trigger_processor/ttc_trig_num[19]} {trigger_top/trigger_processor/ttc_trig_num[20]} {trigger_top/trigger_processor/ttc_trig_num[21]} {trigger_top/trigger_processor/ttc_trig_num[22]} {trigger_top/trigger_processor/ttc_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {trigger_top/channel_acq_controller/acq_trig_num[0]} {trigger_top/channel_acq_controller/acq_trig_num[1]} {trigger_top/channel_acq_controller/acq_trig_num[2]} {trigger_top/channel_acq_controller/acq_trig_num[3]} {trigger_top/channel_acq_controller/acq_trig_num[4]} {trigger_top/channel_acq_controller/acq_trig_num[5]} {trigger_top/channel_acq_controller/acq_trig_num[6]} {trigger_top/channel_acq_controller/acq_trig_num[7]} {trigger_top/channel_acq_controller/acq_trig_num[8]} {trigger_top/channel_acq_controller/acq_trig_num[9]} {trigger_top/channel_acq_controller/acq_trig_num[10]} {trigger_top/channel_acq_controller/acq_trig_num[11]} {trigger_top/channel_acq_controller/acq_trig_num[12]} {trigger_top/channel_acq_controller/acq_trig_num[13]} {trigger_top/channel_acq_controller/acq_trig_num[14]} {trigger_top/channel_acq_controller/acq_trig_num[15]} {trigger_top/channel_acq_controller/acq_trig_num[16]} {trigger_top/channel_acq_controller/acq_trig_num[17]} {trigger_top/channel_acq_controller/acq_trig_num[18]} {trigger_top/channel_acq_controller/acq_trig_num[19]} {trigger_top/channel_acq_controller/acq_trig_num[20]} {trigger_top/channel_acq_controller/acq_trig_num[21]} {trigger_top/channel_acq_controller/acq_trig_num[22]} {trigger_top/channel_acq_controller/acq_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {trigger_top/channel_acq_controller/acq_enable[0]} {trigger_top/channel_acq_controller/acq_enable[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {trigger_top/channel_acq_controller/nextstate[0]} {trigger_top/channel_acq_controller/nextstate[1]} {trigger_top/channel_acq_controller/nextstate[2]} {trigger_top/channel_acq_controller/nextstate[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {trigger_top/channel_acq_controller/chan_en[0]} {trigger_top/channel_acq_controller/chan_en[1]} {trigger_top/channel_acq_controller/chan_en[2]} {trigger_top/channel_acq_controller/chan_en[3]} {trigger_top/channel_acq_controller/chan_en[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {trigger_top/trigger_processor/nextstate[0]} {trigger_top/trigger_processor/nextstate[1]} {trigger_top/trigger_processor/nextstate[2]} {trigger_top/trigger_processor/nextstate[3]} {trigger_top/trigger_processor/nextstate[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 5 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {trigger_top/trigger_processor/state[0]} {trigger_top/trigger_processor/state[1]} {trigger_top/trigger_processor/state[2]} {trigger_top/trigger_processor/state[3]} {trigger_top/trigger_processor/state[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {trigger_top/trigger_processor/acq_trig_num[0]} {trigger_top/trigger_processor/acq_trig_num[1]} {trigger_top/trigger_processor/acq_trig_num[2]} {trigger_top/trigger_processor/acq_trig_num[3]} {trigger_top/trigger_processor/acq_trig_num[4]} {trigger_top/trigger_processor/acq_trig_num[5]} {trigger_top/trigger_processor/acq_trig_num[6]} {trigger_top/trigger_processor/acq_trig_num[7]} {trigger_top/trigger_processor/acq_trig_num[8]} {trigger_top/trigger_processor/acq_trig_num[9]} {trigger_top/trigger_processor/acq_trig_num[10]} {trigger_top/trigger_processor/acq_trig_num[11]} {trigger_top/trigger_processor/acq_trig_num[12]} {trigger_top/trigger_processor/acq_trig_num[13]} {trigger_top/trigger_processor/acq_trig_num[14]} {trigger_top/trigger_processor/acq_trig_num[15]} {trigger_top/trigger_processor/acq_trig_num[16]} {trigger_top/trigger_processor/acq_trig_num[17]} {trigger_top/trigger_processor/acq_trig_num[18]} {trigger_top/trigger_processor/acq_trig_num[19]} {trigger_top/trigger_processor/acq_trig_num[20]} {trigger_top/trigger_processor/acq_trig_num[21]} {trigger_top/trigger_processor/acq_trig_num[22]} {trigger_top/trigger_processor/acq_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {trigger_top/trigger_processor/acq_fifo_data[0]} {trigger_top/trigger_processor/acq_fifo_data[1]} {trigger_top/trigger_processor/acq_fifo_data[2]} {trigger_top/trigger_processor/acq_fifo_data[3]} {trigger_top/trigger_processor/acq_fifo_data[4]} {trigger_top/trigger_processor/acq_fifo_data[5]} {trigger_top/trigger_processor/acq_fifo_data[6]} {trigger_top/trigger_processor/acq_fifo_data[7]} {trigger_top/trigger_processor/acq_fifo_data[8]} {trigger_top/trigger_processor/acq_fifo_data[9]} {trigger_top/trigger_processor/acq_fifo_data[10]} {trigger_top/trigger_processor/acq_fifo_data[11]} {trigger_top/trigger_processor/acq_fifo_data[12]} {trigger_top/trigger_processor/acq_fifo_data[13]} {trigger_top/trigger_processor/acq_fifo_data[14]} {trigger_top/trigger_processor/acq_fifo_data[15]} {trigger_top/trigger_processor/acq_fifo_data[16]} {trigger_top/trigger_processor/acq_fifo_data[17]} {trigger_top/trigger_processor/acq_fifo_data[18]} {trigger_top/trigger_processor/acq_fifo_data[19]} {trigger_top/trigger_processor/acq_fifo_data[20]} {trigger_top/trigger_processor/acq_fifo_data[21]} {trigger_top/trigger_processor/acq_fifo_data[22]} {trigger_top/trigger_processor/acq_fifo_data[23]} {trigger_top/trigger_processor/acq_fifo_data[24]} {trigger_top/trigger_processor/acq_fifo_data[25]} {trigger_top/trigger_processor/acq_fifo_data[26]} {trigger_top/trigger_processor/acq_fifo_data[27]} {trigger_top/trigger_processor/acq_fifo_data[28]} {trigger_top/trigger_processor/acq_fifo_data[29]} {trigger_top/trigger_processor/acq_fifo_data[30]} {trigger_top/trigger_processor/acq_fifo_data[31]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {trigger_top/trigger_processor/acq_trig_type[0]} {trigger_top/trigger_processor/acq_trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {trigger_top/ttc_trigger_receiver/nextstate[0]} {trigger_top/ttc_trigger_receiver/nextstate[1]} {trigger_top/ttc_trigger_receiver/nextstate[2]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {trigger_top/ttc_trigger_receiver/acq_trig_num[0]} {trigger_top/ttc_trigger_receiver/acq_trig_num[1]} {trigger_top/ttc_trigger_receiver/acq_trig_num[2]} {trigger_top/ttc_trigger_receiver/acq_trig_num[3]} {trigger_top/ttc_trigger_receiver/acq_trig_num[4]} {trigger_top/ttc_trigger_receiver/acq_trig_num[5]} {trigger_top/ttc_trigger_receiver/acq_trig_num[6]} {trigger_top/ttc_trigger_receiver/acq_trig_num[7]} {trigger_top/ttc_trigger_receiver/acq_trig_num[8]} {trigger_top/ttc_trigger_receiver/acq_trig_num[9]} {trigger_top/ttc_trigger_receiver/acq_trig_num[10]} {trigger_top/ttc_trigger_receiver/acq_trig_num[11]} {trigger_top/ttc_trigger_receiver/acq_trig_num[12]} {trigger_top/ttc_trigger_receiver/acq_trig_num[13]} {trigger_top/ttc_trigger_receiver/acq_trig_num[14]} {trigger_top/ttc_trigger_receiver/acq_trig_num[15]} {trigger_top/ttc_trigger_receiver/acq_trig_num[16]} {trigger_top/ttc_trigger_receiver/acq_trig_num[17]} {trigger_top/ttc_trigger_receiver/acq_trig_num[18]} {trigger_top/ttc_trigger_receiver/acq_trig_num[19]} {trigger_top/ttc_trigger_receiver/acq_trig_num[20]} {trigger_top/ttc_trigger_receiver/acq_trig_num[21]} {trigger_top/ttc_trigger_receiver/acq_trig_num[22]} {trigger_top/ttc_trigger_receiver/acq_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 24 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {trigger_top/ttc_trigger_receiver/acq_event_cnt[0]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[1]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[2]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[3]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[4]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[5]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[6]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[7]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[8]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[9]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[10]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[11]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[12]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[13]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[14]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[15]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[16]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[17]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[18]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[19]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[20]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[21]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[22]} {trigger_top/ttc_trigger_receiver/acq_event_cnt[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {trigger_top/ttc_trigger_receiver/acq_trig_type[0]} {trigger_top/ttc_trigger_receiver/acq_trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 128 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {trigger_top/ttc_trigger_receiver/fifo_data[0]} {trigger_top/ttc_trigger_receiver/fifo_data[1]} {trigger_top/ttc_trigger_receiver/fifo_data[2]} {trigger_top/ttc_trigger_receiver/fifo_data[3]} {trigger_top/ttc_trigger_receiver/fifo_data[4]} {trigger_top/ttc_trigger_receiver/fifo_data[5]} {trigger_top/ttc_trigger_receiver/fifo_data[6]} {trigger_top/ttc_trigger_receiver/fifo_data[7]} {trigger_top/ttc_trigger_receiver/fifo_data[8]} {trigger_top/ttc_trigger_receiver/fifo_data[9]} {trigger_top/ttc_trigger_receiver/fifo_data[10]} {trigger_top/ttc_trigger_receiver/fifo_data[11]} {trigger_top/ttc_trigger_receiver/fifo_data[12]} {trigger_top/ttc_trigger_receiver/fifo_data[13]} {trigger_top/ttc_trigger_receiver/fifo_data[14]} {trigger_top/ttc_trigger_receiver/fifo_data[15]} {trigger_top/ttc_trigger_receiver/fifo_data[16]} {trigger_top/ttc_trigger_receiver/fifo_data[17]} {trigger_top/ttc_trigger_receiver/fifo_data[18]} {trigger_top/ttc_trigger_receiver/fifo_data[19]} {trigger_top/ttc_trigger_receiver/fifo_data[20]} {trigger_top/ttc_trigger_receiver/fifo_data[21]} {trigger_top/ttc_trigger_receiver/fifo_data[22]} {trigger_top/ttc_trigger_receiver/fifo_data[23]} {trigger_top/ttc_trigger_receiver/fifo_data[24]} {trigger_top/ttc_trigger_receiver/fifo_data[25]} {trigger_top/ttc_trigger_receiver/fifo_data[26]} {trigger_top/ttc_trigger_receiver/fifo_data[27]} {trigger_top/ttc_trigger_receiver/fifo_data[28]} {trigger_top/ttc_trigger_receiver/fifo_data[29]} {trigger_top/ttc_trigger_receiver/fifo_data[30]} {trigger_top/ttc_trigger_receiver/fifo_data[31]} {trigger_top/ttc_trigger_receiver/fifo_data[32]} {trigger_top/ttc_trigger_receiver/fifo_data[33]} {trigger_top/ttc_trigger_receiver/fifo_data[34]} {trigger_top/ttc_trigger_receiver/fifo_data[35]} {trigger_top/ttc_trigger_receiver/fifo_data[36]} {trigger_top/ttc_trigger_receiver/fifo_data[37]} {trigger_top/ttc_trigger_receiver/fifo_data[38]} {trigger_top/ttc_trigger_receiver/fifo_data[39]} {trigger_top/ttc_trigger_receiver/fifo_data[40]} {trigger_top/ttc_trigger_receiver/fifo_data[41]} {trigger_top/ttc_trigger_receiver/fifo_data[42]} {trigger_top/ttc_trigger_receiver/fifo_data[43]} {trigger_top/ttc_trigger_receiver/fifo_data[44]} {trigger_top/ttc_trigger_receiver/fifo_data[45]} {trigger_top/ttc_trigger_receiver/fifo_data[46]} {trigger_top/ttc_trigger_receiver/fifo_data[47]} {trigger_top/ttc_trigger_receiver/fifo_data[48]} {trigger_top/ttc_trigger_receiver/fifo_data[49]} {trigger_top/ttc_trigger_receiver/fifo_data[50]} {trigger_top/ttc_trigger_receiver/fifo_data[51]} {trigger_top/ttc_trigger_receiver/fifo_data[52]} {trigger_top/ttc_trigger_receiver/fifo_data[53]} {trigger_top/ttc_trigger_receiver/fifo_data[54]} {trigger_top/ttc_trigger_receiver/fifo_data[55]} {trigger_top/ttc_trigger_receiver/fifo_data[56]} {trigger_top/ttc_trigger_receiver/fifo_data[57]} {trigger_top/ttc_trigger_receiver/fifo_data[58]} {trigger_top/ttc_trigger_receiver/fifo_data[59]} {trigger_top/ttc_trigger_receiver/fifo_data[60]} {trigger_top/ttc_trigger_receiver/fifo_data[61]} {trigger_top/ttc_trigger_receiver/fifo_data[62]} {trigger_top/ttc_trigger_receiver/fifo_data[63]} {trigger_top/ttc_trigger_receiver/fifo_data[64]} {trigger_top/ttc_trigger_receiver/fifo_data[65]} {trigger_top/ttc_trigger_receiver/fifo_data[66]} {trigger_top/ttc_trigger_receiver/fifo_data[67]} {trigger_top/ttc_trigger_receiver/fifo_data[68]} {trigger_top/ttc_trigger_receiver/fifo_data[69]} {trigger_top/ttc_trigger_receiver/fifo_data[70]} {trigger_top/ttc_trigger_receiver/fifo_data[71]} {trigger_top/ttc_trigger_receiver/fifo_data[72]} {trigger_top/ttc_trigger_receiver/fifo_data[73]} {trigger_top/ttc_trigger_receiver/fifo_data[74]} {trigger_top/ttc_trigger_receiver/fifo_data[75]} {trigger_top/ttc_trigger_receiver/fifo_data[76]} {trigger_top/ttc_trigger_receiver/fifo_data[77]} {trigger_top/ttc_trigger_receiver/fifo_data[78]} {trigger_top/ttc_trigger_receiver/fifo_data[79]} {trigger_top/ttc_trigger_receiver/fifo_data[80]} {trigger_top/ttc_trigger_receiver/fifo_data[81]} {trigger_top/ttc_trigger_receiver/fifo_data[82]} {trigger_top/ttc_trigger_receiver/fifo_data[83]} {trigger_top/ttc_trigger_receiver/fifo_data[84]} {trigger_top/ttc_trigger_receiver/fifo_data[85]} {trigger_top/ttc_trigger_receiver/fifo_data[86]} {trigger_top/ttc_trigger_receiver/fifo_data[87]} {trigger_top/ttc_trigger_receiver/fifo_data[88]} {trigger_top/ttc_trigger_receiver/fifo_data[89]} {trigger_top/ttc_trigger_receiver/fifo_data[90]} {trigger_top/ttc_trigger_receiver/fifo_data[91]} {trigger_top/ttc_trigger_receiver/fifo_data[92]} {trigger_top/ttc_trigger_receiver/fifo_data[93]} {trigger_top/ttc_trigger_receiver/fifo_data[94]} {trigger_top/ttc_trigger_receiver/fifo_data[95]} {trigger_top/ttc_trigger_receiver/fifo_data[96]} {trigger_top/ttc_trigger_receiver/fifo_data[97]} {trigger_top/ttc_trigger_receiver/fifo_data[98]} {trigger_top/ttc_trigger_receiver/fifo_data[99]} {trigger_top/ttc_trigger_receiver/fifo_data[100]} {trigger_top/ttc_trigger_receiver/fifo_data[101]} {trigger_top/ttc_trigger_receiver/fifo_data[102]} {trigger_top/ttc_trigger_receiver/fifo_data[103]} {trigger_top/ttc_trigger_receiver/fifo_data[104]} {trigger_top/ttc_trigger_receiver/fifo_data[105]} {trigger_top/ttc_trigger_receiver/fifo_data[106]} {trigger_top/ttc_trigger_receiver/fifo_data[107]} {trigger_top/ttc_trigger_receiver/fifo_data[108]} {trigger_top/ttc_trigger_receiver/fifo_data[109]} {trigger_top/ttc_trigger_receiver/fifo_data[110]} {trigger_top/ttc_trigger_receiver/fifo_data[111]} {trigger_top/ttc_trigger_receiver/fifo_data[112]} {trigger_top/ttc_trigger_receiver/fifo_data[113]} {trigger_top/ttc_trigger_receiver/fifo_data[114]} {trigger_top/ttc_trigger_receiver/fifo_data[115]} {trigger_top/ttc_trigger_receiver/fifo_data[116]} {trigger_top/ttc_trigger_receiver/fifo_data[117]} {trigger_top/ttc_trigger_receiver/fifo_data[118]} {trigger_top/ttc_trigger_receiver/fifo_data[119]} {trigger_top/ttc_trigger_receiver/fifo_data[120]} {trigger_top/ttc_trigger_receiver/fifo_data[121]} {trigger_top/ttc_trigger_receiver/fifo_data[122]} {trigger_top/ttc_trigger_receiver/fifo_data[123]} {trigger_top/ttc_trigger_receiver/fifo_data[124]} {trigger_top/ttc_trigger_receiver/fifo_data[125]} {trigger_top/ttc_trigger_receiver/fifo_data[126]} {trigger_top/ttc_trigger_receiver/fifo_data[127]}]]
create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {trigger_top/ttc_trigger_receiver/state[0]} {trigger_top/ttc_trigger_receiver/state[1]} {trigger_top/ttc_trigger_receiver/state[2]}]]
create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {trigger_top/ttc_trigger_receiver/trig_type[0]} {trigger_top/ttc_trigger_receiver/trig_type[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 44 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[0]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[1]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[2]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[3]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[4]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[5]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[6]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[7]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[8]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[9]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[10]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[11]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[12]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[13]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[14]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[15]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[16]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[17]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[18]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[19]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[20]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[21]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[22]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[23]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[24]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[25]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[26]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[27]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[28]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[29]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[30]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[31]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[32]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[33]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[34]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[35]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[36]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[37]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[38]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[39]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[40]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[41]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[42]} {trigger_top/ttc_trigger_receiver/trig_timestamp_cnt[43]}]]
create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {trigger_top/ttc_trigger_receiver/trig_settings[0]} {trigger_top/ttc_trigger_receiver/trig_settings[1]} {trigger_top/ttc_trigger_receiver/trig_settings[2]} {trigger_top/ttc_trigger_receiver/trig_settings[3]} {trigger_top/ttc_trigger_receiver/trig_settings[4]} {trigger_top/ttc_trigger_receiver/trig_settings[5]} {trigger_top/ttc_trigger_receiver/trig_settings[6]} {trigger_top/ttc_trigger_receiver/trig_settings[7]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list trigger_top/acq_fifo_full]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list trigger_top/trigger_processor/acq_fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list trigger_top/trigger_processor/acq_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list trigger_top/ttc_trigger_receiver/acq_trigger]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list trigger_top/ttc_trigger_receiver/empty_event]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list trigger_top/ttc_trigger_receiver/fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list trigger_top/channel_acq_controller/fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list trigger_top/ttc_trigger_receiver/fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list trigger_top/channel_acq_controller/fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list trigger_top/trigger_processor/initiate_readout]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[0]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[1]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[2]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[3]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[4]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[5]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[6]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[7]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[8]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[9]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[10]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe53]
connect_debug_port u_ila_0/probe53 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[11]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe54]
connect_debug_port u_ila_0/probe54 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[12]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe55]
connect_debug_port u_ila_0/probe55 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[13]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe56]
connect_debug_port u_ila_0/probe56 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[14]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe57]
connect_debug_port u_ila_0/probe57 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[15]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe58]
connect_debug_port u_ila_0/probe58 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[16]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe59]
connect_debug_port u_ila_0/probe59 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[17]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe60]
connect_debug_port u_ila_0/probe60 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[18]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe61]
connect_debug_port u_ila_0/probe61 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[19]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe62]
connect_debug_port u_ila_0/probe62 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[20]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe63]
connect_debug_port u_ila_0/probe63 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[21]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe64]
connect_debug_port u_ila_0/probe64 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[22]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe65]
connect_debug_port u_ila_0/probe65 [get_nets [list {trigger_top/trigger_processor/n_0_ttc_event_num_reg[23]}]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe66]
connect_debug_port u_ila_0/probe66 [get_nets [list trigger_top/trigger_processor/readout_done]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe67]
connect_debug_port u_ila_0/probe67 [get_nets [list trigger_top/trigger_processor/readout_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe68]
connect_debug_port u_ila_0/probe68 [get_nets [list command_manager/readout_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe69]
connect_debug_port u_ila_0/probe69 [get_nets [list trigger_top/trig_fifo_full]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe70]
connect_debug_port u_ila_0/probe70 [get_nets [list trigger_top/trigger_processor/trig_fifo_ready]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe71]
connect_debug_port u_ila_0/probe71 [get_nets [list trigger_top/trigger_processor/trig_fifo_valid]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe72]
connect_debug_port u_ila_0/probe72 [get_nets [list trigger_top/ttc_trigger_receiver/trigger]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe73]
connect_debug_port u_ila_0/probe73 [get_nets [list trigger_top/channel_acq_controller/trigger]]
create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe74]
connect_debug_port u_ila_0/probe74 [get_nets [list trigger_top/trigger_processor/ttc_empty_event]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk125]
