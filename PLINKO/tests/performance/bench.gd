extends SceneTree
var results=[]
func game():
	var g=load("res://scripts/main.gd").new();g.testing=true;g.sound_on=false
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.current_level=12;g.start_shift();g.rng.seed=1987
	return g
func summary(label,times,extra={}):
	times.sort();var sum=0.0
	for t in times:sum+=t
	var row={"scenario":label,"samples":times.size(),"p50_us":times[int(times.size()*.5)],"p95_us":times[int(times.size()*.95)],"max_us":times[-1],"mean_us":sum/times.size()}
	row.merge(extra);results.append(row);print(JSON.stringify(row))
func fixture(label,count,contact,dead_pegs=false,reduced=false,kind="normal",visuals=0):
	var g=game();g.reduced_motion=reduced;g.balls=[];g.spawn_clock=100
	for i in range(count):
		g.spawn_ball(g.pegs[i%g.pegs.size()].p+Vector2(0,-29) if contact else Vector2(80+(i%10)*55,280+(i/10)*3),kind,Vector2(0,100))
	for p in g.pegs:p.hp=0 if dead_pegs else 100000;p.max=100000
	if dead_pegs:g.pegs[0].hp=100000
	for i in range(visuals):g.particles.append({"p":Vector2(300,400),"v":Vector2(10,20),"life":1.0})
	var initial_balls=g.balls.duplicate(true);var initial_pegs=g.pegs.duplicate(true);var initial_particles=g.particles.duplicate(true)
	var times=[];var peak_balls=0;var peak_particles=0
	for i in range(2200):
		g.balls=initial_balls.duplicate(true)
		for j in range(g.pegs.size()):
			g.pegs[j].hp=initial_pegs[j].hp;g.pegs[j].flash=initial_pegs[j].flash
		g.particles=initial_particles.duplicate(true);g.floats=[];g.pickups=[];g.remaining=10;g.spawn_clock=100;g.pickup_clock=100;g.mode="play"
		var start=Time.get_ticks_usec();g.step(1.0/60);var elapsed=Time.get_ticks_usec()-start
		if i>=200:times.append(elapsed)
		peak_balls=maxi(peak_balls,g.balls.size());peak_particles=maxi(peak_particles,g.particles.size())
	summary(label,times,{"input_balls":count,"pegs":g.pegs.size(),"output_balls_max":peak_balls,"particles_max":peak_particles,"fixture_setup_excluded":true});g.free()
func natural():
	var g=game();var times=[];var maxballs=0;var maxparticles=0;var totalballs=0
	for run in range(40):
		g.current_level=1 if run<20 else 12;g.levels=[0,0,0,0,0,0,0,0] if run<20 else [6,4,2,1,1,1,0,4];g.equipped=["splitter","impact"];g.start_shift();g.rng.seed=run+934
		while g.mode=="play":
			var start=Time.get_ticks_usec();g.step(1.0/60);times.append(Time.get_ticks_usec()-start)
			maxballs=maxi(maxballs,g.balls.size());maxparticles=maxi(maxparticles,g.particles.size());totalballs+=g.balls.size()
	summary("natural_40_runs_fixed_center_no_pulse",times,{"max_balls":maxballs,"mean_balls":float(totalballs)/times.size(),"max_particles":maxparticles});g.free()
func _initialize():
	natural()
	fixture("normal_8_balls_34_live_no_contact",8,false)
	fixture("max_80_balls_34_live_no_contact",80,false)
	fixture("max_80_balls_1_live_33_dead",80,false,true)
	fixture("max_80_normal_contact",80,true)
	fixture("splitter20_contact_fanout_to80",20,true,false,false,"splitter")
	fixture("splitter80_contact_cap80",80,true,false,false,"splitter")
	fixture("max_80_contact_plus240_particles",80,true,false,false,"normal",240)
	var dest=OS.get_environment("BENCH_OUTPUT")
	if dest!="":var f=FileAccess.open(dest,FileAccess.WRITE);f.store_string(JSON.stringify({"engine":Engine.get_version_info(),"results":results},"\t"));f.close()
	quit()
