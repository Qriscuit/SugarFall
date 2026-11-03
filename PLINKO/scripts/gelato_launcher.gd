extends RefCounted
## Fixed top-center launchers. Aim and upgrades stay in the area campaign.
const SINGLE_ORIGIN = Vector2(360,267)
const TWIN_ORIGINS = [Vector2(318,267),Vector2(402,267)]
const TWIN_GUIDE_COLORS = [Color("34736b"),Color("8a4f77")]
var g

func _init(game):
	g=game

func is_twin() -> bool:
	return g.area_id=="gelato" and g.ability_grant_active(g.twin_launchers) and not g.trial_active

func origins() -> Array:
	return TWIN_ORIGINS.duplicate() if is_twin() else [SINGLE_ORIGIN]

func gravity() -> float:
	return maxf(.001,float(g.tuning.get("gravity",400.0)))

func aim_target() -> Vector2:
	var target=Vector2(clampf(g.aim_x,66,654),clampf(g.aim_y,330,1000))
	# Keep the normal launch speed and downward flight. Both twins share the
	# intersection of their reachable ranges instead of promising an impossible hit.
	var left=66.0
	var right=654.0
	for origin in origins():
		var reach=speed()*sqrt(2.0*(target.y-origin.y)/gravity())
		left=maxf(left,origin.x-reach)
		right=minf(right,origin.x+reach)
	target.x=clampf(target.x,left,right)
	return target

func solution(origin: Vector2 = SINGLE_ORIGIN) -> Dictionary:
	var target=aim_target()
	var delta=target-origin
	var acceleration=gravity()
	var a=speed()*speed()+acceleration*delta.y
	var discriminant=maxf(0.0,a*a-acceleration*acceleration*delta.length_squared())
	# Stable low-flight-time root of |(delta - .5*g*t*t) / t| = speed.
	var time=sqrt(2.0*delta.length_squared()/(a+sqrt(discriminant)))
	var velocity=(delta-Vector2(0,.5*acceleration*time*time))/time
	return {"velocity":velocity,"time":time,"target":target,"clamped":target.distance_to(Vector2(g.aim_x,g.aim_y))>.01}

func direction(origin: Vector2 = SINGLE_ORIGIN) -> Vector2:
	return solution(origin).velocity.normalized()

func trajectory_point(origin: Vector2, velocity: Vector2, time: float) -> Vector2:
	return origin+velocity*time+Vector2(0,.5*gravity()*time*time)

func preview(origin: Vector2 = SINGLE_ORIGIN) -> Dictionary:
	var shot=solution(origin)
	var points: Array[Vector2]=[]
	var time=0.0
	var previous=origin
	var hit=false
	# Short, bounded steps keep the contact estimate within a pixel of the arc.
	# Accumulate distance for evenly spaced round dots as the food accelerates.
	var spacing=0.0
	while time<float(shot.time):
		var next_time=minf(time+.01,float(shot.time))
		var point=trajectory_point(origin,shot.velocity,next_time)
		for peg in g.pegs:
			if peg.hp<=0: continue
			var contact=segment_contact(previous,point,peg.p,22.0+g.ball_radius("normal"))
			if contact>=0:
				point=previous.lerp(point,contact)
				hit=true
				break
		spacing+=previous.distance_to(point)
		if spacing>=18.0:
			points.append(point)
			spacing=fmod(spacing,18.0)
		previous=point
		time=next_time
		if hit: break
	# The final dot marks the reachable aim point, or the first contact.
	if points.is_empty() or points[-1].distance_to(previous)>3.0: points.append(previous)
	return {"points":points,"hit":hit,"end":previous,"solution":shot}

func segment_contact(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var offset=start-center
	if offset.length_squared()<=radius*radius: return 0.0
	var segment=finish-start
	var a=segment.length_squared()
	if a<.000001: return -1.0
	var b=2.0*offset.dot(segment)
	var c=offset.length_squared()-radius*radius
	var discriminant=b*b-4.0*a*c
	if discriminant<0: return -1.0
	var contact=(-b-sqrt(discriminant))/(2.0*a)
	return contact if contact>=0.0 and contact<=1.0 else -1.0

func speed() -> float:
	return maxf(1.0,float(g.tuning.get("launcher_speed",260.0)))

func interval(feed_tier: int = -1) -> float:
	var tier=g.levels[0] if feed_tier<0 else feed_tier
	var rate=float(g.tuning.get("twin_fire_rate_multiplier",.65)) if is_twin() else 1.0
	return maxf(.13,.74/(1.0+tier*.18))/rate

func fire():
	for origin in origins():
		if g.balls.size()>=80: break
		g.spawn_ball(origin,g.random_ball(),solution(origin).velocity,false)

func cost() -> int:
	return int(g.tuning.get("twin_launcher_cost",3000))

func unlocked() -> bool:
	return g.area_id=="gelato" and not g.trial_active and not is_twin() and g.highest_unlocked>=int(g.tuning.get("twin_unlock_level",8)) and g.levels[1]>=int(g.tuning.get("twin_unlock_power",6))

func buy() -> bool:
	if g.mode not in ["shop","ability_offer"] or g.run_transition.active or not unlocked(): return false
	if not g.run_id.is_empty() and not g.shift_claimed: return false
	if g.profile_load_blocked or not g.ensure_gelato_shop_state(): return false
	if not g.can_afford(cost()):
		g.note="Need %s more credits" % g.credits_needed_text(cost()-g.bank)
		g.note_time=3
		return false
	var previous_bank=g.bank
	var previous_power=g.levels[1]
	var previous_reset_tier=g.power_reset_tier
	var previous_owned=g.gelato_owned_nodes.duplicate(true)
	var previous_reset=g.gelato_reset_power_nodes.duplicate(true)
	var previous_note=g.note
	var previous_note_time=g.note_time
	var previous_twin=g.twin_launchers
	var previous_source=g.ability_unlock_source
	g.spend_coins(cost())
	_apply_transformation("earned")
	# Commit the purchase and Power reset together. Failure restores the build.
	if not g.testing and not g.save_game():
		g.bank=previous_bank
		g.levels[1]=previous_power
		g.power_reset_tier=previous_reset_tier
		g.gelato_owned_nodes=previous_owned
		g.gelato_reset_power_nodes=previous_reset
		g.twin_launchers=previous_twin
		g.ability_unlock_source=previous_source
		g.note=previous_note
		g.note_time=previous_note_time
		return false
	g.tone(720,.08)
	g.note="Twin launchers ready. Rebuild Power for both."
	g.note_time=4
	return true

func _apply_transformation(source: String):
	# A restored purchase or re-earned entitlement never resets Power twice.
	if not g.twin_launchers:
		g.power_reset_tier=g.levels[1]
		for node in g.gelato_owned_nodes.duplicate(true):
			if int(node[0])==1:
				g.gelato_owned_nodes.erase(node)
				g.gelato_reset_power_nodes.append(node.duplicate())
		g.levels[1]=0
	g.twin_launchers=true
	g.ability_unlock_source=source

func activate(source: String) -> bool:
	if g.area_id!="gelato" or g.trial_active or source not in ["preview","store"] or not g.ability_early_access("gelato") or not g.ensure_gelato_shop_state(): return false
	_apply_transformation(source)
	return true

func guide_color(origin: Vector2, alpha: float = 1.0) -> Color:
	if not is_twin(): return Color(.33,.23,.44,.64*alpha)
	# Distinguish the two real trajectories where they converge. Their geometry
	# still comes from the same launch solution used by fire().
	var index = 1 if origin==TWIN_ORIGINS[1] else 0
	return Color(TWIN_GUIDE_COLORS[index],.82*alpha)

func draw_guide(alpha: float):
	g.draw_board_transform()
	for origin in origins():
		var path=preview(origin)
		var color=guide_color(origin,alpha)
		for point in path.points:
			g.draw_circle(point,3.0,color,true,-1.0,true)
		if not path.hit:
			g.draw_arc(path.end,7,0,TAU,24,Color(color,color.a*.86),1.5,true)

func draw(offset_y: float, alpha: float):
	for origin in origins():
		var width=82.0 if is_twin() else 112.0
		var angle=direction(origin).angle()-PI*.5
		g.draw_board_transform(origin+Vector2(0,offset_y),angle)
		if not g.food_art.draw(g,"hopper",Rect2(-width*.5,-width,width,width),Color(1,1,1,alpha)):
			g.draw_circle(Vector2(0,-width*.5),width*.4,Color(g.BLUE,alpha))
			g.draw_line(Vector2(0,-width*.5),Vector2.ZERO,Color(g.GOLD,alpha),12,true)
	g.draw_board_transform()
