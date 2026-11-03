extends SceneTree
## Production rendering at phone sizes plus a whole-scene overview. All player
## profile reads/writes and gameplay stepping are explicitly intercepted.
const Graph = preload("res://scripts/upgrade_graph.gd")
var output = ""
var count = 0
class Preview extends "res://scripts/main.gd":
	var persistence_attempts = 0
	var map_only = false
	var art_only = false
	func _ready():
		testing=true
		sound_on=false
		load_presentation()
		food_art.load_assets()
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw():
		if art_only: upgrade_map.arc_art.draw(self,area_id,Rect2(Vector2.ZERO,get_viewport_rect().size),upgrade_map.center(),upgrade_map.zoom)
		elif map_only: upgrade_map.draw_map(self)
		else: super._draw()
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

func save_capture(viewport: SubViewport, game, name: String) -> bool:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture=viewport.get_texture().get_image()
	if picture.get_size()!=viewport.size or picture.save_png(output.path_join(name+".png"))!=OK:
		push_error("Capture failed: "+name)
		return false
	count+=1
	return true

func capture():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("An absolute output directory and graphics renderer are required")
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
	var m=game.upgrade_map
	for area in ["bakery","gelato"]:
		if not game.set_active_area(area) or not m.arc_art.is_ready(area):
			push_error("Arc art unavailable for "+area)
			quit(1)
			return
		var scene_size: Vector2=m.arc_art.texture_size(area)
		if absf(scene_size.x/scene_size.y-m.arc_art.world_rect.size.x/m.arc_art.world_rect.size.y)>.01:
			push_error("The complete illustration would be stretched: "+area)
			quit(1)
			return
		for phone_size in [Vector2i(450,800),Vector2i(720,1280)]:
			viewport.size=phone_size
			game.scale=Vector2.ONE*float(phone_size.x)/720.0
			game.position=Vector2.ZERO
			game.map_only=false
			for stage in ["first-choices","mid-arc","end-arc","overview"]:
				game.mode="shop"
				game.levels.fill(0)
				game.bank=220
				game.note_time=0
				game.diagnostics_on=false
				m.reset_view_state()
				match stage:
					"first-choices": game.levels[0]=1
					"mid-arc":
						for node in Graph.nodes():
							if Graph.rank(node.x,node.y)>=29: break
							game.levels[node.x]=node.y
						m.zoom=.68
						m.pan=Vector2(360,560)-m.point(1,4)
						m.selected=1
						m.tier=4
					"end-arc":
						game.levels=Graph.CAPS.duplicate()
						m.zoom=.68
						m.pan=Vector2(360,560)-m.point(1,10)
						m.selected=1
						m.tier=10
					"overview":
						game.levels=Graph.CAPS.duplicate()
						m.zoom=m.MIN_ZOOM
						var bounds=Rect2()
						for node in Graph.nodes():
							var marker: Rect2=m.node_rect(node.x,node.y,false)
							bounds=bounds.merge(marker) if bounds.has_area() else marker
						m.pan+=m.FOCUS_AREA.get_center()-bounds.get_center()
				m.update(0)
				if not await save_capture(viewport,game,area+"-"+stage+"-"+str(phone_size.x)):
					quit(1)
					return
		viewport.size=Vector2i(1750,1000)
		game.scale=Vector2.ONE
		game.map_only=true
		game.levels=Graph.CAPS.duplicate()
		m.reset_view_state()
		m.zoom=minf(float(viewport.size.x)/m.arc_art.world_rect.size.x,float(viewport.size.y)/m.arc_art.world_rect.size.y)
		m.pan=Vector2(viewport.size)*.5-m.ORIGIN-m.arc_art.world_rect.get_center()*m.zoom
		m.update(0)
		if not await save_capture(viewport,game,area+"-whole-arc"):
			quit(1)
			return
		game.art_only=true
		if not await save_capture(viewport,game,area+"-art-canvas"):
			quit(1)
			return
		game.art_only=false
		# Review the authored scene at a useful landscape zoom and at the closest
		# supported camera scale. A single world illustration is magnified here;
		# these captures document its actual detail rather than asserting sprite density.
		viewport.size=Vector2i(1280,1280)
		var scenery_center=Vector2(2944.486,-3520)
		m.zoom=.34
		m.pan=Vector2(viewport.size)*.5-m.ORIGIN-scenery_center*m.zoom
		if not await save_capture(viewport,game,area+"-scenery-detail"):
			quit(1)
			return
		m.zoom=m.MAX_ZOOM
		m.pan=Vector2(viewport.size)*.5-m.ORIGIN-scenery_center*m.zoom
		if not await save_capture(viewport,game,area+"-scenery-closeup"):
			quit(1)
			return
	if game.persistence_attempts!=0:
		push_error("Unexpected player-profile access")
		quit(1)
		return
	print("ARC_ART_VISUAL_QA captures=",count," player_profile_accesses=0")
	game.free()
	viewport.queue_free()
	quit()
