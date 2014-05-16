source setup.tcl

source read_hdl.tcl
source read_ip.tcl
# source read_constraints.tcl
read_xdc $ROOT/constraints/timing.xdc
read_xdc $ROOT/constraints/ipbus_only_place.xdc

synth_design -top wfd_top -name wfd -part xc7k160tfbg676-2
refresh_design

# read_xdc $ROOT/constraints/debug.xdc


opt_design
# power_opt_design
place_design
phys_opt_design
route_design

write_bitstream -force $ROOT/bitstreams/wfd_master.bit
# write_debug_probes -force $ROOT/bitstreams/debug.ltx

start_gui
