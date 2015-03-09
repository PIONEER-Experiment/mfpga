# Export the bitstream file
if {[file exists ./wfd_top.bit]} {
  file copy -force ./wfd_top.bit [file dirname [info script]]/../bitstreams/wfd_master.bit
  puts "INFO: Bitstream copied: wfd_master.bit"
} else {
  puts "ERROR: Bitstream not found: wfd_top.bit"
}

# Export the debug file
if {[file exists ./debug_netlist.ltx]} {
  file copy -force ./debug_netlist.ltx [file dirname [info script]]/../debugs/debug.ltx
  puts "INFO: Debug copied: debug.ltx"
} else {
  puts "ERROR: Debug not found: debug_netlist.ltx"
}
