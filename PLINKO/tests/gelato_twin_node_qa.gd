extends "res://tests/gelato_upgrade_map_qa.gd"
## Optional Twin map node and plain, padded upgrade descriptions.

func twin_node_checks():
	var game = fresh()
	var map = game.upgrade_map
	var twin: Vector2i = map.TWIN_NODE
	var parent_tier: int = int(game.tuning.twin_unlock_power)
	check(parent_tier==6 and game.upgrade_graph().nodes().size()==62 and map._positions.size()==63 and map.node_visible(8,1),"Dual Shot is visible from the start without adding a saved upgrade family")
	check(map.node_prerequisites(twin)==[Vector2i(0,1)] and map._positions[twin]==Vector2(0,440),"Dual Shot connects directly beneath the central starter")
	tap(game,map.point(8,1),71)
	check(map.twin_selected and map.selected_node()==twin and map._twin_gate_text()=="Tray 8 · Power 6","The initial locked Dual Shot card clearly explains both purchase requirements")
	var fresh_bank: float = game.bank
	tap(game,map.buy_rect().get_center(),71)
	check(not game.twin_launchers and game.bank==fresh_bank and game.levels==[0,0,0,0,0,0,0,0],"Inspecting and pressing the initial locked card does not spend or grant upgrades")
	game.highest_unlocked = 8; map.update(0)
	check(map.state_for(8,1)=="locked" and not game.buy_twin_launchers(),"Reaching tray 8 alone does not bypass the Power 6 requirement")
	game.highest_unlocked = 7
	game.levels = game.MAX_LEVELS.duplicate(); game.levels[1] = parent_tier-1
	stage_legacy_counts(game,game.levels)
	map.twin_selected = false
	map.selected = 1; map.tier = parent_tier
	var bank: float = game.bank
	var price: int = game.upgrade_cost(1)
	map.press(map.buy_rect().get_center())
	check(game.bank==bank-price and game.levels[1]==parent_tier and map.node_visible(8,1) and map.state_for(8,1)=="locked","Buying Power 6 keeps Dual Shot visible while the tray gate remains locked")
	check(not map.twin_selected,"Buying Power 6 continues normal discovery without jumping back to the already visible Dual Shot")
	var twin_nodes: Array[Vector2i] = [twin]
	map._frame_nodes(twin_nodes); map.update(map.CAMERA_DURATION)
	tap(game,map.point(8,1),71)
	check(map.twin_selected and map.selected_node()==twin and game.levels[1]==parent_tier,"A real touch selects the Twin map tile without buying it")
	tap(game,map.buy_rect().get_center(),71)
	check(not game.twin_launchers and map.state_for(8,1)=="locked","A locked Twin node cannot purchase through its card")
	game.highest_unlocked = 8; game.bank = game.gelato_launcher.cost()-1
	map.update(0)
	check(map.state_for(8,1)=="unaffordable","Discovered Twin shows an unaffordable state when the wallet is short")
	game.bank += 1; map.update(0)
	check(game.gelato_launcher.cost()==3000 and map.state_for(8,1)=="affordable" and map.SURFACE[map.state_for(8,1)]=="upgrade_tile_green","Discovered Twin becomes green at its increased 3000-coin cost")
	var owned: Array = game.levels.duplicate()
	tap(game,map.buy_rect().get_center(),71)
	owned[1] = 0
	check(game.twin_launchers and game.bank==0 and game.levels==owned and game.power_reset_tier==parent_tier,"Twin node buys through the existing transaction, resets only Power and charges once")
	check(map.state_for(8,1)=="owned" and map.node_visible(8,1) and map.node_visible(1,parent_tier) and game.is_rebuild_power_node(map.selected,map.tier),"Owned Twin and reset Power remain visible after the reset, with an eligible reset slot selected")
	game.bank = game.upgrade_cost(1)
	check(map.state_for(1,1)=="affordable" and map.SURFACE[map.state_for(1,1)]=="upgrade_tile_green","The first Power rebuild is green as soon as its price is affordable")
	game.bank = 0
	game.levels = [0,0,0,0,0,0,0,0]; game.power_reset_tier = 0
	stage_legacy_counts(game,game.levels)
	map.reset_view_state(); map.update(0)
	check(map.node_visible(8,1) and map.state_for(8,1)=="owned","An old save with only the Twin flag still displays its owned node even without a Power history")
	map._frame_nodes(twin_nodes); map.update(map.CAMERA_DURATION)
	tap(game,map.point(8,1),17); tap(game,map.buy_rect().get_center(),17)
	check(game.bank==0 and game.levels==[0,0,0,0,0,0,0,0] and map.twin_selected,"Inspecting an old owned Twin node cannot charge or reset again")
	stage_legacy_counts(game,game.MAX_LEVELS); map.update(0)
	var geometry = [var_to_bytes(map._positions),var_to_bytes(map._paths)]
	for at_zoom in [map.minimum_zoom(),map.INITIAL_ZOOM,map.MAX_ZOOM]:
		map.zoom = at_zoom
		var clear = true
		for node in game.upgrade_graph().nodes(): clear = clear and not map.node_rect(8,1,false).intersects(map.node_rect(node.x,node.y,false))
		check(clear,"Twin has clear tile spacing at zoom %s" % str(at_zoom))
	var start: Vector2 = map._positions[map.TWIN_PARENT]
	var finish: Vector2 = map._positions[twin]
	var no_crossing = true
	for edge in map._paths:
		if edge.z==8: continue
		var path: PackedVector2Array = map._paths[edge]
		for segment in range(path.size()-1):
			var crossing = Geometry2D.segment_intersects_segment(start,finish,path[segment],path[segment+1])
			if crossing!=null and crossing.distance_to(start)>1: no_crossing = false
	check(no_crossing and map.arc_art.area_world_rect("gelato").encloses(Rect2(finish-map.TILE_SIZE*.5,map.TILE_SIZE)),"Twin's connecting edge crosses no unrelated path and its tile stays inside the scenery")
	map.twin_selected = false; map.zoom = map.minimum_zoom()
	map._frame_nodes(map.visible_nodes()); map.update(map.CAMERA_DURATION)
	var overview = true
	for node in map.visible_nodes(): overview = overview and map.focus_area().encloses(map.node_rect(node.x,node.y,false))
	check(overview,"The full-map overview includes all 62 upgrades and the optional Twin node")
	game.set_active_area("bakery"); game.mode="shop"; map.update(0)
	check(map.node_visible(8,1) and game.ability_ui.title()=="Jam Burst" and game.upgrade_graph().nodes().size()==62 and map._positions.size()==64 and map._positions.has(map.MORE_JAM_NODE),"Bakery retains 62 ordinary upgrades plus its own Jam Burst and More Jam nodes")
	game.set_active_area("gelato"); game.mode="shop"; map.update(0)
	check([var_to_bytes(map._positions),var_to_bytes(map._paths)]==geometry and map.node_visible(8,1),"Returning to Gelato restores the exact Twin branch and owned appearance")
	game.twin_launchers = false; game.levels = game.MAX_LEVELS.duplicate(); game.levels[1] = parent_tier-1; game.bank = 1000000
	stage_legacy_counts(game,game.levels)
	map.reset_view_state(); map.update(0)
	map.selected = 1; map.tier = parent_tier
	map.press(map.buy_rect().get_center())
	check(not map.twin_selected and map.selected_node()!=twin,"A legacy Power purchase does not select the already visible Dual Shot as a new discovery")
	check(game.profile_io==0,"Twin map integration performs no player profile IO")
	game.free()

func copy_and_padding():
	var numeric_stats = RegEx.new()
	numeric_stats.compile("[0-9]|%")
	for area in ["bakery","gelato"]:
		var game = fresh(area)
		var map = game.upgrade_map
		for family in range(8):
			var description: String = map._effect_text(family,game.MAX_LEVELS[family])
			check(description==game.UPGRADE_DESC[family] and numeric_stats.search(description)==null and game.font.get_string_size(description,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x<=map.CARD_EFFECT_RECT.size.x,"%s family %d uses short functional copy that fits without number stats or shrinking" % [area,family])
			var font_size: int = map.card_font_size(description,map.CARD_EFFECT_RECT,21)
			check(font_size>=19 and game.font.get_height(font_size)<=map.CARD_EFFECT_RECT.size.y,"%s family %d description has readable font height inside its own row" % [area,family])
			game.levels[family] = game.MAX_LEVELS[family]-1
			var label = "Buy · %s" % game.credits_text(game.upgrade_cost(family))
			var button_text: Rect2 = map.BUY_RECT.grow(-24)
			font_size = map.card_font_size(label,button_text,26)
			check(font_size>=16 and game.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=button_text.size.x and game.font.get_height(font_size)<=button_text.size.y,"%s family %d maximum price fits both dimensions inside the Buy button" % [area,family])
		var padded = true
		for rect in [map.CARD_TITLE_RECT,map.CARD_STATUS_RECT,map.CARD_EFFECT_RECT,map.BUY_RECT]: padded = padded and map.CARD_RECT.grow(-24).encloses(rect)
		padded = padded and not map.CARD_EFFECT_RECT.intersects(map.BUY_RECT)
		check(padded,"%s standard card text and Buy control stay at least 24px inside the panel" % area)
		var twin_padded = map.TWIN_CARD_RECT.grow(-24).encloses(map.TWIN_TITLE_RECT) and map.TWIN_CARD_RECT.grow(-24).encloses(map.TWIN_STATUS_RECT) and map.TWIN_CARD_RECT.grow(-24).encloses(map.TWIN_BUY_RECT)
		for index in range(map._twin_effect_lines().size()):
			var line: String = map._twin_effect_lines()[index]
			twin_padded = twin_padded and numeric_stats.search(line)==null and map.TWIN_CARD_RECT.grow(-24).encloses(map.TWIN_EFFECT_RECTS[index]) and game.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x<=map.TWIN_EFFECT_RECTS[index].size.x
		check(twin_padded,"%s Twin copy fits the padded panel with explicit reset, slower drops and stronger costly rebuilds" % area)
		game.free()

func _initialize():
	twin_node_checks()
	copy_and_padding()
	print("GELATO_TWIN_NODE_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
