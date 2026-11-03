extends SceneTree
## In-memory progression and checkpoint checks. No player save is opened.
const Graph=preload("res://scripts/upgrade_graph.gd")
const GelatoGraph=preload("res://scripts/gelato_upgrade_graph.gd")
const Main=preload("res://scripts/main.gd")
const Snapshot=preload("res://scripts/run_snapshot.gd")
const OLD_FINGERPRINTS={"bakery":"dea32d445fc64aae42da844b56ab365a58d5835708e3c8c9a11702d404d51c6b","gelato":"c1c2d11c9d71416448974155db9e4b9149ad71c53400d1bae8db9f2979daae96"}
var passed=0
var failures=[]

func check(ok: bool,label: String):
	if ok: passed+=1; print("PASS: ",label)
	else: failures.append(label); print("FAIL: ",label)

func fresh(area: String = "bakery"):
	var g=Main.new()
	g.testing=true
	g.sound_on=false
	g.set_active_area(area)
	g.bank=100000000.0
	return g

func visible(levels: Array):
	var result=[]
	for node in Graph.nodes():
		if Graph.is_visible(levels,node.x,node.y): result.append(node)
	return result

func ancestors(node: Vector2i,seen: Dictionary = {}) -> Dictionary:
	var found=seen.duplicate()
	for parent in Graph.prerequisites(node.x,node.y):
		if not found.has(parent):
			found[parent]=true
			found.merge(ancestors(parent,found))
	return found

func structure():
	var ordered=Graph.nodes()
	check(ordered.size()==62,"All 62 original tiers remain on the map")
	var seen={}
	var counts=[0,0,0,0,0,0,0,0]
	var valid=true
	var acyclic=true
	var single_parent=true
	var edge_count=0
	for node in ordered:
		valid=valid and Graph.valid_node(node.x,node.y) and not seen.has(node)
		var parents=Graph.prerequisites(node.x,node.y)
		edge_count+=parents.size()
		single_parent=single_parent and parents.size()==(0 if node==Vector2i(0,1) else 1)
		for parent in parents: acyclic=acyclic and seen.has(parent)
		seen[node]=true
		counts[node.x]+=1
	check(valid and counts==Graph.CAPS,"Every original family/tier identity occurs exactly once")
	check(acyclic,"All dependencies precede their child; graph has no cycles")
	check(single_parent and edge_count==61,"Only Feed1 has no parent; each of the other 61 tiers has exactly one")
	var routes=Graph.routes()
	check(routes.size()==3 and routes[0].size()==22 and routes[1].size()==22 and routes[2].size()==17,"Three independently playable mixed routes contain all remaining tiers")
	var family_route={}
	var separated=true
	var sequential=true
	var mixed=true
	for route_index in range(routes.size()):
		var previous=Vector2i(0,1)
		var local_counts=[1,0,0,0,0,0,0,0]
		var families={}
		for node in routes[route_index]:
			if family_route.has(node.x): separated=separated and family_route[node.x]==route_index
			family_route[node.x]=route_index
			families[node.x]=true
			local_counts[node.x]+=1
			sequential=sequential and node.y==local_counts[node.x] and Graph.prerequisites(node.x,node.y)==[previous]
			if node.y>1: sequential=sequential and ancestors(node).has(Vector2i(node.x,node.y-1))
			previous=node
		mixed=mixed and families.size()>=2
	check(separated and family_route.size()==8,"Each upgrade family belongs to one route, eliminating hidden cross-route tier requirements")
	check(sequential and mixed,"Mixed routes preserve each family's tier order and its preceding tier is always an ancestor")
	var levels=[0,0,0,0,0,0,0,0]
	check(visible(levels)==[Vector2i(0,1)],"Only the starter is visible before the first purchase")
	var available=[]
	for node in ordered:
		if Graph.is_unlocked(levels,node.x,node.y): available.append(node)
	check(available==[Vector2i(0,1)],"Only Feed1 is initially purchasable")
	levels[0]=1
	available=[]
	for node in ordered:
		if not Graph.is_owned(levels,node.x,node.y) and Graph.is_unlocked(levels,node.x,node.y): available.append(node)
	check(available==[Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)],"Feed1 opens exactly Bounce1, Time1 and Gold1")
	check(visible(levels)==[Vector2i(0,1),Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)],"Buying the starter reveals only the three route heads alongside the owned starter")
	levels[2]=1
	check(Graph.is_unlocked(levels,1,1) and not Graph.is_unlocked(levels,3,1),"Bounce opens Power on its own route without opening another route's Ricochet")
	check(visible(levels)==[Vector2i(0,1),Vector2i(2,1),Vector2i(7,1),Vector2i(6,1),Vector2i(1,1)],"Buying Bounce reveals Power while keeping the other route heads and hiding all deeper nodes")
	levels[1]=1
	check(Graph.is_unlocked(levels,5,1) and not Graph.is_unlocked(levels,1,2),"Power1 opens Impact1; its next tier waits for that one parent")
	var progression_ok=true
	levels=[0,0,0,0,0,0,0,0]
	for node in ordered:
		progression_ok=progression_ok and Graph.is_unlocked(levels,node.x,node.y) and Graph.missing_prerequisites(levels,node.x,node.y).size()<=1
		levels[node.x]+=1
	check(progression_ok and levels==Graph.CAPS,"A fresh profile can reach all 62 tiers without a dead end or a two-parent lock")
	check(visible(levels)==ordered,"A completed map keeps every purchased upgrade visible")
	check(not Graph.is_unlocked([],0,1) and not Graph.is_visible([],0,1) and not Graph.is_visible(levels,-1,1) and not Graph.is_unlocked(levels,8,1) and not Graph.is_unlocked(levels,0,11),"Invalid identities and profile shapes fail closed")
	# Returned arrays cannot mutate the static authoritative graph.
	routes[0].clear()
	ordered.clear()
	check(Graph.nodes().size()==62 and Graph.routes()[0].size()==22,"Callers receive independent copies of node and route lists")

func discovery():
	# For an ordinary profile, each route is an owned prefix followed by one
	# revealed step. Compare against that rule after every individual purchase.
	for route_index in range(Graph.routes().size()):
		var levels=[1,0,0,0,0,0,0,0]
		var routes=Graph.routes()
		var bought={Vector2i(0,1):true}
		var frontier_ok=true
		for depth in range(routes[route_index].size()+1):
			var expected=bought.duplicate()
			for other_index in range(routes.size()):
				var next_depth=depth if other_index==route_index else 0
				if next_depth<routes[other_index].size(): expected[routes[other_index][next_depth]]=true
			var actual=visible(levels)
			frontier_ok=frontier_ok and actual.size()==expected.size()
			for node in Graph.nodes():
				frontier_ok=frontier_ok and (actual.has(node)==expected.has(node))
			if depth<routes[route_index].size():
				var next=routes[route_index][depth]
				levels[next.x]=next.y
				bought[next]=true
		check(frontier_ok,"Every purchase along route %d preserves owned nodes, reveals one successor and leaves other routes unchanged" % [route_index+1])
	var g=fresh()
	g.buy_upgrade(0)
	var before=visible(g.levels)
	g.bank=0
	check(visible(g.levels)==before and before.size()==4,"The next upgrade remains visible even when the player cannot afford it")
	g.free()

func authoritative_purchases():
	var g=fresh()
	var funds=g.bank
	check(not g.buy_upgrade(1) and g.bank==funds and g.levels[1]==0,"Direct Power purchase cannot bypass its parent or debit coins")
	check(g.buy_upgrade(0) and g.buy_upgrade(2) and g.buy_upgrade(1),"Feed, Bounce and Power can be purchased without investing in another route")
	funds=g.bank
	check(not g.buy_upgrade(1) and g.bank==funds and g.levels[1]==1,"Power2 cannot skip the intervening Impact1 parent")
	check(g.buy_upgrade(5) and g.buy_upgrade(1),"Buying the one Impact parent unlocks Power2")
	g.free()
	for area in ["bakery","gelato"]:
		var graph = Graph if area=="bakery" else GelatoGraph
		for route_index in range(graph.routes().size()):
			g=fresh(area)
			var all_ok=g.buy_upgrade(0)
			var expected=[1,0,0,0,0,0,0,0]
			for node in graph.routes()[route_index]:
				var before=g.bank
				var cost=g.upgrade_cost(node.x)
				all_ok=g.buy_upgrade(node.x) and is_equal_approx(g.bank,before-cost) and all_ok
				expected[node.x]=node.y
			check(all_ok and g.levels==expected,"Route %d completes independently with exact debits and untouched other routes in %s" % [route_index+1,area])
			g.free()
		g=fresh(area)
		var all_ok=true
		for node in graph.nodes():
			var before=g.bank
			var cost=g.upgrade_cost(node.x)
			all_ok=g.buy_upgrade(node.x) and is_equal_approx(g.bank,before-cost) and g.levels[node.x]==node.y and all_ok
		check(all_ok and g.levels==graph.CAPS,"All tiers can be purchased, with exact debits, in "+area)
		funds=g.bank
		check(not g.buy_upgrade(1) and g.bank==funds,"A capped Power family cannot spend additional coins in "+area)
		g.free()

func vouchers_and_legacy():
	var g=fresh()
	g.module_vouchers=2
	check(not g.claim_module("ricochet") and g.module_vouchers==2 and g.levels[3]==0,"Voucher cannot bypass its connected route parent")
	g.buy_upgrade(0); g.buy_upgrade(7)
	var funds=g.bank
	check(g.claim_module("ricochet") and g.levels[3]==1 and g.module_vouchers==1 and g.bank==funds,"Connected ingredient consumes one voucher and no coins")
	check(not g.claim_module("ricochet") and g.module_vouchers==1,"Owned ingredient cannot consume another voucher")
	g.toggle_module("invalid")
	check(g.levels[2]==0,"Invalid module identity cannot target the Bounce family")
	g.levels=[0,8,0,0,0,0,0,0]
	var legacy=g.levels.duplicate()
	check(Graph.is_owned(g.levels,1,8) and Graph.is_visible(g.levels,1,8) and Graph.is_unlocked(g.levels,1,8),"Previously owned Power tiers stay owned and visible without retroactive prerequisites")
	funds=g.bank
	check(not g.buy_upgrade(1) and g.levels==legacy and g.bank==funds,"Legacy Power build retains all tiers but connects its route before the next purchase")
	check(g.buy_upgrade(0) and g.levels[1]==8,"Legacy profile can build missing support without losing Power")
	g.free()
	var legacy_profiles=[[0,8,0,0,0,0,0,0],[3,8,1,0,0,0,2,4],[0,0,0,6,6,6,0,0],[10,0,0,0,0,0,8,0]]
	for profile in legacy_profiles:
		g=fresh()
		g.levels=profile.duplicate()
		var preserved=true
		var completed=true
		for node in Graph.nodes():
			preserved=preserved and (node.y>profile[node.x] or (Graph.is_owned(g.levels,node.x,node.y) and Graph.is_visible(g.levels,node.x,node.y)))
			completed=completed and Graph.missing_prerequisites(g.levels,node.x,node.y).size()<=1
			if not Graph.is_owned(g.levels,node.x,node.y):
				completed=completed and Graph.is_visible(g.levels,node.x,node.y)
				completed=g.buy_upgrade(node.x) and completed
		check(preserved and completed and g.levels==Graph.CAPS,"Irregular legacy profile %s keeps owned tiers visible and reveals every missing tier needed to finish" % [str(profile)])
		g.free()

func damage_and_resume():
	var g=fresh()
	check(is_equal_approx(g.power_damage(0),1) and is_equal_approx(g.power_damage(3),2.5) and is_equal_approx(g.power_damage(6),3.55) and is_equal_approx(g.power_damage(10),4.55),"Power tapers at the approved breakpoints to a 4.55 cap")
	g.levels[1]=4
	check(is_equal_approx(g.power_damage(),2.85) and is_equal_approx(g.power_damage(5),3.20),"Functional upgrade copy preserves the approved Power calculation")
	for family in range(g.UPGRADE_DESC.size()):
		check(g.upgrade_value(family)==g.UPGRADE_DESC[family] and g.upgrade_preview(family)==g.UPGRADE_DESC[family] and not "%" in g.UPGRADE_DESC[family],"Upgrade %d uses the shared functional description without percentage stats" % family)
	g.free()
	for area in ["bakery","gelato"]:
		g=fresh(area)
		g.levels=[3,8,1,0,0,0,2,4]
		g.bank=7654.5
		g.total_shifts=28
		g.module_vouchers=2
		g.monetization.attempts=3
		g.monetization.active_seconds=111
		g.monetization.entitlements={"remove_ads":true,"baker_toolkit":true}
		g.monetization.store_owned=g.monetization.entitlements.duplicate()
		g.start_shift()
		var snapshot=Snapshot.capture(g)
		check(not snapshot.is_empty() and g.restore_active_run(snapshot),"Current checkpoint resumes with irregular layout in "+area)
		var campaign=g.campaign_profile()
		var permanent=g.monetization.export_state()
		snapshot.fingerprint=OLD_FINGERPRINTS[area]
		check(not g.restore_active_run(snapshot) and g.mode=="home" and not g.snapshot_rejection.is_empty(),"Pre-rebalance active checkpoint safely returns to Home in "+area)
		check(g.campaign_profile()==campaign and g.monetization.export_state()==permanent,"Checkpoint rejection preserves coins, owned tiers, vouchers, attempts and permanent purchases in "+area)
		g.free()

func _initialize():
	structure()
	discovery()
	authoritative_purchases()
	vouchers_and_legacy()
	damage_and_resume()
	print("UPGRADE_GRAPH_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
