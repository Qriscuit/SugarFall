extends SceneTree
## Area entry and shop integration; all profile IO is intercepted in memory.
var passed=0
var failures: Array[String]=[]

class Fixture extends "res://scripts/main.gd":
	var writes=0
	var reads=0
	var fail_write=false
	var candidate={}
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): reads+=1
	func save_game(): return true
	func write_profile_file(value: Dictionary) -> bool:
		writes+=1
		candidate=value.duplicate(true)
		return not fail_write
	func area_content_ready(id: String) -> bool: return area_boards(id).size()==12
	func developer_tools_available() -> bool: return true

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fresh():
	var g=Fixture.new()
	g.testing=true;g.sound_on=false
	g.first_run_guide.active=false;g.first_run_guide.completed=true
	g.mode="home";g.shift_claimed=true;g.run_id=""
	g.navigation_delay=0;g.result_input_delay=0;g.run_transition.finish()
	g.bank=800;g.levels=[1,2,0,0,0,0,0,0]
	g.area_records={"bakery":g.AreaCampaign.capture_local(g)}
	return g

func completed_gelato(g):
	var record=g.AreaCampaign.default_record()
	record.bank=2000;record.current_level=12;record.highest_unlocked=12;record.best_wave=12;record.chapter_complete=true
	g.area_records.gelato=record

func entry_checks():
	var g=fresh();completed_gelato(g)
	check(g.area_entry_status("crystal").can_enter and g.area_entry_status("crystal").cost==1500,"A completed funded Gelato record can unlock Crystal while Bakery is active")
	check(g.enter_area("crystal") and g.area_id=="crystal" and g.writes==1,"One atomic entry opens Crystal from another active area's picker")
	check(g.area_records.bakery.bank==800 and g.area_records.gelato.bank==500 and g.bank==0,"Crystal entry debits only the Gelato wallet and starts the Crystal wallet at zero")
	check(g.levels==[0,0,0,0,0,0,0,0] and not g.crystal_second_prism and not g.twin_launchers and g.highest_unlocked==1,"Crystal starts at tray one without either area's special purchase or upgrades")
	check(g.candidate.version==5 and g.candidate.area_entries==g.area_entries and g.area_entries[0].source=="gelato" and g.area_entries[0].destination=="crystal","The v5 entry ledger names the actual charged predecessor")
	check(not g.enter_area("crystal") and g.writes==1,"Repeated entry cannot charge or reset Crystal again")
	g.bank=88;g.levels=[1,4,0,0,0,0,0,0];g.highest_unlocked=6;g.crystal_second_prism=true
	var crystal=g.AreaCampaign.capture_local(g)
	check(g.switch_area("bakery") and g.bank==800 and not g.crystal_second_prism,"Revisiting Bakery restores its wallet without Crystal's Prism ownership")
	check(g.switch_area("crystal") and g.AreaCampaign.capture_local(g)==crystal,"Returning to Crystal restores its own upgrades, wallet, and Second Prism")
	var valid=g.profile_envelope(g.area_records,"crystal",g.area_entries)
	valid.areas.crystal=crystal
	check(g.AreaCampaign.decode_profile(valid).ok,"The completed three-area candidate validates with its independent records")
	var malformed=valid.duplicate(true);malformed.areas.bakery.crystal_second_prism=true
	check(not g.AreaCampaign.decode_profile(malformed).ok,"A Crystal purchase cannot appear in Bakery's record")
	malformed=valid.duplicate(true);malformed.areas.crystal.erase("crystal_second_prism")
	check(not g.AreaCampaign.decode_profile(malformed).ok,"Version five requires an explicit Crystal ownership flag")
	for version in [3,4]:
		var legacy=valid.duplicate(true);legacy.version=version
		for id in legacy.areas: legacy.areas[id].erase("crystal_second_prism")
		var decoded=g.AreaCampaign.decode_profile(legacy)
		check(decoded.ok and not decoded.records.crystal.crystal_second_prism,"Legacy version%d defaults missing Second Prism ownership to false"%version)
	malformed=valid.duplicate(true);malformed.area_entries[0].source="bakery"
	check(not g.AreaCampaign.decode_profile(malformed).ok,"Crystal's ledger rejects a fabricated Bakery-to-Crystal payment")
	check(g.reads==0,"Area and migration fixtures never load a player profile")
	g.free()
	g=fresh();completed_gelato(g);g.fail_write=true
	var before=g.AreaCampaign.capture_local(g);var records=g.area_records.duplicate(true)
	check(not g.enter_area("crystal") and g.AreaCampaign.capture_local(g)==before and g.area_records==records and g.area_id=="bakery","Failed entry writes roll back both wallets, active area, and ownership")
	g.free()

func developer_checks():
	var g=fresh();g.mode="developer_areas"
	check(g.developer_switch_area("crystal") and g.area_entries.is_empty() and not g.area_owned("gelato"),"Developer entry can test Crystal directly without a paid entry or fabricated Gelato ownership")
	g.bank=47;g.levels[0]=1;g.mode="developer_areas"
	check(g.developer_switch_area("bakery") and g.bank==800,"Developer return retains the original Bakery wallet")
	g.mode="developer_areas"
	check(g.developer_switch_area("crystal") and g.bank==47 and g.levels[0]==1,"Developer revisits retain Crystal's existing working build")
	check(g.AreaCampaign.decode_profile(g.candidate).ok,"A direct developer Crystal record is a valid save without a paid ledger")
	g.free()

func board_and_shop_checks():
	var g=fresh();g.set_active_area("crystal");g.AreaCampaign.apply_local(g,g.AreaCampaign.default_record());g.mode="shop"
	check(g.board_data.size()==12 and g.tuning.gravity==0 and g.tuning.launcher_interval==1.15 and g.tuning.base_power_damage==2.0,"Crystal loads twelve trays and its independent straight-shot balance")
	var board_valid=true
	for index in range(12):
		var board=g.board_data[index]
		board_valid=board_valid and board.base_hp==[6,12,18,24][index/3] and board.positions.size()==board.peg_count
		for p in board.positions: board_valid=board_valid and p[0]>=50 and p[0]<=670 and p[1]>=290 and p[1]<=900
	check(board_valid,"All twelve authored trays obey their three-tray HP walls and safe saved-position bounds")
	var map=g.upgrade_map;map.reset_view_state();map.update(0)
	check(g.upgrade_graph().nodes().size()==62 and map._positions.size()==63 and map.visible_nodes()==[Vector2i(0,1),map.TWIN_NODE],"Crystal has its own 62-slot map plus the visible locked Second Prism")
	check(map.node_rect(8,1,false).position.y>map.node_rect(0,1,false).end.y and map.node_rect(8,1,false).end.y<map.TWIN_CARD_RECT.position.y,"Second Prism sits below the starter and clears its purchase card")
	check(map.state_for(8,1)=="locked" and map._twin_gate_text()=="Tray 8 · Power 4","Second Prism clearly states both progression gates")
	g.bank=1000;map.selected=0;map.tier=1;map.press(map.buy_rect().get_center());map.update(map.CAMERA_DURATION)
	check(g.levels[0]==1 and map.visible_nodes().size()==5,"Buying Crystal's starter reveals three independent paths alongside Second Prism")
	var framed=true
	for route in g.upgrade_graph().routes(): framed=framed and map.focus_area().encloses(map.node_rect(route[0].x,route[0].y,false))
	check(framed,"The opening camera frames all three Crystal choices")
	g.highest_unlocked=8;g.levels[1]=3;g.bank=900
	check(map.state_for(8,1)=="locked","Tray eight alone cannot bypass the Power requirement")
	g.levels[1]=4;g.highest_unlocked=7
	check(map.state_for(8,1)=="locked","Power four alone cannot bypass the tray requirement")
	g.highest_unlocked=8;g.bank=899
	check(map.state_for(8,1)=="unaffordable","Second Prism is red when its eligible wallet is one coin short")
	g.bank=900
	check(map.state_for(8,1)=="affordable" and map.SURFACE[map.state_for(8,1)]=="upgrade_tile_green","Second Prism turns green when its 900-coin price is affordable")
	var levels=g.levels.duplicate();map.twin_selected=true;map.selected=-1
	map.press(map.buy_rect().get_center())
	check(g.crystal_second_prism and g.bank==0 and g.levels==levels and map.twin_selected and map.state_for(8,1)=="owned","Buying Second Prism charges once, preserves every upgrade, and keeps its owned card selected")
	map.press(map.buy_rect().get_center())
	check(g.bank==0 and g.levels==levels and not g.twin_launchers,"Inspecting an owned Second Prism cannot charge again or enable Gelato twins")
	check(map._effect_text(0,1)=="Fire candy faster" and map._effect_text(2,1)=="Keep shots in play" and map._effect_text(3,1)=="Stay in play longer when equipped","Crystal cards explain firing and flight without misleading bounce arithmetic")
	check(g.reads==0,"Shop fixtures never load a player profile")
	g.free()

func _initialize():
	entry_checks();developer_checks();board_and_shop_checks()
	print("CRYSTAL_AREA_UI_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
