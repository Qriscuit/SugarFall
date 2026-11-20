# Gelato and Crystal interface art

Four native PNGs generated with the built-in image_gen tool on 4 November 2026. Exact prompts, reference roles, original paths and runtime paths are in [sources.json](sources.json); byte hashes, dimensions, alpha ranges and authored crop bounds are in [native-validation.json](native-validation.json).

Each native 1254×1254 controls atlas has fourteen isolated objects in a 4×4 grid, with the last two cells unused. The request asked for 2048×2048; the returned native dimensions are retained. No pixels were edited, resized or recolored offline. The area-specific `regions.json` files address the native source directly through normalized bounds. Godot handles normal import and UI slicing.

Gelato uses lavender and mint ceramic with a quiet ivory face. Crystal uses pale aqua sugar-glass rims, copper seams and peach accents. Green/red/ivory upgrade states remain distinct; labels, prices, checks, locks and navigation symbols stay live.

The two native 1536×1024 cream variants retain the original crest composition with subtle area accents. The runtime uses the top 1536×768 region, join y520 and existing opaque white body. The native wave alpha maximum is254; native alpha does not establish complete screen coverage. Real rendered midpoint coverage is checked separately.

The old Bakery controls, neutral Bakery wave and existing area menu frames remain deliberate reuse within their respective scope. The three old Gelato control PNGs remain as historical originals and are no longer loaded. See [integration and verification](../../PLINKO/docs/AREA_INTERFACE_ART.md).

`inspect_assets.py` reads native pixels to verify bytes/alpha and writes metadata/import settings; it never changes pixels.
