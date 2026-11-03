extends RefCounted
## Shared bakery environments; source art has no baked controls or text.
const ROOT = "res://data/art/environment/"
const NAMES = ["home_counter","play_counter","upgrade_counter","journey_backdrop","bakery_landmark"]
const AreaArt = preload("res://scripts/area_art.gd")
const GELATO_ROOT = "res://data/art/gelato/environment/"
const CRYSTAL_ROOT = "res://data/art/crystal/environment/"
const AREA_ROOTS = {"bakery":ROOT,"gelato":GELATO_ROOT,"crystal":CRYSTAL_ROOT}
var textures: Dictionary = {}
var regions: Dictionary = {}
var area_id = "bakery"
var _sets: Dictionary = {}

func load_assets():
	_sets.clear()
	_sets["bakery"] = AreaArt.read_set(ROOT,NAMES)
	_sets["gelato"] = AreaArt.read_set(GELATO_ROOT,NAMES)
	_sets["crystal"] = AreaArt.read_set(CRYSTAL_ROOT,NAMES,false,true)
	if not set_area(area_id): set_area("bakery")

func is_area_ready(id: String) -> bool:
	if not AREA_ROOTS.has(id): return false
	if not _sets.has(id): _sets[id] = AreaArt.read_set(AREA_ROOTS[id],NAMES,false,id=="crystal")
	return _sets[id].complete

func set_area(id: String) -> bool:
	if not is_area_ready(id): return false
	area_id = id
	textures = _sets[id].textures
	regions = _sets[id].regions
	return true

func draw_for_area(canvas: CanvasItem, id: String, name: String, target: Rect2, tint: Color = Color.WHITE, preserve_aspect: bool = true) -> bool:
	if not is_area_ready(id) or not _sets[id].textures.has(name): return false
	var source: Rect2 = _sets[id].regions[name]
	if preserve_aspect:
		var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
		var size = source.size*factor
		target = Rect2(target.position+(target.size-size)*.5,size)
	canvas.draw_texture_rect_region(_sets[id].textures[name],target,source,tint)
	return true

func draw_cover_for_area(canvas: CanvasItem, id: String, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not is_area_ready(id) or not _sets[id].textures.has(name): return false
	var source: Rect2 = _sets[id].regions[name]
	var ratio = target.size.x/target.size.y
	var crop = Vector2(minf(source.size.x,source.size.y*ratio),minf(source.size.y,source.size.x/ratio))
	source = Rect2(source.get_center()-crop*.5,crop)
	canvas.draw_texture_rect_region(_sets[id].textures[name],target,source,tint)
	return true

func draw(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE, preserve_aspect: bool = true) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	if preserve_aspect:
		var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
		var size = source.size*factor
		target = Rect2(target.position+(target.size-size)*.5,size)
	canvas.draw_texture_rect_region(textures[name],target,source,tint)
	return true

func draw_cover(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	var ratio = target.size.x/target.size.y
	var crop = Vector2(minf(source.size.x,source.size.y*ratio),minf(source.size.y,source.size.x/ratio))
	source = Rect2(source.get_center()-crop*.5,crop)
	canvas.draw_texture_rect_region(textures[name],target,source,tint)
	return true
