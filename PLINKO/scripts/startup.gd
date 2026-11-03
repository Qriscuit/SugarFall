extends Node
## A small loading stage. All progression continues to belong to main.gd.
const MAIN_SCENE = "res://main.tscn"
const SAVE_PATH = "user://sugarfall_save.json"
const MINIMUM_SECONDS = 1.8
const BEAT_SECONDS = .9
const HUM_VOLUME_DB = -7.0
const MAX_PENDING = 3
const FoodArt = preload("res://scripts/food_art.gd")
const EnvironmentArt = preload("res://scripts/environment_art.gd")
const UIArt = preload("res://scripts/ui_art.gd")
const ResultArt = preload("res://scripts/result_comparison_ui.gd")
var status = "waiting"
## QA fixtures opt out before entering the tree; normal startup never sets this.
var testing = false
var reduced_motion = false
var sound_on = true
var audio_preference_read = false
var hum_start_count = 0
var hum_releasing = false
var heartbeat_elapsed = 0.0
var frames_shown = 0
var suspended = false
var skip_resume_delta = false
var loading_progress = 0.0
var error_resource = ""
var queued: Array[String] = []
var pending: Dictionary = {}
var loaded_resources: Dictionary = {}
var total_resources = 0
var game
var handoff_count = 0
var quiet_ready_frame = false
@onready var canvas: Control = $Stage/Canvas
@onready var stamp: TextureRect = $Stage/Canvas/Stamp
@onready var background: ColorRect = $Stage/Canvas/Background
@onready var hum: AudioStreamPlayer = $WarmHum
@onready var failure: VBoxContainer = $Stage/Canvas/Failure

func _ready():
	Engine.max_fps = 60
	canvas.resized.connect(_layout)
	$Stage/Canvas/Failure/Retry.pressed.connect(retry)
	$Stage/Canvas/Failure/Quit.pressed.connect(_quit)
	_layout()
	if testing:
		status = "preview"
		_render_heartbeat()
		return
	if "--self-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		# Existing command-line regression never discovers a real player profile.
		$Stage.hide()
		var scene = load(MAIN_SCENE) as PackedScene
		if scene != null: add_child(scene.instantiate())
		else: get_tree().quit(2)
		set_process(false)
		return
	var preferences = _read_startup_preferences()
	reduced_motion = preferences.reduced_motion
	sound_on = preferences.sound_on
	audio_preference_read = true
	_render_heartbeat()
	_start_hum()
	call_deferred("_begin_loading")

func _layout():
	var viewport = get_viewport().get_visible_rect().size
	var fit = minf(viewport.x/720.0,viewport.y/1280.0)
	var height = minf((330.0 if status == "error" else 600.0)*fit,viewport.x*.55*855.0/301.0)
	stamp.size = Vector2(height*301.0/855.0,height)
	var center = Vector2(viewport.x*.5,viewport.y*.28) if status == "error" else viewport*.5
	stamp.position = center-stamp.size*.5
	stamp.pivot_offset = Vector2(stamp.size.x*.5,stamp.size.y)
	if background.material is ShaderMaterial:
		background.material.set_shader_parameter("viewport_aspect",viewport.x/maxf(1.0,viewport.y))
	failure.size = Vector2(minf(560.0*fit,viewport.x*.86),250.0*fit)
	failure.position = Vector2((viewport.x-failure.size.x)*.5,viewport.y*.52)
	failure.add_theme_constant_override("separation",maxi(12,roundi(16*fit)))
	$Stage/Canvas/Failure/Message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Stage/Canvas/Failure/Message.add_theme_font_size_override("font_size",maxi(16,roundi(25*fit)))
	for button in [$Stage/Canvas/Failure/Retry,$Stage/Canvas/Failure/Quit]:
		button.custom_minimum_size.y = maxf(48,64*fit)
		button.add_theme_font_size_override("font_size",maxi(16,roundi(23*fit)))

func _read_reduced_motion() -> bool:
	return _read_startup_preferences().reduced_motion

func _read_startup_preferences() -> Dictionary:
	var path = SAVE_PATH
	if not FileAccess.file_exists(path):
		# Match the existing loader's discovery order without migrating or writing.
		var candidates = ["user://sugarfall_areas_v3.json","user://peg_foundry_v1.json"]
		var selector = FileAccess.open("user://peg_foundry_profile.json",FileAccess.READ)
		if selector != null and selector.get_length() <= 128:
			var choice = JSON.parse_string(selector.get_as_text())
			if choice is Dictionary and choice.get("version") == 1 and choice.get("fresh") == true:
				candidates = ["user://sugarfall_fresh_test_areas_v3.json","user://peg_foundry_fresh_test_v1.json"]+candidates
		for candidate in candidates:
			if FileAccess.file_exists(candidate): path = candidate; break
	if not FileAccess.file_exists(path): return {"reduced_motion":false,"sound_on":true}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1048576: return {"reduced_motion":false,"sound_on":false}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {"reduced_motion":false,"sound_on":false}
	return {"reduced_motion":parser.data.get("reduced_motion",false)==true,"sound_on":parser.data.get("sound",true)==true}

static func heartbeat_at(seconds: float) -> float:
	var phase = fposmod(maxf(0.0,seconds),BEAT_SECONDS)
	if phase < .04 or phase > .65: return 0.0
	# Strong quick beat, smaller second thump, then a long quiet interval.
	return clampf(exp(-pow((phase-.14)/.055,2.0))+.55*exp(-pow((phase-.30)/.075,2.0)),0.0,1.0)

func _render_heartbeat():
	var beat = 0.0 if reduced_motion or status == "error" else heartbeat_at(heartbeat_elapsed)
	stamp.scale = Vector2.ONE*(1.0+.055*beat)
	if stamp.material is ShaderMaterial: stamp.material.set_shader_parameter("heartbeat",beat)
	if background.material is ShaderMaterial: background.material.set_shader_parameter("heartbeat",beat)

func _start_hum():
	if not audio_preference_read or not sound_on or suspended or status in ["error","handed_off"] or hum == null: return
	if hum.playing: return
	if hum.stream is AudioStreamWAV:
		# Loop a private stream instance; no imported/shared resource is mutated.
		hum.stream = hum.stream.duplicate()
		hum.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum.stream.loop_begin = 0
		hum.stream.loop_end = roundi(hum.stream.get_length()*hum.stream.mix_rate)
	if not hum.playing:
		_update_hum_volume()
		hum.stream_paused = false
		hum.play(fposmod(heartbeat_elapsed,maxf(.001,hum.stream.get_length())))
		hum_start_count += 1

func _update_hum_volume():
	if hum == null: return
	var phase = fposmod(heartbeat_elapsed,BEAT_SECONDS)
	# Every cycle ends in silence, so the settled-frame reveal has no cut thump.
	var gain = smoothstep(.04,.10,phase)*(1.0-smoothstep(.57,.65,phase))
	hum.volume_db = HUM_VOLUME_DB+linear_to_db(maxf(.001,gain))

func _pause_hum():
	if hum != null and hum.playing: hum.stream_paused = true

func _resume_hum():
	if hum == null or not audio_preference_read or not sound_on or status in ["error","handed_off"]: return
	if hum.playing or hum.stream_paused:
		hum.seek(fposmod(heartbeat_elapsed,maxf(.001,hum.stream.get_length())))
		hum.stream_paused = false
	else:
		_start_hum()

func _stop_hum(fade: bool = false):
	if hum == null: return
	if fade and hum.playing and not hum.stream_paused and hum.volume_db > -60.0:
		# Reduced Motion may be ready mid-note: an 80ms release never delays Home.
		hum_releasing = true
		var release = hum.create_tween()
		release.tween_property(hum,"volume_db",-64.0,.08)
		release.tween_callback(_finish_hum_release)
	else:
		hum.stop()

func _finish_hum_release():
	hum.stop()
	hum_releasing = false
	if status == "handed_off": queue_free()

static func warmup_paths() -> Array[String]:
	var unique: Dictionary = {MAIN_SCENE:true,"res://data/art/transitions/cream_wave.png":true,"res://data/art/host/mabel_welcome.png":true}
	for area in ["bakery","gelato"]:
		for name in FoodArt.NAMES: unique[FoodArt.AREA_ROOTS[area]+name+".png"] = true
		for name in EnvironmentArt.NAMES: unique[EnvironmentArt.AREA_ROOTS[area]+name+".png"] = true
	for name in UIArt.NAMES: unique[UIArt.ROOT+name+".png"] = true
	for name in UIArt.GELATO_OVERRIDES: unique[UIArt.GELATO_ROOT+name+".png"] = true
	for area in ["bakery","gelato","crystal"]: unique[UIArt.MENU_ROOT+area+"_frame.png"] = true
	unique["res://data/art/bakery_ability/jam_donut.png"] = true
	for path in [FoodArt.CRYSTAL_ROOT+"regions.json",EnvironmentArt.CRYSTAL_ROOT+"regions.json"]:
		var regions = JSON.parse_string(FileAccess.get_file_as_string(path))
		if regions is Dictionary:
			for value in regions.values():
				if value is Dictionary and str(value.get("texture","")).begins_with("res://data/art/crystal/"):
					unique[value.texture] = true
	var arc = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_arc_art.json"))
	if arc is Dictionary:
		for area in arc.get("areas",{}).values():
			if area is Dictionary and str(area.get("texture","")).begins_with("res://data/art/"): unique[area.texture] = true
	for path in ResultArt.ART_PATHS.values(): unique[path] = true
	for kind in ["normal","prism","clock","armored"]:
		for suffix in ["","_flash"]: unique["res://data/art/"+kind+suffix+".svg"] = true
	var result: Array[String] = []
	for path in unique: result.append(str(path))
	return result

func _begin_loading():
	if status == "handed_off" or suspended: return
	status = "loading"; error_resource = ""; loading_progress = 0.0
	queued = warmup_paths(); total_resources = queued.size()
	pending.clear(); loaded_resources.clear()
	failure.hide()
	_layout()
	_fill_requests()

func _request_resource(path: String) -> Error:
	return ResourceLoader.load_threaded_request(path,"",true,ResourceLoader.CACHE_MODE_REUSE)

func _resource_status(path: String, progress: Array) -> int:
	return ResourceLoader.load_threaded_get_status(path,progress)

func _take_resource(path: String) -> Resource:
	return ResourceLoader.load_threaded_get(path)

func _fill_requests():
	while status == "loading" and pending.size() < MAX_PENDING and not queued.is_empty():
		var path = queued.pop_front()
		if _request_resource(path) != OK:
			_fail(path)
			return
		pending[path] = 0.0

func _poll_loading():
	for path in pending.keys():
		var progress: Array = []
		var state = _resource_status(path,progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			var resource = _take_resource(path)
			if resource == null: _fail(path); return
			loaded_resources[path] = resource
			pending.erase(path)
		elif state in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			# Godot retains a failed request token until get() consumes it. Retry
			# must release that token, while keeping other healthy requests alive.
			if state == ResourceLoader.THREAD_LOAD_FAILED: _take_resource(path)
			_fail(path); return
		elif not progress.is_empty(): pending[path] = clampf(float(progress[0]),0.0,1.0)
	var completed = float(loaded_resources.size())
	for fraction in pending.values(): completed += float(fraction)
	loading_progress = completed/maxi(1,total_resources)
	_fill_requests()
	if status == "loading" and queued.is_empty() and pending.is_empty():
		loading_progress = 1.0
		_prepare_game()

func _prepare_game():
	if suspended or game != null: return
	var packed = loaded_resources.get(MAIN_SCENE) as PackedScene
	if packed == null: _fail(MAIN_SCENE); return
	game = packed.instantiate()
	if game == null or not game.has_method("start_shift"):
		if game != null: game.free(); game = null
		_fail(MAIN_SCENE)
		return
	# These flags are transient, never captured in a profile or run snapshot.
	game.startup_blocked = true
	game.profile_initialization_complete = false
	add_child(game)
	if not game.profile_initialization_complete: _fail(MAIN_SCENE); return
	reduced_motion = game.reduced_motion
	sound_on = game.sound_on
	if not sound_on: _stop_hum()
	status = "ready"

func _process(delta):
	if suspended or status == "handed_off": return
	if skip_resume_delta:
		delta = 0.0
		skip_resume_delta = false
	frames_shown += 1
	if is_finite(delta) and delta > 0: heartbeat_elapsed += delta
	if status == "loading": _poll_loading()
	_render_heartbeat()
	_update_hum_volume()
	if status == "ready" and frames_shown >= 2 and (reduced_motion or heartbeat_elapsed >= MINIMUM_SECONDS):
		# Let a settled logo frame actually render before the page controller
		# captures it. Finishing a load mid-beat must not chop off that beat.
		if reduced_motion or (heartbeat_at(heartbeat_elapsed) == 0 and quiet_ready_frame):
			_handoff()
		else:
			quiet_ready_frame = heartbeat_at(heartbeat_elapsed) == 0
	else:
		quiet_ready_frame = false

func _handoff():
	if status != "ready" or suspended or game == null: return
	status = "handed_off"; handoff_count += 1
	_stop_hum(true)
	# Capture the actual last studio frame, then let the existing page overlay
	# reveal Home, a pending result or a restored paused run without changing it.
	game.page_transition.begin("studio",game.mode)
	$Stage.hide()
	game.startup_blocked = false
	game.reparent(get_tree().root)
	get_tree().current_scene = game
	if not hum_releasing: queue_free()

func _fail(path: String):
	status = "error"; error_resource = path
	_stop_hum()
	pending.erase(path)
	failure.show()
	_layout()
	_render_heartbeat()

func retry():
	if status != "error" or suspended: return
	if game != null: game.queue_free(); game = null
	heartbeat_elapsed = 0.0
	quiet_ready_frame = false
	var retry_path = error_resource
	status = "loading"; error_resource = ""
	pending.erase(retry_path)
	if not retry_path.is_empty(): queued.push_front(retry_path)
	failure.hide()
	_layout()
	_start_hum()
	_fill_requests()

func _quit():
	_stop_hum()
	get_tree().quit()

func _input(_event):
	# Error buttons receive GUI input; the held game still rejects all actions.
	if status not in ["handed_off","error"]: get_viewport().set_input_as_handled()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		suspended = true
		if is_node_ready(): _pause_hum()
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		suspended = false
		skip_resume_delta = true
		if is_node_ready(): _resume_hum()
		if is_node_ready() and status == "waiting" and total_resources == 0: call_deferred("_begin_loading")
