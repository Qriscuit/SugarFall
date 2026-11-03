extends SceneTree
## Transition/lifecycle checks use in-memory saves only. Production _ready and
## player profile access are bypassed even when testing=false exercises timers.
var passed = 0
var failures: Array[String] = []
var g

class TransitionGame extends "res://scripts/main.gd":
	var save_attempts = 0
	var read_attempts = 0
	var saved_snapshot: Dictionary = {}
	func _ready(): pass
	func save_game():
		save_attempts += 1
		saved_snapshot = RunSnapshot.capture(self).duplicate(true)
		return true
	func load_game(): read_attempts += 1

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func create_game(level: int = 4):
	var game = TransitionGame.new()
	game.testing = true
	game.sound_on = false
	game.board_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	game.current_level = level
	game.highest_unlocked = 12
	game.levels = [2,1,1,1,1,1,2,1]
	game.equipped = ["splitter","impact"]
	game.bank = 1234
	game.reduced_motion = false
	game.navigation_delay = 0
	game.monetization.active_seconds = 19.0
	game.monetization.attempts = 2
	game.page_transition.enabled = true
	return game

func fresh(level: int = 4):
	if is_instance_valid(g): g.free()
	g = create_game(level)

func state(game) -> Dictionary:
	var snapshot: Dictionary = game.RunSnapshot.capture(game).duplicate(true)
	# Run identities are intentionally different between independent controls.
	snapshot.erase("run_id")
	return snapshot

func equal(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equal(a[i],b[i]): return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a)-float(b))<.000000001
	return a==b

func touch(p: Vector2, pressed: bool, index: int = 0):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = g.to_global(p)
	event.pressed = pressed
	g._input(event)

func drag(p: Vector2):
	var event = InputEventScreenDrag.new()
	event.index = 0
	event.position = g.to_global(p)
	event.relative = Vector2(140,60)
	g._input(event)

func launch_and_freeze():
	fresh()
	g.testing = false
	var serial = g.run_serial
	var play: Vector2 = g.home_menu.PLAY_RECT.get_center()
	touch(play,true,17)
	check(g.mode=="home" and not g.run_transition.active,"Home launch waits for a completed touch")
	touch(play,false,17)
	check(g.mode=="play" and g.run_transition.active and not g.page_transition.active,"Production Home Play morphs its tray into the live board without cream")
	check(g.run_serial==serial+1 and g.save_attempts==1 and not g.saved_snapshot.is_empty(),"Home launch creates and checkpoints exactly one initialized run")
	check(g.run_transition.progress()==0.0 and is_equal_approx(g.run_transition.time,0.0),"Home launch begins at the unchanged preview endpoint")
	check(g.remaining==g.BASE_SECONDS+g.levels[7]*g.CLOCK_STEP and g.balls.is_empty(),"The full timer and empty board are retained at launch")
	var before = state(g)
	var cooldown: float = g.monetization.active_seconds
	var clock: float = g.checkpoint_clock
	g._physics_process(.1)
	g.step(.1)
	check(equal(before,state(g)),"Both physics dispatch and direct gameplay steps are frozen during entry")
	check(g.monetization.active_seconds==cooldown and g.monetization.attempts==2 and g.monetization.pending.is_empty(),"Entry does not advance ad cooldown, completed attempts, or provider requests")
	g._process(.1)
	var first: float = g.run_transition.progress()
	g._process(.1)
	check(g.run_transition.active and first>0 and g.run_transition.progress()>first and g.run_transition.progress()<1,"Presentation advances smoothly while entry remains active")
	check(equal(before,state(g)) and g.checkpoint_clock==clock and g.save_attempts==1,"Presentation frames leave gameplay, RNG, and checkpoint cadence unchanged")
	g._process(5.0)
	check(not g.run_transition.active and g.run_transition.progress()==1.0,"A stalled render frame settles at the exact gameplay endpoint")
	check(equal(before,state(g)) and g.checkpoint_clock==clock and g.save_attempts==1,"The transition-ending frame does not charge its delta to the run or checkpoint clock")
	g._process(.1)
	check(is_equal_approx(g.checkpoint_clock,clock-.1),"Normal checkpoint cadence resumes on the following gameplay frame")
	var control = create_game()
	control.start_shift()
	g.step(1.0/60.0)
	control.step(1.0/60.0)
	check(equal(state(g),state(control)),"The first active physics frame matches a directly started run exactly")
	for i in range(30):
		g.step(1.0/60.0)
		control.step(1.0/60.0)
	check(equal(state(g),state(control)) and g.total_spawned>0,"After entry, drops and deterministic physics continue identically to the direct-start control")
	check(is_equal_approx(g.monetization.active_seconds,control.monetization.active_seconds),"Only real gameplay time contributes to the automatic-ad cooldown")
	control.free()

func tray_launch_waits_for_equipment():
	fresh()
	g.testing=false
	var tray: Vector2 = g.home_menu.TRAY_RECT.get_center()
	touch(tray,true,17)
	touch(tray,false,17)
	var before = state(g)
	var cooldown: float = g.monetization.active_seconds
	g._process(g.run_transition.DURATION-.001)
	g._physics_process(.5)
	g.step(.5)
	check(g.run_transition.active and equal(before,state(g)),"Tray launch keeps timer, RNG, and donut spawns frozen until the full entrance settles")
	check(g.monetization.active_seconds==cooldown and g.save_attempts==1,"Tray entrance does not consume ad cooldown time or create extra checkpoints")
	g._process(.002)
	check(not g.run_transition.active and g.balls.is_empty() and is_equal_approx(g.spawn_clock,.25),"The entire tray, hopper, and buckets settle before the initial drop countdown begins")
	g.step(.249)
	check(g.total_spawned==0,"The first donut keeps its initial delay after the equipment is in place")
	g.step(.002)
	check(g.total_spawned==1,"The first donut falls only after the settled board and initial delay")

func input_guard():
	fresh()
	g.start_shift(true)
	g.navigation_delay = 0
	var before = state(g)
	var serial = g.run_serial
	touch(Vector2(620,500),true)
	drag(Vector2(600,650))
	touch(Vector2(600,650),false)
	g.handle_press(Vector2(630,70))
	g.handle_press(g.home_menu.PLAY_RECT.get_center())
	check(g.mode=="play" and g.run_transition.active and equal(before,state(g)),"Entry absorbs touch aiming, dragging, and ordinary button taps")
	check(g.run_serial==serial,"Repeated taps during entry cannot create another attempt")
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	g._input(event)
	check(g.mode=="paused" and not g.run_transition.active,"Escape settles the board and opens Pause during entry")
	check(equal(before,state(g)),"Escape during entry preserves the untouched run")
	g.navigation_delay = 0
	g.go_back()
	check(g.mode=="paused" and g.page_transition.active,"Pause page transition still gates repeated Back after interrupting entry")
	g.page_transition.finish(); g.go_back(); g.page_transition.finish()
	check(g.mode=="play" and not g.run_transition.active,"Resume after interrupting entry starts at the finished board without replaying its morph")
	g.step(.1)
	check(g.run_elapsed>0 and g.remaining<float(before.remaining),"The interrupted run can resume real gameplay normally")
	for route in ["escape","back","system-back"]:
		fresh()
		var play: Vector2 = g.home_menu.PLAY_RECT.get_center()
		touch(play,true,27)
		touch(play,false,27)
		check(g.run_transition.active and g.navigation_delay>0,"A real Home tap activates entry and navigation debounce for "+route)
		var unchanged = state(g)
		if route=="escape":
			g._input(event)
		elif route=="back":
			g.go_back()
		else:
			g._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(g.mode=="paused" and not g.run_transition.active and equal(unchanged,state(g)),"Immediate "+route+" interrupts entry even within the Home navigation guard")
		g.go_back()
		check(g.mode=="paused","Repeated Back after "+route+" cannot immediately undo Pause")

func lifecycle():
	for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		fresh()
		g.testing = false
		g.start_shift(true)
		g._process(.12)
		var before = state(g)
		g._notification(notification)
		check(g.mode=="paused" and not g.run_transition.active,"Lifecycle event %d settles entry and pauses" % notification)
		check(equal(before,state(g)) and g.save_attempts==2 and not g.saved_snapshot.is_empty(),"Lifecycle event %d checkpoints the untouched run in memory" % notification)
		g._process(1.0)
		g._physics_process(1.0)
		check(equal(before,state(g)) and is_equal_approx(g.checkpoint_clock,5.0),"Lifecycle event %d remains paused without timer or checkpoint drift" % notification)
	fresh()
	g.start_shift(true)
	g._process(.15)
	var original = state(g)
	var saved: Dictionary = g.RunSnapshot.capture(g)
	check(g.restore_active_run(saved),"An interrupted entry snapshot is a valid existing-schema active run")
	check(g.mode=="paused" and g.resumed_run and not g.run_transition.active and equal(original,state(g)),"Restoring entry checkpoints clears presentation state and resumes paused with exact gameplay state")
	fresh()
	g.start_shift(true)
	g.reject_snapshot("transition fixture")
	check(g.mode=="home" and not g.run_transition.active,"Rejecting a snapshot clears a pending entry transition")
	fresh()
	g.start_shift(true)
	g.reset_profile_runtime()
	check(g.mode=="home" and not g.run_transition.active and g.run_serial==0,"Switching or resetting a profile clears entry presentation")

func reduced_motion_and_direct_routes():
	fresh()
	g.reduced_motion = true
	g.start_shift(true)
	check(g.mode=="play" and not g.run_transition.active,"Reduced Motion enters gameplay immediately")
	check(g.remaining==g.BASE_SECONDS+g.levels[7]*g.CLOCK_STEP and is_equal_approx(g.spawn_clock,.25),"Reduced Motion retains the full timer and initial drop delay")
	g.step(.1)
	check(g.run_elapsed>0,"Reduced Motion gameplay begins without a hidden animation wait")
	fresh()
	g.start_shift()
	check(g.mode=="play" and not g.run_transition.active,"Map, upgrade, replay, and trial direct-start contract remains immediate")
	g.start_shift(true)
	g._process(.1)
	g.start_shift()
	check(not g.run_transition.active and is_equal_approx(g.run_elapsed,0.0),"A direct new run clears any previous presentation transition")
	for level in [1,4,12]:
		fresh(level)
		var preview: Array = g.home_menu.preview_pegs()
		g.start_shift(true)
		var matching = preview.size()==g.pegs.size()
		for i in range(mini(preview.size(),g.pegs.size())):
			matching = matching and preview[i].p==g.pegs[i].p and preview[i].kind==g.pegs[i].kind
		check(matching,"Level %d transitions using the exact previewed peg positions and kinds" % level)
	check(g.read_attempts==0 and g.save_attempts==0,"Transition fixtures never access a player profile")

func _initialize():
	launch_and_freeze()
	tray_launch_waits_for_equipment()
	input_guard()
	lifecycle()
	reduced_motion_and_direct_routes()
	if is_instance_valid(g): g.free()
	print("RUN_TRANSITION_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
