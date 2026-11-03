extends SceneTree
const Feedback = preload("res://scripts/impact_feedback.gd")
var passed = 0
var failed: Array[String] = []

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failed.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	var feedback = Feedback.new()
	for amount in [0.0,-1.0,NAN,INF]: feedback.show_damage(Vector2(360,500),amount,true)
	feedback.show_damage(Vector2(INF,500),2,true)
	check(feedback.damage_labels.is_empty() and feedback.impact_bursts.is_empty(),"Invalid or zero damage cannot create a visual hit")
	feedback.show_damage(Vector2(360,500),1.5)
	feedback.advance(.04)
	feedback.show_damage(Vector2(360,500),6,true)
	check(feedback.damage_labels.size()==1 and is_equal_approx(feedback.damage_labels[0].damage,7.5) and feedback.damage_labels[0].impact,"Rapid contacts on one peg merge while retaining actual damage and Impact emphasis")
	feedback.advance(.08)
	feedback.show_damage(Vector2(360,500),1)
	check(feedback.damage_labels.size()==1 and feedback.damage_labels[0].damage==1,"A later hit replaces the old number rather than overlapping or indefinitely accumulating damage")
	for index in range(100): feedback.show_damage(Vector2(index*2,600),2,true)
	check(feedback.damage_labels.size()==18 and feedback.impact_bursts.size()==8,"Crowded boards retain bounded label and burst counts")
	check(feedback.damage_text(24)=="24" and feedback.damage_text(1.5)=="1.5" and feedback.damage_text(.01)=="<0.1","Damage labels use compact whole or fractional actual loss")
	var font = load("res://data/fonts/Nunito-Bold.tres")
	for position in [Vector2(0,240),Vector2(720,240),Vector2(0,1060),Vector2(720,1060),Vector2(360,600)]:
		var label = {"p":position,"damage":48.0,"impact":true,"life":.36}
		var normal = feedback.damage_label_layout(label,font,false)
		var reduced = feedback.damage_label_layout(label,font,true)
		var safe = Rect2(40,270,640,770)
		check(safe.encloses(normal.bounds) and safe.encloses(reduced.bounds),"Damage glyphs stay inside playable screen at "+str(position))
		var older = label.duplicate()
		older.life = .15
		check(feedback.damage_label_layout(older,font,true).p==reduced.p,"Reduced-motion labels remain stationary at "+str(position))
	feedback.advance(1)
	check(feedback.damage_labels.is_empty() and feedback.impact_bursts.is_empty(),"Hit visuals expire completely")
	feedback.show_damage(Vector2(300,500),2,true)
	feedback.hit_peg(Vector2(300,500))
	feedback.catch_food(1)
	feedback.reset()
	check(feedback.damage_labels.is_empty() and feedback.impact_bursts.is_empty() and feedback.peg_times.is_empty() and feedback.bucket_times[1]==0,"Run reset clears all previous hit and cup visuals")
	print("DAMAGE_FEEDBACK_QA_RESULT passed=%d failed=%d" % [passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
