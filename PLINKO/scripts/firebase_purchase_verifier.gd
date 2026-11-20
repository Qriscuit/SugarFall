extends Node
## HTTPS purchase verification. Firebase authenticates requests; Google Play tokens
## identify permanent ownership, so a reinstall can restore with a fresh anonymous UID.
const ProductCatalog = preload("res://scripts/play_product_catalog.gd")
const PACKAGE = "com.sungati.sugarfall"
const PRODUCTS = ProductCatalog.PRODUCTS
const MAX_CREDENTIAL_LENGTH = 8192
const MAX_PROOF_TTL = 300.0
const AUTH_PATH = "user://commerce_auth.json"
signal authentication_finished(success: bool)
var _config: Dictionary = {}
var _id_token = ""
var _refresh_token = ""
var _expires_at = 0
var _authenticating = false
var _loaded_auth = false
var _generation = 0
var persist_auth = true
var error = "Purchase verification is not configured."

func configure(config: Dictionary) -> bool:
	_generation += 1
	var was_authenticating = _authenticating
	_authenticating = false
	var billing = config.get("billing",config)
	_config = billing.duplicate(true) if billing is Dictionary else {}
	_id_token = ""
	_refresh_token = ""
	_expires_at = 0
	_loaded_auth = false
	error = "" if is_configured() else "Purchase verification is not configured."
	# Release existing waiters; old network replies may not overwrite this config.
	if was_authenticating: authentication_finished.emit(false)
	return is_configured()

func _matches(value: String, pattern: String) -> bool:
	var expression = RegEx.new()
	return expression.compile(pattern)==OK and expression.search(value)!=null

func _valid_endpoint(endpoint) -> bool:
	if not endpoint is String or endpoint.length()>2048 or not _matches(endpoint,"^https://[A-Za-z0-9.-]+(?::443)?(?:/[A-Za-z0-9_./~%:-]*)?$"): return false
	var host = endpoint.substr(8).get_slice("/",0).trim_suffix(":443")
	if host.length()>253: return false
	for label in host.split("."):
		if not _matches(label,"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$"): return false
	return true

func is_configured() -> bool:
	var key = _config.get("firebase_web_api_key","")
	var project = _config.get("firebase_project_id","")
	return _valid_endpoint(_config.get("verification_url","")) and key is String and key.length()<=256 and _matches(key,"^[A-Za-z0-9_-]+$") and project is String and _matches(project,"^[a-z][a-z0-9-]{4,28}[a-z0-9]$")

func _new_http_request() -> HTTPRequest:
	var request = HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 65536
	# Neither Firebase credentials nor purchase tokens can follow a redirect.
	request.max_redirects = 0
	return request

func _post(url: String, data: Dictionary, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not url.begins_with("https://") or not is_inside_tree(): return {"ok":false,"error":"Verification service is unavailable."}
	var request = _new_http_request()
	add_child(request)
	var body = JSON.stringify(data)
	var content_type = "application/json"
	if url.begins_with("https://securetoken.googleapis.com/v1/token?"):
		content_type = "application/x-www-form-urlencoded"
		var pairs: PackedStringArray = []
		for key in data: pairs.append(str(key).uri_encode()+"="+str(data[key]).uri_encode())
		body = "&".join(pairs)
	var sent = request.request(url,headers+PackedStringArray(["Content-Type: "+content_type]),HTTPClient.METHOD_POST,body)
	if sent != OK:
		request.queue_free()
		return {"ok":false,"error":"Could not connect. Try Restore purchases."}
	var reply = await request.request_completed
	request.queue_free()
	if reply.size()!=4 or reply[0]!=HTTPRequest.RESULT_SUCCESS: return {"ok":false,"error":"Connection failed. Try Restore purchases."}
	var parsed = JSON.parse_string(reply[3].get_string_from_utf8())
	if int(reply[1])<200 or int(reply[1])>=300:
		return {"ok":false,"code":int(reply[1]),"data":parsed if parsed is Dictionary else {},"error":"Verification could not finish. Try Restore purchases."}
	if not parsed is Dictionary: return {"ok":false,"error":"Verification returned an invalid response."}
	return {"ok":true,"data":parsed}

func _load_refresh():
	if _loaded_auth: return
	_loaded_auth = true
	if not persist_auth or not FileAccess.file_exists(AUTH_PATH): return
	var file = FileAccess.open(AUTH_PATH,FileAccess.READ)
	if file==null or file.get_length()>16384: return
	var saved = JSON.parse_string(file.get_as_text())
	if saved is Dictionary and saved.get("version",0)==1 and saved.get("project_id","")==_config.get("firebase_project_id","") and _valid_credential(saved.get("refresh_token")):
		_refresh_token = saved.refresh_token

func _save_refresh():
	if not persist_auth or _refresh_token.is_empty(): return
	# App-private credential file is separate from game saves and export inputs.
	var file = FileAccess.open(AUTH_PATH+".tmp",FileAccess.WRITE)
	if file==null: return
	file.store_string(JSON.stringify({"version":1,"project_id":_config.get("firebase_project_id",""),"refresh_token":_refresh_token}))
	file.flush()
	var saved = file.get_error()==OK
	file.close()
	if saved: DirAccess.rename_absolute(ProjectSettings.globalize_path(AUTH_PATH+".tmp"),ProjectSettings.globalize_path(AUTH_PATH))

func _valid_credential(value) -> bool:
	return value is String and value.length()>0 and value.length()<=MAX_CREDENTIAL_LENGTH and _matches(value,"^[\\x21-\\x7e]+$")

func _valid_identity() -> bool:
	return not _id_token.is_empty() and Time.get_unix_time_from_system() < _expires_at-60

func _accept_auth(data: Dictionary, refreshed: bool) -> bool:
	var identity = data.get("id_token" if refreshed else "idToken")
	var refresh = data.get("refresh_token" if refreshed else "refreshToken")
	var expiry = data.get("expires_in" if refreshed else "expiresIn")
	if not _valid_credential(identity) or not _matches(identity,"^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$") or not _valid_credential(refresh): return false
	var seconds = 0.0
	if expiry is String and _matches(expiry,"^[0-9]{1,5}$"): seconds = float(expiry)
	elif (expiry is int or expiry is float) and is_finite(float(expiry)) and floorf(float(expiry))==float(expiry): seconds = float(expiry)
	if seconds<=60 or seconds>86400: return false
	if refreshed and (data.get("project_id","")!=_config.firebase_project_id or data.get("token_type","")!="Bearer"): return false
	_id_token = identity
	_refresh_token = refresh
	_expires_at = int(Time.get_unix_time_from_system())+int(minf(seconds,3600))
	return true

func _finish_auth(generation: int, success: bool) -> bool:
	if generation!=_generation: return false
	if success: _save_refresh()
	else: error = "Could not connect to purchase verification. Try Restore purchases."
	_authenticating = false
	authentication_finished.emit(success)
	return success and generation==_generation

func _authenticate() -> bool:
	if not is_configured(): return false
	var generation = _generation
	if _valid_identity(): return true
	if _authenticating:
		var shared_success = await authentication_finished
		return generation==_generation and shared_success==true and _valid_identity()
	_authenticating = true
	_id_token = ""
	_load_refresh()
	var api_key = str(_config.firebase_web_api_key).uri_encode()
	var response: Dictionary = {}
	if not _refresh_token.is_empty():
		response = await _post("https://securetoken.googleapis.com/v1/token?key="+api_key,{"grant_type":"refresh_token","refresh_token":_refresh_token})
		if generation!=_generation: return false
		if response.get("ok",false):
			return _finish_auth(generation,response.get("data") is Dictionary and _accept_auth(response.data,true))
		var payload = response.get("data",{})
		var failure = payload.get("error",{}) if payload is Dictionary else {}
		var reason = failure.get("message","") if failure is Dictionary else ""
		# A transient outage, wrong project or disabled account must not create
		# another anonymous identity. Explicit invalid/deleted credentials can retry.
		if response.get("code",0)!=400 or reason not in ["TOKEN_EXPIRED","INVALID_REFRESH_TOKEN","USER_NOT_FOUND"]:
			return _finish_auth(generation,false)
		_refresh_token = ""
	# Reauthentication does not lose permanent Play ownership; its token is rechecked.
	response = await _post("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="+api_key,{"returnSecureToken":true})
	if generation!=_generation: return false
	return _finish_auth(generation,response.get("ok",false) and response.get("data") is Dictionary and _accept_auth(response.data,false))

func _authoritative_revocation(response: Dictionary) -> String:
	if response.get("code",0)!=403: return ""
	var value = response.get("data",{})
	if not value is Dictionary or not value.get("verified") is bool or value.verified or not value.get("acknowledged") is bool or value.acknowledged or not value.get("retryable") is bool or value.retryable: return ""
	var code = value.get("error","")
	var state = value.get("purchase_state","")
	if code=="purchase_cancelled" and state=="cancelled": return state
	if code in ["purchase_not_found","purchase_refunded_or_invalid_quantity","purchase_consumed_or_unknown"] and state=="revoked": return state
	return ""

func _valid_proof(result: Dictionary, product: String, token: String) -> bool:
	if not result.get("verified") is bool or not result.verified or not result.get("acknowledged") is bool or not result.acknowledged or result.get("purchase_state","")!="purchased" or result.get("package_name","")!=PACKAGE or result.get("product_id","")!=product or result.get("purchase_token","")!=token or result.get("purchase_option_id","")!=ProductCatalog.purchase_option(product): return false
	var ttl = result.get("revalidate_after_seconds",0)
	var verified_at = result.get("verified_at",0)
	return (ttl is int or ttl is float) and is_finite(float(ttl)) and float(ttl)>0 and float(ttl)<=MAX_PROOF_TTL and (verified_at is int or verified_at is float) and is_finite(float(verified_at)) and float(verified_at)>0 and float(verified_at)<=9007199254740991.0 and floorf(float(verified_at))==float(verified_at)

func verify_purchase(purchase: Dictionary) -> Dictionary:
	var generation = _generation
	var product = purchase.get("product_id","")
	var token = purchase.get("purchase_token","")
	if not is_configured() or purchase.get("package_name","")!=PACKAGE or not product is String or product not in PRODUCTS or not token is String or token.is_empty() or token.length()>4096 or not _matches(token,"^[\\x21-\\x7e]+$"):
		return {"verified":false,"error":"Purchase verification is unavailable."}
	var authenticated = await _authenticate()
	if generation!=_generation: return {"verified":false,"error":"Purchase configuration changed. Try Restore purchases."}
	if not authenticated: return {"verified":false,"error":error if not error.is_empty() else "Purchase verification is unavailable."}
	var body = {"package_name":PACKAGE,"product_id":product,"purchase_token":token}
	var sent_identity = _id_token
	var response = await _post(str(_config.verification_url),body,PackedStringArray(["Authorization: Bearer "+sent_identity]))
	if generation!=_generation: return {"verified":false,"error":"Purchase configuration changed. Try Restore purchases."}
	if not response.get("ok",false):
		if response.get("code",0)==401 and _id_token==sent_identity:
			_id_token=""; _expires_at=0
		error = response.get("error","Verification could not finish. Try Restore purchases.")
		var revoked = _authoritative_revocation(response)
		if not revoked.is_empty():
			return {"verified":false,"acknowledged":false,"revoked":true,"package_name":PACKAGE,"product_id":product,"purchase_token":token,"purchase_state":revoked,"error":error}
		return {"verified":false,"error":error}
	var result = response.get("data",{})
	if not result is Dictionary or not _valid_proof(result,product,token):
		error="Purchase could not be verified. Try Restore purchases."
		return {"verified":false,"error":error}
	error=""
	return result
