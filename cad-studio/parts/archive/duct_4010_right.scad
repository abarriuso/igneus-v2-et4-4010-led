// One-piece 4010 duct — right side (as mounted). Archived: replaced by adapter + LED mount.
include <../lib/duct4010.scad>
// import paths resolve from this file's folder, one level deeper than parts/
DUCT  = "../../igneus/asm/duct_5015.stl";
ADAPT = "../../igneus/asm/adapter_4010_v2.stl";

// Shifted so it shows mounted next to the left one (the slicer re-centres it anyway)
translate([36.05, 0, 0]) duct4010();
