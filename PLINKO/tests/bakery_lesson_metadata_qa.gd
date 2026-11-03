extends SceneTree
## Metadata-only run compatibility. In-memory fixtures; no player profile IO.
const Snapshot = preload("res://scripts/run_snapshot.gd")
var passed = 0
var failures: Array = []

class Fixture extends "res://scripts/main.gd":
	var reads = 0
	var writes = 0
	func _ready(): pass
	func load_game(): reads += 1
	func save_game(): writes += 1; return false
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func begin_automatic_ad(): pass

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture():
	var g=Fixture.new()
	g.testing=true; g.sound_on=false; g.first_run_guide.completed=true
	g.set_active_area("bakery")
	return g

func _initialize():
	var current=Snapshot.content_fingerprint("bakery")
	var previous=Snapshot.BAKERY_BRIEFS_PREVIOUS_FINGERPRINT
	check(current==Snapshot.BAKERY_BRIEFS_CURRENT_FINGERPRINT,"Current Bakery data matches the reviewed metadata-only hash")
	check(Snapshot.compatible_fingerprint(previous,current,"bakery"),"Previous active Bakery runs accepted by exact pair")
	check(not Snapshot.compatible_fingerprint(previous,"f".repeat(64),"bakery"),"Future content cannot inherit metadata exception")
	check(not Snapshot.compatible_fingerprint("e".repeat(64),current,"bakery"),"Unreviewed prior content remains rejected")
	check(not Snapshot.compatible_fingerprint(current,previous,"bakery"),"Metadata exception is forward-only")
	for area in ["gelato","crystal"]:
		check(not Snapshot.compatible_fingerprint(previous,current,area),"Bakery metadata exception cannot cross into "+area)
	var g=fixture()
	var briefs=[]
	var unique_briefs={}
	for board in g.board_data:
		briefs.append(board.trait_brief)
		unique_briefs[board.trait_brief]=true
	check(briefs.size()==12 and unique_briefs.size()==12,"Twelve distinct authored tray lessons loaded by production")
	for tray in [1,4,7,10,12]:
		g.current_level=tray; g.highest_unlocked=tray
		g.start_shift(); g.run_transition.finish()
		for frame in range(120): g.step(1.0/60.0)
		var snapshot=Snapshot.capture(g)
		check(not snapshot.is_empty(),"Active checkpoint captured on tray %d" % tray)
		var original=Snapshot.validate_and_decode(snapshot,g)
		snapshot.fingerprint=previous
		var legacy=Snapshot.validate_and_decode(snapshot,g)
		check(original.ok and legacy.ok and original.state==legacy.state,"Only fingerprint differs; decoded tray %d state identical" % tray)
		var restored=fixture()
		restored.highest_unlocked=tray; restored.current_level=tray
		check(restored.restore_active_run(snapshot),"Prior metadata checkpoint restores on tray %d" % tray)
		check(restored.pegs==g.pegs and restored.balls==g.balls and restored.rng.state==g.rng.state and restored.remaining==g.remaining,"Restored geometry/damage/balls/RNG/timer preserved")
		check(restored.reads==0 and restored.writes==0,"Metadata fixture does not access profiles")
		restored.free()
	check(g.reads==0 and g.writes==0,"Main metadata fixture does not access profiles")
	g.free()
	print("BAKERY_LESSON_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
