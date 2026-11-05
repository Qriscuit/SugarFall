# Rich upgrades and cream-transition footage

This fixture captures the actual Gelato Home → Upgrades navigation and the production cream wave, followed by the nearly completed upgrade map. It uses a fresh isolated copy of the frozen V1 capture project. The relevant upgrade-map, Gelato layout and page-transition source hashes match the current game workspace.

The staged campaign is tray12 with 56 of62 ordinary nodes owned and Dual Shot earned through its normal purchase API. Six terminal branch leaves remain unbought and affordable. The fixture purchases prerequisites with the production purchase functions, earns Dual Shot under its tray/Power gates, then rebuilds the reset Power through the same API. A recorded12,500-coin balance represents the staged late-campaign wallet. No developer money, developer menu or production save is used.

Initial overview framing uses the existing map camera API. The recorded72px pan uses actual screen-touch and screen-drag input. The click at source0.10seconds goes through the real Home Upgrades button. Its .62-second cream animation fully covers the frame before revealing the map. The captured transition is Home → Shop; it is not a Play transition.

Run `run_capture.py` with the bundled Python environment from the workspace. It creates a fresh `verification/trailer-v4-20261104/capture/run-01` project, changes only that copy's entry scene and isolated user-directory identity, exports the same public nondebug preset, and captures270JPEG96 frames at1080×1920/60fps. Logs, profile directories and temporary paths stay inside the isolated run directory. Use a new run directory for another capture.

Output: `outputs/trailer-v4-20261104/gameplay/09-upgrades-rich/frame_%05d.jpg`, plus `clip.json`. Clip metadata records the staged ownership, all purchase costs, actual UI feedback, map camera samples and cream coverage. `upgrades-capture-validation.json` verifies all491 frozen script/data resources, 56/62 ordinary ownership,57owned/6affordable visible nodes, the full cream cover and zero profile IO.

`encode_capture.py` saves a normal-speed4.5-second H.264/yuv420p clip to `outputs/trailer-v4-20261104/encoded/09-upgrades-rich.mp4`; its readback probe and full decode are checked. `upgrades-frame-hashes.json` freezes all270raw-frame hashes and the clip/validation JSON identities.

The root edit can use the first215frames (0–3.5833seconds) in the existing upgrade-page slot. No player save, production script, drawing function or gameplay mechanic is changed by this capture. The trailer's existing Mabel sequence remains separate and untouched.
