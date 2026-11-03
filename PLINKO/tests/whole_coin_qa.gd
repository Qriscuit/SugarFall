extends SceneTree
## Currency presentation checks only. No player profiles are opened or written.
const CoinDisplay = preload("res://scripts/coin_display.gd")
var passed = 0
var failures: Array[String] = []
var g

class CurrencyGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
	func _ready(): pass
	func save_game(): persistence_attempts += 1
	func load_game(): persistence_attempts += 1

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failures.append(label)
		print("FAIL: ", label)

func fresh():
	g.testing = true
	g.sound_on = false
	g.reduced_motion = false
	g.trial_active = false
	g.levels = [0,0,0,0,0,0,0,0]
	g.current_level = 1
	g.highest_unlocked = 1
	g.total_shifts = 0
	g.module_milestones.clear()
	g.bank = 0.0
	g.monetization.entitlements.baker_toolkit = false
	g.start_shift()

func display_boundaries():
	for sample in [[0.0,"0"],[.55,"0"],[1.0,"1"],[1.99,"1"],[29.99,"29"],[30.0,"30"],[1234.55,"1234"],[100000000.0,"100000000"]]:
		check(g.credits_text(sample[0])==sample[1],"Whole coin text for %s is %s" % [str(sample[0]),sample[1]])
	check(g.credits_needed_text(.01)=="1" and g.credits_needed_text(1.01)=="2" and g.credits_needed_text(30)=="30","Shortfalls round up so a positive shortage never says Need 0")
	var consistent = true
	for cents in range(0,3101):
		var balance = cents / 100.0
		consistent = consistent and ((int(g.credits_text(balance))>=30)==(balance>=30))
	check(consistent,"Displayed affordability agrees with a thirty-coin price at every cent from zero through thirty-one")
	check(CoinDisplay.gain(.75,.55)==1 and CoinDisplay.gain(0,.55)==0,"Carried fractional earnings only show a coin when the whole balance advances")
	check(CoinDisplay.gain(29.95,.05)==1,"An exact cent boundary does not lose a whole coin to floating-point arithmetic")

func catch_food(kind: String):
	g.spawn_clock = .74
	g.spawn_ball(Vector2(360,g.BUCKET_CATCH_Y+1),kind,Vector2.ZERO)
	g.balls[-1].productive = true
	g.step(.001)

func live_payouts():
	fresh()
	catch_food("shard")
	check(is_equal_approx(g.shift_coins,.55) and g.credits_text(g.shift_coins)=="0","First seed retains its fractional earning internally while the counter remains whole")
	check(g.floats.is_empty(),"A sub-coin catch does not produce a misleading +0 popup")
	catch_food("shard")
	check(is_equal_approx(g.shift_coins,1.15) and g.floats.size()==1 and g.floats[-1].text=="+1","The next seed crosses one whole coin and shows +1")
	catch_food("shard")
	check(is_equal_approx(g.shift_coins,1.8) and g.floats.size()==1,"A later fractional catch keeps its earning without a zero popup")
	catch_food("shard")
	catch_food("normal")
	var shown = 0
	var integer_only = true
	for item in g.floats:
		integer_only = integer_only and item.text.begins_with("+") and item.text.substr(1).is_valid_int() and int(item.text.substr(1))>0
		shown += int(item.text.substr(1))
	check(integer_only and shown==int(g.credits_text(g.shift_coins)) and shown==4,"Mixed seed and donut popups add up to the visible run counter without decimal or zero text")
	check(is_equal_approx(g.bucket_reward(2),1.5),"Whole coin presentation preserves decimal bucket multiplier growth")
	g.reduced_motion = true
	var count = g.floats.size()
	catch_food("normal")
	check(g.floats.size()==count and is_equal_approx(g.shift_coins,5.6),"Reduced Motion still earns exact credits without introducing a floating popup")

func prepare_result(balance: float, earned: float, toolkit: bool = false, rewarded: bool = false):
	fresh()
	g.bank = balance
	g.shift_coins = earned
	g.monetization.entitlements.baker_toolkit = toolkit
	g.reward_earned = rewarded
	g.remaining = 0
	g.finish_shift(false)

func collect_matches_preview():
	for sample in [[.8,.4,false,false,1],[30.35,3.05,false,false,3],[.99,10.10,true,true,18],[0.0,10.10,true,true,17],[.2,.55,false,false,0],[.95,.05,false,false,1]]:
		prepare_result(sample[0],sample[1],sample[2],sample[3])
		var before: float = g.bank
		var exact: float = g.result_payout()
		var displayed: int = g.displayed_result_payout()
		check(displayed==int(sample[4]),"Collect preview counts the wallet's actual whole-coin increase for balance %s and payout %s" % [str(before),str(exact)])
		g.collect_reward(false)
		check(is_equal_approx(g.bank,g.round_credits(before+exact)) and int(g.credits_text(g.bank))-int(g.credits_text(before))==displayed,"Collection preserves exact cents and matches its whole-coin preview")
		check(g.note.begins_with("Collected %d credits" % displayed),"Collection toast reports the same whole-coin amount")
		var claimed: float = g.bank
		g.collect_reward(true)
		check(is_equal_approx(g.bank,claimed),"Repeating a collection cannot create extra coins through display rounding")
	prepare_result(.95,10.10,true,false)
	var ordinary: int = g.displayed_result_payout()
	var bonus: int = g.displayed_reward_bonus()
	g.reward_earned = true
	check(bonus==5 and g.displayed_result_payout()-ordinary==bonus,"Rewarded offer previews exactly the additional whole coins in the final Collect amount")
	check(g.displayed_reward_bonus()==0,"An already-earned reward cannot be offered as an additional displayed gain")
	prepare_result(0,.55,false,false)
	check(g.displayed_reward_bonus()==0 and is_equal_approx(g.result_payout(),.55),"Tiny optional bonuses can display no numeric amount without discarding the underlying earning")
	prepare_result(.8,.4,false,false)
	g.levels[3]=1; g.levels[4]=1; g.levels[5]=1
	g.current_level=2; g.wave=2; g.level_won=true
	var milestone_display: int = g.displayed_result_payout()
	g.collect_reward(false)
	check(milestone_display==61 and is_equal_approx(g.bank,61.2) and g.note.begins_with("Collected 61 credits"),"An all-modules-owned milestone includes its sixty-coin substitute in both preview and collection")
	check(2 in g.module_milestones and is_equal_approx(g.collection_payout(),g.result_payout()),"An already-claimed milestone is never previewed a second time")

func purchase_and_storage_contracts():
	fresh()
	var price=g.upgrade_cost(0)
	g.bank=price-.01
	check(not g.buy_upgrade(0) and g.credits_text(g.bank)==str(price-1) and g.note=="Need 1 more credits","A just-unaffordable purchase keeps its red state and a truthful whole-coin shortfall")
	g.bank=price+.35
	check(g.buy_upgrade(0) and g.credits_text(g.bank)=="0" and is_equal_approx(g.bank,.35),"Buying an integer-cost upgrade retains the hidden fraction without rounding spendable funds up")
	g.shift_coins=1.75
	check(is_equal_approx(g.campaign_profile().bank,.35) and is_equal_approx(g.pending_result_data().coins,1.75),"Campaign and result serialization still preserve exact fractional balances")
	check(g.credits_text(g.bank)=="0" and g.credits_text(g.shift_coins)=="1","Restored-style fractional values are immediately presented as whole coins")

func _initialize():
	g = CurrencyGame.new()
	g.board_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	display_boundaries()
	live_payouts()
	collect_matches_preview()
	purchase_and_storage_contracts()
	check(g.persistence_attempts==0,"Currency fixtures never read or write a player profile")
	g.free()
	print("WHOLE_COIN_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
