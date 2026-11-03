extends "res://tests/arc_art_visual_qa.gd"
## Use the same save-free production preview to inspect each discovery step.

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
	for area in ["bakery","gelato"]:
		game.set_active_area(area)
		game.mode="shop"
		game.levels.fill(0)
		game.bank=220
		game.note_time=0
		game.diagnostics_on=false
		m.reset_view_state()
		m.update(0)
		for stage in ["fresh","starter-bought","bounce-bought","empty-wallet"]:
			if stage=="starter-bought": game.buy_upgrade(0)
			elif stage=="bounce-bought": game.buy_upgrade(2)
			elif stage=="empty-wallet": game.bank=0
			m.update(0)
			m.update(m.FEEDBACK_DURATION+1)
			game.note_time=0
			if not await save_capture(viewport,game,area+"-"+stage):
				quit(1)
				return
	if game.persistence_attempts!=0:
		push_error("Unexpected player-profile access")
		quit(1)
		return
	print("UPGRADE_DISCOVERY_VISUAL_QA captures=",count," player_profile_accesses=0")
	game.free()
	viewport.queue_free()
	quit()
