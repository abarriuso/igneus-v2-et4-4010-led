// color: #1d1d1f
// 2510 fan -> Locos3D's 30 mm fan clamp, as mounted (view frame). Printable: export/Fan_adapter_2510_30mm.stl
// is the print-ready copy (fan side down, no supports). Parameters and module: lib/fan_adapter.scad.
include <lib/fan_adapter.scad>

// local (x, y) = view (x, z); local +z = view -Y (towards the fan)
translate([0, face, 0]) rotate([90, 0, 0]) fan_adapter();
