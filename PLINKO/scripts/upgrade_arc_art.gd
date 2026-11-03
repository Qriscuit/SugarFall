extends RefCounted
## One complete illustrated background per area, beneath the live upgrade map.
## The outer image margin fades into a quiet surface. Art is never tiled or
## assembled from separate props at runtime; textures and fade patches cache once.
const METADATA_PATH = "res://data/upgrade_arc_art.json"
static var _cache: Dictionary = {}
static var _loaded = false
var world_rect = Rect2()
var edge_fade = .025
var _areas: Dictionary = {}
var _patches: Array = []

func _init():
	if not _loaded:
		_cache = _read_assets()
		_loaded = true
	if _cache.is_empty(): return
	world_rect = _cache.world_rect
	edge_fade = _cache.edge_fade
	_areas = _cache.areas
	_patches = _cache.patches

static func _finite_numbers(value, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for number in value:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
	return true

static func _read_assets() -> Dictionary:
	if not FileAccess.file_exists(METADATA_PATH): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(METADATA_PATH))
	if not data is Dictionary or data.get("schema",0)!=3: return {}
	var raw = data.get("world_rect")
	if not _finite_numbers(raw,4): return {}
	var rect = Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	if not rect.has_area(): return {}
	var fade = data.get("edge_fade_fraction",.025)
	if not _finite_numbers([fade],1) or float(fade)<=0 or float(fade)>=.25: return {}
	var definitions = data.get("areas",{})
	if not definitions is Dictionary: return {}
	var areas: Dictionary = {}
	for id in ["bakery","gelato","crystal"]:
		var area = definitions.get(id,{})
		if not area is Dictionary or area.is_empty(): continue
		var path = str(area.get("texture",""))
		var texture: Texture2D = null
		if path.begins_with("res://data/art/") and ResourceLoader.exists(path): texture=load(path) as Texture2D
		var area_rect=rect
		if area.has("world_rect"):
			if not _finite_numbers(area.world_rect,4): continue
			area_rect=Rect2(float(area.world_rect[0]),float(area.world_rect[1]),float(area.world_rect[2]),float(area.world_rect[3]))
			if not area_rect.has_area(): continue
		areas[id] = {"texture":texture,"path":path,"world_rect":area_rect,"patches":_make_patches(area_rect,float(fade)),"base_color":Color.from_string(str(area.get("base_color","9fb79e")),Color("9fb79e"))}
	return {"world_rect":rect,"edge_fade":float(fade),"areas":areas,"patches":_make_patches(rect,float(fade))}

static func _make_patches(rect: Rect2, fade: float) -> Array:
	# These nine sampling patches all use the same image and continuous UVs.
	# Only vertices on its outermost edge fade; the complete interior is opaque.
	var coordinates = [0.0,float(fade),1.0-float(fade),1.0]
	var patches: Array = []
	for y in range(3):
		for x in range(3):
			var uv = PackedVector2Array([
				Vector2(coordinates[x],coordinates[y]),Vector2(coordinates[x+1],coordinates[y]),
				Vector2(coordinates[x+1],coordinates[y+1]),Vector2(coordinates[x],coordinates[y+1])])
			var points = PackedVector2Array()
			var colors = PackedColorArray()
			for p in uv:
				points.append(rect.position+p*rect.size)
				var boundary = p.x==0 or p.x==1 or p.y==0 or p.y==1
				colors.append(Color(1,1,1,0 if boundary else 1))
			patches.append({"points":points,"colors":colors,"uv":uv})
	return patches

func is_ready(area: String) -> bool:
	return _areas.has(area) and _areas[area].texture is Texture2D and area_world_rect(area).has_area() and _areas[area].patches.size()==9

func area_world_rect(area: String) -> Rect2:
	return _areas[area].world_rect if _areas.has(area) else world_rect

func texture_size(area: String) -> Vector2:
	return _areas[area].texture.get_size() if is_ready(area) else Vector2.ZERO

func source_pixel_ratio(area: String, zoom: float) -> Vector2:
	# A complete illustrated world is intentionally magnified at close zoom.
	# Expose the actual density for review rather than claiming sprite sharpness.
	return texture_size(area)/(area_world_rect(area).size*zoom) if is_ready(area) and is_finite(zoom) and zoom>0 else Vector2.ZERO

func target_rect(origin: Vector2, zoom: float, area: String = "bakery") -> Rect2:
	var rect=area_world_rect(area)
	return Rect2(origin+rect.position*zoom,rect.size*zoom)

func draw(canvas: CanvasItem, area: String, viewport: Rect2, origin: Vector2, zoom: float) -> bool:
	if not is_ready(area) or not is_finite(zoom) or zoom<=0: return false
	canvas.draw_rect(viewport,_areas[area].base_color)
	if not target_rect(origin,zoom,area).intersects(viewport): return true
	canvas.draw_set_transform(origin,0,Vector2.ONE*zoom)
	var texture: Texture2D = _areas[area].texture
	for patch in _areas[area].patches:
		canvas.draw_polygon(patch.points,patch.colors,patch.uv,texture)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	return true
