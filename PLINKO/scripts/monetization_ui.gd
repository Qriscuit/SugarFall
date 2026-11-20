extends RefCounted
## Native purchase controls and separate local simulation screens.
var g
var purchase_message = ""

const NATIVE_BUY = Rect2(80,570,560,88)
const NATIVE_RESTORE = Rect2(80,686,560,88)
const NATIVE_BACK = Rect2(80,866,560,88)
const REMOVE_ADS_NAME = "Remove automatic ads"
const REMOVE_ADS_DESCRIPTION = "Skip automatic ad breaks."
const REWARDED_AD_DESCRIPTION = "Optional reward ads stay available."
const REMOVE_ADS = Rect2(160,330,480,86)
const TOOLKIT = Rect2(160,588,480,86)
const RESTORE = Rect2(48,740,624,96)
const TOOLS = Rect2(48,846,624,96)
const SHOP_BACK = Rect2(48,952,624,96)
const AVAILABILITY = Rect2(48,420,624,96)
const STAGE_BREAK = Rect2(48,530,624,96)
const CLEAR_ENTITLEMENTS = Rect2(48,640,624,96)
const RESET_TEST = Rect2(48,750,624,96)
const TOOLS_BACK = Rect2(48,890,624,96)
const AD_COMPLETE = Rect2(60,668,600,96)
const AD_CANCEL = Rect2(60,780,600,96)
const AD_UNAVAILABLE = Rect2(60,892,600,96)
const PURCHASE_APPROVE = Rect2(60,582,600,86)
const PURCHASE_PENDING = Rect2(60,682,600,86)
const PURCHASE_FAIL = Rect2(60,782,600,86)
const PURCHASE_CANCEL = Rect2(60,882,600,86)

func _init(game):
	g=game

func bind_billing():
	var billing = g.ability_ui.billing
	if not billing.purchase_result.is_connected(_on_purchase_result):
		billing.purchase_result.connect(_on_purchase_result)
	if not billing.restore_finished.is_connected(_on_restore_finished):
		billing.restore_finished.connect(_on_restore_finished)

func open_purchases():
	purchase_message=""
	g.mode="purchases"

func _on_purchase_result(product: String, outcome: String):
	if g.mode!="purchases" or product!=g.ability_ui.billing.REMOVE_ADS_PRODUCT: return
	match outcome:
		"cancelled": purchase_message="Purchase cancelled."
		"failed", "unavailable": purchase_message="Purchase could not start or finish."
		"verification_failed": purchase_message="Purchase verification failed. Tap Restore purchases."
		"revoked": purchase_message="Purchase is no longer active."
		_: purchase_message=""
	g.queue_redraw()

func _on_restore_finished(success: bool, _message: String):
	if g.mode!="purchases": return
	var billing = g.ability_ui.billing
	purchase_message="Purchases checked." if success and not billing.has_entitlement(billing.REMOVE_ADS_PRODUCT) else ""
	g.queue_redraw()

func press_purchases(p: Vector2):
	var billing = g.ability_ui.billing
	var product: String = billing.REMOVE_ADS_PRODUCT
	if NATIVE_BACK.has_point(p):
		g.mode="support"
	elif NATIVE_RESTORE.has_point(p) and billing.can_restore() and not billing.restore_status().restoring:
		purchase_message=""
		billing.restore()
	elif NATIVE_BUY.has_point(p) and billing.offer(product).available:
		purchase_message=""
		billing.purchase(product)

func draw_purchases():
	var billing = g.ability_ui.billing
	var product: String = billing.REMOVE_ADS_PRODUCT
	var owned: bool = billing.has_entitlement(product)
	var offer: Dictionary = billing.offer(product)
	var restoring: bool = billing.restore_status().restoring
	var panel = Rect2(48,296,624,692)
	if not g.ui_art.menu_frame(g,panel): g.ui_panel(panel)
	g.heading_centered("Purchases",380,42)
	g.heading_centered(REMOVE_ADS_NAME,457,33)
	g.centered(REMOVE_ADS_DESCRIPTION,500,24,g.MUTED)
	g.centered(REWARDED_AD_DESCRIPTION,537,23,g.MUTED)
	var label = "Store unavailable"
	if owned: label="Purchased"
	elif offer.pending: label="Purchase in progress"
	elif restoring: label="Checking purchases…"
	elif billing.needs_restore(product): label="Restore to check purchase"
	elif offer.available: label="Buy · "+offer.price_label
	g.button(NATIVE_BUY,label,offer.available)
	g.button(NATIVE_RESTORE,"Restore purchases" if billing.can_restore() else "Restore unavailable")
	var detail: String = billing.error if restoring or billing.restore_status().phase=="failed" else purchase_message
	if detail.is_empty(): detail=offer.error
	if not detail.is_empty():
		wrapped_text(detail,Rect2(80,786,560,70),22,g.MUTED)
	g.button(NATIVE_BACK,"Back",true)

func draw():
	if g.mode=="purchases":
		if g.native_purchases_available(): draw_purchases()
		return
	if not g.test_commerce_available(): return
	match g.mode:
		"monetization": draw_shop()
		"monetization_tools": draw_tools()
		"test_ad": draw_ad()
		"test_purchase": draw_purchase()

func press(p: Vector2):
	if g.mode=="purchases":
		if g.native_purchases_available(): press_purchases(p)
		return
	if not g.test_commerce_available(): return
	match g.mode:
		"monetization":
			if REMOVE_ADS.has_point(p) and not g.monetization.entitlements.get("remove_ads",false):
				if g.monetization.store_owned.get("remove_ads",false): g.restore_test_purchases()
				else: g.begin_test_purchase("remove_ads")
			elif TOOLKIT.has_point(p) and not g.monetization.entitlements.get("baker_toolkit",false):
				if g.monetization.store_owned.get("baker_toolkit",false): g.restore_test_purchases()
				else: g.begin_test_purchase("baker_toolkit")
			elif RESTORE.has_point(p): g.restore_test_purchases()
			elif TOOLS.has_point(p):
				g.mode="monetization_tools"
				g.commerce_message=""
			elif SHOP_BACK.has_point(p): g.mode="support"
		"monetization_tools":
			if AVAILABILITY.has_point(p):
				g.monetization.ads_available=not g.monetization.ads_available
				g.persist_monetization()
				g.commerce_message="Test ads are available." if g.monetization.ads_available else "No test ads are available. Gameplay continues."
			elif STAGE_BREAK.has_point(p): g.stage_test_ad_break()
			elif CLEAR_ENTITLEMENTS.has_point(p): g.clear_test_entitlements_for_restore()
			elif RESET_TEST.has_point(p): g.reset_test_monetization()
			elif TOOLS_BACK.has_point(p):
				g.mode="monetization"
				g.commerce_message=""
		"test_ad":
			if AD_COMPLETE.has_point(p): g.finish_test_request("completed")
			elif AD_CANCEL.has_point(p): g.finish_test_request("cancelled")
			elif AD_UNAVAILABLE.has_point(p): g.finish_test_request("unavailable")
		"test_purchase":
			if PURCHASE_APPROVE.has_point(p): g.finish_test_request("completed")
			elif PURCHASE_PENDING.has_point(p): g.finish_test_request("pending")
			elif PURCHASE_FAIL.has_point(p): g.finish_test_request("failed")
			elif PURCHASE_CANCEL.has_point(p): g.finish_test_request("cancelled")
	g.queue_redraw()

func header(title: String):
	g.heading(title,Vector2(48,105),46)
	g.fitted_text("Local simulation · no money charged",Rect2(48,133,624,36),23,g.TEAL)

func product_name(product: String) -> String:
	return "Baker's toolkit" if product=="baker_toolkit" else REMOVE_ADS_NAME

func draw_shop():
	header("Test shop")
	product_card("remove_ads",200,"donut",REMOVE_ADS_DESCRIPTION,REWARDED_AD_DESCRIPTION,REMOVE_ADS)
	product_card("baker_toolkit",458,"cup_gold","+20% normal campaign credits.","A permanent benefit in this test.",TOOLKIT)
	g.button(RESTORE,"Restore test purchases")
	g.button(TOOLS,"Test controls")
	g.button(SHOP_BACK,"Back")
	status(Rect2(48,1074,624,96))

func product_card(product: String, y: float, art: String, line_one: String, line_two: String, action: Rect2):
	var owned=bool(g.monetization.entitlements.get(product,false))
	var restorable=bool(g.monetization.store_owned.get(product,false))
	g.ui_panel(Rect2(48,y,624,242))
	g.food_art.draw_centered(g,art,Vector2(105,y+101),Vector2(73,86))
	g.heading(product_name(product),Vector2(160,y+48),31)
	g.fitted_text(line_one,Rect2(160,y+63,480,29),23,g.MUTED)
	g.fitted_text(line_two,Rect2(160,y+94,480,29),21,g.MUTED)
	g.button(action,"Owned in this test" if owned else ("Restore test purchase" if restorable else "Test purchase"),not owned)
	if owned: g.symbol("check",Vector2(105,y+186),27,g.TEAL)

func draw_tools():
	header("Test controls")
	g.ui_panel(Rect2(48,200,624,188))
	g.fitted_number("%d / 4" % g.monetization.attempts,Rect2(78,224,250,58),39,g.TEAL,true)
	g.fitted_number("%ds / 120s" % int(g.monetization.active_seconds),Rect2(360,224,282,58),35,g.TEAL,true)
	g.fitted_text("Completed attempts",Rect2(72,291,266,32),21,g.MUTED,true)
	g.fitted_text("Active play",Rect2(360,291,282,32),21,g.MUTED,true)
	g.fitted_text("Both checks must pass before an automatic ad.",Rect2(72,338,576,30),20,g.MUTED,true)
	g.button(AVAILABILITY,"Test ads  ·  "+("Available" if g.monetization.ads_available else "Unavailable"))
	g.button(STAGE_BREAK,"Stage next ad break",true,"Make the next completed attempt eligible")
	g.button(CLEAR_ENTITLEMENTS,"Clear local benefits",false,"Keep test purchases for a restore check")
	g.button(RESET_TEST,"Reset monetization test",false,"Clear ad counters and test purchases")
	g.button(TOOLS_BACK,"Back")
	g.fitted_text("These controls do not reset your game progress.",Rect2(48,1003,624,34),21,g.MUTED,true)
	status(Rect2(48,1058,624,112))

func draw_ad():
	var rewarded=str(g.monetization.pending.get("kind",""))=="rewarded"
	header("Test reward ad" if rewarded else "Test ad break")
	g.ui_panel(Rect2(48,212,624,396))
	g.food_art.draw_centered(g,"donut",Vector2(360,314),Vector2(128,128))
	g.heading_centered("An extra helping" if rewarded else "A little break",437,40)
	g.fitted_text("Complete this test to add +50% to this result." if rewarded else "Four attempts and two minutes of active play.",Rect2(78,463,564,40),23,g.MUTED,true)
	g.fitted_text("Cancel or unavailable gives no reward." if rewarded else "Your result is safe while the ad is shown.",Rect2(78,507,564,40),22,g.MUTED,true)
	g.fitted_text("Choose how this test ad finishes.",Rect2(78,555,564,30),20,g.TEAL,true)
	g.button(AD_COMPLETE,"Complete test ad",true)
	g.button(AD_CANCEL,"Cancel")
	g.button(AD_UNAVAILABLE,"Ad unavailable")
	status(Rect2(48,1048,624,122))

func draw_purchase():
	var product=str(g.monetization.pending.get("context",""))
	header("Test checkout")
	g.ui_panel(Rect2(48,212,624,324))
	g.food_art.draw_centered(g,"cup_gold" if product=="baker_toolkit" else "donut",Vector2(360,305),Vector2(92,112))
	g.heading_centered(product_name(product),419,38)
	g.fitted_text("Choose a test payment outcome.",Rect2(78,446,564,34),24,g.MUTED,true)
	g.fitted_text("Pending payments grant no benefit.",Rect2(78,484,564,30),21,g.TEAL,true)
	g.button(PURCHASE_APPROVE,"Approve test purchase",true)
	g.button(PURCHASE_PENDING,"Payment pending")
	g.button(PURCHASE_FAIL,"Fail purchase")
	g.button(PURCHASE_CANCEL,"Cancel")
	status(Rect2(48,1010,624,160))

func status(rect: Rect2):
	if g.commerce_message.is_empty(): return
	g.ui_panel(rect)
	wrapped_text(g.commerce_message,rect.grow(-22),22,g.TEAL)

func wrapped_text(value: String, rect: Rect2, size: int, color: Color):
	var lines: Array[String]=[]
	var line=""
	for word in value.split(" "):
		var candidate=word if line.is_empty() else line+" "+word
		if not line.is_empty() and g.font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x:
			lines.append(line)
			line=word
		else: line=candidate
	if not line.is_empty(): lines.append(line)
	var line_height=g.font.get_height(size)+3
	var y=rect.position.y+maxf(0,(rect.size.y-lines.size()*line_height)*.5)+g.font.get_ascent(size)
	for text in lines:
		g.text_at(text,Vector2(rect.position.x,y),size,color)
		y+=line_height
