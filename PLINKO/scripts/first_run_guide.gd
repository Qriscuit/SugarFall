extends RefCounted
## Guided first loop. Owns presentation and teaching state, never the economy.
const VERSION = 2
const SpeechBubble = preload("res://scripts/speech_bubble.gd")
const HOST_PATH = "res://data/art/host/mabel_welcome.png"
const STEPS = ["play", "aim_drag", "playing", "earned", "time_pickup", "collect", "upgrades", "retry", "buy", "again"]
const LEGACY_STEPS = {"welcome":"play", "aim":"aim_drag", "feed":"buy", "improved":"again"}
const SKIP_RECT = Rect2(548,132,148,72)
const BOARD_INPUT = Rect2(48,272,624,512)
const COLLECT_RECT = Rect2(60,800,600,96)
const PAUSE_RECT = Rect2(580,22,104,96)
const INK = Color("443b32")
const MINT = Color("3d8673")
const CREAM = Color("fffaf0")

var g
var active = false
var completed = false
var step_id = "play"
var earned_seen = false
var time_pickup_seen = false
var upgraded_this_intro = false
var revealed = 0.0
var age = 0.0
var host: Texture2D
var host_region = Rect2()
## Authoring controls, never exposed to players. Size follows the complete message.
var bubble_options = {"max_width":410.0,"min_width":264.0,"padding":23.0,"radius":30.0,"font_size":28,"title_size":27,"hint_size":22,"line_height":35.0}
var _bubble_cache_key = ""
var _bubble_cache: Dictionary = {}
var _primary = -1
var _down = Vector2.ZERO
var _target = ""
var _tap = false
var _aim_candidate = false
var _pickup_candidate = false
var _touches: Dictionary = {}

func _init(game):
	g = game

func load_assets():
	if ResourceLoader.exists(HOST_PATH):
		host = load(HOST_PATH)
		if host != null:
			var source = host.get_image()
			host_region = Rect2(source.get_used_rect()) if source != null else Rect2(Vector2.ZERO,host.get_size())

func reset():
	active = false
	completed = false
	step_id = "play"
	earned_seen = false
	time_pickup_seen = false
	upgraded_this_intro = false
	revealed = 0.0
	age = 0.0
	cancel_gestures()

func maybe_begin():
	if not completed and not active and g.mode == "home" and not g.profile_load_blocked and g.area_id == "bakery": begin()

func begin(persist: bool = true):
	if g.area_id != "bakery" or g.profile_load_blocked: return
	active = true
	completed = false
	earned_seen = false
	time_pickup_seen = false
	upgraded_this_intro = false
	g.home_menu.reset()
	_set_step("play",persist)

func replay():
	if g.area_id != "bakery" or g.trial_active or g.mode not in ["guide","home"]: return
	g.mode = "home"
	g.note_time = 0
	begin()

func export_state() -> Dictionary:
	return {"version":VERSION,"completed":completed,"active":active,"step":step_id,"earned_seen":earned_seen,"time_pickup_seen":time_pickup_seen,"upgraded_this_intro":upgraded_this_intro}

func import_state(value, existing_profile: bool):
	reset()
	# Profiles created before the guide keep their uninterrupted return experience.
	# JSON decodes version numbers as floats; numeric equality preserves those saves.
	if not value is Dictionary or typeof(value.get("version",0)) not in [TYPE_INT,TYPE_FLOAT] or (value.get("version",0) != 1 and value.get("version",0) != VERSION):
		completed = existing_profile
		return
	var saved_step = str(value.get("step",""))
	saved_step = LEGACY_STEPS.get(saved_step,saved_step)
	if typeof(value.get("completed")) != TYPE_BOOL or typeof(value.get("active")) != TYPE_BOOL or saved_step not in STEPS:
		completed = existing_profile
		return
	completed = value.completed
	active = value.active and not completed and g.area_id == "bakery" and not g.trial_active
	step_id = saved_step
	earned_seen = value.get("earned_seen",false) == true
	time_pickup_seen = typeof(value.get("time_pickup_seen",false)) == TYPE_BOOL and value.get("time_pickup_seen",false)
	upgraded_this_intro = value.get("upgraded_this_intro",false) == true
	if not active: return
	# The saved gameplay/result is authoritative if the last presentation save was interrupted.
	if g.mode == "result": step_id = "collect"
	elif g.mode in ["play","paused"]:
		if step_id not in ["aim_drag","playing","earned","time_pickup"]: step_id = "playing"
		if step_id == "time_pickup" and (time_pickup_seen or _live_time_pickup().is_empty() or g.clear_draining): step_id = "playing"
	elif g.mode == "home":
		if step_id in ["buy","upgrades","collect","playing","earned","aim_drag","retry","time_pickup"]:
			step_id = "again" if g.levels[0] > 0 else ("upgrades" if g.bank >= g.upgrade_cost(0) else "retry")
	if g.mode == "shop" and step_id == "buy": _select_feed()
	revealed = float(dialogue().length())

func _persist():
	if not g.testing: g.save_game()

func _set_step(next: String, persist: bool = true):
	step_id = LEGACY_STEPS.get(next,next)
	if step_id == "buy" and g.mode == "shop": _select_feed()
	revealed = float(dialogue().length())
	age = 0.0
	cancel_gestures()
	g.queue_redraw()
	if persist: _persist()

func finish():
	active = false
	completed = true
	cancel_gestures()
	g.queue_redraw()
	_persist()

func on_run_started():
	if not active: return
	if step_id == "again":
		active = false
		completed = true
		cancel_gestures()
	elif step_id == "play": _set_step("aim_drag",false)
	else: _set_step("playing",false)

func on_result():
	if active: _set_step("collect",false)

func on_collected():
	if not active: return
	_set_step("again" if g.levels[0] > 0 else ("upgrades" if g.bank >= g.upgrade_cost(0) else "retry"),false)

func on_upgrade_bought(i):
	if active and i == 0 and step_id == "buy":
		upgraded_this_intro = true
		_set_step("again",false)

func _live_time_pickup() -> Dictionary:
	for pickup in g.pickups:
		if pickup.life > 0: return pickup
	return {}

func time_pickup_position() -> Vector2:
	return _live_time_pickup().get("p",Vector2(360,520))

func on_time_pickup_spawned() -> bool:
	if not active or time_pickup_seen or step_id != "playing" or g.mode != "play" or g.trial_active or g.clear_draining or g.run_transition.active: return false
	if _live_time_pickup().is_empty(): return false
	# The caller returns from the spawn tick before the pickup can age or move.
	_set_step("time_pickup")
	return true

func on_time_pickup_collected():
	if not active: return
	time_pickup_seen = true
	if step_id == "time_pickup": _set_step("playing")

func _collect_time_pickup(p: Vector2):
	if step_id == "time_pickup" and g.navigation_delay <= 0:
		g.collect_pickups(g.screen_to_board(p))

func update(delta: float) -> bool:
	if not active: return false
	if not is_finite(delta) or delta <= 0: return false
	if g.mode in ["paused","abandon_confirm"]: return false
	if g.run_transition.active: return false
	age += minf(delta,.1)
	revealed = float(dialogue().length())
	if g.mode == "home" and step_id == "buy":
		_set_step("again" if g.levels[0] > 0 else ("upgrades" if g.bank >= g.upgrade_cost(0) else "retry"))
	if step_id == "time_pickup" and (_live_time_pickup().is_empty() or g.clear_draining):
		_set_step("playing")
	# Also recover a live pickup saved just before its lesson was presented.
	if step_id == "playing" and on_time_pickup_spawned(): return true
	if step_id == "playing" and g.mode == "play" and not earned_seen and g.shift_coins >= 1.0:
		earned_seen = true
		_set_step("earned")
	if step_id == "upgrades" and g.mode == "shop":
		g.upgrade_map.reset_view_state()
		_set_step("buy")
	return true

func blocks_simulation() -> bool:
	return active and step_id in ["aim_drag","earned","time_pickup"] and g.mode == "play"

func visible() -> bool:
	return active and g.mode in ["home","play","result","shop"] and not g.run_transition.active

func _select_feed():
	g.upgrade_map.selected = 0
	g.upgrade_map.tier = 1

func uses_mouse_controls() -> bool:
	return OS.has_feature("windows")

func dialogue() -> String:
	match step_id:
		"play": return "Hit cookies to earn coins. Tap Play."
		"aim_drag": return "Donuts drop automatically. Hold left click and move to aim at cookies." if uses_mouse_controls() else "Donuts drop automatically. Drag to aim at cookies."
		"earned": return "Hits earn coins. Destroy every cookie to clear the tray before time runs out."
		"time_pickup": return "Hold left click over the circle for up to 2 extra seconds." if uses_mouse_controls() else "Touch the circle for up to 2 extra seconds."
		"collect": return "Collect your coins, even if the tray isn't clear."
		"upgrades": return "Tap Upgrades to make the dispenser faster."
		"retry": return "Earn %s more coins for Feed 1. Tap Play." % g.credits_needed_text(g.upgrade_cost(0)-g.bank)
		"buy": return "Buy Feed 1 for %s coins. It drops donuts faster." % g.credits_text(g.upgrade_cost(0))
		"again": return "Your dispenser drops faster. Tap Play."
	return ""

func _dialogue_step() -> bool:
	return step_id == "earned"

func _ready_text() -> bool:
	return revealed >= dialogue().length()

func advance():
	if not active: return
	g.feedback("ui_tap")
	# A tap advances immediately, even if an older caller supplied partial text.
	if step_id == "earned": _set_step("playing")
	else:
		revealed = float(dialogue().length())
		g.queue_redraw()

func bubble_layout() -> Dictionary:
	var key = dialogue()+step_id+JSON.stringify(bubble_options)
	if key != _bubble_cache_key:
		_bubble_cache_key = key
		_bubble_cache = SpeechBubble.measure(g.font,g.display_font,dialogue(),"Mabel",_ready_hint(),bubble_options)
	return _bubble_cache

func _ready_hint() -> String:
	if _dialogue_step(): return "Tap anywhere to continue  ›"
	if step_id == "aim_drag": return "Hold left click and move" if uses_mouse_controls() else "Drag across the tray"
	if step_id == "time_pickup": return "Hold left click over the circle" if uses_mouse_controls() else "Touch or drag over the circle"
	return "Try the highlighted action"

func portrait_rect() -> Rect2:
	var top = 586.0
	if step_id == "collect": top = 382.0
	elif step_id in ["buy","again"] and g.mode == "shop": top = 242.0
	elif step_id in ["aim_drag","earned","time_pickup"]: top = 828.0
	var slot = Rect2(4,top,220,330)
	if host_region.size.x <= 0 or host_region.size.y <= 0: return slot
	var fit = minf(slot.size.x/host_region.size.x,slot.size.y/host_region.size.y)
	var size = host_region.size*fit
	return Rect2(slot.position+Vector2((slot.size.x-size.x)*.5,slot.size.y-size.y),size)

func bubble_anchor() -> Vector2:
	var portrait = portrait_rect()
	return portrait.position+portrait.size*Vector2(.60,.25)

func bubble_rect() -> Rect2:
	var portrait = portrait_rect()
	var size: Vector2 = bubble_layout().size
	return Rect2(Vector2(224,portrait.position.y+34),size)

func action_rect() -> Rect2:
	match step_id:
		"play","retry": return g.home_menu.PLAY_RECT
		"aim_drag": return BOARD_INPUT
		"time_pickup":
			var center: Vector2 = g.board_to_screen(time_pickup_position())
			return Rect2(center-Vector2.ONE*45*g.BOARD_SCALE,Vector2.ONE*90*g.BOARD_SCALE)
		"collect": return COLLECT_RECT
		"upgrades": return g.home_menu.UPGRADES_RECT
		"buy": return g.upgrade_map.buy_rect()
		"again": return g.upgrade_map.PLAY_RECT if g.mode == "shop" else g.home_menu.PLAY_RECT
	return Rect2()

func _target_at(p: Vector2) -> String:
	if not Rect2(0,0,g.WIDTH,g.HEIGHT).has_point(p): return ""
	if SKIP_RECT.has_point(p): return "skip"
	if step_id == "playing": return ""
	if g.mode == "play" and PAUSE_RECT.has_point(p): return "pause"
	if action_rect().has_point(p): return "action"
	# The whole canvas can reveal or continue dialogue. Actual gameplay lessons
	# still complete only through their highlighted control or collection gesture.
	return "dialogue"

func cancel_gestures():
	_primary = -1
	_target = ""
	_tap = false
	_aim_candidate = false
	_pickup_candidate = false
	_touches.clear()

func handle_input(event) -> bool:
	if not visible(): return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
			advance()
			return true
		return false
	if event is InputEventMouseButton: return step_id != "playing"
	if event is InputEventMouseMotion:
		# Windows mouse presses and drags arrive as emulated touch events.
		if step_id == "time_pickup" and not OS.has_feature("windows"):
			_collect_time_pickup(g.to_local(event.position))
			return true
		return step_id != "playing"
	if event is InputEventScreenTouch:
		var p: Vector2 = g.to_local(event.position)
		var free_play = step_id == "playing"
		var consumed = not free_play or _target == "skip" or _target_at(p) == "skip"
		if event.pressed:
			var hit = _target_at(p)
			_touches[event.index] = p
			if _touches.size() == 1:
				_primary = event.index
				_down = p
				_target = hit
				_tap = hit != "" and g.navigation_delay <= 0 and not event.canceled
				_aim_candidate = _tap and hit == "action" and step_id == "aim_drag"
				_pickup_candidate = step_id == "time_pickup" and hit in ["dialogue","action"] and not bubble_rect().has_point(p) and g.navigation_delay <= 0 and not event.canceled
				if _pickup_candidate: _collect_time_pickup(p)
			else:
				_tap = false
				_aim_candidate = false
				_pickup_candidate = false
		else:
			if not _touches.has(event.index): return step_id != "playing"
			_touches.erase(event.index)
			var activate: bool = not event.canceled and event.index == _primary and _tap and _touches.is_empty() and g.navigation_delay <= 0 and p.distance_to(_down) <= 14 and _target_at(p) == _target
			var target = _target
			if event.index == _primary: _tap = false
			if _touches.is_empty(): cancel_gestures()
			if activate: _activate(target,p)
		return consumed
	if event is InputEventScreenDrag:
		if not _touches.has(event.index): return step_id != "playing"
		var consumed = step_id != "playing" or _target == "skip"
		var p: Vector2 = g.to_local(event.position)
		_touches[event.index] = p
		if event.index == _primary and p.distance_to(_down) > 14: _tap = false
		if step_id == "time_pickup" and _pickup_candidate and event.index == _primary and _touches.size() == 1:
			_collect_time_pickup(p)
			return true
		if not BOARD_INPUT.has_point(p): _aim_candidate = false
		if event.index == _primary and p.distance_to(_down) > 14:
			_tap = false
			if step_id == "aim_drag" and _aim_candidate and _touches.size() == 1 and _ready_text() and BOARD_INPUT.has_point(p) and absf(p.x-_down.x) >= 24:
				var board: Vector2 = g.screen_to_board(p)
				g.aim_x = clampf(board.x,66,654)
				g.aim_y = clampf(board.y,330,770)
				_set_step("playing")
		return consumed
	return step_id != "playing"

func _activate(target: String, p: Vector2):
	if target == "skip": finish(); return
	if target == "pause": g.handle_press(p); return
	if target == "dialogue": advance(); return
	if target != "action": return
	if step_id == "aim_drag": return
	if step_id == "time_pickup":
		_collect_time_pickup(p)
		return
	g.handle_press(p)
	if step_id == "upgrades" and g.mode == "shop":
		g.upgrade_map.reset_view_state()
		_set_step("buy")

func _focus() -> Vector3:
	if step_id == "aim_drag": return Vector3(360,520,230)
	if step_id == "earned": return Vector3(298,70,118)
	if step_id == "time_pickup":
		var center: Vector2 = g.board_to_screen(time_pickup_position())
		return Vector3(center.x,center.y,76)
	var rect = action_rect()
	if rect.size.x > 0: return Vector3(rect.get_center().x,rect.get_center().y,minf(170,maxf(85,rect.size.x*.55)))
	return Vector3(360,435,190)

func _draw_spotlight():
	var focus = _focus()
	var center = Vector2(focus.x,focus.y)
	var radius = focus.z
	var dim = Color("243b32")
	dim.a = .63
	# The outside of a circle is tessellated directly: no full-screen image capture,
	# shader dependency, or changed gameplay/input coordinates.
	for n in range(80):
		var a = Vector2.from_angle(float(n)*TAU/80)
		var b = Vector2.from_angle(float(n+1)*TAU/80)
		g.draw_colored_polygon(PackedVector2Array([center+a*radius,center+a*2400,center+b*2400,center+b*radius]),dim)
	var pulse = 0.0 if g.reduced_motion else sin(age*3.0)*3.0
	g.draw_arc(center,radius+pulse,0,TAU,80,Color("f4d79e"),4,true)
	g.draw_arc(center,radius+8+pulse,0,TAU,80,Color(1,.95,.8,.22),2,true)
	var rect = action_rect()
	if rect.size.x > 0 and step_id not in ["aim_drag","time_pickup"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color("ffe4a4")
		style.set_border_width_all(3)
		style.set_corner_radius_all(24)
		g.draw_style_box(style,rect.grow(5))

func _draw_magnifier():
	if step_id != "earned": return
	var center = Vector2(560,285)
	var from = Vector2(340,95)
	g.draw_line(from,center,Color("f4d79e"),3,true)
	g.draw_circle(center,88,CREAM)
	g.draw_arc(center,88,0,TAU,60,Color("b8753d"),4,true)
	g.ui_art.draw(g,"coin",Rect2(center-Vector2(62,55),Vector2(72,72)))
	g.fitted_number(g.credits_text(g.shift_coins),Rect2(center+Vector2(6,-44),Vector2(65,64)),40,g.GOLD,true)
	g.fitted_text("earned",Rect2(center+Vector2(-62,30),Vector2(124,28)),22,INK,true)

func _wrapped_lines(value: String, max_width: float, size: int) -> Array[String]:
	return SpeechBubble.wrap_text(g.font,value,max_width,size)

func _draw_bubble():
	var rect = bubble_rect()
	var portrait = portrait_rect()
	if host != null and host_region.size.x > 0 and host_region.size.y > 0:
		g.draw_texture_rect_region(host,portrait,host_region)
	var prompt = _ready_hint()
	var progress = 1.0 if g.reduced_motion else 1.0-pow(1.0-clampf(age/.22,0,1),3)
	SpeechBubble.draw(g,bubble_layout(),rect,bubble_anchor(),int(revealed),prompt,progress)

func draw():
	if not visible(): return
	g.draw_set_transform(Vector2.ZERO)
	if step_id != "playing":
		_draw_spotlight()
		_draw_magnifier()
		_draw_bubble()
	g.box(SKIP_RECT,Color("fffaf0"),18,Color("c9b997"))
	g.fitted_text("Skip intro",SKIP_RECT.grow(-8),21,INK,true)
