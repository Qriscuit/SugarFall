extends SceneTree
## Immutable v0.6.9 profiles were captured using that archived game's runtime.
## Only the explicit isolated file may be written; never discover player saves.
const Snapshot=preload("res://scripts/run_snapshot.gd")
const Campaign=preload("res://scripts/area_campaign.gd")
const PREVIOUS="9cf438255f4930f41ece8847325d238aaed8756564842abd6339119bc7a6f1d6"
const CURRENT="5a0bd00a920e20cc8aca0255b477147de84e305c50cfcfcb9ba40013fbca4870"
var passed=0
var failures: Array[String]=[]
var test_path=""

class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func legacy_profile_path() -> String: return ""

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func equal(a,b) -> bool:
	# JSON decodes all numbers as doubles; restored counters are integers and
	# Vector2 coordinates are floats. Ignore only that serialization roundoff.
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<1e-10
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
	return a==b

func fixture():
	var game=Fixture.new()
	game.testing=true; game.sound_on=false; game.SAVE_FILE=test_path
	return game

func write_json(data):
	var file=FileAccess.open(test_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"",true,true)); file.close()

func cleanup():
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path+suffix): DirAccess.remove_absolute(test_path+suffix)

func old_profiles_keep_progress():
	for kind in ["single","twins","trial"]:
		var path="res://tests/fixtures/gelato-v069-"+kind+"-profile.json"
		var original=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(original is Dictionary and original.active_run.fingerprint==PREVIOUS,"Real v069 fixture has the pinned original fingerprint: "+kind)
		write_json(original)
		var bytes=FileAccess.get_file_as_bytes(test_path)
		var game=fixture(); game.load_game()
		check(not game.profile_load_blocked and game.mode=="home" and not game.resumed_run and game.snapshot_rejection=="Checkpoint content no longer matches this build","Changed combat rules reject old live checkpoints safely: "+kind)
		var expected=Campaign.normalized(original.areas.gelato,"gelato")
		check(equal(Campaign.capture_local(game),expected),"Old wallet, upgrades, milestones and twins survive with current Trial-record rules: "+kind)
		check(equal(game.area_records.bakery,Campaign.normalized(original.areas.bakery,"bakery")),"Other area progression survives normalization intact: "+kind)
		check(game.twin_launchers==expected.twin_launchers and not game.trial_active,"Campaign launcher ownership survives while the old run is discarded: "+kind)
		check(FileAccess.get_file_as_bytes(test_path)==bytes,"Reading old checkpoint does not rewrite its source profile: "+kind)
		check(game.save_game(),"First post-migration save succeeds: "+kind)
		var migrated=JSON.parse_string(FileAccess.get_file_as_string(test_path))
		check(not migrated.has("active_run") and equal(migrated.areas.gelato,expected),"Next save preserves campaign progress without reviving the rejected checkpoint: "+kind)
		var again=fixture(); again.load_game()
		check(again.mode=="home" and not again.resumed_run and equal(Campaign.capture_local(again),expected),"Migrated campaign loads again with the same wallet and ownership: "+kind)
		if kind=="twins":
			check(game.highest_unlocked==5 and game.levels[1]==1 and game.power_reset_tier==3 and game.gelato_launcher.is_twin(),"Previously owned twins remain active below the new purchase gates")
			var bank=game.bank
			check(not game.buy_twin_launchers() and game.bank==bank,"Grandfathered ownership is never charged again")
		game.free(); again.free()

func changed_fingerprint(path: String,before: String,after: String) -> String:
	var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for input in ["res://data/gelato_board_design.json","res://data/economy.json","res://data/gelato_economy.json"]:
		var bytes=FileAccess.get_file_as_bytes(input)
		if input==path:
			var source=bytes.get_string_from_utf8()
			check(source.contains(before),"Future-change probe modifies a real packaged input: "+before)
			bytes=source.replace(before,after).to_utf8_buffer()
		context.update(bytes)
	return context.finish().hex_encode()

func bridge_is_pinned():
	var packaged=Snapshot.content_fingerprint("gelato")
	check(packaged!=CURRENT and not Snapshot.compatible_fingerprint(CURRENT,packaged,"gelato") and not Snapshot.compatible_fingerprint(PREVIOUS,packaged,"gelato"),"New combat content rejects both historical shop fingerprints")
	check(Snapshot.GELATO_SHOP_PREVIOUS_FINGERPRINT==PREVIOUS and Snapshot.GELATO_SHOP_CURRENT_FINGERPRINT==CURRENT,"The bridge pins both historical and destination fingerprints")
	check(Snapshot.compatible_fingerprint(PREVIOUS,CURRENT,"gelato"),"Only Gelato's old shop-only source hash is accepted")
	check(not Snapshot.compatible_fingerprint(PREVIOUS,CURRENT,"bakery"),"Gelato compatibility cannot leak into Bakery")
	check(not Snapshot.compatible_fingerprint(CURRENT,PREVIOUS,"gelato"),"The price bridge does not authorize downgrading to old content")
	check(not Snapshot.compatible_fingerprint("unrelated",CURRENT,"gelato") and not Snapshot.compatible_fingerprint(PREVIOUS,"","gelato"),"Unknown or missing content is rejected")
	for spec in [["res://data/gelato_economy.json","\"gravity\": 400.0","\"gravity\": 450.0"],["res://data/gelato_economy.json","\"launcher_speed\": 260.0","\"launcher_speed\": 280.0"],["res://data/gelato_board_design.json","\"base_hp\": 6","\"base_hp\": 7"]]:
		var future=changed_fingerprint(spec[0],spec[1],spec[2])
		check(future!=CURRENT and not Snapshot.compatible_fingerprint(PREVIOUS,future,"gelato"),"Future physics/board changes cannot inherit this compatibility bridge: "+spec[1])
	check(Snapshot.compatible_fingerprint(Snapshot.PRICE_ONLY_PREVIOUS_FINGERPRINT,Snapshot.PRICE_ONLY_CURRENT_FINGERPRINT,"bakery"),"Existing narrowly pinned Bakery migration is retained")

func _initialize():
	test_path=OS.get_environment("SUGARFALL_GELATO_SHOP_QA_SAVE")
	if not test_path.is_absolute_path() or "--gelato-shop-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Gelato shop migration QA requires an explicit isolated save path and flag"); quit(2); return
	cleanup()
	bridge_is_pinned()
	old_profiles_keep_progress()
	cleanup()
	print("GELATO_SHOP_MIGRATION_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
