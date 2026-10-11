// color: #2a2a2d
// variant: flat
// PREVIEW ONLY: impellers of the flat-variant blowers (they spin in the animation; axis parallel to Y).
include <lib/flat4010.scad>
include <lib/fans.scad>

blower_4010_front_impeller(flat_fan_x0 + 36.05, flat_fan_y0, flat_z_seat, fan_t);
mirror([1, 0, 0]) blower_4010_front_impeller(flat_fan_x0 + 36.05, flat_fan_y0, flat_z_seat, fan_t);
