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
flat_front_h  = 5.0;            // one-piece duct: front wall of the cradle, below the blower's intake (mm)
flat_outlet   = [1.2, 16.2];    // fan outlet along its bottom edge, measured from the inner end (mm)
flat_fan_x0   = -0.6;           // inner side of the fan (just clear of the duct arm, whose face is at x = -2.8)
flat_fan_y0   = -19.4;          // front face of the fan (intake), centred over the nozzle
flat_z_seat   = nozzle_top + flat_floor;   // where the bottom edge of the fan rests

flat_cradle_x = [-2.8, flat_fan_x0 + fan_w + clearance + cradle_wall];
flat_cradle_y = [flat_fan_y0 - clearance - cradle_wall, flat_fan_y0 + fan_t + clearance + cradle_wall];
function flat_out_x() = [flat_fan_x0 + flat_outlet[0], flat_fan_x0 + flat_outlet[1]];
function flat_out_y() = [flat_fan_y0 + 1.0, flat_fan_y0 + fan_t - 1.0];

// Floor over the top of the nozzle (stopping at y = -5.1, in front of the two ribs on the inside of the duct's
// back plate), and the cradle block on it, 0.15 mm above the top edges of the duct walls. Where the floor is
// wider than the cradle it narrows at 45° (or steeper) up to it, and a wedge in the socket's notch covers the
// top of the key tab: printed upside down, nothing sticks out into the air.
module flat_body() {
    w = x_ext[1] - x_ext[0];
    hull() {
        translate([x_ext[0], -24.9, nozzle_top]) cube([w, 19.8, eps]);
        translate([x_ext[0], flat_cradle_y[0], nozzle_top + 3.3]) cube([w, flat_cradle_y[1] - flat_cradle_y[0], eps]);
    }
    kx = [socket_key[0][0] + 0.15, socket_key[0][1] - 0.15];
    ky = socket_key[1] - 0.19;                   // back face of the key tab
    translate([kx[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = kx[1] - kx[0])
        polygon([[-7.3, nozzle_top], [ky, nozzle_top], [ky, nozzle_top + 0.2], [-7.3, nozzle_top + 0.2 + ky + 7.3]]);
    translate([flat_cradle_x[0], flat_cradle_y[0], nozzle_top + 0.15])
        cube([flat_cradle_x[1] - flat_cradle_x[0], flat_cradle_y[1] - flat_cradle_y[0], flat_floor - 0.15 + flat_cradle_h]);
}

// Air path: through the nozzle, then a short taper into the fan outlet
module flat_air() {
    in_w = nozzle_in[1] - nozzle_in[0];
    translate([nozzle_in[0][0], nozzle_in[0][1], -16]) cube([in_w[0], in_w[1], 16 + nozzle_top + eps]);
    hull() {
        translate([nozzle_in[0][0], nozzle_in[0][1], nozzle_top]) cube([in_w[0], in_w[1], eps]);
        translate([flat_out_x()[0], flat_out_y()[0], flat_z_seat])
            cube([flat_out_x()[1] - flat_out_x()[0], flat_out_y()[1] - flat_out_y()[0], eps]);
    }
}

module flat_pocket() {
    translate([flat_fan_x0 - clearance, flat_fan_y0 - clearance, flat_z_seat])
        cube([fan_w + 2 * clearance, fan_t + 2 * clearance, flat_cradle_h + 40]);
    // relief for the ring round the intake (see fan_pocket); impeller axis 21.2 mm from the inner end, 19 mm up
    translate([flat_fan_x0 + 21.2, flat_fan_y0 - clearance + eps, flat_z_seat + 19])
        rotate([90, 0, 0]) cylinder(d = intake_rim, h = 0.5 + eps, $fn = 64);
}

// Flat 4010 adapter for the original 5015 duct (separate part). Prints upside down without supports.
module adapter4010_flat()
    difference() {
        union() { nozzle(); flat_body(); }
        flat_air();
        flat_pocket();
    }

// One-piece duct, flat version. Front view (XZ): the duct, and the tray that carries the blower sweeping out
// of the duct's outer wall on a fillet, its ends rounded
module flat_body_xz() {
    zt = flat_z_seat + flat_cradle_h;
    duct_outline(flat_z_seat);
    polygon(rpoly([[near_out_x, ch_far_c[1]], [far_out_x, ch_far_c[1]], [far_out_x, duct_top, 4.5],
                   [flat_cradle_x[1], duct_top, 5], [flat_cradle_x[1], zt, 3], [near_out_x, zt, 1.5]]));
}
// Side view (YZ, as [y, z]): the tray stands on the floor over the duct, set back from its front on a rounded
// step, and runs back to the back face
module flat_body_yz() {
    zt = flat_z_seat + flat_cradle_h;
    polygon(rpoly([[2, -60], [2, zt + 5], [flat_cradle_y[0], zt + 5], [flat_cradle_y[0], flat_z_seat, 3.5],
                   [-duct_d, flat_z_seat, 2.5], [-duct_d, -60]]));
}
// The front wall of the cradle is cut down to flat_front_h between the end walls, below the blower's intake,
// its top front edge rounded
module flat_front_notch() {
    px = [flat_fan_x0 - clearance, flat_fan_x0 + fan_w + clearance];
    zf = flat_z_seat + min(flat_front_h, flat_cradle_h);
    y0 = flat_cradle_y[0];   y1 = flat_fan_y0 - clearance + eps;
    translate([px[0], 0, 0]) rotate([90, 0, 90]) linear_extrude(height = px[1] - px[0])
        polygon(rpoly([[y1, zf], [y0, zf, 1.5], [y0, zf - 5], [y0 - 5, zf - 5], [y0 - 5, zf + 30], [y1, zf + 30]]));
}

// Duct, floor, cradle and mounting arm drawn as one part, with the LED channel. Prints lying on its flat back
// face without supports; the low front wall of the cradle is a bridge between the two end walls.
module duct4010_flat() {
    ox = flat_out_x();   oy = flat_out_y();
    plenum = [sec([ox[0], flat_z_seat + 0.5], [ox[1], flat_z_seat + 0.5], oy[1], oy[0], 0),
              sec([ox[0], flat_z_seat], [ox[1], flat_z_seat], oy[1], oy[0], 0)];
    difference() {
        union() {
            soft() { flat_body_xz(); flat_body_yz(); }   // duct, floor and cradle in one piece, every edge rounded
            mount_arm(flat_z_seat + flat_cradle_h);     // the spine flush with the top of the cradle
            if (led) led_channel();
        }
        loft(concat(plenum, duct_secs()));
        flat_pocket();
        flat_front_notch();
        slot();
    }
}

echo(str("Flat cradle: ", fan_w + 2 * clearance, " x ", fan_t + 2 * clearance, " mm, fan edge at z = ", flat_z_seat));
