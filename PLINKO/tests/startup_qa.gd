extends SceneTree
## Loader/controller tests never discover or write a normal player profile.
const Startup = preload("res://scripts/startup.gd")
const STARTUP_SCENE = preload("res://startup.tscn")
var passed = 0
var failures: Array[String] = []

class LoaderFixture extends "res://scripts/startup.gd":
	var plan: Dictionary = {}
	var requests: Dictionary = {}
	var takes: Dictionary = {}
	var preparations = 0
	var preference_reads = 0
	func _read_reduced_motion() -> bool:
		preference_reads += 1
		return false
	func _request_resource(path: String) -> Error:
		requests[path] = int(requests.get(path,0))+1
		return ERR_CANT_OPEN if plan.get(path,{}).get("reject",false) else OK
	func _resource_status(path: String, progress: Array) -> int:
		var entry = plan.get(path,{})
		progress.append(float(entry.get("progress",0)))
		return int(entry.get("status",ResourceLoader.THREAD_LOAD_LOADED))
	func _take_resource(path: String) -> Resource:
		takes[path] = int(takes.get(path,0))+1
		return null if plan.get(path,{}).get("status") == ResourceLoader.THREAD_LOAD_FAILED else Resource.new()
	func _prepare_game():
		preparations += 1
		status = "ready"
	func _handoff():
		if status != "ready" or suspended: return
		status = "handed_off"
		handoff_count += 1

class GameFixture extends "res://scripts/main.gd":
	var saves = 0
	var saved: Dictionary = {}
	func _ready(): pass
	func save_game():
		saves += 1
		saved = RunSnapshot.capture(self).duplicate(true)
		return true
	func load_game(): assert(false,"Unit fixture must not load a profile")

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture():
	# Preserve the actual authored children/material while replacing only loader
	# hooks. The production _ready still binds and lays out the real controls.
	var scene = STARTUP_SCENE.instantiate()
	var g = LoaderFixture.new()
	for child in scene.get_children():
		clear_scene_owner(child)
		scene.remove_child(child); g.add_child(child)
	scene.free()
	g.testing = true
	root.add_child(g)
	g.set_process(false); g.set_process_input(false)
	return g

func clear_scene_owner(node):
	node.owner = null
	for child in node.get_children(): clear_scene_owner(child)

func queue_fixture(g, paths: Array[String]):
	g.status = "loading"; g.queued = paths.duplicate(); g.total_resources = paths.size()
	g.pending.clear(); g.loaded_resources.clear(); g.loading_progress = 0
	g._fill_requests()

func heartbeat_and_native_layout():
	check(Startup.heartbeat_at(0) == 0 and Startup.heartbeat_at(.03) == 0 and Startup.heartbeat_at(.70) == 0,"Native engine still and quiet runtime heartbeat use exactly zero pulse")
	check(Startup.heartbeat_at(.14) > .99 and Startup.heartbeat_at(.30) > .54 and Startup.heartbeat_at(.30) < .57,"Heartbeat has one strong beat and one smaller second thump")
	check(is_equal_approx(Startup.heartbeat_at(.14),Startup.heartbeat_at(1.04)),"Heartbeat repeats every 0.9 seconds")
	var bounded = true
	for tick in range(901):
		var value = Startup.heartbeat_at(tick*.01)
		bounded = bounded and value >= 0 and value <= 1
	check(bounded,"All sampled heartbeat strengths stay within shader bounds")
	var g = fixture()
	check(g.preference_reads == 0 and g.status == "preview" and g.requests.is_empty(),"Opted-in scene fixture bypasses preference discovery and automatic loading")
	check(g.stamp.texture.get_size() == Vector2(301,855),"Production scene retains the supplied native stamp dimensions")
	var viewport = root.get_visible_rect().size
	var expected = 600*minf(viewport.x/720.0,viewport.y/1280.0)
	check(is_equal_approx(g.stamp.size.y,expected) and is_equal_approx(g.stamp.size.x/g.stamp.size.y,301.0/855.0),"Runtime logo keeps native aspect and matches the centered 600px engine still fit")
	check(g.stamp.position+g.stamp.size*.5 == viewport*.5,"Stamp stays centered in the actual viewport")
	check(g.stamp.pivot_offset == Vector2(g.stamp.size.x*.5,g.stamp.size.y),"Warm heartbeat is anchored at the stamp bottom center")
	var anchor = g.stamp.get_transform()*g.stamp.pivot_offset
	g.heartbeat_elapsed = .14; g._render_heartbeat()
	check(is_equal_approx(g.stamp.scale.x,1.055) and g.stamp.material.get_shader_parameter("heartbeat") > .99,"Strong beat changes runtime scale and shader contrast together")
	check(g.stamp.get_transform()*g.stamp.pivot_offset == anchor,"Scaling leaves the stamp bottom-center anchor exactly fixed")
	check(g.background.material.get_shader_parameter("heartbeat") > .99,"The warm spotlight follows the same heartbeat as the native mark")
	g.reduced_motion = true; g._render_heartbeat()
	check(g.stamp.scale == Vector2.ONE and g.stamp.material.get_shader_parameter("heartbeat") == 0,"Reduced Motion keeps the original stamp completely still")
	g.free()

func warm_hum_contract():
	var g = fixture()
	var original_stream = g.hum.stream
	check(original_stream is AudioStreamWAV and absf(original_stream.get_length()-.9)<.001,"Original warm hum is a real 0.9-second WAV matching the pulse cycle")
	g._start_hum()
	check(not g.hum.playing and g.hum_start_count==0,"Startup cannot make sound before preference discovery")
	g.audio_preference_read = true; g.sound_on = false; g._start_hum()
	check(not g.hum.playing and g.hum_start_count==0,"Saved Sound off prevents the first sample from playing")
	g.sound_on = true; g.heartbeat_elapsed = .14; g._start_hum(); g._start_hum()
	check(g.hum.playing and g.hum_start_count==1,"Repeated start requests retain one playing hum without duplicate voices")
	check(g.hum.stream!=original_stream and g.hum.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Loop settings apply to a private WAV instance")
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED); g._process(10)
	check(g.hum.stream_paused and is_equal_approx(g.heartbeat_elapsed,.14),"Background pauses the hum and heartbeat together")
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED); g._process(10)
	check(not g.hum.stream_paused and g.hum.playing and g.hum_start_count==1 and is_equal_approx(g.heartbeat_elapsed,.14),"Resume realigns the same voice without spending background time")
	g.heartbeat_elapsed = .72; g._update_hum_volume()
	check(g.hum.volume_db<=-60,"Each heartbeat has a silent release before the cream handoff")
	g.heartbeat_elapsed = 1.81; g._update_hum_volume()
	check(g.hum.volume_db<=-60,"The start-of-cycle quiet frame also stays silent at the normal 1.8-second handoff")
	g._fail("fixture")
	check(not g.hum.playing,"Loading failure stops the hum while Retry and Close stay available")
	g.status = "preview"; g.heartbeat_elapsed = .14; g._start_hum()
	check(g.hum.playing and g.hum_start_count==2,"A retry can restart the same stopped player")
	g._stop_hum(true)
	check(g.hum_releasing,"An immediate Reduced Motion handoff can release an unfinished note without delaying the game")
	await create_timer(.12).timeout
	await process_frame
	await process_frame
	check(not g.hum.playing and not g.hum_releasing,"The short handoff tail stops instead of persisting into gameplay")
	g.free()

func active_asset_roster():
	var paths = Startup.warmup_paths()
	var unique = {}; var exists = true; var retired = false
	for path in paths:
		unique[path] = true
		exists = exists and ResourceLoader.exists(path)
		retired = retired or "upgrade_u_garden" in path or "upgrade_antler_garden" in path or "upgrade_winding_garden" in path or "/arc_props/" in path
	check(paths.size() == unique.size() and paths.size() > 80,"Warmup deduplicates real shared resources instead of loading role aliases twice")
	check(exists and not retired,"Every warmup target exists and excludes retired art versions")
	check(Startup.MAIN_SCENE in paths and "res://data/art/transitions/cream_wave.png" in paths,"Warmup includes the actual main scene and shared reveal texture")
	check("res://data/art/crystal/food/balls_atlas.png" in paths and "res://data/art/crystal/food/pegs_atlas.png" in paths and "res://data/art/crystal/environment/upgrade_courtyard.png" in paths,"Crystal warmup follows current atlas metadata and the authored courtyard")

func real_progress_and_bounds():
	var g = fixture()
	g.plan = {"a":{"status":ResourceLoader.THREAD_LOAD_IN_PROGRESS,"progress":.5},"b":{"status":ResourceLoader.THREAD_LOAD_IN_PROGRESS,"progress":0},"c":{"status":ResourceLoader.THREAD_LOAD_IN_PROGRESS,"progress":.25},"d":{"status":ResourceLoader.THREAD_LOAD_LOADED}}
	queue_fixture(g,["a","b","c","d"])
	check(g.pending.size() == 3 and g.queued == ["d"] and g.requests.size() == 3,"Loader starts only three concurrent requests")
	g._poll_loading()
	check(is_equal_approx(g.loading_progress,.1875) and g.preparations == 0,"Progress reflects actual reported partial work, never an elapsed-time percentage")
	for path in ["a","b","c"]: g.plan[path].status = ResourceLoader.THREAD_LOAD_LOADED
	g._poll_loading()
	check(g.loaded_resources.size() == 3 and g.pending.size() == 1 and g.pending.has("d") and g.preparations == 0,"Loaded resources are retained and only free worker slots take queued work")
	g._poll_loading()
	check(g.loading_progress == 1 and g.preparations == 1 and g.loaded_resources.size() == 4 and g.status == "ready","Main preparation waits for every real request to complete")
	g._process(.1)
	check(g.preparations == 1 and g.handoff_count == 0,"Completed loading is not prepared twice and does not skip the brief brand hold")
	g.free()

func failures_and_retry():
	var g = fixture()
	g.plan = {"a":{"status":ResourceLoader.THREAD_LOAD_IN_PROGRESS},"b":{"reject":true}}
	queue_fixture(g,["a","b","c","d"])
	check(g.status == "error" and g.failure.visible and g.error_resource == "b" and g.preparations == 0,"Immediate loader failure exposes useful Retry/Close UI before any main instance")
	check(g.stamp.position.y+g.stamp.size.y < g.failure.position.y and g.failure.position.y < root.get_visible_rect().size.y*.6,"Recovery layout separates the smaller stamp from its buttons and leaves a lower-screen margin")
	check(g.pending.has("a") and g.queued == ["c","d"],"Failed request preserves healthy in-flight and queued work")
	g.plan.b.reject = false
	g.retry()
	check(g.status == "loading" and not g.failure.visible and g.requests.a == 1 and g.requests.b == 2,"Retry restarts only the failed resource without duplicating a healthy request token")
	check(g.stamp.position+g.stamp.size*.5 == root.get_visible_rect().size*.5,"Retry restores the normal centered logo layout")
	g.plan.b.status = ResourceLoader.THREAD_LOAD_FAILED
	g._poll_loading()
	check(g.status == "error" and g.takes.b == 1 and not g.pending.has("b"),"Asynchronous failure consumes the Godot token before offering retry")
	g.plan.b.status = ResourceLoader.THREAD_LOAD_LOADED
	g.retry()
	check(g.requests.a == 1 and g.requests.b == 3 and g.status == "loading","Retry after asynchronous failure issues a fresh request and retains healthy progress")
	g.plan.a.status = ResourceLoader.THREAD_LOAD_LOADED
	g._poll_loading(); g._poll_loading()
	check(g.status == "ready" and g.preparations == 1 and g.loading_progress == 1,"Successful retry reaches readiness once without resetting saved progress")
	g.free()

func foreground_and_handoff():
	var g = fixture()
	g.status = "ready"
	g._process(.6); g._process(.6)
	check(g.handoff_count == 0 and g.status == "ready","A fast load retains two short heartbeat cycles before handoff")
	g._process(.61)
	check(g.handoff_count == 0,"A settled logo frame renders before the cream-wave snapshot is taken")
	g._process(0.0)
	check(g.handoff_count == 1 and g.status == "handed_off","Ready startup hands off after the 1.8-second minimum")
	g._process(10); g._handoff()
	check(g.handoff_count == 1,"Completed startup cannot hand off or replay twice")
	g.free()

	g = fixture(); g.reduced_motion = true
	g.plan = {"held":{"status":ResourceLoader.THREAD_LOAD_IN_PROGRESS,"progress":.6}}
	queue_fixture(g,["held"])
	g._process(20)
	check(g.handoff_count == 0 and g.status == "loading","Reduced Motion still waits for real resource readiness")
	g.plan.held.status = ResourceLoader.THREAD_LOAD_LOADED
	g._process(.01)
	check(g.handoff_count == 1 and g.stamp.scale == Vector2.ONE,"Reduced Motion hands off immediately once loading and the initial frames finish")
	g.free()
	g = fixture(); g.status = "waiting"
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	g._begin_loading(); g._process(20)
	check(g.status == "waiting" and g.requests.is_empty() and g.heartbeat_elapsed == 0,"Backgrounding before deferred startup cannot start work or consume heartbeat time")
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await process_frame
	check(g.status == "loading" and g.pending.size() == 3,"Foreground recovery starts a loader that was suspended before its first request")
	g._process(20)
	check(g.heartbeat_elapsed == 0,"The first resumed frame discards background-sized delta")
	g.free()
	g = fixture(); g.status = "ready"; g.heartbeat_elapsed = 1.7
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); g._process(100)
	check(g.handoff_count == 0 and g.heartbeat_elapsed == 1.7,"A ready but backgrounded splash defers handoff and keeps its elapsed time")
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN); g._process(100)
	check(g.handoff_count == 0 and g.heartbeat_elapsed == 1.7,"Foreground notification cannot spend background time on the remaining heartbeat")
	g._process(.11)
	g._process(0.0)
	check(g.handoff_count == 1,"A ready splash continues once after actual foreground time")
	g.free()
	g = fixture(); g.status = "ready"; g.heartbeat_elapsed = 1.94; g.frames_shown = 3
	g._process(0.0)
	check(g.handoff_count == 0 and g.stamp.material.get_shader_parameter("heartbeat") > .99,"Loading that finishes during a bright beat waits for the logo to settle")
	g._process(.52)
	check(g.handoff_count == 0 and g.stamp.scale == Vector2.ONE,"Quiet phase gets its own rendered rest frame before reveal")
	g._process(0.0)
	check(g.handoff_count == 1,"Mid-beat readiness hands off once after the quiet frame")
	g.free()

func error_button_input():
	var g = fixture()
	g.plan = {"broken":{"reject":true}}
	queue_fixture(g,["broken"])
	g.plan.broken.reject = false
	g.set_process_input(true)
	await process_frame
	await process_frame
	var button = g.get_node("Stage/Canvas/Failure/Retry")
	var point = button.get_global_rect().get_center()
	var press = InputEventMouseButton.new()
	press.position = point; press.global_position = point; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	root.push_input(press,true)
	var release = InputEventMouseButton.new()
	release.position = point; release.global_position = point; release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	root.push_input(release,true)
	await process_frame
	check(g.status == "loading" and g.requests.broken == 2 and not g.failure.visible,"Real GUI Retry press passes the startup input gate and restarts the failed request")
	g.free()

func held_main_contract():
	for area in ["bakery","gelato","crystal"]:
		var g = GameFixture.new()
		g.testing = false; g.sound_on = false; g.set_active_area(area)
		g.first_run_guide.active = false; g.first_run_guide.completed = true
		g.profile_initialization_complete = false; g.startup_blocked = true
		for notification in [Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_CLOSE_REQUEST]: g._notification(notification)
		check(g.saves == 0 and g.mode == "home","Pre-restore lifecycle events cannot write default "+area+" progress")
		g.start_shift(); g.handle_press(Vector2(360,1030)); g.go_back()
		check(g.saves == 0 and g.run_serial == 0,"Held "+area+" cannot start a run through direct actions")
		g.profile_initialization_complete = true; g.startup_blocked = false
		g.start_shift(); g.run_transition.finish(); g.page_transition.finish()
		g.startup_blocked = true
		var snapshot = g.RunSnapshot.capture(g).duplicate(true)
		var checkpoint = g.checkpoint_clock
		var remaining = g.remaining
		var guide_age = g.first_run_guide.age
		g.step(1); g._physics_process(1); g._process(1)
		var press = InputEventScreenTouch.new(); press.pressed = true; press.position = Vector2(620,70)
		g._input(press); g.handle_press(Vector2(620,70)); g.start_shift()
		check(g.remaining == remaining and g.checkpoint_clock == checkpoint and g.run_elapsed == 0 and g.first_run_guide.age == guide_age and g.saves == 1 and g.run_serial == 1,"Startup hold freezes "+area+" simulation, input, guide and checkpoint cadence")
		check(g.RunSnapshot.capture(g) == snapshot and not snapshot.has("startup_blocked") and not snapshot.has("profile_initialization_complete"),"Boot-only flags do not enter "+area+" checkpoints or change RNG state")
		g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(g.mode == "paused" and g.saves == 2 and not g.saved.is_empty(),"Post-restore background saves a valid paused "+area+" run")
		g.free()

func _initialize():
	call_deferred("run_checks")

func run_checks():
	heartbeat_and_native_layout()
	await warm_hum_contract()
	active_asset_roster()
	real_progress_and_bounds()
	failures_and_retry()
	await foreground_and_handoff()
	await error_button_input()
	held_main_contract()
	await process_frame
	print("STARTUP_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
