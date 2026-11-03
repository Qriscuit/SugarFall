extends "res://tests/arc_art_visual_qa.gd"
## Render the immediate successor card and a second purchase during its bounce.

func prepare(game, selected_node: Vector2i, wallet: float = 100000):
	game.mode="shop"
	game.levels.fill(0)
	game.levels[0]=1
	game.bank=wallet
	game.note_time=0
	game.navigation_delay=0
	game.result_input_delay=0
	game.diagnostics_on=false
	game.reduced_motion=false
	var m=game.upgrade_map
	m.reset_view_state()
	m.pan=m.FOCUS_AREA.get_center()-m.point(selected_node.x,selected_node.y)
	m.selected=selected_node.x; m.tier=selected_node.y
	m.update(0)

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
	game.scale=Vector2.ONE*450.0/720.0
	var m=game.upgrade_map
	var samples=[]
	for area in ["bakery","gelato"]:
		game.set_active_area(area)
		prepare(game,Vector2i(2,1))
		for stage in ["first-buy","card-bounce","second-buy","settled","unaffordable","reduced-motion","starter-choice","route-complete"]:
			match stage:
				"first-buy": m.press(m.buy_rect().get_center())
				"card-bounce": m.update(.07)
				"second-buy":
					m.press(m.buy_rect().get_center())
					m.update(.07)
				"settled": m.update(m.CAMERA_DURATION+1)
				"unaffordable":
					prepare(game,Vector2i(6,1),81)
					m.press(m.buy_rect().get_center())
					m.update(m.CAMERA_DURATION+1)
				"reduced-motion":
					prepare(game,Vector2i(2,1))
					game.reduced_motion=true
					m.press(m.buy_rect().get_center())
					m.update(m.FEEDBACK_DURATION+1)
				"starter-choice":
					prepare(game,Vector2i(0,1))
					game.levels.fill(0)
					m.update(0)
					m.press(m.buy_rect().get_center())
					m.update(m.CAMERA_DURATION+1)
				"route-complete":
					var last_node: Vector2i = Graph.routes()[0].back()
					prepare(game,last_node)
					game.levels=Graph.CAPS.duplicate()
					game.levels[last_node.x]-=1
					m.selected=last_node.x; m.tier=last_node.y
					m.update(0)
					m.press(m.buy_rect().get_center())
					m.update(m.CAMERA_DURATION+1)
			var name=area+"-"+stage
			samples.append({"capture":name,"selected":[m.selected,m.tier],"card_offset_y":m.card_offset().y,"wallet":game.bank,"state":m.state_for(m.selected,m.tier),"camera_moving":m._camera_active})
			if not await save_capture(viewport,game,name):
				quit(1)
				return
	if game.persistence_attempts!=0:
		push_error("Unexpected player-profile access")
		quit(1)
		return
	var report=FileAccess.open(output.path_join("selection-samples.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(samples,"\t"))
	print("NEXT_SELECTION_VISUAL_QA captures=",count," player_profile_accesses=0")
	game.free()
	viewport.queue_free()
	quit()
