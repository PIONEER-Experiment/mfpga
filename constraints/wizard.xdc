


create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list ttc/ttc_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {trigger_top/ttc_trigger_receiver/state[0]} {trigger_top/ttc_trigger_receiver/state[1]} {trigger_top/ttc_trigger_receiver/state[2]} {trigger_top/ttc_trigger_receiver/state[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {trigger_top/channel_acq_controller_async/fifo_data[0]} {trigger_top/channel_acq_controller_async/fifo_data[1]} {trigger_top/channel_acq_controller_async/fifo_data[2]} {trigger_top/channel_acq_controller_async/fifo_data[3]} {trigger_top/channel_acq_controller_async/fifo_data[4]} {trigger_top/channel_acq_controller_async/fifo_data[5]} {trigger_top/channel_acq_controller_async/fifo_data[6]} {trigger_top/channel_acq_controller_async/fifo_data[7]} {trigger_top/channel_acq_controller_async/fifo_data[8]} {trigger_top/channel_acq_controller_async/fifo_data[9]} {trigger_top/channel_acq_controller_async/fifo_data[10]} {trigger_top/channel_acq_controller_async/fifo_data[11]} {trigger_top/channel_acq_controller_async/fifo_data[12]} {trigger_top/channel_acq_controller_async/fifo_data[13]} {trigger_top/channel_acq_controller_async/fifo_data[14]} {trigger_top/channel_acq_controller_async/fifo_data[15]} {trigger_top/channel_acq_controller_async/fifo_data[16]} {trigger_top/channel_acq_controller_async/fifo_data[17]} {trigger_top/channel_acq_controller_async/fifo_data[18]} {trigger_top/channel_acq_controller_async/fifo_data[19]} {trigger_top/channel_acq_controller_async/fifo_data[20]} {trigger_top/channel_acq_controller_async/fifo_data[21]} {trigger_top/channel_acq_controller_async/fifo_data[22]} {trigger_top/channel_acq_controller_async/fifo_data[23]} {trigger_top/channel_acq_controller_async/fifo_data[24]} {trigger_top/channel_acq_controller_async/fifo_data[25]} {trigger_top/channel_acq_controller_async/fifo_data[26]} {trigger_top/channel_acq_controller_async/fifo_data[27]} {trigger_top/channel_acq_controller_async/fifo_data[28]} {trigger_top/channel_acq_controller_async/fifo_data[29]} {trigger_top/channel_acq_controller_async/fifo_data[30]} {trigger_top/channel_acq_controller_async/fifo_data[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {trigger_top/channel_acq_controller_async/state[0]} {trigger_top/channel_acq_controller_async/state[1]} {trigger_top/channel_acq_controller_async/state[2]} {trigger_top/channel_acq_controller_async/state[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 5 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {trigger_top/channel_acq_controller_async/acq_dones[0]} {trigger_top/channel_acq_controller_async/acq_dones[1]} {trigger_top/channel_acq_controller_async/acq_dones[2]} {trigger_top/channel_acq_controller_async/acq_dones[3]} {trigger_top/channel_acq_controller_async/acq_dones[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 10 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {trigger_top/channel_acq_controller_async/acq_enable[0]} {trigger_top/channel_acq_controller_async/acq_enable[1]} {trigger_top/channel_acq_controller_async/acq_enable[2]} {trigger_top/channel_acq_controller_async/acq_enable[3]} {trigger_top/channel_acq_controller_async/acq_enable[4]} {trigger_top/channel_acq_controller_async/acq_enable[5]} {trigger_top/channel_acq_controller_async/acq_enable[6]} {trigger_top/channel_acq_controller_async/acq_enable[7]} {trigger_top/channel_acq_controller_async/acq_enable[8]} {trigger_top/channel_acq_controller_async/acq_enable[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 5 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {trigger_top/channel_acq_controller_async/acq_trig[0]} {trigger_top/channel_acq_controller_async/acq_trig[1]} {trigger_top/channel_acq_controller_async/acq_trig[2]} {trigger_top/channel_acq_controller_async/acq_trig[3]} {trigger_top/channel_acq_controller_async/acq_trig[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 5 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {trigger_top/channel_acq_controller_async/acq_dones_latched[0]} {trigger_top/channel_acq_controller_async/acq_dones_latched[1]} {trigger_top/channel_acq_controller_async/acq_dones_latched[2]} {trigger_top/channel_acq_controller_async/acq_dones_latched[3]} {trigger_top/channel_acq_controller_async/acq_dones_latched[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 24 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {trigger_top/channel_acq_controller_async/acq_trig_num[0]} {trigger_top/channel_acq_controller_async/acq_trig_num[1]} {trigger_top/channel_acq_controller_async/acq_trig_num[2]} {trigger_top/channel_acq_controller_async/acq_trig_num[3]} {trigger_top/channel_acq_controller_async/acq_trig_num[4]} {trigger_top/channel_acq_controller_async/acq_trig_num[5]} {trigger_top/channel_acq_controller_async/acq_trig_num[6]} {trigger_top/channel_acq_controller_async/acq_trig_num[7]} {trigger_top/channel_acq_controller_async/acq_trig_num[8]} {trigger_top/channel_acq_controller_async/acq_trig_num[9]} {trigger_top/channel_acq_controller_async/acq_trig_num[10]} {trigger_top/channel_acq_controller_async/acq_trig_num[11]} {trigger_top/channel_acq_controller_async/acq_trig_num[12]} {trigger_top/channel_acq_controller_async/acq_trig_num[13]} {trigger_top/channel_acq_controller_async/acq_trig_num[14]} {trigger_top/channel_acq_controller_async/acq_trig_num[15]} {trigger_top/channel_acq_controller_async/acq_trig_num[16]} {trigger_top/channel_acq_controller_async/acq_trig_num[17]} {trigger_top/channel_acq_controller_async/acq_trig_num[18]} {trigger_top/channel_acq_controller_async/acq_trig_num[19]} {trigger_top/channel_acq_controller_async/acq_trig_num[20]} {trigger_top/channel_acq_controller_async/acq_trig_num[21]} {trigger_top/channel_acq_controller_async/acq_trig_num[22]} {trigger_top/channel_acq_controller_async/acq_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 5 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {acq_trigs_OBUF[0]} {acq_trigs_OBUF[1]} {acq_trigs_OBUF[2]} {acq_trigs_OBUF[3]} {acq_trigs_OBUF[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {trigger_top/s_acq_fifo_tdata[0]} {trigger_top/s_acq_fifo_tdata[1]} {trigger_top/s_acq_fifo_tdata[2]} {trigger_top/s_acq_fifo_tdata[3]} {trigger_top/s_acq_fifo_tdata[4]} {trigger_top/s_acq_fifo_tdata[5]} {trigger_top/s_acq_fifo_tdata[6]} {trigger_top/s_acq_fifo_tdata[7]} {trigger_top/s_acq_fifo_tdata[8]} {trigger_top/s_acq_fifo_tdata[9]} {trigger_top/s_acq_fifo_tdata[10]} {trigger_top/s_acq_fifo_tdata[11]} {trigger_top/s_acq_fifo_tdata[12]} {trigger_top/s_acq_fifo_tdata[13]} {trigger_top/s_acq_fifo_tdata[14]} {trigger_top/s_acq_fifo_tdata[15]} {trigger_top/s_acq_fifo_tdata[16]} {trigger_top/s_acq_fifo_tdata[17]} {trigger_top/s_acq_fifo_tdata[18]} {trigger_top/s_acq_fifo_tdata[19]} {trigger_top/s_acq_fifo_tdata[20]} {trigger_top/s_acq_fifo_tdata[21]} {trigger_top/s_acq_fifo_tdata[22]} {trigger_top/s_acq_fifo_tdata[23]} {trigger_top/s_acq_fifo_tdata[24]} {trigger_top/s_acq_fifo_tdata[25]} {trigger_top/s_acq_fifo_tdata[26]} {trigger_top/s_acq_fifo_tdata[27]} {trigger_top/s_acq_fifo_tdata[28]} {trigger_top/s_acq_fifo_tdata[29]} {trigger_top/s_acq_fifo_tdata[30]} {trigger_top/s_acq_fifo_tdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 10 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {acq_enable[0]} {acq_enable[1]} {acq_enable[2]} {acq_enable[3]} {acq_enable[4]} {acq_enable[5]} {acq_enable[6]} {acq_enable[7]} {acq_enable[8]} {acq_enable[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 5 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {acq_dones_IBUF[0]} {acq_dones_IBUF[1]} {acq_dones_IBUF[2]} {acq_dones_IBUF[3]} {acq_dones_IBUF[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list accept_pulse_triggers]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list trigger_top/ttc_trigger_receiver/accept_pulse_triggers]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list trigger_top/channel_acq_controller_async/accept_pulse_triggers]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list trigger_top/channel_acq_controller_async/accept_pulse_triggers_40]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list trigger_top/channel_acq_controller_async/async_mode]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list trigger_top/evt_cnt_rst]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list trigger_top/channel_acq_controller_async/fifo_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list trigger_top/fifo_reset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list trigger_top/fifo_reset_n]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list trigger_top/channel_acq_controller_async/fifo_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list trigger_top/pulse_trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list trigger_top/channel_acq_controller_async/readout_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list reset40]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list reset40_n]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list trigger_top/s_acq_fifo_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list trigger_top/s_acq_fifo_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list trigger_top/s_acq_fifo_tvalid_sync]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list trigger_top/ttc_trigger_receiver/trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list trigger_top/channel_acq_controller_async/ttc_trigger]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list clk125]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 128 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {trigger_top/trigger_processor/trig_fifo_data[0]} {trigger_top/trigger_processor/trig_fifo_data[1]} {trigger_top/trigger_processor/trig_fifo_data[2]} {trigger_top/trigger_processor/trig_fifo_data[3]} {trigger_top/trigger_processor/trig_fifo_data[4]} {trigger_top/trigger_processor/trig_fifo_data[5]} {trigger_top/trigger_processor/trig_fifo_data[6]} {trigger_top/trigger_processor/trig_fifo_data[7]} {trigger_top/trigger_processor/trig_fifo_data[8]} {trigger_top/trigger_processor/trig_fifo_data[9]} {trigger_top/trigger_processor/trig_fifo_data[10]} {trigger_top/trigger_processor/trig_fifo_data[11]} {trigger_top/trigger_processor/trig_fifo_data[12]} {trigger_top/trigger_processor/trig_fifo_data[13]} {trigger_top/trigger_processor/trig_fifo_data[14]} {trigger_top/trigger_processor/trig_fifo_data[15]} {trigger_top/trigger_processor/trig_fifo_data[16]} {trigger_top/trigger_processor/trig_fifo_data[17]} {trigger_top/trigger_processor/trig_fifo_data[18]} {trigger_top/trigger_processor/trig_fifo_data[19]} {trigger_top/trigger_processor/trig_fifo_data[20]} {trigger_top/trigger_processor/trig_fifo_data[21]} {trigger_top/trigger_processor/trig_fifo_data[22]} {trigger_top/trigger_processor/trig_fifo_data[23]} {trigger_top/trigger_processor/trig_fifo_data[24]} {trigger_top/trigger_processor/trig_fifo_data[25]} {trigger_top/trigger_processor/trig_fifo_data[26]} {trigger_top/trigger_processor/trig_fifo_data[27]} {trigger_top/trigger_processor/trig_fifo_data[28]} {trigger_top/trigger_processor/trig_fifo_data[29]} {trigger_top/trigger_processor/trig_fifo_data[30]} {trigger_top/trigger_processor/trig_fifo_data[31]} {trigger_top/trigger_processor/trig_fifo_data[32]} {trigger_top/trigger_processor/trig_fifo_data[33]} {trigger_top/trigger_processor/trig_fifo_data[34]} {trigger_top/trigger_processor/trig_fifo_data[35]} {trigger_top/trigger_processor/trig_fifo_data[36]} {trigger_top/trigger_processor/trig_fifo_data[37]} {trigger_top/trigger_processor/trig_fifo_data[38]} {trigger_top/trigger_processor/trig_fifo_data[39]} {trigger_top/trigger_processor/trig_fifo_data[40]} {trigger_top/trigger_processor/trig_fifo_data[41]} {trigger_top/trigger_processor/trig_fifo_data[42]} {trigger_top/trigger_processor/trig_fifo_data[43]} {trigger_top/trigger_processor/trig_fifo_data[44]} {trigger_top/trigger_processor/trig_fifo_data[45]} {trigger_top/trigger_processor/trig_fifo_data[46]} {trigger_top/trigger_processor/trig_fifo_data[47]} {trigger_top/trigger_processor/trig_fifo_data[48]} {trigger_top/trigger_processor/trig_fifo_data[49]} {trigger_top/trigger_processor/trig_fifo_data[50]} {trigger_top/trigger_processor/trig_fifo_data[51]} {trigger_top/trigger_processor/trig_fifo_data[52]} {trigger_top/trigger_processor/trig_fifo_data[53]} {trigger_top/trigger_processor/trig_fifo_data[54]} {trigger_top/trigger_processor/trig_fifo_data[55]} {trigger_top/trigger_processor/trig_fifo_data[56]} {trigger_top/trigger_processor/trig_fifo_data[57]} {trigger_top/trigger_processor/trig_fifo_data[58]} {trigger_top/trigger_processor/trig_fifo_data[59]} {trigger_top/trigger_processor/trig_fifo_data[60]} {trigger_top/trigger_processor/trig_fifo_data[61]} {trigger_top/trigger_processor/trig_fifo_data[62]} {trigger_top/trigger_processor/trig_fifo_data[63]} {trigger_top/trigger_processor/trig_fifo_data[64]} {trigger_top/trigger_processor/trig_fifo_data[65]} {trigger_top/trigger_processor/trig_fifo_data[66]} {trigger_top/trigger_processor/trig_fifo_data[67]} {trigger_top/trigger_processor/trig_fifo_data[68]} {trigger_top/trigger_processor/trig_fifo_data[69]} {trigger_top/trigger_processor/trig_fifo_data[70]} {trigger_top/trigger_processor/trig_fifo_data[71]} {trigger_top/trigger_processor/trig_fifo_data[72]} {trigger_top/trigger_processor/trig_fifo_data[73]} {trigger_top/trigger_processor/trig_fifo_data[74]} {trigger_top/trigger_processor/trig_fifo_data[75]} {trigger_top/trigger_processor/trig_fifo_data[76]} {trigger_top/trigger_processor/trig_fifo_data[77]} {trigger_top/trigger_processor/trig_fifo_data[78]} {trigger_top/trigger_processor/trig_fifo_data[79]} {trigger_top/trigger_processor/trig_fifo_data[80]} {trigger_top/trigger_processor/trig_fifo_data[81]} {trigger_top/trigger_processor/trig_fifo_data[82]} {trigger_top/trigger_processor/trig_fifo_data[83]} {trigger_top/trigger_processor/trig_fifo_data[84]} {trigger_top/trigger_processor/trig_fifo_data[85]} {trigger_top/trigger_processor/trig_fifo_data[86]} {trigger_top/trigger_processor/trig_fifo_data[87]} {trigger_top/trigger_processor/trig_fifo_data[88]} {trigger_top/trigger_processor/trig_fifo_data[89]} {trigger_top/trigger_processor/trig_fifo_data[90]} {trigger_top/trigger_processor/trig_fifo_data[91]} {trigger_top/trigger_processor/trig_fifo_data[92]} {trigger_top/trigger_processor/trig_fifo_data[93]} {trigger_top/trigger_processor/trig_fifo_data[94]} {trigger_top/trigger_processor/trig_fifo_data[95]} {trigger_top/trigger_processor/trig_fifo_data[96]} {trigger_top/trigger_processor/trig_fifo_data[97]} {trigger_top/trigger_processor/trig_fifo_data[98]} {trigger_top/trigger_processor/trig_fifo_data[99]} {trigger_top/trigger_processor/trig_fifo_data[100]} {trigger_top/trigger_processor/trig_fifo_data[101]} {trigger_top/trigger_processor/trig_fifo_data[102]} {trigger_top/trigger_processor/trig_fifo_data[103]} {trigger_top/trigger_processor/trig_fifo_data[104]} {trigger_top/trigger_processor/trig_fifo_data[105]} {trigger_top/trigger_processor/trig_fifo_data[106]} {trigger_top/trigger_processor/trig_fifo_data[107]} {trigger_top/trigger_processor/trig_fifo_data[108]} {trigger_top/trigger_processor/trig_fifo_data[109]} {trigger_top/trigger_processor/trig_fifo_data[110]} {trigger_top/trigger_processor/trig_fifo_data[111]} {trigger_top/trigger_processor/trig_fifo_data[112]} {trigger_top/trigger_processor/trig_fifo_data[113]} {trigger_top/trigger_processor/trig_fifo_data[114]} {trigger_top/trigger_processor/trig_fifo_data[115]} {trigger_top/trigger_processor/trig_fifo_data[116]} {trigger_top/trigger_processor/trig_fifo_data[117]} {trigger_top/trigger_processor/trig_fifo_data[118]} {trigger_top/trigger_processor/trig_fifo_data[119]} {trigger_top/trigger_processor/trig_fifo_data[120]} {trigger_top/trigger_processor/trig_fifo_data[121]} {trigger_top/trigger_processor/trig_fifo_data[122]} {trigger_top/trigger_processor/trig_fifo_data[123]} {trigger_top/trigger_processor/trig_fifo_data[124]} {trigger_top/trigger_processor/trig_fifo_data[125]} {trigger_top/trigger_processor/trig_fifo_data[126]} {trigger_top/trigger_processor/trig_fifo_data[127]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 5 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {trigger_top/trigger_processor/state[0]} {trigger_top/trigger_processor/state[1]} {trigger_top/trigger_processor/state[2]} {trigger_top/trigger_processor/state[3]} {trigger_top/trigger_processor/state[4]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 24 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {trigger_top/trigger_processor/ttc_trig_num[0]} {trigger_top/trigger_processor/ttc_trig_num[1]} {trigger_top/trigger_processor/ttc_trig_num[2]} {trigger_top/trigger_processor/ttc_trig_num[3]} {trigger_top/trigger_processor/ttc_trig_num[4]} {trigger_top/trigger_processor/ttc_trig_num[5]} {trigger_top/trigger_processor/ttc_trig_num[6]} {trigger_top/trigger_processor/ttc_trig_num[7]} {trigger_top/trigger_processor/ttc_trig_num[8]} {trigger_top/trigger_processor/ttc_trig_num[9]} {trigger_top/trigger_processor/ttc_trig_num[10]} {trigger_top/trigger_processor/ttc_trig_num[11]} {trigger_top/trigger_processor/ttc_trig_num[12]} {trigger_top/trigger_processor/ttc_trig_num[13]} {trigger_top/trigger_processor/ttc_trig_num[14]} {trigger_top/trigger_processor/ttc_trig_num[15]} {trigger_top/trigger_processor/ttc_trig_num[16]} {trigger_top/trigger_processor/ttc_trig_num[17]} {trigger_top/trigger_processor/ttc_trig_num[18]} {trigger_top/trigger_processor/ttc_trig_num[19]} {trigger_top/trigger_processor/ttc_trig_num[20]} {trigger_top/trigger_processor/ttc_trig_num[21]} {trigger_top/trigger_processor/ttc_trig_num[22]} {trigger_top/trigger_processor/ttc_trig_num[23]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 32 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {trigger_top/trigger_processor/acq_fifo_data[0]} {trigger_top/trigger_processor/acq_fifo_data[1]} {trigger_top/trigger_processor/acq_fifo_data[2]} {trigger_top/trigger_processor/acq_fifo_data[3]} {trigger_top/trigger_processor/acq_fifo_data[4]} {trigger_top/trigger_processor/acq_fifo_data[5]} {trigger_top/trigger_processor/acq_fifo_data[6]} {trigger_top/trigger_processor/acq_fifo_data[7]} {trigger_top/trigger_processor/acq_fifo_data[8]} {trigger_top/trigger_processor/acq_fifo_data[9]} {trigger_top/trigger_processor/acq_fifo_data[10]} {trigger_top/trigger_processor/acq_fifo_data[11]} {trigger_top/trigger_processor/acq_fifo_data[12]} {trigger_top/trigger_processor/acq_fifo_data[13]} {trigger_top/trigger_processor/acq_fifo_data[14]} {trigger_top/trigger_processor/acq_fifo_data[15]} {trigger_top/trigger_processor/acq_fifo_data[16]} {trigger_top/trigger_processor/acq_fifo_data[17]} {trigger_top/trigger_processor/acq_fifo_data[18]} {trigger_top/trigger_processor/acq_fifo_data[19]} {trigger_top/trigger_processor/acq_fifo_data[20]} {trigger_top/trigger_processor/acq_fifo_data[21]} {trigger_top/trigger_processor/acq_fifo_data[22]} {trigger_top/trigger_processor/acq_fifo_data[23]} {trigger_top/trigger_processor/acq_fifo_data[24]} {trigger_top/trigger_processor/acq_fifo_data[25]} {trigger_top/trigger_processor/acq_fifo_data[26]} {trigger_top/trigger_processor/acq_fifo_data[27]} {trigger_top/trigger_processor/acq_fifo_data[28]} {trigger_top/trigger_processor/acq_fifo_data[29]} {trigger_top/trigger_processor/acq_fifo_data[30]} {trigger_top/trigger_processor/acq_fifo_data[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 24 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {trigger_top/trigger_processor/acq_trig_num[0]} {trigger_top/trigger_processor/acq_trig_num[1]} {trigger_top/trigger_processor/acq_trig_num[2]} {trigger_top/trigger_processor/acq_trig_num[3]} {trigger_top/trigger_processor/acq_trig_num[4]} {trigger_top/trigger_processor/acq_trig_num[5]} {trigger_top/trigger_processor/acq_trig_num[6]} {trigger_top/trigger_processor/acq_trig_num[7]} {trigger_top/trigger_processor/acq_trig_num[8]} {trigger_top/trigger_processor/acq_trig_num[9]} {trigger_top/trigger_processor/acq_trig_num[10]} {trigger_top/trigger_processor/acq_trig_num[11]} {trigger_top/trigger_processor/acq_trig_num[12]} {trigger_top/trigger_processor/acq_trig_num[13]} {trigger_top/trigger_processor/acq_trig_num[14]} {trigger_top/trigger_processor/acq_trig_num[15]} {trigger_top/trigger_processor/acq_trig_num[16]} {trigger_top/trigger_processor/acq_trig_num[17]} {trigger_top/trigger_processor/acq_trig_num[18]} {trigger_top/trigger_processor/acq_trig_num[19]} {trigger_top/trigger_processor/acq_trig_num[20]} {trigger_top/trigger_processor/acq_trig_num[21]} {trigger_top/trigger_processor/acq_trig_num[22]} {trigger_top/trigger_processor/acq_trig_num[23]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 35 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {cm_state[0]} {cm_state[1]} {cm_state[2]} {cm_state[3]} {cm_state[4]} {cm_state[5]} {cm_state[6]} {cm_state[7]} {cm_state[8]} {cm_state[9]} {cm_state[10]} {cm_state[11]} {cm_state[12]} {cm_state[13]} {cm_state[14]} {cm_state[15]} {cm_state[16]} {cm_state[17]} {cm_state[18]} {cm_state[19]} {cm_state[20]} {cm_state[21]} {cm_state[22]} {cm_state[23]} {cm_state[24]} {cm_state[25]} {cm_state[26]} {cm_state[27]} {cm_state[28]} {cm_state[29]} {cm_state[30]} {cm_state[31]} {cm_state[32]} {cm_state[33]} {cm_state[34]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 35 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {command_manager/state[0]} {command_manager/state[1]} {command_manager/state[2]} {command_manager/state[3]} {command_manager/state[4]} {command_manager/state[5]} {command_manager/state[6]} {command_manager/state[7]} {command_manager/state[8]} {command_manager/state[9]} {command_manager/state[10]} {command_manager/state[11]} {command_manager/state[12]} {command_manager/state[13]} {command_manager/state[14]} {command_manager/state[15]} {command_manager/state[16]} {command_manager/state[17]} {command_manager/state[18]} {command_manager/state[19]} {command_manager/state[20]} {command_manager/state[21]} {command_manager/state[22]} {command_manager/state[23]} {command_manager/state[24]} {command_manager/state[25]} {command_manager/state[26]} {command_manager/state[27]} {command_manager/state[28]} {command_manager/state[29]} {command_manager/state[30]} {command_manager/state[31]} {command_manager/state[32]} {command_manager/state[33]} {command_manager/state[34]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 24 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {command_manager/total_fp_triggers_sync[0]} {command_manager/total_fp_triggers_sync[1]} {command_manager/total_fp_triggers_sync[2]} {command_manager/total_fp_triggers_sync[3]} {command_manager/total_fp_triggers_sync[4]} {command_manager/total_fp_triggers_sync[5]} {command_manager/total_fp_triggers_sync[6]} {command_manager/total_fp_triggers_sync[7]} {command_manager/total_fp_triggers_sync[8]} {command_manager/total_fp_triggers_sync[9]} {command_manager/total_fp_triggers_sync[10]} {command_manager/total_fp_triggers_sync[11]} {command_manager/total_fp_triggers_sync[12]} {command_manager/total_fp_triggers_sync[13]} {command_manager/total_fp_triggers_sync[14]} {command_manager/total_fp_triggers_sync[15]} {command_manager/total_fp_triggers_sync[16]} {command_manager/total_fp_triggers_sync[17]} {command_manager/total_fp_triggers_sync[18]} {command_manager/total_fp_triggers_sync[19]} {command_manager/total_fp_triggers_sync[20]} {command_manager/total_fp_triggers_sync[21]} {command_manager/total_fp_triggers_sync[22]} {command_manager/total_fp_triggers_sync[23]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
set_property port_width 4 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {command_manager/chan_tx_fifo_dest[0]} {command_manager/chan_tx_fifo_dest[1]} {command_manager/chan_tx_fifo_dest[2]} {command_manager/chan_tx_fifo_dest[3]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
set_property port_width 5 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {command_manager/trig_type[0]} {command_manager/trig_type[1]} {command_manager/trig_type[2]} {command_manager/trig_type[3]} {command_manager/trig_type[4]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
set_property port_width 23 [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {command_manager/pulse_data_size[0]} {command_manager/pulse_data_size[1]} {command_manager/pulse_data_size[2]} {command_manager/pulse_data_size[3]} {command_manager/pulse_data_size[4]} {command_manager/pulse_data_size[5]} {command_manager/pulse_data_size[6]} {command_manager/pulse_data_size[7]} {command_manager/pulse_data_size[8]} {command_manager/pulse_data_size[9]} {command_manager/pulse_data_size[10]} {command_manager/pulse_data_size[11]} {command_manager/pulse_data_size[12]} {command_manager/pulse_data_size[13]} {command_manager/pulse_data_size[14]} {command_manager/pulse_data_size[15]} {command_manager/pulse_data_size[16]} {command_manager/pulse_data_size[17]} {command_manager/pulse_data_size[18]} {command_manager/pulse_data_size[19]} {command_manager/pulse_data_size[20]} {command_manager/pulse_data_size[21]} {command_manager/pulse_data_size[22]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
set_property port_width 32 [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list {command_manager/chan_rx_fifo_data[0]} {command_manager/chan_rx_fifo_data[1]} {command_manager/chan_rx_fifo_data[2]} {command_manager/chan_rx_fifo_data[3]} {command_manager/chan_rx_fifo_data[4]} {command_manager/chan_rx_fifo_data[5]} {command_manager/chan_rx_fifo_data[6]} {command_manager/chan_rx_fifo_data[7]} {command_manager/chan_rx_fifo_data[8]} {command_manager/chan_rx_fifo_data[9]} {command_manager/chan_rx_fifo_data[10]} {command_manager/chan_rx_fifo_data[11]} {command_manager/chan_rx_fifo_data[12]} {command_manager/chan_rx_fifo_data[13]} {command_manager/chan_rx_fifo_data[14]} {command_manager/chan_rx_fifo_data[15]} {command_manager/chan_rx_fifo_data[16]} {command_manager/chan_rx_fifo_data[17]} {command_manager/chan_rx_fifo_data[18]} {command_manager/chan_rx_fifo_data[19]} {command_manager/chan_rx_fifo_data[20]} {command_manager/chan_rx_fifo_data[21]} {command_manager/chan_rx_fifo_data[22]} {command_manager/chan_rx_fifo_data[23]} {command_manager/chan_rx_fifo_data[24]} {command_manager/chan_rx_fifo_data[25]} {command_manager/chan_rx_fifo_data[26]} {command_manager/chan_rx_fifo_data[27]} {command_manager/chan_rx_fifo_data[28]} {command_manager/chan_rx_fifo_data[29]} {command_manager/chan_rx_fifo_data[30]} {command_manager/chan_rx_fifo_data[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
set_property port_width 1 [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list trigger_top/trigger_processor/acq_fifo_ready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
set_property port_width 1 [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list trigger_top/trigger_processor/acq_fifo_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
set_property port_width 1 [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list command_manager/chan_rx_fifo_last]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
set_property port_width 1 [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list command_manager/chan_rx_fifo_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe16]
set_property port_width 1 [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list daq_almost_full]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe17]
set_property port_width 1 [get_debug_ports u_ila_1/probe17]
connect_debug_port u_ila_1/probe17 [get_nets [list daq_header]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe18]
set_property port_width 1 [get_debug_ports u_ila_1/probe18]
connect_debug_port u_ila_1/probe18 [get_nets [list daq_ready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe19]
set_property port_width 1 [get_debug_ports u_ila_1/probe19]
connect_debug_port u_ila_1/probe19 [get_nets [list daq_trailer]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe20]
set_property port_width 1 [get_debug_ports u_ila_1/probe20]
connect_debug_port u_ila_1/probe20 [get_nets [list daq_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe21]
set_property port_width 1 [get_debug_ports u_ila_1/probe21]
connect_debug_port u_ila_1/probe21 [get_nets [list trigger_top/trigger_processor/error_trig_num]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe22]
set_property port_width 1 [get_debug_ports u_ila_1/probe22]
connect_debug_port u_ila_1/probe22 [get_nets [list trigger_top/error_trig_num]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe23]
set_property port_width 1 [get_debug_ports u_ila_1/probe23]
connect_debug_port u_ila_1/probe23 [get_nets [list error_trig_num_from_tt]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe24]
set_property port_width 1 [get_debug_ports u_ila_1/probe24]
connect_debug_port u_ila_1/probe24 [get_nets [list trigger_top/trigger_processor/error_trig_type]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe25]
set_property port_width 1 [get_debug_ports u_ila_1/probe25]
connect_debug_port u_ila_1/probe25 [get_nets [list latch_ttc_trigger]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe26]
set_property port_width 1 [get_debug_ports u_ila_1/probe26]
connect_debug_port u_ila_1/probe26 [get_nets [list trigger_top/pulse_trigger_125]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe27]
set_property port_width 1 [get_debug_ports u_ila_1/probe27]
connect_debug_port u_ila_1/probe27 [get_nets [list trigger_top/trigger_processor/readout_ready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe28]
set_property port_width 1 [get_debug_ports u_ila_1/probe28]
connect_debug_port u_ila_1/probe28 [get_nets [list trigger_top/trigger_processor/reset]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe29]
set_property port_width 1 [get_debug_ports u_ila_1/probe29]
connect_debug_port u_ila_1/probe29 [get_nets [list trigger_top/trigger_processor/trig_fifo_ready]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe30]
set_property port_width 1 [get_debug_ports u_ila_1/probe30]
connect_debug_port u_ila_1/probe30 [get_nets [list trigger_top/trigger_processor/trig_fifo_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe31]
set_property port_width 1 [get_debug_ports u_ila_1/probe31]
connect_debug_port u_ila_1/probe31 [get_nets [list trigger_top/trigger_processor/ttc_empty_event]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe32]
set_property port_width 1 [get_debug_ports u_ila_1/probe32]
connect_debug_port u_ila_1/probe32 [get_nets [list ttc_trigger_125]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk125]
