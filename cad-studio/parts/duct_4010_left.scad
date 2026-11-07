// color: #1d1d1f
// variant: onepiece
// One-piece 4010 duct with the LED channel, left side (as mounted): mirror of the right one.
include <lib/duct4010.scad>

translate([-36.05, 0, 0]) mirror([1, 0, 0]) duct4010();
