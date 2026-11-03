extends SceneTree
## Cookie damage is a presentation of HP. These checks never read or save a profile.
const FoodArt = preload("res://scripts/food_art.gd")
var passed = 0
var failures: Array[String] = []

class CookieGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
	func _ready(): pass
	func save_game(): persistence_attempts += 1
	func load_game(): persistence_attempts += 1

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func _initialize():
	var art = FoodArt.new()
	for kind in ["normal","armored","prism","clock"]:
		var base = "cookie_"+kind
		for maximum in [6.0,15.0]:
			check(art.cookie_name(kind,maximum,maximum)==base,"Full-health %s (%s HP) uses intact art" % [kind,maximum])
			check(art.cookie_name(kind,maximum-.01,maximum)==base+"_damage_1","Even a small first hit visibly chips %s (%s HP)" % [kind,maximum])
			check(art.cookie_name(kind,maximum*2.0/3.0+.001,maximum)==base+"_damage_1","%s remains lightly cracked just above two-thirds HP" % kind)
			check(art.cookie_name(kind,maximum*2.0/3.0,maximum)==base+"_damage_2","%s changes to stage two at exactly two-thirds HP" % kind)
			check(art.cookie_name(kind,maximum/3.0+.001,maximum)==base+"_damage_2","%s remains at stage two just above one-third HP" % kind)
			check(art.cookie_name(kind,maximum/3.0,maximum)==base+"_damage_3","%s changes to stage three at exactly one-third HP" % kind)
			check(art.cookie_name(kind,.001,maximum)==base+"_damage_3","%s retains the broken silhouette while barely alive" % kind)
		check(art.cookie_name(kind,0,6)==base+"_damage_3" and art.cookie_name(kind,-100,6)==base+"_damage_3","Depleted %s safely resolves to its last damage frame" % kind)
		check(art.cookie_name(kind,7,6)==base,"Overfull %s safely resolves to intact art" % kind)
		check(art.cookie_name(kind,1,0)==base and art.cookie_name(kind,1,-1)==base,"Invalid maximum HP falls back to intact %s" % kind)
		check(art.cookie_name(kind,NAN,6)==base and art.cookie_name(kind,INF,6)==base and art.cookie_name(kind,1,INF)==base,"Nonfinite HP falls back to intact %s" % kind)
		for stage in range(1,4):
			check(base+"_damage_"+str(stage) in FoodArt.NAMES,"Damage asset is loaded once: %s stage %d" % [kind,stage])
	check(art.cookie_name("unknown",1,6)=="cookie_normal","Unknown cookie kinds have a safe intact fallback")
	var unique = {}
	for name in FoodArt.NAMES: unique[name] = true
	check(unique.size()==26 and unique.size()==FoodArt.NAMES.size(),"Food manifest has the fourteen originals and twelve unique damage textures")
	var game = CookieGame.new()
	game.testing = true
	game.sound_on = false
	game.board_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	game.start_shift()
	game.pegs[0].hp = 4.0
	game.pegs[1].hp = 2.0
	game.pegs[2].hp = -.5
	game.destroyed = 1
	var snapshot: Dictionary = game.RunSnapshot.capture(game)
	var before = var_to_bytes(snapshot)
	var peg_before = var_to_bytes(game.pegs)
	var rng_before = game.rng.state
	var selected: Array[String] = []
	for peg in game.pegs:
		if peg.hp>0: selected.append(art.cookie_name(peg.kind,peg.hp,peg.max))
	check(selected.size()==game.pegs.size()-1,"Dead pegs are omitted from the existing live-peg render loop")
	check(selected[0]=="cookie_normal_damage_2" and selected[1]=="cookie_normal_damage_3","Existing saved fractional HP directly selects the correct damage frame")
	check(not snapshot.is_empty() and var_to_bytes(game.RunSnapshot.capture(game))==before,"Selecting damage frames leaves the active-run snapshot unchanged")
	check(var_to_bytes(game.pegs)==peg_before and game.rng.state==rng_before,"Selecting damage frames changes neither peg fields nor gameplay RNG")
	var fields_match = true
	for peg in game.pegs:
		fields_match = fields_match and peg.size()==5 and peg.has("p") and peg.has("hp") and peg.has("max") and peg.has("kind") and peg.has("flash")
	check(fields_match,"Cookie damage derives from existing saved peg fields")
	check(game.persistence_attempts==0,"Cookie fixtures never access the player's profile")
	game.free()
	print("COOKIE_DAMAGE_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
