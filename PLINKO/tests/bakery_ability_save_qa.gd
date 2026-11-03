extends SceneTree
## Actual Bakery ability save/reload; requires a verified disposable user folder.
const Campaign=preload("res://scripts/area_campaign.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]
var save_path=""

class Fixture extends "res://scripts/main.gd":
	var fail_write=false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func legacy_profile_path() -> String: return ""
	func write_profile_file(data: Dictionary) -> bool:
		return false if fail_write else super.write_profile_file(data)

func check(value: bool,label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func same(a,b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not same(a[index],b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<.000001
	return a==b

func fixture():
	var g=Fixture.new()
	g.testing=true;g.sound_on=false;g.SAVE_FILE=save_path
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area("bakery");Campaign.apply_local(g,Campaign.default_record())
	g.mode="shop";g.shift_claimed=true;g.run_id=""
	g.current_level=8;g.highest_unlocked=8;g.levels[1]=4;g.bank=2300
	g.area_records={"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.area_records.gelato.bank=2345;g.area_records.crystal.bank=3456
	return g

func run():
	var g=fixture();g.testing=false
	check(g.save_game(),"Baseline ability profile writes to isolated disk")
	var before=FileAccess.get_file_as_bytes(save_path)
	g.fail_write=true
	check(not g.bakery_ability.buy() and g.bank==2300 and not g.bakery_jam_burst,"Actual failed write rolls back Bakery purchase")
	check(FileAccess.get_file_as_bytes(save_path)==before,"Failed purchase preserves saved bytes")
	g.fail_write=false
	check(g.bakery_ability.buy() and g.bank==1100,"Earned purchase saves its exact debit")
	var disk=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(disk.areas.bakery.bakery_jam_burst and disk.areas.bakery.ability_unlock_source=="earned","Disk owns Jam Burst with earned provenance")
	g.testing=true;g.start_shift();g.run_transition.finish()
	for index in range(5): g.spawn_ball(Vector2(360+index*8,267),"normal",Vector2(0,85),false)
	g.balls[4].used=true;g.balls[4].productive=true
	var expected=Snapshot.capture(g)
	check(expected.schema==6 and expected.bakery_run.normal_launches==5,"Live Bakery checkpoint includes charge progress")
	g.testing=false
	check(g.save_game(),"Charged/spent ball checkpoint writes through production profile path")
	var saved=FileAccess.get_file_as_bytes(save_path)
	var restored=fixture();restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and restored.bakery_jam_burst and restored.ability_unlock_source=="earned","New game restores earned ability and pauses its run")
	var actual=Snapshot.capture(restored)
	for key in expected:
		if not actual.has(key) or not same(actual[key],expected[key]): print("SNAPSHOT_MISMATCH ",key," expected=",expected[key]," actual=",actual.get(key))
	check(same(actual,expected),"Exact charge, spent flags, RNG, balls and timers survive disk roundtrip")
	check(restored.area_records.gelato.bank==2345 and restored.area_records.crystal.bank==3456,"Other areas retain independent money")
	check(FileAccess.get_file_as_bytes(save_path)==saved,"Loading does not rewrite a valid checkpoint")
	g.testing=true;restored.testing=true;restored.mode="play";restored.pause_transition.settle()
	for index in range(90):
		g.step(1.0/120.0);restored.step(1.0/120.0)
	check(same(Snapshot.capture(restored),Snapshot.capture(g)),"Resumed physics and charge continue identically to uninterrupted play")
	g.free();restored.free()

func _initialize():
	save_path=OS.get_environment("SUGARFALL_BAKERY_ABILITY_QA_SAVE")
	var expected=OS.get_user_data_dir().replace("\\","/")+"/"
	if save_path.is_empty() or not save_path.is_absolute_path() or not save_path.replace("\\","/").begins_with(expected) or "--bakery-ability-save-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Bakery ability disk QA requires its explicit isolated namespace and opt-in marker");quit(2);return
	run()
	print("BAKERY_ABILITY_SAVE_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
