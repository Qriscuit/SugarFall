extends "res://tests/ui_art_preview.gd"
## Missing area-audit states through the production renderer; no player-profile IO.
const Base = preload("res://tests/ui_art_preview.gd")
var files: Array[String] = []
var observations: Array[Dictionary] = []

class AuditPreview extends Base.PreviewGame:
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts += 1
		return false

func _initialize(): call_deferred("run")

func prepare(game, area: String, reduced: bool = false):
	game.set_active_area(area)
	game.AreaCampaign.apply_local(game,game.AreaCampaign.default_record())
	game.scale=Vector2.ONE*game.get_viewport_rect().size.x/720.0
	game.position=Vector2.ZERO
	game.testing=true; game.sound_on=false; game.reduced_motion=reduced
	game.first_run_guide.active=false; game.first_run_guide.completed=true
	game.mode="home"; game.shift_claimed=true; game.run_id=""; game.trial_active=false
	game.current_level=8; game.highest_unlocked=12; game.bank=12000
	game.levels=[4,6,3,3,3,3,3,4]; game.equipped=["splitter","impact"]
	game.module_vouchers=1; game.trial_records={"4":7.8,"8":11.2}
	game.crystal_second_prism=false; game.twin_launchers=false; game.power_reset_tier=0
	if area=="gelato":
		game.gelato_shop_revision=0; game.gelato_owned_nodes=[]; game.gelato_reset_power_nodes=[]
		check(game.ensure_gelato_shop_state(),"Gelato ownership staged without profile IO")
	game.run_transition.finish(); game.navigation_delay=0; game.result_input_delay=0
	game.note=""; game.note_time=0; game.elapsed=2; game.diagnostics_on=false
	game.upgrade_map.reset_view_state(); game.home_menu.reset(); game.level_map.reset()
	game.impact_feedback.reset(); game.text_overflows.clear()
	if not game.peg_damaged.is_connected(game.impact_feedback.show_damage):
		game.peg_damaged.connect(game.impact_feedback.show_damage)

func play(game):
	game.start_shift(); game.run_transition.finish()
	game.aim_x=510; game.aim_y=740; game.spawn_clock=100
	game.remaining=7.0; game.shift_coins=28
	game.update_coin_feedback(0)

func effects(game):
	# Use actual contact handling to activate a splitter, then real damage/catch APIs.
	var target=game.pegs[3]
	game.spawn_ball(target.p+Vector2(0,-36),"splitter",Vector2(0,360),false)
	game.step(1.0/60.0)
	check(game.balls.size()>=4,"Real split creates parent and shards in "+game.area_id)
	game.damage_peg(game.pegs[6],2.0,true)
	game.damage_peg(game.pegs[9],game.pegs[9].hp)
	game.spawn_ball(Vector2(360,game.BUCKET_CATCH_Y-1),"normal",Vector2(0,300),false)
	game.balls[-1].productive=true
	game.step(1.0/60.0)
	game.spawn_ball(Vector2(490,560),"impact",Vector2(-70,250),false)
	game.spawn_ball(Vector2(150,650),"ricochet",Vector2(230,-150),false)
	game.update_coin_feedback(.07)
	check(not game.impact_feedback.damage_labels.is_empty(),"Real damage signal reaches presentation in "+game.area_id)
	check(game.impact_feedback.bucket_times[2]>0,"Actual catch animates cup in "+game.area_id)

func snap(viewport,game,output: String,name: String,resolution: Vector2i):
	game.capture_name=name; game.text_overflows.clear()
	var before=game.AreaCampaign.capture_local(game)
	var rng_before=game.rng.state
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	var picture=viewport.get_texture().get_image()
	var file="%s-%dx%d.png"%[name,resolution.x,resolution.y]
	check(picture!=null and picture.get_size()==resolution,"GPU frame "+file)
	check(game.text_overflows.is_empty(),"Labels fit "+file+" "+str(game.text_overflows))
	check(picture.save_png(output.path_join(file))==OK,"Saved "+file)
	check(game.AreaCampaign.capture_local(game)==before and game.rng.state==rng_before,"Render is side-effect free "+file)
	files.append(file)
	observations.append({"file":file,"area":game.area_id,"mode":game.mode,"reduced_motion":game.reduced_motion,"balls":game.balls.size(),"damage_labels":game.impact_feedback.damage_labels.size(),"particles":game.particles.size()})

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Absolute output and GPU renderer required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new(); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=AuditPreview.new(); viewport.add_child(game)
	for resolution in RESOLUTIONS:
		viewport.size=resolution
		for area in ["gelato","crystal"]:
			for page in ["guide","loadout","trials","support"]:
				prepare(game,area); game.mode=page
				await snap(viewport,game,output,area+"-"+page,resolution)
			prepare(game,area); play(game); game.mode="paused"
			await snap(viewport,game,output,area+"-pause",resolution)
			for reduced in [false,true]:
				prepare(game,area,reduced); play(game); effects(game)
				await snap(viewport,game,output,area+"-effects"+("-reduced" if reduced else ""),resolution)
				game.remaining=1.7
				if area=="gelato": game.pickups=[{"p":Vector2(550,740),"life":.6}]
				else:
					game.run_elapsed=3.0; game.crystal_launcher.advance(0)
					game.run_elapsed=6.4; game.crystal_launcher.advance(0)
				await snap(viewport,game,output,area+"-countdown"+("-reduced" if reduced else ""),resolution)
				if area=="gelato":
					game.collect_pickups(Vector2(550,740))
					game.step(1.0/60.0)
					check(game.pickups.is_empty() and game.time_bonus>0,"Gelato time pickup collected")
					await snap(viewport,game,output,"gelato-pickup-collected"+("-reduced" if reduced else ""),resolution)
			for cleared in [false,true]:
				prepare(game,area); play(game)
				if cleared:
					for peg in game.pegs: game.damage_peg(peg,peg.hp)
					game.step(1.0/60.0)
				else:
					game.remaining=0; game.step(1.0/60.0)
				check(game.mode=="result" and game.level_won==cleared,"Actual clear/fail reaches result in "+area)
				await snap(viewport,game,output,area+("-clear" if cleared else "-fail"),resolution)
		# Deep Crystal cards and real clamp boundaries complement the existing entry/overview proof.
		for view in ["deep-card","deep-owned","edge-left","edge-right","zoomed-card"]:
			prepare(game,"crystal"); game.mode="shop"
			game.levels=game.MAX_LEVELS.duplicate(); game.levels[1]=7
			if view=="deep-owned": game.levels[1]=8
			var map=game.upgrade_map
			map.reset_view_state(); map.selected=1; map.tier=8; map.update(0)
			map.zoom=map.MAX_ZOOM if view=="zoomed-card" else .72
			var selected_nodes: Array[Vector2i]=[Vector2i(1,8)]
			map._frame_nodes(selected_nodes)
			map.update(map.CAMERA_DURATION)
			if view.begins_with("edge-"):
				map.pan.x=100000 if view=="edge-left" else -100000
				map._clamp_pan()
			await snap(viewport,game,output,"crystal-"+view,resolution)
	check(game.persistence_attempts==0,"Zero player-profile IO")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("AREA_COMPLETION_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free(); viewport.free(); quit(0 if failures.is_empty() else 1)
