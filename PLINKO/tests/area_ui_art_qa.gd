extends SceneTree
## Asset ownership, confinement, switching and route behavior. No profile IO.
const UI = preload("res://scripts/ui_art.gd")
const Art = preload("res://scripts/area_art.gd")
const Wave = preload("res://scripts/page_transition.gd")
const Startup = preload("res://scripts/startup.gd")
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func save_game(): return true
	func load_game(): push_error("UI art fixture must not load a profile")

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	var ui = UI.new(); ui.load_assets()
	for area in UI.AREA_ROOTS:
		check(ui.is_area_ready(area) and ui.set_area(area),"Complete independent UI set activates: "+area)
		check(ui.textures.size()==UI.NAMES.size() and ui.regions.size()==UI.NAMES.size(),"All UI roles are present: "+area)
		for name in UI.NAMES:
			var texture = ui.textures.get(name) as Texture2D
			var region: Rect2 = ui.regions.get(name,Rect2())
			check(texture != null and texture.resource_path.begins_with(UI.AREA_ROOTS[area]),"UI texture belongs to selected area: "+area+"/"+name)
			check(texture != null and region.has_area() and Rect2(Vector2.ZERO,texture.get_size()).grow(.01).encloses(region),"UI region stays within its native source: "+area+"/"+name)
			if area != "bakery":
				check(texture != ui._sets.bakery.textures[name],"Themed UI never aliases Bakery: "+area+"/"+name)
	var previous = ui.area_id
	var textures = ui.textures
	check(not ui.set_area("unknown") and ui.area_id==previous and ui.textures==textures,"Invalid area leaves the current UI intact")
	for area in ["gelato","crystal"]:
		var root: String = UI.AREA_ROOTS[area]
		check(Art.valid_atlas_path(root,root+"controls.png"),"UI atlas accepts its own native texture: "+area)
		for invalid in [UI.ROOT+"panel.png",UI.AREA_ROOTS["crystal" if area=="gelato" else "gelato"]+"controls.png",root+"../food/balls.png",root+"controls.svg"]:
			check(not Art.valid_atlas_path(root,invalid),"UI atlas rejects cross-area, escaped or non-PNG source: "+invalid)
		ui._sets[area].complete = false
		check(not ui.is_area_ready(area) and not ui.set_area(area) and ui.area_id==previous,"Incomplete UI set blocks selection instead of borrowing Bakery: "+area)
		ui._sets.erase(area)
		check(ui.is_area_ready(area),"Themed UI reloads from its explicit metadata: "+area)
	var warmed = Startup.warmup_paths()
	for path in UI.resource_paths()+Wave.WAVE_PATHS.values():
		check(path in warmed and ResourceLoader.exists(path),"Startup warms the exact active UI/wave resource: "+path)
	var game = Fixture.new(); game.testing=true; game.sound_on=false
	game.page_transition.load_assets()
	game.page_transition.enabled=true
	for area in UI.AREA_ROOTS:
		game.set_active_area(area)
		game.page_transition.begin("studio","home")
		check(game.page_transition.active and game.page_transition.wave_area_id==area and game.page_transition.wave_texture!=null and game.page_transition.wave_texture.resource_path==Wave.WAVE_PATHS[area],"Studio reveal selects destination area's native wave: "+area)
		var wave = game.page_transition.wave_texture
		game.set_active_area("crystal" if area!="crystal" else "gelato")
		game.page_transition.begin("home","support")
		check(game.page_transition.wave_texture==wave and game.page_transition.wave_area_id==area,"Coalesced mode writes preserve the captured wave artwork: "+area)
		game.set_active_area(area)
		for bounds in [Rect2(0,0,720,1280),Rect2(-45,-80,810,1440)]:
			game.page_transition.time=Wave.DURATION*.5
			check(game.page_transition.geometry(bounds).fully_covered,"Area wave retains opaque midpoint including overscan: "+area+" "+str(bounds))
		game.page_transition.finish()
		game.reduced_motion=true
		game.page_transition.begin("home","shop")
		check(not game.page_transition.is_blocking(),"Reduced Motion skips themed wave and input hold: "+area)
		game.reduced_motion=false
		check(not game.page_transition.uses_cream("home","play") and not game.page_transition.uses_cream("play","paused") and not game.page_transition.uses_cream("play","result"),"Area theming preserves Home morph, pause and frozen results routes: "+area)
	game.free()
	print("AREA_UI_ART_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
