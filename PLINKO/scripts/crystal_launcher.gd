extends RefCounted
## Crystal owns straight flight and its run-local Prism offers. Campaign rewards
## still go through the shared damage/catch functions and the normal save flow.
const ORIGIN = Vector2(360,267)
const BALL_CAP = 80
const OFFER_LIFETIME = 4.0
const OFFER_TIMES = [3.0,7.5]
const OFFER_WAIT = 1.5
const CLONE_ANGLE = PI/15.0
const RUN_KEYS = ["next_offer","collected","offer_life","offer_position","offer_started"]
var g

func _init(game):
	g=game

func owned() -> bool:
	return g.area_id=="crystal" and g.ability_grant_active(g.crystal_second_prism) and not g.trial_active

func unlocked() -> bool:
	return g.area_id=="crystal" and not g.trial_active and not owned() and g.highest_unlocked>=maxi(8,int(g.tuning.get("crystal_second_prism_unlock_level",8))) and g.levels[1]>=int(g.tuning.get("crystal_second_prism_unlock_power",4))

func cost() -> int:
	return maxi(1,int(g.tuning.get("crystal_second_prism_cost",900)))

func buy() -> bool:
	if not unlocked() or g.profile_load_blocked or g.mode not in ["shop","ability_offer"] or g.run_transition.active or not g.can_afford(cost()): return false
	if not g.shift_claimed and not g.run_id.is_empty(): return false
	var before={"bank":g.bank,"crystal_second_prism":g.crystal_second_prism,"ability_unlock_source":g.ability_unlock_source,"note":g.note,"note_time":g.note_time}
	if not g.spend_coins(cost()): return false
	g.crystal_second_prism=true
	g.ability_unlock_source="earned"
	g.note="A second Prism can appear each run"
	g.note_time=4.0
	if not g.testing and not g.save_game():
		for key in before: g.set(key,before[key])
		return false
	return true

func activate(source: String) -> bool:
	if g.area_id!="crystal" or g.trial_active or source not in ["preview","store"] or not g.ability_early_access("crystal"): return false
	g.crystal_second_prism=true
	g.ability_unlock_source=source
	return true

func speed() -> float:
	return clampf(float(g.tuning.get("launcher_speed",360.0)),60.0,610.0)

func interval(feed_tier: int = -1) -> float:
	var tier=g.levels[0] if feed_tier<0 else feed_tier
	return maxf(.74,float(g.tuning.get("launcher_interval",1.15))/(1.0+tier*float(g.tuning.get("feed_rate_step",.055))))

func lifetime(kind: String = "normal") -> float:
	return float(g.tuning.get("crystal_ball_lifetime",8.0))+g.levels[2]*float(g.tuning.get("crystal_bounce_lifetime_step",.5))+(float(g.tuning.get("crystal_ricochet_lifetime_bonus",2.0)) if kind=="ricochet" else 0.0)

func origin() -> Vector2:
	return ORIGIN

func direction() -> Vector2:
	return (Vector2(clampf(g.aim_x,66,654),clampf(g.aim_y,330,1000))-ORIGIN).normalized()

func prepare_velocity(value: Vector2) -> Vector2:
	return (value.normalized() if value.length_squared()>.0001 else Vector2.DOWN)*speed()

func velocity() -> Vector2:
	return direction()*speed()

func fire():
	if g.balls.size()<BALL_CAP: g.spawn_ball(ORIGIN,g.random_ball(),velocity(),false)

static func segment_contact(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var offset=start-center
	if offset.length_squared()<=radius*radius: return 0.0
	var segment=finish-start
	var a=segment.length_squared()
	if a<.000001: return -1.0
	var b=2.0*offset.dot(segment)
	var c=offset.length_squared()-radius*radius
	var discriminant=b*b-4.0*a*c
	if discriminant<0: return -1.0
	var hit=(-b-sqrt(discriminant))/(2.0*a)
	return hit if hit>=0 and hit<=1 else -1.0

func preview() -> Dictionary:
	var ray=direction()
	var distance=(g.BUCKET_CATCH_Y-ORIGIN.y)/ray.y
	if ray.x<0: distance=minf(distance,(54.0-ORIGIN.x)/ray.x)
	elif ray.x>0: distance=minf(distance,(666.0-ORIGIN.x)/ray.x)
	var end=ORIGIN+ray*distance
	var nearest=1.0
	var hit=false
	for peg in g.pegs:
		if peg.hp<=0: continue
		var contact=segment_contact(ORIGIN,end,peg.p,22.0+g.ball_radius("normal"))
		if contact>=0 and contact<nearest: nearest=contact; hit=true
	end=ORIGIN.lerp(end,nearest)
	var points: Array[Vector2]=[]
	var length=ORIGIN.distance_to(end)
	var travel=18.0
	while travel<length:
		points.append(ORIGIN+ray*travel)
		travel+=18.0
	points.append(end)
	return {"points":points,"end":end,"hit":hit,"velocity":velocity()}

func reset_run():
	g.crystal_run={"next_offer":0,"collected":0,"offer_life":0.0,"offer_position":Vector2.ZERO,"offer_started":-1.0}

func _live_balls() -> Array:
	return g.balls.filter(func(ball): return not ball.dead and ball.p.y<=g.BUCKET_CATCH_Y)

static func offer_times(game) -> Array:
	var values=game.tuning.get("crystal_offer_times",OFFER_TIMES)
	if values is Array and values.size()==2 and _number(values[0],.1,80) and _number(values[1],.1,85) and values[1]>values[0]:
		return [float(values[0]),float(values[1])]
	return OFFER_TIMES.duplicate()

static func offer_wait(game) -> float:
	return clampf(float(game.tuning.get("crystal_offer_wait",OFFER_WAIT)),0.0,4.0)

func advance(_dt: float):
	if g.area_id!="crystal" or g.mode!="play" or g.clear_draining: return
	if g.crystal_run.is_empty(): reset_run()
	var state: Dictionary=g.crystal_run
	if state.offer_life>0:
		state.offer_life=maxf(0.0,OFFER_LIFETIME-(g.run_elapsed-float(state.offer_started)))
		if state.offer_life<.000001: state.offer_life=0.0
	var limit=2 if owned() else 1
	var index=int(state.next_offer)
	if index>=limit or state.offer_life>0: return
	var scheduled=float(offer_times(g)[index])
	if g.run_elapsed<scheduled: return
	if _live_balls().is_empty():
		# Each scheduled window is tried once; no indefinite or rerolled offer.
		if g.run_elapsed>scheduled+offer_wait(g): state.next_offer=index+1
		return
	if g.run_elapsed>scheduled+offer_wait(g):
		state.next_offer=index+1
		return
	state.next_offer=index+1
	state.offer_started=g.run_elapsed
	state.offer_position=Vector2(230 if index==0 else 490,610 if index==0 else 710)
	state.offer_life=OFFER_LIFETIME

func try_collect(point: Vector2) -> bool:
	if g.area_id!="crystal" or g.mode!="play" or g.run_transition.active or g.clear_draining or g.crystal_run.is_empty(): return false
	var state: Dictionary=g.crystal_run
	if state.offer_life<=0 or point.distance_to(state.offer_position)>=45: return false
	if duplicate_live_balls()==0: return false
	state.offer_life=0.0
	state.collected+=1
	g.add_float(state.offer_position,"×2",g.TEAL)
	# Reuse the prewarmed pickup cue; unsupported frequencies are intentionally
	# silent, so a new pitch must never be requested without a registered stream.
	g.tone(950,.08)
	return true

func duplicate_live_balls() -> int:
	var originals=_live_balls()
	var room=maxi(0,BALL_CAP-g.balls.size())
	var count=mini(room,originals.size())
	for index in range(count):
		var clone: Dictionary=originals[index].duplicate(true)
		clone.v=clone.v.rotated(CLONE_ANGLE if index%2==0 else -CLONE_ANGLE)
		# Preserve spent specials, age and damage cooldown; this is extra food,
		# not a fresh launch that re-arms an Impact or Splitter effect.
		g.balls.append(clone)
		g.total_spawned+=1
		g.type_drops[clone.kind]=g.type_drops.get(clone.kind,0)+1
	return count

func begin_clear_drain():
	if not g.crystal_run.is_empty(): g.crystal_run.offer_life=0.0
	for ball in g.balls: _drain_velocity(ball)

func _drain_velocity(ball: Dictionary):
	var magnitude=maxf(60.0,ball.v.length())
	var x=clampf(float(ball.v.x),-magnitude*.5,magnitude*.5)
	ball.v=Vector2(x,sqrt(maxf(0.0,magnitude*magnitude-x*x)))

func step_ball(ball: Dictionary, dt: float, pending: Array):
	if ball.dead or dt<=0: return
	ball.life+=dt
	if g.clear_draining: _drain_velocity(ball)
	# Six board pixels per substep prevents even the fastest allowed shot
	# skipping a peg. A bounded catch-up interval avoids unbounded work.
	var duration=minf(dt,.25)
	var count=clampi(ceili(duration*maxf(1.0,ball.v.length())/6.0),1,32)
	var slice=duration/count
	for _index in range(count):
		ball.cool-=slice
		ball.p+=ball.v*slice
		if ball.p.x<54: ball.p.x=54; ball.v.x=absf(ball.v.x)
		if ball.p.x>666: ball.p.x=666; ball.v.x=-absf(ball.v.x)
		if ball.p.y<260: ball.p.y=260; ball.v.y=absf(ball.v.y)
		if not g.clear_draining:
			for peg in g.pegs:
				if peg.hp<=0: continue
				var diff: Vector2=ball.p-peg.p
				var radius=22.0+float(ball.r)
				if diff.length_squared()>=radius*radius: continue
				var normal=diff.normalized() if diff.length_squared()>.0001 else -ball.v.normalized()
				if normal.length_squared()<.0001: normal=Vector2.UP
				ball.p=peg.p+normal*(radius+.1)
				var entering=ball.v.dot(normal)<0
				if entering: ball.v=ball.v.bounce(normal)
				if entering and ball.cool<=0:
					_hit_peg(ball,peg,pending)
				break
		if ball.p.y>g.BUCKET_CATCH_Y:
			_catch(ball)
			break
	if ball.life>lifetime(ball.kind) and not g.clear_draining: ball.dead=true

func _hit_peg(ball: Dictionary, peg: Dictionary, pending: Array):
	var first=ball.kind=="impact" and not ball.used
	var damage=g.CombatBalance.hit_damage(g.power_damage(),ball.kind,ball.used,peg.kind,g.tuning)
	ball.productive=true
	g.damage_peg(peg,damage,first)
	if peg.hp<=0: g.special_stats[ball.kind]=g.special_stats.get(ball.kind,0)+1
	ball.cool=.08
	if ball.kind=="impact": ball.used=true
	if ball.kind=="splitter" and not ball.used:
		for index in range(3):
			pending.append({"p":ball.p,"v":prepare_velocity(ball.v.rotated((index-1)*PI/6.0)),"kind":"shard","productive":true})
		ball.used=true
	if g.clear_draining: _drain_velocity(ball)

func _catch(ball: Dictionary):
	var bin=clampi(int((ball.p.x-42)/127.2),0,4)
	g.impact_feedback.catch_food(bin)
	g.catch_settle_remaining=g.impact_feedback.BUCKET_DURATION
	g.settling_bucket=bin
	if not g.tuning.productive_bins_only or ball.productive: g.buckets[bin].hits+=1
	var reward=g.bucket_reward(bin)
	if ball.kind=="shard": reward=g.round_credits(reward*.5)
	if g.tuning.productive_bins_only and not ball.productive: reward=0.0
	var shown=g.CoinDisplay.gain(g.shift_coins,reward)
	g.shift_coins=g.round_credits(g.shift_coins+reward)
	if shown>0: g.add_float(Vector2(106+bin*127,g.BUCKET_CATCH_Y+4),"+%d" % shown,g.GOLD)
	ball.dead=true

func capture_extra() -> Dictionary:
	if g.crystal_run.is_empty(): reset_run()
	return {"crystal_second_prism":owned(),"crystal_run":g.crystal_run.duplicate(true)}

static func validate_extra(snapshot: Dictionary, state: Dictionary, game) -> Dictionary:
	if not snapshot.get("crystal_second_prism") is bool: return {"ok":false}
	var second=bool(snapshot.crystal_second_prism)
	if second!=(game.ability_grant_active(bool(game.crystal_second_prism)) and not state.trial_active): return {"ok":false}
	var value=snapshot.get("crystal_run")
	if not value is Dictionary or value.size()!=RUN_KEYS.size(): return {"ok":false}
	for key in RUN_KEYS:
		if not value.has(key): return {"ok":false}
	var limit=2 if second else 1
	if not _integer(value.next_offer,0,limit) or not _integer(value.collected,0,int(value.next_offer)): return {"ok":false}
	if not _number(value.offer_life,0,OFFER_LIFETIME) or not _number(value.offer_started,-1,90): return {"ok":false}
	var point=value.offer_position
	if not point is Array or point.size()!=2 or not _number(point[0],0,720) or not _number(point[1],0,1000): return {"ok":false}
	var next=int(value.next_offer)
	var times=offer_times(game)
	if next>0 and state.run_elapsed<float(times[next-1]): return {"ok":false}
	if value.offer_life>0:
		if next==0 or state.clear_draining or int(value.collected)>=next: return {"ok":false}
		var scheduled=float(times[next-1])
		if value.offer_started<scheduled or value.offer_started>scheduled+offer_wait(game) or value.offer_started>state.run_elapsed: return {"ok":false}
		if absf(value.offer_life-(OFFER_LIFETIME-(state.run_elapsed-value.offer_started)))>.001: return {"ok":false}
		var expected=Vector2(230 if next==1 else 490,610 if next==1 else 710)
		if Vector2(point[0],point[1]).distance_to(expected)>.001: return {"ok":false}
	elif value.offer_started>state.run_elapsed: return {"ok":false}
	var decoded=value.duplicate(true)
	decoded.next_offer=int(value.next_offer)
	decoded.collected=int(value.collected)
	decoded.offer_position=Vector2(float(point[0]),float(point[1]))
	return {"ok":true,"crystal_second_prism":second,"crystal_run":decoded}

static func _number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high

static func _integer(value, low: int, high: int) -> bool:
	return _number(value,low,high) and float(value)==floorf(float(value))

func draw_guide(alpha: float = 1.0):
	g.draw_board_transform()
	for point in preview().points: g.draw_circle(point,3.0,Color(.32,.33,.58,.7*alpha),true,-1.0,true)

func draw(offset_y: float = 0.0, alpha: float = 1.0):
	g.draw_board_transform(ORIGIN+Vector2(0,offset_y),direction().angle()-PI*.5)
	if not g.food_art.draw(g,"hopper",Rect2(-56,-112,112,112),Color(1,1,1,alpha)):
		g.draw_circle(Vector2(0,-56),44,Color(g.BLUE,alpha))
		g.draw_line(Vector2(0,-56),Vector2.ZERO,Color(g.GOLD,alpha),12,true)
	g.draw_board_transform()

func draw_pickup():
	if g.crystal_run.is_empty() or g.crystal_run.offer_life<=0: return
	var state: Dictionary=g.crystal_run
	g.draw_board_transform(state.offer_position)
	g.draw_circle(Vector2.ZERO,36,Color(.68,.83,1,.24))
	g.food_art.draw_centered(g,"multiply_pickup",Vector2.ZERO,Vector2(56,56))
	g.draw_arc(Vector2.ZERO,35,-PI/2,-PI/2+TAU*state.offer_life/OFFER_LIFETIME,32,g.TEAL,3,true)
	g.box(Rect2(-24,19,48,25),g.area_surface("panel"),9)
	g.text_at("×2",Vector2(-16,38),20,g.TEAL)
	g.draw_board_transform()
