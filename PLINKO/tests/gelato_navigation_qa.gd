extends SceneTree
## Real navigation and area commits with all persistence replaced by memory.
var passed = 0
var failures: Array[String] = []
var g
var journey

class FixtureGame extends "res://scripts/main.gd":
	var writes: Array = []
	var allow_write = true
	var content_ready = true
	var profile_reads = 0
	func _ready(): pass
	func load_game(): profile_reads += 1
	func save_game(): return true
	func write_profile_file(data: Dictionary) -> bool:
		writes.append(data.duplicate(true))
		return allow_write
	func area_content_ready(id: String) -> bool:
		return content_ready and not area_boards(id).is_empty()

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func touch(p: Vector2, pressed: bool, index: int = 7, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.position = g.to_global(p)
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	g._input(event)

func tap(p: Vector2):
	touch(p,true)
	touch(p,false)

func motion(a: Vector2, b: Vector2):
	var event = InputEventScreenDrag.new()
	event.position = g.to_global(b)
	event.relative = g.to_global(b)-g.to_global(a)
	event.index = 7
	g._input(event)

func wheel(p: Vector2):
	var event = InputEventMouseButton.new()
	event.position = g.to_global(p)
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	g._input(event)

func unlock_input():
	g.navigation_delay = 0
	g.result_input_delay = 0

func fresh():
	g.run_transition.finish()
	g.set_active_area("bakery")
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.bank = 450000
	g.current_level = 12
	g.highest_unlocked = 12
	g.chapter_complete = true
	g.levels = [4,3,2,1,2,1,3,2]
	g.equipped = ["splitter","impact"]
	g.module_vouchers = 1
	g.module_milestones = [2,5]
	g.run_id = ""
	g.shift_claimed = true
	g.trial_active = false
	g.mode = "boards"
	g.return_mode = "home"
	g.position = Vector2.ZERO
	g.scale = Vector2.ONE
	g.note_time = 0
	g.profile_load_blocked = false
	g.area_transaction_pending = false
	g.content_ready = true
	g.allow_write = true
	g.area_records = {"bakery":g.AreaCampaign.capture_local(g)}
	g.area_entries = []
	g.writes = []
	g.monetization.pending = {}
	g.home_menu.reset()
	journey.reset()
	journey.open()
	unlock_input()

func confirmation():
	fresh()
	var before = g.AreaCampaign.capture_local(g)
	var serial = g.run_serial
	tap(journey.area_gate_rect().get_center())
	check(journey.entry_open and g.writes.is_empty() and g.AreaCampaign.capture_local(g)==before,"Opening entry never spends or mutates the current area")
	unlock_input()
	var previous_scroll = journey.scroll
	wheel(Vector2(350,600))
	tap(journey.PLAY_RECT.get_center())
	check(journey.entry_open and journey.scroll==previous_scroll and g.run_serial==serial,"Entry consumes wheel and underlying Play input")
	tap(journey.ENTRY_CANCEL_RECT.get_center())
	check(not journey.entry_open and g.AreaCampaign.capture_local(g)==before and g.writes.is_empty(),"Cancel preserves all Bakery values and performs no commit")
	unlock_input()
	tap(journey.area_gate_rect().get_center())
	unlock_input()
	g.go_back()
	check(not journey.entry_open and g.mode=="boards","System Back closes entry without leaving the journey")
	unlock_input()
	tap(journey.area_gate_rect().get_center())
	unlock_input()
	g.bank = g.area_entry_status("gelato").cost-0.01
	tap(journey.ENTRY_ENTER_RECT.get_center())
	check(journey.entry_open and g.writes.is_empty() and g.area_id=="bakery","Enter rechecks affordability if the wallet changes under the confirmation")
	g.bank = 450000
	g.allow_write = false
	tap(journey.ENTRY_ENTER_RECT.get_center())
	check(journey.entry_open and g.area_id=="bakery" and g.bank==450000 and g.writes.size()==1,"A failed save keeps entry open and the Bakery wallet intact")
	g.allow_write = true
	var enter = journey.ENTRY_ENTER_RECT.get_center()
	touch(enter,true)
	check(g.area_id=="bakery" and g.writes.size()==1,"Holding Enter does not submit a purchase")
	touch(enter,false)
	check(g.area_id=="gelato" and g.mode=="home" and g.writes.size()==2,"One completed Enter tap commits Gelato and opens Home")
	check(g.bank==0 and g.levels==[0,0,0,0,0,0,0,0] and g.current_level==1 and g.highest_unlocked==1 and g.equipped.is_empty(),"Gelato Home starts with its own fresh first tray and upgrade state")
	check(g.area_records.bakery.bank==449000 and g.area_records.bakery.levels==before.levels and g.area_entries.size()==1,"The committed Bakery keeps its upgrade build and exact post-fee coins")
	check(g.run_serial==serial and g.balls.is_empty() and not g.run_transition.active and g.monetization.pending.is_empty(),"Entry neither starts food nor advances a run or opens an ad")
	tap(enter)
	check(g.mode=="home" and g.run_serial==serial and g.writes.size()==2,"A rapid repeated confirmation tap cannot start the newly revealed Home tray")

func entry_gestures():
	fresh()
	journey.open_entry()
	unlock_input()
	var enter = journey.ENTRY_ENTER_RECT.get_center()
	touch(enter,true); touch(enter,false,7,true)
	check(g.writes.is_empty() and journey.entry_open,"A canceled Enter tap does not commit")
	touch(enter,true); motion(enter,enter+Vector2(80,0)); motion(enter+Vector2(80,0),enter); touch(enter,false)
	check(g.writes.is_empty(),"Dragging away and back is not an Enter tap")
	touch(enter,true); touch(Vector2(100,600),true,23); touch(Vector2(100,600),false,23); touch(enter,false)
	check(g.writes.is_empty(),"A second finger cancels a pending entry")
	touch(enter,true); g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); touch(enter,false)
	check(g.writes.is_empty(),"Focus loss cancels a pending entry")
	touch(enter,true); g._notification(Node.NOTIFICATION_APPLICATION_PAUSED); touch(enter,false)
	check(g.writes.is_empty(),"Application pause cancels a pending entry")
	g.position=Vector2(24,52)
	g.scale=Vector2(.88,.88)
	touch(enter,true); motion(enter,enter+Vector2(3,3)); touch(enter+Vector2(3,3),false)
	check(g.area_id=="gelato" and g.writes.size()==1,"Enter accepts finger jitter with a transformed safe-area canvas")

func open_picker():
	g.mode = "boards"
	journey.open()
	unlock_input()
	tap(journey.TITLE_RECT.get_center())
	unlock_input()

func picker():
	fresh()
	open_picker()
	check(journey.area_menu_open and g.mode=="boards","The journey title opens an accessible area picker")
	var old_scroll = journey.scroll
	wheel(Vector2(360,600))
	tap(journey.PLAY_RECT.get_center())
	check(not journey.area_menu_open and g.mode=="boards" and g.writes.is_empty() and journey.scroll==old_scroll,"An outside picker tap dismisses it without using the covered Play control")
	unlock_input()
	open_picker()
	tap(journey.area_option_rect("bakery").get_center())
	check(not journey.area_menu_open and g.mode=="boards" and g.writes.is_empty(),"Selecting the current area only closes the picker")
	unlock_input()
	open_picker()
	g.go_back()
	check(not journey.area_menu_open and g.mode=="boards","System Back closes the area picker first")
	unlock_input()
	open_picker()
	g.bank=100
	tap(journey.area_option_rect("gelato").get_center())
	check(not journey.entry_open and not journey.area_menu_open and g.area_id=="bakery" and is_equal_approx(journey.scroll,journey.scroll_bounds().x),"A locked destination reveals its requirements without charging")
	g.bank=450000
	unlock_input()
	open_picker()
	tap(journey.area_option_rect("gelato").get_center())
	check(journey.entry_open and g.writes.is_empty(),"Choosing an eligible unowned area opens first-entry disclosure")
	unlock_input()
	tap(journey.ENTRY_ENTER_RECT.get_center())
	g.bank=137
	g.levels[0]=2
	g.gelato_shop_revision=0
	check(g.ensure_gelato_shop_state(),"The legacy-count revisit fixture creates matching exact Gelato node ownership")
	g.highest_unlocked=3
	g.current_level=2
	open_picker()
	tap(journey.area_option_rect("bakery").get_center())
	check(g.area_id=="bakery" and g.mode=="home" and g.bank==449000 and g.levels==[4,3,2,1,2,1,3,2],"Returning through the picker restores the completed Bakery wallet and upgrades")
	open_picker()
	tap(journey.area_option_rect("gelato").get_center())
	check(g.area_id=="gelato" and g.mode=="home" and g.bank==137 and g.levels[0]==2 and g.current_level==2 and g.area_entries.size()==1,"Returning to owned Gelato restores its local progress without another fee")
	g.current_level=12
	g.highest_unlocked=12
	g.chapter_complete=true
	g.mode="boards"
	journey.open()
	unlock_input()
	var writes = g.writes.size()
	tap(journey.area_gate_rect().get_center())
	check(journey.has_next_area() and not journey.entry_open and g.writes.size()==writes and g.area_id=="gelato" and journey.area_gate_requirements().cost==1500 and not journey.area_gate_requirements().funded,"Gelato offers the real Crystal gate but never charges an underfunded wallet")

func authored_boards():
	fresh()
	check(g.set_active_area("gelato") and g.board_data.size()==12,"The complete twelve-tray Gelato content is selectable")
	var previous_count = 0
	var layouts = {}
	for level in range(1,13):
		g.current_level=level
		g.highest_unlocked=12
		g.mode="home"
		g.start_shift()
		var spec = g.board_data[level-1]
		var valid = int(spec.peg_count)>previous_count and spec.positions.size()==int(spec.peg_count)
		var unique = JSON.stringify(spec.positions)
		valid = valid and not layouts.has(unique)
		layouts[unique] = true
		previous_count = int(spec.peg_count)
		for i in range(g.pegs.size()):
			var p: Vector2 = g.pegs[i].p
			valid = valid and Rect2(70,310,580,530).has_point(p)
			for j in range(i):
				valid = valid and p.distance_to(g.pegs[j].p)>=69
		check(valid,"Gelato tray %d has a distinct progressive layout with safe peg spacing" % level)
		var preview = g.home_menu.preview_pegs()
		var matches = preview.size()==g.pegs.size()
		for i in range(mini(preview.size(),g.pegs.size())):
			matches = matches and preview[i].p==g.pegs[i].p and preview[i].kind==g.pegs[i].kind
		check(matches,"Gelato tray %d Home preview matches its actual positions and roles" % level)
		g.run_transition.finish()
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.set_active_area("gelato")
	g.mode="home"
	var earned = 0.0
	for attempt in range(3):
		g.start_shift()
		g.run_transition.finish()
		for frame in range(1000):
			if g.mode!="play": break
			g.step(1.0/60)
		check(g.mode=="result" and g.shift_coins>0,"Fresh Gelato idle attempt %d earns coins without inherited upgrades" % (attempt+1))
		earned += g.shift_coins
		g.collect_reward(false)
	check(earned>=g.upgrade_cost(0),"A fresh Gelato player can fund the first Feed upgrade within three no-ad idle attempts")

func _initialize():
	g=FixtureGame.new()
	g.testing=true
	g.sound_on=false
	journey=g.level_map
	confirmation()
	entry_gestures()
	picker()
	authored_boards()
	check(g.profile_reads==0,"Gelato navigation fixtures never read a player profile")
	g.free()
	print("GELATO_NAV_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
