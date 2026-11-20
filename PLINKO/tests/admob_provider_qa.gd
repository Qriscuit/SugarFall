extends SceneTree
const Provider = preload("res://scripts/admob_provider.gd")
const AdMobConfig = preload("res://scripts/admob_config.gd")
const LIVE_FIXTURE = {
	"enabled": true,
	"use_test_ads": false,
	"app_id": "ca-app-pub-1234567890123456~1234567890",
	"rewarded_unit_id": "ca-app-pub-1234567890123456/1111111111",
	"interstitial_unit_id": "ca-app-pub-1234567890123456/2222222222",
}
var passed = 0
var failures: Array[String] = []
class FakeNative extends RefCounted:
	signal consent_result(allowed: bool, privacy_required: bool, error: String)
	signal initialization_result(error: String)
	signal ad_loaded(kind: String, token: int)
	signal ad_load_failed(kind: String, token: int, error: Dictionary)
	signal ad_dismissed(request_id: String)
	signal ad_rewarded(request_id: String, reward: Dictionary)
	signal ad_show_failed(request_id: String, error: Dictionary)
	var enabled=true
	var consent_calls=0
	var init_calls=0
	var privacy_calls=0
	var closed=false
	var loads: Dictionary={}
	var shown: Array=[]
	var released: Array=[]
	var discarded: Array=[]
	var show_ok=true
	func available(): return enabled
	func begin_consent(_config): consent_calls+=1
	func initialize_sdk(_config): init_calls+=1
	func load_ad(kind,unit,token): loads[kind]={"unit":unit,"token":token}
	func show_ad(kind,id,context): shown.append([kind,id,context]);return show_ok
	func release(id): released.append(id)
	func discard(kind): discarded.append(kind)
	func show_privacy_options(): privacy_calls+=1
	func shutdown(): closed=true

func check(ok: bool,label: String):
	if ok: passed+=1;print("PASS: ",label)
	else: failures.append(label);print("FAIL: ",label)

func fixture(config: Variant = null):
	if config == null:
		config = AdMobConfig.read(false)
	var native=FakeNative.new()
	var provider=Provider.new(native)
	var outcomes=[]
	var earned=[]
	provider.reward_earned.connect(func(id,reward): earned.append({"id":id,"reward":reward}))
	provider.request_finished.connect(func(id,result): outcomes.append({"id":id,"result":result}))
	check(provider.initialize(config),"Native adapter can start the asynchronous consent flow")
	return {"p":provider,"n":native,"outcomes":outcomes,"earned":earned}

func arm(f):
	f.n.consent_result.emit(true,true,"")
	f.n.initialization_result.emit("")
	for kind in ["rewarded","interstitial"]: f.n.ad_loaded.emit(kind,f.n.loads[kind].token)

func consent_and_readiness():
	var unavailable=Provider.new()
	check(not unavailable.initialize(LIVE_FIXTURE) and not unavailable.is_initialized() and not unavailable.is_ready("rewarded"),"Desktop editor mocks cannot act as the production ad provider")
	unavailable.free()
	var f=fixture({"ads":AdMobConfig.read(false)})
	check(not f.p.refresh_consent() and f.n.consent_calls==1,"Repeated UI input cannot overlap native consent updates")
	check(f.n.consent_calls==1 and f.n.init_calls==0 and not f.p.is_ready("rewarded"),"Ads neither initialize nor load before native consent permits requests")
	f.n.consent_result.emit(false,false,"Consent unavailable")
	check(not f.p.status().consent_ready and f.p.status().consent_error=="Consent unavailable" and f.n.loads.is_empty(),"Consent failure exposes its actual state without loading ads")
	check(f.p.refresh_consent() and f.n.consent_calls==2,"A deliberate consent retry uses the native service again")
	f.n.consent_result.emit(true,true,"")
	check(f.n.init_calls==1 and f.p.status().consent_ready and not f.p.is_initialized(),"Consent readiness remains separate from SDK initialization")
	f.n.initialization_result.emit("")
	check(f.p.is_initialized() and not f.p.is_ready("rewarded") and f.n.loads.size()==2,"SDK initialization alone never claims ad inventory is ready")
	check(f.n.loads.rewarded.unit == AdMobConfig.DEMO_REWARDED and f.n.loads.interstitial.unit == AdMobConfig.DEMO_INTERSTITIAL,"Preview mode requests only Google's real-SDK demo units")
	for kind in ["rewarded","interstitial"]: f.n.ad_loaded.emit(kind,f.n.loads[kind].token)
	check(f.p.is_ready("rewarded") and f.p.is_ready("interstitial"),"Only matching native loaded callbacks enable each ad format")
	check(not f.p.show("rewarded","","") and not f.p.show("unknown","bad","") and f.outcomes.is_empty(),"Invalid or unavailable requests cannot create successful callbacks")
	check(f.p.show_privacy_options() and f.n.privacy_calls==1 and not f.p.is_ready("rewarded"),"Native privacy options block competing fullscreen ads")
	f.n.consent_result.emit(false,true,"")
	check(not f.p.status().consent_ready and not f.p.is_ready("rewarded") and "rewarded" in f.n.discarded,"Updated consent invalidates loaded inventory")
	f.p.free()

func production_inventory():
	var preview = AdMobConfig.read(false)
	check(AdMobConfig.valid(preview, false) and not AdMobConfig.valid(preview, true), "Preview profile is excluded from production")
	check(not AdMobConfig.valid(LIVE_FIXTURE, false), "Live inventory is excluded from the preview profile")
	var native = FakeNative.new()
	var provider = Provider.new(native)
	var invalid = [
		{},
		{"ads": []},
		preview.merged({"rewarded_unit_id": LIVE_FIXTURE.rewarded_unit_id}, true),
		preview.merged({"use_test_ads": false}, true),
		LIVE_FIXTURE.merged({"app_id": ""}, true),
		LIVE_FIXTURE.merged({"app_id": LIVE_FIXTURE.app_id + "\n"}, true),
		LIVE_FIXTURE.merged({"rewarded_unit_id": AdMobConfig.DEMO_REWARDED}, true),
		LIVE_FIXTURE.merged({"interstitial_unit_id": LIVE_FIXTURE.rewarded_unit_id}, true),
		LIVE_FIXTURE.merged({"test_device_ids": []}, true),
		LIVE_FIXTURE.merged({"consent": {"test_device_hashed_ids": []}}, true),
		LIVE_FIXTURE.merged({"consent": {"debug_geography": 0}}, true),
		LIVE_FIXTURE.merged({"consent": false}, true),
	]
	for config in invalid:
		check(not provider.initialize(config) and not provider.refresh_consent() and native.consent_calls == 0, "Invalid ad configuration fails before native consent or loading")
	provider.free()
	var f = fixture(LIVE_FIXTURE)
	check(not f.p.status().use_test_ads and f.n.loads.is_empty(), "Production waits for native consent and SDK initialization")
	arm(f)
	check(f.n.loads.rewarded.unit == LIVE_FIXTURE.rewarded_unit_id and f.n.loads.interstitial.unit == LIVE_FIXTURE.interstitial_unit_id, "Production requests exactly its configured rewarded and interstitial units")
	f.p.free()

func reward_ordering():
	var f=fixture();arm(f)
	check(f.p.show("rewarded","early","run-1") and not f.p.show("interstitial","overlap",""),"One caller-keyed fullscreen request can be active")
	f.n.ad_rewarded.emit("stale",{"amount":1})
	check(f.outcomes.is_empty(),"A reward for another request is ignored")
	f.n.ad_rewarded.emit("early",{"amount":1,"type":"coin"})
	f.n.ad_rewarded.emit("early",{"amount":999})
	check(f.earned.size()==1 and f.earned[0].id=="early" and f.earned[0].reward.amount==1,"Native earned event is emitted once immediately for durable run-ledger persistence")
	check(f.outcomes.is_empty() and f.n.released.is_empty(),"Native reward waits for dismissal without destroying its live ad")
	f.n.ad_dismissed.emit("early");f.n.ad_dismissed.emit("early")
	check(f.outcomes.size()==1 and f.outcomes[0].result.granted and f.outcomes[0].result.reward.amount==1 and f.outcomes[0].result.context=="run-1","Reward-before-dismiss completes exactly once and preserves caller run context")
	check(f.n.released==["early"] and not f.p.show("rewarded","early","run-1"),"Terminal request IDs cannot replay a grant")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","late","run-2")
	f.n.ad_dismissed.emit("late");f.p.advance(.1)
	check(f.outcomes.is_empty() and f.n.released.is_empty(),"Dismissal retains the native ad while a delayed reward callback can arrive")
	f.n.ad_rewarded.emit("late",{"amount":1,"type":"coin"})
	f.n.ad_rewarded.emit("late",{"amount":1});f.n.ad_dismissed.emit("late")
	check(f.outcomes.size()==1 and f.outcomes[0].result.granted and f.n.released==["late"],"Dismiss-before-reward also grants exactly once")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","skip","run-3");f.n.ad_dismissed.emit("skip")
	f.p.set_suspended(true);f.p.advance(60)
	check(f.outcomes.is_empty(),"Background time cannot expire the reward callback grace")
	f.p.set_suspended(false);f.p.advance(Provider.REWARD_DISMISS_GRACE+.1)
	check(f.outcomes.size()==1 and f.outcomes[0].result.status=="cancelled" and not f.outcomes[0].result.granted,"Dismissed ad without a native reward cancels without granting")
	f.n.ad_rewarded.emit("skip",{"amount":1})
	check(f.outcomes.size()==1,"Callbacks after terminal cancellation cannot create a second outcome")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","reentrant","run")
	f.p.reward_earned.connect(func(_id,_reward): f.p.shutdown())
	f.n.ad_rewarded.emit("reentrant",{"amount":1})
	check(f.outcomes.size()==1 and f.outcomes[0].result.granted,"An earned-event persistence handler may close the provider without losing or duplicating the reward")
	f.p.free()

func failures_and_lifecycle():
	var f=fixture();arm(f)
	f.p.show("interstitial","interstitial","")
	f.n.ad_rewarded.emit("interstitial",{"amount":1})
	check(f.outcomes.is_empty(),"Interstitial reward-shaped callbacks have no effect")
	f.n.ad_dismissed.emit("interstitial")
	check(f.outcomes.size()==1 and f.outcomes[0].result.status=="completed" and not f.outcomes[0].result.granted,"Interstitial completion requires native dismissal and grants no reward")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","show-failed","run")
	f.n.ad_show_failed.emit("show-failed",{"code":4,"message":"No Activity"})
	check(f.outcomes.size()==1 and f.outcomes[0].result.status=="failed" and not f.outcomes[0].result.granted,"Native show failure is terminal without awarding a reward")
	f.n.ad_dismissed.emit("show-failed");f.n.ad_rewarded.emit("show-failed",{"amount":1})
	check(f.outcomes.size()==1,"Callbacks from a failed show cannot resolve again")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","earned-error","run")
	f.n.ad_rewarded.emit("earned-error",{"amount":1});f.n.ad_show_failed.emit("earned-error",{"message":"Close error"})
	check(f.outcomes.size()==1 and f.outcomes[0].result.granted,"A later native error cannot revoke a reward already earned")
	f.p.free()
	f=fixture();arm(f);f.n.show_ok=false
	check(f.p.show("rewarded","rejected","run") and f.outcomes.size()==1 and not f.outcomes[0].result.granted,"A synchronous native show rejection resolves the accepted request as failed")
	f.p.free()
	f=fixture();arm(f);f.p.set_suspended(true)
	check(not f.p.is_ready("rewarded") and not f.p.show("rewarded","background","run"),"Suspension prevents a new ad from showing")
	f.p.set_suspended(false);f.p.show("rewarded","shutdown","run");f.p.shutdown()
	f.n.ad_rewarded.emit("shutdown",{"amount":1});f.n.ad_dismissed.emit("shutdown")
	check(not f.p.initialize(),"A disposed native session cannot be restarted with stale callbacks")
	check(f.n.closed and f.outcomes.size()==1 and f.outcomes[0].result.status=="cancelled" and not f.p.is_initialized(),"Shutdown cancels pending UI and ignores late native callbacks")
	f.p.free()
	f=fixture();arm(f);f.p.show("rewarded","earned-shutdown","run")
	f.n.ad_rewarded.emit("earned-shutdown",{"amount":1});f.p.shutdown()
	check(f.earned.size()==1 and f.outcomes.size()==1 and f.outcomes[0].result.granted,"Shutdown retains a real reward already earned before dismissal")
	f.p.free()

func load_errors_and_timeout():
	var f=fixture();f.n.consent_result.emit(true,false,"");f.n.initialization_result.emit("")
	var token=f.n.loads.rewarded.token
	f.n.ad_load_failed.emit("rewarded",token,{"code":3,"message":"No fill"})
	check(not f.p.is_ready("rewarded") and f.p.status().errors.rewarded.code==3 and f.outcomes.is_empty(),"Native no-fill exposes unavailable inventory without a fake request completion")
	f.n.ad_loaded.emit("rewarded",token)
	check(not f.p.is_ready("rewarded"),"Stale loaded callback cannot resurrect failed inventory")
	var before=f.n.loads.rewarded.token
	for value in [0.0,-1.0,NAN,INF]: f.p.advance(value)
	f.p.advance(4)
	check(f.n.loads.rewarded.token==before,"Invalid deltas and early frames cannot bypass load backoff")
	f.p.advance(1.1)
	check(f.n.loads.rewarded.token!=before,"A real retry occurs after bounded backoff")
	var retry_token=f.n.loads.rewarded.token
	f.p.advance(Provider.LOAD_TIMEOUT+.1)
	check(f.n.loads.rewarded.token==retry_token,"A large timeout frame cannot skip the newly started retry backoff")
	check(not f.p.is_ready("rewarded") and not f.p.status().errors.rewarded.is_empty(),"A missing load callback times out without inventing readiness")
	f.p.free()
	f=fixture();f.n.consent_result.emit(true,false,"");f.p.advance(Provider.INITIALIZE_TIMEOUT+.1)
	check(not f.p.is_initialized() and not f.p.status().initializing and not f.p.status().consent_error.is_empty(),"A missing SDK initialization callback leaves ads unavailable")
	f.n.initialization_result.emit("")
	check(not f.p.is_initialized(),"A stale callback after initialization timeout is ignored")
	f.p.free()

func _initialize():
	consent_and_readiness();production_inventory();reward_ordering();failures_and_lifecycle();load_errors_and_timeout()
	print("ADMOB_PROVIDER_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
