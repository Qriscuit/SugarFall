extends SceneTree
## Actual Godot texture rendering at 49 board pixels and 31 phone pixels.
## QA labels belong only to this contact sheet, never the in-game presentation.
## Run after import: Godot --path <project> --script res://tests/cookie_damage_preview.gd -- --output=<absolute.png>
const FoodArt = preload("res://scripts/food_art.gd")
const KINDS = ["normal","armored","prism","clock"]
const HP = [6.0,5.0,3.0,1.0]
const SIZES = [49.0,31.0]
const CANVAS_SIZE = Vector2i(1024,448)
var checks = 0
var failures: Array[String] = []

class StageSheet extends Node2D:
	var art = FoodArt.new()
	var missing: Array[String] = []
	func _ready():
		art.load_assets()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,Vector2(CANVAS_SIZE)),Color("fff7e7"))
		var font = ThemeDB.fallback_font
		for panel in range(2):
			var left = float(panel*512)
			draw_string(font,Vector2(left+25,35),"COOKIE DAMAGE  |  %d px" % SIZES[panel],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("63442e"))
			for column in range(4):
				draw_string(font,Vector2(left+130+column*96,72),["Intact","Chipped","Cracked","Crumbling"][column],HORIZONTAL_ALIGNMENT_CENTER,80,13,Color("63442e"))
			for row in range(4):
				var y = 121.0+row*87.0
				draw_string(font,Vector2(left+24,y+5),KINDS[row].capitalize(),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("63442e"))
				for column in range(4):
					var name: String = art.cookie_name(KINDS[row],HP[column],6.0)
					var center = Vector2(left+165+column*96,y)
					if not art.draw_centered(self,name,center,Vector2.ONE*SIZES[panel]) and name not in missing:
						missing.append(name)

func _initialize():
	call_deferred("capture")

func check(ok: bool, label: String):
	checks += 1
	if ok:
		print("PASS: ",label)
	else:
		failures.append(label)
		push_error("FAIL: "+label)

func capture():
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.is_absolute_path() or output.get_extension().to_lower()!="png" or DisplayServer.get_name()=="headless":
		push_error("Use a graphics renderer and --output=<absolute .png path>.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output.get_base_dir())!=OK:
		push_error("Cannot create the preview output directory.")
		quit(2)
		return
	var viewport = SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet = StageSheet.new()
	viewport.add_child(sheet)
	for kind in KINDS:
		var base = "cookie_"+kind
		check(sheet.art.has_art(base),"Imported intact texture exists: "+base)
		if not sheet.art.has_art(base): continue
		var texture_size: Vector2 = sheet.art.textures[base].get_size()
		var base_region: Rect2 = sheet.art.regions[base]
		var base_uv = Rect2(base_region.position/texture_size,base_region.size/texture_size)
		for stage in range(1,4):
			var name = base+"_damage_"+str(stage)
			check(sheet.art.has_art(name),"Imported damage texture exists: "+name)
			if not sheet.art.has_art(name): continue
			texture_size = sheet.art.textures[name].get_size()
			var region: Rect2 = sheet.art.regions[name]
			var uv = Rect2(region.position/texture_size,region.size/texture_size)
			check(uv.is_equal_approx(base_uv),"Damage stage preserves the intact source frame: "+name)
	await process_frame
	await RenderingServer.frame_post_draw
	var image = viewport.get_texture().get_image()
	check(image!=null and image.get_size()==CANVAS_SIZE,"Actual GPU contact sheet captured at its native resolution")
	check(sheet.missing.is_empty(),"All thirty-two rendered samples use the requested PNG")
	if image!=null:
		for panel in range(2):
			for row in range(4):
				var previous = PackedByteArray()
				for column in range(4):
					var center = Vector2i(panel*512+165+column*96,121+row*87)
					var pixels = image.get_region(Rect2i(center-Vector2i(27,27),Vector2i(54,54))).get_data()
					if column>0: check(pixels!=previous,"%s stage %d is visibly distinct at %d px" % [KINDS[row],column,SIZES[panel]])
					previous = pixels
		check(image.save_png(output)==OK,"Saved the cookie damage contact sheet")
	print("COOKIE_DAMAGE_PREVIEW_OUTPUT=",output)
	print("COOKIE_DAMAGE_PREVIEW_RESULT passed=",checks-failures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
