extends SceneTree
## Synthetic transport/auth fixtures only. No Firebase/Google request or real payment.
var passed = 0
var failed: Array[String] = []

class Verifier extends "res://scripts/firebase_purchase_verifier.gd":
	var calls: Array = []
	var backend: Dictionary = {}
	var saves = 0
	var auth_delay = 1
	var backend_delay = 1
	var signup_response = {"ok":true,"data":{"idToken":"synthetic.id.token","refreshToken":"synthetic-refresh","expiresIn":"3600"}}
	var refresh_response = {"ok":true,"data":{"id_token":"refreshed.id.token","refresh_token":"synthetic-refresh","expires_in":"3600","project_id":"demo-sugarfall","token_type":"Bearer"}}
	var backend_queue: Array = []
	func _save_refresh(): saves += 1
	func _load_refresh(): pass
	func _post(url: String, data: Dictionary, headers: PackedStringArray = PackedStringArray()) -> Dictionary:
		calls.append({"url":url,"data":data.duplicate(true),"headers":headers})
		var reply: Dictionary
		var frames = auth_delay
		if url.begins_with("https://identitytoolkit.googleapis.com/"):
			reply = signup_response.duplicate(true)
		elif url.begins_with("https://securetoken.googleapis.com/"):
			reply = refresh_response.duplicate(true)
		else:
			reply = (backend_queue.pop_front() if not backend_queue.is_empty() else backend).duplicate(true)
			frames = backend_delay
		for i in range(frames): await get_tree().process_frame
		return reply

class Job extends RefCounted:
	var done = false
	var result: Dictionary = {}
	func start(client, purchase):
		result = await client.verify_purchase(purchase)
		done = true

func wait_jobs(jobs: Array):
	for i in range(24):
		if jobs.all(func(job):return job.done): return
		await process_frame
	check(false,"Synthetic concurrent requests finish within the fixture frame bound")

func check(value: bool, label: String):
	if value: passed += 1
	else: failed.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _initialize():
	print("FIREBASE_VERIFIER_QA_USER_DIR=",OS.get_user_data_dir())
	call_deferred("run")

func run():
	var client = Verifier.new()
	check(client.PACKAGE=="com.sungati.sugarfall","Server verifier uses the Play Console package")
	root.add_child(client)
	client.persist_auth = false
	var config={"verification_url":"https://example.invalid/verifyPurchase","firebase_web_api_key":"synthetic-key","firebase_project_id":"demo-sugarfall"}
	check(not client.configure({}),"Missing account configuration cannot enable checkout verification")
	var insecure=config.duplicate();insecure.verification_url="http://example.invalid/verify"
	check(not client.configure(insecure),"Purchase tokens are never sent to an HTTP endpoint")
	for endpoint in ["https://","https://user@example.invalid/verify","https://example.invalid/#fragment","https://example.invalid/?token=query","https://bad host/verify","https://-bad.invalid/verify","https://example.invalid:8443/verify"]:
		var invalid_config=config.duplicate();invalid_config.verification_url=endpoint
		check(not client.configure(invalid_config),"Malformed, credential-bearing or nonstandard endpoint is rejected: "+endpoint)
	check(not client.configure({"billing":"invalid"}),"Malformed nested configuration fails without a script error")
	check(client.configure(config),"Complete HTTPS project configuration is accepted")
	var native_request = client._new_http_request()
	check(native_request.max_redirects==0 and native_request.timeout==15.0 and native_request.body_size_limit==65536,"Actual HTTP request policy disables redirects and bounds time/body size; no live request performed")
	native_request.free()
	for request in [{},{"package_name":"wrong","product_id":"sugarfall_bakery_ability","purchase_token":"test"},{"package_name":"com.qriscuit.sugarfall","product_id":"sugarfall_bakery_ability","purchase_token":"test"},{"package_name":client.PACKAGE,"product_id":"coins","purchase_token":"test"},{"package_name":client.PACKAGE,"product_id":"sugarfall_bakery_ability","purchase_token":""}]:
		check((await client.verify_purchase(request)).get("verified",false)==false,"Malformed or foreign purchase cannot request a grant")
	check(client.calls.is_empty(),"Invalid requests perform no authentication or verification traffic")
	var purchase={"package_name":client.PACKAGE,"product_id":"sugarfall_bakery_ability","purchase_token":"synthetic-purchase-token"}
	var proof=purchase.duplicate();proof.merge({"verified":true,"acknowledged":true,"purchase_state":"purchased","purchase_option_id":"early-unlock","verified_at":1700000000000,"revalidate_after_seconds":300})
	var old_package_proof=proof.duplicate()
	old_package_proof.package_name="com.qriscuit.sugarfall"
	check(not client._valid_proof(old_package_proof,purchase.product_id,purchase.purchase_token),"Earlier-package server proof cannot grant a purchase")
	for property in ["verified","acknowledged","purchase_state","package_name","product_id","purchase_token","purchase_option_id","verified_at","revalidate_after_seconds"]:
		var malformed=proof.duplicate();malformed[property]=false if property in ["verified","acknowledged"] else "wrong"
		client.backend={"ok":true,"data":malformed}
		check((await client.verify_purchase(purchase)).get("verified",false)==false,"Server response must prove exact "+property)
	client.backend={"ok":false,"code":503,"error":"unavailable"}
	check((await client.verify_purchase(purchase)).get("verified",false)==false,"Network/backend failure grants nothing")
	client.backend={"ok":true,"data":proof}
	check((await client.verify_purchase(purchase))==proof,"Exact verified and acknowledged permanent purchase passes through")
	var auth_calls=client.calls.filter(func(call):return call.url.begins_with("https://identitytoolkit.googleapis.com/"))
	check(auth_calls.size()==1,"Sequential synthetic verifications reuse the cached Firebase ID token")
	var sent: Dictionary=client.calls.back()
	check(sent.data==purchase and sent.headers==PackedStringArray(["Authorization: Bearer synthetic.id.token"]),"Backend receives only exact purchase identifiers with Firebase authentication")
	var ad_purchase={"package_name":client.PACKAGE,"product_id":"remove_ads","purchase_token":"synthetic-ad-purchase-token"}
	var ad_proof=proof.duplicate()
	ad_proof.merge(ad_purchase,true)
	client.backend={"ok":true,"data":ad_proof}
	check(not (await client.verify_purchase(ad_purchase)).get("verified",false),"An early-unlock proof cannot grant Remove Ads")
	ad_proof.purchase_option_id="remove-ads"
	check((await client.verify_purchase(ad_purchase))==ad_proof and client.calls.back().data==ad_purchase,"Remove Ads requires exact permanent proof bound to the Play product and token")
	client.backend={"ok":true,"data":proof}
	client._expires_at=0
	check((await client.verify_purchase(purchase))==proof,"Expired identity refreshes without losing Play token ownership")
	check(client.calls.filter(func(call):return call.url.begins_with("https://securetoken.googleapis.com/")).size()==1,"Expired identity uses the refresh endpoint once")
	client.backend={"ok":false,"code":401}
	await client.verify_purchase(purchase)
	check(client._id_token.is_empty(),"Unauthorized responses invalidate the in-memory Firebase identity")
	# Real concurrent coroutines, with a yielding fake transport, share one auth job.
	client.configure(config);client.calls.clear();client.backend={"ok":true,"data":proof}
	var first=Job.new();var second=Job.new()
	first.start(client,purchase);second.start(client,purchase)
	await wait_jobs([first,second])
	check(first.result.get("verified",false) and second.result.get("verified",false),"Two concurrent synthetic callers both receive bound proof")
	check(client.calls.filter(func(call):return call.url.begins_with("https://identitytoolkit.googleapis.com/")).size()==1,"Concurrent synthetic callers create one anonymous authentication request")
	# A new config must release old waiters and fence the old leader's response.
	client.configure(config);client.calls.clear();client.auth_delay=3
	first=Job.new();second=Job.new();first.start(client,purchase);second.start(client,purchase)
	var replacement=config.duplicate();replacement.firebase_project_id="demo-replacement";replacement.verification_url="https://replacement.invalid/verifyPurchase"
	client.configure(replacement)
	await wait_jobs([first,second])
	check(not first.result.get("verified",false) and not second.result.get("verified",false),"Config change rejects both the old auth leader and waiting request")
	check(client._id_token.is_empty() and client._refresh_token.is_empty() and not client._authenticating,"Old authentication cannot populate the replacement project's credential cache")
	client.configure(config);client.auth_delay=4
	first=Job.new();second=Job.new();first.start(client,purchase);second.start(client,purchase)
	client.configure(replacement);client.auth_delay=1
	client.signup_response={"ok":true,"data":{"idToken":"replacement.id.token","refreshToken":"replacement-refresh","expiresIn":"3600"}}
	var replacement_job=Job.new();replacement_job.start(client,purchase)
	await wait_jobs([first,second,replacement_job])
	check(replacement_job.result.get("verified",false) and not first.result.get("verified",false) and not second.result.get("verified",false),"New configuration can authenticate while old concurrent jobs are fenced")
	check(client._id_token=="replacement.id.token" and client._refresh_token=="replacement-refresh","Late old authentication leaves the newer project's credentials intact")
	client.signup_response={"ok":false,"code":503};client.configure(config);client.calls.clear()
	first=Job.new();second=Job.new();first.start(client,purchase);second.start(client,purchase)
	await wait_jobs([first,second])
	check(not first.result.get("verified",false) and not second.result.get("verified",false) and not client._authenticating,"Shared authentication failure releases all concurrent callers")
	check(client.calls.size()==1,"Shared authentication failure performs one synthetic signup attempt")
	client.signup_response={"ok":true,"data":{"idToken":"synthetic.id.token","refreshToken":"synthetic-refresh","expiresIn":"3600"}}
	# Config change after auth but before a backend reply also fences that proof.
	client.configure(config);client.auth_delay=1;client.backend_delay=4;client.calls.clear()
	first=Job.new();first.start(client,purchase)
	for i in range(2): await process_frame
	client.configure(replacement)
	await wait_jobs([first])
	check(not first.result.get("verified",false),"In-flight backend proof from the previous configuration is discarded")
	client.configure(config);client.backend_delay=1;client.calls.clear();client._refresh_token="synthetic-refresh"
	client.refresh_response={"ok":false,"code":503,"error":"unavailable"}
	check(not (await client.verify_purchase(purchase)).get("verified",false),"Refresh outage grants nothing")
	check(client.calls.size()==1 and client._refresh_token=="synthetic-refresh","Refresh outage retains its credential and does not create another anonymous account")
	for reason in ["USER_DISABLED","PROJECT_NUMBER_MISMATCH"]:
		client.calls.clear();client.refresh_response={"ok":false,"code":400,"data":{"error":{"message":reason}}}
		check(not (await client.verify_purchase(purchase)).get("verified",false) and client.calls.size()==1,"Refresh "+reason+" cannot be bypassed with anonymous signup")
	client.calls.clear();client.refresh_response={"ok":false,"code":400,"data":{"error":{"message":"INVALID_REFRESH_TOKEN"}}}
	check((await client.verify_purchase(purchase)).get("verified",false),"Explicit invalid refresh credential can recover with a fresh anonymous identity and bound backend proof")
	check(client.calls.filter(func(call):return call.url.begins_with("https://identitytoolkit.googleapis.com/")).size()==1,"Invalid-credential recovery creates one new anonymous account")
	# A late 401 for the old identity must not erase a later refreshed identity.
	client.backend_delay=4;client.backend_queue=[{"ok":false,"code":401}]
	first=Job.new();first.start(client,purchase)
	client._id_token="newer.id.token";client._expires_at=int(Time.get_unix_time_from_system())+3600
	await wait_jobs([first])
	check(client._id_token=="newer.id.token","Late unauthorized reply cannot wipe a newer in-memory identity")
	client.backend_delay=1
	# Revocation is constructed only from the known authoritative HTTP error pairs.
	for pair in [["purchase_cancelled","cancelled"],["purchase_not_found","revoked"],["purchase_refunded_or_invalid_quantity","revoked"],["purchase_consumed_or_unknown","revoked"]]:
		client.backend={"ok":false,"code":403,"data":{"verified":false,"acknowledged":false,"retryable":false,"error":pair[0],"purchase_state":pair[1]}}
		var denied = await client.verify_purchase(purchase)
		check(denied.get("revoked",false) and denied.get("verified",true)==false and denied.get("package_name")==purchase.package_name and denied.get("product_id")==purchase.product_id and denied.get("purchase_token")==purchase.purchase_token,"Authoritative "+pair[0]+" revocation binds exact outstanding purchase identifiers")
	for response in [{"ok":false,"code":403},{"ok":false,"code":503,"data":{"verified":false,"acknowledged":false,"retryable":false,"error":"purchase_not_found","purchase_state":"revoked"}},{"ok":false,"code":403,"data":{"verified":false,"acknowledged":false,"retryable":true,"error":"purchase_not_found","purchase_state":"revoked"}}]:
		client.backend=response
		check(not (await client.verify_purchase(purchase)).get("revoked",false),"Generic or transient HTTP failure does not manufacture a revocation")
	for invalid in [{"verified":1},{"acknowledged":1},{"verified_at":INF},{"revalidate_after_seconds":301},{"revalidate_after_seconds":true}]:
		var invalid_proof=proof.duplicate();invalid_proof.merge(invalid,true);client.backend={"ok":true,"data":invalid_proof}
		check(not (await client.verify_purchase(purchase)).get("verified",false),"Proof fields must be typed and bounded: "+str(invalid.keys()))
	for invalid_auth in [{"idToken":"bad\r\nheader","refreshToken":"refresh","expiresIn":"3600"},{"idToken":"synthetic.id.token","refreshToken":"refresh","expiresIn":"invalid"},{"idToken":"synthetic.id.token","refreshToken":"","expiresIn":"3600"}]:
		client.configure(config);client.signup_response={"ok":true,"data":invalid_auth};client.calls.clear()
		check(not (await client.verify_purchase(purchase)).get("verified",false) and client._id_token.is_empty(),"Malformed synthetic auth response cannot be cached or sent as a header")
	check(client.persist_auth==false,"Synthetic fixture keeps credentials out of player profiles")
	client.queue_free()
	print("FIREBASE_VERIFIER_QA_RESULT passed=%d failed=%d" % [passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
