extends SceneTree
## Frozen visual review of the real UI renderer. No physics, input, profile reads,
## or saves. Every page is staged in memory at 720x1280 and 450x800.
## Run after editor import with a graphics renderer (not --headless):
## Godot --path <project> --script res://tests/ui_art_preview.gd -- --output-dir=<absolute directory> [--only-shop|--only-journey|--only-launch]

const PAGES = ["home", "home-fresh", "home-last", "home-menu", "home-large-wallet", "home-safe-area", "launch-start", "launch-quarter", "launch-mid", "launch-late", "launch-final", "launch-reduced", "gameplay-early", "gameplay-late", "shop-fresh", "shop-first-purchase", "shop-mixed", "shop-affordability-change", "shop-affordability-settled", "shop-reduced-motion", "shop-zoomed", "shop-maxed", "shop-expanding", "shop-legacy", "shop", "shop-selected", "shop-panned", "shop-fullscreen", "shop-ui-baseline", "shop-under-overlays", "shop-safe-area", "boards", "levels-fresh", "levels-mid", "levels-last", "levels-gate-cleared", "levels-gate-funded", "levels-scrolled", "levels-locked", "levels-safe-area", "loadout", "result-clear", "result-retry", "pause", "settings", "guide", "trials", "trial-result", "finish-confirm", "bonus-confirm", "test-shop", "test-shop-owned", "test-shop-restore", "test-controls", "test-interstitial", "test-rewarded", "test-purchase", "test-purchase-pending", "result-test-bonuses"]
const RESOLUTIONS = [Vector2i(720,1280), Vector2i(450,800)]
var checks = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []

class PreviewGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
	var text_overflows: Array[String] = []
	var capture_name = ""
	var shop_draws = 0
	var journey_draws = 0
	var test_input_enabled = false

	func _ready():
		# Never call the production _ready: it reads the player's chosen profile.
		testing = true
		sound_on = false
		load_presentation()
		food_art.load_assets()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json"))
		board_data = parsed if parsed is Array else parsed.get("boards",[])
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _input(event):
		if test_input_enabled: super._input(event)
	func _notification(_what): pass
	func save_game(): persistence_attempts += 1
	func load_game(): persistence_attempts += 1

	func draw_shop():
		shop_draws += 1
		super.draw_shop()

	func draw_boards():
		journey_draws += 1
		super.draw_boards()

	func record_text(value: String, pos: Vector2, size: int, face: Font):
		# Menu text is in canvas coordinates. Gameplay text can be transformed
		# around food/cup anchors, and is assessed from the captured image instead.
		if mode in ["play","paused","abandon_confirm"] or value.is_empty(): return
		# The continuous journey intentionally draws partial numbered badges at
		# the physical screen edge. Fixed title/action text is still checked.
		if mode=="boards" and value.is_valid_int(): return
		var width = face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var top = pos.y-face.get_ascent(size)
		var bottom = pos.y+face.get_descent(size)
		if pos.x < -1 or pos.x+width > WIDTH+1 or top < -1 or bottom > HEIGHT+1:
			var message = "%s: text outside canvas: %s" % [capture_name,value]
			if message not in text_overflows: text_overflows.append(message)

	func text_at(value, pos, size = 24, color = WHITE, painter: CanvasItem = null):
		record_text(str(value),pos,size,font)
		super.text_at(value,pos,size,color,painter)

	func heading(value, pos, size = 40, color = WHITE, painter: CanvasItem = null):
		record_text(str(value),pos,size,display_font)
		super.heading(value,pos,size,color,painter)

	func fitted_text(value, rect: Rect2, size = 24, color = WHITE, align_center = false, painter: CanvasItem = null):
		# A label that cannot fit even at the helper's minimum needs a layout fix.
		if font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x > rect.size.x+1:
			var message = "%s: label exceeds allocated width: %s" % [capture_name,value]
			if message not in text_overflows: text_overflows.append(message)
		super.fitted_text(value,rect,size,color,align_center,painter)

	func fitted_number(value: String, rect: Rect2, size = 34, color = WHITE, align_center = false):
		if number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x > rect.size.x+1:
			var message = "%s: number exceeds allocated width: %s" % [capture_name,value]
			if message not in text_overflows: text_overflows.append(message)
		super.fitted_number(value,rect,size,color,align_center)

func _initialize():
	call_deferred("capture_previews")

func check(condition: bool, label: String):
	checks += 1
	if condition:
		print("PASS: ",label)
	else:
		failures.append(label)
		push_error("FAIL: "+label)

func output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): return argument.trim_prefix("--output-dir=")
	return ""

func preview_pages() -> Array:
	if "--only-launch" in OS.get_cmdline_user_args():
		return PAGES.filter(func(page_name): return page_name=="home" or page_name.begins_with("launch-"))
	if "--only-journey" in OS.get_cmdline_user_args():
		return PAGES.filter(func(page_name): return page_name in ["home","boards"] or page_name.begins_with("home-") or page_name.begins_with("levels-"))
	if "--only-shop" not in OS.get_cmdline_user_args(): return PAGES
	return PAGES.filter(func(page_name): return page_name=="shop" or page_name.begins_with("shop-"))

func background_corners_match(game, capture: Image, asset: String, page_name: String) -> bool:
	if not game.environment_art.textures.has(asset): return false
	var source: Image = game.environment_art.textures[asset].get_image()
	if source==null or source.is_empty(): return false
	if source.is_compressed() and source.decompress()!=OK: return false
	var resolution = capture.get_size()
	var region: Rect2 = game.environment_art.regions[asset]
	var ratio = float(resolution.x)/resolution.y
	var crop = Vector2(minf(region.size.x,region.size.y*ratio),minf(region.size.y,region.size.x/ratio))
	var origin = region.get_center()-crop*.5
	# GPU trilinear sampling can mix adjacent mip texels. Their support extends
	# beyond a single base-level pixel. Compare against the mapped imported-art
	# footprint, with only 3/255 additional channel tolerance for quantization.
	var footprint = (crop/Vector2(resolution)*2.0).max(Vector2.ONE)
	var corners = [Vector2i(2,2),Vector2i(resolution.x-3,2),Vector2i(2,resolution.y-3),resolution-Vector2i(3,3)]
	var matches = true
	for pixel in corners:
		var sample = origin+(Vector2(pixel)+Vector2(.5,.5))*crop/Vector2(resolution)-Vector2(.5,.5)
		var first = Vector2i((sample-footprint).floor()).max(Vector2i.ZERO)
		var last = Vector2i((sample+footprint).ceil()).min(source.get_size()-Vector2i.ONE)
		var low = Vector3.ONE
		var high = Vector3.ZERO
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var color = source.get_pixel(x,y)
				var rgb = Vector3(color.r,color.g,color.b)
				low=low.min(rgb)
				high=high.max(rgb)
		var actual = capture.get_pixelv(pixel)
		var rgb = Vector3(actual.r,actual.g,actual.b)
		var tolerance = Vector3.ONE*(3.01/255.0)
		var corner_matches = rgb.x>=low.x-tolerance.x and rgb.x<=high.x+tolerance.x and rgb.y>=low.y-tolerance.y and rgb.y<=high.y+tolerance.y and rgb.z>=low.z-tolerance.z and rgb.z<=high.z+tolerance.z and actual.a>.99
		matches=matches and corner_matches
		if not corner_matches:
			print("UI_BACKGROUND_CORNER_DETAIL=",page_name," ",resolution," pixel=",pixel," asset=",asset," actual=",rgb," expected_range=",low,"..",high)
	return matches

func stage(game, page_name: String):
	game.capture_name = page_name
	game.shop_draws = 0
	game.journey_draws = 0
	game.position = Vector2.ZERO
	game.scale = Vector2.ONE*game.get_viewport_rect().size.x/720.0
	game.text_overflows.clear()
	game.testing = true
	game.monetization.reset_test_state()
	game.commerce_message="Local simulation. No money is charged."
	game.mode = "home"
	game.navigation_delay = 0
	game.result_input_delay = 0
	game.current_level = 4
	game.highest_unlocked = 8
	game.bank = 1268.55
	game.levels = [2,3,2,3,3,3,2,3]
	game.equipped = ["splitter","impact"]
	game.module_vouchers = 1
	game.total_shifts = 2
	game.trial_active = false
	game.chapter_complete = false
	game.note_time = 0
	game.elapsed = 2.0
	game.reduced_motion = false
	game.diagnostics_on = false
	game.upgrade_map.reset_view_state()
	game.home_menu.reset()
	game.level_map.reset()
	game.trial_records = {"4":7.8,"8":11.2}
	game.start_shift()
	game.rng.seed = 20261023
	game.remaining = 7.4
	game.shift_coins = 127.35
	game.max_combo = 9
	game.special_stats = {"normal":12,"ricochet":3,"splitter":2,"impact":2,"shard":6,"pulse":0}
	game.type_drops = {"normal":12,"ricochet":3,"splitter":2,"impact":2,"shard":6}
	game.impact_feedback.reset()
	match page_name:
		"home", "home-fresh", "home-last", "home-menu", "home-large-wallet", "home-safe-area":
			game.mode = "home"
			if page_name=="home-fresh":
				game.current_level=1
				game.highest_unlocked=1
				game.bank=0.0
				game.levels=[0,0,0,0,0,0,0,0]
			elif page_name=="home-last":
				game.current_level=12
				game.highest_unlocked=12
			elif page_name=="home-menu": game.home_menu.menu_open=true
			elif page_name=="home-large-wallet": game.bank=1234567890.55
			elif page_name=="home-safe-area":
				var display_scale = game.get_viewport_rect().size.x/720.0
				game.apply_safe_area(Rect2(Vector2(0,60)*display_scale,Vector2(720,1160)*display_scale))
		"launch-start", "launch-quarter", "launch-mid", "launch-late", "launch-final", "launch-reduced":
			# Start from the exact default Home state. Only presentation time
			# advances, so all six frames represent one initialized frozen run.
			game.mode = "home"
			game.reduced_motion = page_name=="launch-reduced"
			game.start_shift(true)
			if page_name=="launch-final":
				game.run_transition.finish()
			elif page_name!="launch-reduced":
				game.run_transition.time = {"launch-start":0.0,"launch-quarter":.105,"launch-mid":.21,"launch-late":.336}[page_name]
		"gameplay-early":
			game.current_level = 1
			game.highest_unlocked = 1
			game.levels = [0,0,0,0,0,0,0,0]
			game.equipped = []
			game.start_shift()
			game.remaining = 8.0
			game.shift_coins = 4.4
			game.spawn_ball(Vector2(350,295),"normal",Vector2(20,120))
			game.spawn_ball(Vector2(300,470),"normal",Vector2(-15,130))
		"gameplay-late":
			game.current_level = 12
			game.highest_unlocked = 12
			game.start_shift()
			game.remaining = 2.8
			game.shift_coins = 748.55
			for i in range(game.pegs.size()):
				if i%6==1: game.pegs[i].hp = game.pegs[i].max*.5
			for item in [["normal",Vector2(360,298)],["splitter",Vector2(370,520)],["impact",Vector2(410,453)],["normal",Vector2(125,670)],["shard",Vector2(291,654)],["shard",Vector2(318,674)]]:
				game.spawn_ball(item[1],item[0],Vector2(30,140))
			for i in range(5): game.buckets[i].hits = [2,6,9,3,5][i]
		"shop-fresh", "shop-first-purchase", "shop-mixed", "shop-affordability-change", "shop-affordability-settled", "shop-reduced-motion", "shop-zoomed", "shop-maxed", "shop-expanding", "shop-legacy", "shop", "shop-selected", "shop-panned", "shop-fullscreen", "shop-ui-baseline", "shop-under-overlays", "shop-safe-area":
			game.mode = "shop"
			if page_name=="shop-safe-area":
				game.levels=[1,0,0,0,0,0,0,0]
				game.bank=65.0
				game.upgrade_map.selected=6
				game.upgrade_map.tier=1
				var display_scale = game.get_viewport_rect().size.x/720.0
				game.apply_safe_area(Rect2(Vector2(0,60)*display_scale,Vector2(720,1160)*display_scale))
			elif page_name=="shop-fullscreen":
				game.levels=[3,2,2,2,2,2,2,2]
				game.bank=55.0
				game.upgrade_map.zoom=game.upgrade_map.MIN_ZOOM
			elif page_name in ["shop-ui-baseline","shop-under-overlays"]:
				game.levels=[4,2,2,2,2,2,2,2]
				game.bank=55.0
				game.upgrade_map.selected=0
				game.upgrade_map.tier=3
				if page_name=="shop-under-overlays": game.upgrade_map.pan=Vector2(0,420)
			elif page_name=="shop-fresh":
				game.levels=[0,0,0,0,0,0,0,0]
				game.bank=38.5
				game.upgrade_map.selected=0
				game.upgrade_map.tier=1
			elif page_name=="shop-first-purchase":
				game.levels=[1,0,0,0,0,0,0,0]
				game.bank=8.5
				game.upgrade_map.selected=0
				game.upgrade_map.tier=1
			elif page_name in ["shop-mixed","shop-affordability-change","shop-affordability-settled","shop-reduced-motion"]:
				game.levels=[1,0,0,0,0,0,0,0]
				game.bank=65.0
				game.upgrade_map.selected=6
				game.upgrade_map.tier=1
				game.reduced_motion=page_name=="shop-reduced-motion"
				game.upgrade_map.update(0.0)
				if page_name!="shop-mixed":
					game.upgrade_map.press(game.upgrade_map.BUY_RECT.get_center())
					game.upgrade_map.update(game.upgrade_map.FEEDBACK_DURATION if page_name=="shop-affordability-settled" else .09)
			elif page_name=="shop-zoomed":
				game.levels=[3,2,1,1,1,1,2,2]
				game.bank=55.0
				game.upgrade_map.zoom=game.upgrade_map.MAX_ZOOM
				game.upgrade_map.pan=Vector2(90,120)
				game.upgrade_map.selected=1
				game.upgrade_map.tier=3
			elif page_name=="shop-maxed":
				game.levels=game.MAX_LEVELS.duplicate()
				game.bank=12345678.90
				game.upgrade_map.zoom=game.upgrade_map.MIN_ZOOM
				game.upgrade_map.selected=6
				game.upgrade_map.tier=game.MAX_LEVELS[6]
			elif page_name=="shop-expanding":
				game.levels=[2,1,0,0,0,0,0,1]
				game.upgrade_map.selected=1
				game.upgrade_map.tier=2
			elif page_name=="shop-legacy":
				game.levels=[0,2,0,0,1,0,0,1]
			elif page_name=="shop-selected":
				game.levels[1] = 2
				game.upgrade_map.selected = 1
				game.upgrade_map.tier = 3
				game.upgrade_map.pan=Vector2(-50,55)
			elif page_name=="shop-panned":
				game.levels[0]=4
				game.upgrade_map.zoom = game.upgrade_map.MIN_ZOOM
				game.upgrade_map.pan = Vector2(0,300)
				game.upgrade_map.selected = 0
				game.upgrade_map.tier = 5
		"boards", "levels-fresh", "levels-mid", "levels-last", "levels-gate-cleared", "levels-gate-funded", "levels-scrolled", "levels-locked", "levels-safe-area":
			game.mode="boards"
			if page_name=="levels-fresh":
				game.current_level=1
				game.highest_unlocked=1
			elif page_name=="levels-mid":
				game.current_level=6
				game.highest_unlocked=6
			elif page_name in ["levels-last","levels-gate-cleared","levels-gate-funded"]:
				game.current_level=12
				game.highest_unlocked=12
				game.chapter_complete=page_name!="levels-last"
				game.bank=400000 if page_name=="levels-gate-funded" else 1234
			elif page_name=="levels-locked": game.highest_unlocked=4
			game.level_map.open()
			if page_name in ["levels-scrolled","levels-locked"]:
				game.level_map.scroll=game.level_map.world_point(9).y-game.level_map.FOCUS_Y
			elif page_name=="levels-safe-area":
				var display_scale = game.get_viewport_rect().size.x/720.0
				game.apply_safe_area(Rect2(Vector2(0,60)*display_scale,Vector2(720,1160)*display_scale))
		"loadout", "guide", "trials": game.mode = page_name
		"result-clear", "result-retry", "bonus-confirm":
			game.mode = "bonus_confirm" if page_name=="bonus-confirm" else "result"
			game.level_won = page_name!="result-retry"
			game.destroyed = game.pegs.size() if game.level_won else 5
		"trial-result":
			game.mode = "result"
			game.trial_active = true
			game.level_won = true
			game.run_elapsed = 7.8
			game.destroyed = game.pegs.size()
		"pause": game.mode = "paused"
		"settings": game.mode = "support"
		"finish-confirm": game.mode = "abandon_confirm"
		"test-shop", "test-shop-owned", "test-shop-restore":
			game.mode="monetization"
			if page_name=="test-shop-owned":
				game.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
				game.monetization.store_owned=game.monetization.entitlements.duplicate()
				game.commerce_message="Test purchases restored from this profile's store."
			elif page_name=="test-shop-restore":
				game.monetization.store_owned={"remove_ads":true,"baker_toolkit":true}
				game.commerce_message="Local benefits cleared. Restore keeps store purchases."
		"test-controls":
			game.mode="monetization_tools"
			game.stage_test_ad_break()
		"test-interstitial", "test-rewarded":
			game.mode="result"
			if page_name=="test-interstitial":
				game.monetization.attempts=4
				game.monetization.active_seconds=120.0
				game.begin_automatic_ad()
			else: game.begin_rewarded_ad()
		"test-purchase", "test-purchase-pending":
			game.mode="monetization"
			game.begin_test_purchase("baker_toolkit")
			if page_name=="test-purchase-pending": game.finish_test_request("pending")
		"result-test-bonuses":
			game.mode="result"
			game.reward_earned=true
			game.monetization.entitlements.baker_toolkit=true
	game.upgrade_map.update(0.0)
	game.level_map.update(0.0)
	game.queue_redraw()

func capture_previews():
	var output = output_directory()
	if output.is_empty() or not output.is_absolute_path():
		push_error("Supply --output-dir=<absolute directory>. No player profile is read or written.")
		quit(2)
		return
	if DisplayServer.get_name()=="headless":
		push_error("UI art previews need the graphics renderer; omit --headless.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Unable to create preview directory.")
		quit(2)
		return
	var viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = PreviewGame.new()
	game.testing = true
	viewport.add_child(game)
	check(game.testing,"Fixture bypasses player profiles, input and simulation")
	check(game.board_data.size()==12,"All campaign tray layouts are available for previews")
	for asset in game.ui_art.NAMES:
		check(game.ui_art.textures.has(asset) and game.ui_art.textures[asset].get_width()>0,"Imported UI asset available: "+asset)
	for asset in game.environment_art.NAMES:
		check(game.environment_art.textures.has(asset) and game.environment_art.textures[asset].get_width()>0,"Imported environment asset available: "+asset)
	check(game.font.get_font_name().contains("Nunito"),"Body font is the bundled Nunito face")
	check(game.display_font.get_font_name().contains("Fraunces"),"Display font is the bundled Fraunces face")
	check(game.number_font.get_font_name().contains("Nunito"),"Numeric font is the bundled Nunito face")
	print("UI_BODY_FONT_AXES=",game.font.get_supported_variation_list())
	print("UI_DISPLAY_FONT_AXES=",game.display_font.get_supported_variation_list())
	var covered = true
	for glyph in "0123456789.,%+×•·":
		if not game.font.has_char(glyph.unicode_at(0)):
			covered = false
			print("UI_MISSING_GLYPH=",glyph," U+%04X" % glyph.unicode_at(0))
	check(covered,"Body font covers currency, multiplier and upgrade notation")
	for resolution in RESOLUTIONS:
		viewport.size = resolution
		game.scale = Vector2.ONE*float(resolution.x)/720.0
		var overlay_baseline: Image
		var home_baseline: Image
		var launch_final_baseline: Image
		for page_name in preview_pages():
			stage(game,page_name)
			await process_frame
			await RenderingServer.frame_post_draw
			check((game.shop_draws>0)==(game.mode=="shop"),"Recipe map draws only on its page: "+page_name)
			check((game.journey_draws>0)==(game.mode=="boards"),"Level journey draws only on its page: "+page_name)
			var capture = viewport.get_texture().get_image()
			var filename = "%s-%dx%d.png" % [page_name,resolution.x,resolution.y]
			var image_ok = capture != null and capture.get_size()==resolution
			check(image_ok,"Actual renderer captured: "+filename)
			var saved = capture.save_png(output.path_join(filename)) if image_ok else ERR_CANT_CREATE
			check(saved==OK,"Preview saved: "+filename)
			check(game.text_overflows.is_empty(),"Menu text stays within its canvas and fitting bounds: "+filename)
			for issue in game.text_overflows: print("UI_LAYOUT_DETAIL=",issue)
			if image_ok and page_name=="home": home_baseline=capture
			if image_ok and page_name=="launch-start":
				check(home_baseline!=null and home_baseline.get_format()==capture.get_format() and home_baseline.get_data()==capture.get_data(),"The first launch frame exactly matches Home pixels at %dx%d" % [resolution.x,resolution.y])
			if image_ok and page_name=="launch-final": launch_final_baseline=capture
			if image_ok and page_name=="launch-reduced":
				check(launch_final_baseline!=null and launch_final_baseline.get_format()==capture.get_format() and launch_final_baseline.get_data()==capture.get_data(),"Reduced Motion immediately matches the settled launch pixels at %dx%d" % [resolution.x,resolution.y])
			if image_ok and page_name=="shop-ui-baseline": overlay_baseline=capture
			if image_ok and page_name=="shop-under-overlays" and overlay_baseline!=null:
				# Interior colors must remain stable while the actual map moves
				# underneath. Allow 3/255 for faint generated-skin transparency.
				var scale_factor = float(resolution.x)/720.0
				for sample in [[Vector2(80,70),"Menu"],[Vector2(400,70),"Wallet"],[Vector2(210,1000),"Selected upgrade"],[Vector2(160,1140),"Treats"],[Vector2(480,1140),"Play"]]:
					var pixel = Vector2i(sample[0]*scale_factor)
					var actual = capture.get_pixelv(pixel)
					var before = overlay_baseline.get_pixelv(pixel)
					var largest_delta = maxf(absf(actual.r-before.r),maxf(absf(actual.g-before.g),absf(actual.b-before.b)))
					check(largest_delta<=3.01/255.0,"Panning beneath the fixed %s overlay preserves its rendered interior at %dx%d" % [sample[1],resolution.x,resolution.y])
			if image_ok and page_name in ["home-safe-area","shop-safe-area","levels-safe-area"]:
				var asset = {"home-safe-area":"home_counter","shop-safe-area":"upgrade_counter","levels-safe-area":"journey_backdrop"}[page_name]
				check(background_corners_match(game,capture,asset,page_name),"Safe-area physical corners match the imported %s background at %dx%d" % [asset,resolution.x,resolution.y])
			if image_ok and page_name in ["shop-safe-area","levels-safe-area"]:
				var physical_margin = Vector2(3,resolution.y*.5)
				var local_margin = game.to_local(physical_margin)
				var margin_interactive: bool = game.upgrade_map.map_input_at(local_margin) if page_name=="shop-safe-area" else game.level_map.map_input_at(local_margin)
				check(local_margin.x<0 and margin_interactive,"The %s physical side margin remains interactive beyond the safe UI canvas at %dx%d" % [page_name,resolution.x,resolution.y])
			captures.append({"file":filename,"page":page_name,"width":resolution.x,"height":resolution.y,"text_overflows":game.text_overflows.duplicate()})
	check(game.persistence_attempts==0,"No profile load or save was attempted by any preview")
	var report = {"fixture":"ui_art_preview.gd","renderer":RenderingServer.get_video_adapter_name(),"checks":checks,"passed":checks-failures.size(),"failures":failures,"captures":captures,"note":"Frozen real-renderer compositions; text bounds checks do not replace visual review or interaction tests."}
	var report_file = FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	if report_file: report_file.store_string(JSON.stringify(report,"\t"))
	print("UI_ART_PREVIEW_RESULT passed=",checks-failures.size()," failed=",failures.size()," captures=",captures.size())
	quit(0 if failures.is_empty() else 1)
