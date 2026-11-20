extends RefCounted
## Poing 5.1.0 v2 bridge, resolved against Google GMA Next-Gen 1.6.0.
## This adapter never uses the addon's editor mock factory as a production provider.
signal consent_result(allowed: bool, privacy_required: bool, error: String)
signal initialization_result(error: String)
signal ad_loaded(kind: String, token: int)
signal ad_load_failed(kind: String, token: int, error: Dictionary)
signal ad_dismissed(request_id: String)
signal ad_rewarded(request_id: String, reward: Dictionary)
signal ad_show_failed(request_id: String, error: Dictionary)
const Ads = preload("res://addons/admob/gdscript/src/api/MobileAds.gd")
const Ump = preload("res://addons/admob/gdscript/src/ump/api/UserMessagingPlatform.gd")
const ConsentInfo = preload("res://addons/admob/gdscript/src/ump/api/ConsentInformation.gd")
const ConsentParams = preload("res://addons/admob/gdscript/src/ump/core/ConsentRequestParameters.gd")
const ConsentDebug = preload("res://addons/admob/gdscript/src/ump/core/ConsentDebugSettings.gd")
const Configuration = preload("res://addons/admob/gdscript/src/api/core/RequestConfiguration.gd")
const InitListener = preload("res://addons/admob/gdscript/src/api/listeners/OnInitializationCompleteListener.gd")
const Request = preload("res://addons/admob/gdscript/src/api/core/AdRequest.gd")
const RewardLoader = preload("res://addons/admob/gdscript/src/api/RewardedAdLoader.gd")
const InterstitialLoader = preload("res://addons/admob/gdscript/src/api/InterstitialAdLoader.gd")
const RewardCallback = preload("res://addons/admob/gdscript/src/api/listeners/RewardedAdLoadCallback.gd")
const InterstitialCallback = preload("res://addons/admob/gdscript/src/api/listeners/InterstitialAdLoadCallback.gd")
const ContentCallback = preload("res://addons/admob/gdscript/src/api/listeners/FullScreenContentCallback.gd")
const RewardListener = preload("res://addons/admob/gdscript/src/api/listeners/OnUserEarnedRewardListener.gd")
var _config: Dictionary = {}
var _ads: Dictionary = {}
var _tokens = {"rewarded":0,"interstitial":0}
var _loaders: Dictionary = {}
var _load_callbacks: Dictionary = {}
var _active: Dictionary = {}
var _closed = false
var _session = 0

func available() -> bool:
	if OS.get_name()!="Android": return false
	for name in ["PoingGodotAdMob","PoingGodotAdMobRewardedAd","PoingGodotAdMobInterstitialAd","PoingGodotAdMobConsentInformation","PoingGodotAdMobUserMessagingPlatform"]:
		if not Engine.has_singleton(name): return false
	return true

func begin_consent(config: Dictionary):
	if not available(): consent_result.emit(false,false,"The native consent service is unavailable.");return
	_config=config.duplicate(true)
	var params = ConsentParams.new()
	var consent: Dictionary = config.get("consent",{})
	params.tag_for_under_age_of_consent=consent.get("tag_for_under_age_of_consent",false)==true
	if config.get("use_test_ads",false)==true and not consent.get("test_device_hashed_ids",[]).is_empty():
		var debug = ConsentDebug.new()
		debug.debug_geography=int(consent.get("debug_geography",0))
		for value in consent.get("test_device_hashed_ids",[]): debug.test_device_hashed_ids.append(str(value))
		params.consent_debug_settings=debug
	var session = _session
	Ump.consent_information.update(params,func(): _consent_updated(session),func(error): _consent_done(session,error.message))

func _consent_updated(session: int):
	if _closed or session!=_session: return
	# UMP determines whether a consent form is needed; no local consent boolean is trusted.
	if Ump.consent_information.get_consent_status() == ConsentInfo.ConsentStatus.REQUIRED:
		Ump.load_consent_form(func(form): form.show(func(error): _consent_done(session,"" if error==null else error.message)),func(error): _consent_done(session,error.message))
	else: _consent_done(session,"")

func _consent_done(session: int, error: String):
	if _closed or session!=_session: return
	var info = Ump.consent_information
	# The bridge exposes the two UMP statuses that permit requests after update.
	var allowed = info.get_consent_status() in [ConsentInfo.ConsentStatus.NOT_REQUIRED, ConsentInfo.ConsentStatus.OBTAINED]
	var privacy_required = info.get_privacy_options_requirement_status() == ConsentInfo.PrivacyOptionsRequirementStatus.REQUIRED
	consent_result.emit(allowed, privacy_required, error)

func show_privacy_options():
	if not available(): consent_result.emit(false,false,"The native consent service is unavailable.");return
	var session = _session
	Ump.show_privacy_options_form(func(error): _consent_done(session,"" if error==null else error.message))

func initialize_sdk(config: Dictionary):
	if not available(): initialization_result.emit("The native ad service is unavailable.");return
	var request_config = Configuration.new()
	request_config.max_ad_content_rating = str(config.get("max_ad_content_rating", "PG"))
	request_config.tag_for_child_directed_treatment = int(config.get("tag_for_child_directed_treatment", -1))
	request_config.tag_for_under_age_of_consent = int(config.get("tag_for_under_age_of_consent", -1))
	if config.get("use_test_ads", false) == true:
		for value in config.get("test_device_ids", []):
			request_config.test_device_ids.append(str(value))
	Ads.set_request_configuration(request_config)
	var listener = InitListener.new()
	var session = _session
	listener.on_initialization_complete=func(_status):
		if _closed or session!=_session: return
		Ads.set_app_muted(config.get("muted",false)==true)
		initialization_result.emit("")
	Ads.initialize(listener)

func load_ad(kind: String, unit_id: String, token: int):
	_tokens[kind]=token
	var callback = RewardCallback.new() if kind=="rewarded" else InterstitialCallback.new()
	var loader = RewardLoader.new() if kind=="rewarded" else InterstitialLoader.new()
	_load_callbacks[kind]=callback;_loaders[kind]=loader
	var session = _session
	callback.on_ad_loaded=func(ad):
		if _closed or session!=_session or token!=_tokens[kind]: ad.destroy();return
		_ads[kind]=ad
		_loaders.erase(kind);_load_callbacks.erase(kind)
		ad_loaded.emit(kind,token)
	callback.on_ad_failed_to_load=func(error):
		if _closed or session!=_session or token!=_tokens[kind]: return
		_loaders.erase(kind);_load_callbacks.erase(kind)
		ad_load_failed.emit(kind,token,_error(error))
	loader.load(unit_id,Request.new(),callback)

func show_ad(kind: String, request_id: String, _context: String) -> bool:
	if not available() or not _ads.has(kind) or not _active.is_empty(): return false
	var ad = _ads[kind]
	_ads.erase(kind)
	var content = ContentCallback.new()
	var session = _session
	content.on_ad_dismissed_full_screen_content=func():
		if not _closed and session==_session: ad_dismissed.emit(request_id)
	content.on_ad_failed_to_show_full_screen_content=func(error):
		if not _closed and session==_session: ad_show_failed.emit(request_id,_error(error))
	ad.full_screen_content_callback=content
	_active={"id":request_id,"kind":kind,"ad":ad,"content":content}
	if kind=="rewarded":
		var listener = RewardListener.new()
		listener.on_user_earned_reward=func(item):
			if not _closed and session==_session: ad_rewarded.emit(request_id,{"amount":item.amount,"type":item.type})
		_active.listener=listener
		ad.show(listener)
	else: ad.show()
	return true

func release(request_id: String):
	if not _active.is_empty() and _active.id==request_id:
		_active.ad.destroy();_active.clear()

func discard(kind: String):
	_tokens[kind]=-1
	if _ads.has(kind): _ads[kind].destroy();_ads.erase(kind)
	_loaders.erase(kind);_load_callbacks.erase(kind)

func shutdown():
	_closed=true;_session+=1
	for kind in ["rewarded","interstitial"]: discard(kind)
	if not _active.is_empty(): _active.ad.destroy();_active.clear()

func _error(error) -> Dictionary:
	return {"code":error.code,"domain":error.domain,"message":error.message}
