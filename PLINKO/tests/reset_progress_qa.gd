extends SceneTree
## Destructive save fixtures: run only through the isolated Windows/Unix runner.
const Main = preload("res://scripts/main.gd")
const OLD_MAIN = "user://sugarfall_areas_v3.json"
const OLD_FRESH = "user://sugarfall_fresh_test_areas_v3.json"
const OLD_SELECTOR = "user://peg_foundry_profile.json"
const OLD_MAIN_V1 = "user://peg_foundry_v1.json"
const OLD_FRESH_V1 = "user://peg_foundry_fresh_test_v1.json"
const CUSTOM_SAVE = "user://reset_progress_custom_qa.json"

class ResetGame extends "res://scripts/main.gd":
	var fail_write = false
	var writes = 0
	var bank_at_write = -1.0
	var guide_at_write: Dictionary = {}
	var candidate: Dictionary = {}
	func write_profile_file(data: Dictionary) -> bool:
		writes += 1
		bank_at_write = bank
		guide_at_write = first_run_guide.export_state().duplicate(true)
		candidate = data.duplicate(true)
		if fail_write: return false
		return super.write_profile_file(data)

var passed = 0
var failed: Array[String] = []

func _initialize():
	if "--reset-qa-isolated" not in OS.get_cmdline_user_args():
		print("RESET_QA_REFUSED: Use isolated user-data directories and --reset-qa-isolated.")
		quit(2)
		return
	clear_storage()
	confirmation_and_guards()
	confirmation_gestures()
	reset_success_and_reload()
	reset_write_failure()
	migration_selection()
	migration_legacy_and_custom()
	reset_prevents_old_progress_returning()
	clear_storage()
	print("RESET_PROGRESS_QA_RESULT passed=",passed," failed=",failed.size())
	for issue in failed: print("FAIL: ",issue)
	quit(0 if failed.is_empty() else 1)

func check(ok: bool, label: String):
	if ok: passed += 1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)

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
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.000001
	return a == b

func fixture():
	var g = ResetGame.new()
	g.testing = true
	g.sound_on = false
	g.set_active_area("bakery")
	g.shift_claimed = true
	return g

func restart():
	var g = fixture()
	g.load_game()
	return g

func raw(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func read_json(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func write_json(path: String, value):
	var file = FileAccess.open(path,FileAccess.WRITE)
	assert(file != null,"QA storage must be writable")
	file.store_string(JSON.stringify(value,"",true,true))
	file.close()

func remove_file(path: String):
	if FileAccess.file_exists(path): assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)

func clear_storage():
	for base in [Main.SAVE_PATH,OLD_MAIN,OLD_FRESH,OLD_SELECTOR,OLD_MAIN_V1,OLD_FRESH_V1,CUSTOM_SAVE]:
		for path in [base,base+".tmp"]:
			var absolute = ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
				assert(DirAccess.remove_absolute(absolute) == OK,"QA cleanup failed")

func seed_progress(g):
	g.bank = 4321.75
	g.levels = [3,4,2,1,1,1,2,4]
	g.current_level = 12; g.highest_unlocked = 12; g.best_wave = 12; g.chapter_complete = true
	g.total_shifts = 23; g.run_serial = 81; g.last_claimed_run_id = "old-claimed-run"
	g.module_milestones = [2,5,8]; g.module_vouchers = 2; g.equipped = ["ricochet","impact"]
	g.trial_records = {"4":7.25,"8":10.1}
	g.area_records.bakery = g.AreaCampaign.capture_local(g)
	g.area_records.gelato = g.AreaCampaign.default_record()
	g.area_records.gelato.bank = 275.25
	g.area_records.gelato.levels = [1,0,0,0,0,0,0,0]
	g.area_records.gelato.merge(g.AreaCampaign.legacy_gelato_shop_state(g.area_records.gelato.levels,false,0),true)
	g.area_records.gelato.current_level = 3; g.area_records.gelato.highest_unlocked = 3
	g.area_entries = [{"id":"old-entry","source":"bakery","destination":"gelato","cost":40000}]
	g.set_active_area("gelato")
	g.AreaCampaign.apply_local(g,g.area_records.gelato)
	g.monetization.entitlements = {"remove_ads":true,"baker_toolkit":true}
	g.monetization.store_owned = {"remove_ads":true,"baker_toolkit":true}
	g.monetization.serial = 87
	g.monetization.attempts = 3; g.monetization.active_seconds = 115; g.monetization.last_counted_run = "old-ad-run"
	g.sound_on = false; g.reduced_motion = true
	g.first_run_guide.completed = true
	g.shift_claimed = true
	g.mode = "support"

func full_state(g) -> Dictionary:
	return {"campaign":g.campaign_profile(),"area":g.area_id,"areas":g.area_records.duplicate(true),"ledger":g.area_entries.duplicate(true),"trials":g.trial_records.duplicate(true),"serial":g.run_serial,"claimed":g.last_claimed_run_id,"commerce":g.monetization.export_state(),"request":g.monetization.pending.duplicate(true),"guide":g.first_run_guide.export_state(),"sound":g.sound_on,"reduced":g.reduced_motion,"mode":g.mode}

func confirmation_and_guards():
	clear_storage()
	var g = fixture(); seed_progress(g); g.save_game()
	var before = raw(Main.SAVE_PATH)
	var original = full_state(g)
	var writes: int = g.writes
	g.request_progress_reset()
	check(g.mode == "reset_confirm" and g.bank == 275.25 and g.writes == writes and raw(Main.SAVE_PATH) == before,"Settings Reset Progress opens confirmation without changing or saving progression")
	g.cancel_progress_reset()
	check(equal(full_state(g),original) and raw(Main.SAVE_PATH) == before,"Cancel returns to Settings with all state and save bytes unchanged")
	g.request_progress_reset(); g.navigation_delay = 0; g.go_back()
	check(g.mode == "support" and g.bank == 275.25 and raw(Main.SAVE_PATH) == before,"Back dismisses reset confirmation without erasing progress")
	for screen in ["home","play","paused","result","shop","guide","trials","monetization"]:
		g.mode = screen
		g.request_progress_reset()
		check(g.mode == screen and not g.reset_progress() and g.writes == writes,"Reset cannot be requested or executed directly from "+screen)
	g.mode = "support"; g.trial_active = true
	g.request_progress_reset()
	check(g.mode == "support" and not g.reset_progress(),"An active trial cannot open or execute reset")
	g.trial_active = false; g.run_id = "unclaimed-run"; g.shift_claimed = false
	g.request_progress_reset()
	check(g.mode == "support" and not g.reset_progress(),"Unclaimed gameplay cannot be discarded by a forced Settings reset request")
	check(not g.has_method("switch_test_profile") and not g.has_method("load_profile_choice"),"Runtime exposes one save with no profile switching API")
	var source = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(not source.contains('"Fresh test profile"') and not source.contains('"Return to main"') and not source.contains('"Main profile"'),"Settings no longer advertises profile selection controls")
	g.free()

func reset_success_and_reload():
	clear_storage()
	var g = fixture(); seed_progress(g); g.save_game()
	var old_bank: float = g.bank
	var old_guide: Dictionary = g.first_run_guide.export_state().duplicate(true)
	var old_request = g.monetization.request("rewarded","old-reward-context")
	var old_serial: int = g.monetization.serial
	g.special_stats = {"normal":99}; g.type_drops = {"normal":80}; g.total_spawned = 80
	g.shift_coins = 51; g.destroyed = 6; g.run_elapsed = 9
	g.request_progress_reset()
	check(g.reset_progress(),"Confirmed reset commits a fresh save successfully")
	check(g.bank_at_write == old_bank and g.guide_at_write == old_guide,"Fresh candidate is written before mutating the live campaign or guide")
	check(g.mode == "home" and g.area_id == "bakery" and g.bank == 0 and g.levels == [0,0,0,0,0,0,0,0] and g.current_level == 1 and g.highest_unlocked == 1,"Successful reset opens Bakery tray one with zero coins and upgrades")
	check(g.area_records.size() == 1 and equal(g.area_records.bakery,g.AreaCampaign.default_record()) and g.area_entries.is_empty() and g.trial_records.is_empty(),"Reset removes unlocked areas, entry history, milestones, equipment and trial records")
	check(g.total_shifts == 0 and g.run_serial == 0 and g.last_claimed_run_id.is_empty() and g.run_id.is_empty() and g.balls.is_empty() and g.pegs.is_empty() and g.pickups.is_empty() and g.shift_coins == 0 and g.destroyed == 0 and g.total_spawned == 0 and g.run_elapsed == 0,"Run, result and accumulated gameplay state are cleared")
	check(not g.sound_on and g.reduced_motion,"Reset preserves audio and Reduced Motion preferences")
	check(not g.monetization.entitlements.remove_ads and not g.monetization.entitlements.baker_toolkit and not g.monetization.store_owned.remove_ads and not g.monetization.store_owned.baker_toolkit,"Reset clears all simulated purchase benefits and fake store ownership")
	check(g.monetization.attempts == 0 and g.monetization.active_seconds == 0 and g.monetization.pending.is_empty() and g.monetization.serial >= old_serial,"Reset clears ad cadence and pending requests while retaining the request serial")
	check(g.monetization.resolve(old_request.id,"completed").is_empty(),"A pre-reset ad callback cannot grant a post-reset reward")
	check(g.first_run_guide.active and not g.first_run_guide.completed and g.first_run_guide.step_id == "welcome","Reset immediately shows Mabel's opening welcome")
	var data = read_json(Main.SAVE_PATH)
	check(not data.has("active_run") and not data.has("pending_result") and data.onboarding.active and data.onboarding.step == "welcome" and not data.has("onboarding_restart_pending"),"Fresh canonical save persists the introduction without old run/result or profile-only metadata")
	var writes: int = g.writes
	check(not g.reset_progress() and g.writes == writes,"A repeated confirmation cannot reset again after leaving the confirmation screen")
	var x = restart()
	check(x.mode == "home" and x.bank == 0 and x.current_level == 1 and x.area_records.size() == 1 and x.first_run_guide.active and x.first_run_guide.step_id == "welcome","Restart loads the same fresh campaign and opening welcome")
	check(not x.sound_on and x.reduced_motion and not x.monetization.entitlements.baker_toolkit and x.monetization.serial >= old_serial,"Reset preferences, cleared benefits and callback guard survive restart")
	x.free(); g.free()

func touch(g, p: Vector2, pressed: bool, index: int = 0, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.position = g.to_global(p); event.pressed = pressed; event.index = index; event.canceled = canceled
	g._input(event)

func confirmation_gestures():
	clear_storage()
	var g = fixture(); seed_progress(g); g.save_game(); g.request_progress_reset()
	var p: Vector2 = g.progress_reset_ui.RESET_RECT.get_center()
	var original = raw(Main.SAVE_PATH)
	var writes: int = g.writes
	touch(g,p,false)
	check(g.mode == "reset_confirm" and g.writes == writes,"An unmatched Settings release cannot confirm reset")
	touch(g,p,true); g.navigation_delay = 0; touch(g,p,false)
	check(g.mode == "reset_confirm" and g.writes == writes,"A contact started during the navigation guard cannot confirm later")
	touch(g,p,true)
	check(g.writes == writes and g.bank == 275.25,"Reset never activates on touch-down")
	touch(g,p,false,0,true)
	check(g.mode == "reset_confirm" and g.writes == writes,"A canceled confirmation tap cannot reset progress")
	touch(g,p,true)
	var event = InputEventScreenDrag.new(); event.index = 0; event.position = g.to_global(p+Vector2(35,0)); g._input(event)
	touch(g,p,false)
	check(g.mode == "reset_confirm" and g.writes == writes,"Dragging then returning to the Reset button cannot become a confirmation")
	touch(g,p,true,2); touch(g,p+Vector2(10,0),true,7); touch(g,p+Vector2(10,0),false,7); touch(g,p,false,2)
	check(g.mode == "reset_confirm" and g.writes == writes,"A second finger permanently cancels the pending reset tap")
	for code in [KEY_ENTER,KEY_SPACE]:
		var key = InputEventKey.new(); key.keycode = code; key.pressed = true; g._input(key)
	check(g.mode == "reset_confirm" and g.writes == writes,"Enter and Space do not confirm a destructive reset")
	touch(g,p,true); g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); touch(g,p,false)
	check(g.mode == "reset_confirm" and g.writes == writes,"Focus loss cancels the pending reset contact")
	var cancel: Vector2 = g.progress_reset_ui.CANCEL_RECT.get_center()
	touch(g,cancel,true); touch(g,cancel,false)
	check(g.mode == "support" and raw(Main.SAVE_PATH) == original,"A stable Cancel tap leaves progression and save bytes intact")
	g.request_progress_reset(); g.navigation_delay = 0
	touch(g,p,true); touch(g,p,false)
	check(g.mode == "home" and g.bank == 0 and g.first_run_guide.active and g.writes == writes+1,"One deliberate stable Reset tap commits exactly once and shows Mabel")
	touch(g,p,false)
	check(g.writes == writes+1,"A duplicate release cannot repeat the reset")
	g.free()

func reset_write_failure():
	clear_storage()
	var g = fixture(); seed_progress(g); g.save_game()
	g.request_progress_reset()
	var before = full_state(g)
	var saved = raw(Main.SAVE_PATH)
	g.fail_write = true
	check(not g.reset_progress() and equal(full_state(g),before) and raw(Main.SAVE_PATH) == saved,"Failed atomic reset write preserves the entire live state and previous save")
	g.fail_write = false
	var path = ProjectSettings.globalize_path(Main.SAVE_PATH+".tmp")
	assert(DirAccess.make_dir_absolute(path) == OK)
	check(not g.reset_progress() and equal(full_state(g),before) and raw(Main.SAVE_PATH) == saved,"A real temporary-file write failure cannot erase progression")
	assert(DirAccess.remove_absolute(path) == OK)
	check(g.reset_progress() and g.bank == 0 and g.first_run_guide.active,"Retry succeeds after the write failure is removed")
	g.free()

func stored_save(path: String, coins: float):
	var g = fixture()
	g.SAVE_FILE = path; g.bank = coins; g.first_run_guide.completed = true
	g.save_game(); g.free()

func migration_selection():
	clear_storage()
	stored_save(OLD_MAIN,111); stored_save(OLD_FRESH,222)
	var old_main = raw(OLD_MAIN); var old_fresh = raw(OLD_FRESH)
	write_json(OLD_SELECTOR,{"version":1,"fresh":true})
	var g = restart()
	check(g.SAVE_FILE == Main.SAVE_PATH and g.bank == 222 and FileAccess.file_exists(Main.SAVE_PATH),"Absent canonical save migrates the previously selected Fresh progress into the one save")
	check(raw(OLD_MAIN) == old_main and raw(OLD_FRESH) == old_fresh,"Migration preserves retired files as recovery copies")
	g.free()
	write_json(OLD_SELECTOR,{"version":1,"fresh":false})
	g = restart()
	check(g.bank == 222,"Once created, the canonical save ignores retired profile selection")
	g.free()
	for value in [null,[],{}, {"version":2,"fresh":true}, {"version":"1","fresh":true}, {"version":true,"fresh":true}, {"version":1,"fresh":1}, {"version":1,"fresh":"true"}, {"version":1,"fresh":true,"padding":"x".repeat(200)}]:
		remove_file(Main.SAVE_PATH)
		write_json(OLD_SELECTOR,value)
		g = restart()
		check(g.bank == 111,"Malformed retired selector chooses the old main save safely: "+JSON.stringify(value).left(65))
		g.free()
	remove_file(Main.SAVE_PATH); remove_file(OLD_FRESH)
	write_json(OLD_SELECTOR,{"version":1,"fresh":true})
	g = restart()
	check(g.bank == 111,"Missing previously selected Fresh save falls back to the existing old main save")
	g.free()

func migration_legacy_and_custom():
	clear_storage()
	var g = fixture()
	var legacy = g.campaign_profile()
	legacy.merge({"version":1,"balance_revision":4,"bank":333.25,"sound":false,"reduced_motion":true},true)
	g.free()
	write_json(OLD_MAIN_V1,legacy)
	g = restart()
	check(g.bank == 333.25 and g.reduced_motion and read_json(Main.SAVE_PATH).version == Main.PROFILE_VERSION,"Original v1 main progression migrates into the current canonical area save")
	g.free()
	remove_file(Main.SAVE_PATH)
	legacy.bank = 444.5
	write_json(OLD_FRESH_V1,legacy); write_json(OLD_SELECTOR,{"version":1,"fresh":true})
	g = restart()
	check(g.bank == 444.5,"Previously selected original v1 Fresh progression migrates without reset")
	g.free()
	remove_file(Main.SAVE_PATH)
	g = fixture(); g.SAVE_FILE = CUSTOM_SAVE; g.load_game()
	check(g.bank == 0 and not FileAccess.file_exists(CUSTOM_SAVE) and g.legacy_profile_path().is_empty(),"Custom fixture saves cannot discover or migrate any retired player files")
	g.free()
	write_json(Main.SAVE_PATH,{"broken":"canonical"})
	g = restart()
	check(g.profile_load_blocked and g.bank == 0 and read_json(Main.SAVE_PATH).has("broken"),"An unreadable canonical save blocks loading instead of silently resurrecting retired progress")
	g.mode = "support"; g.request_progress_reset()
	check(g.reset_progress() and not g.profile_load_blocked and g.first_run_guide.active,"Explicit confirmed reset can recover an unreadable canonical save")
	g.free()

func reset_prevents_old_progress_returning():
	clear_storage()
	stored_save(OLD_MAIN,8000); stored_save(OLD_FRESH,9000)
	write_json(OLD_SELECTOR,{"version":1,"fresh":true})
	var g = restart()
	g.mode = "support"; g.request_progress_reset(); g.reset_progress(); g.free()
	write_json(OLD_SELECTOR,{"version":1,"fresh":false})
	g = restart()
	check(g.bank == 0 and g.current_level == 1 and g.first_run_guide.active,"Restart after reset stays fresh even while old saves and profile selector remain")
	check(not g.has_method("switch_test_profile") and g.SAVE_FILE == Main.SAVE_PATH,"There is no in-game path back to a second profile after reset")
	g.free()
