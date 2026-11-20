extends Node
## Native ad policy and durable, run-bound reward receipts. No simulated outcomes.
signal availability_changed
signal reward_committed(area_id: String, run_id: String)
signal request_finished(request_id: String, outcome: Dictionary)
const Provider = preload("res://scripts/admob_provider.gd")
const ATTEMPTS_REQUIRED = 4
const COOLDOWN_SECONDS = 120.0
const MAX_SERIAL = 9007199254740990
const MAX_RECEIPTS = 256
var provider: Node
var persist: Callable
var context_valid: Callable
var attempts = 0
var active_seconds = 0.0
var last_counted_run = ""
var serial = 0
var pending: Dictionary = {}
var receipts: Array = []
var message = ""
var _durable: Dictionary = {}
var _started = false
var _enabled = false
var _suspended = false
var _retry_save = 0.0
var _automatic_ads_allowed: Callable

func _init(native_provider: Node = null, persist_state: Callable = Callable(), validate_context: Callable = Callable(), automatic_ads_allowed: Callable = Callable()):
	provider=native_provider
	persist=persist_state
	context_valid=validate_context
	_automatic_ads_allowed=automatic_ads_allowed

func initialize(config: Dictionary = {}) -> bool:
	if _started: return _enabled
	_started=true
	if provider==null: provider=Provider.new()
	provider.reward_earned.connect(_on_reward_earned)
	provider.request_finished.connect(_on_request_finished)
	provider.availability_changed.connect(_on_availability_changed)
	add_child(provider)
	_enabled=provider.initialize(config)
	availability_changed.emit()
	return _enabled

func enabled() -> bool:
	return _enabled

func has_pending() -> bool:
	return not pending.is_empty()

func status() -> Dictionary:
	var result=provider.status() if provider!=null else {}
	result["enabled"]=_enabled
	result["message"]=message
	result["pending"]=has_pending()
	return result

func is_ready(kind: String) -> bool:
	return _enabled and not _suspended and pending.is_empty() and _placement_allowed(kind) and provider.is_ready(kind)

func _placement_allowed(kind: String) -> bool:
	return kind!="interstitial" or not _automatic_ads_allowed.is_valid() or _automatic_ads_allowed.call()==true

func advance_campaign_play(delta: float):
	if _enabled and not _suspended and is_finite(delta) and delta>0:
		active_seconds=minf(COOLDOWN_SECONDS,active_seconds+delta)

func complete_attempt(run_id: String):
	if not _enabled or not _valid_id(run_id) or run_id==last_counted_run: return
	last_counted_run=run_id
	attempts=mini(ATTEMPTS_REQUIRED,attempts+1)

func automatic_eligible() -> bool:
	return attempts>=ATTEMPTS_REQUIRED and active_seconds>=COOLDOWN_SECONDS and is_ready("interstitial")

func has_reward(area_id: String, run_id: String) -> bool:
	for receipt in receipts:
		if receipt.area_id==area_id and receipt.run_id==run_id and _durable.has(receipt.id): return true
	return false

func has_unsaved_reward(area_id: String, run_id: String) -> bool:
	for receipt in receipts:
		if receipt.area_id==area_id and receipt.run_id==run_id and not _durable.has(receipt.id): return true
	return false

func request(kind: String, area_id: String, run_id: String, profile: String) -> bool:
	message=""
	if kind not in ["rewarded","interstitial"] or not _valid_id(run_id) or area_id not in ["bakery","gelato","crystal"] or profile.is_empty(): return false
	if kind=="rewarded" and (has_reward(area_id,run_id) or has_unsaved_reward(area_id,run_id)): return false
	if not _placement_allowed(kind): return false
	if not is_ready(kind):
		message=unavailable_message(kind)
		availability_changed.emit()
		return false
	if kind=="interstitial" and not automatic_eligible(): return false
	if serial>=MAX_SERIAL: return false
	var before=export_state()
	serial+=1
	pending={"id":"native-ad-%d-%d-%d" % [serial,get_instance_id(),Time.get_ticks_usec()],"kind":kind,"area_id":area_id,"run_id":run_id,"profile":profile}
	if not _context_matches(): pending.clear();return false
	# Persist the consumed cadence and request serial before native playback.
	attempts=0;active_seconds=0.0
	if not _persist():
		pending.clear();import_state(before)
		message="Progress could not be saved. Try again."
		availability_changed.emit();return false
	var id: String=pending.id
	# Purchase status can change while the pre-playback save is being written.
	var suppressed=not _placement_allowed(kind)
	if suppressed or not provider.show(kind,id,run_id):
		pending.clear();import_state(before);_persist()
		if not suppressed: message=unavailable_message(kind)
		availability_changed.emit();return false
	return true

func unavailable_message(kind: String = "rewarded") -> String:
	if not _enabled: return "Ads are unavailable on this device."
	var state=provider.status()
	if not state.get("consent_error","").is_empty(): return "Ad privacy setup is unavailable. Try again later."
	if not state.get("errors",{}).get(kind,{}).is_empty(): return "No ad available. Try again later."
	return "Ad loading. Try again shortly."

func show_privacy_options() -> bool:
	return _enabled and provider.show_privacy_options()

func set_suspended(value: bool):
	_suspended=value
	if provider!=null: provider.set_suspended(value)

func _process(delta: float):
	if _suspended or not is_finite(delta) or delta<=0: return
	_retry_save=maxf(0,_retry_save-delta)
	if _retry_save>0: return
	for receipt in receipts:
		if not _durable.has(receipt.id):
			_retry_save=1.0
			_commit_receipts()
			break

func _context_matches() -> bool:
	return not pending.is_empty() and (not context_valid.is_valid() or context_valid.call(pending.duplicate(true))==true)

func _persist() -> bool:
	return persist.is_valid() and persist.call()==true

func _on_reward_earned(id: String, _reward: Dictionary):
	if pending.is_empty() or pending.id!=id or pending.kind!="rewarded" or not _context_matches(): return
	for receipt in receipts:
		if receipt.id==id: return
	receipts.append({"id":id,"area_id":pending.area_id,"run_id":pending.run_id})
	while receipts.size()>MAX_RECEIPTS:
		_durable.erase(receipts[0].id);receipts.pop_front()
	_commit_receipts()

func _commit_receipts():
	if not _persist():
		message="Bonus earned. Saving progress…"
		availability_changed.emit();return
	for receipt in receipts:
		if _durable.has(receipt.id): continue
		_durable[receipt.id]=true
		reward_committed.emit(receipt.area_id,receipt.run_id)
	message=""
	availability_changed.emit()

func _on_request_finished(id: String, outcome: Dictionary):
	if pending.is_empty() or pending.id!=id: return
	var binding=pending.duplicate(true)
	var matches=_context_matches()
	pending.clear()
	var result=outcome.duplicate(true)
	result["area_id"]=binding.area_id;result["run_id"]=binding.run_id;result["profile"]=binding.profile
	# The terminal outcome cannot invent a receipt; only reward_earned can do so.
	result["granted"]=matches and binding.kind=="rewarded" and has_reward(binding.area_id,binding.run_id)
	if not matches: result["status"]="cancelled"
	if binding.kind=="rewarded" and not result.granted:
		message="Ad closed. No bonus added." if result.get("status","")=="cancelled" else "Ad unavailable. No bonus added."
	_persist()
	request_finished.emit(id,result)
	availability_changed.emit()

func _on_availability_changed():
	if provider!=null and provider.is_ready("rewarded") and pending.is_empty():
		var unsaved=false
		for receipt in receipts:
			if not _durable.has(receipt.id): unsaved=true;break
		if not unsaved: message=""
	availability_changed.emit()

func export_state() -> Dictionary:
	# In-flight ads are excluded: a restart never completes an unfinished ad.
	return {"version":1,"attempts":attempts,"active_seconds":active_seconds,"last_counted_run":last_counted_run,"serial":serial,"receipts":receipts.duplicate(true)}

func import_state(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty(): return false
	if not _integer(value.get("version"),1,1) or not _integer(value.get("attempts"),0,ATTEMPTS_REQUIRED) or not _number(value.get("active_seconds"),0,COOLDOWN_SECONDS) or not _integer(value.get("serial"),0,MAX_SERIAL): return false
	if not value.get("last_counted_run",null) is String or value.last_counted_run.length()>256: return false
	if not value.get("receipts",null) is Array or value.receipts.size()>MAX_RECEIPTS: return false
	var ids={}
	for receipt in value.receipts:
		if not receipt is Dictionary or not _valid_id(receipt.get("id")) or not _valid_id(receipt.get("run_id")) or receipt.get("area_id") not in ["bakery","gelato","crystal"] or ids.has(receipt.id): return false
		ids[receipt.id]=true
	attempts=int(value.attempts);active_seconds=float(value.active_seconds);serial=int(value.serial)
	last_counted_run=value.last_counted_run;receipts=value.receipts.duplicate(true);_durable=ids
	pending.clear()
	return true

func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length()<=256

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high

func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,float(low),float(high)) and float(value)==floorf(float(value))
