extends RefCounted
## Presentation only. The initialized run remains frozen until this settles.
const DURATION = .42
var g
var active = false
var time = DURATION
var preview: Array = []

func _init(game):
	g = game

func begin():
	finish()
	if g.reduced_motion: return
	preview = g.home_menu.preview_layout()
	time = 0.0
	active = true

func finish():
	active = false
	time = DURATION
	preview.clear()

func progress() -> float:
	return clampf(time/DURATION,0.0,1.0)

func update(delta: float) -> bool:
	if not active: return false
	if g.mode != "play" or g.reduced_motion:
		finish()
		return true
	if not is_finite(delta) or delta <= 0: return false
	time = minf(DURATION,time+delta)
	if time >= DURATION: finish()
	return true

func draw():
	var t = progress()
	var move = smoothstep(0.0,1.0,t)
	var equipment = smoothstep(.12,.94,t)
	var hud = smoothstep(.42,1.0,t)
	var bounds = g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()
	g.environment_art.draw_cover(g,"home_counter",bounds)
	if t <= 0.0:
		g.home_menu.draw()
		return
	g.environment_art.draw_cover(g,"play_counter",bounds,Color(1,1,1,move))
	var start: Rect2 = g.home_menu.TRAY_RECT
	var destination = Rect2(g.board_to_screen(Vector2(24,220)),Vector2(672,896)*g.BOARD_SCALE)
	var tray = Rect2(start.position.lerp(destination.position,move),start.size.lerp(destination.size,move))
	# Slice borders grow with the board too, matching gameplay's final transform.
	var frame_scale = lerpf(1.0,g.BOARD_SCALE,move)
	g.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*frame_scale)
	g.food_art.draw_tray(g,Rect2(tray.position/frame_scale,tray.size/frame_scale))
	g.draw_board_transform()
	g.draw_aim_guide(equipment)
	g.draw_set_transform(Vector2.ZERO)
	var tier: String = g.peg_strength_tier(g.wave,g.trial_active)
	for i in range(mini(preview.size(),g.pegs.size())):
		var peg = g.pegs[i]
		var position: Vector2 = preview[i].p.lerp(g.board_to_screen(peg.p),move)
		var size = lerpf(preview[i].scale,g.BOARD_SCALE,move)
		g.draw_set_transform(position,0.0,Vector2.ONE*size)
		g.food_art.draw_cookie(g,peg.kind,peg.hp,peg.max,Vector2.ZERO,Vector2(49,49),tier)
	g.draw_buckets(250*(1-equipment),equipment)
	g.draw_dispenser(-90*(1-equipment),equipment)
	g.draw_set_transform(Vector2.ZERO)
	g.home_menu.draw_controls(smoothstep(0.0,.56,t))
	if hud > 0: g.draw_game_hud(Vector2(0,-140*(1-hud)))
	g.draw_set_transform(Vector2.ZERO)
