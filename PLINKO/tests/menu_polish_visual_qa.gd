extends "res://tests/area_completion_visual_qa.gd"
## Real GPU frames of menu polish and opaque cream transitions. Isolated in-memory profile.

func identical(a: Image, b: Image) -> bool:
	return a.get_size()==b.get_size() and a.get_data()==b.get_data()

func fully_white(picture: Image) -> bool:
	# Every pixel, including overscan outside the safe area, must be covered.
	for y in range(picture.get_height()):
		for x in range(picture.get_width()):
			var c=picture.get_pixel(x,y)
			if c.r<.995 or c.g<.995 or c.b<.995 or c.a<.995: return false
	return true

func settled_frame(viewport,game) -> Image:
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func setup(game,area: String,reduced: bool=false):
	game.page_transition.enabled=false
	game.page_transition.finish()
	prepare(game,area,reduced)

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
		for area in ["bakery","gelato","crystal"]:
			for page in ["home","support"]:
				setup(game,area); game.mode=page
				await snap(viewport,game,output,area+"-"+page,resolution)
			for reduced in [false,true]:
				setup(game,area,reduced); play(game); effects(game)
				await snap(viewport,game,output,area+"-damage"+("-reduced" if reduced else ""),resolution)
			setup(game,area)
			var old_frame: Image=await settled_frame(viewport,game)
			game.page_transition.enabled=true
			game.mode="shop"
			check(game.page_transition.active and game.page_transition.snapshot!=null,"GPU old-page snapshot "+area)
			for fraction in [0.0,.25,.5,.75]:
				game.page_transition.time=game.page_transition.DURATION*fraction
				await snap(viewport,game,output,area+"-wave-"+str(roundi(fraction*100)),resolution)
				var frame=viewport.get_texture().get_image()
				if fraction==0: check(identical(frame,old_frame),"Wave starts with exact prior frame "+area)
				if fraction==.5: check(fully_white(frame),"Every midpoint pixel is opaque white "+area)
			game.page_transition.finish()
			await snap(viewport,game,output,area+"-upgrades-revealed",resolution)
			check(not game.page_transition.active and game.page_transition.snapshot==null,"Snapshot released "+area)
			setup(game,area,true); await settled_frame(viewport,game)
			game.page_transition.enabled=true; game.mode="support"
			check(not game.page_transition.active,"Reduced Motion changes page without sweep "+area)
			await snap(viewport,game,output,area+"-settings-reduced",resolution)
		# Safe-area gutters must be washed too, not only the 720x1280 game canvas.
		setup(game,"gelato")
		game.apply_safe_area(Rect2(14,35,resolution.x-28,resolution.y-70))
		await settled_frame(viewport,game)
		game.page_transition.enabled=true; game.mode="support"
		game.page_transition.time=game.page_transition.DURATION*.5
		await snap(viewport,game,output,"safe-area-covered",resolution)
		check(fully_white(viewport.get_texture().get_image()),"Safe-area full viewport coverage "+str(resolution))
		game.page_transition.finish()
	check(game.persistence_attempts==0,"Zero player-profile IO")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("MENU_POLISH_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free(); viewport.free(); quit(0 if failures.is_empty() else 1)
