extends SceneTree
## Production UI captures with profile access explicitly intercepted.
const Graph = preload("res://scripts/upgrade_graph.gd")
var output = ""
class Preview extends "res://scripts/main.gd":
	var persistence_attempts = 0
	func _ready():
		testing=true
		sound_on=false
		load_presentation()
		food_art.load_assets()
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _input(_event): pass
	func _notification(_what): pass
	func save_game() -> bool:
		persistence_attempts+=1
		return false
	func load_game(): persistence_attempts+=1
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts+=1
		return false

func _initialize(): call_deferred("capture")

func capture():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("An absolute output folder and GPU renderer are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new()
	viewport.size=Vector2i(450,800)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=Preview.new()
	viewport.add_child(game)
	var count=0
	for area in ["bakery","gelato"]:
		game.set_active_area(area)
		for stage in ["first-choices","locked-route","mid-web","late-web","overview","board-4","board-12"]:
			viewport.size=Vector2i(1440,2560) if stage=="overview" else Vector2i(450,800)
			game.mode="shop"
			game.levels.fill(0)
			game.bank=220
			game.note_time=0
			game.diagnostics_on=false
			game.scale=Vector2.ONE*float(viewport.size.x)/720.0
			game.position=Vector2.ZERO
			game.upgrade_map.reset_view_state()
			var m=game.upgrade_map
			match stage:
				"first-choices": game.levels[0]=1
				"locked-route":
					game.levels[0]=1
					m.selected=1
					m.tier=1
					m.zoom=.76
					m.pan=Vector2(360,560)-m.point(1,1)
				"mid-web":
					for node in Graph.nodes():
						if Graph.rank(node.x,node.y)>=21: break
						game.levels[node.x]=node.y
					m.zoom=.68
					m.pan=Vector2(360,600)-m.point(1,3)
					m.selected=1
					m.tier=3
				"late-web":
					for node in Graph.nodes():
						if Graph.rank(node.x,node.y)>=49: break
						game.levels[node.x]=node.y
					m.zoom=.6
					m.pan=Vector2(360,600)-m.point(0,7)
					m.selected=0
					m.tier=7
				"overview":
					game.levels=Graph.CAPS.duplicate()
					var bounds=Rect2(Vector2.ZERO,Vector2.ZERO)
					for node in Graph.nodes(): bounds=bounds.expand(m._positions[node])
					bounds=bounds.grow(90)
					m.zoom=minf(630.0/bounds.size.x,880.0/bounds.size.y)
					m.pan=Vector2(360,590)-m.ORIGIN-bounds.get_center()*m.zoom
				_:
					game.mode="play"
					game.current_level=4 if stage=="board-4" else 12
					game.start_shift()
					game.run_transition.finish()
			m.update(0)
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var picture=viewport.get_texture().get_image()
			var path=output.path_join(area+"-"+stage+".png")
			if picture.save_png(path)!=OK:
				quit(1)
				return
			count+=1
	if game.persistence_attempts!=0:
		push_error("Unexpected persistence call")
		quit(1)
		return
	print("SPIRAL_VISUAL_QA captures=",count," player_profile_accesses=0")
	game.free()
	viewport.queue_free()
	quit()
