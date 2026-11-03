extends "res://tests/area_ability_visual_qa.gd"
## Render the far-end reward and four-charge HUD at actual portrait sizes.

func reward_stage(game):
	stage(game,"bakery")
	game.mode="shop"; game.highest_unlocked=10; game.current_level=10
	game.levels=game.MAX_LEVELS.duplicate(); game.bank=0
	game.bakery_jam_burst=true; game.bakery_jam_quick=false
	game.upgrade_map.reset_view_state(); game.upgrade_map.update(0)

func focus_reward(game,at_zoom=.84):
	var map=game.upgrade_map
	var cap_nodes: Array[Vector2i]=[map.MORE_JAM_NODE]
	map.selected=map.MORE_JAM_NODE.x; map.tier=map.MORE_JAM_NODE.y; map.twin_selected=false
	map.zoom=at_zoom; map._frame_nodes(cap_nodes); map._finish_camera()
	map.update(0); map.feedback.clear()

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("More Jam visual QA requires absolute output and an actual GPU renderer"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game=AbilityPreview.new(); root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution; await process_frame; await process_frame
		reward_stage(game)
		await capture(game,output,"more-jam-ready",resolution)
		check(game.upgrade_map.state_for(8,2)=="affordable","Eligible free node is green at zero coins")
		game.levels[0]-=1; focus_reward(game)
		await capture(game,output,"more-jam-lanes-locked",resolution)
		reward_stage(game); game.highest_unlocked=9; focus_reward(game)
		await capture(game,output,"more-jam-tray-locked",resolution)
		reward_stage(game)
		check(game.bakery_ability.quick_buy(),"Real More Jam claim succeeds in isolated renderer")
		focus_reward(game)
		await capture(game,output,"more-jam-owned",resolution)
		game.upgrade_map.zoom=.23
		var tips: Array[Vector2i]=game.upgrade_map.node_prerequisites(game.upgrade_map.MORE_JAM_NODE)
		tips.append(game.upgrade_map.MORE_JAM_NODE)
		game.upgrade_map._frame_nodes(tips); game.upgrade_map._finish_camera()
		await capture(game,output,"more-jam-three-lanes",resolution)
		game.start_shift(); game.run_transition.finish(); game.spawn_clock=100; game.pickup_clock=100
		for index in range(3): game.spawn_ball(Vector2(180+index*90,420),"normal",Vector2(0,85),false)
		check(game.bakery_ability.cadence()==4,"Claimed run uses the four-drop meter")
		await capture(game,output,"more-jam-three-charges",resolution)
		game.spawn_ball(Vector2(450,380),"normal",Vector2(0,85),false)
		check(game.balls[-1].jam,"Fourth normal ball carries jam")
		await capture(game,output,"more-jam-fourth-ball",resolution)
	check(game.persistence_attempts==0,"More Jam rendering never accesses player profiles")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"phone_verified":false,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")); out.close()
	print("MORE_JAM_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free(); quit(0 if failures.is_empty() else 1)
