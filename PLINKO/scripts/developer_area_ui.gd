extends RefCounted
## Developer settings. Area records and purchase policy belong to the game.
const AREAS = ["bakery","gelato","crystal"]
const CARD_RECTS = [Rect2(48,205,624,196),Rect2(48,415,624,196),Rect2(48,625,624,196)]
const MONEY_RECT = Rect2(48,865,624,82)
const BACK_RECT = Rect2(48,1080,624,96)
var g
var _touches: Dictionary = {}
var _primary = -1
var _down = Vector2.ZERO
var _target = ""
var _tap = false

func _init(game):
	g = game

func cancel_gestures():
	_touches.clear()
	_primary = -1
	_down = Vector2.ZERO
	_target = ""
	_tap = false

func area_button_rect(id: String) -> Rect2:
	var index = AREAS.find(id)
	if index<0: return Rect2()
	return Rect2(CARD_RECTS[index].position+Vector2(24,111),Vector2(576,66))

func area_action(id: String) -> String:
	if id==g.area_id: return "Current"
	if not g.area_content_ready(id): return "Unavailable"
	return "Continue" if g.area_owned(id) else "Start fresh"

func area_detail(id: String) -> String:
	if id==g.area_id: return "Tray %d · %s coins" % [g.current_level,g.credits_text(g.bank)]
	if not g.area_owned(id): return "Tray 1 · 0 coins · no upgrades"
	var record: Dictionary = g.area_records.get(id,{})
	return "Tray %d · %s coins" % [int(record.get("current_level",1)),g.credits_text(float(record.get("bank",0.0)))]

func _target_at(p: Vector2) -> String:
	if BACK_RECT.has_point(p): return "back"
	if MONEY_RECT.has_point(p): return "money"
	for id in AREAS:
		if area_button_rect(id).has_point(p): return id
	return ""

func _can_switch(id: String) -> bool:
	return id in AREAS and id!=g.area_id and g.developer_tools_available() and g.developer_area_navigation_allowed() and g.area_content_ready(id)

func _can_toggle_money() -> bool:
	return g.developer_tools_available() and g.developer_area_navigation_allowed()

func press(p: Vector2):
	if g.mode!="developer_areas" or g.navigation_delay>0 or not _touches.is_empty(): return
	var target = _target_at(p)
	if target=="back":
		cancel_gestures()
		g.mode = "support"
		g.navigation_delay = .25
		g.queue_redraw()
	elif target=="money" and _can_toggle_money():
		if g.set_developer_money(not g.developer_money_enabled()): cancel_gestures()
		g.queue_redraw()
	elif _can_switch(target):
		if g.developer_switch_area(target): cancel_gestures()
		g.queue_redraw()

func handle_input(event) -> bool:
	if g.mode!="developer_areas":
		cancel_gestures()
		return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			cancel_gestures()
			press(BACK_RECT.get_center())
		return true
	if event is InputEventScreenTouch:
		var p: Vector2 = g.to_local(event.position)
		if event.pressed:
			if _touches.is_empty():
				_primary = event.index
				_down = p
				_target = _target_at(p)
				_tap = not event.canceled and g.navigation_delay<=0 and (_target=="back" or (_target=="money" and _can_toggle_money()) or _can_switch(_target))
			else:
				_tap = false
			_touches[event.index] = p
		else:
			if not _touches.has(event.index): return true
			_touches.erase(event.index)
			var activate: bool = not event.canceled and event.index==_primary and _tap and _touches.is_empty() and p.distance_to(_down)<=14.0 and _target_at(p)==_target
			if event.index==_primary: _tap = false
			if _touches.is_empty(): cancel_gestures()
			if activate: press(p)
		return true
	if event is InputEventScreenDrag:
		if _touches.has(event.index):
			var p: Vector2 = g.to_local(event.position)
			_touches[event.index] = p
			if event.index==_primary and p.distance_to(_down)>14.0: _tap = false
		return true
	# Mouse is already emulated as touch. Consume covered Settings input.
	return true

func draw():
	if g.mode!="developer_areas": return
	g.heading("Developer settings",Vector2(48,115),42)
	g.fitted_text("Test any area. Progress stays separate.",Rect2(48,151,624,45),25,g.TEAL)
	if not g.developer_tools_available():
		g.fitted_text("Developer tools are unavailable in this build.",Rect2(48,420,624,90),27,g.MUTED,true)
	else:
		for index in range(AREAS.size()):
			var id: String = AREAS[index]
			var rect: Rect2 = CARD_RECTS[index]
			g.ui_panel(rect)
			g.fitted_text(g.area_title(id),Rect2(rect.position+Vector2(24,12),Vector2(576,40)),28,g.WHITE)
			g.fitted_text(area_detail(id),Rect2(rect.position+Vector2(24,52),Vector2(576,26)),20,g.GOLD)
			var detail = "Coins and upgrades are retained." if g.area_owned(id) else "A new area starts without upgrades."
			g.fitted_text(detail,Rect2(rect.position+Vector2(24,80),Vector2(576,22)),18,g.MUTED)
			g.button(area_button_rect(id),area_action(id),_can_switch(id))
		g.fitted_text("Testing · "+g.area_title(),Rect2(48,828,624,30),22,g.TEAL)
		g.button(MONEY_RECT,"Infinite money · "+("On" if g.developer_money_enabled() else "Off"),g.developer_money_enabled() and _can_toggle_money())
		g.fitted_text("Buy upgrades without spending this area's coins.",Rect2(48,963,624,32),22,g.MUTED,true)
		g.fitted_text("Upgrades stay saved. The toggle resets on restart.",Rect2(48,1006,624,32),20,g.MUTED,true)
	g.button(BACK_RECT,"Back",true)
