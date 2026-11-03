extends SceneTree
## Authored downward-fan geometry; fixture persistence never touches a profile.
const ORIGIN = Vector2(360,267)
const DESIGN_SPEED = 260.0
const DESIGN_GRAVITY = 400.0
const MAX_AIM_ANGLE = 70.0
const TIERS = ["bronze","silver","gold","diamond"]
const HP = [6.0,12.0,18.0,24.0]
var passed = 0
var failures: Array[String] = []

class FixtureGame extends "res://scripts/main.gd":
	var profile_calls = 0
	func _ready(): pass
	func load_game(): profile_calls += 1
	func save_game():
		profile_calls += 1
		return false
	func write_profile_file(_data: Dictionary) -> bool:
		profile_calls += 1
		return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func ballistic_path(point: Vector2) -> Dictionary:
	# Solve y=x*tan(a)+g*x^2/(2*v^2*cos(a)^2), a downward from horizontal.
	# This checks an aimable path to each center after foreground pegs clear,
	# not a claim that all targets are exposed simultaneously or human-tested.
	var dx = absf(point.x-ORIGIN.x)
	var dy = point.y-ORIGIN.y
	if dy<=0: return {"ok":false}
	if dx<.001: return {"ok":true,"angle":0.0}
	var a = DESIGN_GRAVITY*dx*dx/(2.0*DESIGN_SPEED*DESIGN_SPEED)
	var discriminant = dx*dx-4.0*a*(a-dy)
	if discriminant<0: return {"ok":false}
	var slope = (-dx+sqrt(discriminant))/(2.0*a)
	if slope<0: return {"ok":false}
	var from_horizontal = atan(slope)
	var angle = 90.0-rad_to_deg(from_horizontal)
	var time = dx/(DESIGN_SPEED*cos(from_horizontal))
	var reached_y = DESIGN_SPEED*sin(from_horizontal)*time+DESIGN_GRAVITY*time*time*.5
	return {"ok":angle<=MAX_AIM_ANGLE and absf(reached_y-dy)<.001,"angle":angle}

func _initialize():
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://data/gelato_board_design.json"))
	var origin = document.get("launcher_origin",[]) if document is Dictionary else []
	check(origin is Array and origin.size()==2 and Vector2(float(origin[0]),float(origin[1]))==ORIGIN,"Gelato authoring uses the fixed top-center nozzle")
	var game = FixtureGame.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	check(game.set_active_area("gelato") and game.board_data.size()==12,"Twelve complete launcher boards are available")
	var seen = {}
	var previous_count = 0
	for tray in range(1,13):
		game.current_level = tray
		game.highest_unlocked = 12
		game.start_shift()
		var spec: Dictionary = game.board_data[tray-1]
		var count = int(spec.peg_count)
		var band = floori((tray-1)/3.0)
		check(count>previous_count and count<=36 and spec.positions.size()==count,"Tray %d grows the peg roster within the authored limit" % tray)
		previous_count = count
		check(spec.strength_tier==TIERS[band] and spec.base_hp==HP[band],"Tray %d uses the agreed material and HP band" % tray)
		var key = JSON.stringify(spec.positions)
		check(not seen.has(key),"Tray %d has a distinct fixed arrangement" % tray)
		seen[key] = true
		var bounds_ok = true
		var clear_nozzles = true
		var aiming_ok = true
		var minimum_gap = INF
		var upper_count = 0
		var center_lane_open = true
		for index in range(count):
			var point: Vector2 = game.pegs[index].p
			bounds_ok = bounds_ok and point.x>=100 and point.x<=620 and point.y>=350 and point.y<=850
			for nozzle in [ORIGIN,Vector2(318,267),Vector2(402,267)]:
				clear_nozzles = clear_nozzles and point.distance_to(nozzle)>=80.0
			aiming_ok = aiming_ok and ballistic_path(point).ok
			if point.y<400:
				upper_count += 1
				center_lane_open = center_lane_open and absf(point.x-ORIGIN.x)>=65.0
			for other in range(index): minimum_gap = minf(minimum_gap,point.distance_to(game.pegs[other].p))
		check(bounds_ok and minimum_gap>=70.0,"Tray %d keeps readable spacing and the complete fan within the tray" % tray)
		check(clear_nozzles and upper_count>=2 and upper_count<=3 and center_lane_open,"Tray %d leaves the nozzle area and a central opening clear" % tray)
		check(aiming_ok,"Tray %d targets are ballistically reachable from the single launcher within seventy degrees" % tray)
		var roles_ok = true
		for index in range(count):
			var peg = game.pegs[index]
			if index<int(spec.armored_count): roles_ok = roles_ok and peg.kind=="armored" and peg.p.y>=700
			if index>=count-int(spec.clock_peg_count): roles_ok = roles_ok and peg.kind=="clock" and peg.p.y<=550
		check(roles_ok,"Tray %d places armor below the opening and clock targets in the early fan" % tray)
		var rng_before = game.rng.state
		var preview = game.home_menu.preview_pegs()
		var preview_matches = preview.size()==count
		for index in range(mini(preview.size(),count)):
			preview_matches = preview_matches and preview[index].p==game.pegs[index].p and preview[index].kind==game.pegs[index].kind
		check(preview_matches and game.rng.state==rng_before,"Tray %d Home preview uses the exact live arrangement without consuming RNG" % tray)
		var before = var_to_bytes(game.pegs)
		game.start_shift()
		check(var_to_bytes(game.pegs)==before,"Tray %d retry preserves authored positions and roles" % tray)
		var snapshot = game.RunSnapshot.capture(game)
		check(game.RunSnapshot.validate_and_decode(snapshot,game).get("ok",false),"Tray %d current launcher board survives checkpoint validation" % tray)
		if tray in [4,8,12]:
			check(spec.get("trial_base_hp")==6,"Trial %d has its separate six-HP baseline" % tray)
	check(game.profile_calls==0,"All launcher-layout checks avoid player profiles")
	game.free()
	print("GELATO_LAUNCHER_LAYOUT_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
