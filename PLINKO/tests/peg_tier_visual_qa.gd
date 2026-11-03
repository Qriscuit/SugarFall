extends SceneTree
## Tests the shared tier presentation without altering textures or player saves.
const FoodArt = preload("res://scripts/food_art.gd")
const TIERS = ["bronze","silver","gold","diamond"]
var passed = 0
var failures: Array[String] = []

class RecordingArt extends "res://scripts/food_art.gd":
	var calls: Array = []
	var draw_succeeds = true
	func draw_centered(_game: CanvasItem, name: String, center: Vector2, size: Vector2, tint: Color = Color.WHITE) -> bool:
		calls.append({"name":name,"center":center,"size":size,"tint":tint})
		return draw_succeeds

class FixtureGame extends "res://scripts/main.gd":
	var profile_calls = 0
	func _ready(): pass
	func save_game():
		profile_calls += 1
		return false
	func load_game(): profile_calls += 1
	func write_profile_file(_data: Dictionary) -> bool:
		profile_calls += 1
		return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func palette_contract():
	var art = FoodArt.new()
	var unique = {}
	for tier in TIERS:
		var tint = art.tier_color(tier)
		unique[tint.to_html()] = true
		check(tint.a==1.0 and tint.r>0 and tint.g>0 and tint.b>0 and tint.r<=1 and tint.g<=1 and tint.b<=1,"%s tint preserves alpha and nonzero detail without overbright clipping" % tier)
		check(art.tier_label(tier)==tier.capitalize(),"%s has the expected readable tier name" % tier)
	check(unique.size()==4,"The four strength tiers have distinct colors")
	for neutral in ["","unsupported"]:
		check(art.tier_color(neutral)==Color.WHITE and art.tier_label(neutral)=="","Empty or unsupported tier leaves original presentation unchanged")
	check(FoodArt.NAMES.size()==26,"Tier colors require no additional texture names or generated raster variants")

func draw_dispatch_and_opacity():
	var art = RecordingArt.new()
	var canvas = Node2D.new()
	var center = Vector2(123,456)
	var size = Vector2(49,49)
	var caller_tint = Color(.8,.9,1,.35)
	for tier in TIERS:
		for kind in FoodArt.COOKIE_KINDS:
			for stage in range(4):
				var maximum = 24.0
				var hp = [24.0,20.0,12.0,4.0][stage]
				art.calls.clear()
				check(art.draw_cookie(canvas,kind,hp,maximum,center,size,tier,caller_tint),"%s %s damage stage %d forwards successful drawing" % [tier,kind,stage])
				var expected_name = "cookie_"+kind+("_damage_"+str(stage) if stage>0 else "")
				var single = art.calls.size()==1
				var call = art.calls[0] if single else {}
				check(single and call.get("name")==expected_name and call.get("center")==center and call.get("size")==size,"%s %s stage %d keeps its existing role/damage sprite, center and size" % [tier,kind,stage])
				var actual_tint: Color = call.get("tint",Color.TRANSPARENT)
				check(actual_tint.is_equal_approx(art.tier_color(tier)*caller_tint) and is_equal_approx(actual_tint.a,caller_tint.a),"%s %s stage %d composes caller feedback while retaining opacity" % [tier,kind,stage])
	for kind in FoodArt.COOKIE_KINDS:
		art.calls.clear()
		art.draw_cookie(canvas,kind,4,6,center,size)
		check(art.calls.size()==1 and art.calls[0].name=="cookie_"+kind+"_damage_2" and art.calls[0].tint==Color.WHITE,"No-tier %s retains the original Gelato/Trial tint and damage selection" % kind)
	for alpha in [0.0,.25,1.0]:
		art.calls.clear()
		art.draw_cookie(canvas,"normal",24,24,center,size,"diamond",Color(1,1,1,alpha))
		check(is_equal_approx(art.calls[0].tint.a,alpha),"Tier coloring retains caller alpha %.2f including fully transparent input" % alpha)
	art.calls.clear()
	art.draw_cookie(canvas,"unknown",4,6,center,size,"bronze")
	check(art.calls[0].name=="cookie_normal","Unknown peg role keeps the existing safe cookie fallback")
	art.draw_succeeds = false
	check(not art.draw_cookie(canvas,"normal",6,6,center,size,"gold"),"Missing-art failure is forwarded so the caller can retain its fallback")
	canvas.free()

func presentation_does_not_change_state():
	var art = RecordingArt.new()
	var game = FixtureGame.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	game.set_active_area("bakery")
	game.current_level = 12
	game.highest_unlocked = 12
	game.start_shift()
	game.pegs[0].hp = game.pegs[0].max*.5
	var before = var_to_bytes(game.RunSnapshot.capture(game))
	var pegs_before = var_to_bytes(game.pegs)
	var rng_before = game.rng.state
	var bank_before = game.bank
	for tier in TIERS:
		for peg in game.pegs:
			art.draw_cookie(game,peg.kind,peg.hp,peg.max,peg.p,Vector2(49,49),tier)
	check(var_to_bytes(game.RunSnapshot.capture(game))==before,"Tier presentation leaves the complete active-run snapshot unchanged")
	check(var_to_bytes(game.pegs)==pegs_before and game.rng.state==rng_before and game.bank==bank_before,"Tier presentation changes no peg fields, RNG or earned progression")
	check(game.profile_calls==0,"Tier visual fixtures never read or write a player profile")
	game.free()

func _initialize():
	palette_contract()
	draw_dispatch_and_opacity()
	presentation_does_not_change_state()
	print("PEG_TIER_VISUAL_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
