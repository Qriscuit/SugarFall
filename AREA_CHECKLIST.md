# Sugarfall — default area checklist

Template version 4 · 3 November 2026

An **area** is a themed campaign with its own mechanic, boards, upgrades, economy and saved progress. A **tray** is one playable board inside an area. The current default is **12 trays per area**.

## How we use this

1. Before building a new area, copy this file to `PLINKO/docs/areas/<area_id>_checklist.md`. Keep this root template blank.
2. Fill in the area brief, choose the mechanic and theme, and add rows for any area-specific work. Keep the item IDs so fixes can refer to them.
3. Update **Built**, **Integrated** and **Verified** separately during each implementation pass. Use `No`, `Yes` or `N/A`.
4. Every `Yes` needs a useful reference in the evidence column: a design decision, source file, screenshot, test log, playtest note or build record. Every `N/A` needs a reason. An applicable unfinished item stays `No`.
5. For each art/effect row, choose `New`, `Reuse` or `Omit`. Name the shared asset when reusing it; explain omissions. Effects may use sprites, animation, shaders or runtime drawing.
6. End each work session with the current stage, completed IDs, remaining gaps and next action. Link related `SF-` tasks and `CHG-` fixes in the existing launch tracker.
7. When adding a tray to an existing area, update that area's tray register and the affected checklist rows. A new themed area gets a full checklist.

| Status column | What `Yes` means |
|---|---|
| Built | The design, content, asset or behavior exists in its intended form. |
| Integrated | The selected area uses it through the real game flow. A loose image or isolated prototype remains unintegrated. |
| Verified | Its acceptance check passed and evidence is recorded. Use phone playtests for feel and pacing. |

Shared assets still need integration and verification in the new area. Artwork approval, working code, editor rendering and APK delivery are separate milestones.

## Area brief — fill this first

| Decision | Area-specific answer |
|---|---|
| Area name / stable save ID / campaign position | TBD |
| Checklist owner / last updated / current stage | TBD |
| One-sentence player fantasy | TBD |
| Signature mechanic: launcher, balls, board or map progression | TBD |
| New player decision or skill, and its payoff | TBD |
| How the mechanic develops from opening to late trays | TBD |
| Theme, materials, palette, silhouettes and references | TBD |
| Tray count | 12 by default; document and integrate any change |
| Starting shot strength, speed, cadence and run duration | TBD |
| Area-specific upgrade or transformation | TBD; record if deliberately omitted |
| Normal entry requirement, fee and paying area's wallet | TBD |
| First-entry defaults / what persists on revisit | TBD |
| What is new, what is shared, what is deliberately excluded | TBD |
| Target phone sizes/devices and performance budget | TBD |
| Design, art folder, validation folder and tracker links | TBD |

Current examples: Bakery uses a movable gravity dropper; Gelato uses calculated gravity aiming and Dual Shot; Crystal uses straight ricochets and a timed live-ball multiplier. Future areas choose their own hook, values and upgrade structure.

## 1. Mechanic and controls

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|
| M01 | Define and prototype the signature mechanic; explain the choice or skill it gives the player. | No | No | No | |
| M02 | Set launcher position, movement/rotation, shot origin, aim limits and touch behavior. | No | No | No | |
| M03 | Define ball motion: gravity or straight flight, speed, cadence, collision response and wall/bottom behavior. | No | No | No | |
| M04 | Make any aiming preview match actual launch physics; show or explain where prediction stops. Include every emitter after upgrades. | No | No | No | |
| M05 | Define normal and special ball roles, spawning/equipment rules, interactions, fragments/clones and spent-effect behavior. | No | No | No | |
| M06 | Specify each pickup: trigger, touch/tap rule, placement, duration, frequency, effect, expiry and upgrade changes. | No | No | No | |
| M07 | Define limits and edge cases: no target/ball available, object cap, repeated contact, overlapping effects and low frame rates. | No | No | No | |
| M08 | Handle pause, backgrounding, resume, end of timer, final hit and remaining balls so every run can finish cleanly. | No | No | No | |
| M09 | Verify aiming, pickup input and menu input coexist; canceled touches, extra fingers and drags cannot trigger accidental purchases/actions. | No | No | No | |

## 2. Theme and composition

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|
| T01 | Establish theme references, material/light rules, palette and recognizable food/equipment silhouettes. | No | No | No | |
| T02 | Plan full portrait compositions for gameplay, Home, the tray journey and upgrade map before placing detailed scenery. | No | No | No | |
| T03 | Reserve clear space around live pegs, upgrade nodes, paths, prices, cards and touch targets; check pan/zoom edges. | No | No | No | |
| T04 | Keep short functional copy, legible type and snug padding inside artwork. Render labels, prices and timers as live UI. | No | No | No | |

## 3. Individual art inventory

List the actual source file and runtime role in the last column. Add a separate row for each new ball, target, pickup, machine part or decoration that the mechanic introduces. Existing special roles may be deliberately omitted if they are unavailable in this area and that choice is integrated into the loadout/shop.

| ID | Asset and required states | New / Reuse / Omit | Built | Integrated | Verified | File / role / evidence / gap |
|---|---|---|---|---|---|---|
| A01 | Normal ball/projectile. | Decide | No | No | No | |
| A02 | Ricochet or extended-flight special ball. | Decide | No | No | No | |
| A03 | Splitter special ball. | Decide | No | No | No | |
| A04 | Impact/heavy special ball. | Decide | No | No | No | |
| A05 | Fragment, shard or child projectile; clone appearance if different. | Decide | No | No | No | |
| A06 | Each additional area-specific ball form, with a separate row per form. | Decide | No | No | No | |
| A07 | Ordinary peg: intact and every supported damage stage. | Decide | No | No | No | |
| A08 | Armored peg: intact and every supported damage stage. | Decide | No | No | No | |
| A09 | Prism/special-effect peg: intact and every supported damage stage. | Decide | No | No | No | |
| A10 | Clock/time peg: intact and every supported damage stage. | Decide | No | No | No | |
| A11 | Each new target/obstacle role, including active, damaged, disabled or destroyed states as applicable. | Decide | No | No | No | |
| A12 | Difficulty appearances: Bronze, Silver, Gold, Diamond or a documented alternative; readable strength cues. | Decide | No | No | No | |
| A13 | Dropper/spout body, correct pivot/outlet and any upgraded or multiple-emitter appearance. | Decide | No | No | No | |
| A14 | Ordinary collector cup/bin. | Decide | No | No | No | |
| A15 | Gold/bonus collector cup/bin. | Decide | No | No | No | |
| A16 | Gameplay tray, rails, liner and any area-specific boundaries. | Decide | No | No | No | |
| A17 | Each floating pickup and its active/expiring/collected visual treatment. | Decide | No | No | No | |
| A18 | Icons for every upgrade family, special upgrade and equipped ball; match their in-game function. | Decide | No | No | No | |
| A19 | Area landmark and area-selection/entry presentation. | Decide | No | No | No | |
| A20 | Home environment. | Decide | No | No | No | |
| A21 | Gameplay environment. | Decide | No | No | No | |
| A22 | Tray-selection journey background and applicable markers. | Decide | No | No | No | |
| A23 | Upgrade-map illustration and scenery around/between routes. | Decide | No | No | No | |
| A24 | Results, pause, settings, Help and loadout backgrounds; intentional sharing recorded. | Decide | No | No | No | |
| A25 | Shared control skins: buttons, panels, HUD, node tiles and state indicators reviewed in the area palette. | Decide | No | No | No | |
| A26 | Production assets: correct transparency, proportions, crop/atlas bounds, pivots, stable damage-frame scale and suitable import settings. | Decide | No | No | No | |
| A27 | Source/provenance record: native originals, exact generation prompts or source/license, runtime paths and variants. | Decide | No | No | No | |
| A28 | Illustrated page-transition artwork: white-cream wave or documented area alternative, palette/accent variants, native source/provenance and runtime crop/import. Record intentional shared reuse. | Decide | No | No | No | |

Current peg art supports intact plus three damaged states. If that changes, update the asset loader and damage presentation together. New art does not require repainting deliberately shared controls.

## 4. Effects, sound and feedback

Effects are deliverables too. Specify their visual form and trigger, even when reusing the existing runtime effect. Add separate rows for new mechanics with multiple effects.

| ID | Effect / required behavior | New / Reuse / Omit | Built | Integrated | Verified | Asset or runtime implementation / evidence |
|---|---|---|---|---|---|---|
| F01 | Launch/nozzle feedback and aim preview/trail, if used. | Decide | No | No | No | |
| F02 | Ball impact feedback and readable damage numbers. | Decide | No | No | No | |
| F03 | Peg damage change, break particles/debris and disappearance. | Decide | No | No | No | |
| F04 | Each special-ball activation: ricochet, split, impact or new role. | Decide | No | No | No | |
| F05 | Pickup appearance, countdown, expiry, collection and the mechanic's resulting effect. | Decide | No | No | No | |
| F06 | Multiplication, transformation, portals or other new mechanic effects, one row per distinct effect. | Decide | No | No | No | |
| F07 | Cup catch, coin gain, wallet feedback and reward payout. | Decide | No | No | No | |
| F08 | Countdown urgency, tray clear/failure and special-upgrade purchase/transformation feedback. | Decide | No | No | No | |
| F09 | Sound cues for the applicable actions; music/ambience decision; Sound off works. | Decide | No | No | No | |
| F10 | Reduced Motion, effect clutter, text contrast and state/strength cues beyond color; inspect at actual phone scale. | Decide | No | No | No | |
| F11 | Define transitions by route: fully covered wipes, continuous/morph entries, frozen-board results and pause fade/blur. Keep pause controls sharp; Resume removes the menu before the blur. Gate input and gameplay through settling, provide Reduced Motion alternatives and verify supported pages/area palettes. | Decide | No | No | No | |

## 5. Trays, difficulty and rewards

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|
| B01 | Author every tray around the actual aiming/movement mechanic, with reachable targets, useful gaps and readable layouts. | No | No | No | |
| B02 | Progress from teaching the mechanic to combining it with harder choices; each tray has a stated purpose. | No | No | No | |
| B03 | Establish 3–4 meaningful difficulty walls and visible peg strength bands; record their tray boundaries and HP. | No | No | No | |
| B04 | Balance durability against expected upgrades at each wall. Tune peg coin budgets independently from HP and damage. | No | No | No | |
| B05 | Define damage, break, cup, combo and clear rewards; close repeat-hit, duplicate-ball and repeat-result farming holes. | No | No | No | |
| B06 | Check progression from a fresh wallet through actual purchases, including losses, retry earnings, special upgrades and final-tray completion. | No | No | No | |

Fill one row per tray. `Implemented` covers the authored board; `Verified` needs an appropriate gameplay check. Keep human pacing results identifiable. If the tray count changes, update every engine, journey, gate, save and validation assumption that depends on it.

| Tray | Lesson / challenge / layout | Strength band / HP | Coin budgets / payout | Expected build / next purchase | Implemented | Verified / evidence / remaining gap |
|---|---|---|---|---|---|---|
| 1 | TBD | TBD | TBD | TBD | No | No |
| 2 | TBD | TBD | TBD | TBD | No | No |
| 3 | TBD | TBD | TBD | TBD | No | No |
| 4 | TBD | TBD | TBD | TBD | No | No |
| 5 | TBD | TBD | TBD | TBD | No | No |
| 6 | TBD | TBD | TBD | TBD | No | No |
| 7 | TBD | TBD | TBD | TBD | No | No |
| 8 | TBD | TBD | TBD | TBD | No | No |
| 9 | TBD | TBD | TBD | TBD | No | No |
| 10 | TBD | TBD | TBD | TBD | No | No |
| 11 | TBD | TBD | TBD | TBD | No | No |
| 12 | TBD | TBD | TBD | TBD | No | No |

## 6. Upgrade map and economy

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|---|
| U01 | Audit every inherited upgrade against the new physics. Define useful effects, caps, starting values, costs and short functional descriptions. | No | No | No | |
| U02 | Define area-specific upgrades: purchase conditions, price, benefit, tradeoff/reset, later rebuilding and persistent ownership. | No | No | No | |
| U03 | Author the map's route shape, branches, entry, discovery and prerequisites; keep node identities stable across revisions. | No | No | No | |
| U04 | Make locked, revealed, affordable, unaffordable, owned and rebuilding states clear. Eligible affordable purchases are green, including after resets. | No | No | No | |
| U05 | Integrate selection cards, live prices, purchase feedback, pan/zoom and comfortable touch targets without art/node/path overlap. | No | No | No | |
| U06 | Verify legal purchase paths, caps, reset/rebuy behavior, no duplicate grants and save-failure rollback. Existing owners keep earned upgrades. | No | No | No | |

The map may use a different shape, node count or ownership model from existing areas. Document it and integrate the corresponding purchase, save and reveal rules; the current 62-node family structure is a reference, not a required future design.

## 7. Full-game integration and saves

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|---|
| I01 | Register the area ID, title, board/economy/art resources, sequence and content-ready checks; no incomplete selectable area. | No | No | No | |
| I02 | Wire normal entry, prerequisite completion, fee disclosure, correct source wallet, fresh defaults and free revisits. | No | No | No | |
| I03 | Wire Home, gameplay, tray journey, area picker, upgrades, pause, Help, loadout, results/history and applicable Trials/milestones. Teach the area's control and pickup mechanic with short, clear explanations. | No | No | No | |
| I04 | Add developer area access and Infinite money using the area's real logic; first entry starts fresh and later visits retain that area's data. | No | No | No | |
| I05 | Preserve independent wallets, upgrades, selected/unlocked trays, special ownership and records; keep global settings/entitlements/run identities intact. | No | No | No | |
| I06 | Save purchases, entry charges and rewards atomically; failures, repeated taps and reloading cannot erase progress or grant/pay twice. | No | No | No | |
| I07 | Persist all active-run state needed by the mechanic: balls, spent effects, timers, offers, RNG and pending results. Resume pauses safely and continues correctly. | No | No | No | |
| I08 | Handle schema/fingerprint compatibility and old-save migration deliberately; valid previous-area saves and interrupted runs remain usable. | No | No | No | |
| I09 | Add required scripts, data, atlas metadata and imported textures to exports; verify the packaged build actually contains and loads them. | No | No | No | |

## 8. Verification and delivery

| ID | Requirement / acceptance check | Built | Integrated | Verified | Evidence / missing work |
|---|---|---|---|---|---|---|
| Q01 | Run relevant physics, input, progression, purchase and edge-case checks; include a complete run with the new mechanic and its upgrades. | No | No | No | |
| Q02 | Verify actual disk save/reload, entry/revisit, failed writes, active effects and old-save compatibility using isolated fixture profiles. | No | No | No | |
| Q03 | Review real rendered screens at target phone sizes: gameplay, effect states, all map/card states, navigation, pause and results. | No | No | No | |
| Q04 | Test normal, partial and late builds; record income, purchases, clears, misses and run length. Label fixed-build/synthetic results separately from human play. | No | No | No | |
| Q05 | Run focused regression checks for previous areas and shared systems touched by the change. | No | No | No | |
| Q06 | Test on a physical phone: aiming/tapping, readability, crowded effects, pause/resume, performance and install-over save retention. Record device and build. | No | No | No | |
| Q07 | Playtest progression with normal wallets and legal upgrades; resolve or explicitly track remaining difficulty, pacing and economy issues. | No | No | No | |
| Q08 | Build the requested preview; verify payload, version, package/signing continuity and relevant Android checks. | No | No | No | |
| Q09 | Deliver through the established download location when requested; verify the uploaded file and record the exact build and known limitations. | No | No | No | |
| Q10 | Update the area design, asset provenance, release notes, this checklist and related launch-tracker changes/fixes. | No | No | No | |

## Completion gates

- [ ] **Concept defined:** brief complete, mechanic and theme chosen, asset decisions recorded, tray/upgrade progression outlined.
- [ ] **Playable in source:** applicable source-side content is built and integrated; the actual area can be entered, played, upgraded, left and resumed. Export, physical-phone and delivery rows may remain open at this stage.
- [ ] **APK ready for playtest:** required content is packaged; relevant automated/render/save checks pass; the exact build and open test items are recorded.
- [ ] **Phone verified:** required device checks and normal-wallet progression playtests are recorded; significant findings have fixes or explicit tracked decisions.
- [ ] **Area complete for its agreed scope:** every applicable row is Built + Integrated + Verified, omissions/reuse are documented, and no required work remains hidden in notes. Delivery is recorded where it was requested.

An area can reach **APK ready for playtest** with phone/pacing rows still open. Keep its overall stage there until the remaining requirements are fulfilled. Completing an area does not by itself complete the game's public-launch checklist.

## Session handoff — maintain in each area's copy

| Field | Current record |
|---|---|
| Current stage / date / build | TBD |
| Completed or changed item IDs | TBD |
| Built but not integrated | TBD |
| Integrated but not verified | TBD |
| Remaining design/art/gameplay gaps | TBD |
| Phone playtest findings / related SF or CHG IDs | TBD |
| Next concrete action | TBD |

## Current project references

Paths below are relative to the workspace root; retain that meaning in per-area copies.

- `PLINKO/docs/ART_DIRECTION.md` — shared materials, typography, asset and composition rules.
- `PLINKO/docs/STUDIO_STARTUP.md` — shared startup presentation and the resource warmup roster; include a new area's required resources before the studio-to-game handoff.
- `PLINKO/docs/CRYSTAL_CANDYWORKS.md` — complete third-area design and current testing limits.
- `PLINKO/docs/GELATO_LAUNCHER.md` and `PLINKO/docs/GELATO_U_MAP.md` — alternate aiming, upgrade and map examples.
- `PLINKO/docs/DEVELOPER_AREAS.md` — separate progress and developer testing behavior.
- `PLINKO/scripts/area_campaign.gd`, `PLINKO/scripts/food_art.gd`, `PLINKO/scripts/environment_art.gd`, `PLINKO/scripts/run_snapshot.gd` — current integration contracts; inspect the actual code before changing them.
- `PLINKO/tests/run_windows_tests.ps1` — existing isolated verification runner.
- `outputs/launch-tracker-01a18eec/Sugarfall Launch Tracker.xlsx` — game-wide tasks and change history.
- `PLINKO/BUILD_LINKS.txt` — current downloadable builds.
