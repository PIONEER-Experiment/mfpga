# Add the 6.7.3 Ethernet / IPbus debug VIO to the open project (run once, in the Vivado Tcl console,
# with the master project open):    source <repo>/scripts/add_debug_vio.tcl
#
# It creates the vio_eth IP in ip/debug/ (10 probes in, none out, widths as eth_debug.vhd expects),
# adds constraints/debug/debug_vio.xdc, and generates the IP's output products.  The top level must
# have DEBUG_ETH_VIO = 1 for the VIO to be built in.
#
# For a release build: set DEBUG_ETH_VIO = 0 and remove ip/debug/vio_eth/vio_eth.xci and
# constraints/debug/debug_vio.xdc from the project (remove_files ...); nothing else changes.
set origin_dir [file normalize [file dirname [info script]]/..]
if {[llength [get_ips -quiet vio_eth]] == 0} {
  create_ip -name vio -vendor xilinx.com -library ip -module_name vio_eth -dir $origin_dir/ip/debug
  set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {10} CONFIG.C_NUM_PROBE_OUT {0} CONFIG.C_EN_PROBE_IN_ACTIVITY {0} \
    CONFIG.C_PROBE_IN0_WIDTH {16} CONFIG.C_PROBE_IN1_WIDTH {8} CONFIG.C_PROBE_IN2_WIDTH {16} \
    CONFIG.C_PROBE_IN3_WIDTH {16} CONFIG.C_PROBE_IN4_WIDTH {16} CONFIG.C_PROBE_IN5_WIDTH {16} \
    CONFIG.C_PROBE_IN6_WIDTH {16} CONFIG.C_PROBE_IN7_WIDTH {16} CONFIG.C_PROBE_IN8_WIDTH {16} \
    CONFIG.C_PROBE_IN9_WIDTH {16} ] [get_ips vio_eth]
  generate_target all [get_files vio_eth.xci]
  puts "INFO: vio_eth created in $origin_dir/ip/debug/vio_eth"
} else {
  puts "INFO: vio_eth already in the project"
}
set src $origin_dir/ipbus/hdl/eth_debug.vhd
if {[llength [get_files -quiet $src]] == 0} {
  add_files -fileset sources_1 -norecurse $src
  puts "INFO: added $src"
}
set xdc $origin_dir/constraints/debug/debug_vio.xdc
if {[llength [get_files -quiet $xdc]] == 0} {
  add_files -fileset constrs_1 -norecurse $xdc
  set_property used_in_synthesis false [get_files $xdc]
  puts "INFO: added $xdc (implementation only)"
}
