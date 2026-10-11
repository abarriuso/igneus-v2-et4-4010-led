// color: #b9bec4
// variant: normal
// material: metal
// PREVIEW ONLY: M3 nuts (duct screws, in the body's nut pockets, and adapter screws under the blowers).
$fn = 32;
module nut(d = 6.35, h = 2.4) difference() { cylinder(d = d, h = h, $fn = 6); translate([0, 0, -0.1]) cylinder(d = 3, h = h + 0.2); }

// duct screws: nut dropped into the body's pocket, resting on a corner (the body is not symmetric:
// the left pocket sits 1.5 mm further out than the right one)
for (p = [[1, 15.3], [-1, 16.8]]) mirror([p[0] < 0 ? 1 : 0, 0, 0])
    translate([p[1], -4.39, 19.6]) rotate([0, 90, 0]) nut();
for (s = [1, -1]) mirror([s < 0 ? 1 : 0, 0, 0])
    translate([28.2, -9.51, 32.17]) rotate([0, -90, 0]) rotate([0, 0, 30]) nut();   // flat side down, clear of the duct ear
