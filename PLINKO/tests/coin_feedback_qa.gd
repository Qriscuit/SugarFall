extends SceneTree
const Feedback = preload("res://scripts/coin_feedback.gd")
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var profile_io = 0
	func _ready(): pass
	func load_game(): profile_io += 1
	func save_game():
		profile_io += 1
		return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	var fx = Feedback.new()
	fx.observe(500.5,"bakery")
	check(not fx.active(),"Loading an existing wallet does not celebrate old earnings")
	fx.observe(500.99,"bakery")
	check(not fx.active(),"Hidden fractional income does not animate an unchanged displayed number")
	fx.observe(501.0,"bakery"); fx.advance(.075)
	var peak = fx.presentation(false)
	check(fx.active() and peak.scale>1.2 and absf(peak.rotation)>.17 and peak.glow>.99,"Earned whole coin grows, twists and glows gold")
	var reduced = fx.presentation(true)
	check(reduced.scale==1.0 and reduced.rotation==0.0 and reduced.glow<=.22,"Reduced Motion keeps the number stationary with a subdued gold response")
	var age = fx.age
	fx.observe(900,"bakery")
	check(fx.age==age,"A burst of earnings shares the current animation rather than stacking growth")
	for index in range(60):
		fx.advance(.01)
		var state = fx.presentation(false)
		check(state.scale>=1.0 and state.scale<=Feedback.MAX_SCALE and absf(state.rotation)<=Feedback.MAX_ROTATION,"Celebration stays within the reserved layout bounds frame%d"%index)
	check(not fx.active() and fx.presentation(false)=={"scale":1.0,"rotation":0.0,"glow":0.0},"Number returns exactly to its normal size, angle and color")
	fx.observe(901,"bakery"); fx.advance(.075)
	check(signf(fx.presentation(false).rotation)==-signf(peak.rotation),"Separate earnings alternate the celebratory twist")
	fx.observe(400,"bakery")
	check(not fx.active(),"Spending cancels the earned-money celebration")
	fx.observe(9999,"gelato")
	check(not fx.active(),"Area changes never celebrate a different wallet as income")
	fx.reset(); fx.observe(250,"resumed-run")
	check(not fx.active(),"Resuming a run shows its earned amount without replaying the celebration")
	var game = Fixture.new()
	game.testing=true; game.sound_on=false; game.first_run_guide.active=false
	game.mode="home"; game.bank=20; game._process(.01)
	game.bank=45; game._process(.01)
	check(game.bank_coin_feedback.active() and game.bank==45,"Home wallet notices a collected payout without changing the authoritative balance")
	game.run_id="coin-test"; game.mode="play"; game.shift_coins=0; game._process(.01)
	game.shift_coins=6; game._process(.01); game._process(.075)
	check(game.run_coin_feedback.presentation(false).scale>1.0 and game.shift_coins==6,"Gameplay HUD celebrates the actual run total")
	game.mode="paused"; age=game.run_coin_feedback.age; game._process(1)
	check(game.run_coin_feedback.age==age,"Pause freezes the run-money animation")
	game.mode="play"; game.first_run_guide.active=true; game.first_run_guide.step_id="earned"; game._process(1)
	check(game.run_coin_feedback.age==age,"A blocking tutorial also freezes the run-money animation")
	game.first_run_guide.active=false
	game.bank_coin_feedback.advance(1)
	for screen in ["home","result","paused","shop"]:
		game.mode=screen
		check(not game.update_coin_feedback(.01),"A frozen run pulse does not force permanent redraws on "+screen)
	game.mode="home"; game.trial_active=true; game.bank=0
	game.update_coin_feedback(.01)
	game.trial_active=false; game.bank=45; game.update_coin_feedback(.01)
	check(not game.bank_coin_feedback.active(),"Returning from a Trial does not celebrate the restored campaign wallet as income")
	check(game.profile_io==0,"Feedback never reads or writes a player profile")
	game.free()
	print("COIN_FEEDBACK_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
