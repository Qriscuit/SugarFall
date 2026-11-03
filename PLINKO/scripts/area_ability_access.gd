extends RefCounted
## Earned upgrades belong to area progression. This service owns early access only.
## Preview receipts are test data, never a public Play purchase verification source.
const STATE_VERSION = 1
const EARN_TRAY = 8
const DESIGN_PRICE_USD = 2.99
const MAX_SERIAL = 9007199254740990
const CATALOG = {
	"bakery":{"title":"Jam Burst","product_id":"sugarfall_bakery_ability"},
	"gelato":{"title":"Dual Shot","product_id":"sugarfall_gelato_ability"},
	"crystal":{"title":"Second Prism","product_id":"sugarfall_crystal_ability"}}
var _preview = false
var _serial = 0
var _epoch = 0
var _preview_owned = {"bakery":false,"gelato":false,"crystal":false}
var _preview_receipts = {"bakery":false,"gelato":false,"crystal":false}
var _provider: RefCounted
var pending: Dictionary = {}

func _init(allow_preview: bool = true):
	_preview = allow_preview and preload("res://scripts/monetization_service.gd").preview_tools_allowed()

func preview_enabled() -> bool:
	return _preview

func bind_provider(provider: RefCounted) -> bool:
	# The provider must verify purchases independently; no save dictionary binds it.
	for method in ["has_entitlement","offer","purchase","restore"]:
		if provider==null or not provider.has_method(method): return false
	_provider=provider
	return true

func has_early_access(area: String) -> bool:
	if not CATALOG.has(area): return false
	if _provider!=null and _provider.has_entitlement(CATALOG[area].product_id): return true
	return _preview and _preview_owned[area]

func offer(area: String, earned: bool = false) -> Dictionary:
	if not CATALOG.has(area): return {}
	var live: Dictionary = _provider.offer(CATALOG[area].product_id) if _provider!=null else {}
	var owned = earned or has_early_access(area)
	var is_pending = not pending.is_empty() and pending.get("area")==area
	var live_ready = live.get("available",false)==true
	return {"area":area,"title":CATALOG[area].title,"product_id":CATALOG[area].product_id,
		"price_label":str(live.get("price_label","$2.99")),"price_is_live":live_ready,
		"owned":owned,"earned":earned,"available":not owned and pending.is_empty() and live.get("pending",false)!=true and (_preview or live_ready),
		"preview":_preview and not live_ready,"pending":is_pending or live.get("pending",false)==true,
		"description":"Earn from tray 8, or unlock early.",
		"error":"" if owned or _preview or live_ready else str(live.get("error","Google Play purchases are not connected yet."))}

func request_preview(area: String, earned: bool = false) -> Dictionary:
	if not _preview or not CATALOG.has(area) or earned or has_early_access(area) or not pending.is_empty() or _serial>=MAX_SERIAL:
		return {}
	# A restorable receipt should be restored, never sold a second time.
	if _preview_receipts[area]: return {}
	_serial+=1
	pending={"id":"ability-test-%d-%d-%d"%[get_instance_id(),_epoch,_serial],"area":area,"product_id":CATALOG[area].product_id,"outcome":"requested"}
	return pending.duplicate(true)

func request_purchase(area: String, earned: bool = false) -> Dictionary:
	if not CATALOG.has(area) or earned or has_early_access(area) or not pending.is_empty(): return {}
	var live: Dictionary = _provider.offer(CATALOG[area].product_id) if _provider!=null else {}
	if live.get("pending",false)==true: return {}
	if live.get("available",false)==true: return _provider.purchase(CATALOG[area].product_id)
	return request_preview(area,earned)

func resolve_preview(request_id: String, outcome: String, persist: Callable = Callable()) -> Dictionary:
	if not _preview or pending.is_empty() or pending.id!=request_id or outcome not in ["completed","pending","cancelled","failed","unavailable"]: return {}
	var result = pending.duplicate(true)
	result.outcome=outcome
	result.granted=false
	if outcome=="pending":
		pending.outcome="pending"
		return result
	var previous = export_state()
	var request = pending.duplicate(true)
	if outcome=="completed" and not _preview_receipts[result.area]:
		_preview_owned[result.area]=true
		_preview_receipts[result.area]=true
		result.granted=true
	pending.clear()
	if result.granted and persist.is_valid() and persist.call()!=true:
		_preview_owned=previous.preview_owned.duplicate(true)
		_preview_receipts=previous.preview_receipts.duplicate(true)
		pending=request
		result.granted=false
		result.outcome="save_failed"
	return result

func restore_preview(persist: Callable = Callable()) -> bool:
	if not _preview: return false
	var before = _preview_owned.duplicate(true)
	var changed = false
	for area in CATALOG:
		if _preview_receipts[area] and not _preview_owned[area]:
			_preview_owned[area]=true
			changed=true
	if changed and persist.is_valid() and persist.call()!=true:
		_preview_owned=before
		return false
	return changed

func restore() -> void:
	if _provider!=null: _provider.restore()

func clear_preview_benefits() -> void:
	if not _preview: return
	_preview_owned={"bakery":false,"gelato":false,"crystal":false}
	pending.clear()
	_epoch+=1

func reset_preview_store() -> void:
	if not _preview: return
	clear_preview_benefits()
	_preview_receipts={"bakery":false,"gelato":false,"crystal":false}

func cancel_pending_preview() -> void:
	if not _preview: return
	pending.clear()
	_epoch+=1

func export_state() -> Dictionary:
	if not _preview: return {}
	# Pending requests do not survive restart and cannot complete implicitly.
	return {"version":STATE_VERSION,"namespace":"area_ability_preview","serial":_serial,
		"preview_owned":_preview_owned.duplicate(true),"preview_receipts":_preview_receipts.duplicate(true)}

func import_state(data: Variant) -> bool:
	if not _preview: return false
	if not data is Dictionary or data.get("version")!=STATE_VERSION or data.get("namespace")!="area_ability_preview": return false
	var serial = data.get("serial")
	if not (serial is int or serial is float) or not is_finite(float(serial)) or serial<0 or serial>MAX_SERIAL or float(serial)!=floorf(float(serial)): return false
	if not _valid_ownership(data.get("preview_owned")) or not _valid_ownership(data.get("preview_receipts")): return false
	for area in CATALOG:
		if data.preview_owned[area] and not data.preview_receipts[area]: return false
	_preview_owned=data.preview_owned.duplicate(true)
	_preview_receipts=data.preview_receipts.duplicate(true)
	_serial=maxi(_serial,int(serial))
	pending.clear()
	_epoch+=1
	return true

func _valid_ownership(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=CATALOG.size(): return false
	for area in CATALOG:
		if not value.has(area) or not value[area] is bool: return false
	return true
