extends SceneTree
## First-run behavior checks. No player-profile IO: production _ready is bypassed,
## all persistence is captured in memory, and gameplay is stepped deterministically.
var passed = 0
var failures: Array[String] = []
var g

class GuideGame extends "res://scripts/main.gd":
	var save_attempts = 0
	var read_attempts = 0
	var writes = 0
	var saved_guide: Dictionary = {}
	var fail_save = false
	func _ready(): pass
	func save_game():
		save_attempts += 1
		if fail_save: return false
		saved_guide = first_run_guide.export_state().duplicate(true)
		return true
	func write_profile_file(_data: Dictionary) -> bool:
		writes += 1
		return true
	func load_game(): read_attempts += 1

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func fresh():
	if is_instance_valid(g):
		check(g.read_attempts == 0 and g.writes == 0,"Fixture performed no profile reads or disk writes")
		g.free()
	g = GuideGame.new()
	g.testing = true
	g.sound_on = false
	g.board_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.navigation_delay = 0
	g.reduced_motion = false

func touch(p: Vector2, pressed: bool, index: int = 0, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.position = g.to_global(p)
	event.pressed = pressed
	event.index = index
	event.canceled = canceled
	g._input(event)

func tap(p: Vector2):
	touch(p,true)
	touch(p,false)

func drag(p: Vector2, index: int = 0):
	var event = InputEventScreenDrag.new()
	event.position = g.to_global(p)
	event.relative = Vector2(90,0)
	event.index = index
	g._input(event)

func hover(p: Vector2):
	var event = InputEventMouseMotion.new()
	event.position = g.to_global(p)
	event.button_mask = 0
	g._input(event)

func reveal():
	g.first_run_guide.revealed = float(g.first_run_guide.dialogue().length())

func action():
	g.navigation_delay = 0
	g.result_input_delay = 0
	reveal()
	tap(g.first_run_guide.action_rect().get_center())

func sim_state() -> Array:
	return [g.remaining,g.run_elapsed,g.rng.state,g.spawn_clock,g.total_spawned,
		g.shift_coins,g.checkpoint_clock,g.monetization.active_seconds,g.monetization.attempts]

func begin_first_run():
	g.first_run_guide.begin()
	reveal()
	g.first_run_guide.advance()
	action()
	g._process(.6)
	g.navigation_delay = 0

func eligibility_and_dialogue():
	fresh()
	g.first_run_guide.import_state(null,true)
	g.first_run_guide.maybe_begin()
	check(g.first_run_guide.completed and not g.first_run_guide.active,"Legacy profiles do not unexpectedly enter the introduction")
	g.first_run_guide.import_state(null,false)
	g.first_run_guide.maybe_begin()
	check(g.first_run_guide.active and g.first_run_guide.step_id == "welcome","A new profile starts with Mabel's welcome")
	var bubble: Vector2 = g.first_run_guide.bubble_rect().get_center()
	touch(bubble,true)
	check(g.first_run_guide.step_id == "welcome" and g.first_run_guide.revealed == 0,"Dialogue does not advance on touch-down")
	touch(bubble,false)
	check(g.first_run_guide.step_id == "welcome" and g.first_run_guide._ready_text(),"First tap reveals the entire current line")
	tap(bubble)
	check(g.first_run_guide.step_id == "play" and g.mode == "home","Second tap advances to the real Play action")
	g.first_run_guide._set_step("welcome",false)
	g.first_run_guide.update(.2)
	check(g.first_run_guide.revealed > 0 and g.first_run_guide.revealed < g.first_run_guide.dialogue().length(),"Fast typewriter advances without automatically dismissing dialogue")
	g.profile_load_blocked = true
	g.first_run_guide.reset()
	g.first_run_guide.maybe_begin()
	check(not g.first_run_guide.active,"A profile recovery block cannot start an introduction")

func gesture_guards():
	fresh()
	g.first_run_guide.begin()
	reveal()
	var p: Vector2 = g.first_run_guide.bubble_rect().get_center()
	touch(p,true)
	touch(p,false,0,true)
	check(g.first_run_guide.step_id == "welcome","Canceled touches do not advance dialogue")
	touch(p,true)
	drag(p+Vector2(50,0))
	touch(p+Vector2(50,0),false)
	check(g.first_run_guide.step_id == "welcome","Dragging over the bubble does not become a tap")
	touch(p,true,4)
	touch(p+Vector2(20,0),true,8)
	touch(p+Vector2(20,0),false,8)
	touch(p,false,4)
	check(g.first_run_guide.step_id == "welcome","A second finger cancels pending dialogue activation")
	tap(Vector2(40,50))
	check(g.first_run_guide.step_id == "play" and g.mode == "home","A background tap advances the instruction without activating the Home control beneath it")

func tap_anywhere_dialogue():
	fresh()
	g.scale = Vector2(.625,.625)
	g.position = Vector2(24,18)
	var points = [Vector2(40,50),Vector2(680,1200),Vector2(48,700),g.home_menu.PLAY_RECT.get_center()]
	for point in points:
		g.first_run_guide.begin()
		touch(point,true)
		check(g.first_run_guide.step_id == "welcome" and g.first_run_guide.revealed == 0 and g.mode == "home","Anywhere touch-down waits for a stable release at %s" % point)
		touch(point,false)
		check(g.first_run_guide.step_id == "welcome" and g.first_run_guide._ready_text(),"First background tap reveals the line at transformed canvas point %s" % point)
		tap(point)
		check(g.first_run_guide.step_id == "play" and g.mode == "home" and g.run_id.is_empty() and g.run_serial == 0 and g.bank == 0,"Second background tap continues without dispatching underlying Home actions at %s" % point)
	# The Play control under the previous dialogue tap requires its own fresh gesture.
	action()
	check(g.mode == "play" and g.first_run_guide.step_id == "aim","A later deliberate Play tap still launches the real lesson")

	fresh()
	begin_first_run()
	var before = sim_state()
	var background = Vector2(40,50)
	tap(background)
	check(g.first_run_guide.step_id == "aim" and g.first_run_guide._ready_text(),"A tap outside the bubble reveals the aiming explanation")
	tap(background)
	check(g.first_run_guide.step_id == "aim_drag" and sim_state() == before,"Continuing the aiming explanation anywhere retains the required drag and frozen run")
	g.first_run_guide._set_step("earned",false)
	tap(background)
	check(g.first_run_guide.step_id == "earned" and g.first_run_guide._ready_text(),"First background tap reveals the earnings explanation")
	tap(background)
	check(g.first_run_guide.step_id == "playing" and sim_state() == before,"Second earnings tap returns to gameplay without advancing simulation or changing the award")

	fresh()
	g.mode = "shop"
	g.levels[0] = 1
	g.first_run_guide.active = true
	g.first_run_guide._set_step("improved",false)
	var play: Vector2 = g.upgrade_map.PLAY_RECT.get_center()
	tap(play)
	check(g.first_run_guide.step_id == "improved" and g.first_run_guide._ready_text() and g.mode == "shop","Tap over map Play first reveals the upgrade feedback")
	tap(play)
	check(g.first_run_guide.step_id == "again" and g.mode == "shop" and g.run_serial == 0,"Continuing upgrade feedback does not click through to the newly highlighted Play button")

func background_gesture_guards():
	fresh()
	g.first_run_guide.begin()
	reveal()
	var p = Vector2(40,50)
	touch(p,true)
	drag(p+Vector2(30,0))
	drag(p)
	touch(p,false)
	check(g.first_run_guide.step_id == "welcome","Dragging outside the bubble and returning to the start never becomes a dialogue tap")
	touch(p,true)
	touch(p,false,0,true)
	check(g.first_run_guide.step_id == "welcome","Canceled background releases cannot continue dialogue")
	touch(p,true,4)
	touch(p+Vector2(20,0),true,8)
	touch(p+Vector2(20,0),false,8)
	touch(p,false,4)
	check(g.first_run_guide.step_id == "welcome","Multiple background touches cancel dialogue even when both release inside the canvas")
	touch(p,true)
	g.navigation_delay = .25
	touch(p,false)
	check(g.first_run_guide.step_id == "welcome","A navigation guard that starts before release prevents background activation")
	g.navigation_delay = 0
	touch(p,true,0,true)
	touch(p,false)
	check(g.first_run_guide.step_id == "welcome","A canceled background press cannot become a valid release")
	tap(p)
	check(g.first_run_guide.step_id == "play","A fresh stable background tap succeeds after canceled gestures")

func action_lessons_require_actions():
	fresh()
	g.first_run_guide.begin()
	g.first_run_guide._set_step("play",false)
	var upgrades: Vector2 = g.home_menu.UPGRADES_RECT.get_center()
	tap(upgrades)
	check(g.first_run_guide._ready_text() and g.first_run_guide.step_id == "play","Background tapping can reveal an action lesson")
	tap(upgrades)
	check(g.first_run_guide.step_id == "play" and g.mode == "home" and g.run_serial == 0,"Further background taps cannot bypass Play or open the covered Upgrades control")
	g.first_run_guide._set_step("upgrades",false)
	tap(g.home_menu.PLAY_RECT.get_center())
	tap(g.home_menu.PLAY_RECT.get_center())
	check(g.first_run_guide.step_id == "upgrades" and g.mode == "home" and g.run_serial == 0,"The Upgrades lesson cannot be bypassed by tapping covered Home Play")

	fresh()
	g.mode = "shop"
	g.bank = 100
	g.upgrade_map.selected = 0
	g.upgrade_map.tier = 1
	g.first_run_guide.active = true
	g.first_run_guide._set_step("buy",false)
	tap(g.upgrade_map.PLAY_RECT.get_center())
	tap(g.upgrade_map.PLAY_RECT.get_center())
	check(g.first_run_guide.step_id == "buy" and g.mode == "shop" and g.bank == 100 and g.levels[0] == 0 and g.run_serial == 0,"Background taps in the Buy lesson neither purchase equipment nor start a run")
	var price: int = g.upgrade_cost(0)
	action()
	check(g.first_run_guide.step_id == "improved" and g.levels[0] == 1 and g.bank == 100-price,"The highlighted Buy action still performs one real purchase")

	fresh()
	g.start_shift()
	g.first_run_guide.active = true
	g.first_run_guide._set_step("collect",false)
	g.mode = "result"
	g.shift_coins = 20
	g.result_input_delay = 0
	g.navigation_delay = 0
	tap(Vector2(360,960))
	tap(Vector2(360,960))
	check(g.first_run_guide.step_id == "collect" and g.mode == "result" and g.bank == 0 and not g.shift_claimed,"Background taps cannot collect earnings or activate the covered result bonus control")

func explicit_controls_keep_priority():
	fresh()
	begin_first_run()
	g.first_run_guide.revealed = 0
	tap(g.first_run_guide.PAUSE_RECT.get_center())
	check(g.mode == "paused" and g.first_run_guide.step_id == "aim" and g.first_run_guide.revealed == 0,"Pause retains priority over anywhere dialogue and leaves its text untouched")
	g.navigation_delay = 0
	g.go_back()
	g._process(.3)
	tap(g.first_run_guide.SKIP_RECT.get_center())
	check(g.mode == "play" and g.first_run_guide.completed and not g.first_run_guide.active,"Skip retains priority over anywhere dialogue after resuming")

func freeze_and_aim():
	fresh()
	g.testing = false
	g.monetization.active_seconds = 17
	begin_first_run()
	check(g.mode == "play" and not g.run_transition.active and g.first_run_guide.step_id == "aim","Actual Home Play settles at the frozen aim lesson")
	var state = sim_state()
	var saves: int = g.save_attempts
	g.step(.5)
	g._physics_process(.5)
	g._process(.5)
	check(sim_state() == state,"Aim explanation freezes timer, RNG, spawns, earnings, checkpoint and ad clocks")
	check(g.save_attempts == saves,"Reading a lesson does not create timed checkpoints")
	reveal()
	g.first_run_guide.advance()
	reveal()
	var aim_before: float = g.aim_x
	tap(Vector2(350,500))
	check(g.first_run_guide.step_id == "aim_drag" and g.aim_x == aim_before,"A tap cannot satisfy the required aiming gesture")
	touch(Vector2(350,500),true)
	touch(Vector2(390,500),true,1)
	touch(Vector2(390,500),false,1)
	drag(Vector2(470,500))
	touch(Vector2(470,500),false)
	check(g.first_run_guide.step_id == "aim_drag" and g.aim_x == aim_before,"A second finger cancels the whole aiming gesture even after it lifts")
	touch(Vector2(350,500),true)
	drag(Vector2(710,500))
	drag(Vector2(470,500))
	touch(Vector2(470,500),false)
	check(g.first_run_guide.step_id == "aim_drag" and g.aim_x == aim_before,"Leaving the tray cancels the aiming gesture until a new contact")
	touch(Vector2(350,500),true)
	drag(Vector2(470,500))
	touch(Vector2(470,500),false)
	check(g.first_run_guide.step_id == "playing" and g.aim_x > aim_before,"A deliberate horizontal drag teaches aiming and starts real play")
	g.step(.3)
	check(g.total_spawned > 0 and g.run_elapsed > 0 and g.remaining < state[0],"The normal feeder and timer run after the aiming gesture")
	g.shift_coins = 1.0
	g.first_run_guide.update(.01)
	check(g.first_run_guide.step_id == "earned" and g.first_run_guide.earned_seen,"First earned coin triggers its explanation once")
	state = sim_state()
	g.step(1)
	g._process(1)
	check(sim_state() == state,"The earnings close-up freezes every gameplay clock")
	reveal()
	g.first_run_guide.advance()
	g.first_run_guide.update(.01)
	check(g.first_run_guide.step_id == "playing","Continuing earnings does not immediately repeat the same lesson")
	var skip: Vector2 = g.first_run_guide.SKIP_RECT.get_center()
	touch(Vector2(350,500),true)
	touch(skip,true,1)
	touch(skip,false,1)
	touch(Vector2(350,500),false)
	check(g.first_run_guide.active and not g.first_run_guide.completed,"Holding a board finger prevents a second finger from activating Skip during play")
	tap(skip)
	check(g.first_run_guide.completed and not g.first_run_guide.active,"After both fingers lift, a fresh single tap on Skip succeeds")

func complete_attempt():
	for frame in range(1800):
		if g.mode == "result": break
		if g.first_run_guide.step_id == "earned":
			reveal()
			g.first_run_guide.advance()
		elif g.first_run_guide.step_id == "time_pickup":
			hover(g.board_to_screen(g.first_run_guide.time_pickup_position()))
		g.step(1.0/60.0)
		g._process(1.0/60.0)

func real_loop():
	fresh()
	begin_first_run()
	reveal()
	g.first_run_guide.advance()
	reveal()
	touch(Vector2(300,500),true)
	drag(Vector2(360,500))
	touch(Vector2(360,500),false)
	var attempts = 0
	while attempts < 8 and g.levels[0] == 0:
		complete_attempt()
		check(g.mode == "result" and g.first_run_guide.step_id == "collect","A real timed attempt reaches the Collect lesson")
		if g.mode != "result": break
		var before: float = g.bank
		var payout: float = g.result_payout()
		action()
		check(g.mode == "home" and is_equal_approx(g.bank,g.round_credits(before+payout)),"Collect pays exactly the normal result, without a tutorial grant")
		attempts += 1
		if g.first_run_guide.step_id == "retry":
			check(g.bank < g.upgrade_cost(0),"Retry is selected only while Feed 1 is genuinely unaffordable")
			action()
			g._process(.6)
			continue
		check(g.first_run_guide.step_id == "upgrades","Sufficient earnings lead to Upgrades")
		action()
		check(g.mode == "shop" and g.first_run_guide.step_id in ["feed","buy"],"The normal upgrade map opens with its first recipe highlighted")
		if g.first_run_guide.step_id == "feed": action()
		check(g.first_run_guide.step_id == "buy","Selecting Feed 1 exposes its real purchase action")
		before = g.bank
		var price: int = g.upgrade_cost(0)
		action()
		check(g.levels[0] == 1 and is_equal_approx(g.bank,g.round_credits(before-price)),"Tutorial purchase spends the real Feed 1 price exactly once")
		check(g.first_run_guide.step_id == "improved","A successful real purchase triggers the improved-dispenser lesson")
		reveal()
		g.first_run_guide.advance()
		action()
		check(g.mode == "play" and g.first_run_guide.completed and not g.first_run_guide.active,"Playing the upgraded dispenser finishes the introduction")
		break
	check(g.levels[0] == 1,"The complete real-earnings loop reaches the first purchase")

func persistence_skip_and_replay():
	fresh()
	g.testing = false
	g.first_run_guide.begin()
	tap(g.first_run_guide.SKIP_RECT.get_center())
	check(g.first_run_guide.completed and not g.first_run_guide.active and g.saved_guide.completed,"Skip completes and persists the introduction without changing the campaign")
	var saved: Dictionary = g.first_run_guide.export_state()
	var envelope: Dictionary = g.profile_envelope(g.area_records,g.area_id,g.area_entries)
	var decoded = JSON.parse_string(JSON.stringify(envelope))
	var restored = preload("res://scripts/first_run_guide.gd").new(g)
	restored.import_state(decoded.get("onboarding",{}) if decoded is Dictionary else {},true)
	check(decoded is Dictionary and decoded.has("onboarding") and restored.export_state() == saved,"Campaign save envelope carries the complete onboarding state through JSON round-trip")
	g.first_run_guide.reset()
	g.first_run_guide.import_state(saved,true)
	g.first_run_guide.maybe_begin()
	check(g.first_run_guide.completed and not g.first_run_guide.active,"Completed guide stays completed after import")
	g.bank = 12.5
	g.levels[0] = 3
	g.mode = "guide"
	g.first_run_guide.replay()
	check(g.mode == "home" and g.first_run_guide.active and g.bank == 12.5 and g.levels[0] == 3,"Replay keeps existing coins and upgrades")
	g.first_run_guide.on_collected()
	check(g.first_run_guide.step_id == "improved","Replay recognizes an already-owned feeder without demanding another purchase")
	var unfinished = {"version":1,"active":true,"completed":false,"step":"buy","earned_seen":true}
	g.mode = "result"
	g.first_run_guide.import_state(unfinished,true)
	check(g.first_run_guide.step_id == "collect","A pending result is authoritative over stale tutorial state")
	g.mode = "home"
	g.first_run_guide.import_state(unfinished,true)
	check(g.first_run_guide.step_id == "again","Interrupted purchase resumes from owned equipment")
	g.levels[0] = 0
	g.bank = 0
	g.first_run_guide.import_state(unfinished,true)
	check(g.first_run_guide.step_id == "retry" and g.bank == 0,"Unaffordable interrupted lessons invite another run without inventing coins")
	g.first_run_guide.import_state({"version":1,"active":"yes","completed":false,"step":"buy"},true)
	check(not g.first_run_guide.active,"Malformed guide metadata cannot capture returning-player input")

func lifecycle_and_reduced_motion():
	fresh()
	g.testing = false
	begin_first_run()
	var unchanged = sim_state()
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(g.mode == "paused" and g.first_run_guide.step_id == "aim","Focus loss pauses the run while retaining the lesson")
	g._process(2)
	g._physics_process(2)
	check(sim_state() == unchanged,"Backgrounding a lesson does not consume the run")
	g.navigation_delay = 0
	g.go_back()
	check(g.mode == "play" and g.first_run_guide.blocks_simulation(),"Resume returns to the instruction before gameplay restarts")
	g.first_run_guide.import_state({"version":1,"active":true,"completed":false,"step":"aim_drag","earned_seen":false},true)
	check(g.first_run_guide.step_id == "aim_drag" and g.first_run_guide.active,"An unfinished aiming lesson survives checkpoint reconciliation")
	g.first_run_guide.finish()
	g.step(.1)
	check(g.run_elapsed > 0,"Skipping a frozen lesson releases the actual game")
	fresh()
	g.reduced_motion = true
	g.first_run_guide.begin()
	check(g.first_run_guide._ready_text(),"Reduced Motion shows dialogue immediately")
	g.first_run_guide.advance()
	action()
	check(g.mode == "play" and not g.run_transition.active and g.first_run_guide._ready_text(),"Reduced Motion skips entrance animation while retaining the readable lesson")

func floating_bubble_layout():
	fresh()
	g.first_run_guide.begin()
	var guide = g.first_run_guide
	var initial = guide.bubble_rect()
	guide.revealed = guide.dialogue().length()
	check(guide.bubble_rect() == initial,"Bubble geometry stays stable during text reveal")
	var portrait = guide.portrait_rect()
	guide._set_step("retry",false)
	check(guide.portrait_rect() == portrait,"Message length never resizes or shifts Mabel")
	var bubble = preload("res://scripts/speech_bubble.gd")
	var short_line = bubble.measure(g.font,g.display_font,"Hello!","Mabel","Tap to continue")
	var long_line = bubble.measure(g.font,g.display_font,"That's money in the making! Cookie hits earn coins. Clear the tray before time runs out. You keep your earnings either way.","Mabel","Tap to continue")
	check(short_line.size.x < long_line.size.x and short_line.size.y < long_line.size.y,"Short messages produce smaller bubbles in both dimensions")
	var narrower = bubble.measure(g.font,g.display_font,guide.dialogue(),"Mabel","Tap to continue",{"max_width":300.0,"padding":18.0})
	check(narrower.size.x <= 300,"Internal authoring options can reshape bubble width")
	var token = "extraordinarilylongunbrokenlocalizedwordwithoutspaces"
	var split = bubble.measure(g.font,g.display_font,token,"Mabel","Next",{"max_width":264.0})
	var reconstructed = ""
	var all_fit = true
	for line in split.lines:
		reconstructed += line
		all_fit = all_fit and g.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,split.font_size).x <= split.size.x-split.padding*2+.1
	check(all_fit and reconstructed == token and split.starts.back()+split.lines.back().length()==token.length(),"Long words wrap without clipping or dropping revealed characters")

func stage_time_pickup():
	fresh()
	g.testing = false
	g.start_shift()
	g.first_run_guide.active = true
	g.first_run_guide.completed = false
	g.first_run_guide.earned_seen = true
	g.first_run_guide._set_step("playing",false)
	g.pickup_clock = .01
	g.step(.02)
	g.navigation_delay = 0

func time_pickup_freeze_and_hover():
	stage_time_pickup()
	var guide = g.first_run_guide
	check(guide.step_id == "time_pickup" and guide.blocks_simulation() and g.pickups.size() == 1,"The first real time-pickup spawn opens its mandatory collection lesson")
	if g.pickups.is_empty(): return
	check(is_equal_approx(float(g.pickups[0].life),4.0),"The spawned pickup freezes before consuming any of its four-second lifetime")
	var state = sim_state()
	var pickups: Array = g.pickups.duplicate(true)
	var saves: int = g.save_attempts
	g.step(8)
	g._physics_process(8)
	g._process(8)
	check(sim_state() == state and g.pickups == pickups,"Time-pickup instruction freezes physics, all gameplay clocks and the pickup's lifetime")
	check(g.save_attempts == saves,"Reading the time-pickup lesson does not create timed save checkpoints")
	var before: float = g.remaining
	var bonus: float = g.time_bonus
	var center: Vector2 = guide.time_pickup_position()
	hover(g.board_to_screen(center+Vector2(70,0)))
	check(guide.step_id == "time_pickup" and g.remaining == before and g.time_bonus == bonus,"Hovering outside the pickup cannot grant time or advance the lesson")
	for keycode in [KEY_SPACE,KEY_ENTER]:
		var key = InputEventKey.new(); key.pressed = true; key.keycode = keycode
		g._input(key)
	reveal(); tap(guide.bubble_rect().get_center())
	check(guide.step_id == "time_pickup" and not guide.time_pickup_seen and g.remaining == before,"Keyboard and dialogue taps cannot bypass the required pickup collection")
	tap(Vector2(40,50)); tap(Vector2(40,50))
	check(guide.step_id == "time_pickup" and not guide.time_pickup_seen and g.pickups == pickups and g.remaining == before,"Anywhere background taps reveal the pickup instruction without collecting or expiring its target")
	g.scale = Vector2(.625,.625)
	g.position = Vector2(24,18)
	guide.revealed = 0.0
	hover(g.board_to_screen(center))
	check(guide.step_id == "playing" and guide.time_pickup_seen and not guide.blocks_simulation(),"A no-button mouse hover collects the real pickup through board, scale and offset transforms")
	check(is_equal_approx(g.remaining,before+2.0) and is_equal_approx(g.time_bonus,bonus+2.0) and g.pickups[0].life == 0,"Collection grants exactly the normal two-second pickup effect")
	check(g.saved_guide.get("time_pickup_seen",false) == true,"Successful pickup collection persists the completed lesson")
	hover(g.board_to_screen(center)); tap(g.board_to_screen(center))
	check(is_equal_approx(g.remaining,before+2.0) and is_equal_approx(g.time_bonus,bonus+2.0),"Repeated hover, tap and release cannot collect the same pickup twice")
	g.step(.1)
	check(g.remaining < before+2.0 and g.pickups.is_empty(),"Real gameplay and normal spent-pickup cleanup resume after collection")
	g.pickups = [{"p":center,"life":4.0}]
	check(not guide.on_time_pickup_spawned() and guide.step_id == "playing","Later pickups do not reopen an already completed lesson")

func time_pickup_touch_and_cap():
	stage_time_pickup()
	var center: Vector2 = g.board_to_screen(g.first_run_guide.time_pickup_position())
	var before: float = g.remaining
	touch(center,true)
	check(g.first_run_guide.time_pickup_seen and g.first_run_guide.step_id == "playing" and is_equal_approx(g.remaining,before+2),"Touch-down on the pickup collects it using the game's normal immediate interaction")
	touch(center,false)
	check(is_equal_approx(g.remaining,before+2),"The following touch release cannot grant the time again")
	stage_time_pickup()
	center = g.board_to_screen(g.first_run_guide.time_pickup_position())
	before = g.remaining
	g.time_bonus = 2.5
	# Start on the canvas: this deterministic pickup spawns near the left edge.
	var miss = center+Vector2(95 if center.x < 360 else -95,0)
	touch(miss,true)
	check(g.first_run_guide.step_id == "time_pickup","Touching elsewhere keeps the pickup lesson active")
	drag(center)
	check(g.first_run_guide.time_pickup_seen and g.first_run_guide.step_id == "playing" and is_equal_approx(g.remaining,before+.5) and is_equal_approx(g.time_bonus,3.0),"Dragging onto the pickup collects it while respecting the shared three-second bonus cap")
	touch(center,false)
	check(is_equal_approx(g.remaining,before+.5),"Capped pickup collection is still exactly once")
	stage_time_pickup()
	center = g.board_to_screen(g.first_run_guide.time_pickup_position())
	miss = center+Vector2(95 if center.x < 360 else -95,0)
	touch(miss,true,4); touch(center,true,8); touch(center,false,8)
	drag(center,4); touch(center,false,4)
	check(g.first_run_guide.step_id == "time_pickup" and not g.first_run_guide.time_pickup_seen and g.time_bonus == 0,"A second finger cancels pickup dragging until a fresh single contact")
	touch(center,true); touch(center,false)
	check(g.first_run_guide.time_pickup_seen,"A fresh contact can collect after the canceled multi-touch gesture")
	stage_time_pickup()
	var point: Vector2 = g.first_run_guide.time_pickup_position()
	g.first_run_guide._set_step("earned",false)
	check(not g.first_run_guide.on_time_pickup_spawned() and g.first_run_guide.step_id == "earned","A live pickup cannot overwrite an earnings explanation already on screen")
	g.collect_pickups(point)
	check(g.pickups[0].life == 4 and not g.first_run_guide.time_pickup_seen and g.time_bonus == 0,"The pickup cannot be collected through another blocking explanation")
	reveal(); g.first_run_guide.advance(); g.first_run_guide.update(.01)
	check(g.first_run_guide.step_id == "time_pickup","The waiting live pickup receives its instruction after the earnings explanation finishes")

func time_pickup_persistence_and_reset():
	stage_time_pickup()
	var saved: Dictionary = g.first_run_guide.export_state().duplicate(true)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(g.RunSnapshot.capture(g)))
	var point: Vector2 = g.first_run_guide.time_pickup_position()
	check(saved.get("time_pickup_seen",true) == false and saved.step == "time_pickup","An unfinished pickup lesson exports its new field without claiming completion")
	fresh()
	check(g.restore_active_run(snapshot),"A checkpoint made during the pickup lesson remains a valid resumable run")
	g.first_run_guide.import_state(saved,true)
	check(g.mode == "paused" and g.first_run_guide.step_id == "time_pickup" and g.first_run_guide.time_pickup_position() == point,"Restoring paused gameplay retains the pickup lesson and its actual target")
	var state = sim_state()
	var pickups: Array = g.pickups.duplicate(true)
	g.collect_pickups(point)
	check(sim_state() == state and g.pickups == pickups,"Paused gameplay cannot collect a saved pickup behind the pause overlay")
	g._process(6); g._physics_process(6)
	check(sim_state() == state and g.pickups == pickups,"The restored paused lesson does not expire its target in the background")
	g.navigation_delay = 0; g.go_back()
	check(g.mode == "play" and g.first_run_guide.blocks_simulation(),"Resume returns to the live target's instruction before the timer can continue")
	g._process(.3)
	hover(g.board_to_screen(point))
	var completed: Dictionary = g.first_run_guide.export_state().duplicate(true)
	check(completed.get("time_pickup_seen",false) == true and completed.step == "playing","Resumed collection records the lesson as complete")
	var collected_snapshot: Dictionary = JSON.parse_string(JSON.stringify(g.RunSnapshot.capture(g)))
	var collected_remaining: float = g.remaining
	var collected_bonus: float = g.time_bonus
	fresh()
	check(g.restore_active_run(collected_snapshot),"A JSON checkpoint immediately after collection validates its zero-life pickup and increased timer")
	g.first_run_guide.import_state(completed,true)
	g.navigation_delay = 0; g.go_back()
	g._process(.3)
	hover(g.board_to_screen(point))
	check(is_equal_approx(g.remaining,collected_remaining) and is_equal_approx(g.time_bonus,collected_bonus) and g.first_run_guide.time_pickup_seen and g.first_run_guide.step_id == "playing","Restoring the spent pickup preserves its added time and cannot award a second collection")
	g.pickups = [{"p":point,"life":4.0}]
	check(not g.first_run_guide.on_time_pickup_spawned(),"A completed pickup lesson remains completed after metadata import")
	g.pickups = []
	g.first_run_guide.import_state(saved,true)
	check(g.first_run_guide.step_id == "playing" and not g.first_run_guide.blocks_simulation(),"A restored pickup lesson without a live target recovers to playable gameplay")
	g.pickups = [{"p":point,"life":0.0}]
	g.mode = "paused"
	g.first_run_guide.import_state(saved,true)
	check(g.first_run_guide.step_id == "playing","An expired saved pickup cannot trap the player in a collection lesson")
	var old_schema = {"version":1,"active":true,"completed":false,"step":"playing","earned_seen":true}
	g.first_run_guide.import_state(old_schema,true)
	check(not g.first_run_guide.time_pickup_seen,"Existing version-one guide saves default the new pickup lesson flag to unseen")
	g.mode = "guide"; g.bank = 12.5; g.levels[0] = 2
	g.first_run_guide.time_pickup_seen = true
	g.first_run_guide.replay()
	check(not g.first_run_guide.time_pickup_seen and g.first_run_guide.step_id == "welcome" and g.bank == 12.5 and g.levels[0] == 2,"Help replay teaches the pickup again while preserving progression")
	g.first_run_guide.time_pickup_seen = true
	g.reset_profile_runtime()
	check(not g.first_run_guide.time_pickup_seen,"Progress reset clears the pickup lesson alongside the other introduction state")
	stage_time_pickup()
	var before: float = g.remaining
	tap(g.first_run_guide.SKIP_RECT.get_center())
	check(g.first_run_guide.completed and not g.first_run_guide.active and not g.first_run_guide.blocks_simulation() and g.remaining == before and g.time_bonus == 0,"Skip exits the pickup lesson without awarding uncollected bonus time")
	g.step(.1)
	check(g.run_elapsed > .02 and g.pickups[0].life < 4,"Skipped instruction releases gameplay and the remaining pickup lifetime")

func purchase_save_transaction():
	fresh()
	g.mode="shop"; g.bank=100
	g.first_run_guide.active=true; g.first_run_guide.completed=false
	g.first_run_guide._set_step("buy",false)
	g.testing=false
	var price=g.upgrade_cost(0)
	check(g.buy_upgrade_node(0,1) and g.levels[0]==1 and g.bank==100-price,"Bakery tutorial purchase commits its real upgrade and wallet together")
	check(g.save_attempts==1 and g.saved_guide.step=="improved" and g.saved_guide.upgraded_this_intro,"The purchase save already contains the advanced onboarding step")
	fresh()
	g.mode="shop"; g.bank=100; g.note="Prior note"; g.note_time=2.5
	g.first_run_guide.active=true; g.first_run_guide.completed=false
	g.first_run_guide._set_step("buy",false)
	var guide_before=g.first_run_guide.export_state()
	g.testing=false; g.fail_save=true
	check(not g.buy_upgrade_node(0,1),"A failed tutorial purchase write reports failure")
	check(g.levels[0]==0 and g.bank==100 and g.equipped.is_empty() and g.first_run_guide.export_state()==guide_before and g.note=="Prior note" and g.note_time==2.5,"Failed tutorial purchase restores wallet, build, onboarding and existing feedback")
	g.fail_save=false
	check(g.buy_upgrade_node(0,1) and g.levels[0]==1 and g.bank==100-price and g.saved_guide.step=="improved","A deliberate retry buys once and persists the recovered onboarding step")

func _initialize():
	eligibility_and_dialogue()
	gesture_guards()
	tap_anywhere_dialogue()
	background_gesture_guards()
	action_lessons_require_actions()
	explicit_controls_keep_priority()
	freeze_and_aim()
	real_loop()
	persistence_skip_and_replay()
	purchase_save_transaction()
	lifecycle_and_reduced_motion()
	floating_bubble_layout()
	time_pickup_freeze_and_hover()
	time_pickup_touch_and_cap()
	time_pickup_persistence_and_reset()
	if is_instance_valid(g):
		check(g.read_attempts == 0 and g.writes == 0,"Final fixture performed no profile IO")
		g.free()
	print("FIRST_RUN_GUIDE_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
