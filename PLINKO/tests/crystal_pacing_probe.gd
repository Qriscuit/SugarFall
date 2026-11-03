extends SceneTree
## Synthetic targeting probes expose gross tuning problems, not phone balance.
const BUILDS={"new":[0,0,0,0,0,0,0,0],"mid":[4,4,2,1,1,1,2,4],"max":[10,10,6,6,6,6,8,10]}
var runs: Array=[]

class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): assert(false,"Pacing probe must not read player saves")
	func save_game(): return true

func simulate(board: int, build: String, strategy: String, pickup_mode: String) -> Dictionary:
	var g=Fixture.new()
	g.testing=true; g.sound_on=false; g.reduced_motion=true
	g.first_run_guide.completed=true; g.first_run_guide.active=false
	g.set_active_area("crystal")
	g.current_level=board; g.highest_unlocked=12; g.levels=BUILDS[build].duplicate()
	g.equipped=["splitter","impact"] if build!="new" else []
	g.crystal_second_prism=pickup_mode=="two"
	g.start_shift()
	var total_hp=0.0
	for peg in g.pegs: total_hp+=float(peg.max)
	var launches=0
	var clones=0
	var ticks=0
	while g.mode=="play" and ticks<1800:
		if strategy=="front":
			var target=Vector2(360,700)
			var front=100000.0
			for peg in g.pegs:
				if peg.hp>0 and peg.p.y<front:
					front=peg.p.y; target=peg.p
			g.aim_x=target.x; g.aim_y=target.y
		else:
			g.aim_x=360+285*sin(g.run_elapsed*1.7)
			g.aim_y=470+200*sin(g.run_elapsed*.61)
		var before=int(g.total_spawned)
		var shards=int(g.type_drops.shard)
		g.step(1.0/60.0)
		launches+=int(g.total_spawned)-before-(int(g.type_drops.shard)-shards)
		if pickup_mode!="off" and g.mode=="play" and g.crystal_run.offer_life>0:
			before=int(g.total_spawned)
			g.crystal_launcher.try_collect(g.crystal_run.offer_position)
			clones+=int(g.total_spawned)-before
		ticks+=1
	var damage=total_hp
	for peg in g.pegs: damage-=float(peg.hp)
	var result={"board":board,"build":build,"strategy":strategy,"pickup":pickup_mode,"clear":g.level_won,"destroyed":g.destroyed,"pegs":g.pegs.size(),"damage":snappedf(damage,.01),"damage_fraction":snappedf(damage/total_hp,.0001),"launches":launches,"clones":clones,"spawned_total":g.total_spawned,"coins":g.shift_coins,"elapsed":snappedf(g.run_elapsed,.01),"terminated":g.mode=="result","offers_collected":g.crystal_run.collected}
	g.free()
	return result

func _initialize():
	for build in BUILDS:
		for board in range(1,13):
			for strategy in ["front","sweep"]:
				for pickup_mode in ["off","one","two"]:
					var result=simulate(board,build,strategy,pickup_mode)
					runs.append(result)
					print("CRYSTAL_PACING_RUN ",JSON.stringify(result))
	print("CRYSTAL_PACING_RESULT runs=",runs.size()," terminated=",runs.filter(func(run): return run.terminated).size())
	quit(0 if runs.all(func(run): return run.terminated) else 1)
