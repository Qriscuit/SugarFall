# Sugarfall next-area progression proposal (archived)

23 October 2026 · Original design proposal

**Implemented 24 October 2026.** See [Gelato Garden](GELATO_GARDEN.md) for the current entry rules, local progression, twelve authored trays, save behavior and validation limits. The proposal below is retained as historical design rationale; its future-tense implementation notes and references to the locked v0.5.4 gate are not the current behavior.

**Profile notes superseded 26 October 2026.** References below to keeping Main and Fresh Test separate describe the retired profile feature. Current source uses one canonical campaign save and a confirmed Reset progress action; see [the current reset design](NEW_PLAYER_EXPERIENCE_GDD.md#reset-progress). Area-local wallets and upgrades remain separate within that single campaign.

## Entry and player-facing explanation

After collecting the result for Bakery tray 12, the player can continue earning Bakery coins. Once Bakery has at least **400,000 coins** and the next area is released, its gate opens a short entry confirmation. Entry costs 400,000 Bakery coins once. Cancel changes nothing.

Use a new-area illustration, its name, and three compact functional statements: **“Upgrades restart”**, **“Purchases stay”**, and **“Leftover coins stay in Bakery”**. This is consequence disclosure, not decorative copy. Put the live 400,000-coin price on the Enter button; never paint it into an asset. Buttons: Cancel and Enter. Revisiting an owned area never charges again or resets anything.

Successful entry opens the new area's Home screen on tray 1 with its own peg arrangement. It does not automatically start a run, show an ad, or open the upgrades map. Play and tapping the play space retain the current seamless entrance, with drops beginning only after equipment is in place.

## Recommended scope

| State | On first entry to the next area |
| --- | --- |
| Eight upgrade branches | All start at tier 0 in the new area. Preserve Bakery's tiers in its own saved record. |
| Equipped specials and unlocked special tiers | Empty / tier 0 in the new area; original Bakery loadout stays in Bakery. Reskin the same mechanical roles without carrying their tiers. |
| Upgrade-map visibility | Begin at the first Feed tile, then reveal descendants using the existing rules. |
| Current / highest unlocked tray | Both 1. New area has 12 separately authored trays; completed=false. |
| Free treat vouchers and milestone claims | New area starts with no vouchers and no claims. Each area's tray 2/5/8 milestones can award once. Unused Bakery vouchers remain usable in Bakery. |
| Coins | Separate wallet per area. Subtract exactly 400,000 from Bakery; keep all excess there. Gelato Garden starts at 0. No confiscation or hidden conversion. |
| Remove Automatic Ads | Keep permanently; continues suppressing automatic ads in every area. |
| Baker Toolkit | Keep permanently; existing +20% normal campaign payout applies in every area, even when its food theme is no longer a bakery. Keep the product ID stable. |
| Store ownership / restore state | Keep globally, independent of every area's upgrade data. |
| Sound, Reduced Motion | Keep globally. |
| Attempt/ad counters, cooldown, provider serial, last counted run | Keep globally. Changing area neither triggers an ad nor restarts/evades the cadence. |
| Run serial and last claimed run | Keep globally. Never reuse identities after an area switch. |
| Completed-area history and trial records | Preserve. Namespace records by area and tray; retain Bakery's records. |
| Active balls, effects, bucket hit growth, combo, timers, catch settle | No active run may cross entry. Clear transient presentation only after entry commits. |

“Reset upgrades” means the new area starts fresh; it does not erase the completed area's build. An area picker in the winding level journey can revisit Bakery. Its saved levels, upgrades, local wallet, and unspent vouchers return. Replays earn only that area's coins, so an efficient Bakery farm cannot skip progression in the next area. No new currency icon is needed: the area name and scene establish which local wallet is shown. A first-entry explanation makes the distinction explicit.

Gelato Garden retains the existing mechanical roles with new food: ice-cream scoops for ordinary drops, wafer pegs, strawberry splitter, chocolate bonbon impact, lemon candy ricochet, and sundae cups. Artwork changes do not implicitly change hitboxes, collision behavior, reward percentages, or automatic special-drop rules. Its boards and balance still need deliberate authoring.

This local-wallet choice is a recommendation for the next implementation pass, not an already-shipped rule. A shared wallet would be simpler, but a player arriving with 462,495 coins could pay the 400,000 fee and buy the entire current 62,495-coin upgrade tree immediately. Preserving excess locally avoids that loophole without deleting earned value. Do not silently introduce a carryover cap, zero the old bank, or charge more than the displayed fee.

The 400,000 requirement remains the existing Bakery goal. It is not automatically the correct fee or economy for area 2. Existing 2–3-hour estimates cover clearing Bakery and funding its gate; the next area's fresh-profile pacing needs its own simulation and human playtests.

## Save and transaction design

Add a version 3 profile with `active_area_id`, an `areas` dictionary, and an entry ledger. Each area record owns its wallet, upgrade tiers, equipment, current/highest tray, completion, free voucher count, claimed milestones, and trial records. Keep lifetime `total_shifts`, settings, run identity counters, last claimed run, and `monetization_test` at the profile root. The two product IDs remain `remove_ads` and `baker_toolkit`; new theme names never mint replacement purchases.

Permanent means player/account scope rather than area scope. The current test service is local and separated by profile: retain that separation between the main and fresh-test profiles. This proposal does not create accounts, cloud saves, cross-device ownership, real purchases, or real restore guarantees. Future verified store entitlements may be account-level, while their local cache stays outside area records.

Use a dedicated entry function that builds a deep-copied candidate profile. Preflight the destination's board data, required artwork, valid starting configuration, and ability to load its Home before offering entry. Recheck content availability, source completion, exact local balance, destination ownership, current profile, and idle navigation state when Enter is tapped. Require all finished rewards to be collected and any active run to finish or be explicitly abandoned through its existing flow. A new area's ID in `areas` is the durable ownership record. An already-owned destination switches normally and does not run initialization or charge again.

For first entry, the candidate deducts the exact fee, adds a single entry record (`source`, `destination`, `cost`, unique transaction ID), creates the destination defaults, and selects it. Write the whole candidate through a temporary file, flush, verify success, and atomically replace the save. Only then apply it to live state and animate the new Home. A failed save leaves the old area and balance untouched. Repeated taps or restarting after the commit find the owned area and cannot double-charge. Do not mutate the live wallet and then hope a later save succeeds.

Retain a pre-migration backup. Read legacy version 1/2 profiles as Bakery records without changing coins, owned tiers, entitlements, milestone claims, settings, or valid pending rewards. A separate v3 save filename can preserve the legacy file for recovery and avoid an older preview overwriting the new area records; once v3 exists it is authoritative. Import legacy data once, never merge its wallet again on subsequent launches. Keep the existing application/package identity and Android signing identity. Document that older preview builds do not understand new-area progress.

New active-run snapshots need an explicit `area_id`, area content fingerprint, and schema version. New pending results also need `area_id` so a late result cannot pay a different wallet or advance the wrong tray. Legacy schema 1/2 runs and results belong to Bakery. Preserve the existing exact price-only compatibility exception only for its audited Bakery pair; never treat a next-area reskin or board change as generally fingerprint-compatible. Snapshot validation must compare against the relevant area's immutable content before restoring. Adding an area must not invalidate otherwise-compatible paused Bakery runs.

## Rewards and purchases during entry

Do not allow entry while an ad/purchase modal or an uncollected result is on screen. Finish the existing flow first. Rewarded bonuses remain attached to their original run and can be collected once; they are not a transferable boost, a next-area starter reward, or a permanent purchase. Keep the current four completed attempts / 120 active seconds policy, with menus, transitions, practice, and ad time excluded. A gate is not an additional ad placement.

The test provider deliberately does not save in-flight requests; restarting never completes a purchase or ad. Preserve that rule during this design pass. For eventual real billing, a store payment awaiting external approval should be a global durable transaction independent of the current area and should not block ordinary play indefinitely. A verified completion grants the global entitlement once; duplicate or stale callbacks cannot pay coins or reset upgrades. That provider work is separate from releasing area 2.

## Implementation hazards in the current code

- `scripts/main.gd:934`, `reset_profile_runtime()`, calls `monetization.reset_test_state()` and clears wallet, run IDs, records, and upgrades. **Do not reuse it for area entry.**
- `scripts/monetization_service.gd:125`, `reset_test_state()`, clears both entitlements and fake store ownership. `main.gd:775`, `reset_test_monetization()`, and `main.gd:769`, `clear_test_entitlements_for_restore()`, are also test-only resets, not area lifecycle functions.
- `scripts/main.gd:869`/`:875` flatten one campaign into profile version 2. Refactor persistence before enabling a gate; returning to old fields would overwrite another area's progress.
- `scripts/main.gd:640` awards coins, vouchers, and tray progression without area identity. `:872` pending results and `:964` active restoration require an area before they can be safely used by multiple areas.
- `scripts/main.gd:997` loads wallets with a 100,000,000 safety ceiling; ordinary runtime additions do not enforce that same ceiling. Use the same validated money bounds in both candidate transactions and load/save, preserving current cent-precision internals and whole-number display. Never round away valid legacy fractions during migration. Gate subtraction is an exact integer cost.
- `scripts/monetization_service.gd:138` separates persistent ownership/cadence from transient requests; preserve this boundary. `main.gd:675` is where Toolkit and earned reward payout apply.
- `scripts/run_snapshot.gd:4`, `:23`, and `:45` define schema 2, a closed field list, and a single global content fingerprint. Merely appending an area field would fail strict validation without an explicit migration.
- `scripts/level_map.gd:44` intentionally reports `content_ready=false` and `can_enter=false`. Keep that shipping behavior until the whole entry path is tested.

## Release acceptance checks

Test entry at 399,999 / 400,000 / 450,000 Bakery coins, cleared and uncleared Bakery, unavailable content, repeated taps, save failure, and restart on either side of commit. At 450,000, Bakery must retain 50,000 and the new area must begin at 0. Returning to Bakery and back must neither charge again nor reset either build. Verify local vouchers/milestones cannot be duplicated by switching.

Verify both permanent products independently and together across migration, first entry, re-entry, restart, and restore. Verify the same payout percentage in both areas, Remove Ads continuity, uninterrupted ad cadence, no ad on entry, and no duplicate rewarded result. Resume legacy Bakery play, won-board drain, and pending results before allowing entry. Confirm the new Home-to-play entrance still waits for all equipment and the final-ball drain still finishes its bucket bounce before results.
