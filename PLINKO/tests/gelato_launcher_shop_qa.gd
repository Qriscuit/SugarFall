extends SceneTree
## Real shop input and purchase logic, with persistence isolated in memory.
const Graph = preload("res://scripts/upgrade_graph.gd")
var passed = 0
var failures: Array[String] = []
var g
var m

class FixtureGame extends "res://scripts/main.gd":
	var profile_calls = 0
	func _ready(): pass
	func load_game(): profile_calls += 1
	func save_game():
		profile_calls += 1
		return false
	func write_profile_file(_data: Dictionary) -> bool:
		profile_calls += 1
		return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func stage_legacy_counts():
	g.gelato_shop_revision=0 if g.area_id=="gelato" else 1
	g.gelato_owned_nodes=[]; g.gelato_reset_power_nodes=[]
	check(g.ensure_gelato_shop_state(),"Count-only shop fixture migrates exact slot identities")

func fresh(area: String = "gelato"):
	g.set_active_area(area)
	g.testing = true
	g.mode = "shop"
	g.trial_active = false
	g.twin_launchers = false
	g.power_reset_tier = 0
	g.run_id = ""
	g.shift_claimed = true
	g.run_transition.finish()
	g.navigation_delay = 0
	g.result_input_delay = 0
	g.note = ""
	g.note_time = 0
	g.bank = 10000.0
	g.levels = g.MAX_LEVELS.duplicate()
	g.levels[1] = int(g.tuning.get("twin_unlock_power",6))
	g.current_level = int(g.tuning.get("twin_unlock_level",8))
	g.highest_unlocked = int(g.tuning.get("twin_unlock_level",8))
	g.reduced_motion = false
	stage_legacy_counts()
	m.reset_view_state()
	m.update(0)

func touch(point: Vector2, pressed: bool, index: int = 0, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.position = g.to_global(point)
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	g._input(event)

func move_touch(point: Vector2, index: int = 0):
	var event = InputEventScreenDrag.new()
	event.position = g.to_global(point)
	event.index = index
	g._input(event)

func tap(point: Vector2):
	touch(point,true)
	touch(point,false)

func select_twins():
	tap(twin_point())

func twin_point() -> Vector2:
	var nodes: Array[Vector2i] = [m.TWIN_NODE]
	m._frame_nodes(nodes)
	m.update(m.CAMERA_DURATION)
	return m.point(m.TWIN_NODE.x,m.TWIN_NODE.y)

func gating_checks():
	fresh("bakery")
	check(not m.twin_control_visible() and not m.node_visible(8,1),"Bakery has no Twin map node")
	check(m.focus_area()==m.FOCUS_AREA and not g.buy_twin_launchers(),"Bakery framing and purchases ignore Twin launchers")
	fresh()
	check(m.twin_control_visible() and m.node_visible(8,1) and m.node_prerequisites(m.TWIN_NODE)==[Vector2i(0,1)],"Gelato displays Dual Shot beneath the starter independently of its Power purchase gate")
	check(g.gelato_launcher.cost()==3000 and g.tuning.twin_unlock_level==8,"Twin requires the later tray and increased 3000-coin price")
	check(m.focus_area()==m.FOCUS_AREA and not m.overlay_at(Vector2(360,170)),"Removing the fixed Twin header restores the upper map area")
	for blocker in ["tray","power","trial","play","transition","pending"]:
		fresh()
		match blocker:
			"tray": g.highest_unlocked = int(g.tuning.twin_unlock_level)-1
			"power":
				g.levels[1] = int(g.tuning.twin_unlock_power)-1
				stage_legacy_counts()
			"trial": g.trial_active = true
			"play": g.mode = "play"
			"transition": g.run_transition.active = true
			"pending": g.run_id = "pending"; g.shift_claimed = false
		var bank: float = g.bank
		var power: int = g.levels[1]
		check(not g.buy_twin_launchers() and not g.twin_launchers and g.levels[1]==power and g.bank==bank,"Twin purchase rejects %s state without changing progress" % blocker)
	fresh()
	g.trial_active = true
	check(not m.twin_control_visible(),"Fixed Trials do not offer Twin launchers")
	fresh()
	g.bank = g.gelato_launcher.cost()-1
	select_twins()
	tap(m.buy_rect().get_center())
	check(not g.twin_launchers and g.bank==g.gelato_launcher.cost()-1 and g.levels[1]==6,"Insufficient credit purchase leaves Power and bank intact")
	fresh()
	g.highest_unlocked = 7
	select_twins()
	check(m.twin_selected and m.has_selection() and m._twin_gate_text().contains("Requires"),"Locked Twin selection still explains its requirements")
	tap(m.buy_rect().get_center())
	check(not g.twin_launchers and g.bank==10000.0,"Locked card never spends credits")

func gesture_checks():
	fresh()
	var selector: Vector2 = twin_point()
	var start_pan: Vector2 = m.pan
	touch(selector,true,7)
	check(not m.twin_selected and not g.twin_launchers,"Twin selector does not activate on touch down")
	touch(selector,false,7)
	check(m.twin_selected and m.selected==-1 and not g.twin_launchers and g.bank==10000.0,"Clean selector release opens its card without buying")
	check(m.card_rect()==m.TWIN_CARD_RECT and m.overlay_at(m.card_rect().position+Vector2(20,20)),"Padded Twin tradeoff card blocks map input across its full height")
	var buy: Vector2 = m.buy_rect().get_center()
	touch(buy,true)
	check(not g.twin_launchers,"Twin Buy waits for release")
	move_touch(buy+Vector2(40,0))
	touch(buy+Vector2(40,0),false)
	check(not g.twin_launchers and g.bank==10000.0 and m.pan==start_pan,"Dragging Buy cancels purchase without moving the map")
	touch(buy,true,8)
	touch(selector,true,9)
	touch(buy,false,8)
	touch(selector,false,9)
	check(not g.twin_launchers and m.overlay_touches.is_empty(),"A second finger cancels the entire Twin Buy gesture")
	touch(buy,true)
	touch(buy,false,0,true)
	check(not g.twin_launchers,"Canceled Twin Buy touch cannot purchase")
	g.navigation_delay = .2
	tap(buy)
	check(not g.twin_launchers,"Navigation guard also blocks Twin Buy")
	g.navigation_delay = 0
	g.result_input_delay = .2
	tap(buy)
	check(not g.twin_launchers,"Result guard also blocks Twin Buy")
	fresh()
	selector = twin_point()
	start_pan = m.pan
	touch(selector,true)
	move_touch(selector+Vector2(50,30))
	touch(selector+Vector2(50,30),false)
	check(not m.twin_selected and m.pan.is_equal_approx(start_pan+Vector2(50,30)),"Dragging the Twin node pans the map without opening or purchasing it")

func purchase_checks():
	for old_power in [6,8,10]:
		fresh()
		g.levels[1] = old_power
		stage_legacy_counts()
		var previous: Array = g.levels.duplicate()
		var cost: int = g.gelato_launcher.cost()
		select_twins(); tap(m.buy_rect().get_center())
		check(g.twin_launchers and g.power_reset_tier==old_power and g.levels[1]==0 and is_equal_approx(g.power_damage(),1.0),"Twin purchase resets Power %d and remembers its exact bought slots" % old_power)
		previous[1] = 0
		check(g.levels==previous and g.bank==10000.0-cost,"Twin purchase %d charges once and preserves other upgrades" % old_power)
		check(not m.twin_selected and g.is_rebuild_power_node(m.selected,m.tier),"Twin purchase selects an eligible nearby rebuild slot")
		m.update(m.CAMERA_DURATION)
		check(m.focus_area().encloses(m.node_rect(m.selected,m.tier,false)),"Twin purchase frames the selected rebuild clear of fixed controls")
		var all_green=true
		for n in range(1,old_power+1): all_green=all_green and m.node_visible(1,n) and m.state_for(1,n)=="affordable" and m.SURFACE[m.state_for(1,n)]=="upgrade_tile_green"
		check(all_green,"All historically purchased Power slots are visible and green when affordable")
		var earned_bank: float = g.bank
		g.bank = 0
		check(m.state_for(1,1)=="unaffordable" and m.SURFACE[m.state_for(1,1)]=="upgrade_tile_red","An unaffordable Power rebuild is red")
		g.developer_free_purchases["gelato"] = true
		check(m.state_for(1,old_power)=="affordable" and m.SURFACE[m.state_for(1,old_power)]=="upgrade_tile_green","Developer money makes any eligible reset slot green even with zero coins")
		g.developer_free_purchases.clear(); g.bank = earned_bank
		m.selected = 1; m.tier = old_power
		var bank: float = g.bank
		var rebuild_cost: int = g.upgrade_cost(1)
		var expected: int = ceili(g.BASE_COSTS[1]*g.tuning.upgrade_cost_scale*g.tuning.power_rebuild_cost_multiplier)
		check(rebuild_cost==expected,"Rebuilt Power starts at its increased aggregate-tier price")
		tap(m.buy_rect().get_center())
		check(g.levels[1]==1 and g.bank==bank-rebuild_cost and m.state_for(1,old_power)=="owned" and not g.shop_node_owned(1,1),"Player can rebuild the chosen high-ordinal slot first without granting Power1's slot")
		check(m.selected_node()==Vector2i(1,old_power),"Buying an already visible rebuild keeps the player's selected slot without an ordinal jump")
		check(m.node_visible(1,1) and m.state_for(1,1)=="affordable","Unbought reset slots remain visible and available after another slot is rebuilt")
		bank=g.bank
		tap(m.buy_rect().get_center())
		check(g.levels[1]==1 and g.bank==bank,"Tapping the owned rebuild card cannot buy it twice")
		check(g.power_damage(1)>1.0 and g.power_damage(1)==1.0+float(g.tuning.core_tier_gains[0])*g.tuning.power_rebuild_gain_multiplier,"First rebuilt effect uses the stronger aggregate Power1 gain regardless of slot ordinal")
		select_twins(); tap(m.buy_rect().get_center())
		check(m.twin_selected and m._twin_gate_text().begins_with("Owned") and g.bank==bank and g.levels[1]==1,"Owned launcher card remains inspectable and cannot charge or reset again")
	fresh()
	var dependency: Vector2i = g.upgrade_graph().prerequisites(1,2)[0]
	g.levels[dependency.x] = dependency.y-1
	stage_legacy_counts()
	select_twins(); tap(m.buy_rect().get_center())
	var guarded_bank: float = g.bank
	var guarded_cost: int = g.upgrade_cost(1)
	m.selected=1; m.tier=2
	tap(m.buy_rect().get_center())
	check(g.levels[1]==1 and g.bank==guarded_bank-guarded_cost and g.shop_node_owned(1,2) and not g.shop_node_owned(dependency.x,dependency.y),"A migrated reset slot rebuilds without granting its newly shuffled unowned parent")
	check(m.selected_node()==Vector2i(1,2) and m.state_for(1,1)=="affordable","Legacy rebuild stays selected and leaves other historical reset choices available")
	fresh()
	g.testing = false
	check(not g.buy_twin_launchers() and g.bank==10000.0 and g.levels[1]==6 and not g.twin_launchers and g.power_reset_tier==0,"Failed in-memory save rolls back the entire launcher transaction")
	g.testing = true
	check(g.profile_calls==1,"Only the deliberate save-failure fixture invoked persistence; no file was opened")

func presentation_checks():
	fresh()
	check(m._effect_text(0,4)=="Drop food faster","Single Gelato Feed card uses a short functional description")
	g.twin_launchers = true
	g.power_reset_tier = 3
	g.levels[1] = 0
	stage_legacy_counts()
	check(m._effect_text(0,4)=="Drop food faster","Twin Feed keeps its meaning without a decimal rate")
	check(m._effect_text(1,2)=="Hit pegs harder","Power explains its function without damage arithmetic")
	g.tuning.twin_fire_rate_multiplier = .7
	g.tuning.power_rebuild_cost_multiplier = 2.5
	g.tuning.power_rebuild_gain_multiplier = 1.5
	var lines: Array = m._twin_effect_lines()
	check(lines==["Two slower launchers. Power starts over.","Power costs more and grows stronger."],"Twin tradeoff explains slower drops, reset Power, higher prices and stronger rebuilds without numeric stats")
	g.twin_launchers = false
	g.tuning.twin_unlock_level = 8
	g.tuning.twin_unlock_power = 6
	check(m._twin_gate_text()=="Requires tray 8 + Power 6","Gate copy follows configured tray and Power requirements")
	g.twin_launchers = true
	g.power_reset_tier = 10
	g.trial_active = true
	m.twin_selected = true
	m.update(0)
	check(not m.twin_selected and not m.is_reset_power(1,10) and m._effect_text(0,4)=="Drop food faster","Trial view suppresses Twin selection and reset-path visibility while keeping plain Feed copy")
	fresh("bakery")
	g.twin_launchers = true
	g.power_reset_tier = 10
	g.levels[1] = 0
	check(not m.is_reset_power(1,10) and m.node_visible(1,10)==Graph.is_visible(g.levels,1,10),"Stale Twin fields cannot reveal Bakery Power nodes")
	check(m._effect_text(0,4)=="Drop food faster","Bakery uses the same simple Feed description")

func _initialize():
	g = FixtureGame.new()
	g.sound_on = false
	g.first_run_guide.completed = true
	g.first_run_guide.active = false
	m = g.upgrade_map
	gating_checks()
	gesture_checks()
	purchase_checks()
	presentation_checks()
	g.free()
	print("GELATO_LAUNCHER_SHOP_QA_RESULT: ",passed," passed, ",failures.size()," failed: ",failures)
	quit(0 if failures.is_empty() else 1)
