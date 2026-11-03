extends SceneTree
const Rules = preload("res://scripts/flow_rules.gd")
const Combat = preload("res://scripts/combat_balance.gd")
var passed = 0
var failures: Array[String] = []

func check(ok: bool, label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	for value in [1,1.0,2,2.0]: check(Rules.valid_revision(value),"Accept supported exact revision "+str(value))
	for value in [null,true,false,"2",0,-1,1.5,3,1.7e308,INF,NAN]: check(not Rules.valid_revision(value),"Reject unsupported/malformed revision "+str(value))
	for tray in range(1,13):
		var base = float([6,12,18,24][int((tray-1)/3)])
		check(Rules.normal_hp(base,tray,false,1)==base and Rules.damage_budget(6,tray,false,1)==6 and Rules.break_reward(9,tray,false,1)==9 and Rules.clear_reward(40+tray*5,tray,false,1)==40+tray*5,"Legacy tray%d keeps exact HP and all income"%tray)
		check(Rules.normal_hp(base,tray,true,2)==base and Rules.damage_budget(6,tray,true,2)==6 and Rules.break_reward(9,tray,true,2)==9 and Rules.clear_reward(40+tray*5,tray,true,2)==40+tray*5,"Trial tray%d keeps exact authored values"%tray)
		check(is_equal_approx(Rules.normal_hp(base,tray,false,2),base*(1.15 if tray>=8 else 1.0)),"Current tray%d HP applies late wall only"%tray)
		if tray<8: check(Rules.damage_budget(6,tray,false,2)==6 and Rules.break_reward(3,tray,false,2)==3,"Opening tray%d keeps rewards"%tray)
	check(Rules.damage_budget(6,8,false)==8 and Rules.damage_budget(9,8,false)==11,"Bakery/Gelato budgets round once to8/11")
	check(Rules.damage_budget(8,8,false)==10 and Rules.damage_budget(12,8,false)==15,"Crystal budgets become10/15")
	check(Rules.break_reward(3,8,false)==4 and Rules.break_reward(9,8,false)==11,"Final ordinary/prism reward rounded after authored multiplier")
	check(Rules.clear_reward(80,8,false)==100 and Rules.clear_reward(85,8,false)==106,"Tray8 clear rewards are whole coins")
	for value in [0.0,-1.0,NAN,INF,-INF]: check(Rules.normal_hp(value,8,false)==0.0,"Invalid HP stays finite and nonnegative")
	check(is_finite(Rules.normal_hp(1.7e308,8,false)),"Finite extreme HP does not overflow")
	check(Rules.damage_budget(-10,8,false)==0 and Rules.clear_reward(9223372036854775807,8,false)==Rules.MAX_REWARD,"Reward bounds cannot overflow or become negative")
	for hp in [20.7,27.6,41.4,49.68,55.2]:
		for budget in [8,10,11,15]:
			var before=hp
			var earned=0
			var ticks=0
			while before>0 and ticks<10000:
				var after=maxf(0,before-.137)
				earned+=Combat.damage_coins(hp,before,after,budget)
				before=after; ticks+=1
			check(earned==budget,"Fractional hits conserve hp%.2f budget%d"%[hp,budget])
			check(Combat.damage_coins(hp,0,0,budget)==0,"Dead pegs cannot repeat late budget")
			var saved_hp=hp*.63
			var paid_before=Combat.damage_coins(hp,hp,saved_hp,budget)
			var paid_after=Combat.damage_coins(hp,saved_hp,0,budget)
			check(paid_before+paid_after==budget,"Checkpoint split conserves pinned late budget")
	# A revision belongs to the run: loading revision1 uses its original total even
	# when the default for NEW runs has advanced. No partial coin ledger migration.
	var old_hp=24.0
	var partial_hp=16.9
	var legacy_paid=Combat.damage_coins(old_hp,old_hp,partial_hp,Rules.damage_budget(6,10,false,1))
	var legacy_tail=Combat.damage_coins(old_hp,partial_hp,0,Rules.damage_budget(6,10,false,1))
	check(legacy_paid+legacy_tail==6 and Rules.normal_hp(old_hp,10,false,1)==24,"Pinned legacy checkpoint finishes original six-coin budget at original HP")
	check(legacy_paid+Combat.damage_coins(old_hp,partial_hp,0,Rules.damage_budget(6,10,false,2))!=6,"Regression sentinel detects accidental mid-run reward-revision switch")
	print("FLOW_RULES_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
