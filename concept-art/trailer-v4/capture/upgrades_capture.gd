extends Node
## Isolated public-UI footage. All art, purchases, navigation and cream drawing are inherited.
const Capture = preload("res://capture/trailer_capture.gd")
const SIZE = Vector2i(1080,1920)
const FPS = 60
var helper
var viewport: SubViewport
var destination = ""
var capture_time = 0.0
var recording = false
var events: Array = []
var purchases: Array = []
var camera_samples: Array = []
var transition_samples: Array = []
var profile_before: Dictionary = {}

func _ready(): call_deferred("run")

func fail(message: String):
	push_error(message)
	get_tree().quit(2)

func log_event(name: String, options: Dictionary):
	if recording: events.append({"time":snappedf(capture_time,.00001),"event":name,"area":helper.g.area_id,"options":options.duplicate(true)})

func tick(dt: float):
	var g=helper.g
	g.elapsed+=dt
	g.navigation_delay=maxf(0,g.navigation_delay-dt)
	g.note_time=maxf(0,g.note_time-dt)
	var page_was_active=g.page_transition.active
	g.page_transition.update(dt)
	g.pause_transition.update(dt)
	g.update_coin_feedback(dt)
	if not page_was_active and not g.page_transition.is_blocking():g.upgrade_map.update(dt)

func touch(index: int, pressed: bool, point: Vector2):
	var event=InputEventScreenTouch.new()
	event.index=index;event.pressed=pressed;event.position=point*1.5
	helper.g.upgrade_map.handle_input(event)

func drag(index: int, point: Vector2, relative: Vector2):
	var event=InputEventScreenDrag.new()
	event.index=index;event.position=point*1.5;event.relative=relative*1.5
	helper.g.upgrade_map.handle_input(event)

func stage_rich_map() -> bool:
	var g=helper.g
	helper.prepare("gelato",12,[0,0,0,0,0,0,0,0])
	g.highest_unlocked=12;g.current_level=12;g.mode="shop";g.bank=5000000
	var omitted: Array[Vector2i]=[]
	for branch in g.GelatoUpgradeGraph.branches():omitted.append(branch[-1])
	# Buy every prerequisite through the production purchase API, leaving six terminal leaves.
	for attempt in range(100):
		var changed=false
		for node in g.GelatoUpgradeGraph.nodes():
			if node in omitted or g.shop_node_owned(node.x,node.y) or not g.shop_node_unlocked(node.x,node.y):continue
			var before=g.bank
			if not g.buy_upgrade_node(node.x,node.y):fail("Normal purchase failed");return false
			purchases.append({"node":[node.x,node.y],"cost":before-g.bank,"levels":g.levels.duplicate()})
			changed=true
			if not g.twin_launchers and g.gelato_launcher.unlocked():
				before=g.bank
				if not g.gelato_launcher.buy():fail("Earned Dual Shot purchase failed");return false
				purchases.append({"ability":"Dual Shot","cost":before-g.bank,"source":g.ability_unlock_source,"power_reset":g.levels[1]})
		if not changed:break
	if not g.ensure_gelato_shop_state() or g.gelato_owned_nodes.size()!=56 or not g.twin_launchers:
		fail("Rich map state is not the expected legal56/62 build");return false
	g.bank=12500;g.note="";g.note_time=0;g.navigation_delay=0
	g.upgrade_map.reset_view_state();g.upgrade_map.update(.01)
	g.upgrade_map._frame_nodes(g.upgrade_map.visible_nodes());g.upgrade_map._finish_camera()
	# Initial overview is a normal attainable map-camera position; the recorded pan uses touch input.
	for _i in range(120):tick(1.0/120.0)
	g.mode="home";g.home_menu.reset();g.upgrade_map.update(.01)
	g.page_transition.enabled=true;g.page_transition.finish()
	profile_before={"area":g.area_id,"tray":g.current_level,"highest_unlocked":g.highest_unlocked,"bank":g.bank,
		"levels":g.levels.duplicate(),"owned_nodes":g.gelato_owned_nodes.duplicate(true),"owned_ordinary":g.gelato_owned_nodes.size(),
		"total_ordinary":g.GelatoUpgradeGraph.nodes().size(),"twin_launchers":g.twin_launchers,"ability_source":g.ability_unlock_source,
		"unowned_terminal_leaves":omitted.map(func(n):return [n.x,n.y]),"zoom":g.upgrade_map.zoom,"pan":[g.upgrade_map.pan.x,g.upgrade_map.pan.y]}
	return true

func save_frame(folder: String, index: int):
	helper.g.queue_redraw();helper.g.page_transition.redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGB8)
	if image.get_size()!=SIZE or image.save_jpg(folder.path_join("frame_%05d.jpg"%index),.96)!=OK:fail("Capture frame failed")
	if index%60==0:print("UPGRADE_FRAME ",index)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):destination=arg.trim_prefix("--output=")
	if not destination.is_absolute_path() or OS.is_debug_build() or not OS.has_feature("sugarfall_public") or DisplayServer.get_name()=="headless":
		fail("Capture requires isolated public nondebug renderer");return
	DirAccess.make_dir_recursive_absolute(destination)
	helper=Capture.new()
	viewport=SubViewport.new();viewport.size=SIZE;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	helper.g=Capture.CaptureGame.new();viewport.add_child(helper.g);helper.g.logger=log_event
	if not stage_rich_map():return
	var g=helper.g
	var folder=destination.path_join("09-upgrades-rich");DirAccess.make_dir_recursive_absolute(folder)
	recording=true
	for frame in range(270):
		capture_time=float(frame)/FPS
		if frame==6:g.handle_press(g.home_menu.UPGRADES_RECT.get_center())
		if frame==72:touch(0,true,Vector2(360,610))
		if frame>72 and frame<=180:
			var before=float(frame-73)/108.0
			var progress=float(frame-72)/108.0
			var previous=Vector2(360,610+smoothstep(0.0,1.0,before)*72)
			var point=Vector2(360,610+smoothstep(0.0,1.0,progress)*72)
			drag(0,point,point-previous)
		if frame==181:touch(0,false,Vector2(360,682))
		tick(1.0/120.0);tick(1.0/120.0)
		transition_samples.append({"frame":frame,"active":g.page_transition.active,"time":g.page_transition.time,"from":g.page_transition.from_mode,"to":g.page_transition.to_mode,"covered":g.page_transition.covered()})
		if frame%30==0:camera_samples.append({"frame":frame,"zoom":g.upgrade_map.zoom,"pan":[g.upgrade_map.pan.x,g.upgrade_map.pan.y]})
		await save_frame(folder,frame)
		if g.developer_tools_available() or g.developer_money_enabled():fail("Developer capability active");return
	recording=false
	var states={}
	for node in g.upgrade_map.visible_nodes():
		var state=g.upgrade_map.state_for(node.x,node.y);states[state]=int(states.get(state,0))+1
	var entry={"name":"09-upgrades-rich","frames":270,"fps":FPS,"seconds":4.5,"pattern":"09-upgrades-rich/frame_%05d.jpg",
		"dimensions":[1080,1920],"before":profile_before,"after":{"mode":g.mode,"bank":g.bank,"levels":g.levels.duplicate(),"owned_nodes":g.gelato_owned_nodes.duplicate(true)},
		"events":events,"visible_state_counts":states,"camera":camera_samples,"page_transition":transition_samples,
		"interaction":{"navigation":"Actual Home Upgrades button at0.10s","cream_duration":g.page_transition.DURATION,"pan":"Actual screen-touch/drag,72localpx upward-map reveal over1.8s"},
		"staged_campaign_state":true,"purchases_before_recording":purchases,"profile_io":g.profile_io,
		"debug":OS.is_debug_build(),"public_feature":OS.has_feature("sugarfall_public"),"production_draw_changed":false,"physics_changed":false}
	if g.profile_io!=0 or g.bank!=profile_before.bank or g.levels!=profile_before.levels or g.gelato_owned_nodes!=profile_before.owned_nodes:fail("Profile or ownership changed during capture");return
	FileAccess.open(folder.path_join("clip.json"),FileAccess.WRITE).store_string(JSON.stringify(entry,"\t"))
	print("UPGRADE_CAPTURE_OK frames270 owned",profile_before.owned_ordinary," states",JSON.stringify(states)," profile_io",g.profile_io)
	g.free();viewport.free();helper.free();get_tree().quit()
