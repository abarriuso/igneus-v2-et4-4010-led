// color: #0e0e0f
// PREVIEW ONLY: 2510 hotend fan (the Anycubic Kobra X one), blowing towards +Y onto the V6.
// Screwed to the 25 -> 30 mm adapter (fan_adapter_2510_30.scad); the rotor is in view_fan_2510_rotor.scad.
include <lib/fans.scad>

face  = -27.06;   // outer face of the clamp plate
cz    = -5.05;    // centre of the 30 mm hole pattern
ad_t  = 4.0;      // 25 -> 30 adapter thickness

translate([0, face - ad_t - 10, cz]) rotate([-90, 0, 0]) axial_2510(blades = false);
