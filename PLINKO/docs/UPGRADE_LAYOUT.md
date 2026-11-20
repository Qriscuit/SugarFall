# Upgrade selection and card layout

4 November 2026 · CHG-047 / AF-011 · v0.7.12-preview/code 39 delivered

The user reported that Gelato text and text boxes sit too high against the new artwork. They also requested a simpler selected-node display and a compact signature-upgrade card. This pass aligns live labels with existing artwork and updates shared upgrade presentation. It does not require new generated assets.

Gelato's primary mint button labels and symbols move down two logical pixels. Secondary cream button labels and the Home selector labels move down four, to sit on the painted reading faces. The same rendering offsets apply wherever those controls are reused. Touch bounds and control behavior retain their existing layout. Preserve the native atlas pixels and resource identity from CHG-046. The earlier uniform six-pixel candidate remains iteration history.

Selected available, unowned ordinary upgrades show their required coin amount without the power or upgrade picture behind it, including unaffordable upgrades. An unowned selected signature node shows its earned coin price even while its earned gate is locked; the lower card retains that gate and the early-access route. An available selected More Jam node shows `Free`. Owned nodes and locked ordinary nodes retain their regular art/status. Hidden nodes remain hidden. The picture returns when a node is no longer selected. The lower card identifies the upgrade and describes its effect. Preserve green/red purchase-state meaning, discovery, ownership and purchase guards.

Signature cards are 224 logical pixels high and use two columns, with the large card picture removed. The left column contains the title, two effect lines directly below it, and the earned gates or current status/message. The right column contains the coin action above the early-access purchase action, using 78-pixel-high buttons separated by 12 pixels. Keep prices, gates and ownership live. Preview confirmation, pending/restore behavior and no-charge labels remain within the same card flow.

Effect rows allow 32 logical pixels of height. Effect text uses 19–21 logical pixels; action labels retain at least 24 with padded button faces. Gelato's first effect line is “Two slower launchers. Power resets.” This describes the existing Dual Shot behavior.

1,750 source/desktop assertions pass with zero failures, including 1,229 GPU assertions across 156 captures at 450x800 and 450x1000. Final frames cover selection, signature cards and general interfaces. 521 selected-state, map/camera, ability-integration and Twin checks pass. All 270 source/art/data inputs match the isolated fixture; normal player-profile IO is zero and the final root editor import exits successfully. The four native interface/wave PNGs from CHG-046 remain byte-identical; no new bitmap artwork is generated for this layout correction.

v0.7.12-preview/code 39 passes 1,318 payload checks and 16 Android metadata/signature/alignment checks; 98,872,682 bytes. The existing preview package and signing certificate are retained. Eight Drive metadata readback checks pass after replacement in the existing private preview file. File ID, folder, owner permissions, URL and exact byte count are retained; no remote checksum comparison is claimed. [Exact build](ANDROID_SUGARFALL_v0.7.12.json). Source evidence: [UPGRADE_LAYOUT_VALIDATION.json](../../PLINKO/docs/UPGRADE_LAYOUT_VALIDATION.json); [visual-review.json](../../verification/upgrade-layout-20261104/visual-review.json); [native-retention.json](../../verification/upgrade-layout-20261104/native-retention.json).

Physical-phone readability and touch acceptance remain AF-009 / D01–D17. Real Play billing, current legal progression and the Bakery tray-10 retest remain open.
