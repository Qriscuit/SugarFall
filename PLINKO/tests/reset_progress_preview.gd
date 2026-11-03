extends SceneTree
## Actual renderer, all state in memory. Never invokes production startup or disk saves.
var failures: Array[String] = []
var captures: Array = []

class PreviewGame extends "res://scripts/main.gd":
	var candidate: Dictionary = {}
	var profile_reads = 0
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
	func load_game(): profile_reads += 1
	func write_profile_file(data: Dictionary) -> bool:
		candidate = data.duplicate(true)
		return true

func _initialize(): call_deferred("capture")

func capture():
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Use graphics rendering and an absolute --output-dir.")
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
		viewport.size=resolution
		g.scale=Vector2.ONE*float(resolution.x)/720.0
		g.reset_profile_runtime()
		g.bank=12345
		g.levels=[3,4,2,1,1,1,2,4]
		g.current_level=8
		g.highest_unlocked=10
		g.mode="support"
		for state in ["settings","confirmation","new-game"]:
			if state=="confirmation": g.request_progress_reset()
			if state=="new-game":
				if not g.reset_progress(): failures.append("Reset failed in memory")
				g.first_run_guide.revealed=10000
				g.first_run_guide.age=1.0
				if g.bank!=0 or g.levels!=[0,0,0,0,0,0,0,0] or g.current_level!=1 or g.first_run_guide.step_id!="welcome": failures.append("Fresh state not visible")
			g.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var name="%s-%dx%d.png" % [state,resolution.x,resolution.y]
			var picture=viewport.get_texture().get_image()
			if picture.save_png(output.path_join(name))!=OK: failures.append("Save failed: "+name)
			captures.append(name)
	if g.profile_reads!=0: failures.append("Preview attempted profile access")
	var summary={"captures":captures,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"note":"Staged real-renderer captures with in-memory save adapter; no player reset performed."}
	var file=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	print("RESET_PROGRESS_PREVIEW captures=",captures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
