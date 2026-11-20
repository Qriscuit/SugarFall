extends SceneTree
## Coin feedback through real damage accounting; fixtures never access profiles.
const Feedback = preload("res://scripts/impact_feedback.gd")
var passed = 0
var failed: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var profile_io = 0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): profile_io += 1
	func save_game(): profile_io += 1; return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failed.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func presentation():
	var feedback = Feedback.new()
	for amount in [0.0,-1.0,.25,NAN,INF]: feedback.show_coins(Vector2(360,500),amount,true)
	feedback.show_coins(Vector2(INF,500),2,true)
	check(feedback.coin_labels.is_empty() and feedback.impact_bursts.is_empty(),"Invalid and zero whole-coin gains do not claim earnings")
	feedback.show_coins(Vector2(360,500),1)
	feedback.advance(.04)
	feedback.show_coins(Vector2(360,500),6,true)
	check(feedback.coin_labels.size()==1 and feedback.coin_labels[0].coins==7 and feedback.coin_labels[0].impact,"Rapid paid contacts merge their actual coins and Impact emphasis")
	feedback.advance(.08)
	feedback.show_coins(Vector2(360,500),1)
	check(feedback.coin_labels.size()==1 and feedback.coin_labels[0].coins==1,"Later paid contact replaces the old number without indefinite accumulation")
	for index in range(100): feedback.show_coins(Vector2(index*2,600),2,true)
	check(feedback.coin_labels.size()==18 and feedback.impact_bursts.size()==8,"Crowded boards retain bounded label and burst counts")
	var font = load("res://data/fonts/Nunito-Bold.tres")
	for amount in [1,24,999999999]:
		for position in [Vector2(0,240),Vector2(720,240),Vector2(0,1060),Vector2(720,1060),Vector2(360,600)]:
			var label = {"p":position,"coins":amount,"impact":true,"life":.36}
			var normal = feedback.coin_label_layout(label,font,false)
			var reduced = feedback.coin_label_layout(label,font,true)
			var safe = Rect2(40,270,640,770)
			check(safe.encloses(normal.bounds) and safe.encloses(reduced.bounds) and not normal.has("icon"),"Text-only coin gain stays inside board: %d at %s" % [amount,position])
			check(normal.text=="+"+str(amount) and normal.color==Feedback.COIN_GOLD and normal.outline==Feedback.COIN_OUTLINE,"Paid amount is positive gold with a dark outline")
			var older = label.duplicate()
			older.life = .15
			check(feedback.coin_label_layout(older,font,true).p==reduced.p,"Reduced-motion earned number remains stationary")
	feedback.advance(1)
	check(feedback.coin_labels.is_empty() and feedback.impact_bursts.is_empty(),"Paid hit visuals expire completely")
	feedback.show_coins(Vector2(300,500),2,true)
	feedback.hit_peg(Vector2(300,500))
	feedback.catch_food(1)
	feedback.reset()
	check(feedback.coin_labels.is_empty() and feedback.impact_bursts.is_empty() and feedback.peg_times.is_empty() and feedback.bucket_times[1]==0,"Run reset clears coin, hit and cup visuals")

func integration():
	for area in ["bakery","gelato","crystal"]:
		var game = Fixture.new()
		game.testing=true; game.sound_on=false; game.first_run_guide.completed=true
		game.set_active_area(area); game.current_level=1; game.highest_unlocked=12
		game.start_shift(); game.run_transition.finish()
		var peg = {"p":Vector2(300,500),"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}
		var spare = {"p":Vector2(400,500),"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}
		game.pegs=[peg,spare]; game.impact_feedback.reset(); game.floats=[]; game.shift_coins=.75
		var before = float(game.shift_coins)
		var event = game.damage_peg(peg,.25)
		check(event.damage>0 and event.coins==0 and game.shift_coins==before and game.impact_feedback.coin_labels.is_empty(),"Sub-coin damage keeps money unchanged and shows no invented gain: "+area)
		event=game.damage_peg(peg,.75)
		check(event.coins==1 and game.shift_coins==before+1 and game.impact_feedback.coin_labels.size()==1 and game.impact_feedback.coin_labels[0].coins==1,"Peg hit label matches the actual credited coin with a fractional starting balance: "+area)
		game.impact_feedback.reset(); before=game.shift_coins
		event=game.damage_peg(peg,9999,true)
		check(event.damage==5 and event.broken and event.coins==game.shift_coins-before and game.impact_feedback.coin_labels[0].coins==event.coins,"Overkill shows damage-budget remainder plus break reward, not damage: "+area)
		check(game.floats.is_empty(),"Break bonus has one gold label without a duplicate mint reward: "+area)
		game.impact_feedback.reset(); before=game.shift_coins
		event=game.damage_peg(peg,9999,true)
		check(event.coins==0 and game.shift_coins==before and game.impact_feedback.coin_labels.is_empty(),"Dead peg cannot pay or display a duplicate award: "+area)
		before=game.shift_coins; event=game.damage_peg(spare,9999,true)
		check(game.clear_draining and game.shift_coins-before>event.coins and game.impact_feedback.coin_labels[0].coins==event.coins,"Last peg's label excludes the separate tray-clear bonus: "+area)
		check(game.profile_io==0,"Coin feedback performs zero player profile IO: "+area)
		game.note="Collected coins"; game.note_time=8
		game.mode="boards"; game.level_map.reset()
		check(game.level_map.map_input_at(Vector2(360,1220)),"An old note cannot block bottom journey gestures: "+area)
		game.mode="shop"; game.upgrade_map.reset_view_state()
		check(game.upgrade_map.map_input_at(Vector2(360,1220)),"An old note cannot block bottom upgrade-map gestures: "+area)
		game.free()
	var game = Fixture.new()
	game.testing=true; game.sound_on=false; game.first_run_guide.completed=true
	game.bakery_jam_burst=true; game.ability_unlock_source="earned"; game.current_level=1
	game.start_shift(); game.run_transition.finish()
	var direct = {"p":Vector2(300,500),"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}
	game.pegs=[direct,{"p":Vector2(340,500),"hp":6.0,"max":6.0,"kind":"normal","flash":0.0},{"p":Vector2(380,500),"hp":6.0,"max":6.0,"kind":"normal","flash":0.0}]
	game.levels[1]=2
	var ball = {"kind":"normal","jam":true,"used":false}
	var before=float(game.shift_coins)
	var count=game.bakery_ability.on_hit(ball,direct)
	var shown=0
	for label in game.impact_feedback.coin_labels: shown+=label.coins
	check(count==2 and shown>0 and shown==game.shift_coins-before,"Jam splash labels sum to the actual coins from affected pegs")
	check(game.profile_io==0,"Splash fixture performs zero player profile IO")
	game.free()

func _initialize():
	presentation(); integration()
	print("DAMAGE_FEEDBACK_QA_RESULT passed=%d failed=%d" % [passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
