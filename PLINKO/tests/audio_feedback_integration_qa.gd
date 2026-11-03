extends SceneTree
## Actual action hooks with intercepted saves; no player profile is discovered.
const Campaign=preload("res://scripts/area_campaign.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var heard: Array[String]=[]
	var heard_areas: Array[String]=[]
	var fail_write=false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func write_profile_file(_data: Dictionary) -> bool: return not fail_write
	func listen(event_name: String,event_area: String):
		heard.append(event_name); heard_areas.append(event_area)
	func clear_heard(): heard.clear(); heard_areas.clear()

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area="bakery"):
	var g=Fixture.new()
	g.testing=true;g.page_transition.enabled=false
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area(area);Campaign.apply_local(g,Campaign.default_record())
	g.area_records={"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.bank=10000;g.shift_claimed=true;g.run_id="";g.navigation_delay=0;g.result_input_delay=0
	g.rng.seed=714203
	g.audio_feedback_requested.connect(g.listen)
	return g

func touch(g,p: Vector2,down: bool,index=0,cancel=false):
	var event=InputEventScreenTouch.new()
	event.position=p;event.pressed=down;event.index=index;event.canceled=cancel
	g._input(event)

func menus():
	var g=fixture()
	g.handle_press(Vector2(5,500))
	check(g.heard.is_empty(),"Blank Home taps produce no feedback")
	var p=g.home_menu.MENU_RECT.get_center()
	touch(g,p,true);touch(g,p,false,0,true)
	check(g.heard.is_empty() and not g.home_menu.menu_open,"Canceled Home touch is silent")
	touch(g,p,true);touch(g,p,true,1);touch(g,p,false,1);touch(g,p,false)
	check(g.heard.is_empty() and not g.home_menu.menu_open,"Extra fingers cannot play or activate a menu")
	touch(g,p,true);touch(g,p,false)
	check(g.heard==["ui_tap"] and g.home_menu.menu_open,"Completed menu tap plays one cue")
	g.clear_heard();g.home_menu.close_menu()
	check(g.heard==["ui_back"],"Closing Home popover has a back cue")
	g.clear_heard();g.mode="support"
	check(g.heard==["ui_tap"],"Opening Settings has one navigation cue")
	g.navigation_delay=0;g.clear_heard();g.handle_press(g.settings_menu_layout().actions.motion.get_center())
	check(g.heard==["ui_confirm"],"Motion setting confirms only its completed action")
	g.navigation_delay=0;g.clear_heard();g.handle_press(g.settings_menu_layout().actions.sound.get_center())
	check(not g.sound_on and g.heard.is_empty(),"Disabling Sound remains silent")
	g.navigation_delay=0;g.handle_press(g.settings_menu_layout().actions.sound.get_center())
	check(g.sound_on and g.heard==["ui_confirm"],"Re-enabling Sound gives one confirmation")
	g.free()

func run_and_lifecycle():
	var g=fixture();g.setup_audio()
	g.remove_child(g.game_audio);root.add_child(g.game_audio)
	g.start_shift();g.run_transition.finish()
	check(g.heard==["run_start"],"Fresh run emits one start cue")
	g.clear_heard();g.mode="paused"
	check(g.heard==["pause"],"Pause emits its own cue")
	g.clear_heard();g.mode="play"
	check(g.heard==["resume"],"Resume emits its own cue")
	g.testing=false;g.game_audio.advance(1);g.feedback("ui_confirm")
	check(g.game_audio.active_voice_count()>0,"Production wrapper reaches the actual cached voice pool")
	g.sound_on=false
	check(g.game_audio.active_voice_count()==0,"Sound-off setter immediately stops playing voices")
	g.sound_on=true;g.clear_heard();g.feedback("ui_confirm")
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(g.game_audio.active_voice_count()==0 and g.game_audio.suspended,"Background notification stops audio immediately")
	g.clear_heard();g.feedback("upgrade")
	check(g.heard.is_empty(),"Background requests are discarded rather than queued")
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	g._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(g.game_audio.suspended,"Application resume alone cannot override lost window focus")
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(not g.game_audio.suspended and g.game_audio.active_voice_count()==0,"Foreground return stays silent with no stale replay")
	g.testing=true;g.mode="play";g.clear_heard();g.remaining=3.02;g.spawn_clock=100
	g.step(.04)
	check(g.heard.count("countdown")==1,"Timer emits one warning at the three-second boundary")
	g.clear_heard();g.step(.02)
	check(not g.heard.has("countdown"),"Timer does not repeat the warning every frame")
	g.clear_heard();g.finish_shift(false)
	check(g.heard==["tray_loss"],"Timed or abandoned run uses the gentle result cue once")
	g.clear_heard();g.finish_shift(false)
	check(g.heard.is_empty(),"Repeated result completion cannot replay the sting")
	g.collect_reward()
	check(g.heard==["collect"],"Collect produces one reward cue")
	g.game_audio.free();g.game_audio=null;g.free()

func upgrades_and_offers():
	for area in Campaign.IDS:
		var g=fixture(area);g.mode="shop";g.clear_heard()
		check(g.buy_upgrade_node(0,1),area+" legal first upgrade can be bought")
		check(g.heard==["upgrade"],area+" purchase cue follows a successful transaction")
		g.clear_heard();g.buy_upgrade_node(0,1)
		check(g.heard.is_empty(),area+" duplicate upgrade request has no success cue")
		g.free()
	var failed=fixture();failed.mode="shop";failed.testing=false;failed.fail_write=true;failed.clear_heard()
	check(not failed.buy_upgrade_node(0,1) and failed.heard.is_empty(),"Failed save rolls back without a purchase-success sound")
	failed.free()
	for area in Campaign.IDS:
		var g=fixture(area);g.ability_ui.open("home");g.clear_heard()
		g.ability_ui.press(g.ability_ui.EARLY_RECT.get_center())
		check(g.heard==["ui_tap"] and not g.ability_ui.owned(),area+" opening test checkout does not celebrate an unlock")
		g.clear_heard();g.ability_ui.press(g.ability_ui.RESTORE_RECT.get_center())
		check(g.heard==["ui_back"] and not g.ability_ui.owned(),area+" cancel gives no purchase cue")
		g.ability_ui.press(g.ability_ui.EARLY_RECT.get_center());g.clear_heard()
		g.ability_ui.press(g.ability_ui.EARLY_RECT.get_center())
		check(g.heard==["twin_transform" if area=="gelato" else "ability_purchase"] and g.ability_ui.owned(),area+" confirmed test grant uses its ability cue exactly once")
		g.clear_heard();g.ability_ui.press(g.ability_ui.EARLY_RECT.get_center())
		check(g.heard.is_empty(),area+" owned ability cannot replay purchase success")
		g.free()

func mechanics():
	for area in Campaign.IDS:
		var g=fixture(area);g.start_shift();g.run_transition.finish();g.clear_heard()
		g.spawn_ball(Vector2(360,267),"normal",Vector2(0,85),false)
		check(g.heard==["launch"] and g.heard_areas==[area],area+" actual launcher drop selects its material sound")
		g.clear_heard();g.damage_peg(g.pegs[0],.25)
		check(g.heard==["peg_hit"],area+" surviving peg gives a hit cue")
		g.clear_heard();g.damage_peg(g.pegs[0],10000)
		check(g.heard.has("peg_break"),area+" peg destruction gives a break cue")
		g.clear_heard();g.damage_peg(g.pegs[0],10000)
		check(g.heard.is_empty(),area+" dead peg cannot replay impact or break sounds")
		g.clear_heard();g.add_time(.5)
		check(g.heard==["time_pickup"],area+" awarded extra time has one cue")
		g.clear_heard();g.time_bonus=g.BONUS_TIME_CAP;g.add_time(2)
		check(g.heard.is_empty(),area+" capped time award has no false success cue")
		g.clear_heard();g.balls=[{"p":Vector2(360,g.BUCKET_CATCH_Y+2),"v":Vector2(0,100),"kind":"normal","r":9.0,"used":false,"productive":true,"cool":1.0,"life":0.0,"dead":false}];g.spawn_clock=100
		g.step(.001)
		check(g.heard.count("cup_catch")==1,area+" food landing in a cup produces one catch cue")
		g.free()
	var jam=fixture();jam.bakery_jam_burst=true;jam.start_shift();jam.run_transition.finish();jam.clear_heard()
	var ball={"kind":"normal","jam":true,"used":false}
	jam.bakery_ability.on_hit(ball,jam.pegs[0]);jam.bakery_ability.on_hit(ball,jam.pegs[0])
	check(jam.heard.count("jam_splash")==1,"Spent Jam ball cannot replay its splash sound")
	jam.free()
	var prism=fixture("crystal");prism.start_shift();prism.run_transition.finish();prism.spawn_ball(Vector2(360,400),"normal",Vector2(0,360),false);prism.clear_heard()
	prism.run_elapsed=3;prism.crystal_launcher.advance(0);prism.crystal_launcher.advance(0)
	check(prism.heard==["pickup_appear"],"Prism offer announces its appearance once")
	prism.clear_heard();var point=prism.crystal_run.offer_position
	check(prism.crystal_launcher.try_collect(point),"Live Prism can be collected")
	prism.crystal_launcher.try_collect(point)
	check(prism.heard==["prism"],"Consumed Prism duplicates and chimes only once")
	prism.free()

func unchanged_simulation():
	for area in Campaign.IDS:
		var loud=fixture(area);var silent=fixture(area);silent.sound_on=false
		loud.start_shift();silent.start_shift();loud.run_transition.finish();silent.run_transition.finish()
		for index in range(1800): loud.step(1.0/60.0);silent.step(1.0/60.0)
		check(loud.rng.state==silent.rng.state,area+" audio consumes no extra gameplay RNG over a real run")
		check(loud.pegs==silent.pegs and loud.balls==silent.balls,area+" muted and audible runs retain identical physics")
		check(loud.shift_coins==silent.shift_coins and loud.destroyed==silent.destroyed and loud.remaining==silent.remaining,area+" audio does not alter rewards or timers")
		loud.free();silent.free()

func restored_silence():
	var g=fixture();g.start_shift();g.spawn_ball(Vector2(360,267),"normal");var saved=Snapshot.capture(g)
	g.clear_heard()
	check(g.restore_active_run(saved),"Existing ordinary checkpoint remains valid with audio integration")
	check(g.heard.is_empty(),"Restoring a checkpoint does not replay launch, result or pause cues")
	g.startup_blocked=true;g.feedback("upgrade")
	check(g.heard.is_empty(),"Loading hold suppresses gameplay cues beneath the studio")
	g.free()

func _initialize(): call_deferred("run")
func run():
	menus();run_and_lifecycle();upgrades_and_offers();mechanics();unchanged_simulation();restored_silence()
	print("AUDIO_FEEDBACK_INTEGRATION_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
