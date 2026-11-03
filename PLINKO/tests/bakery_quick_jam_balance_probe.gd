extends SceneTree
## Bounded fixed-build comparison. Legal graph purchases use a synthetic wallet;
## modeled aiming and automatic pickup collection are not human playtesting.
const STEP = 1.0/60.0
const PAIRS = [["splitter","impact"],["ricochet","impact"],["ricochet","splitter"]]
const RETARGET_SECONDS = .35
const FINGER_SPEED = 600.0
const AIM_ERROR = 14.0
var results: Array[Dictionary] = []
var failures: Array[String] = []

class MeasuredJam extends "res://scripts/bakery_ability.gd":
	func on_hit(ball: Dictionary, direct_peg: Dictionary) -> int:
		var will_burst=active() and ball.kind=="normal" and ball.get("jam",false) and not ball.used
		if will_burst: g.jam_activations+=1
		g.measuring_jam=will_burst
		var targets=super.on_hit(ball,direct_peg)
		g.measuring_jam=false
		return targets

class Fixture extends "res://scripts/main.gd":
	var profile_io=0
	var jam_launched=0
	var jam_activations=0
	var measuring_jam=false
	var jam_damage=0.0
	var total_damage=0.0
	var damage_events=0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): profile_io+=1
	func save_game(): return true
	func spawn_ball(pos,kind,velocity=Vector2(0,85),jitter: bool=true):
		super.spawn_ball(pos,kind,velocity,jitter)
		if balls[-1].get("jam",false): jam_launched+=1
	func damage_peg(peg,damage,impact_first_hit: bool=false) -> Dictionary:
		var event=super.damage_peg(peg,damage,impact_first_hit)
		total_damage+=event.damage
		if event.damage>0: damage_events+=1
		if measuring_jam: jam_damage+=event.damage
		return event

func require(ok: bool,label: String):
	if not ok: failures.append(label);print("FAIL: ",label)

func sum_hp(pegs: Array) -> float:
	var amount=0.0
	for peg in pegs: amount+=maxf(0.0,float(peg.hp))
	return amount

func target_x(g,aim_rng: RandomNumberGenerator,noise: bool) -> float:
	var target=Vector2(360,10000)
	for peg in g.pegs:
		if peg.hp>0 and peg.p.y<target.y: target=peg.p
	return clampf(target.x+(aim_rng.randf_range(-AIM_ERROR,AIM_ERROR) if noise else 0.0),66,654)

func simulate(tray: int,pair: Array,seed_variant: int,policy: String,quick: bool) -> Dictionary:
	var g=Fixture.new()
	g.testing=true;g.sound_on=false;g.reduced_motion=true
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.page_transition.enabled=false;g.set_active_area("bakery")
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.bakery_ability=MeasuredJam.new(g)
	g.ability_access=g.ability_access.get_script().new(false)
	g.highest_unlocked=tray;g.mode="shop";g.bank=1000000
	var start_failures=failures.size()
	var ordinary_count=0
	for node in g.upgrade_graph().nodes():
		var bought=g.buy_upgrade_node(node.x,node.y)
		require(bought,"Ordinary purchase failed: "+str(node))
		if bought: ordinary_count+=1
	require(g.levels==g.MAX_LEVELS and ordinary_count==62,"Probe must own the full legal ordinary graph")
	require(g.bakery_ability.buy(),"Earned Jam Burst purchase failed")
	if quick: require(g.bakery_ability.quick_buy(),"Far-end Quick Jam claim failed")
	for kind in g.equipped.duplicate(): g.toggle_module(kind)
	for kind in pair: g.toggle_module(kind)
	require(g.module_slots()==2 and g.equipped==pair,"Probe uses exactly one legal two-slot special pairing")
	require(g.bakery_ability.owned() and g.bakery_ability.quick_owned()==quick and not g.ability_early_access("bakery"),"Probe uses earned ability ownership without early access")
	if failures.size()>start_failures:
		g.free();return {"valid":false,"tray":tray,"pair":pair,"quick":quick}
	g.current_level=tray;g.start_shift();g.run_transition.finish()
	var seed_value=1719+tray*104729+seed_variant*7919
	g.rng.seed=seed_value
	var aim_rng=RandomNumberGenerator.new();aim_rng.seed=9001+seed_variant*104729
	var initial_hp=sum_hp(g.pegs)
	var initial_duration=g.remaining
	var aim_clock=0.0
	var desired_x=g.aim_x
	var ticks=0
	var pickup_count=0
	var peak_balls=0
	var sweep_phase=aim_rng.randf_range(0,TAU)
	var observed_cadence=int(g.bakery_run.get("every",5))
	require(observed_cadence==(4 if quick else 5),"Actual run cadence matches the purchased variant")
	while g.mode=="play" and ticks<7200:
		if not g.clear_draining:
			match policy:
				"instant": g.aim_x=target_x(g,aim_rng,false)
				"sweep": g.aim_x=360+280*sin(g.run_elapsed*TAU/2.8+sweep_phase)
				_:
					aim_clock-=STEP
					if aim_clock<=0:
						desired_x=target_x(g,aim_rng,true);aim_clock+=RETARGET_SECONDS
					g.aim_x=move_toward(g.aim_x,desired_x,FINGER_SPEED*STEP)
			for pickup in g.pickups.duplicate():
				var before=g.pickups.size();g.collect_pickups(pickup.p)
				pickup_count+=before-g.pickups.size()
		g.step(STEP);ticks+=1
		peak_balls=maxi(peak_balls,g.balls.size())
	var remaining_hp=sum_hp(g.pegs)
	var remaining_pegs: Array[Dictionary]=[]
	for peg in g.pegs:
		if peg.hp>0: remaining_pegs.append({"kind":peg.kind,"hp":peg.hp,"max_hp":peg.max,"position":[peg.p.x,peg.p.y]})
	require(g.mode=="result" and g.profile_io==0,"Bounded probe terminates without reading a player profile")
	require(absf(initial_hp-remaining_hp-g.total_damage)<.00001,"Measured damage conserves the board's actual HP")
	require(g.jam_damage<=g.jam_activations*2*g.power_damage()*.75+.00001,"Jam damage stays inside its actual bounded two-target splash budget")
	var result={"valid":true,"tray":tray,"pair":pair.duplicate(),"seed_variant":seed_variant,"physics_seed":seed_value,
		"policy":policy,"quick":quick,"cadence":observed_cadence,"flow_rules":g.run_rules_revision,"clear":g.level_won,
		"initial_hp":initial_hp,"hp_remaining":remaining_hp,"hp_remaining_fraction":remaining_hp/initial_hp,
		"pegs":g.pegs.size(),"destroyed":g.destroyed,"remaining_pegs":remaining_pegs,"elapsed":g.run_elapsed,
		"base_duration":initial_duration,"bonus_seconds":g.time_bonus,"time_pickups":pickup_count,"coins":g.shift_coins,
		"power":g.power_damage(),"drops":g.type_drops.duplicate(),"jam_launched":g.jam_launched,
		"jam_activations":g.jam_activations,"jam_damage":g.jam_damage,"total_damage":g.total_damage,"damage_events":g.damage_events,
		"peak_balls":peak_balls,"live_balls_at_end":g.balls.size(),"profile_io":g.profile_io,
		"ordinary_nodes_bought":ordinary_count,"earned_jam":true,"early_access":g.ability_early_access("bakery"),"terminated":g.mode=="result"}
	g.free();return result

func add_run(tray: int,pair: Array,seed_variant: int,policy: String,quick: bool):
	var result=simulate(tray,pair,seed_variant,policy,quick)
	results.append(result)
	print("BAKERY_JAM_BALANCE_RUN ",JSON.stringify(result))

func _initialize():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not output.is_absolute_path(): push_error("Probe requires an absolute result path");quit(2);return
	var smoke="--smoke" in OS.get_cmdline_user_args()
	for tray in [10,11,12]:
		for pair in ([PAIRS[0]] if smoke else PAIRS):
			for seed_variant in ([0] if smoke else [0,1,2]):
				for quick in [false,true]: add_run(tray,pair,seed_variant,"track",quick)
	if not smoke:
		for pair in PAIRS:
			for seed_variant in [0,1,2]:
				for quick in [false,true]: add_run(10,pair,seed_variant,"sweep",quick)
		for tray in [10,11,12]:
			for quick in [false,true]: add_run(tray,PAIRS[0],0,"instant",quick)
		var replay=simulate(10,PAIRS[0],0,"track",false)
		require(replay==results[0],"Repeated initial seed and aiming policy produce an identical result")
	var report={"results":results,"failures":failures,"runs":results.size(),"failed":failures.size(),
		"scope":"Fixed maximum legal ordinary build and earned Jam; synthetic wallet, no early access. Identical initial seeds, not forced identical later random-drop streams.",
		"aim":{"track":{"retarget_seconds":RETARGET_SECONDS,"maximum_x_speed":FINGER_SPEED,"uniform_x_error":AIM_ERROR,"target":"topmost surviving peg"},
		"sweep":{"period_seconds":2.8,"x_range":[80,640]},"instant":"Instant exact topmost targeting, optimistic reference only"},
		"pickups":"Immediate automatic time-pickup collection; clock pegs retain normal mechanics and cap",
		"legal_special_slots":2,"human_playtest":false,"natural_wallet_progression":false}
	var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BAKERY_JAM_BALANCE_RESULT runs=%d cleared=%d invalid=%d"%[results.size(),results.filter(func(item): return item.get("clear",false)).size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
