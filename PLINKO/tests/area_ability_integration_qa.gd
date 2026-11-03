extends SceneTree
## Real input, campaign transactions and provider boundaries; profile IO is intercepted.
const Campaign=preload("res://scripts/area_campaign.gd")
const Access=preload("res://scripts/area_ability_access.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var fail_write=false
	var writes=0
	var candidate: Dictionary={}
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): assert(false,"Integration fixture must not read player profiles")
	func write_profile_file(data: Dictionary) -> bool:
		writes+=1;candidate=data.duplicate(true)
		return not fail_write

func check(value: bool,label: String):
	if value: passed+=1
	else: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func fixture(area: String):
	var g=Fixture.new()
	g.testing=false;g.sound_on=false;g.page_transition.enabled=false
	g.first_run_guide.completed=true;g.first_run_guide.active=false
	g.set_active_area(area);Campaign.apply_local(g,Campaign.default_record())
	g.area_records={"bakery":Campaign.default_record(),"gelato":Campaign.default_record(),"crystal":Campaign.default_record()}
	g.area_records.bakery.bank=111;g.area_records.gelato.bank=222;g.area_records.crystal.bank=333
	g.mode="home";g.shift_claimed=true;g.run_id="";g.bank=5000
	g.current_level=1;g.highest_unlocked=1;g.navigation_delay=0
	return g

func touch(g,point: Vector2,pressed: bool,index: int=0,canceled: bool=false):
	var event=InputEventScreenTouch.new()
	event.position=g.to_global(point);event.index=index;event.pressed=pressed;event.canceled=canceled
	g._input(event)

func drag(g,point: Vector2,index: int=0):
	var event=InputEventScreenDrag.new()
	event.position=g.to_global(point);event.index=index
	g._input(event)

func tap(g,rect: Rect2):
	g.navigation_delay=0;g.pause_transition.update(0)
	touch(g,rect.get_center(),true);touch(g,rect.get_center(),false)

func open_offer(g):
	tap(g,g.ability_ui.HOME_RECT)
	check(g.mode=="ability_offer",g.area_id+" Home offer opens through its actual touch target")

func buy_preview(g):
	tap(g,g.ability_ui.EARLY_RECT)
	check(g.ability_ui.stage=="confirm" and not g.ability_access.pending.is_empty(),g.area_id+" early purchase opens an explicit test confirmation")
	tap(g,g.ability_ui.EARLY_RECT)

func gestures():
	for area in Campaign.IDS:
		var g=fixture(area);var rect: Rect2=g.ability_ui.HOME_RECT;var p=rect.get_center()
		check(g.home_menu.target_at(p)=="ability",area+" offer wins over underlying tray Play target")
		touch(g,p,true);touch(g,p,false,0,true)
		check(g.mode=="home" and g.run_id.is_empty(),area+" canceled Home tap never launches or buys")
		touch(g,p,true);drag(g,p+Vector2(0,35));touch(g,p+Vector2(0,35),false)
		check(g.mode=="home",area+" Home drag cannot open offer")
		touch(g,p,true);touch(g,p,true,1);touch(g,p,false,1);touch(g,p,false)
		check(g.mode=="home",area+" multi-touch cannot open offer")
		open_offer(g);g.navigation_delay=0;p=g.ability_ui.EARLY_RECT.get_center()
		touch(g,p,true)
		g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		touch(g,p,false)
		check(g.ability_ui.stage=="details" and g.ability_access.pending.is_empty(),area+" backgrounding cancels an armed purchase before release")
		touch(g,p,true);touch(g,p,false,0,true)
		check(g.ability_ui.stage=="details" and g.ability_access.pending.is_empty(),area+" canceled purchase touch grants nothing")
		touch(g,p,true);drag(g,p+Vector2(25,0));touch(g,p+Vector2(25,0),false)
		check(g.ability_access.pending.is_empty(),area+" dragged purchase touch grants nothing")
		touch(g,p,true);touch(g,p,true,1);touch(g,p,false,1);touch(g,p,false)
		check(g.ability_access.pending.is_empty(),area+" multi-touch cannot queue payment")
		g.navigation_delay=1;touch(g,p,true);touch(g,p,false)
		check(g.ability_access.pending.is_empty(),area+" navigation debounce blocks payment")
		tap(g,g.ability_ui.EARLY_RECT);var request=g.ability_access.pending.id
		tap(g,g.ability_ui.RESTORE_RECT)
		check(g.ability_ui.stage=="details" and g.ability_access.pending.is_empty() and not g.ability_ui.owned(),area+" cancel closes test confirmation without ownership")
		check(g.ability_access.resolve_preview(request,"completed").is_empty(),area+" canceled callback cannot grant access")
		g.page_transition.enabled=true;g.page_transition.active=true;g.navigation_delay=0
		touch(g,p,true);touch(g,p,false)
		check(g.ability_access.pending.is_empty(),area+" page transition blocks offer touch input")
		g.free()

func earned_and_paid():
	for area in Campaign.IDS:
		var g=fixture(area);open_offer(g)
		g.highest_unlocked=7;g.levels[1]=6 if area=="gelato" else 4
		if area=="gelato": g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
		var wallet=g.bank
		tap(g,g.ability_ui.EARN_RECT)
		check(not g.ability_ui.owned() and g.bank==wallet,area+" coin path stays locked before tray8")
		g.highest_unlocked=8
		tap(g,g.ability_ui.EARN_RECT)
		check(g.ability_ui.owned() and g.ability_unlock_source=="earned" and g.bank==wallet-g.ability_ui.cost(),area+" tray8 earned button buys its exact coin price")
		var state=Campaign.capture_local(g)
		tap(g,g.ability_ui.EARN_RECT);tap(g,g.ability_ui.EARLY_RECT)
		check(Campaign.capture_local(g)==state and g.ability_access.pending.is_empty(),area+" owned ability cannot be charged again")
		g.mode="home";g.navigation_delay=0
		check(g.begin_trial(8) and not g.ability_ui.owned(),area+" Trial disables earned ability")
		g.end_trial()
		check(g.ability_ui.owned() and g.ability_unlock_source=="earned",area+" leaving Trial restores earned ownership")
		g.free()
		g=fixture(area);g.levels[1]=2
		if area=="gelato": g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
		open_offer(g);wallet=g.bank;var before=Campaign.capture_local(g)
		g.fail_write=true;buy_preview(g)
		check(not g.ability_ui.owned() and not g.ability_access.has_early_access(area) and Campaign.capture_local(g)==before,area+" failed paid save rolls back receipt, flags, Power and wallet atomically")
		check(not g.ability_access.pending.is_empty(),area+" failed save retains one retryable request")
		g.fail_write=false;tap(g,g.ability_ui.EARLY_RECT)
		check(g.ability_ui.owned() and g.ability_unlock_source=="preview" and g.bank==wallet and g.highest_unlocked==1,area+" paid early path works at tray1 without spending coins")
		if area=="gelato":
			check(g.levels[1]==0 and g.power_reset_tier==2 and g.gelato_reset_power_nodes.size()==2,"Paid Dual Shot performs the same one-time Power reset")
			g.levels[1]=1;g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
			check(g.ability_ui.restore_activation() and g.levels[1]==1,"Restoring already active Dual Shot never resets rebuilt Power again")
		state=Campaign.capture_local(g)
		tap(g,g.ability_ui.EARLY_RECT)
		check(Campaign.capture_local(g)==state and g.ability_access.pending.is_empty(),area+" paid ownership cannot be bought twice")
		g.free()

func area_reset_and_public():
	var g=fixture("bakery");open_offer(g);buy_preview(g)
	var bakery=Campaign.capture_local(g);g.mode="home";g.navigation_delay=0
	check(g.switch_area("gelato") and g.bank==222 and not g.ability_ui.owned(),"Switching preserves separate Gelato money and locked ability")
	check(g.area_records.bakery==bakery,"Switching retains Bakery paid source and wallet")
	g.mode="home";g.navigation_delay=0
	check(g.switch_area("bakery") and g.ability_ui.owned() and g.bank==bakery.bank,"Revisit restores Bakery ability and independent wallet")
	g.mode="reset_confirm"
	check(g.reset_progress() and g.bank==0 and not g.bakery_jam_burst,"Reset clears earned area progression")
	check(g.ability_access.has_early_access("bakery"),"Reset preserves the paid early-access receipt")
	g.first_run_guide.active=false;g.first_run_guide.completed=true;g.mode="home";g.navigation_delay=0
	open_offer(g);tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.owned() and g.ability_unlock_source=="preview" and g.bank==0,"Restore reactivates paid ability after reset without coins")
	g.free()
	for area in Campaign.IDS:
		g=fixture(area);open_offer(g);buy_preview(g)
		g.testing=true;g.start_shift();g.run_transition.finish()
		if area=="bakery":
			for index in range(5): g.spawn_ball(Vector2(360,267),"normal",Vector2(0,85),false)
		var saved=Snapshot.capture(g)
		check(Snapshot.validate_and_decode(saved,g).ok,area+" verified preview-paid active run is resumable")
		var preview=g.ability_access.export_state()
		# Public restoration is a fresh process, not a provider swap underneath a
		# running simulation whose ability access is deliberately pinned.
		var public=fixture(area)
		Campaign.apply_local(public,Campaign.capture_local(g))
		public.run_rules_revision=g.run_rules_revision
		public.ability_access=Access.new(false)
		check(not public.ability_access.import_state(preview) and not public.ability_ui.owned(),area+" public service cannot trust saved preview receipt")
		check(not Snapshot.validate_and_decode(saved,public).ok,area+" public run decoder rejects preview-paid active ability")
		public.ability_unlock_source="earned"
		check(public.ability_ui.owned(),area+" legitimate earned flags remain usable with public provider")
		public.free();g.free()

func restore_feedback():
	var g=fixture("bakery");open_offer(g);buy_preview(g)
	g.mode="home";g.navigation_delay=0
	check(g.switch_area("gelato"),"Restore feedback fixture switches away from its purchased Bakery ability")
	g.ability_access.clear_preview_benefits();open_offer(g)
	g.fail_write=true;tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.message=="Could not restore. Try again." and not g.ability_access.has_early_access("bakery"),"Failed other-area restore reports retry and leaves entitlement rolled back")
	g.fail_write=false;tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.message=="Purchases restored" and g.ability_access.has_early_access("bakery") and not g.ability_ui.owned(),"Other-area receipts restore successfully without granting this area's ability")
	g.free()
	g=fixture("bakery");open_offer(g);buy_preview(g)
	g.ability_access.clear_preview_benefits();g.bakery_jam_burst=false
	g.fail_write=true;tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.message=="Could not restore. Try again." and not g.bakery_jam_burst and not g.ability_access.has_early_access("bakery"),"Failed current-area restore reports retry and rolls back both ability and entitlement")
	g.fail_write=false;tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.message=="Purchases restored" and g.ability_ui.owned(),"Retry restores current-area ability and reports success")
	g.free()
	g=fixture("bakery");g.ability_access=Access.new(false);open_offer(g)
	tap(g,g.ability_ui.RESTORE_RECT)
	check(g.ability_ui.message=="Store unavailable" and not g.ability_ui.owned(),"Public restore without a configured provider reports unavailable without granting access")
	g.free()

func entitlement_loss_checkpoint():
	for area in Campaign.IDS:
		var g=fixture(area)
		g.ability_access=Access.new(false)
		g.ability_unlock_source="preview"
		if area=="bakery": g.bakery_jam_burst=true
		elif area=="gelato": g.twin_launchers=true
		else: g.crystal_second_prism=true
		g.testing=true;g.start_shift();g.run_transition.finish()
		check(not g.ability_ui.owned(),area+" newly started public run disables an unverified saved ability")
		var saved=Snapshot.capture(g)
		check(Snapshot.validate_and_decode(saved,g).ok,area+" newly started base run remains resumable after old paid access is unavailable")
		var history=Campaign.capture_local(g)
		check(g.restore_active_run(saved) and Campaign.capture_local(g)==history and not g.ability_ui.owned(),area+" restoring a base run retains inactive campaign activation history")
		g.free()

func _initialize():
	gestures();earned_and_paid();area_reset_and_public();restore_feedback();entitlement_loss_checkpoint()
	print("AREA_ABILITY_INTEGRATION_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
