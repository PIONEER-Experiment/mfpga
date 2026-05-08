global version
global tag

catch {set fptr [open [file dirname [info script]]/../hdl/constants.vh r]};
set contents [read -nonewline $fptr]; # Read the file contents
close $fptr;                          # Close the file since it has been read now
set splitCont [split $contents "\n"]; # Split the files contents on new line
foreach ele $splitCont {
  [regexp {MAJOR_REV\s*=\s*\d+'h([0-9a-fA-F]+)} $ele -> major_rev]
  [regexp {MINOR_REV\s*=\s*\d+'h([0-9a-fA-F]+)} $ele -> minor_rev]
  [regexp {PATCH_REV\s*=\s*\d+'h([0-9a-fA-F]+)} $ele -> patch_rev]
}

puts $major_rev

set version "0x$major_rev$minor_rev$patch_rev"
set tag "0x4d$major_rev$minor_rev$patch_rev"
