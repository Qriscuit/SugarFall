extends SceneTree
## Frozen real-renderer scenes, isolated in memory; no player profiles are touched.
const STEPS = ["play","aim_drag","earned","time_pickup","collect","upgrades","retry","buy","again"]
var failures: Array[String] = []
var captures: Array = []

class TouchGuide extends "res://scripts/first_run_guide.gd":
	func uses_mouse_controls() -> bool: return false

class MouseGuide extends "res://scripts/first_run_guide.gd":
	func uses_mouse_controls() -> bool: return true

class PreviewGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
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
		persistence_attempts += 1
		return false
	func load_game(): persistence_attempts += 1

func stage(g, step_id: String):
	g.reset_profile_runtime()
	g.navigation_delay = 0
	g.note_time = 0
	g.first_run_guide.begin()
	if step_id in ["aim_drag","earned","time_pickup","collect"]:
		g.start_shift()
		if step_id == "earned": g.shift_coins = 3.0
		if step_id == "time_pickup":
			g.remaining = 6.0
			g.run_elapsed = 4.0
			g.pickups = [{"p":Vector2(480,455),"life":4.0}]
			g.first_run_guide.earned_seen = true
		if step_id == "collect":
			g.mode = "result"
			g.shift_coins = 48.0
	elif step_id in ["buy","again"]:
		g.bank = 48.0
		g.mode = "shop"
		if step_id in ["again"]:
			g.levels[0] = 1
			g.bank = 10.0
		g.upgrade_map.reset_view_state()
		g.upgrade_map.update(0.0)
		g.upgrade_map.selected = 0
		g.upgrade_map.tier = 1
	elif step_id == "upgrades": g.bank = 48.0
	elif step_id == "retry": g.bank = 15.0
	g.first_run_guide._set_step(step_id,false)
	if step_id in ["again"]: g.first_run_guide.upgraded_this_intro = true
	g.first_run_guide.revealed = 10000
	g.first_run_guide.age = 1.0
	g.queue_redraw()

func _initialize(): call_deferred("capture")

func capture():
	var output = ""
	var only_pickup = "--only-time-pickup" in OS.get_cmdline_user_args()
	var only_step = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--only-step="): only_step = arg.trim_prefix("--only-step=")
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
	if g.first_run_guide.host == null: failures.append("Host texture unavailable")
	for controls in ["touch","mouse"]:
		g.first_run_guide = TouchGuide.new(g) if controls == "touch" else MouseGuide.new(g)
		g.first_run_guide.load_assets()
		for resolution in [Vector2i(720,1280),Vector2i(450,800)]:
			viewport.size = resolution
			g.scale = Vector2.ONE*float(resolution.x)/720.0
			for id in STEPS:
				if only_pickup and id != "time_pickup": continue
				if not only_step.is_empty() and id != only_step: continue
				stage(g,id)
				var guide = g.first_run_guide
				var bubble: Rect2 = guide.bubble_rect()
				var layout: Dictionary = guide.bubble_layout()
				var action: Rect2 = guide.action_rect()
				if action.has_area() and bubble.intersects(action): failures.append(id+": bubble covers target")
				if not Rect2(24,24,672,1232).encloses(bubble): failures.append(id+": bubble leaves safe canvas")
				for line in layout.lines:
					if g.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.font_size).x > bubble.size.x-layout.padding*2+.1: failures.append(id+": line exceeds bubble")
				if layout.body_top+layout.lines.size()*layout.line_height > layout.hint_top: failures.append(id+": dialogue overlaps hint")
				if layout.hint_top+g.font.get_height(layout.hint_size) > bubble.size.y-layout.padding: failures.append(id+": hint exceeds bubble")
				await process_frame
				await RenderingServer.frame_post_draw
				var filename = "%s-%s-%dx%d.png" % [controls,id,resolution.x,resolution.y]
				var picture = viewport.get_texture().get_image()
				if picture.save_png(output.path_join(filename)) != OK: failures.append("Could not save "+filename)
				captures.append(filename)
	if g.persistence_attempts != 0: failures.append("Preview attempted persistence")
	var report = {"captures":captures,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"note":"Staged actual Godot rendering. Interaction is verified separately; no phone validation implied."}
	var file = FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("FIRST_RUN_GUIDE_PREVIEW captures=",captures.size()," failed=",failures.size())
	for failure in failures: print("FAIL: ",failure)
	quit(0 if failures.is_empty() else 1)
