// color: #2a2a2d
// variant: normal
// PREVIEW ONLY: impellers of both 4010 blowers (they spin in the animation; axis parallel to X through y,z = blower_c).
include <lib/duct4010.scad>
include <lib/fans.scad>

blower_x0 = fan_cx - fan_t / 2 + 36.05;
blower_c  = [fan_cy - 1.2, z_seat + fan_w / 2 - 1];   // same as in view_blowers_4010.scad

blower_4010_impeller(blower_x0, fan_t, blower_c);
mirror([1, 0, 0]) blower_4010_impeller(blower_x0, fan_t, blower_c);
