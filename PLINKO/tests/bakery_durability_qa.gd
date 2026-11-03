extends SceneTree
## Campaign durability contracts, using packaged data and in-memory save writes.
## No fixture loads, resets or writes a player's profile.
const Snapshot = preload("res://scripts/run_snapshot.gd")
const Rules = preload("res://scripts/flow_rules.gd")
const PREVIOUS_BAKERY_FINGERPRINT = "8ea5737038153f21aabf79e092109a9559ffcd5c5cf682d1d0ca4d3f5fa0b21b"
const FLAT_BAKERY_FINGERPRINT = "475381e6848aa2724ef4d3356f9081bcc3d54710dc99410d1bb5a6e2cbdb1e6d"
const PRE_LAUNCHER_GELATO_FINGERPRINT = "ba3aef12301ec366a8d95bede61073f1aaa2325d31c8a8fa165708085bf0d772"
const GELATO_HP = [6,6,6,12,12,12,18,18,18,24,24,24]
const TIER_IDS = ["bronze","silver","gold","diamond"]
const TIER_HP = [6,12,18,24]
var passed = 0
var failures: Array[String] = []

class FixtureGame extends "res://scripts/main.gd":
	var profile_reads = 0
	var memory_writes = 0
	var saved_profile: Dictionary = {}
	func _ready(): pass
	func load_game(): profile_reads += 1
	func write_profile_file(data: Dictionary) -> bool:
		memory_writes += 1
		saved_profile = data.duplicate(true)
		return true

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func same(a, b) -> bool:
	return JSON.stringify(a,"",true) == JSON.stringify(b,"",true)

func fixture(area: String = "bakery"):
	var game = FixtureGame.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	game.set_active_area(area)
	game.highest_unlocked = 12
	return game

func close_fixture(game):
	check(game.profile_reads==0,"Durability fixture never requests a player-profile read")
	game.free()

func ordinary_peg(game):
	for peg in game.pegs:
		if peg.kind=="normal": return peg
	return {}

func campaign_curve_and_checkpoints():
	var game = fixture()
	var previous_hp = 0.0
	for tray in range(1,13):
		game.current_level = tray
		game.start_shift()
		var spec: Dictionary = game.board_data[tray-1]
		var base_hp = float(spec.base_hp)
		var band = floori((tray-1)/3.0)
		check(base_hp==TIER_HP[band] and spec.get("strength_tier")==TIER_IDS[band],"Bakery tray %d pairs its material with the correct difficulty band" % tray)
		if tray in [4,7,10]:
			check(base_hp==previous_hp+6.0,"Bakery tray %d introduces the next six-HP difficulty wall" % tray)
		elif tray>1:
			check(base_hp==previous_hp,"Bakery tray %d holds peg strength steady within its band" % tray)
		if tray==1: check(base_hp==6.0,"Bakery tray 1 retains its six-HP opening")
		previous_hp = base_hp
		check(game.peg_strength_tier()==TIER_IDS[band] and game.peg_strength_tier(tray)==TIER_IDS[band],"Selected and explicit material lookup match tray %d" % tray)
		check(game.peg_strength_tier(tray,true).is_empty(),"Fixed Trial presentation does not claim campaign material on tray %d" % tray)
		var current_hp=Rules.normal_hp(base_hp,tray,false,game.run_rules_revision)
		check(is_equal_approx(game.normal_peg_hp(),current_hp) and is_equal_approx(game.normal_peg_hp(tray),current_hp),"Selected and explicit HP lookup match Bakery tray %d" % tray)
		var health_matches = true
		for peg in game.pegs:
			var expected = current_hp*(float(spec.armored_hp_multiplier) if peg.kind=="armored" else 1.0)
			health_matches = health_matches and is_equal_approx(peg.max,expected) and is_equal_approx(peg.hp,expected)
		check(health_matches,"Bakery tray %d applies normal HP and its authored armor factor" % tray)
		var first_pegs = game.pegs.duplicate(true)
		game.start_shift()
		check(same(first_pegs,game.pegs),"Retry restores the same full-health pegs on Bakery tray %d" % tray)
		game.damage_peg(ordinary_peg(game),.25)
		var snapshot = Snapshot.capture(game)
		var decoded = Snapshot.validate_and_decode(JSON.parse_string(JSON.stringify(snapshot)),game)
		check(decoded.get("ok",false) and same(decoded.get("state",{}).get("pegs",[]),game.pegs),"Damaged Bakery tray %d round-trips through the current checkpoint" % tray)
		var malformed = snapshot.duplicate(true)
		malformed.pegs[0].max = float(malformed.pegs[0].max)+1.0
		check(not Snapshot.validate_and_decode(malformed,game).get("ok",false),"Current fingerprint cannot authorize an incorrect peg maximum on tray %d" % tray)
		if tray>=10:
			check(ceili(base_hp/game.power_damage(10))>2,"Max Power does not reduce late Bakery tray %d normal pegs to two hits" % tray)
	close_fixture(game)

func damage_hits_and_preview():
	var game = fixture()
	for tray in [1,6,12]:
		game.current_level = tray
		for power in [0,3,6,10]:
			game.levels[1] = power
			game.start_shift()
			var peg = ordinary_peg(game)
			var hp = float(peg.max)
			var damage = game.power_damage()
			var hits = ceili(hp/damage)
			for hit in range(hits-1): game.damage_peg(peg,damage)
			check(peg.hp>0 and game.destroyed==0,"Tray %d Power %d peg survives until its last required hit" % [tray,power])
			game.damage_peg(peg,damage)
			check(peg.hp<=0 and game.destroyed==1,"Tray %d Power %d breaks after exactly %d hits" % [tray,power,hits])
			check(game.upgrade_preview(1)=="Hit pegs harder","Power preview explains its function at tray %d tier %d" % [tray,power])
			check(game.upgrade_map._effect_text(1,power)=="Hit pegs harder","Live Power card stays concise at tray %d tier %d" % [tray,power])
	close_fixture(game)

func damage_reward_accounting():
	var game = fixture()
	for tray in [1,6,12]:
		game.current_level = tray
		game.start_shift()
		var peg = ordinary_peg(game)
		var hp = float(peg.max)
		game.damage_peg(peg,1.0)
		var budget=Rules.damage_budget(6,tray,false,game.run_rules_revision)
		check(game.shift_coins==floorf(float(budget)/hp) and peg.hp==hp-1.0,"Tray %d nonlethal damage earns its cumulative share of the fixed coin budget" % tray)
		game.damage_peg(peg,9999.0)
		var break_reward = int(game.tuning.peg_base+floor((tray-game.tuning.peg_level_offset)*game.tuning.peg_level_step))+mini(1,int(game.tuning.combo_credit_cap))
		var expected = budget+Rules.break_reward(break_reward,tray,false,game.run_rules_revision)
		check(is_equal_approx(game.shift_coins,expected),"Tray %d overkill cannot exceed its pinned damage budget plus one break payout" % tray)
		var paid = game.shift_coins
		game.damage_peg(peg,9999.0)
		check(game.shift_coins==paid and game.destroyed==1,"Tray %d dead peg cannot pay damage or break rewards twice" % tray)
	close_fixture(game)

func gelato_and_area_switches():
	var game = fixture("gelato")
	check(Snapshot.content_fingerprint("gelato")!=PRE_LAUNCHER_GELATO_FINGERPRINT,"Gelato launcher revision has its own updated checkpoint content")
	for tray in range(1,13):
		game.current_level = tray
		game.start_shift()
		var hp = Rules.normal_hp(float(GELATO_HP[tray-1]),tray,false,game.run_rules_revision)
		check(game.normal_peg_hp()==hp and ordinary_peg(game).max==hp,"Gelato tray %d uses its authored strength band" % tray)
		check(game.peg_strength_tier()==TIER_IDS[floori((tray-1)/3.0)],"Gelato tray %d shows its matching material" % tray)
		var snapshot = Snapshot.capture(game)
		check(game.restore_active_run(snapshot) and game.mode=="paused","Gelato tray %d checkpoint resumes paused" % tray)
	game.mode = "home"
	game.shift_claimed = true
	game.current_level = 12
	game.bank = 100.25
	game.area_records = {"gelato":game.AreaCampaign.capture_local(game),"bakery":game.AreaCampaign.default_record()}
	game.area_records.bakery.current_level = 12
	game.area_records.bakery.highest_unlocked = 12
	game.area_records.bakery.bank = 200.5
	check(game.switch_area("bakery") and game.area_id=="bakery" and game.bank==200.5,"Owned-area switching restores Bakery's own tray and wallet")
	var bakery_hp = game.normal_peg_hp()
	check(bakery_hp>8 and game.upgrade_preview(1)=="Hit pegs harder","Bakery tray 12 retains durability and plain Power copy after switching areas")
	check(game.upgrade_map._effect_text(1,1)=="Hit pegs harder","Live Bakery Power card remains functional after switching areas")
	check(game.switch_area("gelato") and is_equal_approx(game.normal_peg_hp(),Rules.normal_hp(24.0,12,false)) and game.bank==100.25,"Returning to Gelato preserves its HP and wallet")
	check(ceili(game.normal_peg_hp()/game.power_damage(0))==28 and ceili(game.normal_peg_hp()/game.power_damage(1))==19,"Gelato tray 12 applies its current HP with unchanged ordinary Power damage")
	check(game.upgrade_map._effect_text(1,1)=="Hit pegs harder","Live Gelato Power card stays simple after switching back")
	check(game.memory_writes==2,"Owned-area transactions were committed only to fixture memory")
	close_fixture(game)

func old_checkpoint_and_completed_reward():
	var game = fixture()
	game.current_level = 12
	game.bank = 7654.5
	game.levels = [3,8,1,0,0,0,2,4]
	game.module_vouchers = 2
	game.monetization.entitlements = {"remove_ads":true,"baker_toolkit":true}
	game.monetization.store_owned = game.monetization.entitlements.duplicate()
	game.start_shift()
	var checkpoint = Snapshot.capture(game)
	check(checkpoint.fingerprint!=PREVIOUS_BAKERY_FINGERPRINT,"New Bakery durability produces a new content fingerprint")
	var progression = game.campaign_profile()
	var commerce = game.monetization.export_state()
	for fingerprint in [PREVIOUS_BAKERY_FINGERPRINT,FLAT_BAKERY_FINGERPRINT]:
		checkpoint.fingerprint = fingerprint
		check(not game.restore_active_run(checkpoint) and game.mode=="home" and not game.snapshot_rejection.is_empty(),"Previous Bakery active checkpoint returns safely Home")
		check(same(progression,game.campaign_profile()) and same(commerce,game.monetization.export_state()),"Rejected old checkpoint retains wallet, tiers, vouchers and purchase state")
	game.start_shift()
	game.shift_coins = 37.25
	game.finish_shift(false)
	check(game.save_game() and game.saved_profile.has("pending_result") and not game.saved_profile.has("active_run"),"Completed earnings use the pending-result path rather than an obsolete active checkpoint")
	var pending: Dictionary = game.saved_profile.get("pending_result",{})
	check(pending.get("coins")==37.25 and pending.get("area_id")=="bakery" and not pending.has("fingerprint"),"Pending result preserves its exact earned amount independently of board fingerprint")
	var before = game.bank
	var payout = game.result_payout()
	game.collect_reward()
	check(is_equal_approx(game.bank,before+payout),"Completed payout remains collectible after Bakery checkpoint rejection")
	var once = game.bank
	game.collect_reward()
	check(game.bank==once,"Completed payout remains once-only")
	close_fixture(game)

func fixed_trials_remain_separate():
	var records = {"4":7.25,"8":9.5,"12":10.75}
	for tray in [4,8,12]:
		var game = fixture()
		game.current_level = 12
		game.bank = 1234.5
		game.levels = [3,4,2,1,0,0,1,2]
		game.equipped = ["ricochet"]
		game.trial_records = records.duplicate()
		var campaign = game.AreaCampaign.capture_local(game)
		check(game.normal_peg_hp(tray,true)==6.0 and game.normal_peg_hp(tray)>6.0,"Trial %d keeps six HP separately from its stronger campaign tray" % tray)
		check(game.begin_trial(tray) and game.levels==[6,6,2,1,1,1,0,4],"Trial %d retains the existing fixed upgrade profile" % tray)
		game.start_shift()
		var trial_health = true
		for peg in game.pegs:
			var expected = 12.0 if peg.kind=="armored" else 6.0
			trial_health = trial_health and peg.hp==expected and peg.max==expected
		check(trial_health,"Trial %d uses six-HP ordinary pegs and twelve-HP armor" % tray)
		game.damage_peg(ordinary_peg(game),.25)
		var snapshot = Snapshot.capture(game)
		var decoded = Snapshot.validate_and_decode(JSON.parse_string(JSON.stringify(snapshot)),game)
		check(decoded.get("ok",false) and same(decoded.get("state",{}).get("pegs",[]),game.pegs),"Trial %d checkpoint validates against fixed Trial HP" % tray)
		var tampered = snapshot.duplicate(true)
		tampered.pegs[0].max = game.normal_peg_hp(tray)*(2.0 if tampered.pegs[0].kind=="armored" else 1.0)
		check(not Snapshot.validate_and_decode(tampered,game).get("ok",false),"Trial %d rejects a checkpoint substituted with campaign peg HP" % tray)
		check(game.save_game() and same(game.saved_profile.areas.bakery.trial_records,records),"Saving Trial %d preserves comparable best records" % tray)
		var resumed = fixture()
		resumed.AreaCampaign.apply_local(resumed,campaign)
		check(resumed.restore_active_run(snapshot) and resumed.mode=="paused" and resumed.trial_active and same(resumed.pegs,game.pegs),"Trial %d resumes paused with its original fixed durability" % tray)
		resumed.end_trial()
		check(same(resumed.AreaCampaign.capture_local(resumed),campaign),"Leaving resumed Trial %d restores campaign progress and existing records" % tray)
		game.end_trial()
		check(same(game.AreaCampaign.capture_local(game),campaign),"Leaving Trial %d preserves campaign progress and existing records" % tray)
		game.start_shift()
		check(not game.trial_active and ordinary_peg(game).max==game.normal_peg_hp(12) and ordinary_peg(game).max>6.0,"Campaign play after Trial %d uses the new durability again" % tray)
		close_fixture(resumed)
		close_fixture(game)
	var gelato = fixture("gelato")
	for tray in [4,8,12]:
		check(gelato.normal_peg_hp(tray,true)==6.0,"Gelato Trial %d uses the fixed six-HP launcher challenge" % tray)
	close_fixture(gelato)

func _initialize():
	campaign_curve_and_checkpoints()
	damage_hits_and_preview()
	damage_reward_accounting()
	gelato_and_area_switches()
	old_checkpoint_and_completed_reward()
	fixed_trials_remain_separate()
	print("BAKERY_DURABILITY_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
