# Sugarfall economy and repeat play proposal

Design pass dated 25 October 2026. The purchase panel now shows the full price even when unaffordable. The economy changes below are a prototype proposal; production prices, earnings and monetization remain unchanged.

The next economy should space out meaningful purchases, increase the scale of earnings, and give players a bakery worth returning to. Price increases need to accompany a better challenge curve. A blanket multiplier mostly extends the current early bottlenecks.

## Current purchase pace

Current prices depend on each upgrade family's owned tier. The mixed routes repeatedly return to inexpensive tiers: Bounce 1 costs 38, Power 1 costs 50, Impact 1 costs 88, Power 2 costs 93, then Bounce 2 costs 66. A fresh profile can buy six paid upgrades in its first five attempts and twelve in its first ten under the balanced automated policy. Early failed attempts in one reference run pay approximately 45–80 coins, so a failure often still funds a purchase.

All 62 upgrades cost 62,495 coins before vouchers. The routes cost 32,194, 11,801 and 18,462 respectively, plus the shared 38-coin starter. Feed, Time and damage improvements raise both clear probability and income, accelerating further purchases. Normal Bakery cookies remain at 6 HP throughout the current twelve trays; armor first appears on trays 10–12.

The following paired experiments use current production physics at 60 Hz, the same balanced purchase policy and two aiming phases. Candidate prices preserve Feed 1 at 38 and multiply other prices in a temporary test subclass. They exclude menus, thinking, guidance, ads and time away; these are automated active-play measurements, not human session or retention results.

| Price experiment | Paid purchases in first ten attempts | Attempts to clear tray 1 | Attempts to clear Bakery | Active minutes to clear Bakery |
| --- | ---: | ---: | ---: | ---: |
| Current | 12 | 11 | 33–35 | 6.9–7.3 |
| Other prices doubled | 6 | 20 | 55–57 | 11.3–11.8 |
| Other prices quadrupled | 4 | 37–38 | 97–99 | 19.7–20.1 |

At quadruple prices, 73–74 of the 97–99 attempts are spent on trays 1 and 4. Most later trays still take only one to three attempts. This increases repetition without distributing challenge through the area. Keep the useful automatic next-selection UI; change what players work toward between purchases.

The current Gelato entry fee is 1,000, selected after the independent peg-reward and Power-scaled Impact pass; see `ECONOMY_REBALANCE.md`. The historical 2–3-hour estimate in `PACING_v0.5.4.md` relied mainly on a 400,000-coin post-clear savings target. Reinstating that fee would restore a long savings tail rather than a richer Bakery.

## Price and earning targets

Separate coin denomination from purchasing effort. A tenfold denomination makes payouts and prices feel larger but changes no purchasing power when applied consistently. Tune actual effort through fixed prices authored against reference earnings and route position. Prices must never rise dynamically because an individual player has a large wallet or earns efficiently.

Illustrative arithmetic, not production tuning:

| Example | Coins per ordinary attempt | Upgrade price | Attempt equivalents from an empty wallet |
| --- | ---: | ---: | ---: |
| Small numbers | 60 | 66 | 1.1 |
| Both numbers ten times larger | 600 | 660 | 1.1 |
| Larger numbers and a deliberate purchase | 600 | 1,800 | 3.0 |

Start with these purchase-cadence hypotheses:

| Progression stage | Target effort for an ordinary purchase |
| --- | --- |
| Feed 1 and the opening lesson | About one attempt |
| Opening choices | One to two attempts |
| Established early play | Two to three attempts |
| Middle of Bakery | Three to five attempts |
| Later ordinary upgrades | Four to seven attempts |
| Occasional major milestone | Eight to twelve attempts, with smaller goals along the way |

Author a price table for the existing node IDs using expected ordinary-run earnings at that stage multiplied by target attempts, then adjust for unusually strong effects. Include failed-attempt income and milestone vouchers in the budget. Use mixed-route depth as well as upgrade strength so a newly introduced family does not repeatedly reset the price to tutorial levels. Keep occasional inexpensive rewards deliberately.

Protect the first guided purchase and retune the first tray together with its opening prices. A candidate onboarding goal is a first clear within two to four attempts, followed by more substantial challenges later. This needs a layout and HP experiment; the current first tray does not meet that goal under the reference policy. Raising its prices first would worsen the observed bottleneck.

For the first prototype, use 45–60 minutes of meaningful active Bakery progression across several sessions as a working target pending player preference. Measure first clear, optional mastery and entry into Gelato separately. The proposed cadence alone does not establish this duration; it requires distributed challenge and additional useful goals.

## The repeat play loop

Play a tray, earn coins and progress an order, choose an upgrade, see the bakery improve, then try a new challenge. When returning later, collect a modest production payout and make another choice.

Keep free retries and earnings on unfinished trays. Preserve three independent routes and the current one-upgrade visibility horizon. Add milestone goals that make revisits purposeful: a clear with a different equipped treat, a collection target on a particular tray, or a mastery goal that rewards better aiming. Introduce these after the guided opening. Avoid making every ordinary upgrade require an additional currency or another route's investment.

Spread authored challenges around trays 4, 8 and 12. Start with the existing ingredients: earlier selective armor, deliberate cookie arrangements, prism opportunities and layouts that change which treat is useful. Test gradual normal-cookie durability changes rather than leaving every normal cookie at 6 HP. No board should require a paid benefit or one exact random special drop to clear.

A meaningful milestone should also change something visible in the bakery: a finished counter, a working oven or a decorated building. These are proposed additions to the current single-image scenery, not existing interactive buildings. Their purpose is to make progress feel like building the bakery rather than only increasing statistics.

## Passive bakery production

Unlock production around tray 4, after the active loop is understood. An authored production rate increases at bakery milestones and stores at most eight hours of output. Show the rate, stored amount and cap clearly. Claims are optional; no streak resets or loss of already stored earnings for returning late.

Budget a full store to approximately two ordinary upgrades at its milestone. For an illustrative 5,000-coin reference upgrade, a rate of 1,250 coins per hour stores 10,000 coins over eight hours. The reference price and rate are fixed milestone tuning, not a moving price based on the currently selected tile. A four-hour return funds roughly one reference upgrade; a short break contributes part of one. Active play still funds progress faster.

Do not start with passive income at 10% of active earnings. Eight hours at that rate equals 48 minutes of active earnings. At the sampled current post-clear rates this would grant roughly 100,000–120,000 coins, exceeding the entire current upgrade map. Price the return reward in upgrades first, then derive its rate and cap.

Allow passive coins to buy upgrades but require active clears for campaign advancement. Bakery production remains Bakery currency; it does not automatically fund a fresh Gelato profile. Claiming more frequently must not produce extra total income. Calculate away earnings from elapsed time at the saved rate, cap once, and make settlement idempotent. Backward clock changes yield no negative payout; production purchase validation will need trustworthy time and provider verification when real online services are added.

## Monetization fit

Balance the base path without ads or purchases. Existing ads and purchases are local simulations: a rewarded result adds 50%, Baker Toolkit adds 20% of normal campaign earnings, and Remove Automatic Ads suppresses interstitials. Automatic ads currently become eligible after both four completed attempts and 120 active seconds.

Short attempts make per-result advertising awkward. In an illustrative comparison, a 15-second run paying 600 yields 2,400 coins per active minute. Adding a 30-second ad for a 50% bonus yields 900 per 45 seconds, or 1,200 per elapsed minute. This excludes menus and assumes that ad duration; it demonstrates why a small bonus after every short run can be unattractive.

Prototype one clearly optional delivery bonus at a natural return or session milestone, with its reward budgeted as a fraction of one ordinary upgrade. Preserve the base claim independently of the bonus. Compare this with the existing result bonus rather than stacking both into the free-path assumptions. Google requires clear reward disclosure and an affirmative opt-in for ordinary rewarded ads, and declining must leave normal app use available. [Rewarded-ad policy](https://support.google.com/admanager/answer/7496282?hl=en).

Prioritize bakery and food cosmetics as additional purchases. Retain the existing no-ads entitlement if automatic ads remain; test a substantially wider interval, such as 8–10 active minutes after onboarding, at natural results. Keep Toolkit's existing benefit in compatibility testing and measure its 20% acceleration separately. Product pricing and a live billing or ad integration are separate decisions; the simulator does not establish revenue or conversion.

Avoid an energy limit, paid upgrade prerequisites, compulsory production timers or removing the convenient Buy-next flow. Make the ordinary experience satisfying before offering optional acceleration or decoration.

## Prototype sequence and validation

1. Keep the delivered full-price label and collect a fresh baseline by tray. The focused UI pass has 281 passing map checks and 16 rendered phone states, including an unaffordable Feed 2 showing `Buy · 66` with a 37-coin wallet.
2. Author opening tray fixes, a gradual later challenge curve and node prices together. Compare at least two aiming policies and several route priorities. Target fewer purchase bursts without concentrating retries on trays 1 and 4.
3. Add production at milestone-sized rates and test absent players, frequent claimers, active-only players and both area wallets. A full claim should produce a useful purchase choice, not complete the map.
4. Compare free, Toolkit, rewarded and combined paths. Include real ad time in elapsed-session comparisons when available. Then run human phone playtests before selecting final pacing.

Record purchases per result, attempts between purchases, retries per tray, affordable next choices, time to the first improvement, tiers owned at first clear, passive share of spending and voluntary stopping points. Separate active, menu, ad and away time. Retention needs observed returning players; simulated completion time cannot supply it.

A denomination change must migrate existing wallets, unclaimed results, active-run coin fields, trial snapshots, fixed coin grants and area fees exactly once while preserving owned tiers and entitlements. Repricing leaves already owned upgrades owned. Introduce a separate economy version and verify interruption and pending-result recovery before exporting a rebalance.

## Evidence and references

The current audit, paired candidate comparison, complete purchase traces, bounded simulation harness and source hashes are in [verification/economy-design-2026-10-25](../../verification/economy-design-2026-10-25/). Simulations use unattached test instances and do not access player saves. The current run covered nine cases; the two price candidates covered two balanced aiming phases each, with no harness failures.

The production-versus-cost framework is consistent with Kongregate's explanation of income growth and upgrade-cost curves; Sugarfall's proposed values above are our own hypotheses. [The Math of Idle Games](https://www.kongregate.com/en/pages/the-math-of-idle-games-part-i). Google's current documentation describes rewarded-ad formats and their possible duration bounds; the arithmetic example above is a chosen scenario, not a guarantee about a future ad. [AdMob rewarded units](https://support.google.com/admob/answer/7311747?hl=en).
