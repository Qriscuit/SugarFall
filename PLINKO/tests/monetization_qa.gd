extends SceneTree
## Run through run_windows_tests.ps1: persistence/reset cases use its isolated saves.
const Main = preload("res://scripts/main.gd")
const Service = preload("res://scripts/monetization_service.gd")
const SAVE = "user://monetization_qa.json"
var passed = 0
var failed: Array = []

func _initialize():
	if "--monetization-qa-isolated" not in OS.get_cmdline_user_args():
		print("MONETIZATION_QA_REFUSED: Use the isolated Windows runner and --monetization-qa-isolated.")
		quit(2)
		return
	clear_storage()
	check_service_cadence()
	check_service_requests()
	check_service_persistence()
	check_active_play()
	check_result_boundaries()
	check_rewarded_results()
	check_purchases()
	check_ui_routes()
	check_progress_reset()
	clear_storage()
	print("MONETIZATION_QA_RESULT passed=", passed, " failed=", failed.size())
	for issue in failed: print("FAIL: ", issue)
	quit(1 if failed.size() else 0)

func check(ok, label):
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed.append(label)
		print("FAIL: ", label)

func fixture():
	var g = Main.new()
	g.testing = true
	g.sound_on = false
	g.SAVE_FILE = SAVE
	g.board_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	return g

func restart():
	var g = fixture()
	g.load_game()
	return g

func clear_storage():
	for base in [SAVE]:
		for path in [base, base + ".tmp"]:
			if FileAccess.file_exists(path):
				assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)

func result_game(coins = 10.10):
	var g = fixture()
	g.start_shift()
	g.shift_coins = coins
	g.remaining = 0
	g.finish_shift()
	return g

func check_service_cadence():
	var m = Service.new()
	m.advance(119.99)
	for i in range(3): m.complete_attempt("run-%d" % i)
	check(not m.eligible(), "Three attempts never meet the four-attempt gate")
	m.complete_attempt("run-3")
	check(not m.eligible(), "Four attempts at 119.99 seconds remain ineligible")
	m.advance(0.01)
	check(m.eligible(), "Four attempts and exactly 120 active seconds are eligible")
	check(not m.complete_attempt("run-3") and m.attempts == 4, "Repeated completed run identity cannot increment cadence")
	m.advance(-100)
	m.advance(INF)
	m.advance(NAN)
	check(m.active_seconds == 120, "Negative or nonfinite time cannot change the cooldown")
	for i in range(10): m.complete_attempt("extra-%d" % i)
	m.advance(1000)
	check(m.attempts == 4 and m.active_seconds == 120, "Cadence saturates instead of accumulating owed ads")
	m.ads_available = false
	check(m.request("interstitial").is_empty() and m.pending.is_empty(), "Unavailable interstitial creates no queued request")
	m.ads_available = true
	var request = m.request("interstitial")
	check(not request.is_empty() and m.attempts == 0 and m.active_seconds == 0, "A displayed automatic ad resets both cadence gates")
	check(m.request("rewarded", "run").is_empty(), "Only one fullscreen request may be in flight")
	request["kind"] = "forged"
	check(m.pending.kind == "interstitial", "Caller cannot mutate the service's pending request")
	var id = m.pending.id
	check(m.resolve("stale-id", "completed").is_empty(), "Stale provider callback is ignored")
	m.resolve(id, "completed")
	check(m.pending.is_empty() and m.resolve(id, "completed").is_empty(), "Ad completion resolves once and duplicates are ignored")
	m.attempts = 4
	m.active_seconds = 120
	request = m.request("rewarded", "earned-run")
	check(m.attempts == 0 and m.active_seconds == 0, "Rewarded ads share the automatic-ad interruption cooldown")
	var cancelled = m.resolve(request.id, "cancelled")
	check(not cancelled.granted, "Closing a rewarded ad early grants no bonus")
	m.entitlements.remove_ads = true
	m.attempts = 4
	m.active_seconds = 120
	check(not m.eligible() and m.request("interstitial").is_empty(), "Remove Automatic Ads suppresses forced advertisements")
	check(not m.request("rewarded", "voluntary-run").is_empty(), "Remove Automatic Ads retains voluntary rewarded ads")

func check_service_requests():
	var m = Service.new()
	check(m.request("unknown").is_empty() and m.request("purchase", "unknown").is_empty(), "Unknown operation and product cannot start a transaction")
	var request = m.request("purchase", "baker_toolkit")
	var id = request.id
	var pending_result = m.resolve(id, "pending")
	check(not pending_result.granted and not m.entitlements.baker_toolkit and m.pending.id == id, "Pending payment grants nothing and retains its callback identity")
	var completed = m.resolve(id, "completed")
	check(completed.granted and m.entitlements.baker_toolkit and m.store_owned.baker_toolkit, "Completed test purchase grants ownership and store receipt")
	check(m.resolve(id, "completed").is_empty() and m.request("purchase", "baker_toolkit").is_empty(), "Duplicate callbacks and repurchase cannot duplicate permanent benefits")
	m.entitlements.baker_toolkit = false
	check(m.restore_purchases() and m.entitlements.baker_toolkit, "Restoration recovers a store-owned permanent purchase")
	check(not m.restore_purchases(), "Repeated restoration makes no duplicate grant")
	for outcome in ["cancelled", "failed", "unavailable"]:
		request = m.request("purchase", "remove_ads")
		var resolution = m.resolve(request.id, outcome)
		check(not resolution.granted and not m.entitlements.remove_ads and not m.store_owned.remove_ads, "Purchase %s never grants ownership" % outcome)
	request = m.request("purchase", "remove_ads")
	var old_id = request.id
	m.reset_test_state()
	request = m.request("purchase", "remove_ads")
	check(request.id != old_id and m.resolve(old_id, "completed").is_empty(), "Reset cannot let an old callback complete a new purchase")

func check_service_persistence():
	var m = Service.new()
	m.advance(45.25)
	m.complete_attempt("saved-run")
	var purchase = m.request("purchase", "remove_ads")
	m.resolve(purchase.id, "completed")
	var state = m.export_state()
	var loaded = Service.new()
	check(loaded.import_state(JSON.parse_string(JSON.stringify(state))) and loaded.active_seconds == 45.25 and loaded.attempts == 1 and loaded.entitlements.remove_ads, "JSON round trip preserves cadence and permanent purchases")
	check(not loaded.complete_attempt("saved-run"), "Saved result identity remains counted only once after restart")
	var before = loaded.export_state()
	var malformed = state.duplicate(true)
	malformed.entitlements.remove_ads = "true"
	check(not loaded.import_state(malformed) and loaded.export_state() == before, "Malformed ownership is rejected atomically")
	malformed = state.duplicate(true)
	malformed.active_seconds = INF
	check(not loaded.import_state(malformed) and loaded.export_state() == before, "Nonfinite saved cooldown is rejected atomically")
	m.request("purchase", "baker_toolkit")
	loaded.import_state(m.export_state())
	check(loaded.pending.is_empty() and not loaded.entitlements.baker_toolkit, "Restart discards an unfinished payment without granting it")

func check_active_play():
	var g = fixture()
	g.start_shift()
	g.step(0.25)
	check(is_equal_approx(g.monetization.active_seconds, 0.25), "Campaign physics advances the active-play cooldown")
	for screen in ["paused", "home", "result", "shop", "test_ad", "test_purchase"]:
		g.mode = screen
		g.step(2)
		g._process(2)
	check(is_equal_approx(g.monetization.active_seconds, 0.25), "Menus, pause, results and service screens add no active time")
	g.mode = "play"
	g.remaining = 0.1
	g.step(20)
	check(is_equal_approx(g.monetization.active_seconds, 0.35), "Final physics tick only counts time remaining in the attempt")
	g.mode = "home"
	g.highest_unlocked = 4
	g.begin_trial(4)
	g.start_shift()
	g.step(0.5)
	g.remaining = 0
	g.finish_shift()
	check(is_equal_approx(g.monetization.active_seconds, 0.35) and g.monetization.attempts == 1, "Practice trials add neither active campaign time nor completed attempts")
	g.free()

func check_result_boundaries():
	var g = fixture()
	g.start_shift()
	g.mode = "paused"
	g.finish_shift()
	check(g.monetization.attempts == 0, "Early Finish and Collect does not count as a completed attempt")
	g.start_shift()
	g.level_won = true
	g.finish_shift()
	check(g.monetization.attempts == 1, "An early board clear counts as a completed attempt")
	g.finish_shift()
	check(g.monetization.attempts == 1, "Repeated finish calls do not double count an attempt")
	g.monetization.attempts = 3
	g.monetization.active_seconds = 120
	g.start_shift()
	g.remaining = 0
	g.finish_shift()
	check(g.mode == "test_ad" and g.monetization.pending.get("kind") == "interstitial", "The fourth eligible completion opens an automatic ad at the result boundary")
	g.save_game()
	var loaded = restart()
	check(loaded.mode == "result" and not loaded.shift_claimed and loaded.monetization.pending.is_empty(), "Restart during an automatic ad safely restores the result without replaying the ad")
	loaded.free()
	g.finish_test_request("completed")
	check(g.mode == "result" and not g.reward_earned, "Automatic ad completion returns to result without a rewarded bonus")
	g.monetization.attempts = 3
	g.monetization.active_seconds = 120
	g.monetization.ads_available = false
	g.start_shift()
	g.remaining = 0
	g.finish_shift()
	check(g.mode == "result" and g.monetization.pending.is_empty(), "Unavailable automatic ad lets the finished result proceed immediately")
	g.monetization.ads_available = true
	g._process(1)
	check(g.mode == "result" and g.monetization.pending.is_empty(), "Late ad availability cannot interrupt the existing result")
	g.free()

func check_rewarded_results():
	var g = result_game()
	g.collect_reward(true)
	check(is_equal_approx(g.bank, 10.10), "Legacy direct Collect(true) cannot forge a rewarded bonus")
	g.free()
	for outcome in ["cancelled", "failed", "unavailable"]:
		g = result_game()
		g.begin_rewarded_ad()
		g.finish_test_request(outcome)
		check(g.mode == "result" and not g.reward_earned and not g.shift_claimed and g.bank == 0, "Rewarded ad %s preserves the unclaimed base result" % outcome)
		g.free()
	g = result_game()
	g.monetization.ads_available = false
	g.begin_rewarded_ad()
	check(g.mode == "result" and not g.reward_earned and g.monetization.pending.is_empty(), "Missing rewarded inventory offers no bonus and does not strand results")
	g.monetization.ads_available = true
	g.begin_rewarded_ad()
	g.finish_test_request("completed")
	check(g.mode == "result" and g.reward_earned and not g.shift_claimed and g.bank == 0, "Completed rewarded ad records a bonus without prematurely collecting the result")
	g.finish_test_request("completed")
	check(g.reward_earned and g.bank == 0, "Duplicate reward callback cannot pay twice")
	check(g.save_game(), "Earned unclaimed ad bonus can be saved")
	var loaded = restart()
	check(loaded.mode == "result" and loaded.reward_earned, "Earned ad bonus survives restart with its pending result")
	loaded.collect_reward(false)
	check(is_equal_approx(loaded.bank, 15.15) and loaded.mode=="home", "Collection returns Home with 10.10 base plus the exact 5.05 rewarded bonus once")
	loaded.collect_reward(true)
	check(is_equal_approx(loaded.bank, 15.15), "Repeated collection cannot duplicate the earned bonus")
	loaded.save_game()
	loaded.free()
	loaded = restart()
	loaded.collect_reward(true)
	check(is_equal_approx(loaded.bank, 15.15) and loaded.mode != "result", "Claimed reward stays claimed after restart")
	loaded.free()
	g.free()

func check_purchases():
	var g = fixture()
	g.mode = "monetization"
	g.begin_test_purchase("remove_ads")
	check(g.mode == "test_purchase", "Test purchase opens an explicit fake checkout")
	g.finish_test_request("pending")
	check(not g.monetization.entitlements.remove_ads and not g.monetization.pending.is_empty(), "Pending test checkout grants nothing")
	g.save_game()
	var loaded = restart()
	check(not loaded.monetization.entitlements.remove_ads and loaded.monetization.pending.is_empty(), "Restart cannot complete a pending purchase")
	loaded.free()
	g.finish_test_request("completed")
	check(g.monetization.entitlements.remove_ads and g.monetization.store_owned.remove_ads, "Successful fake checkout grants Remove Automatic Ads")
	g.finish_test_request("completed")
	g.mode = "monetization_tools"
	g.clear_test_entitlements_for_restore()
	check(not g.monetization.entitlements.remove_ads and g.monetization.store_owned.remove_ads, "Restore test clears local access while preserving the fake store receipt")
	g.mode = "monetization"
	g.restore_test_purchases()
	check(g.monetization.entitlements.remove_ads, "Restore test recovers purchased ad removal")
	g.mode = "monetization"
	g.begin_test_purchase("baker_toolkit")
	g.finish_test_request("completed")
	g.start_shift()
	g.shift_coins = 10.10
	g.remaining = 0
	g.finish_shift()
	g.begin_rewarded_ad()
	g.finish_test_request("completed")
	g.collect_reward(false)
	check(is_equal_approx(g.bank, 17.17), "Toolkit adds 2.02 to 10.10 base credits and 5.05 rewarded bonus, without compounding")
	g.save_game()
	loaded = restart()
	check(loaded.monetization.entitlements.baker_toolkit and loaded.monetization.entitlements.remove_ads and is_equal_approx(loaded.bank, 17.17), "Purchases and exact decimal payout survive restart")
	loaded.free()
	g.free()

func check_progress_reset():
	clear_storage()
	var g = fixture()
	g.mode = "monetization"
	g.begin_test_purchase("remove_ads")
	g.finish_test_request("completed")
	g.mode = "monetization"
	g.begin_test_purchase("baker_toolkit")
	g.finish_test_request("completed")
	g.monetization.complete_attempt("pre-reset-run")
	g.monetization.advance(44)
	g.bank = 450
	var request = g.monetization.request("rewarded","pre-reset-reward")
	var serial: int = g.monetization.serial
	g.shift_claimed = true
	g.mode = "support"
	g.request_progress_reset()
	check(g.mode == "reset_confirm" and g.monetization.entitlements.remove_ads and g.bank == 450, "Reset confirmation keeps simulated benefits and wallet until explicitly confirmed")
	check(g.reset_progress() and g.bank == 0, "Confirmed progression reset returns to an empty wallet")
	check(not g.monetization.entitlements.remove_ads and not g.monetization.entitlements.baker_toolkit and not g.monetization.store_owned.remove_ads and not g.monetization.store_owned.baker_toolkit and g.monetization.pending.is_empty(), "Progression reset clears both fake products, store ownership and outstanding requests")
	check(g.monetization.attempts == 0 and g.monetization.active_seconds == 0 and g.monetization.serial >= serial and g.monetization.resolve(request.id,"completed").is_empty(), "Reset clears ad cadence while preventing old callbacks from becoming rewards")
	var loaded = restart()
	check(loaded.bank == 0 and not loaded.monetization.entitlements.baker_toolkit and not loaded.monetization.store_owned.remove_ads and loaded.monetization.serial >= serial, "Single-save restart retains the reset test-purchase state and callback guard")
	loaded.free()
	g.free()

func tap(g, rect: Rect2):
	# Advance past the existing tap-through guard between deliberate player actions.
	g.result_input_delay = 0
	g.navigation_delay = 0
	g.handle_press(rect.get_center())

func check_ui_routes():
	var g = fixture()
	var ui = g.monetization_ui
	g.mode = "support"
	tap(g, Rect2(48,920,624,96))
	check(g.mode == "monetization", "Settings button opens the monetization test shop")
	tap(g, ui.TOOLKIT)
	check(g.mode == "test_purchase" and g.monetization.pending.get("context") == "baker_toolkit", "Toolkit product button opens its fake checkout")
	tap(g, ui.PURCHASE_PENDING)
	var pending_id = g.monetization.pending.get("id")
	check(g.mode == "test_purchase" and not g.monetization.entitlements.baker_toolkit and pending_id != null, "Payment Pending button retains checkout without granting ownership")
	tap(g, ui.PURCHASE_APPROVE)
	check(g.mode == "monetization" and g.monetization.entitlements.baker_toolkit and g.monetization.pending.is_empty(), "Approve button completes pending checkout and returns to the shop")
	tap(g, ui.TOOLS)
	check(g.mode == "monetization_tools", "Test controls button opens the diagnostic controls")
	tap(g, ui.CLEAR_ENTITLEMENTS)
	check(not g.monetization.entitlements.baker_toolkit and g.monetization.store_owned.baker_toolkit, "Clear Local Benefits button keeps the restorable test receipt")
	tap(g, ui.TOOLS_BACK)
	var serial = g.monetization.serial
	tap(g, ui.TOOLKIT)
	check(g.mode == "monetization" and g.monetization.entitlements.baker_toolkit and g.monetization.pending.is_empty() and g.monetization.serial == serial, "Product Restore button restores ownership without opening another checkout")
	tap(g, ui.TOOLS)
	tap(g, ui.STAGE_BREAK)
	check(g.monetization.attempts == 3 and g.monetization.active_seconds == 120 and g.monetization.pending.is_empty(), "Stage Next Ad Break button prepares both gates without displaying an ad")
	tap(g, ui.TOOLS_BACK)
	tap(g, ui.SHOP_BACK)
	tap(g, Rect2(48,1080,624,96))
	tap(g, g.home_menu.PLAY_RECT)
	check(g.mode == "play" and g.monetization.pending.is_empty(), "Returning home and pressing Play never displays the staged ad")
	var launch_remaining: float = g.remaining
	g.step(.1)
	check(g.run_transition.active and g.remaining == launch_remaining and g.monetization.attempts == 3 and g.monetization.pending.is_empty(), "Home entry cannot consume gameplay or trigger the staged ad")
	g._process(g.run_transition.DURATION)
	check(not g.run_transition.active and g.mode == "play" and g.monetization.pending.is_empty(), "Completing Home entry starts gameplay without showing the staged ad")
	g.remaining = 0
	g.step(0)
	check(g.mode == "test_ad" and g.monetization.pending.get("kind") == "interstitial" and g.monetization.last_counted_run == g.run_id, "The next completed attempt opens the staged ad at its result boundary")
	tap(g, ui.AD_COMPLETE)
	check(g.mode == "result" and not g.reward_earned and g.monetization.pending.is_empty(), "Complete Test Ad button returns safely to the unclaimed result")
	g.free()
