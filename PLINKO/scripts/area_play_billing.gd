extends RefCounted
## Optional GodotGooglePlayBilling 3.x bridge. No billing plugin or backend ships yet.
## A configured trusted backend must verify AND acknowledge the permanent purchase.
## Nothing imported from a local save can grant a real-money entitlement here.
signal changed
signal purchase_result(product_id: String, outcome: String)
const PACKAGE = "com.qriscuit.sugarfall"
const PURCHASE_OPTION = "early-unlock"
const PRODUCTS = ["sugarfall_bakery_ability","sugarfall_gelato_ability","sugarfall_crystal_ability"]
const INAPP = 0
const PURCHASED = 1
const PENDING = 2
var _client: Node
var _verify: Callable
var _catalog: Dictionary = {}
var _entitlements: Dictionary = {}
var _checking: Dictionary = {}
var _pending_product = ""
var _generation = 0
var error = "Google Play purchases are not connected yet."

func configure_backend(verify_purchase: Callable) -> void:
	# Application code supplies a secure backend adapter, never player/save input.
	_verify=verify_purchase

func start(host: Node) -> bool:
	if not _verify.is_valid():
		error="Purchase verification is not configured."
		return false
	if not OS.has_feature("android") or not Engine.has_singleton("GodotGooglePlayBilling"):
		error="Google Play billing is unavailable."
		return false
	if is_instance_valid(_client):
		restore()
		return true
	for entry in ProjectSettings.get_global_class_list():
		if entry.class=="BillingClient":
			_client=load(entry.path).new()
			break
	if not is_instance_valid(_client):
		error="Google Play billing plugin is missing."
		return false
	host.add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_products)
	_client.query_purchases_response.connect(_on_owned_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.start_connection()
	return true

func has_entitlement(product_id: String) -> bool:
	return _entitlements.get(product_id,false)==true

func offer(product_id: String) -> Dictionary:
	var price: Dictionary = _catalog.get(product_id,{})
	var ready = is_instance_valid(_client) and _client.is_ready() and _verify.is_valid() and not price.is_empty()
	return {"available":ready and _pending_product.is_empty() and not has_entitlement(product_id),
		"price_label":price.get("formatted_price","$2.99"),"pending":_pending_product==product_id,
		"error":"" if ready else error}

func purchase(product_id: String) -> Dictionary:
	if product_id not in PRODUCTS or not offer(product_id).available: return {}
	_pending_product=product_id
	var result: Dictionary = _client.purchase(product_id,PURCHASE_OPTION,"")
	if result.get("response_code",-1)!=0:
		_pending_product=""
		if result.get("response_code")==7: restore()
		purchase_result.emit(product_id,"cancelled" if result.get("response_code")==1 else "unavailable")
	changed.emit()
	return result

func restore() -> void:
	if not is_instance_valid(_client) or not _verify.is_valid(): return
	if _client.is_ready(): _client.query_purchases(INAPP)
	else: _client.start_connection()

func _on_connected() -> void:
	error="Loading Google Play products."
	_client.query_product_details(PackedStringArray(PRODUCTS),INAPP)
	restore()
	changed.emit()

func _on_disconnected() -> void:
	error="Google Play is disconnected."
	changed.emit()

func _on_connect_error(_code: int, _message: String) -> void:
	error="Google Play is unavailable. Try again later."
	changed.emit()

func _on_products(response: Dictionary) -> void:
	_catalog.clear()
	if response.get("response_code",-1)!=0:
		error="Google Play prices are unavailable."
		changed.emit()
		return
	# Match the configured permanent base option; never display a rental/offer price.
	for product in response.get("product_details",[]):
		if not product is Dictionary or product.get("product_id") not in PRODUCTS: continue
		var options = product.get("one_time_purchase_offer_details_list",[])
		if not options is Array: continue
		for item in options:
			if not item is Dictionary or item.get("purchase_option_id")!=PURCHASE_OPTION: continue
			if item.get("offer_id") not in [null,""] or item.get("rental_details")!=null: continue
			if not item.get("formatted_price") is String or item.formatted_price.is_empty(): continue
			_catalog[product.product_id]=item.duplicate(true)
			break
	error="This upgrade is unavailable in Google Play."
	changed.emit()

func _on_owned_purchases(response: Dictionary) -> void:
	if response.get("response_code",-1)!=0:
		error="Purchases could not be restored."
		changed.emit()
		return
	_generation+=1
	_entitlements.clear()
	_checking.clear()
	_pending_product=""
	changed.emit()
	for purchase_data in response.get("purchases",[]):
		if purchase_data is Dictionary: _verify_purchase(purchase_data,_generation)

func _on_purchase_updated(response: Dictionary) -> void:
	if response.get("response_code",-1)!=0:
		var product = _pending_product
		_pending_product=""
		if response.get("response_code")==7: restore()
		purchase_result.emit(product,"cancelled" if response.get("response_code")==1 else "failed")
		changed.emit()
		return
	for purchase_data in response.get("purchases",[]):
		if purchase_data is Dictionary: _verify_purchase(purchase_data,_generation)

func _verify_purchase(purchase_data: Dictionary, generation: int) -> void:
	if not _verify.is_valid() or purchase_data.get("package_name")!=PACKAGE: return
	var token = purchase_data.get("purchase_token","")
	if not token is String or token.is_empty(): return
	var ids = purchase_data.get("product_ids",[])
	if not (ids is Array or ids is PackedStringArray): return
	for product_id in ids:
		if product_id not in PRODUCTS: continue
		if has_entitlement(product_id): continue
		if purchase_data.get("purchase_state")==PENDING:
			_pending_product=product_id
			purchase_result.emit(product_id,"pending")
			changed.emit()
			continue
		if purchase_data.get("purchase_state")!=PURCHASED or purchase_data.get("is_suspended",false)==true: continue
		var key = product_id+":"+token
		if _checking.has(key): continue
		_checking[key]=true
		# The backend verifies the token with Google, grants once and acknowledges.
		# Its result is never synthesized from is_acknowledged or a client boolean.
		var result = await _verify.call({"package_name":PACKAGE,"product_id":product_id,"purchase_token":token})
		if generation!=_generation: return
		_checking.erase(key)
		var valid = result is Dictionary and result.get("verified")==true and result.get("acknowledged")==true and result.get("purchase_state")=="purchased" and result.get("package_name")==PACKAGE and result.get("product_id")==product_id and result.get("purchase_token")==token
		if valid:
			_entitlements[product_id]=true
			_pending_product=""
			purchase_result.emit(product_id,"completed")
		else:
			_pending_product=""
			error="Purchase verification could not finish. Restore purchases to retry."
			purchase_result.emit(product_id,"verification_failed")
		changed.emit()
