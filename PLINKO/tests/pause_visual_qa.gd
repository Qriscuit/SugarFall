extends "res://tests/area_completion_visual_qa.gd"
## Production GPU layers, manually stepped presentation, no player profile IO.
const SIZES = [Vector2i(450,800),Vector2i(450,1000)]

func _initialize(): call_deferred("run")

func stage_pause(game, area: String, reduced: bool = false):
	game.page_transition.enabled = false
	prepare(game,area,reduced)
	game.update_safe_area()
	game.start_shift()
	game.run_transition.finish()
	game.aim_x = 510; game.aim_y = 740
	# A real, valid early run gives the background moving balls to preserve.
	for tick in range(60): game.step(1.0/60.0)
	game.elapsed = .85
	game.note_time = 0
	game.navigation_delay = 0
	game.update_coin_feedback(0)
	game.page_transition.enabled = true
	game.pause_transition.settle()
	game.pause_transition.sync_visuals()
	check(game.mode == "play" and not game.RunSnapshot.capture(game).is_empty(),area+" visual fixture is an active, resumable run")

func frozen_state(game) -> Dictionary:
	return {"run":game.RunSnapshot.capture(game).duplicate(true),"profile":game.AreaCampaign.capture_local(game).duplicate(true),"rng":game.rng.state,"elapsed":game.elapsed,"particles":game.particles.duplicate(true),"floats":game.floats.duplicate(true),"checkpoint":game.checkpoint_clock}

func frame(game, output: String, label: String, expect_cream: bool = false) -> Image:
	game.capture_name = label
	game.text_overflows.clear()
	var before = frozen_state(game)
	game.pause_transition.sync_visuals()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var size = root.size
	var file = "%s-%dx%d.png" % [label,size.x,size.y]
	check(image != null and image.get_size() == size,"Actual GPU viewport captured: "+file)
	check(image.save_png(output.path_join(file)) == OK,"Saved capture: "+file)
	check(frozen_state(game) == before,"Rendering keeps run, profile, RNG and effects frozen: "+file)
	check(game.page_transition.active==expect_cream,("Expected cream cover retained: " if expect_cream else "No cream during pause presentation: ")+file)
	check(game.text_overflows.is_empty(),"Pause labels fit: "+file+" "+str(game.text_overflows))
	files.append(file)
	observations.append({"file":file,"area":game.area_id,"mode":game.mode,"phase":game.pause_transition.phase,"time":game.pause_transition.time,"menu_alpha":game.pause_transition.menu_alpha,"blur_amount":game.pause_transition.blur_amount,"resolution":str(size),"transform":str(game.transform)})
	return image

func pixel_rect(game, logical: Rect2, image: Image) -> Rect2i:
	var transform = root.get_final_transform()*game.get_global_transform_with_canvas()
	var physical: Rect2 = transform*logical
	return Rect2i(physical.position.ceil(),physical.size.floor()).intersection(Rect2i(Vector2i.ZERO,image.get_size()))

func patch_delta(first: Image, second: Image, bounds: Rect2i) -> float:
	var biggest = 0.0
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var a = first.get_pixel(x,y); var b = second.get_pixel(x,y)
			biggest = maxf(biggest,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	return biggest

func detail_energy(image: Image, bounds: Rect2i) -> float:
	# Normalizing the Laplacian by local contrast distinguishes blur from a
	# flat translucent scrim, which scales both numerator and denominator.
	var region = bounds.grow(-1)
	var mean = 0.0; var count = 0
	for y in range(region.position.y,region.end.y,2):
		for x in range(region.position.x,region.end.x,2):
			mean += image.get_pixel(x,y).get_luminance(); count += 1
	mean /= maxf(1.0,float(count))
	var detail = 0.0; var contrast = 0.0
	for y in range(region.position.y,region.end.y,2):
		for x in range(region.position.x,region.end.x,2):
			var center = image.get_pixel(x,y).get_luminance()
			var neighbors = image.get_pixel(x-1,y).get_luminance()+image.get_pixel(x+1,y).get_luminance()+image.get_pixel(x,y-1).get_luminance()+image.get_pixel(x,y+1).get_luminance()
			detail += absf(neighbors-4.0*center)
			contrast += absf(center-mean)
	return detail/maxf(.000001,contrast)

func corners_treated(before: Image, after: Image) -> bool:
	var size = before.get_size()
	var total_before = 0.0; var total_after = 0.0
	for point in [Vector2i(2,2),Vector2i(size.x-3,2),Vector2i(2,size.y-3),size-Vector2i(3,3)]:
		var clear = before.get_pixelv(point)
		var treated = after.get_pixelv(point)
		# Blur can brighten a dark corner by averaging surrounding light art.
		# Every sampled edge must be affected and opaque; aggregate light falls.
		if clear.is_equal_approx(treated) or treated.a<.99 or treated.get_luminance()<.005: return false
		total_before += clear.get_luminance(); total_after += treated.get_luminance()
	return total_after<total_before

func entirely_white(image: Image) -> bool:
	if image.get_format() not in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]: return false
	var bytes = image.get_data()
	return bytes.count(255)==bytes.size()

func run():
	var output = output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("Absolute output directory and GPU renderer required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game = AuditPreview.new()
	root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size = resolution
		await process_frame; await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage_pause(game,area)
			var clear = await frame(game,output,area+"-play")
			var preserved = frozen_state(game)
			game.mode = "paused"
			game.pause_transition.update(game.pause_transition.OPEN_DURATION*.5)
			check(game.pause_transition.active and game.pause_transition.menu_alpha>0 and game.pause_transition.menu_alpha<1 and game.pause_transition.blur_amount>0 and game.pause_transition.blur_amount<1,area+" pause menu and blur fade in together")
			await frame(game,output,area+"-opening")
			game.pause_transition.update(game.pause_transition.OPEN_DURATION*.5+.00001)
			var paused = await frame(game,output,area+"-paused")
			check(not game.pause_transition.active and is_equal_approx(game.pause_transition.menu_alpha,1) and is_equal_approx(game.pause_transition.blur_amount,1),area+" pause settles to a full sharp menu and slight blur")
			var backdrop_bounds = game.pause_transition.backdrop.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,game.pause_transition.backdrop.size)
			check(backdrop_bounds.grow(.01).encloses(root.get_visible_rect()),area+" pause backdrop geometry spans the full physical viewport")
			check(corners_treated(clear,paused),area+" backdrop treats all physical corners and dims the overall scene including expanded portrait margins")
			game.pause_transition.blur_amount = 0
			var control = await frame(game,output,area+"-sharp-control")
			var resume_center: Vector2 = game.pause_menu_layout().actions.resume.get_center()
			var label_delta = patch_delta(paused,control,pixel_rect(game,Rect2(resume_center-Vector2(100,20),Vector2(200,40)),paused))
			check(label_delta<=1.01/255.0,area+" Resume label/button stays sharp when background blur changes (max delta "+str(label_delta)+")")
			var hud = pixel_rect(game,Rect2(24,28,650,100),paused)
			var blurred_detail = detail_energy(paused,hud)
			var clear_detail = detail_energy(control,hud)
			check(blurred_detail<clear_detail*.9,area+" HUD pixels visibly soften independently of flat dimming ("+str(blurred_detail)+" < "+str(clear_detail)+")")
			game.pause_transition.blur_amount = 1
			game.pause_transition.sync_visuals()
			game.mode = "abandon_confirm"
			await frame(game,output,area+"-finish-confirm")
			check(game.pause_transition.blur_amount==1 and not game.pause_transition.active,area+" finish confirmation retains settled blur without cream")
			game.mode = "paused"
			game.mode = "play"
			game.pause_transition.update(game.pause_transition.MENU_OUT_DURATION*.5)
			check(game.pause_transition.menu_alpha>0 and game.pause_transition.menu_alpha<1 and game.pause_transition.blur_amount==1,area+" Resume first fades only the menu")
			await frame(game,output,area+"-menu-exit")
			game.pause_transition.update(game.pause_transition.MENU_OUT_DURATION*.5+game.pause_transition.BLUR_OUT_DURATION*.5)
			check(game.pause_transition.menu_alpha==0 and game.pause_transition.blur_amount>0 and game.pause_transition.blur_amount<1,area+" Resume then clears only the blur")
			await frame(game,output,area+"-blur-exit")
			game.pause_transition.update(game.pause_transition.BLUR_OUT_DURATION*.5+.00001)
			var resumed = await frame(game,output,area+"-resumed")
			check(resumed.get_data()==clear.get_data(),area+" resumed pixels exactly equal the original frozen gameplay without residual blur or dimming")
			check(frozen_state(game)==preserved,area+" full pause/confirm/resume flow preserves the existing run and its visuals")
			if resolution==Vector2i(450,1000):
				var saved = game.RunSnapshot.capture(game)
				game.page_transition.enabled = false
				check(game.restore_active_run(saved),area+" valid active run restores for pause rendering")
				game.page_transition.enabled = true
				check(game.mode=="paused" and game.resumed_run and not game.pause_transition.active,area+" restore opens an already settled pause")
				check(game.note.is_empty() and game.note_time==0,area+" restored run needs no redundant welcome toast")
				await frame(game,output,area+"-restored")
				stage_pause(game,area,true)
				game.mode = "paused"
				check(not game.pause_transition.active and game.pause_transition.menu_alpha==1 and game.pause_transition.blur_amount==1,area+" Reduced Motion shows static pause without hidden animation delay")
				await frame(game,output,area+"-reduced-motion")
	# Moving cream above the pause children must preserve the two routes that
	# still use it: studio restoration and ordinary menu navigation.
	stage_pause(game,"gelato")
	game.mode = "paused"
	game.pause_transition.update(game.pause_transition.OPEN_DURATION)
	var studio_state = frozen_state(game)
	game.page_transition.begin("studio","paused")
	game.page_transition.time = game.page_transition.DURATION*.5
	var studio_cover = await frame(game,output,"gelato-studio-paused-covered",true)
	check(entirely_white(studio_cover),"Studio cream midpoint is opaque over both the blurred board and sharp pause panel")
	game.page_transition.finish()
	await frame(game,output,"gelato-studio-paused-revealed")
	check(game.mode=="paused" and game.pause_transition.menu_alpha==1 and game.pause_transition.blur_amount==1 and frozen_state(game)==studio_state,"Studio cream reveals the same settled paused run without advancing it")
	game.page_transition.enabled = false
	game.mode = "home"
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	game.page_transition.enabled = true
	game.mode = "support"
	game.page_transition.time = game.page_transition.DURATION*.5
	var settings_cover = await frame(game,output,"gelato-home-settings-covered",true)
	check(entirely_white(settings_cover),"Ordinary Home-to-Settings cream still covers the complete expanded viewport")
	game.page_transition.finish()
	check(game.persistence_attempts==0,"No player-profile reads or writes during pause visual fixtures")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name(),"phone_verified":false}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")); out.close()
	print("PAUSE_PREVIEW_RESULT passed=%d failed=%d captures=%d" % [checks-failures.size(),failures.size(),files.size()])
	game.free(); quit(0 if failures.is_empty() else 1)
