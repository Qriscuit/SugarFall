extends Node
## Production ad lifecycle. Rewards are accepted only from the native reward event.
## The game owns request IDs, run binding, persistence and whether an ad is offered.
signal availability_changed
signal request_finished(request_id: String, outcome: Dictionary)
signal reward_earned(request_id: String, reward: Dictionary)
signal consent_changed
const AdMobConfig = preload("res://scripts/admob_config.gd")
const REWARD_DISMISS_GRACE = 2.0
const LOAD_TIMEOUT = 45.0
const INITIALIZE_TIMEOUT = 45.0
const MAX_AD_AGE_MS = 2700000
var _adapter: RefCounted
var _config: Dictionary = {}
var _started = false
var _initialized = false
var _initializing = false
var _init_remaining = 0.0
var _consent_ready = false
var _consent_loading = false
var _consent_error = ""
var _privacy_required = false
var _privacy_open = false
var _suspended = false
var _closed = false
var _generation = 0
var _slots = {"rewarded":false,"interstitial":false}
var _load_tokens = {"rewarded":0,"interstitial":0}
var _loading = {"rewarded":false,"interstitial":false}
var _load_remaining = {"rewarded":0.0,"interstitial":0.0}
var _loaded_at = {"rewarded":0,"interstitial":0}
var _retry_remaining = {"rewarded":0.0,"interstitial":0.0}
var _retry_attempts = {"rewarded":0,"interstitial":0}
var _errors = {"rewarded":{},"interstitial":{}}
var _pending: Dictionary = {}
var _finished: Dictionary = {}

func _init(native_adapter: RefCounted = null):
	_adapter = native_adapter

func initialize(config: Dictionary = {}) -> bool:
	if _closed: return false
	if _started: return _adapter.available()
	var ads = config.get("ads", config)
	if not ads is Dictionary:
		_consent_error = "Ads are unavailable."
		availability_changed.emit();return false
	var test_mode = ads.get("use_test_ads")
	var production = OS.has_feature(AdMobConfig.PUBLIC_FEATURE) or (test_mode is bool and not test_mode)
	if not AdMobConfig.valid(ads, production):
		_consent_error = "Ads are unavailable."
		availability_changed.emit();return false
	if _adapter == null:
		if OS.get_name() != "Android" or not Engine.has_singleton("PoingGodotAdMob"):
			_consent_error = "Ads are unavailable on this device."
			availability_changed.emit();return false
		_adapter = load("res://scripts/admob_native_adapter.gd").new()
	if not _adapter.available():
		_consent_error = "The native ad service is unavailable."
		availability_changed.emit();return false
	_config = ads.duplicate(true)
	_started = true
	_adapter.consent_result.connect(_on_consent_result)
	_adapter.initialization_result.connect(_on_initialization_result)
	_adapter.ad_loaded.connect(_on_ad_loaded)
	_adapter.ad_load_failed.connect(_on_ad_load_failed)
	_adapter.ad_dismissed.connect(_on_ad_dismissed)
	_adapter.ad_rewarded.connect(_on_ad_rewarded)
	_adapter.ad_show_failed.connect(_on_ad_show_failed)
	_consent_loading=true
	_adapter.begin_consent(_config)
	return true

func is_initialized() -> bool:
	return _initialized and not _closed

func is_ready(kind: String) -> bool:
	return kind in _slots and _initialized and _consent_ready and not _privacy_open and not _closed and not _suspended and _pending.is_empty() and _slots[kind] and Time.get_ticks_msec()-_loaded_at[kind] < MAX_AD_AGE_MS

func status() -> Dictionary:
	return {"initialized":is_initialized(),"initializing":_initializing,"consent_ready":_consent_ready,"consent_loading":_consent_loading,
		"consent_error":_consent_error,"privacy_options_required":_privacy_required,"privacy_open":_privacy_open,
		"rewarded_ready":is_ready("rewarded"),"interstitial_ready":is_ready("interstitial"),
		"loading":_loading.duplicate(),"errors":_errors.duplicate(true),"pending":not _pending.is_empty(),
		"use_test_ads":_config.get("use_test_ads",false)==true,"native_available":_adapter!=null and _adapter.available()}

func show(kind: String, request_id: String, context: String = "") -> bool:
	if not is_ready(kind) or request_id.is_empty() or request_id.length()>256 or context.length()>256 or _finished.has(request_id): return false
	_pending={"id":request_id,"kind":kind,"context":context,"rewarded":false,"dismissed":false,"grace":-1.0,"reward":{}}
	_slots[kind]=false
	availability_changed.emit()
	if not _adapter.show_ad(kind,request_id,context):
		_finish("failed",{"message":"The ad could not be shown."})
	return true

func show_privacy_options() -> bool:
	if _closed or _adapter==null or not _privacy_required or _privacy_open or _consent_loading or not _pending.is_empty() or _suspended: return false
	_privacy_open=true
	availability_changed.emit();consent_changed.emit()
	_adapter.show_privacy_options()
	return true

func refresh_consent() -> bool:
	if _closed or not _started or not _pending.is_empty() or _privacy_open or _consent_loading or _suspended: return false
	_consent_ready=false;_consent_error=""
	_consent_loading=true
	for kind in _slots:
		_slots[kind]=false;_loading[kind]=false;_generation+=1;_load_tokens[kind]=_generation
		_adapter.discard(kind)
	availability_changed.emit();consent_changed.emit()
	_adapter.begin_consent(_config)
	return true

func set_suspended(value: bool):
	if _suspended==value: return
	_suspended=value;availability_changed.emit()
	if not value: _preload()

func shutdown():
	if _closed: return
	_closed=true;_initialized=false;_initializing=false;_generation+=1
	if not _pending.is_empty(): _finish("completed" if _pending.rewarded else "cancelled",{"message":"Ad request stopped."})
	if _adapter!=null: _adapter.shutdown()
	for kind in _slots: _slots[kind]=false;_loading[kind]=false
	availability_changed.emit()

func _exit_tree():
	shutdown()

func _process(delta: float):
	advance(delta)

func advance(delta: float):
	if _closed or _suspended or not is_finite(delta) or delta<=0: return
	if _initializing:
		_init_remaining-=delta
		if _init_remaining<=0:
			_initializing=false;_consent_error="The ad service did not respond. Try again later."
			availability_changed.emit()
	if not _pending.is_empty() and _pending.grace>=0:
		_pending.grace-=delta
		if _pending.grace<=0: _finish("completed" if _pending.rewarded else "cancelled")
	for kind in _slots:
		if _slots[kind] and Time.get_ticks_msec()-_loaded_at[kind]>=MAX_AD_AGE_MS:
			_slots[kind]=false;_adapter.discard(kind);availability_changed.emit()
		if _retry_remaining[kind]>0:
			_retry_remaining[kind]=maxf(0,_retry_remaining[kind]-delta)
		if _loading[kind]:
			_load_remaining[kind]-=delta
			if _load_remaining[kind]<=0:
				_on_ad_load_failed(kind,_load_tokens[kind],{"message":"The ad request timed out."})
	_preload()

func _on_consent_result(allowed: bool, privacy_required: bool, error: String):
	if _closed or (not _consent_loading and not _privacy_open): return
	_consent_loading=false
	_privacy_open=false;_consent_ready=allowed;_privacy_required=privacy_required;_consent_error=error
	if not allowed:
		for kind in _slots:
			_slots[kind]=false;_loading[kind]=false;_generation+=1;_load_tokens[kind]=_generation
			_adapter.discard(kind)
	elif not _initialized and not _initializing:
		_initializing=true;_init_remaining=INITIALIZE_TIMEOUT
		_adapter.initialize_sdk(_config)
	else: _preload()
	consent_changed.emit();availability_changed.emit()

func _on_initialization_result(error: String):
	if _closed or not _initializing: return
	_initializing=false;_initialized=error.is_empty()
	if not error.is_empty(): _consent_error=error
	availability_changed.emit()
	_preload()

func _preload():
	if not _initialized or not _consent_ready or _closed or _suspended or _privacy_open or not _pending.is_empty(): return
	for kind in _slots:
		if _slots[kind] or _loading[kind] or _retry_remaining[kind]>0: continue
		var unit: String = _config[kind + "_unit_id"]
		_generation+=1;_load_tokens[kind]=_generation;_loading[kind]=true;_load_remaining[kind]=LOAD_TIMEOUT
		_adapter.load_ad(kind,unit,_generation)

func _on_ad_loaded(kind: String, token: int):
	if _closed or kind not in _slots or token!=_load_tokens[kind] or not _loading[kind]: return
	_loading[kind]=false;_slots[kind]=true;_loaded_at[kind]=Time.get_ticks_msec()
	_retry_remaining[kind]=0;_retry_attempts[kind]=0;_errors[kind]={}
	availability_changed.emit()

func _on_ad_load_failed(kind: String, token: int, error: Dictionary):
	if _closed or kind not in _slots or token!=_load_tokens[kind] or not _loading[kind]: return
	_loading[kind]=false;_slots[kind]=false;_errors[kind]=error.duplicate(true)
	_retry_attempts[kind]+=1;_retry_remaining[kind]=minf(60.0,5.0*pow(2.0,mini(4,_retry_attempts[kind]-1)))
	_generation+=1;_load_tokens[kind]=_generation;_adapter.discard(kind)
	availability_changed.emit()

func _on_ad_rewarded(request_id: String, reward: Dictionary):
	if _closed or _pending.is_empty() or _pending.id!=request_id or _pending.kind!="rewarded" or _pending.rewarded: return
	_pending.rewarded=true;_pending.reward=reward.duplicate(true)
	# Persist this event in the game's request ledger before waiting for UI dismissal.
	reward_earned.emit(request_id,reward.duplicate(true))
	if _closed or _pending.is_empty() or _pending.id!=request_id: return
	if _pending.dismissed: _finish("completed")

func _on_ad_dismissed(request_id: String):
	if _closed or _pending.is_empty() or _pending.id!=request_id or _pending.dismissed: return
	_pending.dismissed=true
	if _pending.kind=="interstitial" or _pending.rewarded: _finish("completed")
	else: _pending.grace=REWARD_DISMISS_GRACE

func _on_ad_show_failed(request_id: String, error: Dictionary):
	if _closed or _pending.is_empty() or _pending.id!=request_id: return
	_finish("completed" if _pending.rewarded else "failed",error)

func _finish(outcome: String, error: Dictionary = {}):
	if _pending.is_empty(): return
	var request = _pending.duplicate(true)
	_pending.clear();_finished[request.id]=true
	while _finished.size()>256: _finished.erase(_finished.keys()[0])
	if _adapter!=null: _adapter.release(request.id)
	var granted = request.kind=="rewarded" and request.rewarded and outcome=="completed"
	request_finished.emit(request.id,{"status":outcome,"outcome":outcome,"kind":request.kind,"context":request.context,"granted":granted,"reward":request.reward,"error":error.duplicate(true)})
	availability_changed.emit();_preload()
