extends RefCounted
## Native Play Billing with server verification. Only verified in-memory rights
## survive a transient refresh failure; local save flags never grant purchases.
signal changed
signal purchase_result(product_id: String, outcome: String)
signal restore_state_changed(status: Dictionary)
signal restore_finished(success: bool, message: String)
signal _verification_finished
const ProductCatalog = preload("res://scripts/play_product_catalog.gd")
const PACKAGE = "com.sungati.sugarfall"
const PRODUCTS = ProductCatalog.PRODUCTS
const REMOVE_ADS_PRODUCT = ProductCatalog.REMOVE_ADS_PRODUCT
const CLIENT_PATH = "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const INAPP = 0
const PURCHASED = 1
const PENDING = 2
const MAX_PROOF_TTL_SECONDS = 300.0
const REFRESH_INTERVAL_SECONDS = 240.0
var _client: Node
var _verify: Callable
var _catalog: Dictionary = {}
var _entitlements: Dictionary = {}
var _checking: Dictionary = {}
var _store_pending: Dictionary = {}
var _verification_errors: Dictionary = {}
var _pending_product = ""
var _generation = 0
var _account_id = ""
var _profile_id = ""
var _restore_phase = "unconfigured"
var _initial_restore_complete = false
var _inventory_verified = false
var _inventory_verified_msec = -1
var _last_restore_success = false
var _restore_processing = false
var _entitlement_revision = 0
var _grant_revisions: Dictionary = {}
var _query_entitlement_revision = 0
var _query_live_revision = 0
var _query_generation = -1
var _query_outstanding = false
var _restore_after_query = false
var _live_revision = 0
var _live_revisions: Dictionary = {}
var _proof_expires_msec: Dictionary = {}
var _verified_tokens: Dictionary = {}
var _revoked_checks: Dictionary = {}
var _revoked_proofs: Dictionary = {}
var _refresh_timer: Timer
var _expiry_timer: Timer
var error = "Google Play purchases are not connected yet."

func configure_backend(verify_purchase: Callable, obfuscated_account_id: String = "", obfuscated_profile_id: String = "") -> void:
	# Call only from the authenticated backend adapter. An account change must
	# invalidate old rights and in-flight responses before any new checkout.
	if _verify==verify_purchase and _account_id==obfuscated_account_id and _profile_id==obfuscated_profile_id:
		_apply_account_ids()
		return
	_generation+=1
	_verify=verify_purchase
	_account_id=obfuscated_account_id
	_profile_id=obfuscated_profile_id
	_entitlements.clear(); _grant_revisions.clear(); _checking.clear()
	_proof_expires_msec.clear()
	_verified_tokens.clear(); _revoked_checks.clear(); _revoked_proofs.clear()
	if is_instance_valid(_expiry_timer): _expiry_timer.stop()
	_store_pending.clear(); _verification_errors.clear(); _pending_product=""
	_live_revisions.clear(); _restore_after_query=false
	_restore_processing=false; _initial_restore_complete=false; _inventory_verified=false
	_inventory_verified_msec=-1
	_last_restore_success=false
	if _account_id.length()>64 or _profile_id.length()>64 or _account_id.contains("@") or _profile_id.contains("@"):
		_verify=Callable()
		error="Purchase account identifiers must be obfuscated."
	else:
		error="" if _verify.is_valid() else "Purchase verification is not configured."
	_restore_phase="configured" if _verify.is_valid() else "unconfigured"
	_apply_account_ids()
	_notify()

func backend_configured() -> bool:
	return _verify.is_valid()

func initial_restore_finished() -> bool:
	return _initial_restore_complete

func restore_status() -> Dictionary:
	return {"phase":_restore_phase,"initial_finished":_initial_restore_complete,
		"restoring":_restore_phase in ["connecting","querying","verifying"],
		"success":_last_restore_success,"configured":backend_configured(),
		"has_verified_inventory":_inventory_verified,"verifying":_checking.size(),"error":error}

func _notify():
	restore_state_changed.emit(restore_status())
	changed.emit()

func _finish_restore(success: bool, message: String = ""):
	var generation = _generation
	_restore_processing=false
	_initial_restore_complete=true
	_last_restore_success=success
	_restore_phase="ready" if success else "failed"
	error=message
	_notify()
	if generation!=_generation: return
	restore_finished.emit(success,message)
	if generation!=_generation: return
	if _restore_after_query and not _query_outstanding:
		_restore_after_query=false
		restore()

func _mark_live_change(product: String):
	_live_revision+=1
	_live_revisions[product]=_live_revision

func _request_reconciliation():
	if _query_outstanding or _restore_processing: _restore_after_query=true
	else: restore()

func start(host: Node) -> bool:
	if not backend_configured():
		_finish_restore(false,"Purchase verification is not configured.")
		return false
	if not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"):
		_finish_restore(false,"Google Play billing is unavailable.")
		return false
	if is_instance_valid(_client):
		restore()
		return true
	if ResourceLoader.exists(CLIENT_PATH): _client=load(CLIENT_PATH).new()
	if not is_instance_valid(_client):
		_finish_restore(false,"Google Play billing plugin is missing.")
		return false
	host.add_child(_client)
	_ensure_refresh_timers()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_products)
	_client.query_purchases_response.connect(_on_owned_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_apply_account_ids()
	_restore_phase="connecting"; error="Connecting to Google Play."
	_notify()
	_client.start_connection()
	return true

func _apply_account_ids():
	if not is_instance_valid(_client): return
	if _client.has_method("set_obfuscated_account_id"): _client.set_obfuscated_account_id(_account_id)
	if _client.has_method("set_obfuscated_profile_id"): _client.set_obfuscated_profile_id(_profile_id)

func has_entitlement(product_id: String) -> bool:
	return _entitlements.get(product_id,false)==true and int(_proof_expires_msec.get(product_id,0))>_monotonic_msec()

func has_authoritative_absence(product_id: String) -> bool:
	# Expiration of an existing proof is not evidence that a purchase was revoked.
	if _pending_product==product_id or _store_pending.has(product_id) or _verifying_product(product_id) or _verification_errors.has(product_id): return false
	if has_authoritative_revocation(product_id): return true
	return _inventory_verified and _last_restore_success and not restore_status().restoring and _entitlements.get(product_id,false)!=true and _inventory_verified_msec>=0 and _monotonic_msec()<_inventory_verified_msec+int(MAX_PROOF_TTL_SECONDS*1000.0)

func has_authoritative_revocation(product_id: String) -> bool:
	return not has_entitlement(product_id) and int(_revoked_proofs.get(product_id,0))>_monotonic_msec()

func _revoked_key(product: String, token: String, generation: int) -> String:
	return "%d:%s:%s" % [generation,product,token]

func _was_revoked(product: String, token: String, generation: int) -> bool:
	return generation==_generation and int(_revoked_checks.get(_revoked_key(product,token,generation),0))>_monotonic_msec()

func _clear_revoked_token(product: String, token: String):
	# A refund for an older purchase must not remove a verified repurchase.
	if _verified_tokens.get(product,"")!=token: return
	_entitlements.erase(product); _proof_expires_msec.erase(product)
	_verified_tokens.erase(product); _grant_revisions.erase(product)
	_mark_live_change(product)

func _commit_revocation(product: String, token: String):
	_clear_revoked_token(product,token)
	if not str(_verified_tokens.get(product,"")).is_empty(): return
	_revoked_proofs[product]=_monotonic_msec()+int(MAX_PROOF_TTL_SECONDS*1000.0)
	_store_pending.erase(product)
	_verification_errors.erase(product)
	if _pending_product==product: _pending_product=""
	purchase_result.emit(product,"revoked")

func _monotonic_msec() -> int:
	return Time.get_ticks_msec()

func _ensure_refresh_timers():
	if not is_instance_valid(_client) or not _client.is_inside_tree(): return
	if not is_instance_valid(_refresh_timer):
		_refresh_timer=Timer.new()
		_refresh_timer.name="PurchaseProofRefresh"
		_refresh_timer.wait_time=REFRESH_INTERVAL_SECONDS
		_client.add_child(_refresh_timer)
		_refresh_timer.timeout.connect(_refresh_verified_rights)
		_refresh_timer.start()
	if not is_instance_valid(_expiry_timer):
		_expiry_timer=Timer.new()
		_expiry_timer.name="PurchaseProofExpiry"
		_expiry_timer.one_shot=true
		_client.add_child(_expiry_timer)
		_expiry_timer.timeout.connect(_on_proof_expiry)

func _refresh_verified_rights():
	if not backend_configured() or not is_instance_valid(_client) or not _client.is_inside_tree(): return
	# Fresh inventory also establishes which products are absent.
	if _initial_restore_complete or not _entitlements.is_empty() or not _store_pending.is_empty(): restore()

func _schedule_proof_expiry():
	_ensure_refresh_timers()
	if not is_instance_valid(_expiry_timer): return
	_expiry_timer.stop()
	var now = _monotonic_msec()
	var earliest = 0
	for product in _entitlements:
		var deadline = int(_proof_expires_msec.get(product,0))
		if deadline>now and (earliest==0 or deadline<earliest): earliest=deadline
	if earliest>0: _expiry_timer.start(maxf(.001,float(earliest-now)/1000.0))

func _on_proof_expiry():
	# Expiry changes availability, never earned campaign flags or airborne state.
	_notify()
	_refresh_verified_rights()
	_schedule_proof_expiry()

func _verifying_product(product_id: String) -> bool:
	for job in _checking.values():
		if job.product==product_id: return true
	return false

func can_restore() -> bool:
	return backend_configured() and is_instance_valid(_client)

func needs_restore(product_id: String) -> bool:
	return can_restore() and not has_entitlement(product_id) and (_entitlements.get(product_id,false)==true or _verification_errors.has(product_id) or (_initial_restore_complete and not _inventory_verified))

func offer(product_id: String) -> Dictionary:
	var price: Dictionary = _catalog.get(product_id,{})
	var ready = is_instance_valid(_client) and _client.is_ready() and backend_configured() and not price.is_empty()
	var pending = _pending_product==product_id or _store_pending.has(product_id) or _verifying_product(product_id)
	var busy = not _pending_product.is_empty() or not _store_pending.is_empty() or not _checking.is_empty() or restore_status().restoring
	return {"available":ready and _inventory_verified and not busy and not needs_restore(product_id) and not _verification_errors.has(product_id) and not has_entitlement(product_id),
		"price_label":price.get("formatted_price","$2.99"),"pending":pending,
		"error":str(_verification_errors.get(product_id,"")) if ready else error}

func purchase(product_id: String) -> Dictionary:
	if product_id not in PRODUCTS or not offer(product_id).available: return {}
	_pending_product=product_id
	_apply_account_ids()
	var result: Dictionary = _client.purchase(product_id,ProductCatalog.purchase_option(product_id),"")
	if result.get("response_code",-1)!=0:
		_pending_product=""
		_mark_live_change(product_id)
		if result.get("response_code")==7:
			_verification_errors[product_id]="Restore this purchase."
			restore()
		purchase_result.emit(product_id,"cancelled" if result.get("response_code")==1 else "unavailable")
	_notify()
	return result

func restore() -> void:
	if not can_restore():
		_finish_restore(false,"Purchase verification or Google Play is unavailable.")
		return
	if _query_outstanding:
		# Native query callbacks carry no request ID. Drain the previous account's
		# one outstanding query before issuing a query for a newly bound account.
		if _query_generation!=_generation:
			_restore_after_query=true
			_restore_phase="querying"
			_notify()
		return
	if _restore_phase=="verifying": return
	if _client.is_ready():
		_restore_phase="querying"
		_query_entitlement_revision=_entitlement_revision
		_query_live_revision=_live_revision
		_query_generation=_generation
		_query_outstanding=true
		error="Restoring Google Play purchases."
		_notify()
		_client.query_purchases(INAPP)
	else:
		_restore_phase="connecting"; error="Connecting to Google Play."
		_notify()
		_client.start_connection()

func _on_connected() -> void:
	_ensure_refresh_timers()
	error="Loading Google Play products."
	_client.query_product_details(PackedStringArray(PRODUCTS),INAPP)
	restore()

func _on_disconnected() -> void:
	if _restore_phase=="verifying":
		error="Google Play disconnected while purchases are being verified."
		_notify()
	elif restore_status().restoring: _finish_restore(false,"Google Play is disconnected. Restore purchases to retry.")
	else:
		error="Google Play is disconnected."
		_notify()

func _on_connect_error(_code: int, _message: String) -> void:
	_finish_restore(false,"Google Play is unavailable. Try again later.")

func _on_products(response: Dictionary) -> void:
	if response.get("response_code",-1)!=0:
		error="Google Play prices are unavailable."
		_notify()
		return
	var products = response.get("product_details",[])
	if not products is Array:
		error="Google Play returned invalid product information."
		_notify()
		return
	var catalog: Dictionary = {}
	# Match only the permanent base option; never a rental or unrelated offer.
	for product in products:
		if not product is Dictionary or product.get("product_id") not in PRODUCTS: continue
		var options = product.get("one_time_purchase_offer_details_list",[])
		if not options is Array: continue
		var purchase_option = ProductCatalog.purchase_option(product.product_id)
		for item in options:
			if not item is Dictionary or item.get("purchase_option_id")!=purchase_option: continue
			if item.get("offer_id") not in [null,""] or item.get("rental_details")!=null: continue
			if not item.get("formatted_price") is String or item.formatted_price.is_empty(): continue
			catalog[product.product_id]=item.duplicate(true)
			break
	_catalog=catalog
	if not restore_status().restoring: error="This upgrade is unavailable in Google Play." if _catalog.is_empty() else ""
	_notify()

func _purchase_records(purchases) -> Dictionary:
	if not purchases is Array: return {"ok":false,"records":[]}
	var records: Array = []
	var seen: Dictionary = {}
	for data in purchases:
		if not data is Dictionary: return {"ok":false,"records":[]}
		var ids = data.get("product_ids",[])
		if not (ids is Array or ids is PackedStringArray) or ids.is_empty(): return {"ok":false,"records":[]}
		for product in ids:
			if product not in PRODUCTS: continue
			var token = data.get("purchase_token","")
			if data.get("package_name")!=PACKAGE or not token is String or token.is_empty(): return {"ok":false,"records":[]}
			var state = data.get("purchase_state",-1)
			if state!=PURCHASED and state!=PENDING: return {"ok":false,"records":[]}
			var key = product+":"+token
			if seen.has(key): continue
			seen[key]=true
			records.append({"product":product,"token":token,"state":state,"suspended":data.get("is_suspended",false)==true})
	return {"ok":true,"records":records}

func _on_owned_purchases(response: Dictionary) -> void:
	if not _query_outstanding: return
	var issuing_generation = _query_generation
	_query_outstanding=false
	if issuing_generation!=_generation:
		if _restore_after_query:
			_restore_after_query=false
			_restore_phase="configured"
			restore()
		return
	if _restore_processing: return
	if not backend_configured():
		_finish_restore(false,"Purchase verification is not configured.")
		return
	if response.get("response_code",-1)!=0:
		_finish_restore(false,"Purchases could not be restored. Try again later.")
		return
	var parsed = _purchase_records(response.get("purchases",null))
	if not parsed.ok:
		_finish_restore(false,"Google Play returned incomplete purchases. Restore purchases to retry.")
		return
	var generation = _generation
	var query_revision = _query_entitlement_revision
	var query_live_revision = _query_live_revision
	_restore_processing=true; _restore_phase="verifying"
	_notify()
	if generation!=_generation: return
	var candidates: Dictionary = {}
	var pending_inventory: Dictionary = {}
	var revoked_inventory: Dictionary = {}
	var unresolved_products: Dictionary = {}
	var all_verified = true
	for record in parsed.records:
		if generation!=_generation: return
		if record.state==PENDING:
			pending_inventory[record.product]=true
			if int(_live_revisions.get(record.product,0))<=query_live_revision:
				_store_pending[record.product]=true
				if _pending_product==record.product: _pending_product=""
				purchase_result.emit(record.product,"pending")
			if generation!=_generation: return
			continue
		if record.suspended: continue
		if int(_live_revisions.get(record.product,0))<=query_live_revision: _store_pending.erase(record.product)
		if await _verify_record(record.product,record.token,generation): candidates[record.product]=true
		elif _was_revoked(record.product,record.token,generation):
			_clear_revoked_token(record.product,record.token)
			revoked_inventory[record.product]=record.token
		else:
			all_verified=false
			unresolved_products[record.product]=true
			if generation==_generation:
				_verification_errors[record.product]="Purchase verification could not finish. Restore purchases to retry."
				if _pending_product==record.product: _pending_product=""
				purchase_result.emit(record.product,"verification_failed")
		if generation!=_generation: return
	for product in revoked_inventory:
		if not candidates.has(product) and not unresolved_products.has(product):
			_commit_revocation(product,revoked_inventory[product])
			if generation!=_generation: return
	if not all_verified:
		_finish_restore(false,"Purchase verification could not finish. Restore purchases to retry.")
		return
	if generation!=_generation: return
	# A refresh commits atomically. Keep rights until all returned tokens verify,
	# and never revoke a purchase completed after this inventory query started.
	for product in _entitlements:
		if int(_grant_revisions.get(product,0))>query_revision: candidates[product]=true
	var previous = _entitlements
	_entitlements=candidates
	var candidate_errors: Dictionary = {}
	for product in _live_revisions:
		if int(_live_revisions[product])<=query_live_revision: continue
		if _store_pending.has(product): pending_inventory[product]=true
		else: pending_inventory.erase(product)
		if _verification_errors.has(product): candidate_errors[product]=_verification_errors[product]
	_store_pending=pending_inventory
	_inventory_verified=true
	_inventory_verified_msec=_monotonic_msec()
	_verification_errors=candidate_errors
	_schedule_proof_expiry()
	for product in candidates:
		_verification_errors.erase(product)
		if _pending_product==product: _pending_product=""
		if not previous.get(product,false): purchase_result.emit(product,"completed")
		if generation!=_generation: return
	if pending_inventory.has(_pending_product): _pending_product=""
	_finish_restore(true)

func _on_purchase_updated(response: Dictionary) -> void:
	if response.get("response_code",-1)!=0:
		var product = _pending_product
		if product.is_empty() and _store_pending.size()==1: product=str(_store_pending.keys()[0])
		var was_pending = _store_pending.has(product)
		_pending_product=""
		if not product.is_empty():
			_mark_live_change(product)
			if response.get("response_code")==1: _store_pending.erase(product)
			else: _verification_errors[product]="Payment status could not be checked. Restore purchases to retry."
		if response.get("response_code")==7:
			_verification_errors[product]="Restore this purchase."
		if was_pending or response.get("response_code")==7: _request_reconciliation()
		purchase_result.emit(product,"cancelled" if response.get("response_code")==1 else "failed")
		_notify()
		return
	var parsed = _purchase_records(response.get("purchases",null))
	if not parsed.ok or parsed.records.is_empty():
		var product = _pending_product
		_pending_product=""
		if not product.is_empty():
			_mark_live_change(product)
			_verification_errors[product]="Purchase response was incomplete. Restore purchases to retry."
			purchase_result.emit(product,"verification_failed")
		_request_reconciliation()
		_notify()
		return
	for data in response.purchases:
		if data is Dictionary: _verify_purchase(data,_generation)

func _verify_record(product: String, token: String, generation: int) -> bool:
	if not backend_configured() or generation!=_generation: return false
	var key = "%d:%s:%s" % [generation,product,token]
	if _checking.has(key):
		var existing: Dictionary = _checking[key]
		while not existing.done: await _verification_finished
		return existing.valid and generation==_generation
	var job = {"product":product,"done":false,"valid":false}
	_checking[key]=job
	_notify()
	if generation!=_generation:
		job.done=true
		_checking.erase(key)
		_verification_finished.emit()
		return false
	# The authenticated adapter binds the token to its user and verifies with
	# Google before acknowledging. No key, token or response is logged here.
	var request = {"package_name":PACKAGE,"product_id":product,"purchase_token":token,
		"obfuscated_account_id":_account_id,"obfuscated_profile_id":_profile_id}
	var result = await _verify.call(request)
	var bound = generation==_generation and result is Dictionary and result.get("package_name")==PACKAGE and result.get("product_id")==product and result.get("purchase_token")==token
	var revoked = bound and typeof(result.get("revoked"))==TYPE_BOOL and result.get("revoked")==true and typeof(result.get("verified"))==TYPE_BOOL and result.get("verified")==false and typeof(result.get("acknowledged"))==TYPE_BOOL and result.get("acknowledged")==false and result.get("purchase_state","") in ["revoked","cancelled"]
	if revoked: _revoked_checks[_revoked_key(product,token,generation)]=_monotonic_msec()+int(MAX_PROOF_TTL_SECONDS*1000.0)
	var valid = generation==_generation and result is Dictionary and result.get("verified")==true and result.get("acknowledged")==true and result.get("purchase_state")=="purchased" and result.get("package_name")==PACKAGE and result.get("product_id")==product and result.get("purchase_token")==token
	if valid:
		var ttl = result.get("revalidate_after_seconds",0)
		var verified_at = result.get("verified_at",0)
		valid = (ttl is int or ttl is float) and is_finite(float(ttl)) and float(ttl)>0 and (verified_at is int or verified_at is float) and is_finite(float(verified_at)) and float(verified_at)>0
		if valid:
			# The server timestamp is metadata only. A validated response starts a
			# bounded local monotonic lifetime; no save can prolong this proof.
			_proof_expires_msec[product]=_monotonic_msec()+maxi(1,floori(minf(float(ttl),MAX_PROOF_TTL_SECONDS)*1000.0))
			_verified_tokens[product]=token
			_revoked_proofs.erase(product)
			_revoked_checks.erase(_revoked_key(product,token,generation))
			_schedule_proof_expiry()
	job.done=true; job.valid=valid
	_checking.erase(key)
	_verification_finished.emit()
	return valid

func _verify_purchase(purchase_data: Dictionary, generation: int) -> void:
	if generation!=_generation: return
	var parsed = _purchase_records([purchase_data])
	if not parsed.ok: return
	for record in parsed.records:
		if generation!=_generation: return
		var product: String = record.product
		_mark_live_change(product)
		if record.state==PENDING:
			_store_pending[product]=true
			purchase_result.emit(product,"pending")
			_notify()
			continue
		if record.suspended:
			_store_pending.erase(product)
			if _pending_product==product: _pending_product=""
			_verification_errors[product]="Purchase is suspended. Restore purchases to check access."
			purchase_result.emit(product,"unavailable")
			if generation!=_generation: return
			_request_reconciliation()
			_notify()
			continue
		if has_entitlement(product) and _verified_tokens.get(product,"")==record.token:
			# This is a new native confirmation of an already verified right.
			# An older inventory snapshot must not revoke it while finishing later.
			_entitlement_revision+=1
			_grant_revisions[product]=_entitlement_revision
			_store_pending.erase(product)
			if _pending_product==product: _pending_product=""
			_notify()
			continue
		_store_pending.erase(product)
		var valid = await _verify_record(product,record.token,generation)
		if generation!=_generation: return
		if _pending_product==product: _pending_product=""
		_mark_live_change(product)
		if valid and not has_entitlement(product):
			_entitlement_revision+=1
			_grant_revisions[product]=_entitlement_revision
			_entitlements[product]=true
			_schedule_proof_expiry()
			_verification_errors.erase(product)
			purchase_result.emit(product,"completed")
		elif _was_revoked(product,record.token,generation):
			_commit_revocation(product,record.token)
		elif not valid:
			error="Purchase verification could not finish. Restore purchases to retry."
			_verification_errors[product]=error
			purchase_result.emit(product,"verification_failed")
		_notify()
