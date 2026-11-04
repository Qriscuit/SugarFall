extends "res://tests/area_completion_visual_qa.gd"
## Frame-by-frame capture of the actual startup scene and production handoff.
## The loading destination is staged in memory, so no player profile is opened.
const FPS = 25
const SIZE = Vector2i(450,800)
var frames: Array[Dictionary]=[]

func frame(game,output: String,phase: String,moment: float,beat: float=0.0):
	game.queue_redraw(); game.page_transition.redraw()
	await process_frame; await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	if picture==null or picture.get_size()!=SIZE:
		push_error("Intro capture returned the wrong image size"); quit(2); return
	var name="frame-%04d.png"%frames.size()
	if picture.save_png(output.path_join(name))!=OK:
		push_error("Could not save intro frame"); quit(2); return
	frames.append({"file":name,"phase":phase,"seconds":moment,"heartbeat":beat,"duration_ms":40})

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Intro GIF needs an absolute frame directory and GPU rendering"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=SIZE
	await process_frame; await process_frame
	var studio=load("res://startup.tscn").instantiate()
	studio.testing=true; root.add_child(studio); studio.set_process(false)
	var game=AuditPreview.new(); studio.add_child(game)
	prepare(game,"bakery")
	game.AreaCampaign.apply_local(game,game.AreaCampaign.default_record())
	game.current_level=1; game.highest_unlocked=1; game.bank=0; game.levels.fill(0)
	game.first_run_guide.completed=true; game.first_run_guide.active=false
	game.mode="home"; game.update_safe_area(); game.startup_blocked=true
	game.home_menu.reset(); game.note=""; game.note_time=0
	game.page_transition.enabled=true
	studio.game=game; studio.status="preview"; studio.sound_on=false
	studio.reduced_motion=false; studio._layout()
	var profile=game.AreaCampaign.capture_local(game)
	var rng_before=game.rng.state
	var anchor=studio.stamp.get_global_transform()*studio.stamp.pivot_offset
	# Two 1.30-second cycles retain the actual 2.60-second intro minimum.
	for index in range(65):
		var moment=float(index)/FPS
		studio.heartbeat_elapsed=moment; studio._render_heartbeat()
		check(studio.stamp.get_global_transform()*studio.stamp.pivot_offset==anchor,"Bottom-center anchor frame "+str(index))
		await frame(game,output,"studio",moment,studio.heartbeat_at(moment))
	# Exercise production's ready/quiet-frame gate and its real cream handoff.
	studio.status="ready"; studio.heartbeat_elapsed=studio.MINIMUM_SECONDS
	studio.frames_shown=65; studio.quiet_ready_frame=true; studio.suspended=false
	studio._process(0.0)
	check(studio.handoff_count==1 and game.page_transition.active and not game.startup_blocked,"One actual studio handoff starts cream reveal")
	for index in range(16):
		game.page_transition.time=float(index)/FPS
		await frame(game,output,"cream",2.6+float(index)/FPS)
	game.page_transition.update(.04)
	check(not game.page_transition.active and game.mode=="home","Cream settles on the actual Home renderer")
	for index in range(29):
		await frame(game,output,"home",3.24+float(index)/FPS)
	check(game.persistence_attempts==0,"No player profile reads or writes")
	check(game.AreaCampaign.capture_local(game)==profile and game.rng.state==rng_before,"Capture preserves campaign and RNG")
	var report={"passed":checks-failures.size(),"failed":failures.size(),"failures":failures,"frames":frames,
		"size":[SIZE.x,SIZE.y],"fps":FPS,"duration_ms":frames.size()*40,"renderer":RenderingServer.get_video_adapter_name(),
		"scope":"Actual Godot startup and cream/Home renderer at authored timestamps; staged in-memory ready destination, not a measured cold-load recording. GIF is silent.","profile_io":game.persistence_attempts}
	var file=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("INTRO_GIF_RESULT passed=%d failed=%d frames=%d"%[checks-failures.size(),failures.size(),frames.size()])
	game.free(); quit(0 if failures.is_empty() else 1)
