source ../../../scripts/setup.tcl

create_project -force ipbus_sim $ROOT/ipbus/project/

source $ROOT/ipbus/read_hdl.tcl

read_vhdl [list $ROOT/ipbus/sim/hdl/ipbus_tb.vhd $ROOT/ipbus/sim/hdl/package_ipbus_simulation.vhd]
set_property top ipbus_tb [get_filesets sim_1]
set_property runtime 5us [get_filesets sim_1]

launch_xsim -mode behavioral
start_gui
