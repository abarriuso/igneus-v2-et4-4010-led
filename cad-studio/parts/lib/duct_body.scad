// Body of the one-piece 4010 ducts — Igneus V2 (Anet ET4/ET5)
// Remix of "IGNEUS V2 - E3D V6/VOLCANO" by Locos3D, CC BY-NC-SA 4.0
// https://www.thingiverse.com/thing:4178590
//
// Same frame as duct4010.scad: right-hand part as mounted, Z+ up, X- towards the nozzle, Y- = front.
// Drawn from scratch as a single part: the curves of the air channel, the rails of the mounting arm and its
// height slot are measured from Locos3D's 5015 duct, so it mounts and aims the air like the original.
// It prints lying on its flat back face (y = 0) without supports: every wall is a prism standing on that
// face or rises at 45 degrees, and what is left as a ceiling is a short bridge.

/* [Internal: one-piece duct body] */
// air channel in the XZ plane: inner wall (nozzle side) and outer wall, both arcs ending in the outlet
ch_near_c  = [-18.38, -19.50];   // centre of the inner wall curve
ch_near_r  = [14.07, 15.58];     // its outer face (towards the nozzle) and channel face
ch_near_a  = 67.7;               // the inner wall ends this many degrees below the horizontal
ch_far_c   = [-8.19, -14.55];    // centre of the outer wall curve
ch_far_r   = [20.67, 22.17];     // its channel face and outer face
ch_far_a   = 79.4;               // the curve ends here and a straight lip aims the air at the nozzle
ch_lip     = [7.3, 7.0];         // lip length: channel face, outer face
ch_back    = -1.5;               // channel back face: 1.5 mm wall on the face it prints on
ch_front   = -25.0;              // channel front face: 3 mm front wall
duct_d     = 28.0;               // depth of the duct (Y)
duct_top   = -9.85;              // top of the curved duct = where the air comes in
roof_c     = 5.0;                // 45° chamfers along the front edges of the channel...
roof_ridge = 4.0;                // ...leaving a flat strip this wide (a short bridge when printing)

// mounting arm: rails that slide into the body's grooves and the slot of the height-adjustment screw
arm_x      = [-12.8, -7.8];      // arm face against the body / outer face (the screw head bears on it)
arm_d      = 11.26;              // arm depth (Y)
arm_top    = 27.3;               // top of the arm
rail_tip   = -14.0;              // the rails stick out of the arm face up to here
rails      = [[0, 1.98], [6.58, 8.56]];   // rail bases (depth from the back face); tips 0.55 mm narrower each side
slot_y     = -4.28;              // height slot: centre (Y), width and the Z range of the screw
slot_w     = 3.3;
slot_z     = [9.09, 25.33];
spine_top  = 5.5;                // the block that joins arm and duct stays under the screw head

// derived: straight faces of the walls
near_out_x = ch_near_c[0] + ch_near_r[0];   // -4.31
near_in_x  = ch_near_c[0] + ch_near_r[1];   // -2.80
far_in_x   = ch_far_c[0] + ch_far_r[0];     // 12.48
far_out_x  = ch_far_c[0] + ch_far_r[1];     // 13.98

function pol(c, r, a) = [c[0] + r * cos(a), c[1] + r * sin(a)];
function lerp(a, b, t) = a + (b - a) * t;
function cw_dir(a) = [sin(a), -cos(a)];     // tangent of a circle at angle a, going clockwise
function seg_n(n) = [for (i = [0 : n]) i / n];

// outer wall, channel face: straight, then the arc, then the lip; f = 0..1 from the height of the inner
// wall's centre (where the inner wall starts to curve) to the tip of the lip
far_a0    = asin((ch_near_c[1] - ch_far_c[1]) / ch_far_r[0]);
far_arc_l = ch_far_r[0] * (ch_far_a + far_a0) * PI / 180;
function far_pt(f) = let(s = f * (far_arc_l + ch_lip[0]))
    s <= far_arc_l ? pol(ch_far_c, ch_far_r[0], far_a0 - s / ch_far_r[0] * 180 / PI)
                   : pol(ch_far_c, ch_far_r[0], -ch_far_a) + (s - far_arc_l) * cw_dir(-ch_far_a);
function near_pt(f) = pol(ch_near_c, ch_near_r[1], -f * ch_near_a);
function far_x_at(z) = z >= ch_far_c[1] ? far_in_x : ch_far_c[0] + sqrt(pow(ch_far_r[0], 2) - pow(z - ch_far_c[1], 2));

// Cross-section of the air path: the line from a (inner side) to b (outer side) in XZ, swept in Y from the
// back face yb to the front face yf, with the two front edges chamfered at 45 degrees by c.
function sec(a, b, yb = ch_back, yf = ch_front, c = roof_c) = [a, b, yb, yf, c];
function sec_pts(s) = let(a = s[0], b = s[1], yb = s[2], yf = s[3], l = norm(b - a), u = (b - a) / l,
                          c = min(s[4], max(0, (l - roof_ridge) / 2)))
    [[a[0], yb, a[1]], [b[0], yb, b[1]], [b[0], yf + c, b[1]],
     [b[0] - c * u[0], yf, b[1] - c * u[1]], [a[0] + c * u[0], yf, a[1] + c * u[1]], [a[0], yf + c, a[1]]];

// solid between consecutive cross-sections (each piece is convex, neighbours share a face)
module loft(secs) for (i = [0 : len(secs) - 2])
    hull() polyhedron(points = concat(sec_pts(secs[i]), sec_pts(secs[i + 1])),
                      faces = [[0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11]]);

// The curved duct, from its top (duct_top) to 1.5 mm past the outlet
function duct_secs(n = 20) = concat(
    [for (z = [duct_top, -12, ch_far_c[1], -16, -17.5, ch_near_c[1]]) sec([near_in_x, z], [far_x_at(z), z])],
    [for (f = seg_n(n)) if (f > 0) sec(near_pt(f), far_pt(f))],
    [sec(near_pt(1) + 1.5 * cw_dir(-ch_near_a), far_pt(1) + 1.5 * cw_dir(-ch_far_a))]);

module duct_channel() loft(duct_secs());

// XZ outline of the duct walls, from z_top down to the outlet
module duct_outline(z_top = duct_top) {
    a_near = -ch_near_a;
    lip_out_end = pol(ch_far_c, ch_far_r[1], -ch_far_a) + ch_lip[1] * cw_dir(-ch_far_a);
    polygon(concat(
        [[near_out_x, z_top]],
        [for (f = seg_n(16)) pol(ch_near_c, ch_near_r[0], -f * ch_near_a)],   // inner wall, nozzle side
        [pol(ch_near_c, ch_near_r[1], a_near)],                              // its end, across the wall
        [far_pt(1)],                                                         // across the outlet
        [lip_out_end],                                                       // end of the lip
        [for (f = seg_n(24)) pol(ch_far_c, ch_far_r[1], -ch_far_a * (1 - f))],   // outer wall, back up
        [[far_out_x, z_top]]));
}

// the duct walls as a prism standing on the back face
module duct_shell(z_top = duct_top) rotate([90, 0, 0]) linear_extrude(height = duct_d) duct_outline(z_top);

// Arm profile in XY (rails on the face against the body)
module arm_profile() {
    teeth = [for (r = rails) each [[arm_x[0], -r[0]], [rail_tip, -r[0] - 0.55], [rail_tip, -r[1] + 0.55], [arm_x[0], -r[1]]]];
    polygon(concat([[arm_x[1], 0], [arm_x[1], -arm_d], [arm_x[0], -arm_d]], [for (i = [len(teeth) - 1 : -1 : 0]) teeth[i]]));
}

// Mounting arm: the rails slide into the grooves on the side of the Igneus body and the M3 screw goes through
// the height slot into the body. The spine joins it to the duct, below the screw head.
module mount_arm() {
    difference() {
        union() {
            intersection() {
                translate([0, 0, -2]) linear_extrude(height = arm_top + 2) arm_profile();
                // round the top front corner (the back corner stays square: it sits on the bed)
                rotate([90, 0, 90]) translate([0, 0, -20]) linear_extrude(height = 20)
                    offset(r = 3) offset(delta = -3) translate([-arm_d, -10]) square([arm_d + 3, arm_top + 10]);
            }
            // spine: from the arm to the inner wall of the duct, chamfered under the arm
            rotate([90, 0, 0]) linear_extrude(height = arm_d)
                polygon([[arm_x[0], spine_top], [near_out_x, spine_top], [near_out_x, duct_top - 4.1],
                         [near_out_x - 2.2, duct_top - 4.1], [arm_x[0], duct_top + 2.2]]);
        }
        slot();
    }
}

module slot()
    hull() for (z = [slot_z[0] + slot_w / 2, slot_z[1] - slot_w / 2])
        translate([arm_x[0] - 2.5, slot_y, z]) rotate([0, 90, 0]) cylinder(d = slot_w, h = arm_x[1] - arm_x[0] + 5, $fn = 24);
