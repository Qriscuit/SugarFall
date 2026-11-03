extends SceneTree
## Ability, entitlement isolation and strict checkpoint tests use in-memory fixtures.
const Campaign=preload("res://scripts/area_campaign.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var fail_write=false
	var writes=0
	var early_access=false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): assert(false,"In-memory ability QA must not read profiles")
	func save_game(): writes+=1; return not fail_write
	func random_ball(): return "normal"
	func ability_early_access(_area: String) -> bool: return early_access
	func ability_grant_active(flag: bool) -> bool: return flag and (ability_unlock_source=="earned" or early_access)

func check(value: bool,label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture():
	var g=Fixture.new()
	g.testing=true;g.sound_on=false
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area("bakery");Campaign.apply_local(g,Campaign.default_record())
	g.current_level=8;g.highest_unlocked=8;g.levels[1]=4;g.bank=1200
	g.mode="shop";g.shift_claimed=true;g.run_id=""
	return g

func launch(g,kind: String="normal") -> Dictionary:
	g.spawn_ball(Vector2(360,267),kind,Vector2(0,85),false)
	# The hook is idempotent, and this also checks accidental duplicate dispatch.
	g.bakery_ability.on_launch(g.balls[-1])
	return g.balls[-1]

func purchases():
	var g=fixture()
	g.highest_unlocked=7
	check(not g.bakery_ability.buy(),"Earned Jam Burst stays locked before tray8")
	g.highest_unlocked=8;g.levels[1]=3
	check(not g.bakery_ability.buy(),"Earned Jam Burst requires Power4")
	g.levels[1]=4;g.bank=1199
	check(not g.bakery_ability.buy(),"Earned purchase requires its full coin price")
	g.bank=1200;g.testing=false;g.fail_write=true
	check(not g.bakery_ability.buy() and g.bank==1200 and not g.bakery_jam_burst and g.ability_unlock_source=="earned","Failed durable purchase rolls back coins, ownership and source")
	g.fail_write=false
	check(g.bakery_ability.buy() and g.bank==0 and g.bakery_jam_burst,"Earned purchase commits exactly1200coins")
	check(not g.bakery_ability.buy() and g.bank==0,"Repeated purchase cannot charge twice")
	g.trial_active=true
	check(not g.bakery_ability.owned(),"Trials ignore campaign ability ownership")
	g.trial_active=false;g.bakery_jam_burst=false;g.current_level=1;g.highest_unlocked=1;g.levels[1]=0
	check(not g.bakery_ability.activate("preview"),"Unverified early-access activation grants nothing")
	g.early_access=true
	check(g.bakery_ability.activate("preview") and g.bakery_ability.owned() and g.ability_unlock_source=="preview","Verified preview access activates early without changing its source to earned")
	g.early_access=false
	check(not g.bakery_ability.owned(),"Removing preview access disables the preview grant")
	check(not g.bakery_ability.activate("earned"),"Provider activation cannot manufacture an earned source")
	g.free()

func charge_and_splash():
	var g=fixture();g.bakery_jam_burst=true;g.start_shift();g.run_transition.finish()
	for index in range(4): check(not launch(g).jam,"Normal drop%d is not charged"%(index+1))
	launch(g,"impact")
	check(g.bakery_run.normal_launches==4,"Special drops do not consume normal charge")
	var ball=launch(g)
	check(ball.jam and g.bakery_run.normal_launches==5,"Fifth normal doughnut is charged exactly once")
	var direct={"p":Vector2(360,500),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}
	var left={"p":Vector2(310,500),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}
	var right={"p":Vector2(410,500),"hp":100.0,"max":100.0,"kind":"armored","flash":0.0}
	var third={"p":Vector2(360,575),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}
	var distant={"p":Vector2(360,606),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}
	g.pegs=[direct,left,right,third,distant]
	var splash=g.power_damage()*.75
	check(g.bakery_ability.on_hit(ball,direct)==2,"Jam hits at most the nearest two living neighbours")
	check(direct.hp==100 and is_equal_approx(left.hp,100-splash) and is_equal_approx(right.hp,100-splash),"Splash excludes direct target and uses bounded normal Power even on armor")
	check(third.hp==100 and distant.hp==100,"Third and out-of-radius targets remain unchanged")
	var wallet=g.shift_coins
	check(ball.used and g.bakery_ability.on_hit(ball,direct)==0 and g.shift_coins==wallet,"Spent jam ball cannot splash or pay again")
	var before=g.rng.state
	for index in range(5): ball=launch(g)
	check(g.rng.state==before,"Normal charge consumes no extra random draws")
	g.bakery_ability.on_hit(ball,direct)
	g.reduced_motion=true;g.bakery_ability.advance(.01)
	check(g.bakery_ability.bursts.is_empty(),"Reduced Motion clears transient burst animation")
	g.free()

func snapshots():
	var g=fixture();g.bakery_jam_burst=true;g.start_shift();g.run_transition.finish()
	for index in range(5): launch(g)
	var snap=Snapshot.capture(g)
	var decoded=Snapshot.validate_and_decode(snap,g)
	check(snap.schema==6 and decoded.ok,"Owned Bakery schema6 saves active charge: "+str(decoded.get("reason","")))
	check(decoded.ok and decoded.state.bakery_run.normal_launches==5 and decoded.state.balls[-1].jam and not decoded.state.balls[-1].used,"Charged doughnut and exact counter survive validation")
	g.balls[-1].used=true;g.balls[-1].productive=true
	snap=Snapshot.capture(g);decoded=Snapshot.validate_and_decode(snap,g)
	check(decoded.ok and decoded.state.balls[-1].used,"Spent jam flag survives checkpoint decoding")
	var damaged=snap.duplicate(true);damaged.bakery_run.normal_launches=4
	check(not Snapshot.validate_and_decode(damaged,g).ok,"Inconsistent launch charge is rejected")
	damaged=snap.duplicate(true);damaged.balls[-1].jam="yes"
	check(not Snapshot.validate_and_decode(damaged,g).ok,"Non-boolean jam flag is rejected")
	damaged=snap.duplicate(true);damaged.balls[-1].kind="impact";damaged.balls[-1].r=11.25
	check(not Snapshot.validate_and_decode(damaged,g).ok,"Special balls cannot claim Jam Burst")
	g.ability_unlock_source="preview";g.early_access=false
	check(not Snapshot.validate_and_decode(snap,g).ok,"A preview-paid checkpoint cannot resume without effective access")
	g.early_access=true
	check(Snapshot.validate_and_decode(snap,g).ok,"Matching preview entitlement permits its unchanged checkpoint")
	g.bakery_jam_burst=false;g.ability_unlock_source="earned";g.early_access=false
	g.start_shift();g.run_transition.finish();launch(g)
	snap=Snapshot.capture(g);decoded=Snapshot.validate_and_decode(snap,g)
	check(snap.schema==4 and decoded.ok and not decoded.state.bakery_run.enabled,"Unowned Bakery keeps legacy schema4 without inventing charge")
	check(not snap.balls[0].has("jam"),"Legacy unowned normal balls retain their original shape")
	var legacy=Campaign.default_record();legacy.erase("bakery_jam_burst");legacy.erase("ability_unlock_source")
	check(Campaign.valid_record(legacy,"bakery") and not Campaign.normalized(legacy,"bakery").bakery_jam_burst and Campaign.normalized(legacy,"bakery").ability_unlock_source=="earned","Old campaign records normalize new fields without granting ownership")
	legacy=Campaign.default_record();legacy.bakery_jam_burst=true
	check(not Campaign.valid_record(legacy,"gelato"),"Bakery ownership cannot cross into another area record")
	legacy=Campaign.default_record();legacy.ability_unlock_source="free_money"
	check(not Campaign.valid_record(legacy,"bakery"),"Unknown grant sources are rejected")
	g.free()

func _initialize():
	purchases();charge_and_splash();snapshots()
	print("BAKERY_ABILITY_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
