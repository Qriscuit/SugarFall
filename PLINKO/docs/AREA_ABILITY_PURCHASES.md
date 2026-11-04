# Area ability early unlocks

3 November 2026 · Local implementation and provider contracts; real Play payments remain unconnected.

Each area has one permanent signature ability. The gameplay route opens from tray 8 with that area's stated Power and coin requirements. An optional early unlock is planned at **US$2.99 per area**, visible from tray 1. Both routes activate the same mechanic and tradeoffs. The purchase does not add a stronger exclusive version or remove the normal progression route.

| Area | Ability | Permanent Play product ID | Base purchase option |
|---|---|---|---|
| Bakery | Jam Burst | `sugarfall_bakery_ability` | `early-unlock` |
| Gelato Garden | Dual Shot | `sugarfall_gelato_ability` | `early-unlock` |
| Crystal Candyworks | Second Prism | `sugarfall_crystal_ability` | `early-unlock` |

These are independent non-consumable one-time products, not subscriptions or repeat purchases. The design USD price is a preview label. A connected store must show the price returned by Google Play in the player's currency. The adapter selects only the configured permanent base option; rentals or unrelated discounted offers cannot supply its displayed price.

## Direct upgrade-card actions — CHG-043

Each selected signature upgrade card has two stacked actions: Buy with the coin cost above Buy with the localized store price (preview $2.99). Two short effect lines and the tray/Power gate remain on the card. Home has no ability purchase artwork or touch target, and there is no separate options page.

Coin purchases use the existing earned gates and costs. In preview, the early-access action stays on the card and changes to Confirm test and Cancel under explicit Test purchase / No charge labels. Back, leaving the map or selecting away cancels confirmation. Available public purchases request the provider directly; missing or unverified providers cannot grant access. Owned abilities cannot be bought again, pending requests are guarded, and Restore uses the lower action when receipt restoration is needed. No real billing integration is completed by this UI change.

844 source/desktop assertions pass with zero failures: 192 integration, 431 GPU, 35 Crystal UI, 105 Gelato shop and 81 Twin-node checks. The renderer covers 38 captures at 450x800 and 450x1000; 259 relevant source/art/data/fixture hashes match. Direct actions, gates, inline confirmation, provider-fixture pending/restore/rollback and Home cleanup are exercised. No real Play transaction or phone acceptance is claimed. The [v0.7.10 preview](ANDROID_SUGARFALL_v0.7.10.json) packages this revision. U08 remains unfinished: changing the purchase entry point does not connect Play products, install the plugin/backend or establish real store transactions.

## Ownership and gameplay integration

[`area_ability_access.gd`](../scripts/area_ability_access.gd) owns early access only. Earned ownership and the actual ability transformation belong to area progression. `has_early_access(area)` does not modify the earned flag. `offer(area, earned)` reports title, product ID, price, owned/earned, available, preview, pending and error fields. An earned or already-owned ability cannot be purchased again. Buying one area does not unlock another.

Preview receipts use their own versioned global save namespace, `area_ability_preview`. They survive an area reset but never import as a public paid entitlement. Pending test purchases do not survive restart. The preview confirmation must clearly identify itself as a test and explain that no money is charged. Unknown, cancelled, pending, failed, unavailable and repeated callbacks grant nothing. Completion and restore accept a persistence callback; a failed save restores the previous receipt/benefit state. The gameplay caller must similarly roll back any area transformation if persistence fails.

The existing advertisement and Baker Toolkit simulator is separate. No entitlement in that simulator is repurposed as a real purchase.

## Real Play provider seam

[`area_play_billing.gd`](../scripts/area_play_billing.gd) is an optional adapter for the current first-party `BillingClient` API. It dynamically discovers the installed class, connects purchase/product/query signals, fetches localized prices, launches the permanent option, handles pending/cancelled/error outcomes and restores non-consumed inventory. The current official Godot setup requires the plugin and an Android Gradle build. [Godot setup](https://godot-sdk-integrations.github.io/godot-google-play-billing/installation.html), [client methods](https://godot-sdk-integrations.github.io/godot-google-play-billing/api/methods.html).

The adapter refuses to start a real purchase without a configured backend verifier. The verifier receives `{package_name, product_id, purchase_token}` and must authenticate the player, validate that exact token/product/package with Google, commit the permanent entitlement idempotently, and acknowledge delivery. Its successful response echoes those identifiers and includes `verified: true`, `acknowledged: true`, and `purchase_state: "purchased"`. These values are the trusted backend adapter's result; no client purchase dictionary or local save can supply them. Google recommends server verification, grants only for PURCHASED, and acknowledgement after delivery; these unlocks must never be consumed. [Google purchase security](https://developer.android.com/google/play/billing/security).

Real access is held only in the verified provider's memory and refreshed from owned purchases. No durable production entitlement cache is implemented. Before launch, choose and test an authenticated restore/offline policy, including refunds/revocations and failed-verification retry. A source flag saying `store` is not proof of payment.

The game now binds the provider's change/result signals to the shared offer and activation flow, requests a restore on foreground resume, and applies a completed unlock at a safe menu or the next run. Ability access is pinned when a run starts so a background inventory refresh cannot change airborne balls or Gelato Power midway. Profile restoration checks the available provider again. These hooks are integrated; the real verifier and store remain unavailable.

## Remaining public-release work

- Create the Play Console app for `com.qriscuit.sugarfall`; create and activate the three products and `early-unlock` purchase options with a US base price of $2.99. Product IDs must match exactly. [Console setup](https://godot-sdk-integrations.github.io/godot-google-play-billing/google_play_console_setup.html).
- Install and pin the first-party Godot plugin. The checked current Godot 4 release is **3.3.0**, using Billing Library **9.1.0**; it is not bundled in this source revision. Enable the plugin, Gradle export, required network permissions and release signing. [Official releases](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases).
- Implement and configure the authenticated verification/acknowledgement backend and account/restore policy. Exercise the integrated signal/activation and foreground-restore hooks against the real provider, including save failures and entitlement changes while a run is active.
- Upload a billing-enabled release build to an internal Play track and configure license testers. Verify actual store pricing, success/cancel/pending, duplicate callbacks, restore/reinstall, offline recovery, refunds and retained earned access on an Android device. Local fake-client tests do not replace this check. [Play testing setup](https://godot-sdk-integrations.github.io/godot-google-play-billing/google_play_console_setup.html).

Until that work is complete, preview builds offer an explicit test purchase flow. Public builds can explain the early-unlock offer but must show the store as unavailable and cannot fabricate a successful charge.

## Contract verification

[`area_ability_access_qa.gd`](../tests/area_ability_access_qa.gd) checks preview purchase lifecycle, save-failure rollback, receipt restore, malformed saves, replay resistance, earned/area separation, public rejection of preview data and missing-provider behavior. Its fake BillingClient/backend checks the real adapter's localized-price and permanent-option mapping, pending/no-proof behavior, verified response binding, duplicate fulfillment, restore queries and inventory revocation. The fake objects have no network access and do not claim a Play transaction.

Evidence is recorded under `verification/area-purchases-20261103/`. This report does not mark billing products, backend, Android purchase testing or public monetization ready.
