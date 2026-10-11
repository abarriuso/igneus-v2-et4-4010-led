// color: #0e0e0f
// variant: normal
// PREVIEW ONLY: both 4010 blowers (the Creality Ender 3 stock part-cooling fan) in the adapter cradles.
// The impellers are separate (view_blower_4010_rotors.scad) so they can spin.
include <lib/duct4010.scad>
include <lib/fans.scad>

// right-hand blower geometry, in the view frame
blower_x0     = fan_cx - fan_t / 2 + 36.05;                 // inner face (towards the body)
blower_y      = [fan_cy - fan_w / 2, fan_cy + fan_w / 2];   // edge that sits in the cradle
blower_c      = [fan_cy - 1.2, z_seat + fan_w / 2 - 1];     // impeller axis
blower_outlet = [blower_y[1] - 19, blower_y[1]];            // outlet, towards the mounting hole
blower_ears   = [[-9.51, 32.17], [blower_y[0] + 3.5, z_seat + fan_w - 3.5]];   // the first one takes the duct screw

module blowers(impeller = false) {
    module one() blower_4010(blower_x0, fan_t, blower_c, blower_y, z_seat, blower_outlet, blower_ears, impeller = impeller);
    one();
    mirror([1, 0, 0]) one();
}

blowers();
