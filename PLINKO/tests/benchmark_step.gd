extends SceneTree
func _initialize():
	var g=load("res://scripts/main.gd").new()
	g.testing=true
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.current_level=12
	g.start_shift()
	# Persistent high-HP board, eighty live balls replenished before every step.
	for p in g.pegs: p.hp=1000000;p.max=1000000
	g.remaining=100000
	g.spawn_clock=100000
	g.pickup_clock=100000
	var timings=[]
	for tick in range(6600):
		while g.balls.size()<80:
			g.spawn_ball(Vector2(g.rng.randf_range(80,640),g.rng.randf_range(280,800)),"ricochet",Vector2(g.rng.randf_range(-200,200),g.rng.randf_range(-200,200)))
		var start=Time.get_ticks_usec()
		g.step(1.0/60)
		var duration=Time.get_ticks_usec()-start
		if tick>=600: timings.append(duration)
	timings.sort()
	var sum=0.0
	for t in timings: sum+=t
	var results={"samples":timings.size(),"warmup_steps":600,"balls_per_step":80,"pegs":g.pegs.size(),"mean_us":sum/timings.size(),"p50_us":timings[timings.size()/2],"p95_us":timings[int(timings.size()*.95)],"p99_us":timings[int(timings.size()*.99)],"max_us":timings[-1],"scope":"Cloud CPU headless step only; excludes draw/audio/OS/GPU/input and is not device FPS"}
	print(JSON.stringify(results))
	var f=FileAccess.open("res://tests/benchmark_step_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"))
	g.free()
	quit()
