extends RefCounted
## A bounded celebration of earned whole coins. Amounts always display immediately;
## this state never changes a wallet, payout or save. Rapid gains share one beat.
const CoinDisplay = preload("res://scripts/coin_display.gd")
const DURATION = .56
const MAX_SCALE = 1.22
const MAX_ROTATION = .18
var initialized = false
var key = ""
var last_whole = 0
var age = DURATION
var direction = 1.0

func reset():
	initialized = false
	key = ""
	last_whole = 0
	age = DURATION
	direction = 1.0

func observe(amount: float, identity: String):
	var whole = CoinDisplay.whole(amount)
	if not initialized or identity != key or whole < last_whole:
		age = DURATION
	elif whole > last_whole and age >= DURATION:
		age = 0.0
		direction = -direction
	initialized = true
	key = identity
	last_whole = whole

func advance(delta: float):
	age = minf(DURATION,age+maxf(0.0,delta))

func active() -> bool:
	return age < DURATION

func presentation(reduced_motion: bool) -> Dictionary:
	var rise = smoothstep(0.0,.075,age)
	var settle = 1.0-smoothstep(.075,DURATION,age)
	var beat = rise*settle if active() else 0.0
	return {"scale":1.0 if reduced_motion else 1.0+(MAX_SCALE-1.0)*beat,
		"rotation":0.0 if reduced_motion else direction*MAX_ROTATION*beat,
		"glow":beat*(.22 if reduced_motion else 1.0)}

func draw(game: CanvasItem, value: String, rect: Rect2, font: Font, size: int, ink: Color, reduced_motion: bool, origin: Vector2 = Vector2.ZERO):
	var state = presentation(reduced_motion)
	# Fit against the full animated bounds, so large wallets stay inside their
	# allotted space at every frame, including the gold outline.
	var fit = size
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x
	var height = font.get_height(fit)
	while fit > 10 and ((width*cos(MAX_ROTATION)+height*sin(MAX_ROTATION))*MAX_SCALE+8 > rect.size.x or (height*cos(MAX_ROTATION)+width*sin(MAX_ROTATION))*MAX_SCALE+8 > rect.size.y):
		fit -= 1
		width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x
		height = font.get_height(fit)
	game.draw_set_transform(origin+rect.get_center(),state.rotation,Vector2.ONE*state.scale)
	var baseline = Vector2(-width*.5,(font.get_ascent(fit)-font.get_descent(fit))*.5)
	if state.glow > .001:
		game.draw_string_outline(font,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit,7,Color(1.0,.69,.13,.16*state.glow))
		game.draw_string_outline(font,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit,3,Color(1.0,.82,.29,.55*state.glow))
	game.draw_string(font,baseline,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit,ink.lerp(Color("d28a13"),state.glow*.65))
	game.draw_set_transform(origin)
