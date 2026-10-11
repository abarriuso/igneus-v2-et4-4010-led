// color: #f2f1ec
// PREVIEW ONLY: sample LED strips placed in the channels. Not printed.
include <lib/duct4010.scad>

translate([36.05, 0, 0]) led_strip();
translate([-36.05, 0, 0]) mirror([1, 0, 0]) led_strip();
