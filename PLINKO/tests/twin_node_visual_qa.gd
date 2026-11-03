extends "res://tests/ui_art_preview.gd"
## Real renderer captures every upgrade family and Twin state at phone sizes.
const BasePreview = preload("res://tests/ui_art_preview.gd")
var files: Array[String] = []

class MapPreview extends BasePreview.PreviewGame:
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts += 1
		return false
	func fitted_text(value, rect: Rect2, size = 24, color = WHITE, align_center = false, painter: CanvasItem = null):
		if mode=="shop" and not str(value).is_empty() and rect.position.y>=838 and rect.end.y<=1078:
			var fit = size
			while fit>14 and font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x>rect.size.x: fit-=1
			if font.get_height(fit)>rect.size.y+.01 or font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x>rect.size.x+.01:
				text_overflows.append("Card glyph bounds exceed their row: "+str(value))
		super.fitted_text(value,rect,size,color,align_center,painter)

func prepare(game, area: String):
	game.set_active_area(area)
	stage(game,"shop-fresh")
	game.first_run_guide.active = false
	game.first_run_guide.completed = true
	game.run_transition.finish()
	game.mode = "shop"
	game.run_id = ""
	game.shift_claimed = true
	game.navigation_delay = 0
	game.result_input_delay = 0
	game.current_level = 5
	game.highest_unlocked = 5
	game.bank = 100000000
	game.levels = game.MAX_LEVELS.duplicate()
	game.twin_launchers = false
	game.power_reset_tier = 0
	game.reduced_motion = true
	game.note_time = 0
	game.diagnostics_on = false
	game.upgrade_map.reset_view_state()

func frame(game, nodes: Array[Vector2i]):
	var map = game.upgrade_map
	map.update(0)
	map._frame_nodes(nodes)
	map.update(1)
	map.feedback.clear()
	map.tap_feedback.clear()
	game.text_overflows.clear()

func snap(viewport: SubViewport, game, name: String, directory: String):
	game.capture_name = name
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = viewport.get_texture().get_image()
	check(picture!=null and picture.get_size()==viewport.size,"GPU produced "+name)
	check(game.text_overflows.is_empty(),"Actual font bounds fit on "+name+": "+str(game.text_overflows))
	check(picture.save_png(directory.path_join(name+".png"))==OK,"Saved "+name)
	files.append(name+".png")

func _initialize(): call_deferred("run")

func run():
	var directory = output_directory()
	if not directory.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("An absolute output directory and GPU renderer are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = MapPreview.new()
	viewport.add_child(game)
	for resolution in RESOLUTIONS:
		viewport.size = resolution
		for area in ["bakery","gelato"]:
			for family in range(8):
				prepare(game,area)
				game.levels[family] -= 1
				var map = game.upgrade_map
				map.selected = family; map.tier = game.levels[family]+1
				var nodes: Array[Vector2i] = [Vector2i(map.selected,map.tier)]
				frame(game,nodes)
				await snap(viewport,game,"%s-%s-%d" % [area,map.NAMES[family].to_lower(),resolution.x],directory)
		for state in ["locked","eligible","unaffordable","owned-old-save","pan-zoom"]:
			prepare(game,"gelato")
			var map = game.upgrade_map
			game.levels[1] = 3
			if state=="locked": game.highest_unlocked = 4
			if state=="unaffordable": game.bank = 0
			if state in ["owned-old-save","pan-zoom"]:
				game.twin_launchers = true
				game.levels[1] = 0
				game.power_reset_tier = 0 if state=="owned-old-save" else 3
			map.twin_selected = true
			var nodes: Array[Vector2i] = [map.TWIN_NODE]
			if state!="owned-old-save": nodes.append(map.TWIN_PARENT)
			if state=="pan-zoom": map.zoom = 1.3
			frame(game,nodes)
			if state=="pan-zoom": map.pan += Vector2(65,30)
			await snap(viewport,game,"twin-%s-%d" % [state,resolution.x],directory)
		if resolution.x==450:
			for area in ["bakery","gelato"]:
				for page in ["guide","loadout"]:
					game.set_active_area(area)
					stage(game,page)
					await snap(viewport,game,"%s-%s-%d" % [area,page,resolution.x],directory)
	check(game.persistence_attempts==0,"All GPU states performed zero player profile accesses")
	var manifest = FileAccess.open(directory.path_join("captures.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"captures":files,"count":files.size(),"checks":checks,"failures":failures,"player_profile_accesses":game.persistence_attempts},"\t"))
	manifest.close()
	game.free()
	viewport.free()
	print("TWIN_NODE_VISUAL_QA_RESULT passed=%d failed=%d captures=%d" % [checks-failures.size(),failures.size(),files.size()])
	quit(0 if failures.is_empty() else 1)
