extends "res://tests/page_transition_qa.gd"
## Focused pause behavior through production input, process, save and lifecycle
## entry points. Fixture profiles remain in memory; no player-profile IO.

func live(area: String = "bakery"):
	var game = fixture(area)
	game.testing = false
	game.start_shift()
	game.step(.4)
	game.elapsed = 2.0
	game.note_time = 1.5
	game.bank_coin_feedback.age = .1
	game.run_coin_feedback.age = .2
	game.page_transition.enabled = true
	game.navigation_delay = 0
	return game

func frozen_state(game) -> Dictionary:
	return {
		"run":state(game), "rng":game.rng.state, "elapsed":game.elapsed,
		"checkpoint":game.checkpoint_clock, "ad":game.monetization.active_seconds,
		"bank_pulse":game.bank_coin_feedback.age, "run_pulse":game.run_coin_feedback.age,
		"guide_age":game.first_run_guide.age, "guide_revealed":game.first_run_guide.revealed,
		"note_time":game.note_time, "particles":game.particles.duplicate(true),
		"floats":game.floats.duplicate(true), "damage":game.impact_feedback.damage_labels.duplicate(true),
		"bucket_pulses":game.impact_feedback.bucket_times.duplicate(),
	}

func pause_by_button(game):
	game.navigation_delay = 0
	game.handle_press(Vector2(630,70))

func resume_by_button(game):
	game.navigation_delay = 0
	game.handle_press(Vector2(360,648))

func check_frozen(game, before: Dictionary, label: String):
	game.step(.13)
	game._physics_process(.13)
	check(equal(before,frozen_state(game)),label)

func ordered_fades_and_clocks():
	for area in ["bakery","gelato","crystal"]:
		var game = live(area)
		var previous_saves = game.saves
		pause_by_button(game)
		var pause = game.pause_transition
		check(game.mode == "paused" and pause.active and pause.phase == "opening" and not game.page_transition.active,area+" Pause starts a fade without cream")
		check(pause.menu_alpha == 0.0 and pause.blur_amount == 0.0,area+" opening starts with the unchanged clear board")
		check(game.saves == previous_saves+1 and not game.saved_run.is_empty(),area+" Pause checkpoints the current run exactly once")
		# An active guide would otherwise age while paused; it must freeze too.
		game.first_run_guide.active = true
		game.first_run_guide.step_id = "welcome"
		game.first_run_guide.age = .2
		var before = frozen_state(game)
		game._process(pause.OPEN_DURATION*.5)
		check(pause.menu_alpha > 0.0 and pause.menu_alpha < 1.0 and pause.blur_amount > 0.0 and pause.blur_amount < 1.0,area+" menu and slight blur enter together")
		check_frozen(game,before,area+" opening freezes live objects, RNG, clocks, feedback and guide")
		game._process(10.0)
		check(not pause.active and pause.menu_alpha == 1.0 and pause.blur_amount == 1.0,area+" opening settles on a sharp complete menu over full slight blur")
		check_frozen(game,before,area+" opening completion frame does not consume a stalled frame delta")
		game._process(.5)
		check_frozen(game,before,area+" settled pause keeps the background completely still")
		resume_by_button(game)
		check(game.mode == "play" and pause.active and pause.phase == "closing" and not game.page_transition.active,area+" Resume restores the same logical run while presentation remains blocked")
		check(game.run_serial == 1 and game.saves == previous_saves+1,area+" Resume creates neither a new attempt nor a second pause save")
		game._process(pause.MENU_OUT_DURATION*.5)
		check(pause.menu_alpha > 0.0 and pause.menu_alpha < 1.0 and pause.blur_amount == 1.0,area+" Resume first fades only the menu")
		check_frozen(game,before,area+" menu-out keeps the entire board and every clock frozen")
		game._process(pause.MENU_OUT_DURATION*.5)
		check(is_zero_approx(pause.menu_alpha) and is_equal_approx(pause.blur_amount,1.0),area+" blur remains at full strength when the menu has just disappeared")
		game._process(pause.BLUR_OUT_DURATION*.5)
		check(is_zero_approx(pause.menu_alpha) and pause.blur_amount > 0.0 and pause.blur_amount < 1.0,area+" blur fades only after the menu is gone")
		check_frozen(game,before,area+" blur-out cannot advance balls, pickups, timers or RNG")
		game._process(10.0)
		check(not pause.active and is_zero_approx(pause.menu_alpha) and is_zero_approx(pause.blur_amount),area+" Resume fully removes menu and blur")
		check_frozen(game,before,area+" resume completion frame cannot charge excess delta to gameplay")
		game._process(0.0)
		game.first_run_guide.active = false
		var elapsed = game.run_elapsed
		game.step(.1)
		check(game.run_elapsed > elapsed and game.remaining < before.run.remaining,area+" the next clean frame resumes the existing run normally")
		game.free()

func repeated_input():
	var game = live()
	pause_by_button(game)
	var before = frozen_state(game)
	var sound = game.sound_on
	var reduced = game.reduced_motion
	var saves = game.saves
	var escape = InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	for stage in ["opening","closing"]:
		game.navigation_delay = 0
		for point in [Vector2(360,648),Vector2(360,748),Vector2(360,848),Vector2(360,948),Vector2(630,70)]:
			game.handle_press(point)
			touch(game,point,true); touch(game,point,false)
		game.go_back(); game._input(escape); game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		game.start_shift()
		check(game.pause_transition.phase == stage and game.sound_on == sound and game.reduced_motion == reduced and game.saves == saves and game.run_serial == 1,"Repeated buttons, touches, Escape, system Back and direct start are blocked during "+stage)
		check(equal(before,frozen_state(game)),"Blocked "+stage+" input cannot mutate gameplay")
		if stage == "opening":
			settle(game)
			resume_by_button(game)
	game.free()

func interruptions_and_restore():
	for phase in ["opening","closing"]:
		for notification in [Node.NOTIFICATION_APPLICATION_PAUSED,Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_WM_CLOSE_REQUEST]:
			var game = live("gelato")
			pause_by_button(game)
			if phase == "closing": settle(game); resume_by_button(game)
			game._process(.05)
			var before = frozen_state(game)
			var saves = game.saves
			game._notification(notification)
			check(game.mode == "paused" and not game.pause_transition.active and not game.pause_transition.is_blocking() and game.pause_transition.menu_alpha == 1.0 and game.pause_transition.blur_amount == 1.0,"Lifecycle event settles a fully visible paused menu during "+phase+": "+str(notification))
			check(not game.page_transition.active and game.page_transition.enabled and game.saves == saves+1,"Lifecycle saves once and leaves no hidden cream/fade gate during "+phase+": "+str(notification))
			game._process(3)
			check_frozen(game,before,"Background time cannot resume a "+phase+" transition: "+str(notification))
			game.free()
	var original = live("crystal")
	var snapshot = original.RunSnapshot.capture(original)
	var restored = fixture("crystal")
	restored.page_transition.enabled = true
	check(restored.restore_active_run(snapshot),"Existing active snapshot restores successfully")
	check(restored.mode == "paused" and not restored.pause_transition.active and not restored.pause_transition.is_blocking() and restored.pause_transition.menu_alpha == 1.0 and restored.pause_transition.blur_amount == 1.0,"Restored runs show their fully settled pause without replaying the fade")
	check(equal(state(original),state(restored)),"Pause presentation adds no gameplay/save-schema drift")
	restored.page_transition.begin("studio","paused")
	check(restored.page_transition.active and restored.page_transition.from_mode == "studio" and not restored.pause_transition.active and restored.pause_transition.menu_alpha == 1.0,"Studio still cream-reveals an already settled restored pause")
	restored.page_transition.finish()
	restored.mode = "support"; restored.load_game()
	check(restored.mode == "paused" and not restored.pause_transition.active and not restored.pause_transition.is_blocking() and restored.pause_transition.menu_alpha == 1.0,"Load wrapper bypasses animations for chained restore mode writes")
	original.free(); restored.free()

func confirmation_and_other_routes():
	var game = live()
	pause_by_button(game); settle(game)
	var before = frozen_state(game)
	game.handle_press(Vector2(360,948))
	check(game.mode == "abandon_confirm" and not game.page_transition.active and not game.pause_transition.active and game.pause_transition.menu_alpha == 1.0 and game.pause_transition.blur_amount == 1.0,"End-shift confirmation replaces the pause panel over the same blurred board without cream")
	game._process(.3)
	check_frozen(game,before,"Confirmation keeps the board frozen")
	game.navigation_delay = 0; game.go_back()
	check(game.mode == "paused" and not game.page_transition.active and not game.pause_transition.active and game.pause_transition.blur_amount == 1.0,"Back from confirmation keeps a settled pause and its blur")
	game.navigation_delay = 0; game.handle_press(Vector2(360,948))
	game.navigation_delay = 0; game.handle_press(Vector2(360,698))
	check(game.mode == "result" and not game.page_transition.active and not game.pause_transition.active and is_zero_approx(game.pause_transition.menu_alpha) and is_zero_approx(game.pause_transition.blur_amount),"Finish-and-collect opens the result window with no residual pause blur or cream")
	game.mode = "support"
	check(game.page_transition.active and not game.pause_transition.active,"Ordinary menu navigation retains its cream transition")
	game.free()

func reduced_motion_and_controller_contract():
	var game = live()
	game.reduced_motion = true
	pause_by_button(game)
	check(not game.pause_transition.active and not game.pause_transition.is_blocking() and game.pause_transition.menu_alpha == 1.0 and game.pause_transition.blur_amount == 1.0,"Reduced Motion opens a static blurred pause immediately")
	resume_by_button(game)
	check(game.mode == "play" and not game.pause_transition.is_blocking() and is_zero_approx(game.pause_transition.menu_alpha) and is_zero_approx(game.pause_transition.blur_amount),"Reduced Motion Resume removes the overlay immediately")
	var elapsed = game.run_elapsed; game.step(.1)
	check(game.run_elapsed > elapsed,"Reduced Motion introduces no hidden gameplay delay")
	game.reduced_motion = false
	pause_by_button(game)
	var pause = game.pause_transition
	var values = [pause.time,pause.menu_alpha,pause.blur_amount,pause.phase]
	for invalid in [-1.0,0.0,NAN,INF]:
		pause.update(invalid)
		check(values == [pause.time,pause.menu_alpha,pause.blur_amount,pause.phase],"Invalid/nonpositive delta cannot corrupt pause presentation: "+str(invalid))
	game.reduced_motion = true; game._process(.01)
	check(not pause.active and pause.menu_alpha == 1.0 and pause.blur_amount == 1.0,"Enabling Reduced Motion during opening settles the visible pause")
	game.reduced_motion = false; settle(game); resume_by_button(game)
	game._process(.05)
	var before = frozen_state(game)
	game.reduced_motion = true; game._process(.01)
	check(not pause.active and is_zero_approx(pause.menu_alpha) and is_zero_approx(pause.blur_amount),"Enabling Reduced Motion during closing clears both visual layers")
	check_frozen(game,before,"Reduced Motion toggle cannot consume a transition completion-frame delta")
	game._process(0)
	game.page_transition.enabled = false; game.mode = "paused"
	check(not pause.active and not pause.is_blocking() and pause.menu_alpha == 1.0,"Disabled presentation still shows a settled readable pause")
	game.mode = "play"
	check(not pause.is_blocking() and is_zero_approx(pause.blur_amount),"Disabled presentation resumes without an invisible pause gate")
	game.free()

func _initialize():
	ordered_fades_and_clocks()
	repeated_input()
	interruptions_and_restore()
	confirmation_and_other_routes()
	reduced_motion_and_controller_contract()
	print("PAUSE_TRANSITION_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
