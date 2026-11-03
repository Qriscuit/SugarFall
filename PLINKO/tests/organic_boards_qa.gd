extends SceneTree
## Board geometry and continuity checks. Player persistence is never used.
var passed = 0
var failures: Array[String] = []

class FixtureGame extends "res://scripts/main.gd":
	var profile_calls = 0
	func _ready(): pass
	func load_game(): profile_calls += 1
	func save_game(): return true
	func write_profile_file(_data: Dictionary) -> bool:
		profile_calls += 1
		return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	var g = FixtureGame.new()
	g.testing = true
	g.sound_on = false
	var seen = {}
	for area in ["bakery","gelato"]:
		check(g.set_active_area(area) and g.board_data.size()==12,area+" has twelve complete board specifications")
		for level in range(1,13):
			g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
			g.current_level=level
			g.highest_unlocked=12
			g.start_shift()
			g.run_transition.finish()
			var spec: Dictionary = g.board_data[level-1]
			var count: int = int(spec.peg_count)
			var layout_key = JSON.stringify(spec.positions)
			check(not seen.has(layout_key),"%s tray %d has its own arrangement" % [area,level])
			seen[layout_key]=true
			var valid = g.pegs.size()==count and spec.positions.size()==count
			var minimum_gap = INF
			for i in range(count):
				var p: Vector2 = g.pegs[i].p
				valid = valid and p.x>=90 and p.x<=630 and p.y>=345 and p.y<=(850 if area=="gelato" else 805)
				for j in range(i): minimum_gap=minf(minimum_gap,p.distance_to(g.pegs[j].p))
			check(valid and minimum_gap>=70,"%s tray %d keeps every peg in bounds and separates visible food" % [area,level])
			var rng_before = g.rng.state
			var preview: Array = g.home_menu.preview_pegs()
			var matches = preview.size()==count
			for i in range(count): matches=matches and preview[i].p==g.pegs[i].p and preview[i].kind==g.pegs[i].kind
			check(matches and g.rng.state==rng_before,"%s tray %d Home previews exact positions/roles without consuming gameplay RNG" % [area,level])
			var first = g.pegs.duplicate(true)
			g.start_shift()
			g.run_transition.finish()
			check(first==g.pegs,"%s tray %d retry keeps its readable layout stable" % [area,level])
			var snapshot = g.RunSnapshot.capture(g)
			var decoded = g.RunSnapshot.validate_and_decode(JSON.parse_string(JSON.stringify(snapshot)),g)
			check(decoded.get("ok",false),"%s tray %d current irregular arrangement survives checkpoint validation" % [area,level])
		g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
		g.mode="home"
		var earned = 0.0
		for attempt in range(3):
			g.start_shift()
			g.run_transition.finish()
			for frame in range(3000):
				if g.mode!="play": break
				g.step(1.0/60.0)
			earned+=g.shift_coins
			check(g.mode=="result" and g.shift_coins>0,"%s fresh idle attempt %d lands hits and reaches a result" % [area,attempt+1])
			g.collect_reward(false)
		check(earned>=g.upgrade_cost(0),area+" first Feed remains reachable within three no-ad idle attempts")
	check(g.profile_calls==0,"All geometry checks avoid player profile reads/writes")
	print("ORGANIC_BOARDS_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	g.free()
	quit(0 if failures.is_empty() else 1)
