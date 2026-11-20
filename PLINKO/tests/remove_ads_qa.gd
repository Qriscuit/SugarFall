extends SceneTree
## Game input, billing, verification, ad policy and disk saves with fake platform I/O.
const Billing = preload("res://scripts/area_play_billing.gd")
const Monetization = preload("res://scripts/monetization_service.gd")
const ResultUI = preload("res://scripts/result_comparison_ui.gd")
const PRODUCT = "remove_ads"
const OPTION = "remove-ads"
const TOKEN = "fixture-remove-ads-token"
const ENDPOINT = "https://example.invalid/verifyPurchase"

var passed = 0
var failures: Array[String] = []
var directory = ""

class Game extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func _notification(_what): pass
	func native_purchases_available() -> bool: return true

class Play extends Node:
	signal query_product_details_response(response: Dictionary)
	signal query_purchases_response(response: Dictionary)
	signal on_purchase_updated(response: Dictionary)
	var products = PackedStringArray()
	var queries = 0
	var checkouts: Array = []

	func is_ready() -> bool: return true
	func query_product_details(ids, _type): products = ids
	func query_purchases(_type): queries += 1
	func purchase(product, option, offer) -> Dictionary:
		checkouts.append([product, option, offer])
		return {"response_code": 0}

class Verifier extends "res://scripts/firebase_purchase_verifier.gd":
	signal release
	var requests: Array = []
	var hold_proof = false
	var option = "remove-ads"

	func _post(url: String, data: Dictionary, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
		if url.begins_with("https://identitytoolkit.googleapis.com/"):
			return {"ok": true, "data": {"idToken": "synthetic.id.token", "refreshToken": "fixture", "expiresIn": "3600"}}
		requests.append({"url": url, "body": data.duplicate(), "headers": headers})
		if hold_proof: await release
		var proof = data.duplicate()
		proof.merge({"verified": true, "acknowledged": true, "purchase_state": "purchased",
			"purchase_option_id": option, "verified_at": 1700000000000, "revalidate_after_seconds": 300})
		return {"ok": true, "data": proof}

class Ads extends Node:
	signal availability_changed
	signal reward_earned(id: String, reward: Dictionary)
	signal request_finished(id: String, outcome: Dictionary)
	var shown: Array = []

	func initialize(_config) -> bool: return true
	func is_ready(_kind) -> bool: return true
	func status() -> Dictionary: return {}
	func set_suspended(_value): pass
	func show(kind, id, _context) -> bool:
		shown.append({"kind": kind, "id": id})
		return true
	func finish():
		request_finished.emit(shown.back().id, {"status": "completed"})

func check(ok: bool, message: String):
	if ok: passed += 1
	else: failures.append(message)
	print("PASS: " if ok else "FAIL: ", message)

func fixture(file: String) -> Dictionary:
	var game = Game.new()
	root.add_child(game)
	game.SAVE_FILE = file
	game.sound_on = false
	game.page_transition.enabled = false
	game.monetization = Monetization.new(false)
	game.first_run_guide.import_state({"version": 2, "completed": true, "active": false}, true)
	game.set_active_area("bakery")
	var play = Play.new()
	game.add_child(play)
	var billing = game.ability_ui.billing
	billing._client = play
	play.query_product_details_response.connect(billing._on_products)
	play.query_purchases_response.connect(billing._on_owned_purchases)
	play.on_purchase_updated.connect(billing._on_purchase_updated)
	var verifier = Verifier.new()
	verifier.persist_auth = false
	game.add_child(verifier)
	game.purchase_verifier = verifier
	game.setup_native_purchases({"billing": {"verification_url": ENDPOINT,
		"firebase_web_api_key": "synthetic-key", "firebase_project_id": "demo-sugarfall"}})
	billing._on_connected()
	play.query_product_details_response.emit({"response_code": 0, "product_details": [{"product_id": PRODUCT,
		"one_time_purchase_offer_details_list": [{"purchase_option_id": OPTION, "formatted_price": "€2.49"}]}]})
	var ads = Ads.new()
	game.setup_native_ads({}, {}, ads)
	return {"game": game, "play": play, "verifier": verifier, "billing": billing, "ads": ads}

func tap(game, rect: Rect2):
	game.navigation_delay = 0
	game.result_input_delay = 0
	for pressed in [true, false]:
		var touch = InputEventScreenTouch.new()
		touch.position = game.to_global(rect.get_center())
		touch.pressed = pressed
		game._input(touch)

func open_store(game):
	tap(game, game.home_menu.MENU_RECT)
	tap(game, game.home_menu.SETTINGS_RECT)
	check(game.mode == "support" and game.settings_menu_layout().actions.has("purchases"), "Home menu opens Settings with a Purchases entry")
	tap(game, game.settings_menu_layout().actions.get("purchases", Rect2()))
	check(game.mode == "purchases", "Settings opens the real Purchases screen")

func record(state: int = 1) -> Dictionary:
	return {"package_name": Billing.PACKAGE, "product_ids": [PRODUCT],
		"purchase_token": TOKEN, "purchase_state": state, "is_acknowledged": false}

func inventory(play: Play, purchases: Array):
	play.query_purchases_response.emit({"response_code": 0, "purchases": purchases})

func finish_eligible_result(game, run_id: String):
	game.mode = "play"
	game.run_area_id = game.area_id
	game.run_id = run_id
	game.shift_claimed = false
	game.remaining = 0
	game.shift_coins = 100
	game.native_ad_service.attempts = game.native_ad_service.ATTEMPTS_REQUIRED - 1
	game.native_ad_service.active_seconds = game.native_ad_service.COOLDOWN_SECONDS
	check(game.finish_shift(), "Completed result with eligible ad cadence saves progress: " + run_id)

func checkout(file: String):
	var f = fixture(file)
	var game = f.game
	var buy: Rect2 = game.monetization_ui.NATIVE_BUY
	var restore: Rect2 = game.monetization_ui.NATIVE_RESTORE
	check(PRODUCT in f.play.products and f.play.queries == 1, "Google Play startup queries the Remove Ads SKU and owned inventory")
	open_store(game)
	tap(game, buy)
	check(f.play.checkouts.is_empty() and not game.automatic_ads_allowed(), "Unresolved startup inventory blocks checkout and automatic ad playback")
	inventory(f.play, [])
	check(f.billing.offer(PRODUCT).price_label == "€2.49", "The permanent offer exposes the localized Google Play price")
	finish_eligible_result(game, "bakery:unowned")
	check(game.mode == "native_ad" and f.ads.shown.size() == 1 and f.ads.shown[0].kind == "interstitial", "A verified non-owner still receives an automatic interstitial")
	if game.mode == "native_ad": f.ads.finish()
	game.collect_reward()
	open_store(game)

	tap(game, buy)
	check(f.play.checkouts == [[PRODUCT, OPTION, ""]], "The native Buy control launches the permanent Remove Ads checkout")
	f.play.on_purchase_updated.emit({"response_code": 1})
	check(not f.billing.has_entitlement(PRODUCT) and f.verifier.requests.is_empty() and game.monetization_ui.purchase_message == "Purchase cancelled.", "Canceled checkout reports cancellation and grants no ownership")

	tap(game, buy)
	f.play.on_purchase_updated.emit({"response_code": 0, "purchases": [record(2)]})
	tap(game, buy)
	check(not f.billing.has_entitlement(PRODUCT) and f.billing.offer(PRODUCT).pending and f.verifier.requests.is_empty()
		and f.play.checkouts.size() == 2 and not game.automatic_ads_allowed(), "Pending payment grants nothing and blocks duplicate checkout and automatic ads until resolved")
	f.verifier.option = "wrong-option"
	f.play.on_purchase_updated.emit({"response_code": 0, "purchases": [record()]})
	check(not f.billing.has_entitlement(PRODUCT) and f.billing.needs_restore(PRODUCT) and not game.automatic_ads_allowed()
		and "verification failed" in game.monetization_ui.purchase_message, "A mismatched proof grants nothing, prompts Restore and leaves automatic ads paused")
	var queries: int = f.play.queries
	tap(game, restore)
	check(f.play.queries == queries + 1, "Restore queries Play after a verification failure")
	inventory(f.play, [])

	f.verifier.option = OPTION
	f.verifier.hold_proof = true
	tap(game, buy)
	f.play.on_purchase_updated.emit({"response_code": 0, "purchases": [record()]})
	check(f.play.checkouts.size() == 3 and f.verifier.requests.size() == 2 and not f.billing.has_entitlement(PRODUCT)
		and f.billing.offer(PRODUCT).pending, "A successful native payment waits for the verifier before granting ownership")
	var request: Dictionary = f.verifier.requests.back() if not f.verifier.requests.is_empty() else {}
	check(request.get("url") == ENDPOINT and request.get("headers") == PackedStringArray(["Authorization: Bearer synthetic.id.token"])
		and request.get("body") == {"package_name": Billing.PACKAGE, "product_id": PRODUCT, "purchase_token": TOKEN}, "The real verifier authenticates and submits the exact Play purchase identifiers")
	f.verifier.release.emit()
	await process_frame
	check(f.billing.has_entitlement(PRODUCT) and game.monetization_ui.purchase_message.is_empty(), "An acknowledged, verified purchase grants ownership and clears checkout errors")

	finish_eligible_result(game, "bakery:owned")
	check(game.mode == "result" and f.ads.shown.size() == 1 and not game.begin_native_ad("interstitial"), "An owner reaches Results without an interstitial, including through direct ad requests")
	check(game.reward_ad_label() == "Watch ad +50", "The owner still sees the voluntary reward and its amount")
	tap(game, ResultUI.BONUS_RECT)
	check(game.mode == "bonus_confirm", "The result reward control opens voluntary ad confirmation")
	tap(game, Rect2(60, 620, 600, 96))
	check(game.mode == "native_ad" and f.ads.shown.size() == 2 and f.ads.shown.back().kind == "rewarded", "Confirming the voluntary reward still reaches the ad SDK boundary")
	if game.mode == "native_ad":
		f.ads.reward_earned.emit(f.ads.shown.back().id, {"amount": 1})
		f.ads.finish()
	check(game.mode == "result" and game.result_payout() == 150, "The optional ad still awards its normal bonus")
	game.collect_reward()
	var persisted = FileAccess.get_file_as_string(file)
	var profile = JSON.parse_string(persisted)
	check(profile is Dictionary and TOKEN not in persisted and not profile.has(PRODUCT), "Profile saves contain no purchase proof or native entitlement flag")
	game.free()

func restart_and_restore(file: String):
	var f = fixture(file)
	var game = f.game
	game.load_game()
	check(not f.billing.has_entitlement(PRODUCT) and not game.automatic_ads_allowed(), "Fresh controllers wait for Play and suppress interstitials during the ownership check")
	f.play.query_purchases_response.emit({"response_code": 2})
	check(not f.billing.has_entitlement(PRODUCT) and not game.automatic_ads_allowed(), "A transient startup failure does not allow an automatic ad before ownership is known")
	open_store(game)
	tap(game, game.monetization_ui.NATIVE_RESTORE)
	check(f.play.queries == 2, "The actual Restore purchases control retries a failed startup query")
	inventory(f.play, [record()])
	check(f.billing.has_entitlement(PRODUCT) and f.verifier.requests.size() == 1 and f.play.checkouts.is_empty(), "A fresh game restores the same Play purchase through verification without a new checkout")
	finish_eligible_result(game, "bakery:restored")
	check(game.mode == "result" and f.ads.shown.is_empty(), "A restored owner skips the automatic ad at an eligible result")
	game.collect_reward()
	var profile = JSON.parse_string(FileAccess.get_file_as_string(file))
	profile[PRODUCT] = true
	profile.monetization_test = {"version": 1, "entitlements": {"remove_ads": true, "baker_toolkit": false},
		"store_owned": {"remove_ads": true, "baker_toolkit": false}}
	check(game.write_profile_file(profile), "A separate fixture stages forged local remove-ads flags")
	game.free()

	f = fixture(file)
	game = f.game
	game.load_game()
	inventory(f.play, [])
	finish_eligible_result(game, "bakery:forged")
	check(not f.billing.has_entitlement(PRODUCT) and game.mode == "native_ad" and f.ads.shown.size() == 1, "Forged local ownership cannot suppress ads after Play reports no purchase")
	if game.mode == "native_ad": f.ads.finish()
	game.free()

func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): directory = argument.trim_prefix("--output-dir=")
	if not directory.is_absolute_path() or directory.begins_with("user://"):
		push_error("An explicit absolute isolated --output-dir is required.")
		quit(2)
		return
	call_deferred("run")

func run():
	DirAccess.make_dir_recursive_absolute(directory)
	var file = directory.path_join("remove-ads-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	await checkout(file)
	if FileAccess.file_exists(file): restart_and_restore(file)
	else: check(false, "Checkout produced an isolated profile for restart testing")
	print("REMOVE_ADS_QA_RESULT passed=%d failed=%d" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)
