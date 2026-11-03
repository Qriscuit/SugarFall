extends RefCounted
## Local, deterministic monetization policy and fake provider. No network or money.
## The caller advances active campaign play only and offers an interstitial once
## at each completed result. This service never queues an unavailable advert.
## Provider requests have opaque IDs; only the current request may resolve.

const ATTEMPTS_REQUIRED: int = 4
const COOLDOWN_SECONDS: float = 120.0
const PRODUCTS: Dictionary = {
	"remove_ads": {
		"name": "Remove Automatic Ads",
		"description": "Skip automatic ads. Optional rewarded ads remain available.",
	},
	"baker_toolkit": {
		"name": "Baker Toolkit",
		"description": "Earn 20% more normal campaign credits.",
		"earnings_multiplier": 1.2,
	},
}
const STATE_VERSION: int = 1
# JSON stores numbers as doubles; stay within its exact integer range.
const MAX_SERIAL: int = 9007199254740990
const MAX_RUN_ID_LENGTH: int = 256

var attempts: int = 0
var active_seconds: float = 0.0
var last_counted_run: String = ""
var entitlements: Dictionary = {"remove_ads": false, "baker_toolkit": false}
var store_owned: Dictionary = {"remove_ads": false, "baker_toolkit": false}
var pending: Dictionary = {}
var serial: int = 0
var ads_available: bool = true
var _request_epoch: int = 0
var _simulation_enabled: bool = false

static func preview_tools_allowed() -> bool:
	# An explicit public feature also protects diagnostic/debug RC exports.
	return not OS.has_feature("sugarfall_public") and (OS.is_debug_build() or OS.has_feature("developer"))

func _init(allow_simulation: bool = true):
	_simulation_enabled = allow_simulation and preview_tools_allowed()
	ads_available = _simulation_enabled

func simulation_enabled() -> bool:
	return _simulation_enabled

func advance(dt: float) -> void:
	if not _simulation_enabled: return
	# Background, menus, ads and practice must never be passed here by the caller.
	if is_finite(dt) and dt > 0.0:
		active_seconds = minf(COOLDOWN_SECONDS, active_seconds + dt)


func complete_attempt(run_id: String) -> bool:
	if not _simulation_enabled: return false
	# Campaign results are finalized in order. Keep the last ID across restarts so
	# reopening/resuming the same result cannot count it a second time.
	if run_id.is_empty() or run_id.length() > MAX_RUN_ID_LENGTH or run_id == last_counted_run:
		return false
	last_counted_run = run_id
	attempts = mini(ATTEMPTS_REQUIRED, attempts + 1)
	return true


func eligible() -> bool:
	return _simulation_enabled and attempts >= ATTEMPTS_REQUIRED and active_seconds >= COOLDOWN_SECONDS and not entitlements["remove_ads"]


func request(kind: String, context: String = "") -> Dictionary:
	if not _simulation_enabled or not pending.is_empty() or serial >= MAX_SERIAL:
		return {}
	match kind:
		"interstitial":
			if not eligible() or not ads_available:
				return {}
		"rewarded":
			if context.is_empty() or context.length() > MAX_RUN_ID_LENGTH or not ads_available:
				return {}
		"purchase":
			if not PRODUCTS.has(context) or entitlements[context] or store_owned[context]:
				return {}
		_:
			return {}
	serial += 1
	pending = {
		"id": "test-%d-%d-%d" % [get_instance_id(), _request_epoch, serial],
		"kind": kind,
		"context": context,
	}
	if kind == "interstitial" or kind == "rewarded":
		# A ready request opens the simulated full-screen ad. Even an early close
		# was an interruption, so both ad types restart the shared cadence now.
		attempts = 0
		active_seconds = 0.0
	# Never hand out a mutable reference to the actual in-flight request.
	return pending.duplicate(true)


func resolve(request_id: String, outcome: String) -> Dictionary:
	if not _simulation_enabled or pending.is_empty() or pending["id"] != request_id:
		return {}
	if outcome not in ["completed", "cancelled", "unavailable", "pending", "failed"]:
		return {}
	var kind: String = pending["kind"]
	if outcome == "pending" and kind != "purchase":
		return {}
	var result: Dictionary = pending.duplicate(true)
	result["outcome"] = outcome
	result["granted"] = false
	if outcome == "pending":
		# A pending payment grants nothing. Keep its ID so the test panel can
		# deliver the eventual completed/cancelled/failed provider callback.
		return result
	if outcome == "completed":
		if kind == "rewarded":
			result["granted"] = true
		elif kind == "purchase":
			var product_id: String = pending["context"]
			if not entitlements[product_id] and not store_owned[product_id]:
				store_owned[product_id] = true
				entitlements[product_id] = true
				result["granted"] = true
	pending.clear()
	return result


func restore_purchases() -> bool:
	if not _simulation_enabled: return false
	# Returns whether this restore changed local ownership. The fake store is
	# separate from entitlements so tests can remove local access then restore it.
	var changed: bool = false
	for product_id in PRODUCTS:
		if store_owned[product_id] and not entitlements[product_id]:
			entitlements[product_id] = true
			changed = true
	return changed


func reset_test_state() -> void:
	attempts = 0
	active_seconds = 0.0
	last_counted_run = ""
	entitlements = {"remove_ads": false, "baker_toolkit": false}
	store_owned = {"remove_ads": false, "baker_toolkit": false}
	pending.clear()
	ads_available = _simulation_enabled
	# Preserve the monotonically increasing serial and rotate the request epoch
	# so a callback held by a test cannot resolve an unrelated request after reset.
	_request_epoch += 1


func export_state() -> Dictionary:
	if not _simulation_enabled: return {}
	# In-flight requests are deliberately excluded. Restarting never completes
	# an advert or payment, and no reward is inferred from a saved request.
	return {
		"version": STATE_VERSION,
		"attempts": attempts,
		"active_seconds": active_seconds,
		"last_counted_run": last_counted_run,
		"entitlements": entitlements.duplicate(true),
		"store_owned": store_owned.duplicate(true),
		"serial": serial,
		"ads_available": ads_available,
	}


func import_state(data: Variant) -> bool:
	# Preview ownership is never production purchase verification. Public RCs
	# retain gameplay records while discarding this independent optional field.
	if not _simulation_enabled:
		reset_test_state()
		return false
	# Validate the entire snapshot before applying any of it. Integer-valued
	# JSON floats are accepted for counters; purchases require actual booleans.
	if not data is Dictionary:
		return false
	for key in ["version", "attempts", "active_seconds", "last_counted_run", "entitlements", "store_owned", "serial", "ads_available"]:
		if not data.has(key):
			return false
	if not _integer_in_range(data["version"], STATE_VERSION, STATE_VERSION):
		return false
	if not _integer_in_range(data["attempts"], 0, ATTEMPTS_REQUIRED):
		return false
	if not _number_in_range(data["active_seconds"], 0.0, COOLDOWN_SECONDS):
		return false
	if not _integer_in_range(data["serial"], 0, MAX_SERIAL):
		return false
	if not data["last_counted_run"] is String or data["last_counted_run"].length() > MAX_RUN_ID_LENGTH:
		return false
	if not _valid_ownership(data["entitlements"]) or not _valid_ownership(data["store_owned"]):
		return false
	if not data["ads_available"] is bool:
		return false
	attempts = int(data["attempts"])
	active_seconds = float(data["active_seconds"])
	last_counted_run = data["last_counted_run"]
	entitlements = data["entitlements"].duplicate(true)
	store_owned = data["store_owned"].duplicate(true)
	serial = int(data["serial"])
	ads_available = data["ads_available"]
	pending.clear()
	_request_epoch += 1
	return true


func _valid_ownership(value: Variant) -> bool:
	if not value is Dictionary or value.size() != PRODUCTS.size():
		return false
	for product_id in PRODUCTS:
		if not value.has(product_id) or not value[product_id] is bool:
			return false
	return true


func _number_in_range(value: Variant, lower: float, upper: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= lower and float(value) <= upper


func _integer_in_range(value: Variant, lower: int, upper: int) -> bool:
	return _number_in_range(value, float(lower), float(upper)) and float(value) == floorf(float(value))
