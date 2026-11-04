extends RefCounted
## The home tray is a visual preview of the selected board, never a live run.
const LEVEL_RECT = Rect2(36,32,548,100)
const MENU_RECT = Rect2(604,32,80,100)
const WALLET_RECT = Rect2(72,148,576,76)
const TRAY_RECT = Rect2(40,264,640,690)
const PEG_RECT = Rect2(90,350,540,440)
const PLAY_RECT = Rect2(48,984,624,92)
const UPGRADES_RECT = Rect2(48,1088,624,96)
const MENU_PANEL = Rect2(360,148,324,350)
const SETTINGS_RECT = Rect2(382,170,280,92)
const HELP_RECT = Rect2(382,276,280,92)
const TRIALS_RECT = Rect2(382,382,280,92)
const COPPER = Color("b8753d")

var g
var menu_open = false
var touches: Dictionary = {}
var _primary = -1
var _down = Vector2.ZERO
var _target = ""
var _tap = false

func _init(game):
	g = game

func reset():
	menu_open = false
	cancel_gestures()

func cancel_gestures():
	touches.clear()
	_primary = -1
	_target = ""
	_tap = false

func close_menu() -> bool:
	if not menu_open: return false
	g.feedback("ui_back")
	reset()
	g.queue_redraw()
	return true

func target_at(p: Vector2) -> String:
	if MENU_RECT.has_point(p): return "menu"
	if menu_open:
		if SETTINGS_RECT.has_point(p): return "settings"
		if HELP_RECT.has_point(p): return "help"
		if TRIALS_RECT.has_point(p): return "trials"
		return "dismiss"
	if LEVEL_RECT.has_point(p): return "levels"
	# The preview tray and Play button share one guarded tap action.
	if PLAY_RECT.has_point(p) or TRAY_RECT.has_point(p): return "play"
	if UPGRADES_RECT.has_point(p): return "upgrades"
	return ""

func handle_input(event) -> bool:
	if g.mode != "home": return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and menu_open:
		if not event.echo: close_menu()
		return true
	if event is InputEventScreenTouch:
		var p: Vector2 = g.to_local(event.position)
		if event.pressed:
			touches[event.index] = p
			if touches.size() == 1:
				_primary = event.index
				_down = p
				_target = target_at(p)
				_tap = g.navigation_delay <= 0.0 and _target != ""
			else:
				_tap = false
		else:
			if not touches.has(event.index): return true
			touches.erase(event.index)
			var activate: bool = not event.canceled and event.index == _primary and _tap and touches.is_empty() and p.distance_to(_down) <= 14.0 and target_at(p) == _target
			if event.index == _primary: _tap = false
			if touches.is_empty(): cancel_gestures()
			if activate: g.handle_press(p)
		return true
	if event is InputEventScreenDrag:
		if touches.has(event.index):
			var p: Vector2 = g.to_local(event.position)
			touches[event.index] = p
			if event.index == _primary and p.distance_to(_down) > 14.0: _tap = false
		return true
	return false

func press(p: Vector2):
	match target_at(p):
		"menu":
			menu_open = not menu_open
			g.feedback("ui_tap" if menu_open else "ui_back")
		"dismiss":
			menu_open = false
			g.feedback("ui_back")
		"settings": reset(); g.mode = "support"
		"help": reset(); g.mode = "guide"
		"trials": reset(); g.mode = "trials"
		"levels":
			reset()
			g.level_map.open()
			g.mode = "boards"
		"play": reset(); g.start_shift(true)
		"upgrades": reset(); g.mode = "shop"; g.return_mode = "home"
	g.queue_redraw()

func draw():
	_draw_preview()
	draw_controls()
	if menu_open: _draw_menu()

func draw_controls(departure: float = 0.0):
	if departure >= 1.0: return
	g.draw_set_transform(Vector2(0,-270.0*departure))
	_draw_level_selector()
	_draw_menu_button()
	_draw_wallet()
	g.draw_set_transform(Vector2(0,330.0*departure))
	_draw_action_button(PLAY_RECT,"Play","play",true)
	_draw_action_button(UPGRADES_RECT,"Upgrades","upgrade")
	g.draw_set_transform(Vector2.ZERO)

func _draw_action_button(rect: Rect2, label: String, icon: String, primary: bool = false):
	# The symbol and label form one centered group inside the existing hitbox.
	g.button(rect,"",primary)
	var text_font: Font = g.display_font if primary else g.font
	var size = 30 if primary else 28
	var icon_size = 38.0
	var gap = 16.0
	var width: float = text_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	while size>18 and width+icon_size+gap>rect.size.x-56.0:
		size-=1
		width=text_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var left = rect.get_center().x-(width+icon_size+gap)*.5
	g.symbol(icon,Vector2(left+icon_size*.5,rect.get_center().y),icon_size,g.TEAL)
	var baseline = Vector2(left+icon_size+gap,rect.get_center().y+(text_font.get_ascent(size)-text_font.get_descent(size))*.5)
	if primary: g.heading(label,baseline,size)
	else: g.text_at(label,baseline,size)

func _draw_level_selector():
	if not g.ui_art.skin(g,"level_selector",LEVEL_RECT): g.ui_panel(LEVEL_RECT)
	var points = PackedVector2Array()
	for step in range(25):
		var t = step / 24.0
		points.append(Vector2(91 + sin(t*TAU)*15.0,100-t*40.0))
	g.draw_polyline(points,COPPER,3.0,true)
	g.draw_circle(points[0],7.0,g.TEAL)
	g.draw_circle(points[24],7.0,g.GOLD)
	var label = "%s · %d / 12" % [g.area_title(),g.current_level]
	var size = 32
	while size > 23 and g.display_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > 365.0: size -= 1
	var baseline = LEVEL_RECT.get_center().y + (g.display_font.get_ascent(size)-g.display_font.get_descent(size))*.5
	var tier_label: String = g.food_art.tier_label(g.peg_strength_tier())
	if not tier_label.is_empty(): baseline -= 12.0
	g.heading(label,Vector2(135,baseline),size)
	if not tier_label.is_empty():
		g.fitted_text("%s · normal pegs: %d HP" % [tier_label,ceili(g.normal_peg_hp(-1,false,g.FlowRules.CURRENT_REVISION))],Rect2(135,86,365,24),20,g.MUTED)
	g.draw_polyline(PackedVector2Array([Vector2(540,67),Vector2(553,82),Vector2(540,97)]),COPPER,4.5,true)

func _draw_menu_button():
	g.button(MENU_RECT,"")
	g.symbol("settings",MENU_RECT.get_center()-Vector2(0,2),43.0)

func _draw_wallet():
	var value: String = g.credits_text(g.bank)
	var size = 38
	while size > 22 and g.number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > WALLET_RECT.size.x-70.0: size -= 1
	var width: float = g.number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var left: float = WALLET_RECT.get_center().x-(width+66.0)*.5
	g.ui_art.draw(g,"coin",Rect2(left,WALLET_RECT.position.y+12,52,52))
	g.bank_coin_feedback.draw(g,value,Rect2(left+58,WALLET_RECT.position.y,width+24,WALLET_RECT.size.y),g.number_font,size,g.GOLD,g.reduced_motion)

func preview_pegs() -> Array:
	var level: int = clampi(g.current_level,1,12)
	var spec: Dictionary = g.board_data[level-1] if level <= g.board_data.size() else {}
	var count = int(spec.get("peg_count",24+mini(22,(level-1)*2)))
	var armor = int(spec.get("armored_count",1 if level >= 10 else 0))
	var clock_count = int(spec.get("clock_peg_count",0 if level == 1 else 2))
	var pegs: Array = []
	for i in range(count):
		var kind = "normal"
		if armor > 0 and i < armor: kind = "armored"
		elif i >= count-clock_count: kind = "clock"
		elif level >= 3 and i%13 == 7: kind = "prism"
		pegs.append({"p":g.board_peg_position(i,spec),"kind":kind})
	return pegs

func preview_layout() -> Array:
	# Uniform scale keeps the actual arrangement, distances and cookie roles.
	var pegs = preview_pegs()
	var layout: Array = []
	if pegs.is_empty(): return layout
	var low: Vector2 = pegs[0].p
	var high: Vector2 = low
	for peg in pegs:
		low = low.min(peg.p)
		high = high.max(peg.p)
	var span = high-low
	var fit = minf(.96,minf((PEG_RECT.size.x-56.0)/maxf(1.0,span.x),(PEG_RECT.size.y-56.0)/maxf(1.0,span.y)))
	var origin = (low+high)*.5
	for peg in pegs:
		layout.append({"p":PEG_RECT.get_center()+(peg.p-origin)*fit,"kind":peg.kind,"scale":fit})
	return layout

func _draw_preview():
	if not g.food_art.draw_tray(g,TRAY_RECT): g.ui_panel(TRAY_RECT)
	var tier: String = g.peg_strength_tier()
	var hp: float = g.normal_peg_hp(-1,false,g.FlowRules.CURRENT_REVISION)
	for peg in preview_layout():
		g.food_art.draw_cookie(g,peg.kind,hp,hp,peg.p,Vector2.ONE*49.0*peg.scale,tier)

func _draw_menu():
	g.draw_rect(g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect(),Color(g.area_surface("overlay"),.22))
	g.ui_panel(MENU_PANEL)
	g.button(SETTINGS_RECT,"Settings")
	g.button(HELP_RECT,"Help")
	g.button(TRIALS_RECT,"Trials")
	_draw_menu_button()
