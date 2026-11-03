extends SceneTree
## Independent purchase topology and geometry checks. No player-profile access.
const Graph = preload("res://scripts/gelato_upgrade_graph.gd")
const BakeryGraph = preload("res://scripts/upgrade_graph.gd")
const ROOT = Vector2i(0,1)
const TWIN = Vector2i(8,1)
var passed = 0
var failures: Array[String] = []

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func node_id(value) -> Vector2i:
	return Vector2i(int(value[0]),int(value[1]))

func point(value) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func ancestors(node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var pending: Array[Vector2i] = Graph.prerequisites(node.x,node.y)
	while not pending.is_empty() and result.size()<63:
		var current: Vector2i = pending.pop_back()
		if current in result: continue
		result.append(current)
		pending.append_array(Graph.prerequisites(current.x,current.y))
	return result

func children(node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for candidate in Graph.nodes():
		if node in Graph.prerequisites(candidate.x,candidate.y): result.append(candidate)
	return result

func structure():
	var nodes=Graph.nodes()
	check(nodes.size()==62 and Graph.CAPS==[10,10,6,6,6,6,8,10] and Graph.routes().size()==2 and Graph.routes()[0].size()==14 and Graph.routes()[1].size()==14,"All62 original tiers remain on two14step Gelato arms with unchanged saved caps")
	var seen={}; var counts=[0,0,0,0,0,0,0,0]; var edges=0; var topology=true
	for node in nodes:
		topology=topology and Graph.valid_node(node.x,node.y) and not seen.has(node)
		var parents=Graph.prerequisites(node.x,node.y)
		edges+=parents.size()
		topology=topology and parents.size()==(0 if node==ROOT else 1)
		for parent in parents: topology=topology and seen.has(parent)
		seen[node]=true; counts[node.x]+=1
	check(topology and counts==Graph.CAPS and edges==61,"Exactly one root and61 real prerequisite edges form an acyclic tree")
	var shuffled=false
	for node in nodes:
		if node.y>1 and Vector2i(node.x,node.y-1) not in ancestors(node): shuffled=true
	check(shuffled,"Fixed slot ordinals are deliberately independent of purchase order")
	var route_nodes=[]
	for index in range(Graph.routes().size()):
		var previous=ROOT; var valid=true
		for node in Graph.routes()[index]:
			valid=valid and node not in route_nodes and Graph.prerequisites(node.x,node.y)==[previous]
			route_nodes.append(node); previous=node
		check(valid,"Main arm%d remains one uninterrupted purchase chain"%index)
	var branch_nodes=[]; var branches_valid=Graph.branches().size()==6
	var lengths=[6,6,5,6,6,4]
	for index in range(Graph.branches().size()):
		var branch: Array=Graph.branches()[index]
		branches_valid=branches_valid and branch.size()==lengths[index]
		var parent: Vector2i=Graph.prerequisites(branch[0].x,branch[0].y)[0]
		for node in branch:
			branches_valid=branches_valid and node not in route_nodes and node not in branch_nodes and Graph.prerequisites(node.x,node.y)==[parent]
			branch_nodes.append(node); parent=node
	check(branches_valid and route_nodes.size()+branch_nodes.size()+1==62,"Six actual4–6upgrade tines and the continuing antler arms account for every tier")
	for path in Graph.routes()+Graph.branches():
		var families={}; var previous=-1; var streak=0; var longest=0
		for node in path:
			families[node.x]=true
			streak=streak+1 if node.x==previous else 1
			longest=maxi(longest,streak); previous=node.x
		check(families.size()>=4 and longest<=2,"Each real path mixes at least four upgrade families without long repeated-family runs")
	for side in range(2):
		var fork_depths=[]
		var route: Array=Graph.routes()[side]
		for index in range(route.size()):
			if children(route[index]).size()>1: fork_depths.append(index+1)
		check(fork_depths==[3,6,9],"Arm%d forks everythree upgrades, then ends with a five-upgrade continuation"%side)
	var fork_count=0
	for node in nodes:
		if children(node).size()>1: fork_count+=1
	check(fork_count==7,"The central split and six successive branch-of-branch forks are actual purchase choices")
	check(BakeryGraph.routes().size()==3 and BakeryGraph.routes()[0].size()==22,"Bakery keeps its established independent three-route graph")

func segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b): return true
	var corners=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for index in range(4):
		if Geometry2D.segment_intersects_segment(a,b,corners[index],corners[(index+1)%4])!=null: return true
	return false

func edge_tangent(data: Dictionary,parent: Vector2i,node: Vector2i,at_end: bool) -> Vector2:
	for edge in data.edges:
		if node_id(edge.from)==parent and node_id(edge.to)==node:
			var vertices: Array=edge.points
			return (point(vertices[-1])-point(vertices[-2])).normalized() if at_end else (point(vertices[1])-point(vertices[0])).normalized()
	return Vector2.ZERO

func visible_exit_tangent(data: Dictionary,parent: Vector2i,node: Vector2i,at_end: bool,half_size: float) -> Vector2:
	for edge in data.edges:
		if node_id(edge.from)!=parent or node_id(edge.to)!=node: continue
		var vertices: Array=edge.points.duplicate(true)
		if at_end: vertices.reverse()
		var anchor=point(vertices[0])
		for index in range(1,vertices.size()):
			var delta=(point(vertices[index])-anchor).abs()
			if maxf(delta.x,delta.y)>=half_size:
				var direction=(point(vertices[index])-point(vertices[index-1])).normalized()
				return -direction if at_end else direction
	return Vector2.ZERO

func layout_geometry():
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/gelato_upgrade_layout.json"))
	check(data is Dictionary and data.get("schema")==1 and data.get("shape",{}).get("kind")=="winding_tree","The authored layout declares the taller winding-tree composition")
	var artwork=JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_arc_art.json"))
	check(data.shape.world_rect==artwork.areas.gelato.world_rect,"Art and live upgrades share exactly the same world bounds")
	var positions={}
	for entry in data.nodes: positions[node_id(entry.id)]=point(entry.position)
	var complete=positions.size()==62 and positions.get(ROOT)==Vector2.ZERO
	for node in Graph.nodes(): complete=complete and positions.has(node)
	check(complete,"Every retained tier has one fixed position around the central Feed1 origin")
	var branch_metadata=data.get("branches",[]).size()==Graph.branches().size()
	for index in range(Graph.branches().size()):
		var branch: Array=Graph.branches()[index]; var authored: Dictionary=data.branches[index]
		branch_metadata=branch_metadata and authored.nodes.size()==branch.size() and Graph.prerequisites(branch[0].x,branch[0].y)==[node_id(authored.anchor)]
		for depth in range(branch.size()): branch_metadata=branch_metadata and branch[depth]==node_id(authored.nodes[depth])
		branch_metadata=branch_metadata and int(authored.route_index)==(0 if index<3 else 1) and int(authored.fork_depth)==3*(index%3+1)
	check(branch_metadata,"Authored metadata identifies every real4–6step tine and its actual anchor")
	var handoffs: Array=data.get("spine_handoffs",[])
	var handoffs_valid=handoffs.size()==6
	for handoff in handoffs:
		var side=int(handoff.route_index); var depth=int(handoff.fork_depth)
		var route: Array=Graph.routes()[side]
		var anchor=node_id(handoff.anchor); var continuation=node_id(handoff.continuation); var terminal=node_id(handoff.terminal_branch)
		handoffs_valid=handoffs_valid and depth in [3,6,9] and anchor==route[depth-1] and node_id(handoff.incoming)==route[depth-2] and continuation==route[depth] and terminal!=continuation and Graph.prerequisites(terminal.x,terminal.y)==[anchor]
	check(handoffs_valid,"Six authored handoffs correctly identify each continuing branch and misleading terminal tine")
	var special: Dictionary=data.special_nodes[0]
	positions[TWIN]=point(special.position)
	check(data.special_nodes.size()==1 and node_id(special.id)==TWIN and node_id(special.parent)==ROOT and positions[TWIN].x==0 and positions[TWIN].y>=350,"Dual Shot is authored below the central start with its own root link")
	var all_nodes=Graph.nodes(); all_nodes.append(TWIN)
	var node_bounds=Rect2(positions[ROOT],Vector2.ZERO)
	for node in all_nodes: node_bounds=node_bounds.expand(positions[node])
	check(node_bounds.size.y>=node_bounds.size.x*1.8,"The live tree is substantially taller than it is wide")
	var minimum_spacing=INF
	var spacing={}
	for i in range(all_nodes.size()):
		spacing[all_nodes[i]]=INF
		for other in all_nodes:
			if other==all_nodes[i]: continue
			var separation: Vector2=(positions[all_nodes[i]]-positions[other]).abs()
			spacing[all_nodes[i]]=minf(spacing[all_nodes[i]],maxf(separation.x,separation.y))
		for j in range(i+1,all_nodes.size()):
			var delta: Vector2=(positions[all_nodes[i]]-positions[all_nodes[j]]).abs()
			minimum_spacing=minf(minimum_spacing,maxf(delta.x,delta.y))
	check(minimum_spacing>=299.99,"Every tile pair retains at least76world-pixel axis clearance")
	var minimum_zoom=minf(.055,minf(624.0/(node_bounds.size.x+224),722.0/(node_bounds.size.y+224)))
	var peak_size={}
	for node in all_nodes:
		var largest=224.0
		for at_zoom in [minimum_zoom,1.55,36.0/224.0,.5,clampf(38.0/spacing[node],minimum_zoom,1.55)]:
			largest=maxf(largest,minf(maxf(224*at_zoom,36),spacing[node]*at_zoom-(6 if 224*at_zoom>=112 else 2))/at_zoom)
		peak_size[node]=largest
	for side in range(2):
		var previous=Vector2.ZERO; var rising=true
		for node in Graph.routes()[side]:
			var current: Vector2=positions[node]
			rising=rising and current.y<previous.y and signf(current.x)==(-1.0 if side==0 else 1.0)
			previous=current
		check(rising,"Main arm%d snakes upward on its own side of the central U"%side)
		var route: Array=Graph.routes()[side]
		for depth in [3,6,9]:
			var anchor: Vector2i=route[depth-1]
			var continuation: Vector2i=route[depth]
			var incoming: Vector2=edge_tangent(data,route[depth-2],anchor,true)
			var terminal: Vector2i=children(anchor)[0]
			if terminal==continuation: terminal=children(anchor)[1]
			var direct: Vector2=edge_tangent(data,anchor,terminal,false)
			var turn: Vector2=edge_tangent(data,anchor,continuation,false)
			check(incoming.dot(direct)>incoming.dot(turn)+.05,"At arm%d fork%d the apparent straight continuation is the terminal tine; the turning branch climbs onward"%[side,depth])
			for half_size in [112.0,peak_size[anchor]*.5]:
				var arrival=visible_exit_tangent(data,route[depth-2],anchor,true,half_size)
				var apparent=visible_exit_tangent(data,anchor,terminal,false,half_size)
				var continuing=visible_exit_tangent(data,anchor,continuation,false,half_size)
				check(arrival.dot(apparent)>arrival.dot(continuing),"Arm%d fork%d keeps its deceptive continuation outside the actual %.2f-world tile footprint"%[side,depth,half_size*2])
	for index in range(Graph.branches().size()):
		var branch: Array=Graph.branches()[index]; var previous: Vector2=positions[Graph.prerequisites(branch[0].x,branch[0].y)[0]]; var rising=true
		for node in branch:
			var current: Vector2=positions[node]; rising=rising and current.y<previous.y; previous=current
		check(rising,"Long tine%d grows upward rather than folding down over preceding upgrades"%index)
	var edges={}; var attached=data.edges.size()==61; var curved=0
	for edge in data.edges:
		var parent=node_id(edge.from); var node=node_id(edge.to); var key=Vector4i(parent.x,parent.y,node.x,node.y)
		var path: Array[Vector2]=[]
		for vertex in edge.points: path.append(point(vertex))
		var farthest=0.0
		for vertex in path: farthest=maxf(farthest,vertex.distance_to(Geometry2D.get_closest_point_to_segment(vertex,path[0],path[-1])))
		if path.size()>=8 and farthest>=12: curved+=1
		attached=attached and not edges.has(key) and Graph.prerequisites(node.x,node.y)==[parent] and path.size()>=2 and path[0].distance_to(positions[parent])<.001 and path[-1].distance_to(positions[node])<.001
		edges[key]=path
	check(attached,"Every visible route is backed by its exact purchase prerequisite and correct endpoints")
	check(curved>=40,"Most live links visibly bend through authored intermediate points rather than straight chords")
	edges[Vector4i(ROOT.x,ROOT.y,TWIN.x,TWIN.y)]=[positions[ROOT],positions[TWIN]]
	var no_crossings=true; var no_tile_hits=true; var keys=edges.keys()
	for i in range(keys.size()):
		var first: Vector4i=keys[i]; var a: Array=edges[first]
		for node in all_nodes:
			if node in [Vector2i(first.x,first.y),Vector2i(first.z,first.w)]: continue
			var extent=float(peak_size[node])*.5+64
			var tile=Rect2(positions[node]-Vector2.ONE*extent,Vector2.ONE*extent*2)
			for segment in range(a.size()-1): no_tile_hits=no_tile_hits and not segment_hits_rect(a[segment],a[segment+1],tile)
		for j in range(i+1,keys.size()):
			var second: Vector4i=keys[j]
			var shared=[]
			for endpoint in [Vector2i(first.x,first.y),Vector2i(first.z,first.w)]:
				if endpoint in [Vector2i(second.x,second.y),Vector2i(second.z,second.w)]: shared.append(positions[endpoint])
			var b: Array=edges[second]
			for ai in range(a.size()-1):
				for bi in range(b.size()-1):
					var crossing=Geometry2D.segment_intersects_segment(a[ai],a[ai+1],b[bi],b[bi+1])
					if crossing==null: continue
					var permitted=false
					for endpoint in shared: permitted=permitted or crossing.distance_to(endpoint)<.05
					no_crossings=no_crossings and permitted
	check(no_crossings,"All main, nested and Dual Shot paths avoid unrelated path crossings")
	check(no_tile_hits,"Curves plus64-world stroke clearance avoid every unrelated tile's maximum compact footprint")
	var w: Array=data.shape.world_rect; var world=Rect2(float(w[0]),float(w[1]),float(w[2]),float(w[3])); var in_world=true
	for node in all_nodes: in_world=in_world and world.encloses(Rect2(positions[node]-Vector2(140,140),Vector2(280,280)))
	check(in_world,"All63 node and selection footprints fit inside the illustrated world")
	var reserves: Array=data.shape.get("scenery_reserves",[])
	check(reserves.size()>=2,"The scenery declares physical keep-out regions for both inner trees")
	for reserve in reserves:
		var box: Array=reserve.rect
		var rect=Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
		var nodes_clear=world.encloses(rect); var links_clear=true
		for node in all_nodes:
			nodes_clear=nodes_clear and not rect.intersects(Rect2(positions[node]-Vector2(140,140),Vector2(280,280)))
		for key in keys:
			var path: Array=edges[key]
			for segment in range(path.size()-1):
				links_clear=links_clear and not segment_hits_rect(path[segment],path[segment+1],rect.grow(30))
		check(nodes_clear,"Node/selection footprints clear declared scenery region "+str(reserve.id))
		check(links_clear,"Links retain30world-pixel clearance from scenery region "+str(reserve.id))

func _initialize():
	structure(); layout_geometry()
	print("GELATO_UPGRADE_GRAPH_QA_RESULT passed=%d failed=%d" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
