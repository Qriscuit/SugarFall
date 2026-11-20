extends "res://tests/gelato_upgrade_map_qa.gd"
## Real ownership/state transitions for the selected-price presentation.

func unlock_power(game) -> Vector2i:
	for step in range(16):
		var power: Vector2i=game.next_shop_node(1)
		if power.x>=0: return power
		var bought=false
		for node in game.upgrade_graph().nodes():
			if not game.shop_node_owned(node.x,node.y) and game.shop_node_unlocked(node.x,node.y):
				bought=game.buy_upgrade_node(node.x,node.y)
				break
		if not bought: break
	return Vector2i(-1,-1)

func selection_checks():
	for area in ["bakery","gelato","crystal"]:
		var game=fresh(area); var map=game.upgrade_map
		var power=unlock_power(game)
		check(power.x==1,"Legal purchases reveal a Power upgrade: "+area)
		map.selected=power.x;map.tier=power.y;map.twin_selected=false
		check(map.state_for(power.x,power.y)=="affordable" and map.shows_selected_price(power),"Selected affordable ordinary node displays its required amount: "+area)
		map.selected=-1
		check(not map.shows_selected_price(power),"Deselection restores ordinary upgrade artwork: "+area)
		map.selected=power.x;game.bank=0
		check(map.state_for(power.x,power.y)=="unaffordable" and map.shows_selected_price(power),"Selected unaffordable ordinary node still displays required amount: "+area)
		var cost=game.upgrade_cost(power.x);game.bank=cost
		check(game.buy_upgrade_node(power.x,power.y) and game.bank==0,"Selected ordinary upgrade still spends the exact existing price once: "+area)
		check(map.state_for(power.x,power.y)=="owned" and not map.shows_selected_price(power),"Owned selection retains its artwork and check: "+area)
		var hidden=Vector2i(1,game.MAX_LEVELS[1]);map.selected=hidden.x;map.tier=hidden.y
		check(not map.node_visible(hidden.x,hidden.y) and not map.shows_selected_price(hidden),"Unavailable hidden upgrade cannot display a selectable price: "+area)
		map.twin_selected=true;map.selected=-1
		check(map.state_for(8,1)=="locked" and map.shows_selected_price(map.TWIN_NODE),"Selected unowned signature displays earned price while card retains gate and paid route: "+area)
		var original=game.AreaCampaign.capture_local(game).duplicate(true)
		check(map.node_cost(map.TWIN_NODE)==game.ability_ui.cost() and not map._twin_gate_text().is_empty(),"Signature amount uses existing earned cost and preserves gate disclosure: "+area)
		map.twin_selected=false
		check(not map.shows_selected_price(map.TWIN_NODE) and game.AreaCampaign.capture_local(game)==original,"Deselecting signature restores icon without any ownership or wallet mutation: "+area)
		game.highest_unlocked=8;game.levels[1]=6 if area=="gelato" else 4
		if area=="gelato": stage_legacy_counts(game,game.levels)
		game.bank=game.ability_ui.cost()
		check(game.ability_ui.controller().buy(),"Existing earned transaction purchases the signature for the owned-state check: "+area)
		map.twin_selected=true
		check(map.state_for(8,1)=="owned" and not map.shows_selected_price(map.TWIN_NODE),"Owned signature selection retains its status: "+area)
		var left=[map.TWIN_TITLE_RECT,map.TWIN_STATUS_RECT,map.TWIN_MESSAGE_RECT]+map.TWIN_EFFECT_RECTS
		var clear=map.TWIN_CARD_RECT.size.y<=240 and map.TWIN_PAID_RECT.position.y-map.TWIN_BUY_RECT.end.y>=12
		for rect in left: clear=clear and map.TWIN_CARD_RECT.grow(-24).encloses(rect) and rect.end.x+16<=map.TWIN_BUY_RECT.position.x
		check(clear,"Compact signature copy and two stacked actions occupy separate padded columns: "+area)
		for i in range(map._twin_effect_lines().size()):
			var line: String=map._twin_effect_lines()[i]
			var body_size: int=map.card_font_size(line,map.TWIN_EFFECT_RECTS[i],21)
			print("COMPACT_CARD_FONT area=%s line=%d size=%d"%[area,i,body_size])
			check(body_size>=18,"Signature effect stays readable inside compact description column: "+area+" "+str(i))
		check(game.profile_io==0,"Selected-price checks never read or write a player profile: "+area)
		game.free()
	var game=fresh("bakery");var map=game.upgrade_map
	game.highest_unlocked=10;game.levels=game.MAX_LEVELS.duplicate();game.bank=game.ability_ui.cost();game.ability_ui.controller().buy()
	map.reset_view_state();map.twin_selected=false;map.selected=8;map.tier=2
	check(map.state_for(8,2)=="affordable" and map.node_cost(map.MORE_JAM_NODE)==0 and map.shows_selected_price(map.MORE_JAM_NODE),"Selected available More Jam uses its existing Free requirement")
	check(game.bakery_ability.quick_buy(),"Free More Jam still uses its existing unlock transaction")
	check(map.state_for(8,2)=="owned" and not map.shows_selected_price(map.MORE_JAM_NODE),"Owned More Jam restores its icon and status")
	game.free()

func _initialize():
	selection_checks()
	print("UPGRADE_SELECTION_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
