extends RefCounted
## A touch-first recipe map. Progression and prices remain owned by the game.
const AREA = Rect2(0,0,720,1280)
# A comfortable destination for panning; this is never a drawing boundary.
const FOCUS_AREA = Rect2(24,145,672,770)
const MENU_RECT = Rect2(36,22,96,96)
const WALLET_RECT = Rect2(156,28,528,84)
const TWIN_NODE = Vector2i(8,1)
const MORE_JAM_NODE = Vector2i(8,2)
const TWIN_PARENT = Vector2i(0,1)
const TWIN_CARD_RECT = Rect2(36,768,648,310)
const TWIN_BUY_RECT = Rect2(438,794,214,86)
const TWIN_PAID_RECT = Rect2(438,892,214,86)
const TWIN_FOCUS_AREA = Rect2(24,145,672,599)
const CARD_RECT = Rect2(36,908,648,170)
const BUY_RECT = Rect2(438,932,214,86)
const CARD_TITLE_RECT = Rect2(148,932,268,40)
const CARD_STATUS_RECT = Rect2(148,978,268,28)
const CARD_EFFECT_RECT = Rect2(68,1026,584,28)
const TWIN_TITLE_RECT = Rect2(148,794,268,40)
const TWIN_STATUS_RECT = Rect2(148,840,268,64)
const TWIN_MESSAGE_RECT = Rect2(68,934,348,38)
const TWIN_EFFECT_RECTS = [Rect2(68,990,584,28),Rect2(68,1024,584,28)]
const TREATS_RECT = Rect2(48,1090,220,96)
const PLAY_RECT = Rect2(286,1090,386,96)
const TILE_SIZE = Vector2(224,224)
const PORTRAIT_RECT = Rect2(-72,-82,144,132)
const OVERVIEW_SIZE = 36.0
const NODE_GAP = 6.0
const COMPACT_GAP = 2.0
const DETAIL_SIZE = 112.0
# The wide arc can be surveyed as a whole, then zoomed back into its recipes.
const MIN_ZOOM = .075
const INITIAL_ZOOM = .84
const GELATO_INITIAL_ZOOM = .72
const MAX_ZOOM = 1.55
const FEEDBACK_DURATION = .28
const TAP_DURATION = .20
const CAMERA_DURATION = .55
const CARD_BOUNCE_DURATION = .28
const ORIGIN = Vector2(360,760)
const NAMES = ["Feed","Power","Bounce","Ricochet","Split","Impact","Gold","Time"]
const ART = ["hopper","cookie_armored","donut","ricochet","pomegranate","pumpkin","cup_gold","cookie_clock"]
const Graph = preload("res://scripts/upgrade_graph.gd")
const ArcArt = preload("res://scripts/upgrade_arc_art.gd")
const SURFACE = {"affordable":"upgrade_tile_green","unaffordable":"upgrade_tile_red","owned":"upgrade_tile_cream","locked":"upgrade_tile_cream"}
const FALLBACK = {"affordable":Color("a5c89a"),"unaffordable":Color("df9990"),"owned":Color("fff1d6"),"locked":Color("d6d0bf")}

var g
var arc_art = ArcArt.new()
static var _layout_cache: Dictionary = {}
var _positions: Dictionary = {}
var _layout_area = ""
var _paths: Dictionary = {}
var _spacing: Dictionary = {}
var pan = Vector2.ZERO
var zoom = INITIAL_ZOOM
var selected = -1
var twin_selected = false
var tier = 1
var dragging = false
var moved = false
var down = Vector2.ZERO
var last = Vector2.ZERO
var touch_points: Dictionary = {}
var feedback: Dictionary = {}
var tap_feedback: Dictionary = {}
var overlay_touches: Dictionary = {}
var _overlay_primary = -1
var _overlay_down = Vector2.ZERO
var _overlay_action = ""
var _overlay_tap = false
var _states: Dictionary = {}
var _was_shop = false
var _last_bank = -1.0
var _pinch_ids: Array = []
var _pinch_mid = Vector2.ZERO
var _pinch_distance = 0.0
var _tap_candidate = false
var _camera_active = false
var _camera_elapsed = 0.0
var _camera_from_pan = Vector2.ZERO
var _camera_to_pan = Vector2.ZERO
var _camera_from_zoom = INITIAL_ZOOM
var _camera_to_zoom = INITIAL_ZOOM
var _card_bounce_age = -1.0

func _init(game):
	g = game
	_build_positions()

func center():
	return ORIGIN + pan

func _build_positions():
	_layout_area=g.area_id
	if _layout_cache.has(_layout_area):
		_positions = _layout_cache[_layout_area].positions
		_paths = _layout_cache[_layout_area].paths
		_spacing = _layout_cache[_layout_area].spacing
		return
	_positions={}; _paths={}; _spacing={}
	# Each area has its own fixed routes. Discovery never moves existing nodes.
	var layout_path={"gelato":"res://data/gelato_upgrade_layout.json","crystal":"res://data/crystal_upgrade_layout.json"}.get(g.area_id,"res://data/upgrade_layout.json")
	var layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not layout is Dictionary or layout.get("schema",0) != 1:
		push_error("Upgrade layout is missing or has an unsupported schema")
		return
	for entry in layout.nodes:
		var node = Vector2i(int(entry.id[0]),int(entry.id[1]))
		_positions[node] = Vector2(float(entry.position[0]),float(entry.position[1]))
	for entry in layout.edges+layout.get("special_edges",[]):
		var key = Vector4i(int(entry.from[0]),int(entry.from[1]),int(entry.to[0]),int(entry.to[1]))
		var path = PackedVector2Array()
		for p in entry.points: path.append(Vector2(float(p[0]),float(p[1])))
		_paths[key] = path
	# Dual Shot is an optional purchase, not a ninth saved family. Its visible
	# root connection is separate from its Tray 8 + Power 6 purchase requirements.
	if _layout_area in ["bakery","gelato","crystal"]:
		_positions[TWIN_NODE] = _positions[TWIN_PARENT]+Vector2(0,440)
		for entry in layout.get("special_nodes",[]):
			if Vector2i(int(entry.id[0]),int(entry.id[1])) == TWIN_NODE:
				_positions[TWIN_NODE] = Vector2(float(entry.position[0]),float(entry.position[1]))
		var twin_edge = Vector4i(TWIN_PARENT.x,TWIN_PARENT.y,TWIN_NODE.x,TWIN_NODE.y)
		if not _paths.has(twin_edge): _paths[twin_edge] = PackedVector2Array([_positions[TWIN_PARENT],_positions[TWIN_NODE]])
	if _layout_area=="bakery":
		for entry in layout.get("special_nodes",[]):
			if Vector2i(int(entry.id[0]),int(entry.id[1]))==MORE_JAM_NODE:
				_positions[MORE_JAM_NODE]=Vector2(float(entry.position[0]),float(entry.position[1]))
	# Use the whole authored map so future discoveries never resize old nodes.
	# Chebyshev spacing measures the clearance between square tile faces.
	for node in _positions:
		var nearest = INF
		for other in _positions:
			if node == other: continue
			var delta: Vector2 = (_positions[node]-_positions[other]).abs()
			nearest = minf(nearest,maxf(delta.x,delta.y))
		_spacing[node] = nearest
	_layout_cache[_layout_area] = {"positions":_positions,"paths":_paths,"spacing":_spacing}

func minimum_zoom() -> float:
	if g.area_id not in ["gelato","crystal"]: return MIN_ZOOM
	# The winding garden grows vertically. The complete authored map,
	# including hidden nodes, sets a stable overview limit for the whole area.
	var nodes: Array[Vector2i] = []
	for node in _positions: nodes.append(node)
	var bounds = _reveal_bounds(nodes,1.0)
	return minf(.055,minf((FOCUS_AREA.size.x-48)/bounds.size.x,(FOCUS_AREA.size.y-48)/bounds.size.y)) if bounds.has_area() else .055

func initial_zoom() -> float:
	return GELATO_INITIAL_ZOOM if g.area_id in ["gelato","crystal"] else INITIAL_ZOOM

func _entry_nodes() -> Array[Vector2i]:
	var nodes: Array[Vector2i] = [Vector2i(0,1),TWIN_NODE]
	for route in g.upgrade_graph().routes():
		if not route.is_empty(): nodes.append(route[0])
	return nodes

func _frame_entry():
	if g.area_id not in ["bakery","gelato","crystal"]: return
	# Reserve the taller Dual Shot card even before selection so inspecting the
	# visible locked node never hides it behind the newly opened panel.
	var focus = TWIN_FOCUS_AREA.grow(-24)
	var nodes = _entry_nodes()
	var bounds = _reveal_bounds(nodes,zoom)
	var scale_to_fit = minf(1.0,minf(focus.size.x/bounds.size.x,focus.size.y/bounds.size.y))
	zoom = maxf(minimum_zoom(),zoom*scale_to_fit)
	bounds = _reveal_bounds(nodes,zoom)
	pan = focus.get_center()-ORIGIN-bounds.get_center()

func point(i, n):
	return center() + _positions.get(Vector2i(i,n),Vector2.ZERO) * zoom

func node_visual_size(i: int, n: int) -> Vector2:
	return _node_visual_size_at_zoom(i,n,zoom)

func _node_visual_size_at_zoom(i: int, n: int, at_zoom: float) -> Vector2:
	# Keep distant icons readable, but never let enlarged neighbors overlap.
	var desired = maxf(TILE_SIZE.x*at_zoom,OVERVIEW_SIZE)
	var gap = NODE_GAP if TILE_SIZE.x*at_zoom >= DETAIL_SIZE else COMPACT_GAP
	var clearance = maxf(1.0,float(_spacing.get(Vector2i(i,n),INF))*at_zoom-gap)
	return Vector2.ONE*minf(desired,clearance)

func node_rect(i: int, n: int, animated: bool = true) -> Rect2:
	var size = node_visual_size(i,n)
	var p: Vector2 = point(i,n)
	# Compact markers retain color feedback without jostling their narrow gaps.
	if animated and detail_visible(i,n):
		var motion = animation_for(Vector2i(i,n))
		size *= motion.scale
		p += motion.offset*node_visual_size(i,n)/TILE_SIZE
	return Rect2(p-size*.5,size)

func detail_visible(i: int, n: int) -> bool:
	return node_visual_size(i,n).x >= DETAIL_SIZE

func route_width(emphasized: bool = false) -> float:
	return clampf(9.5*zoom*(1.18 if emphasized else 1.0),3.0,10.0)

func route_opacity(owned: bool, emphasized: bool = false) -> float:
	return 1.0 if emphasized else (.9 if owned else .95)

func route_points(parent: Vector2i, node: Vector2i) -> PackedVector2Array:
	if g.area_id in ["gelato","crystal"] or node==MORE_JAM_NODE:
		var key = Vector4i(parent.x,parent.y,node.x,node.y)
		if _paths.has(key):
			var points = PackedVector2Array()
			for position in _paths[key]: points.append(center()+position*zoom)
			return points
	return PackedVector2Array([point(parent.x,parent.y),point(node.x,node.y)])

func node_visible(i: int, n: int) -> bool:
	if Vector2i(i,n)==TWIN_NODE: return twin_control_visible()
	if Vector2i(i,n)==MORE_JAM_NODE: return more_jam_visible()
	return g.shop_node_visible(i,n)

func more_jam_visible() -> bool:
	if g.area_id!="bakery" or g.trial_active: return false
	if g.highest_unlocked>=10 or g.bakery_ability.quick_owned(): return true
	for route in Graph.routes():
		var tip: Vector2i=route[-1]
		if g.shop_node_owned(tip.x,tip.y): return true
	return false

func more_jam_gate_text() -> String:
	if g.bakery_ability.quick_owned(): return "Owned"
	if not g.bakery_ability.owned(): return "Requires Jam Burst"
	if g.highest_unlocked<10: return "Reach tray 10"
	if not g.bakery_ability.routes_complete(): return "Finish all 3 lanes"
	return "All three lanes complete"

func twin_control_visible() -> bool:
	return g.area_id in ["bakery","gelato","crystal"] and not g.trial_active

func special_owned() -> bool:
	return g.ability_ui.owned()

func special_unlocked() -> bool:
	return g.ability_ui.unlocked()

func special_cost() -> int:
	return g.ability_ui.cost()

func special_buy() -> bool:
	if g.ability_ui.purchase_pending() or g.ability_ui.can_restore(): return false
	return g.ability_ui.controller().buy()

func node_prerequisites(node: Vector2i) -> Array[Vector2i]:
	if node==TWIN_NODE: return [TWIN_PARENT]
	if node==MORE_JAM_NODE:
		var tips: Array[Vector2i]=[]
		for route in Graph.routes(): tips.append(route[-1])
		return tips
	return g.upgrade_graph().prerequisites(node.x,node.y)

func node_cost(node: Vector2i) -> int:
	if node==MORE_JAM_NODE: return 0
	return special_cost() if node==TWIN_NODE else g.upgrade_cost(node.x)

func selected_node() -> Vector2i:
	return TWIN_NODE if twin_selected else Vector2i(selected,tier)

func is_reset_power(i: int, n: int) -> bool:
	return twin_control_visible() and g.is_rebuild_power_node(i,n)

func visible_nodes() -> Array[Vector2i]:
	var nodes: Array[Vector2i] = []
	for node in g.upgrade_graph().nodes():
		if node_visible(node.x,node.y): nodes.append(node)
	if twin_control_visible(): nodes.append(TWIN_NODE)
	if more_jam_visible(): nodes.append(MORE_JAM_NODE)
	return nodes

func state_for(i: int, n: int) -> String:
	if not node_visible(i,n): return "hidden"
	if Vector2i(i,n)==MORE_JAM_NODE:
		if g.bakery_ability.quick_owned(): return "owned"
		return "affordable" if g.bakery_ability.quick_unlocked() else "locked"
	if Vector2i(i,n)==TWIN_NODE:
		if special_owned(): return "owned"
		if not special_unlocked(): return "locked"
		return "affordable" if g.can_afford(special_cost()) else "unaffordable"
	if g.shop_node_owned(i,n): return "owned"
	if not g.shop_node_unlocked(i,n): return "locked"
	return "affordable" if g.can_afford(g.upgrade_cost(i)) else "unaffordable"

func visual_area() -> Rect2:
	# Safe-area layout keeps controls clear of notches. The map still fills the
	# physical viewport beyond that inset, with no separate paper or tile edge.
	if not g.is_inside_tree(): return AREA
	return g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()

func node_in_view(i: int, n: int) -> bool:
	return node_visible(i,n) and visual_area().intersects(node_rect(i,n))

func cancel_gestures():
	_cancel_camera()
	touch_points.clear()
	overlay_touches.clear()
	_overlay_primary = -1
	_overlay_down = Vector2.ZERO
	_overlay_action = ""
	_overlay_tap = false
	_pinch_ids.clear()
	_pinch_distance = 0.0
	_pinch_mid = Vector2.ZERO
	dragging = false
	moved = false
	_tap_candidate = false
	down = Vector2.ZERO
	last = Vector2.ZERO

func reset_view_state():
	if _layout_area!=g.area_id: _build_positions()
	cancel_gestures()
	_card_bounce_age = -1.0
	pan = Vector2.ZERO
	zoom = initial_zoom()
	selected = -1
	twin_selected = false
	tier = 1
	_frame_entry()
	# Returning players at the reported tray-10 wall can find the new reward
	# immediately; its authored location remains at the far end of the tree.
	if more_jam_visible() and g.bakery_ability.quick_unlocked():
		selected=MORE_JAM_NODE.x; tier=MORE_JAM_NODE.y
		_frame_nodes([MORE_JAM_NODE])
		_finish_camera()
	feedback.clear()
	tap_feedback.clear()
	_states.clear()
	_was_shop = false
	_last_bank = -1.0
	_request_redraw()

func update(delta: float) -> bool:
	var changed = false
	if g.mode != "shop":
		if _card_bounce_age>=0 or _camera_active or _was_shop or dragging or not touch_points.is_empty() or not overlay_touches.is_empty() or not tap_feedback.is_empty():
			cancel_gestures()
			_card_bounce_age = -1.0
			feedback.clear()
			tap_feedback.clear()
			_states.clear()
			_was_shop = false
			changed = true
		return changed
	changed = _sync_states() or changed
	if _card_bounce_age>=0 and g.reduced_motion:
		_card_bounce_age = -1.0
		changed = true
	if _camera_active and g.reduced_motion:
		_finish_camera()
		changed = true
	if not is_finite(delta) or delta <= 0: return changed
	if _card_bounce_age>=0:
		_card_bounce_age += minf(delta,CARD_BOUNCE_DURATION)
		if _card_bounce_age>=CARD_BOUNCE_DURATION: _card_bounce_age = -1.0
		changed = true
	if _camera_active:
		_camera_elapsed = minf(CAMERA_DURATION,_camera_elapsed+delta)
		var progress = _camera_elapsed/CAMERA_DURATION
		var eased = progress*progress*(3.0-2.0*progress)
		pan = _camera_from_pan.lerp(_camera_to_pan,eased)
		zoom = lerpf(_camera_from_zoom,_camera_to_zoom,eased)
		if _camera_elapsed >= CAMERA_DURATION: _finish_camera()
		changed = true
	for node in feedback.keys():
		feedback[node].age += minf(delta,FEEDBACK_DURATION)
		changed = true
		if feedback[node].age >= FEEDBACK_DURATION: feedback.erase(node)
	for node in tap_feedback.keys():
		tap_feedback[node] += minf(delta,TAP_DURATION)
		changed = true
		if tap_feedback[node] >= TAP_DURATION: tap_feedback.erase(node)
	if changed: _request_redraw()
	return changed

func _cancel_camera():
	_camera_active = false
	_camera_elapsed = 0.0

func _finish_camera():
	pan = _camera_to_pan
	zoom = _camera_to_zoom
	_camera_active = false

func _reveal_bounds(nodes: Array[Vector2i], at_zoom: float) -> Rect2:
	var bounds = Rect2()
	for node in nodes:
		var size = _node_visual_size_at_zoom(node.x,node.y,at_zoom)
		var position: Vector2 = _positions[node]*at_zoom
		var rect = Rect2(position-size*.5,size)
		bounds = bounds.merge(rect) if bounds.has_area() else rect
	return bounds

func _frame_new_upgrades(before: Array[Vector2i]):
	var revealed: Array[Vector2i] = []
	for node in visible_nodes():
		if node==MORE_JAM_NODE and not g.bakery_ability.quick_unlocked(): continue
		if node not in before: revealed.append(node)
	if g.area_id in ["gelato","crystal"] and before==[Vector2i(0,1),TWIN_NODE] and revealed.size()==g.upgrade_graph().routes().size():
		# The first fork retains the central start and the visible locked reward
		# beneath it. Later discoveries use the ordinary local camera behavior.
		_camera_from_pan=pan; _camera_from_zoom=zoom
		_frame_entry()
		_camera_to_pan=pan; _camera_to_zoom=zoom
		pan=_camera_from_pan; zoom=_camera_from_zoom
		_camera_elapsed=0.0
		_camera_active=not pan.is_equal_approx(_camera_to_pan) or not is_equal_approx(zoom,_camera_to_zoom)
		if g.reduced_motion: _finish_camera()
		return
	_frame_nodes(revealed)

func focus_area() -> Rect2:
	return TWIN_FOCUS_AREA if twin_selected and twin_control_visible() else FOCUS_AREA

func _frame_nodes(revealed: Array[Vector2i]):
	if revealed.is_empty(): return
	var focus = focus_area().grow(-24.0)
	var target_zoom = zoom
	var bounds = _reveal_bounds(revealed,target_zoom)
	# The starter reveals three choices. Fit them together only when necessary;
	# a normal one-step reveal retains the player's chosen zoom.
	if revealed.size()>1 and (bounds.size.x>focus.size.x or bounds.size.y>focus.size.y):
		var lower = minimum_zoom()
		var upper = zoom
		for iteration in range(20):
			var candidate = (lower+upper)*.5
			var candidate_bounds = _reveal_bounds(revealed,candidate)
			if candidate_bounds.size.x<=focus.size.x and candidate_bounds.size.y<=focus.size.y:
				lower = candidate
			else:
				upper = candidate
		target_zoom = lower
		bounds = _reveal_bounds(revealed,target_zoom)
	_camera_from_pan = pan
	_camera_from_zoom = zoom
	_camera_to_pan = focus.get_center()-ORIGIN-bounds.get_center()
	_camera_to_zoom = target_zoom
	_camera_elapsed = 0.0
	_camera_active = not pan.is_equal_approx(_camera_to_pan) or not is_equal_approx(zoom,_camera_to_zoom)
	if g.reduced_motion: _finish_camera()

func _sync_states() -> bool:
	if _layout_area!=g.area_id: reset_view_state()
	var current: Dictionary = {}
	for node in visible_nodes(): current[node] = state_for(node.x,node.y)
	var changed = current != _states or not is_equal_approx(_last_bank,g.bank)
	if _was_shop:
		for node in current:
			if not _states.has(node):
				feedback[node] = {"age":0.0,"kind":"reveal","from":current[node]}
			elif current[node] != _states[node]:
				var kind = "purchase" if current[node] == "owned" else ("unlock" if _states[node] == "locked" else "affordability")
				feedback[node] = {"age":0.0,"kind":kind,"from":_states[node]}
	else:
		feedback.clear()
	for node in feedback.keys():
		if not current.has(node): feedback.erase(node)
	for node in tap_feedback.keys():
		if not current.has(node): tap_feedback.erase(node)
	_states = current
	_last_bank = g.bank
	_was_shop = true
	if twin_selected and not twin_control_visible():
		twin_selected = false
		_card_bounce_age = -1.0
	if selected >= 0 and not node_visible(selected,tier):
		selected = -1
		_card_bounce_age = -1.0
	return changed

func animation_for(node: Vector2i) -> Dictionary:
	var result = {"scale":Vector2.ONE,"offset":Vector2.ZERO,"alpha":1.0,"blend":1.0}
	if feedback.has(node):
		var t = clampf(feedback[node].age / FEEDBACK_DURATION,0,1)
		result.blend = t
		if feedback[node].kind == "reveal": result.alpha = minf(1,t * 2.0)
		if not g.reduced_motion:
			var envelope = sin(t * PI)
			var squash = sin(t * TAU) * envelope
			result.scale = Vector2(1 + squash * .045,1 - squash * .07)
			result.offset = Vector2(0,-6 * envelope)
	if tap_feedback.has(node) and not g.reduced_motion:
		# A separate small response preserves any in-flight color/purchase cue.
		var t = clampf(tap_feedback[node] / TAP_DURATION,0,1)
		var envelope = sin(t * PI)
		var squash = sin(t * TAU) * envelope
		result.scale *= Vector2(1 + squash * .02,1 - squash * .025)
		result.offset.y -= 3 * envelope
	return result

func _request_redraw():
	g.queue_redraw()

func has_selection() -> bool:
	return (twin_selected and twin_control_visible()) or (selected >= 0 and node_visible(selected,tier))

func card_offset() -> Vector2:
	if _card_bounce_age<0 or g.reduced_motion or not has_selection(): return Vector2.ZERO
	return Vector2(0,-8.0*sin(PI*clampf(_card_bounce_age/CARD_BOUNCE_DURATION,0,1)))

func card_rect() -> Rect2:
	var rect = TWIN_CARD_RECT if twin_selected and twin_control_visible() else CARD_RECT
	return Rect2(rect.position+card_offset(),rect.size)

func buy_rect() -> Rect2:
	var rect = TWIN_BUY_RECT if twin_selected and twin_control_visible() else BUY_RECT
	return Rect2(rect.position+card_offset(),rect.size)

func paid_rect() -> Rect2:
	return Rect2(TWIN_PAID_RECT.position+card_offset(),TWIN_PAID_RECT.size)

func overlay_at(p: Vector2) -> bool:
	if MENU_RECT.has_point(p) or WALLET_RECT.has_point(p): return true
	if TREATS_RECT.has_point(p) or PLAY_RECT.has_point(p): return true
	if has_selection() and card_rect().has_point(p): return true
	if g.diagnostics_on and Rect2(24,1175,672,84).has_point(p): return true
	return g.note_time > 0 and Rect2(24,1190,672,60).has_point(p)

func map_input_at(p: Vector2) -> bool:
	return visual_area().has_point(p) and not overlay_at(p)

func _action_at(p: Vector2) -> String:
	if MENU_RECT.has_point(p): return "menu"
	if TREATS_RECT.has_point(p): return "treats"
	if PLAY_RECT.has_point(p): return "play"
	if twin_selected and twin_control_visible() and not special_owned():
		if paid_rect().has_point(p): return "cancel" if g.ability_ui.card_confirming() else "paid"
		if buy_rect().has_point(p): return "confirm" if g.ability_ui.card_confirming() else "buy"
	if has_selection() and buy_rect().has_point(p): return "buy"
	return ""

func _overlay_input(event) -> bool:
	# A finger starting on UI never becomes a map gesture. Activate on a clean
	# release, and disarm the entire UI touch sequence if another finger joins.
	var p = g.to_local(event.position)
	if event is InputEventScreenDrag:
		if not overlay_touches.has(event.index): return false
		if p.distance_to(_overlay_down) > 12: _overlay_tap = false
		return true
	if event.pressed and not event.canceled:
		if overlay_touches.is_empty():
			_overlay_primary = event.index
			_overlay_down = p
			_overlay_action = _action_at(p)
			_overlay_tap = _input_allowed() and not _overlay_action.is_empty()
		else:
			_overlay_tap = false
		overlay_touches[event.index] = p
		return true
	if not overlay_touches.has(event.index): return false
	var activate = not event.canceled and event.index == _overlay_primary and _overlay_tap and p.distance_to(_overlay_down) <= 12 and _action_at(p) == _overlay_action and _input_allowed()
	overlay_touches.erase(event.index)
	_overlay_tap = false
	if overlay_touches.is_empty():
		cancel_gestures()
		if activate: g.handle_press(p)
	return true

func _input_allowed() -> bool:
	return g.navigation_delay <= 0 and g.result_input_delay <= 0

func _reset_pinch_baseline():
	_pinch_ids.clear()
	if touch_points.size() >= 2:
		var ids = touch_points.keys()
		_pinch_ids = [ids[0],ids[1]]
		var a: Vector2 = touch_points[ids[0]]
		var b: Vector2 = touch_points[ids[1]]
		_pinch_mid = (a+b)*.5
		_pinch_distance = a.distance_to(b)
	elif touch_points.size() == 1:
		last = touch_points.values()[0]
		down = last

func _zoom_at(anchor: Vector2, requested: float):
	if not is_finite(requested): return
	_cancel_camera()
	var next = clampf(requested,minimum_zoom(),MAX_ZOOM)
	var world = (anchor-center()) / zoom
	zoom = next
	pan = anchor - ORIGIN - world*zoom
	_clamp_pan()

func _clamp_pan():
	# Bound the camera to revealed content, leaving enough room to bring every
	# leaf fully into the viewport even at maximum zoom and a capped branch.
	var nodes = visible_nodes()
	if nodes.is_empty():
		pan = Vector2.ZERO
		return
	var first = node_rect(nodes[0].x,nodes[0].y,false)
	var smallest_end = first.end-pan
	var largest_start = first.position-pan
	for node in nodes:
		var rect = node_rect(node.x,node.y,false)
		smallest_end = smallest_end.min(rect.end-pan)
		largest_start = largest_start.max(rect.position-pan)
	var minimum = focus_area().position+Vector2(24,24)-largest_start
	var maximum = focus_area().end-Vector2(24,24)-smallest_end
	pan = pan.clamp(minimum,maximum)

func handle_input(event) -> bool:
	if g.mode != "shop":
		cancel_gestures()
		return false
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: return false
		var p = g.to_local(event.position)
		if not map_input_at(p) or not overlay_touches.is_empty(): return false
		if event.pressed and _input_allowed():
			var amount = maxf(.1,absf(event.factor))
			_zoom_at(p,zoom*pow(1.12,amount if event.button_index == MOUSE_BUTTON_WHEEL_UP else -amount))
			_tap_candidate = false
			moved = true
			if not touch_points.is_empty(): _reset_pinch_baseline()
			_request_redraw()
		return true
	if event is InputEventScreenTouch:
		var p = g.to_local(event.position)
		if not overlay_touches.is_empty() or (event.pressed and touch_points.is_empty() and overlay_at(p)):
			return _overlay_input(event)
		if event.canceled:
			if not touch_points.has(event.index): return false
			touch_points.erase(event.index)
			_tap_candidate = false
			moved = true
			dragging = not touch_points.is_empty()
			_reset_pinch_baseline()
			return true
		if event.pressed:
			# Once a gesture starts, extra fingers belong to it even over Buy/Play.
			if touch_points.is_empty() and not visual_area().has_point(p): return false
			if not _input_allowed(): return true
			_cancel_camera()
			touch_points[event.index] = p
			dragging = true
			if touch_points.size() == 1:
				down = p
				last = p
				moved = false
				_tap_candidate = true
			else:
				moved = true
				_tap_candidate = false
			_reset_pinch_baseline()
			return true
		if not touch_points.has(event.index): return false
		var should_select = touch_points.size() == 1 and _tap_candidate and not moved and p.distance_to(down) <= 12
		touch_points.erase(event.index)
		dragging = not touch_points.is_empty()
		if not touch_points.is_empty():
			_tap_candidate = false
			moved = true
			_reset_pinch_baseline()
		else:
			cancel_gestures()
			if should_select and _input_allowed(): select_at(p)
		return true
	if event is InputEventScreenDrag:
		if not overlay_touches.is_empty(): return _overlay_input(event)
		if not touch_points.has(event.index): return false
		var p = g.to_local(event.position)
		touch_points[event.index] = p
		if not _input_allowed():
			_tap_candidate = false
			_reset_pinch_baseline()
			return true
		if touch_points.size() >= 2:
			var a: Vector2 = touch_points[_pinch_ids[0]]
			var b: Vector2 = touch_points[_pinch_ids[1]]
			var midpoint = (a+b)*.5
			var distance = a.distance_to(b)
			if _pinch_distance > 1 and distance > 1:
				_zoom_at(_pinch_mid,zoom*distance/_pinch_distance)
			pan += midpoint - _pinch_mid
			_clamp_pan()
			_pinch_mid = midpoint
			_pinch_distance = distance
			moved = true
			_tap_candidate = false
		else:
			if p.distance_to(down) > 12:
				moved = true
				_tap_candidate = false
			if moved:
				pan += p-last
				_clamp_pan()
			last = p
		_request_redraw()
		return true
	# Left mouse is already emulated as touch by the project. Do not process twice.
	return false

func select_at(p):
	if not map_input_at(p) or not _input_allowed(): return
	var nodes = visible_nodes()
	nodes.reverse()
	for node in nodes:
		var rect = node_rect(node.x,node.y)
		if rect.has_point(p):
			if node!=TWIN_NODE: g.ability_ui.cancel_card_purchase()
			g.feedback("ui_tap")
			twin_selected = node==TWIN_NODE
			selected = -1 if twin_selected else node.x
			tier = node.y
			_card_bounce_age = -1.0
			if not g.reduced_motion: tap_feedback[node] = 0.0
			_request_redraw()
			return

func press(p):
	if not _input_allowed() or not touch_points.is_empty() or not overlay_touches.is_empty(): return
	if selected_node()==MORE_JAM_NODE and more_jam_visible():
		if not buy_rect().has_point(p) or g.bakery_ability.quick_owned(): return
		if g.bakery_ability.quick_buy():
			g.note=""; g.note_time=0
			_card_bounce_age=-1.0 if g.reduced_motion else 0.0
		else:
			g.feedback("ui_error")
		_sync_states()
		_request_redraw()
		return
	if twin_selected and twin_control_visible():
		if special_owned(): return
		if g.ability_ui.card_confirming():
			if paid_rect().has_point(p):
				g.ability_ui.cancel_card_purchase()
				g.feedback("ui_back")
				g.navigation_delay=.25
			elif buy_rect().has_point(p):
				g.ability_ui.press_action("confirm")
			_sync_states()
			_request_redraw()
			return
		if paid_rect().has_point(p):
			g.ability_ui.buy_from_card()
			_sync_states()
			_request_redraw()
			return
		var requested = buy_rect().has_point(p)
		var purchased = special_buy() if requested else false
		if requested and not purchased and not special_owned(): g.feedback("ui_error")
		if purchased:
			g.note = ""
			g.note_time = 0
			_card_bounce_age = -1.0 if g.reduced_motion else 0.0
			_sync_states()
			if g.area_id=="gelato":
				twin_selected = false
				var rebuild = _nearest_rebuild_node(TWIN_NODE)
				selected = rebuild.x
				tier = rebuild.y
				if selected>=0: _frame_nodes([rebuild])
		_request_redraw()
		return
	if selected < 0 or not node_visible(selected,tier) or not buy_rect().has_point(p): return
	if not g.shop_node_unlocked(selected,tier):
		g.feedback("ui_error")
		return
	_sync_states()
	var before = visible_nodes()
	var bought = Vector2i(selected,tier)
	if g.buy_upgrade_node(selected,tier):
		# The tile pop and persistent ownership state already confirm the purchase.
		g.note = ""
		g.note_time = 0
		_sync_states()
		if more_jam_visible() and g.bakery_ability.quick_unlocked():
			twin_selected=false; selected=MORE_JAM_NODE.x; tier=MORE_JAM_NODE.y
			_frame_nodes([MORE_JAM_NODE])
		else:
			_select_next_upgrade(before,bought)
			_frame_new_upgrades(before)
	else:
		g.feedback("ui_error")
		_sync_states()
	_request_redraw()

func _nearest_rebuild_node(from: Vector2i) -> Vector2i:
	var result = Vector2i(-1,1)
	var distance = INF
	var origin: Vector2 = _positions.get(from,Vector2.ZERO)
	for node in g.upgrade_graph().nodes():
		if not is_reset_power(node.x,node.y) or not g.shop_node_unlocked(node.x,node.y): continue
		var candidate = origin.distance_squared_to(_positions.get(node,Vector2.ZERO))
		if candidate<distance:
			distance=candidate
			result=node
	return result

func _select_next_upgrade(before: Array[Vector2i], bought: Vector2i):
	# Follow a single newly revealed child. Mixed-family branches never jump
	# across the garden just because another node has the next saved ordinal.
	var next: Array[Vector2i] = []
	for node in visible_nodes():
		if node==MORE_JAM_NODE: continue
		if node not in before and bought in node_prerequisites(node): next.append(node)
	# A branch still needs the player's choice; never jump to another route or
	# across an already-owned legacy segment to fill an unrelated missing tier.
	if next.size()!=1: return
	twin_selected = next[0]==TWIN_NODE
	selected = -1 if twin_selected else next[0].x
	tier = next[0].y
	_card_bounce_age = -1.0 if g.reduced_motion else 0.0

func draw():
	_sync_states()
	# Paint the entire map first. Every fixed control is then painted above it.
	draw_map(g)
	g.button(MENU_RECT,"")
	for y in [-10,0,10]:
		g.draw_line(MENU_RECT.get_center()+Vector2(-15,y),MENU_RECT.get_center()+Vector2(15,y),g.WHITE,4,true)
	g.ui_panel(WALLET_RECT)
	g.ui_art.draw(g,"coin",Rect2(179,47,44,44))
	if g.developer_money_enabled():
		g.fitted_text("∞ · Developer money",Rect2(238,43,420,52),29,g.GOLD)
	else:
		g.fitted_number(g.credits_text(g.bank),Rect2(238,43,420,52),32,g.GOLD)
	if twin_selected and twin_control_visible():
		_draw_twin_card()
	elif selected_node()==MORE_JAM_NODE and more_jam_visible():
		_draw_more_jam_card()
	elif has_selection():
		g.draw_set_transform(card_offset(),0,Vector2.ONE)
		g.ui_panel(CARD_RECT)
		g.food_art.draw(g,ART[selected],Rect2(68,936,64,64))
		var owned = g.shop_node_owned(selected,tier)
		var shown_tier = tier if g.area_id!="gelato" else (g.levels[selected] if owned else mini(g.levels[selected]+1,g.MAX_LEVELS[selected]))
		var title = "Flight" if g.area_id=="crystal" and selected==2 else NAMES[selected]
		_card_label("%s · %d" % [title,shown_tier],CARD_TITLE_RECT,28,g.WHITE)
		if owned:
			_card_label("Complete" if shown_tier == g.MAX_LEVELS[selected] else "Owned",CARD_STATUS_RECT,22,g.MUTED)
			g.symbol("check",BUY_RECT.get_center(),38,g.TEAL)
		elif not g.shop_node_unlocked(selected,tier):
			_card_label("Follow the path",CARD_STATUS_RECT,21,g.MUTED)
			_purchase_button(BUY_RECT,"Locked",false)
		else:
			var cost = g.upgrade_cost(selected)
			var affordable = g.can_afford(cost)
			var label = "Buy · %s" % g.credits_text(cost)
			_purchase_button(BUY_RECT,label,affordable)
		_card_label(_effect_text(selected,tier),CARD_EFFECT_RECT,21,g.MUTED)
		g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	g.button(TREATS_RECT,"Treats")
	g.button(PLAY_RECT,"Play",true)

func _draw_more_jam_card():
	g.draw_set_transform(card_offset(),0,Vector2.ONE)
	g.ui_panel(CARD_RECT)
	g.bakery_ability.draw_icon(g,Rect2(68,936,64,64))
	_card_label("More Jam",CARD_TITLE_RECT,28,g.WHITE)
	_card_label(more_jam_gate_text(),CARD_STATUS_RECT,21,g.MUTED)
	_card_label("Jam every fourth doughnut.",CARD_EFFECT_RECT,21,g.MUTED)
	if g.bakery_ability.quick_owned():
		g.symbol("check",BUY_RECT.get_center(),38,g.TEAL)
	else:
		var available=g.bakery_ability.quick_unlocked()
		_purchase_button(BUY_RECT,"Unlock · Free" if available else "Locked",available)
	g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _twin_effect_lines() -> Array[String]:
	if g.area_id=="bakery": return g.ability_ui.effects()
	if g.area_id=="crystal": return ["Two prisms can appear each run.","Tap a prism to double live balls."]
	return ["Two slower launchers. Power starts over.","Power costs more and grows stronger."]

func _twin_gate_text() -> String:
	return "" if special_owned() else g.ability_ui.gate_text()

func _draw_twin_card():
	g.draw_set_transform(card_offset(),0,Vector2.ONE)
	g.ui_panel(TWIN_CARD_RECT)
	_draw_twin_icon(g,Rect2(68,796,64,64),Color.WHITE)
	_card_label(g.ability_ui.title(),TWIN_TITLE_RECT,27,g.WHITE)
	var offer=g.ability_access.offer(g.area_id,special_owned())
	if g.ability_ui.card_confirming():
		_card_label("Test purchase",Rect2(148,840,268,28),21,g.MUTED)
		_card_label("No charge",Rect2(148,874,268,28),21,g.MUTED)
	else:
		_card_label(_twin_gate_text(),TWIN_STATUS_RECT,21,g.MUTED)
	if special_owned():
		_purchase_button(TWIN_BUY_RECT,"Owned",false)
	elif g.ability_ui.card_confirming():
		_purchase_button(TWIN_BUY_RECT,"Confirm test",true)
		_purchase_button(TWIN_PAID_RECT,"Cancel",false)
	else:
		_purchase_button(TWIN_BUY_RECT,"Buy %s" % g.credits_text(special_cost()),special_unlocked() and g.can_afford(special_cost()) and not offer.pending and not g.ability_ui.can_restore())
		var paid_label="Restore" if g.ability_ui.can_restore() else ("Pending" if offer.pending else "Buy "+offer.price_label)
		_purchase_button(TWIN_PAID_RECT,paid_label,(offer.available or g.ability_ui.can_restore()) and not offer.pending)
	if not g.ability_ui.message.is_empty() and not special_owned():
		_card_label(g.ability_ui.message,TWIN_MESSAGE_RECT,19,g.MUTED)
	var lines = _twin_effect_lines()
	for line in range(lines.size()):
		_card_label(lines[line],TWIN_EFFECT_RECTS[line],21,g.MUTED)
	g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _effect_text(i: int, _n: int) -> String:
	if g.area_id=="crystal":
		if i==0: return "Fire candy faster"
		if i==2: return "Keep shots in play"
		if i==3: return "Stay in play longer when equipped"
	return g.UPGRADE_DESC[i] if i>=0 and i<g.UPGRADE_DESC.size() else ""

func card_font_size(value: String, rect: Rect2, requested: int) -> int:
	var fit = requested
	while fit>14 and (g.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x>rect.size.x or g.font.get_height(fit)>rect.size.y): fit -= 1
	return fit

func _card_label(value: String, rect: Rect2, requested: int, color: Color, centered: bool = false):
	g.fitted_text(value,rect,card_font_size(value,rect,requested),color,centered)

func _purchase_button(rect: Rect2, label: String, enabled: bool):
	g.button(rect,"",enabled)
	_card_label(label,rect.grow(-24),26,g.WHITE,true)

func _draw_twin_icon(canvas: CanvasItem, rect: Rect2, tint: Color):
	if g.area_id=="bakery":
		g.bakery_ability.draw_icon(canvas,rect,tint)
		return
	if g.area_id=="crystal":
		g.food_art.draw(canvas,"multiply_pickup",rect,tint)
		return
	# Two separate hopper silhouettes read as a pair at detail and overview zoom.
	var size = Vector2(rect.size.x*.56,rect.size.y*.9)
	g.food_art.draw(canvas,"hopper",Rect2(rect.position+Vector2(0,rect.size.y*.08),size),tint)
	g.food_art.draw(canvas,"hopper",Rect2(rect.position+Vector2(rect.size.x*.44,0),size),tint)

func _box(canvas: CanvasItem, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 23):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	canvas.draw_style_box(style,rect)

func _label(canvas: CanvasItem, value: String, rect: Rect2, size: int, color: Color, face: Font = null):
	if face == null: face = g.number_font
	var fit = size
	while fit > 12 and (face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x > rect.size.x or face.get_height(fit)>rect.size.y): fit -= 1
	var width = face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x
	var pos = Vector2(rect.position.x+(rect.size.x-width)*.5,rect.position.y+(rect.size.y-face.get_height(fit))*.5+face.get_ascent(fit))
	canvas.draw_string(face,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit,color)

func _check(canvas: CanvasItem, p: Vector2, color: Color):
	canvas.draw_polyline(PackedVector2Array([p+Vector2(-16,0),p+Vector2(-4,12),p+Vector2(21,-16)]),color,6,true)

func _tile_face(canvas: CanvasItem, state: String, rect: Rect2, alpha: float):
	if not SURFACE.has(state): return
	var tint = Color(.79,.79,.75,alpha) if state == "locked" else Color(1,1,1,alpha)
	if not g.ui_art.draw(canvas,SURFACE[state],rect,tint):
		_box(canvas,rect,Color(FALLBACK[state],alpha),Color("ba895d"),2)

func _dashed_trail(canvas: CanvasItem, path: PackedVector2Array, color: Color, width: float):
	# Keep future route segments readable at the overview, too.
	var dash = maxf(11.0*zoom,7.0)
	var period = maxf(19.0*zoom,12.0)
	var walked = 0.0
	for i in range(path.size()-1):
		var length = path[i].distance_to(path[i+1])
		if length < .001: continue
		var direction = (path[i+1]-path[i])/length
		var offset = 0.0
		while offset < length-.001:
			var phase = fposmod(walked+offset,period)
			var visible = phase < dash
			var step = minf(length-offset,(dash if visible else period)-phase)
			if step < .001: step = minf(.001,length-offset)
			if visible: canvas.draw_line(path[i]+direction*offset,path[i]+direction*(offset+step),color,width,true)
			offset += step
		walked += length

func draw_map(canvas: CanvasItem):
	var bounds = visual_area()
	if not arc_art.draw(canvas,g.area_id,bounds,center(),zoom):
		canvas.draw_rect(bounds,g.area_surface("background"))
		if not g.environment_art.draw_cover(canvas,"upgrade_counter",bounds):
			g.ui_art.surface(canvas,"upgrade_parchment",bounds)
	var nodes = visible_nodes()
	var parents = node_prerequisites(selected_node()) if has_selection() else []
	for node in nodes:
		for parent in node_prerequisites(node):
			if not node_visible(parent.x,parent.y): continue
			var path = route_points(parent,node)
			var active = g.shop_node_historical(parent.x,parent.y)
			var emphasized = selected_node()==node
			var owned = state_for(node.x,node.y)=="owned"
			var opacity = route_opacity(owned,emphasized)
			var ink = Color("355c43") if g.area_id == "bakery" else Color("615077")
			if emphasized: ink = g.TEAL
			var width = route_width(emphasized)
			# A light outer stroke separates the route from either illustrated ground.
			canvas.draw_polyline(path,Color(g.area_surface("panel"),opacity),width+3.0,true)
			if active:
				canvas.draw_polyline(path,Color(ink,opacity),width,true)
			else:
				_dashed_trail(canvas,path,Color(ink,.8 if not emphasized else opacity),width)
	for node in nodes:
		if not node_in_view(node.x,node.y): continue
		var state = state_for(node.x,node.y)
		var motion = animation_for(node)
		var screen_rect = node_rect(node.x,node.y)
		canvas.draw_set_transform(screen_rect.get_center(),0,screen_rect.size/TILE_SIZE)
		var rect = Rect2(-TILE_SIZE*.5,TILE_SIZE)
		var alpha: float = motion.alpha
		var detailed = detail_visible(node.x,node.y)
		if feedback.has(node) and feedback[node].from != state:
			_tile_face(canvas,feedback[node].from,rect,alpha)
			_tile_face(canvas,state,rect,alpha*motion.blend)
		else:
			_tile_face(canvas,state,rect,alpha)
		if selected_node()==node:
			if detailed:
				_box(canvas,rect.grow(3),Color.TRANSPARENT,Color("3d8673"),4,31)
				_box(canvas,rect.grow(7),Color.TRANSPARENT,Color("fff5de"),2,34)
			else:
				# Inset compact outlines preserve the two-pixel neighbor gap.
				_box(canvas,rect,Color.TRANSPARENT,Color("3d8673"),ceili(1.5*TILE_SIZE.x/screen_rect.size.x),23)
		elif node in parents:
			_box(canvas,rect.grow(2) if detailed else rect,Color.TRANSPARENT,Color("3d8673"),2 if detailed else ceili(TILE_SIZE.x/screen_rect.size.x),30)
		var portrait = PORTRAIT_RECT if detailed else Rect2(-80,-84,160,160)
		if node==MORE_JAM_NODE: g.bakery_ability.draw_icon(canvas,portrait,Color(1,1,1,alpha))
		elif node==TWIN_NODE: _draw_twin_icon(canvas,portrait,Color(1,1,1,alpha))
		else: g.food_art.draw(canvas,ART[node.x],portrait,Color(1,1,1,alpha))
		# Gelato's shuffled slot ordinals are internal identities, not effect
		# levels. Its card shows the current/next family level instead.
		if detailed and node!=TWIN_NODE and g.area_id!="gelato":
			canvas.draw_circle(Vector2(70,-70),18,Color(Color("fff1d8"),alpha))
			_label(canvas,"4" if node==MORE_JAM_NODE else str(node.y),Rect2(52,-88,36,36),27,Color(Color("594132"),alpha))
		if state == "owned":
			_check(canvas,Vector2(0,74),Color(Color("507963"),alpha))
		elif state == "locked":
			var lock_color = Color(Color("655f70") if g.area_id == "gelato" else Color("5c6858"),alpha)
			canvas.draw_arc(Vector2(0,67),12,PI,TAU,16,lock_color,6,true)
			_box(canvas,Rect2(-17,66,34,25),lock_color,Color.TRANSPARENT,0,5)
		else:
			var marker = Vector2(-74,-74) if detailed else Vector2(0,74)
			canvas.draw_circle(marker,16,Color(Color("fff1d8"),alpha))
			canvas.draw_line(marker+Vector2(-10,0),marker+Vector2(10,0),Color(Color("594132"),alpha),4,true)
			if state == "affordable": canvas.draw_line(marker+Vector2(0,-10),marker+Vector2(0,10),Color(Color("594132"),alpha),4,true)
			if detailed:
				_box(canvas,Rect2(-82,54,164,36),Color(Color("fff1d8"),alpha),Color(Color("c2996d"),alpha),1,14)
				if node==MORE_JAM_NODE:
					_label(canvas,"Free",Rect2(-76,58,152,28),28,Color(Color("513c2c"),alpha))
				else:
					g.ui_art.draw(canvas,"coin",Rect2(-76,58,28,28),Color(1,1,1,alpha))
					_label(canvas,g.credits_text(node_cost(node)),Rect2(-42,58,116,28),28,Color(Color("513c2c"),alpha))
		canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
