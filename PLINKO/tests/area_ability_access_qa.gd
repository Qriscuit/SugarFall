extends SceneTree
const Access = preload("res://scripts/area_ability_access.gd")
const Billing = preload("res://scripts/area_play_billing.gd")
var passed = 0
var failed = 0
var verification_calls = 0
var verification_mode = "reject"

class FakeClient extends Node:
	var connected_ready = true
	var calls: Array = []
	var restore_calls = 0
	func is_ready(): return connected_ready
	func purchase(id, option, offer_id):
		calls.append([id,option,offer_id])
		return {"response_code":0}
	func query_purchases(_type): restore_calls+=1
	func start_connection(): pass

func backend(request: Dictionary) -> Dictionary:
	verification_calls+=1
	if verification_mode=="reject": return {}
	var response=request.duplicate(true)
	response.verified=true; response.acknowledged=true; response.purchase_state="purchased"
	if verification_mode=="wrong_product": response.product_id="unknown"
	if verification_mode=="wrong_token": response.purchase_token="wrong"
	if verification_mode=="not_acknowledged": response.acknowledged=false
	return response

func live_contract():
	var billing=Billing.new()
	var client=FakeClient.new(); root.add_child(client)
	billing._client=client
	billing.configure_backend(backend)
	var id=Access.CATALOG.bakery.product_id
	var live_offer={"purchase_option_id":"early-unlock","offer_id":null,"formatted_price":"€3.49","rental_details":null}
	billing._on_products({"response_code":0,"product_details":[{"product_id":id,"one_time_purchase_offer_details_list":[live_offer]}]})
	check(billing.offer(id).available and billing.offer(id).price_label=="€3.49","Live offer uses fetched localized price instead of USD design price")
	var access=Access.new(false); access.bind_provider(billing)
	check(access.offer("bakery").price_is_live and not access.offer("bakery").preview,"Configured real contract is distinct from preview simulation")
	check(not access.request_purchase("bakery").is_empty() and client.calls==[[id,"early-unlock",""]],"Purchase launches exact permanent option")
	check(access.request_purchase("bakery").is_empty() and billing.purchase(id).is_empty(),"Live duplicate tap cannot launch twice")
	billing._on_purchase_updated({"response_code":1})
	check(not access.has_early_access("bakery") and billing.offer(id).available,"Live cancellation grants nothing and releases request")
	var data={"package_name":Billing.PACKAGE,"purchase_token":"fixture-token","purchase_state":2,"product_ids":[id],"is_acknowledged":true}
	await billing._verify_purchase(data,0)
	check(verification_calls==0 and not access.has_early_access("bakery") and billing.offer(id).pending,"Play PENDING never verifies or grants despite client acknowledgement flag")
	data.purchase_state=1
	await billing._verify_purchase(data,0)
	check(verification_calls==1 and not access.has_early_access("bakery"),"Client PURCHASED/acknowledged fields alone cannot grant")
	for invalid_mode in ["wrong_product","wrong_token","not_acknowledged"]:
		verification_mode=invalid_mode
		await billing._verify_purchase(data,0)
		check(not access.has_early_access("bakery"),invalid_mode+" backend response is rejected")
	verification_mode="accept"
	await billing._verify_purchase(data,0)
	check(access.has_early_access("bakery") and not access.has_early_access("gelato"),"Verified acknowledged purchase grants only corresponding area")
	var count=verification_calls
	await billing._verify_purchase(data,0)
	check(verification_calls==count and billing.purchase(id).is_empty(),"Duplicate live callback cannot fulfill or charge again")
	check(access.export_state().is_empty(),"Real verified access is never serialized into preview save namespace")
	billing.restore()
	check(client.restore_calls==1,"Restore queries non-consumed Play inventory")
	billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(not access.has_early_access("bakery"),"Authoritative empty inventory revokes cached paid access")
	var rental=live_offer.duplicate(true); rental.rental_details={"period":"P1D"}
	billing._on_products({"response_code":0,"product_details":[{"product_id":id,"one_time_purchase_offer_details_list":[rental]}]})
	check(not billing.offer(id).available,"Rental cannot masquerade as permanent early unlock")
	client.free()

func check(ok: bool, label: String):
	if ok: passed+=1
	else: failed+=1
	print("PASS: " if ok else "FAIL: ",label)

func _initialize():
	call_deferred("run")

func run():
	var access=Access.new()
	check(access.preview_enabled(),"Editor test enables explicitly marked preview purchase path")
	for area in Access.CATALOG:
		var offer=access.offer(area)
		check(offer.available and offer.preview and not offer.owned and offer.price_label=="$2.99" and not offer.price_is_live,area+" offers honest design price in preview")
		check(access.request_preview(area,true).is_empty(),area+" earned ownership cannot be charged again")
		var request=access.request_preview(area)
		check(not request.is_empty() and access.request_preview(area).is_empty(),area+" repeated tap cannot create two requests")
		request.area="unknown"
		check(access.pending.area==area,"Returned request cannot mutate in-flight area")
		check(access.resolve_preview("forged","completed").is_empty() and not access.has_early_access(area),"Unknown callback cannot grant")
		var id=access.pending.id
		var pending=access.resolve_preview(id,"pending")
		check(not pending.granted and not access.has_early_access(area) and access.offer(area).pending,"Pending purchase grants no benefit")
		var cancelled=access.resolve_preview(id,"cancelled")
		check(not cancelled.granted and not access.has_early_access(area) and access.pending.is_empty(),"Cancellation remains unowned")
		for outcome in ["failed","unavailable"]:
			id=access.request_preview(area).id
			check(not access.resolve_preview(id,outcome).granted and not access.has_early_access(area),outcome+" grants nothing")
		id=access.request_preview(area).id
		var failure=access.resolve_preview(id,"completed",func(): return false)
		check(failure.outcome=="save_failed" and not access.has_early_access(area) and access.pending.id==id,"Save failure rolls back ownership and keeps retryable request")
		var complete=access.resolve_preview(id,"completed",func(): return true)
		check(complete.granted and access.has_early_access(area) and access.pending.is_empty(),area+" successful persistent completion grants exactly once")
		check(access.resolve_preview(id,"completed").is_empty() and access.request_preview(area).is_empty(),"Repeated callback/purchase cannot double grant")
	check(access.request_preview("unknown").is_empty() and access.offer("unknown").is_empty(),"Unknown area cannot obtain a product")
	var snapshot=access.export_state()
	var restored=Access.new()
	check(restored.import_state(snapshot),"Preview receipt state reloads")
	for area in Access.CATALOG: check(restored.has_early_access(area),area+" preview receipt survives restart")
	access.clear_preview_benefits()
	check(not access.has_early_access("bakery") and access.request_preview("bakery").is_empty(),"A restorable receipt cannot be sold twice")
	check(not access.restore_preview(func(): return false) and not access.has_early_access("bakery"),"Failed restore persistence rolls back")
	check(access.restore_preview(func(): return true) and access.has_early_access("bakery"),"Restore re-enables receipt without payment")
	var invalid=snapshot.duplicate(true)
	invalid.preview_owned.bakery=1
	check(not access.import_state(invalid) and access.has_early_access("bakery"),"Corrupt ownership does not overwrite valid state")
	invalid=snapshot.duplicate(true); invalid.preview_receipts.bakery=false
	check(not access.import_state(invalid),"Ownership without a receipt is rejected")
	invalid=snapshot.duplicate(true); invalid.serial=1.5
	check(not access.import_state(invalid),"Fractional serial is rejected")
	access.reset_preview_store()
	var old=access.request_preview("bakery").id
	access.cancel_pending_preview()
	var fresh=access.request_preview("bakery").id
	check(old!=fresh and access.resolve_preview(old,"completed").is_empty(),"Canceled callback cannot complete a newer request")
	var interrupted=Access.new(); interrupted.import_state(access.export_state())
	check(interrupted.pending.is_empty() and not interrupted.has_early_access("bakery"),"Restart cannot complete a pending test purchase")
	var public_access=Access.new(false)
	check(not public_access.import_state(snapshot),"Public service rejects preview receipts")
	check(public_access.export_state().is_empty() and not public_access.has_early_access("bakery"),"Public service exports no test ownership")
	check(public_access.request_preview("bakery").is_empty() and public_access.request_purchase("bakery").is_empty(),"Unavailable public store cannot launch a fake purchase")
	public_access.pending={"id":"forged","area":"bakery","product_id":Access.CATALOG.bakery.product_id}
	check(public_access.resolve_preview("forged","completed").is_empty() and not public_access.restore_preview(),"Even forged public pending state cannot grant or restore")
	check(public_access.offer("bakery",true).owned and not public_access.offer("bakery",true).available,"Earned gameplay ownership works with unavailable public billing")
	var billing=Billing.new()
	check(not billing.start(root),"Unconfigured real provider cannot launch or charge")
	check(public_access.bind_provider(billing),"Real provider binds through separate contract")
	check(not public_access.offer("gelato").available and not public_access.has_early_access("gelato"),"Missing SDK/backend never becomes a live offer or entitlement")
	await live_contract()
	print("AREA_ABILITY_ACCESS_QA_RESULT passed=%d failed=%d"%[passed,failed])
	quit(0 if failed==0 else 1)
