extends RefCounted
## Explicit reset confirmation. A completed, single-contact tap is required;
## the Settings opener, keyboard repeats and stray releases cannot confirm it.
const PANEL_RECT = Rect2(48,280,624,760)
const CANCEL_RECT = Rect2(80,764,560,100)
const RESET_RECT = Rect2(80,888,560,100)
const DESTRUCTIVE_INK = Color("9a3648")

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

func _target_at(p: Vector2) -> String:
	if CANCEL_RECT.has_point(p): return "cancel"
	if RESET_RECT.has_point(p): return "reset"
	return ""

func handle_input(event) -> bool:
	if g.mode != "reset_confirm": return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE and g.navigation_delay <= 0.0:
			cancel_gestures()
			g.cancel_progress_reset()
		# Enter and Space intentionally never confirm destructive changes.
		return true
	if event is InputEventScreenTouch:
		var p: Vector2 = g.to_local(event.position)
		if event.pressed:
			_touches[event.index] = p
			if _touches.size() == 1:
				_primary = event.index
				_down = p
				_target = _target_at(p)
				_tap = _target != "" and g.navigation_delay <= 0.0
			else:
				_tap = false
		else:
			if not _touches.has(event.index): return true
			_touches.erase(event.index)
			var activate: bool = not event.canceled and event.index == _primary and _tap and _touches.is_empty() and g.navigation_delay <= 0.0 and p.distance_to(_down) <= 14.0 and _target_at(p) == _target
			var target = _target
			if event.index == _primary: _tap = false
			if _touches.is_empty(): cancel_gestures()
			if activate:
				if target == "cancel": g.cancel_progress_reset()
				elif target == "reset": g.reset_progress()
		return true
	if event is InputEventScreenDrag:
		if _touches.has(event.index):
			var p: Vector2 = g.to_local(event.position)
			_touches[event.index] = p
			if event.index == _primary and p.distance_to(_down) > 14.0: _tap = false
		return true
	# Mouse is emulated as touch by project settings. Consume its original events
	# and every other event so the covered Settings controls never receive input.
	return true

func draw():
	if g.mode != "reset_confirm": return
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect(),Color(g.area_surface("overlay"),.62))
	g.ui_panel(PANEL_RECT)
	g.heading_centered("Reset all progress?",354,42)
	g.draw_line(Vector2(80,385),Vector2(640,385),Color("c8d8c6"),2.0,true)
	g.fitted_text("Coins, upgrades, completed trays, areas",Rect2(80,417,560,36),26,g.WHITE,true)
	g.fitted_text("and trial records will be cleared.",Rect2(80,453,560,36),26,g.WHITE,true)
	g.fitted_text("Purchased area abilities can be restored.",Rect2(80,505,560,36),24,g.MUTED,true)
	g.fitted_text("Start again at Bakery, tray 1, with Mabel.",Rect2(80,568,560,36),26,g.WHITE,true)
	g.fitted_text("Sound and motion settings stay the same.",Rect2(80,614,560,36),25,g.MUTED,true)
	g.fitted_text("This cannot be undone.",Rect2(80,687,560,38),27,DESTRUCTIVE_INK,true)
	g.button(CANCEL_RECT,"Cancel",true)
	g.button(RESET_RECT,"")
	g.box(RESET_RECT.grow(-3),Color.TRANSPARENT,24,Color("d87388"))
	g.fitted_text("Reset progress",RESET_RECT.grow(-22),29,DESTRUCTIVE_INK,true)
