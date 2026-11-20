extends RefCounted
## Short visual responses driven by the active physics clock. The run mirrors
## the last catch's remaining time so a won board can resume its final settle.
const PEG_DURATION = .24
const BUCKET_DURATION = .32
const CoinDisplay = preload("res://scripts/coin_display.gd")
const COIN_DURATION = .72
const IMPACT_DURATION = .30
const MAX_COIN_LABELS = 18
const MAX_IMPACT_BURSTS = 8
const COIN_MERGE_WINDOW = .10
const COIN_GOLD = Color("f6c751")
const COIN_OUTLINE = Color("714719")
var peg_times: Dictionary = {}
var bucket_times = PackedFloat32Array([0.0,0.0,0.0,0.0,0.0])
var coin_labels: Array = []
var impact_bursts: Array = []

func reset():
	peg_times.clear()
	bucket_times.fill(0.0)
	coin_labels.clear()
	impact_bursts.clear()

func hit_peg(position: Vector2):
	peg_times[position] = PEG_DURATION

func catch_food(index: int):
	# Restart instead of adding impulses, so simultaneous catches stay subtle.
	bucket_times[index] = BUCKET_DURATION

func show_coins(position: Vector2, earned_coins: float, impact_first_hit: bool = false):
	# Only authoritative whole-coin awards reach this presentation. A fractional
	# hit may remove HP without earning a coin; it must never display a fake +1.
	if not position.is_finite() or not is_finite(earned_coins) or earned_coins < 1: return
	var amount = CoinDisplay.whole(earned_coins)
	var merged = false
	for label in coin_labels:
		if label.p == position and label.age <= COIN_MERGE_WINDOW:
			label.coins += amount
			label.impact = label.impact or impact_first_hit
			label.life = COIN_DURATION
			merged = true
			break
	if not merged:
		# A later contact replaces this peg's old number instead of drawing two
		# almost coincident labels. Other pegs keep their own independent feedback.
		coin_labels = coin_labels.filter(func(label): return label.p != position)
		if coin_labels.size() >= MAX_COIN_LABELS: coin_labels.pop_front()
		coin_labels.append({"p":position,"coins":amount,"impact":impact_first_hit,"life":COIN_DURATION,"age":0.0})
	if impact_first_hit:
		if impact_bursts.size() >= MAX_IMPACT_BURSTS: impact_bursts.pop_front()
		impact_bursts.append({"p":position,"life":IMPACT_DURATION})

func advance(delta: float):
	for position in peg_times.keys():
		peg_times[position] = maxf(0.0,peg_times[position]-delta)
		if peg_times[position] <= 0.0: peg_times.erase(position)
	for i in range(bucket_times.size()):
		bucket_times[i] = maxf(0.0,bucket_times[i]-delta)
	for label in coin_labels:
		label.life -= delta
		label.age += delta
	coin_labels = coin_labels.filter(func(label): return label.life > 0)
	for burst in impact_bursts: burst.life -= delta
	impact_bursts = impact_bursts.filter(func(burst): return burst.life > 0)

func draw_ball_aura(game: CanvasItem, ball: Dictionary, reduced_motion: bool):
	if ball.get("kind","") != "impact" or ball.get("used",false): return
	var center: Vector2 = ball.p
	var radius = float(ball.r)
	var wave = 0.0 if reduced_motion else sin(float(ball.life)*10.0)
	var glow = Color("ffba50")
	game.draw_circle(center,radius+8.0+wave*1.2,Color(glow,.12))
	game.draw_arc(center,radius+5.0+wave*.6,0,TAU,24,Color("b75f2a"),2.0,true)
	game.draw_arc(center,radius+6.5+wave*.6,0,TAU,24,Color("ffdd88"),1.5,true)
	if not reduced_motion:
		var velocity: Vector2 = ball.v
		var behind = -velocity.normalized()
		game.draw_line(center+behind*(radius+8),center+behind*(radius+20),Color(glow,.46),4.0,true)
		game.draw_line(center+behind*(radius+23),center+behind*(radius+28),Color(glow,.23),2.5,true)
	# A fixed bright notch makes the charged state visible even without animation.
	var sparkle = center+Vector2(-radius-4,-radius-3)
	game.draw_line(sparkle-Vector2(4,0),sparkle+Vector2(4,0),Color("fff1bd"),2.0,true)
	game.draw_line(sparkle-Vector2(0,4),sparkle+Vector2(0,4),Color("fff1bd"),2.0,true)

func coin_label_layout(label: Dictionary, font: Font, reduced_motion: bool) -> Dictionary:
	var age = clampf(1.0-float(label.life)/COIN_DURATION,0.0,1.0)
	var size = 29 if label.impact else 24
	var value = "+"+CoinDisplay.text(float(label.coins))
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var baseline: Vector2 = label.p+Vector2(-width*.5,-28.0-(0.0 if reduced_motion else age*24.0))
	baseline.x = clampf(baseline.x,46.0,674.0-width)
	baseline.y = clampf(baseline.y,308.0,1004.0)
	var bounds = Rect2(baseline-Vector2(0,font.get_ascent(size)),Vector2(width,font.get_height(size))).grow(3)
	return {"text":value,"size":size,"p":baseline,"alpha":minf(1.0,float(label.life)/.22),"bounds":bounds,"color":COIN_GOLD,"outline":COIN_OUTLINE}

func draw_coin_gains(game: CanvasItem, font: Font, reduced_motion: bool):
	for burst in impact_bursts:
		var age = clampf(1.0-float(burst.life)/IMPACT_DURATION,0.0,1.0)
		var fade = (1.0-age)*.8
		var radius = 29.0 if reduced_motion else 22.0+age*29.0
		game.draw_arc(burst.p,radius,0,TAU,28,Color(1.0,.65,.19,fade),2.0,true)
		if not reduced_motion:
			for index in range(6):
				var direction = Vector2.from_angle(float(index)*TAU/6.0+.3)
				game.draw_line(burst.p+direction*(radius+4),burst.p+direction*(radius+10),Color(1.0,.83,.42,fade),2.0,true)
	for label in coin_labels:
		var layout = coin_label_layout(label,font,reduced_motion)
		var gold = Color(COIN_GOLD,layout.alpha)
		var outline = Color(COIN_OUTLINE,layout.alpha)
		game.draw_string_outline(font,layout.p,layout.text,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.size,4,outline)
		game.draw_string(font,layout.p,layout.text,HORIZONTAL_ALIGNMENT_LEFT,-1,layout.size,gold)

func spring(remaining: float, duration: float) -> float:
	if remaining <= 0.0: return 0.0
	var t = clampf(1.0-remaining/duration,0.0,1.0)
	# Immediate compression, a smaller stretch, then a smooth return to rest.
	return cos(t*TAU)*(1.0-t)*(1.0-t)

func peg_scale(position: Vector2, reduced_motion: bool) -> Vector2:
	var amount = 0.0 if reduced_motion else spring(peg_times.get(position,0.0),PEG_DURATION)
	return Vector2(1.0+.10*amount,1.0-.10*amount)

func bucket_scale(index: int, reduced_motion: bool) -> Vector2:
	var amount = 0.0 if reduced_motion else spring(bucket_times[index],BUCKET_DURATION)
	return Vector2(1.0+.035*amount,1.0-.07*amount)

func bucket_tint(index: int, gold: bool) -> Color:
	var strength = clampf(bucket_times[index]/BUCKET_DURATION,0.0,1.0)
	# A mint glaze for ceramic; a warmer honey tone preserves the gold identity.
	var color = Color(1.10,.88,.60) if gold else Color(.70,1.08,.84)
	return Color.WHITE.lerp(color,strength)
