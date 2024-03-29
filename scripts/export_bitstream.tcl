# Export the bitstream file and create the .mcs file
if {[file exists ./wfd_top.bit]} {
  file copy -force ./wfd_top.bit [file dirname [info script]]/../bitstreams/wfd_master_$version.bit
  puts "INFO: Bitstream copied: wfd_master.bit"
  write_cfgmem -force -format MCS -size 32 -interface SPIx1 \
      -loadbit "up 0x00670000 ./wfd_top.bit" [file dirname [info script]]/../bitstreams/wfd_master_$version
} else {
  puts "ERROR: Bitstream not found: wfd_top.bit"
}

# Export the debug file
if {[file exists ./debug_nets.ltx]} {
  file copy -force ./debug_nets.ltx [file dirname [info script]]/../bitstreams/wfd_master_$version.ltx
  puts "INFO: Debug copied: wfd_master.ltx"
} else {
  puts "ERROR: Debug not found: debug_nets.ltx"
}
