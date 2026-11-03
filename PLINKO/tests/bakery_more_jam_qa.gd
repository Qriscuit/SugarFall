extends SceneTree
## Real upgrade transactions plus isolated disk round trips. No player profiles.
const Campaign=preload("res://scripts/area_campaign.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]
var save_root=""

class DiskFixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func legacy_profile_path() -> String: return ""
	func random_ball(): return "normal"

class MemoryFixture extends DiskFixture:
	var fail_write=false
	var writes=0
	var candidate: Dictionary={}
	var cues: Array[String]=[]
	func write_profile_file(data: Dictionary) -> bool:
		writes+=1;candidate=data.duplicate(true)
		return not fail_write
	func load_game(): assert(false,"Memory fixture cannot read a player profile")
	func feedback(event: String,_options: Dictionary={}) -> bool:
		cues.append(event)
		return true

func check(value: bool,label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func setup(g):
	g.testing=false;g.sound_on=false;g.page_transition.enabled=false
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area("bakery");Campaign.apply_local(g,Campaign.default_record())
	g.area_records={"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.mode="shop";g.shift_claimed=true;g.run_id="";g.bank=100000000
	g.current_level=10;g.highest_unlocked=10;g.chapter_complete=false
	return g

func purchase_base(g):
	var count=0
	for node in g.UpgradeGraph.nodes():
		if g.buy_upgrade_node(node.x,node.y): count+=1
	check(count==62 and g.levels==g.MAX_LEVELS,"All 62 base upgrades remain legally purchasable at unlocked tray10")
	check(g.bakery_ability.buy(),"Jam Burst is purchased through the earned coin path")
	g.navigation_delay=0

func launch(g,kind: String="normal") -> Dictionary:
	g.spawn_ball(Vector2(360,267),kind,Vector2(0,85),false)
	g.bakery_ability.on_launch(g.balls[-1])
	return g.balls[-1]

func gates_and_transaction():
	var g=setup(MemoryFixture.new());purchase_base(g)
	check(g.bakery_ability.routes_complete() and g.bakery_ability.quick_unlocked(),"Tray10 reached without clearing it exposes the free milestone")
	for route in g.UpgradeGraph.routes():
		var tip: Vector2i=route[-1]
		g.levels[tip.x]-=1
		check(not g.bakery_ability.quick_buy(),"An unfinished route cannot claim More Jam")
		g.levels[tip.x]+=1
	g.levels[0]=0
	check(not g.bakery_ability.quick_buy(),"Owned route tips cannot bypass a missing shared root")
	g.levels[0]=10;g.highest_unlocked=9
	check(not g.bakery_ability.quick_buy(),"Tray9 cannot claim the milestone")
	g.highest_unlocked=10;g.bakery_jam_burst=false
	check(not g.bakery_ability.quick_buy(),"Max ordinary upgrades do not substitute for Jam Burst")
	g.bakery_jam_burst=true
	for guard in ["profile_load_blocked","startup_blocked","trial_active"]:
		g.set(guard,true)
		check(not g.bakery_ability.quick_buy(),guard+" blocks More Jam")
		g.set(guard,false)
	g.mode="home"
	check(not g.bakery_ability.quick_buy(),"Backend rejects a claim outside the upgrade map")
	g.mode="shop";g.run_id="unfinished";g.shift_claimed=false
	check(not g.bakery_ability.quick_buy(),"An outstanding run cannot change its launch cadence")
	g.run_id="";g.shift_claimed=true;g.bank=0;g.note="existing";g.note_time=7
	var levels=g.levels.duplicate();var records=g.area_records.duplicate(true)
	var cues=g.cues.size();g.fail_write=true
	check(not g.bakery_ability.quick_buy(),"Failed durable save returns a failed claim")
	check(not g.bakery_jam_quick and g.bank==0 and g.levels==levels and g.area_records==records and g.note=="existing" and g.note_time==7 and g.cues.size()==cues,"Failed claim rolls back ownership, feedback and campaign state without charging")
	g.fail_write=false
	check(g.bakery_ability.quick_buy() and g.bakery_ability.quick_owned(),"Free claim succeeds with a zero wallet")
	check(g.candidate.areas.bakery.bakery_jam_quick and g.bank==0 and g.levels==levels and g.ability_unlock_source=="earned","Durable candidate stores only the area-local milestone")
	check(g.cues.size()==cues+1 and g.cues[-1]=="upgrade","Successful claim emits one upgrade cue")
	var writes=g.writes
	check(not g.bakery_ability.quick_buy() and g.writes==writes and g.cues.size()==cues+1,"Repeated claims neither save nor repeat success feedback")
	check(g.bakery_ability.cadence()==4,"Claim immediately updates menu cadence")
	g.ability_unlock_source="preview"
	check(not g.bakery_ability.quick_owned(),"Milestone cannot reactivate missing preview Jam access")
	g.ability_unlock_source="earned"
	g.free()

func cadence_and_checkpoint():
	var g=setup(MemoryFixture.new());purchase_base(g)
	g.start_shift();g.run_transition.finish()
	for index in range(3): check(not launch(g).jam,"Base normal%d is uncharged"%(index+1))
	var legacy=Snapshot.capture(g)
	check(legacy.schema==6 and not legacy.bakery_run.has("every"),"Original Jam checkpoint keeps schema6 and its exact two-field state")
	g.bakery_jam_quick=true
	check(g.bakery_ability.cadence()==5 and not launch(g).jam and launch(g).jam,"Active run retains fifth-drop cadence despite a later campaign flag")
	check(g.restore_active_run(legacy) and g.bakery_ability.cadence()==5,"Legacy restore pins five even when campaign owns More Jam")
	check(not launch(g).jam and launch(g).jam,"Legacy resumed charge continues at the exact original fifth drop")
	g.mode="home";g.shift_claimed=true;g.run_id="";g.pause_transition.settle()
	g.start_shift();g.run_transition.finish()
	check(g.bakery_ability.cadence()==4,"Next new run adopts earned fourth-drop cadence")
	for index in range(12):
		if index==2:
			launch(g,"impact");launch(g,"shard")
			check(g.bakery_run.normal_launches==2,"Special and shard launches do not advance normal charge")
		var ball=launch(g)
		check(ball.jam==((index+1)%4==0),"Fourth-drop schedule is exact at normal%d"%(index+1))
	var snap=Snapshot.capture(g)
	var decoded=Snapshot.validate_and_decode(snap,g)
	check(snap.schema==7 and decoded.ok and decoded.state.bakery_run.every==4,"Schema7 validates the pinned fourth-drop interval")
	var bad=snap.duplicate(true);bad.bakery_run.every=5
	check(not Snapshot.validate_and_decode(bad,g).ok,"Schema7 cannot reinterpret the cadence as five")
	for invalid in [true,3,4.5,"4",null]:
		bad=snap.duplicate(true);bad.bakery_run.every=invalid
		check(not Snapshot.validate_and_decode(bad,g).ok,"Unsupported cadence value is rejected: "+str(invalid))
	bad=snap.duplicate(true);bad.bakery_run.erase("every")
	check(not Snapshot.validate_and_decode(bad,g).ok,"Schema7 requires an explicit cadence")
	bad=snap.duplicate(true);bad.schema=6
	check(not Snapshot.validate_and_decode(bad,g).ok,"Legacy schema6 cannot smuggle the new field")
	g.bakery_jam_quick=false
	check(not Snapshot.validate_and_decode(snap,g).ok,"Fourth-drop checkpoint requires earned milestone ownership")
	g.free()

func areas_trials_reset():
	var g=setup(MemoryFixture.new());purchase_base(g);g.bakery_ability.quick_buy()
	g.mode="home"
	check(g.begin_trial(8) and not g.bakery_jam_quick and not g.bakery_ability.quick_owned(),"Trials temporarily disable the campaign milestone")
	check(Campaign.capture_local(g).bakery_jam_quick,"Saving a Trial retains the untouched campaign milestone")
	g.start_shift();g.run_transition.finish()
	check(not launch(g).has("jam") and g.bakery_ability.cadence()==5,"Trial drops have no Jam ability or faster cadence")
	g.end_trial()
	check(g.bakery_jam_quick and g.bakery_ability.quick_owned(),"Leaving Trial restores campaign ownership")
	g.mode="home";g.run_id="";g.shift_claimed=true
	for area in ["gelato","crystal"]:
		check(g.switch_area(area) and not g.bakery_jam_quick and not g.bakery_ability.quick_buy(),area+" keeps independent progression and cannot claim Bakery milestone")
		check(g.switch_area("bakery") and g.bakery_jam_quick,"Bakery milestone persists across "+area+" revisit")
	g.mode="reset_confirm";g.fail_write=true
	check(not g.reset_progress() and g.bakery_jam_quick,"Failed reset preserves the earned milestone")
	g.fail_write=false
	check(g.reset_progress() and not g.bakery_jam_quick and not g.candidate.areas.bakery.bakery_jam_quick,"Successful campaign reset removes the earned-only milestone")
	g.free()

func schema_checks():
	var old=Campaign.default_record();old.erase("bakery_jam_quick")
	check(Campaign.valid_record(old,"bakery") and not Campaign.normalized(old,"bakery").bakery_jam_quick,"Older profiles default to unowned More Jam")
	for invalid in [1,"true",null]:
		var bad=old.duplicate(true);bad.bakery_jam_quick=invalid
		check(not Campaign.valid_record(bad,"bakery"),"Campaign rejects non-boolean milestone ownership")
	var earned=Campaign.default_record();earned.bakery_jam_burst=true;earned.bakery_jam_quick=true;earned.highest_unlocked=10;earned.levels=Campaign.CAPS.duplicate()
	check(Campaign.valid_record(earned,"bakery"),"Earned milestone has a valid area-local profile")
	for area in ["gelato","crystal"]:
		var bad=earned.duplicate(true);bad.bakery_jam_burst=false
		check(not Campaign.valid_record(bad,area),area+" cannot import Bakery milestone ownership")
	for missing in ["jam","tray","route"]:
		var bad=earned.duplicate(true)
		if missing=="jam": bad.bakery_jam_burst=false
		elif missing=="tray": bad.highest_unlocked=9
		else: bad.levels[0]=9
		check(not Campaign.valid_record(bad,"bakery"),"Profile cannot assert earned milestone without "+missing)

func write_json(path: String,data: Dictionary):
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()

func disk_case(quick: bool):
	var path=save_root.path_join("quick.json" if quick else "legacy.json")
	var g=setup(DiskFixture.new());g.SAVE_FILE=path;purchase_base(g)
	if quick: check(g.bakery_ability.quick_buy(),"Real disk claim commits More Jam")
	g.start_shift();g.run_transition.finish()
	for index in range(3): launch(g)
	check(g.save_game(),"Real profile writes partial Jam charge")
	var profile=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not quick:
		profile.areas.bakery.erase("bakery_jam_quick")
		write_json(path,profile)
	var bytes=FileAccess.get_file_as_bytes(path)
	var restored=setup(DiskFixture.new());restored.SAVE_FILE=path;restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and restored.bakery_jam_quick==quick,"Disk reload preserves old/new ownership and resumes paused: "+restored.snapshot_rejection+" "+restored.note)
	check(FileAccess.get_file_as_bytes(path)==bytes,"Valid old/new profile load preserves original file bytes")
	if restored.mode!="paused":
		g.free();restored.free();return
	check(restored.bakery_ability.cadence()==(4 if quick else 5) and restored.bakery_run.normal_launches==3,"Disk reload preserves exact cadence and partial charge")
	check(launch(restored).jam==quick,"First resumed normal drop respects fourth/fifth boundary")
	check(restored.save_game(),"Resumed run can save without schema drift")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.active_run.schema==(7 if quick else 6),"Resave retains the pinned checkpoint schema")
	if quick:
		saved.active_run.bakery_run.every=3;write_json(path,saved)
		var rejected=setup(DiskFixture.new());rejected.SAVE_FILE=path;rejected.load_game()
		check(rejected.mode=="home" and not rejected.snapshot_rejection.is_empty() and rejected.bakery_jam_quick,"Invalid run cadence rejects only checkpoint, preserving campaign milestone")
		rejected.free()
	g.free();restored.free()

func _initialize():
	save_root=OS.get_environment("SUGARFALL_MORE_JAM_QA_SAVE_ROOT")
	var expected=OS.get_user_data_dir().replace("\\","/")+"/"
	if save_root.is_empty() or not save_root.is_absolute_path() or not (save_root.replace("\\","/")+"/").begins_with(expected) or "--more-jam-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("More Jam QA requires an explicit isolated user namespace");quit(2);return
	DirAccess.make_dir_recursive_absolute(save_root)
	gates_and_transaction();cadence_and_checkpoint();areas_trials_reset();schema_checks();disk_case(false);disk_case(true)
	print("BAKERY_MORE_JAM_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
