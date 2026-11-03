extends SceneTree
## Actual profile IO is restricted to an explicit, disposable user namespace.
const Rules=preload("res://scripts/flow_rules.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]
var save_root=""

class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func legacy_profile_path() -> String: return ""

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area: String, path: String):
	var g=Fixture.new()
	g.testing=true;g.sound_on=false;g.SAVE_FILE=path
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area(area)
	g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record())
	g.current_level=8;g.highest_unlocked=12;g.bank=100
	g.area_records={}
	for id in g.AreaCampaign.IDS: g.area_records[id]=g.AreaCampaign.default_record()
	return g

func ordinary(g) -> int:
	for index in range(g.pegs.size()):
		if g.pegs[index].kind=="normal" and g.pegs[index].hp>0: return index
	return -1

func write_json(path: String, data: Dictionary):
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()

func campaign_case(area: String, tray: int, revision: int):
	var path=save_root.path_join("%s-%d-rev%d.json"%[area,tray,revision])
	var g=fixture(area,path)
	g.current_level=tray;g.start_shift()
	if revision==1:
		g.run_rules_revision=1;g.build_wave()
	var index=ordinary(g)
	g.damage_peg(g.pegs[index],7.1)
	check(g.save_game(),"%s tray%d revision%d writes checkpoint"%[area,tray,revision])
	var profile=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(profile.active_run_rules==revision,"Profile records exact active run rules")
	var fingerprint=profile.active_run.fingerprint
	if revision==1:
		profile.erase("active_run_rules")
		write_json(path,profile)
	var original=FileAccess.get_file_as_bytes(path)
	var restored=fixture(area,path);restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and restored.run_rules_revision==revision,"Load pins legacy/current rules BEFORE checkpoint validation")
	check(is_equal_approx(restored.pegs[index].max,g.pegs[index].max) and is_equal_approx(restored.pegs[index].hp,g.pegs[index].hp),"Partial peg HP survives rule-pinned restore")
	check(restored.shift_coins==g.shift_coins and Snapshot.content_fingerprint(area)==fingerprint,"Restore preserves paid damage and unchanged content fingerprint")
	check(FileAccess.get_file_as_bytes(path)==original,"Loading valid legacy/current checkpoint does not rewrite bytes")
	g.damage_peg(g.pegs[index],9999)
	restored.damage_peg(restored.pegs[index],9999)
	check(g.shift_coins==restored.shift_coins,"Post-restore remaining damage/break income matches uninterrupted run")
	check(restored.save_game(),"Resaving pins the previously implicit legacy revision explicitly")
	profile=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(profile.active_run_rules==revision,"Resave does not upgrade an airborne run's rules")
	restored.mode="home";restored.shift_claimed=true;restored.run_id="";restored.pause_transition.settle()
	restored.start_shift()
	check(restored.run_rules_revision==2 and is_equal_approx(restored.pegs[index].max,Rules.normal_hp(float(restored.board_data[tray-1].base_hp),tray,false,2)),"Next new campaign adopts current rules after legacy completion")
	g.free();restored.free()

func invalid_revision():
	var path=save_root.path_join("invalid-revision.json")
	var g=fixture("bakery",path);g.start_shift();g.save_game()
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	for invalid in [0,3,1.5,true,"2"]:
		data.active_run_rules=invalid;write_json(path,data)
		var restored=fixture("bakery",path);restored.load_game()
		check(restored.mode=="home" and not restored.snapshot_rejection.is_empty() and restored.bank==100,"Unsupported run revision rejects only active run and retains wallet")
		restored.free()
	g.free()

func trial_case():
	var path=save_root.path_join("trial-rules.json")
	var g=fixture("gelato",path)
	g.begin_trial(8);g.start_shift()
	check(g.trial_active and ordinary(g)>=0 and g.pegs[ordinary(g)].max==6,"Trial starts at authored HP under revision2")
	check(g.save_game(),"Trial saves through normal profile path")
	var restored=fixture("gelato",path);restored.load_game()
	check(restored.trial_active and restored.mode=="paused" and restored.run_rules_revision==2 and restored.pegs[ordinary(restored)].max==6,"Trial restore retains fixed authored HP and pinned revision")
	g.free();restored.free()

func _initialize():
	save_root=OS.get_environment("SUGARFALL_FLOW_QA_SAVE_ROOT")
	var expected=OS.get_user_data_dir().replace("\\","/")+"/"
	if save_root.is_empty() or not save_root.is_absolute_path() or not (save_root.replace("\\","/")+"/").begins_with(expected) or "--flow-save-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Flow disk QA requires its explicit isolated directory and opt-in marker");quit(2);return
	DirAccess.make_dir_recursive_absolute(save_root)
	for area in ["bakery","gelato","crystal"]:
		for tray in [8,12]:
			for revision in [1,2]: campaign_case(area,tray,revision)
	invalid_revision();trial_case()
	print("FLOW_RULES_SAVE_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
