extends Node
## Isolated public-renderer footage capture. Production drawing and physics are inherited.
const Game = preload("res://scripts/main.gd")
const FPS = 60
const SIZE = Vector2i(1080,1920)
var output = ""
var clips: Array = []
var viewport: SubViewport
var g
var shot_name = ""
var shot_clock = 0.0
var record_events = false
var events: Array = []
var clear_probe: Dictionary = {}

class CaptureGame extends Game:
	var profile_io = 0
	var logger: Callable
	func _ready():
		testing=true; sound_on=false
		load_presentation(); food_art.load_assets()
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_dt): pass
	func _physics_process(_dt): pass
	func _input(_event): pass
	func _notification(_what): pass
	func load_game(): profile_io+=1
	func save_game(): profile_io+=1; return false
	func write_profile_file(_data): profile_io+=1; return false
	func feedback(event_name: String, options: Dictionary = {}):
		if logger.is_valid(): logger.call(event_name,options)

func fail(message: String):
	push_error(message)
	get_tree().quit(2)

func _ready(): call_deferred("run")

func log_feedback(event_name: String, options: Dictionary):
	if record_events:
		events.append({"time":snappedf(shot_clock,.00001),"event":event_name,"area":g.area_id,"options":options.duplicate(true)})

func prepare(area: String, tray: int, tiers: Array):
	g.set_active_area(area)
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.scale=Vector2.ONE*1.5; g.position=Vector2.ZERO
	g.testing=true;g.sound_on=false;g.reduced_motion=false
	g.first_run_guide.active=false;g.first_run_guide.completed=true
	g.page_transition.enabled=false;g.pause_transition.settle();g.run_transition.finish()
	g.mode="home";g.shift_claimed=true;g.run_id="";g.trial_active=false
	g.current_level=tray;g.highest_unlocked=maxi(tray,8);g.levels=tiers.duplicate();g.bank=4200
	g.equipped=["splitter","impact"];g.ability_unlock_source="earned"
	g.balls.clear();g.pegs.clear();g.particles.clear();g.floats.clear();g.pickups.clear();g.run_elapsed=0
	g.crystal_launcher.reset_run()
	g.bakery_jam_burst=false;g.bakery_jam_quick=false;g.twin_launchers=false;g.crystal_second_prism=false
	g.gelato_shop_revision=0;g.gelato_owned_nodes=[];g.gelato_reset_power_nodes=[]
	if area=="gelato": g.ensure_gelato_shop_state()
	g.navigation_delay=0;g.result_input_delay=0;g.note="";g.note_time=0;g.elapsed=2
	g.diagnostics_on=false;g.developer_free_purchases.clear()
	g.apply_safe_area(Rect2(0,0,1080,1920))
	g.upgrade_map.reset_view_state();g.home_menu.reset();g.level_map.reset();g.impact_feedback.reset()
	if not g.peg_damaged.is_connected(g.impact_feedback.show_damage):g.peg_damaged.connect(g.impact_feedback.show_damage)

func fixed_step(aim: Vector2, dt: float = 1.0/120.0):
	g.aim_x=aim.x;g.aim_y=aim.y
	if g.mode=="play": g.step(dt)
	g.elapsed+=dt; g.note_time=maxf(0,g.note_time-dt)
	g.navigation_delay=maxf(0,g.navigation_delay-dt)
	g.result_input_delay=maxf(0,g.result_input_delay-dt)
	g.update_coin_feedback(dt)
	g.upgrade_map.update(dt)
	g.level_map.update(dt)

func start_run():
	g.start_shift();g.run_transition.finish()

func advance(seconds: float, aim: Vector2):
	for _i in range(roundi(seconds*120)):
		fixed_step(aim)

func clear_aim() -> Vector2:
	var target=Vector2(360,650)
	var best=-INF
	for peg in g.pegs:
		if peg.hp<=0: continue
		var score=peg.p.y + (1.0-float(peg.hp)/float(peg.max))*50
		if score>best: best=score;target=peg.p
	return Vector2(clampf(target.x,66,654),clampf(target.y,330,1000))

func probe_clear() -> Dictionary:
	for area in ["bakery","gelato","crystal"]:
		for tray in [1,2,3]:
			prepare(area,tray,[10,10,6,6,6,6,8,10])
			g.highest_unlocked=12
			if area=="bakery":
				g.mode="shop"
				if not g.bakery_ability.buy(): continue
			g.equipped=["splitter","impact"]
			start_run()
			for frame in range(7200):
				fixed_step(clear_aim())
				if g.clear_draining:
					return {"area":area,"tray":tray,"last_peg_time":float(frame+1)/120.0,"levels":g.levels.duplicate(),"jam":g.bakery_jam_burst}
				if g.mode!="play": break
	return {}

func frame_image(folder: String, index: int):
	g.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture=viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	if picture.get_size()!=SIZE: fail("Wrong frame size");return
	if picture.save_jpg(folder.path_join("frame_%05d.jpg"%index),.96)!=OK: fail("Frame save failed");return
	if index%60==0: print("FRAME ",shot_name," ",index)

func capture_clip(name: String, seconds: float, policy: Callable, action: Callable = Callable()):
	shot_name=name;shot_clock=0.0;events=[];record_events=true
	var folder=output.path_join(name);DirAccess.make_dir_recursive_absolute(folder)
	var count=roundi(seconds*FPS)
	var before={"area":g.area_id,"tray":g.current_level,"levels":g.levels.duplicate(),"bank":g.bank,"mode":g.mode,
		"run_time":g.run_elapsed,"balls":g.balls.size(),"pegs_remaining":g.pegs.filter(func(p):return p.hp>0).size(),"jam":g.bakery_jam_burst,"twins":g.twin_launchers}
	var min_balls=999;var max_balls=0;var prism_before=-1;var prism_after=-1
	for frame in range(count):
		shot_clock=float(frame)/FPS
		if action.is_valid():
			var state=action.call(shot_clock)
			if state is Dictionary and state.has("prism_before"):
				prism_before=state.prism_before;prism_after=state.prism_after
		var aim: Vector2=policy.call(shot_clock)
		fixed_step(aim);fixed_step(aim)
		min_balls=mini(min_balls,g.balls.size());max_balls=maxi(max_balls,g.balls.size())
		await frame_image(folder,frame)
		if g.developer_tools_available() or g.developer_money_enabled(): fail("Developer capability active");return
	record_events=false
	var entry={"name":name,"frames":count,"fps":FPS,"seconds":seconds,"pattern":name+"/frame_%05d.jpg","before":before,
		"after":{"mode":g.mode,"run_time":g.run_elapsed,"balls":g.balls.size(),"pegs_remaining":g.pegs.filter(func(p):return p.hp>0).size(),"level_won":g.level_won,"clear_draining":g.clear_draining,"levels":g.levels.duplicate(),"bank":g.bank},
		"min_balls":min_balls,"max_balls":max_balls,"prism_before":prism_before,"prism_after":prism_after,"events":events.duplicate(true)}
	clips.append(entry)
	FileAccess.open(folder.path_join("clip.json"),FileAccess.WRITE).store_string(JSON.stringify(entry,"\t"))
	print("CLIP_DONE ",name," frames=",count," balls=",min_balls,"..",max_balls)

func run():
	var probe_only=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
		if arg=="--probe": probe_only=true
	if not output.is_absolute_path() or OS.is_debug_build() or not OS.has_feature("sugarfall_public"): fail("Wrong capture context");return
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=SIZE;viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	g=CaptureGame.new();g.logger=log_feedback;viewport.add_child(g)
	clear_probe=probe_clear()
	if clear_probe.is_empty(): fail("No legal clear recipe found");return
	FileAccess.open(output.path_join("clear-probe.json"),FileAccess.WRITE).store_string(JSON.stringify(clear_probe,"\t"))
	print("CLEAR_PROBE ",JSON.stringify(clear_probe))
	if probe_only: print("TRAILER_PROBE_OK");g.free();get_tree().quit();return
	if DisplayServer.get_name()=="headless": fail("Capture requires renderer");return
	prepare("bakery",1,[2,2,1,0,0,0,1,2]);g.equipped=[];start_run();advance(.3,Vector2(315,700))
	await capture_clip("01-bakery-sparse",4.0,func(t):return Vector2(315+sin(t*.8)*90,700))
	prepare("gelato",4,[4,3,2,2,2,2,2,2]);start_run();advance(1.8,Vector2(570,770))
	await capture_clip("02-gelato-aim",5.0,func(t):return Vector2(520+sin(t*1.1)*90,740+cos(t*.5)*55))
	prepare("crystal",4,[6,5,3,2,3,3,3,4]);start_run();advance(2.4,Vector2(530,760))
	var collected=[false]
	await capture_clip("03-crystal-prism",6.0,func(t):return Vector2(480+sin(t*.9)*80,760),func(t):
		if not collected[0] and t>=1.0 and g.crystal_run.offer_life>0:
			var before=g.crystal_launcher._live_balls().size()
			if g.crystal_launcher.try_collect(g.crystal_run.offer_position):
				collected[0]=true
				return {"prism_before":before,"prism_after":g.crystal_launcher._live_balls().size()}
		return {})
	if not collected[0]:fail("Prism collection missing");return
	prepare("gelato",8,[0,0,0,0,0,0,0,0]);g.mode="shop";g.bank=150
	g.upgrade_map.reset_view_state();g.upgrade_map.update(.01)
	var selected=[false];var bought=[false]
	await capture_clip("04-feed-purchase",3.6,func(_t):return Vector2(360,700),func(t):
		if t>=.5 and not selected[0]:
			g.upgrade_map.select_at(g.upgrade_map.point(0,1));selected[0]=true
		if t>=2.2 and not bought[0]:
			g.upgrade_map.press(g.upgrade_map.buy_rect().get_center());bought[0]=g.levels[0]==1
		return {})
	if not bought[0]:fail("Feed purchase missing");return
	start_run();advance(.5,Vector2(450,740))
	await capture_clip("05-feed-result",3.6,func(t):return Vector2(450+sin(t*.7)*75,740))
	prepare("gelato",8,[8,6,4,3,4,4,4,6]);g.mode="shop";g.bank=4200
	if not g.gelato_launcher.buy():fail("Twin earned purchase missing");return
	start_run();advance(2.2,Vector2(230,780))
	await capture_clip("06-twin-growth",7.0,func(t):return Vector2(300+sin(t*.55)*180,780))
	prepare("bakery",8,[8,6,4,3,4,4,4,6]);g.mode="shop";g.bank=4200
	if not g.bakery_ability.buy():fail("Jam earned purchase missing");return
	start_run();advance(2.1,Vector2(300,740))
	await capture_clip("07-jam-busy",3.0,func(t):return Vector2(300+sin(t*1.2)*180,740))
	prepare(clear_probe.area,clear_probe.tray,[10,10,6,6,6,6,8,10]);g.highest_unlocked=12
	if clear_probe.jam:
		g.mode="shop";g.bank=4200
		if not g.bakery_ability.buy():fail("Clear Jam purchase missing");return
	start_run()
	var skip=maxf(0,float(clear_probe.last_peg_time)-2.0)
	for _i in range(roundi(skip*120)): fixed_step(clear_aim())
	await capture_clip("08-real-clear",6.0,func(_t):return clear_aim())
	if not g.level_won:fail("Final captured clear did not occur");return
	if g.profile_io!=0:fail("Profile IO attempted");return
	var report={"renderer":RenderingServer.get_video_adapter_name(),"debug":OS.is_debug_build(),"public_feature":OS.has_feature("sugarfall_public"),
		"dimensions":[1080,1920],"fps":FPS,"format":"JPEG96 RGB sequence","profile_io":g.profile_io,"clips":clips,"clear_recipe":clear_probe,
		"android_device_capture":false,"staged_campaign_state":true,"game_draw_functions_changed":false,"physics_changed":false,
		"scope":"Fresh current-source nondebug public Windows renderer, fixed120Hz simulation,60fps readback, staged isolated progress/wallets, real purchases and Prism API, no extra balls/pegs or draw overrides."}
	FileAccess.open(output.path_join("capture-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRAILER_CAPTURE_OK clips=",clips.size()," profile_io=",g.profile_io)
	g.free();get_tree().quit()
