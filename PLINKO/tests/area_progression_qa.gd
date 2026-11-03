extends SceneTree
## Uses only a caller-supplied workspace test path. Never loads a player profile.
const Main=preload("res://scripts/main.gd")
class Fixture extends "res://scripts/main.gd":
	var content_available=true
	var fail_write=false
	var memory_writes=true
	var saved={}
	var writes=0
	var legacy_path=""
	func area_content_ready(id: String) -> bool:
		return content_available and not area_boards(id).is_empty()
	func write_profile_file(data: Dictionary) -> bool:
		writes+=1
		if fail_write: return false
		if memory_writes: saved=data.duplicate(true); return true
		return super.write_profile_file(data)
	func legacy_profile_path() -> String:
		return legacy_path

var passed=0
var failed=[]
var test_path=""
func check(ok, label):
	if ok: passed+=1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)
func equal(a,b):
	return JSON.stringify(a,"",true,true)==JSON.stringify(b,"",true,true)
func fixture():
	var g=Fixture.new()
	g.testing=true
	g.sound_on=false
	g.set_active_area("bakery")
	g.bank=45000.35
	g.levels=[3,4,2,2,1,1,2,4]
	g.current_level=12; g.highest_unlocked=12; g.best_wave=12; g.chapter_complete=true
	g.equipped=["splitter","impact"]
	g.module_vouchers=2; g.module_milestones=[2,5,8]; g.trial_records={"4":5.75,"12":9.25}
	g.total_shifts=38; g.run_serial=101; g.last_claimed_run_id="bakery:101:123"
	g.monetization.attempts=3; g.monetization.active_seconds=103.5; g.monetization.serial=12
	g.monetization.last_counted_run="bakery:101:123"
	g.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
	g.monetization.store_owned=g.monetization.entitlements.duplicate()
	g.reduced_motion=true
	g.shift_claimed=true
	g.SAVE_FILE=test_path
	return g
func local(g): return g.AreaCampaign.capture_local(g)
func globals(g):
	return {"monetization":g.monetization.export_state(),"serial":g.run_serial,"claimed":g.last_claimed_run_id,"shifts":g.total_shifts,"sound":g.sound_on,"reduced":g.reduced_motion}
func write_json(path,data):
	var f=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"",true,true)); f.close()
func read_json(path): return JSON.parse_string(FileAccess.get_file_as_string(path))
func cleanup(path):
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
func _initialize():
	test_path=OS.get_environment("SUGARFALL_AREA_QA_SAVE")
	if test_path.is_empty() or not test_path.is_absolute_path() or "--area-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Area QA needs an explicit absolute isolated save path and --area-qa-isolated"); quit(2); return
	cleanup(test_path); cleanup(test_path+".legacy"); cleanup(test_path+".fresh")
	entry_and_revisits()
	permanent_product_matrix()
	guards_and_failure()
	wallet_ceiling()
	persistence_and_legacy()
	combat_record_migration()
	run_identity()
	cleanup(test_path); cleanup(test_path+".legacy"); cleanup(test_path+".fresh")
	print("AREA_PROGRESSION_QA_RESULT passed=",passed," failed=",failed.size())
	quit(0 if failed.is_empty() else 1)
func entry_and_revisits():
	var g=fixture()
	var old=local(g); var permanent=globals(g)
	check(g.area_entry_status().can_enter,"Completed funded Bakery can enter released Gelato")
	check(g.enter_area(),"First entry commits successfully")
	check(g.area_id=="gelato" and equal(local(g),g.AreaCampaign.default_record()) and g.mode=="home","New area opens idle Home with zero wallet/upgrades/vouchers and tray one")
	old.bank=44000.35
	check(equal(g.area_records.bakery,old),"1000 fee preserves every Bakery-local field and fractional leftover")
	check(equal(globals(g),permanent) and g.monetization.pending.is_empty(),"Entry retains both purchases, provider ownership/cadence, preferences and run identities without an ad")
	check(g.saved.version==Main.PROFILE_VERSION and g.saved.active_area_id=="gelato" and g.saved.area_entries.size()==1 and g.saved.area_entries[0].cost==1000,"Single atomic current-version candidate includes debit, destination ownership and entry ledger")
	var committed=g.saved.duplicate(true)
	check(not g.enter_area() and equal(g.saved,committed) and g.writes==1,"Repeated Enter cannot charge or initialize twice")
	g.bank=333.15; g.levels=[1,2,0,1,0,0,0,0]; g.current_level=3; g.highest_unlocked=4; g.module_vouchers=1; g.module_milestones=[2]; g.equipped=["ricochet"]; g.trial_records={"4":8.5}
	g.gelato_shop_revision=0
	check(g.ensure_gelato_shop_state(),"Count-prefix Gelato revisit fixture migrates to exact node ownership")
	var gelato=local(g)
	check(g.switch_area("bakery") and equal(local(g),old),"Revisit restores Bakery wallet, tiers, equipment, vouchers and trials")
	g.start_shift(); g.shift_coins=100; g.level_won=false; g.finish_shift(false); g.collect_reward()
	check(is_equal_approx(g.bank,44120.35) and g.area_records.gelato.bank==333.15,"Bakery replay plus20percent Toolkit earnings stay in Bakery")
	g.mode="home"
	check(g.switch_area("gelato") and equal(local(g),gelato) and g.area_entries.size()==1,"Returning to Gelato restores its exact build with no new fee or reset")
	g.shift_coins=100
	check(g.result_payout()==120,"Toolkit gives the same20percent in Gelato")
	g.monetization.attempts=4; g.monetization.active_seconds=120
	check(not g.monetization.eligible(),"Remove Ads remains effective in Gelato")
	g.free()
func guards_and_failure():
	for amount in [999.0,999.99,1000.0,1500.0]:
		var g=fixture(); g.bank=amount
		check(g.area_entry_status().can_enter==(amount>=1000),"Exact entry boundary at "+str(amount))
		if amount>=1000:
			g.enter_area(); check(g.area_records.bakery.bank==amount-1000,"Entry subtracts displayed fee exactly at "+str(amount))
		g.free()
	var g=fixture(); var original=local(g); var permanent=globals(g)
	g.mode="boards"; g.level_map.open_entry(); g.level_map.close_overlay()
	check(equal(local(g),original) and g.writes==0 and g.area_id=="bakery","Cancel confirmation changes no profile state")
	g.fail_write=true
	check(not g.enter_area() and equal(local(g),original) and equal(globals(g),permanent) and not g.area_owned("gelato") and not g.area_transaction_pending,"Failed durable write leaves area, wallet, unlocks and permanent state untouched")
	g.fail_write=false; g.chapter_complete=false
	check(not g.enter_area(),"Uncleared Bakery cannot enter")
	g.chapter_complete=true; g.content_available=false
	check(not g.enter_area(),"Incomplete content cannot enter")
	g.content_available=true
	for screen in ["play","paused","result","test_ad","test_purchase","shop","abandon_confirm"]:
		g.mode=screen; check(not g.enter_area(),"Entry rejects non-idle screen "+screen)
	g.mode="home"; g.trial_active=true
	check(not g.enter_area(),"Entry rejects practice")
	g.trial_active=false; g.monetization.pending={"id":"pending"}
	check(not g.enter_area(),"Entry rejects an unresolved provider request")
	g.monetization.pending={}; g.run_id="unclaimed"; g.shift_claimed=false
	check(not g.enter_area(),"Entry rejects unclaimed run even behind an idle screen")
	g.free()
func permanent_product_matrix():
	for ads in [false,true]:
		for toolkit in [false,true]:
			var g=fixture()
			var ownership={"remove_ads":ads,"baker_toolkit":toolkit}
			g.monetization.entitlements=ownership.duplicate(); g.monetization.store_owned=ownership.duplicate()
			var permanent=globals(g)
			var entered=g.enter_area()
			check(entered and equal(globals(g),permanent),"Independent product ownership survives entry: ads=%s toolkit=%s"%[ads,toolkit])
			g.monetization.entitlements={"remove_ads":false,"baker_toolkit":false}; g.monetization.restore_purchases()
			g.shift_coins=100; g.monetization.attempts=4; g.monetization.active_seconds=120
			check(equal(g.monetization.entitlements,ownership) and g.result_payout()==(120 if toolkit else 100) and g.monetization.eligible()==(not ads),"Restore and product effects remain correct in Gelato: ads=%s toolkit=%s"%[ads,toolkit])
			g.free()
func persistence_and_legacy():
	var g=fixture(); g.memory_writes=false
	check(g.enter_area(),"Durable first entry writes real isolated v4 file")
	var saved=read_json(test_path)
	var x=fixture(); x.memory_writes=false; x.load_game()
	check(x.area_id=="gelato" and x.bank==0 and x.area_records.bakery.bank==44000.35 and x.monetization.entitlements.remove_ads and x.monetization.entitlements.baker_toolkit,"Restart after atomic entry restores both wallets and permanent products")
	check(not x.enter_area() and x.switch_area("bakery") and x.bank==44000.35,"Restart cannot charge a committed entry twice")
	var fresh=fixture(); fresh.SAVE_FILE=test_path+".fresh"; fresh.memory_writes=false; fresh.bank=7; fresh.chapter_complete=false; fresh.monetization.reset_test_state(); fresh.save_game()
	var fresh_restart=fixture(); fresh_restart.SAVE_FILE=test_path+".fresh"; fresh_restart.load_game()
	check(fresh_restart.area_id=="bakery" and fresh_restart.bank==7 and not fresh_restart.area_owned("gelato") and not fresh_restart.monetization.entitlements.remove_ads,"Independent fixture save isolates ownership, purchases and wallet")
	fresh.free(); fresh_restart.free(); x.free(); g.free()
	for version in [1,2]:
		cleanup(test_path)
		g=fixture(); var profile=g.campaign_profile(); profile.merge({"version":version,"balance_revision":4,"trial_records":g.trial_records,"run_serial":g.run_serial,"last_claimed_run_id":g.last_claimed_run_id,"sound":g.sound_on,"reduced_motion":true,"monetization_test":g.monetization.export_state()},true)
		write_json(test_path+".legacy",profile)
		var before=FileAccess.get_file_as_bytes(test_path+".legacy")
		g.memory_writes=false; g.legacy_path=test_path+".legacy"; g.load_game()
		check(g.area_id=="bakery" and g.bank==45000.35 and g.trial_records.is_empty() and g.monetization.entitlements.baker_toolkit,"Legacy v%d migration preserves Bakery progress while obsolete Trial times reset"%version)
		check(read_json(test_path).version==Main.PROFILE_VERSION and FileAccess.get_file_as_bytes(test_path+".legacy")==before,"Legacy v%d source retained byte-for-byte while current canonical save becomes authoritative"%version)
		profile.bank=900000; write_json(test_path+".legacy",profile); g.load_game()
		check(g.bank==45000.35,"Existing v4 never reimports a changed legacy wallet")
		write_json(test_path,{"version":3,"areas":{}}); g.load_game()
		check(g.profile_load_blocked and not g.save_game() and read_json(test_path).areas.is_empty(),"Malformed authoritative v3 is protected from overwrite or fallback")
		g.free()
	# Exact new profile decoder keeps owned local records closed to malformed values.
	check(Main.AreaCampaign.decode_profile(saved).ok,"Committed v4 passes strict area-record validation")
func wallet_ceiling():
	var g=fixture(); g.bank=99999999.99; g.start_shift(); g.shift_coins=100; g.finish_shift(false); g.collect_reward()
	check(g.bank==100000000 and g.save_game() and g.AreaCampaign.decode_profile(g.saved).ok,"Runtime payout ceiling produces a self-valid v4 profile")
	g.bank=100000000.01
	var count=g.writes
	check(not g.save_game() and not g.enter_area() and g.writes==count,"Out-of-bound local state cannot overwrite a valid profile or fund area entry")
	g.free()

func combat_record_migration():
	var campaign=Main.AreaCampaign
	for id in campaign.IDS:
		var record=campaign.default_record()
		record.bank=4321.75; record.levels=[3,6,2,1,1,1,2,3]
		record.current_level=8; record.highest_unlocked=8; record.equipped=["impact"]
		record.trial_records={"4":8.25,"8":11.5}
		if id=="gelato":
			record.twin_launchers=true; record.power_reset_tier=6
			record.merge(campaign.legacy_gelato_shop_state(record.levels,true,6),true)
		check(equal(campaign.normalized(record,id),record),"Current combat revision preserves new Trial records in "+id)
		for revision in [null,0,-1,2,"1",true]:
			var legacy=record.duplicate(true)
			if revision==null: legacy.erase("combat_rules_revision")
			else: legacy.combat_rules_revision=revision
			var original=legacy.duplicate(true)
			var expected=record.duplicate(true); expected.trial_records={}
			var migrated=campaign.normalized(legacy,id)
			check(equal(migrated,expected) and equal(legacy,original),"Combat migration clears only obsolete times and preserves source: %s / %s"%[id,str(revision)])
func run_identity():
	var g=fixture(); g.enter_area(); g.start_shift()
	for i in range(90): g.step(1.0/60)
	var checkpoint=g.RunSnapshot.capture(g)
	check(checkpoint.schema==g.RunSnapshot.LEGACY_AREA_SCHEMA and checkpoint.area_id=="gelato" and checkpoint.run_id.begins_with("gelato:") and checkpoint.fingerprint!=g.RunSnapshot.content_fingerprint("bakery"),"Gelato checkpoint has area-specific run identity and board fingerprint")
	var x=fixture(); x.set_active_area("gelato"); x.area_records["gelato"]=x.AreaCampaign.default_record(); x.AreaCampaign.apply_local(x,x.area_records.gelato)
	check(x.restore_active_run(checkpoint) and x.mode=="paused" and x.run_area_id=="gelato","Gelato active physics checkpoint restores into its own area")
	x.set_active_area("bakery")
	check(not x.restore_active_run(checkpoint),"Gelato checkpoint cannot resume on Bakery geometry")
	x.free(); g.free()
	for schema in [1,2]:
		g=fixture(); g.start_shift(); g.step(.05)
		checkpoint=g.RunSnapshot.capture(g); checkpoint.schema=schema; checkpoint.erase("area_id")
		if schema==1:
			for key in g.RunSnapshot.DRAIN_FIELDS: checkpoint.erase(key)
		x=fixture()
		check(x.restore_active_run(checkpoint) and x.run_area_id=="bakery" and x.run_id==g.run_id,"Legacy schema%d structure with current content migrates to Bakery without losing run identity"%schema)
		var previous_local=local(x); var previous_globals=globals(x)
		checkpoint.fingerprint=g.RunSnapshot.PRICE_ONLY_PREVIOUS_FINGERPRINT
		check(not x.restore_active_run(checkpoint) and x.mode=="home" and equal(local(x),previous_local) and equal(globals(x),previous_globals),"Old price-only fingerprint cannot bypass the new board/Power rebalance; schema%d campaign and purchases stay intact"%schema)
		x.free(); g.free()
	for id in ["bakery","gelato"]:
		g=fixture()
		if id=="gelato": g.enter_area()
		g.start_shift(); g.shift_coins=25.15; g.level_won=false; g.finish_shift(false)
		g.memory_writes=false; g.save_game()
		x=fixture(); x.load_game()
		var previous=x.bank
		check(x.mode=="result" and x.run_area_id==id and x.area_id==id,"Pending result restores into originating "+id+" wallet")
		x.collect_reward(); var once=x.bank; x.collect_reward()
		check(is_equal_approx(once,previous+30.18) and x.bank==once,"Reward and Toolkit cents collect exactly once in "+id)
		x.free()
		var wrong=read_json(test_path); wrong.pending_result.area_id="bakery" if id=="gelato" else "gelato"; write_json(test_path,wrong)
		x=fixture(); x.load_game()
		check(x.mode=="home" and x.snapshot_rejection.contains("another area"),"Cross-area pending reward is rejected for "+id)
		x.free(); g.free()
