# Read all of the HDL files for the project

# Delegate reading the IPbus stuff to another script
source $ROOT/ipbus/read_hdl.tcl

# Main Files
read_verilog [ glob $ROOT/hdl/*.v ]

# Also include the TTC decoder module from Boston (VHDL)
read_vhdl [ glob $ROOT/hdl/*.vhd ]

# DAQ link from Boston
read_vhdl [ glob $ROOT/DAQ_Link_7S/*.vhd ]