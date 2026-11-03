extends Node2D
## Original prototype with a local monetization simulator. No external SDK or network.
const RunSnapshot = preload("res://scripts/run_snapshot.gd")
const AreaCampaign = preload("res://scripts/area_campaign.gd")
const UpgradeGraph = preload("res://scripts/upgrade_graph.gd")
const GelatoUpgradeGraph = preload("res://scripts/gelato_upgrade_graph.gd")
const CrystalUpgradeGraph = preload("res://scripts/crystal_upgrade_graph.gd")
const MonetizationService = preload("res://scripts/monetization_service.gd")
const CoinDisplay = preload("res://scripts/coin_display.gd")
const CombatBalance = preload("res://scripts/combat_balance.gd")
const FlowRules = preload("res://scripts/flow_rules.gd")
var run_rules_revision = FlowRules.CURRENT_REVISION
signal peg_damaged(position: Vector2, actual_damage: float, impact_first_hit: bool)
signal audio_feedback_requested(event_name: String, event_area: String)
const WIDTH = 720.0
const HEIGHT = 1280.0
const BOARD_SCALE = 1.05
const BOARD_CENTER = Vector2(360,668)
const BUCKET_TOP = 1036.0
const BUCKET_HEIGHT = 203.0
const BUCKET_CATCH_Y = BUCKET_TOP + 16.0
const SAVE_PATH = "user://sugarfall_save.json"
const PROFILE_VERSION = 5
var SAVE_FILE = SAVE_PATH
const AREA_SURFACES = {
	"bakery": {
		"background": Color("dde8d9"), "secondary": Color("d0dfcd"), "panel": Color("f5f8f0"),
		"route_shadow": Color("a3b89e"), "route_outer": Color("6f8b72"), "route_inner": Color("b7cbb0"),
		"route_base": Color("d8e5d2"), "route_center": Color("edf3e8"),
		"tray_rail": Color("7c9e84"), "overlay": Color("27362b")
	},
	"crystal": {
		"background": Color("e2f0f2"), "secondary": Color("d0e5eb"), "panel": Color("f5fbfa"),
		"route_shadow": Color("9ebdc9"), "route_outer": Color("567e91"), "route_inner": Color("b9dbe1"),
		"route_base": Color("dbecef"), "route_center": Color("f0f8f7"),
		"tray_rail": Color("80a8b6"), "overlay": Color("243d4b")
	},
	"gelato": {
		"background": Color("e6e1f1"), "secondary": Color("d8d0e8"), "panel": Color("f7f4fb"),
		"route_shadow": Color("b2a5c5"), "route_outer": Color("8a769e"), "route_inner": Color("c4b7d8"),
		"route_base": Color("e0d7ed"), "route_center": Color("f0ebf8"),
		"tray_rail": Color("a696ba"), "overlay": Color("322b42")
	}
}
const WHITE = Color("443b32")
const MUTED = Color("716757")
const TEAL = Color("3d8673")
const GOLD = Color("ad711b")
const PINK = Color("d87388")
const BLUE = Color("729aca")
const UPGRADE_NAMES = ["FEEDER", "CORE POWER", "SPRING ALLOY", "RICOCHET", "SPLITTER", "IMPACT", "GOLD BINS", "SHIFT CLOCK"]
const UPGRADE_DESC = ["Drop food faster", "Hit pegs harder", "Keep bounces lively", "Extra bounces when equipped", "Split on impact when equipped", "Hit hard when equipped", "Earn more from gold cups", "Keep runs going longer"]
const BASE_COSTS = [30,40,30,50,60,70,35,40]
const BASE_SECONDS = 10.0
const CLOCK_STEP = 0.5
const BONUS_TIME_CAP = 3.0
const MAX_LEVELS = [10,10,6,6,6,6,8,10]
var tuning = {"core_step":0.5,"core_tier_gains":[0.5,0.5,0.5,0.35,0.35,0.35,0.25,0.25,0.25,0.25],"core_cost_growth":1.85,"upgrade_cost_scale":1.25,"upgrade_cost_growth":1.75,"area_unlock_cost":1000,"clock_base_cost":40,"peg_base":4,"peg_level_step":1.0,"peg_level_offset":0,"combo_credit_cap":5,"clear_base":100,"clear_per_level":25,"productive_bins_only":false,"min_rebound_speed":0.0,"combat_reward_revision":1,"peg_damage_coin_budget":6,"armored_damage_coin_budget":9,"impact_damage_multiplier":4.0,"impact_armored_multiplier":6.0}
var levels: Array = [0,0,0,0,0,0,0,0]
var twin_launchers = false
var bakery_jam_burst = false
var bakery_run: Dictionary = {}
var ability_unlock_source = "earned"
var bakery_ability
var ability_access = preload("res://scripts/area_ability_access.gd").new()
var ability_ui
var run_ability_active = false
var run_ability_pinned = false
var crystal_second_prism = false
var crystal_run: Dictionary = {}
var power_reset_tier = 0
var gelato_shop_revision = AreaCampaign.GELATO_SHOP_REVISION
var gelato_owned_nodes: Array = []
var gelato_reset_power_nodes: Array = []
var _gelato_shop_validation_cached = false
var _gelato_shop_validation_hash = 0
var _gelato_shop_validation_valid = false
var bakery_tuning: Dictionary = {}
var bank = 0.0
var developer_free_purchases: Dictionary = {}
var best_wave = 1
var current_level = 1
var highest_unlocked = 1
var chapter_complete = false
var trial_active=false
var trial_snapshot={}
var trial_records={}
var run_elapsed=0.0
var result_input_delay=0.0
var result_peg_total=0
var module_vouchers = 0
var module_milestones: Array = []
var equipped: Array = []
var board_data: Array = []
var area_id = "bakery"
var area_records = {"bakery": AreaCampaign.default_record()}
var area_entries: Array = []
var area_transaction_pending = false
var profile_load_blocked = false
var level_won = false
## A cleared board keeps simulating food until the final cup catch has settled.
var clear_draining = false
var catch_settle_remaining = 0.0
var settling_bucket = -1
var pickups: Array = []
var pickup_clock = 4.0
var time_bonus = 0.0
var total_shifts = 0
var mode = "home":
	set(value):
		if value == mode: return
		if value in ["monetization","monetization_tools","test_ad","test_purchase","bonus_confirm"] and monetization != null and not test_commerce_available(): return
		if page_transition != null: page_transition.begin(mode,value)
		if pause_transition != null: pause_transition.begin(mode,value)
		var previous = mode
		mode = value
		_audio_mode_changed(previous,value)
var return_mode = "home"
var page = 0
var pegs: Array = []
var balls: Array = []
var particles: Array = []
var floats: Array = []
var buckets: Array = []
var rng = RandomNumberGenerator.new()
var font: Font = preload("res://data/fonts/Nunito-Semibold.tres")
var display_font: Font = preload("res://data/fonts/Fraunces-Display.tres")
var number_font: Font = preload("res://data/fonts/Nunito-Bold.tres")
var ui_art = preload("res://scripts/ui_art.gd").new()
var elapsed = 0.0
var remaining = BASE_SECONDS
var spawn_clock = 0.0
var aim_x = 360.0
var aim_y = 515.0
var special_stats = {}
var type_drops = {}
## Legacy checkpoint fields: retained for older saves, never gameplay controls.
var force_special = ""
var queued_special = ""
var module_cooldowns = {"ricochet":0.0,"splitter":0.0,"impact":0.0}
var cosmetic = 0
var shift_coins = 0.0
var destroyed = 0
var wave = 1
var pulse_charge = 0.0
var pulse_flash = 0.0
var pulse_origin = Vector2.ZERO
var combo = 0
var combo_timer = 0.0
var max_combo = 0
var wave_flash = 0.0
var note = ""
var note_time = 0.0
var total_spawned = 0
var shift_claimed = false
var testing = false
## Boot-only holds are intentionally absent from every save/checkpoint field.
var startup_blocked = false
var profile_initialization_complete = true
var screenshot_timer = -1.0
var game_audio
var audio_application_paused = false
var audio_focus_lost = false
var audio_restoring = false
var sound_on = true:
	set(value):
		sound_on = value
		if game_audio != null: game_audio.set_enabled(value)
var reduced_motion = false
var run_id = ""
var run_area_id = "bakery"
var run_serial = 0
var last_claimed_run_id = ""
var resumed_run = false
var checkpoint_clock = 5.0
var snapshot_rejection = ""
var navigation_delay = 0.0
var collision_source = []
var collision_rows = {}
var upgrade_map
var home_menu
var level_map
var run_transition
var page_transition
var pause_transition
var gelato_launcher
var crystal_launcher
var first_run_guide
var progress_reset_ui
var developer_area_ui
var environment_art = preload("res://scripts/environment_art.gd").new()
var impact_feedback = preload("res://scripts/impact_feedback.gd").new()
var countdown_feedback = preload("res://scripts/countdown_feedback.gd").new()
var run_coin_feedback = preload("res://scripts/coin_feedback.gd").new()
var bank_coin_feedback = preload("res://scripts/coin_feedback.gd").new()
var result_history = preload("res://scripts/run_history.gd").new()
var monetization = MonetizationService.new()
var monetization_ui
var reward_earned = false
var commerce_message = "Local simulation. No money is charged."
var commerce_profile = ""
var commerce_return_mode = "result"

func _init():
	peg_damaged.connect(impact_feedback.show_damage)
	upgrade_map=preload("res://scripts/upgrade_map.gd").new(self)
	home_menu=preload("res://scripts/home_menu.gd").new(self)
	level_map=preload("res://scripts/level_map.gd").new(self)
	run_transition=preload("res://scripts/run_transition.gd").new(self)
	page_transition=preload("res://scripts/page_transition.gd").new(self)
	pause_transition=preload("res://scripts/pause_transition.gd").new(self)
	gelato_launcher=preload("res://scripts/gelato_launcher.gd").new(self)
	crystal_launcher=preload("res://scripts/crystal_launcher.gd").new(self)
	bakery_ability=preload("res://scripts/bakery_ability.gd").new(self)
	ability_ui=preload("res://scripts/area_ability_ui.gd").new(self)
	monetization_ui=preload("res://scripts/monetization_ui.gd").new(self)
	first_run_guide=preload("res://scripts/first_run_guide.gd").new(self)
	progress_reset_ui=preload("res://scripts/progress_reset_ui.gd").new(self)
	developer_area_ui=preload("res://scripts/developer_area_ui.gd").new(self)
	if FileAccess.file_exists("res://data/economy.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
		if parsed is Dictionary:
			for key in tuning:
				if key in parsed: tuning[key]=parsed[key]
	bakery_tuning=tuning.duplicate(true)

func load_area_tuning(id: String):
	tuning=bakery_tuning.duplicate(true)
	var path=AreaCampaign.ECONOMY_PATHS.get(id,"")
	if not path.is_empty() and FileAccess.file_exists(path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key in parsed: tuning[key]=parsed[key]

func _ready():
	profile_initialization_complete = false
	Engine.max_fps=60 # Avoid unnecessary 90/120 Hz rendering; physics remains60 Hz.
	load_presentation()
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()
	rng.randomize()
	food_art.load_assets()
	set_active_area("bakery")
	testing = "--self-test" in OS.get_cmdline_user_args()
	if not testing:
		load_game()
	profile_initialization_complete = true
	ability_ui.setup_store()
	for kind in ["normal","prism","clock","armored"]:
		for suffix in ["","_flash"]: peg_textures[kind+suffix]=load("res://data/art/"+kind+suffix+".svg")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	setup_audio()
	if testing:
		self_test()
	elif "--capture" in OS.get_cmdline_user_args():
		levels = [2,2,2,3,3,2,2,2]
		start_shift()
		screenshot_timer = 8.0
	else:
		first_run_guide.maybe_begin()
	page_transition.enabled = not testing
	queue_redraw()

func load_presentation():
	font = preload("res://data/fonts/Nunito-Semibold.tres")
	ui_art.load_assets()
	environment_art.load_assets()
	first_run_guide.load_assets()
	page_transition.load_assets()
	pause_transition.attach()

func setup_audio():
	if game_audio != null: return
	game_audio = preload("res://scripts/game_audio.gd").new()
	game_audio.set_enabled(sound_on)
	game_audio.set_suspended(audio_application_paused or audio_focus_lost)
	add_child(game_audio)
	game_audio.prepare()

func feedback(event_name: String, options: Dictionary = {}):
	if not sound_on or startup_blocked or not profile_initialization_complete or audio_application_paused or audio_focus_lost or audio_restoring: return
	audio_feedback_requested.emit(event_name,area_id)
	if game_audio != null and not testing: game_audio.play_event(event_name,area_id,options)

func _audio_mode_changed(previous: String, destination: String):
	if startup_blocked or not profile_initialization_complete or audio_application_paused or audio_focus_lost or audio_restoring: return
	if destination=="paused" and previous=="play":
		if game_audio != null: game_audio.stop_all()
		feedback("pause")
	elif destination=="play" and previous in ["paused","abandon_confirm"]:
		if game_audio != null: game_audio.stop_all()
		feedback("resume")
	elif destination=="result" and previous in ["play","paused"]:
		if game_audio != null: game_audio.stop_all()
		feedback("tray_win" if level_won else "tray_loss")
	elif destination=="play" or (previous=="result" and destination=="home"):
		pass # The committed run start or reward collection supplies its own cue.
	else:
		feedback("ui_back" if destination=="home" or previous in ["ability_offer","reset_confirm","guide","developer_areas"] else "ui_tap")

func tone(freq: float, duration: float = 0.045):
	# Keep old combat call arguments (including their RNG draw) unchanged.
	# Playback now uses authored samples rather than synthesizing sine tones.
	if not is_finite(freq) or not is_finite(duration): return
	if is_equal_approx(duration,.025) and freq>=260 and freq<=340:
		feedback("peg_hit",{"pitch":clampf(freq/300.0,.9,1.1)})
	elif is_equal_approx(duration,.045) and freq>=520 and freq<=1170:
		feedback("peg_break",{"pitch":clampf(1.0+(freq-520.0)/6500.0,.9,1.1)})
	elif is_equal_approx(duration,.08) and is_equal_approx(freq,950): feedback("time_pickup")
	elif is_equal_approx(duration,.08) and is_equal_approx(freq,720): feedback("upgrade")

func apply_safe_area(rect):
	# The background paints the expanded viewport; only the interactive board
	# is fitted to its safe region. Do not clip a tall display to the design size.
	var viewport_bounds=get_viewport_rect() if is_inside_tree() else Rect2(0,0,WIDTH,HEIGHT)
	var safe=rect.intersection(viewport_bounds)
	if safe.size.x<=0 or safe.size.y<=0: return
	var factor=minf(safe.size.x/WIDTH,safe.size.y/HEIGHT)
	scale=Vector2.ONE*factor
	position=safe.position+(safe.size-Vector2(WIDTH,HEIGHT)*factor)*.5
	queue_redraw()

func update_safe_area():
	var safe=get_viewport_rect()
	if OS.get_name()=="Android":
		var display_safe=Rect2(DisplayServer.get_display_safe_area())
		if display_safe.size.x>0 and display_safe.size.y>0:
			var local_safe=get_viewport().get_screen_transform().affine_inverse()*display_safe
			var clipped=local_safe.intersection(safe)
			if clipped.size.x>0 and clipped.size.y>0: safe=clipped
	apply_safe_area(safe)

func go_back():
	if startup_blocked: return
	if page_transition.is_blocking() or pause_transition.is_blocking(): return
	if navigation_delay>0 and not run_transition.active: return
	if mode=="boards" and level_map.close_overlay():
		navigation_delay=.25
		return
	if mode=="home" and home_menu.close_menu():
		navigation_delay=.25
		return
	var previous=mode
	_go_back_impl()
	if mode!=previous:
		navigation_delay=.25
		if previous=="shop": upgrade_map.cancel_gestures()
		if previous=="boards": level_map.cancel_gestures()
		if previous=="home": home_menu.reset()

func _go_back_impl():
	if mode=="ability_offer": ability_ui.close()
	elif mode=="developer_areas":
		developer_area_ui.cancel_gestures()
		mode="support"
	elif mode=="reset_confirm": cancel_progress_reset()
	elif mode in ["test_ad","test_purchase"]: finish_test_request("cancelled")
	elif mode=="monetization_tools": mode="monetization"
	elif mode=="monetization": mode="support"
	elif mode=="abandon_confirm": mode="paused"
	elif mode=="play":
		run_transition.finish()
		mode="paused"
		if not testing: save_game()
	elif mode=="paused": mode="play"
	elif mode=="result":
		note="Use Back to Trials to return safely" if trial_active else "Choose Collect to keep your result"
		note_time=3
	elif mode=="bonus_confirm":
		mode="result"
		result_input_delay=.25
	elif trial_active: end_trial()
	elif mode in ["guide","shop","support","loadout","boards","trials"]: mode="home"

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]: audio_application_paused=true
	elif what==NOTIFICATION_APPLICATION_RESUMED: audio_application_paused=false
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: audio_focus_lost=true
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN: audio_focus_lost=false
	if game_audio != null:
		game_audio.set_suspended(audio_application_paused or audio_focus_lost)
		if what==NOTIFICATION_WM_CLOSE_REQUEST: game_audio.stop_all()
	# A nested focus/close event while startup restores a profile must never
	# persist the temporary default campaign over that profile.
	if not profile_initialization_complete: return
	if what==NOTIFICATION_APPLICATION_RESUMED and not testing: ability_access.restore()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if startup_blocked: return
		if page_transition.is_blocking() or pause_transition.is_blocking(): return
		if navigation_delay>0 and not run_transition.active: return
		if mode=="home" and not testing:
			if home_menu.close_menu():
				navigation_delay=.25
				return
			save_game()
			get_tree().quit()
		else: go_back()
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not testing:
		var pages_enabled = page_transition.enabled
		page_transition.enabled = false
		run_transition.finish()
		if mode=="play": mode="paused"
		pause_transition.settle()
		save_game()
		page_transition.enabled = pages_enabled
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		var pages_enabled = page_transition.enabled
		page_transition.enabled = false
		run_transition.finish()
		first_run_guide.cancel_gestures()
		progress_reset_ui.cancel_gestures()
		developer_area_ui.cancel_gestures()
		ability_ui.cancel_gestures()
		if upgrade_map!=null: upgrade_map.cancel_gestures()
		if home_menu!=null: home_menu.cancel_gestures()
		if level_map!=null: level_map.cancel_gestures()
		if mode == "play":
			mode = "paused"
		pause_transition.settle()
		if not testing:
			save_game()
		page_transition.enabled = pages_enabled

func cancel_page_gestures():
	for controller in [first_run_guide,progress_reset_ui,developer_area_ui,ability_ui,upgrade_map,home_menu,level_map]:
		if controller != null: controller.cancel_gestures()

var diagnostics_on=false
var diagnostic_step_us=0.0
var diagnostic_draw_us=0.0
var last_redraw_mode=""

func update_coin_feedback(delta: float) -> bool:
	if page_transition.is_blocking() or pause_transition.is_blocking() or mode in ["paused","abandon_confirm"]: return false
	var run_advances = mode=="play" and not first_run_guide.blocks_simulation() and not run_transition.active
	var was_animating = bank_coin_feedback.active() or (run_advances and run_coin_feedback.active())
	bank_coin_feedback.advance(delta)
	bank_coin_feedback.observe(bank,area_id+(":trial" if trial_active else ":campaign"))
	if run_advances:
		run_coin_feedback.advance(delta)
	run_coin_feedback.observe(shift_coins,run_id)
	# A frozen run pulse must not keep Home, Result or Pause repainting forever.
	return was_animating or bank_coin_feedback.active() or (run_advances and run_coin_feedback.active())

func _process(delta):
	if startup_blocked: return
	if game_audio != null: game_audio.advance(delta)
	var page_was_active = page_transition.active
	var page_changed = page_transition.update(delta)
	var pause_was_active = pause_transition.active
	var pause_changed = pause_transition.update(delta)
	var page_frozen = page_was_active or page_transition.is_blocking() or pause_was_active or pause_transition.is_blocking()
	var presentation_frozen = page_frozen or run_transition.active or mode in ["paused","abandon_confirm"]
	if not presentation_frozen and mode not in ["result","bonus_confirm","test_ad"]: elapsed += delta
	var coin_feedback_changed = false if presentation_frozen else update_coin_feedback(delta)
	var guide_was_blocking = first_run_guide.blocks_simulation()
	var guide_changed = false if presentation_frozen else first_run_guide.update(delta)
	var was_entering = run_transition.active
	var entrance_changed = false if page_frozen else run_transition.update(delta)
	var map_changed = false if page_frozen else upgrade_map.update(delta)
	var journey_changed = false if page_frozen else level_map.update(delta)
	if mode=="play" and not testing and not page_frozen and not was_entering and not guide_was_blocking and not first_run_guide.blocks_simulation():
		checkpoint_clock-=delta
		if checkpoint_clock<=0:
			checkpoint_clock=5.0
			save_game()
	result_input_delay=maxf(0,result_input_delay-delta)
	navigation_delay=maxf(0,navigation_delay-delta)
	var note_was_visible=note_time>0
	if not presentation_frozen: note_time = maxf(0, note_time - delta)

	if screenshot_timer > 0:
		screenshot_timer -= delta
		if screenshot_timer <= 0:
			await RenderingServer.frame_post_draw
			var img = get_viewport().get_texture().get_image()
			img.save_png("res://builds/gameplay.png")
			get_tree().quit()
	if mode=="play" or mode!=last_redraw_mode or note_was_visible or diagnostics_on or map_changed or journey_changed or entrance_changed or guide_changed or coin_feedback_changed or page_changed or pause_changed:
		queue_redraw()
	last_redraw_mode=mode

func _physics_process(delta):
	if startup_blocked: return
	if mode == "play" and not testing:
		var started=Time.get_ticks_usec() if diagnostics_on else 0
		step(delta)
		if diagnostics_on: diagnostic_step_us=lerpf(diagnostic_step_us,float(Time.get_ticks_usec()-started),.1)

func start_shift(from_home: bool = false):
	if startup_blocked or page_transition.is_blocking() or pause_transition.is_blocking() or (from_home and run_transition.active): return
	run_ability_pinned=false
	if not trial_active: ability_ui.restore_activation()
	run_ability_active=ability_ui.owned()
	run_ability_pinned=true
	run_rules_revision=FlowRules.CURRENT_REVISION
	run_transition.finish()
	impact_feedback.reset()
	reward_earned=false
	run_serial+=1
	run_area_id=area_id
	run_id="%s:%d:%d" % [area_id,run_serial,Time.get_ticks_usec()]
	resumed_run=false
	checkpoint_clock=5.0
	mode = "play"
	queued_special=""
	force_special=""
	run_elapsed=0.0
	module_cooldowns={"ricochet":0.0,"splitter":0.0,"impact":0.0}
	rng.seed = 1719 + current_level * 104729 + (7919 if area_id=="gelato" else (15823 if area_id=="crystal" else 0))
	remaining = BASE_SECONDS + levels[7] * CLOCK_STEP
	level_won = false
	clear_draining = false
	catch_settle_remaining = 0.0
	settling_bucket = -1
	pickups.clear()
	pickup_clock = 4.0
	time_bonus = 0.0
	shift_coins = 0.0
	destroyed = 0
	wave = current_level
	combo = 0
	max_combo = 0
	combo_timer = 0
	balls.clear()
	particles.clear()
	floats.clear()
	buckets.clear()
	for i in range(5):
		buckets.append({"hits":0, "gold":i == (total_shifts % 5)})
	aim_x = 360
	aim_y=515
	spawn_clock = 0.25
	pulse_charge = 0.0
	pulse_flash = 0.0
	total_spawned = 0
	shift_claimed = false
	special_stats = {"normal":0,"ricochet":0,"splitter":0,"impact":0,"shard":0,"pulse":0}
	type_drops = {"normal":0,"ricochet":0,"splitter":0,"impact":0,"shard":0}
	crystal_launcher.reset_run()
	bakery_ability.reset_run()
	build_wave()
	result_peg_total=pegs.size()
	if from_home and not page_transition.active: run_transition.begin()
	feedback("run_start")
	first_run_guide.on_run_started()
	if not testing: save_game()

func peg_position(i, family):
	if family == "compact":
		return Vector2(220+(i%4)*90+(15 if int(i/4)%2 else 0),345+int(i/4)*72)
	if family == "splitclusters":
		var index=int(i/2)
		return Vector2(90+(i%2)*360+(index%3)*80,345+int(index/3)*66)
	if family == "denseclusters":
		var cluster=i%4
		var index=int(i/4)
		return Vector2(135+(cluster%2)*330+(index%3)*57,350+int(cluster/2)*220+int(index/3)*56)
	return Vector2(78+(i%8)*80+(12 if int(i/8)%2 else 0),345+int(i/8)*70)

func board_peg_position(i: int, spec: Dictionary) -> Vector2:
	var positions=spec.get("positions",[])
	if positions is Array and i>=0 and i<positions.size() and positions[i] is Array and positions[i].size()==2:
		return Vector2(float(positions[i][0]),float(positions[i][1]))
	return peg_position(i,str(spec.get("family","broadstagger")))

func normal_peg_hp(level: int = -1, for_trial: bool = false, revision: int = -1) -> float:
	var board = current_level if level < 0 else level
	var spec: Dictionary = board_data[board-1] if board>=1 and board<=board_data.size() else {}
	var campaign_hp = float(spec.get("base_hp",6.0))
	var base=float(spec.get("trial_base_hp",campaign_hp)) if for_trial else campaign_hp
	return FlowRules.normal_hp(base,board,for_trial,run_rules_revision if revision<0 else revision)

func peg_strength_tier(level: int = -1, for_trial: bool = false) -> String:
	# Material is authored with HP, not inferred from an armored peg's doubled HP.
	if for_trial: return ""
	var board = current_level if level < 0 else level
	var spec: Dictionary = board_data[board-1] if board>=1 and board<=board_data.size() else {}
	return str(spec.get("strength_tier",""))

func build_wave():
	impact_feedback.peg_times.clear()
	collision_source = []
	pegs.clear()
	var spec = board_data[wave-1] if wave>=1 and wave<=board_data.size() else {}
	var count = int(spec.get("peg_count",24+mini(22,(wave-1)*2)))
	var family = str(spec.get("family","broadstagger"))
	var base_hp = normal_peg_hp(wave,trial_active)
	var clock_count = int(spec.get("clock_peg_count",0 if wave==1 else 2))
	var armor_count = int(spec.get("armored_count",1 if wave>=10 else 0))
	for i in range(count):
		var pos = board_peg_position(i,spec)
		var kind="normal"
		if armor_count>0 and i<armor_count: kind="armored"
		elif i>=count-clock_count: kind="clock"
		elif wave>=3 and i%13==7: kind="prism"
		var hp=base_hp*(float(spec.get("armored_hp_multiplier",2.5)) if kind=="armored" else 1.0)
		pegs.append({"p":pos,"hp":hp,"max":hp,"kind":kind,"flash":0.0})
	if family == "splitclusters": aim_x=170
	elif family == "denseclusters": aim_x=192
	wave_flash=2.0

func step(dt):
	if startup_blocked or mode != "play" or run_transition.active or page_transition.is_blocking() or pause_transition.is_blocking() or first_run_guide.blocks_simulation(): return
	if not clear_draining and board_is_clear(): begin_clear_drain()
	if not clear_draining and remaining <= 0:
		finish_shift()
		return
	dt = maxf(0,dt) if clear_draining else minf(maxf(0,dt),remaining)
	# Clear time and automatic-ad cadence stop at the last broken cookie.
	# The drain is presentation plus remaining food physics, never extra play time.
	if not clear_draining:
		if not trial_active: monetization.advance(dt)
		run_elapsed += dt
		var previous_second = ceili(remaining)
		remaining -= dt
		if remaining>0 and remaining<=3 and ceili(remaining)<previous_second: feedback("countdown")
		if remaining <= 0:
			finish_shift()
			return
	impact_feedback.advance(dt)
	bakery_ability.advance(dt)
	catch_settle_remaining = maxf(0,catch_settle_remaining-dt)
	wave_flash = maxf(0, wave_flash - dt)
	combo_timer -= dt
	if combo_timer <= 0:
		combo = 0
	pickup_clock -= dt
	if area_id!="crystal" and not clear_draining and pickup_clock <= 0 and time_bonus < BONUS_TIME_CAP:
		pickups.append({"p":Vector2(rng.randf_range(90,630),rng.randf_range(365,740)), "life":4.0})
		feedback("pickup_appear")
		pickup_clock = 100.0 # One free pickup per run; clock pegs share the bonus cap.
		if first_run_guide.on_time_pickup_spawned(): return
	for pickup in pickups:
		pickup.life -= dt
	pickups = pickups.filter(func(p): return p.life > 0)
	if area_id=="crystal" and not clear_draining: crystal_launcher.advance(dt)
	if not clear_draining: spawn_clock -= dt
	if not clear_draining and spawn_clock <= 0 and balls.size() < 80:
		if area_id=="crystal":
			crystal_launcher.fire()
			spawn_clock += crystal_launcher.interval()
		elif area_id=="gelato":
			gelato_launcher.fire()
			spawn_clock += gelato_launcher.interval()
		else:
			spawn_ball(Vector2(aim_x, 267), random_ball())
			spawn_clock += maxf(.13, .74 / (1.0 + levels[0] * .18))
	for peg in pegs:
		peg.flash = maxf(0, peg.flash - dt)
	# Ordered geometry cache. Array replacement catches snapshot restore.
	if not is_same(collision_source, pegs):
		collision_source = pegs
		collision_rows = {}
		for peg in pegs:
			var lo = floori((peg.p.y - 33.25) / 64.0)
			var hi = floori((peg.p.y + 33.25) / 64.0)
			for row in range(lo,hi+1):
				if not collision_rows.has(row): collision_rows[row]=[]
				collision_rows[row].append(peg)
	var pending: Array = []
	for ball in balls:
		if area_id=="crystal":
			crystal_launcher.step_ball(ball,dt,pending)
			continue
		ball.life += dt
		var gravity=float(tuning.get("gravity",400.0))
		if area_id=="gelato":
			# Same exact constant-gravity curve as the launcher's dotted preview.
			ball.p += ball.v*dt+Vector2(0,.5*gravity*dt*dt)
			ball.v.y += gravity*dt
		else:
			ball.v.y += gravity*dt
			ball.p += ball.v*dt
		ball.cool -= dt
		if ball.p.x < 54:
			ball.p.x = 54
			ball.v.x = absf(ball.v.x) * .85
		if ball.p.x > 666:
			ball.p.x = 666
			ball.v.x = -absf(ball.v.x) * .85
		if ball.p.y < 260:
			ball.p.y = 260
			ball.v.y = absf(ball.v.y)
		var candidates = pegs if ball.cool > 0 else collision_rows.get(floori(ball.p.y / 64.0), [])
		for peg in candidates:
			if peg.hp <= 0:
				continue
			var diff: Vector2 = ball.p - peg.p
			var radius = 22.0 + ball.r
			if diff.length_squared() < radius * radius:
				var normal = diff.normalized() if diff.length_squared() > .001 else Vector2.UP
				ball.p = peg.p + normal * (radius + 1)
				if ball.v.dot(normal) < 0:
					impact_feedback.hit_peg(peg.p)
					ball.v = ball.v.bounce(normal) * restitution(ball.kind)
					var outward = ball.v.dot(normal)
					if outward < tuning.min_rebound_speed:
						ball.v += normal * (tuning.min_rebound_speed - outward)
					ball.v.x += rng.randf_range(-35, 35)
					ball.v = ball.v.limit_length(610)
				if ball.cool <= 0:
					var impact_first_hit = ball.kind=="impact" and not ball.used
					var dmg = CombatBalance.hit_damage(power_damage(),ball.kind,ball.used,peg.kind,tuning)
					var was_alive = peg.hp > 0
					ball.productive = true
					damage_peg(peg, dmg, impact_first_hit)
					if area_id=="bakery": bakery_ability.on_hit(ball,peg)
					if was_alive and peg.hp <= 0:
						special_stats[ball.kind] = special_stats.get(ball.kind,0) + 1
					ball.cool = .08
					if ball.kind == "impact": ball.used = true
					if ball.kind == "splitter" and not ball.used:
						feedback("special_split")
						for j in range(3):
							pending.append({"p":ball.p, "v":Vector2((j-1)*145, -165), "kind":"shard", "productive":true})
					ball.used = true
				break
		if ball.p.y > BUCKET_CATCH_Y:
			var bin = clampi(int((ball.p.x - 42) / 127.2), 0, 4)
			impact_feedback.catch_food(bin)
			feedback("cup_catch",{"pitch":.96+bin*.025})
			catch_settle_remaining = impact_feedback.BUCKET_DURATION
			settling_bucket = bin
			if not tuning.productive_bins_only or ball.productive:
				buckets[bin].hits += 1
			var reward = bucket_reward(bin)
			if ball.kind == "shard": reward = round_credits(reward * .5)
			if tuning.productive_bins_only and not ball.productive: reward=0.0
			var shown_reward = CoinDisplay.gain(shift_coins,reward)
			shift_coins = round_credits(shift_coins + reward)
			if shown_reward > 0: add_float(Vector2(106 + bin * 127, BUCKET_CATCH_Y+4), "+%d" % shown_reward, GOLD)
			ball.dead = true
		if ball.life > 16 and not clear_draining:
			ball.dead = true
	balls = balls.filter(func(b): return not b.dead)
	for b in pending:
		# A final-hit split was already earned before the feeder stopped. Keep its
		# seeds even if the normal active-play population cap was reached.
		if clear_draining or balls.size() < 80:
			spawn_ball(b.p, b.kind, b.v)
			balls[-1].productive = b.productive
	for p in particles:
		p.p += p.v * dt
		p.v.y += 180 * dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	for f in floats:
		f.p.y -= 32 * dt
		f.life -= dt
	floats = floats.filter(func(f): return f.life > 0)
	# Pending splitter seeds were added above, so they cannot be skipped by a win.
	if clear_draining and balls.is_empty() and catch_settle_remaining <= 0:
		finish_shift()

func board_is_clear() -> bool:
	if pegs.is_empty(): return false
	for peg in pegs:
		if peg.hp > 0: return false
	return true

func begin_clear_drain():
	if clear_draining or not board_is_clear(): return
	clear_draining = true
	if not level_won:
		shift_coins = round_credits(shift_coins + FlowRules.clear_reward(int(tuning.clear_base + wave * tuning.clear_per_level),wave,trial_active,run_rules_revision))
	level_won = true
	pickups.clear()
	if area_id=="crystal": crystal_launcher.begin_clear_drain()

func queue_module(_kind):
	# Compatibility for previous diagnostic scripts. Food specials are passive.
	return false

func random_ball():
	# Discard legacy overrides without consuming RNG or changing the drop odds.
	queued_special=""
	force_special=""
	var roll = rng.randf()
	var impact_chance = .04 + .008 * levels[5] if levels[5] > 0 and "impact" in equipped else 0.0
	var splitter_chance = .04 + .008 * levels[4] if levels[4] > 0 and "splitter" in equipped else 0.0
	var ricochet_chance = .06 + .012 * levels[3] if levels[3] > 0 and "ricochet" in equipped else 0.0
	if roll < impact_chance:
		return "impact"
	if roll < impact_chance + splitter_chance:
		return "splitter"
	if roll < impact_chance + splitter_chance + ricochet_chance:
		return "ricochet"
	return "normal"

func spawn_ball(pos, kind, velocity = Vector2(0, 85), jitter: bool = true):
	var launch_velocity=crystal_launcher.prepare_velocity(velocity) if area_id=="crystal" else (velocity+Vector2(rng.randf_range(-18,18),0) if jitter else velocity)
	balls.append({"p":pos, "v":launch_velocity, "kind":kind, "r":ball_radius(kind), "used":false, "productive":false, "cool":0.0, "life":0.0, "dead":false})
	total_spawned += 1
	type_drops[kind] = type_drops.get(kind,0) + 1
	if area_id=="bakery": bakery_ability.on_launch(balls[-1])
	if kind!="shard": feedback("special_ricochet" if kind=="ricochet" else "launch")

func ball_radius(kind):
	return 6.0 if kind=="shard" else (11.25 if kind=="impact" else 9.0)

func restitution(kind):
	return minf(1.06, .73 + levels[2] * .035 + (.25 if kind == "ricochet" else 0))

func bucket_reward(index):
	var base = 3 + levels[6] if buckets[index].gold else 1
	return round_credits(base + buckets[index].hits * 0.1)

func round_credits(amount) -> float:
	return roundf(float(amount) * 100.0) / 100.0

func credits_text(amount) -> String:
	return CoinDisplay.text(float(amount))

func credits_needed_text(amount) -> String:
	return CoinDisplay.shortfall_text(float(amount))

func add_time(amount):
	if clear_draining: return
	var allowed = minf(amount,BONUS_TIME_CAP-time_bonus)
	if allowed <= 0: return
	time_bonus += allowed
	remaining += allowed
	feedback("time_pickup")
	add_float(Vector2(280,300),"+%.1fs" % allowed,TEAL)

func collect_pickups(pos):
	if mode != "play" or run_transition.active or clear_draining: return
	if first_run_guide.blocks_simulation() and first_run_guide.step_id != "time_pickup": return
	for pickup in pickups:
		if pickup.life > 0 and pickup.p.distance_to(pos) < 45:
			pickup.life = 0
			add_time(2.0)
			first_run_guide.on_time_pickup_collected()

func damage_peg(peg, damage, impact_first_hit: bool = false) -> Dictionary:
	var event={"damage":0.0,"coins":0,"broken":false,"impact":impact_first_hit}
	if peg.hp<=0 or not is_finite(float(damage)) or damage<=0:
		return event
	var before_hp = maxf(0, peg.hp)
	peg.hp = maxf(0.0,before_hp-float(damage))
	event.damage=before_hp-peg.hp
	if event.damage<=0.0: return event
	if impact_first_hit: feedback("special_impact")
	impact_feedback.hit_peg(peg.p)
	var damage_budget=FlowRules.damage_budget(CombatBalance.damage_budget(peg.kind,tuning),wave,trial_active,run_rules_revision)
	event.coins=CombatBalance.damage_coins(float(peg.max),before_hp,peg.hp,damage_budget)
	shift_coins = round_credits(shift_coins+event.coins)
	peg_damaged.emit(peg.p,event.damage,impact_first_hit)
	peg.flash = .12
	if peg.hp <= 0:
		event.broken=true
		destroyed += 1
		combo += 1
		combo_timer = 1.3
		max_combo = maxi(max_combo, combo)
		var reward = int(tuning.peg_base + floor((wave - tuning.peg_level_offset) * tuning.peg_level_step)) + mini(combo, int(tuning.combo_credit_cap))
		if peg.kind == "clock":
			add_time(.5)
		if peg.kind == "prism":
			reward *= 3
		reward=FlowRules.break_reward(reward,wave,trial_active,run_rules_revision)
		shift_coins = round_credits(shift_coins + reward)
		event.coins+=reward
		add_float(peg.p, "+%d" % reward, TEAL)
		for i in range(5):
			var particle={"p":peg.p, "v":Vector2(rng.randf_range(-95,95), rng.randf_range(-130,40)), "life":.55, "c":TEAL if peg.kind != "prism" else PINK}
			if not reduced_motion: particles.append(particle)
		tone(520 + mini(combo, 10)*65)
		if destroyed == pegs.size(): begin_clear_drain()
	else:
		tone(260 + rng.randf_range(0,80), .025)
	return event

func pulse():
	# Kept as a harmless compatibility entry point; there is no manual attack.
	pass

func add_float(pos, value, color):
	if not reduced_motion and floats.size() < 45:
		floats.append({"p":pos, "text":value, "c":color, "life":.85})

func finish_shift(allow_automatic_ad = true):
	if mode != "play" and mode != "paused": return false
	if clear_draining and (not balls.is_empty() or catch_settle_remaining > 0): return false
	remaining = maxf(0,remaining)
	mode = "result"
	result_input_delay=.5
	if trial_active:
		if level_won:
			var key=str(wave)
			if not key in trial_records or run_elapsed<float(trial_records[key]): trial_records[key]=run_elapsed
		return true if testing else save_game()
	best_wave = maxi(best_wave, wave)
	total_shifts += 1
	result_history.record_run(run_area_id,result_run_record())
	var completed_attempt=level_won or remaining<=0
	if completed_attempt: monetization.complete_attempt(run_id)
	first_run_guide.on_result()
	# Persist pending result, so closing before collecting cannot lose a finished run.
	var saved=true if testing else save_game()
	if saved and completed_attempt and allow_automatic_ad:
		begin_automatic_ad()
	return saved

func collect_reward(_legacy_bonus = false):
	if mode != "result" or shift_claimed:
		return
	if run_area_id!=area_id:
		reject_snapshot("Result belongs to another area.")
		return
	if trial_active:
		end_trial()
		return
	shift_claimed = true
	last_claimed_run_id=run_id
	# Only a completed service callback can authorize the rewarded portion.
	var payout = result_payout()
	var previous_bank = bank
	bank = safe_credits(bank + payout)
	var new_voucher=false
	if level_won:
		if wave in [2,5,8] and wave not in module_milestones:
			module_milestones.append(wave)
			if levels[3]>0 and levels[4]>0 and levels[5]>0:
				bank=safe_credits(bank+60)
				payout=round_credits(payout+60)
			else:
				module_vouchers+=1
				new_voucher=true
		if current_level == 12: chapter_complete = true
		current_level = mini(12,current_level+1)
		highest_unlocked = maxi(highest_unlocked,current_level)
	mode = "home"
	home_menu.reset()
	result_input_delay=.4
	return_mode = "home"
	note = "Collected %d credits%s" % [CoinDisplay.gain(previous_bank,bank-previous_bank), " · test bonus" if reward_earned and test_commerce_available() else ""]
	if new_voucher: note="Free treat unlock earned"
	note_time = 4
	first_run_guide.on_collected()
	feedback("collect")
	if not testing:
		save_game()

func result_payout() -> float:
	var toolkit=round_credits(shift_coins*.2) if test_commerce_available() and not trial_active and monetization.entitlements.baker_toolkit else 0.0
	return round_credits(shift_coins+toolkit+(round_credits(shift_coins*.5) if test_commerce_available() and reward_earned and not trial_active else 0.0))

func collection_payout() -> float:
	var payout = result_payout()
	if not trial_active and level_won and wave in [2,5,8] and wave not in module_milestones and levels[3]>0 and levels[4]>0 and levels[5]>0:
		payout += 60
	return round_credits(payout)

func displayed_result_payout() -> int:
	return CoinDisplay.gain(bank,collection_payout())

func displayed_reward_bonus() -> int:
	if not test_commerce_available() or trial_active or reward_earned: return 0
	return CoinDisplay.gain(round_credits(bank+collection_payout()),round_credits(shift_coins*.5))

func persist_monetization() -> bool:
	if not test_commerce_available(): return false
	queue_redraw()
	return true if testing else save_game()

func begin_automatic_ad():
	# Called only at a newly completed, saved campaign result, never on resume or Play.
	if not test_commerce_available() or mode!="result" or trial_active or shift_claimed: return
	begin_test_ad("interstitial")

func begin_rewarded_ad():
	if not test_commerce_available() or mode not in ["result","bonus_confirm"] or trial_active or shift_claimed or reward_earned: return
	begin_test_ad("rewarded")

func begin_test_ad(kind: String):
	if not test_commerce_available(): return
	var before=monetization.export_state()
	var request=monetization.request(kind,run_id)
	if request.is_empty():
		mode="result"
		if kind=="rewarded":
			note="Test ad unavailable. Collect your credits."; note_time=4
		return
	commerce_profile=SAVE_FILE
	commerce_return_mode="result"
	commerce_message="No real ad is playing. Choose a test outcome."
	mode="test_ad"
	result_input_delay=.25
	# Save the shown-ad cooldown with the pending result before exposing controls.
	if not persist_monetization():
		monetization.import_state(before)
		mode="result"

func begin_test_purchase(product: String):
	if not test_commerce_available() or mode!="monetization" or trial_active: return
	var request=monetization.request("purchase",product)
	if request.is_empty(): return
	commerce_profile=SAVE_FILE
	commerce_return_mode="monetization"
	commerce_message="Choose a test payment outcome. No charge."
	mode="test_purchase"
	result_input_delay=.25

func finish_test_request(outcome: String):
	if not test_commerce_available() or mode not in ["test_ad","test_purchase"] or monetization.pending.is_empty(): return
	var request=monetization.pending.duplicate(true)
	if commerce_profile!=SAVE_FILE: return
	if request.kind in ["rewarded","interstitial"] and (request.context!=run_id or trial_active or shift_claimed): return
	var reply=monetization.resolve(str(request.id),outcome)
	if reply.is_empty(): return
	if reply.kind=="purchase" and reply.outcome=="pending":
		commerce_message="Payment pending. Approve or cancel to finish."
		queue_redraw()
		return
	if reply.kind=="rewarded" and reply.granted:
		reward_earned=true
	mode=commerce_return_mode
	result_input_delay=.25
	navigation_delay=.25
	if reply.kind=="purchase":
		commerce_message="Test purchase added." if reply.granted else "Purchase %s. Nothing granted." % reply.outcome
	else:
		note="Test bonus added. Collect when ready." if reply.kind=="rewarded" and reply.granted else "Test ad closed. Your credits are safe."
		note_time=4
	persist_monetization()

func restore_test_purchases():
	if not test_commerce_available() or mode!="monetization": return
	monetization.restore_purchases()
	commerce_message="Test purchases restored from the local test store."
	persist_monetization()

func stage_test_ad_break():
	if not test_commerce_available() or mode!="monetization_tools": return
	monetization.attempts=3
	monetization.active_seconds=120.0
	commerce_message="Staged, but Remove Ads still skips automatic ads." if monetization.entitlements.remove_ads else "Staged: next finished run checks for an ad."
	persist_monetization()

func clear_test_entitlements_for_restore():
	if not test_commerce_available() or mode!="monetization_tools": return
	monetization.entitlements={"remove_ads":false,"baker_toolkit":false}
	commerce_message="Local benefits cleared. Restore keeps store purchases."
	persist_monetization()

func reset_test_monetization():
	if not test_commerce_available() or mode!="monetization_tools": return
	monetization.reset_test_state()
	commerce_message="Test ads and purchases reset. Credits kept."
	persist_monetization()

func module_slots():
	return 2 if trial_active or highest_unlocked >= 4 else 1

func claim_module(kind):
	var idx=["ricochet","splitter","impact"].find(kind)+3
	if idx<3 or idx>5 or module_vouchers<=0 or levels[idx]>0: return false
	var node=next_shop_node(idx)
	if node.x<0:
		note="Follow its upgrade path first."; note_time=3
		return false
	return _purchase_upgrade_node(node.x,node.y,true)

func toggle_module(kind):
	var idx = ["ricochet","splitter","impact"].find(kind)+3
	if idx<3 or idx>5: return
	if levels[idx]<=0:
		if module_vouchers>0:
			claim_module(kind)
			return
		note="Buy in workshop or earn a free unlock on boards 2, 5, 8"
	elif kind in equipped:
		equipped.erase(kind)
		feedback("ui_confirm")
		note="Module unequipped. Swaps are always free."
	elif equipped.size()>=module_slots():
		note="Unequip another module to make space"
		feedback("ui_error")
	else:
		equipped.append(kind)
		feedback("ui_confirm")
		note="Module equipped. Special drops happen by chance."
	note_time=3
	if not testing: save_game()

func upgrade_cost(i):
	var base = tuning.clock_base_cost if i == 7 else BASE_COSTS[i]
	var growth = tuning.core_cost_growth if i == 1 else tuning.upgrade_cost_growth
	# Keep the first purchase close; later tiers are deliberate savings goals.
	var rebuild=float(tuning.get("power_rebuild_cost_multiplier",2.0)) if area_id=="gelato" and gelato_launcher.is_twin() and i==1 else 1.0
	return maxi(1, ceili(base * tuning.upgrade_cost_scale * pow(growth,levels[i]) * rebuild))

func buy_twin_launchers() -> bool:
	return gelato_launcher.buy()

func ability_early_access(id: String) -> bool:
	return ability_access.has_early_access(id)

func ability_grant_active(flag: bool) -> bool:
	if run_ability_pinned and mode in ["play","paused","abandon_confirm"] and not shift_claimed:
		return flag and run_ability_active
	return flag and (ability_unlock_source=="earned" or ability_early_access(area_id))

func power_damage(tier: int = -1) -> float:
	var count = clampi(levels[1] if tier<0 else tier,0,MAX_LEVELS[1])
	var gains = tuning.get("core_tier_gains",[])
	var damage = float(tuning.get("base_power_damage",2.0)) if area_id=="crystal" else 1.0
	var rebuild=float(tuning.get("power_rebuild_gain_multiplier",1.35)) if area_id=="gelato" and gelato_launcher.is_twin() and not trial_active else 1.0
	for index in range(count):
		damage += (float(gains[index]) if index<gains.size() else float(tuning.core_step))*rebuild
	return damage

func upgrade_graph():
	if area_id=="crystal": return CrystalUpgradeGraph
	return GelatoUpgradeGraph if area_id=="gelato" else UpgradeGraph

func ensure_gelato_shop_state() -> bool:
	if area_id!="gelato": return true
	# Revision zero is explicit legacy runtime state. Versioned data is never
	# repaired from counters: that would turn a corrupt save into free purchases.
	if gelato_shop_revision==0:
		if levels.size()!=MAX_LEVELS.size(): return false
		for family in range(MAX_LEVELS.size()):
			if not AreaCampaign.integer(levels[family],0,MAX_LEVELS[family]): return false
		if not AreaCampaign.integer(power_reset_tier,0,MAX_LEVELS[1]): return false
		var migrated=AreaCampaign.legacy_gelato_shop_state(levels,twin_launchers,power_reset_tier)
		gelato_shop_revision=migrated.gelato_shop_revision
		gelato_owned_nodes=migrated.gelato_owned_nodes
		gelato_reset_power_nodes=migrated.gelato_reset_power_nodes
	var state={"levels":levels,"twin_launchers":twin_launchers,"power_reset_tier":power_reset_tier,
		"gelato_shop_revision":gelato_shop_revision,"gelato_owned_nodes":gelato_owned_nodes,"gelato_reset_power_nodes":gelato_reset_power_nodes}
	var signature=hash(state)
	if _gelato_shop_validation_cached and signature==_gelato_shop_validation_hash: return _gelato_shop_validation_valid
	_gelato_shop_validation_cached=true
	_gelato_shop_validation_hash=signature
	_gelato_shop_validation_valid=AreaCampaign.valid_gelato_shop_state(state)
	return _gelato_shop_validation_valid

func shop_node_owned(i: int, n: int) -> bool:
	if area_id!="gelato": return UpgradeGraph.is_owned(levels,i,n)
	return ensure_gelato_shop_state() and GelatoUpgradeGraph.valid_node(i,n) and [i,n] in gelato_owned_nodes

func is_rebuild_power_node(i: int, n: int) -> bool:
	return area_id=="gelato" and not trial_active and ensure_gelato_shop_state() and i==1 and [i,n] in gelato_reset_power_nodes

func shop_node_historical(i: int, n: int) -> bool:
	return shop_node_owned(i,n) or is_rebuild_power_node(i,n)

func shop_missing_prerequisites(i: int, n: int) -> Array[Vector2i]:
	if area_id!="gelato": return UpgradeGraph.missing_prerequisites(levels,i,n)
	var missing: Array[Vector2i]=[]
	if not ensure_gelato_shop_state() or not GelatoUpgradeGraph.valid_node(i,n): return missing
	# Already purchased reset slots remain rebuildable even when a migrated
	# legacy node has an unowned parent in the new shuffled map.
	if shop_node_owned(i,n) or is_rebuild_power_node(i,n): return missing
	for parent in GelatoUpgradeGraph.prerequisites(i,n):
		if not shop_node_historical(parent.x,parent.y): missing.append(parent)
	return missing

func shop_node_unlocked(i: int, n: int) -> bool:
	if area_id!="gelato": return UpgradeGraph.is_unlocked(levels,i,n)
	if trial_active or not ensure_gelato_shop_state() or not GelatoUpgradeGraph.valid_node(i,n): return false
	if shop_node_owned(i,n): return true
	return levels[i]<MAX_LEVELS[i] and shop_missing_prerequisites(i,n).is_empty()

func shop_node_visible(i: int, n: int) -> bool:
	if area_id!="gelato": return UpgradeGraph.is_visible(levels,i,n)
	return shop_node_historical(i,n) or shop_node_unlocked(i,n)

func next_shop_node(i: int) -> Vector2i:
	if i<0 or i>=levels.size() or levels[i]>=MAX_LEVELS[i]: return Vector2i(-1,-1)
	if area_id!="gelato":
		return Vector2i(i,int(levels[i])+1) if UpgradeGraph.is_unlocked(levels,i,int(levels[i])+1) else Vector2i(-1,-1)
	for node in GelatoUpgradeGraph.nodes():
		if node.x==i and not shop_node_owned(node.x,node.y) and shop_node_unlocked(node.x,node.y): return node
	return Vector2i(-1,-1)

func upgrade_unlocked(i: int) -> bool:
	return next_shop_node(i).x>=0

func buy_upgrade(i):
	var node=next_shop_node(i)
	if node.x<0:
		note="Buy the preceding upgrade first."
		note_time=2
		return false
	return buy_upgrade_node(node.x,node.y)

func buy_upgrade_node(i: int, n: int) -> bool:
	return _purchase_upgrade_node(i,n,false)

func _purchase_upgrade_node(i: int, n: int, voucher: bool) -> bool:
	if trial_active or profile_load_blocked or i<0 or i>=levels.size() or levels[i]>=MAX_LEVELS[i]: return false
	if shop_node_owned(i,n) or not shop_node_unlocked(i,n): return false
	if area_id!="gelato" and n!=levels[i]+1: return false
	if voucher and (i not in [3,4,5] or levels[i]!=0 or module_vouchers<=0): return false
	var cost = upgrade_cost(i)
	if not voucher and not can_afford(cost):
		note = "Need %s more credits" % credits_needed_text(cost - bank)
		note_time = 2
		return false
	var previous={"bank":bank,"levels":levels.duplicate(),"equipped":equipped.duplicate(),"module_vouchers":module_vouchers,
		"gelato_owned_nodes":gelato_owned_nodes.duplicate(true),"gelato_reset_power_nodes":gelato_reset_power_nodes.duplicate(true),
		"note":note,"note_time":note_time,"navigation_delay":navigation_delay}
	var previous_guide=first_run_guide.export_state()
	if voucher: module_vouchers-=1
	else: spend_coins(cost)
	if area_id=="gelato":
		gelato_owned_nodes.append([i,n])
		gelato_reset_power_nodes.erase([i,n])
	levels[i] += 1
	if levels[i] == 1 and i in [3,4,5]:
		var kind = ["ricochet","splitter","impact"][i-3]
		if equipped.size() < module_slots(): equipped.append(kind)
	first_run_guide.on_upgrade_bought(i)
	if not testing and not save_game():
		for key in previous: set(key,previous[key])
		first_run_guide.import_state(previous_guide,true)
		return false
	tone(720, .08)
	if voucher:
		navigation_delay=.25
		note="Free module equipped. Special drops happen by chance." if ["ricochet","splitter","impact"][i-3] in equipped else "Module unlocked. Unequip another to try it."
		note_time=4
	else:
		note = "%s upgraded to level %d" % [UPGRADE_NAMES[i], levels[i]]
		note_time = 2
	return true

func begin_trial(board):
	if trial_active or highest_unlocked<4 or board not in [4,8,12] or mode not in ["trials","home"]: return false
	trial_snapshot=campaign_profile()
	trial_active=true
	twin_launchers=false
	crystal_second_prism=false
	bakery_jam_burst=false; bakery_run={}; ability_unlock_source="earned"
	power_reset_tier=0
	levels=RunSnapshot.TRIAL_LEVELS.duplicate()
	current_level=board
	bank=0.0
	module_vouchers=0
	equipped=["ricochet","splitter"]
	force_special=""
	mode="loadout"
	note="Choose any two modules. Campaign upgrades are untouched."
	note_time=4
	return true

func end_trial():
	if not trial_active: return
	for key in trial_snapshot: set(key,trial_snapshot[key])
	trial_active=false
	trial_snapshot={}
	queued_special=""
	shift_claimed=true
	mode="trials"
	result_input_delay=.4
	if not testing: save_game()

func area_title(id: String = "") -> String:
	return AreaCampaign.TITLES.get(area_id if id.is_empty() else id,"Bakery")

func area_owned(id: String) -> bool:
	return area_records.has(id)

func has_area(id: String) -> bool:
	return area_owned(id)

func area_boards(id: String) -> Array:
	if id not in AreaCampaign.IDS: return []
	var path=AreaCampaign.BOARD_PATHS[id]
	if not FileAccess.file_exists(path): return []
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	var boards=parsed.get("boards",[]) if parsed is Dictionary else parsed
	if not boards is Array or boards.size()!=12: return []
	for i in range(12):
		var spec=boards[i]
		if not spec is Dictionary or not AreaCampaign.integer(spec.get("level"),i+1,i+1): return []
		if not AreaCampaign.integer(spec.get("peg_count"),1,48) or not AreaCampaign.number(spec.get("base_hp"),.01,10000): return []
		if spec.has("trial_base_hp") and not AreaCampaign.number(spec.trial_base_hp,.01,10000): return []
		if spec.has("strength_tier") and spec.strength_tier not in ["bronze","silver","gold","diamond"]: return []
		if not AreaCampaign.integer(spec.get("clock_peg_count",0),0,spec.peg_count) or not AreaCampaign.integer(spec.get("armored_count",0),0,spec.peg_count): return []
		if not AreaCampaign.number(spec.get("armored_hp_multiplier",1.0),1,10): return []
		if id=="gelato" or spec.has("positions"):
			var positions=spec.get("positions",[])
			if not positions is Array or positions.size()!=int(spec.peg_count): return []
			for point in positions:
				if not point is Array or point.size()!=2 or not AreaCampaign.number(point[0],50,670) or not AreaCampaign.number(point[1],290,1000): return []
	return boards

func area_content_ready(id: String) -> bool:
	if area_boards(id).is_empty(): return false
	return food_art.is_area_ready(id) and environment_art.is_area_ready(id) and ui_art.is_area_ready(id)

func set_active_area(id: String) -> bool:
	# Presentation-only selection for loading and isolated render fixtures. Normal
	# navigation must use enter_area/switch_area to preserve the outgoing record.
	var boards=area_boards(id)
	if boards.is_empty(): return false
	area_id=id
	board_data=boards
	load_area_tuning(id)
	food_art.set_area(id)
	ui_art.set_area(id)
	environment_art.set_area(id)
	if upgrade_map!=null: upgrade_map.reset_view_state()
	return true

func area_navigation_allowed() -> bool:
	return mode in ["home","boards"] and (shift_claimed or run_id.is_empty()) and not trial_active and not run_transition.active and monetization.pending.is_empty() and not area_transaction_pending and not profile_load_blocked

func developer_tools_available() -> bool:
	# Available in the editor/debug builds or an explicitly tagged developer export.
	return MonetizationService.preview_tools_allowed()

func test_commerce_available() -> bool:
	# Real ads/billing are not connected in the public release candidate.
	return monetization != null and monetization.simulation_enabled()

func developer_money_enabled() -> bool:
	return developer_tools_available() and not trial_active and developer_free_purchases.get(area_id,false)==true

func set_developer_money(enabled: bool) -> bool:
	if not developer_area_navigation_allowed(): return false
	developer_free_purchases[area_id]=enabled
	feedback("ui_confirm")
	queue_redraw()
	return true

func can_afford(cost: float) -> bool:
	return is_finite(cost) and cost>=0 and (developer_money_enabled() or bank>=cost)

func spend_coins(cost: float) -> bool:
	if not can_afford(cost): return false
	if not developer_money_enabled(): bank=round_credits(bank-cost)
	return true

func developer_area_navigation_allowed() -> bool:
	return developer_tools_available() and mode in ["support","developer_areas"] and (shift_claimed or run_id.is_empty()) and not trial_active and not run_transition.active and monetization.pending.is_empty() and not area_transaction_pending and not profile_load_blocked and not first_run_guide.active

func open_developer_areas() -> bool:
	if mode!="support" or not developer_area_navigation_allowed(): return false
	developer_area_ui.cancel_gestures()
	mode="developer_areas"
	navigation_delay=.25
	queue_redraw()
	return true

func developer_switch_area(id: String) -> bool:
	if not developer_area_navigation_allowed() or id not in AreaCampaign.IDS or id==area_id or not area_content_ready(id): return false
	var records=area_records.duplicate(true)
	records[area_id]=AreaCampaign.capture_local(self)
	# Initialize once. A return visit resumes that area's exact independent build.
	if not records.has(id): records[id]=AreaCampaign.default_record()
	# Developer entry skips the gate and fee without inventing a paid-entry record.
	return commit_area_change(id,records,area_entries.duplicate(true))

func area_entry_status(id: String = "gelato") -> Dictionary:
	var source_id=AreaCampaign.predecessor(id)
	var source=AreaCampaign.capture_local(self) if area_id==source_id else area_records.get(source_id,AreaCampaign.default_record())
	var cost=int(bakery_tuning.area_unlock_cost) if id=="gelato" else AreaCampaign.entry_cost(id)
	var owned=area_owned(id)
	var cleared=source.chapter_complete and source.highest_unlocked==12
	var funded=source.bank>=cost
	var ready=area_content_ready(id)
	return {"source":source_id,"cost":cost,"cleared":cleared,"funded":funded,"content_ready":ready,"owned":owned,"can_enter":not source_id.is_empty() and not owned and AreaCampaign.valid_record(source,source_id) and cleared and funded and ready and area_navigation_allowed()}

func enter_area(id: String = "gelato") -> bool:
	var status=area_entry_status(id)
	if not status.can_enter: return false
	var records=area_records.duplicate(true)
	records[area_id]=AreaCampaign.capture_local(self)
	records[status.source].bank=round_credits(records[status.source].bank-status.cost)
	records[id]=AreaCampaign.default_record()
	var ledger=area_entries.duplicate(true)
	ledger.append({"id":"%s:%s:%d:%d" % [area_id,id,run_serial,Time.get_ticks_usec()],"source":status.source,"destination":id,"cost":status.cost})
	return commit_area_change(id,records,ledger)

func switch_area(id: String) -> bool:
	if id==area_id or not area_owned(id) or not area_navigation_allowed() or not area_content_ready(id): return false
	var records=area_records.duplicate(true)
	records[area_id]=AreaCampaign.capture_local(self)
	return commit_area_change(id,records,area_entries.duplicate(true))

func commit_area_change(id: String, records: Dictionary, ledger: Array) -> bool:
	# The candidate is durable before any live wallet, entitlement or area changes.
	# A failed write leaves the overlay and the complete current area untouched.
	area_transaction_pending=true
	var candidate=profile_envelope(records,id,ledger)
	if not AreaCampaign.decode_profile(candidate).ok or not write_profile_file(candidate):
		area_transaction_pending=false
		return false
	area_records=records
	area_entries=ledger
	set_active_area(id)
	AreaCampaign.apply_local(self,records[id])
	clear_area_transients()
	area_transaction_pending=false
	return true

func clear_area_transients():
	run_ability_pinned=false
	run_transition.finish()
	developer_area_ui.cancel_gestures()
	impact_feedback.reset()
	trial_active=false; trial_snapshot={}; reward_earned=false
	run_id=""; run_area_id=area_id; resumed_run=false
	shift_coins=0; destroyed=0; wave=current_level; level_won=false; shift_claimed=true
	clear_draining=false; catch_settle_remaining=0.0; settling_bucket=-1
	result_peg_total=0; run_elapsed=0; queued_special=""; force_special=""
	pegs=[]; balls=[]; pickups=[]; particles=[]; floats=[]; buckets=[]
	crystal_launcher.reset_run()
	bakery_ability.reset_run()
	mode="home"; return_mode="home"; result_input_delay=.25; navigation_delay=.25
	upgrade_map.reset_view_state()
	home_menu.reset()
	level_map.reset()
	queue_redraw()

func campaign_profile():
	if area_id=="gelato" and not trial_active: ensure_gelato_shop_state()
	return {"bank":round_credits(bank),"levels":levels.duplicate(),"twin_launchers":twin_launchers,"bakery_jam_burst":bakery_jam_burst,"ability_unlock_source":ability_unlock_source,"crystal_second_prism":crystal_second_prism,"power_reset_tier":power_reset_tier,"gelato_shop_revision":gelato_shop_revision,"gelato_owned_nodes":gelato_owned_nodes.duplicate(true),"gelato_reset_power_nodes":gelato_reset_power_nodes.duplicate(true),"best_wave":best_wave,"total_shifts":total_shifts,"current_level":current_level,"force_special":force_special,"equipped":equipped.duplicate(),"highest_unlocked":highest_unlocked,"chapter_complete":chapter_complete,"module_vouchers":module_vouchers,"module_milestones":module_milestones.duplicate()}

func pending_result_data():
	return {"area_id":run_area_id,"peg_total":result_peg_total if result_peg_total>0 else board_peg_count(wave),"coins":round_credits(shift_coins),"won":level_won,"wave":wave,"destroyed":destroyed,"combo":max_combo,"stats":special_stats,"drops":type_drops,"run_id":run_id,"trial":trial_active,"run_elapsed":run_elapsed,"equipped":equipped.duplicate(),"reward_earned":test_commerce_available() and reward_earned}

func result_run_record() -> Dictionary:
	var peg_total = clampi(result_peg_total if result_peg_total>0 else board_peg_count(wave),1,48)
	return {"run_id":run_id,"coins":safe_credits(shift_coins,0.0,10000000.0),
		"destroyed":clampi(destroyed,0,peg_total),"peg_total":peg_total,
		"combo":clampi(max_combo,0,48),"wave":clampi(wave,1,12)}

func run_comparison() -> Dictionary:
	return result_history.comparison(run_area_id,result_run_record())

func profile_envelope(records: Dictionary, active_id: String, ledger: Array) -> Dictionary:
	return {"version":PROFILE_VERSION,"balance_revision":4,"active_area_id":active_id,"areas":records,"area_entries":ledger,"total_shifts":trial_snapshot.get("total_shifts",total_shifts) if trial_active else total_shifts,"sound":sound_on,"reduced_motion":reduced_motion,"run_serial":run_serial,"last_claimed_run_id":last_claimed_run_id,"monetization_test":monetization.export_state(),"area_ability_preview":ability_access.export_state(),"onboarding":first_run_guide.export_state(),"run_history":result_history.export_state()}

func save_game():
	if profile_load_blocked: return false
	if area_id=="gelato" and not trial_active and not ensure_gelato_shop_state(): return false
	var records=area_records.duplicate(true)
	records[area_id]=AreaCampaign.capture_local(self)
	var data=profile_envelope(records,area_id,area_entries.duplicate(true))
	if not AreaCampaign.decode_profile(data).ok:
		note="Progress could not be saved. Existing save kept."; note_time=5
		return false
	if mode in ["result","bonus_confirm","test_ad"] and not shift_claimed:
		data["pending_result"]=pending_result_data()
	elif mode in ["play","paused","abandon_confirm"] and not shift_claimed:
		if not clear_draining and board_is_clear(): begin_clear_drain()
		# Airborne food and an unfinished catch remain resumable even on a won board.
		var drain_done=clear_draining and balls.is_empty() and catch_settle_remaining<=0
		if drain_done or (not clear_draining and remaining<=0):
			mode="paused"
			# A background checkpoint must never open a fullscreen ad.
			return finish_shift(false)
		data["active_run"]=RunSnapshot.capture(self)
		data["active_run_rules"]=run_rules_revision
	if not write_profile_file(data): return false
	area_records=records
	return true

func write_profile_file(data: Dictionary) -> bool:
	if profile_load_blocked: return false
	var file=FileAccess.open(SAVE_FILE+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data,"",true,true))
		file.flush()
		var write_status=file.get_error()
		file.close()
		if write_status==OK and DirAccess.rename_absolute(SAVE_FILE+".tmp",SAVE_FILE)==OK: return true
	note="Save unavailable: keep the game open"
	note_time=5
	return false

func request_progress_reset():
	if mode!="support" or trial_active or run_transition.active: return
	if not run_id.is_empty() and not shift_claimed: return
	progress_reset_ui.cancel_gestures()
	mode="reset_confirm"
	navigation_delay=.25
	queue_redraw()

func cancel_progress_reset():
	if mode!="reset_confirm": return
	progress_reset_ui.cancel_gestures()
	mode="support"
	navigation_delay=.25
	queue_redraw()

func reset_progress() -> bool:
	if mode!="reset_confirm" or trial_active or run_transition.active: return false
	if not run_id.is_empty() and not shift_claimed: return false
	# Commit a complete fresh save first. A failed write leaves the live game intact.
	var clean_store = MonetizationService.new()
	clean_store.serial = monetization.serial
	var candidate = {
		"version":PROFILE_VERSION,"balance_revision":4,"active_area_id":"bakery",
		"areas":{"bakery":AreaCampaign.default_record()},"area_entries":[],
		"total_shifts":0,"sound":sound_on,"reduced_motion":reduced_motion,
		"run_serial":0,"last_claimed_run_id":"","monetization_test":clean_store.export_state(),"area_ability_preview":ability_access.export_state(),
		"run_history":{"version":1,"areas":{}},
		"onboarding":{"version":first_run_guide.VERSION,"completed":false,"active":true,
			"step":"welcome","earned_seen":false,"time_pickup_seen":false,"upgraded_this_intro":false}
	}
	# The existing explicit confirmation may replace any blocked profile.
	# Ordinary write paths retain their read-only guard until that confirmation.
	var was_blocked=profile_load_blocked
	profile_load_blocked=false
	var committed=AreaCampaign.decode_profile(candidate).ok and write_profile_file(candidate)
	profile_load_blocked=was_blocked
	if not committed:
		note="Reset could not be saved. Your progress is unchanged."
		note_time=6
		queue_redraw()
		return false
	reset_profile_runtime()
	first_run_guide.begin(false)
	queue_redraw()
	return true

func reset_profile_runtime():
	run_transition.finish()
	developer_free_purchases.clear()
	developer_area_ui.cancel_gestures()
	result_history.reset()
	first_run_guide.reset()
	progress_reset_ui.cancel_gestures()
	impact_feedback.reset()
	monetization.reset_test_state()
	area_records={"bakery":AreaCampaign.default_record()}
	area_entries=[]; area_transaction_pending=false; profile_load_blocked=false
	set_active_area("bakery")
	reward_earned=false
	commerce_profile=""
	commerce_return_mode="result"
	commerce_message="Local simulation. No money is charged."
	levels=[0,0,0,0,0,0,0,0]
	twin_launchers=false; power_reset_tier=0
	crystal_second_prism=false
	bakery_jam_burst=false; bakery_run={}; ability_unlock_source="earned"
	crystal_launcher.reset_run()
	gelato_shop_revision=AreaCampaign.GELATO_SHOP_REVISION
	gelato_owned_nodes=[]; gelato_reset_power_nodes=[]
	bank=0.0; best_wave=1; current_level=1; highest_unlocked=1; chapter_complete=false
	total_shifts=0; module_vouchers=0; module_milestones=[]; equipped=[]; force_special=""
	trial_active=false; trial_snapshot={}; trial_records={}
	run_id=""; run_area_id="bakery"; run_serial=0; last_claimed_run_id=""; resumed_run=false
	shift_coins=0.0; destroyed=0; wave=1; level_won=false; shift_claimed=true
	clear_draining=false; catch_settle_remaining=0.0; settling_bucket=-1
	result_peg_total=0; run_elapsed=0; queued_special=""; snapshot_rejection=""
	remaining=BASE_SECONDS; spawn_clock=0; aim_x=360; aim_y=515
	pickup_clock=4.0; time_bonus=0; total_spawned=0
	special_stats={}; type_drops={}; collision_source=[]; collision_rows={}
	module_cooldowns={"ricochet":0.0,"splitter":0.0,"impact":0.0}
	pulse_charge=0; pulse_flash=0; pulse_origin=Vector2.ZERO
	combo=0; combo_timer=0; max_combo=0; wave_flash=0
	checkpoint_clock=5.0; note=""; note_time=0
	diagnostics_on=false; diagnostic_step_us=0; diagnostic_draw_us=0
	pegs=[]; balls=[]; pickups=[]; particles=[]; floats=[]; buckets=[]
	mode="home"; return_mode="home"; result_input_delay=0; navigation_delay=.25
	upgrade_map.reset_view_state()
	home_menu.reset()
	level_map.reset()

func reject_snapshot(reason):
	run_transition.finish()
	snapshot_rejection=reason
	mode="home"
	trial_active=false
	trial_snapshot={}
	note="Run could not resume. Workshop progress kept."
	note_time=8

func restore_active_run(snapshot):
	var pages_enabled = page_transition.enabled
	var was_restoring = audio_restoring
	audio_restoring = true
	page_transition.enabled = false
	var restored = _restore_active_run_impl(snapshot)
	page_transition.enabled = pages_enabled
	audio_restoring = was_restoring
	return restored

func _restore_active_run_impl(snapshot):
	run_transition.finish()
	run_ability_pinned=false
	var checked=RunSnapshot.validate_and_decode(snapshot,self)
	if not checked.ok:
		reject_snapshot(checked.reason)
		return false
	var state=checked.state
	if state.run_id==last_claimed_run_id:
		reject_snapshot("This run reward was already claimed.")
		return false
	var campaign=campaign_profile()
	run_area_id=area_id
	for key in state:
		# Run ability flags describe active physics. Keep the campaign's prior
		# activation and one-time Power reset history if access is unavailable.
		if not state.trial_active and key in ["twin_launchers","power_reset_tier","crystal_second_prism"]: continue
		if key not in ["rng_seed","rng_state"]: set(key,state[key])
	if trial_active: trial_snapshot=campaign
	else: trial_snapshot={}
	rng.seed=int(state.rng_seed)
	rng.state=int(state.rng_state)
	impact_feedback.reset()
	if clear_draining and catch_settle_remaining>0 and settling_bucket>=0:
		impact_feedback.bucket_times[settling_bucket]=catch_settle_remaining
	particles=[]; floats=[]; pulse_flash=0; wave_flash=0
	run_ability_active=ability_ui.owned()
	run_ability_pinned=true
	mode="paused"
	resumed_run=true
	checkpoint_clock=5.0
	# The paused overlay already explains the restored state.
	note=""
	note_time=0
	return true

func safe_number(value, fallback=0):
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value),-100000000,100000000))
	return fallback

func safe_credits(value, fallback=0.0, maximum=100000000.0) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return round_credits(clampf(float(value),0.0,maximum))
	return round_credits(clampf(float(fallback),0.0,maximum))

func safe_stats(value):
	var result={}
	if value is Dictionary:
		for key in ["normal","ricochet","splitter","impact","shard","pulse"]:
			result[key]=clampi(safe_number(value.get(key,0)),0,1000000)
	return result

func legacy_profile_path() -> String:
	# One-time compatibility only. All play and resets use the single canonical save.
	# Custom fixture paths must never discover a player's old campaign.
	if SAVE_FILE!=SAVE_PATH or FileAccess.file_exists(SAVE_PATH): return ""
	var candidates = ["user://sugarfall_areas_v3.json","user://peg_foundry_v1.json"]
	var selector = FileAccess.open("user://peg_foundry_profile.json",FileAccess.READ)
	if selector and selector.get_length()<=128:
		var choice = JSON.parse_string(selector.get_as_text())
		if choice is Dictionary and typeof(choice.get("version")) in [TYPE_INT,TYPE_FLOAT] and choice.version==1 and typeof(choice.get("fresh"))==TYPE_BOOL and choice.fresh:
			candidates = ["user://sugarfall_fresh_test_areas_v3.json","user://peg_foundry_fresh_test_v1.json"]+candidates
	for path in candidates:
		if FileAccess.file_exists(path): return path
	return ""

func load_game():
	var pages_enabled = page_transition.enabled
	var was_restoring = audio_restoring
	audio_restoring = true
	page_transition.enabled = false
	_load_game_impl()
	page_transition.enabled = pages_enabled
	audio_restoring = was_restoring

func _load_game_impl():
	run_transition.finish()
	first_run_guide.reset()
	result_history.reset()
	var source_path=SAVE_FILE
	# Only production profile paths may discover the corresponding legacy file.
	# Isolated fixtures and custom profiles can never read the player's real save.
	if not FileAccess.file_exists(source_path):
		var legacy_path=legacy_profile_path()
		if not legacy_path.is_empty(): source_path=legacy_path
	if not FileAccess.file_exists(source_path):
		first_run_guide.import_state(null,false)
		return
	# Recovery exits must also preserve the legacy-profile opt-out.
	first_run_guide.import_state(null,true)
	var file = FileAccess.open(source_path, FileAccess.READ)
	if not file:
		profile_load_blocked=true
		note="Save could not be opened. Existing progress kept."
		note_time=8
		return
	if file.get_length()>1048576:
		profile_load_blocked=true
		note="Save file too large to read safely."; note_time=8
		return
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK:
		profile_load_blocked=true
		note="Save is unreadable. Current workshop kept."; note_time=8
		return
	var data=parser.data
	file.close()
	if not data is Dictionary or safe_number(data.get("version", 0)) not in [1,2,3,4,PROFILE_VERSION]:
		profile_load_blocked=true
		note="Save version is unsupported. Existing progress kept read-only."; note_time=8
		return
	var version=safe_number(data.version)
	var run_history_data=data.get("run_history",{})
	if version>=3:
		var decoded=AreaCampaign.decode_profile(data)
		if not decoded.ok or not area_content_ready(decoded.get("area_id","")):
			profile_load_blocked=true
			note="Area save is unavailable. Recovery copy kept."; note_time=8
			return
		area_records=decoded.records
		area_entries=decoded.ledger
		set_active_area(decoded.area_id)
		data=data.duplicate(true)
		data.merge(area_records[area_id],true)
	else:
		area_records={"bakery":AreaCampaign.default_record()}
		area_entries=[]
		set_active_area("bakery")
	profile_load_blocked=false
	result_history.import_state(run_history_data)
	mode="home"
	shift_claimed=true
	run_id=""; run_area_id=area_id
	trial_active=false
	clear_draining=false; catch_settle_remaining=0.0; settling_bucket=-1
	trial_snapshot={}
	resumed_run=false
	snapshot_rejection=""
	monetization.reset_test_state()
	monetization.import_state(data.get("monetization_test",{}))
	ability_access.reset_preview_store()
	ability_access.import_state(data.get("area_ability_preview",{}))
	reward_earned=false
	commerce_profile=""
	run_serial=maxi(0,safe_number(data.get("run_serial",0)))
	last_claimed_run_id=str(data.get("last_claimed_run_id",""))
	reduced_motion=data.get("reduced_motion",false)==true
	trial_records={}
	var records=data.get("trial_records",{})
	if records is Dictionary and safe_number(data.get("balance_revision",0))==4 and safe_number(data.get("combat_rules_revision",0))==AreaCampaign.COMBAT_RULES_REVISION:
		for key in ["4","8","12"]:
			var value=records.get(key,0)
			if (value is float or value is int) and is_finite(float(value)) and value>0 and value<=120: trial_records[key]=float(value)
	bank = safe_credits(data.get("bank",0))
	twin_launchers=area_id=="gelato" and data.get("twin_launchers",false)==true
	bakery_jam_burst=area_id=="bakery" and data.get("bakery_jam_burst",false)==true
	ability_unlock_source=str(data.get("ability_unlock_source","earned"))
	crystal_second_prism=area_id=="crystal" and data.get("crystal_second_prism",false)==true
	crystal_launcher.reset_run()
	power_reset_tier=clampi(safe_number(data.get("power_reset_tier",0)),0,10) if twin_launchers else 0
	var saved = data.get("levels",[])
	if saved is Array and saved.size() == 8:
		for i in range(8):
			levels[i] = clampi(safe_number(saved[i]),0,MAX_LEVELS[i])
	gelato_shop_revision=int(data.get("gelato_shop_revision",AreaCampaign.GELATO_SHOP_REVISION))
	gelato_owned_nodes=data.get("gelato_owned_nodes",[]).duplicate(true)
	gelato_reset_power_nodes=data.get("gelato_reset_power_nodes",[]).duplicate(true)
	best_wave = clampi(safe_number(data.get("best_wave",1),1),1,999)
	total_shifts = maxi(0,safe_number(data.get("total_shifts",0)))
	sound_on = bool(data.get("sound",true))
	current_level = clampi(safe_number(data.get("current_level",1),1),1,12)
	highest_unlocked = clampi(safe_number(data.get("highest_unlocked",current_level),current_level),current_level,12)
	chapter_complete = data.get("chapter_complete",false) == true
	module_vouchers=clampi(safe_number(data.get("module_vouchers",0)),0,3)
	module_milestones=[]
	var milestones=data.get("module_milestones",[])
	if milestones is Array:
		for milestone in milestones:
			var valid_milestone=safe_number(milestone,-1)
			if valid_milestone in [2,5,8] and valid_milestone not in module_milestones: module_milestones.append(valid_milestone)
	equipped=[]
	var saved_equipped = data.get("equipped",[])
	if saved_equipped is Array:
		for kind in saved_equipped:
			if kind is String and kind in ["ricochet","splitter","impact"] and kind not in equipped and equipped.size()<module_slots():
				var idx = ["ricochet","splitter","impact"].find(kind)+3
				if levels[idx]>0: equipped.append(kind)
	# Older builds guaranteed the next special after a purchase. Ignore it now.
	force_special = ""
	area_records[area_id]=AreaCampaign.capture_local(self)
	var pending = data.get("pending_result",null)
	if pending is Dictionary:
		if pending.get("area_id","bakery" if version<3 else "")!=area_id:
			reject_snapshot("Result belongs to another area.")
			return
		run_area_id=area_id
		run_id=str(pending.get("run_id","legacy-pending"))
		if run_id==last_claimed_run_id:
			reject_snapshot("Completed reward already claimed.")
			return
		var pending_trial=pending.get("trial",false)==true
		if pending_trial:
			var trial_board=safe_number(pending.get("wave",0))
			if trial_board not in [4,8,12] or highest_unlocked<4:
				reject_snapshot("Incompatible trial result."); return
			trial_snapshot=campaign_profile()
			trial_active=true
			twin_launchers=false
			crystal_second_prism=false
			bakery_jam_burst=false; bakery_run={}; ability_unlock_source="earned"
			power_reset_tier=0
			levels=RunSnapshot.TRIAL_LEVELS.duplicate()
			current_level=trial_board
			bank=0.0
			module_vouchers=0
			equipped=[]
			var saved_modules=pending.get("equipped",[])
			if saved_modules is Array:
				for kind in saved_modules:
					if kind in ["ricochet","splitter","impact"] and kind not in equipped and equipped.size()<2: equipped.append(kind)
			var elapsed_value=pending.get("run_elapsed",0)
			run_elapsed=clampf(float(elapsed_value),0,120) if (elapsed_value is int or elapsed_value is float) and is_finite(float(elapsed_value)) else 0.0
		shift_coins=safe_credits(pending.get("coins",0),0.0,10000000.0)
		reward_earned=test_commerce_available() and typeof(pending.get("reward_earned",false))==TYPE_BOOL and pending.get("reward_earned",false) and not trial_active
		level_won=bool(pending.get("won",false))
		wave=clampi(safe_number(pending.get("wave",1),1),1,999)
		destroyed=maxi(0,safe_number(pending.get("destroyed",0)))
		var legacy_total=24+mini(22,maxi(0,wave-1)*2) if safe_number(data.get("balance_revision",0))!=4 else board_peg_count(wave)
		result_peg_total=clampi(safe_number(pending.get("peg_total",legacy_total)),1,48)
		max_combo=maxi(0,safe_number(pending.get("combo",0)))
		special_stats=safe_stats(pending.get("stats",{}))
		type_drops=safe_stats(pending.get("drops",{}))
		mode="result"
		result_input_delay=.5
		shift_claimed=false
	elif data.has("active_run"):
		var saved_rules=data.get("active_run_rules",FlowRules.LEGACY_REVISION)
		if not FlowRules.valid_revision(saved_rules):
			reject_snapshot("Run rules are unsupported. Workshop progress kept.")
			return
		run_rules_revision=int(saved_rules)
		restore_active_run(data.active_run)
	if mode=="result" and not trial_active:
		result_history.record_run(run_area_id,result_run_record())
	first_run_guide.import_state(data.get("onboarding",null),true)
	if source_path!=SAVE_FILE:
		# The old profile remains byte-for-byte intact for recovery and older builds.
		save_game()

func _input(event):
	if startup_blocked: return
	if page_transition.is_blocking() or pause_transition.is_blocking(): return
	if mode=="ability_offer" and ability_ui.handle_input(event): return
	if mode=="developer_areas" and developer_area_ui.handle_input(event): return
	if mode=="reset_confirm" and progress_reset_ui.handle_input(event): return
	if first_run_guide.handle_input(event): return
	if mode=="shop" and upgrade_map.handle_input(event): return
	if mode=="home" and home_menu.handle_input(event): return
	if mode=="boards" and level_map.handle_input(event): return
	if event is InputEventKey and event.pressed:
		if event.echo or (navigation_delay>0 and not run_transition.active): return
		if event.keycode == KEY_ESCAPE:
			go_back()
	if run_transition.active: return
	var pos = Vector2.ZERO
	var press = false
	var motion = false
	if event is InputEventScreenTouch:
		if event.index!=0: return
		pos = to_local(event.position)
		press = event.pressed
	elif event is InputEventScreenDrag:
		if event.index!=0: return
		pos = to_local(event.position)
		motion = true
	elif event is InputEventMouseButton:
		# Mouse is converted to touch by project settings.
		return
	elif event is InputEventMouseMotion:
		pos = to_local(event.position)
		motion = event.button_mask == MOUSE_BUTTON_MASK_LEFT
		if mode == "play": collect_pickups(screen_to_board(pos))
	else:
		return
	var board_pos = screen_to_board(pos)
	# A multiplier tap is a separate action: it never steers the next shot.
	if area_id=="crystal" and mode=="play" and press and crystal_launcher.try_collect(board_pos):
		queue_redraw()
		return
	if mode == "play" and (press or motion) and board_pos.y >= 210 and board_pos.y < 1100:
		aim_x = clampf(board_pos.x,66,654)
		aim_y = clampf(board_pos.y,330,1000 if area_id in ["gelato","crystal"] else 770)
	if mode == "play" and (press or motion): collect_pickups(board_pos)
	if press:
		handle_press(pos)

func inside(p, rect):
	return rect.has_point(p)

func handle_press(p):
	if startup_blocked or navigation_delay>0 or run_transition.active or page_transition.is_blocking() or pause_transition.is_blocking(): return
	var previous=mode
	_handle_press_impl(p)
	if mode!=previous:
		navigation_delay=.25
		if previous=="shop": upgrade_map.cancel_gestures()
		if previous=="boards": level_map.cancel_gestures()
		if previous=="home": home_menu.reset()

func _handle_press_impl(p):
	if mode in ["shop","loadout","trials"] and result_input_delay>0: return
	if mode in ["monetization","monetization_tools","test_ad","test_purchase"]:
		if result_input_delay<=0: monetization_ui.press(p)
		queue_redraw()
		return
	match mode:
		"ability_offer": ability_ui.press(p)
		"home":
			home_menu.press(p)
		"play":
			if inside(p,Rect2(580,22,104,96)):
				mode = "paused"
				if not testing: save_game()
		"paused":
			var actions = pause_menu_layout().actions
			if inside(p,actions.resume): mode = "play"
			elif inside(p,actions.sound):
				sound_on = not sound_on
				feedback("ui_confirm")
				if not testing: save_game()
			elif inside(p,actions.motion):
				reduced_motion=not reduced_motion
				feedback("ui_confirm")
				if reduced_motion: particles=[]; floats=[]; pulse_flash=0
				impact_feedback.reset()
				if not testing: save_game()
			elif inside(p,actions.end_shift): mode="abandon_confirm"
		"abandon_confirm":
			if inside(p,Rect2(80,650,560,96)):
				# The win is already earned; finish catching its food before results.
				mode="play" if clear_draining else "paused"
				if not clear_draining: finish_shift()
			elif inside(p,Rect2(80,780,560,96)): mode="paused"
		"result":
			if result_input_delay>0: return
			if inside(p,preload("res://scripts/result_comparison_ui.gd").COLLECT_RECT): collect_reward(false)
			elif inside(p,preload("res://scripts/result_comparison_ui.gd").BONUS_RECT) and test_commerce_available() and not trial_active and not reward_earned:
				mode="bonus_confirm"
				result_input_delay=.25
		"bonus_confirm":
			if result_input_delay>0: return
			if inside(p,Rect2(60,620,600,96)):
				begin_rewarded_ad()
			elif inside(p,Rect2(60,740,600,96)):
				mode="result"
				result_input_delay=.25
		"shop":
			upgrade_map.press(p)
			if inside(p,upgrade_map.PLAY_RECT): start_shift()
			elif inside(p,upgrade_map.TREATS_RECT): mode="loadout"
			elif inside(p,upgrade_map.MENU_RECT): mode = "home"
		"loadout":
			for i in range(3):
				if inside(p,Rect2(48,260+i*220,624,190)): toggle_module(["ricochet","splitter","impact"][i])
			if inside(p,Rect2(48,1080,624,96)):
				if trial_active: start_shift()
				else: mode="shop"
			elif trial_active and inside(p,Rect2(36,22,100,96)): end_trial()
		"trials":
			for i in range(3):
				if inside(p,Rect2(48,260+i*220,624,180)): begin_trial([4,8,12][i])
			if inside(p,Rect2(48,1080,624,96)): mode="home"
		"boards":
			level_map.press(p)
		"support":
			var actions = settings_menu_layout().actions
			if inside(p,actions.sound):
				sound_on=not sound_on
				feedback("ui_confirm")
				if not testing: save_game()
			elif inside(p,actions.motion):
				reduced_motion=not reduced_motion
				feedback("ui_confirm")
				impact_feedback.reset()
				if not testing: save_game()
			elif inside(p,actions.reset): request_progress_reset()
			elif actions.has("developer") and inside(p,actions.developer): open_developer_areas()
			elif actions.has("performance") and inside(p,actions.performance):
				diagnostics_on=not diagnostics_on
				feedback("ui_confirm")
			elif actions.has("commerce") and inside(p,actions.commerce):
				mode="monetization"
				commerce_message="Local simulation. No money is charged."
			elif inside(p,actions.back): mode="home"
		"guide":
			if inside(p,Rect2(48,1030,624,82)) and area_id=="bakery": first_run_guide.replay()
			elif inside(p,Rect2(48,1132,624,82)): mode = "home"
	queue_redraw()

func text_at(value, pos, size = 24, color = WHITE, painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	canvas.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value, y, size = 24, color = WHITE, painter: CanvasItem = null):
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text_at(value,Vector2((WIDTH-width)/2,y),size,color,painter)

func heading(value, pos, size = 40, color = WHITE, painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	canvas.draw_string(display_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func heading_centered(value, y, size = 40, color = WHITE, painter: CanvasItem = null):
	var width = display_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	heading(value,Vector2((WIDTH-width)*.5,y),size,color,painter)

func fitted_text(value, rect: Rect2, size = 24, color = WHITE, align_center = false, painter: CanvasItem = null):
	var fit = size
	while fit > 14 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x > rect.size.x: fit -= 1
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x
	var x = rect.position.x+(rect.size.x-width)*.5 if align_center else rect.position.x
	text_at(value,Vector2(x,rect.position.y+(rect.size.y-font.get_height(fit))*.5+font.get_ascent(fit)),fit,color,painter)

func area_surface(role: String) -> Color:
	# Presentation colors follow the active area; semantic action colors stay shared.
	return AREA_SURFACES.get(area_id,AREA_SURFACES.bakery)[role]

func ui_panel(rect: Rect2, painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	if not ui_art.skin(canvas,"panel",rect): box(rect,area_surface("panel"),24,Color.TRANSPARENT,canvas)

func fitted_number(value: String, rect: Rect2, size = 34, color = WHITE, align_center = false):
	var fit = size
	while fit > 16 and number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x > rect.size.x: fit -= 1
	var width = number_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit).x
	var x = rect.position.x+(rect.size.x-width)*.5 if align_center else rect.position.x
	draw_string(number_font,Vector2(x,rect.position.y+(rect.size.y-number_font.get_height(fit))*.5+number_font.get_ascent(fit)),value,HORIZONTAL_ALIGNMENT_LEFT,-1,fit,color)

func symbol(kind: String, center: Vector2, size: float, color = WHITE, painter: CanvasItem = null):
	# Simple navigation marks stay crisp and do not rely on font glyph coverage.
	var canvas = painter if painter != null else self
	var r = size*.34
	var width = maxf(2.5,size*.07)
	match kind:
		"pause":
			for x in [-.35,.35]: canvas.draw_line(center+Vector2(r*x,-r),center+Vector2(r*x,r),color,width*1.6,true)
		"play": canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-r*.6,-r),center+Vector2(r,r*0),center+Vector2(-r*.6,r)]),color)
		"back":
			canvas.draw_polyline(PackedVector2Array([center+Vector2(r*.3,-r),center+Vector2(-r*.65,0),center+Vector2(r*.3,r)]),color,width,true)
		"check": canvas.draw_polyline(PackedVector2Array([center+Vector2(-r,0),center+Vector2(-r*.2,r*.65),center+Vector2(r,-r*.7)]),color,width,true)
		"lock":
			canvas.draw_arc(center+Vector2(0,-r*.25),r*.55,PI,TAU,16,color,width,true)
			box(Rect2(center+Vector2(-r*.8,-r*.2),Vector2(r*1.6,r*1.35)),color,4,Color.TRANSPARENT,canvas)
		"target":
			canvas.draw_arc(center,r*.7,0,TAU,24,color,width,true)
			for v in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: canvas.draw_line(center+v*r*.5,center+v*r*1.2,color,width,true)
		"plus", "minus":
			canvas.draw_line(center+Vector2(-r,0),center+Vector2(r,0),color,width,true)
			if kind == "plus": canvas.draw_line(center+Vector2(0,-r),center+Vector2(0,r),color,width,true)
		"boards":
			for y in [-1,1]:
				for x in [-1,1]: box(Rect2(center+Vector2(x,y)*r*.55-Vector2.ONE*r*.3,Vector2.ONE*r*.6),color,3,Color.TRANSPARENT,canvas)
		"upgrade":
			for v in [Vector2(-r,r*.6),Vector2(0,-r*.7),Vector2(r,r*.6)]:
				canvas.draw_line(center,v+center,color,width,true)
				canvas.draw_circle(v+center,size*.1,color)
		"settings":
			canvas.draw_arc(center,r*.65,0,TAU,24,color,width*1.5,true)
			for n in range(8):
				var v = Vector2.from_angle(n*TAU/8)
				canvas.draw_line(center+v*r*.65,center+v*r,color,width*1.5,true)
		"help":
			canvas.draw_arc(center,r,0,TAU,24,color,width,true)
			fitted_text("?",Rect2(center-Vector2.ONE*size*.45,Vector2.ONE*size*.9),int(size*.7),color,true,canvas)

var style_cache = {}
func box(rect, color, radius = 18.0, border = Color.TRANSPARENT, painter: CanvasItem = null):
	var key = str(color)+":"+str(int(radius))+":"+str(border)
	if not style_cache.has(key):
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(int(radius))
		if border.a > 0:
			style.border_color = border
			style.set_border_width_all(2)
		style_cache[key] = style
	var canvas = painter if painter != null else self
	canvas.draw_style_box(style_cache[key], rect)

func button(rect, label, primary = false, subtitle = "", painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	if rect.size.x/rect.size.y < 1.5 and label in ["","<","II","⌖","−","+"]:
		# Round icon controls use their own saucer, keeping wide endcaps uncompressed.
		if not ui_art.draw(canvas,"node",rect): box(rect,area_surface("panel"),24,Color.TRANSPARENT,canvas)
	elif not ui_art.skin(canvas,"button_mint" if primary else "button_cream",rect): box(rect,Color("9dc8b5") if primary else area_surface("panel"),24,Color.TRANSPARENT,canvas)
	var symbols = {"<":"back","II":"pause","⌖":"target","−":"minus","+":"plus"}
	if symbols.has(label):
		symbol(symbols[label],rect.get_center()-Vector2(0,2),38,WHITE,canvas)
		return
	var text_rect = rect.grow(-22)
	if subtitle != "":
		text_rect.size.y = rect.size.y*.45
		text_rect.position.y = rect.position.y+10
		fitted_text(subtitle,Rect2(rect.position+Vector2(22,rect.size.y*.52),Vector2(rect.size.x-44,rect.size.y*.3)),18,MUTED,true,canvas)
	if primary and subtitle=="" and not label.contains("Collect") and not label.contains("coins"):
		var size = 30
		while size>20 and display_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>text_rect.size.x: size -= 1
		var width = display_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		heading(label,Vector2(text_rect.get_center().x-width*.5,text_rect.position.y+(text_rect.size.y-display_font.get_height(size))*.5+display_font.get_ascent(size)),size,WHITE,canvas)
	else:
		fitted_text(label,text_rect,28 if subtitle=="" else 25,WHITE,true,canvas)

var paper_texture=preload("res://data/art/paper.svg")
var tray_dots_texture=preload("res://data/art/tray_dots.svg")
var peg_textures={}
var food_art=preload("res://scripts/food_art.gd").new()

func _draw():
	var started=Time.get_ticks_usec() if diagnostics_on else 0
	draw_frame()
	first_run_guide.draw()
	if diagnostics_on:
		diagnostic_draw_us=lerpf(diagnostic_draw_us,float(Time.get_ticks_usec()-started),.1)
		box(Rect2(24,1175,672,84),area_surface("panel"),8)
		text_at("%d FPS · %d balls · %d live pegs" % [Engine.get_frames_per_second(),balls.size(),pegs.size()-destroyed],Vector2(38,1208),21,WHITE)
		text_at("CPU step %.2f ms · draw %.2f ms (not GPU)" % [diagnostic_step_us/1000,diagnostic_draw_us/1000],Vector2(38,1240),19,MUTED)
	pause_transition.sync_visuals()
	page_transition.redraw()

func draw_frame():
	var bounds = get_global_transform_with_canvas().affine_inverse()*get_viewport_rect()
	draw_rect(bounds,area_surface("background"))
	if mode not in ["play","paused","abandon_confirm","boards","shop","result","bonus_confirm"]:
		environment_art.draw_cover(self,"home_counter" if mode=="home" else "upgrade_counter",bounds)
	match mode:
		"home": draw_home()
		"ability_offer": ability_ui.draw()
		"play", "paused", "abandon_confirm":
			if run_transition.active: run_transition.draw()
			else: draw_game()
		"shop": draw_shop()
		"result": draw_result()
		"bonus_confirm":
			draw_result()
			draw_bonus_confirm()
		"guide": draw_guide()
		"support": draw_support()
		"developer_areas": developer_area_ui.draw()
		"reset_confirm":
			draw_support()
			progress_reset_ui.draw()
		"loadout": draw_loadout()
		"boards": draw_boards()
		"trials": draw_trials()
		"monetization","monetization_tools","test_ad","test_purchase": monetization_ui.draw()
	if note_time > 0:
		box(Rect2(24,1190,672,60),area_surface("secondary"),14)
		centered(note,1228,21,TEAL)

func draw_home():
	home_menu.draw()

func ball_color(kind):
	match kind:
		"ricochet": return Color("edc553")
		"splitter": return Color("c83e48")
		"impact": return Color("e89432")
		"shard": return Color("e34964")
	return PINK

func board_to_screen(point: Vector2) -> Vector2:
	return BOARD_CENTER+(point-BOARD_CENTER)*BOARD_SCALE

func screen_to_board(point: Vector2) -> Vector2:
	return BOARD_CENTER+(point-BOARD_CENTER)/BOARD_SCALE

func draw_board_transform(origin: Vector2 = Vector2.ZERO, rotation: float = 0.0, stretch: Vector2 = Vector2.ONE):
	draw_set_transform(board_to_screen(origin),rotation,stretch*BOARD_SCALE)

func draw_game():
	var bounds = get_global_transform_with_canvas().affine_inverse()*get_viewport_rect()
	if not environment_art.draw_cover(self,"play_counter",bounds):
		food_art.draw(self,"countertop",bounds,Color.WHITE,false)
	# Grow the whole tray a little, preserving round sprites and physics coordinates.
	draw_board_transform()
	if not food_art.draw_tray(self,Rect2(24,220,672,896)):
		box(Rect2(24,220,672,896),area_surface("tray_rail"),36)
		box(Rect2(47,275,626,803),area_surface("background"),22)
	# Each area previews its own dispenser physics before the first collision.
	draw_aim_guide()
	var strength_tier = peg_strength_tier(wave,trial_active)
	for peg in pegs:
		if peg.hp <= 0: continue
		var tint = Color(1.35,1.25,1.12) if peg.flash>0 and not reduced_motion else Color.WHITE
		draw_board_transform(peg.p,0.0,impact_feedback.peg_scale(peg.p,reduced_motion))
		if not food_art.draw_cookie(self,peg.kind,peg.hp,peg.max,Vector2.ZERO,Vector2(49,49),strength_tier,tint):
			var texture_key=peg.kind+ ("_flash" if peg.flash>0 and not reduced_motion else "")
			if peg_textures.has(texture_key): draw_texture(peg_textures[texture_key],-Vector2(28,28),food_art.tier_color(strength_tier))
		draw_board_transform()
	for pickup in pickups:
		if pickup.life <= 0: continue
		# Enlarge the actual collectible during its lesson; input stays on that circle.
		var pickup_zoom = 1.25 if first_run_guide.active and first_run_guide.step_id == "time_pickup" else 1.0
		draw_board_transform(pickup.p,0.0,Vector2.ONE*pickup_zoom)
		var wobble = 0.0 if reduced_motion else sin(elapsed*8)*3
		draw_circle(Vector2.ZERO,34+wobble,Color(.96,.73,.28,.18))
		food_art.draw_centered(self,"cookie_clock",Vector2.ZERO,Vector2(52,52))
		draw_arc(Vector2.ZERO,31,-PI/2,-PI/2+TAU*pickup.life/4,32,GOLD,3,true)
		box(Rect2(Vector2(-23,18),Vector2(46,24)),area_surface("panel"),9)
		text_at("+2s",Vector2(-17,36),17,TEAL)
		draw_board_transform()
	if area_id=="crystal": crystal_launcher.draw_pickup()
	for ball in balls:
		var color = ball_color(ball.kind)
		impact_feedback.draw_ball_aura(self,ball,reduced_motion)
		if not reduced_motion: draw_circle(ball.p-ball.v.normalized()*5,ball.r+1,Color(color,.12))
		var angle = 0.0 if reduced_motion else sin(ball.life*2.7)*.16+ball.v.x*.001
		if ball.kind in ["normal","ricochet","shard"] and not reduced_motion: angle=ball.life*1.9
		draw_board_transform(ball.p,angle)
		var diameter = ball.r*2.55
		if not bakery_ability.draw_ball(self,ball) and not food_art.draw_centered(self,food_art.ball_name(ball.kind),Vector2.ZERO,Vector2(diameter,diameter)):
			draw_circle(Vector2.ZERO,ball.r,color)
		draw_board_transform()
	bakery_ability.draw_effects(self)
	draw_buckets()
	for p in particles:
		draw_circle(p.p,2.6,Color(Color("bd8753"),minf(1,p.life*2)))
	for f in floats:
		text_at(f.text,f.p,20,Color(f.c,minf(1,f.life*2)))
	impact_feedback.draw_damage(self,number_font,reduced_motion)
	draw_dispenser()
	if area_id=="bakery": bakery_ability.draw_charge(self,Vector2(aim_x,235))
	draw_set_transform(Vector2.ZERO)
	draw_game_hud()

func draw_aim_guide(alpha: float = 1.0):
	if area_id=="crystal":
		crystal_launcher.draw_guide(alpha)
		return
	if area_id=="gelato":
		gelato_launcher.draw_guide(alpha)
		return
	draw_board_transform()
	for y in range(292,int(BUCKET_CATCH_Y)-33,24):
		draw_line(Vector2(aim_x,y),Vector2(aim_x,y+8),Color(.38,.40,.29,.14*alpha),2,true)

func draw_buckets(rise: float = 0.0, alpha: float = 1.0):
	# Mouths overlap the lower tray; impact stretching stays anchored at the base.
	for i in range(5):
		var rect = Rect2(45+i*127.2,BUCKET_TOP,121,BUCKET_HEIGHT)
		var anchor = Vector2(rect.get_center().x,rect.end.y)
		draw_board_transform(anchor+Vector2(0,rise),0.0,impact_feedback.bucket_scale(i,reduced_motion))
		rect.position -= anchor
		var gold = buckets[i].gold
		var cup_art = "cup_gold" if gold else "cup_cream"
		var tint = impact_feedback.bucket_tint(i,gold)
		tint.a *= alpha
		if not food_art.draw(self,cup_art,rect,tint,false):
			box(rect,(Color("edc573") if gold else Color("b9cbbc"))*tint,16)
		var reward_text = "%.1f×" % bucket_reward(i)
		var label = game_hud_label_layout(reward_text,food_art.cup_label_rect(cup_art,rect),number_font,31)
		draw_string(number_font,label.baseline,reward_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size,Color(Color("70401e") if gold else Color("4d5b50"),alpha))
		draw_board_transform()

func draw_dispenser(offset_y: float = 0.0, alpha: float = 1.0):
	if area_id=="crystal":
		crystal_launcher.draw(offset_y,alpha)
		return
	if area_id=="gelato":
		gelato_launcher.draw(offset_y,alpha)
		return
	# Preserve natural proportions; the final outlet ends at y267.
	draw_board_transform(Vector2(0,offset_y))
	if not food_art.draw(self,"hopper",Rect2(aim_x-56,155,112,112),Color(1,1,1,alpha)):
		box(Rect2(aim_x-28,238,56,33),Color(TEAL,alpha),9)
	draw_board_transform()

func game_hud_label_layout(value: String, rect: Rect2, label_font: Font, preferred_size: int) -> Dictionary:
	# Fit the complete font line box, then center its baseline in the quiet area.
	# Width-only fitting leaves tall ascenders/descent outside compact HUD rows.
	var size = preferred_size
	while size > 10 and (label_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x or label_font.get_height(size) > rect.size.y):
		size -= 1
	var width = label_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var text_box = Rect2(rect.get_center()-Vector2(width,label_font.get_height(size))*.5,Vector2(width,label_font.get_height(size)))
	return {"font_size":size,"baseline":text_box.position+Vector2(0,label_font.get_ascent(size)),"text_box":text_box}

func game_hud_status_rows() -> Array[Dictionary]:
	var tier_label = food_art.tier_label(peg_strength_tier(wave,trial_active))
	var labels = [("Trial %02d" if trial_active else "Tray %02d") % wave]
	if not tier_label.is_empty(): labels.append(tier_label)
	labels.append("%d left" % (pegs.size()-destroyed))
	# The panel ends at x564/y118; reserve its border and a coin-column gap.
	var column = Rect2(430,34,112,70)
	var row_height = column.size.y/labels.size()
	var result: Array[Dictionary] = []
	for index in range(labels.size()):
		result.append({"text":labels[index],"rect":Rect2(column.position+Vector2(0,index*row_height),Vector2(column.size.x,row_height)),"size":20 if index == 0 else 18,"color":TEAL if index == 0 else MUTED})
	return result

func draw_game_hud(hud_offset: Vector2 = Vector2.ZERO):
	# A single compact status row replaces the title block.
	draw_set_transform(hud_offset)
	button(Rect2(580,22,104,96),"II")
	ui_panel(Rect2(36,22,528,96))
	var countdown = countdown_feedback.presentation(remaining,run_elapsed,reduced_motion,clear_draining,run_id)
	if countdown.urgent:
		box(Rect2(43,28,176,84),countdown.badge_face,20,countdown.badge_edge)
		ui_art.draw(self,"timer",Rect2(52,45,43,43),countdown.icon_tint)
		draw_set_transform(hud_offset+Vector2(157,68),countdown.rotation)
		fitted_number(countdown.label,Rect2(-55,-42,110,84),countdown.font_size,countdown.color,true)
		draw_set_transform(hud_offset)
	else:
		ui_art.draw(self,"timer",Rect2(52,45,43,43))
		fitted_number(countdown.label,Rect2(102,39,116,58),countdown.font_size,countdown.color)
	ui_art.draw(self,"coin",Rect2(225,47,40,40))
	run_coin_feedback.draw(self,credits_text(shift_coins),Rect2(269,28,153,81),number_font,32,GOLD,reduced_motion,hud_offset)
	for row in game_hud_status_rows():
		var label = game_hud_label_layout(row.text,row.rect,font,row.size)
		draw_string(font,label.baseline,row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size,row.color)
	draw_set_transform(Vector2.ZERO)

func pause_menu_layout() -> Dictionary:
	# Drawing and touch targets share the same compact composition.
	return {"panel":Rect2(60,332,600,580),"title_y":411,
		"actions":{"resume":Rect2(92,456,536,88),"sound":Rect2(92,560,536,88),
		"motion":Rect2(92,664,536,88),"end_shift":Rect2(92,784,536,88)}}

func draw_pause(painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	var layout = pause_menu_layout()
	if not ui_art.menu_frame(canvas,layout.panel): ui_panel(layout.panel,canvas)
	heading_centered("Paused",layout.title_y,42,WHITE,canvas)
	button(layout.actions.resume,"Resume",true,"",canvas)
	button(layout.actions.sound,"Sound  ·  " + ("On" if sound_on else "Off"),false,"",canvas)
	button(layout.actions.motion,"Reduced motion  ·  " + ("On" if reduced_motion else "Off"),false,"",canvas)
	button(layout.actions.end_shift,"End shift…",false,"",canvas)

func draw_abandon_confirm(painter: CanvasItem = null):
	var canvas = painter if painter != null else self
	ui_panel(Rect2(48,350,624,570),canvas)
	heading_centered("Finish this shift?",450,42,WHITE,canvas)
	centered("Keep your credits. The tray stays uncleared." if not trial_active else "Return to Trials. Campaign progress stays safe.",522,22,MUTED,canvas)
	button(Rect2(80,650,560,96),"Finish & collect",true,"",canvas)
	button(Rect2(80,780,560,96),"Keep playing",false,"",canvas)

func draw_shop():
	upgrade_map.draw()

func upgrade_preview(i):
	return UPGRADE_DESC[i] if i>=0 and i<UPGRADE_DESC.size() else ""

func upgrade_value(i):
	return upgrade_preview(i)

func draw_result():
	preload("res://scripts/result_comparison_ui.gd").draw_backdrop(self)
	if trial_active:
		draw_trial_result()
		return
	preload("res://scripts/result_comparison_ui.gd").draw(self,run_comparison())

func draw_bonus_confirm():
	draw_rect(get_global_transform_with_canvas().affine_inverse()*get_viewport_rect(),Color(area_surface("overlay"),.50))
	ui_panel(Rect2(36,370,648,510))
	heading_centered("Test reward",450,40,GOLD)
	var bonus = displayed_reward_bonus()
	centered("Add %d extra credits once?" % bonus if bonus>0 else "Add a reward bonus once?",518,27,WHITE)
	centered("Complete a simulated ad to earn the bonus.",560,23,MUTED)
	button(Rect2(60,620,600,96),"Start test ad",true)
	button(Rect2(60,740,600,96),"Cancel",false)

func draw_guide():
	ui_panel(Rect2(48,42,624,136))
	heading_centered("How to play",128,42)
	var sections=[
		["donut","Aim the drops","Drag to move the dispenser.","Food falls automatically."],
		["cookie_normal","Crumble cookies","Bronze, Silver, Gold, then Diamond.","Stronger cookies at trays 4, 7 and 10."],
		["cup_cream","Grow your cups","Each catch makes that cup worth more.","Split pieces earn a smaller share."],
		["cookie_clock","Extra time","Clock cookies and pickups add time.",""],
		["pomegranate","Mix in specials","Equipped specials drop by chance.","Free unlocks on trays 2, 5 and 8."]]
	if area_id=="bakery":
		sections[4]=["donut","Jam Burst","Every fifth doughnut splashes nearby pegs.","Earn from tray 8, or unlock early."]
	if area_id=="gelato":
		sections[0]=["donut","Aim the curved drop","Drag to aim along the dotted curve.","Each launcher shows its own falling path."]
		sections[1]=["cookie_normal","Crumble wafers","Bronze, Silver, Gold, then Diamond.","Stronger wafers at trays 4, 7 and 10."]
		sections[3][2]="Clock wafers and pickups add time."
		sections[4]=["hopper","Dual Shot · 3,000 coins","Below Feed 1. Requires tray 8 and Power 6.","Resets Power; rebuilding costs more."]
	elif area_id=="crystal":
		sections[0]=["donut","Line up the shot","Drag to turn the spout.","Candy flies straight and ricochets."]
		sections[1]=["cookie_normal","Crack sugar crystals","Bronze, Silver, Gold, then Diamond.","Stronger crystals at trays 4, 7 and 10."]
		sections[3]=["multiply_pickup","Catch the Prism","Tap within four seconds to double","the balls already on the board."]
		sections[4]=["multiply_pickup","Second Prism","Unlock another chance each run.","Earn from tray 8, or unlock early."]
	for i in range(5):
		var y=222+i*160
		ui_panel(Rect2(48,y,624,145))
		food_art.draw_centered(self,sections[i][0],Vector2(105,y+71),Vector2(67,77))
		heading(sections[i][1],Vector2(164,y+45),28)
		fitted_text(sections[i][2],Rect2(164,y+(72 if sections[i][3].is_empty() else 57),474,32),22,MUTED)
		if not sections[i][3].is_empty(): fitted_text(sections[i][3],Rect2(164,y+91,474,30),21,MUTED)
	if area_id=="bakery": button(Rect2(48,1030,624,82),"Learn with Mabel",true)
	button(Rect2(48,1132,624,82),"Got it")

func settings_menu_layout() -> Dictionary:
	var order: Array[String] = ["sound","motion"]
	if developer_tools_available(): order.append_array(["developer","performance"])
	if test_commerce_available(): order.append("commerce")
	order.append_array(["reset","back"])
	var actions = {}
	var y = 112.0
	for key in order:
		if key=="reset" or key==order[2]: y+=16
		actions[key] = Rect2(80,y,560,88)
		y+=104
	var height = y+16
	var top = (HEIGHT-height)*.5
	for key in order: actions[key].position.y+=top
	return {"panel":Rect2(48,top,624,height),"title_y":top+76,"actions":actions,"order":order}

func draw_support():
	var layout = settings_menu_layout()
	var labels = {"sound":"Sound  ·  "+("On" if sound_on else "Off"),
		"motion":"Reduced motion  ·  "+("On" if reduced_motion else "Off"),
		"developer":"Developer settings","performance":"Performance display  ·  "+("On" if diagnostics_on else "Off"),
		"commerce":"Ads & purchases · test","reset":"Reset progress","back":"Back"}
	if not ui_art.menu_frame(self,layout.panel): ui_panel(layout.panel)
	heading_centered("Settings",layout.title_y,42)
	for key in layout.order: button(layout.actions[key],labels[key],key=="back")

func board_peg_count(index):
	if index>=1 and index<=board_data.size(): return int(board_data[index-1].get("peg_count",24+mini(22,(index-1)*2)))
	return 24+mini(22,maxi(0,index-1)*2)

func board_name(index):
	if index >= 1 and index <= board_data.size():
		return str(board_data[index-1].get("name","Board %d" % index))
	return "Board %02d" % index

func draw_loadout():
	if trial_active: button(Rect2(36,22,100,96),"<")
	heading("Trial ingredients" if trial_active else "Special ingredients",Vector2(160 if trial_active else 48,110),36 if trial_active else 42)
	text_at("%d / %d equipped" % [equipped.size(),module_slots()],Vector2(48,165),27,TEAL)
	fitted_text("Fixed Power · all specials free" if trial_active else ("%d free unlock · follow its path first" % module_vouchers if module_vouchers>0 else "Free unlocks: trays 2, 5 and 8"),Rect2(48,183,624,40),22,GOLD if module_vouchers>0 else MUTED)
	var names=["Lemon candy","Strawberry","Bonbon"] if area_id=="gelato" else ["Orange","Pomegranate","Pumpkin"]
	if area_id=="crystal": names=["Lemon crystal","Raspberry cluster","Blueberry core"]
	var kinds=["ricochet","splitter","impact"]
	var descs=["Bounces farther","Splits into smaller pieces","Heavy first hit. Breaks armor."]
	if area_id=="crystal": descs[0]="Stays in play longer"
	for i in range(3):
		var r=Rect2(48,260+i*220,624,190)
		var active=kinds[i] in equipped
		var free_unlock=module_vouchers>0 and upgrade_unlocked(i+3)
		ui_panel(r)
		food_art.draw_centered(self,food_art.ball_name(kinds[i]),r.position+Vector2(68,90),Vector2(88,88))
		heading(names[i],r.position+Vector2(133,56),32)
		fitted_text(descs[i],Rect2(r.position+Vector2(133,73),Vector2(455,36)),23,MUTED)
		symbol("check" if active else ("plus" if levels[i+3]>0 or free_unlock else "lock"),r.position+Vector2(148,143),24,TEAL if active else GOLD)
		text_at("Equipped" if active else ("Tap to equip" if levels[i+3]>0 else ("Free unlock" if free_unlock else "Follow upgrade path")),r.position+Vector2(173,151),21,TEAL if active else MUTED)
	centered("Equipped ingredients drop automatically by chance.",983,23,TEAL)
	centered("Choose any two." if trial_active else "Second slot opens after tray 3.",1023,21,MUTED)
	button(Rect2(48,1080,624,96),"Start trial" if trial_active else "Back to upgrades",true)

func draw_trials():
	ui_panel(Rect2(48,42,624,174))
	heading_centered("Trials",118,42)
	centered("Free replay · no credits spent or earned",176,22,MUTED)
	for i in range(3):
		var board=[4,8,12][i]
		var r=Rect2(48,260+i*220,624,180)
		ui_panel(r)
		food_art.draw_centered(self,["ricochet","pomegranate","pumpkin"][i],r.position+Vector2(65,69),Vector2(66,66))
		heading(["Wide reach","Cluster control","Armored finish"][i],r.position+Vector2(119,51),30)
		text_at("Tray %d · choose two ingredients" % board,r.position+Vector2(119,94),22,MUTED)
		var record=trial_records.get(str(board),0)
		text_at("Unlock after tray 3" if highest_unlocked<4 else ("Best: %.1fs" % record if record>0 else "Tap to try"),r.position+Vector2(30,145),22,GOLD)
	centered("Campaign progress stays unchanged.",990,23,MUTED)
	button(Rect2(48,1080,624,96),"Back",true)

func draw_trial_result():
	preload("res://scripts/result_comparison_ui.gd").draw_trial(self)

func draw_boards():
	level_map.draw()

func self_test():
	var checks=0
	rng.seed=12345
	start_shift()
	assert(pegs.size()==board_peg_count(1))
	checks+=1
	var old_count=balls.size()
	spawn_ball(Vector2(360,300),"splitter")
	assert(balls.size()==old_count+1)
	checks+=1
	for n in range(3600):
		aim_x=100+fmod(n*1.7,520)
		if mode=="play": step(1.0/60)
		for b in balls:
			assert(is_finite(b.p.x) and is_finite(b.p.y))
		assert(balls.size()<=80)
	assert(shift_coins>0) # Productive damage earns progress even without a break.
	checks+=2
	finish_shift()
	var before=bank
	var earned=shift_coins
	collect_reward(false)
	assert(bank==before+earned)
	collect_reward(true)
	assert(bank==before+earned)
	checks+=2
	bank=100000
	levels=[0,0,0,0,0,0,0,0]
	for node in UpgradeGraph.nodes():
		# Mixed routes may include a second tier before another family's first.
		# Follow the actual paths until every family has been exercised.
		if levels.min()>=1: break
		if not buy_upgrade(node.x) or levels[node.x]!=node.y:
			push_error("Self-test could not buy connected upgrade "+str(node))
			get_tree().quit(1)
			return
		checks+=1
	bank=0
	assert(not buy_upgrade(0))
	checks+=1
	levels=[10,10,6,6,6,6,8,10]
	start_shift()
	for n in range(3600):
		aim_x=90+fmod(n*2.2,540)
		if mode=="play": step(1.0/60)
		assert(balls.size()<=80)
	assert(destroyed==board_peg_count(1))
	checks+=1
	print("SELF_TEST_PASS checks=",checks," max_upgrade_shift_credits=",shift_coins," pegs=",destroyed," wave=",wave)
	get_tree().quit(0)
