extends SceneTree
## In-memory interaction and progression checks. Never enters production _ready.
const Graph = preload("res://scripts/upgrade_graph.gd")
var passed = 0
var failed: Array[String] = []
var g
var m

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failed.append(label)
		print("FAIL: ",label)

func touch(p: Vector2, index: int, pressed: bool, canceled: bool = false):
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = g.to_global(p)
	event.pressed = pressed
	event.canceled = canceled
	g._input(event)

func move_touch(a: Vector2, b: Vector2, index: int):
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = g.to_global(b)
	event.relative = g.to_global(b)-g.to_global(a)
	g._input(event)

func tap(p: Vector2, index: int = 0):
	touch(p,index,true)
	touch(p,index,false)

func drag(a: Vector2, b: Vector2, index: int = 0):
	touch(a,index,true)
	move_touch(a,b,index)
	touch(b,index,false)

func wheel(p: Vector2, up: bool):
	var event = InputEventMouseButton.new()
	event.position = g.to_global(p)
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	g._input(event)

func swipe_to_node(family: int, tier: int):
	# Every gesture stays inside the usable phone viewport. The finite budget
	# scales with the actual map distance, including at maximum zoom.
	var start: Vector2 = m.FOCUS_AREA.get_center()
	var distance: float = start.distance_to(m.point(family,tier))
	var budget = ceili(distance/240.0)+3
	for swipe in range(budget):
		var to_node: Vector2 = start-m.point(family,tier)
		if to_node.length()<1.0: break
		drag(start,start+to_node.limit_length(240.0),17)

func fresh(wallet: float = 100000.0, started: bool = false):
	g.mode = "shop"
	g.navigation_delay = 0
	g.result_input_delay = 0
	g.note = ""
	g.note_time = 0
	g.position = Vector2.ZERO
	g.scale = Vector2.ONE
	g.bank = wallet
	g.levels.fill(0)
	if started: g.levels[0] = 1
	g.reduced_motion = false
	m.reset_view_state()
	# Entry now frames the visible Jam Burst node. These legacy gesture/camera
	# checks deliberately start from their canonical zero-pan camera; entry
	# framing itself is covered separately below and in the GPU ability audit.
	m.pan=Vector2.ZERO
	m.zoom=m.INITIAL_ZOOM
	m.update(0.0)

func buy_point() -> Vector2:
	return m.buy_rect().get_center()

func affordability_feedback() -> Array:
	var nodes: Array = []
	for node in m.feedback:
		if m.feedback[node].kind=="affordability": nodes.append(node)
	return nodes

func same_nodes(a: Array, b: Array) -> bool:
	if a.size()!=b.size(): return false
	for node in a:
		if not b.has(node): return false
	return true

func entry_checks():
	fresh()
	m.reset_view_state()
	var entry_pan: Vector2=m.pan
	var entry_zoom: float=m.zoom
	m.twin_selected=true
	var safe=m.focus_area().grow(-23)
	check(safe.encloses(m.node_rect(0,1,false)) and safe.encloses(m.node_rect(m.TWIN_NODE.x,m.TWIN_NODE.y,false)),"Bakery entry frames Feed and Jam Burst clear of the special ability card")
	check(entry_zoom>=m.MIN_ZOOM and entry_zoom<=m.INITIAL_ZOOM,"Entry framing remains within readable camera limits")
	m.reset_view_state()
	check(m.pan==entry_pan and m.zoom==entry_zoom,"Repeated entry resets use the same stable camera")

func progression_checks():
	fresh()
	check(m.visible_nodes()==[Vector2i(0,1),m.TWIN_NODE],"Fresh map reveals the starter and locked Jam Burst")
	check(m.point(0,1)==m.center(),"First Feed upgrade occupies the recipe center")
	check(not m.node_visible(-1,1) and not m.node_visible(9,1) and not m.node_visible(0,0) and not m.node_visible(0,g.MAX_LEVELS[0]+1),"Invalid branch and tier indices cannot be visible")
	check(m.state_for(0,1)=="affordable" and m.state_for(1,1)=="hidden" and m.state_for(0,2)=="hidden","Future recipes stay hidden before Feed 1")
	var starter_rect: Rect2 = m.node_rect(0,1,false)
	var first_choice_rect: Rect2 = m.node_rect(2,1,false)
	tap(m.point(2,1),7)
	check(m.selected==-1 and not m.node_in_view(2,1),"A hidden upgrade cannot be selected even at its on-screen position")
	m.selected=2; m.tier=1; m.update(0)
	check(m.selected==-1 and not m.has_selection(),"Refreshing clears a selection that is no longer visible")
	m.selected=1; m.tier=1; tap(buy_point())
	check(g.levels[1]==0 and g.bank==100000,"Locked selection cannot spend the wallet")
	m.selected=9; m.tier=1; m.press(buy_point())
	check(g.bank==100000,"Invalid forged branch cannot access or spend the wallet")
	m.selected=0; m.tier=0; m.press(buy_point())
	check(g.bank==100000,"Invalid forged tier cannot spend the wallet")
	m.selected=-1; tap(m.point(0,1),7)
	check(m.selected==0 and m.tier==1,"A primary finger with a nonzero touch ID selects the starter")
	check(g.levels[0]==0 and g.bank==100000,"Selecting a tile never purchases it")
	m.tier=3; tap(buy_point())
	check(g.levels[0]==0,"Forged future selection cannot skip a tier")
	m.tier=1
	var cost: int = g.upgrade_cost(0)
	g.note="Previous status"; g.note_time=2.0
	tap(buy_point())
	check(g.levels[0]==1 and g.bank==100000-cost,"Starter purchase spends the existing quoted cost once")
	check(g.note.is_empty() and g.note_time==0,"Successful map purchase leaves visual feedback without a redundant text toast")
	var available: Array = []
	for node in Graph.nodes():
		if m.state_for(node.x,node.y)=="affordable": available.append(node)
	check(same_nodes(available,[Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)]),"Feed 1 opens exactly three routes: Bounce, Time and Gold")
	check(same_nodes(m.visible_nodes(),[Vector2i(0,1),Vector2i(2,1),Vector2i(7,1),Vector2i(6,1),m.TWIN_NODE]),"Starter purchase reveals three first choices beside the starter and Jam Burst")
	check(m.state_for(0,2)=="hidden" and m.state_for(1,1)=="hidden","Upgrades beyond the next choice remain hidden on every route")
	check(m.node_rect(0,1,false)==starter_rect and m.node_rect(2,1,false)==first_choice_rect,"Discovery preserves authored icon positions and sizes")
	check(m.selected==0 and m.tier==1 and m.state_for(0,1)=="owned","Starter stays selected so the player chooses among its three new routes")
	var bank: float = g.bank
	tap(buy_point())
	check(g.levels[0]==1 and g.bank==bank,"Repeated starter taps do not choose a route automatically")
	g.navigation_delay=0; tap(buy_point())
	check(g.levels[0]==1 and g.bank==bank,"Purchased tile cannot rebuy after the navigation guard expires")
	for i in range(8):
		fresh()
		for node in Graph.nodes():
			if node == Vector2i(i,1): break
			g.levels[node.x] = node.y
		m.update(0)
		m.selected=i; m.tier=1; g.bank=g.upgrade_cost(i)-1
		var before: float = g.bank
		tap(buy_point())
		check(g.levels[i]==0 and g.bank==before,"Insufficient funds branch %d never spends" % i)
		if i==0: check(g.note.begins_with("Need ") and g.note_time>0,"Failed purchase keeps its useful insufficient-funds message")
		g.bank=100000; g.navigation_delay=0; before=g.bank; cost=g.upgrade_cost(i)
		tap(buy_point())
		check(g.levels[i]==1 and g.bank==before-cost,"Deliberate purchase branch %d spends the exact quoted cost" % i)
		g.navigation_delay=0; g.levels[i]=g.MAX_LEVELS[i]; m.selected=i; m.tier=g.MAX_LEVELS[i]; before=g.bank
		tap(buy_point())
		check(g.bank==before and g.levels[i]==g.MAX_LEVELS[i],"Branch %d cap cannot be exceeded" % i)
		check(not m.node_visible(i,g.MAX_LEVELS[i]+1),"Capped branch %d does not reveal an extra node" % i)
	fresh()
	g.levels[4]=2
	check(m.state_for(4,1)=="owned" and m.state_for(4,2)=="owned","Legacy non-Feed progress preserves its owned tiers")
	check(m.state_for(4,3)=="hidden","Legacy ownership does not reveal a tier with a missing route prerequisite")
	m.selected=4; m.tier=4; bank=g.bank; tap(buy_point())
	check(g.levels[4]==2 and g.bank==bank,"Forged future selection cannot skip an existing branch tier")
	m.tier=3; tap(buy_point())
	check(g.levels[4]==2 and g.bank==bank,"A missing preceding route node still prevents spending")
	fresh(100000,true)
	m.selected=2; m.tier=1; tap(buy_point())
	check(m.state_for(1,1)=="affordable" and m.feedback[Vector2i(1,1)].kind=="reveal","Buying Bounce reveals Power without a second parent")
	check(same_nodes(m.visible_nodes(),[Vector2i(0,1),Vector2i(2,1),Vector2i(1,1),Vector2i(7,1),Vector2i(6,1),m.TWIN_NODE]) and m.state_for(5,1)=="hidden","One route advances by one choice while the other two frontiers remain unchanged")
	g.navigation_delay=0; m.selected=1; m.tier=1; bank=g.bank; cost=g.upgrade_cost(1); tap(buy_point())
	check(g.levels[1]==1 and g.bank==bank-cost and m.state_for(5,1)=="affordable","Buying Power opens the next mixed upgrade on its route")
	check(m.selected==5 and m.tier==1,"A route purchase immediately selects the new Impact upgrade")
	var single_parent = true
	for node in Graph.nodes():
		single_parent=single_parent and Graph.prerequisites(node.x,node.y).size()==(0 if node==Vector2i(0,1) else 1)
	check(single_parent,"Every recipe after Feed 1 has one preceding route node")
	fresh()
	var all_nodes = Graph.nodes()
	var separated = true
	var map_bounds = Rect2(m._positions[all_nodes[0]],Vector2.ZERO)
	for j in range(all_nodes.size()):
		var a: Vector2 = m._positions[all_nodes[j]]
		map_bounds=map_bounds.expand(a)
		for k in range(j+1,all_nodes.size()):
			var delta: Vector2 = (a-m._positions[all_nodes[k]]).abs()
			separated=separated and (delta.x>m.TILE_SIZE.x+12 or delta.y>m.TILE_SIZE.y+12)
	check(separated,"All 62 full-size tiles have non-overlapping hit areas and breathing room")
	var overview_size: Vector2 = map_bounds.size*m.MIN_ZOOM+Vector2.ONE*m.OVERVIEW_SIZE
	check(overview_size.x<=m.FOCUS_AREA.size.x and overview_size.y<=m.FOCUS_AREA.size.y,"The complete arc and semantic node margins fit the overview")
	var first_view = true
	for node in [Vector2i(0,1),Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)]:
		first_view=first_view and m.FOCUS_AREA.encloses(m.node_rect(node.x,node.y,false))
	check(first_view,"The root and three first choices fit between the phone overlays at normal zoom")
	var first_recipe = true
	g.levels.fill(1)
	m.update(0)
	m.feedback.clear()
	for family in range(8):
		swipe_to_node(family,1)
		first_recipe=first_recipe and m.FOCUS_AREA.encloses(m.node_rect(family,1,false))
		tap(m.point(family,1),29)
		first_recipe=first_recipe and m.selected==family and m.tier==1
	check(first_recipe,"Every first-tier recipe can be brought clear of overlays and selected using phone-length swipes")
	g.levels.fill(0)
	m.update(0)
	check(m.visible_nodes()==[Vector2i(0,1),m.TWIN_NODE] and m.state_for(1,1)=="hidden" and m.selected==-1,"Reset hides later routes and clears stale selection, keeping Jam Burst visible")
	fresh(0,true)
	check(m.visible_nodes().size()==5 and m.state_for(2,1)=="unaffordable" and m.state_for(7,1)=="unaffordable" and m.state_for(6,1)=="unaffordable","An empty wallet still shows the next upgrade on all three routes and Jam Burst")

func gesture_checks():
	fresh()
	var origin: Vector2 = m.point(0,1)
	drag(origin,origin+Vector2(100,20),17)
	check(m.pan.is_equal_approx(Vector2(100,20)) and m.selected==-1,"Nonzero touch ID drags the map without selecting a tile")
	check(g.bank==100000 and m.touch_points.is_empty(),"A finished pan cannot spend and releases every tracked touch")
	fresh()
	# Keep the starter inside camera bounds so this tests anchoring rather than
	# the deliberate clamp that keeps a one-node map within reach.
	var anchor = Vector2(425,650)
	var world_before: Vector2 = (anchor-m.center())/m.zoom
	wheel(anchor,true)
	check(m.zoom>m.INITIAL_ZOOM,"Scrolling upward zooms into the recipe")
	check(((anchor-m.center())/m.zoom).is_equal_approx(world_before),"Wheel zoom preserves the world point under the pointer")
	wheel(anchor,false)
	check(is_equal_approx(m.zoom,m.INITIAL_ZOOM) and m.pan.length()<.001,"Opposite wheel steps return to the original view within subpixel precision")
	var old_zoom: float = m.zoom
	m.selected=0; m.tier=1
	wheel(Vector2(360,70),true); wheel(buy_point(),true)
	check(m.zoom==old_zoom,"Wheel input over the header or purchase card cannot zoom the map")
	for i in range(40): wheel(anchor,true)
	check(is_equal_approx(m.zoom,m.MAX_ZOOM),"Wheel zoom clamps at its readable maximum")
	for i in range(40): wheel(anchor,false)
	check(is_equal_approx(m.zoom,m.MIN_ZOOM),"Wheel zoom clamps at its readable minimum")
	old_zoom=m.zoom; m.press(Vector2(93,930)); m.press(Vector2(195,930))
	check(m.zoom==old_zoom,"Former minus and plus button areas no longer change zoom")
	fresh()
	# Keep the enlarged starter well inside the camera bounds. This isolates
	# anchor math from deliberate clamping when a tile approaches an overlay.
	m.pan=Vector2(0,-100)
	anchor=m.center()-Vector2(0,65)
	world_before=(anchor-m.center())/m.zoom
	var left=anchor-Vector2(80,0)
	var right=anchor+Vector2(80,0)
	touch(left,7,true); touch(right,31,true)
	move_touch(left,anchor-Vector2(120,0),7)
	move_touch(right,anchor+Vector2(120,0),31)
	check(is_equal_approx(m.zoom,m.INITIAL_ZOOM*1.5),"Two nonzero touch IDs pinch outward to zoom in")
	check(((anchor-m.center())/m.zoom).is_equal_approx(world_before),"Pinch keeps its final midpoint anchored to the same world point")
	check(m.selected==-1 and g.bank==100000,"A pinch cannot select or purchase an upgrade")
	touch(anchor+Vector2(120,0),31,false)
	var pinch_pan: Vector2 = m.pan
	move_touch(anchor-Vector2(120,0),anchor-Vector2(90,0),7)
	check(m.pan.is_equal_approx(pinch_pan+Vector2(30,0)),"The remaining pinch finger continues panning from its current position")
	touch(anchor-Vector2(90,0),7,false)
	check(m.touch_points.is_empty() and m.selected==-1 and g.bank==100000,"Remaining pinch finger releases safely without turning into a tap")
	fresh()
	touch(left,23,true); touch(right,41,true)
	move_touch(left,anchor-Vector2(5,0),23); move_touch(right,anchor+Vector2(5,0),41)
	check(is_equal_approx(m.zoom,m.MIN_ZOOM),"Pinching inward clamps to the full-map overview minimum")
	touch(anchor-Vector2(5,0),23,false,true)
	touch(anchor+Vector2(5,0),41,false)
	check(m.touch_points.is_empty() and m.selected==-1,"Canceled multitouch input clears gestures without selecting")
	fresh()
	tap(m.point(0,1))
	var bank: float = g.bank
	touch(Vector2(300,500),13,true)
	touch(buy_point(),0,true)
	touch(buy_point(),0,false)
	move_touch(Vector2(300,500),buy_point(),13)
	touch(buy_point(),13,false)
	check(g.bank==bank and g.levels[0]==0,"A second finger outside the map and a drag ending on Buy cannot purchase")
	check(m.touch_points.is_empty(),"Moving fingers outside the map still releases all gesture state")
	fresh()
	g.position=Vector2(20,30); g.scale=Vector2(.8,.8)
	tap(m.point(0,1),19)
	check(m.selected==0,"Safe-area transforms preserve tile selection for nonzero touch IDs")
	anchor=Vector2(400,650); world_before=(anchor-m.center())/m.zoom; wheel(anchor,true)
	check(((anchor-m.center())/m.zoom).is_equal_approx(world_before),"Safe-area transforms preserve pointer-anchored wheel zoom")
	fresh()
	m.selected=0; m.tier=1; m.pan=Vector2(200,100); m.zoom=1.3
	tap(Vector2(619,68),9)
	check(m.pan==Vector2(200,100) and m.zoom==1.3 and m.selected==0 and m.tier==1,"The former GPS location is inert wallet space and never resets the camera")
	fresh()
	g.navigation_delay=.25; tap(m.point(0,1),3)
	check(m.selected==-1,"Navigation guard blocks tile selection")
	m.selected=0; m.tier=1; bank=g.bank; tap(buy_point())
	check(g.bank==bank,"Navigation guard blocks purchase")
	g.navigation_delay=0; g.result_input_delay=.4; tap(buy_point())
	check(g.bank==bank,"Result destination guard blocks purchase")
	fresh()
	var partial_center = Vector2(m.AREA.position.x+20,m.AREA.get_center().y)
	m.pan=partial_center-m.center()
	check(m.node_in_view(0,1),"A partially clipped tile remains part of the visible map")
	m.select_at(m.point(0,1))
	check(m.selected==0,"The visible portion of a clipped tile remains selectable")
	m.selected=-1; m.select_at(Vector2(m.AREA.position.x-2,partial_center.y))
	check(m.selected==-1,"Clipped pixels outside the map cannot select a tile")
	m.pan+=Vector2(-m.TILE_SIZE.x*2,0)
	check(not m.node_in_view(0,1),"A fully offscreen tile is not considered visible")
	m.select_at(m.point(0,1))
	check(m.selected==-1,"A fully offscreen tile cannot be selected")
	fresh()
	touch(Vector2(300,500),7,true); touch(Vector2(430,500),31,true)
	g.go_back()
	check(m.touch_points.is_empty() and not m.dragging,"Leaving the map clears all active pinch and drag state")
	g.mode="shop"; g.navigation_delay=0
	var old_pan: Vector2 = m.pan
	move_touch(Vector2(300,500),Vector2(400,600),7)
	touch(Vector2(400,600),7,false); touch(Vector2(430,500),31,false)
	check(m.pan==old_pan and m.selected==-1,"Stale movement and releases after navigation cannot move or select")
	fresh()
	touch(Vector2(300,500),11,true); touch(Vector2(430,500),26,true)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(m.touch_points.is_empty() and not m.dragging,"Focus loss cancels every map gesture")
	fresh()
	touch(Vector2(300,500),11,true)
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(m.touch_points.is_empty() and not m.dragging,"Application pause cancels a held map gesture")
	fresh()
	g.levels=g.MAX_LEVELS.duplicate()
	m.zoom=m.MAX_ZOOM
	var start: Vector2 = m.FOCUS_AREA.get_center()
	for branch in range(g.MAX_LEVELS.size()):
		m.pan=Vector2.ZERO
		var leaf: int = g.MAX_LEVELS[branch]
		swipe_to_node(branch,leaf)
		var tile: Rect2 = m.node_rect(branch,leaf,false)
		check(m.FOCUS_AREA.encloses(tile),"Max-zoom terminal tile in branch %d can be fully revealed between the overlays by phone-length drags" % branch)
	var furthest = 0.0
	for node in m.visible_nodes():
		furthest=maxf(furthest,(m.point(node.x,node.y)-m.pan-start).length())
	for direction in [Vector2.ONE,-Vector2.ONE]:
		drag(start,start+direction*1000000.0,17)
		var edge_pan: Vector2 = m.pan
		drag(start,start+direction*1000000.0,17)
		check(m.pan==edge_pan and m.pan.is_finite() and m.pan.length()<furthest*2+m.AREA.size.length(),"Extreme %s panning stops at a finite content bound" % ("positive" if direction.x>0 else "negative"))
	check(m._effect_text(3,1).contains("when equipped") and m._effect_text(4,1).contains("when equipped") and m._effect_text(5,1).contains("when equipped"),"Special upgrade effects retain the equipped condition")

func fullscreen_overlay_checks():
	# These are actual former gutter positions, not points derived from AREA.
	# Each must contain selectable map content now that only the phone clips it.
	for edge in [Vector2(10,620),Vector2(710,620),Vector2(360,128),Vector2(360,1245)]:
		fresh()
		m.pan=edge-m.point(0,1)
		tap(edge,29)
		check(m.selected==0 and m.tier==1,"Map tiles remain selectable at full-page position %s outside the former box" % edge)
	fresh()
	var lower_map = Vector2(360,1230)
	var world: Vector2 = (lower_map-m.center())/m.zoom
	wheel(lower_map,true)
	check(m.zoom>m.INITIAL_ZOOM and ((lower_map-m.center())/m.zoom).is_equal_approx(world),"The lower page margin supports pointer-anchored map zoom")
	fresh()
	var card_space = Vector2(200,1000)
	var old_zoom: float = m.zoom
	wheel(card_space,true)
	check(m.zoom>old_zoom,"Unselected map keeps the absent card's space available for zoom")
	m.selected=0; m.tier=1; old_zoom=m.zoom
	wheel(card_space,true)
	check(m.zoom==old_zoom,"Selecting an upgrade makes its visible card intercept zoom")
	fresh()
	m.pan=m.WALLET_RECT.get_center()-m.point(0,1)
	tap(m.WALLET_RECT.get_center(),21)
	check(m.selected==-1 and m.pan!=Vector2.ZERO,"A tile behind the wallet cannot be selected through it")
	fresh(100000,true)
	m.selected=0; m.tier=1
	m.pan=card_space-m.point(1,1)
	m.select_at(card_space)
	tap(card_space,21)
	check(m.selected==0 and m.tier==1 and g.levels[1]==0,"The selected card blocks both direct and touch selection of the tile behind it")
	fresh()
	tap(m.point(0,1))
	var bank: float = g.bank
	touch(buy_point(),17,true)
	check(g.bank==bank and g.levels[0]==0,"Buy waits for a completed deliberate tap instead of spending on touch-down")
	move_touch(buy_point(),Vector2(380,600),17)
	touch(Vector2(450,600),33,true)
	move_touch(Vector2(450,600),Vector2(500,650),33)
	touch(Vector2(500,650),33,false)
	touch(Vector2(380,600),17,false)
	check(g.bank==bank and g.levels[0]==0 and m.pan==Vector2.ZERO and m.zoom==m.INITIAL_ZOOM,"A drag starting on Buy cannot purchase or become a map pan/pinch")
	check(m.touch_points.is_empty() and not m.dragging,"UI-origin multitouch releases every map gesture state")
	fresh()
	touch(m.MENU_RECT.get_center(),11,true)
	touch(m.PLAY_RECT.get_center(),26,true)
	touch(m.MENU_RECT.get_center(),11,false)
	touch(m.PLAY_RECT.get_center(),26,false)
	check(g.mode=="shop" and m.pan==Vector2.ZERO,"Two simultaneous overlay fingers cannot navigate to either destination")
	fresh()
	touch(Vector2(320,550),7,true)
	touch(m.MENU_RECT.get_center(),0,true)
	touch(m.MENU_RECT.get_center(),0,false)
	move_touch(Vector2(320,550),m.PLAY_RECT.get_center(),7)
	touch(m.PLAY_RECT.get_center(),7,false)
	check(g.mode=="shop" and m.touch_points.is_empty(),"A map gesture owns fingers crossing Menu and Play without triggering navigation")
	for action in [[m.MENU_RECT.get_center(),"home"],[m.TREATS_RECT.get_center(),"loadout"],[m.PLAY_RECT.get_center(),"play"]]:
		fresh()
		touch(action[0],37,true)
		check(g.mode=="shop","%s remains on the map until the navigation tap completes" % action[1])
		touch(action[0],37,false)
		check(g.mode==action[1] and g.navigation_delay>0,"A nonzero touch ID opens %s in one tap through real input" % action[1])
	fresh()
	touch(m.MENU_RECT.get_center(),19,true)
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch(m.MENU_RECT.get_center(),19,false)
	check(g.mode=="shop","Losing focus cancels a pending menu tap")
	fresh()
	touch(m.PLAY_RECT.get_center(),19,true)
	touch(m.PLAY_RECT.get_center(),19,false,true)
	check(g.mode=="shop","A canceled Play touch never launches a run")

func feedback_checks():
	fresh(81.0,true)
	check(m.feedback.is_empty(),"Entering a recipe establishes affordability without a mass bounce")
	check(m.state_for(0,1)=="owned" and m.state_for(6,1)=="affordable" and m.state_for(1,1)=="hidden","Owned and available recipes remain visible while future recipes are hidden")
	check(m.state_for(6,2)=="hidden","Future Gold tier stays hidden until its preceding route node is purchased")
	m.selected=6; m.tier=1; tap(buy_point())
	check(g.bank==37 and g.levels[6]==1,"Buying Gold from 81 coins leaves exactly 37 coins")
	var changed = [Vector2i(2,1)]
	check(same_nodes(affordability_feedback(),changed),"Only the existing Bounce choice bounces when spending makes it unaffordable")
	check(m.state_for(2,1)=="unaffordable" and m.feedback[Vector2i(2,1)].from=="affordable","Bounce records its green-to-red transition")
	check(not m.feedback.has(Vector2i(7,1)) and not m.feedback.has(Vector2i(0,1)),"Unchanged affordable and owned tiles do not bounce")
	check(m.feedback.has(Vector2i(6,1)) and m.feedback[Vector2i(6,1)].kind=="purchase","Purchased Gold tile receives purchase feedback")
	check(m.state_for(0,2)=="unaffordable" and m.state_for(4,1)=="hidden" and m.state_for(5,1)=="hidden" and m.state_for(6,2)=="hidden","Gold reveals an unaffordable Feed 2 while later route nodes remain hidden")
	check(m.feedback.has(Vector2i(0,2)) and m.feedback[Vector2i(0,2)].kind=="reveal","The newly discovered upgrade receives reveal feedback even without enough coins")
	check(m.selected==0 and m.tier==2,"Feedback selects the next Feed tier even while it is unaffordable")
	m.update(.09)
	var animation: Dictionary = m.animation_for(Vector2i(2,1))
	check(animation.offset!=Vector2.ZERO or animation.scale!=Vector2.ONE,"An affordability transition produces visible bounce motion")
	m.update(-1.0); m.update(INF); m.update(NAN)
	var valid = true
	for node in m.feedback:
		var age: float = m.feedback[node].age
		var visual: Dictionary = m.animation_for(node)
		valid = valid and is_finite(age) and age>=0 and visual.offset.is_finite() and visual.scale.is_finite()
	check(valid,"Negative and nonfinite frame deltas cannot poison feedback state")
	m.update(m.FEEDBACK_DURATION+1.0)
	check(m.feedback.is_empty(),"Bounce feedback expires after a bounded duration")
	check(not m.update(0.016),"An unchanged settled map does not request continuous animation redraws")
	g.bank+=50
	m.update(0.0)
	check(same_nodes(affordability_feedback(),[Vector2i(2,1),Vector2i(0,2)]),"Income makes Bounce and the newly opened Feed 2 affordable without revealing later recipes")
	check(m.state_for(2,1)=="affordable" and m.feedback[Vector2i(2,1)].from=="unaffordable","Income records the red-to-green transition")
	m.update(m.FEEDBACK_DURATION+1.0)
	g.bank+=1; m.update(0.0)
	check(m.feedback.is_empty(),"Income that changes no tile's affordability creates no bounce")
	fresh(81.0,true)
	g.reduced_motion=true; m.selected=6; m.tier=1; tap(buy_point()); m.update(.09)
	var still = true
	for node in m.visible_nodes():
		var visual: Dictionary = m.animation_for(node)
		still = still and visual.offset==Vector2.ZERO and visual.scale==Vector2.ONE
	check(still,"Reduced motion keeps every tile's position and scale unchanged")
	check(g.bank==37 and m.state_for(2,1)=="unaffordable" and m.state_for(6,1)=="owned","Reduced motion preserves color state and purchase feedback meaning")
	m.reset_view_state(); m.update(0.0)
	check(m.feedback.is_empty(),"Resetting a view starts a fresh snapshot without replaying old affordability changes")

func start_camera_purchase():
	fresh(100000,true)
	m.selected=6; m.tier=1
	tap(buy_point())

func purchase_camera_checks():
	start_camera_purchase()
	check(m._camera_active and m.pan==Vector2.ZERO,"Buying Gold starts a glide without an immediate camera jump")
	var initial_zoom: float = m.zoom
	var initial_distance: float = m.point(0,2).distance_to(m.FOCUS_AREA.get_center())
	var bank: float = g.bank
	m.update(m.CAMERA_DURATION*.25)
	check(m._camera_active and m.pan.length()>0 and m.point(0,2).distance_to(m.FOCUS_AREA.get_center())<initial_distance,"The camera moves toward the newly revealed Feed 2 over multiple frames")
	var mid_pan: Vector2 = m.pan
	m.update(-1); m.update(INF); m.update(NAN); m.update(0)
	check(m.pan==mid_pan and m.pan.is_finite() and is_finite(m.zoom),"Invalid frame deltas cannot advance or corrupt a camera glide")
	m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.point(0,2).distance_to(m.FOCUS_AREA.get_center())<.01,"A completed glide centers the new upgrade in the clear map area")
	check(m.FOCUS_AREA.grow(-23).encloses(m.node_rect(0,2,false)) and m.zoom==initial_zoom,"The next upgrade clears fixed controls without changing the player's zoom")
	check(m.selected==0 and m.tier==2 and g.bank==bank and g.levels[0]==1,"Camera travel preserves the newly selected successor without buying it")
	check(not m.update(.016),"The settled camera does not keep requesting redraws")

	for route in Graph.routes():
		for camera_zoom in [m.MIN_ZOOM,m.MAX_ZOOM]:
			fresh(100000,true)
			# Exercise a later reveal in each route, well beyond the starting view.
			for node in route.slice(0,5): g.levels[node.x]=node.y
			m.zoom=camera_zoom
			m.pan=Vector2(80,-40)
			m.update(0)
			var bought: Vector2i = route[5]
			var next: Vector2i = route[6]
			m.selected=bought.x; m.tier=bought.y
			tap(buy_point())
			m.update(m.CAMERA_DURATION+1)
			check(m.point(next.x,next.y).distance_to(m.FOCUS_AREA.get_center())<.01 and m.FOCUS_AREA.encloses(m.node_rect(next.x,next.y,false)) and m.zoom==camera_zoom,"Later route %s reveals its successor clearly at zoom %.3f" % [str(bought),camera_zoom])

	for camera_zoom in [m.MIN_ZOOM,m.INITIAL_ZOOM,m.MAX_ZOOM]:
		fresh()
		m.zoom=camera_zoom
		var group: Rect2 = m.node_rect(2,1,false).merge(m.node_rect(7,1,false)).merge(m.node_rect(6,1,false))
		var available_area: Rect2 = m.FOCUS_AREA.grow(-24)
		var needs_fit = group.size.x>available_area.size.x or group.size.y>available_area.size.y
		m.selected=0; m.tier=1
		tap(buy_point())
		m.update(m.CAMERA_DURATION+1)
		var framed = true
		for node in [Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)]:
			framed=framed and m.FOCUS_AREA.grow(-23).encloses(m.node_rect(node.x,node.y,false))
		check(framed and m.zoom<=camera_zoom,"Starter purchase frames all three newly revealed choices at zoom %.3f" % camera_zoom)
		check((m.zoom<camera_zoom) if needs_fit else is_equal_approx(m.zoom,camera_zoom),"Starter framing zooms out only when the three choices do not fit at zoom %.3f" % camera_zoom)

	start_camera_purchase()
	m.update(.1)
	touch(Vector2(360,500),81,true)
	var stopped: Vector2 = m.pan
	check(not m._camera_active,"Touching the map interrupts automatic camera movement immediately")
	m.update(m.CAMERA_DURATION)
	check(m.pan==stopped,"The camera stays under the finger while a touch is held")
	move_touch(Vector2(360,500),Vector2(400,530),81)
	touch(Vector2(400,530),81,false)
	check(m.pan!=stopped and not m._camera_active,"Dragging takes over smoothly without restarting the glide")

	start_camera_purchase()
	m.update(.1)
	wheel(Vector2(360,500),true)
	stopped=m.pan
	var stopped_zoom: float = m.zoom
	m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==stopped and m.zoom==stopped_zoom,"Wheel zoom takes control and the interrupted glide cannot overwrite it")

	start_camera_purchase()
	m.update(.1)
	touch(Vector2(280,450),82,true); touch(Vector2(440,450),83,true)
	move_touch(Vector2(440,450),Vector2(500,450),83)
	stopped=m.pan; stopped_zoom=m.zoom
	touch(Vector2(280,450),82,false); touch(Vector2(500,450),83,false)
	m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==stopped and m.zoom==stopped_zoom and stopped_zoom>m.INITIAL_ZOOM,"Pinching cancels the glide and retains the manual camera transform")

	for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED]:
		start_camera_purchase()
		m.update(.1)
		g._notification(notification)
		stopped=m.pan
		m.update(m.CAMERA_DURATION)
		check(not m._camera_active and m.pan==stopped,"Focus loss or app pause cancels camera travel: %d" % notification)
	start_camera_purchase()
	m.update(.1)
	tap(m.MENU_RECT.get_center())
	stopped=m.pan
	m.update(m.CAMERA_DURATION)
	g.mode="shop"; m.update(.1)
	check(not m._camera_active and m.pan==stopped,"Leaving and reopening the map never resumes an old purchase glide")
	start_camera_purchase()
	m.reset_view_state()
	var entry_pan: Vector2=m.pan
	var entry_zoom: float=m.zoom
	m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==entry_pan and m.zoom==entry_zoom,"Resetting the view cancels its pending camera target and holds the framed entry")

	fresh(100000,true)
	g.reduced_motion=true
	m.selected=6; m.tier=1; tap(buy_point())
	check(not m._camera_active and m.point(0,2).distance_to(m.FOCUS_AREA.get_center())<.01,"Reduced Motion frames the new upgrade immediately without camera travel")
	start_camera_purchase()
	m.update(.1); g.reduced_motion=true; m.update(.016)
	check(not m._camera_active and m.point(0,2).distance_to(m.FOCUS_AREA.get_center())<.01,"Enabling Reduced Motion mid-glide settles directly at the new upgrade")

	fresh(0,true)
	m.selected=6; m.tier=1; tap(buy_point()); m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==Vector2.ZERO,"An unaffordable purchase does not move the camera")
	fresh(100000,true)
	m.selected=0; m.tier=1; tap(buy_point()); m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==Vector2.ZERO,"Pressing an owned upgrade does not move the camera")
	fresh(100000,true)
	g.bank+=1; m.update(.1)
	g.levels.fill(1); m.update(m.CAMERA_DURATION)
	check(not m._camera_active and m.pan==Vector2.ZERO,"Wallet changes and loaded ownership never trigger automatic travel")
	fresh(100000000,true)
	g.levels=Graph.CAPS.duplicate()
	var last_node: Vector2i = Graph.routes()[0].back()
	g.levels[last_node.x]-=1
	m.update(0)
	m.selected=last_node.x; m.tier=last_node.y; tap(buy_point()); m.update(m.CAMERA_DURATION)
	check(g.levels==Graph.CAPS and not m._camera_active and m.pan==Vector2.ZERO,"A final route purchase with no successor never moves the camera")

	start_camera_purchase()
	m.update(.1)
	m.selected=2; m.tier=1; tap(buy_point())
	m.update(m.CAMERA_DURATION+1)
	check(m.point(1,1).distance_to(m.FOCUS_AREA.get_center())<.01 and m.selected==1 and m.tier==1,"A second purchase selects and frames its newly revealed upgrade")

func next_selection_checks():
	fresh(100000,true)
	m.selected=2; m.tier=1
	var funds: float = g.bank
	var bounce_cost: int = g.upgrade_cost(2)
	tap(buy_point())
	check(m.selected==1 and m.tier==1 and g.levels[1]==0 and g.bank==funds-bounce_cost,"Buying Bounce selects Power immediately without purchasing it")
	check(m._card_bounce_age==0 and m._camera_active,"The new purchase card begins its bounce alongside the camera glide")
	m.update(m.CARD_BOUNCE_DURATION*.25)
	check(m.card_offset().y<0 and m.card_offset().x==0,"The updated purchase panel has a small vertical bounce")
	check(m.card_rect().position==m.CARD_RECT.position+m.card_offset() and m.buy_rect().position==m.BUY_RECT.position+m.card_offset(),"The animated card and Buy hit areas follow their drawn positions")
	var lifted_point: Vector2 = m.card_rect().position+Vector2(10,1)
	check(not m.CARD_RECT.has_point(lifted_point) and m.overlay_at(lifted_point),"The lifted panel still intercepts touches above its resting rectangle")
	funds=g.bank
	var power_cost: int = g.upgrade_cost(1)
	var lifted_buy: Vector2 = m.buy_rect().position+Vector2(20,1)
	tap(lifted_buy)
	check(g.levels[1]==1 and g.bank==funds-power_cost and m.selected==5 and m.tier==1,"A second tap buys Power during the bounce and glide, then selects Impact")
	check(m._card_bounce_age==0 and m._camera_active,"A successive purchase restarts feedback for its own next upgrade")

	# A held button is still one action; each purchase requires a fresh release.
	funds=g.bank
	var impact_cost: int = g.upgrade_cost(5)
	touch(buy_point(),94,true)
	m.update(m.CAMERA_DURATION+1)
	check(g.levels[5]==0 and g.bank==funds,"Holding Buy never purchases or repeats automatically")
	touch(buy_point(),94,false)
	check(g.levels[5]==1 and g.bank==funds-impact_cost and m.selected==1 and m.tier==2,"Releasing Buy purchases exactly once and advances to Power 2")
	touch(buy_point(),94,false)
	check(g.levels[1]==1 and g.bank==funds-impact_cost,"A duplicate release cannot purchase the newly selected successor")

	for route in Graph.routes():
		fresh(100000000,true)
		m.selected=route[0].x; m.tier=route[0].y
		var correct = true
		for index in range(route.size()):
			var node: Vector2i = route[index]
			correct=correct and m.selected==node.x and m.tier==node.y
			funds=g.bank
			var cost: int = g.upgrade_cost(node.x)
			var previous=g.levels.duplicate()
			tap(buy_point())
			previous[node.x]+=1
			correct=correct and g.levels==previous and g.bank==funds-cost
		check(correct,"Distinct Buy taps can follow every tier of route %s without reselecting tiles" % str(route[0]))
		funds=g.bank
		var last_node: Vector2i = route.back()
		tap(buy_point())
		check(g.bank==funds and m.selected==last_node.x and m.tier==last_node.y,"A finished route retains its final owned tier without selecting another route")

	fresh(81,true)
	m.selected=6; m.tier=1; tap(buy_point())
	check(g.bank==37 and m.selected==0 and m.tier==2 and m.state_for(0,2)=="unaffordable" and g.upgrade_cost(m.selected)==66,"The auto-selected next card quotes its own price when unaffordable")
	tap(buy_point())
	check(g.bank==37 and g.levels[0]==1 and m.selected==0 and m.tier==2,"An unaffordable successor stays selected and never advances or spends")
	m.update(m.CAMERA_DURATION+1)
	check(m.card_offset()==Vector2.ZERO and m._card_bounce_age<0 and not m.update(.016),"The panel settles and stops redrawing when its bounded bounce ends")

	start_camera_purchase()
	m.update(.05)
	var offset: Vector2 = m.card_offset()
	m.update(-1); m.update(INF); m.update(NAN)
	check(m.card_offset()==offset and m.card_offset().is_finite(),"Invalid frame times cannot corrupt or advance the card bounce")
	m.selected=7; m.tier=1
	touch(buy_point(),95,true); touch(buy_point(),96,true)
	funds=g.bank
	touch(buy_point(),95,false); touch(buy_point(),96,false)
	check(g.bank==funds and g.levels[7]==0,"Multitouch on Buy cannot chain an unintended purchase")

	fresh(100000,true)
	g.reduced_motion=true
	m.selected=2; m.tier=1; tap(buy_point())
	check(m.selected==1 and m.tier==1 and m.card_offset()==Vector2.ZERO and m._card_bounce_age<0,"Reduced Motion updates selection and purchase UI immediately without a bounce")
	start_camera_purchase(); m.update(.05)
	g.reduced_motion=true; m.update(0)
	check(m.card_offset()==Vector2.ZERO and m._card_bounce_age<0,"Enabling Reduced Motion during the panel bounce removes displacement immediately")
	start_camera_purchase(); m.update(.05)
	m.select_at(m.point(7,1))
	check(m.selected==7 and m.card_offset()==Vector2.ZERO and m._card_bounce_age<0,"Manually choosing another upgrade clears the automatic panel bounce")
	start_camera_purchase(); g.levels.fill(0); m.update(0)
	check(not m.has_selection() and m._card_bounce_age<0,"A hidden selection clears its stale panel animation")
	start_camera_purchase(); g.mode="home"; m.update(0)
	check(m._card_bounce_age<0,"Leaving the map clears panel animation")
	start_camera_purchase(); m.reset_view_state()
	check(m._card_bounce_age<0 and m.card_offset()==Vector2.ZERO,"Reset clears the purchase panel bounce")

func zoom_readability_checks():
	fresh()
	g.levels=g.MAX_LEVELS.duplicate()
	m.update(0)
	m.feedback.clear()
	var all_nodes = Graph.nodes()
	for camera_zoom in [m.MIN_ZOOM,.12,.3,m.INITIAL_ZOOM,m.MAX_ZOOM]:
		m.zoom=camera_zoom
		m.pan=Vector2.ZERO
		m.tap_feedback.clear()
		var nonoverlap = true
		var valid = true
		var overview_readable = 0
		var enlarged = 0
		for j in range(all_nodes.size()):
			var node: Vector2i = all_nodes[j]
			var rect: Rect2 = m.node_rect(node.x,node.y)
			valid=valid and rect.has_area() and rect.position.is_finite() and rect.size.is_finite()
			if rect.size.x>=35.99: overview_readable+=1
			if rect.size.x>224.0*camera_zoom: enlarged+=1
			for k in range(j+1,all_nodes.size()):
				var other: Vector2i = all_nodes[k]
				nonoverlap=nonoverlap and not rect.intersects(m.node_rect(other.x,other.y))
		check(valid and nonoverlap,"Rendered nodes remain finite and separate at zoom %.3f" % camera_zoom)
		for j in range(all_nodes.size()):
			m.feedback[all_nodes[j]]={"age":.035+float(j%6)*.035,"kind":"purchase","from":"affordable"}
		var animated_separate = true
		for j in range(all_nodes.size()):
			var node: Vector2i = all_nodes[j]
			for k in range(j+1,all_nodes.size()):
				var other: Vector2i = all_nodes[k]
				animated_separate=animated_separate and not m.node_rect(node.x,node.y).intersects(m.node_rect(other.x,other.y))
		check(animated_separate,"Staggered purchase feedback cannot overlap displayed nodes at zoom %.3f" % camera_zoom)
		m.feedback.clear()
		if camera_zoom<=.3:
			var compact = true
			for node in all_nodes: compact=compact and not m.detail_visible(node.x,node.y)
			check(compact,"Overview hides microscopic price and tier labels at zoom %.3f" % camera_zoom)
		else:
			check(m.detail_visible(0,1),"Normal/close camera displays full starter details at zoom %.3f" % camera_zoom)
		if is_equal_approx(camera_zoom,m.MIN_ZOOM):
			check(enlarged>all_nodes.size()/2 and overview_readable>0,"Overview enlarges most icons beyond ordinary scaling while preserving separate dense markers")
			print("MAP_OVERVIEW readable_icons=",overview_readable,"/",all_nodes.size()," starter_size=",m.node_visual_size(0,1).x)
		check(m.route_width()>=3.0 and m.route_width(true)<=10.0,"Routes keep a 3px minimum and 10px maximum at zoom %.3f" % camera_zoom)
		check(m.route_opacity(true)>=.85,"Owned route remains prominent at zoom %.3f" % camera_zoom)
		var straight = true
		for node in all_nodes:
			for parent in Graph.prerequisites(node.x,node.y):
				var points: PackedVector2Array = m.route_points(parent,node)
				straight=straight and points.size()==2 and points[0].is_equal_approx(m.point(parent.x,parent.y)) and points[1].is_equal_approx(m.point(node.x,node.y))
		check(straight,"Every connection is one straight segment between its nodes at zoom %.3f" % camera_zoom)
		m.pan=m.FOCUS_AREA.get_center()-m.point(0,1)
		m.selected=-1
		var rect: Rect2 = m.node_rect(0,1)
		tap(rect.get_center()+Vector2(rect.size.x*.45,0),43)
		check(m.selected==0 and m.tier==1,"A tap inside the displayed starter edge selects it at zoom %.3f" % camera_zoom)
		m.selected=-1
		m.select_at(rect.get_center()+Vector2(rect.size.x*.5+1,0))
		check(m.selected!=0,"A tap beyond the displayed starter does not use an invisible larger hit box at zoom %.3f" % camera_zoom)
		m.tap_feedback.clear()
		m.selected=-1
		var size: Vector2 = m.node_visual_size(0,1)
		m.pan=Vector2(-size.x*.5+1,500)-m.ORIGIN
		check(m.node_in_view(0,1),"Semantic node culling retains its final visible edge at zoom %.3f" % camera_zoom)
		m.select_at(Vector2(.5,500))
		check(m.selected==0,"Visible semantic node edge remains selectable at zoom %.3f" % camera_zoom)
		m.selected=-1
		m.pan.x-=3
		check(not m.node_in_view(0,1),"Semantic node culling removes a completely offscreen node at zoom %.3f" % camera_zoom)
		m.pan=Vector2.ZERO
		swipe_to_node(0,1)
		check(m.FOCUS_AREA.encloses(m.node_rect(0,1,false)),"Camera clamp can bring the displayed node clear of overlays at zoom %.3f" % camera_zoom)
	m.zoom=m.INITIAL_ZOOM
	check(m.node_visual_size(0,1).is_equal_approx(Vector2.ONE*188.16),"Default view presents the 224px tile at 188.16 logical pixels")
	check(m.route_width()>=7.0 and m.route_width()<=10.0,"Normal route width stays between 7 and 10 logical pixels")

func _initialize():
	g=load("res://scripts/main.gd").new()
	g.testing=true
	g.sound_on=false
	m=g.upgrade_map
	entry_checks()
	progression_checks()
	gesture_checks()
	fullscreen_overlay_checks()
	feedback_checks()
	purchase_camera_checks()
	next_selection_checks()
	zoom_readability_checks()
	g.free()
	print("MAP_QA ",passed," passed; ",failed.size()," failed: ",failed)
	quit(1 if not failed.is_empty() else 0)
