extends "res://tests/area_completion_visual_qa.gd"
## Actual root-window renders exercise Godot's stretch transform as well as the
## game's safe-area fit. Saves are intercepted by the inherited AuditPreview.
const SIZES = [Vector2i(450,800),Vector2i(450,975),Vector2i(450,1000),Vector2i(450,1050),Vector2i(600,800)]

func _initialize(): call_deferred("run")

func stage(game,area: String):
	game.page_transition.enabled=false
	prepare(game,area)
	game.update_safe_area()
	play(game)
	# Show both cream and gold cups in their actual in-game transforms.
	for i in range(game.buckets.size()): game.buckets[i].gold=i%2==1
	game.queue_redraw()

func frame(game,output: String,name: String):
	game.text_overflows.clear()
	var before=game.AreaCampaign.capture_local(game)
	var rng_before=game.rng.state
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var resolution=root.size
	var file="%s-%dx%d.png"%[name,resolution.x,resolution.y]
	check(picture!=null and picture.get_size()==resolution,"Actual window GPU image "+file)
	check(picture.save_png(output.path_join(file))==OK,"Saved "+file)
	check(game.AreaCampaign.capture_local(game)==before and game.rng.state==rng_before,"Render leaves profile and RNG unchanged "+file)
	files.append(file)
	observations.append({"file":file,"area":game.area_id,"mode":game.mode,"viewport":str(root.get_visible_rect()),"game_transform":str(game.transform),"physical_size":str(root.size)})
	return picture

func assert_fit(game,label: String,safe: Rect2):
	var board=game.transform*Rect2(0,0,720,1280)
	check(safe.grow(.01).encloses(board),label+" complete interactive board inside safe area")
	check(is_equal_approx(game.scale.x,game.scale.y),label+" uniform scale preserves cup/peg/ball shapes")
	check(board.get_center().distance_to(safe.get_center())<.02,label+" logical board centered in safe area")
	# This includes both the root stretch and the independent notch/board fit.
	var physical=root.get_final_transform()*root.get_visible_rect()
	check(physical.position.length()<.05 and physical.size.distance_to(Vector2(root.size))<1.1,label+" viewport spans physical window with no engine letterboxing")
	for point in [Vector2(78,70),Vector2(360,700),Vector2(600,1100)]:
		var screen=root.get_final_transform()*game.to_global(point)
		var local=game.to_local(root.get_final_transform().affine_inverse()*screen)
		check(local.distance_to(point)<.01,label+" physical touch maps back to logical control "+str(point))

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Absolute output directory and GPU renderer required");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","Production project uses expanding viewport")
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND,"Actual window honors expand configuration")
	var game=AuditPreview.new();root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution
		await process_frame;await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage(game,area)
			assert_fit(game,area+str(resolution),root.get_visible_rect())
			var picture=await frame(game,output,area+"-play")
			check(background_corners_match(game,picture,"play_counter","play"),area+str(resolution)+" background art reaches all four physical corners")
		# Synthetic notch and gesture region: scenery must still reach screen edges.
		stage(game,"gelato")
		var safe=root.get_visible_rect().grow_individual(-16,-72,-16,-52)
		game.apply_safe_area(safe)
		assert_fit(game,"notch "+str(resolution),safe)
		var safe_picture=await frame(game,output,"gelato-notch")
		check(background_corners_match(game,safe_picture,"play_counter","play"),"Notch fit keeps edge-to-edge background "+str(resolution))
	root.size=Vector2i(450,1000);await process_frame;await process_frame
	for area in ["bakery","gelato","crystal"]:
		stage(game,area);game.mode="home"
		var home=await frame(game,output,area+"-home")
		check(background_corners_match(game,home,"home_counter","home"),area+" Home fills tall screen")
		game.page_transition.enabled=true;game.start_shift(true)
		check(game.run_transition.active and not game.page_transition.active,area+" Home Play starts tray morph without cream")
		for fraction in [0.0,.25,.6,1.0]:
			game.run_transition.time=game.run_transition.DURATION*fraction
			await frame(game,output,area+"-entry-"+str(int(fraction*100)))
		game.run_transition.finish()
		game.mode="support";game.page_transition.time=game.page_transition.DURATION*.5
		var covered=await frame(game,output,area+"-menu-cream-covered")
		var white=true
		for pixel in [Vector2i(0,0),Vector2i(449,0),Vector2i(0,999),Vector2i(449,999),Vector2i(225,500)]:
			white=white and covered.get_pixelv(pixel).is_equal_approx(Color.WHITE)
		check(white,area+" retained menu cream fully covers expanded physical viewport")
		game.page_transition.finish()
		for cleared in [false,true]:
			stage(game,area)
			game.page_transition.enabled=true
			if cleared:
				for peg in game.pegs:game.damage_peg(peg,peg.hp)
			game.remaining=0
			var backdrop=await frame(game,output,area+("-clear-board" if cleared else "-timeout-board"))
			game.level_won=cleared
			game.finish_shift()
			check(game.mode=="result" and not game.page_transition.active,area+" end-of-run opens result without cream")
			var result=await frame(game,output,area+("-clear-result" if cleared else "-timeout-result"))
			# Outside the dialog, the scene is the same board with a dark scrim.
			var dimmed=true
			for pixel in [Vector2i(2,2),Vector2i(447,2),Vector2i(2,997),Vector2i(447,997)]:
				var before=backdrop.get_pixelv(pixel);var after=result.get_pixelv(pixel)
				dimmed=dimmed and after.get_luminance()<before.get_luminance() and after.get_luminance()>.005
			check(dimmed,area+" result dims the whole physical game background, including expanded margins")
		stage(game,area);game.trial_active=true;game.wave=8;game.remaining=0;game.finish_shift()
		await frame(game,output,area+"-trial-result")
		stage(game,area);game.mode="paused"
		await frame(game,output,area+"-pause")
		stage(game,area);game.finish_shift();game.pegs.clear();game.balls.clear();game.buckets.clear()
		await frame(game,output,area+"-reopened-result")
		stage(game,area);game.finish_shift();game.mode="bonus_confirm"
		await frame(game,output,area+"-reward-dialog")
	# Exercise typography on the hardest tray and maximum gold cup payout.
	for area in ["bakery","gelato","crystal"]:
		stage(game,area);game.wave=12;game.levels=game.MAX_LEVELS.duplicate()
		for cup in game.buckets:cup.gold=true
		await frame(game,output,area+"-max-gold-diamond")
		for i in range(5):game.impact_feedback.catch_food(i)
		await frame(game,output,area+"-cup-catch")
	root.size=Vector2i(450,800);await process_frame;await process_frame
	for area in ["bakery","gelato","crystal"]:
		stage(game,area);game.wave=12
		for peg in game.pegs:game.damage_peg(peg,peg.hp)
		game.remaining=0;game.level_won=true;game.finish_shift()
		await frame(game,output,area+"-area-complete")
	check(game.persistence_attempts==0,"No player-profile IO during visual fixtures")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"));out.close()
	print("SCREEN_POLISH_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free();quit(0 if failures.is_empty() else 1)
