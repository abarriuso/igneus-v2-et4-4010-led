// color: #1d1d1f
// variant: customizer
// Igneus V2 for the Anet ET4 — customizer. Remix of "IGNEUS V2 - E3D V6/VOLCANO" by Locos3D, CC BY-NC-SA 4.0
// (https://www.thingiverse.com/thing:4178590).
//
// Open this file in OpenSCAD, show the Customizer (Window > Customizer), pick a part, enter your measurements,
// render (F6) and export the STL (F7). Every part except the fan adapter needs the original Igneus files:
// see ../igneus/README.md.

include <lib/flat4010.scad>     // also brings in lib/duct4010.scad
include <lib/fan_adapter.scad>

/* [Part] */
// Which part to make
part = "adapter_4010"; // [adapter_4010:4010 adapter (normal), adapter_4010_flat:4010 adapter (flat), led_mount:LED mount for the original duct, duct_4010_led:One-piece duct with LED channel (normal), duct_4010_led_flat:One-piece duct with LED channel (flat), fan_adapter_2510_30:2510 fan to the 30 mm clamp]
// Right or left side (mirror images; ignored for the fan adapter)
side = "right"; // [right, left]
// Ready to print, or as it sits on the printer
orientation = "print"; // [print:Ready to print, mounted:As mounted]

/* [4010 blower — measure yours] */
// Fan thickness (mm)
fan_t = 10.0; // [8:0.05:12]
// Length of the fan edge that sits in the cradle (mm)
fan_w = 40.0; // [38:0.05:42]
// Clearance per side in the cradle (mm)
clearance = 0.20; // [0:0.05:0.6]
// Cradle depth, normal version (mm)
cradle_h = 6.0; // [3:0.5:12]
// Cradle depth, flat version (mm)
flat_cradle_h = 8.0; // [4:0.5:14]
// Floor under the fan, flat version (mm)
flat_floor = 3.0; // [2:0.25:6]
// Clearance per side of the adapter nozzle inside the duct (mm)
nozzle_clear = 0.10; // [0:0.02:0.3]

/* [LED strip — measure yours] */
// Add the LED channel to the one-piece ducts
led = true;
// Strip width (mm)
led_w = 10.0; // [6:0.1:14]
// Strip thickness without the lenses, with the adhesive (mm)
led_t = 0.8; // [0.3:0.05:3]
// Diameter of the LED lenses (mm)
led_lens = 8.0; // [3:0.1:12]
// LEDs per side
led_n = 2; // [1:1:3]
// Distance between LEDs = between cut marks (mm)
led_pitch = 18.1; // [8:0.1:40]
// Beam tilt: 0 = level towards the nozzle, 90 = straight down (degrees)
led_ang = 15; // [0:1:45]
// Strip clearance in the channel (mm)
led_clear = 0.3; // [0:0.05:0.8]
// Clearance of the LED mount against the duct (mm)
mount_clear = 0.15; // [0:0.05:0.5]

/* [2510 fan adapter — measure yours] */
// Fan size (mm)
fan_side = 25; // [20:1:30]
// Distance between the fan's screw holes (mm)
fan_holes = 20; // [16:0.5:24]
// Pilot hole for self-tapping M2.5 screws (mm)
fan_pilot = 2.2; // [1.8:0.1:3]

/* [Hidden] */
$fn = 48;

module side_of() if (side == "left") mirror([1, 0, 0]) children(); else children();
module ready(rot) if (orientation == "print") rotate(rot) children(); else children();

if (part == "adapter_4010")        ready([0, 0, 0])   side_of() adapter4010();
if (part == "adapter_4010_flat")   ready([180, 0, 0]) side_of() adapter4010_flat();
if (part == "led_mount")           ready([-90, 0, 0]) side_of() led_mount();
if (part == "duct_4010_led")       ready([-90, 0, 0]) side_of() duct4010();
if (part == "duct_4010_led_flat")  ready([-90, 0, 0]) side_of() duct4010_flat();
if (part == "fan_adapter_2510_30") {
    if (orientation == "print") rotate([180, 0, 0]) fan_adapter();   // fan side down
    else translate([0, face, 0]) rotate([90, 0, 0]) fan_adapter();
}
