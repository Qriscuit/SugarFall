extends SceneTree
## Reads packaged presentation assets only. No Main instance or profile IO.
const Food=preload("res://scripts/food_art.gd")
const EnvArt=preload("res://scripts/environment_art.gd")
const UI=preload("res://scripts/ui_art.gd")
const Arc=preload("res://scripts/upgrade_arc_art.gd")
const Results=preload("res://scripts/result_comparison_ui.gd")
var passed=0
var failures: Array[String]=[]

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func opaque_pixels(texture: Texture2D,region: Rect2) -> int:
	var bitmap=texture.get_image()
	if bitmap==null: return 0
	var count=0
	for y in range(maxi(0,int(ceil(region.position.y))),mini(bitmap.get_height(),int(floor(region.end.y)))):
		for x in range(maxi(0,int(ceil(region.position.x))),mini(bitmap.get_width(),int(floor(region.end.x)))):
			if bitmap.get_pixel(x,y).a>=.125: count+=1
	return count

func _initialize():
	var food=Food.new(); food.load_assets()
	var environment=EnvArt.new(); environment.load_assets()
	var ui=UI.new(); ui.load_assets()
	var arc=Arc.new()
	for area in ["bakery","gelato","crystal"]:
		check(food.is_area_ready(area) and environment.is_area_ready(area) and ui.is_area_ready(area),"Complete food, environment and UI sets load for "+area)
		check(food.set_area(area) and environment.set_area(area) and ui.set_area(area),"Theme switching activates the requested assets: "+area)
		check(food.textures.size()==(27 if area=="crystal" else 26),"Food set contains every required visual state for "+area)
		check(environment.textures.size()==5 and ui.textures.size()==14,"Environment and shared UI coverage remain complete for "+area)
		check(arc.is_ready(area),"Full upgrade illustration loads for "+area)
		var valid=true
		for name in food.textures:
			valid=valid and Rect2(Vector2.ZERO,food.textures[name].get_size()).encloses(food.regions[name]) and food.regions[name].has_area()
		check(valid,"Every food crop is finite and contained in its imported native source: "+area)
		check(food.has_art("multiply_pickup")== (area=="crystal"),"Multiplier artwork is isolated to Crystal")
	food.set_area("crystal"); environment.set_area("crystal"); ui.set_area("crystal")
	var native_sources={}
	for texture in food.textures.values()+environment.textures.values():
		if native_sources.has(texture.resource_path): continue
		native_sources[texture.resource_path]=true
		var native=Image.load_from_file(texture.resource_path)
		check(native!=null and texture.get_size()==Vector2(native.get_size()),"Imported atlas preserves native dimensions: "+texture.resource_path)
	check(not food.set_area("unknown") and food.area_id=="crystal","Invalid area cannot replace the active Crystal sprite set")
	for names in [["donut","ricochet","pomegranate","pumpkin","seed","multiply_pickup"],["hopper","cup_cream","cup_gold"]]:
		var shared=true
		for name in names: shared=shared and food.textures[name]==food.textures[names[0]]
		check(shared,"Native atlas is reused for the authored sprite group: "+str(names))
	for role in ["normal","armored","prism","clock"]:
		var base="cookie_"+role
		var size: Vector2=food.regions[base].size
		var aligned=true
		for damage in range(1,4):
			var name=base+"_damage_"+str(damage)
			aligned=aligned and food.regions[name].size.is_equal_approx(size) and food.textures[name]==food.textures[base]
		check(aligned,"All four "+role+" damage states retain one physical frame without resizing fragments")
		var intact=opaque_pixels(food.textures[base],food.regions[base])
		var broken=opaque_pixels(food.textures[base+"_damage_3"],food.regions[base+"_damage_3"])
		check(intact>0 and broken>0 and broken<intact*.95,"Final "+role+" damage frame visibly removes material and keeps remaining crystal")
	check(environment.textures.bakery_landmark==food.textures.hopper,"The area landmark uses its own UV frame in the native equipment atlas")
	check(environment.textures.home_counter==environment.textures.play_counter and food.textures.countertop==environment.textures.play_counter,"Home, gameplay and countertop deliberately reuse the complete Crystal room painting")
	for name in UI.NAMES:
		check(ui._sets.crystal.textures[name]==ui._sets.bakery.textures[name],"Shared control keeps its established silhouette/state skin: "+name)
	Results.load_assets(true)
	check(Results.art_ready() and Results._textures.has("crystal"),"Results screen has its Crystal room backdrop and shared payout dish")
	check(Results._textures.crystal==environment.textures.play_counter,"Results backdrop points to the same native Crystal room painting")
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/crystal_upgrade_layout.json"))
	var world: Array=layout.shape.world_rect
	check(arc.area_world_rect("crystal")==Rect2(world[0],world[1],world[2],world[3]),"Crystal upgrade illustration and node geometry share exact world bounds")
	print("CRYSTAL_ART_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
