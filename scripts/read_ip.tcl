# setup
set_property target_simulator XSim [current_project]
set_property part xc7k160tfbg676-2 [current_project]

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

# AXI4-Stream Data FIFO
if {[file exists $ROOT/ip/axis_data_fifo_ipbus_loopback/axis_data_fifo_ipbus_loopback.xci]} {
	read_ip $ROOT/ip/axis_data_fifo_ipbus_loopback/axis_data_fifo_ipbus_loopback.xci
} else {
	set_property target_language Verilog [current_project]
	create_ip -name axis_data_fifo -vendor xilinx.com -library ip -module_name axis_data_fifo_ipbus_loopback -dir $ROOT/ip
	set_property -dict [list CONFIG.TDATA_NUM_BYTES {4} CONFIG.TID_WIDTH {4} CONFIG.TDEST_WIDTH {4} CONFIG.FIFO_DEPTH {128} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1}] [get_ips axis_data_fifo_ipbus_loopback]
	generate_target all [get_files $ROOT/ip/axis_data_fifo_ipbus_loopback/axis_data_fifo_ipbus_loopback.xci]
	synth_ip [get_ips axis_data_fifo_ipbus_loopback]
}