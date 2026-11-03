extends SceneTree
## Exercise real controls, launch physics and upgrade effects without profile IO.
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var profile_io=0
	func _ready(): pass
	func load_game(): profile_io+=1
	func save_game(): profile_io+=1; return false
	func _process(_delta): pass
	func _physics_process(_delta): pass

func check(ok: bool, label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fixture(area: String="gelato"):
	var g=Fixture.new()
	g.testing=true
	g.sound_on=false
	g.first_run_guide.completed=true
	g.set_active_area(area)
	g.highest_unlocked=12
	root.add_child(g)
	return g

func stage_legacy_counts(game):
	game.gelato_shop_revision=0
	game.gelato_owned_nodes=[]; game.gelato_reset_power_nodes=[]
	check(game.ensure_gelato_shop_state(),"Launcher fixture migrates its deliberate count-only build")

func pointer(g, point: Vector2, drag: bool=false, index: int=0):
	var event=InputEventScreenDrag.new() if drag else InputEventScreenTouch.new()
	event.index=index
	event.position=g.to_global(g.board_to_screen(point))
	if not drag: event.pressed=true
	g._input(event)

func controls_and_flight():
	var g=fixture()
	g.scale=Vector2(.625,.625)
	g.position=Vector2(11,29)
	for point in [Vector2(90,350),Vector2(630,350),Vector2(360,900),Vector2(160,740)]:
		g.start_shift()
		pointer(g,point)
		check(Vector2(g.aim_x,g.aim_y).distance_to(point)<.001,"Safe-area touch preserves the Gelato aiming point "+str(point))
		g.spawn_clock=0
		g.step(1.0/60.0)
		check(g.balls.size()==1,"Single launcher fires one ball per volley")
		var ball=g.balls[0]
		var initial_velocity: Vector2=ball.v-Vector2(0,g.tuning.gravity/60.0)
		var wanted: Vector2=g.gelato_launcher.solution().velocity
		check(initial_velocity.distance_to(wanted)<.001,"Finger selects the exact gravity-compensated launch velocity without random spread")
		var reconstructed_origin: Vector2=ball.p-initial_velocity/60.0-Vector2(0,.5*g.tuning.gravity/3600.0)
		check(reconstructed_origin.distance_to(Vector2(360,267))<.001,"Every single shot originates at fixed top center")
	var old=Vector2(g.aim_x,g.aim_y)
	pointer(g,Vector2(630,400),true,1)
	check(Vector2(g.aim_x,g.aim_y)==old,"A second finger cannot redirect the active aim")
	pointer(g,Vector2(600,980),true)
	check(absf(g.aim_y-980)<.001 and absf(g.aim_x-600)<.001,"Dragging can aim at lower pegs beyond the old Bakery bound")
	g.mode="paused"
	old=Vector2(g.aim_x,g.aim_y)
	pointer(g,Vector2(100,330),true)
	check(Vector2(g.aim_x,g.aim_y)==old,"Paused input does not change the shot direction")
	g.start_shift(true)
	old=Vector2(g.aim_x,g.aim_y)
	pointer(g,Vector2(100,330),true)
	g.step(.25)
	check(Vector2(g.aim_x,g.aim_y)==old and g.balls.is_empty(),"Entry animation freezes aiming and spawning")
	check(g.profile_io==0,"Aiming fixture never reads or writes a profile")
	g.mode="home"; g.shift_claimed=true
	g.aim_y=1000
	g.set_active_area("bakery")
	g.start_shift()
	check(g.aim_y==515 and g.RunSnapshot.validate_and_decode(g.RunSnapshot.capture(g),g).ok,"Starting Bakery after a low Gelato aim resets it to a resumable value")
	g.free()
	var bakery=fixture("bakery")
	bakery.start_shift()
	pointer(bakery,Vector2(500,950))
	bakery.spawn_clock=0
	bakery.step(1.0/60.0)
	check(bakery.aim_y==770 and (bakery.balls[0].p-bakery.balls[0].v/60.0).distance_to(Vector2(500,267))<.001,"Bakery retains its movable falling dispenser and aim bounds")
	bakery.free()

func twin_progression():
	var g=fixture()
	g.mode="shop"
	g.levels=[3,6,2,1,1,1,2,3]
	stage_legacy_counts(g)
	g.equipped=["ricochet","splitter"]
	g.bank=10000.25
	var original=g.levels.duplicate()
	var bank=g.bank
	var original_cost=g.upgrade_cost(1)
	var cost=g.gelato_launcher.cost()
	check(g.buy_twin_launchers(),"Eligible player can buy twin launchers")
	check(g.twin_launchers and g.power_reset_tier==6 and g.levels[1]==0 and g.power_damage()==1,"Twin purchase restarts only Power at one damage")
	original[1]=0
	check(g.levels==original and g.equipped==["ricochet","splitter"] and g.bank==bank-cost,"Other upgrades, equipment and exact purchase balance survive reset")
	bank=g.bank
	check(not g.buy_twin_launchers() and g.bank==bank,"A second purchase cannot spend or reset Power again")
	check(g.upgrade_unlocked(1),"The first Power node can be rebuilt immediately through its retained prerequisite")
	var rebuilt_cost=g.upgrade_cost(1)
	var fresh=fixture()
	check(rebuilt_cost>fresh.upgrade_cost(1),"Reset Power has a higher repurchase price")
	fresh.levels[1]=1
	check(g.buy_upgrade(1) and g.power_damage()>fresh.power_damage(),"A rebuilt Power node boosts both balls more than its old tier")
	fresh.free()
	for feed in [0,10]:
		g.levels[0]=feed
		g.twin_launchers=false
		var single=g.gelato_launcher.interval()
		g.twin_launchers=true
		var twin=g.gelato_launcher.interval()
		check(twin>single and 2.0/twin>1.0/single,"At Feed %d twins fire slower individually but faster together" % feed)
	g.start_shift()
	g.aim_x=570; g.aim_y=700
	g.gelato_launcher.fire()
	check(g.balls.size()==2 and g.balls[0].p==Vector2(318,267) and g.balls[1].p==Vector2(402,267),"Twins fire from two distinct fixed nozzles")
	for ball in g.balls:
		var target: Vector2=g.gelato_launcher.solution(ball.p).velocity
		check(ball.v.distance_to(target)<.001,"Both launchers use their exact ballistic solution for the shared target")
	while g.balls.size()<79: g.spawn_ball(Vector2(360,267),"normal")
	g.gelato_launcher.fire()
	check(g.balls.size()==80,"Twin volleys respect the population cap when only one slot remains")
	g.mode="shop"
	g.twin_launchers=false; g.power_reset_tier=0; g.levels[1]=6
	stage_legacy_counts(g)
	bank=g.bank
	check(not g.buy_twin_launchers() and g.bank==bank,"An uncollected active run cannot be overwritten by the upgrade")
	g.mode="play"
	for peg in g.pegs: peg.hp=0
	g.destroyed=g.pegs.size()
	g.begin_clear_drain()
	var spawned=g.total_spawned
	g.spawn_clock=0
	g.step(.01)
	check(g.total_spawned==spawned,"A cleared board stops launcher volleys while food drains")
	check(g.profile_io==0,"Upgrade and physics fixtures never access player profiles")
	g.free()

func _initialize(): call_deferred("run")

func later_twin_gate():
	var g=fixture()
	g.mode="shop"; g.bank=10000; g.levels[1]=6; g.highest_unlocked=7
	stage_legacy_counts(g)
	check(g.gelato_launcher.cost()==3000,"Twin launchers cost three thousand coins")
	check(not g.gelato_launcher.unlocked() and not g.buy_twin_launchers() and g.bank==10000,"Power six alone cannot bypass the tray-eight milestone")
	g.highest_unlocked=8; g.levels[1]=5
	stage_legacy_counts(g)
	check(not g.gelato_launcher.unlocked() and not g.buy_twin_launchers() and g.bank==10000,"Tray eight still requires Power six")
	g.levels[1]=6; g.bank=2999
	stage_legacy_counts(g)
	check(g.gelato_launcher.unlocked() and not g.buy_twin_launchers() and g.bank==2999,"Eligible twin node requires its full later price")
	g.bank=3000
	check(g.buy_twin_launchers() and g.bank==0 and g.twin_launchers and g.power_reset_tier==6,"Exact-price purchase at tray eight and Power six succeeds once")
	check(g.profile_io==0,"Later-gate checks never access a profile")
	g.free()

func run():
	controls_and_flight()
	twin_progression()
	later_twin_gate()
	var art=preload("res://scripts/food_art.gd").new()
	var original=art.cookie_tint("normal","silver")
	art.area_id="gelato"
	var silver=art.cookie_tint("normal","silver",Color(1,1,1,.4))
	check(silver.b>original.b and silver.g>original.g and is_equal_approx(silver.a,.4),"Gelato warm-wafer correction preserves alpha while cooling Silver")
	check(art.cookie_tint("normal","")==Color.WHITE and art.cookie_tint("clock","diamond")==art.tier_color("diamond"),"Untiered Trials and special decorations keep their original tint rules")
	print("GELATO_LAUNCHER_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
