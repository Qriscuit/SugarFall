extends "res://tests/gelato_upgrade_map_qa.gd"
## Temporal presentation checks use real map states and intercept every save.

class RecordedMap extends "res://scripts/upgrade_map.gd":
	var redraws = 0
	func _request_redraw(): redraws += 1

func pulse_game(area: String):
	var game = fresh(area)
	game.upgrade_map = RecordedMap.new(game)
	game.upgrade_map.reset_view_state()
	game.upgrade_map.update(0)
	game.upgrade_map.redraws = 0
	return game

func geometry(map) -> Array:
	var ordinary = []
	for node in map.visible_nodes(): ordinary.append(map.node_rect(node.x,node.y,false))
	return [map.point(8,1),map.node_rect(8,1,false),map.card_rect(),map.buy_rect(),map.paid_rect(),ordinary,map.pan,map.zoom]

func pulse_checks():
	for area in ["bakery","gelato","crystal"]:
		var game = pulse_game(area)
		var map = game.upgrade_map
		var campaign = game.AreaCampaign.capture_local(game).duplicate(true)
		var rng_before = game.rng.state
		var before = geometry(map)
		var rest = map.signature_highlight()
		check(rest.visible and map.state_for(8,1)=="locked",area+" locked signature is highlighted beneath the first upgrade")
		check(rest.rect.get_center().is_equal_approx(map.point(8,1)) and rest.rect.encloses(rest.base),area+" backdrop is centered behind the existing node")
		var previous: float = rest.rect.size.x
		var increasing = true
		for step in range(30):
			check(map.update(map.SIGNATURE_PULSE_DURATION/60.0),area+" visible pulse invalidates the shop frame")
			var width: float = map.signature_highlight().rect.size.x
			increasing = increasing and width >= previous-.001
			previous = width
		var peak = map.signature_highlight()
		check(increasing and peak.rect.size.x>rest.rect.size.x*1.10 and peak.opacity>rest.opacity,area+" background grows smoothly to a brighter peak")
		var decreasing = true
		for step in range(30):
			map.update(map.SIGNATURE_PULSE_DURATION/60.0)
			var width: float = map.signature_highlight().rect.size.x
			decreasing = decreasing and width <= previous+.001
			previous = width
		check(decreasing and is_equal_approx(previous,rest.rect.size.x),area+" background shrinks smoothly to its resting size")
		check(geometry(map)==before and game.AreaCampaign.capture_local(game)==campaign and game.rng.state==rng_before,area+" pulse leaves node art bounds, controls, camera, economy and RNG unchanged")
		for node in map.visible_nodes():
			if node!=map.TWIN_NODE: check(not peak.rect.intersects(map.node_rect(node.x,node.y,false)),area+" peak backdrop clears neighboring node "+str(node))
		map._signature_pulse_age = 0
		for frame in range(60): map.update(.5/60.0)
		var sixty = map.signature_highlight()
		map._signature_pulse_age = 0
		for frame in range(30): map.update(.5/30.0)
		var thirty = map.signature_highlight()
		check(sixty.rect.is_equal_approx(thirty.rect) and is_equal_approx(sixty.opacity,thirty.opacity),area+" pulse timing is independent of frame rate")
		var age: float = map._signature_pulse_age
		map.redraws = 0
		for delta in [0.0,-1.0,NAN,INF]: check(not map.update(delta),area+" invalid/zero delta does not churn a stable map")
		check(map._signature_pulse_age==age and map.redraws==0,area+" invalid deltas neither move nor redraw the backdrop")
		game.reduced_motion = true
		check(map.update(0),area+" enabling Reduced Motion invalidates once immediately")
		var reduced = map.signature_highlight()
		map.redraws = 0
		for frame in range(10): check(not map.update(.2),area+" Reduced Motion keeps the idle map quiet")
		check(map.signature_highlight()==reduced and map.redraws==0,area+" Reduced Motion preserves a steady visible highlight")
		game.reduced_motion = false;map.update(0)
		game.audio_application_paused = true;map.update(0)
		age = map._signature_pulse_age;map.redraws = 0
		check(not map.update(.7) and map._signature_pulse_age==age and map.redraws==0,area+" background suspension freezes pulse and idle redraw")
		game.audio_application_paused = false;game.audio_focus_lost = true;map.update(0)
		check(not map.update(.7) and map._signature_pulse_age==age,area+" focus loss freezes the pulse")
		game.audio_focus_lost = false;map.update(0)
		map.pan += Vector2(100000,100000);map.update(0)
		age = map._signature_pulse_age;map.redraws = 0
		check(not map.signature_highlight().visible and not map.update(.7) and map._signature_pulse_age==age and map.redraws==0,area+" offscreen signature stops animating and requesting redraw")
		map.reset_view_state();map.update(0)
		game.highest_unlocked = 8;game.levels[1] = 6 if area=="gelato" else 4
		if area=="gelato": stage_legacy_counts(game,game.levels)
		game.bank = 0;map.update(map.FEEDBACK_DURATION)
		check(map.state_for(8,1)=="unaffordable" and map.signature_highlight().visible and map.update(.1),area+" unaffordable signature still pulses without changing its gate")
		map._signature_pulse_age = .6
		var unowned_opacity: float = map.signature_highlight().opacity
		game.bank = game.ability_ui.cost()
		check(game.ability_ui.controller().buy(),area+" existing earned purchase remains available")
		map.update(map.FEEDBACK_DURATION);map._signature_pulse_age = .6
		check(map.state_for(8,1)=="owned" and is_equal_approx(map.signature_highlight().opacity,unowned_opacity*.5) and map.update(.1),area+" owned signature retains a subdued pulse")
		game.note_time = 8
		check(map.map_input_at(Vector2(360,1220)) and not map.overlay_at(Vector2(360,1220)),area+" obsolete notification state cannot block bottom map input")
		map.zoom = map.minimum_zoom();map.pan = Vector2.ZERO
		map._signature_pulse_age = map.SIGNATURE_PULSE_DURATION*.5
		var compact = map.signature_highlight()
		for node in map.visible_nodes():
			if node!=map.TWIN_NODE: check(not compact.rect.intersects(map.node_rect(node.x,node.y,false)),area+" overview highlight clears compact neighboring tile "+str(node))
		game.mode = "home";map.update(.1);map.redraws = 0
		check(not map.update(.7) and map._signature_pulse_age==0 and not map.signature_highlight().visible and map.redraws==0,area+" leaving the shop resets pulse and stays idle")
		check(game.profile_io==0,area+" pulse checks never read or write a player profile")
		game.free()

func _initialize():
	pulse_checks()
	print("UPGRADE_PULSE_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
