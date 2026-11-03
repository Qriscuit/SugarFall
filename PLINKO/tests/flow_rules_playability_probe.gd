extends SceneTree
## Synthetic maximal ordinary builds, no signature ability or paid entitlement.
## A clearance here proves a possible automated route, not human balance.
var results: Array[Dictionary] = []
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var persistence_attempts=0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): persistence_attempts+=1
	func save_game(): return true

func simulate(area: String, tray: int, revision: int = 2, earned_ability: bool = false) -> Dictionary:
	var g=Fixture.new()
	g.testing=true; g.sound_on=false; g.reduced_motion=true
	g.first_run_guide.completed=true; g.first_run_guide.active=false
	g.set_active_area(area)
	g.highest_unlocked=12; g.mode="shop"; g.bank=1000000
	g.ability_access=g.ability_access.get_script().new(false)
	var graph=g.upgrade_graph()
	for node in graph.nodes():
		if not g.buy_upgrade_node(node.x,node.y): failures.append(area+" ordinary upgrade path failed "+str(node))
	if earned_ability and not g.crystal_launcher.buy(): failures.append("Crystal Second Prism gameplay purchase failed")
	g.equipped=["splitter","impact"]
	g.current_level=tray
	g.start_shift(); g.run_transition.finish()
	if revision==1:
		g.run_rules_revision=1; g.build_wave()
	var ticks=0
	while g.mode=="play" and ticks<7200:
		var first=INF
		var target=Vector2(360,700)
		for peg in g.pegs:
			if peg.hp>0 and peg.p.y<first:
				first=peg.p.y; target=peg.p
		g.aim_x=clampf(target.x,66,654)
		g.aim_y=clampf(target.y,330,1000 if area!="bakery" else 770)
		# Ideal player pickup collection is stated explicitly in the result.
		for pickup in g.pickups.duplicate(): g.collect_pickups(pickup.p)
		if area=="crystal" and g.crystal_run.offer_life>0: g.crystal_launcher.try_collect(g.crystal_run.offer_position)
		g.step(1.0/60.0)
		ticks+=1
	var result={"area":area,"tray":tray,"build":"all ordinary upgrades bought through live graph","aim":"topmost surviving target","pickups":"immediate collection","signature_ability":g.bakery_ability.owned() or g.gelato_launcher.is_twin() or g.crystal_launcher.owned(),"expected_ability":earned_ability,"ability_source":g.ability_unlock_source,"early_access":g.ability_early_access(area),"rules_revision":g.run_rules_revision,"clear":g.level_won,"destroyed":g.destroyed,"pegs":g.pegs.size(),"coins":g.shift_coins,"elapsed":g.run_elapsed,"terminated":g.mode=="result","profile_reads":g.persistence_attempts}
	g.free()
	return result

func _initialize():
	if "--crystal-compare" in OS.get_cmdline_user_args():
		for revision in [1,2]:
			for tray in range(8,13):
				var result=simulate("crystal",tray,revision,revision==2)
				results.append(result)
				print("FLOW_PLAYABILITY_RUN ",JSON.stringify(result))
	else:
		for area in ["bakery","gelato","crystal"]:
			for tray in range(8,13):
				var result=simulate(area,tray)
				results.append(result)
				print("FLOW_PLAYABILITY_RUN ",JSON.stringify(result))
	var cleared=results.filter(func(item): return item.clear).size()
	print("FLOW_PLAYABILITY_RESULT runs=%d cleared=%d terminated=%d invalid_builds=%d"%[results.size(),cleared,results.filter(func(item): return item.terminated).size(),failures.size()])
	for failure in failures: print("FAIL: ",failure)
	quit(0 if failures.is_empty() and results.all(func(item): return item.terminated and item.profile_reads==0 and item.signature_ability==item.expected_ability and not item.early_access) else 1)
