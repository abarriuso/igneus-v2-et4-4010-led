// Simplified E3D V6, placed according to the Igneus body's hotend seat.
// The nozzle tip ends up ~2 mm below the ducts (adjustable with the height slot).
$fn = 48;
v6_axis = [0, -14.06];
v6_top = 21.7;                       // top of the groove mount
v6_hs_bottom = v6_top - 42.7;        // bottom of the heatsink
v6_block_top = v6_hs_bottom - 2.1;   // top of the heater block

module v6_heatsink() translate([v6_axis[0], v6_axis[1], 0]) {
    translate([0, 0, v6_top - 3.7]) cylinder(d = 16, h = 3.7);
    translate([0, 0, v6_top - 9.7]) cylinder(d = 12, h = 6 + 0.01);
    translate([0, 0, v6_top - 12.7]) cylinder(d = 16, h = 3 + 0.01);
    translate([0, 0, v6_hs_bottom]) cylinder(d = 10, h = 30 + 0.01);
    for (i = [0 : 10]) translate([0, 0, v6_top - 12.7 - 2.2 - i * 2.55]) cylinder(d = 22.3, h = 1.1);
    translate([0, 0, v6_hs_bottom]) cylinder(d = 16, h = 1.2);
    translate([0, 0, v6_block_top - 0.01]) cylinder(d = 7, h = 2.2);   // heatbreak
}
module v6_heater_block() translate([v6_axis[0], v6_axis[1], 0])
    translate([-8, -8, v6_block_top - 11.5]) cube([16, 20, 11.5]);
module v6_heater_cartridge() translate([v6_axis[0], v6_axis[1], 0]) {
    translate([-10, 7, v6_block_top - 5.75]) rotate([0, 90, 0]) cylinder(d = 6, h = 20);
    translate([8, -4.5, v6_block_top - 8]) rotate([0, 90, 0]) cylinder(d = 3, h = 2);   // thermistor
}
module v6_nozzle() translate([v6_axis[0], v6_axis[1], 0]) {
    translate([0, 0, v6_block_top - 11.5 - 3]) cylinder(d = 8.08, h = 3 + 0.01, $fn = 6);
    translate([0, 0, v6_block_top - 11.5 - 5]) cylinder(d1 = 1, d2 = 5, h = 2 + 0.01);
}
