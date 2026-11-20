extends Node
const Game = preload("res://scripts/main.gd")
var shots=[]
var output=""
var failures=[]
var prism_duplicate_report={}
var map_purchase_report=[]
func fail(message):
	push_error(message)
	get_tree().quit(2)
class CaptureGame extends Game:
	var profile_io=0
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

func _ready(): call_deferred("run")

func prepare(g, area, tray, levels):
	g.set_active_area(area)
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.scale=Vector2.ONE*1.5; g.position=Vector2.ZERO
	g.testing=true;g.sound_on=false;g.reduced_motion=false
	g.first_run_guide.active=false;g.first_run_guide.completed=true
	g.page_transition.enabled=false;g.pause_transition.settle();g.run_transition.finish()
	g.mode="home";g.shift_claimed=true;g.run_id="";g.trial_active=false
	g.current_level=tray;g.highest_unlocked=tray;g.levels=levels.duplicate();g.bank=1680
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

func simulate(g, seconds, aim):
	g.start_shift();g.run_transition.finish()
	for frame in range(roundi(seconds*120)):
		g.aim_x=aim.x+sin(frame*.016)*45 if g.area_id=="bakery" else aim.x
		g.aim_y=aim.y
		g.step(1.0/120);g.elapsed+=1.0/120;g.update_coin_feedback(1.0/120)

func capture(viewport,g,name,description):
	g.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	var picture=viewport.get_texture().get_image()
	picture.convert(Image.FORMAT_RGB8)
	var path=output.path_join(name+".png")
	if picture.get_size()!=Vector2i(1080,1920):fail("Wrong capture size");return
	var saved=picture.save_png(path)
	if saved!=OK:fail("Could not save "+path);return
	if g.developer_tools_available() or g.developer_money_enabled():fail("Developer capability active");return
	shots.append({"file":name+".png","area":g.area_id,"tray":g.current_level,"mode":g.mode,"description":description,
		"elapsed":g.run_elapsed,"balls":g.balls.size(),"pegs_remaining":g.pegs.filter(func(p):return p.hp>0).size(),
		"bank":g.bank,"levels":g.levels.duplicate(),"ability_source":g.ability_unlock_source,
		"jam":g.bakery_jam_burst,"twins":g.twin_launchers,"prism_offer":g.crystal_run.get("offer_life",0),"prism_collected":g.crystal_run.get("collected",0),"profile_io":g.profile_io,"ordinary_owned":g.gelato_owned_nodes.size()})

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or OS.is_debug_build() or not OS.has_feature("sugarfall_public"):fail("Wrong public capture context");return
	if DisplayServer.get_name()=="headless":fail("Capture needs GPU renderer");return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new();viewport.size=Vector2i(1080,1920);viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var g=CaptureGame.new();viewport.add_child(g)
	prepare(g,"bakery",4,[4,3,2,2,2,2,2,2]);simulate(g,4.2,Vector2(315,700))
	await capture(viewport,g,"01-bakery-gameplay","Bakery tray4, real drops and peg contacts after4.2 seconds.")
	prepare(g,"gelato",4,[4,3,2,2,2,2,2,2]);simulate(g,3.7,Vector2(570,770))
	await capture(viewport,g,"02-gelato-aim","Gelato tray4, production parabolic preview and physics after3.7 seconds.")
	prepare(g,"crystal",4,[4,3,2,2,2,2,2,2]);simulate(g,4.1,Vector2(530,760))
	if g.crystal_run.offer_life<=0:fail("Missing live Prism offer");return
	await capture(viewport,g,"03-crystal-prism","Crystal tray4, real timed Prism pickup with live balls at4.1 seconds.")
	prepare(g,"gelato",8,[0,0,0,0,0,0,0,0]);g.mode="shop";g.bank=3000
	var bought=0
	for attempt in range(80):
		if bought>=22:break
		for node in g.upgrade_graph().nodes():
			if not g.shop_node_owned(node.x,node.y) and g.buy_upgrade_node(node.x,node.y):
				map_purchase_report.append({"node":[node.x,node.y],"bank_after":g.bank,"levels":g.levels.duplicate()});bought+=1;break
	g.note="";g.note_time=0;g.upgrade_map.update(0)
	g.upgrade_map.selected=-1;g.upgrade_map.twin_selected=false
	g.upgrade_map._frame_nodes(g.upgrade_map.visible_nodes());g.upgrade_map._finish_camera()
	await capture(viewport,g,"04-gelato-upgrades","Gelato map after22 actual coin purchases from an isolated staged wallet; normal reveal rules.")
	prepare(g,"bakery",8,[5,4,3,2,2,2,2,3]);g.mode="shop";g.bank=2400;g.equipped=[]
	if not g.bakery_ability.buy():fail("Jam earned purchase failed");return
	g.note="";g.note_time=0
	g.start_shift();g.run_transition.finish();var found=false
	for frame in range(1800):
		g.aim_x=300;g.aim_y=700;g.step(1.0/120);g.elapsed+=1.0/120;g.update_coin_feedback(1.0/120)
		if not g.bakery_ability.bursts.is_empty():found=true;break
	if not found:fail("No natural jam impact in simulation");return
	await capture(viewport,g,"05-bakery-jam","Tray8 Jam Burst bought through the real earned route, captured on a natural jam impact.")
	prepare(g,"gelato",8,[5,6,3,2,2,2,2,3]);g.mode="shop";g.bank=4200
	if not g.gelato_launcher.buy():fail("Twin earned purchase failed");return
	g.note="";g.note_time=0
	simulate(g,4.2,Vector2(140,800))
	await capture(viewport,g,"06-gelato-twins","Tray8 Dual Shot bought through the real earned route; Power reset retained; both preview paths and shots.")
	prepare(g,"crystal",4,[4,3,2,2,2,2,2,2]);simulate(g,4.1,Vector2(530,760))
	var before=g.balls.size()
	var live_before=g.crystal_launcher._live_balls().size()
	var point=g.crystal_run.get("offer_position",Vector2.ZERO)
	if not g.crystal_launcher.try_collect(point):fail("Real Prism collection failed");return
	var after=g.balls.size()
	prism_duplicate_report={"before":before,"live_before":live_before,"after":after,"duplicated":after-before,"tap_position":[point.x,point.y],"collected":g.crystal_run.collected,"production_api":"crystal_launcher.try_collect"}
	if after-before!=live_before or live_before<3:fail("Prism did not duplicate expected balls");return
	for frame in range(24):
		g.step(1.0/120);g.elapsed+=1.0/120;g.update_coin_feedback(1.0/120)
	await capture(viewport,g,"07-crystal-multiply","Crystal tray4,0.2 seconds after a real live Prism tap; original balls and their duplicates diverge.")
	if g.profile_io!=0:fail("Profile IO attempted");return
	var report={"renderer":RenderingServer.get_video_adapter_name(),"debug":OS.is_debug_build(),"public_feature":OS.has_feature("sugarfall_public"),
		"capture_dimensions":[1080,1920],"format":"24-bit RGB PNG","profile_io":g.profile_io,"captures":shots,
		"android_device_capture":false,"staged_campaign_state":true,"prism_duplication":prism_duplicate_report,"map_purchases":map_purchase_report,"game_draw_functions_changed":false,
		"scope":"Real nondebug Windows rendering of unchanged game runtime at portrait phone dimensions; staged isolated campaign state and fixed-step input, no compositing or added UI."}
	FileAccess.open(output.path_join("capture-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STOREFRONT_CAPTURE_OK captures=",shots.size()," profile_io=",g.profile_io)
	g.free();get_tree().quit()
