extends SceneTree
## Production mode interception and clocks; profiles are in-memory only.
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var saves = 0
	var loads = 0
	var saved_run: Dictionary = {}
	func _ready(): pass
	func save_game():
		saves += 1
		saved_run = RunSnapshot.capture(self).duplicate(true)
		return true
	func _load_game_impl():
		loads += 1
		mode = "home"
		mode = "paused"

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area: String = "bakery"):
	var g = Fixture.new()
	g.testing = true; g.sound_on = false
	g.set_active_area(area)
	g.current_level = 4; g.highest_unlocked = 12; g.bank = 1234
	g.levels = [2,1,1,1,1,1,2,1]; g.equipped = ["splitter","impact"]
	g.first_run_guide.active = false; g.first_run_guide.completed = true
	g.navigation_delay = 0; g.result_input_delay = 0
	return g

func state(g) -> Dictionary:
	var value = g.RunSnapshot.capture(g).duplicate(true)
	value.erase("run_id")
	return value

func equal(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equal(a[i],b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < .00000001
	return a == b

func touch(g, point: Vector2, pressed: bool, index: int = 0, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.position = point; event.pressed = pressed; event.index = index; event.canceled = canceled
	g._input(event)

func settle(g):
	g._process(g.page_transition.DURATION+1)
	g._process(0.0)
	g.navigation_delay = 0; g.result_input_delay = 0

func controller_contract():
	var g = fixture()
	check(not g.page_transition.enabled and not g.page_transition.active,"Startup and isolated fixtures begin with page presentation disabled")
	g.mode = "support"
	check(g.mode == "support" and not g.page_transition.active,"Disabled mode writes remain immediate without an invisible wait")
	g.mode = "home"; g.page_transition.enabled = true; g.mode = "support"
	check(g.mode == "support" and g.page_transition.active and g.page_transition.from_mode == "home" and g.page_transition.to_mode == "support","Logical page commits immediately while its original page is retained for presentation")
	var image = Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var marker = ImageTexture.create_from_image(image)
	g.page_transition.snapshot = marker
	g.page_transition.update(.12)
	var time = g.page_transition.time
	g.mode = "monetization"; g.mode = "test_purchase"
	check(g.mode == "test_purchase" and g.page_transition.to_mode == "test_purchase" and g.page_transition.from_mode == "home" and g.page_transition.snapshot == marker and g.page_transition.time == time,"Synchronous chained mode writes coalesce without recapture or restarting the wipe")
	g.mode = "test_purchase"
	check(g.page_transition.time == time and g.page_transition.snapshot == marker,"Same-mode assignment preserves an in-flight page transition")
	for invalid in [-1.0,0.0,NAN,INF]:
		check(not g.page_transition.update(invalid) and g.page_transition.time == time,"Invalid/nonpositive delta cannot advance page presentation: "+str(invalid))
	g.page_transition.enabled = false
	check(not g.page_transition.is_blocking() and g.page_transition.snapshot == null and g.page_transition.progress() == 1.0,"Disabling presentation releases its snapshot and input gate")
	g.page_transition.enabled = true
	for destination in ["home","shop","boards","guide","support","developer_areas","reset_confirm","loadout","trials","monetization","monetization_tools","test_ad","test_purchase","play","result","bonus_confirm"]:
		g.page_transition.enabled = false; g.mode = "fixture_previous"; g.page_transition.enabled = true
		g.mode = destination
		check(g.mode == destination and g.page_transition.active and g.page_transition.to_mode == destination,"Mode setter covers "+destination)
		g.page_transition.finish()
	g.free()

func coverage_geometry():
	var g = fixture()
	g.page_transition.enabled = true; g.mode = "shop"
	for bounds in [Rect2(0,0,720,1280),Rect2(0,0,450,800),Rect2(-40,-60,800,1400)]:
		g.page_transition.time = 0
		var opening = g.page_transition.geometry(bounds)
		check(opening.covering and not opening.body.has_area() and opening.image.position.y >= bounds.end.y,"Wipe starts outside all content, including safe-area extensions: "+str(bounds))
		g.page_transition.time = g.page_transition.DURATION*.5
		var middle = g.page_transition.geometry(bounds)
		check(not middle.covering and middle.fully_covered and middle.body == bounds and middle.image.position.y >= bounds.end.y,"Opaque body covers every viewport pixel at the page-swap midpoint: "+str(bounds))
		g.page_transition.time = g.page_transition.DURATION
		var finished = g.page_transition.geometry(bounds)
		check(not finished.covering and not finished.body.has_area() and finished.image.end.y <= bounds.position.y+.0001,"Wipe exits fully above content without a residual white strip: "+str(bounds))
	g.page_transition.time = g.page_transition.DURATION*.5
	check(g.page_transition.covered(),"Public covered() reports guaranteed opaque midpoint")
	check(g.page_transition.WAVE_REGION == Rect2(0,0,1536,768) and g.page_transition.BODY_JOIN_Y == 520,"Wave uses native crest crop and joins opaque body before the artwork fade")
	g.free()

func input_gating():
	var g = fixture()
	g.page_transition.enabled = true
	touch(g,g.home_menu.UPGRADES_RECT.get_center(),true,17)
	check(g.home_menu.touches.size() == 1 and g.mode == "home","Home action waits for its clean release")
	touch(g,g.home_menu.UPGRADES_RECT.get_center(),false,17)
	check(g.mode == "shop" and g.page_transition.active and g.home_menu.touches.is_empty(),"Real Home release starts the page wipe and clears outgoing touches")
	g.navigation_delay = 0; g.result_input_delay = 0
	g.upgrade_map.selected = 0; g.upgrade_map.tier = 1
	var bank = g.bank
	var buy = g.upgrade_map.buy_rect().get_center()
	touch(g,buy,true); touch(g,buy,false)
	g.handle_press(g.upgrade_map.PLAY_RECT.get_center())
	g.go_back()
	var escape = InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	g._input(escape); g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(g.mode == "shop" and g.bank == bank and g.levels[0] == 2 and g.run_serial == 0,"Active wipe rejects destination purchase, Play, Escape and Android Back")
	check(g.upgrade_map.touch_points.is_empty() and g.upgrade_map.overlay_touches.is_empty(),"Input is gated before child menus can retain new touches")
	settle(g)
	touch(g,g.upgrade_map.MENU_RECT.get_center(),true); touch(g,g.upgrade_map.MENU_RECT.get_center(),false)
	check(g.mode == "home" and g.page_transition.active,"Destination menu accepts a new clean gesture after settlement")
	g.page_transition.finish()
	# A mode change during any old gesture discards its pending activation.
	g.home_menu.touches[0] = Vector2.ZERO
	g.upgrade_map.touch_points[0] = Vector2.ZERO
	g.upgrade_map.overlay_touches[1] = Vector2.ZERO
	g.level_map.touch_points[0] = Vector2.ZERO
	g.first_run_guide._touches[0] = Vector2.ZERO
	g.progress_reset_ui._touches[0] = Vector2.ZERO
	g.developer_area_ui._touches[0] = Vector2.ZERO
	g.mode = "support"
	check(g.home_menu.touches.is_empty() and g.upgrade_map.touch_points.is_empty() and g.upgrade_map.overlay_touches.is_empty() and g.level_map.touch_points.is_empty() and g.first_run_guide._touches.is_empty() and g.progress_reset_ui._touches.is_empty() and g.developer_area_ui._touches.is_empty(),"Page begin cancels every gameplay-guide and menu gesture owner")
	g.free()

func clocks_and_resume():
	for area in ["bakery","gelato","crystal"]:
		var g = fixture(area)
		g.testing = false; g.page_transition.enabled = true
		g.start_shift(true)
		check(g.mode == "play" and not g.page_transition.active and g.run_transition.active and g.saves == 1,"One initialized "+area+" run uses the matching Home tray morph without cream")
		var before = state(g)
		var checkpoint = g.checkpoint_clock
		var ad = g.monetization.active_seconds
		g.bank_coin_feedback.age = .1; g.run_coin_feedback.age = .2
		g.step(.2); g._physics_process(.2); g._process(.15)
		check(equal(before,state(g)) and g.checkpoint_clock == checkpoint and g.monetization.active_seconds == ad and g.saves == 1,"Run, RNG, checkpoint and ad clocks remain frozen under "+area+" entrance")
		check(g.bank_coin_feedback.age == .1 and g.run_coin_feedback.age == .2 and g.elapsed == 0,"Both coin pulses and visual time wait for the "+area+" entrance to settle")
		g.start_shift(true)
		check(g.run_serial == 1 and g.saves == 1,"Repeated direct start cannot create a second "+area+" run during entry")
		g._process(10.0)
		check(not g.page_transition.active and not g.run_transition.active and equal(before,state(g)) and g.checkpoint_clock == checkpoint,"Ending/stalled render frame cannot charge its delta to the "+area+" run")
		g._process(.1)
		check(not g.page_transition.is_blocking() and is_equal_approx(g.checkpoint_clock,checkpoint-.1),"Next render frame restores normal "+area+" checkpoint cadence")
		g.step(1.0/60.0)
		var control = fixture(area); control.start_shift(); control.step(1.0/60.0)
		check(equal(state(g),state(control)),"First resumed "+area+" physics tick matches a directly started control")
		g.mode = "paused"
		check(not g.page_transition.active and g.pause_transition.active,"Pause fades over the "+area+" board without cream")
		settle(g); g.go_back()
		check(g.mode == "play" and not g.page_transition.active and g.pause_transition.active and g.run_serial == 1,"Resume fades back to the same "+area+" run without cream or a duplicate attempt")
		control.free(); g.free()

func guide_and_lifecycle():
	var g = fixture()
	g.first_run_guide.active = true; g.first_run_guide.step_id = "welcome"
	g.first_run_guide.age = .2; g.first_run_guide.revealed = 4
	g.page_transition.enabled = true; g.mode = "shop"
	g._process(.15)
	check(g.first_run_guide.age == .2 and g.first_run_guide.revealed == 4,"Guide typewriter and lesson advancement remain frozen beneath the outgoing snapshot")
	g.free()
	for notification in [Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		g = fixture("crystal"); g.testing = false; g.page_transition.enabled = true
		g.start_shift(true); g._process(.1)
		var before = state(g)
		g._notification(notification)
		check(g.mode == "paused" and not g.page_transition.is_blocking() and g.page_transition.enabled and g.page_transition.snapshot == null,"Lifecycle event settles and suppresses hidden transitions: "+str(notification))
		check(equal(before,state(g)) and g.saves == 2 and not g.saved_run.is_empty(),"Lifecycle event saves the logical paused run exactly once: "+str(notification))
		g._process(1); g.step(1)
		check(equal(before,state(g)) and g.checkpoint_clock == 5,"Background time does not consume run/checkpoint time: "+str(notification))
		g.free()
	g = fixture("gelato"); g.page_transition.enabled = true; g.start_shift()
	var saved = g.RunSnapshot.capture(g)
	check(g.restore_active_run(saved) and g.mode == "paused" and not g.page_transition.is_blocking() and g.page_transition.enabled,"Restore bypasses page presentation and returns the existing run paused")
	g.mode = "support"; g.load_game()
	check(g.loads == 1 and g.mode == "paused" and not g.page_transition.is_blocking() and g.page_transition.enabled,"Load wrapper suppresses all chained restore mode writes and restores the enable flag")
	g.free()

func reduced_motion():
	var g = fixture()
	g.page_transition.enabled = true; g.reduced_motion = true
	g.home_menu.touches[0] = Vector2.ZERO
	g.first_run_guide._touches[0] = Vector2.ZERO
	g.mode = "support"
	check(not g.page_transition.is_blocking() and g.mode == "support","Reduced Motion swaps menu pages immediately")
	check(g.home_menu.touches.is_empty() and g.first_run_guide._touches.is_empty(),"Reduced Motion still clears outgoing gestures before an immediate page swap")
	g.start_shift(true)
	check(not g.page_transition.is_blocking() and not g.run_transition.active and g.mode == "play","Reduced Motion avoids both page and legacy Home entrance animations")
	g.step(.1)
	check(g.run_elapsed > 0,"Reduced Motion gameplay has no hidden page-animation delay")
	g.reduced_motion = false; g.mode = "paused"
	g.reduced_motion = true; g._process(.01)
	check(not g.page_transition.active and g.page_transition.snapshot == null and not g.pause_transition.active and g.pause_transition.menu_alpha == 1.0,"Enabling Reduced Motion settles the pause fade immediately without a cream snapshot")
	g.page_transition.finish(); g.mode = "support"; g.page_transition.enabled = false
	g.mode = "home"; g.start_shift(true)
	check(not g.page_transition.active and not g.run_transition.active,"Disabled fixture behavior and Reduced Motion remain deterministic")
	g.free()

func result_state(g) -> Dictionary:
	return {"pegs":g.pegs.duplicate(true),"balls":g.balls.duplicate(true),"buckets":g.buckets.duplicate(true),"pickups":g.pickups.duplicate(true),"particles":g.particles.duplicate(true),"floats":g.floats.duplicate(true),"remaining":g.remaining,"run_elapsed":g.run_elapsed,"elapsed":g.elapsed,"rng":g.rng.state,"bank":g.bank,"coins":g.shift_coins,"levels":g.levels.duplicate(),"history":g.result_history.export_state()}

func result_routing_and_claims():
	var ResultUI = load("res://scripts/result_comparison_ui.gd")
	check(ResultUI.PANEL_RECT.encloses(ResultUI.COLLECT_RECT) and ResultUI.PANEL_RECT.encloses(ResultUI.BONUS_RECT) and ResultUI.TRIAL_PANEL_RECT.encloses(ResultUI.COLLECT_RECT),"Result and Trial actions remain wholly inside their modal panels")
	for area in ["bakery","gelato","crystal"]:
		for ending in ["timeout","clear","early"]:
			var g = fixture(area)
			g.page_transition.enabled = true; g.start_shift()
			g.shift_coins = 20.5; g.elapsed = 3.7
			if ending == "clear":
				g.level_won = true; g.destroyed = g.pegs.size()
				for peg in g.pegs: peg.hp = 0
			elif ending == "timeout": g.remaining = 0
			else:
				g.mode = "paused"; settle(g)
			check(g.finish_shift(false) and g.mode == "result" and not g.page_transition.is_blocking(),area+" "+ending+" opens its result window without cream")
			var before = result_state(g)
			g.handle_press(ResultUI.COLLECT_RECT.get_center())
			check(not g.shift_claimed and equal(before,result_state(g)),area+" "+ending+" retains the existing result tap delay")
			g._process(1); g._physics_process(1); g.step(1)
			check(equal(before,result_state(g)),area+" "+ending+" freezes board, RNG, animation time, coins and upgrades under the result window")
			g.handle_press(Vector2(12,600)); g.go_back()
			check(g.mode == "result" and not g.shift_claimed and not g.page_transition.active,area+" "+ending+" cannot dismiss or replay the run through the dimmed background or Back")
			g.navigation_delay = 0; g.result_input_delay = 0
			var payout = g.collection_payout(); var wallet = g.bank
			g.handle_press(ResultUI.COLLECT_RECT.get_center()); g.collect_reward()
			check(g.mode == "home" and g.shift_claimed and g.bank == g.safe_credits(wallet+payout) and g.page_transition.active,area+" "+ending+" Collect pays once and returns through normal menu navigation")
			g.free()
		var g = fixture(area)
		g.page_transition.enabled = true; g.start_shift(); g.shift_coins = 30; g.remaining = 0
		g.monetization.attempts = 3; g.monetization.active_seconds = 130
		g.finish_shift(true)
		check(g.mode == "test_ad" and not g.page_transition.active and g.monetization.pending.kind == "interstitial",area+" automatic test ad keeps end-of-run flow free of cream")
		g.finish_test_request("cancelled")
		check(g.mode == "result" and not g.page_transition.active and not g.shift_claimed,area+" automatic ad cancellation returns to the same unclaimed result window")
		g.navigation_delay = 0; g.result_input_delay = 0
		g.handle_press(ResultUI.BONUS_RECT.get_center())
		check(g.mode == "bonus_confirm" and not g.page_transition.active,area+" optional reward confirmation stays in the modal flow")
		g.result_input_delay = 0; g.navigation_delay = 0; g.begin_rewarded_ad()
		check(g.mode == "test_ad" and not g.page_transition.active,area+" rewarded test request does not cover the result with cream")
		g.finish_test_request("completed")
		check(g.mode == "result" and g.reward_earned and not g.page_transition.active and not g.shift_claimed,area+" earned bonus returns to the same result and still requires Collect")
		g.page_transition.begin("studio","result")
		check(g.page_transition.active and g.page_transition.from_mode == "studio",area+" startup still uses cream when restoring a pending result")
		g.free()
		g = fixture(area)
		g.page_transition.enabled = true; g.begin_trial(4)
		settle(g); g.start_shift(); settle(g); g.remaining = 0
		var saved_wallet = g.trial_snapshot.bank
		g.finish_shift(false)
		check(g.mode == "result" and g.trial_active and not g.page_transition.active,area+" Trial completion uses the same immediate result-window route")
		g.navigation_delay = 0; g.result_input_delay = 0
		g.handle_press(ResultUI.BONUS_RECT.get_center())
		check(g.mode == "result" and g.monetization.pending.is_empty(),area+" Trial result has no campaign reward action")
		g.handle_press(ResultUI.COLLECT_RECT.get_center())
		check(g.mode == "trials" and not g.trial_active and g.bank == saved_wallet,area+" Back to trials restores the campaign wallet without a payout")
		g.free()

func _initialize():
	controller_contract()
	coverage_geometry()
	input_gating()
	clocks_and_resume()
	guide_and_lifecycle()
	reduced_motion()
	result_routing_and_claims()
	print("PAGE_TRANSITION_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
