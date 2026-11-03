extends SceneTree
var passed = 0
var failed = []
var save_path = ""

func check(ok, label):
	if ok: passed += 1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)

func fixture():
	var game=load("res://scripts/main.gd").new()
	game.testing=true
	game.sound_on=false
	game.SAVE_FILE=save_path
	game.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	game.start_shift()
	return game

func clear_except(game, keep=-1):
	for i in range(game.pegs.size()):
		if i==keep: continue
		game.damage_peg(game.pegs[i],9999)
		game.special_stats.normal+=1

func run_to_results(game):
	var ticks=0
	while game.mode=="play" and ticks<1800:
		game.step(1.0/60.0)
		ticks+=1
	return ticks

func roundtrip(game):
	check(game.save_game(),"Drain checkpoint writes atomically")
	var restored=fixture()
	restored.load_game()
	return restored

func same_outcome(a,b):
	return a.shift_coins==b.shift_coins and a.total_spawned==b.total_spawned and a.buckets==b.buckets and a.run_elapsed==b.run_elapsed and a.total_shifts==b.total_shifts

func same_values(a,b):
	# JSON decoding normalizes whole-valued timers to floats. Compare their exact
	# numeric values recursively, not Dictionary's stricter Variant-type equality.
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same_values(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not same_values(a[index],b[index]): return false
		return true
	return a==b

func _initialize():
	save_path=OS.get_environment("SUGARFALL_DRAIN_QA_SAVE")
	if save_path.is_empty() or "--drain-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Run with explicit isolated save path and --drain-qa-isolated")
		quit(2); return
	airborne_drain()
	splitter_drain()
	full_population_split()
	settle_resume()
	legacy_and_invalid()
	content_rebalance_migration()
	lifecycle_boundaries()
	automatic_ad_boundary()
	trial_clock()
	print("FINAL_BALL_DRAIN_QA_RESULT passed=",passed," failed=",failed.size())
	quit(1 if not failed.is_empty() else 0)

func airborne_drain():
	var game=fixture()
	for x in [100,360,620]:
		game.spawn_ball(Vector2(x,500),"normal",Vector2(0,200))
		game.balls[-1].life=15.99
	game.remaining=.01
	game.run_elapsed=game.BASE_SECONDS-.01
	clear_except(game)
	var frozen_time=game.run_elapsed
	var frozen_remaining=game.remaining
	var service_before=game.monetization.export_state().duplicate(true)
	var earned=game.shift_coins
	var spawned=game.total_spawned
	check(game.clear_draining and game.level_won and game.mode=="play","Last cookie starts a won drain instead of opening results")
	check(not game.finish_shift(),"Early finish cannot discard airborne rewards")
	game.step(.1)
	check(game.balls.size()==3 and game.total_spawned==spawned,"Clear stops feeder and lets old food survive its normal lifetime limit")
	check(game.mode=="play" and game.remaining==frozen_remaining,"Expiring run timer cannot truncate a winning drain")
	var copy=roundtrip(game)
	check(copy.mode=="paused" and copy.clear_draining and copy.level_won,"Airborne winning checkpoint resumes paused with its clear phase")
	copy.mode="play"
	var ticks=run_to_results(game)
	run_to_results(copy)
	check(ticks<1800 and game.mode=="result" and game.balls.is_empty(),"All remaining food reaches the cups before results")
	var catches=0
	for bucket in game.buckets: catches+=bucket.hits
	check(catches==3 and game.shift_coins>earned,"Every old airborne food pays out exactly once")
	check(game.total_spawned==spawned and game.run_elapsed==frozen_time,"Drain creates no drops and does not inflate trial clear time")
	check(game.monetization.export_state().active_seconds==service_before.active_seconds,"Drain does not advance automatic-ad cooldown time")
	check(game.total_shifts==1 and game.monetization.attempts==1,"Completed attempt is counted once after settlement")
	check(same_outcome(game,copy),"Airborne save and resume yields identical catches and payout")
	var before=game.shift_coins
	game.begin_clear_drain(); game.step(1); game.finish_shift()
	check(game.shift_coins==before and game.total_shifts==1,"Repeated finish and drain calls cannot duplicate bonus or attempt")
	game.collect_reward()
	check(game.mode=="home" and game.bank==before,"Collect returns Home with the fully drained payout")
	game.free(); copy.free()

func splitter_drain():
	var game=fixture()
	var last=game.pegs.size()-1
	clear_except(game,last)
	game.pegs[last].hp=1.0
	game.spawn_clock=.74
	game.spawn_ball(game.pegs[last].p+Vector2(0,-29),"splitter",Vector2(0,200))
	game.step(.001)
	check(game.clear_draining and game.level_won,"Splitter can destroy the final cookie")
	check(game.balls.size()==4 and game.type_drops.shard==3,"Final-hit splitter includes all three pending seeds in the drain")
	var count=game.total_spawned
	run_to_results(game)
	var catches=0
	for bucket in game.buckets: catches+=bucket.hits
	check(game.mode=="result" and catches==4 and game.total_spawned==count,"Parent fruit and all seeds settle without any further feeder drops")
	game.free()

func settle_resume():
	for reduced in [false,true]:
		var game=fixture()
		game.reduced_motion=reduced
		game.spawn_ball(Vector2(360,game.BUCKET_CATCH_Y+1),"normal",Vector2.ZERO)
		clear_except(game)
		game.step(.001)
		var cup=game.settling_bucket
		check(game.balls.is_empty() and game.mode=="play" and is_equal_approx(game.catch_settle_remaining,.32),"Final catch waits for its complete cue, reduced motion=%s"%reduced)
		if reduced: check(game.impact_feedback.bucket_scale(cup,true)==Vector2.ONE,"Reduced motion catches never displace the cup")
		game.step(.12)
		var copy=roundtrip(game)
		check(copy.mode=="paused" and copy.balls.is_empty() and is_equal_approx(copy.catch_settle_remaining,.2),"Empty-board cup settlement resumes with exact remaining time")
		check(is_equal_approx(copy.impact_feedback.bucket_times[cup],copy.catch_settle_remaining),"Resumed cup cue matches the saved settle countdown")
		var timer=copy.catch_settle_remaining
		copy.step(2)
		check(copy.catch_settle_remaining==timer and copy.mode=="paused","Pause freezes catch settlement")
		copy.mode="play"
		game.step(.19); copy.step(.19)
		check(game.mode=="play" and copy.mode=="play","Results remain hidden while final cup is still bouncing")
		game.step(.02); copy.step(.02)
		check(game.mode=="result" and copy.mode=="result" and same_outcome(game,copy),"Results open immediately after final settle in original and restored runs")
		check(game.impact_feedback.bucket_times[cup]==0,"Cup animation finishes before results")
		game.free(); copy.free()

func full_population_split():
	var game=fixture()
	var last=game.pegs.size()-1
	clear_except(game,last)
	game.pegs[last].hp=1.0
	for index in range(79): game.spawn_ball(Vector2(360,800),"normal",Vector2.ZERO)
	game.spawn_ball(game.pegs[last].p+Vector2(0,-29),"splitter",Vector2(0,200))
	game.step(.001)
	check(game.clear_draining and game.balls.size()==83,"A last-hit splitter retains earned seeds at the normal eighty-food cap")
	var checked=game.RunSnapshot.validate_and_decode(game.RunSnapshot.capture(game),game)
	check(checked.ok,"Bounded temporary drain population remains resumable")
	run_to_results(game)
	var catches=0
	for bucket in game.buckets: catches+=bucket.hits
	check(catches==83 and game.mode=="result","Every full-cap food and final seed reaches a cup")
	game.free()

func automatic_ad_boundary():
	var game=fixture()
	game.monetization.active_seconds=120.0
	game.monetization.attempts=3
	game.spawn_ball(Vector2(360,game.BUCKET_CATCH_Y+1),"normal",Vector2.ZERO)
	clear_except(game)
	game.step(.001)
	game.step(.30)
	check(game.mode=="play" and game.monetization.pending.is_empty() and game.monetization.attempts==3,"A ready fourth-attempt ad waits until the last catch settles")
	game.step(.03)
	check(game.mode=="test_ad" and game.monetization.pending.kind=="interstitial" and game.total_shifts==1,"Ready automatic ad opens once after the finished catch")
	var serial=game.monetization.serial
	game.step(1); game.finish_shift()
	check(game.monetization.serial==serial and game.total_shifts==1,"Repeated completion cannot request a duplicate automatic ad")
	game.save_game()
	var copy=fixture(); copy.load_game()
	check(copy.mode=="result" and copy.monetization.pending.is_empty() and copy.monetization.attempts==0,"Restart after the ad boundary restores the result without replaying an ad")
	game.free(); copy.free()

func legacy_and_invalid():
	var game=fixture()
	var snapshot=game.RunSnapshot.capture(game)
	check(snapshot.schema==game.RunSnapshot.LEGACY_AREA_SCHEMA and snapshot.area_id=="bakery","Bakery captures retain their area-bound schema4 checkpoint")
	var legacy=snapshot.duplicate(true)
	legacy.schema=1
	legacy.erase("area_id")
	for key in game.RunSnapshot.DRAIN_FIELDS: legacy.erase(key)
	var decoded=game.RunSnapshot.validate_and_decode(legacy,game)
	check(decoded.ok and not decoded.state.clear_draining,"Schema-one active run migrates without fabricating clear rewards")
	for mutation in ["live_win","timer","cup","claimed","wrong_schema"]:
		var bad=snapshot.duplicate(true)
		match mutation:
			"live_win": bad.clear_draining=true; bad.level_won=true
			"timer": bad.catch_settle_remaining=.33
			"cup": bad.catch_settle_remaining=.1; bad.settling_bucket=-1
			"claimed": bad.shift_claimed=true
			"wrong_schema": bad.schema=999
		check(not game.RunSnapshot.validate_and_decode(bad,game).ok,"Malformed drain state rejected: "+mutation)
	game.free()

func lifecycle_boundaries():
	for event in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_CLOSE_REQUEST,Node.NOTIFICATION_APPLICATION_PAUSED]:
		var game=fixture()
		game.spawn_ball(Vector2(360,700),"normal",Vector2(0,200))
		clear_except(game)
		game.testing=false; game._notification(event); game.testing=true
		var restored=fixture(); restored.load_game()
		check(game.mode=="paused" and restored.mode=="paused" and restored.clear_draining and restored.balls.size()==1,"Lifecycle event preserves won airborne drain: %d"%event)
		check(game.monetization.pending.is_empty() and game.total_shifts==0,"Background checkpoint never counts or opens an automatic ad")
		game.free(); restored.free()
	var game=fixture()
	game.spawn_ball(Vector2(360,700),"normal",Vector2(0,200))
	clear_except(game)
	game.mode="abandon_confirm"
	game._handle_press_impl(Vector2(300,700))
	check(game.mode=="play" and game.clear_draining and game.total_shifts==0,"Abort confirmation finishes the won catch sequence without dropping rewards")
	run_to_results(game)
	game.save_game()
	var copy=fixture(); copy.load_game()
	check(copy.mode=="result" and copy.level_won and copy.shift_coins==game.shift_coins,"Completed drain persists as a pending result")
	copy.collect_reward(); var bank=copy.bank
	copy.save_game(); copy.load_game(); copy.collect_reward()
	check(copy.mode=="home" and copy.bank==bank,"Repeated reload and Collect cannot replay a drained reward")
	game.free(); copy.free()

func content_rebalance_migration():
	var game=fixture()
	for tick in range(30): game.step(1.0/60.0)
	var snapshot=game.RunSnapshot.capture(game)
	check(snapshot.fingerprint==game.RunSnapshot.content_fingerprint() and snapshot.fingerprint!=game.RunSnapshot.PRICE_ONLY_CURRENT_FINGERPRINT,"Current board and Power rebalance has its own content fingerprint")
	for schema in [1,2]:
		var previous=snapshot.duplicate(true)
		previous.fingerprint=game.RunSnapshot.PRICE_ONLY_PREVIOUS_FINGERPRINT
		previous.schema=schema
		previous.erase("area_id")
		if schema==1:
			for key in game.RunSnapshot.DRAIN_FIELDS: previous.erase(key)
		var copy=fixture()
		copy.bank=12345.5; copy.levels=[2,8,1,0,0,0,1,2]
		copy.module_vouchers=2; copy.total_shifts=24
		copy.monetization.attempts=3; copy.monetization.active_seconds=119
		copy.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
		copy.monetization.store_owned=copy.monetization.entitlements.duplicate()
		var campaign=copy.campaign_profile()
		var purchases=copy.monetization.export_state()
		check(not copy.restore_active_run(previous) and copy.mode=="home" and copy.snapshot_rejection.contains("content no longer matches"),"Historical price-only checkpoint cannot resume with rebalanced geometry and Power, schema %d"%schema)
		check(same_values(copy.campaign_profile(),campaign) and same_values(copy.monetization.export_state(),purchases),"Rebalance rejection preserves wallet, owned tiers, vouchers, completed attempts and permanent purchases, schema %d"%schema)
		copy.free()
	check(not game.RunSnapshot.compatible_fingerprint(game.RunSnapshot.PRICE_ONLY_PREVIOUS_FINGERPRINT,"future-content"),"Future content changes cannot accidentally accept the price migration")
	var unknown=snapshot.duplicate(true)
	unknown.fingerprint="other-old-content"
	check(not game.RunSnapshot.validate_and_decode(unknown,game).ok,"Unrecognized earlier content remains rejected")
	game.free()

func trial_clock():
	var game=fixture()
	game.highest_unlocked=4
	game.mode="home"
	game.begin_trial(4); game.start_shift()
	game.run_elapsed=2.0
	game.remaining=game.BASE_SECONDS+game.levels[7]*game.CLOCK_STEP-2.0
	game.spawn_ball(Vector2(360,500),"normal",Vector2(0,0))
	clear_except(game)
	var time=game.run_elapsed
	run_to_results(game)
	check(game.mode=="result" and game.trial_records.get("4")==time,"Trial record measures final cookie break, not the subsequent drain")
	check(game.total_shifts==0 and game.monetization.attempts==0,"Trial drain does not count monetized attempts")
	game.free()
