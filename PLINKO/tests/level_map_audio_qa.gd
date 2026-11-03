extends SceneTree
const Integration=preload("res://tests/audio_feedback_integration_qa.gd")
const Campaign=preload("res://scripts/area_campaign.gd")
var passed=0
var failures=[]
func check(ok:bool,label:String):
	if ok:passed+=1
	else:failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func _initialize():
	for eligible in [true,false]:
		var g=Integration.Fixture.new()
		g.testing=true;g.page_transition.enabled=false;g.first_run_guide.completed=true;g.first_run_guide.active=false
		g.set_active_area("bakery");Campaign.apply_local(g,Campaign.default_record())
		g.bank=10000;g.shift_claimed=true;g.run_id="";g.current_level=12 if eligible else 1
		g.highest_unlocked=g.current_level;g.best_wave=g.current_level;g.chapter_complete=eligible
		g.area_records={"bakery":Campaign.capture_local(g)}
		g.mode="boards";g.navigation_delay=0;g.level_map.area_menu_open=true
		g.audio_feedback_requested.connect(g.listen)
		g.level_map.press(g.level_map.area_option_rect("gelato").get_center())
		check(g.level_map.entry_open==eligible,"Area selection retains its entry gate: "+str(eligible))
		check(g.heard.size()==1,"One area-picker tap requests one sound: "+str(eligible))
		check(g.heard==["ui_tap" if eligible else "ui_back"],"Dialog replacement uses the appropriate single cue: "+str(eligible))
		g.free()
	print("LEVEL_MAP_AUDIO_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
