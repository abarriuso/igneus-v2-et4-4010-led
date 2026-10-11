// 4010 blower parts for the original 5015 part-cooling duct — Igneus V2 (Anet ET4/ET5)
// Remix of "IGNEUS V2 - E3D V6/VOLCANO" by Locos3D, CC BY-NC-SA 4.0
// https://www.thingiverse.com/thing:4178590
//
// Coordinate system = as mounted on the printer (right-hand part):
//   Z+ up, X- towards the body/nozzle, Y = depth (the fan sits towards Y-).
// The original 5015 duct and 4010 V2 adapter are reused exactly where they sit when mounted,
// so the mounting arm and the air outlet match the original. The body is not modified.

/* [4010 fan — measure yours with calipers] */
fan_t     = 10.0;   // fan thickness (mm)
fan_w     = 40.0;   // length of the edge that sits in the cradle (mm)
clearance = 0.20;   // cradle clearance per side (mm)
cradle_h  = 6.0;    // cradle depth (mm)

/* [LED strip — 24 V, one lensed LED per segment (A1-style light strip)] */
led       = true;   // add the LED strip channel
led_w     = 10.0;   // strip width (mm) — confirm with calipers
led_t     = 0.8;    // PCB thickness with adhesive, WITHOUT the lenses (mm)
led_lens  = 8.0;    // LED lens diameter (mm); they stick out through the opening
led_n     = 2;      // LEDs per duct
led_pitch = 18.1;   // LED spacing = distance between cut marks (mm)
led_ang   = 15;     // beam tilt: 0 = level towards the nozzle, 90 = straight down
led_pos   = [-8.8, -20.5];  // channel centre in X,Z (inner face of the duct)
led_clear = 0.3;    // strip clearance in the channel
led_l     = led_n * led_pitch;   // strip length

/* [LED mount for the original duct (separate part)] */
mount_clear = 0.15;           // clearance against the duct
tab_t       = 1.6;            // thickness of the tab that rests on the front face
tab_x       = 0;              // how far the tab reaches over the front face
plate_x     = [-7.2, -2.9];   // contact plate; carved against the duct wall
plate_z     = [-20.5, -14.35];
zip_tie     = [1.6, 3.4];     // slot for the kit's zip tie (thickness, width)
zip_tie_x   = -6.0;           // outer face of the zip-tie tunnel
zip_tie_z   = -19.0;          // bottom of the tunnel

/* [4010 adapter (separate part)] */
nozzle_clear = 0.10;          // per-side clearance of the adapter nozzle inside the duct (original: 0.165)

/* [Internal: fan position in the original] */
fan_cx = 4.57;      // centre of the original fan pocket in X
fan_cy = -28.26;    // centre of the original fan pocket in Y
z_seat = 5.55;      // where the fan edge rests
ledge  = 3.0;       // ledge at both ends of the edge so the fan does not sink

$fn = 48;
eps = 0.01;

DUCT  = "../igneus/asm/duct_5015.stl";
ADAPT = "../igneus/asm/adapter_4010_v2.stl";

module original_duct()    import(DUCT, convexity = 6);
module original_adapter() import(ADAPT, convexity = 6);

cradle_wall = 2.0;               // wall at both ends of the cradle
x_ext       = [-2.64, 12.34];    // outer faces of the original adapter

// Fills the gap between the adapter nozzle and the duct socket (one piece, no leaks)
module socket_fill() {
    translate([-2.85, -25.05, -13.85]) cube([15.4, 21.6, 5.0]);
    translate([x_ext[0], -3.75, -13.85]) cube([x_ext[1] - x_ext[0], 0.3, 14.85]);   // slit next to the plate
}

// Solid block replacing the original fan pocket (and its slots) so the cradle can be cut to size
module cradle_block() {
    l = fan_w + 2 * clearance;
    translate([x_ext[0], fan_cy - l / 2 - cradle_wall, z_seat - 3])
        cube([x_ext[1] - x_ext[0], l + 2 * cradle_wall, 3 + cradle_h]);
}

// Plinth down to the flat face of the duct (y = 0) so it prints lying down without supports,
// and joins the adapter arm to the duct arm (they used to be two parts 0.16 mm apart)
module plinth() {
    translate([x_ext[0], -3.75, -13.85]) cube([x_ext[1] - x_ext[0], 3.75, 13.85 + z_seat + cradle_h]);
    translate([-2.85, -11.2, 0.5]) cube([2.85 - 0.64, 11.2, 34.5]);
}

// M3 hole for the screw that fixes duct + fan to the body (same axis as the original)
screw_axis = [-9.51, 32.17];   // Y, Z
module holes() {
    translate([-14, screw_axis[0], screw_axis[1]]) rotate([0, 90, 0]) cylinder(d = 3.4, h = 14);
    translate([x_ext[0] - eps, screw_axis[0], screw_axis[1]]) rotate([0, 90, 0]) cylinder(d = 5.69, h = 2.0 + 2 * eps);
    // Height-adjustment slot of the original arm, reopened through the joined arm
    hull() for (z = [9.09 + 1.7, 25.32 - 1.7])
        translate([-3.2, -4.28, z]) rotate([0, 90, 0]) cylinder(d = 3.4, h = 2.7);
}

// Air passage through the nozzle into the duct
module air_passage()
    translate([-1.45, -23.87, -16]) cube([12.6, 17.7, 8]);

// New made-to-measure cradle + air outlet under the fan
module new_cradle() {
    w = fan_t + 2 * clearance;
    l = fan_w + 2 * clearance;
    translate([fan_cx - w / 2, fan_cy - l / 2, z_seat]) cube([w, l, cradle_h + 40]);
    translate([fan_cx - w / 2 + 1, fan_cy - l / 2 + ledge, z_seat - 4]) cube([w - 2, l - 2 * ledge, 4 + eps]);
}

// LED strip channel: straight channel with snap-in lips, joined to the inner wall of the duct.
// 2D profile in the XZ plane; light leaves through the open side (+v before rotating).
module led_profile() {
    w = led_w + 2 * led_clear;  t = led_t + led_clear;
    base = 1.2;  wall = 1.2;  lip_t = 0.8;
    lip = min(0.8, (w - led_lens - 0.6) / 2);   // the lips must not cover the lenses
    phi = 90 + led_ang;   // turns +v towards (-cos a, -sin a)
    // channel = one block minus the strip pocket and the opening between the lips (no parts that only touch
    // along an edge, which newer OpenSCAD versions reject as an open mesh once extruded)
    union() {
        hull() {
            translate(led_pos) rotate(phi) translate([-(w / 2 + wall), -base]) square([w + 2 * wall, base]);
            translate([-3.6, -21]) square([0.6, 6]);   // anchor on the duct wall
        }
        translate(led_pos) rotate(phi) difference() {
            translate([-(w / 2 + wall), -base]) square([w + 2 * wall, base + t + lip_t]);
            translate([-w / 2, 0]) square([w, t]);                                   // strip pocket
            translate([-(w / 2 - lip), t - eps]) square([w - 2 * lip, lip_t + 1]);   // opening between the lips
        }
    }
}

// Starts at the flat face (y = 0) so it prints resting on it; at least the full depth of the duct
module led_channel()
    rotate([90, 0, 0]) linear_extrude(height = max(led_l + 1, 28)) led_profile();

// Sample LED strip placed in the channel (preview only, not printed)
module led_strip() {
    phi = 90 + led_ang;
    rotate([90, 0, 0]) translate([0, 0, 0.5]) linear_extrude(height = led_l)
        translate(led_pos) rotate(phi) translate([-led_w / 2, 0]) square([led_w, led_t]);
    for (i = [0 : led_n - 1])   // lenses: axis along the light direction
        translate([led_pos[0], -(0.5 + led_pitch / 2 + i * led_pitch), led_pos[1]])
            rotate([0, -phi, 0]) translate([0, 0, led_t]) {
                cylinder(d = led_lens, h = 1.0);
                translate([0, 0, 1.0]) scale([1, 1, 0.45]) sphere(d = led_lens);
            }
}

// LED mount that fits the original 5015 duct (no need to reprint it).
// Rests on the inner wall with the tab on the front face, and is tightened with a zip tie
// that wraps around the duct through the tunnel in the plate.
module led_mount() {
    length = max(led_l + 1, 28);
    difference() {
        union() {
            translate([0, tab_t, 0]) rotate([90, 0, 0])
                linear_extrude(height = length + tab_t) led_profile();
            translate([plate_x[0], -28, plate_z[0]])
                cube([plate_x[1] - plate_x[0], 28 + tab_t, plate_z[1] - plate_z[0]]);
            translate([plate_x[0], mount_clear, plate_z[0]])
                cube([tab_x - plate_x[0], tab_t - mount_clear, plate_z[1] - plate_z[0]]);
        }
        // clearance against the duct on every side it touches: inner wall (X), front and back faces (Y), underside (Z)
        original_duct();
        for (o = [[-mount_clear, 0, 0], [0, mount_clear, 0], [0, -mount_clear, 0], [0, 0, -mount_clear]])
            translate(o) original_duct();
        // zip-tie tunnel, front to back
        translate([zip_tie_x, -28 - 1, zip_tie_z]) cube([zip_tie[0], 28 + tab_t + 2, zip_tie[1]]);
        // rear exit: the zip tie turns towards the back face of the duct
        translate([zip_tie_x, -28 - 1.6, zip_tie_z]) cube([plate_x[1] - zip_tie_x + 0.2, 1.6 + eps, zip_tie[1]]);
    }
}

// 4010 adapter -> original 5015 duct, as a separate part: clean made-to-measure cradle
// and a nozzle widened in X so it does not wobble inside the duct.
module adapter4010() {
    difference() {
        union() {
            original_adapter();
            cradle_block();
            // nozzle widened to the duct socket (15.3 x 20.0 mm at y -25..-5) minus the clearance on every side,
            // only in the top 2 mm of the socket: lower down the duct has inner ribs that the original nozzle steps around
            translate([-2.8 + nozzle_clear, -25.0 + nozzle_clear, -11.8]) cube([15.3 - 2 * nozzle_clear, 20.0 - 2 * nozzle_clear, 1.95]);
        }
        air_passage();
        new_cradle();
    }
}

// Archived: duct and 4010 adapter merged into a single part, with the LED channel built in
module duct4010() {
    difference() {
        union() {
            original_duct();
            original_adapter();
            socket_fill();
            cradle_block();
            plinth();
            if (led) led_channel();
        }
        air_passage();
        new_cradle();
        holes();
    }
}

echo(str("Cradle: ", fan_t + 2 * clearance, " x ", fan_w + 2 * clearance, " mm, depth ", cradle_h));
