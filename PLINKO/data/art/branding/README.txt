SUGARFALL APP ICONS

sugarfall_icon.png: full-bleed opaque mint icon for the project and legacy Android launchers.
sugarfall_adaptive_foreground.png: generated RGBA donut/cookie art with wide transparent margins for adaptive launchers. Its alpha also supplies the themed monochrome icon.
sugarfall_adaptive_background.svg: native opaque mint gradient; Android applies the launcher mask.

The food artwork was generated with the built-in image_gen tool. No title or instructions are baked into the artwork. Exact prompts, intermediate references, generated source paths and output roles are in sources.json. Generated source pixels are preserved; Godot performs launcher-size resampling during export.

Android Preview exports all four launcher icon fields explicitly. Keep the installed package identity and signing key stable when renaming the display label. The Sugarfall v0.5.2 update uses version code 7.
