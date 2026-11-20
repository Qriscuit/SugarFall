extends SceneTree
## Real snapshot/disk roundtrips in an explicit isolated output directory only.
const Access=preload("res://scripts/area_ability_access.gd")
var passed=0
var failures: Array[String]=[]
var directory=""

class Game extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func _notification(_what): pass

class Store extends RefCounted:
	signal restore_finished(success: bool, message: String)
	var configured=false
	var entitled=false
	var authoritative=false
	var expired_without_revocation=false
	var explicit_revoked=false
	var requests=0
	func backend_configured(): return configured
	func restore_status(): return {"configured":configured,"success":authoritative,"has_verified_inventory":authoritative,"restoring":false}
	func has_entitlement(_product): return entitled
	func has_authoritative_absence(_product): return explicit_revoked or (configured and authoritative and not entitled and not expired_without_revocation)
	func has_authoritative_revocation(_product): return explicit_revoked
	func offer(_product): return {"available":false,"pending":false,"price_label":"$2.99","error":"Unavailable"}
	func purchase(_product): return {}
	func restore(): requests+=1
	func can_restore(): return configured
	func needs_restore(_product): return not entitled

class Ads extends Node:
	var state: Dictionary={"version":1,"sentinel":"retained"}
	func export_state(): return state.duplicate(true)
	func import_state(value): state=value.duplicate(true)
	func has_reward(_area,_run): return false
	func enabled(): return false
	func advance_campaign_play(_dt): pass
	func complete_attempt(_run): pass
	func has_pending(): return false
	func set_suspended(_value): pass

func check(ok: bool, message: String):
	if ok: passed+=1
	else: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func fixture(area: String, file: String):
	var game=Game.new()
	game.testing=true;game.sound_on=false;game.page_transition.enabled=false
	game.first_run_guide.completed=true;game.first_run_guide.active=false
	game.SAVE_FILE=file
	game.set_active_area(area)
	game.AreaCampaign.apply_local(game,game.AreaCampaign.default_record())
	game.area_records={"bakery":game.AreaCampaign.default_record(),"gelato":game.AreaCampaign.default_record(),"crystal":game.AreaCampaign.default_record()}
	game.current_level=1;game.highest_unlocked=8;game.bank=123.45
	game.mode="home";game.shift_claimed=true
	game.ability_access=Access.new(false)
	var store=Store.new();game.ability_ui.billing=store;game.ability_access.bind_provider(store)
	store.restore_finished.connect(game._on_purchase_restore_finished)
	game.native_ad_service=Ads.new();game.add_child(game.native_ad_service)
	return game

func read_profile(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(file))

func build_paid(area: String, file: String) -> Dictionary:
	var game=fixture(area,file)
	game.ability_ui.billing.entitled=true
	if area=="gelato":
		game.levels[1]=6;game.gelato_shop_revision=0;game.ensure_gelato_shop_state()
	check(game.ability_ui.controller().activate("store"),"Fixture uses the real paid ability transformation: "+area)
	game.start_shift();game.run_transition.finish();game.step(.35);game.mode="paused"
	check(game.save_game(),"Paid checkpoint fixture writes only its isolated file: "+area)
	var data=read_profile(file)
	check(data.has("active_run") and data.areas[area].ability_unlock_source=="store","Fixture includes a store-paid active checkpoint: "+area)
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished)
	game.free()
	return data

func run_area(area: String):
	var file=directory.path_join(area+"-paid.json")
	var original=build_paid(area,file)
	var bytes=FileAccess.get_file_as_bytes(file)
	var game=fixture("bakery",file)
	game.load_game()
	check(game.mode=="home" and game.has_deferred_paid_run() and game.profile_load_blocked and game.snapshot_rejection.is_empty(),"Offline cold start defers its paid checkpoint without rejecting it: "+area)
	check(FileAccess.get_file_as_bytes(file)==bytes and not game.save_game() and FileAccess.get_file_as_bytes(file)==bytes,"Load/background saving cannot erase the unverified checkpoint: "+area)
	check(game.native_ad_service.state==original.native_ads,"Native ad state imports independently of purchase availability: "+area)
	game.current_level=2
	var envelope=game.profile_envelope(game.area_records,game.area_id,game.area_entries)
	var serialized=JSON.parse_string(JSON.stringify(envelope,"",true,true))
	check(serialized.active_run==original.active_run and serialized.active_run_rules==original.active_run_rules and serialized.areas[area]==original.areas[area],"Deferred serialization preserves exact snapshot, rules and paid campaign provenance: "+area)
	check(envelope.native_ads==original.native_ads,"Profile serialization retains the native ads namespace: "+area)
	var serial=game.run_serial
	game.start_shift(true)
	check(game.mode=="home" and game.run_serial==serial and game.has_deferred_paid_run(),"Play becomes a restore retry instead of replacing the saved run: "+area)
	game.mode="trials"
	check(not game.begin_trial(4) and not game.trial_active,"Practice cannot mutate a deferred campaign checkpoint: "+area)
	game.mode="home"
	game.ability_ui.billing.configured=true
	game.retry_purchase_restore()
	check(game.ability_ui.billing.requests==1,"The explicit Restore action requests the configured provider: "+area)
	game.ability_ui.billing.authoritative=true;game.ability_ui.billing.expired_without_revocation=true
	game._on_purchase_restore_finished(true,"")
	check(game.has_deferred_paid_run() and FileAccess.get_file_as_bytes(file)==bytes,"An expired proof is not treated as authoritative purchase revocation: "+area)
	game.ability_ui.billing.authoritative=false;game.ability_ui.billing.expired_without_revocation=false
	game._on_purchase_restore_finished(false,"Offline")
	check(game.has_deferred_paid_run() and FileAccess.get_file_as_bytes(file)==bytes,"Transient verification errors keep the original checkpoint: "+area)
	game.ability_ui.billing.authoritative=true;game.ability_ui.billing.entitled=true
	game.testing=false
	game.ability_ui.billing.restore_finished.emit(true,"")
	check(game.mode=="paused" and not game.has_deferred_paid_run() and not game.profile_load_blocked and game.ability_ui.owned(),"Verified restoration resumes the original paid run paused: "+area)
	var restored=read_profile(file)
	check(restored.active_run==original.active_run and restored.areas[area].ability_unlock_source=="store","Verified retry preserves active physics and ownership source without replaying a purchase: "+area)
	if area=="gelato": check(game.power_reset_tier==6 and game.levels[1]==0,"Restoring Dual Shot never applies Power reset twice")
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished)
	game.free()
	# A successful authoritative empty inventory is different from being offline.
	file=directory.path_join(area+"-revoked.json")
	original=build_paid(area,file)
	game=fixture("bakery",file);game.load_game()
	game.ability_ui.billing.configured=true;game.ability_ui.billing.authoritative=true
	game.testing=false;game.ability_ui.billing.restore_finished.emit(true,"")
	var revoked=read_profile(file)
	check(not game.has_deferred_paid_run() and not game.profile_load_blocked and game.mode=="home" and not revoked.has("active_run"),"Authoritative absence can retire the unusable paid checkpoint: "+area)
	check(revoked.areas[area]==original.areas[area] and not game.ability_ui.owned(),"Revocation keeps campaign money, levels and transformation history without granting access: "+area)
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished)
	game.free()

func ordinary_offline():
	var file=directory.path_join("ordinary.json")
	var game=fixture("bakery",file)
	game.start_shift();game.run_transition.finish();game.step(.2);game.mode="paused"
	check(game.save_game(),"Ordinary isolated checkpoint saves")
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished);game.free()
	game=fixture("bakery",file);game.load_game()
	check(game.mode=="paused" and not game.has_deferred_paid_run() and not game.profile_load_blocked,"Ordinary offline checkpoints restore without waiting for a purchase server")
	game.mode="home";var serial=game.run_serial;game.start_shift()
	check(game.mode=="play" and game.run_serial==serial+1,"Ordinary offline campaign Play remains available")
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished);game.free()

func incompatible_paid_checkpoint():
	var file=directory.path_join("incompatible-paid.json")
	var data=build_paid("bakery",file)
	data.active_run.fingerprint="incompatible-synthetic-fixture"
	var stream=FileAccess.open(file,FileAccess.WRITE)
	stream.store_string(JSON.stringify(data,"",true,true));stream.close()
	var bytes=FileAccess.get_file_as_bytes(file)
	var game=fixture("bakery",file);game.load_game()
	game.ability_ui.billing.configured=true;game.ability_ui.billing.authoritative=true;game.ability_ui.billing.entitled=true
	game.testing=false;game.ability_ui.billing.restore_finished.emit(true,"")
	check(game.has_deferred_paid_run() and game.profile_load_blocked and game.mode=="home","A verified purchase does not erase a checkpoint that fails independent snapshot validation")
	check(FileAccess.get_file_as_bytes(file)==bytes,"Incompatible paid checkpoint bytes remain available for recovery")
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished);game.free()

func explicit_revocation():
	var file=directory.path_join("explicit-revoked.json")
	var original=build_paid("bakery",file)
	var game=fixture("bakery",file);game.load_game()
	game.ability_ui.billing.configured=true;game.ability_ui.billing.explicit_revoked=true
	game.testing=false;game.ability_ui.billing.restore_finished.emit(false,"Other product unavailable")
	var saved=read_profile(file)
	check(not game.has_deferred_paid_run() and not game.profile_load_blocked and not saved.has("active_run"),"Explicit bound revocation can retire the affected checkpoint despite an unrelated restore error")
	check(saved.areas.bakery==original.areas.bakery,"Explicit revocation preserves campaign economy and paid transformation history")
	game.ability_ui.billing.restore_finished.disconnect(game._on_purchase_restore_finished);game.free()

func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): directory=argument.trim_prefix("--output-dir=")
	if not directory.is_absolute_path() or directory.begins_with("user://"):
		push_error("An explicit absolute isolated --output-dir is required");quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	for area in ["bakery","gelato","crystal"]: run_area(area)
	ordinary_offline()
	incompatible_paid_checkpoint()
	explicit_revocation()
	print("PURCHASE_RESTORE_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
