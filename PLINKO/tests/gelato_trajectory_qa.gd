extends SceneTree
## Independent analytic checks against real launch/physics code. No profile IO.
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var profile_io = 0
	var selected_kind = "normal"
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): profile_io += 1
	func save_game(): profile_io += 1; return false
	func write_profile_file(_data: Dictionary) -> bool: profile_io += 1; return false
	func random_ball(): return selected_kind

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area: String = "gelato", twins: bool = false):
	var game = Fixture.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	game.first_run_guide.active = false
	game.set_active_area(area)
	game.highest_unlocked = 12
	game.twin_launchers = twins
	game.power_reset_tier = 3 if twins else 0
	game.start_shift()
	# Empty geometry is intentionally not a clear, so the real flight loop runs.
	game.pegs = []
	game.spawn_clock = 100
	game.pickup_clock = 100
	return game

func analytic(origin: Vector2, velocity: Vector2, gravity: float, time: float) -> Vector2:
	return origin+velocity*time+Vector2(0,.5*gravity*time*time)

func aim(game, target: Vector2):
	game.aim_x = target.x
	game.aim_y = target.y

func solve_and_envelope():
	for twins in [false,true]:
		var game = fixture("gelato",twins)
		var points = [Vector2(360,330),Vector2(360,900),Vector2(500,700),Vector2(160,740),Vector2(66,330),Vector2(654,330),Vector2(66,1000),Vector2(654,1000)]
		for target in points:
			aim(game,target)
			var solutions: Array = []
			for origin in game.gelato_launcher.origins():
				var solution: Dictionary = game.gelato_launcher.solution(origin)
				solutions.append(solution)
				var velocity: Vector2 = solution.velocity
				var time = float(solution.time)
				var endpoint = analytic(origin,velocity,float(game.tuning.gravity),time)
				check(time>0 and is_finite(time) and velocity.is_finite() and velocity.y>=-.001,"Finite downward ballistic solution: twins=%s origin=%s aim=%s" % [twins,origin,target])
				check(absf(velocity.length()-float(game.tuning.launcher_speed))<.01,"Aiming preserves configured launch speed without a hidden boost: %s" % target)
				check(endpoint.distance_to(solution.target)<.02,"Independent ballistic equation reaches the selected target: %s" % target)
				check(game.gelato_launcher.direction(origin).distance_to(velocity.normalized())<.001,"Nozzle uses the launch tangent, not the straight sightline: %s" % target)
			if twins:
				check(solutions[0].target.distance_to(solutions[1].target)<.001,"Both launchers converge on one reachable target: %s" % target)
			if target in [Vector2(66,330),Vector2(654,330)]:
				check(solutions[0].clamped and solutions[0].target.distance_to(target)>1,"Impossible near-side aim is clamped instead of falsely promising a hit: %s" % target)
			else:
				check(not solutions[0].clamped and solutions[0].target.distance_to(target)<.01,"Reachable finger position is the actual landing target: %s" % target)
			aim(game,Vector2(500,700))
			var origin: Vector2 = game.gelato_launcher.origins()[0]
			var velocity: Vector2 = game.gelato_launcher.solution(origin).velocity
			check(absf(velocity.normalized().cross((Vector2(500,700)-origin).normalized()))>.1,"Gravity compensation visibly raises the launch tangent for an off-center target")
		check(game.profile_io==0,"Solver fixtures never touch player profiles")
		game.free()

func actual_flight(target: Vector2, twins: bool, origin_index: int, kind: String, hz: int, change_aim: bool = false):
	var game = fixture("gelato",twins)
	game.selected_kind = kind
	aim(game,target)
	var origin: Vector2 = game.gelato_launcher.origins()[origin_index]
	var solution: Dictionary = game.gelato_launcher.solution(origin)
	game.gelato_launcher.fire()
	var ball: Dictionary = game.balls[origin_index]
	game.balls = [ball]
	var velocity: Vector2 = ball.v
	var label = "%s at %d Hz, twin=%s nozzle=%d target=%s" % [kind,hz,twins,origin_index,target]
	check(ball.p==origin and velocity.distance_to(solution.velocity)<.001,"Fired ball starts exactly on its preview: "+label)
	var time = 0.0
	var max_position_error = 0.0
	var max_velocity_error = 0.0
	while time<float(solution.time)-.000001:
		var dt = minf(1.0/hz,float(solution.time)-time)
		game.step(dt)
		time += dt
		max_position_error = maxf(max_position_error,ball.p.distance_to(analytic(origin,velocity,float(game.tuning.gravity),time)))
		max_velocity_error = maxf(max_velocity_error,ball.v.distance_to(velocity+Vector2(0,float(game.tuning.gravity)*time)))
		if change_aim and time>float(solution.time)*.25: aim(game,Vector2(654,330))
	check(max_position_error<.025 and max_velocity_error<.025,"Every real physics step follows the analytic parabola: "+label+" max error="+str(max_position_error))
	check(game.balls.size()==1 and ball.p.distance_to(solution.target)<.025,"Actual ball reaches its preview endpoint: "+label)
	if change_aim: check(Vector2(game.aim_x,game.aim_y)!=target and ball.p.distance_to(solution.target)<.025,"Moving the finger after firing cannot steer the ball in flight")
	check(game.profile_io==0,"Flight fixture performs no profile IO")
	game.free()

func real_flight_checks():
	for hz in [60,120]:
		for target in [Vector2(360,900),Vector2(500,700),Vector2(160,740),Vector2(654,330)]:
			actual_flight(target,false,0,"normal",hz)
		for nozzle in [0,1]: actual_flight(Vector2(500,700),true,nozzle,"normal",hz)
		for kind in ["ricochet","splitter","impact"]: actual_flight(Vector2(180,720),false,0,kind,hz)
	actual_flight(Vector2(180,720),false,0,"normal",60,true)

func guide_and_spread():
	var game = fixture()
	aim(game,Vector2(500,700))
	var launcher = game.gelato_launcher
	var origin = Vector2(360,267)
	var solution: Dictionary = launcher.solution(origin)
	var rng_before = game.rng.state
	var guide: Dictionary = launcher.preview(origin)
	check(not guide.hit and guide.end.distance_to(solution.target)<.02 and guide.points[-1].distance_to(solution.target)<3.01,"Unobstructed dotted guide ends at the selected target")
	check(guide.points.size()>8,"Full-flight preview provides a readable series of dots")
	var max_curve_error = 0.0
	for point: Vector2 in guide.points:
		# Nonvertical shot: x independently gives time, then check y.
		var time = (point.x-origin.x)/solution.velocity.x
		max_curve_error = maxf(max_curve_error,point.distance_to(analytic(origin,solution.velocity,float(game.tuning.gravity),time)))
	check(max_curve_error<.03,"Every displayed guide point lies on the ballistic curve")
	check(game.rng.state==rng_before,"Calculating the preview consumes no gameplay randomness")
	var peg_position = analytic(origin,solution.velocity,float(game.tuning.gravity),float(solution.time)*.55)
	game.pegs = [{"p":peg_position,"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}]
	var blocked: Dictionary = launcher.preview(origin)
	check(blocked.hit and blocked.end.distance_to(solution.target)>25,"Dotted preview stops at its first live peg instead of promising travel through it")
	check(absf(blocked.end.distance_to(peg_position)-31.0)<2.0,"Preview contact includes the peg and normal-ball radii")
	game.pegs[0].hp = 0
	var cleared: Dictionary = launcher.preview(origin)
	check(not cleared.hit and cleared.end.distance_to(solution.target)<.02,"Destroyed pegs no longer obstruct the preview")
	var deterministic = true
	for seed_value in range(12):
		game.rng.seed = seed_value
		game.balls = []
		launcher.fire()
		deterministic = deterministic and game.balls[0].v.distance_to(solution.velocity)<.001
	check(deterministic,"RNG changes never introduce launch spread into Gelato's previewed shot")
	check(game.profile_io==0,"Guide and spread fixtures perform no profile IO")
	game.free()

func bakery_unchanged():
	var game = fixture("bakery")
	var velocities: Array = []
	for seed_value in range(12):
		game.balls = []
		game.rng.seed = seed_value
		game.spawn_ball(Vector2(420,267),"normal")
		velocities.append(game.balls[0].v.x)
	var bounded = true
	for vx in velocities: bounded = bounded and absf(vx)<=18.0
	check(bounded and velocities.min()!=velocities.max(),"Bakery retains its random horizontal drop spread")
	var ball: Dictionary = game.balls[0]
	var start: Vector2 = ball.p
	var initial: Vector2 = ball.v
	var dt = 1.0/60.0
	game.step(dt)
	check(ball.v.distance_to(initial+Vector2(0,400*dt))<.001 and ball.p.distance_to(start+ball.v*dt)<.001,"Bakery keeps its existing semi-implicit falling motion")
	check(game.profile_io==0,"Bakery control fixture performs no profile IO")
	game.free()

func paired_guides():
	var game = fixture("gelato",true)
	var launcher = game.gelato_launcher
	var origins: Array = launcher.origins()
	var colors = [launcher.guide_color(origins[0]),launcher.guide_color(origins[1])]
	check(absf(colors[0].r-colors[1].r)+absf(colors[0].g-colors[1].g)>.3,"Twin guides have distinct mint and berry ink")
	for origin in origins:
		check(is_equal_approx(launcher.guide_color(origin,.5).a,launcher.guide_color(origin).a*.5),"Twin guide fade follows the board transition")
	for target in [Vector2(360,900),Vector2(160,740),Vector2(570,850),Vector2(66,330),Vector2(654,330)]:
		aim(game,target)
		game.pegs=[]
		game.balls=[]
		launcher.fire()
		for nozzle in range(2):
			var origin: Vector2=origins[nozzle]
			var ball: Dictionary=game.balls[nozzle]
			var guide: Dictionary=launcher.preview(origin)
			var max_error=0.0
			for point: Vector2 in guide.points:
				var time=(point.x-origin.x)/ball.v.x
				max_error=maxf(max_error,point.distance_to(analytic(origin,ball.v,float(game.tuning.gravity),time)))
			check(max_error<.03 and guide.end.distance_to(launcher.aim_target())<.02,"Every twin dot uses its fired ball's own parabola: nozzle %d target %s" % [nozzle,target])
	# Stop only the left guide at an early peg, while the right remains clear.
	aim(game,Vector2(360,900))
	var left: Dictionary=launcher.solution(origins[0])
	var blocker=analytic(origins[0],left.velocity,float(game.tuning.gravity),left.time*.16)
	game.pegs=[{"p":blocker,"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}]
	var blocked: Dictionary=launcher.preview(origins[0])
	var clear: Dictionary=launcher.preview(origins[1])
	check(blocked.hit and not clear.hit,"Each twin guide independently stops at its first live peg")
	check(blocked.end.distance_to(blocker)<32 and clear.end.distance_to(launcher.aim_target())<.02,"The blocked twin has a contact endpoint while its partner keeps the full target")
	game.pegs[0].hp=0
	check(not launcher.preview(origins[0]).hit and not launcher.preview(origins[1]).hit,"Both twin guides extend again when the obstructing peg breaks")
	game.trial_active=true
	check(launcher.origins().size()==1 and launcher.guide_color(Vector2(360,267))==Color(.33,.23,.44,.64),"Fixed-loadout Trial keeps one original-color preview even with owned twins")
	check(game.profile_io==0,"Paired preview checks never access a profile")
	game.free()

func _initialize(): call_deferred("run")

func run():
	solve_and_envelope()
	real_flight_checks()
	guide_and_spread()
	paired_guides()
	bakery_unchanged()
	print("GELATO_TRAJECTORY_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
