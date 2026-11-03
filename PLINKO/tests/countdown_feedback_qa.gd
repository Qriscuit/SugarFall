extends SceneTree
const Feedback = preload("res://scripts/countdown_feedback.gd")
var passed = 0
var failures: Array[String] = []

class TimerGame extends "res://scripts/main.gd":
	var profile_accesses = 0
	func _ready(): pass
	func save_game():
		profile_accesses += 1
		return false
	func load_game(): profile_accesses += 1

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func state(g) -> Dictionary:
	return g.countdown_feedback.presentation(g.remaining,g.run_elapsed,g.reduced_motion,g.clear_draining,g.run_id)

func first_sample(seconds: float, reduced: bool = false, cleared: bool = false) -> Dictionary:
	return Feedback.new().presentation(seconds,10.0-seconds,reduced,cleared,"fixture")

func color_distance(a: Color, b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func _initialize():
	var normal = first_sample(3.001)
	check(not normal.urgent and normal.label == "00:04" and normal.font_size == 31,"Before the final three seconds, the normal clock remains unchanged")
	var feedback = Feedback.new()
	var three = feedback.presentation(3,7,false)
	var two = feedback.presentation(2,8,false)
	var one = feedback.presentation(1,9,false)
	check(three.urgent and three.label == "3s" and three.font_size == 84 and three.color == Feedback.URGENT_INK,"A displayed second begins with one enlarged red beat")
	check(two.label == "2s" and first_sample(.01).label == "1s","Final seconds use the same ceiling rule as the normal timer")
	check(three.rotation < 0 and two.rotation > 0 and one.rotation < 0 and absf(three.rotation) < absf(two.rotation) and absf(two.rotation) < absf(one.rotation),"Twists alternate direction and become more pronounced at 3, 2, then 1 second")
	for tick in [3,2,1]:
		feedback.reset()
		var previous = feedback.presentation(float(tick),10.0-tick,false)
		var monotonic = true
		var still = true
		var fades = true
		for index in range(1,100):
			var frame = feedback.presentation(float(tick)-index*.01,10.0-tick+index*.01,false)
			monotonic = monotonic and frame.font_size <= previous.font_size and frame.beat <= previous.beat and absf(frame.rotation) <= absf(previous.rotation)+.000001 and frame.font_size >= 56
			still = still and frame.offset == Vector2.ZERO
			fades = fades and color_distance(frame.color,Feedback.SOFT_INK) <= color_distance(previous.color,Feedback.SOFT_INK)+.000001
			previous = frame
		check(monotonic and still,"The %ds beat settles once without oscillation, overshoot or position jitter" % tick)
		check(fades and previous.color.is_equal_approx(Feedback.SOFT_INK),"The %ds red steadily softens through that second" % tick)
	check(first_sample(2.51).rotation == 0 and first_sample(2.51).font_size == 56,"Growth and twist finish before the second's remaining color fade")
	var reduced = first_sample(2,true)
	check(reduced.font_size == 56 and reduced.rotation == 0 and reduced.offset == Vector2.ZERO and reduced.color == Feedback.SOFT_INK and reduced == first_sample(1.1,true),"Reduced Motion keeps a large stationary soft-red number with no beat or color pulse")
	check(not first_sample(2,false,true).urgent and first_sample(2,false,true).color == Feedback.NORMAL_INK,"Cleared-board food drain removes urgency even with little time left")
	check(not first_sample(0).urgent and not first_sample(-1).urgent,"An expired timer never becomes a negative urgent countdown")
	feedback.reset()
	var resumed = feedback.presentation(2.65,18.35,false,false,"resumed")
	check(is_equal_approx(resumed.age,.35) and resumed.font_size < 84,"A first mid-second sample reconstructs partial settle instead of replaying a full pop")
	check(feedback.presentation(2.65,18.35,false,false,"resumed") == resumed,"Repeated rendering of an unchanged timer is stable")
	check(feedback.presentation(3,7,false,false,"next-run").font_size == 84,"A new run identity clears the preceding run's presentation")
	feedback.presentation(1.1,8.9,false,false,"rewind")
	check(feedback.presentation(3,7,false,false,"rewind").font_size == 84,"An elapsed-time reset reconstructs presentation even when the identity is reused")
	var g = TimerGame.new()
	g.testing = true
	g.sound_on = false
	g.remaining = 1.75
	g.run_elapsed = 8.125
	g.mode = "paused"
	var before = state(g)
	g._process(1)
	g.step(1)
	check(state(g) == before,"Pause freezes the current countdown beat")
	g.mode = "play"
	g.first_run_guide.active = true
	g.first_run_guide.step_id = "earned"
	g._process(1)
	g.step(1)
	check(state(g) == before,"A blocking tutorial lesson freezes countdown motion")
	g.first_run_guide.active = false
	g.run_transition.active = true
	g.run_transition.time = 0
	g._process(.1)
	g.step(.1)
	check(state(g) == before,"The board entrance freezes countdown motion")
	g.run_transition.finish()
	g.countdown_feedback.reset()
	g.remaining = 2.2
	g.run_elapsed = 7.8
	before = state(g)
	g.add_time(.5)
	var fractional = state(g)
	check(is_equal_approx(g.remaining,2.7) and fractional.label == "3s" and fractional == before,"A 2.2 to 2.7 bonus never rewinds or regrows the current 3s beat")
	g.remaining = 1.9
	g.run_elapsed = 8.6
	state(g)
	g.add_time(.5)
	fractional = state(g)
	check(is_equal_approx(g.remaining,2.4) and fractional.label == "3s" and fractional.beat == 0 and fractional.rotation == 0 and fractional.color == Feedback.SOFT_INK,"A 1.9 to 2.4 bonus increases the label without starting an urgency beat")
	g.remaining = 2
	g.run_elapsed = 9.0
	var next_tick = state(g)
	check(next_tick.label == "2s" and next_tick.font_size == 84 and next_tick.rotation > 0,"The next true displayed-second decrease starts exactly one fresh beat")
	g.add_time(2)
	check(not state(g).urgent,"A time pickup leaving the final three seconds removes the urgent presentation")
	check(g.profile_accesses == 0,"Countdown checks never access a player profile")
	g.free()
	print("COUNTDOWN_FEEDBACK_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
