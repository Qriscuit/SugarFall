extends SceneTree
## Real font metrics and authored cup-face layout; no profile reads or writes.
const Game = preload("res://scripts/main.gd")
var passed = 0
var failures: Array[String] = []

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	var g = Game.new()
	g.testing = true
	g.font = load("res://data/fonts/Nunito-Semibold.tres")
	var panel = Rect2(36,22,528,96)
	var inner = panel.grow(-12)
	g.pegs.resize(48)
	for area in ["bakery","gelato","crystal"]:
		g.area_id = area; g.food_art.area_id = area
		g.board_data = JSON.parse_string(FileAccess.get_file_as_string(g.AreaCampaign.BOARD_PATHS[area])).boards
		for tray in range(1,13):
			g.wave = tray
			for trial in [false,true]:
				g.trial_active = trial
				var rows = g.game_hud_status_rows()
				var previous_end = -INF
				var good = true
				for row in rows:
					var fit = g.game_hud_label_layout(row.text,row.rect,g.font,row.size)
					good = good and inner.encloses(fit.text_box) and row.rect.grow(.001).encloses(fit.text_box)
					good = good and fit.text_box.position.y >= previous_end-.001 and fit.text_box.position.x >= 430
					good = good and absf(fit.text_box.get_center().x-row.rect.get_center().x) < .001
					previous_end = fit.text_box.end.y
				check(good,"Font line boxes stay inside HUD padding without overlap: "+area+" tray "+str(tray)+(" Trial" if trial else " campaign"))
		for cup in ["cup_cream","cup_gold"]:
			var target = Rect2(-60.5,-203,121,203)
			var face = g.food_art.cup_label_rect(cup,target)
			check(target.grow(-8).encloses(face) and absf(face.get_center().x-target.get_center().x) < .001,"Authored front face has side/rim/base clearance and horizontal cup center: "+area+"/"+cup)
			for label in ["1.0×","6.0×","12.3×","999.9×","100003.0×"]:
				var fit = g.game_hud_label_layout(label,face,g.number_font,31)
				check(face.grow(.001).encloses(fit.text_box) and fit.text_box.get_center().distance_to(face.get_center()) < .001,"Multiplier centers inside art face using actual bold-font metrics: "+area+"/"+cup+" "+label)
			if area == "gelato" and cup == "cup_gold":
				check(face.end.y < target.position.y+target.size.y*.60,"Gelato gold text stays on its bowl above the narrow stem")
	# Layout functions must not mutate the reward model or campaign state.
	g.levels[6] = 8
	g.buckets = [{"gold":true,"hits":17},{"gold":false,"hits":23},{"gold":false,"hits":0},{"gold":false,"hits":99},{"gold":false,"hits":999999}]
	var untouched = g.buckets.duplicate(true)
	var values = []
	for i in range(5):
		values.append(g.bucket_reward(i))
		g.game_hud_label_layout("%.1f×" % g.bucket_reward(i),Rect2(0,0,68,48),g.number_font,31)
	check(values == [12.7,3.3,1.0,10.9,100000.9] and g.buckets == untouched,"Label fitting preserves exact decimal multipliers and catch counts")
	check(g.BUCKET_TOP == 1036.0 and g.BUCKET_HEIGHT == 203.0 and g.BUCKET_CATCH_Y == 1052.0,"Existing cup/catch geometry remains unchanged")
	g.free()
	print("HUD_CUP_LAYOUT_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
