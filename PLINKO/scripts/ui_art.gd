extends RefCounted
## Each area owns a complete UI skin set. No area borrows Bakery controls.
const ROOT = "res://data/art/ui/"
const NAMES = ["panel", "button_mint", "button_cream", "timer", "coin", "node", "upgrade_tile_green", "upgrade_tile_red", "upgrade_tile_cream", "upgrade_parchment", "level_badge_cream", "level_badge_mint", "level_badge_muted", "level_selector"]
const AreaArt = preload("res://scripts/area_art.gd")
const GELATO_ROOT = "res://data/art/gelato/ui/"
const CRYSTAL_ROOT = "res://data/art/crystal/ui/"
const AREA_ROOTS = {"bakery":ROOT,"gelato":GELATO_ROOT,"crystal":CRYSTAL_ROOT}
const MENU_ROOT = "res://data/art/menus/"
var textures: Dictionary = {}
var regions: Dictionary = {}
var area_id = "bakery"
var _sets: Dictionary = {}
var _menu_frames: Dictionary = {}

func load_assets():
	_sets.clear()
	_menu_frames.clear()
	for id in ["bakery","gelato","crystal"]:
		var path = MENU_ROOT+id+"_frame.png"
		if ResourceLoader.exists(path): _menu_frames[id] = load(path) as Texture2D
	_load_set("bakery")
	_load_set("gelato")
	_load_set("crystal")
	if not set_area(area_id): set_area("bakery")

func _load_set(id: String):
	if not AREA_ROOTS.has(id): return
	_sets[id] = AreaArt.read_set(AREA_ROOTS[id],NAMES,false,id!="bakery")

static func resource_paths() -> Array[String]:
	# The loader and startup warmup share the same explicit resource roster.
	var paths: Array[String] = []
	for name in NAMES: paths.append(ROOT+name+".png")
	for id in ["gelato","crystal"]:
		var bounds = JSON.parse_string(FileAccess.get_file_as_string(AREA_ROOTS[id]+"regions.json"))
		if not bounds is Dictionary: continue
		for name in NAMES:
			var entry = bounds.get(name)
			if not entry is Dictionary: continue
			var path = str(entry.get("texture",""))
			if AreaArt.valid_atlas_path(AREA_ROOTS[id],path) and path not in paths: paths.append(path)
	return paths

func is_area_ready(id: String) -> bool:
	if not AREA_ROOTS.has(id): return false
	if not _sets.has(id): _load_set(id)
	return _sets[id].complete

func set_area(id: String) -> bool:
	if not is_area_ready(id): return false
	area_id = id
	textures = _sets[id].textures
	regions = _sets[id].regions
	return true

func text_offset(role: String) -> Vector2:
	# Gelato's painted reading faces sit below the full sprite bounds. Keep
	# labels and their symbols on those faces without moving the hit rectangles.
	if area_id=="gelato":
		if role=="button_mint": return Vector2(0,2)
		if role=="button_cream": return Vector2(0,4)
		if role=="level_selector": return Vector2(0,4)
	return Vector2.ZERO

func draw(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
	var size = source.size*factor
	canvas.draw_texture_rect_region(textures[name],Rect2(target.position+(target.size-size)*.5,size),source,tint)
	return true

func menu_frame(canvas: CanvasItem, content: Rect2) -> bool:
	# Dedicated menu artwork is separate from the area's HUD, cards and buttons.
	# Corner ornaments keep a uniform scale; only quiet spans stretch.
	var texture = _menu_frames.get(area_id) as Texture2D
	if texture == null: return false
	var target = content.grow(32.0)
	var size = texture.get_size()
	var cut = minf(size.x,size.y)*.26
	var edge = minf(100.0,minf(target.size.x,target.size.y)*.25)
	var sx = [0.0,cut,size.x-cut,size.x]
	var sy = [0.0,cut,size.y-cut,size.y]
	var dx = [target.position.x,target.position.x+edge,target.end.x-edge,target.end.x]
	var dy = [target.position.y,target.position.y+edge,target.end.y-edge,target.end.y]
	for row in range(3):
		for col in range(3):
			canvas.draw_texture_rect_region(texture,Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row]),Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row]))
	return true

func surface(canvas: CanvasItem, name: String, target: Rect2) -> bool:
	if not textures.has(name): return false
	# Use the quiet interior edge to edge, without the isolated asset's rim.
	var bounds: Rect2 = regions[name]
	var source = Rect2(bounds.position+bounds.size*.15,bounds.size*.7)
	var ratio = target.size.x/target.size.y
	var crop = Vector2(minf(source.size.x,source.size.y*ratio),minf(source.size.y,source.size.x/ratio))
	source = Rect2(source.get_center()-crop*.5,crop)
	canvas.draw_texture_rect_region(textures[name],target,source)
	return true

func skin(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(name): return false
	# Crystal's selector has a centered crest above and below its quiet face.
	# Keep both live Home lines inside that face without changing touch bounds.
	if area_id=="crystal" and name=="level_selector": target=target.grow_individual(0,14,0,14)
	var source: Rect2 = regions[name]
	# Keep ceramic corners round and copper edges thin across cards, chips and buttons.
	var is_panel = name in ["panel", "upgrade_parchment", "level_selector"]
	var source_x = minf(source.size.x,source.size.y)*(.16 if is_panel else .55)
	var source_y = minf(source.size.x,source.size.y)*(.16 if is_panel else .32)
	var edge_x = minf(26.0,minf(target.size.x,target.size.y)*.38) if is_panel else minf(target.size.x*.48,target.size.y*.55)
	var edge_y = edge_x if is_panel else target.size.y*.32
	if area_id!="bakery" and name=="panel":
		# Include the entire painted rim/ornaments in the fixed-height slices;
		# stretching any of that rim would cross live HUD and card headings.
		source_y=minf(source.size.x,source.size.y)*.28
		edge_y=minf(20.0,minf(target.size.x,target.size.y)*.24)
	var sx = [source.position.x,source.position.x+source_x,source.end.x-source_x,source.end.x]
	var sy = [source.position.y,source.position.y+source_y,source.end.y-source_y,source.end.y]
	var dx = [target.position.x,target.position.x+edge_x,target.end.x-edge_x,target.end.x]
	var dy = [target.position.y,target.position.y+edge_y,target.end.y-edge_y,target.end.y]
	for row in range(3):
		for col in range(3):
			canvas.draw_texture_rect_region(textures[name],Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row]),Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row]),tint)
	return true
