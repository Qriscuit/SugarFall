extends RefCounted
## One explicit offer per area. Earned progression and store access stay separate.
const HOME_RECT = Rect2(64,858,592,88)
const EARN_RECT = Rect2(80,538,560,88)
const EARLY_RECT = Rect2(80,654,560,88)
const RESTORE_RECT = Rect2(80,812,560,72)
const BACK_RECT = Rect2(80,944,560,88)
const PANEL_RECT = Rect2(48,208,624,864)
var g
var return_page = "home"
var stage = "details"
var message = ""
var touches: Dictionary = {}
var primary = -1
var down = Vector2.ZERO
var action = ""
var armed = false
var billing = preload("res://scripts/area_play_billing.gd").new()

func _init(game): g=game

func setup_store():
	g.ability_access.bind_provider(billing)
	if not billing.changed.is_connected(_store_changed): billing.changed.connect(_store_changed)
	if not billing.purchase_result.is_connected(_store_result): billing.purchase_result.connect(_store_result)
	billing.start(g)

func _store_changed(): g.queue_redraw()

func _store_result(product: String, outcome: String):
	# Verified purchases can finish while backgrounded. Apply at a safe menu or
	# on the next run, never change an airborne run's ability or Power midway.
	if product!=g.ability_access.CATALOG[g.area_id].product_id: return
	if outcome=="completed" and g.mode in ["home","shop","ability_offer"]:
		var was_owned = owned()
		if restore_activation():
			message="Unlocked"; stage="details"
			if not was_owned and owned(): _purchase_feedback()
	elif outcome=="pending": message="Purchase pending"
	elif outcome in ["failed","cancelled","unavailable"]:
		message="Purchase cancelled" if outcome=="cancelled" else "Store unavailable"
		stage="details"
	g.queue_redraw()

func owned() -> bool:
	match g.area_id:
		"bakery": return g.bakery_ability.owned()
		"gelato": return g.gelato_launcher.is_twin()
		"crystal": return g.crystal_launcher.owned()
	return false

func controller():
	return g.bakery_ability if g.area_id=="bakery" else (g.gelato_launcher if g.area_id=="gelato" else g.crystal_launcher)

func _purchase_feedback():
	g.feedback("twin_transform" if g.area_id=="gelato" else "ability_purchase")

func unlocked() -> bool: return controller().unlocked()
func cost() -> int: return controller().cost()
func title() -> String: return g.ability_access.CATALOG[g.area_id].title

func effects() -> Array[String]:
	match g.area_id:
		"bakery": return ["Every fifth doughnut bursts with jam.","Splash nearby pegs on its first hit."]
		"gelato": return ["Two slower launchers. Power starts over.","Power costs more and grows stronger."]
	return ["Two Prisms can appear each run.","Tap a Prism to double the balls in play."]

func gate_text() -> String:
	var power = 6 if g.area_id=="gelato" else 4
	return "Tray 8 · Power %d" % power

func home_visible() -> bool:
	return not g.trial_active and not owned()

func open(from_page: String):
	if g.trial_active or (not g.run_id.is_empty() and not g.shift_claimed): return
	return_page=from_page if from_page in ["home","shop"] else "home"
	stage="details"; message=""; cancel_gestures()
	if g.ability_early_access(g.area_id) and not restore_activation(): message="Could not restore. Try again."
	g.mode="ability_offer"

func close():
	g.ability_access.cancel_pending_preview()
	stage="details"; cancel_gestures()
	g.mode=return_page

func cancel_gestures():
	touches.clear(); primary=-1; armed=false; action=""

func action_at(p: Vector2) -> String:
	if BACK_RECT.has_point(p): return "back"
	if EARLY_RECT.has_point(p): return "confirm" if stage=="confirm" else "early"
	if RESTORE_RECT.has_point(p): return "cancel" if stage=="confirm" else "restore"
	if EARN_RECT.has_point(p) and stage=="details": return "earn"
	return ""

func handle_input(event) -> bool:
	if event is InputEventKey: return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return false
	var p = g.to_local(event.position)
	if event is InputEventScreenDrag:
		if event.index==primary and p.distance_to(down)>12: armed=false
		return true
	if event.pressed and not event.canceled:
		if touches.is_empty():
			primary=event.index; down=p; action=action_at(p)
			armed=g.navigation_delay<=0 and not action.is_empty()
		else: armed=false
		touches[event.index]=true
		return true
	if not touches.has(event.index): return true
	var activate=armed and not event.canceled and event.index==primary and touches.size()==1 and p.distance_to(down)<=12 and action_at(p)==action and g.navigation_delay<=0
	touches.erase(event.index)
	armed=false
	if touches.is_empty(): cancel_gestures()
	if activate: g.handle_press(p)
	return true

func _activate(source: String) -> bool:
	return controller().activate(source)

func persist_activation() -> bool:
	var before=g.AreaCampaign.capture_local(g)
	var source="store" if billing.has_entitlement(g.ability_access.CATALOG[g.area_id].product_id) else "preview"
	if not _activate(source): return false
	if not g.testing and not g.save_game():
		g.AreaCampaign.apply_local(g,before)
		return false
	return true

func restore_activation() -> bool:
	if owned() or not g.ability_early_access(g.area_id): return true
	return persist_activation()

func persist_restore() -> bool:
	# Restoring another area's receipt does not require owning the current one.
	if g.ability_early_access(g.area_id) and not owned(): return persist_activation()
	return g.testing or g.save_game()

func press(p: Vector2):
	match action_at(p):
		"back": close()
		"cancel":
			g.ability_access.cancel_pending_preview(); stage="details"; message=""
			g.feedback("ui_back")
		"earn":
			if g.ability_early_access(g.area_id):
				message="Restored" if restore_activation() else "Could not save. Try again."
				g.feedback("ui_confirm" if message=="Restored" else "ui_error")
				return
			if controller().buy():
				message="Unlocked"; g.note=""; g.note_time=0
			else: g.feedback("ui_error")
		"early":
			var offer=g.ability_access.offer(g.area_id,owned())
			if offer.owned: return
			if not offer.available:
				message="Store unavailable"; g.feedback("ui_error"); return
			var request=g.ability_access.request_purchase(g.area_id,owned())
			if request.is_empty(): message="Use Restore purchases"; return
			stage="confirm" if offer.preview else "pending"
			message=""
			g.feedback("ui_tap")
		"confirm":
			if g.ability_access.pending.is_empty(): return
			var result=g.ability_access.resolve_preview(g.ability_access.pending.id,"completed",persist_activation)
			if result.get("granted",false):
				stage="details"; message="Unlocked"
				_purchase_feedback()
			elif result.get("outcome","")=="save_failed":
				message="Could not save. Try again."; g.feedback("ui_error")
		"restore":
			if g.ability_access.preview_enabled():
				var receipts: Dictionary=g.ability_access.export_state().preview_receipts
				g.ability_access.restore_preview(persist_restore)
				var restored=restore_activation()
				var any_receipt=false
				for area in receipts:
					if receipts[area]:
						any_receipt=true
						restored=restored and g.ability_early_access(area)
				message=("Purchases restored" if restored else "Could not restore. Try again.") if any_receipt else "No purchases to restore"
			else:
				var store=billing.offer(g.ability_access.CATALOG[g.area_id].product_id)
				if not str(store.get("error","")).is_empty(): message="Store unavailable"
				else: g.ability_access.restore(); message="Restore requested"
			g.feedback("ui_error" if message.begins_with("Could not") or message=="Store unavailable" else "ui_confirm")
	g.navigation_delay=.25
	g.queue_redraw()

func draw_icon(canvas: CanvasItem, rect: Rect2, tint: Color = Color.WHITE):
	if g.area_id=="bakery":
		if not g.bakery_ability.draw_icon(canvas,rect,tint): g.food_art.draw(canvas,"donut",rect,tint)
	elif g.area_id=="crystal": g.food_art.draw(canvas,"multiply_pickup",rect,tint)
	else:
		var size=Vector2(rect.size.x*.56,rect.size.y*.9)
		g.food_art.draw(canvas,"hopper",Rect2(rect.position+Vector2(0,rect.size.y*.08),size),tint)
		g.food_art.draw(canvas,"hopper",Rect2(rect.position+Vector2(rect.size.x*.44,0),size),tint)

func draw_home_offer():
	if not home_visible(): return
	g.button(HOME_RECT,"")
	draw_icon(g,Rect2(HOME_RECT.position+Vector2(18,13),Vector2(60,60)))
	var offer=g.ability_access.offer(g.area_id,owned())
	var restored=g.ability_early_access(g.area_id)
	g.fitted_text(title()+" · "+("Restore" if restored else offer.price_label),Rect2(154,868,474,35),26,g.WHITE,true)
	g.fitted_text("Purchased" if restored else "Earn from tray 8",Rect2(154,904,474,27),19,g.MUTED,true)

func draw():
	if not g.ui_art.menu_frame(g,PANEL_RECT): g.ui_panel(PANEL_RECT)
	draw_icon(g,Rect2(320,250,80,80))
	g.heading_centered("Test unlock" if stage=="confirm" else title(),384,40)
	var lines=effects()
	for i in range(lines.size()): g.fitted_text(lines[i],Rect2(80,408+i*34,560,32),23,g.MUTED,true)
	var offer=g.ability_access.offer(g.area_id,owned())
	if stage=="confirm":
		g.centered(title()+" · "+offer.price_label,526,28)
		g.centered("Test purchase · no charge",576,22,g.MUTED)
		g.button(EARLY_RECT,"Confirm test unlock",true)
		g.button(RESTORE_RECT,"Cancel")
	else:
		g.centered("Unlocked" if owned() else gate_text(),512,23,g.TEAL if owned() else g.MUTED)
		g.button(EARN_RECT,"Owned" if owned() else "Unlock · %s coins" % g.credits_text(cost()),not owned() and unlocked() and g.can_afford(cost()))
		g.button(EARLY_RECT,"Owned" if owned() else "Unlock early · "+offer.price_label,offer.available)
		g.centered("Test purchase · no charge" if offer.preview else ("" if offer.price_is_live else "Store unavailable"),778,21,g.MUTED)
		g.button(RESTORE_RECT,"Restore purchases")
	if not message.is_empty(): g.fitted_text(message,Rect2(80,896,560,30),21,g.TEAL,true)
	g.button(BACK_RECT,"Back",true)
