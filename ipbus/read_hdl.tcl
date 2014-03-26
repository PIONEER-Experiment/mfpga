# source from root directory of the project

read_vhdl [ glob $ROOT/ipbus/hdl/*.vhd ]
read_vhdl [ glob $ROOT/ipbus/ipbus_core/hdl/*.vhd ]
read_vhdl [ glob $ROOT/ipbus/ethernet/hdl/*.vhd ]
read_vhdl [ glob $ROOT/ipbus/slaves/hdl/*.vhd ]