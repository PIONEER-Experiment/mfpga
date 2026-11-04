# 6.7.3 debug VIO (eth_debug in ipbus_top): only in the project when the VIO is built in
# (DEBUG_ETH_VIO = 1 in the top level, scripts/add_debug_vio.tcl).  Remove it from the project
# for a release build, together with the vio_eth IP; with no VIO these constraints would match
# nothing and Vivado would warn.
#
# The VIO samples counters and flags from the MAC clock (userclk2) and the IPbus clock (the PLL's
# clk125) in clk_200.  clk125 and clk_200 come from the same PLL, so Vivado would time those
# paths with the 1 ns worst-case edge relationship of 125 vs 200 MHz; they are observation only
# (read by a person over JTAG), so they are not timed.
set_false_path -through [get_pins -hier -filter {NAME =~ *dbg/vio/probe_in*}]
set_false_path -to [get_cells -hier -filter {NAME =~ *dbg/flags_s1_reg*}]
