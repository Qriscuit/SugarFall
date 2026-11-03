extends SceneTree
## Deterministic economy experiments, not human play-time estimates.
## Uses an immutable v0.6.10 main snapshot and current authored graphs/layouts.
## No profile IO, paid boosts, ads, forced special drops, or free purchases.
const OUT = "res://verification/economy-rebalance-20261102/measurements/"
const DT = 1.0/60.0

class Baseline extends "res://verification/economy-rebalance-20261102/measurements/baseline_main.gd":
	var profile_io = 0
	func _ready(): pass
	func load_game(): profile_io += 1
	func save_game(): profile_io += 1; return false
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func begin_automatic_ad(): pass
	func load_area_tuning(id: String):
		tuning = bakery_tuning.duplicate(true)
		if id == "gelato":
			var frozen = JSON.parse_string(FileAccess.get_file_as_string("res://verification/economy-rebalance-20261102/measurements/baseline_gelato_economy.json"))
			for key in frozen: tuning[key] = frozen[key]

class Candidate extends Baseline:
	func damage_peg(peg, damage):
		if peg.hp <= 0: return
		var before = maxf(0.0,peg.hp)
		if damage == 9999:
			damage = power_damage() * (6.0 if peg.kind == "armored" else 4.0)
		super.damage_peg(peg,damage)
		var after = maxf(0.0,peg.hp)
		var old_credit = maxi(0,int(ceil(before)-ceil(after))) * float(tuning.get("damage_credit_scale",1.0))
		var budget = 9.0 if peg.kind == "armored" else 6.0
		var paid_before = floori(budget * (peg.max-before)/peg.max + .0000001)
		var paid_after = floori(budget * (peg.max-after)/peg.max + .0000001)
		shift_coins = round_credits(shift_coins-old_credit+paid_after-paid_before)

class Production extends "res://scripts/main.gd":
	var profile_io = 0
	func _ready(): pass
	func load_game(): profile_io += 1
	func save_game(): profile_io += 1; return false
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func begin_automatic_ad(): pass

func fixture(area: String, variant: String):
	var g = Production.new() if variant == "production" else (Baseline.new() if variant == "baseline" else Candidate.new())
	g.testing = true
	g.sound_on = false
	g.reduced_motion = true
	g.first_run_guide.completed = true
	var frozen = JSON.parse_string(FileAccess.get_file_as_string(OUT+"baseline_economy.json"))
	for key in frozen: g.bakery_tuning[key] = frozen[key]
	g.set_active_area(area)
	return g

func play(g, seed_value: int) -> Dictionary:
	g.start_shift()
	g.rng.seed = seed_value
	var t = 0.0
	var reaction = 0.0
	var target = Vector2(360,515)
	var cursor = target
	while g.mode == "play" and t < 120.0:
		reaction -= DT
		if reaction <= 0.0:
			reaction = .4
			var next = null
			for peg in g.pegs:
				if peg.hp > 0 and (next == null or peg.p.y < next.p.y): next = peg
			if next != null: target = next.p
			for pickup in g.pickups:
				if pickup.life > 0 and pickup.p.distance_to(cursor) < 250.0*pickup.life:
					target = pickup.p
					break
		cursor = cursor.move_toward(target,250.0*DT)
		# Match input bounds while pickups still use the actual finger position.
		g.aim_x = clampf(cursor.x,66,654)
		g.aim_y = clampf(cursor.y,330,1000 if g.area_id == "gelato" else 770)
		g.collect_pickups(cursor)
		g.step(DT)
		t += DT
	var hp = 0.0
	for peg in g.pegs: hp += maxf(0.0,peg.hp)
	return {"board":g.wave,"won":g.level_won,"seconds":snappedf(t,.01),"credits":g.shift_coins,"destroyed":g.destroyed,"pegs":g.pegs.size(),"hp_remaining":hp,"levels_before":g.levels.duplicate(),"twins":g.twin_launchers,"impact_drops":g.type_drops.impact,"mode":g.mode}

func shop(g, reserve_twins: bool) -> Array:
	var buys = []
	for kind in ["impact","splitter","ricochet"]: g.claim_module(kind)
	g.mode = "shop"
	if reserve_twins and g.gelato_launcher.unlocked():
		if g.buy_twin_launchers(): buys.append("twins")
		else: return buys
	for _purchase in range(100):
		var best = -1
		for i in range(8):
			if not g.upgrade_unlocked(i) or g.upgrade_cost(i) > g.bank: continue
			if best < 0 or g.upgrade_cost(i) < g.upgrade_cost(best): best = i
		if best < 0: break
		if not g.buy_upgrade(best): break
		buys.append(best)
		for kind in ["impact","splitter","ricochet"]: g.claim_module(kind)
		if reserve_twins and g.gelato_launcher.unlocked(): break
	return buys

func equip(g):
	for kind in g.equipped.duplicate(): g.toggle_module(kind)
	var preferred = ["impact","splitter","ricochet"] if g.current_level >= 7 else ["splitter","ricochet","impact"]
	for kind in preferred:
		var idx = ["ricochet","splitter","impact"].find(kind)+3
		if g.equipped.size() < g.module_slots() and g.levels[idx] > 0: g.toggle_module(kind)

func campaign(area: String, variant: String, seed_value: int, limit: int, reserve_twins: bool) -> Dictionary:
	var g = fixture(area,variant)
	var trace = []
	var total_seconds = 0.0
	var total_credits = 0.0
	var failures = 0
	var purchases = 0
	var first_purchase = 0
	for attempt in range(limit):
		var row = play(g,210000+seed_value*1000+attempt)
		if row.mode != "result":
			push_error("Simulation failed to finish: "+JSON.stringify(row))
			break
		total_seconds += row.seconds
		total_credits += row.credits
		if not row.won: failures += 1
		g.collect_reward()
		row["bank_before_shop"] = g.bank
		var buys = [] if g.chapter_complete else shop(g,reserve_twins)
		purchases += buys.size()
		if first_purchase == 0 and not buys.is_empty(): first_purchase = attempt+1
		equip(g)
		row["buys"] = buys
		row["bank_after_shop"] = g.bank
		row["levels_after"] = g.levels.duplicate()
		trace.append(row)
		if g.chapter_complete: break
		if (attempt+1)%40 == 0: print("PROGRESS ",area," ",variant," seed=",seed_value," attempts=",attempt+1," tray=",g.current_level)
	var result = {"area":area,"variant":variant,"seed":seed_value,"reserve_twins":reserve_twins,"completed":g.chapter_complete,"final_board":g.current_level,"attempts":trace.size(),"failures":failures,"gameplay_seconds":snappedf(total_seconds,.01),"gross_credits":snappedf(total_credits,.01),"bank_at_end":g.bank,"levels_at_end":g.levels.duplicate(),"twins_at_end":g.twin_launchers,"first_purchase_attempt":first_purchase,"purchase_count":purchases,"profile_io":g.profile_io,"trace":trace}
	var summary = result.duplicate()
	summary.erase("trace")
	print(JSON.stringify(summary))
	g.free()
	return result

func _initialize():
	var args = OS.get_cmdline_user_args()
	var seeds = 1
	var limit = 160
	var variants = ["baseline","candidate"]
	var areas = ["bakery","gelato"]
	var output = "campaign_comparison.json"
	for arg in args:
		if arg.begins_with("--seeds="): seeds = int(arg.trim_prefix("--seeds="))
		if arg.begins_with("--limit="): limit = int(arg.trim_prefix("--limit="))
		if arg.begins_with("--variants="): variants = Array(arg.trim_prefix("--variants=").split(","))
		if arg.begins_with("--areas="): areas = Array(arg.trim_prefix("--areas=").split(","))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var results = []
	for area in areas:
		for variant in variants:
			for seed_value in range(seeds):
				results.append(campaign(area,variant,seed_value,limit,"--reserve-twins" in args))
				var f = FileAccess.open(OUT+output,FileAccess.WRITE)
				f.store_string(JSON.stringify({"method":"Bounded 0.4s reaction, 250px/s movement, topmost living peg and reachable clock pickup, actual graph-gated cheapest-affordable shopping; no ads/boosts; no human timing claim.","results":results},"\t"))
				f.close()
	quit()
