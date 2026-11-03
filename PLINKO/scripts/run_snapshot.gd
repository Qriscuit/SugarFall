extends RefCounted
## Schema 5 is Crystal-only and persists Prism opportunities. Existing areas
## keep their schema4 payload. Legacy schemas1/2 belong to Bakery.
const SCHEMA = 5
const LEGACY_AREA_SCHEMA = 4
const CRYSTAL_FIELDS = ["crystal_second_prism","crystal_run"]
const CrystalLauncher = preload("res://scripts/crystal_launcher.gd")
const DRAIN_FIELDS = ["clear_draining", "catch_settle_remaining", "settling_bucket"]
## v0.5.4 changes shop prices and the unopened-area requirement only. This exact
## content pair has identical board bytes and in-run physics/payout parameters.
## Pin both sides so a future physics or board rebalance cannot inherit this pass.
const PRICE_ONLY_PREVIOUS_FINGERPRINT = "5c3620042cedb14bda99bc79dac6660e753d2ddb0ec18538036cfd04261f4127"
const PRICE_ONLY_CURRENT_FINGERPRINT = "dea32d445fc64aae42da844b56ab365a58d5835708e3c8c9a11702d404d51c6b"
## v0.6.10 moves Twin launchers later in the shop and raises their price only.
## Boards, flight, rewards and existing builds are identical to v0.6.7-v0.6.9.
## Both exact content hashes are required; later gameplay edits get no pass.
const GELATO_SHOP_PREVIOUS_FINGERPRINT = "9cf438255f4930f41ece8847325d238aaed8756564842abd6339119bc7a6f1d6"
const GELATO_SHOP_CURRENT_FINGERPRINT = "5a0bd00a920e20cc8aca0255b477147de84e305c50cfcfcb9ba40013fbca4870"
## AF-004 edits only Bakery's tray 2–12 trait_brief text. Exact authored geometry,
## durability, rewards and physics data are unchanged. Accept this one old build
## on this one new build; future changes must earn their own compatibility audit.
const BAKERY_BRIEFS_PREVIOUS_FINGERPRINT = "3186f8149fb229ec8d39dd79416a9722e661896595d150e3d4101f474db4a9c0"
const BAKERY_BRIEFS_CURRENT_FINGERPRINT = "cf5e777d9b76e7ee53247c49b4a795fa086d2eeb58fb017307f9f8004ca23936"
const MODULES = ["ricochet", "splitter", "impact"]
const BALL_KINDS = ["normal", "ricochet", "splitter", "impact", "shard"]
const PEG_KINDS = ["normal", "clock", "prism", "armored"]
const STATS_KEYS = ["normal", "ricochet", "splitter", "impact", "shard", "pulse"]
const MAX_LEVELS = [10, 10, 6, 6, 6, 6, 8, 10]
const TRIAL_LEVELS = [6, 6, 2, 1, 1, 1, 0, 4]
const MAX_PEGS = 48
const MAX_BALLS = 80
const MAX_DRAIN_BALLS = MAX_BALLS * 4
const MAX_PICKUPS = 32
const MAX_BINS = 5
const STATE_FIELDS = [
	"remaining", "run_elapsed", "spawn_clock", "aim_x", "aim_y",
	"pickup_clock", "time_bonus", "shift_coins", "destroyed", "wave",
	"pulse_charge", "combo", "combo_timer", "max_combo", "total_spawned",
	"force_special", "queued_special", "module_cooldowns", "special_stats",
	"type_drops", "level_won", "shift_claimed", "trial_active", "twin_launchers", "power_reset_tier", "levels",
	"equipped", "current_level", "pegs", "balls", "pickups", "buckets",
	"clear_draining", "catch_settle_remaining", "settling_bucket"
]
const FLOAT_LIMITS = {
	"remaining": [0.0, 90.0], "run_elapsed": [0.0, 90.0],
	"spawn_clock": [-90.0, 1.0], "aim_x": [66.0, 654.0],
	"aim_y": [330.0, 770.0], "pickup_clock": [-90.0, 100.0],
	"time_bonus": [0.0, 10.0], "pulse_charge": [0.0, 1.0],
	"combo_timer": [-90.0, 1.3], "catch_settle_remaining": [0.0, 0.32]
}
const INT_LIMITS = {
	"destroyed": [0, MAX_PEGS],
	"wave": [1, 12], "combo": [0, MAX_PEGS],
	"max_combo": [0, MAX_PEGS], "total_spawned": [0, 10000],
	"current_level": [1, 12], "settling_bucket": [-1, 4]
}

static func content_fingerprint(area_id: String = "bakery") -> String:
	if area_id not in ["bakery","gelato","crystal"]: return ""
	var context = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	# Hash the exact packaged bytes, in a fixed order, rather than parsed JSON.
	var board_path="res://data/gelato_board_design.json" if area_id=="gelato" else "res://data/board_design.json"
	var paths = [board_path, "res://data/economy.json"]
	if area_id=="gelato": paths.append("res://data/gelato_economy.json")
	if area_id=="crystal": paths=["res://data/crystal_board_design.json","res://data/economy.json","res://data/crystal_economy.json"]
	for path in paths:
		if not FileAccess.file_exists(path):
			return ""
		var bytes = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or context.update(bytes) != OK:
			return ""
	return context.finish().hex_encode()

static func capture(game) -> Dictionary:
	if game.mode not in ["play", "paused", "abandon_confirm"]:
		return {}
	if game.shift_claimed or (not game.clear_draining and (game.level_won or game.remaining <= 0)):
		return {}
	var living = false
	for peg in game.pegs:
		if peg.hp > 0:
			living = true
			break
	if not living and not game.clear_draining:
		return {}
	if game.clear_draining and (living or (game.balls.is_empty() and game.catch_settle_remaining <= 0)):
		return {}
	var identity = game.get("run_id")
	if not _valid_run_id(identity):
		return {}
	var fingerprint = content_fingerprint(game.area_id)
	if fingerprint.is_empty():
		return {}
	var snapshot = {
		"schema": SCHEMA if game.area_id=="crystal" else LEGACY_AREA_SCHEMA, "area_id": game.area_id, "fingerprint": fingerprint, "run_id": identity,
		# Godot exposes these uint64 RNG values as signed int64 Variants. Never
		# send them through JSON numbers, whose double conversion loses bits.
		"rng_seed": str(game.rng.seed), "rng_state": str(game.rng.state)
	}
	for key in STATE_FIELDS:
		snapshot[key] = _encode(game.get(key))
	if game.area_id=="crystal":
		var extra: Dictionary=game.crystal_launcher.capture_extra()
		for key in extra: snapshot[key]=_encode(extra[key])
	return snapshot

static func compatible_fingerprint(saved: String, current: String, area_id: String = "bakery") -> bool:
	if current.is_empty(): return false
	if saved==current: return true
	if area_id=="bakery":
		return (current==PRICE_ONLY_CURRENT_FINGERPRINT and saved==PRICE_ONLY_PREVIOUS_FINGERPRINT) or (current==BAKERY_BRIEFS_CURRENT_FINGERPRINT and saved==BAKERY_BRIEFS_PREVIOUS_FINGERPRINT)
	return area_id=="gelato" and current==GELATO_SHOP_CURRENT_FINGERPRINT and saved==GELATO_SHOP_PREVIOUS_FINGERPRINT

static func validate_and_decode(snapshot, game) -> Dictionary:
	if not snapshot is Dictionary:
		return _failure("Checkpoint is not an object")
	var root_keys = STATE_FIELDS + ["schema", "area_id", "fingerprint", "run_id", "rng_seed", "rng_state"]
	if not snapshot.has("schema") or not _integer(snapshot.schema, 1, SCHEMA):
		return _failure("Unsupported checkpoint schema")
	if snapshot.schema==SCHEMA:
		if snapshot.get("area_id")!="crystal": return _failure("Crystal checkpoint schema belongs to Crystal")
		root_keys+=CRYSTAL_FIELDS
	elif snapshot.get("area_id")=="crystal": return _failure("Crystal checkpoint requires its own run state")
	if snapshot.schema < 4:
		var legacy_keys = root_keys.duplicate()
		if snapshot.schema < 3: legacy_keys.erase("area_id")
		# Some compatibility fixtures downgrade a current capture. Accept the
		# known false flag only; old schemas can never assert twin ownership.
		if snapshot.has("twin_launchers"):
			if not snapshot.twin_launchers is bool or snapshot.twin_launchers:
				return _failure("Legacy checkpoint cannot own twin launchers")
		else:
			legacy_keys.erase("twin_launchers")
		if snapshot.has("power_reset_tier"):
			if not _integer(snapshot.power_reset_tier,0,0):
				return _failure("Legacy checkpoint cannot reset Power")
		else:
			legacy_keys.erase("power_reset_tier")
		if snapshot.schema==1:
			for key in DRAIN_FIELDS: legacy_keys.erase(key)
		if not _keys_match(snapshot, legacy_keys):
			return _failure("Checkpoint fields are missing or unsupported")
		snapshot = snapshot.duplicate(true)
		if snapshot.schema < 3: snapshot.area_id="bakery"
		snapshot.twin_launchers=false
		snapshot.power_reset_tier=0
		if snapshot.schema==1: snapshot.merge({"clear_draining":false,"catch_settle_remaining":0.0,"settling_bucket":-1})
	if not _keys_match(snapshot, root_keys):
		return _failure("Checkpoint fields are missing or unsupported")
	if not snapshot.area_id is String or snapshot.area_id!=game.area_id:
		return _failure("Checkpoint belongs to another area")
	var expected_fingerprint = content_fingerprint(game.area_id)
	if not snapshot.fingerprint is String or not compatible_fingerprint(snapshot.fingerprint, expected_fingerprint,game.area_id):
		return _failure("Checkpoint content no longer matches this build")
	if not _valid_run_id(snapshot.run_id):
		return _failure("Invalid run identity")
	if not _int64_string(snapshot.rng_seed) or not _int64_string(snapshot.rng_state):
		return _failure("Invalid RNG state")
	for key in ["level_won", "shift_claimed", "trial_active", "twin_launchers", "clear_draining"]:
		if not snapshot[key] is bool:
			return _failure("Invalid flag: " + key)
	if snapshot.shift_claimed or snapshot.level_won != snapshot.clear_draining:
		return _failure("A finished or collected run cannot resume")
	var state = {"run_id": snapshot.run_id, "rng_seed": snapshot.rng_seed, "rng_state": snapshot.rng_state}
	state.clear_draining = snapshot.clear_draining
	state.twin_launchers = snapshot.twin_launchers
	if not _integer(snapshot.power_reset_tier,0,MAX_LEVELS[1]) or (not state.twin_launchers and snapshot.power_reset_tier!=0):
		return _failure("Invalid Power reset tier")
	state.power_reset_tier = int(snapshot.power_reset_tier)
	if state.twin_launchers and game.area_id!="gelato":
		return _failure("Twin launchers belong to Gelato")
	for key in FLOAT_LIMITS:
		var limits = FLOAT_LIMITS[key]
		if key=="aim_y" and game.area_id in ["gelato","crystal"]: limits=[330.0,1000.0]
		if key=="spawn_clock" and game.area_id=="crystal": limits=[-90.0,maxf(1.0,game.crystal_launcher.interval(0))]
		if key=="spawn_clock" and game.area_id=="gelato" and state.twin_launchers:
			limits=[-90.0,maxf(1.0,.74/maxf(.001,float(game.tuning.get("twin_fire_rate_multiplier",.65))))]
		if not _number(snapshot[key], limits[0], limits[1]):
			return _failure("Invalid timer or value: " + key)
		state[key] = float(snapshot[key])
	if state.time_bonus > game.BONUS_TIME_CAP:
		return _failure("Checkpoint bonus exceeds current balance cap")
	for key in INT_LIMITS:
		var limits = INT_LIMITS[key]
		if not _integer(snapshot[key], limits[0], limits[1]):
			return _failure("Invalid counter: " + key)
		state[key] = int(snapshot[key])
	# Schema 1 originally stored whole credits. Keep those saves valid while
	# retaining the exact cents earned from incremental bucket multipliers.
	if not _credits(snapshot.shift_coins, 0.0, 10000000.0):
		return _failure("Invalid credit balance")
	state.shift_coins = roundf(float(snapshot.shift_coins) * 100.0) / 100.0
	if state.remaining <= 0 and not state.clear_draining:
		return _failure("An expired run cannot resume")
	if state.catch_settle_remaining > 0 and state.settling_bucket < 0:
		return _failure("A catch must identify its settling cup")
	if state.wave != state.current_level:
		return _failure("Checkpoint level does not match its board")
	if not snapshot.levels is Array or snapshot.levels.size() != MAX_LEVELS.size():
		return _failure("Invalid upgrade levels")
	state.levels = []
	for i in range(MAX_LEVELS.size()):
		if not _integer(snapshot.levels[i], 0, MAX_LEVELS[i]):
			return _failure("Invalid upgrade level")
		state.levels.append(int(snapshot.levels[i]))
	state.trial_active = snapshot.trial_active
	if game.area_id=="crystal":
		var crystal=CrystalLauncher.validate_extra(snapshot,state,game)
		if not crystal.ok: return _failure("Invalid Crystal run state")
		for key in CRYSTAL_FIELDS: state[key]=crystal[key]
	if state.trial_active:
		if state.wave not in [4, 8, 12] or state.levels != TRIAL_LEVELS or state.twin_launchers or state.power_reset_tier!=0 or game.highest_unlocked < 4:
			return _failure("Invalid trial configuration")
	elif state.current_level != game.current_level or state.levels != game.levels or state.twin_launchers != game.twin_launchers or state.power_reset_tier != game.power_reset_tier or state.current_level > game.highest_unlocked:
		return _failure("Checkpoint does not match campaign progress")
	var slot_limit = 2 if state.trial_active or game.highest_unlocked >= 4 else 1
	if not snapshot.equipped is Array or snapshot.equipped.size() > slot_limit:
		return _failure("Invalid equipped modules")
	state.equipped = []
	for kind in snapshot.equipped:
		if not kind is String or kind not in MODULES or kind in state.equipped:
			return _failure("Invalid or repeated equipped module")
		if state.levels[MODULES.find(kind) + 3] <= 0:
			return _failure("Equipped module is locked")
		state.equipped.append(kind)
	if not state.trial_active and state.equipped != game.equipped:
		return _failure("Checkpoint loadout does not match campaign progress")
	for key in ["force_special", "queued_special"]:
		if not snapshot[key] is String or snapshot[key] not in ["", "ricochet", "splitter", "impact"]:
			return _failure("Invalid queued module")
		state[key] = snapshot[key]
	if state.queued_special != "" and state.queued_special not in state.equipped:
		return _failure("Queued module is not equipped")
	if state.force_special != "" and state.levels[MODULES.find(state.force_special) + 3] <= 0:
		return _failure("Forced module is locked")
	if not _keys_match(snapshot.module_cooldowns, MODULES):
		return _failure("Invalid module cooldown fields")
	state.module_cooldowns = {}
	for kind in MODULES:
		if not _number(snapshot.module_cooldowns[kind], -90.0, 16.0):
			return _failure("Invalid module cooldown")
		state.module_cooldowns[kind] = float(snapshot.module_cooldowns[kind])
	if state.queued_special != "" and state.module_cooldowns[state.queued_special] > 0:
		return _failure("Queued module is still cooling down")
	for key in ["special_stats", "type_drops"]:
		var keys = STATS_KEYS if key == "special_stats" else BALL_KINDS
		if not _keys_match(snapshot[key], keys):
			return _failure("Invalid statistic fields: " + key)
		state[key] = {}
		for kind in keys:
			if not _integer(snapshot[key][kind], 0, 10000):
				return _failure("Invalid statistic counter")
			state[key][kind] = int(snapshot[key][kind])
	if _sum_values(state.special_stats) != state.destroyed or _sum_values(state.type_drops) != state.total_spawned:
		return _failure("Checkpoint counters are inconsistent")
	if state.combo > state.max_combo or state.max_combo > state.destroyed:
		return _failure("Checkpoint combo is inconsistent")
	var total_time = game.BASE_SECONDS + state.levels[7] * game.CLOCK_STEP + state.time_bonus
	if absf(state.remaining + state.run_elapsed - total_time) > 0.001:
		return _failure("Checkpoint clock is inconsistent")
	if not snapshot.pegs is Array or snapshot.pegs.is_empty() or snapshot.pegs.size() > MAX_PEGS:
		return _failure("Invalid peg count")
	var spec = game.board_data[state.wave - 1] if state.wave <= game.board_data.size() else {}
	if not spec is Dictionary:
		return _failure("Board specification is unavailable")
	var expected_count = int(spec.get("peg_count", 24 + mini(22, (state.wave - 1) * 2)))
	if snapshot.pegs.size() != expected_count:
		return _failure("Checkpoint peg count does not match its board")
	var family = str(spec.get("family", "broadstagger"))
	var base_hp = float(spec.get("base_hp", 1.0 + (state.wave - 1) * 0.12))
	if state.trial_active: base_hp = float(spec.get("trial_base_hp",base_hp))
	var clock_count = int(spec.get("clock_peg_count", 0 if state.wave == 1 else 2))
	var armor_count = int(spec.get("armored_count", 1 if state.wave >= 10 else 0))
	state.pegs = []
	var dead_pegs = 0
	for i in range(snapshot.pegs.size()):
		var peg = snapshot.pegs[i]
		if not _keys_match(peg, ["p", "hp", "max", "kind", "flash"]):
			return _failure("Invalid peg fields")
		if not _vector(peg.p, -100.0, 900.0) or not peg.kind is String or peg.kind not in PEG_KINDS:
			return _failure("Invalid peg position or kind")
		if not _number(peg.max, 0.001, 10000.0) or not _number(peg.hp, -10000.0, float(peg.max)) or not _number(peg.flash, 0.0, 0.12):
			return _failure("Invalid peg health or flash")
		var expected_kind = "normal"
		if armor_count > 0 and i < armor_count:
			expected_kind = "armored"
		elif i >= expected_count - clock_count:
			expected_kind = "clock"
		elif state.wave >= 3 and i % 13 == 7:
			expected_kind = "prism"
		var expected_hp = base_hp * (float(spec.get("armored_hp_multiplier", 2.5)) if expected_kind == "armored" else 1.0)
		var position = Vector2(float(peg.p[0]), float(peg.p[1]))
		if peg.kind != expected_kind or absf(float(peg.max) - expected_hp) > 0.00001 or position.distance_squared_to(game.board_peg_position(i, spec)) > 0.00001:
			return _failure("Checkpoint pegs do not match their board")
		state.pegs.append({"p": position, "hp": float(peg.hp), "max": float(peg.max), "kind": peg.kind, "flash": float(peg.flash)})
		if peg.hp <= 0:
			dead_pegs += 1
	if (dead_pegs == state.pegs.size()) != state.clear_draining:
		return _failure("Checkpoint clear phase does not match its board")
	if dead_pegs != state.destroyed:
		return _failure("Destroyed peg count is inconsistent")
	var ball_limit = MAX_DRAIN_BALLS if state.clear_draining else MAX_BALLS
	if not snapshot.balls is Array or snapshot.balls.size() > ball_limit or snapshot.balls.size() > state.total_spawned:
		return _failure("Invalid ball count")
	state.balls = []
	for ball in snapshot.balls:
		if not _keys_match(ball, ["p", "v", "kind", "r", "used", "productive", "cool", "life", "dead"]):
			return _failure("Invalid ball fields")
		if not _vector(ball.p, -100.0, 1500.0) or not _vector(ball.v, -10000.0, 10000.0):
			return _failure("Invalid ball position or velocity")
		if game.area_id=="crystal" and absf(Vector2(float(ball.v[0]),float(ball.v[1])).length()-game.crystal_launcher.speed())>.05:
			return _failure("Crystal ball speed does not match its straight-flight rules")
		if not ball.kind is String or ball.kind not in BALL_KINDS:
			return _failure("Invalid ball kind")
		var current_radius=game.ball_radius(ball.kind)
		var legacy_pumpkin=ball.kind=="impact" and _number(ball.r,9.0,9.0)
		if not _number(ball.r, 6.0, 11.25) or (float(ball.r)!=current_radius and not legacy_pumpkin):
			return _failure("Invalid ball radius")
		if not _number(ball.cool, -90.0, 0.08) or not _number(ball.life, 0.0, 90.0 if state.clear_draining else 16.1):
			return _failure("Invalid ball lifetime or cooldown")
		for key in ["used", "productive", "dead"]:
			if not ball[key] is bool:
				return _failure("Invalid ball flag")
		if ball.dead:
			return _failure("Removed ball cannot be resumed")
		# Previous impact balls did not mark their first hit as used. A productive
		# legacy impact has already hit a peg and must not regain its crush.
		var special_used=ball.used or (legacy_pumpkin and ball.productive)
		state.balls.append({"p": Vector2(float(ball.p[0]), float(ball.p[1])), "v": Vector2(float(ball.v[0]), float(ball.v[1])), "kind": ball.kind, "r": current_radius, "used": special_used, "productive": ball.productive, "cool": float(ball.cool), "life": float(ball.life), "dead": ball.dead})
	if state.clear_draining and state.balls.is_empty() and state.catch_settle_remaining <= 0:
		return _failure("A completed drain must be stored as a result")
	if not snapshot.pickups is Array or snapshot.pickups.size() > MAX_PICKUPS:
		return _failure("Invalid pickup count")
	if game.area_id=="crystal" and not snapshot.pickups.is_empty():
		return _failure("Crystal uses Prism offers instead of time pickups")
	state.pickups = []
	for pickup in snapshot.pickups:
		if not _keys_match(pickup, ["p", "life"]) or not _vector(pickup.p, 0.0, 900.0) or not _number(pickup.life, 0.0, 4.0):
			return _failure("Invalid pickup")
		# A tapped pickup can have life=0 until the next physics tick.
		state.pickups.append({"p": Vector2(float(pickup.p[0]), float(pickup.p[1])), "life": float(pickup.life)})
	if not snapshot.buckets is Array or snapshot.buckets.size() != MAX_BINS:
		return _failure("Invalid bin count")
	state.buckets = []
	var gold_bins = 0
	var bin_hits = 0
	for bucket in snapshot.buckets:
		if not _keys_match(bucket, ["hits", "gold"]) or not _integer(bucket.hits, 0, 10000) or not bucket.gold is bool:
			return _failure("Invalid bin")
		state.buckets.append({"hits": int(bucket.hits), "gold": bucket.gold})
		bin_hits += int(bucket.hits)
		if bucket.gold:
			gold_bins += 1
	if gold_bins != 1 or bin_hits > state.total_spawned:
		return _failure("Checkpoint bins are inconsistent")
	# Schema 1 saves remain resumable, but manual attacks and queued/guaranteed
	# specials were removed. Preserve the exact RNG state and earned statistics.
	state.force_special = ""
	state.queued_special = ""
	state.module_cooldowns = {"ricochet":0.0,"splitter":0.0,"impact":0.0}
	state.pulse_charge = 0.0
	state.level_won = state.clear_draining
	state.shift_claimed = false
	return {"ok": true, "reason": "", "state": state}

static func _encode(value):
	if value is Vector2:
		return [value.x, value.y]
	if value is Array:
		var encoded = []
		for item in value:
			encoded.append(_encode(item))
		return encoded
	if value is Dictionary:
		var encoded = {}
		for key in value:
			encoded[key] = _encode(value[key])
		return encoded
	return value

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "state": {}}

static func _keys_match(value, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

static func _credits(value, minimum: float, maximum: float) -> bool:
	if not _number(value, minimum, maximum):
		return false
	var cents = float(value) * 100.0
	return absf(cents - roundf(cents)) <= 0.00001

static func _vector(value, minimum: float, maximum: float) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], minimum, maximum) and _number(value[1], minimum, maximum)

static func _int64_string(value) -> bool:
	if not value is String or value.is_empty() or value.length() > 20:
		return false
	var negative = value.begins_with("-")
	var digits = value.substr(1) if negative else value
	if digits.is_empty() or digits.length() > 19:
		return false
	if digits.length() > 1 and digits.begins_with("0"):
		return false
	if negative and digits == "0":
		return false
	for index in range(digits.length()):
		if digits.unicode_at(index) < 48 or digits.unicode_at(index) > 57:
			return false
	# Check lexically before to_int(): Godot logs errors for overflow strings.
	var maximum = "9223372036854775808" if negative else "9223372036854775807"
	return digits.length() < 19 or digits <= maximum

static func _valid_run_id(value) -> bool:
	if not value is String or value.is_empty() or value.length() > 128 or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 33 or value.unicode_at(index) > 126:
			return false
	return true

static func _sum_values(value: Dictionary) -> int:
	var total = 0
	for entry in value.values():
		total += int(entry)
	return total
