// color: #1d1d1f
// variant: flat
// Flat 4010 adapter, left side (as mounted): blower on top, intake to the front.
include <lib/flat4010.scad>

translate([-36.05, 0, 0]) mirror([1, 0, 0]) adapter4010_flat();
