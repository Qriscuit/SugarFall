@tool
extends RefCounted
## The game and Android manifest exporter read the same profile-specific AdMob config.
const PRODUCTION_PATH = "res://data/production_ads.json"
const PREVIEW_PATH = "res://data/preview_ads.json"
const PUBLIC_FEATURE = "sugarfall_public"
const DEMO_PUBLISHER = "3940256099942544"
const DEMO_APP = "ca-app-pub-3940256099942544~3347511713"
const DEMO_REWARDED = "ca-app-pub-3940256099942544/5224354917"
const DEMO_INTERSTITIAL = "ca-app-pub-3940256099942544/1033173712"

static func read(production: bool) -> Dictionary:
	var path = PRODUCTION_PATH if production else PREVIEW_PATH
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func valid(config: Dictionary, production: bool) -> bool:
	if not config.get("enabled") is bool or not config.enabled:
		return false
	var test_mode = config.get("use_test_ads")
	if not test_mode is bool or test_mode != (not production):
		return false
	var consent = config.get("consent", {})
	if not consent is Dictionary or not consent.get("tag_for_under_age_of_consent", false) is bool:
		return false
	if not config.get("muted", false) is bool or config.get("max_ad_content_rating", "PG") not in ["G", "PG", "T", "MA"]:
		return false
	for key in ["tag_for_child_directed_treatment", "tag_for_under_age_of_consent"]:
		var tag = config.get(key, -1)
		if not (tag is int or tag is float) or float(tag) not in [-1.0, 0.0, 1.0]:
			return false
	if not production:
		var geography = consent.get("debug_geography", 0)
		return config.get("app_id") == DEMO_APP and config.get("rewarded_unit_id") == DEMO_REWARDED and config.get("interstitial_unit_id") == DEMO_INTERSTITIAL \
			and config.get("test_device_ids", []) is Array and consent.get("test_device_hashed_ids", []) is Array \
			and (geography is int or geography is float) and float(geography) in [0.0, 1.0, 2.0, 3.0]
	if config.has("test_device_ids") or consent.has("test_device_hashed_ids") or consent.has("debug_geography"):
		return false
	var id_pattern = RegEx.create_from_string(r"\Aca-app-pub-([0-9]{16})([~/])[0-9]{10}\z")
	var publisher = _publisher(config.get("app_id"), "~", id_pattern)
	return not publisher.is_empty() and publisher != DEMO_PUBLISHER \
		and _publisher(config.get("rewarded_unit_id"), "/", id_pattern) == publisher \
		and _publisher(config.get("interstitial_unit_id"), "/", id_pattern) == publisher \
		and config.rewarded_unit_id != config.interstitial_unit_id

static func _publisher(id: Variant, separator: String, pattern: RegEx) -> String:
	if not id is String:
		return ""
	var id_match = pattern.search(id)
	return id_match.get_string(1) if id_match and id_match.get_string(2) == separator else ""
