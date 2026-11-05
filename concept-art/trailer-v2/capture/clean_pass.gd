extends Node
## Presentation-only compositing pass. Restore every live ball before physics advances.
const Capture = preload("res://capture/trailer_capture.gd")
const HIDE_FROM = {1:225,7:294,15:321}
var helper
var viewport: SubViewport
var tracks: Array = []
var events: Array = []
var frame_states: Array = []
var changed: Array = []
var clock = 0.0
var destination = ""

func _ready(): call_deferred("run")

func log_event(name: String, options: Dictionary):
	events.append({"time":snappedf(clock,.00001),"event":name,"area":helper.g.area_id,"options":options.duplicate(true)})

func identity(ball: Dictionary) -> int:
	for track in tracks:
		if is_same(track.ball,ball): return track.id
	var id=tracks.size()+1
	tracks.append({"id":id,"ball":ball})
	return id

func fail(message: String):
	push_error(message)
	get_tree().quit(2)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):destination=arg.trim_prefix("--output=")
	if not destination.is_absolute_path():fail("Absolute output required");return
	if OS.is_debug_build() or not OS.has_feature("sugarfall_public"):
		fail("Clean draw pass requires the original nondebug public capture binary");return
	if DisplayServer.get_name()=="headless":fail("GPU renderer required");return
	DirAccess.make_dir_recursive_absolute(destination)
	helper=Capture.new()
	viewport=SubViewport.new();viewport.size=Vector2i(1080,1920)
	viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	helper.g=Capture.CaptureGame.new();viewport.add_child(helper.g)
	helper.g.logger=log_event
	helper.prepare("gelato",8,[8,6,4,3,4,4,4,6]);helper.g.mode="shop";helper.g.bank=4200
	if not helper.g.gelato_launcher.buy():fail("Earned twin purchase failed");return
	helper.start_run();helper.advance(2.2,Vector2(230,780))
	events=[]
	var before={"balls":helper.g.balls.size(),"bank":helper.g.bank,"run_time":helper.g.run_elapsed,"levels":helper.g.levels.duplicate(),"mode":helper.g.mode,"pegs_remaining":helper.g.pegs.filter(func(p):return p.hp>0).size()}
	var min_balls=999;var max_balls=0
	for frame in range(420):
		clock=float(frame)/60.0
		var aim=Vector2(300+sin(clock*.55)*180,780)
		helper.fixed_step(aim);helper.fixed_step(aim)
		min_balls=mini(min_balls,helper.g.balls.size());max_balls=maxi(max_balls,helper.g.balls.size())
		var complete_balls: Array = helper.g.balls
		var visible_balls: Array = []
		var hidden: Array = []
		var snapshot: Array = []
		for ball in complete_balls:
			var id=identity(ball)
			var p=helper.g.board_to_screen(ball.p)*1.5
			snapshot.append({"id":id,"x":snappedf(p.x,.001),"y":snappedf(p.y,.001),"vx":snappedf(ball.v.x*1.575,.001),"vy":snappedf(ball.v.y*1.575,.001),"kind":ball.kind,"radius_px":ball.r*1.575,"life":snappedf(ball.life,.001)})
			if HIDE_FROM.has(id) and frame>=HIDE_FROM[id]:hidden.append(id)
			else:visible_balls.append(ball)
		frame_states.append({"frame":frame,"time":snappedf(clock,.00001),"balls":snapshot})
		# No simulation, input or save method runs while the drawing list is filtered.
		if not hidden.is_empty():helper.g.balls=visible_balls
		helper.g.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not hidden.is_empty():
			var image=viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			if image.get_size()!=Vector2i(1080,1920):fail("Wrong frame size");return
			var file="frame_%05d.jpg"%frame
			if image.save_jpg(destination.path_join(file),.96)!=OK:fail("Frame save failed");return
			changed.append({"source_frame":frame,"source_time":clock,"hidden_ids":hidden,"file":file})
		# Restore the identical full array before ANY following physics step.
		helper.g.balls=complete_balls
		if not is_same(helper.g.balls,complete_balls):fail("Full ball array not restored");return
	var report={"scope":"Presentation-only clean plate for promotional handoff; production drawing inherited, selected ball sprites suppressed only during draw readback, full ball array restored before every fixed step.",
		"debug":OS.is_debug_build(),"public_feature":OS.has_feature("sugarfall_public"),"before":before,
		"after":{"balls":helper.g.balls.size(),"run_time":helper.g.run_elapsed,"bank":helper.g.bank,"levels":helper.g.levels.duplicate(),"mode":helper.g.mode,"pegs_remaining":helper.g.pegs.filter(func(p):return p.hp>0).size(),"level_won":helper.g.level_won,"clear_draining":helper.g.clear_draining},
		"min_balls":min_balls,"max_balls":max_balls,
		"fps":60,"dimensions":[1080,1920],"jpeg_quality":.96,"contact_inclusive":true,"changed_frames":changed,
		"events":events,"frames":frame_states,"profile_io":helper.g.profile_io,
		"physics_changed":false,"economy_changed":false,"production_source_changed":false}
	FileAccess.open(destination.path_join("clean-pass-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	print("CLEAN_PASS_OK changed=",changed.size()," before=",before.balls," after=",helper.g.balls.size()," profile_io=",helper.g.profile_io)
	helper.g.free();viewport.free();helper.free();get_tree().quit()
