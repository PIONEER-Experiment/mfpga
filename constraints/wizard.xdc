


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
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 11 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {acq_encode2/state[0]} {acq_encode2/state[1]} {acq_encode2/state[2]} {acq_encode2/state[3]} {acq_encode2/state[4]} {acq_encode2/state[5]} {acq_encode2/state[6]} {acq_encode2/state[7]} {acq_encode2/state[8]} {acq_encode2/state[9]} {acq_encode2/state[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 34 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {command_manager_selftrig/state[1]} {command_manager_selftrig/state[2]} {command_manager_selftrig/state[3]} {command_manager_selftrig/state[4]} {command_manager_selftrig/state[5]} {command_manager_selftrig/state[6]} {command_manager_selftrig/state[7]} {command_manager_selftrig/state[8]} {command_manager_selftrig/state[9]} {command_manager_selftrig/state[10]} {command_manager_selftrig/state[11]} {command_manager_selftrig/state[12]} {command_manager_selftrig/state[13]} {command_manager_selftrig/state[14]} {command_manager_selftrig/state[15]} {command_manager_selftrig/state[16]} {command_manager_selftrig/state[17]} {command_manager_selftrig/state[18]} {command_manager_selftrig/state[19]} {command_manager_selftrig/state[20]} {command_manager_selftrig/state[21]} {command_manager_selftrig/state[22]} {command_manager_selftrig/state[23]} {command_manager_selftrig/state[24]} {command_manager_selftrig/state[25]} {command_manager_selftrig/state[26]} {command_manager_selftrig/state[27]} {command_manager_selftrig/state[28]} {command_manager_selftrig/state[29]} {command_manager_selftrig/state[30]} {command_manager_selftrig/state[31]} {command_manager_selftrig/state[32]} {command_manager_selftrig/state[33]} {command_manager_selftrig/state[34]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list acq_encode2/accept_self_triggers_125]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list acq_encode2/clear_trigger_counts]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list acq_encode2/n_0_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list command_manager_selftrig/readout_ready]]
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
connect_debug_port u_ila_1/clk [get_nets [list ttc/ttc_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 23 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[0]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[1]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[2]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[3]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[4]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[5]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[6]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[7]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[8]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[9]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[10]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[11]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[12]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[13]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[14]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[15]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[16]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[17]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[18]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[19]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[20]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[21]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_hi[22]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 23 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[0]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[1]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[2]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[3]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[4]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[5]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[6]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[7]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[8]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[9]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[10]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[11]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[12]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[13]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[14]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[15]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[16]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[17]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[18]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[19]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[20]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[21]} {selftrigger_top/ctr_loop[0].channel_trigger_receiver/stored_bursts_lo[22]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 23 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {selftrigger_top/stored_bursts_chan0[0]} {selftrigger_top/stored_bursts_chan0[1]} {selftrigger_top/stored_bursts_chan0[2]} {selftrigger_top/stored_bursts_chan0[3]} {selftrigger_top/stored_bursts_chan0[4]} {selftrigger_top/stored_bursts_chan0[5]} {selftrigger_top/stored_bursts_chan0[6]} {selftrigger_top/stored_bursts_chan0[7]} {selftrigger_top/stored_bursts_chan0[8]} {selftrigger_top/stored_bursts_chan0[9]} {selftrigger_top/stored_bursts_chan0[10]} {selftrigger_top/stored_bursts_chan0[11]} {selftrigger_top/stored_bursts_chan0[12]} {selftrigger_top/stored_bursts_chan0[13]} {selftrigger_top/stored_bursts_chan0[14]} {selftrigger_top/stored_bursts_chan0[15]} {selftrigger_top/stored_bursts_chan0[16]} {selftrigger_top/stored_bursts_chan0[17]} {selftrigger_top/stored_bursts_chan0[18]} {selftrigger_top/stored_bursts_chan0[19]} {selftrigger_top/stored_bursts_chan0[20]} {selftrigger_top/stored_bursts_chan0[21]} {selftrigger_top/stored_bursts_chan0[22]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list acq_encode2/accept_self_triggers]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 1 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {selftrigger_top/ctr_loop[0].channel_trigger_receiver/clear_trigger_counts}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ttc_clk]
