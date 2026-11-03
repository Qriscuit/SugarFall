extends "res://tests/ui_art_preview.gd"
## Actual antler-map rendering. Every profile path is intercepted.
const BasePreview = preload("res://tests/ui_art_preview.gd")
var files: Array[String] = []
var observations: Array[Dictionary] = []

class AntlerPreview extends BasePreview.PreviewGame:
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts += 1
		return false
	func fitted_text(value, rect: Rect2, size = 24, color = WHITE, align_center = false):
		if mode=="shop" and not str(value).is_empty() and rect.position.y>=838 and rect.end.y<=1078:
			var fit = size
			while fit>14 and font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x>rect.size.x: fit-=1
			if font.get_height(fit)>rect.size.y+.01 or font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x>rect.size.x+.01:
				text_overflows.append("Card row cannot contain glyphs: "+str(value))
		super.fitted_text(value,rect,size,color,align_center)

func _initialize(): call_deferred("run")

func stage_legacy_counts(game):
	game.gelato_shop_revision=0 if game.area_id=="gelato" else 1
	game.gelato_owned_nodes=[]; game.gelato_reset_power_nodes=[]
	check(game.ensure_gelato_shop_state(),"Visual fixture migrates its deliberate legacy-count state")

func prepare(game, area: String = "gelato"):
	game.set_active_area(area)
	game.capture_name = ""
	game.scale = Vector2.ONE*game.get_viewport_rect().size.x/720.0
	game.position = Vector2.ZERO
	game.mode = "shop"; game.testing = true; game.sound_on = false
	game.first_run_guide.active = false; game.first_run_guide.completed = true
	game.run_transition.finish()
	game.run_id = ""; game.shift_claimed = true
	game.navigation_delay = 0; game.result_input_delay = 0
	game.note = ""; game.note_time = 0; game.diagnostics_on = false
	game.reduced_motion = true; game.trial_active = false
	game.current_level = 8; game.highest_unlocked = 8
	game.bank = 1000000; game.levels = game.MAX_LEVELS.duplicate()
	game.twin_launchers = false; game.power_reset_tier = 0
	game.developer_free_purchases.clear()
	stage_legacy_counts(game)
	game.upgrade_map.reset_view_state()
	game.upgrade_map.update(0)
	game.text_overflows.clear()

func focus(game, nodes: Array[Vector2i], selection: Vector2i = Vector2i(-1,1), at_zoom: float = .84):
	var map = game.upgrade_map
	map.twin_selected = selection==map.TWIN_NODE
	map.selected = -1 if map.twin_selected else selection.x
	map.tier = selection.y
	map.zoom = at_zoom
	map._sync_states()
	map._frame_nodes(nodes)
	map.update(map.CAMERA_DURATION)
	map.feedback.clear(); map.tap_feedback.clear()

func own_ancestors(game, node: Vector2i):
	stage_legacy_counts(game)
	var path: Array[Vector2i]=[]
	var current=node
	while true:
		path.push_front(current)
		var parents=game.upgrade_graph().prerequisites(current.x,current.y)
		if parents.is_empty(): break
		current=parents[0]
	for step in path:
		check(game.buy_upgrade_node(step.x,step.y),"Actual purchases prepare the visual discovery path: "+str(step))
	game.note=""; game.note_time=0

func child_nodes(game, node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for candidate in game.upgrade_graph().nodes():
		if node in game.upgrade_graph().prerequisites(candidate.x,candidate.y): result.append(candidate)
	return result

func snap(viewport, game, output: String, name: String, resolution: Vector2i):
	game.capture_name=name; game.text_overflows.clear()
	var profile = game.AreaCampaign.capture_local(game)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture=viewport.get_texture().get_image()
	var filename="%s-%dx%d.png" % [name,resolution.x,resolution.y]
	check(picture!=null and picture.get_size()==resolution,"GPU rendered "+filename)
	check(game.text_overflows.is_empty(),"Labels fit at phone scale: "+filename+" "+str(game.text_overflows))
	check(picture.save_png(output.path_join(filename))==OK,"Saved "+filename)
	check(game.AreaCampaign.capture_local(game)==profile,"Rendering preserves campaign data: "+filename)
	files.append(filename)
	observations.append({"file":filename,"visible":game.upgrade_map.visible_nodes().size(),"dual":game.upgrade_map.state_for(8,1),"power1":game.upgrade_map.state_for(1,1),"zoom":game.upgrade_map.zoom})

func opening_frame(game, include_heads: bool):
	var map=game.upgrade_map
	game.levels.fill(0); game.current_level=1; game.highest_unlocked=1
	if include_heads: game.levels[0]=1
	stage_legacy_counts(game)
	map.reset_view_state(); map.update(0)
	var root_rect=map.node_rect(0,1,false)
	var dual_rect=map.node_rect(8,1,false)
	check(map.state_for(8,1)=="locked" and map.node_visible(8,1),"Dual Shot is visible and locked from the fresh start")
	check(Rect2(24,145,672,770).encloses(root_rect) and Rect2(24,145,672,770).encloses(dual_rect),"Opening camera contains central starter and lower Dual Shot")
	check(absf(root_rect.get_center().x-360)<1 and root_rect.get_center().y<dual_rect.get_center().y,"Central starter is centered above Dual Shot")
	if include_heads:
		for route in game.upgrade_graph().routes():
			var node: Vector2i=route[0]
			check(map.node_visible(node.x,node.y) and Rect2(24,145,672,770).encloses(map.node_rect(node.x,node.y,false)),"First route choice fits the initial composition")

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Supply absolute output directory and a graphics renderer."); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new()
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=AntlerPreview.new(); viewport.add_child(game)
	for resolution in RESOLUTIONS:
		viewport.size=resolution
		prepare(game); opening_frame(game,false)
		await snap(viewport,game,output,"central-start",resolution)
		prepare(game); opening_frame(game,true)
		await snap(viewport,game,output,"first-fork",resolution)
		prepare(game); game.levels.fill(0); own_ancestors(game,Vector2i(2,1))
		var same_family_choices: Array[Vector2i]=[Vector2i(2,1),Vector2i(1,2),Vector2i(1,7)]
		focus(game,same_family_choices,Vector2i(1,7))
		check(game.upgrade_map.state_for(1,2)=="affordable" and game.upgrade_map.state_for(1,7)=="affordable","Same-family fork presents two independent purchase choices")
		await snap(viewport,game,output,"same-family-choice",resolution)
		var prior_power=game.levels[1]
		check(game.buy_upgrade_node(1,7) and game.levels[1]==prior_power+1,"High-ordinal choice grants exactly one aggregate Power effect")
		game.upgrade_map.update(0); focus(game,same_family_choices,Vector2i(1,7))
		check(game.upgrade_map.state_for(1,7)=="owned" and game.upgrade_map.state_for(1,2)=="affordable","Buying one same-family choice leaves its sibling available")
		await snap(viewport,game,output,"same-family-bought",resolution)
		for scenario in ["tray7-power6","tray8-power5","dual-ready","dual-no-money","dual-infinite"]:
			prepare(game); game.levels[1]=6
			if scenario=="tray7-power6": game.highest_unlocked=7
			if scenario=="tray8-power5": game.levels[1]=5
			if scenario in ["dual-no-money","dual-infinite"]: game.bank=0
			if scenario=="dual-infinite": game.developer_free_purchases["gelato"]=true
			stage_legacy_counts(game)
			var map=game.upgrade_map
			var nodes: Array[Vector2i]=[Vector2i(0,1),map.TWIN_NODE]
			focus(game,nodes,map.TWIN_NODE)
			var expected="locked" if scenario in ["tray7-power6","tray8-power5"] else ("unaffordable" if scenario=="dual-no-money" else "affordable")
			check(map.state_for(8,1)==expected,"Dual Shot respects progression, price and developer money: "+scenario)
			await snap(viewport,game,output,scenario,resolution)
		prepare(game); game.levels[1]=6
		stage_legacy_counts(game)
		var prior_levels=game.levels.duplicate(); var prior_bank=game.bank
		check(game.buy_twin_launchers() and game.levels[1]==0 and game.power_reset_tier==6,"Actual Dual Shot purchase resets Power and retains its rebuilding tier")
		var others_preserved=true
		for family in range(game.levels.size()):
			if family!=1: others_preserved=others_preserved and game.levels[family]==prior_levels[family]
		check(others_preserved and game.bank==prior_bank-3000,"Dual Shot costs exactly 3,000 and preserves every other upgrade")
		game.upgrade_map.update(0)
		var rebuild: Array[Vector2i]=[Vector2i(1,1)]
		focus(game,rebuild,Vector2i(1,1))
		check(game.upgrade_map.state_for(1,1)=="affordable","Affordable reset Power uses green purchase state")
		await snap(viewport,game,output,"dual-purchased-rebuild",resolution)
		prepare(game); game.twin_launchers=true; game.power_reset_tier=3; game.levels[1]=0
		game.highest_unlocked=5
		stage_legacy_counts(game)
		focus(game,[game.upgrade_map.TWIN_NODE],game.upgrade_map.TWIN_NODE)
		check(game.upgrade_map.state_for(8,1)=="owned","Legacy Dual Shot ownership remains visible below newer gates")
		await snap(viewport,game,output,"legacy-dual-owned",resolution)
		prepare(game); game.twin_launchers=true; game.power_reset_tier=6
		stage_legacy_counts(game)
		focus(game,game.upgrade_map.visible_nodes(),Vector2i(-1,1),game.upgrade_map.minimum_zoom())
		check(game.upgrade_map.visible_nodes().size()==63,"Full antler overview preserves all 62 tiers plus Dual Shot")
		await snap(viewport,game,output,"full-antlers",resolution)
		for compact_node in [Vector2i(1,1),Vector2i(2,1)]:
			prepare(game)
			var map=game.upgrade_map
			var critical_zoom=38.0/float(map._spacing[compact_node])
			var compact_frame: Array[Vector2i]=[Vector2i(0,1),game.upgrade_graph().routes()[0][0],game.upgrade_graph().routes()[1][0],Vector2i(2,1)]
			focus(game,compact_frame,Vector2i(-1,1),critical_zoom)
			await snap(viewport,game,output,"compact-clearance-%d"%compact_node.x,resolution)
		var fork_index=0
		for node in game.upgrade_graph().nodes():
			if node==Vector2i(0,1): continue
			var children=child_nodes(game,node)
			if children.size()<2: continue
			prepare(game); game.levels.fill(0); own_ancestors(game,node)
			game.upgrade_map.update(0)
			var frame_nodes: Array[Vector2i]=[node]
			frame_nodes.append_array(children)
			for child in children:
				check(game.upgrade_map.state_for(child.x,child.y)=="affordable","Both choices at fork%d receive equal green treatment"%fork_index)
				for descendant in child_nodes(game,child):
					check(not game.upgrade_map.node_visible(descendant.x,descendant.y),"A fork hides its next continuation until bought")
			focus(game,frame_nodes)
			await snap(viewport,game,output,"antler-fork-%d"%fork_index,resolution)
			fork_index+=1
		prepare(game,"bakery"); game.levels.fill(0); game.levels[0]=1
		game.upgrade_map.reset_view_state(); game.upgrade_map.update(0)
		check(not game.upgrade_map.node_visible(8,1),"Bakery receives no Dual Shot tile")
		await snap(viewport,game,output,"bakery-unchanged",resolution)
	check(game.persistence_attempts==0,"All renderer fixtures performed zero player-profile IO")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"profile_io":game.persistence_attempts,"observations":observations,"renderer":RenderingServer.get_video_adapter_name()}
	var file=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("ANTLER_MAP_PREVIEW_RESULT passed=%d failed=%d captures=%d" % [checks-failures.size(),failures.size(),files.size()])
	game.free(); viewport.free(); quit(0 if failures.is_empty() else 1)
