extends SceneTree
## Actual HUD rendering with in-memory staged runs and no player-profile access.
var failures: Array[String] = []
var captures: Array[String] = []
const CASES = [
	["normal",5.0,false,false],
	["three-peak",3.0,false,false],
	["three-settling",2.82,false,false],
	["three-settled",2.5,false,false],
	["three-soft",2.05,false,false],
	["two-peak",2.0,false,false],
	["two-settling",1.82,false,false],
	["two-settled",1.5,false,false],
	["two-soft",1.05,false,false],
	["one-peak",1.0,false,false],
	["one-settling",.82,false,false],
	["one-settled",.5,false,false],
	["one-soft",.05,false,false],
	["reduced-motion",2.0,true,false],
	["cleared",2.0,false,true],
	["entrance-hud",2.0,false,false]
]

class PreviewGame extends "res://scripts/main.gd":
	var profile_accesses = 0
	func _ready():
		testing = true
		sound_on = false
		load_presentation()
		food_art.load_assets()
		set_active_area("bakery")
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _notification(_what): pass
	func _input(_event): pass
	func save_game():
		profile_accesses += 1
		return false
	func load_game(): profile_accesses += 1

func _initialize(): call_deferred("capture")

func capture():
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("Supply absolute --output-dir and use the graphics renderer.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var g = PreviewGame.new()
	viewport.add_child(g)
	for resolution in [Vector2i(720,1280),Vector2i(450,800)]:
		viewport.size = resolution
		g.scale = Vector2.ONE*float(resolution.x)/720.0
		for entry in CASES:
			g.start_shift()
			g.first_run_guide.active = false
			g.run_transition.finish()
			g.countdown_feedback.reset()
			g.remaining = entry[1]
			g.run_elapsed = 10.0-entry[1]
			g.reduced_motion = entry[2]
			g.clear_draining = entry[3]
			g.shift_coins = 127
			if entry[0] == "entrance-hud":
				g.run_transition.begin()
				g.run_transition.time = .36
			g.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename = "%s-%dx%d.png" % [entry[0],resolution.x,resolution.y]
			if viewport.get_texture().get_image().save_png(output.path_join(filename)) != OK: failures.append("Could not save "+filename)
			captures.append(filename)
	if g.profile_accesses != 0: failures.append("Preview attempted profile access")
	var report = {"captures":captures,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"note":"Staged Godot rendering at peak, 0.18s, 0.50s and 0.95s after each tick. Entrance HUD uses the actual transition at 0.36s. Not physical-device validation."}
	var file = FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("COUNTDOWN_HUD_PREVIEW captures=",captures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
