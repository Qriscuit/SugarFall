extends RefCounted
## Texture-only presentation. Physics and saved positions stay in board space.
const ROOT = "res://data/art/food/"
const NAMES = [
	"donut", "pomegranate", "pumpkin", "seed", "ricochet",
	"cookie_normal", "cookie_armored", "cookie_prism", "cookie_clock",
	"cup_cream", "cup_gold", "tray", "hopper", "countertop",
	"cookie_normal_damage_1", "cookie_normal_damage_2", "cookie_normal_damage_3",
	"cookie_armored_damage_1", "cookie_armored_damage_2", "cookie_armored_damage_3",
	"cookie_prism_damage_1", "cookie_prism_damage_2", "cookie_prism_damage_3",
	"cookie_clock_damage_1", "cookie_clock_damage_2", "cookie_clock_damage_3"
]
const COOKIE_KINDS = ["normal", "armored", "prism", "clock"]
# Multiplicative icing colors retain each role's painted detail and damage alpha.
# Board metadata selects the tier; presentation never derives strength from HP.
const STRENGTH_TIER_COLORS = {
	"bronze": Color("e5a66a"),
	"silver": Color("b5c9e8"),
	"gold": Color("ffda70"),
	"diamond": Color("8de6ff")
}
const STRENGTH_TIER_LABELS = {
	"bronze": "Bronze", "silver": "Silver", "gold": "Gold", "diamond": "Diamond"
}
const BALL_ART = {
	"normal": "donut", "splitter": "pomegranate", "impact": "pumpkin",
	"shard": "seed", "ricochet": "ricochet"
}
const AreaArt = preload("res://scripts/area_art.gd")
const GELATO_ROOT = "res://data/art/gelato/food/"
const CRYSTAL_ROOT = "res://data/art/crystal/food/"
const AREA_ROOTS = {"bakery":ROOT,"gelato":GELATO_ROOT,"crystal":CRYSTAL_ROOT}
# Quiet front-face regions, normalized within each authored sprite/atlas crop.
# Goblet labels belong on the bowl, not at the center of the bowl plus stem.
# These are presentation anchors only; catch positions and rewards are unchanged.
const CUP_LABEL_RECTS = {
	"bakery": {"cup_cream":Rect2(.17,.39,.66,.30),"cup_gold":Rect2(.17,.40,.66,.30)},
	"gelato": {"cup_cream":Rect2(.22,.40,.56,.23),"cup_gold":Rect2(.22,.31,.56,.24)},
	"crystal": {"cup_cream":Rect2(.18,.36,.64,.27),"cup_gold":Rect2(.18,.37,.64,.29)}
}
var textures: Dictionary = {}
var regions: Dictionary = {}
var area_id = "bakery"
var _sets: Dictionary = {}

static func names_for_area(id: String) -> Array:
	var names=NAMES.duplicate()
	if id=="crystal": names.append("multiply_pickup")
	return names

func load_assets():
	_sets.clear()
	_sets["bakery"] = AreaArt.read_set(ROOT,NAMES,true)
	_sets["gelato"] = AreaArt.read_set(GELATO_ROOT,NAMES,true)
	_sets["crystal"] = AreaArt.read_set(CRYSTAL_ROOT,names_for_area("crystal"),false,true)
	if not set_area(area_id): set_area("bakery")

func is_area_ready(id: String) -> bool:
	if not AREA_ROOTS.has(id): return false
	if not _sets.has(id):
		_sets[id] = AreaArt.read_set(AREA_ROOTS[id],names_for_area(id),id!="crystal",id=="crystal")
	return _sets[id].complete

func set_area(id: String) -> bool:
	if not is_area_ready(id): return false
	area_id = id
	textures = _sets[id].textures
	regions = _sets[id].regions
	return true

func has_art(name: String) -> bool:
	return textures.has(name)

func cup_label_rect(name: String, target: Rect2) -> Rect2:
	var uv: Rect2 = CUP_LABEL_RECTS.get(area_id,CUP_LABEL_RECTS.bakery).get(name,Rect2(.18,.39,.64,.28))
	return Rect2(target.position+uv.position*target.size,uv.size*target.size)

func draw(game: CanvasItem, name: String, target: Rect2, tint: Color = Color.WHITE, preserve_aspect: bool = true) -> bool:
	if not textures.has(name): return false
	var source: Rect2 = regions[name]
	if preserve_aspect:
		var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
		var fitted = source.size * factor
		target = Rect2(target.position+(target.size-fitted)*.5,fitted)
	game.draw_texture_rect_region(textures[name],target,source,tint)
	return true

func draw_centered(game: CanvasItem, name: String, center: Vector2, size: Vector2, tint: Color = Color.WHITE) -> bool:
	return draw(game,name,Rect2(center-size*.5,size),tint)

func tier_color(tier: String) -> Color:
	return STRENGTH_TIER_COLORS.get(tier,Color.WHITE)

func tier_label(tier: String) -> String:
	return STRENGTH_TIER_LABELS.get(tier,"")

func cookie_tint(kind: String, tier: String, tint: Color = Color.WHITE) -> Color:
	var material=tier_color(tier)
	# Gelato's waffle body is already golden. Neutralize that warm base before
	# tinting so Silver reads silver and Diamond reads blue instead of green.
	# Role decorations on clock/prism wafers retain their original colors.
	if area_id=="gelato" and kind in ["normal","armored"] and tier in STRENGTH_TIER_COLORS:
		material*=Color(1.0,1.47,3.4,1.0)
	return material*tint

func draw_cookie(game: CanvasItem, kind: String, hp: float, max_hp: float, center: Vector2, size: Vector2, tier: String = "", tint: Color = Color.WHITE) -> bool:
	# One original sprite draw: transparent bites stay empty, role decorations
	# remain visible, and the caller's hit-flash color and opacity still apply.
	return draw_centered(game,cookie_name(kind,hp,max_hp),center,size,cookie_tint(kind,tier,tint))

func draw_tray(game: CanvasItem, target: Rect2) -> bool:
	if not textures.has("tray"): return false
	# Three horizontal slices keep the side rails outside the playable cookie area.
	# The colored liner stretches while the rails occupy only 28 board pixels.
	var source: Rect2 = regions["tray"]
	var edge = source.size.x*.12
	var widths = [28.0,target.size.x-56.0,28.0]
	var source_widths = [edge,source.size.x-2*edge,edge]
	var x = target.position.x
	var sx = source.position.x
	for i in range(3):
		game.draw_texture_rect_region(textures["tray"],Rect2(x,target.position.y,widths[i],target.size.y),Rect2(sx,source.position.y,source_widths[i],source.size.y))
		x += widths[i]
		sx += source_widths[i]
	return true

func ball_name(kind: String) -> String:
	return BALL_ART.get(kind,"donut")

func cookie_name(kind: String, hp: float, max_hp: float) -> String:
	# Damage is derived from existing HP, never added to a saved peg or RNG.
	if kind not in COOKIE_KINDS: return "cookie_normal"
	var intact = "cookie_"+kind
	if not is_finite(hp) or not is_finite(max_hp) or max_hp <= 0 or hp >= max_hp:
		return intact
	var ratio = hp/max_hp
	var stage = 3 if ratio <= 1.0/3.0 else (2 if ratio <= 2.0/3.0 else 1)
	return intact+"_damage_"+str(stage)
