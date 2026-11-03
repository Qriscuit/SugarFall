extends SceneTree
## UI and actual area transactions. All profile reads/writes are intercepted.
const SETTINGS_RECT = Rect2(48,662,624,72)
var passed = 0
var failures: Array[String] = []
var g
var ui

class FixtureGame extends "res://scripts/main.gd":
	var tools_allowed = true
	var blocked_content = ""
	var fail_write = false
	var writes = 0
	var profile_reads = 0
	var unexpected_saves = 0
	var candidate: Dictionary = {}
	var area_at_write = ""
	var bank_at_write = 0.0
	var drawn_buttons: Array = []
	var drawn_text: Array = []
	func _ready(): pass
	func load_game(): profile_reads += 1
	func save_game():
		unexpected_saves += 1
		return false
	func write_profile_file(data: Dictionary) -> bool:
		writes += 1
		candidate = data.duplicate(true)
		area_at_write = area_id
		bank_at_write = bank
		return not fail_write
	func developer_tools_available() -> bool: return tools_allowed
	func area_content_ready(id: String) -> bool:
		return id!=blocked_content and super.area_content_ready(id)
	func heading(value, _pos, _size=40, _color=Color.WHITE): drawn_text.append(str(value))
	func centered(value, _y, _size=24, _color=Color.WHITE): drawn_text.append(str(value))
	func text_at(value, _pos, _size=24, _color=Color.WHITE): drawn_text.append(str(value))
	func fitted_text(value, _rect: Rect2, _size=24, _color=Color.WHITE, _center=false): drawn_text.append(str(value))
	func ui_panel(_rect: Rect2): pass
	func button(rect, label, primary=false, _subtitle=""):
		drawn_buttons.append({"rect":rect,"label":label,"primary":primary})

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fresh():
	g.set_active_area("bakery")
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.mode = "developer_areas"
	g.testing = true
	g.tools_allowed = true
	g.blocked_content = ""
	g.fail_write = false
	g.writes = 0
	g.candidate = {}
	g.trial_active = false
	g.trial_snapshot = {}
	g.area_transaction_pending = false
	g.profile_load_blocked = false
	g.monetization.pending = {}
	g.run_id = ""
	g.shift_claimed = true
	g.run_transition.finish()
	g.navigation_delay = 0
	g.result_input_delay = 0
	g.first_run_guide.active = false
	g.first_run_guide.completed = true
	g.bank = 123.5
	g.levels = [1,2,1,0,0,0,0,1]
	g.current_level = 3
	g.highest_unlocked = 3
	g.best_wave = 3
	g.chapter_complete = false
	g.twin_launchers = false
	g.power_reset_tier = 0
	g.equipped = []
	g.trial_records = {}
	g.module_vouchers = 0
	g.module_milestones = []
	g.area_entries = []
	g.area_records = {"bakery":g.AreaCampaign.capture_local(g)}
	g.developer_free_purchases = {}
	g.drawn_buttons = []
	g.drawn_text = []
	ui.cancel_gestures()

func touch(point: Vector2, pressed: bool, index: int=0, canceled: bool=false):
	var event = InputEventScreenTouch.new()
	event.position = g.to_global(point)
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	g._input(event)

func move_touch(point: Vector2, index: int=0):
	var event = InputEventScreenDrag.new()
	event.position = g.to_global(point)
	event.index = index
	g._input(event)

func tap(point: Vector2):
	touch(point,true)
	touch(point,false)

func key(code: Key, echo: bool=false):
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.echo = echo
	g._input(event)

func button_named(label: String) -> Dictionary:
	for button in g.drawn_buttons:
		if button.label==label: return button
	return {}

func entry_and_copy_checks():
	fresh()
	g.mode = "support"
	g.draw_support()
	check(button_named("Developer settings").get("rect")==SETTINGS_RECT,"Debug Settings draws the developer settings entry in its reserved gap")
	check(not SETTINGS_RECT.intersects(Rect2(48,520,624,96)) and not SETTINGS_RECT.intersects(Rect2(48,760,624,96)),"Developer entry does not overlap Reset or Performance controls")
	g.handle_press(SETTINGS_RECT.get_center())
	check(g.mode=="developer_areas" and g.navigation_delay>0 and g.writes==0,"Settings entry opens area selection with a navigation guard and no write")
	touch(ui.area_button_rect("gelato").get_center(),false)
	check(g.area_id=="bakery" and g.writes==0,"Opener release cannot activate an area")
	g.navigation_delay = 0
	ui.draw()
	check(ui.area_action("bakery")=="Current" and ui.area_action("gelato")=="Start fresh","Current and first-visit area actions are explicit")
	check(ui.area_detail("bakery").contains("Tray 3") and ui.area_detail("bakery").contains(g.credits_text(123.5)),"Current area summary reads live progress")
	check(ui.area_detail("gelato")=="Tray 1 · 0 coins · no upgrades","First visit states its empty wallet and upgrades")
	check(not button_named("Current").get("primary",true),"Current area is drawn without an active action highlight")
	var all_fit = true
	for index in range(ui.AREAS.size()):
		all_fit = all_fit and ui.CARD_RECTS[index].encloses(ui.area_button_rect(ui.AREAS[index])) and not ui.CARD_RECTS[index].intersects(ui.BACK_RECT) and not ui.CARD_RECTS[index].intersects(ui.MONEY_RECT)
		for other in range(index+1,ui.AREAS.size()): all_fit=all_fit and not ui.CARD_RECTS[index].intersects(ui.CARD_RECTS[other])
	check(all_fit and ui.AREAS==["bakery","gelato","crystal"],"All three area actions fit separate cards above the money control and Back")
	check(not ui.MONEY_RECT.intersects(ui.BACK_RECT),"Infinite-money control has its own space below the area cards")
	check(button_named("Infinite money · Off").get("rect")==ui.MONEY_RECT,"Developer page exposes the current area's default-off testing toggle")
	fresh()
	g.tools_allowed = false
	g.mode = "support"
	g.draw_support()
	check(button_named("Developer settings").is_empty(),"Settings hides the entry when developer tools are unavailable")
	g.handle_press(SETTINGS_RECT.get_center())
	check(g.mode=="support" and not g.open_developer_areas(),"Hidden developer entry cannot be activated by coordinates or API")
	g.mode = "developer_areas"
	g.drawn_buttons.clear()
	ui.draw()
	check(g.drawn_buttons.size()==1 and g.drawn_buttons[0].label=="Back","A stale developer screen exposes only Back when disabled")

func gesture_checks():
	fresh()
	var target: Vector2 = ui.area_button_rect("gelato").get_center()
	touch(target,true,7)
	check(g.writes==0 and g.area_id=="bakery","Area change waits for touch release")
	move_touch(target+Vector2(40,0),7)
	touch(target+Vector2(40,0),false,7)
	check(g.writes==0,"Dragging an area button cancels selection")
	touch(target,true,7)
	touch(target+Vector2(50,0),true,8)
	touch(target,false,7)
	touch(target+Vector2(50,0),false,8)
	check(g.writes==0 and ui._touches.is_empty(),"Multitouch cancels the entire area gesture")
	touch(target,true)
	touch(target,false,0,true)
	check(g.writes==0,"Canceled touch cannot switch areas")
	touch(target,false)
	check(g.writes==0,"Unmatched release cannot switch areas")
	touch(target,true)
	g.navigation_delay = .25
	touch(target,false)
	check(g.writes==0,"Release rechecks the navigation guard")
	g.navigation_delay = 0
	touch(target,true)
	g.profile_load_blocked = true
	touch(target,false)
	check(g.writes==0,"Release rechecks transaction eligibility")
	g.profile_load_blocked = false
	key(KEY_ENTER)
	key(KEY_SPACE)
	check(g.writes==0,"Enter and Space never select an area implicitly")
	touch(target,true,9)
	ui.cancel_gestures()
	touch(target,false,9)
	check(g.writes==0,"Focus loss cancellation disarms a pending area tap")
	tap(ui.area_button_rect("bakery").get_center())
	check(g.writes==0 and g.bank==123.5,"Current area button cannot recreate or reset its progress")
	key(KEY_ESCAPE,true)
	check(g.mode=="developer_areas","Repeated Escape does not navigate twice")
	key(KEY_ESCAPE)
	check(g.mode=="support" and g.navigation_delay>0,"Escape returns to Settings with a navigation guard")
	fresh()
	g.tools_allowed = false
	tap(ui.BACK_RECT.get_center())
	check(g.mode=="support","Back remains available on a disabled developer screen")

func money_gesture_checks():
	fresh()
	var target: Vector2 = ui.MONEY_RECT.get_center()
	touch(target,true)
	check(not g.developer_money_enabled(),"Infinite money waits for touch release")
	touch(target,false)
	check(g.developer_money_enabled() and g.bank==123.5 and g.writes==0,"A valid money-toggle tap enables free purchases without changing or saving the wallet")
	touch(target,false)
	check(g.developer_money_enabled(),"An unmatched release cannot toggle infinite money again")
	touch(target,true)
	move_touch(target+Vector2(40,0))
	touch(target+Vector2(40,0),false)
	check(g.developer_money_enabled(),"Dragging across the money switch cancels its action")
	touch(target,true)
	touch(target,false,0,true)
	check(g.developer_money_enabled(),"Canceled release leaves the testing switch unchanged")
	touch(target,true,3)
	touch(target+Vector2(20,0),true,4)
	touch(target,false,3)
	touch(target+Vector2(20,0),false,4)
	check(g.developer_money_enabled(),"Multiple fingers cannot toggle infinite money")
	touch(target,true)
	g.profile_load_blocked = true
	touch(target,false)
	check(g.developer_free_purchases.get("bakery",false),"Money-toggle release rechecks profile safety")
	g.profile_load_blocked = false
	tap(target)
	check(not g.developer_money_enabled() and g.bank==123.5,"A second deliberate tap restores ordinary spending and retains the exact wallet")
	g.tools_allowed = false
	tap(target)
	check(not g.developer_money_enabled() and not g.developer_free_purchases.get("bakery",false),"A stale hidden screen cannot enable free purchases in a normal release")

func transaction_checks():
	fresh()
	var before: Dictionary = g.AreaCampaign.capture_local(g)
	tap(ui.area_button_rect("gelato").get_center())
	check(g.writes==1 and g.area_at_write=="bakery" and g.bank_at_write==123.5,"Area transaction is committed before live area and wallet change")
	check(g.area_id=="gelato" and g.mode=="home" and g.current_level==1 and g.highest_unlocked==1,"First developer visit opens the target home at tray 1")
	check(g.bank==0 and g.levels==[0,0,0,0,0,0,0,0] and not g.twin_launchers,"Fresh Gelato receives no coins, upgrades or Twin launchers")
	check(g.area_records.bakery==before and g.area_entries.is_empty(),"Developer entry preserves Bakery and adds no paid-entry record")
	check(g.AreaCampaign.decode_profile(g.candidate).ok and g.candidate.active_area_id=="gelato","Committed candidate is a valid profile containing the new area")
	g.bank = 88.25
	g.levels = [1,1,1,0,0,0,0,1]
	g.gelato_shop_revision=0
	check(g.ensure_gelato_shop_state(),"The developer revisit fixture creates matching exact Gelato node ownership")
	g.current_level = 2
	g.highest_unlocked = 2
	g.mode = "developer_areas"
	g.navigation_delay = 0
	check(ui.area_action("bakery")=="Continue","Previously visited area offers Continue instead of Start fresh")
	tap(ui.area_button_rect("bakery").get_center())
	check(g.area_id=="bakery" and g.bank==before.bank and g.levels==before.levels and g.current_level==before.current_level,"Returning to Bakery restores its exact wallet, upgrades and selected tray")
	g.mode = "developer_areas"
	g.navigation_delay = 0
	check(ui.area_action("gelato")=="Continue" and ui.area_detail("gelato").contains(g.credits_text(88.25)),"Returning Gelato summary describes the saved area progress")
	tap(ui.area_button_rect("gelato").get_center())
	check(g.area_id=="gelato" and g.bank==88.25 and g.levels[1]==1 and g.current_level==2,"Repeat Gelato visit resumes progress instead of resetting it")
	fresh()
	g.fail_write = true
	before = g.AreaCampaign.capture_local(g)
	tap(ui.area_button_rect("gelato").get_center())
	check(g.writes==1 and g.mode=="developer_areas" and g.area_id=="bakery" and g.AreaCampaign.capture_local(g)==before and not g.area_records.has("gelato"),"Failed write leaves the source area, progress and selection intact")

func guard_checks():
	for blocker in ["tools","trial","transition","pending_run","transaction","profile","onboarding","commerce","content"]:
		fresh()
		match blocker:
			"tools": g.tools_allowed = false
			"trial": g.trial_active = true
			"transition": g.run_transition.active = true
			"pending_run": g.run_id = "pending"; g.shift_claimed = false
			"transaction": g.area_transaction_pending = true
			"profile": g.profile_load_blocked = true
			"onboarding": g.first_run_guide.active = true
			"commerce": g.monetization.pending = {"id":"pending"}
			"content": g.blocked_content = "gelato"
		ui.press(ui.area_button_rect("gelato").get_center())
		check(g.writes==0 and not g.developer_switch_area("gelato") and g.area_id=="bakery","Area switch rejects %s guard at UI and transaction layers" % blocker)
	fresh()
	check(not g.developer_switch_area("unknown") and not g.developer_switch_area("bakery") and g.writes==0,"Unknown or current area IDs cannot create a transaction")
	g.mode = "play"
	check(not g.developer_switch_area("gelato") and not g.open_developer_areas(),"Playing cannot open or use developer area navigation")
	check(g.profile_reads==0 and g.unexpected_saves==0,"Fixture never accesses real profiles or generic save paths")

func _initialize():
	g = FixtureGame.new()
	g.sound_on = false
	ui = g.developer_area_ui
	entry_and_copy_checks()
	gesture_checks()
	money_gesture_checks()
	transaction_checks()
	guard_checks()
	g.free()
	print("DEVELOPER_AREA_UI_QA_RESULT passed=",passed," failed=",failures.size()," details=",failures)
	quit(0 if failures.is_empty() else 1)
