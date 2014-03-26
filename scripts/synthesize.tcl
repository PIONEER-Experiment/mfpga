source setup.tcl
source read_hdl.tcl
source read_ip.tcl

synth_design -top ipbus_only_top -part xc7k160tfbg676-2
report_utilization
report_timing
start_gui