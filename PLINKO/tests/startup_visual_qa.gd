extends "res://tests/area_completion_visual_qa.gd"
## Actual studio scene and game renderer, with no player profile IO.
var studio

func render_image(viewport,game) -> Image:
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func same_pixels(a: Image,b: Image) -> bool:
	return a.get_size()==b.get_size() and a.get_data()==b.get_data()

func white_frame(picture: Image) -> bool:
	for y in range(picture.get_height()):
		for x in range(picture.get_width()):
			var c=picture.get_pixel(x,y)
			if minf(c.r,minf(c.g,c.b))<.995 or c.a<.995: return false
	return true

func show_studio(game,area: String,reduced: bool=false):
	game.page_transition.enabled=false; game.page_transition.finish()
	prepare(game,area,reduced)
	game.startup_blocked=true
	studio.status="preview"; studio.reduced_motion=reduced; studio.heartbeat_elapsed=0.0
	studio.get_node("Stage").show(); studio.failure.hide()
	studio._layout(); studio._render_heartbeat()

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new(); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.size=RESOLUTIONS[0]; root.add_child(viewport)
	var game=AuditPreview.new(); viewport.add_child(game)
	studio=load("res://startup.tscn").instantiate(); studio.testing=true; viewport.add_child(studio); studio.set_process(false)
	for resolution in RESOLUTIONS+[Vector2i(450,1000)]:
		viewport.size=resolution
		show_studio(game,"bakery")
		await snap(viewport,game,output,"studio-rest",resolution)
		var resting: Image=viewport.get_texture().get_image()
		var pool=resting.get_pixel(resolution.x/2,roundi(resolution.y*.22))
		var edge=resting.get_pixel(12,12)
		check(pool.get_luminance()>edge.get_luminance()+.08,"Warm spotlight illuminates the logo space with a soft darker edge")
		var bottom_anchor=studio.stamp.get_global_transform()*studio.stamp.pivot_offset
		if resolution==Vector2i(720,1280):
			var static_boot=Image.load_from_file(ProjectSettings.globalize_path("res://data/art/branding/studio_boot.png"))
			check(same_pixels(resting,static_boot),"Engine first frame exactly matches animated scene at rest")
		for moment in [.28,.78,1.08,2.88]:
			studio.heartbeat_elapsed=moment; studio._render_heartbeat()
			await snap(viewport,game,output,"studio-heart-"+str(roundi(moment*100)),resolution)
			var frame=viewport.get_texture().get_image()
			if moment==1.08: check(same_pixels(resting,frame),"Heartbeat settles back to the exact subdued image")
			if moment==.28: check(not same_pixels(resting,frame) and studio.stamp.scale.x>1.05,"Heartbeat visibly brightens and grows the stamp")
			if moment==.28: check(studio.stamp.get_global_transform()*studio.stamp.pivot_offset==bottom_anchor,"Rendered pulse stays anchored at the mark's bottom center")
			if moment==2.88: check(studio.stamp.scale.x>1.05,"Heartbeat repeats while real loading is pending")
		show_studio(game,"bakery",true); studio.heartbeat_elapsed=.28; studio._render_heartbeat()
		await snap(viewport,game,output,"studio-reduced",resolution)
		check(same_pixels(resting,viewport.get_texture().get_image()) and studio.stamp.scale==Vector2.ONE,"Reduced Motion remains exactly static")
		studio._fail("fixture missing resource")
		await snap(viewport,game,output,"studio-load-error",resolution)
		var error_message=studio.get_node("Stage/Canvas/Failure/Message")
		check(not studio.stamp.get_global_rect().intersects(error_message.get_global_rect()),"Loading error copy leaves the studio mark clear")
		var padded_view=Rect2(Vector2(12,12),Vector2(resolution)-Vector2(24,24))
		var controls_fit=true
		for control_name in ["Message","Retry","Quit"]:
			controls_fit=controls_fit and padded_view.encloses(studio.failure.get_node(control_name).get_global_rect())
		check(controls_fit,"Loading recovery controls fit with viewport edge padding")
		check(error_message.get_minimum_size().x<=studio.failure.size.x,"Loading error text fits its control")
		for area in ["bakery","gelato","crystal"]:
			show_studio(game,area); studio.heartbeat_elapsed=2.6; studio._render_heartbeat()
			var source: Image=await render_image(viewport,game)
			var profile=game.AreaCampaign.capture_local(game)
			game.page_transition.enabled=true; game.page_transition.begin("studio",game.mode)
			studio.get_node("Stage").hide(); game.startup_blocked=false
			check(game.page_transition.active and game.mode=="home","Studio handoff preserves "+area+" destination")
			for fraction in [0.0,.25,.5,.75]:
				game.page_transition.time=game.page_transition.DURATION*fraction
				await snap(viewport,game,output,area+"-studio-wave-"+str(roundi(fraction*100)),resolution)
				var frame=viewport.get_texture().get_image()
				if fraction==0: check(same_pixels(source,frame),"Studio frame is held until cream covers "+area)
				if fraction==.5: check(white_frame(frame),"Studio to "+area+" covers every viewport pixel")
			game.page_transition.finish()
			await snap(viewport,game,output,area+"-studio-home",resolution)
			check(game.AreaCampaign.capture_local(game)==profile,"Studio presentation preserves campaign "+area)
		# Restored destinations must stay paused/unclaimed instead of being sent Home.
		for destination in ["paused","result"]:
			show_studio(game,"crystal"); game.startup_blocked=false; play(game)
			if destination=="result": game.remaining=0; game.step(1.0/60.0)
			else: game.mode="paused"
			game.startup_blocked=true; studio._render_heartbeat()
			await render_image(viewport,game)
			var state=game.RunSnapshot.capture(game)
			game.page_transition.enabled=true; game.page_transition.begin("studio",game.mode)
			studio.get_node("Stage").hide(); game.startup_blocked=false
			game.page_transition.time=game.page_transition.DURATION*.75
			await snap(viewport,game,output,"studio-restored-"+destination,resolution)
			game.page_transition.finish()
			check(game.mode==destination and game.RunSnapshot.capture(game)==state,"Studio reveal retains restored "+destination)
	check(game.persistence_attempts==0,"Zero player profile IO in visual fixtures")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE); out.store_string(JSON.stringify(report,"\t"))
	print("STARTUP_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	studio.free(); game.free(); viewport.free(); quit(0 if failures.is_empty() else 1)
