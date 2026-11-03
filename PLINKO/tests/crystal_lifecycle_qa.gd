extends SceneTree
## Missing Crystal integration cases; uses only the runner's isolated disk file.
const Campaign = preload("res://scripts/area_campaign.gd")
const Graph = preload("res://scripts/crystal_upgrade_graph.gd")
const Snapshot = preload("res://scripts/run_snapshot.gd")
var passed = 0
var failures: Array[String] = []
var save_path = ""

class Fixture extends "res://scripts/main.gd":
	var fail_write = false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func legacy_profile_path() -> String: return ""
	func write_profile_file(data: Dictionary) -> bool:
		return false if fail_write else super.write_profile_file(data)

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ", label)

func equal(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not equal(a[index], b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a)-float(b)) < .000001
	return a == b

func fixture(area: String = "crystal"):
	var g = Fixture.new()
	g.testing = false; g.sound_on = false; g.SAVE_FILE = save_path
	g.first_run_guide.active = false; g.first_run_guide.completed = true
	g.set_active_area(area); Campaign.apply_local(g, Campaign.default_record())
	g.area_records = {"bakery": Campaign.default_record()}
	if area != "bakery": g.area_records[area] = Campaign.default_record()
	g.mode = "home"; g.shift_claimed = true; g.run_id = ""
	g.run_transition.finish(); g.navigation_delay = 0; g.result_input_delay = 0
	return g

func restart():
	var g = fixture("bakery")
	g.load_game()
	return g

func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(save_path))

func clean_file():
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path+suffix):
			assert(DirAccess.remove_absolute(save_path+suffix) == OK)

func paid_entry_and_roundtrip():
	clean_file()
	var g = fixture("bakery")
	g.bank = 800; g.levels = [2,1,0,0,0,0,1,0]
	g.sound_on = true; g.reduced_motion = true
	g.monetization.entitlements = {"remove_ads":true,"baker_toolkit":true}
	g.monetization.store_owned = g.monetization.entitlements.duplicate()
	var gelato = Campaign.default_record()
	gelato.bank = 2000; gelato.current_level = 12; gelato.highest_unlocked = 12; gelato.chapter_complete = true
	g.area_records.gelato = gelato
	check(g.save_game(), "Paid-entry fixture is stored in the isolated profile")
	var bytes = FileAccess.get_file_as_bytes(save_path)
	var before = disk()
	g.fail_write = true
	check(not g.enter_area("crystal") and g.area_id == "bakery" and g.bank == 800, "Failed paid-entry disk write retains the active Bakery state")
	check(FileAccess.get_file_as_bytes(save_path) == bytes and not g.area_records.has("crystal"), "Failed paid entry preserves file bytes and does not grant Crystal")
	g.fail_write = false
	check(g.enter_area("crystal"), "Real paid entry commits Crystal from the Bakery area picker")
	var record = disk()
	check(record.active_area_id == "crystal" and record.areas.crystal.bank == 0 and record.areas.gelato.bank == 500 and record.areas.bakery.bank == 800, "One disk transaction charges only Gelato and creates a zero-wallet Crystal record")
	check(record.area_entries.size() == 1 and record.area_entries[0].source == "gelato" and record.area_entries[0].destination == "crystal", "Durable entry ledger names the correct paying predecessor")
	var loaded = restart()
	check(not loaded.profile_load_blocked and loaded.area_id == "crystal" and loaded.levels == [0,0,0,0,0,0,0,0], "Fresh process fixture reloads paid Crystal ownership and empty upgrades")
	check(loaded.sound_on and loaded.reduced_motion and equal(loaded.monetization.entitlements,before.monetization_test.entitlements), "Paid entry/reload keeps global settings and entitlements")
	bytes = FileAccess.get_file_as_bytes(save_path)
	check(not loaded.enter_area("crystal") and FileAccess.get_file_as_bytes(save_path) == bytes, "Repeated paid entry cannot charge twice or rewrite the completed ledger")
	check(loaded.switch_area("bakery") and loaded.bank == 800 and loaded.levels == [2,1,0,0,0,0,1,0], "Real revisit restores the independent Bakery build")
	check(loaded.switch_area("crystal") and loaded.bank == 0 and loaded.area_records.gelato.bank == 500, "Returning to Crystal is free and retains the Gelato remainder")
	loaded.free(); g.free()

func purchases_and_full_tree():
	clean_file()
	var g = fixture()
	g.mode = "shop"; g.highest_unlocked = 12; g.bank = 1000000
	check(g.save_game(), "Ordinary-purchase fixture is durable")
	var bytes = FileAccess.get_file_as_bytes(save_path)
	var previous = Campaign.capture_local(g)
	g.note = "before"; g.note_time = 2.0; g.fail_write = true
	check(not g.buy_upgrade_node(0,1) and equal(Campaign.capture_local(g),previous), "Failed ordinary Crystal purchase restores every local progression field")
	check(FileAccess.get_file_as_bytes(save_path) == bytes and g.note == "before" and g.note_time == 2.0, "Failed ordinary purchase leaves file bytes and presentation intact")
	g.fail_write = false
	var purchased = 0
	var legal = true
	var exact = true
	var duplicate_safe = true
	for node in Graph.nodes():
		var cost = g.upgrade_cost(node.x)
		var bank = g.bank
		var old_levels = g.levels.duplicate()
		legal = legal and g.shop_node_unlocked(node.x,node.y) and g.buy_upgrade_node(node.x,node.y)
		exact = exact and g.bank == bank-cost and g.levels[node.x] == old_levels[node.x]+1
		for family in range(8):
			if family != node.x: exact = exact and g.levels[family] == old_levels[family]
		bank = g.bank
		duplicate_safe = duplicate_safe and not g.buy_upgrade_node(node.x,node.y) and g.bank == bank
		purchased += 1
	check(purchased == 62 and legal and exact and g.levels == g.MAX_LEVELS, "Every ordinary Crystal slot follows legal prerequisites, exact one-tier grants and exact debits")
	check(duplicate_safe, "All 62 owned nodes reject duplicate purchases without spending")
	var bank = g.bank
	check(g.crystal_launcher.buy() and g.bank == bank-900 and g.crystal_second_prism, "The 63rd position buys Second Prism without resetting the completed tree")
	var loaded = restart()
	check(equal(Campaign.capture_local(loaded),Campaign.capture_local(g)), "All 63 purchased positions survive real disk reload")
	loaded.free(); g.free()

func trial_restore_and_records():
	clean_file()
	var g = fixture()
	g.highest_unlocked = 12; g.current_level = 8; g.bank = 4321.25
	g.levels = [4,5,3,2,2,2,3,4]; g.crystal_second_prism = true
	g.module_vouchers = 1; g.module_milestones = [2,5]; g.equipped = ["ricochet","impact"]
	g.trial_records = {"4":11.25}
	g.monetization.entitlements = {"remove_ads":true,"baker_toolkit":true}
	g.monetization.store_owned = g.monetization.entitlements.duplicate()
	g.sound_on = false; g.reduced_motion = true
	check(g.save_game(), "Non-default Crystal campaign, modules, Trial records and entitlements save")
	var baseline = Campaign.capture_local(g)
	var shifts = g.total_shifts
	var history = g.result_history.export_state()
	check(g.begin_trial(8) and g.trial_active and not g.crystal_second_prism and g.bank == 0 and g.levels == Snapshot.TRIAL_LEVELS, "Trial uses its standard build and suppresses campaign Second Prism")
	g.start_shift(); g.run_transition.finish()
	for _index in range(30): g.step(1.0/120.0)
	check(g.save_game(), "Active Crystal Trial checkpoint writes while the campaign build stays separate")
	var record = disk()
	check(record.areas.crystal.crystal_second_prism and record.areas.crystal.bank == baseline.bank and record.active_run.trial_active and not record.active_run.crystal_second_prism, "Disk separates owned campaign Prism and wallet from the temporary Trial state")
	var loaded = restart()
	check(loaded.mode == "paused" and loaded.trial_active and not loaded.crystal_second_prism and loaded.trial_snapshot.crystal_second_prism, "Restart resumes the Trial paused and retains the campaign Prism for restoration")
	check(equal(Campaign.capture_local(loaded),baseline), "Trial reload preserves every non-default campaign field")
	loaded.end_trial()
	check(not loaded.trial_active and equal(Campaign.capture_local(loaded),baseline) and loaded.crystal_second_prism, "Leaving the resumed Trial restores the full campaign build and Second Prism")
	var again = restart()
	check(equal(Campaign.capture_local(again),baseline) and again.reduced_motion and again.monetization.entitlements.baker_toolkit, "Restored campaign and global settings remain correct on the next restart")
	again.mode = "trials"
	check(again.begin_trial(8), "A later Trial can start after restoration")
	again.start_shift(); again.run_transition.finish()
	again.mode = "play"; again.remaining = 0; again.run_elapsed = 12.0; again.level_won = true
	again.destroyed = again.pegs.size(); again.special_stats.normal = again.destroyed
	again.balls.clear(); again.clear_draining = false
	check(again.finish_shift(false) and again.trial_records.get("8",0) == 12.0, "Completed Trial stores its new area-local best time")
	again.collect_reward()
	var expected = baseline.duplicate(true); expected.trial_records["8"] = 12.0
	check(equal(Campaign.capture_local(again),expected) and again.total_shifts == shifts and equal(again.result_history.export_state(),history), "Trial result retains its best time without paying coins or replacing campaign history")
	var final_load = restart()
	check(equal(Campaign.capture_local(final_load),expected) and final_load.crystal_second_prism, "Trial best time and campaign restoration both survive disk reload")
	final_load.free(); again.free(); loaded.free(); g.free()

func stage_result(g, wave: int, coins: float, won: bool):
	g.current_level = wave; g.highest_unlocked = maxi(g.highest_unlocked,wave)
	g.mode = "home"; g.shift_claimed = true
	g.start_shift(); g.run_transition.finish()
	g.remaining = 0; g.run_elapsed = g.BASE_SECONDS+g.levels[7]*g.CLOCK_STEP
	g.shift_coins = coins; g.level_won = won; g.clear_draining = false; g.balls.clear()
	if won:
		g.destroyed = g.pegs.size(); g.special_stats.normal = g.destroyed
		for peg in g.pegs: peg.hp = 0
	return g.finish_shift(false)

func result_rewards_milestones_and_loadout():
	clean_file()
	var g = fixture()
	g.bank = 100
	g.monetization.entitlements.baker_toolkit = true
	g.monetization.store_owned.baker_toolkit = true
	check(stage_result(g,2,40,true), "Crystal completed campaign result is durably staged before collection")
	var run_id = g.run_id
	var loaded = restart()
	check(loaded.mode == "result" and loaded.run_id == run_id and not loaded.shift_claimed and loaded.bank == 100, "Unclaimed Crystal result reloads without prematurely paying coins")
	check(loaded.result_history.areas.crystal.latest.run_id == run_id and loaded.result_history.areas.crystal.previous.is_empty(), "Result history records the run once on finish and does not duplicate it on reload")
	loaded.begin_rewarded_ad()
	check(loaded.mode == "test_ad" and loaded.monetization.pending.kind == "rewarded", "Crystal result routes to the existing rewarded test request")
	loaded.finish_test_request("completed")
	loaded.finish_test_request("completed")
	check(loaded.reward_earned and loaded.bank == 100 and loaded.monetization.pending.is_empty(), "Completed callback authorizes one bonus without paying it early; repeated callback is inert")
	var earned = restart()
	check(earned.reward_earned and earned.mode == "result" and earned.result_payout() == 68, "Earned bonus survives restart with 40 base, 8 Toolkit and 20 rewarded coins")
	var pending_bytes = FileAccess.get_file_as_bytes(save_path)
	earned.fail_write = true
	earned.collect_reward()
	check(earned.bank == 168 and earned.shift_claimed and FileAccess.get_file_as_bytes(save_path) == pending_bytes, "Failed collection save keeps the durable pending result recoverable without mutating disk")
	var recovered = restart()
	check(recovered.mode == "result" and recovered.bank == 100 and recovered.reward_earned, "Restart after a failed collection write recovers the unpaid durable result")
	recovered.collect_reward()
	check(recovered.bank == 168 and recovered.module_vouchers == 1 and recovered.module_milestones == [2] and recovered.current_level == 3, "Collection pays exact bonuses and grants the tray 2 milestone once")
	recovered.collect_reward(true)
	check(recovered.bank == 168 and recovered.module_vouchers == 1, "Repeated Collect cannot pay or award the milestone again")
	var claimed = restart()
	claimed.collect_reward(true)
	check(claimed.bank == 168 and claimed.mode == "home" and claimed.last_claimed_run_id == run_id, "Claimed result stays claimed across restart")
	claimed.mode = "shop"
	check(claimed.buy_upgrade_node(0,1) and claimed.buy_upgrade_node(7,1), "Real starter and Time purchases reach the Ricochet voucher node legally")
	var wallet = claimed.bank
	check(claimed.claim_module("ricochet") and claimed.module_vouchers == 0 and claimed.levels[3] == 1 and claimed.bank == wallet, "Earned voucher unlocks its legal module without spending the Crystal wallet")
	claimed.toggle_module("ricochet")
	check(claimed.equipped.is_empty(), "Crystal loadout can unequip an owned module")
	claimed.toggle_module("ricochet")
	var equipped = restart()
	check(equipped.equipped == ["ricochet"] and equipped.levels[3] == 1 and equipped.module_vouchers == 0, "Loadout and consumed voucher survive real disk reload")
	check(stage_result(equipped,2,10,true), "Replaying an already-rewarded milestone produces a separate result")
	var second_run = equipped.run_id
	equipped.collect_reward()
	check(equipped.module_vouchers == 0 and equipped.module_milestones == [2], "Replaying tray 2 cannot create another milestone voucher")
	check(equipped.result_history.areas.crystal.latest.run_id == second_run and equipped.result_history.areas.crystal.previous.run_id == run_id, "Two distinct campaign runs retain the correct latest/previous history")
	var final_load = restart()
	check(final_load.result_history.areas.crystal.latest.run_id == second_run and final_load.result_history.areas.crystal.previous.run_id == run_id and final_load.equipped == ["ricochet"], "History, milestone and loadout remain stable on final restart")
	final_load.free(); equipped.free(); claimed.free(); recovered.free(); earned.free(); loaded.free(); g.free()

func touch(g, point: Vector2, pressed: bool, canceled: bool = false, index: int = 0):
	var event = InputEventScreenTouch.new()
	event.position = point; event.index = index; event.pressed = pressed; event.canceled = canceled
	g._input(event)

func tap_after_wait(g, point: Vector2):
	# Explicitly model the navigation debounce expiring before the next action.
	g.navigation_delay = 0; g.result_input_delay = 0
	touch(g,point,true); touch(g,point,false)

func menu_input_flow():
	clean_file()
	var g = fixture()
	g.testing = true; g.highest_unlocked = 12; g.current_level = 8
	g.bank = 1000; g.levels = [3,4,2,1,1,1,2,3]; g.crystal_second_prism = true
	g.equipped = ["ricochet","impact"]
	var before = Campaign.capture_local(g)
	tap_after_wait(g,g.home_menu.MENU_RECT.get_center())
	tap_after_wait(g,g.home_menu.HELP_RECT.get_center())
	check(g.mode == "guide" and not g.home_menu.menu_open, "Actual Home menu touches open Crystal Help and clear Home gestures")
	tap_after_wait(g,Vector2(360,1173))
	tap_after_wait(g,g.home_menu.MENU_RECT.get_center())
	tap_after_wait(g,g.home_menu.TRIALS_RECT.get_center())
	check(g.mode == "trials", "Help return and Home menu touches reach Crystal Trials")
	tap_after_wait(g,Vector2(360,570))
	check(g.mode == "loadout" and g.trial_active and g.current_level == 8 and not g.crystal_second_prism, "Tray 8 Trial touch opens its temporary loadout without campaign Second Prism")
	tap_after_wait(g,Vector2(360,355))
	check(g.equipped == ["splitter"], "Real Trial loadout card touch toggles a module")
	tap_after_wait(g,Vector2(360,1128)); g.run_transition.finish()
	check(g.mode == "play" and g.trial_active, "Trial loadout Play touch starts the Crystal run")
	tap_after_wait(g,Vector2(632,70))
	check(g.mode == "paused", "Gameplay Pause touch enters pause without collecting a Prism")
	tap_after_wait(g,Vector2(360,948))
	check(g.mode == "abandon_confirm", "Pause End Run touch requires the existing confirmation screen")
	tap_after_wait(g,Vector2(360,698))
	check(g.mode == "result" and g.trial_active, "Confirmed Trial exit reaches its result through actual input routing")
	tap_after_wait(g,Vector2(360,848))
	check(g.mode == "trials" and not g.trial_active and equal(Campaign.capture_local(g),before), "Trial result touch restores the original campaign wallet, upgrades, loadout and Prism")
	tap_after_wait(g,Vector2(360,1128))
	tap_after_wait(g,g.home_menu.UPGRADES_RECT.get_center())
	check(g.mode == "shop" and g.home_menu.touches.is_empty(), "Gameplay-to-Trials-to-Home-to-upgrades flow leaves no stale Home touch")
	g.free()

func input_and_reward_conservation():
	clean_file()
	var g = fixture()
	g.testing = true
	g.start_shift(); g.run_transition.finish()
	g.spawn_clock = 100; g.spawn_ball(Vector2(360,400),"normal",Vector2.DOWN)
	g.run_elapsed = 3; g.crystal_launcher.advance(0)
	var point = g.board_to_screen(g.crystal_run.offer_position)
	var aim = Vector2(g.aim_x,g.aim_y)
	touch(g,point,false,true)
	check(g.balls.size() == 1 and g.crystal_run.collected == 0 and Vector2(g.aim_x,g.aim_y) == aim, "Canceled primary release cannot collect the Crystal Prism or steer")
	touch(g,point,true,false,1)
	check(g.balls.size() == 1 and g.crystal_run.collected == 0, "Extra finger cannot steal the Prism from primary input")
	g.clear_area_transients(); g.mode = "shop"; g.bank = 1000; g.navigation_delay = 0; g.result_input_delay = 0
	g.upgrade_map.reset_view_state(); g.upgrade_map.update(0)
	g.upgrade_map.selected = 0; g.upgrade_map.tier = 1; g.upgrade_map.update(g.upgrade_map.CAMERA_DURATION)
	var buy = g.upgrade_map.buy_rect().get_center()
	touch(g,buy,true); touch(g,buy,false,true)
	check(g.bank == 1000 and g.levels[0] == 0 and g.upgrade_map.touch_points.is_empty(), "Canceled Crystal shop purchase cannot spend and clears gesture state")
	touch(g,buy,true)
	var drag = InputEventScreenDrag.new()
	drag.index = 0; drag.position = buy+Vector2(50,0); drag.relative = Vector2(50,0)
	g._input(drag); touch(g,buy,false)
	check(g.bank == 1000 and g.levels[0] == 0 and g.upgrade_map.overlay_touches.is_empty(), "Dragging away and back across Crystal Buy cannot spend")
	touch(g,buy,true); touch(g,buy,true,false,1)
	touch(g,buy,false,false,1); touch(g,buy,false)
	check(g.bank == 1000 and g.levels[0] == 0 and g.upgrade_map.overlay_touches.is_empty(), "Two-finger Crystal Buy sequence is disarmed until every finger lifts")
	g.upgrade_map.selected = 0; g.upgrade_map.tier = 1
	var cost = g.upgrade_cost(0)
	touch(g,buy,true); touch(g,buy,false)
	var after = g.bank
	touch(g,buy,false)
	check(g.levels[0] == 1 and after == 1000-cost and g.bank == after, "One clean release buys once; duplicate release cannot buy another Crystal node")
	g.clear_area_transients(); g.mode = "home"; g.levels = [0,0,0,0,0,0,0,0]; g.current_level = 1
	g.start_shift(); g.run_transition.finish(); g.spawn_clock = 100
	g.pegs = [{"p":Vector2(360,500),"hp":2.0,"max":2.0,"kind":"normal","flash":0.0}]
	g.balls.clear(); g.shift_coins = 0; g.destroyed = 0
	g.spawn_ball(Vector2(360,450),"normal",Vector2.DOWN)
	check(g.crystal_launcher.duplicate_live_balls() == 1, "Reward-conservation case contains an original shot and a Prism clone")
	g.step(.2)
	check(g.destroyed == 1 and g.clear_draining and g.shift_coins == 60, "Original plus clone pay one 8-coin damage budget, one 2-coin break and one 50-coin clear")
	var coins = g.shift_coins
	g.damage_peg(g.pegs[0],1000)
	check(g.shift_coins == coins and g.destroyed == 1, "Repeated damage on the depleted Crystal peg cannot farm coins or clears")
	g.free()

func _initialize():
	save_path = OS.get_environment("SUGARFALL_CRYSTAL_LIFECYCLE_QA_SAVE")
	var expected = OS.get_user_data_dir().replace("\\","/")+"/"
	if save_path.is_empty() or not save_path.is_absolute_path() or not save_path.replace("\\","/").begins_with(expected) or "--crystal-lifecycle-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Crystal lifecycle QA requires its verified isolated path and opt-in flag"); quit(2); return
	paid_entry_and_roundtrip()
	purchases_and_full_tree()
	trial_restore_and_records()
	result_rewards_milestones_and_loadout()
	menu_input_flow()
	input_and_reward_conservation()
	clean_file()
	print("CRYSTAL_LIFECYCLE_QA_RESULT passed=%d failed=%d" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)
