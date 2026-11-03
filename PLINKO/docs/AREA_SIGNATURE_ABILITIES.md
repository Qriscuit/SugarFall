# Area signature abilities

3 November 2026 · CHG-036 source revision after v0.7.5-preview. No new APK or Drive replacement is recorded here. Public payments remain unfinished.

Each area has one permanent ability that changes its play pattern. The player can earn it through the tray-8 route or choose a permanent early unlock from tray 1. The planned US base price is $2.99 per area; a real store must supply its localized price. Both routes grant the same ability and tradeoffs. Existing owners retain their unlocks.

| Area | Ability | Earned route | Behavior |
|---|---|---|---|
| Bakery | Jam Burst | Tray 8 unlocked, Power 4, 1,200 Bakery coins | Every fifth normal doughnut splashes nearby pegs on its first hit |
| Gelato Garden | Dual Shot | Tray 8 unlocked, Power 6, 3,000 Gelato coins | Two gravity launchers follow the same finger target along separate trajectories; Power resets and is rebuilt |
| Crystal Candyworks | Second Prism | Tray 8 unlocked, Power 4, 900 Crystal coins | A second timed opportunity to duplicate live candy in a run |

The Home offer and special upgrade node expose the same choice. Locked earned routes explain their prerequisites; owning the ability suppresses a duplicate purchase. Early access belongs only to its area and does not unlock an unvisited campaign or pay the campaign's entry fee. Trials retain their fixed loadouts and authored rules.

## Jam Burst

[`bakery_ability.gd`](../scripts/bakery_ability.gd) counts actual normal launcher drops. Specials and fragments do not advance the count. Each fifth normal doughnut carries the [native jam sprite](AREA_MENU_ART.md); its first peg contact spends the charge before applying splash damage. Up to two other living pegs within 105 logical pixels of the directly hit peg receive 0.75 times current Power. Targets are selected by distance, with a stable index tie-break. The directly hit peg is excluded.

Splash damage uses the shared damage-budget path, so it cannot create coins beyond each peg's fixed budget. Spent charges cannot replay after another contact or restored checkpoint. Run-local charge count, ownership source and spent-ball state are part of the compatibility checks. A short jam burst and charge dots communicate the effect; Reduced Motion removes the moving splash presentation without changing damage.

## Existing abilities and compatibility

Dual Shot keeps its two ballistic previews, per-launcher cadence, Power reset, stronger rebuilding and higher rebuilding costs. The early route applies those same rules. Existing exact Power-node and reset-node identities remain authoritative. See [Gelato's launcher](GELATO_LAUNCHER.md).

Second Prism's earned gate moves from tray 6 to tray 8. Its 900-coin price and Power-4 requirement remain. Existing owners keep it. The second offer remains scheduled at 7.5 seconds with the existing live-candy, expiry and object-limit rules. Buying access does not guarantee that a player collects either Prism. See [Crystal Candyworks](CRYSTAL_CANDYWORKS.md).

Earned flags and preview/verified-store access remain distinct. A preview receipt cannot become a public entitlement. Purchase activation, any Power reset and ownership persistence must commit together or roll back. Area reset retains the separate early-access record, while progression reset does not silently convert it into earned ownership. See [the purchase contract and unfinished public billing work](AREA_ABILITY_PURCHASES.md).

Campaign activation history is distinct from the physics of a newly started run. If early access becomes unavailable, a new ordinary Gelato run must save and resume as an ordinary run while retaining the campaign's earlier Power-reset/rebuild history. A historical Twin flag alone cannot make that checkpoint use Twin physics. Earned access and verified restored access follow their own grant rules.

## Tray 8 and presentation

[Flow rules revision 2](AREA_FLOW_RULES.md) independently increases new campaign-run HP and damage/break/clear budgets from tray 8. Ability or paid ownership does not control that scaling. Existing active runs stay pinned to revision 1; Trials remain unchanged. The earlier legal-campaign measurements are historical and do not establish current Flow-2 pacing.

[Area-specific Settings/Pause frames](AREA_MENU_ART.md) keep concise live titles and controls inside quiet themed faces. The existing pause fade/blur and navigation route rules remain. New art, core abilities, the public-purchase path and phone acceptance are tracked separately in template U07/U08 and each area's populated checklist.

## Acceptance scope

Current source verification is recorded in [area status](../../AREA_STATUS.md). Real Play products, plugin installation, backend verification/acknowledgement, public purchase/restore testing, a new packaged build, phone feel and fresh legal progression remain separate requirements. The delivered v0.7.5 preview predates CHG-036.
