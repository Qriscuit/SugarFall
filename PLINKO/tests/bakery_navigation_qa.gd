extends SceneTree
## In-memory navigation checks. Production _ready and player profiles are bypassed.
var passed = 0
var failures: Array[String] = []
var g
var home
var journey

class NavigationGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
	var fixture_content_ready = true
	func _ready(): pass
	func save_game(): persistence_attempts += 1
	func load_game(): persistence_attempts += 1
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts += 1
		return false
	func area_content_ready(_id: String) -> bool: return fixture_content_ready

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func touch(p: Vector2, index: int, pressed: bool, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = g.to_global(p)
	event.pressed = pressed
	event.canceled = canceled
	g._input(event)

func motion(a: Vector2, b: Vector2, index: int):
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = g.to_global(b)
	event.relative = g.to_global(b)-g.to_global(a)
	g._input(event)

func tap(p: Vector2, index: int = 7):
	touch(p,index,true)
	touch(p,index,false)

func swipe(a: Vector2, b: Vector2, index: int = 7):
	touch(a,index,true)
	motion(a,b,index)
	touch(b,index,false)

func wheel(p: Vector2, up: bool):
	var event = InputEventMouseButton.new()
	event.position = g.to_global(p)
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	g._input(event)

func fresh(level: int = 4, unlocked: int = 8):
	g.run_transition.finish()
	g.set_active_area("bakery")
	g.area_records = {"bakery":g.AreaCampaign.default_record()}
	g.area_entries = []
	g.fixture_content_ready = true
	g.mode = "home"
	g.run_id = ""
	g.shift_claimed = true
	g.navigation_delay = 0
	g.result_input_delay = 0
	g.note = ""
	g.note_time = 0
	g.current_level = level
	g.highest_unlocked = unlocked
	g.bank = 1234.55
	g.levels = [2,1,1,1,1,1,2,1]
	g.equipped = ["splitter","impact"]
	g.trial_active = false
	g.chapter_complete = false
	g.reduced_motion = false
	g.position = Vector2.ZERO
	g.scale = Vector2.ONE
	home.reset()
	journey.reset()

func open_journey(level: int = 4, unlocked: int = 8):
	fresh(level,unlocked)
	tap(home.LEVEL_RECT.get_center())
	g.navigation_delay = 0

func home_routes():
	fresh()
	var play = home.PLAY_RECT.get_center()
	touch(play,19,true)
	check(g.mode=="home","Home Play waits for a completed tap")
	touch(play,19,false)
	check(g.mode=="play" and g.current_level==4,"Home Play starts the selected level directly")
	check(g.pegs.size()==int(g.board_data[3].peg_count),"Home Play uses the selected authored tray")
	check(g.monetization.pending.is_empty(),"Opening a run does not display an ad")
	fresh()
	tap(home.UPGRADES_RECT.get_center())
	check(g.mode=="shop" and g.return_mode=="home","Home Upgrades opens Recipe Trails")
	fresh()
	tap(home.LEVEL_RECT.get_center())
	check(g.mode=="boards" and g.current_level==4,"The level plaque opens the level journey without starting a run")
	check(journey.point(4).y>350 and journey.point(4).y<850,"Opening the journey puts the current level in the usable center")
	fresh()
	tap(home.MENU_RECT.get_center())
	check(home.menu_open and g.mode=="home","The compact home menu opens in place")
	tap(play)
	check(not home.menu_open and g.mode=="home","Tapping Play behind the menu only dismisses the menu")
	tap(home.MENU_RECT.get_center())
	g.go_back()
	check(not home.menu_open and g.mode=="home","Back closes the home menu before leaving the page")
	for route in [[home.SETTINGS_RECT,"support"],[home.HELP_RECT,"guide"],[home.TRIALS_RECT,"trials"]]:
		fresh()
		tap(home.MENU_RECT.get_center())
		tap(route[0].get_center())
		check(g.mode==route[1] and not home.menu_open,"Home menu route remains reachable: "+route[1])

func home_touch_safety():
	fresh()
	var play = home.PLAY_RECT.get_center()
	touch(play,31,true); touch(play,31,false,true)
	check(g.mode=="home","A canceled home Play touch never starts a run")
	swipe(play,play+Vector2(0,-90),17)
	check(g.mode=="home","Dragging off Home Play never starts a run")
	touch(play,17,true); motion(play,play+Vector2(40,0),17); motion(play+Vector2(40,0),play,17); touch(play,17,false)
	check(g.mode=="home","A drag that returns to Home Play is still not a tap")
	touch(play,17,true); touch(Vector2(400,550),42,true); touch(Vector2(400,550),42,false); touch(play,17,false)
	check(g.mode=="home","A second finger cancels the pending Home Play action")
	touch(play,17,true)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch(play,17,false)
	check(g.mode=="home","Focus loss cancels a pending Home Play action")
	touch(play,17,true)
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	touch(play,17,false)
	check(g.mode=="home","Application pause cancels a pending Home Play action")
	g.navigation_delay=.25
	tap(play)
	check(g.mode=="home","Home Play respects the page transition guard")
	g.navigation_delay=0
	touch(play,8,true); motion(play,play+Vector2(3,3),8); touch(play+Vector2(3,3),8,false)
	check(g.mode=="play","Normal finger jitter still activates Home Play")
	fresh()
	g.position=Vector2(24,52); g.scale=Vector2(.9,.9)
	tap(home.LEVEL_RECT.get_center(),24)
	check(g.mode=="boards","Home controls use the safe-area canvas transform")

func tray_tap_safety():
	fresh()
	var tray = home.TRAY_RECT.get_center()
	var serial = g.run_serial
	touch(tray,12,true)
	check(g.mode=="home" and g.run_serial==serial,"The tray waits for a completed tap before starting")
	touch(tray,12,false)
	check(g.mode=="play" and g.run_transition.active and g.run_serial==serial+1,"Tapping the tray starts the same single entrance transition as Play")
	check(g.pegs.size()==int(g.board_data[3].peg_count) and g.balls.is_empty(),"Tray launch initializes the selected board before any donuts spawn")
	fresh()
	touch(tray,12,true); touch(tray,12,false,true)
	check(g.mode=="home","A canceled tray tap does not start a run")
	swipe(tray,tray+Vector2(75,0),12)
	check(g.mode=="home","Swiping within the tray does not start a run")
	touch(tray,12,true); motion(tray,tray+Vector2(40,0),12); motion(tray+Vector2(40,0),tray,12); touch(tray,12,false)
	check(g.mode=="home","A tray drag that returns to its starting point is still not a tap")
	touch(tray,12,true); touch(tray+Vector2(80,0),22,true); touch(tray+Vector2(80,0),22,false); touch(tray,12,false)
	check(g.mode=="home","A two-finger tray gesture cannot start a run")
	touch(tray,12,true)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch(tray,12,false)
	check(g.mode=="home","Focus loss cancels a pending tray tap")
	tap(home.MENU_RECT.get_center())
	tap(tray)
	check(g.mode=="home" and not home.menu_open,"A tray tap behind the menu only dismisses the overlay")
	g.navigation_delay=.25
	tap(tray)
	check(g.mode=="home","A tray tap respects the navigation debounce")
	g.navigation_delay=0
	tap(Vector2(20,tray.y))
	tap(home.WALLET_RECT.get_center())
	check(g.mode=="home","Wallet and empty space outside the tray do not start a run")
	g.position=Vector2(24,52); g.scale=Vector2(.9,.9)
	touch(tray,12,true); motion(tray,tray+Vector2(3,3),12); touch(tray+Vector2(3,3),12,false)
	check(g.mode=="play" and g.run_transition.active,"Tray taps support finger jitter and the safe-area canvas transform")

func collection_returns_home():
	fresh(4,4)
	g.start_shift()
	g.remaining=0
	g.shift_coins=12.5
	var wallet = g.bank
	var attempts = g.monetization.attempts
	g.finish_shift(false)
	check(g.mode=="result" and not g.shift_claimed and g.bank==wallet,"A finished attempt still offers its unclaimed result")
	check(g.monetization.attempts==attempts+1,"Completed attempts still count toward the automatic ad cadence")
	g.collect_reward()
	check(g.mode=="home" and g.bank==wallet+12.5 and g.current_level==4,"Collecting an unfinished level returns Home with the payout and the same selected level")
	check(not home.menu_open and home.touches.is_empty(),"Collection returns to a clean Home interaction state")
	g.collect_reward()
	check(g.bank==wallet+12.5,"Returning Home cannot duplicate a collected payout")
	fresh(2,2)
	g.levels=[0,0,0,0,0,0,0,0]
	g.equipped=[]
	g.module_milestones=[]
	g.module_vouchers=0
	g.start_shift()
	g.level_won=true
	g.finish_shift(false)
	g.collect_reward()
	check(g.mode=="home" and g.current_level==3 and g.highest_unlocked==3,"Clearing a level returns Home with the next level selected and unlocked")
	check(g.module_vouchers==1 and 2 in g.module_milestones and g.levels[3]==0,"Milestone treats stay available without forcing open the upgrades or treats page")
	fresh(12,12)
	g.start_shift()
	g.level_won=true
	g.finish_shift(false)
	g.collect_reward()
	check(g.mode=="home" and g.current_level==12 and g.chapter_complete,"Clearing level 12 returns Home and preserves the existing chapter-complete behavior")
	fresh()
	g.start_shift()
	g.remaining=0
	g.finish_shift(false)
	g.result_input_delay=0
	var serial = g.run_serial
	var collect = Vector2(360,848)
	touch(collect,0,true)
	check(g.mode=="home" and g.navigation_delay>0,"The Collect action opens Home with the navigation guard active")
	touch(collect,0,false)
	check(g.mode=="home" and g.run_serial==serial,"Releasing Collect over the Home tray cannot start another attempt")
	tap(collect,0)
	check(g.mode=="home" and g.run_serial==serial,"A rapid repeated Collect tap cannot start the newly revealed tray")
	g._process(.3)
	tap(collect,0)
	check(g.mode=="play" and g.run_serial==serial+1 and g.run_transition.active,"A later deliberate tray tap starts the next attempt from Home")

func preview_matches_play():
	for level in [1,4,12]:
		fresh(level,12)
		g.start_shift()
		var before = g.RunSnapshot.capture(g).duplicate(true)
		var preview: Array = home.preview_pegs()
		var matches = preview.size()==g.pegs.size()
		for i in range(mini(preview.size(),g.pegs.size())):
			matches = matches and preview[i].p==g.pegs[i].p and preview[i].kind==g.pegs[i].kind
		check(matches,"Home tray preview matches actual level %d peg positions and roles" % level)
		check(not before.is_empty() and JSON.stringify(before)==JSON.stringify(g.RunSnapshot.capture(g)),"Preparing the level %d preview does not change the live run" % level)

func journey_selection():
	open_journey()
	var wallet = g.bank
	var upgrades = g.levels.duplicate()
	var serial = g.run_serial
	tap(journey.point(3),22)
	check(g.mode=="boards" and g.current_level==3,"Tapping an available level selects it while staying on the journey")
	check(g.bank==wallet and g.levels==upgrades and g.run_serial==serial,"Level selection preserves money and upgrades without starting an attempt")
	check(journey.state_for(3)=="selected" and journey.state_for(2)=="completed" and journey.state_for(9)=="locked","Journey state distinguishes selected, completed and locked levels")
	journey.scroll=journey.world_point(8).y-journey.TITLE_RECT.get_center().y
	tap(journey.point(8))
	check(g.current_level==3 and journey.area_menu_open,"The fixed title opens the area picker instead of selecting the level behind it")
	journey.close_overlay()
	g.navigation_delay=0
	journey.scroll=journey.world_point(9).y-632
	tap(journey.point(9))
	check(g.current_level==3 and g.mode=="boards","A visible locked level cannot be selected or started")
	journey.scroll=journey.world_point(8).y-632
	tap(journey.point(8))
	check(g.current_level==8,"The highest unlocked level is selectable")
	g.navigation_delay=0
	tap(journey.PLAY_RECT.get_center())
	check(g.mode=="play" and g.current_level==8 and g.pegs.size()==int(g.board_data[7].peg_count),"Journey Play starts the chosen authored level directly")
	open_journey(12,12)
	check(journey.point(12).y>350 and journey.point(12).y<850,"The last level opens in the usable center")
	g.current_level=1
	journey.open()
	check(journey.point(1).y>350 and journey.point(1).y<850,"Reopening centers the newly current level instead of stale scroll")
	tap(journey.BACK_RECT.get_center())
	check(g.mode=="home" and g.current_level==1,"Journey Back returns to the home tray with the selected level")

func journey_gestures():
	open_journey()
	var start = Vector2(80,600)
	var old_scroll: float = journey.scroll
	swipe(start,start+Vector2(0,200),31)
	check(journey.scroll<old_scroll and g.current_level==4,"A downward drag reveals higher levels without selecting a node")
	old_scroll=journey.scroll
	wheel(Vector2(360,600),true)
	check(journey.scroll<old_scroll,"Wheel up reveals higher levels")
	old_scroll=journey.scroll
	wheel(Vector2(360,600),false)
	check(journey.scroll>old_scroll,"Wheel down returns toward lower levels")
	old_scroll=journey.scroll
	wheel(journey.PLAY_RECT.get_center(),true)
	wheel(journey.TITLE_RECT.get_center(),true)
	check(journey.scroll==old_scroll,"Wheel input over fixed journey controls does not scroll beneath them")
	for i in range(60): wheel(Vector2(360,600),true)
	var bounds: Vector2 = journey.scroll_bounds()
	check(is_equal_approx(journey.scroll,bounds.x),"Scrolling toward the last level stops at the content bound")
	for i in range(60): wheel(Vector2(360,600),false)
	check(is_equal_approx(journey.scroll,bounds.y),"Scrolling toward the first level stops at the content bound")
	open_journey()
	var selected: Vector2 = journey.point(4)
	swipe(selected,selected+Vector2(0,160),7)
	check(g.current_level==4,"Dragging from a level tile cannot select another tile on release")
	open_journey()
	var before: float = journey.scroll
	touch(journey.PLAY_RECT.get_center(),17,true)
	motion(journey.PLAY_RECT.get_center(),Vector2(360,600),17)
	touch(Vector2(360,600),17,false)
	check(g.mode=="boards" and journey.scroll==before,"Dragging from the Play overlay neither scrolls the map nor starts a run")
	touch(journey.PLAY_RECT.get_center(),17,true)
	touch(journey.PLAY_RECT.get_center(),17,false,true)
	check(g.mode=="boards","A canceled journey Play touch does not start a run")
	touch(start,17,true)
	touch(journey.PLAY_RECT.get_center(),42,true)
	touch(journey.PLAY_RECT.get_center(),42,false)
	touch(start,17,false)
	check(g.mode=="boards","A second finger over journey Play cannot start a run during map interaction")
	open_journey()
	touch(start,17,true)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	motion(start,start+Vector2(0,120),17); touch(start+Vector2(0,120),17,false)
	check(journey.touch_points.is_empty() and is_equal_approx(journey.scroll,journey.world_point(4).y-632),"Focus loss cancels journey gesture state and ignores its later movement")
	touch(start,17,true)
	g.navigation_delay=0
	g.go_back()
	motion(start,start+Vector2(0,120),17); touch(start+Vector2(0,120),17,false)
	check(g.mode=="home" and journey.touch_points.is_empty(),"Leaving the journey cancels gesture ownership")
	open_journey()
	g.position=Vector2(20,44); g.scale=Vector2(.88,.88)
	tap(journey.point(3),29)
	check(g.current_level==3,"Journey selection follows the safe-area canvas transform")
	old_scroll=journey.scroll
	wheel(Vector2(360,600),true)
	check(journey.scroll<old_scroll,"Journey wheel input follows the safe-area canvas transform")
	open_journey()
	touch(Vector2(80,600),17,true)
	home.menu_open=true
	g.reset_profile_runtime()
	check(not home.menu_open and home.touches.is_empty() and journey.touch_points.is_empty() and journey.tap_feedback.is_empty(),"Profile runtime reset clears home menu and journey interaction state")

func next_area_gate():
	open_journey(12,12)
	g.bank=0
	var gate = journey.area_gate_requirements()
	check(gate.cost==1000 and not gate.cleared and not gate.funded,"Next area displays its 1000-coin and twelve-tray requirements")
	check(gate.content_ready and not gate.can_enter,"Ready content still requires a completed and funded Bakery")
	tap(journey.area_gate_rect().get_center())
	check(not journey.entry_open,"An uncleared Bakery cannot open first-entry confirmation")
	g.chapter_complete=true
	g.bank=gate.cost-0.01
	check(not journey.area_gate_requirements().funded,"Next-area funding uses the exact wallet, not rounded display text")
	tap(journey.area_gate_rect().get_center())
	check(not journey.entry_open,"An underfunded Bakery cannot open first-entry confirmation")
	g.bank=gate.cost
	g.fixture_content_ready=false
	gate=journey.area_gate_requirements()
	check(gate.funded and gate.cleared and not gate.content_ready and not gate.can_enter,"Meeting both requirements still waits for actual area content")
	var upgrades=g.levels.duplicate()
	var serial=g.run_serial
	tap(journey.area_gate_rect().get_center())
	check(g.mode=="boards" and g.bank==gate.cost and g.levels==upgrades and g.run_serial==serial and g.chapter_complete,"Tapping the locked gate never charges, resets upgrades, or starts a run")
	g.fixture_content_ready=true
	tap(journey.area_gate_rect().get_center())
	check(journey.entry_open and g.mode=="boards" and g.bank==gate.cost and g.levels==upgrades,"The ready gate opens consequence disclosure without spending coins or resetting upgrades")
	g.navigation_delay=0
	tap(journey.ENTRY_CANCEL_RECT.get_center())
	check(not journey.entry_open and g.bank==gate.cost and g.levels==upgrades and g.run_serial==serial,"Canceling area entry leaves the entire Bakery progression untouched")
	check(journey.area_gate_rect().end.y<journey.point(12).y-journey.NODE_SIZE.y*.5,"Next-area gate does not cover the twelfth level")
	g.navigation_delay=0
	tap(journey.PLAY_RECT.get_center())
	check(g.mode=="play" and g.current_level==12,"A completed Bakery remains replayable after declining new-area entry")

func _initialize():
	g=NavigationGame.new()
	g.testing=true
	g.sound_on=false
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	home=g.home_menu
	journey=g.level_map
	home_routes()
	home_touch_safety()
	tray_tap_safety()
	collection_returns_home()
	preview_matches_play()
	journey_selection()
	journey_gestures()
	next_area_gate()
	check(g.persistence_attempts==0,"Navigation fixtures never read or write a player profile")
	g.free()
	print("BAKERY_NAV_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
