extends SceneTree
## Deterministic gameplay and checkpoint checks. Fixtures never read/write disk.
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var writes=0
	var fail_write=false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): assert(false,"QA must never read player profiles")
	func save_game(): writes+=1; return not fail_write
	func random_ball(): return "normal"

func check(value: bool, label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture():
	var game=Fixture.new()
	game.testing=true
	game.sound_on=false
	game.first_run_guide.completed=true
	game.first_run_guide.active=false
	game.set_active_area("crystal")
	game.highest_unlocked=12
	game.start_shift()
	game.spawn_clock=100
	game.pickup_clock=100
	return game

func shot(game, position: Vector2, direction: Vector2, kind: String="normal") -> Dictionary:
	game.spawn_ball(position,kind,game.crystal_launcher.prepare_velocity(direction),false)
	return game.balls[-1]

func physics():
	var g=fixture()
	g.pegs=[]
	for target in [Vector2(360,950),Vector2(150,700),Vector2(570,700)]:
		g.aim_x=target.x; g.aim_y=target.y
		g.balls=[]
		var direction=(target-g.crystal_launcher.origin()).normalized()
		g.crystal_launcher.fire()
		var ball: Dictionary=g.balls[0]
		var start: Vector2=ball.p
		var speed=ball.v.length()
		for _index in range(30): g.crystal_launcher.step_ball(ball,1.0/120.0,[])
		check(ball.p.distance_to(start+direction*speed*.25)<.01,"Straight flight matches finger vector without gravity: "+str(target))
		check(absf(ball.v.length()-speed)<.001,"Free flight preserves speed")
	g.balls=[]
	var wall=shot(g,Vector2(660,500),Vector2(1,.2))
	g.crystal_launcher.step_ball(wall,.1,[])
	check(wall.v.x<0 and absf(wall.v.length()-360)<.001,"Wall reflection loses no speed and adds no jitter")
	g.balls=[]
	g.pegs=[{"p":Vector2(360,500),"hp":100.0,"max":100.0,"kind":"normal","flash":0.0}]
	var ball=shot(g,Vector2(360,390),Vector2.DOWN)
	var hp=float(g.pegs[0].hp)
	g.crystal_launcher.step_ball(ball,.25,[])
	check(g.pegs[0].hp<hp and ball.v.y<0,"Bounded substeps hit a peg rather than tunnel through it")
	check(absf(ball.v.length()-360)<.001,"Peg reflection preserves shot speed")
	for dt in [1.0/60.0,1.0/30.0,.1,.25]:
		g.balls=[]
		g.pegs[0].hp=100.0
		ball=shot(g,Vector2(360,390),Vector2.DOWN)
		for _index in range(ceili(.25/dt)): g.crystal_launcher.step_ball(ball,dt,[])
		check(g.pegs[0].hp<100 and ball.v.y<0,"Peg collision remains reliable at dt="+str(dt))
	g.pegs=[]
	g.balls=[]
	ball=shot(g,Vector2(360,390),Vector2.DOWN)
	g.crystal_launcher.step_ball(ball,1.0,[])
	check(absf(ball.p.y-480.0)<.001,"Long catch-up ticks explicitly cap movement to250ms")
	var ordinary=g.crystal_launcher.lifetime()
	g.levels[2]=6
	check(g.crystal_launcher.lifetime()==ordinary+3.0,"Bounce upgrades extend useful ball lifetime")
	check(g.crystal_launcher.lifetime("ricochet")==g.crystal_launcher.lifetime()+2.0,"Equipped Ricochet has a real lifetime advantage")
	check(g.crystal_launcher.interval(0)>1 and g.crystal_launcher.interval(10)>=.74,"Feed retains deliberate slow shot cadence at maximum tier")
	for value in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.ZERO]:
		g.balls=[]; g.clear_draining=true
		ball=shot(g,Vector2(360,400),value)
		g.crystal_launcher.begin_clear_drain()
		for _index in range(600):
			if ball.dead: break
			g.crystal_launcher.step_ball(ball,1.0/60.0,[])
		check(ball.dead,"Clear drain reaches a real catch for incoming direction "+str(value))
	g.free()

func press_only_input():
	var g=fixture()
	shot(g,Vector2(300,500),Vector2.DOWN)
	g.run_elapsed=3; g.remaining=7; g.crystal_launcher.advance(0)
	var point: Vector2=g.board_to_screen(g.crystal_run.offer_position)
	var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=point
	g._input(drag)
	check(g.balls.size()==1 and g.crystal_run.collected==0,"Dragging over a Prism does not collect it")
	var hover=InputEventMouseMotion.new(); hover.position=point
	g._input(hover)
	check(g.balls.size()==1 and g.crystal_run.collected==0,"Mouse hover does not collect a Prism")
	var touch=InputEventScreenTouch.new(); touch.index=1; touch.position=point; touch.pressed=true
	g._input(touch)
	check(g.balls.size()==1,"Secondary finger cannot consume the primary touch offer")
	var aim=Vector2(g.aim_x,g.aim_y)
	touch.index=0; g._input(touch)
	check(g.balls.size()==2 and g.crystal_run.collected==1,"A primary press collects the offer through actual input routing")
	check(Vector2(g.aim_x,g.aim_y)==aim,"Collecting a Prism leaves the launcher aim unchanged")
	g.free()

func clones_and_offers():
	var g=fixture()
	g.pegs=[]
	for kind in ["normal","ricochet","splitter","impact","shard"]:
		var ball=shot(g,Vector2(300,500),Vector2.DOWN,kind)
		ball.used=true; ball.productive=true; ball.cool=.04; ball.life=3.25
	var originals=g.balls.duplicate(true)
	var rng_state=g.rng.state
	check(g.crystal_launcher.duplicate_live_balls()==5 and g.balls.size()==10,"Prism clones only the original live population once")
	for index in range(5):
		var clone: Dictionary=g.balls[index+5]
		var original: Dictionary=originals[index]
		check(clone.kind==original.kind and clone.used and clone.productive and clone.cool==original.cool and clone.life==original.life,"Clone preserves spent ability, productivity, cooldown and age: "+str(clone.kind))
		check(absf(clone.v.length()-original.v.length())<.001 and absf(clone.v.angle_to(original.v))>.19,"Clone spreads by twelve degrees without changing speed")
	check(g.rng.state==rng_state and g.total_spawned==10,"Duplication keeps RNG unchanged and counts all new balls")
	check(g.type_drops.values().reduce(func(sum,value): return sum+value,0)==g.total_spawned,"Clone drop totals remain checkpoint-consistent")
	g.balls=[]
	for _index in range(79): shot(g,Vector2(300,500),Vector2.DOWN)
	check(g.crystal_launcher.duplicate_live_balls()==1 and g.balls.size()==80,"Near-cap clone deterministically uses only the remaining slot")
	check(g.crystal_launcher.duplicate_live_balls()==0 and g.balls.size()==80,"Full population cannot exceed80")
	g.balls=[]; g.crystal_second_prism=true; g.crystal_launcher.reset_run()
	g.run_elapsed=3.0; g.crystal_launcher.advance(0)
	check(g.crystal_run.next_offer==0 and g.crystal_run.offer_life==0,"No-ball scheduled offer waits without showing or spending a pickup")
	shot(g,Vector2(300,500),Vector2.DOWN)
	g.run_elapsed=3.1; g.crystal_launcher.advance(.1)
	check(g.crystal_run.next_offer==1 and g.crystal_run.offer_life==4,"First eligible offer starts its full four-second window")
	g.mode="paused"; g.crystal_launcher.advance(2)
	check(g.crystal_run.offer_life==4,"Pause freezes offer lifetime")
	g.mode="play"; g.run_elapsed=7.09; g.crystal_launcher.advance(3.99)
	check(g.crystal_run.offer_life>0,"Offer remains available immediately before four seconds")
	g.run_elapsed=7.1; g.crystal_launcher.advance(.01)
	check(g.crystal_run.offer_life<.00001 and g.crystal_run.next_offer==1,"Expired first opportunity is not rerolled")
	g.run_elapsed=7.5; g.crystal_launcher.advance(.4)
	check(g.crystal_run.next_offer==2 and g.crystal_run.offer_life==4,"Upgrade offers a second chance even after missing the first")
	var point: Vector2=g.crystal_run.offer_position
	check(g.crystal_launcher.try_collect(point) and g.crystal_run.collected==1,"Tap duplicates the balls already on the board")
	check(not g.crystal_launcher.try_collect(point),"Repeated tap cannot collect the same offer twice")
	g.crystal_launcher.reset_run(); g.run_elapsed=3; g.crystal_launcher.advance(0)
	point=g.crystal_run.offer_position
	var held=g.balls.duplicate(true); g.balls=[]
	check(not g.crystal_launcher.try_collect(point) and g.crystal_run.offer_life==4 and g.crystal_run.collected==0,"A tap with no live balls does not consume an active offer")
	g.balls=held; g.clear_draining=true; g.crystal_launcher.begin_clear_drain()
	check(g.crystal_run.offer_life==0 and not g.crystal_launcher.try_collect(point),"Clearing the board cancels any remaining offer")
	g.clear_draining=false
	g.crystal_launcher.reset_run(); g.crystal_second_prism=false; g.run_elapsed=3; g.crystal_launcher.advance(0)
	g.run_elapsed=8; g.crystal_launcher.advance(5)
	check(g.crystal_run.next_offer==1 and g.crystal_run.offer_life==0,"Base build offers at most one chance")
	g.balls=[]; g.crystal_launcher.reset_run(); g.run_elapsed=5; g.crystal_launcher.advance(0)
	check(g.crystal_run.next_offer==1 and g.crystal_run.offer_life==0,"Empty-board offer window ends after bounded waiting")
	g.free()

func snapshots_and_purchase():
	var g=fixture()
	g.spawn_clock=.7; g.crystal_second_prism=true
	shot(g,Vector2(360,500),Vector2.DOWN,"impact")
	g.balls[0].used=true; g.balls[0].life=2.0
	g.run_elapsed=3; g.remaining=7
	g.crystal_launcher.advance(0)
	var checkpoint: Dictionary=Snapshot.capture(g)
	check(checkpoint.get("schema")==5,"Crystal writes checkpoint schema5")
	var decoded=Snapshot.validate_and_decode(checkpoint,g)
	check(decoded.ok,"Active four-second Prism offer validates with real board state")
	if decoded.ok:
		check(decoded.state.crystal_run.offer_life==4 and decoded.state.crystal_run.next_offer==1,"Resume retains exact opportunity and remaining lifetime")
	check(g.restore_active_run(checkpoint) and g.mode=="paused","Interrupted Crystal run resumes paused")
	g.mode="play"
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position),"Restored offer is collectible once")
	checkpoint=Snapshot.capture(g)
	check(Snapshot.validate_and_decode(checkpoint,g).ok and checkpoint.crystal_run.collected==1,"Cloned population and consumed offer survive checkpoint validation")
	for key in ["offer_life","next_offer","collected"]:
		var bad=checkpoint.duplicate(true)
		bad.crystal_run[key]=99
		check(not Snapshot.validate_and_decode(bad,g).ok,"Reject corrupt Prism field: "+key)
	var missing=checkpoint.duplicate(true); missing.erase("crystal_run")
	check(not Snapshot.validate_and_decode(missing,g).ok,"Reject Crystal checkpoint missing opportunity state")
	var wrong=checkpoint.duplicate(true); wrong.crystal_second_prism=false
	check(not Snapshot.validate_and_decode(wrong,g).ok,"Checkpoint cannot change campaign Second Prism ownership")
	var legacy=checkpoint.duplicate(true); legacy.schema=4
	check(not Snapshot.validate_and_decode(legacy,g).ok,"Crystal cannot masquerade as a legacy checkpoint")
	var fast=checkpoint.duplicate(true); fast.balls[0].v=[0,10000]
	check(not Snapshot.validate_and_decode(fast,g).ok,"Reject speeds that could bypass bounded Crystal collision stepping")
	var time_pickup=checkpoint.duplicate(true); time_pickup.pickups=[{"p":[360,500],"life":4.0}]
	check(not Snapshot.validate_and_decode(time_pickup,g).ok,"Crystal cannot resume an unauthorized time pickup")
	for peg in g.pegs: peg.hp=0.0
	g.destroyed=g.pegs.size(); g.special_stats.normal=g.destroyed
	g.clear_draining=true; g.level_won=true; g.crystal_launcher.begin_clear_drain()
	var drain=Snapshot.capture(g)
	check(Snapshot.validate_and_decode(drain,g).ok,"Crystal clear drain preserves valid ball and opportunity state")
	g.mode="shop"; g.shift_claimed=true; g.crystal_second_prism=false; g.highest_unlocked=6; g.levels[1]=4; g.bank=1000
	g.testing=false; g.fail_write=true; g.note="before"; g.note_time=2
	check(not g.crystal_launcher.buy() and g.writes==1 and g.bank==1000 and not g.crystal_second_prism and g.note=="before" and g.note_time==2,"Failed Second Prism save rolls back wallet, ownership and presentation")
	g.fail_write=false
	check(g.crystal_launcher.buy() and g.bank==100 and g.crystal_second_prism,"Second Prism charges900 only after both progression gates")
	check(not g.crystal_launcher.buy() and g.bank==100,"Second Prism cannot be bought twice")
	g.free()
	for area in ["bakery","gelato"]:
		g=fixture(); g.set_active_area(area); g.crystal_second_prism=false; g.start_shift()
		checkpoint=Snapshot.capture(g)
		check(checkpoint.get("schema")==4 and not checkpoint.has("crystal_run"),"Existing area retains schema4 checkpoint shape: "+area)
		check(Snapshot.validate_and_decode(checkpoint,g).ok,"Existing area checkpoint still validates: "+area)
		g.free()

func _initialize():
	physics()
	clones_and_offers()
	press_only_input()
	snapshots_and_purchase()
	print("CRYSTAL PHYSICS QA: %d passed, %d failed" % [passed,failures.size()])
	for label in failures: print("FAILED: ",label)
	quit(0 if failures.is_empty() else 1)
