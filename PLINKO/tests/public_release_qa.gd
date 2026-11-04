extends Node
## Runs in both the editor and a real nondebug export, under a probed save root.
const Service = preload("res://scripts/monetization_service.gd")
const ResultUI = preload("res://scripts/result_comparison_ui.gd")
const AbilityAccess = preload("res://scripts/area_ability_access.gd")
const SAVE = "user://public_release_qa.json"
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var labels: Array[String] = []
	func _ready(): pass
	func button(_rect, label, _primary = false, _subtitle = "", _painter: CanvasItem = null): labels.append(label)
	func ui_panel(_rect: Rect2, _painter: CanvasItem = null): pass
	func heading_centered(_value, _y, _size = 40, _color = WHITE, _painter: CanvasItem = null): pass
	func fitted_text(value, _rect: Rect2, _size = 24, _color = WHITE, _align_center = false, _painter: CanvasItem = null): labels.append(value)
	func centered(value, _y, _size = 24, _color = WHITE, _painter: CanvasItem = null): labels.append(value)

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fake_store() -> Dictionary:
	return {"version":1,"attempts":4,"active_seconds":120.0,"last_counted_run":"old-preview-run","entitlements":{"remove_ads":true,"baker_toolkit":true},"store_owned":{"remove_ads":true,"baker_toolkit":true},"serial":13,"ads_available":true}

func fixture(area: String = "bakery", public_mode: bool = true):
	var g = Fixture.new()
	g.SAVE_FILE = SAVE; g.testing = true; g.sound_on = false
	g.set_active_area(area)
	g.monetization = Service.new(not public_mode)
	g.ability_access = AbilityAccess.new(not public_mode)
	g.current_level = 4; g.highest_unlocked = 12; g.bank = 1234.5
	g.levels = [2,2,1,1,1,1,2,2]; g.equipped = ["splitter","impact"]
	g.first_run_guide.completed = true; g.first_run_guide.active = false
	g.navigation_delay = 0; g.result_input_delay = 0
	return g

func service_gate():
	var service = Service.new(false)
	check(not service.simulation_enabled() and not service.ads_available,"Disabled commerce has no provider or inventory")
	check(not service.import_state(fake_store()),"Public commerce rejects simulated ownership import")
	check(not service.entitlements.remove_ads and not service.entitlements.baker_toolkit and not service.store_owned.remove_ads,"Imported preview entitlements cannot become public ownership")
	service.advance(180)
	check(not service.complete_attempt("public-run") and not service.eligible() and service.attempts == 0 and service.active_seconds == 0,"Public campaign does not stage fake ad cadence")
	for kind in ["interstitial","rewarded","purchase"]:
		check(service.request(kind,"baker_toolkit" if kind=="purchase" else "run").is_empty(),"Public service rejects "+kind+" requests")
	service.pending = {"id":"forged","kind":"purchase","context":"baker_toolkit"}
	check(service.resolve("forged","completed").is_empty() and not service.entitlements.baker_toolkit,"Direct fake callback cannot grant a public purchase")
	service.store_owned.baker_toolkit = true
	check(not service.restore_purchases() and not service.entitlements.baker_toolkit,"Fake store booleans cannot restore public ownership")
	check(service.export_state().is_empty(),"Public save exports no fake ownership or request state")
	var normal = Service.new()
	if Service.preview_tools_allowed():
		check(normal.import_state(fake_store()) and normal.entitlements.baker_toolkit,"Preview ownership remains compatible in a preview build")
		normal.reset_test_state()
		var request = normal.request("purchase","baker_toolkit")
		check(not request.is_empty() and normal.resolve(request.id,"completed").granted,"Preview purchase simulator still completes legitimately")
	else:
		check(not normal.simulation_enabled() and normal.request("purchase","baker_toolkit").is_empty(),"Actual public build cannot enable the simulator by using its default constructor")
		check(not Service.new(true).simulation_enabled(),"Even an explicit true constructor cannot bypass the public build capability")

func routes_and_payouts():
	for area in ["bakery","gelato","crystal"]:
		var g = fixture(area)
		check(not g.test_commerce_available(),area+" public fixture has no commerce capability")
		g.mode = "support"
		for hidden in ["monetization","monetization_tools","test_purchase","test_ad","bonus_confirm"]:
			g.mode = hidden
			check(g.mode == "support",area+" rejects entry into "+hidden)
		g.handle_press(Vector2(360,968))
		check(g.mode != "monetization" and not g.settings_menu_layout().actions.has("commerce") and g.monetization.pending.is_empty(),area+" no commerce target remains; its old position cannot enter the simulator")
		g.draw_support()
		check(not "Ads & purchases · test" in g.labels,area+" Settings omits fake commerce")
		g.labels.clear(); ResultUI._draw_bonus(g)
		check(g.labels.is_empty(),area+" Result does not draw a fake reward offer")
		g.start_shift(); g.shift_coins = 31.25; g.remaining = 0
		g.monetization.attempts = 4; g.monetization.active_seconds = 120
		g.monetization.entitlements = {"remove_ads":true,"baker_toolkit":true}
		g.monetization.store_owned = {"remove_ads":true,"baker_toolkit":true}
		g.reward_earned = true
		g.finish_shift(true)
		check(g.mode == "result" and g.monetization.pending.is_empty(),area+" completion never opens a simulated automatic ad")
		check(g.result_payout() == 31.25 and g.displayed_reward_bonus() == 0,area+" public payout ignores both fake Toolkit and reward flags")
		g.navigation_delay = 0; g.result_input_delay = 0
		g.handle_press(ResultUI.BONUS_RECT.get_center())
		g.begin_rewarded_ad(); g.begin_test_ad("rewarded"); g.begin_test_purchase("baker_toolkit")
		g.finish_test_request("completed"); g.restore_test_purchases(); g.stage_test_ad_break(); g.clear_test_entitlements_for_restore(); g.reset_test_monetization()
		g.monetization_ui.press(g.monetization_ui.AD_COMPLETE.get_center())
		check(g.mode == "result" and g.monetization.pending.is_empty() and g.bank == 1234.5,area+" direct test actions and hidden hitboxes cannot change mode or wallet")
		g.collect_reward(); g.collect_reward()
		check(g.mode == "home" and g.shift_claimed and g.bank == 1265.75,area+" ordinary base payout still collects exactly once")
		if not Service.preview_tools_allowed():
			g.mode = "support"; g.navigation_delay = 0; g.labels.clear(); g.draw_support()
			check(not g.developer_tools_available() and not g.open_developer_areas() and not g.set_developer_money(true),area+" actual public build rejects developer areas and free purchases")
			var actions = g.settings_menu_layout().actions
			check(not actions.has("performance") and not actions.has("developer") and not g.diagnostics_on and not g.labels.any(func(label): return label.begins_with("Performance display") or label == "Developer settings"),area+" actual public Settings exposes no diagnostic or developer input targets")
		g.free()

func saved_preview_migration():
	var g = fixture()
	g.start_shift(); g.shift_coins = 24.5; g.remaining = 0; g.finish_shift(false)
	check(g.save_game(),"Public fixture persists a valid pending result in isolated storage")
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.monetization_test = fake_store()
	data.pending_result.reward_earned = true
	var expected_bank = data.areas.bakery.bank
	var expected_levels = data.areas.bakery.levels.duplicate()
	var file = FileAccess.open(SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close(); g.free()
	g = fixture(); g.load_game()
	check(not g.profile_load_blocked and g.mode == "result" and not g.shift_claimed,"Preview-format profile and pending result remain readable in public mode")
	var levels_preserved = g.levels.size() == expected_levels.size()
	for i in range(expected_levels.size()): levels_preserved = levels_preserved and g.levels[i] == int(expected_levels[i])
	check(g.bank == expected_bank and levels_preserved and g.highest_unlocked == 12,"Public migration preserves earned wallet, upgrades and tray unlocks")
	check(not g.reward_earned and not g.monetization.entitlements.baker_toolkit and not g.monetization.store_owned.remove_ads,"Public load discards preview bonus and fake ownership without discarding progression")
	check(g.collection_payout() == 24.5,"Restored pending base earnings remain collectible without fake bonuses")
	g.collect_reward(); check(g.save_game(),"Public collection persists the normal claim")
	g.free(); g = fixture(); g.load_game()
	check(g.mode == "home" and g.bank == expected_bank+24.5 and g.shift_claimed,"Reopening cannot pay the migrated pending result twice")
	data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data.get("monetization_test",{}).is_empty() and not data.has("pending_result"),"Public checkpoint keeps no simulated entitlements or claimed result")
	g.free()

func signature_purchase_policy():
	for area in ["bakery","gelato","crystal"]:
		var g=fixture(area)
		g.mode="shop";g.current_level=1;g.highest_unlocked=1;g.bank=5000
		g.levels.fill(0);g.shift_claimed=true;g.run_id=""
		if area=="gelato": g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
		g.upgrade_map.reset_view_state();g.upgrade_map.twin_selected=true
		var map=g.upgrade_map
		check(map.twin_control_visible() and map.special_cost()>0,area+" public map retains its earned signature upgrade")
		check(map.card_rect().encloses(map.buy_rect()) and map.card_rect().encloses(map.paid_rect()) and map.paid_rect().position.y>map.buy_rect().end.y,area+" public card retains separate stacked coin and store targets")
		check(g.home_menu.target_at(Vector2(360,902))!="ability",area+" public Home has no area-purchase detour")
		var before=g.AreaCampaign.capture_local(g)
		map.press(map.paid_rect().get_center())
		check(g.mode=="shop" and not g.ability_ui.owned() and g.ability_access.pending.is_empty() and not g.ability_ui.card_confirming() and g.AreaCampaign.capture_local(g)==before,area+" unavailable public billing never starts a fake confirmation or grants access")
		check(g.ability_ui.message=="Store unavailable",area+" public card reports its unconfigured provider honestly")
		g.navigation_delay=0;map.press(map.buy_rect().get_center())
		check(not g.ability_ui.owned() and g.bank==5000,area+" public coin purchase retains tray and Power requirements")
		g.highest_unlocked=8;g.levels[1]=6 if area=="gelato" else 4
		if area=="gelato": g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
		g.navigation_delay=0;var cost=g.ability_ui.cost()
		map.press(map.buy_rect().get_center())
		check(g.mode=="shop" and g.ability_ui.owned() and g.ability_unlock_source=="earned" and g.bank==5000-cost,area+" public gameplay can buy the signature upgrade with earned coins")
		if area=="gelato": check(g.levels[1]==0 and g.power_reset_tier==6,"Public earned Dual Shot preserves its one-time Power reset")
		var earned=g.AreaCampaign.capture_local(g)
		map.twin_selected=true;map.selected=-1;g.navigation_delay=0
		map.press(map.paid_rect().get_center());map.press(map.buy_rect().get_center())
		check(g.AreaCampaign.capture_local(g)==earned and g.ability_access.pending.is_empty(),area+" owned public signature cannot be charged or reset twice")
		g.free()
	if not Service.preview_tools_allowed():
		var access=AbilityAccess.new(true)
		var fake={"version":1,"namespace":"area_ability_preview","serial":4,"preview_owned":{"bakery":true,"gelato":true,"crystal":true},"preview_receipts":{"bakery":true,"gelato":true,"crystal":true}}
		check(not access.preview_enabled() and not access.import_state(fake) and access.export_state().is_empty(),"Actual public constructor rejects all simulated area receipts even with explicit opt-in")
		for area in ["bakery","gelato","crystal"]:
			check(not access.has_early_access(area) and access.request_preview(area).is_empty() and access.request_purchase(area).is_empty(),area+" actual public access cannot synthesize a purchase")
			var g=fixture(area);g.ability_unlock_source="preview"
			if area=="bakery": g.bakery_jam_burst=true
			elif area=="gelato": g.twin_launchers=true
			else: g.crystal_second_prism=true
			check(not g.ability_ui.owned(),area+" saved preview activation flag alone never grants public ownership")
			g.ability_unlock_source="earned"
			check(g.ability_ui.owned(),area+" legitimate earned activation remains valid without a store")
			g.free()

func _ready():
	var release_expected = "--expect-release" in OS.get_cmdline_user_args()
	check(not OS.is_debug_build() and OS.has_feature("sugarfall_public") if release_expected else OS.is_debug_build(),"Harness runs with its declared native build profile")
	service_gate()
	routes_and_payouts()
	saved_preview_migration()
	signature_purchase_policy()
	print("PUBLIC_RELEASE_QA_RESULT passed=%d failed=%d debug=%s public=%s" % [passed,failures.size(),OS.is_debug_build(),OS.has_feature("sugarfall_public")])
	get_tree().quit(0 if failures.is_empty() else 1)
