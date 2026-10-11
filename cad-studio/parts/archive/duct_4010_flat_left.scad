// One-piece 4010 duct, flat variant, left side (as mounted). Built only for the downloads.
include <../lib/flat4010.scad>
// import paths resolve from this file's folder, one level deeper than parts/
DUCT  = "../../igneus/asm/duct_5015.stl";
ADAPT = "../../igneus/asm/adapter_4010_v2.stl";

translate([-36.05, 0, 0]) mirror([1, 0, 0]) duct4010_flat();
