extends SceneTree
## Frozen visual fixture, not a gameplay or balance simulation.
## Uses main.gd's real renderer and the imported food textures at 720x1280.
## It deliberately stages every food type together for art review, including
## specials that would not all be equipped in the same normal two-slot run.
## Never loads player profiles, never saves progress, and never advances physics.
## Run with a graphics renderer (NOT --headless), after an editor import:
## Godot --path <project> --script res://tests/food_art_preview.gd -- --output=<absolute.png>
## Add --feedback to also capture a peg hit and cream/gold cup catches at
## 0, 80, 160, and 320 ms. Only presentation time advances between those frames.

const FOOD_KINDS = ["normal", "splitter", "impact", "ricochet", "shard"]
var failures: Array[String] = []
var checks = 0

class PreviewGame extends "res://scripts/main.gd":
	func _ready():
		# Do not call super: production _ready loads profiles and starts self-tests.
		testing = true
		sound_on = false
		load_presentation()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json"))
		board_data = parsed if parsed is Array else parsed.get("boards",[])
		food_art.load_assets()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _process(_delta):
		# Keep the composition visible even if a native focus notification is
		# also dispatched to the inherited main.gd notification handler.
		mode = "play"
		queue_redraw()

	func _physics_process(_delta):
		pass

	func _notification(_what):
		# Focus changes must not replace the fixture with the pause overlay.
		pass

	func _input(_event):
		pass

func _initialize():
	call_deferred("capture_preview")

func check(condition: bool, label: String):
	checks += 1
	if condition:
		print("PASS: ",label)
	else:
		failures.append(label)
		push_error("FAIL: "+label)

func output_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return ""

func capture_feedback_frames(game, viewport: SubViewport, output: String):
	game.impact_feedback.reset()
	for peg in game.pegs:
		if peg.hp > 0:
			game.impact_feedback.hit_peg(peg.p)
			break
	game.impact_feedback.catch_food(1) # Cream cup.
	game.impact_feedback.catch_food(2) # Gold cup in this fixture.
	var frame_times = [0.0, 0.08, 0.16, 0.32]
	var frame_names = ["impact", "rebound", "settling", "settled"]
	var previous_time = 0.0
	for index in range(frame_times.size()):
		var frame_time: float = frame_times[index]
		game.impact_feedback.advance(frame_time-previous_time)
		previous_time = frame_time
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var capture = viewport.get_texture().get_image()
		var frame_path = output.get_basename()+"-"+frame_names[index]+".png"
		var save_error = capture.save_png(frame_path) if capture != null else ERR_CANT_CREATE
		check(save_error==OK,"Feedback frame saved at %d ms: %s" % [roundi(frame_time*1000),frame_names[index]])
		print("FOOD_FEEDBACK_PREVIEW_OUTPUT=",frame_path)

func has_enclosed_donut_hole(texture: Texture2D) -> bool:
	var image = texture.get_image()
	if image == null: return false
	if image.is_compressed() and image.decompress() != OK: return false
	var width = image.get_width()
	var height = image.get_height()
	var used = image.get_used_rect()
	if not used.has_area(): return false
	# Flood transparent pixels from the image edge. Transparency left inside
	# the donut is a real cutout, unlike a painted pale center or outside padding.
	var transparent = PackedByteArray()
	transparent.resize(width*height)
	var visited = PackedByteArray()
	visited.resize(width*height)
	var queue = PackedInt32Array()
	for y in range(height):
		for x in range(width):
			var index = y*width+x
			if image.get_pixel(x,y).a < .08:
				transparent[index] = 1
				if x==0 or y==0 or x==width-1 or y==height-1:
					visited[index] = 1
					queue.append(index)
	var cursor = 0
	while cursor < queue.size():
		var index = queue[cursor]
		cursor += 1
		var x = index%width
		var y = int(index/width)
		for neighbor in [index-1 if x>0 else -1,index+1 if x<width-1 else -1,index-width if y>0 else -1,index+width if y<height-1 else -1]:
			if neighbor>=0 and transparent[neighbor] and not visited[neighbor]:
				visited[neighbor] = 1
				queue.append(neighbor)
	var hole_pixels = 0
	var center_region = Rect2i(used.position+Vector2i(used.size*.2),Vector2i(used.size*.6))
	for y in range(center_region.position.y,center_region.end.y):
		for x in range(center_region.position.x,center_region.end.x):
			var index = y*width+x
			if transparent[index] and not visited[index]: hole_pixels += 1
	print("DONUT_ENCLOSED_HOLE_PIXELS=",hole_pixels)
	return hole_pixels >= maxi(4,int(used.size.x*used.size.y*.002))

func capture_preview():
	var output = output_argument()
	if output.is_empty() or not output.is_absolute_path() or output.get_extension().to_lower()!="png":
		push_error("Supply --output=<absolute path ending in .png>. No profile data is written.")
		quit(2)
		return
	if DisplayServer.get_name()=="headless":
		push_error("food_art_preview needs a graphics renderer; omit --headless.")
		quit(2)
		return
	var directory_error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if directory_error != OK:
		push_error("Cannot create preview output directory: "+error_string(directory_error))
		quit(2)
		return

	var viewport = SubViewport.new()
	viewport.size = Vector2i(720,1280)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = PreviewGame.new()
	game.testing = true
	viewport.add_child(game)
	check(game.testing,"Fixture uses isolated testing mode")
	check(game.food_art.textures.size()==game.food_art.NAMES.size(),"All individual food textures and cookie damage stages loaded")
	for name in game.food_art.NAMES:
		check(game.food_art.has_art(name),"Texture is present: "+name)
	for kind in FOOD_KINDS:
		check(game.food_art.has_art(game.food_art.ball_name(kind)),"Food type has its texture: "+kind)
	check(game.food_art.has_art("donut") and has_enclosed_donut_hole(game.food_art.textures["donut"]),"Donut has an enclosed transparent hole")

	game.current_level = 10
	game.highest_unlocked = 12
	game.levels = [2,3,2,3,3,3,2,3]
	game.equipped = ["splitter","impact"]
	game.total_shifts = 2 # Gold cup in the middle for this fixed composition.
	game.start_shift()
	game.rng.seed = 20261023
	game.remaining = 8.4
	game.aim_x = 360.0
	game.aim_y = 515.0
	game.elapsed = 1.25
	game.shift_coins = 127.35
	game.wave_flash = 0.0
	for i in range(game.pegs.size()):
		if i%5==2: game.pegs[i].hp = game.pegs[i].max*.5
		elif i%7==3: game.pegs[i].hp = game.pegs[i].max/6.0
	var staged_balls = [
		["normal",Vector2(360,298),Vector2(5,110)],
		["normal",Vector2(280,381),Vector2(-30,145)],
		["splitter",Vector2(370,520),Vector2(50,130)],
		["impact",Vector2(410,453),Vector2(-25,190)],
		["ricochet",Vector2(610,625),Vector2(-160,80)],
		["normal",Vector2(125,670),Vector2(85,100)],
		["normal",Vector2(465,770),Vector2(10,175)],
		["shard",Vector2(291,654),Vector2(-100,70)],
		["shard",Vector2(318,674),Vector2(25,100)],
		["shard",Vector2(344,648),Vector2(110,60)]
	]
	for staged in staged_balls:
		game.spawn_ball(staged[1],staged[0],staged[2])
		game.balls[-1].life = .35+game.balls.size()*.13
	for i in range(5): game.buckets[i].hits = [2,6,9,3,5][i]
	game.pickups = [{"p":Vector2(190,737),"life":3.1}]
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var capture = viewport.get_texture().get_image()
	check(capture != null and capture.get_size()==Vector2i(720,1280),"Actual gameplay renderer captured at 720x1280")
	check(capture != null and capture.get_pixel(360,400)!=capture.get_pixel(0,0),"Rendered tray and countertop are visibly distinct")
	var save_error = capture.save_png(output) if capture != null else ERR_CANT_CREATE
	check(save_error==OK,"Preview PNG saved to requested output")
	print("FOOD_ART_PREVIEW_OUTPUT=",output)
	if "--feedback" in OS.get_cmdline_user_args():
		await capture_feedback_frames(game,viewport,output)
	print("FOOD_ART_PREVIEW_RESULT passed=",checks-failures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
