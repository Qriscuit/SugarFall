extends SceneTree
var failed: Array = []
var passed = 0
var g
func _initialize():
	g = load("res://scripts/main.gd").new()
	g.testing = true
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.rng.seed = 42
	check_short_shift_balance()
	check_core()
	check_specials()
	check_productive_bins()
	check_lower_bucket_boundary()
	check_fractional_catches()
	check_roster()
	check_vouchers_passive()
	check_passive_specials()
	check_trials()
	check_mobile()
	check_bonus_confirmation()
	check_save()
	print("QA_RESULT passed=",passed," failed=",failed.size())
	for issue in failed: print("FAIL: ",issue)
	g.free()
	quit(1 if failed.size() else 0)
func check(ok, label):
	if ok: passed += 1; print("PASS: ",label)
	else: failed.append(label)
func check_core():
	g.start_shift()
	check(g.pegs.size()==8,"First level has eight pegs in candidate C")
	g.mode="paused"
	var t=g.remaining
	g._process(1)
	check(g.remaining==t,"Paused process does not consume time")
	g.mode="play"
	g.pulse_charge=1.0
	var before_pegs=g.pegs.duplicate(true)
	var before_stats=g.special_stats.duplicate(true)
	var before_rng=g.rng.state
	g.pulse()
	check(g.pulse_charge==1 and g.pegs==before_pegs and g.special_stats==before_stats and g.rng.state==before_rng,"Legacy pulse entry point cannot damage pegs, consume RNG or alter stats")
	var count=g.destroyed
	g.pulse()
	check(g.destroyed==count,"Repeated legacy pulse calls cannot damage")
	g.start_shift()
	for i in range(g.pegs.size()-1): g.pegs[i].hp=0
	g.step(.01)
	check(g.mode=="play" and not g.level_won,"One remaining peg prevents win")
	g.pegs[-1].hp=0
	g.step(.01)
	check(g.mode=="result" and g.level_won,"All pegs clear grants win")
	var old_level=g.current_level
	var reward=g.shift_coins
	g.collect_reward(true)
	check(is_equal_approx(g.bank,reward),"Unverified legacy bonus argument pays only earned base credits")
	check(g.current_level==old_level+1,"Claimed clear advances one level")
	var bank=g.bank
	g.collect_reward(true)
	check(g.bank==bank,"Repeated claim cannot duplicate credits")
	g.start_shift()
	g.remaining=.001
	g.step(.01)
	check(g.mode=="result" and not g.level_won,"Timeout retains level without clear")
	g.start_shift()
	g.pickups=[{"p":Vector2(300,500),"life":4.0}]
	t=g.remaining
	g.collect_pickups(Vector2(300,500))
	g.collect_pickups(Vector2(300,500))
	check(is_equal_approx(g.remaining,t+2),"Time pickup awards exactly once")
	g.add_time(50)
	check(g.time_bonus==3,"Time bonuses capped at three seconds")
	g.start_shift()
	var p={"p":Vector2(300,500),"hp":1.0,"max":1.0,"kind":"clock","flash":0.0}
	t=g.remaining
	g.damage_peg(p,1)
	g.damage_peg(p,1)
	check(is_equal_approx(g.remaining,t+.5),"Clock peg awards exactly 0.5 seconds once")
	g.bank=0
	var lvl=g.levels[0]
	check(not g.buy_upgrade(0) and g.levels[0]==lvl,"Unaffordable purchase cannot mutate upgrade")
	g.bank=100000
	g.levels[0]=g.MAX_LEVELS[0]
	bank=g.bank
	check(not g.buy_upgrade(0) and g.bank==bank,"Maximum upgrade cannot spend")
	g.start_shift()
	t=g.remaining
	g.testing=false
	g.sound_on=false
	for i in range(10): g._physics_process(.1)
	g.testing=true
	check(is_equal_approx(t-g.remaining,1),"One wall-clock second consumes one timer second at 10fps")
	g.start_shift()
	g.remaining=.001
	g.pegs=[{"p":Vector2(300,400),"hp":1.0,"max":1.0,"kind":"normal","flash":0.0}]
	g.balls.clear()
	g.spawn_ball(Vector2(300,360),"normal",Vector2(0,300))
	g.step(.1)
	check(not g.level_won,"No clear awarded after timer expires during step")
	g.start_shift()
	g.pickups=[{"p":Vector2(300,500),"life":4.0}]
	var ev=InputEventMouseMotion.new()
	ev.position=g.board_to_screen(Vector2(300,500))
	ev.button_mask=0
	t=g.remaining
	g._input(ev)
	check(g.remaining==t+2,"Mouse hover collects pickup without click")
	g.start_shift()
	g.pickups=[{"p":Vector2(300,500),"life":4.0}]
	var touch=InputEventScreenTouch.new()
	touch.position=g.board_to_screen(Vector2(300,500))
	touch.pressed=true
	t=g.remaining
	g._input(touch)
	check(g.remaining==t+2,"Touch collects pickup")
func check_save():
	g.bank=1234
	g.levels=[1,2,3,4,5,6,7,8]
	g.current_level=4
	g.total_shifts=9
	g.save_game()
	g.bank=0
	g.levels=[0,0,0,0,0,0,0,0]
	g.current_level=1
	g.load_game()
	check(g.bank==1234 and g.levels==[1,2,3,4,5,6,7,8] and g.current_level==4,"Save/load preserves bank, upgrades, progression")
	var valid_save=FileAccess.get_file_as_string(g.SAVE_FILE)
	var f=FileAccess.open(g.SAVE_FILE,FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	g.load_game()
	check(g.bank==1234 and g.profile_load_blocked and not g.save_game(),"Malformed JSON preserves current state and cannot overwrite recovery data")
	f=FileAccess.open(g.SAVE_FILE,FileAccess.WRITE)
	f.store_string(valid_save); f.close()
	g.load_game()
	g.start_shift()
	g.shift_coins=99
	g.finish_shift()
	g.save_game()
	var restored=load("res://scripts/main.gd").new()
	restored.testing=true
	restored.load_game()
	check(restored.mode=="result" and restored.shift_coins==99,"Unclaimed completed result survives restart")
	restored.free()

func check_specials():
	g.levels=[0,0,0,0,0,0,0,0]
	g.start_shift()
	g.pegs=[{"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	g.balls.clear()
	g.spawn_ball(Vector2(300,368),"splitter",Vector2(0,300))
	g.step(.01)
	check(g.balls.size()==4 and g.type_drops.shard==3,"Splitter creates exactly three shards on first contact")
	for i in range(30): g.step(.01)
	check(g.type_drops.shard==3,"Splitter shards do not recursively split")
	g.start_shift()
	g.pegs=[{"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	g.balls.clear()
	g.spawn_ball(Vector2(300,372),"shard",Vector2(0,300))
	g.step(.01)
	check(is_equal_approx(g.pegs[0].hp,99.5),"Shard damage is half normal damage")
	g.start_shift()
	g.pegs=[{"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":"armored","flash":0.0}]
	g.balls.clear()
	g.spawn_ball(Vector2(300,368),"impact",Vector2(0,300))
	g.step(.01)
	check(g.pegs[0].hp==94.0 and g.special_stats.impact==0 and g.balls[0].used,"First Impact deals six times starting Power to armor without an automatic kill")
	check(g.balls[0].r==11.25 and g.ball_radius("normal")==9 and g.ball_radius("shard")==6,"Pumpkin radius is 25 percent larger than donut while seed radius stays six")
	g.start_shift()
	g.spawn_clock=10
	g.pegs=[{"p":Vector2(300,351.5),"hp":100.0,"max":100.0,"kind":"armored","flash":0.0}]
	g.spawn_ball(Vector2(300,384.25),"impact",Vector2.ZERO)
	g.step(.001)
	check(g.pegs[0].hp==94.0,"Expanded pumpkin collider applies its armored first hit across a spatial-grid row boundary")
	g.start_shift()
	g.spawn_clock=10
	g.pegs=[{"p":Vector2(300,400),"hp":6.0,"max":6.0,"kind":"armored","flash":0.0},{"p":Vector2(500,500),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	g.spawn_ball(Vector2(300,368),"impact",Vector2(0,300))
	g.step(.01)
	check(g.pegs[0].hp<=0 and g.balls[0].used and g.mode=="play","Pumpkin can finish six remaining armored HP with its first hit while remaining in play")
	g.balls[0].p=Vector2(500,468)
	g.balls[0].v=Vector2(0,300)
	g.balls[0].cool=0
	g.step(.01)
	check(is_equal_approx(g.pegs[1].hp,99) and g.special_stats.impact==1,"The same pumpkin deals ordinary damage to its second peg and retains its single kill attribution")
	check(g.restitution("ricochet")>g.restitution("normal"),"Ricochet retains more bounce energy")
	g.bank=100000
	g.levels=[0,0,0,0,0,0,0,0]
	g.equipped=[]
	var connected=true
	for family in [0,7,3,7]: connected=g.buy_upgrade(family) and connected
	check(connected,"Split drop fixture follows Feed, Time, Ricochet and Time2 along its route")
	# The preceding Ricochet is automatically equipped; free its slot so this
	# fixture continues to exercise Split's automatic equip/drop behavior.
	g.toggle_module("ricochet")
	var rng_before=g.rng.state
	g.buy_upgrade(4)
	check(g.levels[4]==1 and "splitter" in g.equipped and g.force_special=="" and g.rng.state==rng_before,"Purchasing a special enables its chance without forcing a drop or consuming RNG")

func check_roster():
	check(g.board_data.size()==12,"Authored chapter has twelve boards")
	for n in range(1,13):
		g.current_level=n
		g.start_shift()
		var valid=g.pegs.size()==g.board_data[n-1].peg_count
		var clocks=0
		for i in range(g.pegs.size()):
			var p=g.pegs[i]
			valid=valid and p.p.x>=64 and p.p.x<=656 and p.p.y>=300 and p.p.y<=815
			if p.kind=="clock": clocks+=1
			for j in range(i): valid=valid and p.p.distance_to(g.pegs[j].p)>=44
		check(valid and clocks==g.board_data[n-1].clock_peg_count,"Board %d count, bounds, non-overlap and clock count" % n)
	g.levels=[0,0,0,0,0,0,0,0]
	g.equipped=[]
	g.highest_unlocked=1
	g.toggle_module("impact")
	check(g.equipped.is_empty(),"Unowned module cannot equip")
	g.bank=10000
	var connected=true
	for family in [0,2,1,7,3,7,4]: connected=g.buy_upgrade(family) and connected
	check(connected,"Module roster connects Power and the Ricochet/Split route through authoritative purchases")
	check(g.equipped==["ricochet"] and g.levels[4]==1,"One-slot cap allows ownership without equipping")
	var money=g.bank
	g.toggle_module("ricochet")
	g.toggle_module("splitter")
	check(g.equipped==["splitter"] and g.bank==money,"Owned modules freely swap")
	g.force_special="impact"
	var no_impact=true
	for i in range(100): no_impact=no_impact and g.random_ball()!="impact"
	check(no_impact,"Forced but unequipped module never spawns")
	g.highest_unlocked=4
	g.toggle_module("ricochet")
	var impact_bought=g.buy_upgrade(5)
	check(impact_bought and g.levels[5]==1 and g.equipped.size()==2 and "impact" not in g.equipped,"Second slot unlocked at board four and capped at two")
	g.current_level=1
	g.highest_unlocked=10
	g.start_shift()
	g.level_won=true
	g.finish_shift()
	g.collect_reward(false)
	check(g.highest_unlocked==10,"Replay clear preserves highest unlocked")
	g.current_level=12
	g.start_shift()
	g.level_won=true
	g.finish_shift()
	g.collect_reward(false)
	check(g.chapter_complete and g.current_level==12 and g.highest_unlocked==12,"Final clear completes chapter without board thirteen")
	g.current_level=3
	g.mode="home"
	g.save_game()
	g.current_level=1
	g.highest_unlocked=1
	g.chapter_complete=false
	g.equipped=[]
	g.load_game()
	check(g.current_level==3 and g.highest_unlocked==12 and g.chapter_complete and g.equipped.size()==2,"Save preserves selected board, highest unlock, chapter and loadout")

func check_productive_bins():
	var original=g.tuning.duplicate()
	g.tuning.productive_bins_only=true
	g.levels=[0,0,0,0,0,0,0,0]
	g.start_shift()
	g.spawn_clock=10
	g.spawn_ball(Vector2(360,g.BUCKET_CATCH_Y+1),"normal")
	var old=g.shift_coins
	g.step(.01)
	check(g.shift_coins==old,"Unproductive ball earns no bin payout when enabled")
	g.spawn_ball(Vector2(360,g.BUCKET_CATCH_Y+1),"normal")
	g.balls[-1].productive=true
	g.step(.01)
	check(g.shift_coins>old,"Productive ball retains bin payout")
	g.start_shift()
	g.pegs=[{"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	g.spawn_clock=10
	g.spawn_ball(Vector2(300,368),"splitter",Vector2(0,300))
	g.step(.01)
	var eligible=true
	for b in g.balls: eligible=eligible and b.productive
	check(g.balls.size()==4 and eligible,"Splitter and its shards inherit productive eligibility")
	g.tuning=original

func catch_food(x, bin_index, kind="normal", productive=true):
	# Use the real catch path, avoiding pegs and the automatic drop timer.
	x.spawn_clock=.74
	x.spawn_ball(Vector2(105.6+bin_index*127.2,x.BUCKET_CATCH_Y+1),kind,Vector2.ZERO)
	x.balls[-1].productive=productive
	x.step(.001)

func check_lower_bucket_boundary():
	var x=load("res://scripts/main.gd").new()
	x.testing=true
	x.sound_on=false
	x.board_data=g.board_data
	x.levels=[0,0,0,0,0,0,0,0]
	x.current_level=1
	x.total_shifts=0
	x.start_shift()
	x.spawn_clock=.74
	x.spawn_ball(Vector2(360,838),"normal",Vector2(0,100))
	x.balls[-1].productive=true
	x.step(.001)
	check(x.balls.size()==1 and x.buckets[2].hits==0 and x.shift_coins==0,"Food passes the former bucket height without disappearing or earning early")
	x.balls[0].p.y=x.BUCKET_CATCH_Y-1
	x.balls[0].v=Vector2(0,100)
	x.step(.001)
	check(x.balls.size()==1 and x.buckets[2].hits==0 and x.shift_coins==0,"Food immediately above the lowered cup opening remains in flight")
	x.step(.01)
	check(x.balls.is_empty() and x.buckets[2].hits==1 and is_equal_approx(x.shift_coins,1.1),"Crossing the lowered cup opening catches food and pays its increased multiplier")
	x.step(.01)
	check(x.balls.is_empty() and x.buckets[2].hits==1 and is_equal_approx(x.shift_coins,1.1),"A lower cup catch pays and increments its multiplier only once")
	x.free()

func check_fractional_catches():
	var x=load("res://scripts/main.gd").new()
	x.testing=true
	x.sound_on=false
	x.board_data=g.board_data
	x.levels=[0,0,0,0,0,0,0,0]
	x.current_level=1
	x.total_shifts=0
	x.start_shift()
	catch_food(x,2)
	check(x.buckets[2].hits==1 and is_equal_approx(x.bucket_reward(2),1.1) and is_equal_approx(x.shift_coins,1.1),"First donut immediately raises its bucket to 1.1x and earns 1.1 credits")
	catch_food(x,2)
	check(x.buckets[2].hits==2 and is_equal_approx(x.bucket_reward(2),1.2) and is_equal_approx(x.shift_coins,2.3),"Second donut raises the same bucket to 1.2x and total earnings to 2.3 credits")
	check(x.buckets[1].hits==0 and is_equal_approx(x.bucket_reward(1),1.0) and x.balls.is_empty(),"Catches remove food once and leave other buckets unchanged")
	for i in range(40): catch_food(x,2)
	check(x.buckets[2].hits==42 and is_equal_approx(x.bucket_reward(2),5.2) and is_equal_approx(x.shift_coins,132.3),"Forty-two real catches keep increasing the multiplier beyond the previous cap without fractional drift")
	var earned=x.shift_coins
	x.step(.001)
	check(x.buckets[2].hits==42 and is_equal_approx(x.shift_coins,earned),"Caught food cannot pay or grow the bucket again on the next tick")
	x.start_shift()
	catch_food(x,2,"shard")
	check(is_equal_approx(x.bucket_reward(2),1.1) and is_equal_approx(x.shift_coins,.55),"A pomegranate seed grows its bucket and earns an exact half-value 0.55 credits")
	catch_food(x,2)
	catch_food(x,2,"shard")
	check(x.buckets[2].hits==3 and is_equal_approx(x.bucket_reward(2),1.3) and is_equal_approx(x.shift_coins,2.4),"Mixed donuts and seeds retain 0.05-credit precision rather than rounding each catch to an integer")
	x.levels[6]=3
	x.start_shift()
	catch_food(x,0,"impact")
	check(x.buckets[0].gold and is_equal_approx(x.bucket_reward(0),6.1) and is_equal_approx(x.shift_coins,6.1),"A pumpkin catch adds 0.1x on top of the upgraded gold bucket base")
	x.tuning.productive_bins_only=true
	x.start_shift()
	catch_food(x,2,"normal",false)
	check(x.buckets[2].hits==0 and is_equal_approx(x.bucket_reward(2),1.0) and x.shift_coins==0,"Unproductive food neither earns credits nor increases a bucket when eligibility filtering is enabled")
	catch_food(x,2,"shard",true)
	check(x.buckets[2].hits==1 and is_equal_approx(x.shift_coins,.55),"The next eligible seed starts filtered bucket growth at 1.1x and pays 0.55 credits")
	x.free()

func check_vouchers_passive():
	g.levels=[0,0,0,0,0,0,0,0]
	g.module_milestones=[]
	g.module_vouchers=0
	g.equipped=[]
	g.current_level=2
	g.start_shift()
	g.level_won=true
	g.finish_shift()
	g.collect_reward(false)
	check(g.module_vouchers==1 and g.module_milestones==[2],"Board two clear grants exactly one voucher")
	g.current_level=2
	g.start_shift()
	g.level_won=true
	g.finish_shift()
	g.collect_reward(false)
	check(g.module_vouchers==1,"Replay milestone cannot duplicate voucher")
	g.bank=maxf(g.bank,10000)
	var connected=true
	for family in [0,2,1]: connected=g.buy_upgrade(family) and connected
	check(connected,"Voucher fixture follows the single Bounce and Power route to Impact without using its voucher")
	var money=g.bank
	check(g.claim_module("impact") and g.module_vouchers==0 and g.levels[5]==1 and g.bank==money,"Voucher unlocks module with no cash charge")
	check(g.force_special=="","Voucher claim does not guarantee a special drop")
	check(not g.claim_module("impact") and not g.claim_module("invalid"),"Invalid or repeated voucher claim fails")
	g.module_vouchers=1
	g.save_game()
	g.module_vouchers=0
	g.module_milestones=[]
	g.load_game()
	check(g.module_vouchers==1 and g.module_milestones==[2],"Voucher and milestone persistence")
	g.current_level=5
	g.levels[3]=1
	g.levels[4]=1
	g.start_shift()
	g.level_won=true
	g.finish_shift()
	money=g.bank
	var earned=g.shift_coins
	g.collect_reward(false)
	check(g.bank==money+earned+60 and g.module_vouchers==1,"All-owned milestone substitutes exactly sixty credits")
	g.equipped=["impact","splitter"]
	g.start_shift()
	check(not g.queue_module("impact") and g.queued_special=="","Equipped specials cannot be queued manually")
	check(not g.queue_module("impact") and g.module_cooldowns.impact==0,"Repeated queue attempts cannot start a cooldown")
	g.mode="paused"
	var cd=g.module_cooldowns.impact
	g.step(1)
	check(not g.queue_module("splitter") and g.module_cooldowns.impact==cd,"Paused queue remains disabled")
	g.mode="play"
	g.remaining=0
	check(not g.queue_module("splitter"),"Expired timer blocks queue")
	g.start_shift()
	g.queued_special="impact" # Legacy state cannot bypass equipped ownership.
	g.equipped.erase("impact")
	g.force_special=""
	check(g.random_ball()!="impact" and g.module_cooldowns.impact==0,"Unequipped queued shot is discarded without cooldown")
	g.start_shift()
	check(g.queued_special=="" and g.module_cooldowns.impact==0,"New shift resets queue and module cooldowns")

func check_passive_specials():
	var x=load("res://scripts/main.gd").new()
	x.testing=true
	x.sound_on=false
	x.levels=[0,0,0,1,1,1,0,0]
	x.highest_unlocked=4
	x.equipped=["impact","splitter"]
	x.start_shift()
	x.pulse_charge=1
	x.aim_x=x.pegs[0].p.x
	x.aim_y=x.pegs[0].p.y
	var pegs_before=x.pegs.duplicate(true)
	var rng_before=x.rng.state
	var key=InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_SPACE
	x._input(key)
	x.handle_press(Vector2(200,970))
	x.handle_press(Vector2(500,970))
	x.handle_press(Vector2(300,1070))
	check(x.pegs==pegs_before and x.destroyed==0 and x.queued_special=="" and x.rng.state==rng_before and x.total_spawned==0,"Space and former ability button areas cannot damage, queue, spawn or change RNG")
	x.pulse_charge=0
	x.spawn_clock=1
	x.step(.1)
	check(x.pulse_charge==0 and x.pulse_flash==0,"Gameplay no longer charges or flashes pulse")
	var reference=RandomNumberGenerator.new()
	x.rng.seed=42871
	reference.seed=42871
	var correct=true
	var counts={"normal":0,"splitter":0,"impact":0}
	for index in range(20000):
		x.queued_special="impact"
		x.force_special="splitter"
		var roll=reference.randf()
		var expected="impact" if roll<.048 else ("splitter" if roll<.096 else "normal")
		var actual=x.random_ball()
		correct=correct and actual==expected and x.rng.state==reference.state
		counts[actual]=counts.get(actual,0)+1
	check(correct and x.queued_special=="" and x.force_special=="","Every drop follows one RNG roll at 4.8 percent per owned equipped food; legacy overrides are ignored")
	check(counts.impact>800 and counts.impact<1120 and counts.splitter>800 and counts.splitter<1120 and counts.normal>17000,"Passive drop sampling yields both special foods and predominantly normal donuts")
	x.levels[3]=6
	x.equipped=["ricochet"]
	x.rng.seed=9185
	reference.seed=9185
	correct=true
	var ricochets=0
	for index in range(10000):
		var expected="ricochet" if reference.randf()<.132 else "normal"
		var actual=x.random_ball()
		correct=correct and actual==expected
		if actual=="ricochet": ricochets+=1
	check(correct and ricochets>1150 and ricochets<1500,"Upgraded ricochet probability is 13.2 percent and unequipped foods never spawn")
	x.levels[3]=0
	var locked=true
	for index in range(100): locked=locked and x.random_ball()=="normal"
	check(locked,"An equipped entry without ownership cannot generate a special")
	x.levels[5]=1
	x.equipped=[]
	x.force_special=""
	rng_before=x.rng.state
	x.toggle_module("impact")
	check(x.equipped==["impact"] and x.force_special=="" and x.rng.state==rng_before,"Equipping a food enables chance without scheduling it or consuming RNG")
	x.free()

func check_trials():
	g.mode="home"
	g.highest_unlocked=3
	check(not g.begin_trial(4),"Trials locked until fourth board")
	g.highest_unlocked=8
	g.chapter_complete=false
	g.bank=1234
	g.levels=[3,4,2,1,0,0,1,2]
	g.current_level=6
	g.equipped=["ricochet"]
	g.module_vouchers=1
	g.module_milestones=[2,5]
	g.total_shifts=25
	g.trial_records={}
	check(g.begin_trial(12) and g.levels==[6,6,2,1,1,1,0,4] and g.bank==0 and g.module_slots()==2,"Trial uses fixed power and two module slots")
	g.levels[0]=9
	check(g.RunSnapshot.TRIAL_LEVELS==[6,6,2,1,1,1,0,4],"Changing trial runtime upgrades cannot mutate the shared fixed-profile constant")
	g.equipped.erase("ricochet")
	g.module_milestones.append(8)
	g.save_game()
	var restored=load("res://scripts/main.gd").new()
	restored.testing=true
	restored.load_game()
	check(restored.bank==1234 and restored.levels[0]==3 and restored.current_level==6 and restored.module_milestones==[2,5] and not restored.trial_active,"Restart during trial restores campaign snapshot without alias mutations")
	restored.free()
	g.end_trial()
	check(g.bank==1234 and g.levels==[3,4,2,1,0,0,1,2] and g.equipped==["ricochet"] and g.module_milestones==[2,5],"Trial exit fully restores campaign arrays")
	g.begin_trial(4)
	g.start_shift()
	check(g.remaining==12.0 and is_equal_approx(g.power_damage(),3.55),"Fixed trial starts with twelve seconds and the shared 3.55 tier-six damage")
	g.shift_coins=99999
	g.run_elapsed=7.5
	g.level_won=true
	g.finish_shift()
	check(g.trial_records.get("4",0)==7.5 and g.total_shifts==25,"Trial win records time without campaign shift increment")
	g.collect_reward(true)
	check(g.bank==1234 and g.current_level==6 and g.module_vouchers==1 and not g.trial_active,"Trial collect bonus cannot leak credits, progression or vouchers")
	g.begin_trial(4)
	g.start_shift()
	g.run_elapsed=9.0
	g.level_won=true
	g.finish_shift()
	g.collect_reward()
	check(g.trial_records["4"]==7.5,"Slower trial win cannot replace best record")
	g.begin_trial(8)
	g.start_shift()
	g.remaining=0
	g.step(.01)
	g.collect_reward()
	check(not "8" in g.trial_records and g.bank==1234,"Trial timeout creates no record or campaign earnings")
	g.save_game()
	restored=load("res://scripts/main.gd").new()
	restored.testing=true
	restored.load_game()
	check(restored.trial_records.get("4",0)==7.5 and restored.current_level==6,"Trial records persist separately from campaign")
	restored.free()

func check_mobile():
	g._process(.5)
	g.apply_safe_area(Rect2(0,80,720,1160))
	var bounds=g.transform*Rect2(0,0,720,1280)
	check(bounds.position.y>=80 and bounds.end.y<=1240 and bounds.position.x>=0 and bounds.end.x<=720,"Synthetic notch safe area contains complete logical board")
	check(is_equal_approx(g.scale.x,g.scale.y),"Safe area preserves uniform aspect ratio")
	g.start_shift()
	var touch=InputEventScreenTouch.new()
	touch.index=0
	touch.position=g.to_global(g.board_to_screen(Vector2(200,500)))
	touch.pressed=true
	g._input(touch)
	check(is_equal_approx(g.aim_x,200) and is_equal_approx(g.aim_y,500),"Primary touch maps through safe-area and enlarged-board transforms")
	touch.index=1
	touch.position=g.to_global(g.board_to_screen(Vector2(600,700)))
	g._input(touch)
	check(is_equal_approx(g.aim_x,200),"Second finger cannot steer")
	var drag=InputEventScreenDrag.new()
	drag.index=1
	drag.position=g.to_global(g.board_to_screen(Vector2(600,700)))
	g._input(drag)
	check(is_equal_approx(g.aim_x,200),"Second finger drag cannot steer")
	drag.index=0
	drag.position=g.to_global(g.board_to_screen(Vector2(440,1060)))
	g._input(drag)
	check(is_equal_approx(g.aim_x,440) and is_equal_approx(g.aim_y,770),"Primary drag across lower tray still aims the dropper with a bounded marker")
	g.pickups=[{"p":Vector2(300,500),"life":4.0}]
	var motion=InputEventMouseMotion.new()
	motion.position=g.to_global(g.board_to_screen(Vector2(300,500)))
	var time=g.remaining
	g._input(motion)
	check(is_equal_approx(g.remaining,time+2),"Mouse hover maps through safe-area and enlarged-board transforms")
	g.start_shift()
	g.pickups=[{"p":Vector2(80,360),"life":4.0}]
	motion.position=g.to_global(g.board_to_screen(Vector2(80,360))+Vector2(-42,0))
	time=g.remaining
	g._input(motion)
	check(is_equal_approx(g.remaining,time+2),"Hover inside the enlarged pickup's outer edge collects it at its displayed position")
	g.go_back()
	check(g.mode=="paused","Back pauses active shift")
	g._process(.26)
	g.go_back()
	check(g.mode=="play","Back resumes paused shift")
	g.finish_shift()
	var money=g.bank
	g.handle_press(Vector2(300,950))
	check(g.mode=="result" and g.bank==money,"Result click-through blocked during half-second delay")
	g.go_back()
	check(g.mode=="result" and not g.shift_claimed,"Back preserves unclaimed result")
	g._process(.51)
	g.handle_press(Vector2(300,840))
	check(g.mode=="home" and g.shift_claimed,"Result claim returns Home after the input delay")
	g.apply_safe_area(Rect2(-20,-20,760,1320))
	check(g.scale==Vector2.ONE and g.position==Vector2.ZERO,"Oversized safe rect clips to full logical viewport")
	g.apply_safe_area(Rect2(900,900,1,1))
	check(g.scale==Vector2.ONE and g.position==Vector2.ZERO,"Nonintersecting safe rect leaves valid transform untouched")

func check_bonus_confirmation():
	g.trial_active=false
	g.mode="home"
	g.current_level=1
	g.start_shift()
	g.shift_coins=100
	g.finish_shift()
	g._process(.51)
	var money=g.bank
	g.handle_press(Vector2(300,950))
	check(g.mode=="bonus_confirm" and g.bank==money and not g.shift_claimed,"Bonus opens confirmation without paying")
	g.handle_press(Vector2(300,660))
	check(g.mode=="bonus_confirm" and g.bank==money,"Confirmation delay blocks immediate confirm")
	g._process(.26)
	g.handle_press(Vector2(300,950))
	check(g.mode=="bonus_confirm" and g.bank==money,"Repeated bonus-position tap cannot confirm")
	g.handle_press(Vector2(300,780))
	check(g.mode=="result" and not g.shift_claimed and g.shift_coins==100,"Cancel preserves original base result")
	g._process(.26)
	g.handle_press(Vector2(300,950))
	g._process(.26)
	g.go_back()
	check(g.mode=="result" and not g.shift_claimed and g.bank==money,"Back dismisses confirmation without reward")
	g._process(.26)
	g.handle_press(Vector2(300,950))
	g.testing=false
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	g.testing=true
	var restored=load("res://scripts/main.gd").new()
	restored.testing=true
	restored.load_game()
	check(restored.mode=="result" and restored.shift_coins==100 and not restored.shift_claimed and restored.bank==money,"Focus-out save during confirmation restores unclaimed base result")
	restored.free()
	g._process(.26)
	g.handle_press(Vector2(300,660))
	check(g.mode=="test_ad" and g.bank==money and not g.shift_claimed,"Confirmed reward opens the test ad without paying")
	g.finish_test_request("completed")
	check(g.mode=="result" and g.reward_earned and g.bank==money,"Only completed test ad records the rewarded bonus")
	g.collect_reward(false)
	check(g.bank==money+150 and g.shift_claimed,"Collect after completed ad pays exactly one hundred fifty percent")
	g.collect_reward(true)
	check(g.bank==money+150,"Repeated confirmed reward cannot duplicate payout")
	g.start_shift()
	g.shift_coins=100
	g.finish_shift()
	g._process(.51)
	money=g.bank
	g.handle_press(Vector2(300,840))
	check(g.bank==money+100 and g.shift_claimed and g.mode!="bonus_confirm","Normal Collect remains one-step base reward")
	g.mode="home"
	g.highest_unlocked=4
	g.begin_trial(4)
	g.start_shift()
	g.finish_shift()
	g._process(.51)
	g.handle_press(Vector2(300,950))
	check(g.mode=="result" and g.trial_active,"Hidden trial bonus area cannot open confirmation")
	g.end_trial()

# Explicit v0.4 balance contracts, using an isolated fixture so the original
# lifecycle, collision, reward-idempotence and persistence assertions stay intact.
func check_short_shift_balance():
	var x=load("res://scripts/main.gd").new()
	x.testing=true
	x.sound_on=false
	x.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	x.start_shift()
	check(x.BASE_SECONDS==10.0 and x.remaining==10.0,"Unupgraded short shift starts with exactly ten seconds")
	check(x.tuning.core_step==0.5 and is_equal_approx(x.power_damage(10),4.55) and x.CLOCK_STEP==0.5 and x.BONUS_TIME_CAP==3.0,"Tapered Power, clock and bonus-cap constants match short-run contracts")
	var prices=[]
	for index in range(8): prices.append(x.upgrade_cost(index))
	check(prices==[38,50,38,63,75,88,44,19],"Starting prices match the gradual Bakery savings curve")
	x.levels[0]=1
	check(x.upgrade_cost(0)==66,"Feeder upgrade cost uses the 1.75 multiplier")
	x.levels=[0,1,0,0,0,0,0,1]
	check(x.upgrade_cost(1)==93 and x.tuning.core_cost_growth==1.85,"Core upgrades use the 1.85 cost multiplier")
	x.start_shift()
	check(x.remaining==10.5,"One clock upgrade adds exactly half a second")
	x.pegs=[{"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	x.spawn_clock=1.0
	x.spawn_ball(Vector2(300,368),"normal",Vector2(0,300))
	x.step(.01)
	check(is_equal_approx(x.pegs[0].hp,98.5),"One core upgrade gives normal balls exactly 1.50 damage")
	var roster_ok=true
	for board in range(1,13):
		x.current_level=board
		x.start_shift()
		roster_ok=roster_ok and x.pegs.size()==[8,12,16,18,20,22,24,26,28,30,32,34][board-1]
		for peg in x.pegs:
			var spec=x.board_data[board-1]
			var expected_hp=float(spec.base_hp)*(float(spec.armored_hp_multiplier) if peg.kind=="armored" else 1.0)
			roster_ok=roster_ok and is_equal_approx(peg.max,expected_hp)
	check(roster_ok,"Authored Bakery boards retain their peg counts and apply each tray's normal and armored durability")
	x.current_level=1
	x.levels=[0,0,0,0,0,0,0,0]
	x.start_shift()
	var peg=x.pegs[0]
	x.damage_peg(peg,1.0)
	check(peg.hp==5.0 and x.shift_coins==1 and x.destroyed==0,"Productive Bronze damage earns its share of the fixed coin budget")
	x.damage_peg(peg,9999.0)
	var total=x.shift_coins
	var break_reward=int(x.tuning.peg_base+floor((x.wave-x.tuning.peg_level_offset)*x.tuning.peg_level_step))
	check(total==6+break_reward,"Overkill earns the six-coin damage budget plus its ordinary break reward")
	x.damage_peg(peg,9999.0)
	check(x.shift_coins==total,"Repeated damage to a dead peg cannot duplicate its coin budget")
	x.current_level=12
	x.highest_unlocked=12
	x.levels[7]=10
	x.start_shift()
	var spawns=0
	var first_spawn_time=0.0
	var previous_clock=x.pickup_clock
	for tick in range(1200):
		if x.mode!="play": break
		x.step(1.0/60.0)
		if x.pickup_clock>previous_clock+1.0:
			spawns+=1
			if spawns==1: first_spawn_time=x.run_elapsed
		previous_clock=x.pickup_clock
		for pickup in x.pickups: x.collect_pickups(pickup.p)
	check(spawns==1 and absf(first_spawn_time-4.0)<=1.0/60.0+0.000001,"Only one free pickup spawns, at four seconds within one physics tick")
	check(x.time_bonus<=3.0,"Pickup and clock-peg rewards share the three-second bonus cap")
	x.free()
