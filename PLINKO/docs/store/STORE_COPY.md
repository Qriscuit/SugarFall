# Sugarfall — Google Play copy

Revised 4 November 2026 with Mabel as Sugarfall's mascot. Feature claims refer to the public candidate, **0.8.0-rc2 / code 37**. Draft only; no Console changes or publication. The player-facing fields below can be copied separately. The evidence and production notes are internal. The earlier storefront-v1 package remains historical; the revised text exports are under `concept-art/storefront-v2/exports`.

## App name

Sugarfall

9 / 30 characters.

## Short description

Bounce treats, break pegs and earn upgrades in a sweet physics-based adventure.

79 / 80 characters.

## Full description

Step into Mabel's unusual bakery, where doughnuts bounce through cookies and your next upgrade could turn a near miss into a cleared tray. Mabel helps you get started before you explore gelato gardens and glowing candy workshops.

Drag your finger to position your dispenser or aim your launcher. Use gravity, angles and rebounds to reach awkward pegs, then clear the tray before time runs out. A small change in aim can send your next shot somewhere very different.

Choose your route through branching upgrade maps. Buy stronger shots, faster drops or more time, and adjust your approach as the pegs get tougher. Save for a special ability or buy the improvement that could help right now.

Splash nearby pegs with jam, unlock twin launchers or tap a Prism to multiply the candy already in play. Each area gives you a different way to aim, break pegs and put your upgrades to work.

Fill the collection cups to grow their payouts and earn a bonus for clearing a tray. Didn't finish? Collect your coins, improve your equipment and try again.

Each area has its own upgrades and saved progress. Start with a few bouncing doughnuts and work toward a board full of treats, splashes and ricochets.

1194 / 4,000 characters, including paragraph breaks; 205 words. Copy ends above this line. Exact strings and counts are in [store_copy.en-US.json](store_copy.en-US.json).

## Proposed copy for later features

These paragraphs are not part of either listing field or the plain-text listing exports. Daily challenges and Mabel's continuing presence across areas are proposals, not current functionality.

**Daily challenges:** “Take on a new challenge each day, try a different setup and earn coins for completing its goal. Beat an optional harder objective for a bigger reward to spend on your next upgrade.”

**Mabel's continuing presence:** “Mabel returns as you discover new areas, with a welcome, a quick tip and a celebration when you clear a difficult tray. From your first doughnut to your latest upgrade, there's a familiar face along the way.”

Mabel is the chosen mascot for the icon, banner and character design work. Her current in-game role is the Bakery introduction and its replay; this branding choice does not establish the proposed later dialogue or celebrations.

## Screenshot captions

These are short labels for real captures. Keep the game UI readable and show the pictured feature in the frame. These six captions propose an order; the screenshot production plan controls the final selection and capture state.

| Order | Caption | Actual screen to show |
| --- | --- | --- |
| 01 | Break pegs. Earn coins. | Bakery gameplay. A normal run with doughnuts, readable cookie pegs, cups and HUD; capture an actual hit. |
| 02 | Aim along the curve | Gelato single-launcher gameplay. One spout, a clearly curved dotted preview and ice cream in flight; preview stops at its actual first obstacle. |
| 03 | Tap to multiply candy | Crystal Prism gameplay. The real floating ×2 pickup while candy is in play; capture before it expires. An optional adjacent genuine frame may show the result. |
| 04 | Choose your upgrades | Gelato upgrade map. The winding tree with connected branches and a truthful earned-wallet state; keep store/test purchase controls out of the composition. |
| 05 | Hit nearby pegs with Jam Burst | Bakery Jam Burst gameplay. A charged jam doughnut hitting a peg, with the actual splash reaching nearby living pegs; use an earned Jam Burst build. |
| 06 | Two launchers. Rebuild Power. | Gelato Dual Shot gameplay. Both earned launchers and their separate curved previews; use a saved build that legally owns Dual Shot. |

Alt text was checked against all six final captures on 4 November 2026 and stays below 140 characters:

- **01:** Bakery gameplay with a doughnut dispenser, cookie pegs and collection cups. (75 characters)
- **02:** Gelato Garden gameplay with a top launcher and a curved dotted aiming preview above wafer pegs. (95 characters)
- **03:** Crystal Candyworks gameplay with candy, crystal pegs, collection cups and a floating ×2 Prism pickup. (101 characters)
- **04:** Gelato Garden's branching upgrade tree with connected upgrade nodes and garden scenery. (87 characters)
- **05:** Bakery gameplay showing a charged jam doughnut splashing nearby cookie pegs. (76 characters)
- **06:** Gelato Garden gameplay showing two launchers, two curved aiming previews and wafer pegs. (88 characters)

## Feature claims and evidence

| Claim in copy | Current evidence | Scope or qualification |
| --- | --- | --- |
| Mabel introduces the bakery and helps the player get started | [first_run_guide.gd](../../scripts/first_run_guide.gd), the [first-player-experience design](../NEW_PLAYER_EXPERIENCE_GDD.md) and `data/art/host/mabel_welcome.png`. | Current presence is Bakery onboarding and guide replay. Ongoing all-area guidance is proposed separately. |
| Themed areas with separate upgrades and saved progress | [Bakery](../../data/board_design.json), [Gelato](../../data/gelato_board_design.json), [Crystal](../../data/crystal_board_design.json) and [area_campaign.gd](../../scripts/area_campaign.gd). | No fixed number of areas, levels or trays appears in the listing fields. This does not promise future content. |
| Break pegs before time runs out, earn coins and buy upgrades | [main.gd](../../scripts/main.gd): board_is_clear, begin_clear_drain, finish_shift, upgrade and reward paths; [economy design](../ECONOMY_REBALANCE.md). | Coins are game currency. No claim of real-money rewards. |
| Bakery moves its dispenser and drops doughnuts | [area control comparison](../CRYSTAL_CANDYWORKS.md#area-identity-and-control), [main.gd](../../scripts/main.gd). | Ordinary Bakery controls, not fixed-spout aiming. |
| Jam Burst splashes nearby pegs | [bakery_ability.gd](../../scripts/bakery_ability.gd), [signature design](../AREA_SIGNATURE_ABILITIES.md#jam-burst). | Earned upgrade. Periodic charged doughnuts, with a first-hit splash; not every hit or every ball. |
| Gelato has a curved preview and a winding upgrade tree | [gelato_launcher.gd](../../scripts/gelato_launcher.gd), [launcher design](../GELATO_LAUNCHER.md#controls-and-boards), [map design](../GELATO_U_MAP.md). | Preview follows free flight to the first obstacle; later bounces are not predicted. |
| Dual Shot provides twin launchers | [launcher design](../GELATO_LAUNCHER.md), [signature design](../AREA_SIGNATURE_ABILITIES.md), [public policy evidence](../PUBLIC_RELEASE_RC2_POLICY_VALIDATION.json). | Earned route requires tray 8, Power 6 and 3,000 Gelato coins, then resets Power. Exact requirements and reset are explained in-game; the listing names the ability without promising its starting availability. |
| Crystal shoots straight, rebounds and offers a timed ×2 pickup | [crystal_launcher.gd](../../scripts/crystal_launcher.gd): OFFER_LIFETIME, collect and duplicate_live_balls; [Crystal design](../CRYSTAL_CANDYWORKS.md#prisms-and-the-shop). | One tap duplicates live candy subject to the live-object cap. The pickup expires after four seconds; a second offer requires Second Prism and suitable live candy. No guaranteed two successful collections. |
| Stronger material bands and Power, firing-rate and time upgrades | [durability design](../BAKERY_DURABILITY.md), [Flow rules](../AREA_FLOW_RULES.md), [main.gd](../../scripts/main.gd). | Current values are omitted from marketing copy because balancing remains in progress. |
| Each area retains separate coins, upgrades and progress; cleared trays can be replayed | [area_campaign.gd](../../scripts/area_campaign.gd), [Crystal campaign/save design](../CRYSTAL_CANDYWORKS.md#campaign-developer-access-and-saves), [release policy checks](../PUBLIC_RELEASE_RC2_POLICY_VALIDATION.json). | Local progression only. No cloud-save or cross-device promise. First entry to the next area requires both predecessor completion and earned coins. |
| Physics, cup payouts, clear bonuses and earnings retained after an unfinished tray | [main.gd](../../scripts/main.gd): simulation, `bucket_reward()`, clear and collection paths; [coin-budget design](../ECONOMY_REBALANCE.md). | Cup payouts grow with catches. Rewards are game coins; no cash prizes, guaranteed large payout or chain-bonus claim. |

The [RC2 release record](../ANDROID_SUGARFALL_v0.8.0-rc2.md) confirms the referenced source is packaged. Its 344 artifact checks and 186 separate public-policy checks do not establish physical-phone acceptance or production billing. A store screenshot must not show developer controls, infinite funds, a test purchase or an unavailable paid offer as an available player feature.

## Editorial rules

Use the action or feature name directly. Prefer “Aim along the curve” to invented metaphors. Omit decorative claims such as “irresistible,” “addictive,” “ultimate,” “endless fun,” or “a delicious adventure.” Use “tray” for a board and “area” for Bakery, Gelato Garden or Crystal Candyworks. Keep the title **Sugarfall** consistent.

Do not give a fixed count of areas, levels or trays in the listing fields. Mabel is the mascot; describe her actual introductory role until a continuing role is built. Keep daily-challenge and expanded-character concepts outside the publishable fields.

Do not add claims about working paid early unlocks, a fixed $2.99 store price, ad-free play, offline availability, cloud saves, multiplayer, leaderboards, generated levels, future areas, easy progression or a specific completion time. Real billing and the final commercial declarations are still open. This exclusion is an evidence limit, not a decision to remove planned monetization.

## Google Play requirements checked

The title, short description and full description limits are **30, 80 and 4,000 characters**. [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en).

Metadata must describe actual functionality clearly. Avoid misleading claims, keyword repetition, anonymous endorsements and ranking or price promotions. [Metadata policy](https://support.google.com/googleplay/android-developer/answer/9898842?hl=en).

The short description should explain the game directly; the full description should add useful detail. Screenshots and other graphics must represent actual functionality. [Store listing practices](https://support.google.com/googleplay/android-developer/answer/13393723?hl=en) and [preview asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

Before submission, compare these claims and screenshots with the final Play build and finish the actual pricing, ads, audience, privacy and support declarations. This draft makes no store submission or approval claim.

