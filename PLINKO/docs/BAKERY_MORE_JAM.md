# Bakery More Jam

3 November 2026 · CHG-040 · delivered in v0.7.8-preview/code 34

On 3 November 2026, the user reported being unable to clear Bakery tray 10 despite having all upgrades. The exact installed build, phone/OS, node ownership/loadout, attempts, aim pattern, remaining pegs and time are unconfirmed. This is an open difficulty finding, not a completed phone or campaign acceptance pass.

## Unlock and effect

More Jam is a free, once-only Bakery claim requiring tray 10 unlocked, effective Jam Burst access and all 62 ordinary upgrade nodes, including the shared root and all three routes. It affects newly started campaign runs and introduces no paid product. Base Jam Burst can be earned or accessed through its existing early route; More Jam itself cannot be bought early. Tray 10 only needs to be unlocked, not cleared. Owning the three terminal nodes alone cannot bypass missing ancestors. The node sits at the far end of the existing Bakery tree and opens a short More Jam card showing its gate or the free claim. Existing ordinary node identities and saved ownership remain intact.

New eligible runs charge one Jam doughnut per four normal launcher drops, compared with the base ability's five. Specials and fragments do not advance the counter. The charged doughnut still spends its splash on the first peg hit, damaging up to two other living pegs within 105 logical pixels for 0.75 times Power. Radius, target selection, splash strength, coin budgets, peg HP, base upgrades and board geometry are unchanged. Trials keep their authored loadouts without the campaign ability.

The existing Jam icon, charged-ball sprite, splash feedback, charge display and jam_splash sound are reused. No new art or sound asset is introduced. See [the base signature design](AREA_SIGNATURE_ABILITIES.md).

## State and checkpoints

The area-local `bakery_jam_quick` flag defaults to false, persists when revisiting Bakery and clears with its area reset. Claiming spends no coins; repeat/ineligible claims do nothing, and failed persistence rolls back the grant. Eligibility uses effective Jam Burst access, so historical activation alone cannot provide a currently unavailable ability.

Existing schema-6 active Jam runs retain five-drop cadence. Schema 7 records the four-drop cadence for new More Jam runs. Run-local counters and spent charges follow the recorded rules rather than silently changing an active run after an upgrade. Existing ownership is preserved; players must claim the new node rather than receiving it silently.

## Evidence and retest

1,060 software checks pass across 12 focused backend, save and map suites. Separately, 79 GPU checks pass across 14 captures at 450x800 and 450x1000; 253 final renderer inputs match. No phone result is implied.

The far-end More Jam node connects all three routes, reveals at tray 10 or any completed lane, and focuses eligible players on entry. Final map/GPU checks cover locked, green free-claim, owned, card and four-drop feedback states.

78 fixed-build comparisons plus one deterministic replay have no invariant/profile/termination failures. Tray-10 tracking clears 8/9 at both cadences; broad sweeps clear 0/9 at both. Tracking trays 11/12 change 8/9 to 9/9 and 8/9 to 6/9. Jam damage rises, but this does not establish resolution of the phone difficulty or natural-wallet/human progression.

The bounded simulations use fixed maximum legal builds and modeled controls. They do not establish natural-wallet attainment, human difficulty or a uniformly faster individual run. Keep the reported tray-10 issue open until the user retries the delivered build. Record node discovery, eligibility, the free once-only claim, four-drop feedback, tray-10 outcome and late-tray feel; preserve the only player profile. See [phone checks](AREA_PLAYTEST.md), [feature validation](MORE_JAM_VALIDATION.json) and [bounded pacing evidence](BAKERY_MORE_JAM_BALANCE.md).

786 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 93,051,298 bytes; SHA-256 `9bb0f427a1bb47ac916ec01b5ea73b50d590026f8cfa51f0c37905f602035998`. All 8 Drive readback checks pass; the existing private file ID, folder, owner permissions and URL are retained. No remote checksum comparison is claimed. [Exact build record](ANDROID_SUGARFALL_v0.7.8.json) · [Download](../BUILD_LINKS.txt).
