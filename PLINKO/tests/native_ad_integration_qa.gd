extends SceneTree
const Service = preload("res://scripts/native_ad_service.gd")
const Main = preload("res://scripts/main.gd")
var passed=0
var failed: Array[String]=[]
class FakeProvider extends Node:
	signal availability_changed
	signal reward_earned(id: String, reward: Dictionary)
	signal request_finished(id: String, outcome: Dictionary)
	var inventory={"rewarded":true,"interstitial":true}
	var shown: Array=[]
	var accepted=true
	var initialized=false
	var suspended=false
	var error={}
	func initialize(_config): initialized=true;return true
	func is_ready(kind): return inventory.get(kind,false) and not suspended
	func status(): return {"native_available":true,"consent_ready":true,"privacy_options_required":true,"errors":error}
	func show(kind,id,context):
		shown.append({"kind":kind,"id":id,"context":context})
		if accepted: inventory[kind]=false
		return accepted
	func set_suspended(value): suspended=value
	func show_privacy_options(): return true
	func finish(id,kind,status="cancelled",granted=false):
		request_finished.emit(id,{"kind":kind,"status":status,"outcome":status,"granted":granted})

class SaveGame extends "res://scripts/main.gd":
	var disk: Dictionary={}
	var fail_write=false
	func write_profile_file(data: Dictionary) -> bool:
		if fail_write: return false
		disk=JSON.parse_string(JSON.stringify(data))
		return true

func check(ok: bool,label: String):
	if ok: passed+=1;print("PASS: ",label)
	else: failed.append(label);print("FAIL: ",label)

func fixture(automatic_ads_allowed: Callable = Callable()):
	var state={"disk":{},"writes":0,"fail":false,"context":true,"outcomes":[],"commits":[]}
	var provider=FakeProvider.new()
	var service=Service.new(provider,Callable(),Callable(),automatic_ads_allowed)
	service.persist=func():
		state.writes+=1
		if state.fail: return false
		state.disk=JSON.parse_string(JSON.stringify(service.export_state()))
		return true
	service.context_valid=func(_binding): return state.context
	service.reward_committed.connect(func(area,id): state.commits.append([area,id]))
	service.request_finished.connect(func(id,outcome): state.outcomes.append({"id":id,"outcome":outcome}))
	service.initialize({})
	return {"s":service,"p":provider,"state":state}

func cadence_and_acceptance():
	var f=fixture()
	f.s.advance_campaign_play(10000)
	for id in ["r1","r1","r2","r3"]: f.s.complete_attempt(id)
	check(f.s.attempts==3 and f.s.active_seconds==120 and not f.s.automatic_eligible(),"Cadence counts each result once and requires four attempts plus active play")
	f.s.complete_attempt("r4")
	check(f.s.automatic_eligible(),"Fourth distinct result with 120 active seconds is eligible")
	f.s.set_suspended(true);f.s.active_seconds=20;f.s.advance_campaign_play(50)
	check(f.s.active_seconds==20 and not f.s.is_ready("rewarded"),"Background time cannot advance cadence or start an ad")
	f.s.set_suspended(false);f.s.active_seconds=120
	f.p.inventory.interstitial=false
	check(not f.s.request("interstitial","bakery","r4","fixture") and f.s.attempts==4 and f.s.active_seconds==120,"Unavailable inventory leaves production cadence intact")
	f.p.inventory.interstitial=true;f.state.fail=true
	check(not f.s.request("interstitial","bakery","r4","fixture") and f.p.shown.is_empty() and f.s.attempts==4,"Failed pre-ad save cannot start playback or consume cadence")
	f.state.fail=false;f.p.accepted=false
	check(not f.s.request("interstitial","bakery","r4","fixture") and not f.s.has_pending() and f.s.attempts==4,"Ready-but-rejected provider request restores cadence without a fake completion")
	f.p.accepted=true
	check(f.s.request("interstitial","bakery","r4","fixture") and f.s.attempts==0 and f.s.active_seconds==0,"Accepted real ad request durably resets the shared cadence")
	var id=f.s.pending.id
	f.p.reward_earned.emit(id,{"amount":1})
	f.p.finish(id,"interstitial","completed",true)
	check(f.s.receipts.is_empty() and not f.state.outcomes[0].outcome.granted,"Interstitial completion can never grant a reward")
	f.s.free()

func automatic_ad_suppression():
	var policy={"allowed":false}
	var f=fixture(func(): return policy.allowed)
	f.s.attempts=4
	f.s.active_seconds=120.0
	var before=f.s.export_state()
	var disk_before=JSON.parse_string(JSON.stringify(before))
	check(not f.s.is_ready("interstitial") and not f.s.automatic_eligible(),"Suppressed automatic ads remain ineligible with loaded inventory and full cadence")
	check(not f.s.request("interstitial","bakery","run-paid","fixture") and f.state.writes==0 and f.p.shown.is_empty() and f.s.export_state()==before,"A direct interstitial request cannot bypass the policy or consume cadence")

	policy.allowed=true
	var persist: Callable=f.s.persist
	f.s.persist=func():
		policy.allowed=false
		return persist.call()
	check(not f.s.request("interstitial","gelato","run-restore","fixture") and not f.s.has_pending() and f.p.shown.is_empty(),"Purchase restoration during the pre-ad save prevents native playback")
	check(f.s.export_state()==before and f.state.disk==disk_before,"Suppression just before playback restores the pre-ad cadence in memory and storage")

	check(f.s.is_ready("rewarded") and f.s.request("rewarded","crystal","run-reward","fixture"),"Owners may still opt in to a rewarded ad")
	var id=f.s.pending.get("id","")
	f.p.reward_earned.emit(id,{"amount":1})
	f.p.finish(id,"rewarded","completed",true)
	check(f.s.has_reward("crystal","run-reward"),"Opt-in rewarded playback still grants its durable run bonus")

	policy.allowed=true
	f.s.persist=persist
	f.s.attempts=4
	f.s.active_seconds=120
	check(f.s.automatic_eligible() and f.s.request("interstitial","bakery","run-unowned","fixture"),"The next eligible result can play an interstitial when ownership is absent")
	f.s.free()

func durable_reward_and_restart():
	var f=fixture()
	check(f.s.request("rewarded","gelato","run-A","fixture"),"A loaded rewarded request binds to its exact run and area")
	var id=f.s.pending.id
	var before_reward=f.state.disk.duplicate(true)
	f.p.reward_earned.emit("other",{"amount":50})
	check(f.s.receipts.is_empty(),"A different request's reward cannot affect the current result")
	f.p.reward_earned.emit(id,{"amount":1});f.p.reward_earned.emit(id,{"amount":999})
	check(f.s.has_reward("gelato","run-A") and f.state.disk.receipts.size()==1 and f.state.commits.size()==1 and f.state.outcomes.is_empty(),"Native earned event is saved exactly once before dismissal")
	check(not f.s.has_reward("bakery","run-A") and not f.s.has_reward("gelato","run-B"),"Saved reward cannot cross an area or run boundary")
	var after_reward=f.state.disk.duplicate(true)
	f.p.finish(id,"rewarded","completed",true);f.p.finish(id,"rewarded","completed",true)
	check(f.state.outcomes.size()==1 and f.state.outcomes[0].outcome.granted,"Duplicate terminal callbacks cannot commit another reward")
	var restored=Service.new()
	check(restored.import_state(after_reward) and restored.has_reward("gelato","run-A") and not restored.has_pending(),"JSON round trip restores an earned receipt without reopening or replaying the ad")
	check(restored.import_state(before_reward) and not restored.has_reward("gelato","run-A"),"Restart during playback without an earned event grants nothing")
	var malformed=after_reward.duplicate(true);malformed.receipts[0].area_id="other"
	check(not restored.import_state(malformed) and not restored.has_reward("gelato","run-A"),"Malformed ledger is rejected atomically")
	restored.free();f.s.free()

func close_failure_context_and_save_retry():
	var f=fixture();f.s.request("rewarded","crystal","run-C","fixture")
	var id=f.s.pending.id
	f.p.finish(id,"rewarded","cancelled",false);f.p.reward_earned.emit(id,{"amount":1})
	check(not f.s.has_reward("crystal","run-C") and f.s.receipts.is_empty(),"Close and callbacks after cancellation add no bonus")
	f.s.free();f=fixture();f.s.request("rewarded","bakery","run-D","fixture");id=f.s.pending.id
	f.state.context=false;f.p.reward_earned.emit(id,{"amount":1});f.p.finish(id,"rewarded","completed",true)
	check(f.s.receipts.is_empty() and not f.state.outcomes[0].outcome.granted,"A changed profile, run or area rejects the old native callback")
	f.s.free();f=fixture();f.s.request("rewarded","bakery","run-E","fixture");id=f.s.pending.id
	f.p.finish(id,"rewarded","failed",true)
	check(not f.s.has_reward("bakery","run-E") and f.s.receipts.is_empty(),"A terminal granted flag without the native earned event cannot authorize payout")
	f.s.free();f=fixture();f.s.request("rewarded","bakery","run-F","fixture");id=f.s.pending.id
	f.state.fail=true;f.p.reward_earned.emit(id,{"amount":1})
	check(not f.s.has_reward("bakery","run-F") and f.s.has_unsaved_reward("bakery","run-F") and f.state.commits.is_empty(),"Failed reward save retains the native receipt but does not expose an undurable payout")
	f.p.finish(id,"rewarded","completed",true)
	f.p.inventory.rewarded=true
	check(not f.s.request("rewarded","bakery","run-F","fixture"),"An earned receipt awaiting storage cannot trigger a second ad")
	f.state.fail=false;f.s._process(1.1)
	check(f.s.has_reward("bakery","run-F") and f.state.disk.receipts.size()==1 and f.state.commits.size()==1,"Foreground save retry durably recovers the earned bonus exactly once")
	f.s.free()

func game_fixture():
	var g=SaveGame.new()
	g.testing=false;g.sound_on=false
	g.SAVE_FILE="user://native_ad_integration_never_written.json"
	g.set_active_area("bakery")
	g.first_run_guide.active=false
	g.run_id="bakery:fixture-run";g.run_area_id="bakery";g.shift_claimed=false
	g.shift_coins=100;g.bank=50;g.wave=1;g.mode="result"
	g.page_transition.enabled=false
	var provider=FakeProvider.new()
	g.native_ad_service=Service.new(provider,Callable(g,"_persist_native_ads"),Callable(g,"_native_ad_context_valid"))
	g.native_ad_service.reward_committed.connect(g._native_ad_reward_committed)
	g.native_ad_service.request_finished.connect(g._native_ad_finished)
	g.native_ad_service.initialize({})
	return {"g":g,"p":provider}

func game_integration():
	var f=game_fixture();var g=f.g
	check(g.native_ads_available() and not g.test_commerce_available() and g.reward_ad_label()=="Watch ad +50","Native-enabled gameplay shows the actual ad action and disables the local simulator")
	g.page_transition.enabled=true
	check(g.begin_native_ad("rewarded") and g.mode=="native_ad" and g.disk.has("pending_result") and g.disk.pending_result.run_id==g.run_id,"Native playback persists the exact pending result before opening")
	check(not g.page_transition.active,"Native fullscreen presentation keeps the result backdrop stable")
	var id=g.native_ad_service.pending.id
	g.go_back();g.handle_press(Vector2(100,840));g.start_shift()
	check(g.mode=="native_ad" and not g.shift_claimed and g.run_id=="bakery:fixture-run","Back, Collect and Play cannot mutate a run during native playback")
	f.p.reward_earned.emit(id,{"amount":1})
	check(g.result_payout()==150 and g.disk.native_ads.receipts.size()==1 and g.mode=="native_ad","Actual native reward authorizes one 50% run bonus and saves it before dismissal")
	f.p.finish(id,"rewarded","completed",true)
	check(g.mode=="result" and g.result_reward_earned() and g.reward_ad_label()=="Bonus added","Native dismissal returns to the existing result with its durable bonus")
	g.collect_reward()
	check(g.bank==200 and g.shift_claimed and g.mode=="home","Collect transfers base earnings and one native bonus to the wallet")
	f.p.reward_earned.emit(id,{"amount":1});g.collect_reward()
	check(g.bank==200,"Late reward and repeated Collect cannot pay the same result twice")
	g.native_ad_service.free();g.native_ad_service=null;g.free()
	f=game_fixture();g=f.g;f.p.inventory.rewarded=false
	check(not g.begin_native_ad("rewarded") and g.mode=="result" and not g.native_ad_message.is_empty() and g.result_payout()==100,"No-fill/loading leaves Collect available with inline error and no invented bonus")
	g.first_run_guide.active=true;f.p.inventory.rewarded=true
	check(not g.begin_native_ad("rewarded"),"Onboarding cannot open a fullscreen native ad")
	g.first_run_guide.active=false;g.trial_active=true
	check(not g.begin_native_ad("rewarded"),"Trials cannot request a campaign ad or bonus")
	g.native_ad_service.free();g.native_ad_service=null;g.free()
	f=game_fixture();g=f.g;g.begin_native_ad("rewarded");id=g.native_ad_service.pending.id
	g.fail_write=true;f.p.reward_earned.emit(id,{"amount":1});f.p.finish(id,"rewarded","completed",true)
	g.collect_reward()
	check(g.mode=="result" and not g.shift_claimed and g.bank==50,"Collect waits while a genuine native reward has not reached durable storage")
	g.fail_write=false;g.native_ad_service._process(1.1);g.collect_reward()
	check(g.bank==200 and g.shift_claimed,"Saving recovery allows one complete base-plus-bonus collection")
	g.native_ad_service.free();g.native_ad_service=null;g.free()

func disk_roundtrip():
	const SAVE="user://native_ad_run_ledger_qa.json"
	for path in [SAVE,SAVE+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var g=Main.new()
	g.sound_on=false;g.SAVE_FILE=SAVE;g.set_active_area("bakery")
	g.first_run_guide.import_state({"version":2,"completed":true,"active":false},true)
	g.run_id="bakery:disk-native";g.run_area_id="bakery";g.shift_claimed=false;g.mode="result"
	g.bank=50;g.shift_coins=100
	var provider=FakeProvider.new()
	g.native_ad_service=Service.new(provider,Callable(g,"_persist_native_ads"),Callable(g,"_native_ad_context_valid"))
	g.native_ad_service.reward_committed.connect(g._native_ad_reward_committed)
	g.native_ad_service.initialize({})
	check(g.begin_native_ad("rewarded"),"Disk fixture starts native ad after the pending result is durably saved")
	var id=g.native_ad_service.pending.id
	provider.reward_earned.emit(id,{"amount":1})
	var saved=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved.native_ads.receipts.size()==1 and saved.pending_result.run_id=="bakery:disk-native" and saved.pending_result.coins==100,"On-disk profile contains native reward receipt and original pending earnings before dismissal")
	g.native_ad_service.free();g.native_ad_service=null;g.free()
	# A fresh game/controller has no native in-flight request or memory of the ad.
	g=Main.new();g.sound_on=false;g.SAVE_FILE=SAVE
	provider=FakeProvider.new();g.native_ad_service=Service.new(provider,Callable(g,"_persist_native_ads"),Callable(g,"_native_ad_context_valid"))
	g.native_ad_service.initialize({});g.load_game()
	check(g.mode=="result" and g.result_payout()==150 and not g.native_ad_service.has_pending(),"Fresh game restores the saved native bonus without simulating completion or replaying the ad")
	provider.reward_earned.emit(id,{"amount":1})
	g.collect_reward()
	check(g.bank==200 and g.shift_claimed and not JSON.parse_string(FileAccess.get_file_as_string(SAVE)).has("pending_result"),"Restored result collects once and removes its pending result on disk")
	g.native_ad_service.free();g.native_ad_service=null;g.free()
	g=Main.new();g.sound_on=false;g.SAVE_FILE=SAVE;g.load_game()
	check(g.mode=="home" and g.bank==200 and g.run_id.is_empty(),"Restart after collection preserves the wallet without paying the receipt again")
	g.free()
	for path in [SAVE,SAVE+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _initialize():
	if "--native-ad-qa-isolated" not in OS.get_cmdline_user_args():
		print("NATIVE_AD_QA_REFUSED: Use isolated profile and --native-ad-qa-isolated.")
		quit(2);return
	cadence_and_acceptance()
	automatic_ad_suppression()
	durable_reward_and_restart()
	close_failure_context_and_save_retry()
	game_integration()
	disk_roundtrip()
	print("NATIVE_AD_INTEGRATION_QA_RESULT passed=",passed," failed=",failed.size())
	for issue in failed: print("FAIL: ",issue)
	quit(0 if failed.is_empty() else 1)
