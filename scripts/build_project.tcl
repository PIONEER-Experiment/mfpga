# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir [file dirname [info script]]/../

# Create project
create_project WFD_Master $origin_dir/project

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [get_projects WFD_Master]
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" "xc7k160tfbg676-1" $obj
set_property "simulator_language" "Mixed" $obj
set_property "source_mgmt_mode" "None" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

add_files -norecurse -fileset $obj [glob $origin_dir/ip/*/*.xci]
add_files -norecurse -fileset $obj [glob $origin_dir/ip/standard_mode_only/*/*.xci]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/ipbus_core/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/ethernet/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/ipbus/slaves/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.v]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/standard_mode_only/*.v]
# uncomment if vhdl files get added to standard_mode_only
#add_files -norecurse -fileset $obj [glob $origin_dir/hdl/standard_mode_only/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/DAQ_Link_7S/*.vhd]
add_files -norecurse -fileset $obj [glob $origin_dir/hdl/*.txt]

# Set 'sources_1' fileset file properties for remote files
foreach file [glob $origin_dir/ip/*/*.xci] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	if { ![get_property "is_locked" $file_obj] } {
  		set_property "synth_checkpoint_mode" "Singular" $file_obj
	}
}

foreach file [glob $origin_dir/hdl/*.txt] {
  	set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "Verilog Header" $file_obj
}

foreach file [glob $origin_dir/ipbus/hdl/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/ipbus_core/hdl/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/ethernet/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/ipbus/slaves/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

foreach file [glob $origin_dir/hdl/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

# uncomment if vhdl files get added to self_trig_mode-only
#foreach file [glob $origin_dir/hdl/standard_mode_only/*.vhd] {
#    set file [file normalize $file]
#	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
#	set_property "file_type" "VHDL" $file_obj
#}

foreach file [glob $origin_dir/DAQ_Link_7S/*.vhd] {
    set file [file normalize $file]
	set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
	set_property "file_type" "VHDL" $file_obj
}

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "wfd_top" $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Create 'constrs_impl_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_impl_1] ""]} {
  create_fileset -constrset constrs_impl_1
}

set cflist [glob $origin_dir/constraints/standard/ios.xdc \
                 $origin_dir/constraints/standard/timing.xdc \
                 $origin_dir/constraints/synthesis.xdc \
                 $origin_dir/constraints/bitstream.xdc]

set ciflist [glob $origin_dir/constraints/standard/ios.xdc \
                  $origin_dir/constraints/standard/timing.xdc \
                  $origin_dir/constraints/standard/timing_impl.xdc \
                  $origin_dir/constraints/synthesis.xdc \
                  $origin_dir/constraints/bitstream.xdc]

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
  create_run -name synth_1 -part xc7k160tfbg676-1 -flow {Vivado Synthesis 2023} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2023" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" "xc7k160tfbg676-1" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7k160tfbg676-1 -flow {Vivado Implementation 2023} -strategy "Vivado Implementation Defaults" -constrset constrs_impl_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2023" [get_runs impl_1]
  set_property constrset constrs_impl_1 [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" "xc7k160tfbg676-1" $obj
set_property "steps.write_bitstream.tcl.pre" "[file normalize "$origin_dir/scripts/get_version.tcl"]" $obj
set_property "steps.write_bitstream.tcl.post" "[file normalize "$origin_dir/scripts/export_bitstream.tcl"]" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created: WFD_Master"
