extends SceneTree
## Checks the single illustrated layer without loading or saving a player profile.
const Main = preload("res://scripts/main.gd")
var passed = 0
var failures: Array[String] = []

func check(ok: bool, label: String):
	if ok:
		passed+=1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func _initialize():
	var game=Main.new()
	game.testing=true
	var map=game.upgrade_map
	var art=map.arc_art
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_arc_art.json"))
	check(data is Dictionary and data.get("schema",0)==3,"The active art uses the complete-illustration format")
	check(not data.has("assets") and not data.has("placements") and not data.has("landscaping"),"No old sprite collage or native scenery layers are drawn over the illustration")
	check(art.world_rect.has_area(),"The illustration has finite positive map-world bounds")
	var contained=true
	for node in map._positions:
		contained=contained and art.world_rect.encloses(Rect2(map._positions[node]-map.TILE_SIZE*.5,map.TILE_SIZE))
	check(contained,"All 62 upgrade tiles lie within the illustration bounds")
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_layout.json"))
	check(is_equal_approx(float(layout.shape.sweep_degrees),120.0),"The existing shorter upgrade arc is preserved")
	var transformed=true
	for zoom in [map.MIN_ZOOM,map.INITIAL_ZOOM,map.MAX_ZOOM]:
		for pan in [Vector2.ZERO,Vector2(380,-190),Vector2(-1800,530)]:
			map.zoom=zoom
			map.pan=pan
			var target: Rect2=art.target_rect(map.center(),zoom)
			transformed=transformed and target.position.is_equal_approx(map.center()+art.world_rect.position*zoom) and target.size.is_equal_approx(art.world_rect.size*zoom)
	check(transformed,"The whole illustration follows exactly the upgrades' pan and zoom")
	check(not art.is_ready("missing-area") and art.texture_size("missing-area")==Vector2.ZERO,"Unknown areas use the existing map fallback")
	check(not art.draw(null,"missing-area",Rect2(),Vector2.ZERO,1),"An unknown area never attempts an image draw")
	check(not art.draw(null,"bakery",Rect2(),Vector2.ZERO,0) and not art.draw(null,"bakery",Rect2(),Vector2.ZERO,-1),"Invalid camera scales safely reject the draw")
	check(art.edge_fade>0 and art.edge_fade<=.03,"The scene fades only inside a narrow outer safety margin")
	var covered_area=0.0
	var patches_valid=art._patches.size()==9
	var boundary_transparent=true
	var interior_opaque=true
	for patch in art._patches:
		patches_valid=patches_valid and patch.points.size()==4 and patch.uv.size()==4 and patch.colors.size()==4
		if patch.uv.size()!=4: continue
		covered_area+=(patch.uv[1].x-patch.uv[0].x)*(patch.uv[3].y-patch.uv[0].y)
		for i in range(4):
			var uv: Vector2=patch.uv[i]
			patches_valid=patches_valid and Rect2(0,0,1.00001,1.00001).has_point(uv) and patch.points[i].is_equal_approx(art.world_rect.position+uv*art.world_rect.size)
			if uv.x==0 or uv.x==1 or uv.y==0 or uv.y==1:
				boundary_transparent=boundary_transparent and is_zero_approx(patch.colors[i].a)
			else:
				interior_opaque=interior_opaque and is_equal_approx(patch.colors[i].a,1)
	check(patches_valid and is_equal_approx(covered_area,1),"The fade samples the complete image once with continuous normalized coordinates")
	check(boundary_transparent and interior_opaque,"Image boundaries fade while the complete central illustration stays opaque")
	var another=map.ArcArt.new()
	var metrics={}
	for area in ["bakery","gelato"]:
		check(art.is_ready(area),"The "+area+" complete background is imported and ready")
		var texture: Texture2D=art._areas[area].texture
		var size: Vector2=art.texture_size(area)
		check(size.x>=1000 and size.y>=500,"The "+area+" scene retains its authored image dimensions")
		var area_rect: Rect2 = art.area_world_rect(area)
		check(absf(size.x/size.y-area_rect.size.x/area_rect.size.y)<.01,"The "+area+" scene preserves its own source aspect ratio")
		check(another._areas[area].texture==texture,"Map instances reuse the cached "+area+" scene texture")
		var area_transform = true
		for z in [.055,.84,1.55]:
			var origin = Vector2(470,-130)
			var area_target: Rect2 = art.target_rect(origin,z,area)
			area_transform = area_transform and area_target.position.is_equal_approx(origin+area_rect.position*z) and area_target.size.is_equal_approx(area_rect.size*z)
		check(area_transform,"The "+area+" illustration transforms with its own world bounds")
		var area_patches = true
		for patch in art._areas[area].patches:
			for i in range(4): area_patches = area_patches and patch.points[i].is_equal_approx(area_rect.position+patch.uv[i]*area_rect.size)
		check(area_patches,"The "+area+" fade patches align to its own illustration bounds")
		var density: Vector2=art.source_pixel_ratio(area,map.MAX_ZOOM)
		check(density.is_finite() and density.x>0 and density.y>0,"The "+area+" scene reports its actual source density at close zoom")
		metrics[area]={"texture_size":[size.x,size.y],"source_pixels_per_logical_pixel_at_max_zoom":[density.x,density.y]}
	check(art._areas.bakery.path!=art._areas.gelato.path,"Each theme selects its own complete illustration")
	var before=var_to_bytes([map._positions,map._paths,art.world_rect,art._patches])
	game.mode="shop"
	game.levels.fill(0)
	map.update(0)
	game.levels=game.MAX_LEVELS.duplicate()
	map.update(0)
	check(before==var_to_bytes([map._positions,map._paths,art.world_rect,art._patches]),"Purchases preserve Bakery illustration and upgrade alignment")
	game.set_active_area("gelato")
	game.mode="shop"
	map.update(0)
	check(before!=var_to_bytes([map._positions,map._paths,art.world_rect,art._patches]) and map._layout_area=="gelato","Gelato switches to its distinct U layout instead of reusing the Bakery cache")
	var gelato_contained = true
	for node in map._positions:
		gelato_contained = gelato_contained and art.area_world_rect("gelato").encloses(Rect2(map._positions[node]-map.TILE_SIZE*.5,map.TILE_SIZE))
	check(gelato_contained and art.area_world_rect("gelato")!=art.area_world_rect("bakery"),"Gelato's own illustration bounds contain its entire U and all 62 tiles")
	game.set_active_area("bakery")
	game.mode="shop"
	map.update(0)
	check(before==var_to_bytes([map._positions,map._paths,art.world_rect,art._patches]),"Returning to Bakery restores the exact original layout and illustration alignment")
	game.free()
	print("ARC_ART_METRICS ",JSON.stringify(metrics))
	print("UPGRADE_ARC_ART_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
