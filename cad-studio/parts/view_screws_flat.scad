// color: #b9bec4
// variant: flat
// material: metal
// PREVIEW ONLY (flat variant, no blower ear screw): M3 screws (and the 2510's M2.5) in place. The nuts are in view_nuts.scad.
$fn = 32;

module socket_cap(l, d = 3, head = 5.5, h = 3) {   // socket head cap screw pointing to +Z, head at z = 0
    difference() {
        translate([0, 0, -h]) cylinder(d = head, h = h);
        translate([0, 0, -h - 0.01]) cylinder(d = 2.9, h = 1.6, $fn = 6);
    }
    cylinder(d = d, h = l);
}
module along_x() rotate([0, -90, 0]) children();   // +Z -> -X
module along_y() rotate([-90, 0, 0]) children();   // +Z -> +Y

// M3x14 for each duct: head on the outer face of the duct arm, through its height slot into the body hole,
// with a nut in the body's nut pocket (the body has a separate hole on each side, not a through hole)
for (s = [1, -1]) mirror([s < 0 ? 1 : 0, 0, 0])
    translate([28.3, -4.39, 19.39]) along_x() socket_cap(14);

// M3 from the front clamp to the body, through the tab of the 25 -> 30 adapter: heads flush in the tab
// (bearing face at 4 - 3.2 mm from the clamp face), about 4 mm longer than without the adapter
for (x = [-11, 11]) translate([x, -27.06 - 0.8, 15.65]) along_y() socket_cap(24);

// 2510 to the adapter: 4 self-tapping M2.5 x 12
for (x = [-10, 10], z = [-15.05, 4.95]) translate([x, -41.06, z]) along_y() socket_cap(12, d = 2.5, head = 4.5, h = 2.5);
