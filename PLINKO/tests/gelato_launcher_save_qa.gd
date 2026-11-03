extends SceneTree
## Explicit isolated file only; this suite never discovers or reads player saves.
const Main = preload("res://scripts/main.gd")
const Campaign = preload("res://scripts/area_campaign.gd")
const Snapshot = preload("res://scripts/run_snapshot.gd")
# Exact board/economy fingerprint packaged in Android preview 0.6.6, before
# gravity-solved aim and exact free-flight integration were introduced.
const STRAIGHT_AIM_FINGERPRINT = "b81b8faf969ae879a1f672854ef7f13c83c7f1ce9f66ad0491baadb12b8e064e"
class Fixture extends "res://scripts/main.gd":
	var fail_write = false
	func legacy_profile_path() -> String: return ""
	func write_profile_file(data: Dictionary) -> bool:
		return false if fail_write else super.write_profile_file(data)

var passed = 0
var failed = []
var test_path = ""
func check(ok, label):
	if ok: passed += 1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)
func equal(a,b): return JSON.stringify(a,"",true,true)==JSON.stringify(b,"",true,true)
func write_json(data):
	var file=FileAccess.open(test_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"",true,true)); file.close()
func read_json(): return JSON.parse_string(FileAccess.get_file_as_string(test_path))
func cleanup():
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path+suffix): DirAccess.remove_absolute(test_path+suffix)
func fixture(id="gelato"):
	var game=Fixture.new()
	game.testing=true; game.sound_on=false; game.SAVE_FILE=test_path
	game.set_active_area(id)
	Campaign.apply_local(game,Campaign.default_record())
	game.area_records={"bakery":Campaign.default_record()}
	if id=="gelato": game.area_records.gelato=Campaign.default_record()
	game.mode="home"; game.shift_claimed=true
	return game
func stage_legacy_counts(game):
	game.gelato_shop_revision=0
	game.gelato_owned_nodes=[]; game.gelato_reset_power_nodes=[]
	check(game.ensure_gelato_shop_state(),"Legacy launcher fixture migrates its concrete upgrade identities")
func configured():
	var game=fixture()
	game.bank=15432.25; game.levels=[7,0,4,3,2,2,5,6]
	game.current_level=7; game.highest_unlocked=12; game.best_wave=12
	game.twin_launchers=true; game.power_reset_tier=8
	game.module_vouchers=1; game.module_milestones=[2,5,8]
	game.equipped=["ricochet","impact"]; game.trial_records={"4":8.25,"8":11.5}
	game.area_records.bakery.bank=99.75
	game.area_records.bakery.trial_records={"4":7.5}
	game.total_shifts=44; game.run_serial=80; game.last_claimed_run_id="bakery:80:900"
	game.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
	game.monetization.store_owned=game.monetization.entitlements.duplicate()
	stage_legacy_counts(game)
	return game
func envelope(records):
	return {"version":3,"active_area_id":"gelato","areas":records,"area_entries":[]}
func _initialize():
	test_path=OS.get_environment("SUGARFALL_GELATO_SAVE_QA_SAVE")
	if test_path.is_empty() or not test_path.is_absolute_path() or "--gelato-save-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Gelato save QA requires an explicit absolute isolated save path and --gelato-save-qa-isolated"); quit(2); return
	cleanup()
	area_record_validation()
	legacy_records()
	purchase_transaction()
	save_roundtrip()
	snapshot_roundtrip()
	legacy_snapshots()
	trajectory_checkpoint_migration()
	trial_isolation()
	pending_reward_migration()
	content_hashes()
	cleanup()
	print("GELATO_LAUNCHER_SAVE_QA_RESULT passed=",passed," failed=",failed.size())
	quit(0 if failed.is_empty() else 1)
func area_record_validation():
	var record=Campaign.default_record()
	check(Campaign.valid_record(record) and not record.twin_launchers and record.power_reset_tier==0,"Fresh area has one launcher and no lost Power")
	for value in [null,0,1,"true",[],{}]:
		var bad=record.duplicate(true); bad.twin_launchers=value
		check(not Campaign.valid_record(bad),"Reject nonboolean launcher ownership "+str(value))
	for value in [null,-1,11,1.5,true,"4",[],{}]:
		var bad=record.duplicate(true); bad.twin_launchers=true; bad.power_reset_tier=value
		check(not Campaign.valid_record(bad),"Reject invalid prior Power tier "+str(value))
	for tier in range(11):
		var valid=record.duplicate(true); valid.twin_launchers=true; valid.power_reset_tier=tier
		check(Campaign.valid_record(valid),"Twin ownership retains prior Power tier "+str(tier))
	var bad=record.duplicate(true); bad.power_reset_tier=1
	check(not Campaign.valid_record(bad),"Single launcher cannot claim a Power reset")
	bad=record.duplicate(true); bad.twin_launchers=true
	check(not Campaign.decode_profile({"active_area_id":"bakery","areas":{"bakery":bad},"area_entries":[]}).ok,"Bakery cannot acquire Gelato launcher ownership")
func legacy_records():
	var bakery=Campaign.default_record(); bakery.bank=777.25; bakery.trial_records={"4":9.5}
	var gelato=Campaign.default_record(); gelato.bank=4321.75; gelato.levels=[3,5,2,1,1,1,2,3]; gelato.trial_records={"4":8.5,"12":18.0}
	for record in [bakery,gelato]:
		record.erase("twin_launchers"); record.erase("power_reset_tier"); record.erase("launcher_rules_revision")
		for field in Campaign.SHOP_FIELDS: record.erase(field)
	var original=envelope({"bakery":bakery,"gelato":gelato})
	var before=original.duplicate(true)
	var decoded=Campaign.decode_profile(original)
	check(decoded.ok and equal(original,before),"Legacy area decode does not mutate the source profile")
	check(not decoded.records.gelato.twin_launchers and decoded.records.gelato.power_reset_tier==0,"Legacy Gelato defaults to one launcher and no reset")
	check(decoded.records.gelato.trial_records.is_empty() and decoded.records.bakery.trial_records==bakery.trial_records,"Only previous Gelato Trial times are cleared")
	check(decoded.records.gelato.bank==gelato.bank and decoded.records.gelato.levels==gelato.levels and decoded.records.bakery.bank==bakery.bank,"Rules migration preserves both wallets and existing upgrade counts")
	for revision in [0,1,3,-1,null,"2",true]:
		var changed=original.duplicate(true); changed.areas.gelato.launcher_rules_revision=revision
		var result=Campaign.decode_profile(changed)
		check(result.ok and result.records.gelato.trial_records.is_empty() and result.records.gelato.launcher_rules_revision==Campaign.LAUNCHER_RULES_REVISION,"Old or invalid Gelato Trial revision resets times: "+str(revision))
	gelato.launcher_rules_revision=2
	decoded=Campaign.decode_profile(envelope({"bakery":bakery,"gelato":gelato}))
	check(Campaign.LAUNCHER_RULES_REVISION==2 and decoded.ok and decoded.records.gelato.trial_records==gelato.trial_records,"Current gravity-solved Gelato Trial revision two preserves practice times")
	for version in [1,2]:
		var game=fixture("bakery")
		var legacy=game.campaign_profile()
		legacy.merge({"version":version,"balance_revision":4,"bank":58.25,"trial_records":{"4":7.25}},true)
		legacy.erase("twin_launchers"); legacy.erase("power_reset_tier")
		write_json(legacy)
		game.twin_launchers=true; game.power_reset_tier=7
		game.load_game()
		check(not game.profile_load_blocked and game.area_id=="bakery" and not game.twin_launchers and game.power_reset_tier==0 and game.bank==58.25 and game.trial_records.is_empty(),"Legacy v%d load resets stale launcher state and Trial times without losing Bakery progress"%version)
		game.free()
func purchase_transaction():
	var game=configured(); game.twin_launchers=false; game.power_reset_tier=0; game.levels[1]=8
	stage_legacy_counts(game)
	game.testing=false; game.mode="shop"
	var before=Campaign.capture_local(game)
	check(game.save_game(),"Pre-purchase campaign is durable")
	var bytes=FileAccess.get_file_as_bytes(test_path)
	game.fail_write=true
	check(not game.buy_twin_launchers() and equal(Campaign.capture_local(game),before) and FileAccess.get_file_as_bytes(test_path)==bytes,"Failed twin purchase rolls back currency, Power and ownership atomically")
	game.fail_write=false
	var cost=game.gelato_launcher.cost()
	check(game.buy_twin_launchers() and game.twin_launchers and game.levels[1]==0 and game.power_reset_tier==8 and game.bank==game.round_credits(before.bank-cost),"Twin purchase charges once, resets Power and remembers the red nodes")
	for index in [0,2,3,4,5,6,7]:
		check(game.levels[index]==before.levels[index],"Twin purchase preserves non-Power upgrade family "+str(index))
	var bought=Campaign.capture_local(game)
	check(not game.buy_twin_launchers() and equal(Campaign.capture_local(game),bought),"Repeated twin purchase cannot charge or reset again")
	var loaded=fixture("bakery"); loaded.load_game()
	check(equal(Campaign.capture_local(loaded),bought) and loaded.area_id=="gelato","Purchase survives immediate process-style reload")
	loaded.mode="shop"; loaded.testing=false
	check(loaded.upgrade_unlocked(1) and loaded.buy_upgrade(1) and loaded.levels[1]==1 and loaded.power_reset_tier==8,"Previously purchased route permits Power one rebuy without forgetting old nodes")
	var rebuilt=Campaign.capture_local(loaded)
	var reloaded=fixture("bakery"); reloaded.load_game()
	check(equal(Campaign.capture_local(reloaded),rebuilt),"Power rebuy and original reset tier both survive reload")
	reloaded.free(); loaded.free(); game.free()
func save_roundtrip():
	var game=configured()
	var expected=Campaign.capture_local(game)
	check(game.save_game(),"Twin-launcher campaign writes an isolated current-version profile")
	var saved=read_json()
	check(saved.version==Main.PROFILE_VERSION and saved.areas.gelato.twin_launchers and saved.areas.gelato.power_reset_tier==8,"Current-version area record stores twin ownership, exact nodes and pre-reset Power count")
	var loaded=fixture("bakery"); loaded.load_game()
	check(not loaded.profile_load_blocked and loaded.area_id=="gelato" and equal(Campaign.capture_local(loaded),expected),"Reload preserves reset Power, all other upgrades and Gelato wallet")
	check(loaded.total_shifts==44 and loaded.monetization.entitlements.remove_ads and loaded.monetization.entitlements.baker_toolkit,"Reload preserves lifetime progress and permanent purchases")
	check(loaded.switch_area("bakery") and not loaded.twin_launchers and loaded.power_reset_tier==0 and loaded.bank==99.75,"Bakery revisit restores its own launcher state and wallet")
	check(loaded.switch_area("gelato") and equal(Campaign.capture_local(loaded),expected),"Gelato revisit restores twin ownership and the exact rebuilt workshop")
	var bytes=FileAccess.get_file_as_bytes(test_path)
	loaded.power_reset_tier=11
	check(not loaded.save_game() and bytes==FileAccess.get_file_as_bytes(test_path),"Invalid launcher data cannot overwrite the last valid file")
	loaded.power_reset_tier=8; loaded.fail_write=true
	check(not loaded.save_game() and bytes==FileAccess.get_file_as_bytes(test_path),"Failed durable write preserves the previous profile")
	loaded.free(); game.free()
func snapshot_roundtrip():
	for twins in [false,true]:
		var game=configured(); game.twin_launchers=twins; game.power_reset_tier=8 if twins else 0
		stage_legacy_counts(game)
		game.start_shift(); game.step(.05)
		var snapshot=JSON.parse_string(JSON.stringify(Snapshot.capture(game)))
		var checked=Snapshot.validate_and_decode(snapshot,game)
		check(snapshot.schema==4 and checked.ok and checked.state.twin_launchers==twins and checked.state.power_reset_tier==game.power_reset_tier,"Schema four roundtrip binds both launcher fields: "+str(twins))
		for value in [330.0,770.0,1000.0]:
			var valid=snapshot.duplicate(true); valid.aim_y=value
			check(Snapshot.validate_and_decode(valid,game).ok,"Gelato snapshot accepts downward aim y="+str(value))
		for value in [329.99,1000.01,null,true,"668"]:
			var bad=snapshot.duplicate(true); bad.aim_y=value
			check(not Snapshot.validate_and_decode(bad,game).ok,"Gelato snapshot rejects invalid aim y="+str(value))
		for key in ["twin_launchers","power_reset_tier"]:
			var bad=snapshot.duplicate(true); bad.erase(key)
			check(not Snapshot.validate_and_decode(bad,game).ok,"Schema four requires "+key)
		var bad=snapshot.duplicate(true); bad.unrecognized_launcher=true
		check(not Snapshot.validate_and_decode(bad,game).ok,"Unknown snapshot fields remain rejected")
		bad=snapshot.duplicate(true); bad.twin_launchers=not twins
		check(not Snapshot.validate_and_decode(bad,game).ok,"Checkpoint ownership must match the workshop")
		bad=snapshot.duplicate(true); bad.power_reset_tier=7
		check(not Snapshot.validate_and_decode(bad,game).ok,"Checkpoint prior Power tier must match the workshop")
		for value in [-1,11,1.5,true,"8"]:
			bad=snapshot.duplicate(true); bad.power_reset_tier=value
			check(not Snapshot.validate_and_decode(bad,game).ok,"Snapshot rejects invalid Power reset "+str(value))
		check(game.save_game(),"Checkpoint saves with launcher ownership "+str(twins))
		var restored=fixture("bakery"); restored.load_game()
		check(restored.mode=="paused" and restored.resumed_run and restored.twin_launchers==twins and restored.power_reset_tier==game.power_reset_tier and restored.levels==game.levels,"Interrupted run reload preserves launcher ownership and reset build "+str(twins))
		restored.free(); game.free()
	var game=configured(); game.levels[0]=0
	stage_legacy_counts(game)
	game.start_shift(); game.step(.26)
	var snapshot=Snapshot.capture(game)
	check(game.spawn_clock>1.0 and Snapshot.validate_and_decode(snapshot,game).ok,"Feed-zero twin checkpoint preserves its slower per-launcher cadence above one second")
	var bad=snapshot.duplicate(true); bad.spawn_clock=game.gelato_launcher.interval(0)+.01
	check(not Snapshot.validate_and_decode(bad,game).ok,"Twin spawn timer cannot exceed its configured maximum interval")
	game.free()
func legacy_snapshots():
	var game=fixture("bakery"); game.start_shift(); game.step(.05)
	var original=Snapshot.capture(game)
	for schema in [1,2,3]:
		for keep_fields in [false,true]:
			var legacy=original.duplicate(true); legacy.schema=schema
			if schema<3: legacy.erase("area_id")
			if schema==1:
				for key in Snapshot.DRAIN_FIELDS: legacy.erase(key)
			if not keep_fields:
				legacy.erase("twin_launchers"); legacy.erase("power_reset_tier")
			var result=Snapshot.validate_and_decode(legacy,game)
			check(result.ok and not result.state.twin_launchers and result.state.power_reset_tier==0,"Legacy Bakery schema%d migrates false/zero (current-fixture fields=%s)"%[schema,keep_fields])
			var bad=legacy.duplicate(true); bad.twin_launchers=true
			check(not Snapshot.validate_and_decode(bad,game).ok,"Legacy schema%d cannot assert new launcher ownership"%schema)
			bad=legacy.duplicate(true); bad.power_reset_tier=1
			check(not Snapshot.validate_and_decode(bad,game).ok,"Legacy schema%d cannot assert a Power reset"%schema)
	for value in [330.0,770.0]:
		var valid=original.duplicate(true); valid.aim_y=value
		check(Snapshot.validate_and_decode(valid,game).ok,"Bakery keeps existing aim boundary "+str(value))
	var bad=original.duplicate(true); bad.aim_y=771
	check(not Snapshot.validate_and_decode(bad,game).ok,"Gelato extended aim does not loosen Bakery bounds")
	bad=original.duplicate(true); bad.twin_launchers=true; game.twin_launchers=true
	check(not Snapshot.validate_and_decode(bad,game).ok,"Bakery snapshot cannot resume twin launchers")
	game.free()
func trajectory_checkpoint_migration():
	for practice in [false,true]:
		var game=configured()
		var campaign=Campaign.capture_local(game)
		if practice: game.begin_trial(4)
		game.start_shift(); game.step(.05)
		check(game.save_game(),"Pre-migration Gelato checkpoint saves its campaign: Trial="+str(practice))
		var data=read_json()
		data.active_run.fingerprint=STRAIGHT_AIM_FINGERPRINT
		data.areas.gelato.launcher_rules_revision=1
		write_json(data)
		var before=FileAccess.get_file_as_bytes(test_path)
		var loaded=fixture("bakery"); loaded.load_game()
		campaign.trial_records={}
		check(not loaded.profile_load_blocked and loaded.mode=="home" and not loaded.resumed_run and not loaded.trial_active and not loaded.snapshot_rejection.is_empty(),"Old straight-aim checkpoint returns safely to Home: Trial="+str(practice))
		check(equal(Campaign.capture_local(loaded),campaign),"Trajectory migration preserves wallet, all upgrades, twins and progress while clearing old practice times: Trial="+str(practice))
		check(loaded.area_records.bakery.bank==99.75 and loaded.area_records.bakery.trial_records.get("4")==7.5 and loaded.monetization.entitlements.baker_toolkit,"Trajectory migration keeps Bakery and permanent test benefits: Trial="+str(practice))
		check(FileAccess.get_file_as_bytes(test_path)==before,"Rejected old checkpoint leaves its original save bytes intact: Trial="+str(practice))
		loaded.start_shift(); loaded.step(.05)
		check(Snapshot.validate_and_decode(Snapshot.capture(loaded),loaded).ok,"Retained campaign can immediately start a valid gravity-solved run: Trial="+str(practice))
		loaded.free(); game.free()
func trial_isolation():
	var game=configured(); var campaign=Campaign.capture_local(game)
	check(game.begin_trial(4) and not game.twin_launchers and game.power_reset_tier==0 and game.levels==Snapshot.TRIAL_LEVELS,"Fixed Trial disables twin launchers and reset metadata")
	check(equal(Campaign.capture_local(game),campaign),"Saving during practice captures the underlying twin-launcher campaign")
	game.start_shift(); game.step(.05)
	var snapshot=Snapshot.capture(game)
	check(Snapshot.validate_and_decode(snapshot,game).ok,"Fixed single-launcher Trial checkpoint validates")
	var bad=snapshot.duplicate(true); bad.twin_launchers=true; bad.power_reset_tier=8
	check(not Snapshot.validate_and_decode(bad,game).ok,"Fixed Trial rejects campaign twin-launcher state")
	check(game.save_game(),"Interrupted Trial saves both fixed run and campaign ownership")
	var restored=fixture("bakery"); restored.load_game()
	check(restored.mode=="paused" and restored.trial_active and not restored.twin_launchers and restored.power_reset_tier==0,"Interrupted Trial resumes its fixed single-launcher configuration")
	restored.end_trial()
	check(equal(Campaign.capture_local(restored),campaign),"Ending resumed Trial restores the entire twin-launcher workshop")
	game.end_trial()
	check(equal(Campaign.capture_local(game),campaign),"Ending live Trial restores the entire twin-launcher workshop")
	restored.free(); game.free()
func pending_reward_migration():
	var game=configured(); game.start_shift(); game.shift_coins=25.15; game.level_won=false; game.finish_shift(false)
	check(game.save_game(),"Pending Gelato reward writes before rules migration")
	var data=read_json(); data.areas.gelato.launcher_rules_revision=1; write_json(data)
	var loaded=fixture("bakery"); loaded.load_game()
	check(loaded.mode=="result" and loaded.twin_launchers and loaded.power_reset_tier==8 and loaded.trial_records.is_empty(),"Old Gelato Trial times clear while a completed reward and twin build survive")
	var balance=loaded.bank; loaded.collect_reward(); var once=loaded.bank; loaded.collect_reward()
	check(is_equal_approx(once,balance+30.18) and loaded.bank==once,"Pending reward and Toolkit cents collect once after rules migration")
	check(loaded.area_records.bakery.trial_records.get("4")==7.5,"Gelato reward migration preserves Bakery practice times")
	loaded.free(); game.free()
	game=configured(); var campaign=Campaign.capture_local(game)
	game.begin_trial(4); game.start_shift(); game.run_elapsed=7.5; game.level_won=true; game.finish_shift(false)
	check(game.save_game(),"Completed Trial persists its fixed loadout and underlying twin campaign")
	data=read_json(); data.areas.gelato.launcher_rules_revision=1; write_json(data)
	loaded=fixture("bakery"); loaded.load_game()
	check(loaded.mode=="result" and loaded.trial_active and not loaded.twin_launchers and loaded.power_reset_tier==0 and loaded.trial_records.is_empty(),"Old completed Trial shows a fixed result without reintroducing its obsolete best time")
	loaded.collect_reward(); campaign.trial_records={}
	check(not loaded.trial_active and equal(Campaign.capture_local(loaded),campaign),"Leaving migrated Trial result restores twins and wallet with old times cleared")
	loaded.free(); game.free()
func hash_paths(paths):
	var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for path in paths: context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
func content_hashes():
	check(Snapshot.content_fingerprint("bakery")==hash_paths(["res://data/board_design.json","res://data/economy.json"]),"Bakery fingerprint keeps the exact original two-file algorithm")
	check(Snapshot.content_fingerprint("gelato")==hash_paths(["res://data/gelato_board_design.json","res://data/economy.json","res://data/gelato_economy.json"]),"Gelato fingerprint includes its economy bytes in fixed order")
	check(Snapshot.content_fingerprint("gelato")!=hash_paths(["res://data/gelato_board_design.json","res://data/economy.json"]),"Old Gelato physics checkpoints cannot inherit the new economy fingerprint")
	check(Snapshot.content_fingerprint("gelato")!=STRAIGHT_AIM_FINGERPRINT,"Gravity-solved aim invalidates the exact prior Android straight-aim checkpoint fingerprint")
	var economy=JSON.parse_string(FileAccess.get_file_as_string("res://data/gelato_economy.json"))
	check(economy.trajectory_revision==2,"Packaged Gelato economy records trajectory revision two without changing Bakery data")
