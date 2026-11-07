// 4010 blower parts for the original 5015 part-cooling duct — Igneus V2 (Anet ET4/ET5)
// Remix of "IGNEUS V2 - E3D V6/VOLCANO" by Locos3D, CC BY-NC-SA 4.0
// https://www.thingiverse.com/thing:4178590
//
// Coordinate system = as mounted on the printer (right-hand part):
//   Z+ up, X- towards the body/nozzle, Y = depth (the fan sits towards Y-).
// The 4010 adapter plugs into the socket on top of the original 5015 duct, exactly where Locos3D's own
// 4010 adapter goes; the one-piece duct (lib/duct_body.scad) replaces both. The body is not modified.
include <duct_body.scad>

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

$fn = 48;
eps = 0.01;

DUCT = "../igneus/asm/duct_5015.stl";   // only the LED mount needs it: it is carved against the original duct
module original_duct() import(DUCT, convexity = 6);

cradle_wall = 2.0;               // walls of the cradle
cradle_floor = 3.0;              // floor under the fan
x_ext       = [-2.64, 12.34];    // width of the adapter (same as Locos3D's)
socket      = [[-2.8, 12.5], [-25.0, -5.0]];   // socket on top of the original duct (X, Y)
socket_key  = [[3.2, 6.5], -3.5];               // notch at the back of the socket (X range, back face)
nozzle_in   = [[-1.46, -23.77], [11.15, -6.17]];   // inside of the adapter nozzle: [x, y] min and max
nozzle_top  = duct_top;          // the socket rim
nozzle_bot  = -13.85;            // bottom of the adapter nozzle (4 mm into the socket)

// Fan pocket and cradle of the normal version (fan standing on its edge, intake facing out)
function pocket_x() = [fan_cx - fan_t / 2 - clearance, fan_cx + fan_t / 2 + clearance];
function pocket_y() = [fan_cy - fan_w / 2 - clearance, fan_cy + fan_w / 2 + clearance];
// opening under the blower outlet (it is at the back end of the edge, over the duct)
function outlet_x() = [pocket_x()[0] + 1, pocket_x()[1] - 1];
function outlet_y() = [-28.5, pocket_y()[1] - 1];

// The blower's intake has a ring 0.4 mm proud of its face (d 31): the cradle wall it faces gets a shallow
// relief so it does not press on it. Impeller axis 1.2 mm in front of the centre of the edge, 1 mm below mid-height.
intake_rim = 32;
module fan_pocket() {
    translate([pocket_x()[0], pocket_y()[0], z_seat]) cube([pocket_x()[1] - pocket_x()[0], pocket_y()[1] - pocket_y()[0], 60]);
    translate([pocket_x()[1] - eps, fan_cy - 1.2, z_seat + fan_w / 2 - 1])
        rotate([0, 90, 0]) cylinder(d = intake_rim, h = 0.5 + eps, $fn = 64);
}

// Nozzle that plugs into the socket of the original duct, with its air passage open.
// Close fit (nozzle_clear) only in the top 2 mm: lower down the socket's outer wall bulges in slightly.
module nozzle() {
    c = nozzle_clear;
    difference() {
        union() {
            translate([-2.64, socket[1][0] + 0.03, nozzle_bot]) cube([14.98, socket[1][1] - socket[1][0] - 0.04, nozzle_top - nozzle_bot + 0.2]);
            translate([socket_key[0][0] + 0.15, -5.1, nozzle_bot]) cube([socket_key[0][1] - socket_key[0][0] - 0.3, 5.1 + socket_key[1] - 0.19, nozzle_top - nozzle_bot + 0.2]);
            translate([socket[0][0] + c, socket[1][0] + c, nozzle_top - 1.95]) cube([socket[0][1] - socket[0][0] - 2 * c, socket[1][1] - socket[1][0] - 2 * c, 1.95 + eps]);
        }
        translate([nozzle_in[0][0], nozzle_in[0][1], nozzle_bot - 1]) cube([nozzle_in[1][0] - nozzle_in[0][0], nozzle_in[1][1] - nozzle_in[0][1], nozzle_top - nozzle_bot + 1 + eps]);
    }
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
    rotate([90, 0, 0]) linear_extrude(height = max(led_l + 1, duct_d)) led_profile();

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

// 4010 adapter -> original 5015 duct, as a separate part. Made-to-measure cradle on a nozzle that fits the
// duct's socket. It prints standing on its nozzle without supports: the cradle is carried by a 45° underside
// that comes down in front of the duct to a foot, and the foot and nozzle hug the duct's front wall.
adapter_back = socket[1][1] - 0.05;    // back face, against the duct's back plate (it rises above the socket)
arm_y        = [-14.97, -4.99];        // arm with the M3 screw to the duct's ear (as in Locos3D's adapter)
arm_hole     = [-9.51, 32.17];         // Y, Z of the screw
module adapter4010() {
    zf = z_seat - cradle_floor;   zt = z_seat + cradle_h;
    y_front = pocket_y()[0] - cradle_wall;
    y_foot  = -duct_d - 0.3;                       // just in front of the duct's front wall
    y_toe   = y_front + (zf - nozzle_bot);         // 45° from the front of the cradle down to the bed
    z_rim   = nozzle_top + 0.05;                   // underside, resting on the rim of the duct
    difference() {
        union() {
            nozzle();
            // body: side profile extruded across the width
            translate([x_ext[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = x_ext[1] - x_ext[0])
                polygon([[adapter_back, z_rim], [adapter_back, zt], [y_front, zt], [y_front, zf],
                         [y_toe, nozzle_bot], [y_foot, nozzle_bot], [y_foot, z_rim]]);
            // arm up to the ear of the duct, countersunk screw on the fan side
            translate([x_ext[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = 2.0)
                hull() {
                    translate([arm_y[0], zt - 1]) square([arm_y[1] - arm_y[0], 1]);
                    translate([arm_hole[0] - 0.47, arm_hole[1] + 0.33]) circle(d = arm_y[1] - arm_y[0]);
                }
        }
        // air path: through the nozzle, then a taper to the outlet under the fan
        hull() {
            translate([nozzle_in[0][0], nozzle_in[0][1], nozzle_top - eps]) cube([nozzle_in[1][0] - nozzle_in[0][0], nozzle_in[1][1] - nozzle_in[0][1], eps]);
            translate([outlet_x()[0], outlet_y()[0], zf]) cube([outlet_x()[1] - outlet_x()[0], outlet_y()[1] - outlet_y()[0], eps]);
        }
        translate([outlet_x()[0], outlet_y()[0], zf - eps]) cube([outlet_x()[1] - outlet_x()[0], outlet_y()[1] - outlet_y()[0], cradle_floor + 2 * eps]);
        fan_pocket();
        // M3 countersunk screw: arm + duct ear, the head flush on the fan side
        translate([x_ext[0] - 1, arm_hole[0], arm_hole[1]]) rotate([0, 90, 0]) cylinder(d = 3.4, h = 5, $fn = 24);
        translate([x_ext[0] + 2.0 + eps, arm_hole[0], arm_hole[1]]) rotate([0, -90, 0]) cylinder(d1 = 5.9, d2 = 3.4, h = 1.25, $fn = 24);
    }
}

// One-piece duct, normal version: duct, cradle and mounting arm drawn as one part, with the LED channel.
// Prints lying on its flat back face without supports.
cradle_cut = 1.8;   // the back edge of the cradle is chamfered at 45° from here (keeps the hex key of the
                    // height screw clear and lets the cradle rise from the bed)
module duct4010() {
    px = pocket_x();   py = pocket_y();
    cx = [px[0] - cradle_wall, px[1] + cradle_wall];
    zf = z_seat - cradle_floor;   zt = z_seat + cradle_h;
    y_front = py[0] - cradle_wall;
    neck = zf - 2.2;                                   // the duct walls step in to the cradle above here
    ox = outlet_x();   oy = outlet_y();
    // air path from the blower outlet down to the duct
    t = (-1 - duct_top) / (zf - duct_top);
    plenum = [
        sec([ox[0], z_seat + 0.5], [ox[1], z_seat + 0.5], oy[1], oy[0]),
        sec([ox[0], zf], [ox[1], zf], oy[1], oy[0]),
        sec([lerp(near_in_x, ox[0], t), -1], [lerp(far_in_x, ox[1], t), -1], lerp(ch_back, oy[1], t), ch_front - 0.5)];
    difference() {
        union() {
            duct_shell(neck);
            // the walls step in to the cradle at 45°
            hull() for (s = [[[near_out_x, far_out_x], neck - eps], [cx, zf]])
                translate([s[0][0], -duct_d, s[1]]) cube([s[0][1] - s[0][0], duct_d, eps]);
            // gusset under the part of the cradle that overhangs the front of the duct
            translate([cx[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = cx[1] - cx[0])
                polygon([[-duct_d + 1, -1], [-duct_d, -1], [-duct_d - (zf + 1), zf + eps], [-duct_d + 1, zf + eps]]);
            // cradle, its back edge chamfered at 45° down to the back face
            intersection() {
                translate([cx[0], y_front, zf]) cube([cx[1] - cx[0], -y_front, zt - zf]);
                translate([cx[0] - 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = cx[1] - cx[0] + 2)
                    polygon([[0, cradle_cut], [-60, cradle_cut + 60], [-60, -10], [0, -10]]);
            }
            mount_arm();
            if (led) led_channel();
        }
        loft(concat(plenum, duct_secs()));
        fan_pocket();
        slot();
    }
}

echo(str("Cradle: ", fan_t + 2 * clearance, " x ", fan_w + 2 * clearance, " mm, depth ", cradle_h));
