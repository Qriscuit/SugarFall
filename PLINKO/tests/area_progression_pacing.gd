extends SceneTree
## Current production rules; linked wallets; no grants, trials, ads or paid boosts.
## All player decisions below are synthetic and bounded, not human acceptance.
const DT = 1.0/60.0
const AREA_LIMIT = 220
const FEE_LIMIT = 25
const AC = preload("res://scripts/area_campaign.gd")
var failures: Array = []
var checks = 0
var output_path = ""

class Fixture extends "res://scripts/main.gd":
	var profile_reads = 0
	var disk_saves = 0
	var memory_commits: Array = []
	func _ready(): pass
	func load_game(): profile_reads += 1
	func save_game(): disk_saves += 1; return false
	func write_profile_file(data: Dictionary) -> bool:
		memory_commits.append(data.duplicate(true))
		return true
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func begin_automatic_ad(): pass

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func fixture():
	var g = Fixture.new()
	g.testing = true
	g.sound_on = false
	g.reduced_motion = true
	g.first_run_guide.completed = true
	g.first_run_guide.active = false
	check(g.set_active_area("bakery"), "Current Bakery authored board data loaded")
	check(g.bank == 0 and g.levels == [0,0,0,0,0,0,0,0], "Fresh campaign starts with no funds or upgrades")
	return g

func play(g, run_seed: int) -> Dictionary:
	var before = g.levels.duplicate()
	var wallet = g.bank
	var equipment = g.equipped.duplicate()
	g.mode = "home"
	g.start_shift()
	g.run_transition.finish()
	g.rng.seed = run_seed
	var t = 0.0
	var reaction = 0.0
	var target = Vector2(360,515)
	var cursor = target
	var peak_balls = 0
	var prism_taps = 0
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
			if g.area_id == "crystal" and g.crystal_run.get("offer_life",0.0)>0:
				target = g.crystal_run.offer_position
		cursor = cursor.move_toward(target,250.0*DT)
		# A tap uses the same finger position and four-second offer window.
		# It is never collected by directly addressing a remote pickup.
		if g.area_id == "crystal" and g.crystal_run.get("offer_life",0.0)>0 and cursor.distance_to(g.crystal_run.offer_position)<=24:
			if g.crystal_launcher.try_collect(cursor): prism_taps += 1
		g.aim_x = clampf(cursor.x,66,654)
		g.aim_y = clampf(cursor.y,330,770 if g.area_id == "bakery" else 1000)
		g.collect_pickups(cursor)
		g.step(DT)
		peak_balls = maxi(peak_balls,g.balls.size())
		t += DT
	var hp = 0.0
	for peg in g.pegs: hp += maxf(0.0,peg.hp)
	check(g.mode == "result", "%s run must terminate" % g.area_id)
	check(g.bank == wallet, "Run earnings remain unclaimed until Collect")
	check(not g.developer_money_enabled(), "Normal wallet only")
	check(not g.reward_earned and not g.trial_active, "No ad reward or trial income")
	var payout = g.collection_payout()
	var row = {"tray":g.wave,"won":g.level_won,"seconds":snappedf(t,.01),"credits":payout,"destroyed":g.destroyed,"peg_count":g.pegs.size(),"hp_remaining":snappedf(hp,.001),"levels_before":before,"equipment":equipment,"twins":g.twin_launchers,"second_prism":g.crystal_second_prism,"peak_balls":peak_balls,"prism_taps":prism_taps,"offers_started":g.crystal_run.get("next_offer",0),"wallet_before_run":wallet,"time_bonus":g.time_bonus}
	g.collect_reward()
	check(is_equal_approx(g.bank,g.round_credits(wallet+payout)), "Exactly one earned payout credited")
	var after_claim = g.bank
	g.collect_reward()
	check(g.bank == after_claim, "Repeated Collect does not duplicate earnings")
	row["wallet_after_claim"] = g.bank
	return row

func next_node(g, family: int) -> Vector2i:
	# Uses the exact current shuffled ownership graph, not aggregate tier grants.
	return g.next_shop_node(family)

func voucher_claims(g, buys: Array):
	for family in [5,4,3]:
		var kind = ["ricochet","splitter","impact"][family-3]
		var node = next_node(g,family)
		var wallet = g.bank
		var vouchers = g.module_vouchers
		if g.claim_module(kind):
			check(vouchers>0 and g.module_vouchers==vouchers-1 and g.bank==wallet, "Earned voucher consumed without coin debit")
			buys.append({"type":"voucher","family":family,"node":[node.x,node.y],"cost":0,"wallet":g.bank})

func buy_node(g, node: Vector2i, buys: Array) -> bool:
	if node.x<0: return false
	var price = g.upgrade_cost(node.x)
	var wallet = g.bank
	var tier = g.levels[node.x]
	var reset = g.is_rebuild_power_node(node.x,node.y)
	if not g.buy_upgrade_node(node.x,node.y):
		check(g.bank==wallet and g.levels[node.x]==tier, "Rejected buy leaves wallet and tier unchanged")
		return false
	check(wallet>=price and is_equal_approx(g.bank,g.round_credits(wallet-price)), "Legal node uses earned balance and exact cost")
	check(g.levels[node.x]==tier+1 and g.shop_node_owned(node.x,node.y), "Exact node ownership and family tier increment")
	buys.append({"type":"rebuild" if reset else "upgrade","family":node.x,"node":[node.x,node.y],"tier":g.levels[node.x],"cost":price,"wallet":g.bank})
	return true

func shop(g, policy: String) -> Array:
	var buys: Array = []
	g.mode = "shop"
	voucher_claims(g,buys)
	for _purchase in range(100):
		var cheapest_node_cost = 100000000
		for family in range(8):
			if next_node(g,family).x>=0: cheapest_node_cost=mini(cheapest_node_cost,g.upgrade_cost(family))
		if (policy == "signature" or cheapest_node_cost>=g.gelato_launcher.cost()) and g.area_id == "gelato" and g.gelato_launcher.unlocked():
			var bank_before = g.bank
			var levels_before = g.levels.duplicate()
			if g.buy_twin_launchers():
				check(levels_before[1]>=6 and g.highest_unlocked>=8 and bank_before>=3000, "Twin gate and funds earned legally")
				check(g.bank==g.round_credits(bank_before-3000) and g.levels[1]==0 and g.power_reset_tier==levels_before[1], "Twin purchase debits and resets only Power")
				for i in range(8):
					if i!=1: check(g.levels[i]==levels_before[i], "Twin keeps other upgrade families")
				buys.append({"type":"twins","cost":3000,"power_before":levels_before[1],"wallet":g.bank})
			else:
				check(g.bank==bank_before and g.levels==levels_before, "Unaffordable Twin changes nothing")
				break
		if (policy == "signature" or cheapest_node_cost>=g.crystal_launcher.cost()) and g.area_id == "crystal" and g.crystal_launcher.unlocked():
			var wallet = g.bank
			var powers = g.levels.duplicate()
			if g.crystal_launcher.buy():
				check(wallet>=900 and g.highest_unlocked>=6 and powers[1]>=4 and g.bank==g.round_credits(wallet-900) and g.levels==powers, "Second Prism respects gates, pays 900 and keeps build")
				buys.append({"type":"second_prism","cost":900,"wallet":g.bank})
			else:
				check(g.bank==wallet and g.levels==powers, "Unaffordable Prism changes nothing")
				break
		if policy == "signature" and g.area_id == "gelato" and g.twin_launchers and g.levels[1]<g.power_reset_tier:
			if not buy_node(g,next_node(g,1),buys): break
			continue
		var best = Vector2i(-1,-1)
		for family in range(8):
			var candidate = next_node(g,family)
			if candidate.x<0 or g.upgrade_cost(family)>g.bank: continue
			if best.x<0 or g.upgrade_cost(family)<g.upgrade_cost(best.x): best=candidate
		if best.x<0: break
		if not buy_node(g,best,buys): break
		voucher_claims(g,buys)
	return buys

func equip(g):
	for kind in g.equipped.duplicate(): g.toggle_module(kind)
	var preferred = ["impact","splitter","ricochet"] if g.current_level>=7 else ["splitter","ricochet","impact"]
	for kind in preferred:
		var family = ["ricochet","splitter","impact"].find(kind)+3
		if g.equipped.size()<g.module_slots() and g.levels[family]>0: g.toggle_module(kind)

func signature_done(g, policy: String) -> bool:
	if policy != "signature": return true
	if g.area_id == "gelato": return g.twin_launchers and g.levels[1]>=g.power_reset_tier
	if g.area_id == "crystal": return g.crystal_second_prism
	return true

func campaign(g, policy: String, seed_value: int, area_index: int) -> Dictionary:
	var trace: Array = []
	var cleared_at = 0
	var first_purchase = 0
	var total_seconds = 0.0
	var total_credits = 0.0
	var purchase_count = 0
	var entry = {}
	var next_area = AC.next_area(g.area_id)
	var goal_done = false
	var fee_attempts = 0
	for attempt in range(AREA_LIMIT+FEE_LIMIT):
		if attempt>=AREA_LIMIT and not goal_done: break
		var row = play(g,910000+seed_value*10000+area_index*1000+attempt)
		row["attempt"] = attempt+1
		row["phase"] = "entry_fee" if goal_done else ("signature_after_clear" if cleared_at>0 else "campaign")
		total_seconds += row.seconds
		total_credits += row.credits
		if g.chapter_complete and cleared_at==0: cleared_at=attempt+1
		var buys: Array = []
		if not g.chapter_complete or not signature_done(g,policy): buys=shop(g,policy)
		if first_purchase==0 and not buys.is_empty(): first_purchase=attempt+1
		purchase_count += buys.size()
		equip(g)
		row["buys"] = buys
		row["wallet_after_shop"] = g.bank
		row["levels_after"] = g.levels.duplicate()
		row["twins_after"] = g.twin_launchers
		row["reset_tier"] = g.power_reset_tier
		row["prism_after"] = g.crystal_second_prism
		row["owned_nodes"] = g.gelato_owned_nodes.duplicate(true)
		row["reset_nodes"] = g.gelato_reset_power_nodes.duplicate(true)
		var next_cost = 100000000
		for family in range(8):
			if next_node(g,family).x>=0: next_cost=mini(next_cost,g.upgrade_cost(family))
		if g.gelato_launcher.unlocked(): next_cost=mini(next_cost,g.gelato_launcher.cost())
		if g.crystal_launcher.unlocked(): next_cost=mini(next_cost,g.crystal_launcher.cost())
		row["cheapest_next_cost"] = next_cost if next_cost<100000000 else 0
		row["coins_to_next"] = maxf(0,next_cost-g.bank) if next_cost<100000000 else 0
		trace.append(row)
		goal_done = g.chapter_complete and signature_done(g,policy)
		if goal_done:
			if next_area.is_empty(): break
			g.mode="home"
			var status=g.area_entry_status(next_area)
			if status.can_enter:
				entry={"source":g.area_id,"destination":next_area,"cost":status.cost,"wallet_before":g.bank,"after_attempt":attempt+1}
				break
			fee_attempts+=1
			if fee_attempts>FEE_LIMIT: break
		if (attempt+1)%40==0: print("PACING_PROGRESS ",policy," seed=",seed_value," area=",g.area_id," attempt=",attempt+1," tray=",g.current_level," bank=",g.bank," power=",g.levels[1])
	var result={"area":g.area_id,"completed":g.chapter_complete,"signature_goal":signature_done(g,policy),"clear_attempt":cleared_at,"attempts":trace.size(),"first_purchase_attempt":first_purchase,"purchase_count":purchase_count,"gameplay_seconds":snappedf(total_seconds,.01),"gross_credits":snappedf(total_credits,.01),"wallet_at_end":g.bank,"levels_at_end":g.levels.duplicate(),"twins_at_end":g.twin_launchers,"second_prism_at_end":g.crystal_second_prism,"entry":entry,"trace":trace}
	var summary=result.duplicate(); summary.erase("trace")
	print("PACING_AREA ",JSON.stringify(summary))
	return result

func linked_campaign(policy: String, seed_value: int) -> Dictionary:
	var g=fixture()
	var results: Array=[]
	for index in range(3):
		var result=campaign(g,policy,seed_value,index)
		results.append(result)
		if not result.completed or not result.signature_goal: break
		if index==2: break
		if result.entry.is_empty(): break
		var source=g.area_id
		var before=g.bank
		var entry_count=g.area_entries.size()
		check(g.enter_area(result.entry.destination), "Normal campaign entry succeeds after clear and fee")
		check(g.area_records[source].bank==g.round_credits(before-result.entry.cost), "Fee comes from predecessor wallet")
		check(g.bank==0 and g.levels==[0,0,0,0,0,0,0,0], "New area has independent empty wallet/build")
		check(g.area_entries.size()==entry_count+1, "One entry ledger item")
		result.entry["source_wallet_after"]=g.area_records[source].bank
	check(g.profile_reads==0 and g.disk_saves==0, "No real player profile IO")
	var result={"policy":policy,"seed":seed_value,"areas":results,"profile_reads":g.profile_reads,"disk_saves":g.disk_saves,"memory_commits":g.memory_commits.size(),"all_three_complete":results.size()==3 and results[2].completed,"all_signature_goals":results.size()==3 and results[1].signature_goal and results[2].signature_goal}
	g.free()
	return result

func _initialize():
	output_path=OS.get_environment("SUGARFALL_PACING_OUTPUT")
	if output_path.is_empty(): push_error("Explicit isolated output required"); quit(2); return
	var seeds=OS.get_environment("SUGARFALL_PACING_SEEDS").split(",",false)
	if seeds.is_empty(): seeds=PackedStringArray(["0"])
	var policies=OS.get_environment("SUGARFALL_PACING_POLICIES").split(",",false)
	if policies.is_empty(): policies=PackedStringArray(["economical","signature"])
	var results: Array=[]
	for policy in policies:
		for seed_text in seeds:
			results.append(linked_campaign(policy,int(seed_text)))
			var file=FileAccess.open(output_path,FileAccess.WRITE)
			file.store_string(JSON.stringify({"kind":"synthetic legal progression; not human playtest","dt":DT,"reaction_seconds":.4,"cursor_speed":250,"policy_scope":"economical buys cheapest eligible exact node including special; signature reserves special at gate and rebuilds paid Power; loadouts may be swapped freely","checks":checks,"failures":failures,"campaigns":results},"\t")); file.close()
	print("LEGAL_PACING_RESULT checks=",checks," failed=",failures.size()," campaigns=",results.size())
	quit(0 if failures.is_empty() else 1)
