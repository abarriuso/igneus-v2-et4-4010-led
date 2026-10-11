// color: #0e0e0f
// variant: flat
// PREVIEW ONLY: both 4010 blowers of the flat variant, on top of the adapters with the intake facing the front.
// The impellers are separate (view_blower_4010_rotors_flat.scad) so they can spin.
include <lib/flat4010.scad>
include <lib/fans.scad>

module one() blower_4010_front(flat_fan_x0 + 36.05, flat_fan_y0, flat_z_seat, fan_t, fan_w, outlet = flat_outlet, impeller = false);
one();
mirror([1, 0, 0]) one();
