source setup.tcl

source read_hdl.tcl
source read_ip.tcl
# source read_constraints.tcl
read_xdc $ROOT/constraints/timing.xdc

read_xdc $ROOT/constraints/ipbus_only_place.xdc

synth_design -top wfd_top -name wfd -part xc7k160tfbg676-2
refresh_design

start_gui