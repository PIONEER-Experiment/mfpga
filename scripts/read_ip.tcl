# setup
set_property target_simulator XSim [current_project]
set_property part xc7k160tfbg676-2 [current_project]

# load ips
# if they don't already exist, create them

# gigabit ethernet PHY
if {[file exists $ROOT/ip/gig_ethernet_pcs_pma_0/gig_ethernet_pcs_pma_0.xci]} {
	read_ip $ROOT/ip/gig_ethernet_pcs_pma_0/gig_ethernet_pcs_pma_0.xci
} else {
	set_property target_language VHDL [current_project]
	create_ip -name gig_ethernet_pcs_pma -vendor xilinx.com -library ip -module_name gig_ethernet_pcs_pma_0 -dir $ROOT/ip
	set_property -dict [list CONFIG.SupportLevel {Include_Shared_Logic_in_Core} CONFIG.TransceiverControl {true} CONFIG.Management_Interface {false} CONFIG.Auto_Negotiation {false}] [get_ips gig_ethernet_pcs_pma_0]
	generate_target all [get_files $ROOT/ip/gig_ethernet_pcs_pma_0/gig_ethernet_pcs_pma_0.xci]
	synth_ip [get_ips gig_ethernet_pcs_pma_0]
	set_property target_language Verilog [current_project]
}


# disable IP constraints, since we want to do it ourselves
set_property is_enabled false [get_files $ROOT/ip/gig_ethernet_pcs_pma_0/synth/gig_ethernet_pcs_pma_0_ooc.xdc]

# channnel serial link FIFO
if {[file exists $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci
]} {
	read_ip $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci
} else {
	create_ip -name axis_data_fifo -vendor xilinx.com -library ip -module_name chan_link_axis_data_fifo -dir $ROOT/ip
	set_property -dict [list CONFIG.TDATA_NUM_BYTES {4} CONFIG.FIFO_DEPTH {4096} CONFIG.IS_ACLK_ASYNC {1} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1}] [get_ips chan_link_axis_data_fifo]
	generate_target all [get_files $ROOT/ip/chan_link_axis_data_fifo/chan_link_axis_data_fifo.xci]
	synth_ip [get_ips chan_link_axis_data_fifo]
}

# aurora serial link to channel fpga
if {[file exists $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci]} {
	read_ip $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci
} else {
	create_ip -name aurora_8b10b -vendor xilinx.com -library ip -module_name aurora_8b10b_0 -dir $ROOT/ip
	set_property -dict [list CONFIG.C_LANE_WIDTH {4} CONFIG.C_LINE_RATE {5.0} CONFIG.C_GT_LOC_1 {X} CONFIG.C_GT_LOC_5 {1}] [get_ips aurora_8b10b_0]
	generate_target all [get_files $ROOT/ip/aurora_8b10b_0/aurora_8b10b_0.xci]
	synth_ip [get_ips aurora_8b10b_0]
}

# # axis data width converter
# if {[file exists $ROOT/ip/axis_dwidth_converter_m32_d16/axis_dwidth_converter_m32_d16.xci]} {
# 	read_ip $ROOT/ip/axis_dwidth_converter_m32_d16/axis_dwidth_converter_m32_d16.xci
# } else {
# 	create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -module_name axis_dwidth_converter_m32_d16 -dir $ROOT/ip
# 	set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {2} CONFIG.M_TDATA_NUM_BYTES {4} CONFIG.HAS_TLAST {1} CONFIG.HAS_TKEEP {1}] [get_ips axis_dwidth_converter_m32_d16]
# 	generate_target all [get_files $ROOT/ip/axis_dwidth_converter_m32_d16/axis_dwidth_converter_m32_d16.xci]
# 	synth_ip [get_ips axis_dwidth_converter_m32_d16]
# }

# if {[file exists $ROOT/ip/axis_dwidth_converter_m16_d32/axis_dwidth_converter_m16_d32.xci]} {
# 	read_ip $ROOT/ip/axis_dwidth_converter_m16_d32/axis_dwidth_converter_m16_d32.xci
# } else {
# 	create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -module_name axis_dwidth_converter_m16_d32 -dir $ROOT/ip
# 	set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {4} CONFIG.M_TDATA_NUM_BYTES {2} CONFIG.HAS_TLAST {1} CONFIG.HAS_TKEEP {1}] [get_ips axis_dwidth_converter_m16_d32]
# 	generate_target all [get_files $ROOT/ip/axis_dwidth_converter_m16_d32/axis_dwidth_converter_m16_d32.xci]
# 	synth_ip [get_ips axis_dwidth_converter_m16_d32]
# }