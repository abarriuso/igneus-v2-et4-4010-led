# Original Igneus V2 parts (not included)

This folder is where Locos3D's original Igneus V2 files go. They are not part of this repository.

1. Download the Igneus V2 pack from Thingiverse: https://www.thingiverse.com/thing:4178590
   (Locos3D, [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)).
2. Copy these three files into this folder:
   - `Tobera_5015_V2.stl`
   - `Igneus_Version1_Rev.3.stl`
   - `Abrazadera_Adapter_Fan_30mm.stl`
3. From `cad-studio/`, run `python3 tools/place_originals.py`.

That writes `asm/` and `view/` here, with the parts placed where the OpenSCAD sources in `parts/` expect them.
Only the LED mount (carved against the original duct) and the preview parts need them: the adapters and the
one-piece ducts are drawn from scratch. The print-ready STLs are already in `cad-studio/export/`.
