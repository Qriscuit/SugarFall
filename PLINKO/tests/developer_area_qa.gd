extends SceneTree
## Transaction fixtures use memory writes; restart fixtures use only an explicitly
## supplied, reserved filename inside the caller's isolated user-data directory.
const Main = preload("res://scripts/main.gd")

class Fixture extends "res://scripts/main.gd":
	var developer_enabled = true
	var content_available = true
	var fail_write = false
	var memory_writes = true
	var writes = 0
	var saved: Dictionary = {}
	var area_at_write = ""
	var bank_at_write = 0.0
	var owned_at_write = false
	func developer_tools_available() -> bool: return developer_enabled
	func area_content_ready(id: String) -> bool:
		return content_available and not area_boards(id).is_empty()
	func write_profile_file(data: Dictionary) -> bool:
		writes += 1
		area_at_write = area_id
		bank_at_write = bank
		owned_at_write = area_owned("gelato")
		if fail_write: return false
		if memory_writes:
			saved = data.duplicate(true)
			return true
		return super.write_profile_file(data)
	func legacy_profile_path() -> String: return ""

var passed = 0
var failures: Array[String] = []
var test_path = ""

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func equal(a, b) -> bool:
	return JSON.stringify(a,"",true,true)==JSON.stringify(b,"",true,true)

func fixture():
	var game = Fixture.new()
	game.testing = true
	game.sound_on = false
	game.reduced_motion = true
	game.SAVE_FILE = test_path
	game.set_active_area("bakery")
	game.bank = 321.75
	game.levels = [2,2,1,1,1,1,2,2]
	game.current_level = 2
	game.highest_unlocked = 3
	game.best_wave = 3
	game.module_vouchers = 1
	game.module_milestones = [2]
	game.equipped = ["ricochet"]
	game.total_shifts = 9
	game.run_serial = 12
	game.last_claimed_run_id = "bakery:12:456"
	game.monetization.attempts = 3
	game.monetization.active_seconds = 103.5
	game.monetization.serial = 7
	game.monetization.entitlements = {"remove_ads":true,"baker_toolkit":false}
	game.monetization.store_owned = game.monetization.entitlements.duplicate()
	game.first_run_guide.completed = true
	game.first_run_guide.active = false
	game.shift_claimed = true
	game.mode = "support"
	return game

func local(game) -> Dictionary: return game.AreaCampaign.capture_local(game)

func globals(game) -> Dictionary:
	return {"monetization":game.monetization.export_state(),"serial":game.run_serial,"claimed":game.last_claimed_run_id,"shifts":game.total_shifts,"sound":game.sound_on,"reduced":game.reduced_motion,"history":game.result_history.export_state(),"guide":game.first_run_guide.export_state()}

func stable_state(game) -> Dictionary:
	return {"area":game.area_id,"local":local(game),"records":game.area_records.duplicate(true),"ledger":game.area_entries.duplicate(true),"tuning":game.tuning.duplicate(true),"globals":globals(game),"mode":game.mode,"pending":game.monetization.pending.duplicate(true)}

func switch_from_settings(game, id: String) -> bool:
	game.mode = "support"
	return game.developer_switch_area(id)

func initialize_gelato_progress(game):
	game.start_shift()
	game.shift_coins = 30000.25
	check(game.finish_shift(false),"A synthetic Gelato result finishes through the normal result API")
	game.collect_reward()
	check(is_equal_approx(game.bank,30000.25),"Collected Gelato earnings enter its own fresh wallet")
	game.current_level = 8
	game.highest_unlocked = 8
	game.best_wave = 8
	game.mode = "shop"
	var spent = 0.0
	var chain: Array[Vector2i] = []
	var node=Vector2i(1,6)
	while true:
		chain.push_front(node)
		var parents=game.upgrade_graph().prerequisites(node.x,node.y)
		if parents.is_empty(): break
		node=parents[0]
	for step in chain:
		spent += game.upgrade_cost(step.x)
		check(game.buy_upgrade_node(step.x,step.y),"Gelato can buy its exact prerequisite chain to six Power purchases: "+str(step))
	spent += game.gelato_launcher.cost()
	check(game.buy_twin_launchers(),"Gelato buys twin launchers with earned local coins")
	check(game.twin_launchers and game.power_reset_tier==6 and game.levels[1]==0,"Twin purchase retains ownership and applies its one-time Power reset")
	spent += game.upgrade_cost(1)
	check(game.buy_upgrade(1),"Gelato can rebuild its first Power tier after the reset")
	check(is_equal_approx(game.bank,30000.25-spent) and game.levels[1]==1,"Gelato keeps the exact remaining wallet and rebuilt Power")
	game.module_vouchers = 2
	game.module_milestones = [2,5]
	game.trial_records = {"4":7.75}
	check(game.save_game(),"Gelato progress can be committed before switching areas")

func first_entry_and_revisits():
	var game = fixture()
	var bakery = local(game)
	var shared = globals(game)
	var bakery_tuning = game.tuning.duplicate(true)
	check(game.developer_tools_available() and game.developer_area_navigation_allowed(),"Developer Settings permits safe idle area navigation")
	check(game.developer_switch_area("gelato"),"Developer access enters Gelato before Bakery completion or the normal fee")
	check(game.area_at_write=="bakery" and game.bank_at_write==321.75 and not game.owned_at_write,"The outgoing area remains live until the first-entry save succeeds")
	check(game.area_id=="gelato" and game.mode=="home" and equal(local(game),game.AreaCampaign.default_record()),"First developer entry opens a fresh Gelato Home with zero coins and no upgrades")
	check(equal(game.area_records.bakery,bakery) and equal(game.saved.areas.bakery,bakery),"First developer entry preserves the complete Bakery record without a fee")
	check(game.area_entries.is_empty() and game.saved.area_entries.is_empty(),"Developer entry fabricates no paid-entry ledger record")
	check(equal(globals(game),shared),"Developer navigation preserves permanent benefits, settings and lifetime identities")
	check(is_equal_approx(game.tuning.core_cost_growth,1.6) and game.tuning.has("launcher_speed"),"Gelato-specific economy and launcher tuning become active")
	initialize_gelato_progress(game)
	var gelato = local(game)
	shared = globals(game)
	check(switch_from_settings(game,"bakery") and equal(local(game),bakery),"Returning to Bakery restores its original coins, upgrades, equipment and progress")
	check(equal(game.tuning,bakery_tuning) and not game.twin_launchers and game.power_reset_tier==0,"Returning to Bakery restores exact Bakery tuning and no Gelato launcher state")
	check(equal(game.area_records.gelato,gelato) and equal(globals(game),shared),"Leaving Gelato preserves its earnings, rebuilt Power and shared identities")
	check(switch_from_settings(game,"gelato") and equal(local(game),gelato),"Revisiting Gelato restores its existing wallet and twin build instead of resetting it")
	check(is_equal_approx(game.power_damage(),1.675) and is_equal_approx(game.tuning.core_cost_growth,1.6),"Revisited Gelato uses its rebuilt-Power effect and its own economy")
	game.mode = "developer_areas"
	var before = stable_state(game)
	var writes = game.writes
	check(not game.developer_switch_area("gelato") and equal(stable_state(game),before) and game.writes==writes,"Selecting the current area cannot rewrite or reset progress")
	for repeat in range(2):
		check(switch_from_settings(game,"bakery") and switch_from_settings(game,"gelato") and equal(local(game),gelato),"Repeated developer round trip retains the full Gelato record "+str(repeat+1))
	check(game.area_entries.is_empty() and game.saved.area_entries.is_empty(),"Repeated developer visits still create no paid-entry ledger")
	game.free()

func guards_and_rollback():
	for target in ["","unknown","bakery"]:
		var game = fixture()
		var before = stable_state(game)
		check(not game.developer_switch_area(target) and equal(stable_state(game),before) and game.writes==0,"Invalid or current developer target is a no-op: "+target)
		game.free()
	for guard in ["release","content","trial","transition","provider","unclaimed","blocked","transaction","guide","invalid_wallet"]:
		var game = fixture()
		match guard:
			"release": game.developer_enabled = false
			"content": game.content_available = false
			"trial": game.trial_active = true
			"transition": game.run_transition.active = true
			"provider": game.monetization.pending = {"id":"busy"}
			"unclaimed": game.run_id = "bakery:13:1"; game.shift_claimed = false
			"blocked": game.profile_load_blocked = true
			"transaction": game.area_transaction_pending = true
			"guide": game.first_run_guide.active = true; game.first_run_guide.completed = false
			"invalid_wallet": game.bank = 100000000.01
		var before = stable_state(game)
		check(not game.developer_switch_area("gelato") and equal(stable_state(game),before) and game.writes==0,"Developer switch rejects unsafe state without mutation: "+guard)
		if guard=="release": check(not game.developer_tools_available() and not game.developer_area_navigation_allowed(),"A non-developer build exposes no developer area navigation")
		game.free()
	for screen in ["home","boards","play","paused","result","test_ad","test_purchase","shop","abandon_confirm","reset_confirm","trials","loadout"]:
		var game = fixture()
		game.mode = screen
		var before = stable_state(game)
		check(not game.developer_switch_area("gelato") and equal(stable_state(game),before) and game.writes==0,"Developer switch rejects a non-Settings screen: "+screen)
		game.free()
	var game = fixture()
	var before = stable_state(game)
	game.fail_write = true
	check(not game.developer_switch_area("gelato") and game.writes==1,"A failed first-entry write rejects developer navigation")
	check(equal(stable_state(game),before) and not game.area_owned("gelato") and not game.area_transaction_pending,"Failed first entry leaves both ownership and all live progress intact")
	game.fail_write = false
	check(game.developer_switch_area("gelato"),"Developer entry can be retried after a failed write")
	game.bank = 271.5
	game.mode = "support"
	before = stable_state(game)
	game.fail_write = true
	check(not game.developer_switch_area("bakery") and equal(stable_state(game),before) and not game.area_transaction_pending,"Failed return to an owned area also leaves outgoing earnings and active area intact")
	game.free()

func normal_entry_is_unchanged():
	var game = fixture()
	game.mode = "home"
	check(not game.area_entry_status().can_enter and not game.enter_area() and game.writes==0,"The normal Gelato entry remains gated for incomplete, underfunded Bakery")
	game.bank = 45000.0
	check(not game.enter_area() and game.writes==0,"Normal entry still requires Bakery completion even with enough coins")
	game.current_level = 12; game.highest_unlocked = 12; game.chapter_complete = true
	game.bank = 999.0
	check(not game.enter_area() and game.writes==0,"Normal entry still requires the 1000-coin fee after completion")
	game.bank = 45000.0
	check(game.enter_area() and game.area_records.bakery.bank==44000.0,"Normal paid entry charges its exact 1000-coin fee")
	check(game.area_entries.size()==1 and game.area_entries[0].cost==1000,"Only normal paid entry records a paid-entry ledger item")
	var ledger = game.area_entries.duplicate(true)
	check(switch_from_settings(game,"bakery") and switch_from_settings(game,"gelato") and equal(game.area_entries,ledger),"Developer revisits preserve an existing paid-entry ledger unchanged")
	game.free()

func persistence_and_restart():
	var game = fixture()
	game.memory_writes = false
	var bakery = local(game)
	check(game.developer_switch_area("gelato"),"First developer entry commits to the reserved isolated save file")
	initialize_gelato_progress(game)
	var gelato = local(game)
	check(switch_from_settings(game,"bakery") and equal(local(game),bakery),"The durable return to Bakery preserves its original campaign")
	var restored = fixture()
	check(FileAccess.file_exists(test_path),"A real isolated save exists for the separate restart fixture")
	restored.memory_writes = false
	restored.load_game()
	check(not restored.profile_load_blocked and restored.area_id=="bakery" and equal(local(restored),bakery),"A new game instance loads the saved active Bakery without touching player saves")
	check(equal(restored.area_records.gelato,gelato) and restored.area_entries.is_empty(),"Restart retains Gelato earnings and upgrades with no fabricated entry ledger")
	check(switch_from_settings(restored,"gelato") and equal(local(restored),gelato),"Developer revisit after restart restores exact Gelato twins, rebuilt Power, wallet and trials")
	var again = fixture()
	again.load_game()
	check(not again.profile_load_blocked and again.area_id=="gelato" and equal(local(again),gelato),"A second fresh instance restarts directly into the retained Gelato build")
	check(is_equal_approx(again.tuning.core_cost_growth,1.6) and again.twin_launchers and again.levels[1]==1,"Restart restores Gelato economy and the rebuilt-Power state")
	again.free(); restored.free(); game.free()

func cleanup():
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(test_path+suffix):
			assert(DirAccess.remove_absolute(test_path+suffix)==OK,"Isolated developer-area QA cleanup failed")

func _initialize():
	test_path = OS.get_environment("SUGARFALL_DEVELOPER_AREA_QA_SAVE").replace("\\","/").simplify_path()
	var user_root = OS.get_user_data_dir().replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if "--developer-area-qa-isolated" not in OS.get_cmdline_user_args() or not test_path.is_absolute_path() or test_path.get_file()!="developer-area-qa.json" or not test_path.to_lower().begins_with(user_root.to_lower()):
		push_error("Developer area QA requires its reserved absolute save path inside isolated user data and --developer-area-qa-isolated")
		quit(2)
		return
	cleanup()
	first_entry_and_revisits()
	guards_and_rollback()
	normal_entry_is_unchanged()
	persistence_and_restart()
	cleanup()
	print("DEVELOPER_AREA_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
