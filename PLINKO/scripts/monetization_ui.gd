extends RefCounted
## Local-only commerce screens. Provider outcomes are resolved by main, never by drawing.
var g

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

func draw():
	if not g.test_commerce_available(): return
	match g.mode:
		"monetization": draw_shop()
		"monetization_tools": draw_tools()
		"test_ad": draw_ad()
		"test_purchase": draw_purchase()

func press(p: Vector2):
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
	return "Baker's toolkit" if product=="baker_toolkit" else "Remove automatic ads"

func draw_shop():
	header("Test shop")
	product_card("remove_ads",200,"donut","Skip automatic ad breaks.","Optional reward ads stay available.",REMOVE_ADS)
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
