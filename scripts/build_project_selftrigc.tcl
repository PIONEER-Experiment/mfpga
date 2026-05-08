# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir [file dirname [info script]]/../

# Create project
create_project WFD_Master_selftrigc $origin_dir/project_selftrigc

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects WFD_Master_selftrigc]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xc7k160tfbg676-1" $obj
set_property "simulator_language" "Mixed" $obj
set_property "source_mgmt_mode" "None" $obj

# =============================================================================
# Suppress warnings that we have reviewed and are fine
# =============================================================================

# ----------------------------------------------------------------------------
# Suppress WARNING/INFO messages from foreign code we don't own.
# Scan these directories for Verilog modules and VHDL entities, then
# tell Vivado to silence any message that mentions one of those names.
# ----------------------------------------------------------------------------
set foreign_globs [list \
    "$origin_dir/DAQ_Link_7S/*.v"            \
    "$origin_dir/DAQ_Link_7S/*.vhd"          \
    "$origin_dir/ipbus/ethernet/*.v"         \
    "$origin_dir/ipbus/ethernet/*.vhd"       \
    "$origin_dir/ipbus/ipbus_core/hdl/*.v"   \
    "$origin_dir/ipbus/ipbus_core/hdl/*.vhd" \
]

set foreign_names [list]

foreach pattern $foreign_globs {
    foreach file [glob -nocomplain $pattern] {
        set fp [open $file r]
        set content [read $fp]
        close $fp

        foreach line [split $content "\n"] {
            # Verilog:  "module <name>"
            if { [regexp {^\s*module\s+(\w+)} $line _ name] } {
                lappend foreign_names $name
            }
            # VHDL:  "entity <name> is"
            if { [regexp -nocase {^\s*entity\s+(\w+)\s+is} $line _ name] } {
                lappend foreign_names $name
            }
        }
    }
}

set foreign_names [lsort -unique $foreign_names]
puts "INFO: Suppressing WARNING/INFO for [llength $foreign_names] foreign module/entity names:"
foreach name $foreign_names {
    puts "  $name"
    set_msg_config -severity {WARNING} -string $name -suppress
    set_msg_config -severity {INFO}    -string $name -suppress
}


# -- --------------------------------------------------------------------------
#    List of modules with legitimate unused ports
# -- --------------------------------------------------------------------------

foreach mod {ipbus_flash ipbus_status_reg ipbus_write_only_reg ipbus_axi_stream ipbus_ctrlreg_v} {
    set_msg_config -id "Synth 8-7129" -string $mod -suppress
}

# -- --------------------------------------------------------------------------
#    Specific unused-sequential elements that we accept by design
# -- --------------------------------------------------------------------------
foreach reg {i2c_stop_reg readout_done_reg} {
    set_msg_config -id "Synth 8-6014" -string $reg -suppress
}

# -- --------------------------------------------------------------------------
#    Specific output ports intentionally driven by constants
# -- --------------------------------------------------------------------------
foreach port {ext_clk_sel0 ext_clk_sel1 daq_clk_sel daq_clk_en} {
    set_msg_config -id "Synth 8-3917" -string $port -suppress
}

# -- --------------------------------------------------------------------------
#    Warnings and info from IP-generated user code
# -- --------------------------------------------------------------------------

set_msg_config -severity {WARNING} -string "aurora_8b10b_0" -suppress
set_msg_config -severity {INFO}    -string "aurora_8b10b_0" -suppress


# ----------------------------------------------------------------------------
# Add the source files to the project
# ----------------------------------------------------------------------------

# -- --------------------------------------------------------------------------
#    Miscellaneous warnings that we can ignore
# -- --------------------------------------------------------------------------
set_msg_config -id "Synth 8-3332" -string "event_size1" -suppress


# =============================================================================
# Start assembling the actual project now
# =============================================================================

# ----------------------------------------------------------------------------
# Add the source files to the project
# ----------------------------------------------------------------------------

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

add_files -norecurse -fileset $obj [glob $origin_dir/ip/common/*/*.xci]
add_files -norecurse -fileset $obj [glob $origin_dir/ip/selftrig_mode_only/*/*.xci]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/ipbus_core/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/ethernet/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/slaves/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.v]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/selftrigc_mode_only/*.v]
# uncomment if vhdl files get added to self_trig_mode-only
#add_files -norecurse -fileset $obj [glob $origin_dir/hdl/selftrigc_mode_only/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/DAQ_Link_7S/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.txt]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.vh]
                                                               #*/
# Set 'sources_1' fileset file properties for remote files
# IPs that should synthesize globally instead of OOC
set global_synth_ips { i2c_eeprom_image }

foreach file [glob -nocomplain \
              $origin_dir/ip/common/*.xci \
              $origin_dir/ip/selftrig_mode_only/*.xci] {  #*/
    set file [file normalize $file]
    set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
    if { [get_property "is_locked" $file_obj] } continue
    set ip_name [file rootname [file tail $file]]
    if { [lsearch -exact $global_synth_ips $ip_name] >= 0 } {
        set_property "synth_checkpoint_mode" "None" $file_obj
    } else {
        set_property "synth_checkpoint_mode" "Singular" $file_obj
    }
}

foreach file [glob $origin_dir/hdl/*.txt] {  #*/
  	set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "Verilog Header" $file_obj
}

foreach file [glob $origin_dir/ipbus/hdl/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/ipbus_core/hdl/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/ethernet/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/slaves/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/hdl/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

# uncomment if vhdl files get added to self_trig_mode-only
#foreach file [glob $origin_dir/hdl/self_trig_mode_only/*.vhd] {  #*/
#    set file [file normalize $file]
#    set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
#    set_property "file_type" "VHDL" $file_obj
#}

foreach file [glob $origin_dir/DAQ_Link_7S/*.vhd] {  #*/
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "wfd_selftrigc_top" $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Create 'constrs_impl_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_impl_1] ""]} {
  create_fileset -constrset constrs_impl_1
}

set cflist [glob $origin_dir/constraints/self_trig_cbuf/ios.xdc \
                 $origin_dir/constraints/self_trig_cbuf/timing.xdc \
                 $origin_dir/constraints/synthesis.xdc \
                 $origin_dir/constraints/bitstream.xdc \
                 $origin_dir/constraints/wizard.xdc]

set ciflist [glob $origin_dir/constraints/self_trig_cbuf/ios.xdc \
                  $origin_dir/constraints/self_trig_cbuf/timing.xdc \
                  $origin_dir/constraints/self_trig_cbuf/timing_impl.xdc \
                  $origin_dir/constraints/synthesis.xdc \
                  $origin_dir/constraints/bitstream.xdc \
                  $origin_dir/constraints/wizard.xdc]

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
foreach file_temp $cflist {
	set file "[file normalize "$file_temp"]"
	set file_added [add_files -norecurse -fileset $obj $file]
	set file "$file_temp"
	set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
	set_property "file_type" "XDC" $file_obj
}

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

# Set 'constrs_impl_1' fileset object
set obj [get_filesets constrs_impl_1]

# Add/Import constrs file and set constrs file properties that will be used in implementation
foreach file_temp $ciflist {
  set file "[file normalize "$file_temp"]"
  set file_added [add_files -norecurse -fileset $obj $file]
  set file "$file_temp"
  set file [file normalize $file]
  set file_obj [get_files -of_objects [get_filesets constrs_impl_1] [list "*$file"]]
  set_property "file_type" "XDC" $file_obj
}

# Set 'constrs_impl_1' fileset properties
set obj [get_filesets constrs_impl_1]


# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xc7k160tfbg676-1 -flow {Vivado Synthesis 2025} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2025" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" "xc7k160tfbg676-1" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7k160tfbg676-1 -flow {Vivado Implementation 2025} -strategy "Performance_ExplorePostRoutePhysOpt" -constrset constrs_impl_1 -parent_run synth_1
} else {
  set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
  set_property flow "Vivado Implementation 2025" [get_runs impl_1]
  set_property constrset constrs_impl_1 [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" "xc7k160tfbg676-1" $obj
                                                               
# Add hook scripts to utils_1 so they're part of the project
add_files -fileset utils_1 -norecurse [file normalize "$origin_dir/scripts/get_version.tcl"]
add_files -fileset utils_1 -norecurse [file normalize "$origin_dir/scripts/export_bitstream_selftrigc.tcl"]
set_property "steps.write_bitstream.tcl.pre" "[file normalize "$origin_dir/scripts/get_version.tcl"]" $obj
set_property "steps.write_bitstream.tcl.post" "[file normalize "$origin_dir/scripts/export_bitstream_selftrigc.tcl"]" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

# Generate IP output products from their .xci files
set ips [get_ips]
if {[llength $ips] > 0} {
    puts "INFO: Generating output products for [llength $ips] IPs..."
    foreach ip $ips {
        puts "  $ip"
    }
    generate_target all [get_ips]
}
                                                               
# i2c_eeprom_image is a single 18Kb BMEM; the OOC clock period (20 ns) is
# hardcoded in the blk_mem_gen 8.4 template. The actual silicon timing is
# unaffected — BRAM primitives don't care about OOC clock period since
# synthesis doesn't optimize across the IP boundary at OOC time.
set_msg_config -id "Timing 38-316" -string "i2c_top/i2c_eeprom_image" -suppress
                                                     
puts "INFO: Project created: WFD_Master_selftrigc"
