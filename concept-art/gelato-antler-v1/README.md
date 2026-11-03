# Gelato antler upgrade map

This concept and map were implemented first, then included in the shared Android v0.6.12 preview. The existing Drive APK was replaced in place. See [the verified delivery record](../../PLINKO/docs/ANDROID_SUGARFALL_v0.6.12.json) and [download notes](../../PLINKO/BUILD_LINKS.txt). Physical Android testing remains open; the evidence in this folder documents the source/art phase.

The central Feed 1 entry opens two 14-node main paths. Each forks after steps 3, 6 and 9. The six terminal tines have lengths **6/6/5 on the left** and **6/6/4 on the right**. At each fork the terminal tine follows the incoming direction while the continuing route turns onto an apparent side branch, which grows into the next fork. Six `spine_handoffs` describe these real connections. The topology preserves all 62 existing family/tier identities and caps; every preceding family tier remains an ancestor, with no hidden cross-branch prerequisite.

| Side | Main path, grouped at forks | Terminal tines |
| --- | --- | --- |
| Left | Power 1 → Feed 2 → Power 2 / Feed 3 → Power 3 → Feed 4 / Power 4 → Feed 5 → Power 5 / Power 6–10 | Bounce 1–6; Impact 1–6; Feed 6–10 |
| Right | Time 1 → Gold 1 → Time 2 / Gold 2 → Time 3 → Gold 3 / Time 4 → Gold 4 → Time 5 / Time 6–10 | Ricochet 1–6; Split 1–6; Gold 5–8 |

Feed 1 is `(0,0)`, the first route heads are `(−500,−350)` and `(500,−350)`, and Dual Shot is `(0,440)`. Dual is visible below the entry even while locked and has a displayed link to Feed 1. Buying it requires **tray 8 AND Power 6**, costs **3,000 coins**, and retains the existing Power reset/rebuild behavior. No upgrade prices, effects or save fields change in this map revision.

The square world bounds are `[-5000,-8200,10000,10000]`. Six **authoring target rectangles** guide two tall, snaking trees inside the U: an upper canopy region, narrower middle region and slender root corridor for each tree. They are generation targets, not exact final painted bounds:

| Reserve | World rectangle `[x,y,width,height]` |
| --- | --- |
| Left upper | `[-1150,-7200,1000,4750]` |
| Right upper | `[150,-7200,1000,4750]` |
| Left middle | `[-650,-2600,500,1100]` |
| Right middle | `[150,-2600,500,1100]` |
| Left root | `[-170,-1800,130,1300]` |
| Right root | `[40,-1800,130,1300]` |

The brief places slender trunks in the lower corridors and foliage in the broader upper targets. The generated upper foliage extends beyond some targets; final painted silhouettes therefore need a separate clearance audit against all 63 UI footprints and 62 links, including hidden upgrades and Dual. Gameplay UI supplies the nodes, links, prices and ownership marks; these must not be baked into runtime art.

[layout-guide.png](layout-guide.png) is the exact placement schematic, generated from the same coordinates as the runtime layout. [geometry.json](geometry.json) records the 63 tile/selection keepouts, 62 padded links, authoring target rectangles and handoffs. The guide's labels and route marks are authoring aids. Run [author_gelato_u_map.py](../../PLINKO/tools/author_gelato_u_map.py) to reproduce these files and [gelato_upgrade_layout.json](../../PLINKO/data/gelato_upgrade_layout.json). Authoring validation checks identity coverage, family ancestry, node spacing, noncrossing links, unrelated tile clearance and clearance from the target rectangles. It does not infer the final image's foreground bounds. Minimum final center spacing is 340 world pixels against a 300-pixel requirement.

Earlier simulated economy findings are historical for the preceding route graph. This layout keeps tuning values intact, but its changed purchase order and longer detours still need phone pacing and touch playtests. Current behavior is documented in [GELATO_U_MAP.md](../../PLINKO/docs/GELATO_U_MAP.md); earlier art and APK records remain unchanged.

## Native generated artwork

The [concept illustration](concept.png) establishes the caramel branches, lavender paper and tall pistachio-and-blossom trees. It is a style and composition reference; the [placement guide](layout-guide.png) contains the exact playable topology. The concept is 1145×1374 pixels.

The game uses [upgrade_antler_garden_v1.png](../../PLINKO/data/art/gelato/environment/upgrade_antler_garden_v1.png), a separate 1254×1254 background with no baked upgrade nodes, connecting routes or text. Its world rectangle matches the layout exactly. The lavender surround (`d1acd9`) is the measured mean of the image's outermost pixels. Existing Bakery artwork is unchanged, and earlier Gelato images are preserved as source history but excluded from future exports.

Both images were produced with the built-in `image_gen.imagegen` tool and copied without resizing, retouching or recompositing. [sources.json](sources.json) records original output paths, native dimensions, SHA-256 hashes, references and complete prompts. The exact prompts are also saved as [concept-prompt.txt](concept-prompt.txt) and [runtime-art-prompt.txt](runtime-art-prompt.txt).

The actual tree silhouettes are checked independently of the requested authoring reserves: [art-clearance.json](../../verification/gelato-antler-20261102/art-clearance.json). The read-only color-mask audit uses both permissive and conservative foreground thresholds, all node selection footprints, compact marker sizes across zoom, padded connecting paths and a source-pixel margin. GPU captures supplement the numerical check. The first two route heads were widened after generation to protect the painted root tips at overview zoom; the background pixels were not altered.

[Final validation](../../verification/gelato-antler-20261102/validation.json) records 1,133 headless checks plus 239 renderer checks and 38 captures, with no failures or player-profile IO. The [full in-game overview](../../verification/gelato-antler-20261102/screens/full-antlers-720x1280.png), [opening split](../../verification/gelato-antler-20261102/screens/first-fork-450x800.png) and [Dual Shot card](../../verification/gelato-antler-20261102/screens/dual-ready-450x800.png) show the implemented map. These are Windows GPU captures at phone resolutions; physical Android testing remains open.
