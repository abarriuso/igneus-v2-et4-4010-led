// 25 mm fan (Anycubic Kobra X 2510 hotend fan) -> Locos3D's 30 mm fan clamp (Abrazadera_Adapter_Fan_30mm).
// Library: parameters and the fan_adapter() module, in its own local frame (z = 0 against the clamp).
//
// The clamp's 30 mm pattern (24 mm between holes) cannot hold the plate: those holes sit under the
// 25 mm fan and clash with its 20 mm pattern. Instead the plate has a tab on top that is held by the
// clamp's own two M3 screws (about 4 mm longer than before): bosses fill their counterbores and the
// heads sit flush in the tab. Two pins go into the lower 30 mm holes so the plate cannot turn.
$fn = 48;

/* [Fan — check yours with calipers] */
fan_side        = 25;    // fan size (mm)
fan_holes       = 20;    // distance between the fan's screw holes (mm)
fan_pilot       = 2.2;   // pilot hole for self-tapping M2.5 screws
fan_pilot_depth = 3.2;
fan_bore        = 23.6;  // air opening

/* [Clamp — measured on Abrazadera_Adapter_Fan_30mm] */
face      = -27.06;       // front face of the clamp plate (view Y)
cz        = -5.05;        // centre of the 30 mm pattern (view Z)
m3        = [11, 15.65];  // clamp screws at x = ±m3[0], z = m3[1]
cb_d      = 7.08;         // counterbore of those screws
cb_depth  = 3.0;
pin_holes = 12;           // 30 mm pattern at ±12 around the centre; the lower two take the pins
pin_d     = 2.4;
pin_h     = 3.0;

/* [Adapter] */
plate_t    = 4.0;
boss_clear = 0.15;        // per side, inside the counterbores
head_d     = 6.2;         // recess for the M3 socket heads
head_depth = 3.2;
margin     = 1.6;         // wall around the head recesses

x_half = m3[0] + head_d / 2 + margin;
z_top  = m3[1] + head_d / 2 + margin;
z_bot  = cz - fan_side / 2 - 2.5;

module fan_adapter() {
    difference() {
        union() {
            // plate, z = 0 against the clamp, z = plate_t on the fan side
            linear_extrude(height = plate_t) offset(r = 2) offset(delta = -2)
                translate([-x_half, z_bot]) square([2 * x_half, z_top - z_bot]);
            // bosses that fill the clamp counterbores
            for (s = [-1, 1]) translate([s * m3[0], m3[1], -(cb_depth - 0.2)])
                cylinder(d = cb_d - 2 * boss_clear, h = cb_depth - 0.2 + 0.01);
            // anti-rotation pins
            for (s = [-1, 1]) translate([s * pin_holes, cz - pin_holes, -pin_h])
                cylinder(d = pin_d, h = pin_h + 0.01, $fn = 24);
        }
        translate([0, cz, -1]) cylinder(d = fan_bore, h = plate_t + 2);
        for (s = [-1, 1]) translate([s * m3[0], m3[1], 0]) {
            translate([0, 0, -cb_depth - 1]) cylinder(d = 3.4, h = cb_depth + plate_t + 2);
            translate([0, 0, plate_t - head_depth]) cylinder(d = head_d, h = head_depth + 1);
        }
        for (x = [-1, 1], y = [-1, 1]) translate([x * fan_holes / 2, cz + y * fan_holes / 2, plate_t - fan_pilot_depth])
            cylinder(d = fan_pilot, h = fan_pilot_depth + 1, $fn = 20);
    }
}
