// Fan models for the preview only.

// 4010 blower like the Creality Ender 3 stock part-cooling fan: square 40 x 40 body with rounded corners,
// round intake on the outer face, outlet towards -Z at the +Y end. Profile in the YZ plane.
// body_y = [y0, y1] of the body, z0 = bottom edge (rests in the cradle), c = impeller axis [y, z],
// outlet = [y0, y1] of the outlet opening, ears = [y, z] of the mounting holes.
module blower_4010(x0, t, c, body_y, z0, outlet, ears, impeller = true) {
    side = body_y[1] - body_y[0];
    module profile() offset(r = 3.5) offset(delta = -3.5) translate([body_y[0], z0]) square([side, side]);
    module on_x(h, z = 0) translate([x0 + z, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = h) children();
    difference() {
        on_x(t) profile();
        // mounting holes
        for (o = ears) on_x(t + 2, -1) translate(o) circle(d = 3.4, $fn = 20);
        // impeller pocket, open on the outer face (1 mm back wall)
        on_x(t - 1.0, 1.0 + 0.01) translate(c) circle(d = 27, $fn = 64);
        // outlet
        translate([x0 + 1.2, outlet[0] + 0.3, z0 - 0.01]) cube([t - 2.4, outlet[1] - outlet[0] - 1.5, 5]);
    }
    // raised rim around the intake
    on_x(0.4, t) translate(c) difference() { circle(d = 31, $fn = 64); circle(d = 27, $fn = 64); }
    if (impeller) blower_4010_impeller(x0, t, c);
}

// Blower impeller (separate part so it can spin): axis parallel to X through (c[0], c[1]).
module blower_4010_impeller(x0, t, c) {
    module on_x(h, z = 0) translate([x0 + z, 0, 0]) rotate([90, 0, 90]) linear_extrude(height = h) children();
    // back disc, forward-curved blades (30 of them), hub and its label
    on_x(0.6, 1.05) translate(c) circle(d = 26, $fn = 64);
    on_x(t - 3.2, 1.6) translate(c) for (i = [0 : 29]) rotate(i * 12)
        translate([7.2, 0]) rotate(28) square([5.6, 0.7]);
    on_x(t - 2.4, 1.6) translate(c) circle(d = 11.5, $fn = 32);
    on_x(0.3, t - 0.8) translate(c) circle(d = 10.6, $fn = 32);
}

// 2510 axial fan: axis along +Z, intake face at z = 0, centred in XY.
module axial_2510(side = 25, height = 10, blades = true) {
    r_corner = 1.6;
    module rounded_square(l) offset(r = r_corner) square(l - 2 * r_corner, center = true);
    difference() {
        linear_extrude(height = height) rounded_square(side);
        // corner recess between the two flanges (this is what forms the mounting ears)
        translate([0, 0, 2]) linear_extrude(height = height - 4)
            difference() { square(side + 2, center = true); circle(d = side + 1.2, $fn = 64); }
        // blade opening
        translate([0, 0, -1]) cylinder(d = 23.6, h = height + 2, $fn = 64);
        // mounting holes (20 mm apart)
        for (x = [-10, 10], y = [-10, 10]) translate([x, y, -1]) cylinder(d = 2.6, h = height + 2, $fn = 16);
    }
    if (blades) axial_2510_rotor(height);
    // motor and motor-mount spokes on the back face
    translate([0, 0, height - 2.6]) cylinder(d = 10, h = 2.6, $fn = 40);
    translate([0, 0, height - 1.2]) for (a = [45, 165, 285]) rotate(a) translate([5, -0.6, 0]) cube([7.2, 1.2, 1.2]);
}

// 2510 hub and blades (separate part so it can spin): axis = Z.
module axial_2510_rotor(height = 10) {
    translate([0, 0, 0.8]) cylinder(d = 12, h = height - 3.6, $fn = 40);
    translate([0, 0, 1.2]) for (i = [0 : 6]) rotate(i * 360 / 7)
        linear_extrude(height = height - 3.6, twist = -32, slices = 6) translate([5.5, -0.5]) square([6.0, 1.0]);
}

// Flat variant: the same 4010 blower sitting on its bottom edge with the intake facing the front (-Y),
// like the 2510 hotend fan. x0 = inner side, y0 = front face (intake), z0 = bottom edge.
// Profile in the XZ plane, measured from (x0, z0): c = impeller axis, outlet = [from, to] along the bottom edge
// (at the inner end), ears = mounting holes. The outlet points down (-Z) into the adapter.
module blower_4010_front(x0, y0, z0, t = 10, side = 40, c = [21.2, 19.0], outlet = [1.2, 16.2],
                   ears = [[3.6, side - 3.6], [side - 3.6, 3.6]], impeller = true) {
    module profile() {
        offset(r = 3.5) offset(delta = -3.5) square([side, side]);
        square([outlet[1] + 1.2, 6]);                  // square corner where the outlet spout is
    }
    // w = 0 at the back face (y0 + t), w = t at the front face (y0)
    module on_y(h, w = 0) translate([x0, y0 + t, z0]) rotate([90, 0, 0]) translate([0, 0, w]) linear_extrude(height = h) children();
    difference() {
        on_y(t) profile();
        for (o = ears) on_y(t + 2, -1) translate(o) circle(d = 3.4, $fn = 20);   // mounting holes
        on_y(t - 1.0, 1.0 + 0.01) translate(c) circle(d = 27, $fn = 64);          // impeller pocket, open at the front
        translate([x0 + outlet[0], y0 + 1.2, z0 - 0.01]) cube([outlet[1] - outlet[0], t - 2.4, 5]);   // outlet
    }
    on_y(0.4, t) translate(c) difference() { circle(d = 31, $fn = 64); circle(d = 27, $fn = 64); }   // rim round the intake
    if (impeller) blower_4010_front_impeller(x0, y0, z0, t, c);
}

// Blower impeller (separate part so it can spin): axis parallel to Y through (x0 + c[0], z0 + c[1]).
module blower_4010_front_impeller(x0, y0, z0, t = 10, c = [21.2, 19.0]) {
    module on_y(h, w = 0) translate([x0, y0 + t, z0]) rotate([90, 0, 0]) translate([0, 0, w]) linear_extrude(height = h) children();
    // back disc, forward-curved blades (30 of them), hub and its label
    on_y(0.6, 1.05) translate(c) circle(d = 26, $fn = 64);
    on_y(t - 3.2, 1.6) translate(c) for (i = [0 : 29]) rotate(i * 12) translate([7.2, 0]) rotate(28) square([5.6, 0.7]);
    on_y(t - 2.4, 1.6) translate(c) circle(d = 11.5, $fn = 32);
    on_y(0.3, t - 0.8) translate(c) circle(d = 10.6, $fn = 32);
}
