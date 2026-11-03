extends SceneTree
## Production renderer/art checks. No player profile is loaded or written.
## Godot --path PLINKO --script res://tests/gelato_art_qa.gd -- --output-dir=<absolute-path>
## --art-only runs imported-asset assertions without requiring a GPU renderer.
const AREAS = ["bakery", "gelato"]
const RESOLUTIONS = [Vector2i(720,1280), Vector2i(450,800)]
const PAGES = ["home-fresh", "home", "play", "levels-last", "shop-fresh", "shop-expanded", "loadout", "result-clear", "result-retry", "area-menu", "home-safe-area"]
var passed = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var records: Array[Dictionary] = []

class ArtGame extends "res://scripts/main.gd":
	var persistence_attempts = 0
	var text_overflows: Array[String] = []
	var visible_text: Array[String] = []
	var capture_name = ""
	func _ready():
		testing = true
		sound_on = false
		load_presentation()
		food_art.load_assets()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _input(_event): pass
	func _notification(_what): pass
	func save_game() -> bool:
		persistence_attempts += 1
		return false
	func load_game(): persistence_attempts += 1
	func write_profile_file(_data: Dictionary) -> bool:
		persistence_attempts += 1
		return false
	func record_text(value: String, pos: Vector2, size: int, face: Font):
		if value not in visible_text: visible_text.append(value)
		if mode in ["play","paused","abandon_confirm"] or value.is_empty(): return
		if mode=="boards" and value.is_valid_int(): return
		var width = face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var top = pos.y-face.get_ascent(size)
		var bottom = pos.y+face.get_descent(size)
		if pos.x < -1 or pos.x+width > WIDTH+1 or top < -1 or bottom > HEIGHT+1:
			var issue = "%s outside canvas: %s" % [capture_name,value]
			if issue not in text_overflows: text_overflows.append(issue)
	func text_at(value, pos, size=24, color=WHITE):
		record_text(str(value),pos,size,font)
		super.text_at(value,pos,size,color)
	func heading(value, pos, size=40, color=WHITE):
		record_text(str(value),pos,size,display_font)
		super.heading(value,pos,size,color)
	func fitted_text(value, rect: Rect2, size=24, color=WHITE, align_center=false):
		if font.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x > rect.size.x+1:
			text_overflows.append("%s exceeds fitting width: %s" % [capture_name,value])
		super.fitted_text(value,rect,size,color,align_center)
	func fitted_number(value: String, rect: Rect2, size=34, color=WHITE, align_center=false):
		if value not in visible_text: visible_text.append(value)
		if number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x > rect.size.x+1:
			text_overflows.append("%s number exceeds fitting width: %s" % [capture_name,value])
		super.fitted_number(value,rect,size,color,align_center)

func _initialize(): call_deferred("run_checks")

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	records.append({"passed":ok,"check":label})
	print("PASS: " if ok else "FAIL: ",label)

func output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): return argument.trim_prefix("--output-dir=")
	return ""

func image_for(texture: Texture2D) -> Image:
	var picture = texture.get_image()
	if picture!=null and picture.is_compressed():
		if picture.decompress()!=OK: return null
	return picture

func normalized_region(art, name: String) -> Rect2:
	var region: Rect2 = art.regions[name]
	var dimensions: Vector2 = art.textures[name].get_size()
	return Rect2(region.position/dimensions,region.size/dimensions)

func inspect_art(game, area: String):
	game.set_active_area(area)
	check(game.area_id==area,"Art fixture selects "+area+" without persistence")
	check(game.board_data.size()==12,area+" provides twelve authored boards")
	check(game.food_art.is_area_ready(area) and game.ui_art.is_area_ready(area) and game.environment_art.is_area_ready(area),area+" complete art families are ready before entry")
	for group in [["food",game.food_art],["environment",game.environment_art],["ui",game.ui_art]]:
		var category: String = group[0]
		var art = group[1]
		for name in art.NAMES:
			var exists = art.textures.has(name) and art.regions.has(name)
			check(exists,area+" imported "+category+" texture/region: "+name)
			if not exists: continue
			var texture: Texture2D = art.textures[name]
			var region: Rect2 = art.regions[name]
			check(texture.get_width()>0 and texture.get_height()>0 and region.has_area() and Rect2(Vector2.ZERO,texture.get_size()).grow(.1).encloses(region),area+" valid source frame: "+name)
			if area=="gelato" and category in ["food","environment"]:
				check(texture.resource_path.begins_with("res://data/art/gelato/"),"Gelato uses its own art, not Bakery fallback: "+name)
			if area=="gelato" and category=="ui":
				var expected = "res://data/art/gelato/ui/" if name in art.GELATO_OVERRIDES else "res://data/art/ui/"
				check(texture.resource_path.begins_with(expected),"Gelato UI uses the intended override or shared semantic skin: "+name)
	for kind in game.food_art.COOKIE_KINDS:
		var base = "cookie_"+kind
		if not game.food_art.textures.has(base): continue
		var family_region = normalized_region(game.food_art,base)
		var hashes: Dictionary = {}
		for index in range(4):
			var name = base if index==0 else base+"_damage_"+str(index)
			if not game.food_art.textures.has(name): continue
			check(normalized_region(game.food_art,name).is_equal_approx(family_region),area+" damage frame keeps family position/scale: "+name)
			var picture: Image = image_for(game.food_art.textures[name])
			check(picture!=null and not picture.is_empty(),area+" damage pixels readable: "+name)
			if picture==null or picture.is_empty(): continue
			hashes[picture.get_data().hex_encode().sha256_text()] = true
			var frame = Rect2(family_region.position*Vector2(picture.get_size()),family_region.size*Vector2(picture.get_size())).grow(1.1)
			var clipped = 0
			var visible = 0
			var transparent = 0
			for y in range(picture.get_height()):
				for x in range(picture.get_width()):
					var alpha = picture.get_pixel(x,y).a
					if alpha<.01: transparent+=1
					if alpha>=20.0/255.0:
						visible+=1
						if not frame.has_point(Vector2(x+.5,y+.5)): clipped+=1
			check(visible>100 and transparent>100,area+" damage sprite has food and genuine transparent margins: "+name)
			check(clipped==0,area+" shared damage source frame does not clip visible pixels: "+name)
		check(hashes.size()==4,area+" has four genuinely distinct damage images: "+kind)
	# Every themed food still maps to the existing mechanical role and footprint.
	check(game.food_art.ball_name("normal")=="donut" and game.food_art.ball_name("splitter")=="pomegranate" and game.food_art.ball_name("impact")=="pumpkin" and game.food_art.ball_name("shard")=="seed",area+" theme preserves stable mechanical art keys")
	check(is_equal_approx(game.ball_radius("normal"),9.0) and is_equal_approx(game.ball_radius("impact"),11.25) and is_equal_approx(game.ball_radius("shard"),6.0),area+" theme preserves food collision radii")
	for number in range(1,13):
		game.current_level=number
		game.wave=number
		game.build_wave()
		var preview=game.home_menu.preview_pegs()
		var same=preview.size()==game.pegs.size()
		for i in range(mini(preview.size(),game.pegs.size())):
			same=same and preview[i].p==game.pegs[i].p and preview[i].kind==game.pegs[i].kind
		check(same,area+" Home preview matches physics positions and peg roles on tray "+str(number))

func stage(game, area: String, page: String, resolution: Vector2i):
	game.capture_name=area+"-"+page
	game.visible_text.clear()
	game.text_overflows.clear()
	game.run_transition.finish()
	game.mode="home"
	game.testing=true
	game.sound_on=false
	game.set_active_area(area)
	game.area_records["bakery"]=game.AreaCampaign.default_record()
	game.area_records["gelato"]=game.AreaCampaign.default_record()
	game.position=Vector2.ZERO
	game.scale=Vector2.ONE*float(resolution.x)/720.0
	game.current_level=8
	game.highest_unlocked=10
	game.chapter_complete=false
	game.bank=1268.55
	game.levels=[2,3,2,2,2,2,2,3]
	game.equipped=["splitter","impact"]
	game.module_vouchers=1
	game.module_milestones=[2,5]
	game.trial_active=false
	game.shift_claimed=true
	game.navigation_delay=0
	game.result_input_delay=0
	game.note_time=0
	game.reduced_motion=false
	game.diagnostics_on=false
	game.monetization.reset_test_state()
	game.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
	game.home_menu.reset()
	game.level_map.reset()
	game.upgrade_map.reset_view_state()
	game.start_shift()
	game.run_transition.finish()
	game.mode="home"
	game.shift_claimed=true
	game.remaining=7.4
	game.shift_coins=127.35
	game.impact_feedback.reset()
	game.balls.clear()
	game.particles.clear()
	game.floats.clear()
	match page:
		"home-fresh", "shop-fresh":
			game.current_level=1
			game.highest_unlocked=1
			game.bank=0
			game.levels=[0,0,0,0,0,0,0,0]
			game.equipped=[]
			game.module_vouchers=0
			game.module_milestones=[]
			game.mode="shop" if page=="shop-fresh" else "home"
		"play":
			game.mode="play"
			game.shift_claimed=false
			for i in range(game.pegs.size()):
				game.pegs[i].hp=game.pegs[i].max*[1.0,.85,.55,.25][i%4]
			for food in [["normal",Vector2(205,690)],["splitter",Vector2(515,730)],["impact",Vector2(350,850)],["ricochet",Vector2(150,920)],["shard",Vector2(530,920)]]:
				game.spawn_ball(food[1],food[0],Vector2.ZERO)
			for i in range(5): game.buckets[i].hits=[2,4,9,1,3][i]
			game.impact_feedback.catch_food(2)
		"levels-last", "entry", "entry-unfunded":
			game.mode="boards"
			game.current_level=12
			game.highest_unlocked=12
			game.chapter_complete=true
			game.bank=45000.0 if page!="entry-unfunded" else game.area_entry_status("gelato").cost-1.0
			if area=="bakery": game.area_records.erase("gelato")
			game.level_map.open()
			if page.begins_with("entry"):
				game.level_map.entry_open=true
				check(game.area_entry_status("gelato").can_enter==(page=="entry"),"Entry preview is "+("funded and available" if page=="entry" else "disabled when unfunded")+" at "+str(resolution))
		"shop-expanded": game.mode="shop"
		"loadout": game.mode="loadout"
		"result-clear", "result-retry":
			game.mode="result"
			game.shift_claimed=false
			game.level_won=page=="result-clear"
			game.destroyed=game.pegs.size() if game.level_won else 12
			game.result_peg_total=game.pegs.size()
			game.max_combo=8
			game.special_stats={"normal":game.destroyed-7,"ricochet":2,"splitter":2,"impact":2,"shard":1,"pulse":0}
			game.remaining=0
		"area-menu":
			game.mode="boards"
			game.level_map.open()
			game.level_map.area_menu_open=true
		"home-safe-area":
			var display_scale = float(resolution.x)/720.0
			game.apply_safe_area(Rect2(Vector2(0,60)*display_scale,Vector2(720,1160)*display_scale))
	game.upgrade_map.update(0.0)
	game.level_map.update(0.0)
	game.queue_redraw()

func run_checks():
	var output = output_directory()
	if output.is_empty() or not output.is_absolute_path():
		push_error("Supply --output-dir=<absolute directory>; no player profile is accessed.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		quit(2)
		return
	var art_only = "--art-only" in OS.get_cmdline_user_args()
	if not art_only and DisplayServer.get_name()=="headless":
		push_error("Real renderer previews require a GPU renderer, not --headless.")
		quit(2)
		return
	var viewport = SubViewport.new()
	viewport.size=RESOLUTIONS[0]
	viewport.disable_3d=true
	viewport.transparent_bg=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=ArtGame.new()
	game.testing=true
	viewport.add_child(game)
	for area in AREAS: inspect_art(game,area)
	if not art_only:
		for resolution in RESOLUTIONS:
			viewport.size=resolution
			for area in AREAS:
				var pages=PAGES.duplicate()
				if area=="bakery": pages.append_array(["entry","entry-unfunded"])
				for page in pages:
					stage(game,area,page,resolution)
					var before=var_to_bytes(game.RunSnapshot.capture(game))
					var physical_before=var_to_bytes([game.pegs,game.balls,game.buckets])
					var wallet=game.bank
					var tiers=game.levels.duplicate()
					var random_state=game.rng.state
					var theme_before=[game.food_art.area_id,game.environment_art.area_id,game.ui_art.area_id]
					await process_frame
					await RenderingServer.frame_post_draw
					var picture=viewport.get_texture().get_image()
					var filename="%s-%s-%dx%d.png" % [area,page,resolution.x,resolution.y]
					check(picture!=null and picture.get_size()==resolution,"Actual renderer capture: "+filename)
					if picture!=null: check(picture.save_png(output.path_join(filename))==OK,"Saved rendered image: "+filename)
					check(game.text_overflows.is_empty(),"Text stays in canvas and fitting bounds: "+filename)
					for issue in game.text_overflows: print("GELATO_LAYOUT_DETAIL=",issue)
					var flavor=false
					for line in game.visible_text:
						if line.to_lower().contains("drag to") or line.to_lower().contains("pinch to") or line.to_lower().contains("grow your recipe"): flavor=true
					check(not flavor,"No gesture hints or decorative flavor copy: "+filename)
					if page.begins_with("entry"):
						var underlying_play=false
						for line in game.visible_text:
							if line.begins_with("Play"): underlying_play=true
						check(not underlying_play,"Entry omits covered background Play copy: "+filename)
					if area=="gelato":
						var stale_labels: Array[String]=[]
						for line in game.visible_text:
							for stale in ["cookie","donut","doughnut","pomegranate","pumpkin","orange"]:
								if line.to_lower().contains(stale) and line not in stale_labels: stale_labels.append(line)
						check(stale_labels.is_empty(),"Gelato visible food labels match its art: "+filename)
						if not stale_labels.is_empty(): print("GELATO_STALE_LABEL_DETAIL=",stale_labels)
					check(before==var_to_bytes(game.RunSnapshot.capture(game)) and physical_before==var_to_bytes([game.pegs,game.balls,game.buckets]) and wallet==game.bank and tiers==game.levels and random_state==game.rng.state,"Drawing preserves physics, wallet, upgrades and RNG: "+filename)
					check(theme_before==[game.food_art.area_id,game.environment_art.area_id,game.ui_art.area_id],"Cross-area illustration does not change active theme: "+filename)
					captures.append({"file":filename,"area":area,"page":page,"size":[resolution.x,resolution.y],"visible_text":game.visible_text.duplicate(),"layout_issues":game.text_overflows.duplicate()})
	check(game.persistence_attempts==0,"All art/preview fixtures bypass player profile reads and writes")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"captures":captures,"checks":records,"player_profile_accesses":game.persistence_attempts,"renderer":DisplayServer.get_name()}
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	game.free()
	viewport.queue_free()
	print("GELATO_ART_QA_RESULT passed=",passed," failed=",failures.size()," captures=",captures.size())
	quit(0 if failures.is_empty() else 1)
