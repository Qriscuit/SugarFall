extends RefCounted
## Reusable bakery UI skins. Normalized source bounds follow import size limits.
const ROOT = "res://data/art/ui/"
const NAMES = ["panel", "button_mint", "button_cream", "timer", "coin", "node", "upgrade_tile_green", "upgrade_tile_red", "upgrade_tile_cream", "upgrade_parchment", "level_badge_cream", "level_badge_mint", "level_badge_muted", "level_selector"]
const AreaArt = preload("res://scripts/area_art.gd")
const GELATO_ROOT = "res://data/art/gelato/ui/"
const GELATO_OVERRIDES = ["panel","level_selector","level_badge_muted"]
var textures: Dictionary = {}
var regions: Dictionary = {}
var area_id = "bakery"
var _sets: Dictionary = {}

func load_assets():
	_sets.clear()
	_load_set("bakery")
	_load_set("gelato")
	_load_set("crystal")
	if not set_area(area_id): set_area("bakery")

func _load_set(id: String):
	if id=="bakery":
		_sets[id] = AreaArt.read_set(ROOT,NAMES)
		return
	if not _sets.has("bakery"): _load_set("bakery")
	var base: Dictionary = _sets.bakery
	if id=="crystal":
		# Shared controls retain their established silhouettes and state colors;
		# Crystal's environment and game pieces carry its new area identity.
		_sets[id] = {"textures":base.textures.duplicate(),"regions":base.regions.duplicate(),"complete":base.complete}
		return
	var overrides = AreaArt.read_set(GELATO_ROOT,GELATO_OVERRIDES)
	var themed = {"textures":base.textures.duplicate(),"regions":base.regions.duplicate(),"complete":base.complete and overrides.complete}
	themed.textures.merge(overrides.textures,true)
	themed.regions.merge(overrides.regions,true)
	_sets[id] = themed

func is_area_ready(id: String) -> bool:
	if id not in ["bakery","gelato","crystal"]: return false
	if not _sets.has(id): _load_set(id)
	return _sets[id].complete

func set_area(id: String) -> bool:
	if not is_area_ready(id): return false
	area_id = id
	textures = _sets[id].textures
	regions = _sets[id].regions
	return true

func draw(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
	var size = source.size*factor
	canvas.draw_texture_rect_region(textures[name],Rect2(target.position+(target.size-size)*.5,size),source,tint)
	return true

func surface(canvas: CanvasItem, name: String, target: Rect2) -> bool:
	if not textures.has(name): return false
	# Use the quiet paper interior edge to edge, without the isolated asset's rim.
	var bounds: Rect2 = regions[name]
	var source = Rect2(bounds.position+bounds.size*.15,bounds.size*.7)
	var ratio = target.size.x/target.size.y
	var crop = Vector2(minf(source.size.x,source.size.y*ratio),minf(source.size.y,source.size.x/ratio))
	source = Rect2(source.get_center()-crop*.5,crop)
	canvas.draw_texture_rect_region(textures[name],target,source)
	return true

func skin(canvas: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	# Keep ceramic corners round and copper edges thin across cards, chips and buttons.
	var is_panel = name in ["panel", "upgrade_parchment", "level_selector"]
	var source_x = minf(source.size.x,source.size.y)*(.16 if is_panel else .55)
	var source_y = minf(source.size.x,source.size.y)*(.16 if is_panel else .32)
	var edge_x = minf(26.0,minf(target.size.x,target.size.y)*.38) if is_panel else minf(target.size.x*.48,target.size.y*.55)
	var edge_y = edge_x if is_panel else target.size.y*.32
	var sx = [source.position.x,source.position.x+source_x,source.end.x-source_x,source.end.x]
	var sy = [source.position.y,source.position.y+source_y,source.end.y-source_y,source.end.y]
	var dx = [target.position.x,target.position.x+edge_x,target.end.x-edge_x,target.end.x]
	var dy = [target.position.y,target.position.y+edge_y,target.end.y-edge_y,target.end.y]
	for row in range(3):
		for col in range(3):
			canvas.draw_texture_rect_region(textures[name],Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row]),Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row]),tint)
	return true
