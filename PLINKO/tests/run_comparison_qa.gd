extends SceneTree
## Uses only its explicit custom fixture save inside verified isolated user data.
const History = preload("res://scripts/run_history.gd")
const SAVE = "user://run_comparison_qa.json"
var passed = 0
var failures: Array[String] = []

class ComparisonGame extends "res://scripts/main.gd":
	var fail_write = false
	var candidate: Dictionary = {}
	var history_at_write: Dictionary = {}
	func _ready(): pass
	func write_profile_file(data: Dictionary) -> bool:
		candidate = data.duplicate(true)
		history_at_write = result_history.export_state().duplicate(true)
		if fail_write: return false
		return super.write_profile_file(data)

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func same(a, b) -> bool:
	return JSON.stringify(a,"",true) == JSON.stringify(b,"",true)

func fixture():
	var game = ComparisonGame.new()
	game.SAVE_FILE = SAVE
	game.testing = false
	game.sound_on = false
	game.set_active_area("bakery")
	game.first_run_guide.completed = true
	game.shift_claimed = true
	return game

func restart():
	var game = fixture()
	game.load_game()
	return game

func clear_storage():
	for path in [SAVE,SAVE+".tmp"]:
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)

func read_save() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return value if value is Dictionary else {}

func write_save(data: Dictionary):
	var file = FileAccess.open(SAVE,FileAccess.WRITE)
	assert(file != null,"Isolated QA save must be writable")
	file.store_string(JSON.stringify(data,"",true,true))
	file.close()

func run_record(id: String, coins: float) -> Dictionary:
	return {"run_id":id,"coins":coins,"destroyed":6,"peg_total":28,"combo":3,"wave":1}

func finish_result(game, coins: float, ending: String = "timeout") -> bool:
	game.start_shift()
	game.shift_coins = coins
	game.destroyed = mini(6,game.result_peg_total)
	game.max_combo = 3
	game.remaining = 0 if ending == "timeout" else 4
	if ending == "clear":
		game.level_won = true
		game.destroyed = game.result_peg_total
		for peg in game.pegs: peg.hp = 0
	elif ending == "early": game.mode = "paused"
	return game.finish_shift(false)

func arithmetic_and_identity():
	var cases = [
		[40.0,50.0,"up","25%"], [40.0,30.0,"down","25%"],
		[40.0,40.0,"same","0%"], [40.0,0.0,"down","100%"],
		[0.0,0.0,"same","0%"], [0.0,.01,"from_zero",""],
		[100.0,100.01,"up","<0.1%"], [100.0,99.99,"down","<0.1%"],
		[3.0,4.0,"up","33.3%"], [.55,.60,"up","9.1%"]
	]
	for sample in cases:
		var history = History.new()
		var previous = run_record("previous",sample[0])
		var current = run_record("current",sample[1])
		history.record_run("bakery",previous)
		var comparison = history.comparison("bakery",current)
		check(comparison.direction == sample[2] and comparison.percent_text == sample[3],"Exact base earnings %s to %s produce %s %s" % [sample[0],sample[1],sample[2],sample[3]])
		check(same(comparison.current,current) and same(comparison.previous,previous),"Comparison preserves fractional earnings and both run identities")
		history.record_run("bakery",current)
		check(same(history.comparison("bakery",current),comparison),"Recording the current result retains its prior-run comparison")
	var history = History.new()
	var first = run_record("first",.55)
	check(history.comparison("bakery",first).direction == "first" and history.comparison("bakery",first).previous.is_empty() and history.comparison("bakery",first).percent_text.is_empty(),"A first run has no invented baseline or percentage")
	history.record_run("bakery",first)
	check(history.comparison("bakery",first).direction == "first","The first recorded result still compares as a first run")
	var second = run_record("second",10.1)
	history.record_run("bakery",second)
	var before = history.export_state().duplicate(true)
	history.record_run("bakery",second)
	var changed = second.duplicate(); changed.coins = 900
	history.record_run("bakery",changed)
	check(same(history.export_state(),before),"Repeated current run identity cannot rotate history or rewrite base earnings")
	var exported = history.export_state()
	exported.areas.bakery.latest.coins = 700
	check(same(history.export_state(),before),"A caller cannot mutate stored history through an exported dictionary")
	var restored = History.new()
	restored.import_state(JSON.parse_string(JSON.stringify(before)))
	check(same(restored.export_state(),before) and same(restored.comparison("bakery",second),history.comparison("bakery",second)),"History and its stable comparison survive JSON serialization")

func optional_validation():
	var valid = History.new()
	valid.record_run("bakery",run_record("bakery",12.55))
	valid.record_run("gelato",run_record("gelato",27.25))
	var baseline = valid.export_state()
	var malformed = [null,[],true,"invalid",{"version":99,"areas":{}},{"version":1,"areas":[]}]
	for value in malformed:
		var history = History.new()
		history.import_state(value)
		check(history.comparison("bakery",run_record("new",20)).direction == "first","Malformed optional history is ignored safely: %s" % str(value))
	var invalid_fields = [
		["coins",-1],["coins",10000000.01],["coins",.001],["coins",NAN],["coins",INF],["coins",true],
		["destroyed",29],["destroyed",-1],["peg_total",0],["peg_total",49],
		["combo",49],["combo",1.5],["wave",0],["wave",13],["run_id",""],["run_id","x".repeat(129)]
	]
	for invalid in invalid_fields:
		var state = baseline.duplicate(true)
		state.areas.bakery.latest[invalid[0]] = invalid[1]
		var history = History.new()
		history.import_state(state)
		check(history.comparison("bakery",run_record("new",20)).direction == "first" and history.comparison("gelato",run_record("next",30)).previous.run_id == "gelato","Invalid %s history does not contaminate another area's valid baseline" % invalid[0])
	clear_storage()
	var game = fixture()
	game.bank = 123.45
	game.levels[0] = 2
	check(game.save_game(),"Valid campaign fixture saves before optional metadata corruption")
	var campaign = read_save()
	game.free()
	for value in [null,"broken",{"version":1,"areas":{"bakery":{"latest":{"coins":"bad"}},"gelato":{}}}]:
		var data = campaign.duplicate(true)
		if value == null: data.erase("run_history")
		else: data.run_history = value
		write_save(data)
		game = restart()
		check(not game.profile_load_blocked and game.mode == "home" and is_equal_approx(game.bank,123.45) and game.levels[0] == 2,"Missing or malformed optional history never blocks otherwise valid campaign loading")
		game.free()

func finish_save_reload_and_claim():
	clear_storage()
	var game = fixture()
	game.result_history.record_run("bakery",run_record("baseline",20.25))
	check(finish_result(game,30.75),"Finishing a campaign run persists its result")
	var id: String = game.run_id
	var expected: Dictionary = game.run_comparison().duplicate(true)
	check(expected.current.run_id == id and expected.previous.run_id == "baseline" and is_equal_approx(expected.current.coins,30.75),"New result compares its base earnings to the preceding campaign run")
	var data = read_save()
	check(data.has("run_history") and data.has("pending_result") and data.run_history.areas.bakery.latest.run_id == id and data.run_history.areas.bakery.previous.run_id == "baseline","One save contains both the pending result and its unchanged previous baseline")
	check(not game.finish_shift(false) and same(game.run_comparison(),expected),"Repeated finish cannot rotate an already completed result")
	game.save_game(); game.save_game()
	check(same(game.run_comparison(),expected),"Repeated saves do not rotate the result comparison")
	game.free()
	for attempt in range(3):
		game = restart()
		check(game.mode == "result" and not game.profile_load_blocked and same(game.run_comparison(),expected),"Pending result reload %d retains its original previous-run baseline" % (attempt+1))
		game.save_game()
		if attempt < 2: game.free()
	var history_before = game.result_history.export_state().duplicate(true)
	game.collect_reward()
	var balance: float = game.bank
	game.collect_reward()
	check(game.mode == "home" and is_equal_approx(balance,30.75) and game.bank == balance and same(game.result_history.export_state(),history_before),"Collect pays once while repeated claims leave run history unchanged")
	game.free()
	game = restart()
	check(game.mode == "home" and same(game.result_history.export_state(),history_before),"Reload after collection retains the last completed run without replaying its reward")
	check(finish_result(game,15.35),"The next campaign run finishes successfully")
	var next = game.run_comparison()
	check(next.previous.run_id == id and is_equal_approx(next.previous.coins,30.75) and next.direction == "down","The next result uses the immediately prior completed base earnings")
	game.free()

func old_pending_hydration():
	clear_storage()
	var game = fixture()
	finish_result(game,18.55)
	var pending_id: String = game.run_id
	var data = read_save()
	data.erase("run_history")
	write_save(data)
	game.free()
	game = restart()
	check(game.mode == "result" and game.run_comparison().direction == "first" and game.run_comparison().current.run_id == pending_id,"An older pending result without history becomes a first result safely")
	game.save_game()
	game.free()
	game = restart()
	check(game.run_comparison().direction == "first" and game.result_history.export_state().areas.bakery.latest.run_id == pending_id,"Hydrating an old pending result is idempotent across later saves and reloads")
	game.free()

func bonus_and_trial_isolation():
	clear_storage()
	var game = fixture()
	game.result_history.record_run("bakery",run_record("prior",10.1))
	finish_result(game,20.2)
	var original = game.run_comparison().duplicate(true)
	game.monetization.entitlements.baker_toolkit = true
	check(is_equal_approx(game.result_payout(),24.24) and same(game.run_comparison(),original),"Toolkit payout adds coins without changing the base run comparison")
	game.begin_rewarded_ad()
	check(game.mode == "test_ad","The real rewarded-ad simulation starts from the pending result")
	game.finish_test_request("completed")
	check(game.reward_earned and is_equal_approx(game.result_payout(),34.34) and same(game.run_comparison(),original),"Completed rewarded ads affect the payout while preserving the original comparison")
	game.free()
	game = restart()
	check(game.reward_earned and is_equal_approx(game.result_payout(),34.34) and same(game.run_comparison(),original),"Reloading a bonus-eligible result keeps exact base earnings and the original percentage")
	game.collect_reward()
	check(is_equal_approx(game.bank,34.34),"Collection still grants the full toolkit and rewarded payout")
	var campaign_history = game.result_history.export_state().duplicate(true)
	game.highest_unlocked = 4
	check(game.begin_trial(4),"A normal trial can begin from the claimed campaign result")
	game.start_shift()
	game.shift_coins = 999.99
	game.remaining = 0
	game.finish_shift(false)
	check(game.trial_active and same(game.result_history.export_state(),campaign_history),"A finished trial cannot become the campaign's comparison baseline")
	game.free()
	game = restart()
	check(game.trial_active and game.mode == "result" and same(game.result_history.export_state(),campaign_history),"Loading a pending trial preserves campaign comparison history")
	game.collect_reward()
	check(not game.trial_active and same(game.result_history.export_state(),campaign_history),"Leaving a trial does not rotate campaign history")
	game.free()

func end_types_and_areas():
	clear_storage()
	var game = fixture()
	var ids = []
	for ending in ["early","clear","timeout"]:
		check(finish_result(game,10.0+ids.size(),ending),"A %s campaign result is persisted" % ending)
		var current = game.run_comparison()
		check(current.current.run_id == game.run_id and current.current.destroyed == game.destroyed and current.current.peg_total == game.result_peg_total and current.current.combo == game.max_combo and current.current.wave == game.wave,"The %s result records its actual run statistics" % ending)
		if not ids.is_empty(): check(current.previous.run_id == ids.back(),"The %s result follows the last finished run regardless of how it ended" % ending)
		ids.append(game.run_id)
		game.collect_reward()
	var bakery_history = game.result_history.export_state().areas.bakery.duplicate(true)
	game.area_records.bakery = game.AreaCampaign.capture_local(game)
	game.area_records.gelato = game.AreaCampaign.default_record()
	game.set_active_area("gelato")
	game.AreaCampaign.apply_local(game,game.area_records.gelato)
	finish_result(game,50.5)
	check(game.run_comparison().direction == "first" and same(game.result_history.export_state().areas.bakery,bakery_history),"Gelato's first run has its own baseline and leaves Bakery history untouched")
	var gelato_id: String = game.run_id
	game.collect_reward()
	finish_result(game,60.6)
	check(game.run_comparison().previous.run_id == gelato_id and game.run_comparison().direction == "up" and game.run_comparison().percent_text == "20%","Later Gelato results compare only with the previous Gelato run")
	game.free()
	game = restart()
	check(game.area_id == "gelato" and game.run_comparison().previous.run_id == gelato_id and same(game.result_history.export_state().areas.bakery,bakery_history),"Both area histories persist independently when reloading the active Gelato result")
	game.free()

func reset_and_write_failure():
	clear_storage()
	var game = fixture()
	game.result_history.record_run("bakery",run_record("old-a",10.25))
	game.result_history.record_run("bakery",run_record("old-b",20.5))
	game.result_history.record_run("gelato",run_record("gelato",70.75))
	game.bank = 321.45
	check(game.save_game(),"Reset fixture saves existing campaign and result history")
	var previous_history = game.result_history.export_state().duplicate(true)
	var previous_bytes = FileAccess.get_file_as_bytes(SAVE)
	game.mode = "support"
	game.request_progress_reset()
	game.fail_write = true
	check(not game.reset_progress() and same(game.result_history.export_state(),previous_history) and game.bank == 321.45 and FileAccess.get_file_as_bytes(SAVE) == previous_bytes,"A failed reset save preserves live history, campaign and previous save bytes")
	game.fail_write = false
	check(game.reset_progress(),"Confirmed reset succeeds once storage becomes writable")
	check(same(game.history_at_write,previous_history),"Fresh history is committed before clearing the live previous-run records")
	check(game.result_history.comparison("bakery",run_record("fresh",1)).direction == "first" and game.result_history.comparison("gelato",run_record("fresh-g",1)).direction == "first","Successful reset clears both area's comparison baselines")
	game.free()
	game = restart()
	check(game.bank == 0 and game.mode == "home" and game.result_history.comparison("bakery",run_record("fresh",1)).direction == "first" and game.result_history.comparison("gelato",run_record("fresh-g",1)).direction == "first","Reload after reset cannot resurrect old result history")
	game.first_run_guide.finish()
	finish_result(game,4.55)
	check(game.run_comparison().direction == "first","The first completed run after reset receives a fresh first-run comparison")
	game.free()

func _initialize():
	if "--comparison-qa-isolated" not in OS.get_cmdline_user_args():
		print("RUN_COMPARISON_QA_REFUSED: Use isolated user-data directories and --comparison-qa-isolated.")
		quit(2)
		return
	clear_storage()
	arithmetic_and_identity()
	optional_validation()
	finish_save_reload_and_claim()
	old_pending_hydration()
	bonus_and_trial_isolation()
	end_types_and_areas()
	reset_and_write_failure()
	clear_storage()
	print("RUN_COMPARISON_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
