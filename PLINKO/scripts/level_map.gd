extends RefCounted
## Continuous area journeys with a guarded, first-entry confirmation.
const Campaign = preload("res://scripts/area_campaign.gd")
const AREA = Rect2(0,0,720,1280)
const BACK_RECT = Rect2(36,22,96,96)
const TITLE_RECT = Rect2(156,28,528,84)
const PLAY_RECT = Rect2(48,1090,624,96)
const NODE_SIZE = Vector2(144,144)
const CONTENT_HEIGHT = 2400.0
const FOCUS_Y = 632.0
const TAP_DURATION = .20
const LEVEL_COUNT = 12
const AREA_MENU_RECT = Rect2(144,132,540,356)
const ENTRY_PANEL = Rect2(44,356,632,790)
const ENTRY_ENTER_RECT = Rect2(80,870,560,98)
const ENTRY_CANCEL_RECT = Rect2(150,1000,420,88)

var g
var scroll = 0.0
var touch_points: Dictionary = {}
var tap_feedback: Dictionary = {}
var dragging = false
var moved = false
var area_menu_open = false
var entry_open = false
var entry_destination = ""
var _was_boards = false
var _primary = -1
var _down = Vector2.ZERO
var _last = Vector2.ZERO
var _tap_candidate = false
var _overlay_sequence = false
var _overlay_action = ""

func _init(game):
	g = game

func visual_area() -> Rect2:
	# Controls stay within the logical safe area; scenery fills the physical screen.
	if not g.is_inside_tree(): return AREA
	return g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()

func world_point(n: int) -> Vector2:
	return Vector2(360+142*sin((n-1)*1.4),2160-(n-1)*170)

func point(n: int) -> Vector2:
	return world_point(n)-Vector2(0,scroll)

func area_gate_rect() -> Rect2:
	return Rect2(point(LEVEL_COUNT)+Vector2(-216,-322),Vector2(432,184))

func area_gate_requirements() -> Dictionary:
	return g.area_entry_status(_entry_target())

func _entry_target() -> String:
	return entry_destination if entry_open and not entry_destination.is_empty() else Campaign.next_area(g.area_id)

func has_next_area() -> bool:
	return not Campaign.next_area(g.area_id).is_empty()

func area_option_rect(id: String) -> Rect2:
	var index = Campaign.IDS.find(id)
	return Rect2(168,150+112*index,492,94) if index>=0 else Rect2()

func close_overlay(with_sound: bool = true) -> bool:
	if not area_menu_open and not entry_open: return false
	if with_sound: g.feedback("ui_back")
	area_menu_open = false
	entry_open = false
	entry_destination = ""
	cancel_gestures()
	g.queue_redraw()
	return true

func open_entry(destination: String = "") -> bool:
	var target = Campaign.next_area(g.area_id) if destination.is_empty() else destination
	if target not in Campaign.IDS or Campaign.predecessor(target).is_empty(): return false
	var requirement = g.area_entry_status(target)
	if requirement.owned:
		return g.switch_area(target)
	if not requirement.can_enter: return false
	area_menu_open = false
	entry_open = true
	entry_destination = target
	g.feedback("ui_tap")
	cancel_gestures()
	g.navigation_delay = .25
	g.queue_redraw()
	return true

func scroll_bounds() -> Vector2:
	# Both end levels can reach the comfortable center, clear of floating controls.
	return Vector2(world_point(LEVEL_COUNT).y-FOCUS_Y,world_point(1).y-FOCUS_Y)

func _clamp_scroll():
	var bounds = scroll_bounds()
	scroll = clampf(scroll,bounds.x,bounds.y)

func open():
	area_menu_open = false
	entry_open = false
	entry_destination = ""
	cancel_gestures()
	tap_feedback.clear()
	scroll = world_point(clampi(g.current_level,1,LEVEL_COUNT)).y-FOCUS_Y
	_clamp_scroll()
	_was_boards = true
	g.queue_redraw()

func reset():
	area_menu_open = false
	entry_open = false
	entry_destination = ""
	cancel_gestures()
	tap_feedback.clear()
	scroll = 0.0
	_was_boards = false
	g.queue_redraw()

func cancel_gestures():
	touch_points.clear()
	_primary = -1
	_down = Vector2.ZERO
	_last = Vector2.ZERO
	_tap_candidate = false
	_overlay_sequence = false
	_overlay_action = ""
	dragging = false
	moved = false

func update(delta: float) -> bool:
	if g.mode != "boards":
		var changed = _was_boards or not touch_points.is_empty() or not tap_feedback.is_empty()
		cancel_gestures()
		tap_feedback.clear()
		_was_boards = false
		area_menu_open = false
		entry_open = false
		return changed
	var changed = false
	if not _was_boards:
		open()
		changed = true
	if not is_finite(delta) or delta <= 0: return changed
	for n in tap_feedback.keys():
		tap_feedback[n] += minf(delta,TAP_DURATION)
		changed = true
		if tap_feedback[n] >= TAP_DURATION: tap_feedback.erase(n)
	if changed: g.queue_redraw()
	return changed

func state_for(n: int) -> String:
	if n < 1 or n > LEVEL_COUNT or n > g.highest_unlocked: return "locked"
	if n == g.current_level: return "selected"
	if n < g.highest_unlocked or (n == LEVEL_COUNT and g.chapter_complete): return "completed"
	return "available"

func animation_for(n: int) -> Dictionary:
	var result = {"scale":Vector2.ONE,"offset":Vector2.ZERO}
	if not tap_feedback.has(n) or g.reduced_motion: return result
	var t = clampf(tap_feedback[n]/TAP_DURATION,0,1)
	var envelope = sin(t*PI)
	var squash = sin(t*TAU)*envelope
	result.scale = Vector2(1+squash*.02,1-squash*.025)
	result.offset.y = -3*envelope
	return result

func _input_allowed() -> bool:
	return g.mode == "boards" and g.navigation_delay <= 0 and g.result_input_delay <= 0

func overlay_at(p: Vector2) -> bool:
	if area_menu_open or entry_open: return visual_area().has_point(p)
	if BACK_RECT.has_point(p) or TITLE_RECT.has_point(p) or PLAY_RECT.has_point(p): return true
	if g.diagnostics_on and Rect2(24,1175,672,84).has_point(p): return true
	return g.note_time > 0 and Rect2(24,1190,672,60).has_point(p)

func map_input_at(p: Vector2) -> bool:
	return visual_area().has_point(p) and not overlay_at(p)

func _action_at(p: Vector2) -> String:
	if entry_open:
		if ENTRY_ENTER_RECT.has_point(p): return "enter"
		if ENTRY_CANCEL_RECT.has_point(p): return "cancel"
		return ""
	if area_menu_open:
		if TITLE_RECT.has_point(p): return "areas"
		for id in Campaign.IDS:
			if area_option_rect(id).has_point(p): return "area:"+id
		return "dismiss"
	if BACK_RECT.has_point(p): return "back"
	if TITLE_RECT.has_point(p): return "areas"
	if PLAY_RECT.has_point(p): return "play"
	return ""

func handle_input(event) -> bool:
	if g.mode != "boards":
		cancel_gestures()
		return false
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: return false
		var p = g.to_local(event.position)
		if not visual_area().has_point(p): return false
		# Overlay wheel events are consumed without moving the map underneath them.
		if event.pressed and _input_allowed() and map_input_at(p) and touch_points.is_empty():
			var amount = maxf(.1,absf(event.factor))*108
			scroll += -amount if event.button_index == MOUSE_BUTTON_WHEEL_UP else amount
			_clamp_scroll()
			g.queue_redraw()
		return true
	if event is InputEventScreenTouch:
		var p = g.to_local(event.position)
		if event.pressed and not event.canceled:
			if touch_points.is_empty():
				if not visual_area().has_point(p): return false
				if not _input_allowed(): return true
				_primary = event.index
				_down = p
				_last = p
				_tap_candidate = true
				_overlay_sequence = overlay_at(p)
				_overlay_action = _action_at(p)
				moved = false
			else:
				# A second pointer cannot activate a control or convert a UI tap to pan.
				_tap_candidate = false
				moved = true
			touch_points[event.index] = p
			dragging = not _overlay_sequence
			return true
		if not touch_points.has(event.index): return false
		var activate = not event.canceled and touch_points.size() == 1 and event.index == _primary and _tap_candidate and not moved and p.distance_to(_down) <= 12 and _input_allowed()
		if _overlay_sequence:
			activate = activate and not _overlay_action.is_empty() and _action_at(p) == _overlay_action
		else:
			activate = activate and map_input_at(p)
		touch_points.erase(event.index)
		if touch_points.is_empty():
			cancel_gestures()
			# The root wrapper owns navigation debounce, persistence, and run startup.
			if activate: g.handle_press(p)
		else:
			_tap_candidate = false
			moved = true
			_last = touch_points.values()[0]
		return true
	if event is InputEventScreenDrag:
		if not touch_points.has(event.index): return false
		var p = g.to_local(event.position)
		touch_points[event.index] = p
		if not _input_allowed():
			_tap_candidate = false
			_last = p
			return true
		if p.distance_to(_down) > 12:
			_tap_candidate = false
			moved = true
		if touch_points.size() == 1 and not _overlay_sequence and moved:
			scroll -= p.y-_last.y
			_clamp_scroll()
			g.queue_redraw()
		_last = p
		return true
	# Project settings emulate left mouse as touch; processing it here doubles taps.
	return false

func select_at(p: Vector2):
	if not _input_allowed() or not map_input_at(p): return
	for n in range(LEVEL_COUNT,0,-1):
		if not Rect2(point(n)-NODE_SIZE*.5,NODE_SIZE).has_point(p): continue
		if n > g.highest_unlocked:
			g.feedback("ui_error")
			return
		g.feedback("ui_tap")
		var changed = g.current_level != n
		g.current_level = n
		if not g.reduced_motion: tap_feedback[n] = 0.0
		if changed and not g.testing: g.save_game()
		g.queue_redraw()
		return

func press(p: Vector2):
	if not _input_allowed() or not touch_points.is_empty(): return
	var action = _action_at(p)
	if entry_open:
		if action == "cancel":
			close_overlay()
			g.navigation_delay = .25
		elif action == "enter" and area_gate_requirements().can_enter:
			if g.enter_area(_entry_target()): close_overlay()
		return
	if area_menu_open:
		if action.begins_with("area:"):
			var id = action.trim_prefix("area:")
			if id == g.area_id:
				close_overlay()
			elif g.area_owned(id):
				if g.switch_area(id): close_overlay()
			else:
				close_overlay(false)
				scroll = scroll_bounds().x
				if not open_entry(id): g.feedback("ui_back")
		else: close_overlay()
		g.navigation_delay = .25
		return
	if action == "areas":
		g.feedback("ui_tap")
		area_menu_open = true
		cancel_gestures()
		g.navigation_delay = .25
	elif action == "back":
		g.mode = "home"
		cancel_gestures()
	elif action == "play":
		g.start_shift()
		cancel_gestures()
	elif has_next_area() and area_gate_rect().has_point(p):
		open_entry()
	else:
		select_at(p)
	g.queue_redraw()

func _path_points() -> PackedVector2Array:
	var points = PackedVector2Array()
	# Start beneath the first medallion, so the trail has a finished endpoint.
	var previous = world_point(1)
	for n in range(2,LEVEL_COUNT+2):
		var next = world_point(n) if n <= LEVEL_COUNT else world_point(LEVEL_COUNT)+Vector2(0,-170)
		var middle = (previous.y+next.y)*.5
		var c1 = Vector2(previous.x,middle)
		var c2 = Vector2(next.x,middle)
		for step in range(13):
			points.append(previous.bezier_interpolate(c1,c2,next,step/12.0)-Vector2(0,scroll))
		previous = next
	return points

func _draw_route():
	var route = _path_points()
	var shadow = PackedVector2Array()
	for p in route: shadow.append(p+Vector2(0,5))
	g.draw_polyline(shadow,g.area_surface("route_shadow"),84,true)
	g.draw_polyline(route,g.area_surface("route_outer"),80,true)
	g.draw_polyline(route,g.area_surface("route_inner"),74,true)
	g.draw_polyline(route,g.area_surface("route_base"),66,true)
	g.draw_polyline(route,g.area_surface("route_center"),48,true)

func _draw_node(n: int):
	var state = state_for(n)
	var anim = animation_for(n)
	var center = point(n)+anim.offset
	var size = NODE_SIZE*anim.scale
	var rect = Rect2(center-size*.5,size)
	if not visual_area().intersects(rect.grow(28)): return
	var asset = "level_badge_mint" if state == "selected" else ("level_badge_muted" if state == "locked" else "level_badge_cream")
	if state == "selected":
		g.draw_arc(center,81,0,TAU,64,Color("9e623f"),4,true)
		g.draw_arc(center,77,0,TAU,64,Color("fff6d8"),3,true)
	if not g.ui_art.draw(g,asset,rect):
		g.draw_circle(center,size.x*.48,Color("b27e4e"))
		g.draw_circle(center,size.x*.445,Color("bad4c0") if state == "selected" else (Color("dacdb4") if state == "locked" else Color("fff0ce")))
	var text_color = Color("786550") if state == "locked" else Color("4a3325")
	g.fitted_number(str(n),Rect2(center-Vector2(51,43),Vector2(102,80)),60,text_color,true)
	if state == "selected":
		var marker = center+Vector2(53,48)
		g.draw_circle(marker,25,Color("b9804c"))
		g.draw_circle(marker,21,Color("fff0d1"))
		g.food_art.draw(g,"donut",Rect2(marker-Vector2(20,20),Vector2(40,40)))
	elif state == "locked":
		var marker = center+Vector2(49,48)
		g.draw_circle(marker,23,Color("ac8059"))
		g.draw_circle(marker,19,Color("f1dfbd"))
		g.symbol("lock",marker,28,Color("745535"))
	elif state == "completed":
		g.symbol("check",center+Vector2(0,42),34,Color("387c62"))

func _draw_area_gate():
	if entry_open or not has_next_area(): return
	var rect = area_gate_rect()
	var area = visual_area()
	if not area.intersects(rect): return
	var requirement = area_gate_requirements()
	g.ui_panel(rect)
	g.symbol("check" if requirement.owned else ("play" if requirement.can_enter else "lock"),rect.position+Vector2(48,43),34,g.TEAL if requirement.can_enter or requirement.owned else Color("745535"))
	# As the map pans, omit labels once their line is outside the visible canvas.
	var title = Rect2(rect.position+Vector2(78,19),Vector2(320,44))
	if area.encloses(title): g.fitted_text(g.area_title(_entry_target()),title,30,g.WHITE)
	var price = Rect2(rect.position+Vector2(105,65),Vector2(278,52))
	if requirement.owned:
		if area.encloses(price): g.fitted_text("Open",price,32,g.TEAL)
	else:
		g.ui_art.draw(g,"coin",Rect2(rect.position+Vector2(49,69),Vector2(44,44)))
		if area.encloses(price): g.fitted_number(g.credits_text(requirement.cost),price,36,g.TEAL if requirement.funded else g.WHITE)
	var completion = Rect2(rect.position+Vector2(32,128),Vector2(92,32))
	var count = LEVEL_COUNT if requirement.cleared else clampi(g.highest_unlocked-1,0,LEVEL_COUNT-1)
	if area.encloses(completion): g.fitted_text("%d / 12" % count,completion,22,g.TEAL if requirement.cleared else g.MUTED,true)
	var availability = Rect2(rect.position+Vector2(137,128),Vector2(268,32))
	var state = "Open" if requirement.owned else ("Enter" if requirement.can_enter else ("Not available yet" if not requirement.content_ready else ("Clear 12 trays" if not requirement.cleared else "Save coins")))
	if area.encloses(availability): g.fitted_text(state,availability,22,g.TEAL if requirement.can_enter or requirement.owned else g.MUTED,true)

func _draw_area_menu():
	g.draw_rect(visual_area(),Color(g.area_surface("overlay"),.2))
	g.ui_panel(AREA_MENU_RECT)
	for id in Campaign.IDS:
		var rect = area_option_rect(id)
		var owned = g.area_owned(id)
		g.button(rect,"",id==g.area_id)
		g.fitted_text(g.area_title(id),Rect2(rect.position+Vector2(24,10),Vector2(rect.size.x-100,rect.size.y-20)),30,g.WHITE)
		g.symbol("check" if id==g.area_id else ("play" if owned else "lock"),rect.position+Vector2(rect.size.x-48,rect.size.y*.5),34,g.TEAL if owned else g.MUTED)

func _draw_entry():
	g.draw_rect(visual_area(),Color(g.area_surface("overlay"),.40))
	# Draw the destination illustration without changing active-area resources.
	var destination = _entry_target()
	g.environment_art.draw_for_area(g,destination,"bakery_landmark",Rect2(216,94,288,252))
	g.ui_panel(ENTRY_PANEL)
	g.fitted_text(g.area_title(destination),Rect2(76,395,568,70),42,g.WHITE,true)
	var labels = ["Upgrades restart","Purchases stay","Coins stay in "+g.area_title(Campaign.predecessor(destination))]
	for i in range(3):
		var y = 510+i*106
		var rect = Rect2(80,y,560,80)
		g.box(rect,g.area_surface("secondary"),20)
		if i==2: g.ui_art.draw(g,"coin",Rect2(98,y+18,44,44))
		else: g.symbol("upgrade" if i==0 else "check",Vector2(120,y+40),38,g.TEAL if i==1 else g.GOLD)
		g.fitted_text(labels[i],Rect2(158,y+10,460,60),27 if i<2 else 24,g.WHITE)
	var requirement = area_gate_requirements()
	g.button(ENTRY_ENTER_RECT,"",requirement.can_enter)
	g.fitted_text("Enter",Rect2(130,889,162,60),32,g.WHITE,true)
	g.ui_art.draw(g,"coin",Rect2(318,895,48,48))
	g.fitted_number(g.credits_text(requirement.cost),Rect2(382,884,204,70),36,g.WHITE,true)
	g.button(ENTRY_CANCEL_RECT,"Cancel")

func draw():
	var area = visual_area()
	var environment = g.get("environment_art")
	if environment == null or not environment.draw_cover(g,"journey_backdrop",area):
		g.draw_rect(area,g.area_surface("background"))
	_draw_route()
	if environment != null:
		var landmark = point(LEVEL_COUNT)+Vector2(0,-398 if has_next_area() else -245)
		environment.draw(g,"bakery_landmark",Rect2(landmark-Vector2(90,74),Vector2(180,148)))
	for n in range(1,LEVEL_COUNT+1): _draw_node(n)
	_draw_area_gate()
	# These floating controls are deliberately last; the trail has no inset clip box.
	g.button(BACK_RECT,"<")
	g.ui_panel(TITLE_RECT)
	g.fitted_text(g.area_title(),Rect2(TITLE_RECT.position+Vector2(16,10),TITLE_RECT.size-Vector2(72,20)),34,g.WHITE,true)
	var arrow = TITLE_RECT.position+Vector2(TITLE_RECT.size.x-35,TITLE_RECT.size.y*.5)
	g.draw_polyline(PackedVector2Array([arrow+Vector2(-8,-4),arrow+Vector2(0,4),arrow+Vector2(8,-4)]),g.WHITE,3,true)
	if not entry_open: g.button(PLAY_RECT,"Play · %d" % g.current_level,true)
	if area_menu_open: _draw_area_menu()
	if entry_open: _draw_entry()
