extends SceneTree
var passed=0
var failed=[]
func check(ok,label):
	if ok:passed+=1;print("PASS: ",label)
	else:failed.append(label);print("FAIL: ",label)
func game():
	var g=load("res://scripts/main.gd").new();g.testing=true;g.sound_on=false
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	return g
func _initialize():
	var g=game();g.start_shift()
	check(g.remaining==10,"Fresh run starts at ten seconds")
	check(g.pegs[0].hp==6,"Fresh ordinary peg has six HP")
	for i in range(5):g.damage_peg(g.pegs[0],1)
	check(g.pegs[0].hp==1 and g.destroyed==0,"Five normal hits do not destroy six-HP peg")
	check(g.shift_coins>=5,"Nonlethal damage earns useful credits")
	g.damage_peg(g.pegs[0],1)
	check(g.pegs[0].hp<=0 and g.destroyed==1,"Sixth normal hit destroys peg")
	g.start_shift()
	for i in range(300):g.step(1.0/60)
	g.save_game()
	var restored=game();restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and abs(restored.remaining-g.remaining)<1e-9,"Short-run snapshot restores paused with ten-second timer model")
	check(str(restored.rng.state)==str(g.rng.state),"Short-run snapshot retains exact RNG")
	check(restored.pickup_clock>90,"Single-pickup postspawn timer passes snapshot validation")
	restored.free()
	var saved=JSON.parse_string(FileAccess.get_file_as_string(g.SAVE_FILE))
	saved.active_run.fingerprint=FileAccess.get_file_as_string("res://tests/v04_legacy_fingerprint.txt")
	saved.areas.bakery.bank=123
	var f=FileAccess.open(g.SAVE_FILE,FileAccess.WRITE)
	f.store_string(JSON.stringify(saved));f.close()
	restored=game();restored.load_game()
	check(restored.mode=="home" and restored.bank==123 and restored.snapshot_rejection!="","V03 content fingerprint rejects active run while retaining progression")
	restored.free()
	g.levels[7]=2;g.start_shift()
	check(g.remaining==11,"Two clock upgrades add one second")
	g.add_time(100)
	check(g.time_bonus==3 and g.remaining==14,"Extra time capped at three seconds")
	g.start_shift();g.shift_coins=25;g.remaining=0;g.step(.01)
	var level=g.current_level;g.collect_reward(false)
	check(g.bank==25 and g.current_level==level,"Failed attempt banks earnings and preserves board for free retry")
	g.start_shift()
	check(g.mode=="play" and g.bank==25,"Retry needs no currency or energy")
	g.mode="home";g.highest_unlocked=12
	var trial_results=[]
	for board in [4,8,12]:
		g.begin_trial(board);g.start_shift()
		var elapsed=0.0
		while g.mode=="play" and elapsed<30:
			var next=null
			for p in g.pegs:
				if p.hp>0 and (next==null or p.p.y<next.p.y):next=p
			if next!=null:g.aim_x=next.p.x;g.aim_y=next.p.y
			g.step(1.0/60);elapsed+=1.0/60
		trial_results.append({"board":board,"won":g.level_won,"destroyed":g.destroyed,"total":g.pegs.size(),"seconds":elapsed})
		g.end_trial()
	print("TRIAL_PROBE ",JSON.stringify(trial_results))
	for board in [4,8,12]:
		var t=game();t.highest_unlocked=12;t.mode="home"
		t.begin_trial(board);t.start_shift()
		for i in range(30):t.step(1.0/60)
		t.save_game()
		var resumed=game();resumed.load_game()
		check(resumed.mode=="paused" and resumed.trial_active and resumed.levels==[6,6,2,1,1,1,0,4],"Final fixed trial configuration resumes correctly on board %d" % board)
		t.free();resumed.free()
	print("V04_QA_RESULT passed=",passed," failed=",failed.size())
	g.free();quit(1 if failed.size()>0 else 0)
