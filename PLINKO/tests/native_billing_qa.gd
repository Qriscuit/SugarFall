extends SceneTree
## Delayed provider callbacks and real service boundaries. No network/profile IO.
const Billing = preload("res://scripts/area_play_billing.gd")
var passed = 0
var failed: Array[String] = []

class ClockBilling extends "res://scripts/area_play_billing.gd":
	var now_msec=1000
	func _monotonic_msec() -> int: return now_msec

class FakeClient extends Node:
	var calls: Array = []
	var restores = 0
	var connected_ready = true
	var account = ""
	var profile = ""
	func is_ready(): return connected_ready
	func purchase(product, option, offer):
		calls.append([product,option,offer])
		return {"response_code":0}
	func query_purchases(_type): restores+=1
	func start_connection(): pass
	func set_obfuscated_account_id(value): account=value
	func set_obfuscated_profile_id(value): profile=value

class Verifier extends RefCounted:
	signal release
	var deferred = false
	var approve = true
	var ttl=300.0
	var verified_at=1700000000000.0
	var include_metadata=true
	var revoked=false
	var revoke_product=""
	var revoke_token=""
	var wrong_revoked_token=false
	var requests: Array = []
	func verify(request: Dictionary) -> Dictionary:
		requests.append(request.duplicate(true))
		if deferred: await release
		if revoked and (revoke_product.is_empty() or request.product_id==revoke_product) and (revoke_token.is_empty() or request.purchase_token==revoke_token):
			var denial=request.duplicate(true)
			denial.verified=false;denial.acknowledged=false;denial.revoked=true;denial.purchase_state="revoked"
			if wrong_revoked_token: denial.purchase_token="wrong-fixture-token"
			return denial
		if not approve: return {}
		var response=request.duplicate(true)
		response.verified=true; response.acknowledged=true; response.purchase_state="purchased"
		if include_metadata:
			response.revalidate_after_seconds=ttl;response.verified_at=verified_at
		return response

func check(ok: bool, message: String):
	if ok: passed+=1
	else: failed.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func record(product: String, state: int = 1, token: String = "fixture-token") -> Dictionary:
	return {"package_name":Billing.PACKAGE,"purchase_token":token,"purchase_state":state,"product_ids":[product],"is_acknowledged":true}

func inventory(billing, response: Dictionary):
	billing.restore()
	await billing._on_owned_purchases(response)

func fixture(verifier):
	var billing=ClockBilling.new()
	var client=FakeClient.new(); root.add_child(client)
	billing._client=client
	billing.configure_backend(verifier.verify,"fixture-obfuscated-account","fixture-obfuscated-profile")
	var products: Array = []
	for id in Billing.PRODUCTS:
		var option = "remove-ads" if id=="remove_ads" else "early-unlock"
		products.append({"product_id":id,"one_time_purchase_offer_details_list":[{"purchase_option_id":option,"offer_id":null,"formatted_price":"$2.99","rental_details":null}]})
	billing._on_products({"response_code":0,"product_details":products})
	return billing

func restore_lifecycle():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.PRODUCTS[0]
	var completions: Array = []
	billing.restore_finished.connect(func(ok,message): completions.append([ok,message]))
	check(not billing.offer(id).available and not billing.initial_restore_finished(),"Checkout waits for the first authoritative inventory result")
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and billing.restore_status().success and billing.initial_restore_finished(),"Verified initial inventory finishes the startup restore barrier")
	check(billing._client.account=="fixture-obfuscated-account" and billing._client.profile=="fixture-obfuscated-profile","Obfuscated identifiers reach the native client")
	check(verifier.requests[0].obfuscated_account_id=="fixture-obfuscated-account","Backend verification is bound to the authenticated obfuscated account")
	billing.configure_backend(verifier.verify,"fixture-obfuscated-account","fixture-obfuscated-profile")
	check(billing.has_entitlement(id) and billing.initial_restore_finished(),"Refreshing the same configured account does not discard verified rights or reset startup readiness")
	verifier.deferred=true
	billing.restore()
	inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and billing.restore_status().phase=="verifying","Inventory refresh keeps verified access while its server request is pending")
	check(not billing.offer(Billing.PRODUCTS[1]).available and billing.offer(id).pending,"No checkout launches while inventory tokens are being verified")
	var queries=billing._client.restores
	billing.restore()
	check(billing._client.restores==queries,"Repeated resume or restore cannot overlap an in-flight inventory query")
	verifier.approve=false
	verifier.release.emit()
	await process_frame
	check(billing.has_entitlement(id) and not billing.restore_status().success and billing.restore_status().phase=="failed","Transient verification failure retains existing verified rights")
	check(completions.size()==2 and completions[0][0] and not completions[1][0],"Restore completion reports success and retryable failure separately")
	verifier.deferred=false; verifier.approve=true
	await inventory(billing,{"response_code":0,"purchases":[]})
	check(not billing.has_entitlement(id) and billing.restore_status().success and billing.offer(id).available,"Authoritative empty inventory revokes rights and clears stale retry errors after the refresh completes")
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	await inventory(billing,{"response_code":2})
	check(billing.has_entitlement(id),"Failed native inventory query does not erase earlier verified rights")
	await inventory(billing,{"response_code":0,"purchases":"malformed"})
	check(billing.has_entitlement(id),"Malformed inventory cannot masquerade as an authoritative empty inventory")
	billing._client.free()

func purchase_lifecycle():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.PRODUCTS[1]
	var outcomes: Array = []
	billing.purchase_result.connect(func(product,outcome): outcomes.append([product,outcome]))
	await inventory(billing,{"response_code":0,"purchases":[]})
	check(not billing.purchase(id).is_empty() and billing.offer(id).pending,"Checkout remains locked after the native purchase flow launches")
	billing._on_purchase_updated({"response_code":0,"purchases":[record(id,2)]})
	check(not billing.has_entitlement(id) and billing.offer(id).pending and verifier.requests.is_empty(),"Pending payment never verifies, grants or unlocks another checkout")
	verifier.deferred=true
	billing._on_purchase_updated({"response_code":0,"purchases":[record(id)]})
	billing._on_purchase_updated({"response_code":0,"purchases":[record(id)]})
	check(verifier.requests.size()==1 and billing.offer(id).pending and billing.purchase(id).is_empty(),"Duplicate purchase callbacks share one in-flight verification and preserve the checkout lock")
	verifier.release.emit()
	await process_frame
	var granted=outcomes.filter(func(value): return value[1]=="completed")
	check(billing.has_entitlement(id) and granted.size()==1 and not billing.offer(id).pending,"A verified payment grants once even when native callbacks overlap")
	var other=Billing.PRODUCTS[2]
	billing.purchase(other)
	billing._on_purchase_updated({"response_code":0,"purchases":[record(other)]})
	verifier.approve=false; verifier.release.emit()
	await process_frame
	check(not billing.has_entitlement(other) and billing.needs_restore(other) and not billing.offer(other).pending and not billing.offer(other).available,"Verification failure exposes a retryable Restore state without pretending payment is still pending")
	check(billing.can_restore(),"A verifier error does not disable the Restore action")
	verifier.deferred=false; verifier.approve=true
	await inventory(billing,{"response_code":0,"purchases":[record(id),record(other)]})
	check(billing.has_entitlement(other) and not billing.needs_restore(other),"Restore can finish a previously interrupted verified purchase")
	billing._client.free()

func account_switch_and_races():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.PRODUCTS[0]
	await inventory(billing,{"response_code":0,"purchases":[]})
	billing.restore()
	# This snapshot was requested before a newly completed checkout. It must not
	# erase that later grant when its slower verification finishes.
	verifier.deferred=true
	inventory(billing,{"response_code":0,"purchases":[record(Billing.PRODUCTS[1])]})
	verifier.deferred=false
	billing._verify_purchase(record(id),billing._generation)
	verifier.release.emit()
	await process_frame
	check(billing.has_entitlement(id) and billing.has_entitlement(Billing.PRODUCTS[1]),"A slower inventory refresh cannot revoke a purchase completed after its query began")
	billing._client.free()
	verifier=Verifier.new(); billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[]})
	verifier.deferred=true
	billing._verify_purchase(record(id),billing._generation)
	var replacement=Verifier.new()
	billing.configure_backend(replacement.verify,"different-obfuscated-account")
	verifier.release.emit()
	await process_frame
	check(not billing.has_entitlement(id) and not billing.initial_restore_finished() and billing._checking.is_empty(),"An old account's delayed verification cannot grant to a newly configured user")
	billing._client.free()
	var unconfigured=Billing.new()
	unconfigured.restore()
	await unconfigured._on_owned_purchases({"response_code":0,"purchases":[record(id)]})
	check(not unconfigured.has_entitlement(id) and unconfigured.initial_restore_finished() and not unconfigured.restore_status().success,"Missing authenticated verifier fails closed and releases the initial barrier with an error")
	unconfigured.configure_backend(replacement.verify,"person@example.com")
	check(not unconfigured.backend_configured(),"A raw email address cannot be passed as an obfuscated billing identifier")

func pending_and_error_races():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var first=Billing.PRODUCTS[0]
	var second=Billing.PRODUCTS[1]
	await inventory(billing,{"response_code":0,"purchases":[]})
	verifier.deferred=true
	inventory(billing,{"response_code":0,"purchases":[record(first)]})
	billing._verify_purchase(record(second,2),billing._generation)
	verifier.release.emit(); await process_frame
	check(billing.offer(second).pending and not billing.offer(Billing.PRODUCTS[2]).available,"A stale inventory snapshot cannot erase a later pending payment lock")
	inventory(billing,{"response_code":0,"purchases":[record(first),record(second,2)]})
	verifier.deferred=false
	billing._verify_purchase(record(second),billing._generation)
	verifier.release.emit(); await process_frame
	check(billing.has_entitlement(second) and not billing.offer(second).pending and billing.offer(Billing.PRODUCTS[2]).available,"An older pending snapshot cannot re-lock a payment that completed while inventory verification waited")
	billing._client.free()
	verifier=Verifier.new();billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[record(first)]})
	verifier.deferred=true
	inventory(billing,{"response_code":0,"purchases":[record(second),record(first,2)]})
	verifier.deferred=false
	billing._verify_purchase(record(first),billing._generation)
	verifier.release.emit();await process_frame
	check(billing.has_entitlement(first) and billing.has_entitlement(second) and not billing.offer(first).pending,"A newer native confirmation of an existing verified right survives an older pending inventory snapshot")
	billing._client.free()
	verifier=Verifier.new();billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[]})
	verifier.deferred=true
	inventory(billing,{"response_code":0,"purchases":[record(first)]})
	verifier.deferred=false;verifier.approve=false
	billing._verify_purchase(record(second),billing._generation)
	verifier.approve=true;verifier.release.emit();await process_frame
	check(billing.needs_restore(second) and not billing.offer(second).available,"A stale successful inventory refresh cannot clear a newer payment verification error")
	billing._client.free()
	for code in [1,2]:
		verifier=Verifier.new();billing=fixture(verifier)
		await inventory(billing,{"response_code":0,"purchases":[]})
		billing.purchase(first)
		billing._on_purchase_updated({"response_code":0,"purchases":[record(first,2)]})
		billing._on_purchase_updated({"response_code":code})
		check(billing.restore_status().restoring and billing._client.restores>=2,"A pending payment followed by native code%d requests authoritative reconciliation" % code)
		await billing._on_owned_purchases({"response_code":0,"purchases":[]})
		check(not billing.offer(first).pending and billing.offer(first).available and not billing.has_entitlement(first),"Reconciled cancellation/error code%d releases payment locks without granting" % code)
		billing._client.free()
	verifier=Verifier.new();billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[]})
	billing.purchase(first)
	billing._on_purchase_updated({"response_code":0,"purchases":[record(first,2)]})
	billing._on_purchase_updated({"response_code":0,"purchases":[{}]})
	check(billing.restore_status().restoring and not billing.has_entitlement(first),"An incomplete update after a pending payment starts reconciliation without granting")
	await billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(not billing.offer(first).pending and billing.offer(first).available,"Incomplete pending updates do not leave a permanent hidden payment lock")
	billing._client.free()
	verifier=Verifier.new();billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[]})
	billing.purchase(first)
	var suspended=record(first);suspended.is_suspended=true
	billing._verify_purchase(suspended,billing._generation)
	check(billing.restore_status().restoring and not billing.has_entitlement(first),"A suspended purchase cannot grant and requests authoritative restoration")
	await billing._on_owned_purchases({"response_code":0,"purchases":[suspended]})
	check(not billing.offer(first).pending and billing.offer(first).available,"Authoritatively suspended inventory leaves no stuck checkout lock")
	billing._client.free()

func native_query_generations():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	billing.restore()
	var old_generation=billing._generation
	var replacement=Verifier.new()
	billing.configure_backend(replacement.verify,"replacement-account")
	billing.restore()
	check(billing._client.restores==1 and not billing.initial_restore_finished(),"A new account waits for the old native query to drain before issuing another")
	await billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(billing._client.restores==2 and not billing.initial_restore_finished(),"An old account's empty native inventory cannot complete the new account's startup barrier")
	await billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(billing.initial_restore_finished() and billing.restore_status().success,"The new account's own query can finish restoration")
	var pending_events: Array=[]
	billing.purchase_result.connect(func(product,outcome): pending_events.append([product,outcome]))
	await billing._verify_purchase(record(Billing.PRODUCTS[0],2),old_generation)
	check(pending_events.is_empty() and not billing.offer(Billing.PRODUCTS[0]).pending,"A stale-generation pending callback cannot mutate the new account")
	await billing._verify_purchase(record(Billing.PRODUCTS[0]),billing._generation)
	await billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(billing.has_entitlement(Billing.PRODUCTS[0]),"Unsolicited or duplicate native inventory callbacks cannot revoke current rights")
	await inventory(billing,{"response_code":0,"purchases":[{}]})
	check(billing.has_entitlement(Billing.PRODUCTS[0]) and not billing.restore_status().success,"Missing product IDs cannot masquerade as an authoritative empty inventory")
	await inventory(billing,{"response_code":0,"purchases":[{"product_ids":[]}]})
	check(billing.has_entitlement(Billing.PRODUCTS[0]),"Empty product IDs in a purchase record cannot revoke verified rights")
	billing._client.free()

func proof_expiry_and_refresh():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.PRODUCTS[0]
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	var deadline=int(billing._proof_expires_msec[id])
	check(deadline==301000 and billing.has_entitlement(id),"Verified backend callback starts a memory-only five-minute monotonic proof")
	check(is_instance_valid(billing._refresh_timer) and billing._refresh_timer.get_parent()==billing._client and billing._refresh_timer.wait_time==240.0 and not billing._refresh_timer.is_stopped(),"Native client owns an active four-minute proof refresh timer")
	billing.now_msec=241000
	var queries=billing._client.restores
	billing._refresh_verified_rights()
	check(billing._client.restores==queries+1 and billing.restore_status().restoring,"Periodic refresh requests authoritative native inventory before proof expires")
	verifier.approve=false
	await billing._on_owned_purchases({"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and int(billing._proof_expires_msec[id])==deadline,"Transient refresh failure preserves rights only for the original proof lifetime")
	billing.now_msec=deadline-1
	var calls=verifier.requests.size()
	await billing._verify_purchase(record(id),billing._generation)
	check(billing.has_entitlement(id) and verifier.requests.size()==calls and int(billing._proof_expires_msec[id])==deadline,"A duplicate native purchase confirmation cannot extend the backend proof lifetime")
	billing.now_msec=deadline
	check(not billing.has_entitlement(id) and not billing.has_authoritative_absence(id) and billing.needs_restore(id) and not billing.offer(id).available,"Expired proof removes paid access and offers Restore without claiming the purchase was revoked")
	verifier.approve=true;verifier.ttl=99999;verifier.verified_at=999999999999999.0
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and int(billing._proof_expires_msec[id])==billing.now_msec+300000,"Fresh verification restores access while oversized TTL and future server timestamp cannot exceed five minutes")
	queries=billing._client.restores
	var client=billing._client
	root.remove_child(client)
	billing._refresh_verified_rights()
	check(client.restores==queries,"A native client outside the active tree performs no periodic network queries")
	client.free()
	for invalid in [0.0,-1.0,INF,NAN]:
		verifier=Verifier.new();verifier.ttl=invalid;billing=fixture(verifier)
		await inventory(billing,{"response_code":0,"purchases":[record(id)]})
		check(not billing.has_entitlement(id),"Invalid proof TTL cannot grant paid access: "+str(invalid))
		billing._client.free()
	verifier=Verifier.new();verifier.include_metadata=false;billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(not billing.has_entitlement(id),"A positive-looking reply without proof freshness metadata fails closed")
	billing._client.free()
	verifier=Verifier.new();billing=fixture(verifier)
	await inventory(billing,{"response_code":0,"purchases":[]})
	check(billing.has_authoritative_absence(id),"Fresh successful empty inventory can establish authoritative absence")
	billing.now_msec+=300000
	check(not billing.has_authoritative_absence(id),"Old empty inventory cannot establish indefinite revocation")
	billing._client.free()

func remove_ads_checkout_and_refresh():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.REMOVE_ADS_PRODUCT
	check(id=="remove_ads" and not billing.has_authoritative_absence(id),"Remove Ads uses its permanent product ID and starts with unknown ownership")
	await inventory(billing,{"response_code":0,"purchases":[]})
	check(billing.has_authoritative_absence(id),"Fresh Play inventory establishes Remove Ads absence")
	var queries=billing._client.restores
	billing.now_msec+=240000
	billing._refresh_verified_rights()
	check(billing._client.restores==queries+1 and not billing.has_authoritative_absence(id),"An empty inventory is refreshed and cannot authorize ads while the new query is pending")
	await billing._on_owned_purchases({"response_code":2})
	check(not billing.has_authoritative_absence(id),"A failed Remove Ads refresh leaves ownership unknown")
	billing.now_msec+=240000
	billing._refresh_verified_rights()
	check(billing._client.restores==queries+2,"Periodic refresh retries an expired and failed empty inventory")
	await billing._on_owned_purchases({"response_code":0,"purchases":[]})
	check(billing.has_authoritative_absence(id),"Successful retry restores current evidence of absence")
	var wrong_options=[{"purchase_option_id":"early-unlock","formatted_price":"wrong base"},
		{"purchase_option_id":"remove-ads","offer_id":"wrong-offer","formatted_price":"wrong discount"},
		{"purchase_option_id":"remove-ads","rental_details":{},"formatted_price":"wrong rental"}]
	billing._on_products({"response_code":0,"product_details":[{"product_id":id,"one_time_purchase_offer_details_list":wrong_options}]})
	check(not billing.offer(id).available and billing.purchase(id).is_empty(),"Remove Ads rejects the ability option, discounts and rentals")
	var options=wrong_options+[{"purchase_option_id":"remove-ads","formatted_price":"€3.49"}]
	billing._on_products({"response_code":0,"product_details":[{"product_id":id,"one_time_purchase_offer_details_list":options}]})
	check(billing.offer(id).price_label=="€3.49" and not billing.purchase(id).is_empty() and billing._client.calls==[[id,"remove-ads",""]],"Remove Ads launches its permanent Play offer at the localized price")
	check(not billing.has_authoritative_absence(id) and not billing.has_entitlement(id),"An in-progress checkout is neither authoritative absence nor ownership")
	billing._on_purchase_updated({"response_code":0,"purchases":[record(id,2)]})
	check(not billing.has_entitlement(id) and not billing.has_authoritative_absence(id) and verifier.requests.is_empty(),"Pending Remove Ads payment never starts verification or grants ownership")
	verifier.approve=false
	await billing._verify_purchase(record(id),billing._generation)
	check(not billing.has_entitlement(id) and not billing.has_authoritative_absence(id) and billing.needs_restore(id),"Failed Remove Ads verification is unknown and can be retried through Restore")
	verifier.approve=true
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and not billing.has_authoritative_absence(id),"Verified Play inventory restores the Remove Ads entitlement")
	await inventory(billing,{"response_code":0,"purchases":[]})
	check(not billing.has_entitlement(id) and billing.has_authoritative_absence(id),"Authoritatively empty inventory removes restored ad-free ownership")
	verifier.revoked=true
	await billing._verify_purchase(record(id),billing._generation)
	check(billing.has_authoritative_revocation(id) and billing.has_authoritative_absence(id),"A verified refund establishes Remove Ads absence")
	check(not billing.purchase(id).is_empty() and billing.has_authoritative_revocation(id) and not billing.has_authoritative_absence(id),"An old refund cannot establish absence during a new Remove Ads checkout")
	billing._on_purchase_updated({"response_code":1})
	check(billing.has_authoritative_absence(id),"Cancelling the new checkout leaves the original refund in effect")
	billing._client.free()

func signal_reentrancy():
	var replacement=Verifier.new()
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var switched=[false]
	billing.purchase_result.connect(func(_product,outcome):
		if outcome=="pending" and not switched[0]:
			switched[0]=true;billing.configure_backend(replacement.verify,"changed-in-signal"))
	await inventory(billing,{"response_code":0,"purchases":[record(Billing.PRODUCTS[0],2)]})
	check(switched[0] and not billing.initial_restore_finished() and not billing.restore_status().has_verified_inventory,"Reentrant account changes during pending signals prevent old inventory commit")
	for connection in billing.purchase_result.get_connections(): billing.purchase_result.disconnect(connection.callable)
	billing._client.free()

func bound_revocation():
	var verifier=Verifier.new()
	var billing=fixture(verifier)
	var id=Billing.PRODUCTS[0]
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	verifier.approve=false
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and not billing.has_authoritative_revocation(id),"Unbound verification errors cannot revoke a still-valid paid proof")
	verifier.revoked=true;verifier.wrong_revoked_token=true
	await inventory(billing,{"response_code":0,"purchases":[record(id)]})
	check(billing.has_entitlement(id) and not billing.has_authoritative_revocation(id),"A revoked marker for the wrong token cannot remove the requested product")
	verifier.wrong_revoked_token=false;verifier.revoke_product=id
	await inventory(billing,{"response_code":0,"purchases":[record(id),record(Billing.PRODUCTS[1])]})
	check(not billing.has_entitlement(id) and billing.has_authoritative_revocation(id) and billing.has_authoritative_absence(id) and not billing.restore_status().success,"Bound revocation removes the affected right even if another product has a transient restore error")
	verifier.approve=true;verifier.revoked=false
	await billing._verify_purchase(record(id,1,"new-fixture-token"),billing._generation)
	check(billing.has_entitlement(id) and not billing.has_authoritative_revocation(id),"A newly verified repurchase can restore the product")
	verifier.revoked=true;verifier.revoke_token="fixture-token"
	await billing._verify_purchase(record(id),billing._generation)
	check(billing.has_entitlement(id) and not billing.has_authoritative_revocation(id),"Revoking an older token does not erase a newer verified repurchase")
	verifier.revoke_token="new-fixture-token"
	await inventory(billing,{"response_code":0,"purchases":[record(id,1,"new-fixture-token")]})
	check(not billing.has_entitlement(id) and billing.has_authoritative_revocation(id),"An exact denial for the current token can revoke its verified in-memory right")
	billing._client.free()

func _initialize(): call_deferred("run")
func run():
	check(Billing.PACKAGE=="com.sungati.sugarfall","Native billing uses the Play Console package")
	var billing=fixture(Verifier.new())
	var old_package_record=record(Billing.PRODUCTS[0])
	old_package_record.package_name="com.qriscuit.sugarfall"
	check(not billing._purchase_records([old_package_record]).ok,"A purchase from the earlier package cannot enter native verification")
	billing._client.free()
	await restore_lifecycle()
	await purchase_lifecycle()
	await account_switch_and_races()
	await pending_and_error_races()
	await native_query_generations()
	await proof_expiry_and_refresh()
	await remove_ads_checkout_and_refresh()
	await signal_reentrancy()
	await bound_revocation()
	print("NATIVE_BILLING_QA_RESULT passed=%d failed=%d" % [passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
