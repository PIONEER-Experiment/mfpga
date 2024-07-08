

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list ttc/ttc_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 5 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {selftrigger_top/channel_acq_controller_selftrig/acq_buffer_write[0]} {selftrigger_top/channel_acq_controller_selftrig/acq_buffer_write[1]} {selftrigger_top/channel_acq_controller_selftrig/acq_buffer_write[2]} {selftrigger_top/channel_acq_controller_selftrig/acq_buffer_write[3]} {selftrigger_top/channel_acq_controller_selftrig/acq_buffer_write[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 5 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {selftrigger_top/channel_acq_controller_selftrig/acq_dones_latched[0]} {selftrigger_top/channel_acq_controller_selftrig/acq_dones_latched[1]} {selftrigger_top/channel_acq_controller_selftrig/acq_dones_latched[2]} {selftrigger_top/channel_acq_controller_selftrig/acq_dones_latched[3]} {selftrigger_top/channel_acq_controller_selftrig/acq_dones_latched[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 5 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {selftrigger_top/channel_acq_controller_selftrig/chan_en[0]} {selftrigger_top/channel_acq_controller_selftrig/chan_en[1]} {selftrigger_top/channel_acq_controller_selftrig/chan_en[2]} {selftrigger_top/channel_acq_controller_selftrig/chan_en[3]} {selftrigger_top/channel_acq_controller_selftrig/chan_en[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {selftrigger_top/channel_acq_controller_selftrig/nextstate[0]} {selftrigger_top/channel_acq_controller_selftrig/nextstate[1]} {selftrigger_top/channel_acq_controller_selftrig/nextstate[2]} {selftrigger_top/channel_acq_controller_selftrig/nextstate[3]} {selftrigger_top/channel_acq_controller_selftrig/nextstate[4]} {selftrigger_top/channel_acq_controller_selftrig/nextstate[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 6 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {selftrigger_top/channel_acq_controller_selftrig/state[0]} {selftrigger_top/channel_acq_controller_selftrig/state[1]} {selftrigger_top/channel_acq_controller_selftrig/state[2]} {selftrigger_top/channel_acq_controller_selftrig/state[3]} {selftrigger_top/channel_acq_controller_selftrig/state[4]} {selftrigger_top/channel_acq_controller_selftrig/state[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 2 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/state[0]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/state[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 20 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[0]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[1]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[2]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[3]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[4]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[5]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[6]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[7]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[8]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[9]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[10]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[11]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[12]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[13]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[14]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[15]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[16]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[17]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[18]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_lo[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 20 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[0]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[1]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[2]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[3]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[4]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[5]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[6]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[7]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[8]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[9]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[10]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[11]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[12]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[13]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[14]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[15]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[16]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[17]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[18]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/selftriggers_hi[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 24 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[0]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[1]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[2]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[3]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[4]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[5]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[6]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[7]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[8]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[9]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[10]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[11]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[12]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[13]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[14]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[15]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[16]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[17]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[18]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[19]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[20]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[21]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[22]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 5 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_type[0]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_type[1]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_type[2]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_type[3]} {selftrigger_top/ttc_trigger_receiver_selftrig/acq_trig_type[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 4 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {selftrigger_top/ttc_trigger_receiver_selftrig/state[0]} {selftrigger_top/ttc_trigger_receiver_selftrig/state[1]} {selftrigger_top/ttc_trigger_receiver_selftrig/state[2]} {selftrigger_top/ttc_trigger_receiver_selftrig/state[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 24 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[0]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[1]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[2]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[3]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[4]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[5]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[6]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[7]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[8]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[9]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[10]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[11]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[12]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[13]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[14]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[15]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[16]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[17]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[18]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[19]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[20]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[21]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[22]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_num[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 5 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {selftrigger_top/ttc_trigger_receiver_selftrig/trig_type[0]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_type[1]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_type[2]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_type[3]} {selftrigger_top/ttc_trigger_receiver_selftrig/trig_type[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 5 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {selftrigger_top/chan_buffer_read[0]} {selftrigger_top/chan_buffer_read[1]} {selftrigger_top/chan_buffer_read[2]} {selftrigger_top/chan_buffer_read[3]} {selftrigger_top/chan_buffer_read[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 5 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {selftrigger_top/chan_dones_clk40[0]} {selftrigger_top/chan_dones_clk40[1]} {selftrigger_top/chan_dones_clk40[2]} {selftrigger_top/chan_dones_clk40[3]} {selftrigger_top/chan_dones_clk40[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 5 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {selftrigger_top/chan_en_clk40[0]} {selftrigger_top/chan_en_clk40[1]} {selftrigger_top/chan_en_clk40[2]} {selftrigger_top/chan_en_clk40[3]} {selftrigger_top/chan_en_clk40[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {acq_buffer[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 5 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {acq_enable[0]} {acq_enable[1]} {acq_enable[2]} {acq_enable[3]} {acq_enable[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list accept_self_triggers]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list selftrigger_top/channel_acq_controller_selftrig/accept_self_triggers_reg]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/acq_activated]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/acq_ready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list selftrigger_top/acq_trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/acq_trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/ddr3_buffer}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/empty_event]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/empty_payload]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list ipb_accept_self_triggers_ttc]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list selftrigger_top/channel_acq_controller_selftrig/reset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/reset_trig_num]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/selftriggers_seen]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {selftrigger_top/ctr_loop[1].channel_trigger_receiver/trigger}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {selftrigger_top/ctr_loop[3].channel_trigger_receiver/trigger}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/trigger}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {selftrigger_top/ctr_loop[4].channel_trigger_receiver/trigger}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {selftrigger_top/ctr_loop[2].channel_trigger_receiver/trigger}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list ttc_accept_self_triggers]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list selftrigger_top/ttc_trigger_receiver_selftrig/ttc_trigger]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list selftrigger_top/channel_acq_controller_selftrig/ttc_trigger]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ttc_clk]
