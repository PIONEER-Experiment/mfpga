global version
global tag

catch {set fptr [open [file dirname [info script]]/../hdl/constants.txt r]};
set contents [read -nonewline $fptr]; # Read the file contents
close $fptr;                          # Close the file since it has been read now
set splitCont [split $contents "\n"]; # Split the files contents on new line
foreach ele $splitCont {
  [regexp {MAJOR_REV\s*\d+'h(..)\s*} $ele -> major_rev]
  [regexp {MINOR_REV\s*\d+'h(..)\s*} $ele -> minor_rev]
  [regexp {PATCH_REV\s*\d+'h(..)\s*} $ele -> patch_rev]
}

set version "0x$major_rev$minor_rev$patch_rev"
set tag "0x4d$major_rev$minor_rev$patch_rev"
