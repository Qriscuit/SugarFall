extends SceneTree
## Actual JSON save/reload in the caller's verified disposable namespace only.
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

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func equal(a,b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not equal(a[index],b[index]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<.000001
	return a==b

func fixture():
	var g=Fixture.new()
	g.testing=true;g.sound_on=false;g.SAVE_FILE=save_path
	g.set_active_area("crystal");Campaign.apply_local(g,Campaign.default_record())
	g.first_run_guide.active=false;g.first_run_guide.completed=true
	g.mode="shop";g.shift_claimed=true;g.run_id=""
	g.highest_unlocked=8;g.current_level=6;g.bank=3456;g.levels=[3,4,2,1,1,1,2,3];g.equipped=["ricochet","splitter"]
	g.area_records={"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.area_records.bakery.bank=1234;g.area_records.bakery.levels=[2,1,0,0,0,0,1,0]
	g.area_records.gelato.bank=2345;g.area_records.gelato.levels=[1,2,1,0,0,0,1,1]
	g.area_records.gelato.merge(Campaign.legacy_gelato_shop_state(g.area_records.gelato.levels,false,0),true)
	return g

func disk() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(save_path))

func purchase_and_campaign():
	var g=fixture();g.testing=false
	check(g.save_game(),"Actual profile5 writes to the isolated file")
	var bytes=FileAccess.get_file_as_bytes(save_path);var bank=g.bank
	g.fail_write=true
	check(not g.crystal_launcher.buy() and g.bank==bank and not g.crystal_second_prism,"Failed actual purchase write restores Crystal wallet and Second Prism")
	check(FileAccess.get_file_as_bytes(save_path)==bytes,"Failed purchase leaves saved profile bytes unchanged")
	g.fail_write=false
	check(g.crystal_launcher.buy() and g.bank==bank-900 and g.crystal_second_prism,"Successful Second Prism purchase commits its exact900-coin debit")
	var record=disk()
	check(record.version==5 and record.active_area_id=="crystal" and record.areas.size()==3,"Profile5 persists all three area records with Crystal active")
	check(record.areas.crystal.crystal_second_prism and equal(record.areas.crystal.levels,g.levels),"Disk record stores Second Prism ownership and every Crystal upgrade")
	var restored=fixture();restored.load_game()
	check(restored.area_id=="crystal" and restored.mode=="home" and restored.crystal_second_prism and restored.bank==bank-900 and restored.levels==g.levels,"Fresh game reloads the committed Crystal campaign")
	check(equal(restored.area_records.bakery,record.areas.bakery) and equal(restored.area_records.gelato,record.areas.gelato),"Reload preserves independent Bakery and Gelato wallets and upgrades exactly")
	check(not restored.profile_load_blocked,"Valid three-area profile remains writable")
	restored.free();g.free()

func active_checkpoint():
	var g=fixture();g.crystal_second_prism=true
	g.start_shift();g.run_transition.finish()
	g.spawn_ball(Vector2(360,300),"normal",Vector2(50,330))
	g.spawn_ball(Vector2(500,350),"impact",Vector2(-100,310))
	g.balls[1].used=true;g.balls[1].productive=true;g.balls[1].cool=.04
	g.run_elapsed=3.0;g.crystal_launcher.advance(0)
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position) and g.balls.size()==4,"Real first Prism produces a cloned live-ball state before saving")
	g.run_elapsed=7.5;g.crystal_launcher.advance(0)
	g.run_elapsed=8.25;g.crystal_launcher.advance(0)
	g.remaining=g.BASE_SECONDS+g.levels[7]*g.CLOCK_STEP-g.run_elapsed
	g.shift_coins=37;g.spawn_clock=.25
	var expected=Snapshot.capture(g)
	check(expected.schema==5 and expected.crystal_run.offer_life==3.25 and expected.crystal_run.collected==1 and expected.balls.size()==4,"Crystal schema5 captures live second Prism plus first-offer clones")
	var validation=Snapshot.validate_and_decode(expected,g)
	check(validation.ok,"Prepared active checkpoint satisfies the real strict validator: "+str(validation.get("reason","")))
	g.testing=false
	check(g.save_game(),"Active Crystal run is serialized to the actual isolated profile")
	var record=disk();var bytes=FileAccess.get_file_as_bytes(save_path)
	check(record.version==5 and record.active_run.schema==5 and record.active_run.area_id=="crystal","Disk envelope5 contains the Crystal-only checkpoint schema5")
	var restored=fixture();restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and restored.area_id=="crystal","Mid-run Crystal reload opens paused with Resume available")
	check(equal(Snapshot.capture(restored),expected),"Every cloned-ball flag, velocity, timer, RNG value and Prism opportunity survives disk roundtrip")
	check(restored.bank==g.bank and restored.levels==g.levels and restored.crystal_second_prism,"Active-run resume preserves the Crystal campaign build and wallet")
	check(equal(restored.area_records.bakery,record.areas.bakery) and equal(restored.area_records.gelato,record.areas.gelato),"Active-run reload preserves both inactive area records")
	check(FileAccess.get_file_as_bytes(save_path)==bytes,"Loading a valid active checkpoint does not rewrite the saved file")
	g.testing=true;restored.testing=true;restored.mode="play"
	for _index in range(30):
		g.step(1.0/120.0);restored.step(1.0/120.0)
	check(equal(Snapshot.capture(g),Snapshot.capture(restored)),"Resumed Crystal continuation matches uninterrupted real physics and pickup expiry")
	check(restored.crystal_run.collected==1 and restored.crystal_run.next_offer==2,"Resume never grants a third opportunity or recollects the first")
	restored.free();g.free()

func _initialize():
	save_path=OS.get_environment("SUGARFALL_CRYSTAL_SAVE_QA_SAVE")
	var expected=OS.get_user_data_dir().replace("\\","/")+"/"
	if save_path.is_empty() or not save_path.is_absolute_path() or not save_path.replace("\\","/").begins_with(expected) or "--crystal-save-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Crystal save QA requires its explicit isolated user-directory path and opt-in marker");quit(2);return
	purchase_and_campaign();active_checkpoint()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(save_path+suffix)
	print("CRYSTAL_SAVE_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
