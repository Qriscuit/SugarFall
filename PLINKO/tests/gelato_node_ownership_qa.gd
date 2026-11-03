extends SceneTree
## Real purchase/save/reload integration. Only the caller's isolated file is used.
const Main=preload("res://scripts/main.gd")
const Campaign=preload("res://scripts/area_campaign.gd")
const Graph=preload("res://scripts/gelato_upgrade_graph.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
const SHOP_FIELDS=["gelato_shop_revision","gelato_owned_nodes","gelato_reset_power_nodes"]
var passed=0
var failures: Array[String]=[]
var test_path=""

class Fixture extends "res://scripts/main.gd":
	var fail_write=false
	var writes=0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func legacy_profile_path() -> String: return ""
	func write_profile_file(data: Dictionary) -> bool:
		writes+=1
		return false if fail_write else super.write_profile_file(data)

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func equal(a,b) -> bool:
	return JSON.stringify(a,"",true,true)==JSON.stringify(b,"",true,true)

func ids(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for value in values: result.append(Vector2i(int(value[0]),int(value[1])))
	return result

func counts(values: Array) -> Array:
	var result=[0,0,0,0,0,0,0,0]
	for value in values: result[int(value[0])]+=1
	return result

func local(game) -> Dictionary: return Campaign.capture_local(game)

func fixture(area: String="gelato"):
	var game=Fixture.new()
	game.testing=true; game.sound_on=false; game.SAVE_FILE=test_path
	game.set_active_area(area)
	Campaign.apply_local(game,Campaign.default_record())
	game.area_records={"bakery":Campaign.default_record()}
	if area=="gelato": game.area_records.gelato=Campaign.default_record()
	game.mode="shop"; game.shift_claimed=true; game.run_id=""
	game.first_run_guide.active=false; game.first_run_guide.completed=true
	game.highest_unlocked=8; game.current_level=8; game.bank=1000000
	game.ensure_gelato_shop_state()
	return game

func legacy_record(levels: Array, twins: bool=false, reset: int=0) -> Dictionary:
	var record=Campaign.default_record()
	for field in SHOP_FIELDS: record.erase(field)
	record.levels=levels.duplicate(); record.bank=4321.75
	record.current_level=8; record.highest_unlocked=12; record.best_wave=12
	record.twin_launchers=twins; record.power_reset_tier=reset
	record.module_vouchers=2; record.module_milestones=[2,5]
	record.trial_records={"4":8.25,"8":11.5}
	return record

func write_legacy(record: Dictionary):
	var maker=fixture("bakery")
	var data=maker.profile_envelope({"bakery":Campaign.default_record(),"gelato":record},"gelato",[])
	data.version=3
	write_json(data); maker.free()

func write_json(data):
	var file=FileAccess.open(test_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"",true,true)); file.close()

func load_fixture():
	var game=fixture("bakery"); game.load_game(); return game

func children(node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for candidate in Graph.nodes():
		if node in Graph.prerequisites(candidate.x,candidate.y): result.append(candidate)
	return result

func ancestry(node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var current=node
	while true:
		result.push_front(current)
		var parents=Graph.prerequisites(current.x,current.y)
		if parents.is_empty(): return result
		current=parents[0]
	return result

func buy_path(game,node: Vector2i) -> bool:
	for step in ancestry(node):
		if not game.shop_node_owned(step.x,step.y) and not game.buy_upgrade_node(step.x,step.y): return false
	return true

func eligible(game) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for node in Graph.nodes():
		if not game.shop_node_owned(node.x,node.y) and game.shop_node_unlocked(node.x,node.y): result.append(node)
	return result

func same_family_fork():
	for node in Graph.nodes():
		var choices=children(node)
		if choices.size()==2 and choices[0].x==choices[1].x: return {"parent":node,"choices":choices}
	return {}

func exact_choice_and_aggregate_effect():
	var fork=same_family_fork()
	check(not fork.is_empty(),"The authored mixed tree contains two independent same-family choices")
	if fork.is_empty(): return
	for chosen_index in range(2):
		var game=fixture(); var parent: Vector2i=fork.parent
		check(buy_path(game,parent),"Real purchases reach the same-family fork")
		var chosen: Vector2i=fork.choices[chosen_index]; var other: Vector2i=fork.choices[1-chosen_index]
		check(game.shop_node_unlocked(chosen.x,chosen.y) and game.shop_node_unlocked(other.x,other.y),"Both same-family choices are independently eligible before purchase")
		var before=local(game); var price=game.upgrade_cost(chosen.x)
		var expected=game.levels.duplicate(); expected[chosen.x]+=1
		var expected_power=game.power_damage(expected[1])
		check(game.buy_upgrade_node(chosen.x,chosen.y),"Player can buy the exact chosen slot even when its ordinal is not the next effect level")
		check(game.shop_node_owned(chosen.x,chosen.y) and not game.shop_node_owned(other.x,other.y) and game.shop_node_unlocked(other.x,other.y),"Buying one same-family node neither grants nor locks its sibling")
		check(game.levels==expected and game.bank==before.bank-price and is_equal_approx(game.power_damage(),expected_power),"Selected slot adds one aggregate tier at the next aggregate price and effect")
		var reveal_ok=true
		for child in children(chosen): reveal_ok=reveal_ok and game.shop_node_visible(child.x,child.y)
		for child in children(other): reveal_ok=reveal_ok and not game.shop_node_visible(child.x,child.y)
		check(reveal_ok,"Only the chosen branch reveals its immediate continuation")
		var bought=local(game)
		check(not game.buy_upgrade_node(chosen.x,chosen.y) and equal(local(game),bought),"Duplicate node purchase cannot spend money or grant another effect")
		check(counts(game.gelato_owned_nodes)==game.levels,"Active node counts agree with all eight effective upgrade levels")
		game.free()

func random_purchase_orders():
	for seed_value in range(12):
		var game=fixture(); var rng=RandomNumberGenerator.new(); rng.seed=601200+seed_value
		var bounded=true; var exact=true; var purchases=0
		while purchases<62:
			var options=eligible(game)
			if options.is_empty(): break
			var node: Vector2i=options[rng.randi_range(0,options.size()-1)]
			var before=ids(game.gelato_owned_nodes)
			if not game.buy_upgrade_node(node.x,node.y): break
			purchases+=1
			var after=ids(game.gelato_owned_nodes)
			exact=exact and after.size()==before.size()+1 and node in after
			for prior in before: exact=exact and prior in after
			bounded=bounded and counts(game.gelato_owned_nodes)==game.levels
			for family in range(8): bounded=bounded and game.levels[family]<=game.MAX_LEVELS[family]
		check(purchases==62 and game.levels==game.MAX_LEVELS and exact and bounded,"Varied branch order%d reaches every slot once without cap overflow or hidden family gates"%seed_value)
		game.free()

func legacy_migration():
	var samples: Array=[[0,0,0,0,0,0,0,0],Graph.CAPS.duplicate(),[4,7,3,2,6,1,5,8]]
	for family in range(8):
		var single=[0,0,0,0,0,0,0,0]; single[family]=Graph.CAPS[family]; samples.append(single)
	var rng=RandomNumberGenerator.new(); rng.seed=612613
	for _sample in range(20):
		var values=[]
		for cap in Graph.CAPS: values.append(rng.randi_range(0,cap))
		samples.append(values)
	for index in range(samples.size()):
		var original=legacy_record(samples[index]); write_legacy(original)
		var bytes=FileAccess.get_file_as_bytes(test_path)
		var game=load_fixture(); var exact=true
		for node in Graph.nodes(): exact=exact and game.shop_node_owned(node.x,node.y)==(node.y<=original.levels[node.x])
		check(not game.profile_load_blocked and exact and game.levels==original.levels and game.bank==original.bank,"Legacy sample%d retains every original family/ordinal identity and effective count"%index)
		check(game.module_vouchers==original.module_vouchers and game.module_milestones==original.module_milestones and game.trial_records==original.trial_records and FileAccess.get_file_as_bytes(test_path)==bytes,"Migration retains campaign data and never rewrites its source while loading")
		var migrated=local(game)
		check(game.save_game(),"Migrated node state can be committed")
		var again=load_fixture()
		check(equal(local(again),migrated) and JSON.parse_string(FileAccess.get_file_as_string(test_path)).version==Main.PROFILE_VERSION,"Current-version reload is idempotent and does not reinterpret independent ownership")
		game.mode="shop"; game.bank=1000000
		var budget=62
		while not eligible(game).is_empty() and budget>0:
			var next: Vector2i=eligible(game)[0]
			if not game.buy_upgrade_node(next.x,next.y): break
			budget-=1
		check(game.levels==Graph.CAPS,"Irregular legacy sample%d can finish the new mixed tree without losing or inventing tiers"%index)
		game.free(); again.free()
	for active_power in range(11):
		var old=legacy_record([5,active_power,3,2,2,2,3,4],true,8)
		write_legacy(old); var game=load_fixture(); var exact=true
		for ordinal in range(1,11):
			exact=exact and game.shop_node_owned(1,ordinal)==(ordinal<=active_power)
			exact=exact and game.is_rebuild_power_node(1,ordinal)==(ordinal>active_power and ordinal<=8)
			exact=exact and game.shop_node_historical(1,ordinal)==(ordinal<=maxi(active_power,8))
		check(exact and game.power_reset_tier==8 and game.levels[1]==active_power,"Old eight-Power reset preserves exact active and awaiting-rebuild sets at current Power%d"%active_power)
		game.free()

func malformed_records():
	var game=fixture(); check(buy_path(game,Vector2i(2,1)),"Validation fixture owns a real mixed purchase path")
	var valid=local(game); var bad_records=[]
	for value in [null,false,0,2,"1"]:
		var bad=valid.duplicate(true); bad.gelato_shop_revision=value; bad_records.append(bad)
	for value in [null,{},[1],[[true,1]],[[1,1.5]],[[8,1]],[[1,11]],[[-1,1]]]:
		var bad=valid.duplicate(true); bad.gelato_owned_nodes=value; bad_records.append(bad)
	var duplicate=valid.duplicate(true); duplicate.gelato_owned_nodes.append(duplicate.gelato_owned_nodes[0].duplicate()); bad_records.append(duplicate)
	var missing=valid.duplicate(true); missing.gelato_owned_nodes.pop_back(); bad_records.append(missing)
	var mismatch=valid.duplicate(true); mismatch.levels[0]+=1; bad_records.append(mismatch)
	var wrong_reset=valid.duplicate(true); wrong_reset.twin_launchers=true; wrong_reset.power_reset_tier=1; wrong_reset.gelato_reset_power_nodes=[[0,1]]; bad_records.append(wrong_reset)
	var overlap=valid.duplicate(true); overlap.twin_launchers=true; overlap.power_reset_tier=1; overlap.gelato_reset_power_nodes=[[1,1]]; bad_records.append(overlap)
	var no_twins=valid.duplicate(true); no_twins.gelato_reset_power_nodes=[[1,9]]; bad_records.append(no_twins)
	var lost_reset=Campaign.normalized(legacy_record([2,0,1,1,1,1,1,1],true,8),"gelato")
	lost_reset.gelato_reset_power_nodes.pop_back(); bad_records.append(lost_reset)
	for field in SHOP_FIELDS:
		var partial=valid.duplicate(true); partial.erase(field); bad_records.append(partial)
	var absent=valid.duplicate(true)
	for field in SHOP_FIELDS: absent.erase(field)
	bad_records.append(absent)
	for index in range(bad_records.size()):
		var bad=bad_records[index]
		var data=game.profile_envelope({"bakery":Campaign.default_record(),"gelato":bad},"gelato",[])
		check(not Campaign.decode_profile(data).ok,"Malformed explicit node state is rejected instead of silently remigrated: case%d"%index)
	game.gelato_owned_nodes.pop_back()
	check(not game.ensure_gelato_shop_state(),"An inconsistent explicit runtime state cannot be repaired by granting a count prefix")
	game.free()

func unsupported_profiles_stay_intact():
	for version in [Main.PROFILE_VERSION+1,99]:
		var maker=fixture()
		var data=maker.profile_envelope({"bakery":Campaign.default_record(),"gelato":local(maker)},"gelato",[])
		data.version=version; write_json(data); maker.free()
		var bytes=FileAccess.get_file_as_bytes(test_path); var game=load_fixture()
		check(game.profile_load_blocked and not game.save_game(),"Future profile version%d is protected from ordinary saves"%version)
		game.mode="support"
		check(not game.reset_progress() and FileAccess.get_file_as_bytes(test_path)==bytes,"A blocked future profile cannot reset without the existing confirmation state")
		game.mode="reset_confirm"
		game.fail_write=true
		check(not game.reset_progress() and game.profile_load_blocked and FileAccess.get_file_as_bytes(test_path)==bytes,"Failed explicit reset keeps the blocked future profile intact")
		game.fail_write=false
		check(game.reset_progress() and not game.profile_load_blocked and game.bank==0 and JSON.parse_string(FileAccess.get_file_as_string(test_path)).version==Main.PROFILE_VERSION,"An explicitly confirmed reset can recover a future profile into a fresh supported save")
		game.free()

func reset_rebuild_and_rollback():
	var game=fixture()
	# Reach six Power effects through actual slot purchases, regardless of ordinals.
	for node in Graph.nodes():
		if game.levels[1]>=6: break
		check(game.buy_upgrade_node(node.x,node.y),"Reach the Dual Shot effect-count gate through real mixed-tree purchases")
	check(game.levels[1]==6 and game.gelato_launcher.unlocked(),"Dual Shot gates on six active Power effects, not a particular slot ordinal")
	game.testing=false
	check(game.save_game(),"Pre-reset exact ownership is durable")
	var before=local(game); var bytes=FileAccess.get_file_as_bytes(test_path)
	game.fail_write=true
	check(not game.buy_twin_launchers() and equal(local(game),before) and FileAccess.get_file_as_bytes(test_path)==bytes,"Failed Twin write rolls back money, counts, active nodes and reset-node history")
	game.fail_write=false
	var old_power: Array[Vector2i]=[]
	for node in ids(game.gelato_owned_nodes):
		if node.x==1: old_power.append(node)
	check(game.buy_twin_launchers() and game.levels[1]==0 and game.bank==before.bank-3000,"Dual Shot succeeds once at3000 and removes all active Power effects")
	var reset=ids(game.gelato_reset_power_nodes)
	check(reset.size()==old_power.size() and reset.all(func(node):return node in old_power),"Reset remembers the exact purchased Power slots, including non-prefix ordinals")
	var non_power_ok=true
	for node in ids(before.gelato_owned_nodes):
		if node.x!=1: non_power_ok=non_power_ok and game.shop_node_owned(node.x,node.y)
	check(non_power_ok,"Dual Shot retains every non-Power purchased slot")
	var ready=true
	for node in old_power: ready=ready and game.shop_node_historical(node.x,node.y) and game.shop_node_visible(node.x,node.y) and game.shop_node_unlocked(node.x,node.y)
	check(ready,"Previously purchased Power remains discoverable and rebuildable through historical parents")
	var rebuilt_before=local(game); var rebuy: Vector2i=old_power.back()
	game.fail_write=true
	check(not game.buy_upgrade_node(rebuy.x,rebuy.y) and equal(local(game),rebuilt_before),"Failed exact-node rebuild rolls back both ownership sets, effect count and wallet")
	game.fail_write=false
	var price=game.upgrade_cost(1)
	check(game.buy_upgrade_node(rebuy.x,rebuy.y) and game.levels[1]==1 and game.bank==rebuilt_before.bank-price and not game.is_rebuild_power_node(rebuy.x,rebuy.y),"Player can rebuild the selected high-ordinal slot at aggregate Power1 cost")
	var after=local(game); var again=load_fixture()
	check(equal(local(again),after),"Exact reset and rebuilt slot identities survive immediate reload")
	game.free(); again.free()

func voucher_transaction():
	var game=fixture(); var target=Vector2i(-1,1)
	for node in Graph.nodes():
		if node.x in [3,4,5]: target=node; break
	var parents=Graph.prerequisites(target.x,target.y)
	check(not parents.is_empty() and buy_path(game,parents[0]),"Voucher fixture reaches an actual special-ingredient node")
	game.module_vouchers=1; game.testing=false
	check(game.save_game(),"Voucher fixture commits its prerequisite path")
	var before=local(game); var kind=game.UPGRADE_NAMES[target.x]
	var module_kind=["ricochet","splitter","impact"][target.x-3]
	game.fail_write=true
	check(not game.claim_module(module_kind) and equal(local(game),before),"Failed voucher purchase preserves voucher, equipment, counts and owned nodes")
	game.fail_write=false
	check(game.claim_module(module_kind) and game.levels[target.x]==1 and game.module_vouchers==0 and game.bank==before.bank,"Voucher unlocks one eligible special slot without charging coins: "+kind)
	var added=[]
	for node in ids(game.gelato_owned_nodes):
		if node not in ids(before.gelato_owned_nodes): added.append(node)
	check(added.size()==1 and added[0].x==target.x and game.shop_node_owned(added[0].x,added[0].y),"Voucher grants exactly one concrete eligible node")
	var again=load_fixture(); check(equal(local(again),local(game)),"Voucher's exact slot and equipment survive restart")
	game.free(); again.free()

func lifecycle_roundtrips():
	var game=fixture(); var fork=same_family_fork(); check(buy_path(game,fork.parent),"Lifecycle fixture reaches fork")
	var chosen: Vector2i=fork.choices.back(); check(game.buy_upgrade_node(chosen.x,chosen.y),"Lifecycle fixture owns a non-prefix same-family choice")
	game.mode="home"; game.testing=false; var original=local(game)
	check(game.save_game() and game.switch_area("bakery") and game.switch_area("gelato") and equal(local(game),original),"Area switches retain exact Gelato node sets without importing Bakery ownership")
	check(game.begin_trial(4) and equal(local(game),original),"Starting a fixed Trial preserves the underlying exact-node campaign")
	game.start_shift(); game.step(.05)
	check(game.save_game(),"Interrupted Trial saves its campaign node sets alongside fixed physics")
	var resumed=load_fixture()
	check(resumed.mode=="paused" and resumed.trial_active and resumed.levels==Snapshot.TRIAL_LEVELS and equal(local(resumed),original),"Trial checkpoint resumes fixed effects while retaining exact campaign ownership")
	resumed.end_trial(); check(equal(local(resumed),original),"Ending a resumed Trial restores exact node choices")
	game.end_trial(); game.mode="home"; game.start_shift(); game.step(.05)
	var before_snapshot=Snapshot.capture(game)
	check(game.save_game(),"Campaign checkpoint saves with unchanged snapshot schema")
	var loaded=load_fixture()
	check(loaded.mode=="paused" and not loaded.trial_active and equal(local(loaded),original) and Snapshot.capture(loaded).schema==4,"Live checkpoint resumes exact effective build and independent node history")
	check(Snapshot.capture(loaded).fingerprint==before_snapshot.fingerprint and Snapshot.capture(loaded).levels==before_snapshot.levels,"Shop migration leaves physics fingerprint and active-run effective levels unchanged")
	game.free(); resumed.free(); loaded.free()

func _initialize():
	test_path=OS.get_environment("SUGARFALL_NODE_OWNERSHIP_QA_SAVE")
	if test_path.is_empty() or not test_path.is_absolute_path() or "--node-ownership-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Node ownership QA needs an explicit absolute isolated path and opt-in flag"); quit(2); return
	exact_choice_and_aggregate_effect(); random_purchase_orders(); legacy_migration(); malformed_records(); unsupported_profiles_stay_intact()
	reset_rebuild_and_rollback(); voucher_transaction(); lifecycle_roundtrips()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path+suffix): DirAccess.remove_absolute(test_path+suffix)
	print("GELATO_NODE_OWNERSHIP_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
