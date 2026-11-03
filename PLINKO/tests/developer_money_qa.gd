extends SceneTree
## Developer purchase policy against real game APIs. All persistence stays in memory.
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var tools_allowed = true
	var profile_reads = 0
	var writes = 0
	var fail_write = false
	var candidate: Dictionary = {}
	func _ready(): pass
	func load_game(): profile_reads += 1
	func developer_tools_available() -> bool: return tools_allowed
	func write_profile_file(data: Dictionary) -> bool:
		writes += 1
		candidate = data.duplicate(true)
		return not fail_write
	func legacy_profile_path() -> String: return ""

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fresh(id: String = "bakery"):
	var game = Fixture.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.active = false
	game.first_run_guide.completed = true
	game.set_active_area(id)
	game.bank = 12.34
	game.levels = [0,0,0,0,0,0,0,0]
	game.highest_unlocked = 1
	game.current_level = 1
	game.best_wave = 1
	game.chapter_complete = false
	game.module_vouchers = 0
	game.module_milestones = []
	game.equipped = []
	game.twin_launchers = false
	game.power_reset_tier = 0
	game.trial_records = {}
	game.run_id = ""
	game.shift_claimed = true
	game.mode = "developer_areas"
	game.area_records = {"bakery":game.AreaCampaign.default_record()}
	game.area_records[id] = game.AreaCampaign.capture_local(game)
	game.area_entries = []
	game.developer_free_purchases = {}
	return game

func ordinary_and_free_purchases():
	var game = fresh()
	var initial = game.bank
	check(not game.developer_money_enabled() and not game.can_afford(game.upgrade_cost(0)),"A fresh developer session begins with ordinary affordability")
	game.mode = "shop"
	check(not game.buy_upgrade(0) and game.levels[0]==0 and game.bank==initial,"Insufficient real money still blocks an upgrade while the toggle is off")
	game.mode = "developer_areas"
	check(game.set_developer_money(true) and game.developer_money_enabled(),"Developer settings can enable infinite money for the current area")
	check(game.bank==initial and game.writes==0,"Enabling free purchases never fabricates or saves wallet money")
	check(game.can_afford(1000000) and game.spend_coins(1000000) and game.bank==initial,"Free spending bypasses affordability without decrementing the real wallet")
	var cost = game.upgrade_cost(0)
	game.mode = "shop"
	check(game.buy_upgrade(0) and game.levels[0]==1 and game.bank==initial,"Infinite money buys a real upgrade while retaining exact earned coins")
	check(cost>0 and game.upgrade_cost(0)>cost,"Developer purchases keep normal displayed costs and price growth")
	check(not game.buy_upgrade(1) and game.levels[1]==0,"Infinite money does not bypass the predecessor of a locked Power node")
	check(game.buy_upgrade(2) and game.levels[2]==1 and game.bank==initial,"A normally revealed successor remains purchasable with infinite money")
	game.levels[0] = game.MAX_LEVELS[0]
	check(not game.buy_upgrade(0) and game.levels[0]==game.MAX_LEVELS[0],"Infinite money cannot buy beyond an upgrade cap")
	game.mode = "developer_areas"
	check(game.set_developer_money(false) and not game.developer_money_enabled() and game.bank==initial,"Turning off infinite money restores the original real balance")
	check(game.can_afford(10) and game.spend_coins(10) and is_equal_approx(game.bank,2.34),"Ordinary spending deducts exact coins again after switching off")
	check(not game.spend_coins(3) and is_equal_approx(game.bank,2.34),"A rejected normal spend leaves the wallet untouched")
	check(game.profile_reads==0,"Purchase fixtures never read player saves")
	game.free()

func per_area_and_session_scope():
	var game = fresh()
	check(game.set_developer_money(true),"Bakery can start its own free-purchase session")
	check(game.developer_switch_area("gelato") and not game.developer_money_enabled(),"First Gelato visit starts with its own infinite-money switch off")
	check(game.bank==0 and game.levels==[0,0,0,0,0,0,0,0] and game.area_entries.is_empty(),"Testing switch does not inject money, upgrades or an entry-fee ledger into a new area")
	game.mode = "developer_areas"
	check(game.set_developer_money(true),"Gelato can independently enable infinite money")
	game.mode = "shop"
	check(game.buy_upgrade(0) and game.levels[0]==1 and game.bank==0,"Zero-wallet Gelato can buy its first real upgrade")
	game.mode = "developer_areas"
	check(game.developer_switch_area("bakery") and game.developer_money_enabled() and game.bank==12.34,"Returning to Bakery restores its money and its session switch")
	game.mode = "developer_areas"
	check(game.set_developer_money(false),"Bakery's switch can be turned off without touching Gelato")
	check(game.developer_switch_area("gelato") and game.developer_money_enabled() and game.levels[0]==1,"Gelato retains its own active session switch and purchased build")
	check(not game.candidate.has("developer_free_purchases") and not game.candidate.has("developer_money_enabled"),"Developer toggles are absent from the saved profile envelope")
	check(game.AreaCampaign.decode_profile(game.candidate).ok and game.candidate.areas.gelato.bank==0 and game.candidate.areas.gelato.levels[0]==1,"Saved campaign contains real upgrades and an unchanged finite wallet")
	var restarted = fresh("gelato")
	var decoded: Dictionary = restarted.AreaCampaign.decode_profile(game.candidate)
	restarted.area_records = decoded.records
	restarted.AreaCampaign.apply_local(restarted,decoded.records.gelato)
	check(not restarted.developer_money_enabled() and restarted.levels[0]==1 and restarted.bank==0,"A new session starts the toggle off while saved purchases remain owned")
	game.reset_profile_runtime()
	check(not game.developer_money_enabled() and game.developer_free_purchases.is_empty(),"Reset progress clears developer switches along with campaign state")
	check(game.profile_reads==0 and restarted.profile_reads==0,"Per-area and restart fixtures never read actual profiles")
	restarted.free()
	game.free()

func twin_purchases_and_trials():
	var game = fresh("gelato")
	game.bank = 0
	game.current_level = 8
	game.highest_unlocked = 8
	game.best_wave = 8
	game.levels = [5,6,3,1,1,3,2,3]
	game.gelato_shop_revision=0
	check(game.ensure_gelato_shop_state(),"Legacy-count Twin fixture migrates before free purchases")
	check(game.set_developer_money(true),"Eligible Gelato build enables free testing")
	var prior = game.levels.duplicate()
	game.mode = "shop"
	check(game.buy_twin_launchers() and game.twin_launchers and game.bank==0,"Infinite money can buy eligible Twin launchers without a wallet grant")
	prior[1] = 0
	check(game.levels==prior and game.power_reset_tier==6,"Free Twin purchase retains the real Power-reset tradeoff and other upgrades")
	check(not game.buy_twin_launchers() and game.bank==0,"Infinite money cannot purchase Twin launchers twice")
	check(game.buy_upgrade(1) and game.levels[1]==1 and game.bank==0,"Reset Power can be rebuilt normally while free purchases are enabled")
	var saved_build = game.levels.duplicate()
	game.mode = "home"
	check(game.begin_trial(4) and not game.developer_money_enabled(),"Practice Trials never inherit an active campaign money cheat")
	check(not game.can_afford(1),"A zero-wallet Trial cannot use campaign infinite money")
	game.end_trial()
	check(game.developer_money_enabled() and game.levels==saved_build and game.bank==0,"Leaving a Trial restores the campaign build and its session setting")
	game.free()
	game = fresh("gelato")
	game.set_developer_money(true)
	game.mode = "shop"
	check(not game.buy_twin_launchers() and not game.twin_launchers,"Infinite money does not skip the Twin tray or Power requirements")
	game.current_level = 8; game.highest_unlocked = 8; game.best_wave = 8
	game.levels = [5,6,3,1,1,3,2,3]
	game.gelato_shop_revision=0
	check(game.ensure_gelato_shop_state(),"Legacy-count rollback fixture migrates before its failed write")
	game.testing = false
	game.fail_write = true
	var before: Dictionary = game.AreaCampaign.capture_local(game)
	check(not game.buy_twin_launchers() and game.AreaCampaign.capture_local(game)==before,"A failed saved Twin purchase rolls back its build even when spending is free")
	check(game.profile_reads==0,"Twin and Trial fixtures never read player saves")
	game.free()

func release_and_navigation_guards():
	var game = fresh()
	game.developer_free_purchases["bakery"] = true
	game.tools_allowed = false
	check(not game.developer_money_enabled() and not game.can_afford(100),"Normal release builds ignore even a stale in-memory testing flag")
	check(not game.set_developer_money(true) and not game.spend_coins(100) and game.bank==12.34,"A disabled developer API cannot grant free money or purchases")
	game.free()
	for blocker in ["mode","trial","transition","pending_run","transaction","profile","onboarding","commerce"]:
		game = fresh()
		match blocker:
			"mode": game.mode = "play"
			"trial": game.trial_active = true
			"transition": game.run_transition.active = true
			"pending_run": game.run_id = "pending"; game.shift_claimed = false
			"transaction": game.area_transaction_pending = true
			"profile": game.profile_load_blocked = true
			"onboarding": game.first_run_guide.active = true
			"commerce": game.monetization.pending = {"id":"pending"}
		check(not game.set_developer_money(true) and not game.developer_free_purchases.get("bakery",false),"Infinite-money changes respect the %s navigation guard" % blocker)
		game.free()

func _initialize():
	ordinary_and_free_purchases()
	per_area_and_session_scope()
	twin_purchases_and_trials()
	release_and_navigation_guards()
	print("DEVELOPER_MONEY_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
