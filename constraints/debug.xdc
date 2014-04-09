# select the net that need to be observed
set_property MARK_DEBUG "true" [get_nets ipb/eth/phy/status_vector[*]]

#create one or more ILAs and connect signals
#This one is for signals driven from the 50 MHz 'clkin_buf' clock source
create_debug_core u_ila_0 labtools_ila_v3
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
# enable 'storage qualifiers' to be able to gather samples at a fraction of the clock rate
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]

# connect the clock
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets ipb/eth/phy/userclk2_out]

# the first probe is automatically created
# for busses, put the LSB first and the MSB last
#start with a counter to gather samples at a fraction of the clock rate
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list ipb/eth/phy/status_vector[0] ipb/eth/phy/status_vector[1] ipb/eth/phy/status_vector[2] ipb/eth/phy/status_vector[3] ipb/eth/phy/status_vector[4] ipb/eth/phy/status_vector[5] ipb/eth/phy/status_vector[6] ipb/eth/phy/status_vector[7] ipb/eth/phy/status_vector[8] ipb/eth/phy/status_vector[9] ipb/eth/phy/status_vector[10] ipb/eth/phy/status_vector[11] ipb/eth/phy/status_vector[12] ipb/eth/phy/status_vector[13] ipb/eth/phy/status_vector[14] ipb/eth/phy/status_vector[15]]]

set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]



 