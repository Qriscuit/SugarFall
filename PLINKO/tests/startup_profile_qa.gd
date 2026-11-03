extends SceneTree
## Production startup/main with JSON writes only in a probed disposable user directory.
const Campaign = preload("res://scripts/area_campaign.gd")
const Snapshot = preload("res://scripts/run_snapshot.gd")
const SAVE = "user://sugarfall_save.json"
var passed = 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var warmed_resources: Dictionary = {}

class Seeder extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass

class InterruptedReady extends "res://scripts/main.gd":
	var before_bytes: PackedByteArray
	var guarded = false
	func load_game():
		before_bytes = FileAccess.get_file_as_bytes(SAVE_FILE)
		_notification(NOTIFICATION_APPLICATION_PAUSED)
		_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		guarded = not profile_initialization_complete and FileAccess.get_file_as_bytes(SAVE_FILE) == before_bytes
		super.load_game()

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func equal(a,b) -> bool:
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
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < .000001
	return a == b

func bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SAVE) if FileAccess.file_exists(SAVE) else PackedByteArray()

func disk() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return value if value is Dictionary else {}

func clear_fixture_files():
	# Exact filenames only, after validating the isolated user root.
	for name in ["sugarfall_save.json","sugarfall_save.json.tmp","sugarfall_areas_v3.json","peg_foundry_v1.json","peg_foundry_profile.json","sugarfall_fresh_test_areas_v3.json","peg_foundry_fresh_test_v1.json"]:
		var path = "user://"+name
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func seed_profile(kind: String, area: String, reduced: bool) -> Dictionary:
	clear_fixture_files()
	if kind == "fresh": return {}
	if kind == "blocked":
		var file = FileAccess.open(SAVE,FileAccess.WRITE)
		file.store_string("{corrupt-existing-progress\n"); file.close()
		return {}
	var g = Seeder.new()
	g.testing = true; g.sound_on = false; g.reduced_motion = reduced
	g.set_active_area(area); Campaign.apply_local(g,Campaign.default_record())
	g.first_run_guide.completed = true; g.first_run_guide.active = false
	g.bank = 2345.67; g.highest_unlocked = 9; g.current_level = 6
	g.levels = [2,2,1,1,1,1,1,2]; g.equipped = ["splitter","impact"]
	if area == "gelato":
		g.twin_launchers = true; g.power_reset_tier = 6; g.gelato_shop_revision = 0
		check(g.ensure_gelato_shop_state(),"Seed Gelato Twin/rebuild ownership is valid")
	if area == "crystal": g.crystal_second_prism = true
	g.area_records = {"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.area_records.bakery.bank = 111; g.area_records.gelato.bank = 222; g.area_records.crystal.bank = 333
	if kind in ["paused","result"]:
		g.start_shift()
		g.spawn_ball(Vector2(360,300),"normal",Vector2(50,330))
		g.step(.1)
		g.shift_coins = 42.5
		if kind == "result": g.mode = "result"
		else:
			g.mode = "paused"
			var checked = Snapshot.validate_and_decode(Snapshot.capture(g),g)
			check(checked.ok,"Seed "+area+" checkpoint satisfies strict production validator: "+str(checked.get("reason","")))
	g.testing = false
	check(g.save_game(),"Seed "+kind+" "+area+" writes a valid isolated profile")
	var record = disk()
	g.free()
	return record

func state(g) -> Dictionary:
	return {"mode":g.mode,"area":g.area_id,"bank":g.bank,"levels":g.levels.duplicate(),"records":g.area_records.duplicate(true),
		"run_serial":g.run_serial,"run_id":g.run_id,"claimed":g.shift_claimed,"remaining":g.remaining,"elapsed":g.elapsed,
		"run_elapsed":g.run_elapsed,"spawn_clock":g.spawn_clock,"checkpoint_clock":g.checkpoint_clock,
		"rng":str(g.rng.state),"coins":g.shift_coins,"balls":g.balls.duplicate(true),"pegs":g.pegs.duplicate(true),
		"pickups":g.pickups.duplicate(true),"guide":g.first_run_guide.export_state(),"guide_age":g.first_run_guide.age,
		"guide_revealed":g.first_run_guide.revealed,"last_claimed":g.last_claimed_run_id,"crystal_run":g.crystal_run.duplicate(true)}

func try_hidden_actions(g):
	for point in [Vector2(360,580),Vector2(360,800),Vector2(360,900),Vector2(650,60)]:
		var event = InputEventScreenTouch.new()
		event.position = point; event.index = 0; event.pressed = true
		g._input(event); event.pressed = false; g._input(event)
		g.handle_press(point)
	g.go_back(); g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	g._process(6.0); g._physics_process(6.0); g.step(6.0); g.start_shift(true)

func interrupted_ready():
	var expected = seed_profile("paused","crystal",false)
	var g = InterruptedReady.new()
	g.startup_blocked = true; g.profile_initialization_complete = false
	root.add_child(g)
	check(g.guarded,"Focus/pause/close inside real _ready before restore preserve existing profile bytes")
	check(g.profile_initialization_complete and g.mode == "paused" and g.area_id == "crystal","Real _ready completes interrupted initialization with Crystal paused")
	check(equal(Snapshot.capture(g),expected.active_run),"Initialization guard retains every restored active-run field")
	g.free()

func run_case(kind: String, area: String, reduced: bool):
	var label = kind+"/"+area+("/reduced" if reduced else "")
	var expected = seed_profile(kind,area,reduced)
	var original = bytes()
	var startup = load("res://startup.tscn").instantiate()
	root.add_child(startup)
	startup.set_process(false)
	check(startup.audio_preference_read and (startup.hum_start_count==1 if kind=="fresh" else startup.hum_start_count==0),label+": saved Sound off or unreadable profile prevents any startup audio before main restore")
	startup._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not startup.hum.playing or startup.hum.stream_paused,label+": startup voice is silent while backgrounded")
	await process_frame
	check(startup.game == null and bytes() == original,label+": background before deferred loading leaves disk untouched")
	var early_time = startup.heartbeat_elapsed
	startup._process(30.0)
	check(startup.heartbeat_elapsed == early_time and startup.handoff_count == 0,label+": suspended startup neither pulses nor hands off")
	startup._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await process_frame
	var deadline = Time.get_ticks_msec()+90000
	while startup.status == "loading" and Time.get_ticks_msec() < deadline:
		startup._poll_loading()
		await process_frame
	check(startup.status == "ready",label+": actual threaded resources reach ready ("+str(startup.error_resource)+")")
	if startup.status != "ready":
		startup.free(); return
	var g = startup.game
	# Repeated restart cases share one process; retain resources like the first
	# initialized game does instead of churning all textures between fixtures.
	if warmed_resources.is_empty(): warmed_resources = startup.loaded_resources.duplicate()
	g.set_process(false); g.set_physics_process(false)
	check(g.profile_initialization_complete and g.startup_blocked,label+": actual main initialized under studio input/time gate")
	if kind == "fresh":
		check(g.mode == "home" and g.area_id == "bakery" and g.bank == 0 and g.run_serial == 0,label+": fresh profile stays at Home without starting a run")
		check(g.first_run_guide.active and g.first_run_guide.step_id == "welcome",label+": first-use guide remains at welcome")
	elif kind == "blocked":
		check(g.profile_load_blocked and bytes() == original,label+": corrupt profile blocks writes and preserves bytes")
	else:
		check(g.area_id == area and g.bank == expected.areas[area].bank and equal(g.levels,expected.areas[area].levels),label+": wallet and full upgrade build restored")
		check(equal(g.area_records,expected.areas),label+": all three independent area records retained")
		check(g.reduced_motion == reduced and startup.reduced_motion == reduced,label+": saved motion preference honored before handoff")
		check(bytes() == original,label+": valid startup restore does not rewrite profile bytes")
		if kind == "paused":
			check(g.mode == "paused" and g.resumed_run and equal(Snapshot.capture(g),expected.active_run),label+": full active snapshot including RNG/balls/pickups restored paused")
		elif kind == "result":
			check(g.mode == "result" and not g.shift_claimed and g.run_id == expected.pending_result.run_id and g.shift_coins == expected.pending_result.coins,label+": pending reward restored once and remains unclaimed")
		else: check(g.mode == "home",label+": existing profile opens Home")
	var before = state(g)
	var before_bytes = bytes()
	try_hidden_actions(g)
	check(equal(state(g),before) and bytes() == before_bytes,label+": taps, Back, direct Start and clocks cannot act behind studio")
	startup._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	startup._process(100.0)
	check(equal(state(g),before) and startup.handoff_count == 0,label+": post-ready background stays suspended with gameplay unchanged")
	if kind == "blocked": check(bytes() == original,label+": lifecycle cannot overwrite blocked profile")
	elif kind == "paused": check(equal(disk().active_run,expected.active_run),label+": post-ready lifecycle saves exact paused checkpoint")
	elif kind == "result": check(disk().pending_result.run_id == expected.pending_result.run_id and disk().areas[area].bank == expected.areas[area].bank,label+": lifecycle preserves pending reward without wallet credit")
	startup._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	startup.heartbeat_elapsed = startup.MINIMUM_SECONDS
	startup.frames_shown = 2
	startup._handoff()
	check(startup.handoff_count == 1 and startup.status == "handed_off" and not g.startup_blocked and current_scene == g,label+": one actual handoff assigns initialized main scene")
	check(not startup.hum.playing or startup.hum_releasing,label+": actual handoff stops the hum or bounds its short release tail")
	startup._handoff()
	check(startup.handoff_count == 1,label+": duplicate handoff is harmless")
	check(equal(state(g),before),label+": handoff preserves destination and player state")
	check(g.page_transition.active == not reduced,label+": cream wipe follows saved motion preference")
	if not reduced:
		var cover_state = state(g)
		g._process(.2); g._physics_process(.2); g.step(.2)
		check(equal(state(g),cover_state),label+": cream cover freezes game state")
		g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(not g.page_transition.active and g.mode == before.mode,label+": background during wipe settles presentation without changing destination")
	if kind == "blocked": check(bytes() == original,label+": entire startup leaves corrupt profile byte-identical")
	if kind == "paused": check(equal(Snapshot.capture(g),expected.active_run),label+": lifecycle plus wipe preserve exact paused run")
	if kind == "result":
		g.navigation_delay = 0; g.result_input_delay = 0
		g.collect_reward()
		var once = g.bank
		g.collect_reward()
		check(g.shift_claimed and g.bank == once and g.last_claimed_run_id == expected.pending_result.run_id,label+": pending result can be claimed exactly once after handoff")
	cases.append({"case":label,"destination":before.mode,"area":g.area_id,"reduced_motion":reduced,"loader_resources":startup.total_resources})
	current_scene = null
	g.free()
	await process_frame

func _initialize():
	var expected = OS.get_environment("SUGARFALL_STARTUP_QA_USER_DIR").replace("\\","/").trim_suffix("/")
	var actual = OS.get_user_data_dir().replace("\\","/").trim_suffix("/")
	if expected.is_empty() or actual != expected or "sugarfall-startup-profile-" not in actual or "--startup-profile-isolated" not in OS.get_cmdline_user_args():
		push_error("Startup profile QA requires the explicitly probed isolated user directory"); quit(2); return
	call_deferred("run_all")

func preference_discovery():
	var startup = load("res://scripts/startup.gd").new()
	clear_fixture_files()
	check(startup._read_startup_preferences()=={"reduced_motion":false,"sound_on":true},"Fresh install starts with default sound and motion preferences")
	for path in ["user://sugarfall_save.json","user://sugarfall_areas_v3.json","user://peg_foundry_v1.json"]:
		clear_fixture_files()
		var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"sound":false,"reduced_motion":true})); file.close()
		var before=FileAccess.get_file_as_bytes(path)
		check(startup._read_startup_preferences()=={"reduced_motion":true,"sound_on":false} and FileAccess.get_file_as_bytes(path)==before,"Startup peeks persisted sound/motion without writes: "+path)
	clear_fixture_files()
	var selector=FileAccess.open("user://peg_foundry_profile.json",FileAccess.WRITE); selector.store_string('{"version":1,"fresh":true}'); selector.close()
	var selected=FileAccess.open("user://peg_foundry_fresh_test_v1.json",FileAccess.WRITE); selected.store_string('{"sound":false,"reduced_motion":true}'); selected.close()
	check(startup._read_startup_preferences()=={"reduced_motion":true,"sound_on":false},"Legacy fresh-profile selector uses the same preference discovery order as main")
	var canonical=FileAccess.open(SAVE,FileAccess.WRITE); canonical.store_string('{"sound":true,"reduced_motion":false}'); canonical.close()
	check(startup._read_startup_preferences()=={"reduced_motion":false,"sound_on":true},"Canonical profile takes precedence over a legacy selector")
	clear_fixture_files()
	startup.free()

func run_all():
	preference_discovery()
	interrupted_ready()
	await run_case("fresh","bakery",false)
	for area in ["bakery","gelato","crystal"]:
		await run_case("normal",area,false)
		await run_case("paused",area,false)
		await run_case("result",area,false)
	await run_case("normal","gelato",true)
	await run_case("paused","crystal",true)
	await run_case("blocked","bakery",false)
	var report = {"passed":passed,"failed":failures.size(),"failures":failures,"cases":cases,"user_dir":OS.get_user_data_dir(),"scope":"Actual threaded startup/main and isolated disk profiles; desktop lifecycle injection, no physical Android claim"}
	var output = OS.get_environment("SUGARFALL_STARTUP_QA_REPORT")
	if not output.is_empty():
		var file = FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  ",true,true)); file.close()
	print("STARTUP_PROFILE_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
