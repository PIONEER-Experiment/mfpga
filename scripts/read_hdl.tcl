source $ROOT/ipbus/read_hdl.tcl

read_verilog [ glob $ROOT/hdl/*.v ]
read_vhdl [ glob $ROOT/DAQ_Link_7S/*.vhd ]