extends SceneTree
## Real map and purchase integration with all persistence intercepted in memory.
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	var profile_io = 0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): profile_io += 1
	func save_game(): profile_io += 1; return false
	func write_profile_file(_data: Dictionary) -> bool: profile_io += 1; return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func fresh(area: String = "gelato"):
	var game = Fixture.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	game.first_run_guide.active = false
	game.set_active_area(area)
	game.mode = "shop"
	game.shift_claimed = true
	game.run_id = ""
	game.run_transition.finish()
	game.navigation_delay = 0
	game.result_input_delay = 0
	game.bank = 100000000.0
	game.levels = [0,0,0,0,0,0,0,0]
	game.ensure_gelato_shop_state()
	game.upgrade_map.reset_view_state()
	game.upgrade_map.update(0)
	return game

func stage_legacy_counts(game, values: Array):
	# Deliberately stage an old count-only save, then use the real migration.
	game.levels=values.duplicate()
	game.gelato_shop_revision=0 if game.area_id=="gelato" else 1
	game.gelato_owned_nodes=[]; game.gelato_reset_power_nodes=[]
	check(game.ensure_gelato_shop_state(),"Legacy-count fixture migrates to explicit slot ownership")

func touch(game, point: Vector2, index: int, pressed: bool, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = game.to_global(point)
	event.pressed = pressed
	event.canceled = canceled
	game._input(event)

func move_touch(game, start: Vector2, finish: Vector2, index: int):
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = game.to_global(finish)
	event.relative = game.to_global(finish)-game.to_global(start)
	game._input(event)

func tap(game, point: Vector2, index: int = 0):
	touch(game,point,index,true)
	touch(game,point,index,false)

func drag(game, start: Vector2, finish: Vector2, index: int):
	touch(game,start,index,true)
	move_touch(game,start,finish,index)
	touch(game,finish,index,false)

func swipe_to_node(game, node: Vector2i):
	var map = game.upgrade_map
	var start: Vector2 = map.focus_area().get_center()
	var budget = ceili(start.distance_to(map.point(node.x,node.y))/240.0)+3
	for swipe in range(budget):
		var to_node: Vector2 = start-map.point(node.x,node.y)
		if to_node.length()<1.0: break
		drag(game,start,start+to_node.limit_length(240.0),17)

func purchase_entry_and_reveal():
	var game = fresh()
	var map = game.upgrade_map
	check(map._layout_area=="gelato" and map.visible_nodes()==[Vector2i(0,1),map.TWIN_NODE],"Fresh Gelato shows the central starter and the locked Dual Shot below it")
	check(map._positions[Vector2i(0,1)]==Vector2.ZERO and is_equal_approx(map.point(0,1).x,360) and map.point(0,1).y>300 and map.point(0,1).y<620 and map.node_rect(0,1,false).end.y<map.TWIN_CARD_RECT.position.y,"The entry tile opens near the screen center above purchase controls")
	check(map.node_rect(8,1,false).position.y>map.node_rect(0,1,false).end.y and map.node_rect(8,1,false).end.y<map.TWIN_CARD_RECT.position.y and map.state_for(8,1)=="locked","Dual Shot is fully visible below the starter and remains locked")
	var bank: float = game.bank
	tap(game,map.point(0,1))
	check(map.selected==0 and map.tier==1 and game.bank==bank and game.levels[0]==0,"Tapping the starter selects its card without purchasing")
	var price: int = game.upgrade_cost(0)
	tap(game,map.buy_rect().get_center())
	check(game.levels[0]==1 and is_equal_approx(game.bank,bank-price),"A separate Buy tap purchases exactly Feed 1 at its normal cost")
	var left: Vector2i=game.upgrade_graph().routes()[0][0]
	var right: Vector2i=game.upgrade_graph().routes()[1][0]
	check(map.visible_nodes()==[Vector2i(0,1),left,right,map.TWIN_NODE],"Starter purchase reveals both exact mixed-tree head slots while retaining locked Dual Shot")
	check(map.selected==0 and map.tier==1,"The two-way fork keeps the owned starter selected so the player chooses a path")
	map.update(map.CAMERA_DURATION)
	check(map.focus_area().encloses(map.node_rect(left.x,left.y,false)) and map.focus_area().encloses(map.node_rect(right.x,right.y,false)),"Both newly revealed paths are framed together clear of fixed controls")
	check(map.focus_area().encloses(map.node_rect(0,1,false)) and map.node_rect(8,1,false).end.y<map.TWIN_CARD_RECT.position.y,"The first fork keeps the central start and Dual Shot together on screen")
	tap(game,map.point(1,1))
	bank = game.bank
	price = game.upgrade_cost(1)
	tap(game,map.buy_rect().get_center())
	check(game.levels[1]==1 and is_equal_approx(game.bank,bank-price) and game.levels[7]==0,"Buying Power spends once on the left path without buying the right path")
	var next: Vector2i = game.upgrade_graph().routes()[0][1]
	check(map.selected==next.x and map.tier==next.y and map.node_visible(next.x,next.y),"Power purchase selects and reveals its actual immediate successor")
	map.update(map.CAMERA_DURATION)
	check(map.focus_area().encloses(map.node_rect(next.x,next.y,false)),"The successor camera lands clear of the fixed purchase card and launcher selector")
	game.bank = 0
	map.update(0)
	var owned: Array = game.levels.duplicate()
	var selected = Vector2i(map.selected,map.tier)
	tap(game,map.buy_rect().get_center())
	check(game.levels==owned and game.bank==0 and Vector2i(map.selected,map.tier)==selected and map.state_for(next.x,next.y)=="unaffordable","An unaffordable purchase preserves ownership and selection")
	check(map.node_visible(next.x,next.y) and map.node_visible(right.x,right.y),"Both next choices remain visible when money runs out")
	check(game.profile_io==0,"Entry and reveal tests never read or write player profiles")
	game.free()

func both_real_routes():
	for side in range(2):
		var game = fresh()
		var graph = game.upgrade_graph()
		var map = game.upgrade_map
		game.buy_upgrade_node(0,1)
		map.update(0)
		var expected = [1,0,0,0,0,0,0,0]
		var route: Array = graph.routes()[side]
		for index in range(route.size()):
			var node: Vector2i = route[index]
			map.selected = node.x
			map.tier = node.y
			var bank: float = game.bank
			var price: int = game.upgrade_cost(node.x)
			var before: Array = map.visible_nodes()
			map.press(map.buy_rect().get_center())
			expected[node.x] += 1
			check(game.levels==expected and is_equal_approx(game.bank,bank-price),"Actual Gelato route %d step %d buys only its intended tier" % [side,index+1])
			var choices = []
			for visible in map.visible_nodes():
				if visible not in before and node in map.node_prerequisites(visible): choices.append(visible)
			if choices.size()>1:
				check(Vector2i(map.selected,map.tier)==node,"A Gelato fork keeps the purchased card selected so either new path can be chosen")
			elif index+1<route.size():
				check(Vector2i(map.selected,map.tier)==route[index+1],"Actual route %d step %d selects its newly revealed successor" % [side,index+1])
			else:
				check(Vector2i(map.selected,map.tier)==node,"A finished route keeps its final owned tile selected")
			map.update(map.CAMERA_DURATION)
		var other: Vector2i = graph.routes()[1-side][0]
		check(game.shop_node_unlocked(other.x,other.y) and map.node_visible(other.x,other.y),"Completing actual route %d leaves the other path independently available" % side)
		check(game.profile_io==0,"Actual route %d uses no player profile" % side)
		game.free()

func real_optional_branches():
	var game = fresh()
	var graph = game.upgrade_graph()
	var map = game.upgrade_map
	game.buy_upgrade_node(0,1)
	var trunks_ok = true
	for route in graph.routes():
		for node in route: trunks_ok = game.buy_upgrade_node(node.x,node.y) and trunks_ok
	var expected_trunks = [1,0,0,0,0,0,0,0]
	for route in graph.routes():
		for node in route: expected_trunks[node.x]+=1
	check(trunks_ok and game.levels==expected_trunks,"Actual game purchases follow both main antler continuations without forcing optional branches")
	map.update(0)
	for node in graph.nodes():
		if not game.shop_node_owned(node.x,node.y):
			var focus: Array[Vector2i] = [node]
			map._frame_nodes(focus); map.update(map.CAMERA_DURATION)
			tap(game,map.point(node.x,node.y),41)
			var bank: float = game.bank
			var price: int = game.upgrade_cost(node.x)
			var levels: Array = game.levels.duplicate()
			var before: Array[Vector2i] = map.visible_nodes()
			tap(game,map.buy_rect().get_center(),41)
			levels[node.x] += 1
			check(game.levels==levels and game.bank==bank-price,"A real touch buys antler branch tier %s exactly once" % str(node))
			var choices: Array[Vector2i] = []
			for visible in map.visible_nodes():
				if visible not in before and node in map.node_prerequisites(visible): choices.append(visible)
			var expected: Vector2i = choices[0] if choices.size()==1 else node
			check(map.selected_node()==expected,"Branch %s follows a sole new step but keeps the player's choice at nested forks" % str(node))
	check(game.levels==game.MAX_LEVELS and not game.twin_launchers,"All original upgrades can finish while leaving late Twin optional")
	check(game.profile_io==0,"Optional appendage interaction never accesses the player profile")
	game.free()

func exact_same_family_touch_choice():
	var game=fresh(); var map=game.upgrade_map
	var graph=game.upgrade_graph(); var parent=Vector2i(2,1)
	var path: Array[Vector2i]=[]; var current=parent
	while true:
		path.push_front(current)
		var prerequisites=graph.prerequisites(current.x,current.y)
		if prerequisites.is_empty(): break
		current=prerequisites[0]
	for node in path: check(game.buy_upgrade_node(node.x,node.y),"Touch fixture reaches the mixed same-family fork")
	var choices: Array[Vector2i]=[]
	for node in graph.nodes():
		if parent in graph.prerequisites(node.x,node.y): choices.append(node)
	check(choices.size()==2 and choices[0].x==choices[1].x,"Actual map presents two independent same-family upgrade tiles")
	var high=choices[0] if choices[0].y>choices[1].y else choices[1]
	var other=choices[1] if high==choices[0] else choices[0]
	map.update(0); map._frame_nodes(choices); map.update(map.CAMERA_DURATION)
	tap(game,map.point(high.x,high.y),51)
	check(map.selected_node()==high and not game.shop_node_owned(high.x,high.y),"A real touch selects the high-ordinal choice without granting it")
	var price=game.upgrade_cost(high.x); var bank=game.bank; var count=game.levels[high.x]
	tap(game,map.buy_rect().get_center(),51)
	check(game.shop_node_owned(high.x,high.y) and not game.shop_node_owned(other.x,other.y) and game.levels[high.x]==count+1 and game.bank==bank-price,"Buy targets that exact tile and charges for one aggregate effect")
	check(map.state_for(other.x,other.y)=="affordable","The unchosen same-family tile remains green and purchasable")
	check(game.profile_io==0,"Exact-choice touch fixture never accesses a player profile")
	game.free()

func legacy_cache_and_overview():
	var game = fresh("bakery")
	var map = game.upgrade_map
	var bakery_positions = var_to_bytes(map._positions)
	var bakery_paths = var_to_bytes(map._paths)
	check(game.upgrade_graph().routes().size()==3 and map.minimum_zoom()==map.MIN_ZOOM,"Bakery keeps its original graph and zoom range")
	game.set_active_area("gelato")
	game.mode = "shop"
	stage_legacy_counts(game,[0,8,0,5,6,4,7,9])
	var original = game.levels.duplicate()
	var bank: float = game.bank
	map.update(0)
	var retained = true
	for node in game.upgrade_graph().nodes():
		if node.y<=game.levels[node.x]: retained = retained and map.node_visible(node.x,node.y) and map.state_for(node.x,node.y)=="owned"
	check(retained and game.levels==original and game.bank==bank,"Irregular legacy builds keep every owned tier, wallet and owned appearance on the U")
	check(map._layout_area=="gelato" and var_to_bytes(map._positions)!=bakery_positions and game.upgrade_graph().routes().size()==2,"Switching areas selects Gelato's distinct graph and cached positions")
	var gelato_positions = var_to_bytes(map._positions)
	stage_legacy_counts(game,game.MAX_LEVELS)
	map.update(0)
	map.zoom = map.minimum_zoom()
	map._frame_nodes(map.visible_nodes())
	map.update(map.CAMERA_DURATION)
	var overview_fits = true
	var artwork_contains = true
	var world_rect: Rect2 = map.arc_art.area_world_rect("gelato")
	for node in map.visible_nodes():
		overview_fits = overview_fits and map.focus_area().encloses(map.node_rect(node.x,node.y,false))
		artwork_contains = artwork_contains and world_rect.encloses(Rect2(map._positions[node]-map.TILE_SIZE*.5,map.TILE_SIZE))
	check(map.minimum_zoom()<=.055 and overview_fits,"The complete antler map fits in the playable overview clear of fixed controls")
	check(artwork_contains and map.arc_art.target_rect(map.center(),map.zoom,"gelato").size.is_equal_approx(world_rect.size*map.zoom),"Distinct Gelato scenery bounds contain all live tiles and track map zoom")
	var other_game = fresh("bakery")
	check(var_to_bytes(other_game.upgrade_map._positions)==bakery_positions and var_to_bytes(map._positions)==gelato_positions,"A second Bakery map cannot replace the active Gelato instance's cached geometry")
	other_game.free()
	game.set_active_area("bakery")
	game.mode = "shop"
	map.update(0)
	check(var_to_bytes(map._positions)==bakery_positions and var_to_bytes(map._paths)==bakery_paths,"Returning to Bakery restores its exact original cached layout")
	game.set_active_area("gelato")
	game.mode = "shop"
	map.update(0)
	check(var_to_bytes(map._positions)==gelato_positions and is_equal_approx(map.point(0,1).x,360) and map.zoom<=map.GELATO_INITIAL_ZOOM and map.node_rect(8,1,false).end.y<map.TWIN_CARD_RECT.position.y,"Reopening Gelato restores its antlers and central-start camera with Dual Shot beneath")
	check(game.profile_io==0,"Legacy and cache fixtures perform no player profile IO")
	game.free()

func gelato_gestures():
	var game = fresh()
	var map = game.upgrade_map
	var geometry = [var_to_bytes(map._positions),var_to_bytes(map._paths),var_to_bytes(map._spacing)]
	var bank: float = game.bank
	var owned: Array = game.levels.duplicate()
	var origin: Vector2 = map.point(0,1)
	var entry_view = [map.pan,map.zoom]
	drag(game,origin,origin+Vector2(100,-40),17)
	check(map.pan.is_equal_approx(entry_view[0]+Vector2(100,-40)) and map.selected==-1,"A nonzero Gelato touch ID pans the antlers without selecting a tile")
	check(game.bank==bank and game.levels==owned and map.touch_points.is_empty(),"Finishing a Gelato pan neither purchases nor leaves a tracked finger")
	map.reset_view_state(); map.update(0)
	# Keep the starter inside the camera bounds so clamping does not mask the
	# invariant that the world point under the pinch midpoint stays anchored.
	map.pan = Vector2(0,-150)
	var anchor: Vector2 = map.center()-Vector2(0,65)
	var world_before: Vector2 = (anchor-map.center())/map.zoom
	var initial_zoom: float = map.zoom
	var left = anchor-Vector2(80,0)
	var right = anchor+Vector2(80,0)
	touch(game,left,7,true); touch(game,right,31,true)
	move_touch(game,left,anchor-Vector2(120,0),7)
	move_touch(game,right,anchor+Vector2(120,0),31)
	check(is_equal_approx(map.zoom,initial_zoom*1.5) and ((anchor-map.center())/map.zoom).is_equal_approx(world_before),"Gelato's two-finger pinch zooms while preserving the world point under its midpoint")
	touch(game,anchor+Vector2(120,0),31,false)
	var pinch_pan: Vector2 = map.pan
	move_touch(game,anchor-Vector2(120,0),anchor-Vector2(90,0),7)
	check(map.pan.is_equal_approx(pinch_pan+Vector2(30,0)),"The remaining Gelato pinch finger continues panning without jumping")
	touch(game,anchor-Vector2(90,0),7,false)
	check(map.selected==-1 and game.bank==bank and game.levels==owned and map.touch_points.is_empty(),"Pinch and final finger release cannot select or purchase a Gelato upgrade")
	map.reset_view_state(); map.update(0)
	anchor = Vector2(360,550); left = anchor-Vector2(80,0); right = anchor+Vector2(80,0)
	touch(game,left,23,true); touch(game,right,41,true)
	move_touch(game,left,anchor-Vector2(5,0),23); move_touch(game,right,anchor+Vector2(5,0),41)
	check(is_equal_approx(map.zoom,map.minimum_zoom()),"An inward Gelato pinch reaches its whole-antler overview minimum")
	touch(game,anchor-Vector2(5,0),23,false,true); touch(game,anchor+Vector2(5,0),41,false)
	check(map.touch_points.is_empty() and not map.dragging and map.selected==-1,"Canceling a Gelato pinch releases both IDs without turning into a tap")
	map.reset_view_state(); map.update(0)
	touch(game,left,23,true); touch(game,right,41,true)
	move_touch(game,left,anchor-Vector2(300,0),23); move_touch(game,right,anchor+Vector2(300,0),41)
	touch(game,anchor-Vector2(300,0),23,false); touch(game,anchor+Vector2(300,0),41,false)
	check(is_equal_approx(map.zoom,map.MAX_ZOOM),"An outward Gelato pinch stops at the readable maximum zoom")
	map.reset_view_state(); map.update(0)
	tap(game,map.point(0,1),19)
	var buy: Vector2 = map.buy_rect().get_center()
	touch(game,Vector2(300,500),13,true); touch(game,buy,83,true)
	touch(game,buy,83,false)
	move_touch(game,Vector2(300,500),buy,13); touch(game,buy,13,false)
	check(game.bank==bank and game.levels==owned and map.touch_points.is_empty(),"A second Gelato finger over Buy and a map drag released there cannot purchase")
	var pan_before: Vector2 = map.pan
	drag(game,buy,buy-Vector2(100,100),29)
	check(game.bank==bank and game.levels==owned and map.pan==pan_before and map.overlay_touches.is_empty(),"A drag starting on Gelato's Buy control neither purchases nor moves the map")
	stage_legacy_counts(game,game.MAX_LEVELS)
	map.reset_view_state(); map.update(0)
	map.zoom = map.MAX_ZOOM
	var routes: Array = game.upgrade_graph().routes()
	for node in [routes[0].back(),routes[1].back(),Vector2i(0,1)]:
		swipe_to_node(game,node)
		tap(game,map.point(node.x,node.y),47)
		check(map.focus_area().encloses(map.node_rect(node.x,node.y,false)) and Vector2i(map.selected,map.tier)==node,"Phone-length Gelato swipes reach and select %s clear of overlays at maximum zoom" % str(node))
	for direction in [Vector2(220,220),Vector2(-220,-220)]:
		var start: Vector2 = map.focus_area().get_center()
		for swipe in range(150): drag(game,start,start+direction,53)
		var limit: Vector2 = map.pan
		drag(game,start,start+direction,53)
		check(map.pan.is_equal_approx(limit) and map.pan.is_finite(),"Repeated Gelato swipes stop at a finite content boundary toward %s" % str(direction))
	check(game.bank==bank and game.levels==game.MAX_LEVELS and map.touch_points.is_empty(),"Exploring both complete U arms preserves money and every owned tier")
	game.set_active_area("bakery"); game.mode="shop"; map.update(0)
	game.set_active_area("gelato"); game.mode="shop"; map.update(0)
	check([var_to_bytes(map._positions),var_to_bytes(map._paths),var_to_bytes(map._spacing)]==geometry and map.pan==entry_view[0] and map.zoom==entry_view[1] and map.touch_points.is_empty(),"Switching away after Gelato gestures restores exact authored geometry and a clean central entry camera")
	check(game.profile_io==0,"Gelato gesture fixtures never access the player profile")
	game.free()

func gelato_reduced_motion():
	for side in range(2):
		var game = fresh()
		var map = game.upgrade_map
		game.reduced_motion = true
		var geometry = [var_to_bytes(map._positions),var_to_bytes(map._paths)]
		tap(game,map.point(0,1),19)
		tap(game,map.buy_rect().get_center(),19)
		var left: Vector2i=game.upgrade_graph().routes()[0][0]
		var right: Vector2i=game.upgrade_graph().routes()[1][0]
		check(game.levels[0]==1 and not map._camera_active and map.focus_area().encloses(map.node_rect(left.x,left.y,false)) and map.focus_area().encloses(map.node_rect(right.x,right.y,false)),"Reduced Motion Gelato starter purchase immediately frames both paths, route %d" % side)
		var route: Array = game.upgrade_graph().routes()[side]
		var first: Vector2i = route[0]
		var next: Vector2i = route[1]
		tap(game,map.point(first.x,first.y),23)
		var bank: float = game.bank
		var price: int = game.upgrade_cost(first.x)
		tap(game,map.buy_rect().get_center(),23)
		check(game.levels[first.x]==1 and is_equal_approx(game.bank,bank-price) and Vector2i(map.selected,map.tier)==next and map.state_for(first.x,first.y)=="owned","Reduced Motion route %d still buys once and selects its actual successor" % side)
		check(not map._camera_active and map.focus_area().encloses(map.node_rect(next.x,next.y,false)) and map.card_offset()==Vector2.ZERO and map._card_bounce_age<0,"Reduced Motion route %d frames its successor immediately without camera travel or card bounce" % side)
		var view = [map.pan,map.zoom]
		var still = true
		for delta in [0.0,.07,.08,.15]:
			map.update(delta)
			still = still and [map.pan,map.zoom]==view and not map._camera_active and map.card_offset()==Vector2.ZERO
			for node in map.visible_nodes():
				var motion: Dictionary = map.animation_for(node)
				still = still and motion.scale==Vector2.ONE and motion.offset==Vector2.ZERO
		check(still and map.tap_feedback.is_empty(),"Reduced Motion route %d keeps camera, card and all tile positions/scales stationary throughout purchase feedback" % side)
		game.set_active_area("bakery"); game.mode="shop"; map.update(0)
		game.set_active_area("gelato"); game.mode="shop"; map.update(0)
		check(game.reduced_motion and [var_to_bytes(map._positions),var_to_bytes(map._paths)]==geometry and is_equal_approx(map.point(0,1).x,360) and not map._camera_active and map.node_rect(8,1,false).end.y<map.TWIN_CARD_RECT.position.y,"Reduced Motion and Gelato's antler entry framing survive an area round trip, route %d" % side)
		check(game.profile_io==0,"Reduced Motion route %d performs no player profile IO" % side)
		game.free()
	var game = fresh()
	var map = game.upgrade_map
	tap(game,map.point(0,1)); tap(game,map.buy_rect().get_center())
	map.update(map.CAMERA_DURATION)
	tap(game,map.point(1,1)); tap(game,map.buy_rect().get_center())
	var next: Vector2i = game.upgrade_graph().routes()[0][1]
	var started: bool = map._camera_active
	map.update(.1)
	game.reduced_motion = true
	map.update(0)
	check(started and not map._camera_active and map.focus_area().encloses(map.node_rect(next.x,next.y,false)),"Enabling Reduced Motion during travel immediately finishes the real successor camera")
	game.free()

func _initialize():
	purchase_entry_and_reveal()
	both_real_routes()
	real_optional_branches()
	exact_same_family_touch_choice()
	legacy_cache_and_overview()
	gelato_gestures()
	gelato_reduced_motion()
	print("GELATO_UPGRADE_MAP_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
