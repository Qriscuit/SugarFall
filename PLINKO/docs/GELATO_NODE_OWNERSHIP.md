# Gelato upgrade nodes and profile migration

Current design: 3 November 2026. The delivered [Android v0.7.4-preview (code 29)](ANDROID_SUGARFALL_v0.7.4.json) retains the winding mixed tree and ceramic courtyard. The current writer uses profile 5 for the three-area campaign; exact Gelato node metadata was introduced in profile 4 and is preserved. AF-003 documentation is synchronized with this delivery; no node schema or purchase formula changed in v0.7.4.

This delivery adds [full portrait scenery, padded HUD text and cup-face labels](SCREEN_LAYOUT.md), including a higher label on Gelato’s gold bowl. Home Play uses the tray zoom/morph and results sit over the frozen board; neither uses cream. The [studio heartbeat introduced in v0.7.3](STUDIO_STARTUP.md) and ordinary menu cream remain. Gelato’s wallet, exact node ownership, aiming and economy are preserved. The [1,877-check software validation](../../verification/screen-polish-20261103/validation.json) covers current layout/flow and startup/save cases; [legal progression measurements](AREA_PROGRESSION_BALANCE.md) remain the earlier synthetic baseline. Physical Android and human pacing acceptance remain open.

Gelato's fixed [mixed tree](GELATO_U_MAP.md) lets the same upgrade family appear on independent branches. Each purchase must therefore identify the exact chosen node. Family totals continue to control gameplay, prices and caps; they no longer imply that every lower-numbered Gelato node was bought.

## Stable slots and purchases

All 62 original `[family,ordinal]` IDs remain. The ordinal is a stable purchase-slot identity, not an effect level or family-order prerequisite. Types and positions are authored once and do not reroll between visits, saves or restarts. Feed 1 remains the root. Every other ordinary node has one drawn parent, and only eligible next choices are revealed.

For example, the first left fork offers the Power slots `[1,2]` and `[1,7]`. Either can be bought first. If the player currently has one active Power upgrade, either choice grants Power level 2 at the level-2 price. Only the selected slot becomes owned and reveals its continuation. The other remains available and now offers the next actual Power level at its updated price. Gelato tiles omit internal ordinal badges; cards describe the function and actual current/next aggregate tier.

`buy_upgrade_node(family,ordinal)` performs the exact purchase. The existing `buy_upgrade(family)` compatibility API chooses the first eligible node deterministically. Module vouchers use the same grant path for one eligible module node; they cannot grant a different node implicitly. Bakery keeps its existing sequential-tier graph and ownership behavior.

No upgrade caps, effects or price formulas change. Counts remain `[Feed,Power,Bounce,Ricochet,Split,Impact,Gold,Time]` with caps `[10,10,6,6,6,6,8,10]`. A purchase costs `upgrade_cost(family)` using the current aggregate count. Infinite money bypasses spending only, retaining eligibility, duplicate protection, caps and real saved ownership.

## Campaign state

Each area record carries these fields; Bakery and Crystal keep empty Gelato node lists:

| Field | Meaning |
| --- | --- |
| `gelato_shop_revision` | Node-state format revision, currently `1` |
| `gelato_owned_nodes` | Unique `[family,ordinal]` IDs whose effects are currently active |
| `gelato_reset_power_nodes` | Previously purchased Power IDs awaiting a post-Twin rebuild |
| `levels` | Unchanged aggregate active upgrade counts used by gameplay |
| `power_reset_tier` | Unchanged count of active Power upgrades at the one-time Twin reset |

Active ownership is membership in `gelato_owned_nodes`. Historical route completion is membership in either node list. A new node requires its drawn parent to be historically completed. This keeps discovered paths open while Power is being rebuilt. Owned legacy nodes remain owned even when their new shuffled parent is missing.

Versioned state is validated strictly: IDs must exist, lists must be unique and disjoint, reset IDs must be Power-only, and active counts must match `levels` exactly. The total represented Power slots must be between the count recorded at reset and the ten-slot cap. Unknown revisions, malformed lists or count mismatches are rejected; counters never silently repair a malformed revision-1 save.

## Twin reset and rebuilding

Dual Shot remains visible below the entry. Purchase costs 3,000 coins and requires both tray 8 and six active Power upgrades. The left main path provides six Power purchases by its twelfth step without requiring optional branches.

Buying Twin moves the exact active Power node IDs into the reset list, sets active Power to zero and retains every other upgrade, equipment choice and route discovery. Those reset nodes remain directly rebuildable, even where a migrated old node has an unowned parent in the shuffled map. Rebuying one removes that ID from the reset list, restores its active ownership and grants the next actual Power level. New, never-bought Power nodes still follow their drawn parent.

The existing doubled Power costs and stronger post-Twin gains apply to both rebuilt and newly purchased Power slots. Affordable nodes remain green; unaffordable ones are red. Other family upgrades and the player's wallet are not reset. Twin ownership still uses its existing saved flag and cannot be bought twice.

Normal node grants, voucher grants and Twin purchases commit their wallet, counters, node sets and equipment together. Failed writes roll back the full purchase. The shared Bakery purchase path also saves the advanced onboarding step with the purchase and restores it on failure.

## Reading older profiles

The writer now emits profile envelope version **5**. The loader accepts versions **1–5**: older Bakery-only profiles retain their existing migration, while version-3 area records missing all three node-state fields receive a deterministic count-preserving migration. Version 5 additionally requires `crystal_second_prism`, false outside Crystal. Legacy version 3/4 area records default that ownership to false without altering Gelato's exact nodes.

For each family with saved level `N`, migration marks the existing IDs `[family,1]…[family,N]` active. For an old Twin save with current Power `P` and reset count `R`, active Power IDs are `1…P`, and reset IDs are `P+1…R` when `R>P`. Thus an old Power-2/reset-6 save retains two active upgrades and four visible rebuild nodes. If current Power exceeds the old reset count, no rebuild nodes are invented.

Migration does not spend money, grant effects, change counts, revoke existing purchases or require missing new parents for already-owned nodes. It applies across every saved area before a new profile is written. Versions 4 and 5 require the node fields explicitly. Serialized revision `0`, partial fields and malformed revision-1 data are rejected. Revision `0` is only an explicit in-memory legacy-fixture staging mechanism for `ensure_gelato_shop_state()`.

An older APK that only understands envelope versions 1–3 cannot reconstruct arbitrary node ownership from counts. The original version-4 writer made those builds reject the profile rather than replace it with count-only data. The current version-5 envelope likewise requires a compatible build; a version-4-only APK cannot safely load Crystal ownership. Ordinary saves, purchases and area transitions remain blocked after an unsupported profile load. This does not remove the existing user-authorized recovery action: **Settings → Reset progress → confirmation** can intentionally replace any blocked profile with a fresh campaign, and a failed reset write preserves the old file.

## Runs, Trials and area switching

Node ownership is campaign metadata. It is not added to the strict in-run checkpoint payload. Bakery and Gelato retain checkpoint schema **4**; Crystal uses schema **5** for its Prism offers. The mixed-map revision did not change Gelato's board/economy fingerprint, launcher revision or combat rules. Compatible interrupted runs resume with the same aggregate effects, and completed pending rewards retain their existing exactly-once collection behavior.

Area switching captures and restores exact node lists with the area's wallet and aggregate levels. Trial snapshots retain campaign node metadata while the Trial uses its existing fixed loadout; returning or resuming restores the campaign's exact owned/reset sets. This map change does not invalidate otherwise compatible Trial records.

Coverage includes exact same-family choices, independent random purchase orders, caps, migration, malformed-state rejection, vouchers, failed-write rollback, Twin rebuilding, area round trips, Trials and checkpoint resume. [The legal progression baseline](AREA_PROGRESSION_BALANCE.md) uses the actual shuffled graph and earned wallets, logs each exact purchased node, and exercises paid Twin resets/rebuilds. Six linked three-area campaigns pass 9,044 legality assertions; Gelato's three signature-policy seeds legally restore reset Power 6 in five further runs. Human purchase pacing and comprehension remain open.

Historical v0.7.0 evidence includes 279 exact-node checks and 176 launcher-save checks in the [three-area validation](../../verification/crystal-area-20261103/validation.json). The original v0.6.13 evidence remains under `verification/gelato-tree-20261102`, including [run-01](../../verification/gelato-tree-20261102/regression/run-01/summary.json). No player profile is used by those fixtures. These retained records describe their dated builds; the [v0.7.4 APK record](ANDROID_SUGARFALL_v0.7.4.json) records the current delivery.
