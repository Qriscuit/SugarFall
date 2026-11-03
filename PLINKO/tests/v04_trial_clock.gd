extends SceneTree
func game():
	var g=load("res://scripts/main.gd").new()
	g.testing=true; g.sound_on=false
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	return g
func run(g,seed_value):
	g.start_shift(); g.rng.seed=seed_value
	var t=0.0
	var reaction=0.0
	var target=Vector2(360,515)
	while g.mode=="play" and t<120:
		reaction-=1.0/60
		if reaction<=0:
			reaction=.4
			var next=null
			for p in g.pegs:
				if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
			if next!=null: target=next.p
		var pos=Vector2(g.aim_x,g.aim_y).move_toward(target,250.0/60)
		g.aim_x=pos.x;g.aim_y=pos.y
		g.collect_pickups(pos)
		if g.pulse_charge>=.99: g.pulse()
		if g.queued_special=="" and pos.distance_to(target)<20:
			for kind in g.equipped:
				if g.queue_module(kind): break
		g.step(1.0/60);t+=1.0/60
	var hp_remaining=0.0
	for p in g.pegs: hp_remaining+=maxf(0,p.hp)
	return {"board":g.wave,"won":g.level_won,"seconds":t,"credits":g.shift_coins,"destroyed":g.destroyed,"pegs":g.pegs.size(),"hp_remaining":hp_remaining,"levels":g.levels.duplicate()}
func _initialize():
	var results=[]
	for config in [0,1]:
		for board in [4,8,12]:
			for seed_value in range(10):
				var g=game();g.highest_unlocked=12;g.mode="home";g.begin_trial(board)
				g.levels=[4,4,2,1,1,1,0,2] if config==0 else [6,6,2,1,1,1,0,4]
				var row=run(g,7000+seed_value);row.config=config;row.seed=seed_value
				results.append(row);g.free()
	var clock=[]
	for fixture_type in ["fresh","nearclear"]:
		for build in ["none","core","clock15","feed"]:
			for seed_value in range(20):
				var g=game()
				if fixture_type=="nearclear":g.levels=[2,2,1,0,0,0,0,2]
				# Fresh budget40: core40, feed30, clock15+21=36. Near-clear budget120: core78, feed58, clock29+41=70. Residual held.
				if build=="core":g.levels[1]+=1
				elif build=="feed":g.levels[0]+=1
				elif build=="clock15":g.levels[7]+=2
				var row=run(g,8000+seed_value);row.fixture=fixture_type;row.build=build;row.seed=seed_value;row.budget=40 if fixture_type=="fresh" else 120;row.spent=({"none":0,"core":40,"feed":30,"clock15":36} if fixture_type=="fresh" else {"none":0,"core":78,"feed":58,"clock15":70})[build]
				clock.append(row);g.free()
	var f=FileAccess.open("res://tests/v04_trial_clock_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"trials":results,"clock":clock},"\t"));f.close();quit()
