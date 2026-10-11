// Flat variant of the 4010 adapter — Igneus V2 (Anet ET4/ET5)
// Remix of "IGNEUS V2 - E3D V6/VOLCANO" by Locos3D, CC BY-NC-SA 4.0
// https://www.thingiverse.com/thing:4178590
//
// The 4010 blower sits on top of the adapter with its intake facing the front (like the 2510 hotend fan),
// as low as possible: the fan pocket sits right on top of the nozzle that goes into the original 5015 duct.
// Same coordinate system as duct4010.scad (right-hand part, as mounted; Y- = front).
include <duct4010.scad>

/* [Flat variant] */
flat_floor    = 3.0;            // floor between the nozzle and the fan (mm)
flat_cradle_h = 8.0;            // cradle depth (mm): in this variant the fan is held by the cradle alone
flat_outlet   = [1.2, 16.2];    // fan outlet along its bottom edge, measured from the inner end (mm)
flat_fan_x0   = -0.6;           // inner side of the fan (just clear of the duct arm, whose face is at x = -2.8)
flat_fan_y0   = -19.4;          // front face of the fan (intake), centred over the nozzle
nozzle_top    = -9.85;          // top of the adapter nozzle, just above the duct socket
flat_z_seat   = nozzle_top + flat_floor;   // where the bottom edge of the fan rests

flat_cradle_x = [-2.8, flat_fan_x0 + fan_w + clearance + cradle_wall];
flat_cradle_y = [flat_fan_y0 - clearance - cradle_wall, flat_fan_y0 + fan_t + clearance + cradle_wall];
nozzle_in     = [[-1.45, -23.87], [11.15, -6.17]];   // inside of the nozzle: [x, y] min and max

// Nozzle of the original adapter (only the part that goes into the duct socket) with the close-fitting sleeve
module flat_nozzle() {
    intersection() { original_adapter(); translate([-3, -25.5, -14]) cube([16, 22, 14 + nozzle_top]); }
    translate([-2.8 + nozzle_clear, -25.0 + nozzle_clear, -11.8]) cube([15.3 - 2 * nozzle_clear, 20.0 - 2 * nozzle_clear, 1.95]);
}

// Floor over the top of the nozzle (stopping at y = -5.1, in front of the two ribs on the inside of the duct's
// back plate), and the cradle block on it, 0.15 mm above the top edges of the duct walls
module flat_body() {
    translate([x_ext[0], -24.9, nozzle_top]) cube([x_ext[1] - x_ext[0], 19.8, flat_floor]);
    translate([flat_cradle_x[0], flat_cradle_y[0], nozzle_top + 0.15])
        cube([flat_cradle_x[1] - flat_cradle_x[0], flat_cradle_y[1] - flat_cradle_y[0], flat_floor - 0.15 + flat_cradle_h]);
}

// Air path: through the nozzle, then a short taper into the fan outlet
module flat_air() {
    in_w = nozzle_in[1] - nozzle_in[0];
    translate([nozzle_in[0][0], nozzle_in[0][1], -16]) cube([in_w[0], in_w[1], 16 + nozzle_top + eps]);
    hull() {
        translate([nozzle_in[0][0], nozzle_in[0][1], nozzle_top]) cube([in_w[0], in_w[1], eps]);
        translate([flat_fan_x0 + flat_outlet[0], flat_fan_y0 + 1.0, flat_z_seat])
            cube([flat_outlet[1] - flat_outlet[0], fan_t - 2.0, eps]);
    }
}

module flat_pocket()
    translate([flat_fan_x0 - clearance, flat_fan_y0 - clearance, flat_z_seat])
        cube([fan_w + 2 * clearance, fan_t + 2 * clearance, flat_cradle_h + 40]);

// Plinth down to the flat back face of the duct (y = 0) so the one-piece duct prints lying down.
// It stays clear of the duct screw head on the arm (x < 3).
module flat_plinth()
    translate([3, flat_cradle_y[1] - eps, nozzle_top])
        cube([flat_cradle_x[1] - 3, -flat_cradle_y[1] + eps, flat_floor + flat_cradle_h]);

// Flat 4010 adapter for the original 5015 duct (separate part)
module adapter4010_flat()
    difference() {
        union() { flat_nozzle(); flat_body(); }
        flat_air();
        flat_pocket();
    }

// Flat variant of the one-piece duct: original duct + flat adapter + LED channel
module duct4010_flat()
    difference() {
        union() {
            original_duct();
            flat_nozzle();
            socket_fill();
            flat_body();
            flat_plinth();
            if (led) led_channel();
        }
        flat_air();
        flat_pocket();
    }

echo(str("Flat cradle: ", fan_w + 2 * clearance, " x ", fan_t + 2 * clearance, " mm, fan edge at z = ", flat_z_seat));
