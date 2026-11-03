extends RefCounted
## Presentation only: a reward window over the frozen gameplay scene.
## The large payout includes claim bonuses; comparisons always use base run income.
const PANEL_RECT = Rect2(36,154,648,900)
const TRIAL_PANEL_RECT = Rect2(36,260,648,676)
const DISH_RECT = Rect2(180,280,360,150)
const PAYOUT_RECT = Rect2(80,440,560,88)
const CHANGE_RECT = Rect2(76,540,568,48)
const TITLE_RECT = Rect2(76,592,568,28)
const DETAIL_RECT = Rect2(76,624,568,26)
const STAT_RECTS = [Rect2(90,666,250,104),Rect2(380,666,250,104)]
const COLLECT_RECT = Rect2(60,800,600,96)
const BONUS_RECT = Rect2(60,910,600,100)
const LESS_INK = Color("a53c51")
const QUIET_INK = Color("625647")
const GREEN_INK = Color("286553")
const GOLD_INK = Color("996015")
const ART_PATHS = {
	"bakery":"res://data/art/results/bakery_backdrop_v1.png",
	"gelato":"res://data/art/results/gelato_backdrop_v1.png",
	"crystal":"res://data/art/crystal/environment/candyworks_room.png",
	"dish":"res://data/art/results/coin_dish_v1.png"
}
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}
static var _loaded = false

static func load_assets(force: bool = false):
	if _loaded and not force: return
	_loaded = true
	_textures.clear()
	_regions.clear()
	for key in ART_PATHS:
		if not ResourceLoader.exists(ART_PATHS[key]): continue
		var texture = load(ART_PATHS[key]) as Texture2D
		if texture == null: continue
		var source = Rect2(Vector2.ZERO,texture.get_size())
		if key == "dish":
			var bitmap = texture.get_image()
			if bitmap != null: source = Rect2(bitmap.get_used_rect())
		if not source.has_area(): continue
		_textures[key] = texture
		_regions[key] = source

static func art_ready() -> bool:
	load_assets()
	return _textures.size() == ART_PATHS.size()

static func _draw_art(g, key: String, target: Rect2, cover: bool = false) -> bool:
	load_assets()
	if not _textures.has(key): return false
	var source: Rect2 = _regions[key]
	if cover:
		var ratio = target.size.x/target.size.y
		var crop = Vector2(minf(source.size.x,source.size.y*ratio),minf(source.size.y,source.size.x/ratio))
		source = Rect2(source.get_center()-crop*.5,crop)
	else:
		var factor = minf(target.size.x/source.size.x,target.size.y/source.size.y)
		var size = source.size*factor
		target = Rect2(target.get_center()-size*.5,size)
	g.draw_texture_rect_region(_textures[key],target,source)
	return true

static func coins_text(g, amount: float) -> String:
	# A positive fraction must not look like a zero percentage baseline.
	return "<1" if amount > 0.0 and amount < 1.0 else g.credits_text(amount)

static func content(g, comparison: Dictionary) -> Dictionary:
	var current: Dictionary = comparison.get("current",{})
	var previous: Dictionary = comparison.get("previous",{})
	var direction: String = comparison.get("direction","first")
	var percent: String = comparison.get("percent_text","")
	var first = direction == "first" or previous.is_empty()
	var headline = "First run"
	var color: Color = QUIET_INK
	match direction:
		"up": headline = percent+" more" if percent.begins_with("<") else "+"+percent; color = GREEN_INK
		"down": headline = percent+" less" if percent.begins_with("<") else "−"+percent; color = LESS_INK
		"same": headline = "0%"
		"from_zero": headline = "Up from 0"; color = GREEN_INK
	var now = float(current.get("coins",0))
	var last = float(previous.get("coins",0))
	var detail_needed = not is_equal_approx(g.collection_payout(),now) or g.displayed_result_payout() != int(floor(now)) or not is_equal_approx(now,floor(now)) or (not first and not is_equal_approx(last,floor(last)))
	var detail = ""
	if detail_needed:
		detail = "Base "+coins_text(g,now) if first else "Base %s · last %s" % [coins_text(g,now),coins_text(g,last)]
	return {
		"title":"Run earnings" if first else "Run earnings vs last",
		"headline":headline,"detail":detail,"color":color,
		"labels":["Cleared","Best chain"],
		"values":["%d / %d" % [int(current.get("destroyed",0)),int(current.get("peg_total",0))],"%d×" % int(current.get("combo",0))],
		"previous":["" if first else "Last %d / %d" % [int(previous.get("destroyed",0)),int(previous.get("peg_total",0))],"" if first else "Last %d×" % int(previous.get("combo",0))]
	}

static func _draw_chain(g, center: Vector2):
	var copper = Color("ad693c")
	for offset in [Vector2(-8,-8),Vector2(8,8)]:
		g.draw_arc(center+offset,13,-.25,TAU-.25,32,copper,5,true)

static func _draw_bonus(g):
	if not g.test_commerce_available(): return
	var bonus: int = g.displayed_reward_bonus()
	var label = "Bonus added" if g.reward_earned else ("Test bonus +%d" % bonus if bonus > 0 else "Test bonus")
	var width: float = g.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	var center = BONUS_RECT.get_center()
	var content_width = width+46.0
	var capsule_size = Vector2(clampf(content_width+64.0,360.0,BONUS_RECT.size.x-24.0),80)
	var capsule = Rect2(center-capsule_size*.5,capsule_size)
	if not g.ui_art.skin(g,"button_cream",capsule,Color("ffd479")):
		g.box(capsule,Color("eabb5f"),28)
	var left = center.x-content_width*.5
	var icon = Vector2(left+18,center.y)
	g.draw_arc(icon,18,0,TAU,32,g.WHITE,2,true)
	g.symbol("check" if g.reward_earned else "play",icon,25,g.WHITE)
	g.fitted_text(label,Rect2(left+46,center.y-20,width+6,40),24,g.WHITE)

static func draw_backdrop(g):
	var bounds: Rect2 = g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()
	if g.buckets.size() == 5 and not g.pegs.is_empty():
		# Rendering the retained run supports any viewport without a stale bitmap.
		# Simulation is stopped by Result mode; visual elapsed is held too.
		g.draw_game()
	else:
		# Older and current pending-result saves contain rewards, not board poses.
		# Reopen safely on the area's empty tray without inventing surviving pegs.
		g.environment_art.draw_cover(g,"play_counter",bounds)
		g.draw_board_transform()
		g.food_art.draw_tray(g,Rect2(24,220,672,896))
		for i in range(5):
			g.food_art.draw(g,"cup_cream",Rect2(45+i*127.2,g.BUCKET_TOP,121,g.BUCKET_HEIGHT),Color.WHITE,false)
		g.draw_dispenser()
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(bounds,Color(0,0,0,.58))
	var panel: Rect2 = TRIAL_PANEL_RECT if g.trial_active else PANEL_RECT
	g.box(Rect2(panel.position+Vector2(0,12),panel.size),Color(0,0,0,.24),28)
	g.ui_panel(panel)

static func draw(g, comparison: Dictionary):
	var title = "Area complete!" if g.level_won and g.wave >= 12 else ("Tray cleared!" if g.level_won else "Batch finished")
	g.heading_centered(title,218,42)
	var identity = "%s · Tray %d" % [g.area_title(),g.wave]
	if g.level_won: identity = "%s · All 12 trays cleared" % g.area_title() if g.wave >= 12 else "%s · Next tray unlocked" % g.area_title()
	g.fitted_text(identity,Rect2(76,238,568,32),23,QUIET_INK,true)
	if not _draw_art(g,"dish",DISH_RECT): g.ui_art.draw(g,"coin",DISH_RECT)
	g.fitted_number(str(g.displayed_result_payout()),PAYOUT_RECT,94,GOLD_INK,true)
	var copy = content(g,comparison)
	g.fitted_text(copy.headline,CHANGE_RECT,40,copy.color,true)
	g.fitted_text(copy.title,TITLE_RECT,22,QUIET_INK,true)
	if not copy.detail.is_empty(): g.fitted_text(copy.detail,DETAIL_RECT,21,QUIET_INK,true)
	for index in range(STAT_RECTS.size()):
		var rect: Rect2 = STAT_RECTS[index]
		var icon = rect.position+Vector2(34,28)
		if index == 0: g.food_art.draw_centered(g,"cookie_normal",icon,Vector2(48,48))
		else: _draw_chain(g,icon)
		g.fitted_number(copy.values[index],Rect2(rect.position+Vector2(68,2),Vector2(170,45)),38,g.WHITE)
		g.fitted_text(copy.labels[index],Rect2(rect.position+Vector2(68,47),Vector2(170,28)),22,GREEN_INK)
		if not copy.previous[index].is_empty(): g.fitted_text(copy.previous[index],Rect2(rect.position+Vector2(68,78),Vector2(170,26)),20,QUIET_INK)
	g.button(COLLECT_RECT,"Collect",true)
	_draw_bonus(g)

static func draw_trial(g):
	g.heading_centered("Trial cleared!" if g.level_won else "Trial complete",330,42,g.TEAL)
	g.fitted_text(g.board_name(g.wave),Rect2(76,354,568,38),26,QUIET_INK,true)
	g.ui_art.draw(g,"timer",Rect2(326,410,68,68))
	g.fitted_number("%.1fs" % g.run_elapsed,Rect2(78,492,564,80),60,GOLD_INK,true)
	var pieces = "crystals" if g.area_id=="crystal" else ("wafers" if g.area_id=="gelato" else "cookies")
	var total: int = g.result_peg_total if g.result_peg_total>0 else g.board_peg_count(g.wave)
	g.fitted_text("%d / %d %s cleared" % [g.destroyed,total,pieces],Rect2(76,608,568,40),27,g.WHITE,true)
	g.fitted_text("Campaign wallet and upgrades are unchanged.",Rect2(76,676,568,34),22,QUIET_INK,true)
	g.fitted_text("Try a different recipe next time.",Rect2(76,716,568,32),22,QUIET_INK,true)
	g.button(COLLECT_RECT,"Back to trials",true)
