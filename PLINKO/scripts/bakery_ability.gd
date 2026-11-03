extends RefCounted
## Jam Burst charges only normal Bakery drops. Damage uses the shared peg budget.
const EVERY = 5
const QUICK_EVERY = 4
const QUICK_TRAY = 10
const RADIUS = 105.0
const TARGET_LIMIT = 2
const BURST_LIFETIME = .28
const JAM = Color("b73c68")
var g
var bursts: Array[Dictionary] = []
var icon: Texture2D

func _init(game):
	g=game

func owned() -> bool:
	return g.area_id=="bakery" and not g.trial_active and g.ability_grant_active(g.bakery_jam_burst)

func eligible() -> bool:
	return g.area_id=="bakery" and not g.trial_active and not owned() and g.highest_unlocked>=int(g.tuning.get("bakery_jam_unlock_level",8)) and g.levels[1]>=int(g.tuning.get("bakery_jam_unlock_power",4))

func unlocked() -> bool:
	return eligible()

func cost() -> int:
	return maxi(1,int(g.tuning.get("bakery_jam_cost",1200)))

func buy() -> bool:
	if not eligible() or g.mode not in ["shop","ability_offer"] or g.profile_load_blocked or g.run_transition.active or not g.can_afford(cost()): return false
	if not g.run_id.is_empty() and not g.shift_claimed: return false
	var previous={"bank":g.bank,"bakery_jam_burst":g.bakery_jam_burst,"ability_unlock_source":g.ability_unlock_source,"note":g.note,"note_time":g.note_time}
	if not g.spend_coins(cost()): return false
	g.bakery_jam_burst=true
	g.ability_unlock_source="earned"
	if not g.testing and not g.save_game():
		for key in previous: g.set(key,previous[key])
		return false
	g.note="Jam Burst unlocked"
	g.note_time=3.0
	g.feedback("ability_purchase")
	return true

func activate(source: String) -> bool:
	# The provider/campaign coordinator commits this together with its receipt.
	# A preview receipt must never silently become an earned unlock.
	if g.area_id!="bakery" or g.trial_active or source not in ["preview","store"] or not g.ability_early_access("bakery"): return false
	g.bakery_jam_burst=true
	g.ability_unlock_source=source
	return true

func quick_owned() -> bool:
	return owned() and g.bakery_jam_quick

func routes_complete() -> bool:
	if g.area_id!="bakery": return false
	# Check every authored node, including the shared root; irregular legacy
	# builds cannot skip a missing ancestor merely by owning the three tips.
	for node in g.UpgradeGraph.nodes():
		if not g.shop_node_owned(node.x,node.y): return false
	return true

func quick_unlocked() -> bool:
	return owned() and not g.bakery_jam_quick and g.highest_unlocked>=QUICK_TRAY and routes_complete()

func quick_buy() -> bool:
	if not quick_unlocked() or g.mode!="shop" or g.profile_load_blocked or g.startup_blocked or g.run_transition.active or g.page_transition.is_blocking() or g.pause_transition.is_blocking(): return false
	if not g.run_id.is_empty() and not g.shift_claimed: return false
	var previous={"bakery_jam_quick":g.bakery_jam_quick,"note":g.note,"note_time":g.note_time}
	g.bakery_jam_quick=true
	if not g.testing and not g.save_game():
		for key in previous: g.set(key,previous[key])
		return false
	g.note="More Jam unlocked"
	g.note_time=3.0
	g.feedback("upgrade")
	return true

func cadence() -> int:
	# Airborne runs keep the interval they started with, even after restoring
	# an older checkpoint into a profile that now owns the milestone.
	if active() and g.run_ability_pinned and g.mode in ["play","paused","abandon_confirm"] and not g.shift_claimed: return int(g.bakery_run.get("every",EVERY))
	return QUICK_EVERY if quick_owned() else EVERY

func reset_run():
	g.bakery_run={"enabled":owned(),"normal_launches":0,"every":QUICK_EVERY if quick_owned() else EVERY}
	bursts.clear()

func active() -> bool:
	return owned() and g.bakery_run.get("enabled",false)==true

func on_launch(ball: Dictionary):
	# Call once for each actual launcher drop, after spawn_ball. Shards and
	# specials never spend or advance the next jam-filled doughnut.
	if not active() or ball.kind!="normal" or ball.has("jam"): return
	g.bakery_run.normal_launches+=1
	ball.jam=int(g.bakery_run.normal_launches)%cadence()==0

func on_hit(ball: Dictionary, direct_peg: Dictionary) -> int:
	if not active() or ball.kind!="normal" or not ball.get("jam",false) or ball.used: return 0
	# Spend before damaging neighbours: a clear, pause or save cannot replay it.
	ball.used=true
	g.feedback("jam_splash")
	var candidates: Array[Dictionary]=[]
	for index in range(g.pegs.size()):
		var peg: Dictionary=g.pegs[index]
		if is_same(peg,direct_peg) or peg.hp<=0: continue
		var distance: float=direct_peg.p.distance_squared_to(peg.p)
		if distance<=RADIUS*RADIUS: candidates.append({"peg":peg,"distance":distance,"index":index})
	candidates.sort_custom(func(a,b): return a.distance<b.distance if a.distance!=b.distance else a.index<b.index)
	var targets: Array[Vector2]=[]
	for candidate in candidates.slice(0,TARGET_LIMIT):
		var peg: Dictionary=candidate.peg
		var event: Dictionary=g.damage_peg(peg,g.power_damage()*.75)
		if event.damage<=0: continue
		targets.append(peg.p)
		if event.broken: g.special_stats.normal+=1
	if not g.reduced_motion:
		bursts.append({"p":direct_peg.p,"targets":targets,"life":BURST_LIFETIME})
		if bursts.size()>8: bursts.pop_front()
	return targets.size()

func advance(dt: float):
	if g.reduced_motion:
		bursts.clear()
		return
	for burst in bursts: burst.life=maxf(0.0,burst.life-maxf(0.0,dt))
	bursts=bursts.filter(func(burst): return burst.life>0.0)

func draw_icon(canvas: CanvasItem, rect: Rect2, tint: Color = Color.WHITE) -> bool:
	if icon==null and ResourceLoader.exists("res://data/art/bakery_ability/jam_donut.png"):
		icon=load("res://data/art/bakery_ability/jam_donut.png")
	if icon!=null:
		var scale=minf(rect.size.x/icon.get_width(),rect.size.y/icon.get_height())
		var size=icon.get_size()*scale
		canvas.draw_texture_rect(icon,Rect2(rect.get_center()-size*.5,size),false,tint)
	else:
		var radius=minf(rect.size.x,rect.size.y)*.43
		canvas.draw_circle(rect.get_center(),radius,Color("ce8f52")*tint)
		canvas.draw_circle(rect.get_center(),radius*.72,Color("efc890")*tint)
		canvas.draw_circle(rect.get_center(),radius*.42,JAM*tint)
		canvas.draw_circle(rect.get_center()+Vector2(-radius*.12,-radius*.14),radius*.13,Color("f5b6be")*tint)
	return true

func draw_ball(canvas: CanvasItem, ball: Dictionary) -> bool:
	# Called instead of the ordinary sprite, in the existing ball-local transform.
	if g.area_id!="bakery" or ball.kind!="normal" or not ball.get("jam",false) or ball.used: return false
	var diameter=ball.r*2.55
	draw_icon(canvas,Rect2(-Vector2.ONE*diameter*.5,Vector2.ONE*diameter))
	canvas.draw_arc(Vector2.ZERO,ball.r*1.3,0,TAU,24,Color("f1a9bb"),1.8,true)
	return true

func draw_effects(canvas: CanvasItem):
	if g.area_id!="bakery" or g.reduced_motion: return
	for burst in bursts:
		var fraction: float=burst.life/BURST_LIFETIME
		canvas.draw_arc(burst.p,15.0+(1.0-fraction)*50.0,0,TAU,32,Color(JAM,fraction*.8),3.0,true)
		for point in burst.targets:
			canvas.draw_line(burst.p,point,Color(JAM,fraction*.65),4.0,true)
			canvas.draw_circle(point,5.0+8.0*(1.0-fraction),Color(JAM,fraction*.45))

func draw_charge(canvas: CanvasItem, center: Vector2):
	if not active(): return
	var every=cadence()
	var charge=int(g.bakery_run.normal_launches)%every
	for index in range(every):
		var point=center+Vector2((index-(every-1)*.5)*11.0,0)
		canvas.draw_circle(point,3.3,JAM if index<charge else Color(.5,.28,.25,.3))

func capture_extra() -> Dictionary:
	var run=g.bakery_run.duplicate(true)
	# Keep original Jam runs in schema6 with their exact legacy field shape.
	if int(run.get("every",EVERY))==EVERY: run.erase("every")
	return {"bakery_run":run}

static func validate_extra(snapshot: Dictionary, state: Dictionary, game) -> Dictionary:
	var run=snapshot.get("bakery_run")
	var quick=snapshot.get("schema")==7
	if not run is Dictionary or run.size()!=(3 if quick else 2) or not run.has("enabled") or not run.has("normal_launches"): return {"ok":false}
	if quick and (not run.get("every") is int and not run.get("every") is float): return {"ok":false}
	if quick and (run.every!=QUICK_EVERY or not game.bakery_jam_quick): return {"ok":false}
	if not run.enabled is bool or not run.enabled or state.trial_active or not game.bakery_ability.owned(): return {"ok":false}
	var count=run.normal_launches
	if not (count is int or count is float) or not is_finite(float(count)) or count<0 or count>10000 or float(count)!=floorf(float(count)): return {"ok":false}
	return {"ok":true,"bakery_run":{"enabled":true,"normal_launches":int(count),"every":QUICK_EVERY if quick else EVERY}}
