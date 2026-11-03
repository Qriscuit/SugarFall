extends SceneTree
## Staged renderer checks for the results UI. Campaign/history behavior is tested
## separately; these fixtures never read or write a player profile.
const ResultsUI = preload("res://scripts/result_comparison_ui.gd")
const CASES = ["first","increase","decrease","same","from-zero","zero-zero","fractional","long-values","gelato","bonuses","won","final-tray","tutorial"]
var failures: Array[String] = []
var captures: Array[String] = []
var checks = 0

class PreviewGame extends "res://scripts/main.gd":
	var profile_accesses = 0
	func _ready():
		testing = true
		sound_on = false
		load_presentation()
		food_art.load_assets()
		set_active_area("bakery")
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _notification(_what): pass
	func _input(_event): pass
	func save_game():
		profile_accesses += 1
		return false
	func load_game(): profile_accesses += 1

func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label)

func record(coins: float, cleared: int, chain: int) -> Dictionary:
	return {"run_id":"preview","coins":coins,"destroyed":cleared,"peg_total":8,"combo":chain,"wave":1}

func stage(g, id: String):
	g.first_run_guide.reset()
	g.run_transition.finish()
	g.set_active_area("gelato" if id == "gelato" else "bakery")
	g.current_level = 12 if id == "final-tray" else 1
	g.start_shift()
	g.result_history.reset()
	g.remaining = 0
	g.note_time = 0
	g.bank = 0
	g.reward_earned = id == "bonuses"
	g.monetization.entitlements.baker_toolkit = id == "bonuses"
	var current = record(120,6,4)
	var previous = record(80,4,3)
	var direction = "up"
	var percent = "50%"
	match id:
		"first": current = record(48,3,3); previous = {}; direction = "first"; percent = ""
		"decrease": current = record(48,3,3); direction = "down"; percent = "40%"
		"same": current = record(80,4,3); direction = "same"; percent = "0%"
		"from-zero": current = record(20,2,2); previous = record(0,0,0); direction = "from_zero"; percent = ""
		"zero-zero": current = record(0,0,0); previous = record(0,0,0); direction = "same"; percent = "0%"
		"fractional": current = record(.25,0,0); previous = record(.5,0,0); direction = "down"; percent = "50%"
		"long-values": current = record(10000000,48,48); current.peg_total = 48; previous = record(.01,1,1); direction = "up"; percent = "99999999900%"
		"gelato": current = record(240,5,5); previous = record(300,7,6); direction = "down"; percent = "20%"
		"bonuses": previous = record(100,5,5); percent = "20%"
		"won", "final-tray": current = record(120,8,6)
	g.shift_coins = current.coins
	g.destroyed = current.destroyed
	g.max_combo = current.combo
	g.result_peg_total = current.peg_total
	if not previous.is_empty(): check(g.result_history.record_run(g.area_id,previous),id+": prior record accepted")
	g.level_won = id in ["won","final-tray"]
	g.finish_shift(false)
	var comparison: Dictionary = g.run_comparison()
	check(g.mode == "result" and comparison.direction == direction and comparison.percent_text == percent,id+": actual result history supplies expected comparison")
	if id == "tutorial":
		g.first_run_guide.begin(false)
		g.first_run_guide._set_step("collect",false)
		g.first_run_guide.revealed = 10000
		g.first_run_guide.age = 1
	g.queue_redraw()

func fits(font: Font, value: String, width: float, preferred_size: int, minimum_size: int = 20) -> bool:
	var size = preferred_size
	while size > minimum_size and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width: size -= 1
	return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x <= width

func inspect(g, id: String):
	var copy = ResultsUI.content(g,g.run_comparison())
	check(fits(g.font,copy.title,ResultsUI.TITLE_RECT.size.x,22),id+": comparison heading stays readable")
	check(fits(g.font,copy.headline,ResultsUI.CHANGE_RECT.size.x,40),id+": change text stays readable")
	check(fits(g.font,copy.detail,ResultsUI.DETAIL_RECT.size.x,21),id+": optional base earnings fit")
	check(fits(g.number_font,str(g.displayed_result_payout()),ResultsUI.PAYOUT_RECT.size.x,94,32),id+": hero payout remains readable")
	for index in range(2):
		check(fits(g.number_font,copy.values[index],170,38) and fits(g.font,copy.previous[index],170,20),id+": statistic values fit")
	check(ResultsUI.STAT_RECTS[1].end.y < 800 and ResultsUI.DETAIL_RECT.end.y < ResultsUI.STAT_RECTS[0].position.y,id+": comparison and stats stay clear of Collect")
	check(ResultsUI.COLLECT_RECT == Rect2(60,800,600,96) and ResultsUI.BONUS_RECT == Rect2(60,910,600,100),id+": action targets match native dispatch and Mabel")
	if id == "tutorial": check(not g.first_run_guide.bubble_rect().intersects(Rect2(60,800,600,96)),"Mabel leaves the Collect action uncovered")
	if id == "bonuses": check(g.displayed_result_payout() > current_coins(g) and copy.detail == "Base 120 · last 100","Hero includes bonuses while comparison stays on base earnings")
	if id in ["won","final-tray"]: check(g.level_won and (g.wave == 12 if id == "final-tray" else g.wave == 1),id+": completed tray outcome retained")
	if id == "fractional":
		check(copy.detail == "Base <1 · last <1","Positive fractional earnings never display a false zero baseline")
		var first_copy = ResultsUI.content(g,{"current":record(.25,0,0),"previous":{},"direction":"first","percent_text":""})
		check(first_copy.detail == "Base <1" and ResultsUI.coins_text(g,0) == "0","First fractional run uses <1 while true zero remains 0")

func current_coins(g) -> int: return int(g.run_comparison().current.coins)

func _initialize(): call_deferred("capture")

func capture():
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("Supply absolute --output-dir and use the graphics renderer.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var g = PreviewGame.new()
	viewport.add_child(g)
	check(ResultsUI.art_ready(),"Dedicated result backgrounds and transparent coin dish load")
	for resolution in [Vector2i(720,1280),Vector2i(450,800)]:
		viewport.size = resolution
		g.scale = Vector2.ONE*float(resolution.x)/720.0
		for id in CASES:
			stage(g,id)
			inspect(g,id)
			await process_frame
			await RenderingServer.frame_post_draw
			var filename = "%s-%dx%d.png" % [id,resolution.x,resolution.y]
			check(viewport.get_texture().get_image().save_png(output.path_join(filename)) == OK,"Saved "+filename)
			captures.append(filename)
	check(g.profile_accesses == 0,"Preview never accesses a player profile")
	var report = {"checks":checks,"captures":captures,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"note":"Staged UI fixtures using actual Godot rendering. History/persistence correctness is tested separately; no physical-device validation implied."}
	var file = FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RESULT_COMPARISON_PREVIEW checks=",checks," captures=",captures.size()," failed=",failures.size())
	for failure in failures: print("FAIL: ",failure)
	quit(0 if failures.is_empty() else 1)
