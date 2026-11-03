extends SceneTree
## Live damage/collision and restart accounting. Fixtures never access profiles.
const Balance=preload("res://scripts/combat_balance.gd")
const Rules=preload("res://scripts/flow_rules.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
const OLD_HASHES={"bakery":"afc02ea91b0441cd02e934efe3d325875c847e9f644c4c60ceed1f86a12743c8","gelato":"5a0bd00a920e20cc8aca0255b477147de84e305c50cfcfcb9ba40013fbca4870"}
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var profile_reads=0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): profile_reads+=1
	func save_game(): return true

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area: String):
	var game=Fixture.new()
	game.testing=true; game.sound_on=false; game.first_run_guide.completed=true
	game.set_active_area(area); game.highest_unlocked=12
	return game

func ordinary(game):
	for peg in game.pegs:
		if peg.kind=="normal" and peg.hp>0: return peg
	return {}

func budgets():
	for area in ["bakery","gelato"]:
		var game=fixture(area)
		for tray in [1,4,7,10,12]:
			for kind in ["normal","clock","prism","armored"]:
				for hit_size in [.1,.5,1.675,9999.0]:
					game.current_level=tray; game.start_shift()
					var peg=ordinary(game); peg.kind=kind
					if kind=="armored": peg.hp*=2; peg.max*=2
					var budget=Rules.damage_budget(9 if kind=="armored" else 6,tray,false,game.run_rules_revision)
					var break_reward=2+floori(float(tray-1)/4.0)
					if kind=="prism": break_reward*=3
					break_reward=Rules.break_reward(break_reward,tray,false,game.run_rules_revision)
					var count=0
					while peg.hp>0 and count<1000:
						game.damage_peg(peg,hit_size); count+=1
					check(game.shift_coins==budget+break_reward and game.destroyed==1,"Fixed budget and break: %s tray%d %s hit%.3f" % [area,tray,kind,hit_size])
					var paid=float(game.shift_coins); game.damage_peg(peg,9999)
					check(game.shift_coins==paid and peg.hp==0.0,"No duplicate or overkill earnings: %s tray%d %s hit%.3f" % [area,tray,kind,hit_size])
		game.current_level=10; game.start_shift()
		var peg=ordinary(game)
		var boundary=float(peg.max)/Rules.damage_budget(6,10,false,game.run_rules_revision)
		game.damage_peg(peg,boundary-.1)
		check(game.shift_coins==0 and is_equal_approx(peg.hp,peg.max-boundary+.1),"Diamond waits for its current budget's first HP boundary: "+area)
		game.damage_peg(peg,.1)
		check(game.shift_coins==1 and is_equal_approx(peg.hp,peg.max-boundary),"Fractional boundary pays exactly one coin: "+area)
		check(game.profile_reads==0,"No profile reads: "+area); game.free()

func collide(game,ball,peg):
	ball.p=peg.p+Vector2(0,-32); ball.v=Vector2(0,300); ball.cool=0.0
	game.spawn_clock=100.0; game.step(.01)

func impact_and_feedback():
	for area in ["bakery","gelato"]:
		var game=fixture(area); var feedback=[]
		game.peg_damaged.connect(func(p,amount,impact): feedback.append({"p":p,"damage":amount,"impact":impact}))
		for kind in ["normal","armored"]:
			for tier in [0,10]:
				game.levels[1]=tier; game.current_level=10; game.start_shift()
				var peg={"p":Vector2(300,400),"hp":100.0,"max":100.0,"kind":kind,"flash":0.0}
				game.pegs=[peg]; game.balls.clear(); feedback.clear()
				game.spawn_ball(peg.p+Vector2(0,-32),"impact",Vector2(0,300),false)
				var ball=game.balls[0]; var power=float(game.power_damage())
				var first=power*(6 if kind=="armored" else 4)
				collide(game,ball,peg)
				check(is_equal_approx(peg.hp,100-first) and ball.used and game.special_stats.impact==0,"First Impact scales with Power: %s/%s/tier%d" % [area,kind,tier])
				check(feedback.size()==1 and is_equal_approx(feedback[0].damage,first) and feedback[0].impact,"First Impact emits actual damage once")
				collide(game,ball,peg)
				check(is_equal_approx(peg.hp,100-first-power) and feedback.size()==2 and not feedback[1].impact,"Spent Impact deals normal Power on later collisions")
		game.current_level=1; game.levels[1]=0; game.start_shift(); feedback.clear()
		var peg=ordinary(game); var result=game.damage_peg(peg,9999,true)
		check(result.damage==6 and result.broken and result.coins==8 and feedback.size()==1 and feedback[0].damage==6,"Overkill reports six actual damage and eight earned coins: "+area)
		game.damage_peg(peg,9999,true)
		check(feedback.size()==1,"Dead pegs emit no repeated damage event")
		peg=ordinary(game); var before=float(peg.hp)
		for invalid in [0.0,-1.0,INF,NAN,0.00000000000000000001]: game.damage_peg(peg,invalid)
		check(peg.hp==before and feedback.size()==1,"Invalid attacks cannot heal, pay or emit feedback")
		if area=="gelato":
			game.twin_launchers=true; game.power_reset_tier=6; game.levels[1]=0
			game.ability_unlock_source="earned"
			# Effective ability access is deliberately pinned at run start.
			game.start_shift()
			check(Balance.hit_damage(game.power_damage(),"impact",false,"normal",game.tuning)==4.0 and Balance.hit_damage(game.power_damage(),"impact",false,"armored",game.tuning)==6.0,"Twin reset also resets Impact strength")
			game.levels[1]=1
			check(is_equal_approx(Balance.hit_damage(game.power_damage(),"impact",false,"armored",game.tuning),10.05),"Rebuilt Power scales Impact from 1.675 damage")
		game.free()

func checkpoint_accounting():
	for area in ["bakery","gelato"]:
		var game=fixture(area); game.current_level=10; game.start_shift()
		var peg=ordinary(game); var index=game.pegs.find(peg)
		game.damage_peg(peg,7.1)
		var snapshot=Snapshot.capture(game); var restored=fixture(area); restored.current_level=10
		check(restored.restore_active_run(snapshot),"Partial reward restores without a new ledger: "+area)
		game.damage_peg(peg,9999); restored.damage_peg(restored.pegs[index],9999)
		var expected=Rules.damage_budget(6,10,false,game.run_rules_revision)+Rules.break_reward(4,10,false,game.run_rules_revision)
		check(game.shift_coins==expected and restored.shift_coins==expected,"Resuming between boundaries cannot gain or lose coins: "+area)
		var old=snapshot.duplicate(true); old.fingerprint=OLD_HASHES[area]
		var wallet=restored.bank; var levels=restored.levels.duplicate()
		check(not restored.restore_active_run(old) and restored.mode=="home" and restored.bank==wallet and restored.levels==levels,"Old rules reject checkpoint while retaining campaign: "+area)
		game.free(); restored.free()

func _initialize():
	budgets(); impact_and_feedback(); checkpoint_accounting()
	print("COMBAT_BALANCE_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
