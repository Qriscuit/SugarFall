extends SceneTree
var passed=0
var failed=[]
var g
func check(ok,label):
	if ok: passed+=1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)
func fixture():
	var x=load("res://scripts/main.gd").new()
	x.testing=true
	x.sound_on=false
	x.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	x.bank=1234
	x.levels=[2,2,1,1,1,1,1,2]
	x.current_level=8
	x.highest_unlocked=9
	x.equipped=["splitter","impact"]
	return x
func restart():
	var x=fixture()
	x.load_game()
	return x
func disk():
	return JSON.parse_string(FileAccess.get_file_as_string(g.SAVE_FILE))
func write_disk(data):
	var f=FileAccess.open(g.SAVE_FILE,FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"",true,true)); f.close()
func equal(a,b):
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for k in a:
			if not b.has(k) or not equal(a[k],b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equal(a[i],b[i]): return false
		return true
	if (a is float or a is int) and (b is float or b is int): return abs(float(a)-float(b))<0.000000001
	return a==b
func state(x):
	var result={}
	for key in ["remaining","run_elapsed","pegs","balls","pickups","buckets","spawn_clock","pickup_clock","aim_x","aim_y","module_cooldowns","queued_special","force_special","pulse_charge","shift_coins","destroyed","combo","combo_timer","max_combo","time_bonus","total_spawned","special_stats","type_drops","levels","equipped","current_level","wave","trial_active","clear_draining","catch_settle_remaining","settling_bucket"]:
		result[key]=x.get(key).duplicate(true) if x.get(key) is Array or x.get(key) is Dictionary else x.get(key)
	result.rng_seed=str(x.rng.seed)
	result.rng_state=str(x.rng.state)
	return result
func advance(x,count):
	for i in range(count):
		x.aim_x=100+fmod(i*2.7,500)
		x.aim_y=500
		if x.mode=="play": x.step(1.0/60)
func _initialize():
	g=fixture()
	migration()
	v03_migration()
	short_shift_snapshots()
	passive_save_migration()
	active_resume()
	lower_bucket_resume()
	fractional_rewards_resume()
	corruption()
	edge_states()
	boundaries()
	trials()
	motion_abandon()
	trial_result_counts()
	navigation_guard()
	transition_guard()
	write_failure()
	rng_boundaries()
	snapshot_matrix()
	print("RESUME_QA_RESULT passed=",passed," failed=",failed.size())
	g.free()
	quit(1 if failed.size()>0 else 0)
func migration():
	write_disk({"version":1,"bank":876,"levels":[1,2,1,1,0,0,2,3],"current_level":4,"highest_unlocked":6,"equipped":["ricochet"],"module_milestones":[2],"total_shifts":8})
	var x=restart()
	check(x.bank==876 and x.current_level==4 and x.highest_unlocked==6 and x.levels[1]==2,"Version-one progression migrates without active run")
	check(x.mode=="home" and not x.resumed_run,"Legacy progression does not invent resumed run")
	x.save_game()
	check(disk().version==x.PROFILE_VERSION and disk().balance_revision==4,"Next save upgrades to the current area profile version with balance revision four")
	x.free()
func active_resume():
	g.start_shift()
	advance(g,180)
	g.pickups=[{"p":Vector2(400,500),"life":2.5}]
	var before=state(g)
	g.save_game()
	var x=restart()
	check(x.mode=="paused" and x.resumed_run,"Active run restarts paused")
	check(equal(before,state(x)),"Active physics state and exact RNG survive JSON roundtrip")
	check(x.bank==1234 and x.highest_unlocked==9,"Active resume preserves campaign progression")
	x.mode="play"
	advance(g,300); advance(x,300)
	check(equal(state(g),state(x)),"Resumed continuation matches uninterrupted three-hundred-step simulation")
	x.free()
	g.testing=false
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	g.testing=true
	x=restart()
	check(g.mode=="paused" and x.mode=="paused" and equal(state(g),state(x)),"Focus notification pauses and persists same run")
	x.free()
func fractional_catch(x,kind="normal"):
	x.mode="play"
	x.spawn_clock=.74
	x.spawn_ball(Vector2(360,x.BUCKET_CATCH_Y+1),kind,Vector2.ZERO)
	x.balls[-1].productive=true
	x.step(.001)

func lower_bucket_resume():
	var a=fixture()
	a.levels=[0,0,0,0,0,0,0,0]
	a.equipped=[]
	a.total_shifts=0
	a.start_shift()
	a.spawn_clock=1.0
	a.spawn_ball(Vector2(360,950),"normal",Vector2(0,200))
	a.balls[-1].productive=true
	var before=state(a)
	a.save_game()
	var b=restart()
	check(b.mode=="paused" and b.resumed_run and equal(before,state(b)),"Food in the extended lower flight area survives an active checkpoint exactly")
	b.mode="play"
	var steps=0
	while a.buckets[2].hits==0 and steps<120:
		a.step(.01)
		b.step(.01)
		steps+=1
	check(a.buckets[2].hits==1 and a.balls.is_empty() and is_equal_approx(a.shift_coins,1.1),"Food saved below the former catch line continues down into the lowered cup")
	check(equal(state(a),state(b)),"The first lower cup catch after resume matches uninterrupted physics and exact earnings")
	a.free()
	b.free()

func fractional_rewards_resume():
	var a=fixture()
	a.levels=[0,0,0,0,0,0,0,0]
	var initial_bank=a.upgrade_cost(0)+.35
	a.bank=initial_bank
	a.equipped=[]
	a.start_shift()
	fractional_catch(a,"shard")
	fractional_catch(a)
	var before=state(a)
	a.save_game()
	var saved=disk()
	check(is_equal_approx(saved.areas.bakery.bank,initial_bank) and is_equal_approx(saved.active_run.shift_coins,1.75),"Active checkpoint writes fractional wallet and earned credits without truncation")
	var b=restart()
	check(b.mode=="paused" and equal(before,state(b)) and is_equal_approx(b.bank,initial_bank),"Active resume restores exact cents together with bucket growth and live state")
	fractional_catch(a)
	fractional_catch(b)
	check(equal(state(a),state(b)) and is_equal_approx(b.shift_coins,3.05) and is_equal_approx(b.bucket_reward(2),1.3),"First catch after resume continues the multiplier and fractional earnings exactly")
	b.finish_shift()
	b.save_game()
	saved=disk()
	check(is_equal_approx(saved.pending_result.coins,3.05),"Pending result stores the full fractional reward")
	b.free()
	b=restart()
	check(b.mode=="result" and not b.shift_claimed and is_equal_approx(b.shift_coins,3.05) and is_equal_approx(b.bank,initial_bank),"Restart restores an unclaimed fractional result and existing wallet independently")
	b.collect_reward(false)
	check(b.shift_claimed and is_equal_approx(b.bank,initial_bank+3.05),"Collect adds fractional earnings to the wallet exactly once")
	b.collect_reward(true)
	check(is_equal_approx(b.bank,initial_bank+3.05),"A repeated bonus claim cannot duplicate a previously collected fractional reward")
	check(b.buy_upgrade(0) and b.levels[0]==1 and is_equal_approx(b.bank,3.4),"Buying an upgrade at its current price retains the wallet's fractional remainder")
	b.save_game()
	b.free()
	b=restart()
	b.collect_reward(true)
	check(b.mode!="result" and b.levels[0]==1 and is_equal_approx(b.bank,3.4),"Purchased upgrade and fractional wallet survive restart without restoring a claimed reward")
	b.mode="home"
	var campaign=b.campaign_profile().duplicate(true)
	b.begin_trial(4)
	b.start_shift()
	b.end_trial()
	check(equal(b.campaign_profile(),campaign) and is_equal_approx(b.bank,3.4),"Trial profile swapping preserves the campaign wallet's fractional remainder")
	# Released checkpoints used integer earnings. They remain valid under the
	# wider numeric representation even when the wallet now contains cents.
	saved.active_run=a.RunSnapshot.capture(a)
	# This synthetic checkpoint uses today's physics even though its earnings
	# use the older integer representation. Keep its matching rules envelope.
	saved.active_run_rules=a.run_rules_revision
	saved.erase("pending_result")
	saved.active_run.shift_coins=17
	write_disk(saved)
	b.free()
	b=restart()
	check(b.mode=="paused" and b.shift_coins==17 and is_equal_approx(b.bank,initial_bank),"Legacy integer active earnings still restore alongside a fractional wallet")
	a.free()
	b.free()

func corruption():
	g.start_shift(); advance(g,30); g.save_game()
	var valid=disk()
	var bad=valid.duplicate(true)
	bad.active_run.schema=999
	write_disk(bad)
	var x=restart()
	check(x.mode=="home" and not x.resumed_run and x.bank==1234 and x.snapshot_rejection!="","Incompatible snapshot rejected while retaining workshop")
	x.free()
	bad=valid.duplicate(true)
	bad.active_run.remaining=-99
	write_disk(bad); x=restart()
	check(x.mode=="home" and x.bank==1234,"Negative timer snapshot rejected without progression loss")
	x.free()
	bad=valid.duplicate(true)
	while bad.active_run.balls.size()<81: bad.active_run.balls.append({})
	write_disk(bad); x=restart()
	check(x.mode=="home" and x.bank==1234,"Oversized ball snapshot rejected without progression loss")
	x.free()
	bad=valid.duplicate(true)
	bad.active_run.rng_state="not-a-state"
	write_disk(bad); x=restart()
	check(x.mode=="home" and x.bank==1234,"Malformed RNG snapshot rejected")
	x.free()
func boundaries():
	g.start_shift(); g.remaining=0
	g.testing=false; g.save_game(); g.testing=true
	var x=restart()
	check(x.mode=="result" and not x.level_won,"Expiry checkpoint restores completed timeout rather than dead run")
	x.free()
	g.start_shift()
	for peg in g.pegs: g.damage_peg(peg,9999)
	g.testing=false; g.save_game(); g.testing=true
	x=restart()
	check(x.mode=="result" and x.level_won,"Last-peg checkpoint commits winning pending result")
	var earned=x.shift_coins
	var money=x.bank
	x.collect_reward(false)
	var claimed_total=x.bank
	x.save_game(); x.free()
	x=restart()
	check(x.bank==claimed_total and x.mode!="result","Claimed result cannot reappear after restart")
	x.collect_reward(true)
	check(x.bank==claimed_total,"Repeated restored claim cannot duplicate reward")
	x.free()
	g.start_shift(); g.shift_coins=101; g.finish_shift(); g.mode="bonus_confirm"; g.save_game()
	x=restart()
	check(x.mode=="result" and x.shift_coins==101 and not x.shift_claimed,"Interrupted bonus confirmation restores base result without automatic bonus")
	x.free()
func trials():
	g.mode="home"
	var campaign=g.campaign_profile().duplicate(true)
	g.begin_trial(12); g.start_shift(); advance(g,120); g.save_game()
	var before=state(g)
	var x=restart()
	check(x.mode=="paused" and x.trial_active and equal(before,state(x)),"Interrupted trial restores fixed-loadout live state")
	x.end_trial()
	check(equal(x.campaign_profile(),campaign),"Exiting resumed trial restores exact campaign snapshot")
	x.free()
	var old_profile=disk()
	old_profile.active_run.levels=[2,2,1,1,1,1,0,0]
	old_profile.active_run.remaining-=2.0 # Keep clock arithmetic consistent with the removed clock upgrades.
	write_disk(old_profile); x=restart()
	check(x.mode=="home" and x.snapshot_rejection.contains("trial configuration") and equal(x.campaign_profile(),campaign),"Obsolete fixed trial profile is rejected without changing the saved workshop")
	x.free()
	g.mode="play"; g.level_won=true; g.run_elapsed=7.5; g.finish_shift(); g.save_game()
	x=restart()
	check(x.mode=="result" and x.trial_active and x.run_elapsed==7.5 and x.levels==[6,6,2,1,1,1,0,4],"Completed trial pending result survives restart as trial")
	x.collect_reward(true)
	check(equal(x.campaign_profile(),campaign),"Restored trial result cannot grant campaign credits or progression")
	x.free(); g.end_trial()
func motion_abandon():
	var a=fixture(); var b=fixture()
	a.start_shift(); b.start_shift()
	b.reduced_motion=true
	advance(a,900); advance(b,900)
	check(equal(state(a),state(b)),"Reduced motion changes no physics or RNG after nine-hundred steps")
	check(b.particles.is_empty() and b.floats.is_empty(),"Reduced motion suppresses particles and floating text")
	# Nine hundred steps can now reach the shorter run's legitimate result.
	# Do not relabel an expired result as a live pause merely to test preference saving.
	b.start_shift(); advance(b,120)
	b.mode="paused"; b.save_game()
	var x=restart()
	check(x.reduced_motion,"Reduced-motion preference persists")
	x.free(); a.free(); b.free()
	g.start_shift(); g.mode="paused"
	g.handle_press(g.pause_menu_layout().actions.end_shift.get_center())
	check(g.mode=="abandon_confirm","Ending shift requires deliberate confirmation")
	g._process(.26)
	g.handle_press(Vector2(300,820))
	check(g.mode=="paused" and not g.shift_claimed,"Abandon cancel preserves paused run")
	g._process(.26); g.handle_press(g.pause_menu_layout().actions.end_shift.get_center()); g._process(.26); g.handle_press(Vector2(300,690))
	check(g.mode=="result" and not g.level_won,"Confirmed abandon ends run without level win")

func edge_states():
	g.start_shift(); advance(g,30)
	g.mode="abandon_confirm"
	var before=state(g)
	g.save_game()
	var x=restart()
	check(x.mode=="paused" and equal(before,state(x)),"Restart during abandon confirmation preserves paused run")
	x.free()
	for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		g.testing=false
		g._notification(notification)
		g.testing=true
		x=restart()
		check(x.mode=="paused" and equal(before,state(x)),"Lifecycle notification during abandon modal preserves run: %d" % notification)
		x.free()
	g.mode="play"
	g.pickups=[{"p":Vector2(400,500),"life":0.0}]
	g.save_game(); x=restart()
	check(x.mode=="paused" and x.pickups.size()==1 and x.pickups[0].life==0,"Just-collected zero-life pickup survives without duplicated time")
	x.free()
	var good=disk()
	for mutation in ["fingerprint","rng_number","nan","peg_position","pickup_count","claimed","pending_overrides"]:
		var bad=good.duplicate(true)
		match mutation:
			"fingerprint": bad.active_run.fingerprint="different"
			"rng_number": bad.active_run.rng_state=123
			"nan": bad.active_run.remaining="NaN"
			"peg_position": bad.active_run.pegs[0].p=[400,400]
			"pickup_count":
				while bad.active_run.pickups.size()<33: bad.active_run.pickups.append({"p":[100,400],"life":2})
			"claimed": bad.last_claimed_run_id=bad.active_run.run_id
			"pending_overrides": bad.pending_result={"area_id":"bakery","coins":25,"won":false,"wave":8,"run_id":"pending-priority","trial":false}
		write_disk(bad); x=restart()
		if mutation=="pending_overrides": check(x.mode=="result" and x.shift_coins==25 and not x.resumed_run,"Pending result takes precedence over active snapshot")
		else: check(x.mode=="home" and x.bank==1234,"Reject malformed or stale snapshot: "+mutation)
		x.free()

func snapshot_matrix():
	var checks=0
	var all_valid=true
	var all_deterministic=true
	for board in [1,4,8,12]:
		for build in [0,1]:
			for seed_value in range(3):
				var a=fixture()
				a.current_level=board
				a.highest_unlocked=12
				a.levels=[0,0,0,0,0,0,0,0] if build==0 else [10,10,6,6,6,6,8,10]
				a.equipped=[] if build==0 else ["splitter","impact"]
				a.start_shift()
				a.rng.seed=800+seed_value
				for block in range(5):
					if a.mode!="play": break
					advance(a,120)
					if a.mode!="play": break
					a.save_game()
					var b=restart()
					checks+=1
					if b.mode!="paused" or not equal(state(a),state(b)):
						all_valid=false
						print("MATRIX REJECT board=",board," build=",build," seed=",seed_value," reason=",b.snapshot_rejection)
					else:
						b.mode="play"
						advance(a,60);advance(b,60)
						if not equal(state(a),state(b)): all_deterministic=false
					b.free()
				a.free()
	print("MATRIX_SNAPSHOTS ",checks)
	check(all_valid,"Cross-board base/max-upgrade checkpoint matrix restores every valid live state")
	check(all_deterministic,"Cross-board checkpoint matrix preserves deterministic continued physics")

func rng_boundaries():
	for value in ["9223372036854775807","-9223372036854775808","9007199254740993","-9007199254740993"]:
		g=replace_fixture(g)
		g.start_shift()
		g.rng.seed=int(value)
		g.rng.state=int(value)
		var expected_seed=str(g.rng.seed)
		var expected_state=str(g.rng.state)
		g.save_game()
		var saved=disk()
		var x=restart()
		check(saved.active_run.rng_seed is String and saved.active_run.rng_state is String and str(x.rng.seed)==expected_seed and str(x.rng.state)==expected_state,"Signed-64 RNG string roundtrip "+value)
		var matches=true
		for n in range(20): matches=matches and g.rng.randi()==x.rng.randi()
		check(matches,"Exact next twenty RNG outputs after restoring "+value)
		x.free()
	g.start_shift();g.save_game()
	var valid=disk()
	for value in ["9223372036854775808","-9223372036854775809","1e10","+12","12.5","","0001"]:
		var bad=valid.duplicate(true)
		bad.active_run.rng_state=value
		write_disk(bad)
		var x=restart()
		check(x.mode=="home" and x.bank==1234,"Malformed or overflow RNG string rejected: "+value)
		x.free()
func replace_fixture(old):
	old.free()
	return fixture()

func write_failure():
	g.mode="home"
	g.bank=1234
	g.save_game()
	var previous=FileAccess.get_file_as_bytes(g.SAVE_FILE)
	var temp_path=ProjectSettings.globalize_path(g.SAVE_FILE+".tmp")
	var status=DirAccess.make_dir_absolute(temp_path)
	check(status==OK,"Controlled temporary-path directory collision created in isolated QA storage")
	g.bank=5678
	g.note=""
	g.save_game()
	check(FileAccess.get_file_as_bytes(g.SAVE_FILE)==previous,"Failed temporary save write preserves previous save byte-for-byte")
	check(g.note.contains("Save unavailable"),"Failed save gives visible unavailable warning")
	check(DirAccess.remove_absolute(temp_path)==OK,"Temporary test collision cleaned up")
	g.bank=1234

func transition_guard():
	var x=fixture()
	x.bank=100000
	x.current_level=1
	x.start_shift(); x.shift_coins=100; x.finish_shift()
	x.result_input_delay=0
	x.handle_press(Vector2(300,840))
	var money=x.bank
	var level=x.levels[6]
	x.upgrade_map.selected=6
	x.upgrade_map.tier=level+1
	x.handle_press(Vector2(300,840))
	x.handle_press(Vector2(546,952))
	check(x.mode=="home" and x.bank==money and x.levels[6]==level,"Rapid Collect cannot tap through the Home tray or buy an upgrade during the transition guard")
	x._process(.41)
	x.handle_press(x.home_menu.UPGRADES_RECT.get_center())
	x._process(.41)
	x.handle_press(Vector2(546,952))
	check(x.mode=="shop" and x.levels[6]==level+1 and x.bank<money,"Opening Upgrades from Home still permits a deliberate purchase")
	x.current_level=2
	x.levels=[0,0,0,0,0,0,0,0]
	x.equipped=[]
	x.module_milestones=[]
	x.start_shift(); x.level_won=true; x.finish_shift()
	x.result_input_delay=0
	x.handle_press(Vector2(300,840))
	var vouchers=x.module_vouchers
	x.handle_press(Vector2(300,840))
	check(x.mode=="home" and x.module_vouchers==vouchers and x.levels[5]==0,"Milestone Collect returns Home and repeated taps cannot spend the treat voucher")
	x._process(.41)
	x.handle_press(x.home_menu.UPGRADES_RECT.get_center())
	x._process(.41)
	x.handle_press(x.upgrade_map.TREATS_RECT.get_center())
	x._process(.41)
	x.handle_press(Vector2(300,840))
	check(x.mode=="loadout" and x.levels[5]==0 and x.module_vouchers==vouchers,"Treats cannot spend a saved milestone voucher before the ingredient is connected")
	var connected=true
	for family in [0,2,1]: connected=x.buy_upgrade(family) and connected
	check(connected,"Milestone fixture connects Impact through the same authoritative upgrade purchases")
	x.handle_press(Vector2(300,840))
	check(x.mode=="loadout" and x.levels[5]==1 and x.module_vouchers==vouchers-1,"The saved milestone voucher can be claimed deliberately through Treats once connected")
	x.mode="home"
	x.highest_unlocked=4
	x.begin_trial(4); x.start_shift(); x.finish_shift()
	x.collect_reward(false)
	x.handle_press(Vector2(300,840))
	check(x.mode=="trials" and not x.trial_active,"Immediate trial-return click cannot start underlying new trial")
	x._process(.41)
	x.handle_press(Vector2(300,840))
	check(x.trial_active and x.current_level==12,"Deliberate trial selection works after transition delay")
	x.free()

func navigation_guard():
	var x=fixture()
	x.mode="guide"
	x.go_back()
	check(x.mode=="home","Deliberate Back returns menu to home")
	x.handle_press(x.home_menu.PLAY_RECT.get_center())
	check(x.mode=="home","Back-to-home transition blocks accidental Start click-through")
	x._process(.26)
	x.handle_press(x.home_menu.PLAY_RECT.get_center())
	check(x.mode=="play","Deliberate Start works after navigation guard")
	var key=InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_ESCAPE
	x._input(key)
	check(x.mode=="paused" and not x.run_transition.active,"Immediate Escape during Home entry settles the board and pauses")
	x._input(key)
	check(x.mode=="paused","Repeated Escape cannot immediately undo the entry pause")
	x._process(.26)
	x._input(key)
	x._input(key)
	check(x.mode=="play","Repeated Escape cannot immediately undo resume")
	x._process(.26)
	x._input(key)
	check(x.mode=="paused","A deliberate later Escape pauses active gameplay")
	x._process(.26)
	key.echo=true
	x._input(key)
	check(x.mode=="paused","Echoed Escape does not toggle pause")
	key.echo=false
	x._input(key)
	x.pulse_charge=1
	key.keycode=KEY_SPACE
	x._input(key)
	check(x.pulse_charge==1,"Space during navigation guard cannot activate pulse")
	x._process(.26)
	key.echo=true
	x._input(key)
	check(x.pulse_charge==1,"Echoed Space cannot activate pulse")
	key.echo=false
	x._input(key)
	check(x.pulse_charge==1,"Deliberate Space remains inert after navigation guard")
	key.keycode=KEY_ENTER
	var mode_before=x.mode
	x._input(key); x._input(key)
	check(x.mode==mode_before,"Enter has no unintended repeated navigation action")
	x.mode="loadout"
	x.module_vouchers=1
	x.levels[5]=0
	x.equipped=[]
	x.navigation_delay=0
	x.result_input_delay=0
	x.handle_press(Vector2(300,840))
	x.handle_press(Vector2(300,840))
	check(x.levels[5]==1 and "impact" in x.equipped and x.module_vouchers==0,"Double tap free module claim cannot immediately unequip it")
	x._process(.26)
	x.handle_press(Vector2(300,840))
	check("impact" not in x.equipped,"Deliberate module toggle works after claim guard")
	x._process(.26)
	x.mode="shop"
	x.bank=100000
	x.levels[0]=0
	x.upgrade_map.selected=0
	x.upgrade_map.tier=x.levels[0]+1
	x.handle_press(Vector2(546,952))
	# The map intentionally leaves the purchased node selected. A deliberate
	# next-tier purchase selects the next node rather than double-tapping Buy.
	x.upgrade_map.tier=x.levels[0]+1
	x.handle_press(Vector2(546,952))
	check(x.levels[0]==2,"Same-screen deliberate next-tier map purchases remain undelayed")
	x.free()

func trial_result_counts():
	for board in [4,8,12]:
		var a=fixture()
		a.mode="home"
		a.begin_trial(board)
		a.start_shift()
		var expected={4:18,8:26,12:34}[board]
		var broken=expected-1
		a.destroyed=broken
		a.finish_shift()
		a.save_game()
		var b=restart()
		check(b.mode=="result" and b.trial_active and b.pegs.is_empty() and b.destroyed==broken and b.board_peg_count(b.wave)==expected and b.result_peg_total==expected,"Restored trial result board %d uses authored total without live pegs" % board)
		a.free(); b.free()

func v03_migration():
	# Stable released v0.3 board/economy fingerprint, embedded so this test never
	# reads another project or depends on an absolute previous-build path.
	const V03_FINGERPRINT="a88a3da9476285561653461a75683f1b03e846d59e0cf88657dcb42cb7eccb19"
	var legacy=fixture()
	legacy.bank=4321
	legacy.levels=[3,4,2,1,1,0,3,4]
	legacy.current_level=6
	legacy.highest_unlocked=10
	legacy.equipped=["ricochet","splitter"]
	legacy.force_special="ricochet"
	legacy.best_wave=10
	legacy.total_shifts=41
	legacy.module_milestones=[2,5,8]
	legacy.module_vouchers=2
	var profile=legacy.campaign_profile().duplicate(true)
	var data=profile.duplicate(true)
	profile.force_special="" # Retired forced shots are discarded, progression stays.
	data.merge({"version":2,"sound":false,"reduced_motion":true,"trial_records":{"4":23.5},"run_serial":9,"last_claimed_run_id":"8:1"},true)
	write_disk(data)
	var x=restart()
	check(equal(x.campaign_profile(),profile) and x.mode=="home","Existing v0.3 version-two workshop progress survives the new balance unchanged")
	check(not x.sound_on and x.reduced_motion and x.trial_records.is_empty(),"Existing preferences survive while incompatible v0.3 trial records reset")
	x.free()
	legacy.start_shift()
	data.active_run=legacy.RunSnapshot.capture(legacy)
	data.active_run.fingerprint=V03_FINGERPRINT
	write_disk(data)
	x=restart()
	check(x.mode=="home" and not x.resumed_run and x.snapshot_rejection.contains("content no longer matches"),"Known v0.3 active-run fingerprint is explicitly rejected after rebalance")
	check(equal(x.campaign_profile(),profile) and x.bank==4321,"Rejecting a v0.3 active checkpoint does not discard its saved workshop progression")
	x.free()
	# Old pending rewards are already earned, unlike an incompatible active run.
	# Their result denominator must describe the original board, not its rebalance.
	data.erase("active_run")
	data.pending_result={"coins":123,"won":false,"wave":6,"destroyed":11,"combo":3,"run_id":"legacy-earned-campaign","trial":false}
	write_disk(data); x=restart()
	check(x.mode=="result" and x.shift_coins==123 and x.result_peg_total==34,"Legacy pending campaign reward retains earned coins and its old board denominator")
	x.collect_reward(false)
	check(x.bank==4444 and x.current_level==6 and x.shift_claimed,"Legacy pending campaign reward pays exactly once without unintended progression")
	x.save_game(); x.free(); x=restart()
	x.collect_reward(true)
	check(x.bank==4444 and x.mode!="result","Legacy earned reward cannot be reclaimed after migration and restart")
	x.free()
	data.pending_result={"coins":99999,"won":false,"wave":8,"destroyed":21,"combo":3,"run_id":"legacy-earned-trial","trial":true,"run_elapsed":23.5,"equipped":["ricochet","splitter"]}
	write_disk(data); x=restart()
	check(x.mode=="result" and x.trial_active and x.result_peg_total==38 and x.destroyed==21,"Legacy pending trial retains its original thirty-eight-peg denominator")
	x.collect_reward(true)
	check(equal(x.campaign_profile(),profile) and x.trial_records.is_empty(),"Legacy trial result returns to unchanged workshop without granting trial credits or retaining obsolete records")
	x.free(); legacy.free()

func passive_save_migration():
	var a=fixture()
	a.start_shift()
	advance(a,90)
	a.spawn_ball(Vector2(360,275),"impact")
	a.save_game()
	var original=state(a)
	var old=disk()
	old.force_special="impact"
	old.active_run.force_special="splitter"
	old.active_run.queued_special="impact"
	old.active_run.pulse_charge=1.0
	old.active_run.module_cooldowns.splitter=8.0
	old.active_run.balls[-1].r=9.0
	var contacted=old.active_run.duplicate(true)
	contacted.balls[-1].productive=true
	var decoded=a.RunSnapshot.validate_and_decode(contacted,a)
	check(decoded.ok and decoded.state.balls[-1].used,"Legacy impact that already hit a peg resumes with its one-time crush spent")
	write_disk(old)
	var b=restart()
	check(b.mode=="paused" and b.resumed_run and equal(original,state(b)),"Legacy queued specials, forced drop, pulse charge and cooldown migrate away while physics, credits and RNG stay exact")
	check(b.balls[-1].kind=="impact" and b.balls[-1].r==11.25,"Legacy impact ball radius upgrades to the current pumpkin size")
	b.mode="play"
	advance(a,180); advance(b,180)
	check(equal(state(a),state(b)),"Migrated legacy controls cannot force a special during resumed continuation")
	b.save_game()
	var saved=disk()
	check(not saved.has("force_special") and saved.active_run.force_special=="" and saved.active_run.queued_special=="" and saved.active_run.pulse_charge==0,"Next checkpoint persists only inactive compatibility controls")
	a.free(); b.free()

func short_shift_snapshots():
	var a=fixture()
	a.levels[7]=10
	a.start_shift()
	check(a.remaining==15.0,"Maximum clock upgrades start a fifteen-second v0.4 run")
	advance(a,246)
	check(a.mode=="play" and a.pickups.size()==1 and a.pickup_clock>99 and a.pickup_clock<=100,"Four-second free pickup enters the long one-pickup cooldown")
	a.save_game()
	var b=restart()
	check(b.mode=="paused" and equal(state(a),state(b)),"Checkpoint after free-pickup spawn preserves the near-one-hundred-second cooldown")
	b.free()
	a.add_time(999)
	a.save_game()
	var valid=disk()
	b=restart()
	check(a.time_bonus==3.0 and b.mode=="paused" and equal(state(a),state(b)),"Checkpoint at the three-second bonus cap restores every live field")
	b.free()
	var bad=valid.duplicate(true)
	bad.active_run.time_bonus+=0.5
	bad.active_run.remaining+=0.5
	write_disk(bad); b=restart()
	check(b.mode=="home" and b.bank==1234,"Reject bonus time above the v0.4 cap even when total-clock arithmetic is consistent")
	b.free()
	bad=valid.duplicate(true)
	bad.active_run.pickup_clock=100.5
	write_disk(bad); b=restart()
	check(b.mode=="home" and b.bank==1234,"Reject a free-pickup cooldown beyond the supported one-hundred-second bound")
	b.free()
	bad=valid.duplicate(true)
	bad.active_run.remaining=60.0
	write_disk(bad); b=restart()
	check(b.mode=="home" and b.bank==1234,"Reject obsolete sixty-second timing even under the current fingerprint")
	b.free()
	while a.mode=="play" and a.remaining>.25: a.step(1.0/60.0)
	a.save_game(); b=restart()
	check(a.mode=="play" and b.mode=="paused" and a.remaining>0 and a.remaining<.5 and equal(state(a),state(b)),"Final-quarter-second checkpoint remains resumable in the shorter run")
	a.free(); b.free()
