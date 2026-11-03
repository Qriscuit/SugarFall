extends "res://tests/bakery_ability_save_qa.gd"
## Regression: unavailable paid access may disable physics, never erase the
## historical Twin transformation or prevent a new ordinary run from resuming.
const Access=preload("res://scripts/area_ability_access.gd")

func make_game(preview: bool=false):
	var g=fixture()
	g.set_active_area("gelato");Campaign.apply_local(g,Campaign.default_record())
	g.ability_access=Access.new(preview)
	g.ability_access.bind_provider(g.ability_ui.billing)
	g.mode="home";g.current_level=8;g.highest_unlocked=8;g.bank=5000
	g.levels[1]=6;g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
	return g

func verified_test_grant(g):
	# Test-only injection at the trusted provider seam, never save-file input.
	g.ability_ui.billing._entitlements[Access.CATALOG.gelato.product_id]=true

func access_loss(source: String):
	var g=make_game(source=="preview")
	if source=="preview":
		var request=g.ability_access.request_preview("gelato")
		g.ability_access.resolve_preview(request.id,"completed")
	else: verified_test_grant(g)
	check(g.gelato_launcher.activate(source) and g.levels[1]==0 and g.power_reset_tier==6,source+" initial activation applies the Twin transformation once")
	g.levels[1]=2;g.gelato_shop_revision=0;g.ensure_gelato_shop_state()
	var reset_nodes=g.gelato_reset_power_nodes.duplicate(true)
	var owned_nodes=g.gelato_owned_nodes.duplicate(true)
	var receipt=g.ability_access.export_state()
	g.start_shift();g.run_transition.finish();g.testing=false
	check(g.save_game() and Snapshot.capture(g).twin_launchers,source+" active paid checkpoint saves its real Twin physics")
	var public=make_game();public.load_game()
	check(public.mode=="home" and not public.snapshot_rejection.is_empty() and not public.gelato_launcher.is_twin(),source+" public/revoked access still rejects the old paid checkpoint")
	check(public.twin_launchers and public.power_reset_tier==6 and public.levels[1]==2 and same(public.gelato_reset_power_nodes,reset_nodes),source+" unavailable access preserves prior activation and rebuilt Power")
	public.start_shift();public.run_transition.finish();public.testing=false
	var ordinary=Snapshot.capture(public)
	check(not ordinary.twin_launchers and ordinary.power_reset_tier==0 and public.save_game(),source+" fresh ordinary run saves effective physics without losing campaign history")
	var bytes=FileAccess.get_file_as_bytes(save_path)
	var restored=make_game();restored.load_game()
	check(restored.mode=="paused" and restored.resumed_run and not restored.gelato_launcher.is_twin(),source+" fresh ordinary checkpoint resumes with one launcher")
	check(restored.twin_launchers and restored.power_reset_tier==6 and restored.levels[1]==2 and same(restored.gelato_owned_nodes,owned_nodes) and same(restored.gelato_reset_power_nodes,reset_nodes),source+" ordinary resume does not overwrite campaign activation or reset nodes")
	check(same(Snapshot.capture(restored),ordinary) and FileAccess.get_file_as_bytes(save_path)==bytes,source+" ordinary resume is exact and does not rewrite saved bytes")
	public.testing=true;restored.testing=true;restored.mode="play";restored.pause_transition.settle()
	for step in range(60): public.step(1.0/120);restored.step(1.0/120)
	check(same(Snapshot.capture(public),Snapshot.capture(restored)),source+" resumed base physics matches uninterrupted base physics")
	# Finish the run before restoring access: a provider callback must not alter
	# the pinned physics of balls that are already on the board.
	restored.mode="home";restored.shift_claimed=true;restored.run_id=""
	if source=="preview":
		restored.ability_access=Access.new(true);restored.ability_access.import_state(receipt)
	else: verified_test_grant(restored)
	check(restored.ability_ui.restore_activation() and restored.gelato_launcher.is_twin() and restored.levels[1]==2 and restored.power_reset_tier==6 and same(restored.gelato_reset_power_nodes,reset_nodes),source+" restored access never resets rebuilt Power a second time")
	g.free();public.free();restored.free()

func run():
	access_loss("preview")
	access_loss("store")

func _initialize():
	save_path=OS.get_environment("SUGARFALL_BAKERY_ABILITY_QA_SAVE")
	var expected=OS.get_user_data_dir().replace("\\","/")+"/"
	if save_path.is_empty() or not save_path.is_absolute_path() or not save_path.replace("\\","/").begins_with(expected) or "--bakery-ability-save-qa-isolated" not in OS.get_cmdline_user_args():
		push_error("Entitlement save QA requires its explicit isolated namespace and opt-in marker");quit(2);return
	run()
	print("AREA_ABILITY_ENTITLEMENT_SAVE_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
