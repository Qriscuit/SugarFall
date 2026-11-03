extends "res://tests/arc_art_visual_qa.gd"
## Capture the production purchase action and its camera trajectory, without saves.

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
	var camera_samples=[]
	for area in ["bakery","gelato"]:
		game.set_active_area(area)
		for scenario in ["starter-close","next","later"]:
			game.mode="shop"
			game.levels.fill(0)
			game.bank=100000
			game.note_time=0
			game.navigation_delay=0
			game.result_input_delay=0
			game.diagnostics_on=false
			m.reset_view_state()
			var bought=Vector2i(0,1)
			if scenario=="starter-close": m.zoom=m.MAX_ZOOM
			elif scenario=="next":
				game.levels[0]=1
				bought=Vector2i(6,1)
			else:
				game.levels[0]=1
				var route=Graph.routes()[0]
				for node in route.slice(0,8): game.levels[node.x]=node.y
				bought=route[8]
			m.pan=m.FOCUS_AREA.get_center()-m.point(bought.x,bought.y)
			m.selected=bought.x; m.tier=bought.y
			m.update(0)
			for stage in ["before","quarter","middle","settled"]:
				if stage=="quarter":
					m.press(m.BUY_RECT.get_center())
					m.update(m.CAMERA_DURATION*.25)
				elif stage=="middle": m.update(m.CAMERA_DURATION*.25)
				elif stage=="settled": m.update(m.CAMERA_DURATION*.5)
				var name=area+"-"+scenario+"-"+stage
				camera_samples.append({"capture":name,"pan":[m.pan.x,m.pan.y],"zoom":m.zoom,"moving":m._camera_active,"selected":[m.selected,m.tier]})
				if not await save_capture(viewport,game,name):
					quit(1)
					return
	if game.persistence_attempts!=0:
		push_error("Unexpected player-profile access")
		quit(1)
		return
	var report=FileAccess.open(output.path_join("camera-samples.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(camera_samples,"\t"))
	print("PURCHASE_CAMERA_VISUAL_QA captures=",count," player_profile_accesses=0")
	game.free()
	viewport.queue_free()
	quit()
