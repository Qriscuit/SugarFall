extends SceneTree
## AF-006: real fixed-tick scheduling, capped populations and final-split settlement.
## Oversized direct calls are diagnostic only; a slow rendered frame is not a large physics tick.
var passed=0
var failures: Array[String]=[]
var scenarios: Array=[]
var profile_calls=0

class Fixture extends "res://scripts/main.gd":
	var profile_io=0
	func _ready(): pass
	func _process(_delta): pass
	func _draw(): pass
	func load_game(): profile_io+=1
	func save_game(): profile_io+=1; return false
	func write_profile_file(_data: Dictionary) -> bool: profile_io+=1; return false
	func random_ball(): return "normal"

func check(value: bool,label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture(area: String,twins: bool=false):
	var g=Fixture.new()
	g.testing=true; g.sound_on=false
	g.first_run_guide.completed=true; g.first_run_guide.active=false
	g.set_active_area(area); g.highest_unlocked=12
	g.twin_launchers=twins; g.power_reset_tier=6 if twins else 0
	g.start_shift(); g.spawn_clock=100; g.pickup_clock=100
	return g

func close(g,label: String):
	profile_calls+=g.profile_io
	check(g.profile_io==0,"No profile access: "+label)
	g.free()

func peg(hp: float=1000.0,pos: Vector2=Vector2(360,500)) -> Dictionary:
	return {"p":pos,"hp":hp,"max":hp,"kind":"normal","flash":0.0}

func ball(g,pos: Vector2,velocity: Vector2,kind: String="normal") -> Dictionary:
	g.spawn_ball(pos,kind,velocity,false)
	return g.balls[-1]

func finite_population(g) -> bool:
	for b in g.balls:
		if not b.p.is_finite() or not b.v.is_finite() or not is_finite(b.life) or b.life<0: return false
		if b.p.x<54-.01 or b.p.x>666+.01 or b.p.y<260-.01: return false
	return is_finite(g.shift_coins) and g.shift_coins>=0

func contacts():
	for area in ["bakery","gelato"]:
		for kind in ["normal","ricochet","splitter","impact","shard"]:
			var g=fixture(area)
			g.pegs=[peg()]
			var b=ball(g,Vector2(360,455),Vector2(0,610),kind)
			for _tick in range(4): g.step(1.0/60.0)
			check(g.pegs[0].hp<1000,"610px/s contact cannot skip a peg at production60Hz: %s/%s"%[area,kind])
			check(b.productive and b.used and b.v.y<0,"Contact records productive/spent state and rebounds: %s/%s"%[area,kind])
			check(b.v.length()<=611 and finite_population(g),"Rebound speed and geometry remain finite: %s/%s"%[area,kind])
			var hp=g.pegs[0].hp
			b.cool=.08
			for _tick in range(4):
				b.p=Vector2(360,475); b.v=Vector2(0,610); g.step(.01)
			check(g.pegs[0].hp==hp,"Repeated overlap cannot farm damage within cooldown: %s/%s"%[area,kind])
			close(g,area+" contact "+kind)

func caps_and_expiry():
	for setup in [["bakery",false],["gelato",false],["gelato",true]]:
		var g=fixture(setup[0],setup[1]); var label="%s twins=%s"%setup
		g.pegs=[peg()]
		for i in range(80): ball(g,Vector2(80+(i%8)*75,800+(i/8)*4),Vector2(610 if i%2 else -610,-300))
		g.spawn_clock=-1
		var spawned=g.total_spawned
		g.step(1.0/60)
		check(g.balls.size()==80 and g.total_spawned==spawned,"Full active cap blocks ordinary/twin feeder: "+label)
		check(finite_population(g),"Full cap remains bounded after high-speed wall contact: "+label)
		for b in g.balls: b.life=16.0
		g.step(1.0/60)
		check(g.balls.is_empty(),"Expired active population frees all slots: "+label)
		g.step(1.0/60)
		check(g.balls.size()==(2 if setup[1] else 1),"Feeder resumes after expired slots are released: "+label)
		g.balls=[]
		for i in range(79): ball(g,Vector2(100+(i%8)*70,800),Vector2.ZERO)
		g.spawn_clock=-1; spawned=g.total_spawned;g.step(1.0/60)
		check(g.balls.size()==80 and g.total_spawned==spawned+1,"One remaining slot never admits both twin shots: "+label)
		close(g,label)
	for area in ["bakery","gelato"]:
		for total in [79,80]:
			var g=fixture(area);g.pegs=[peg()]
			for i in range(total-1): ball(g,Vector2(100+(i%8)*70,800),Vector2.ZERO)
			ball(g,Vector2(360,470),Vector2(0,200),"splitter")
			g.step(.001)
			check(g.balls.size()==80 and g.type_drops.shard==80-total,"Pending seeds consume only free active slots: %s/%d"%[area,total])
			check(not g.clear_draining and g.pegs[0].hp>0,"Population stress did not manufacture a clear: "+area)
			close(g,area+" split cap")

func state(g) -> String:
	return var_to_str([g.balls,g.pegs,g.shift_coins,g.total_spawned,g.type_drops,g.remaining,g.run_elapsed,str(g.rng.state)])

func stress_fixture(area: String):
	var g=fixture(area,area=="gelato")
	g.levels=g.MAX_LEVELS.duplicate();g.current_level=12;g.start_shift()
	g.pegs=[]
	for i in range(12):g.pegs.append(peg(10000,Vector2(150+(i%4)*140,420+int(i/4)*140)))
	g.spawn_clock=0;g.pickup_clock=100
	var kinds=["normal","ricochet","splitter","impact"]
	for i in range(80):
		var b=ball(g,Vector2(70+(i%8)*80,290+(i/8)*65),Vector2(610 if i%2 else -610,300 if i%3 else -300),kinds[i%4])
		b.productive=i%2==0
	return g

func schedules():
	check(Engine.physics_ticks_per_second==60,"Production fixed physics frequency is60Hz")
	check(Engine.max_physics_steps_per_frame==8,"Production catches up at most8fixed ticks per rendered frame")
	for area in ["bakery","gelato"]:
		var reference=stress_fixture(area)
		for _tick in range(120): reference.step(1.0/60.0)
		for group in [4,8]:
			var g=stress_fixture(area);var valid=true;var peak=g.balls.size()
			# Same fixed ticks, grouped as delayed rendered frames. No manufactured large delta.
			for _frame in range(int(120/group)):
				for _tick in range(group):
					g.testing=false;g._physics_process(1.0/60.0);g.testing=true
					valid=valid and finite_population(g) and g.balls.size()<=80
					peak=maxi(peak,g.balls.size())
			check(valid,"Crowded fixed-tick frame batches stay finite/capped: %s/%d"%[area,group])
			check(state(g)==state(reference),"Low-render-rate batches preserve exact physics/RNG/rewards: %s/%d"%[area,group])
			scenarios.append({"area":area,"fixed_dt":1.0/60,"ticks":120,"ticks_per_rendered_frame":group,"peak_balls":peak,"remaining_balls":g.balls.size(),"spawned":g.total_spawned,"coins":g.shift_coins,"exact_reference_match":state(g)==state(reference)})
			close(g,area+" scheduling")
		close(reference,area+" scheduling reference")

func split_drain():
	for area in ["bakery","gelato"]:
		var g=fixture(area)
		g.pegs=[peg(1)]
		for i in range(79):
			var b=ball(g,Vector2(100+(i%8)*70,800),Vector2(600 if i%2 else -600,-100))
			b.life=15.99;b.productive=true
		ball(g,Vector2(360,470),Vector2(0,200),"splitter")
		g.step(.001)
		check(g.clear_draining and g.balls.size()==83 and g.type_drops.shard==3,"Final split retains all3earned seeds above cap: "+area)
		var spawned=g.total_spawned;var elapsed=g.run_elapsed;var ticks=0;var valid=true
		while g.mode=="play" and ticks<3600:
			g.step(1.0/60);ticks+=1;valid=valid and finite_population(g) and g.balls.size()<=83
		var catches=0
		for cup in g.buckets:catches+=cup.hits
		check(valid and ticks<3600 and g.mode=="result" and g.balls.is_empty(),"Full final-split population drains without hang or overflow: "+area)
		check(catches==83 and g.total_spawned==spawned and g.run_elapsed==elapsed,"All83foods settle once without feeder or gameplay-time extension: "+area)
		var earned=g.shift_coins;g.begin_clear_drain();g.step(1);g.finish_shift()
		check(g.shift_coins==earned and g.total_shifts==1,"Repeated finish cannot duplicate clear/payout: "+area)
		scenarios.append({"area":area,"kind":"final_split_at_cap","peak_balls":83,"ticks_to_settle":ticks,"catches":catches,"coins":earned})
		close(g,area+" clear drain")

func oversized_probe():
	for area in ["bakery","gelato"]:
		var g=fixture(area);g.pegs=[peg()]
		ball(g,Vector2(360,430),Vector2(0,610))
		g.step(.25)
		var hit=g.pegs[0].hp<1000
		scenarios.append({"area":area,"kind":"unsupported_direct_large_dt_probe","dt":.25,"hit":hit,"note":"Diagnostic only. Slow rendering schedules fixed60Hz ticks, not a single250ms physics call."})
		print("DIAGNOSTIC large_dt area=",area," hit=",hit)
		close(g,area+" oversized diagnostic")

func _initialize():
	contacts();caps_and_expiry();schedules();split_drain();oversized_probe()
	var output=OS.get_environment("SUGARFALL_STRESS_OUTPUT")
	if not output.is_empty():
		var file=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":passed,"failed":failures.size(),"failures":failures,"profile_io_calls":profile_calls,"scenarios":scenarios},"  "));file.close()
	print("CROWDED PHYSICS QA: %d passed, %d failed"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
