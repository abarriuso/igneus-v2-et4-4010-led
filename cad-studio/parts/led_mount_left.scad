// color: #1d1d1f
// LED mount for the original duct — left side (as mounted)
include <lib/duct4010.scad>

translate([-36.05, 0, 0]) mirror([1, 0, 0]) led_mount();
