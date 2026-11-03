extends SceneTree
## Tests the complete authored map's exact polyline geometry, including recipes
## not yet discovered. No player profile is loaded, saved or entered into the tree.
const Graph = preload("res://scripts/upgrade_graph.gd")
const Main = preload("res://scripts/main.gd")
const EPS = .001
const MIN_TILE_GAP = 36.0
var passed = 0
var failures: Array[String] = []
var report: Dictionary = {}

func check(ok: bool, label: String):
	if ok:
		passed += 1
		print("PASS: ",label)
	else:
		failures.append(label)
		print("FAIL: ",label)

func note_examples(label: String, issues: Array):
	if issues.is_empty(): return
	for issue in issues.slice(0,8): print("LAYOUT_DETAIL ",label,": ",issue)

func cross(a: Vector2, b: Vector2) -> float:
	return a.x*b.y-a.y*b.x

func contacts(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	# Return an intersection point, or both overlap endpoints for collinear
	# segments. Segment sampling would miss short crossings and shared runs.
	var r=b-a
	var s=d-c
	var denominator=cross(r,s)
	if absf(denominator)>EPS:
		var t=cross(c-a,s)/denominator
		var u=cross(c-a,r)/denominator
		if t>=-EPS and t<=1+EPS and u>=-EPS and u<=1+EPS:
			return PackedVector2Array([a+r*clampf(t,0,1)])
		return PackedVector2Array()
	if absf(cross(c-a,r))>EPS: return PackedVector2Array()
	var length_squared=r.length_squared()
	if length_squared<EPS:
		if a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d))<EPS:
			return PackedVector2Array([a])
		return PackedVector2Array()
	var t0=(c-a).dot(r)/length_squared
	var t1=(d-a).dot(r)/length_squared
	var low=maxf(0,minf(t0,t1))
	var high=minf(1,maxf(t0,t1))
	if high<low-EPS: return PackedVector2Array()
	if absf(high-low)<EPS: return PackedVector2Array([a+r*low])
	return PackedVector2Array([a+r*low,a+r*high])

func segment_enters_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# A conservative rectangle includes tile art and a 4 px stroke margin.
	if rect.has_point(a) or rect.has_point(b): return true
	var corners=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in range(4):
		if not contacts(a,b,corners[i],corners[(i+1)%4]).is_empty(): return true
	return false

func shared_nodes(a: Vector4i, b: Vector4i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for node in [Vector2i(a.x,a.y),Vector2i(a.z,a.w)]:
		if node==Vector2i(b.x,b.y) or node==Vector2i(b.z,b.w): result.append(node)
	return result

func concealed(contact: Vector2, shared: Array[Vector2i], positions: Dictionary, tile_size: Vector2) -> bool:
	for node in shared:
		# The inset prevents treating an exposed contact just outside a tile as
		# a legitimate node junction. Rounded corners are excluded as well.
		var delta=(contact-positions[node]).abs()
		var half=tile_size*.5-Vector2.ONE*2
		if delta.x<=half.x and delta.y<=half.y:
			var corner=(delta-(half-Vector2.ONE*24)).max(Vector2.ZERO)
			if corner.length()<=24+EPS: return true
	return false

func paths_cross(a: PackedVector2Array, b: PackedVector2Array, shared: Array[Vector2i], positions: Dictionary, tile_size: Vector2) -> bool:
	for i in range(a.size()-1):
		for j in range(b.size()-1):
			for contact in contacts(a[i],a[i+1],b[j],b[j+1]):
				if not concealed(contact,shared,positions,tile_size): return true
	return false

func checker_contract():
	check(contacts(Vector2(0,0),Vector2(10,10),Vector2(0,10),Vector2(10,0)).size()==1,"Crossing detector catches a diagonal X between sample points")
	check(contacts(Vector2(0,0),Vector2(10,0),Vector2(4,0),Vector2(8,0)).size()==2,"Crossing detector catches collinear shared line runs")
	check(contacts(Vector2(0,0),Vector2(10,0),Vector2(10,0),Vector2(5,0)).size()==2,"Crossing detector catches a route reversing over its previous segment")
	check(contacts(Vector2(0,0),Vector2(10,0),Vector2(10,0),Vector2(10,10)).size()==1,"Crossing detector catches an unconnected endpoint touching a route")
	check(contacts(Vector2(0,0),Vector2(10,0),Vector2(0,4),Vector2(10,4)).is_empty(),"Separate parallel routes are not reported as crossings")
	check(segment_enters_rect(Vector2(-10,0),Vector2(10,0),Rect2(-2,-2,4,4)),"Tile obstruction detection catches a route passing through between samples")
	check(not segment_enters_rect(Vector2(-10,5),Vector2(10,5),Rect2(-2,-2,4,4)),"A clear route outside a tile is accepted")
	var shared: Array[Vector2i]=[Vector2i(0,1)]
	var positions={Vector2i(0,1):Vector2.ZERO}
	check(not paths_cross(PackedVector2Array([Vector2.ZERO,Vector2(120,0)]),PackedVector2Array([Vector2.ZERO,Vector2(0,120)]),shared,positions,Vector2(142,142)),"Branches may join underneath their actual shared tile")
	check(paths_cross(PackedVector2Array([Vector2.ZERO,Vector2(120,0)]),PackedVector2Array([Vector2.ZERO,Vector2(90,0),Vector2(90,100)]),shared,positions,Vector2(142,142)),"A shared node does not excuse line overlap outside its tile")

func inspect_arc(positions: Dictionary, tile_size: Vector2) -> Dictionary:
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_layout.json"))
	var has_shape = layout is Dictionary and layout.get("shape") is Dictionary
	check(has_shape,"Production layout describes the intended annular arc")
	if not has_shape: return {}
	var shape: Dictionary = layout.shape
	var raw_center = shape.get("center")
	var valid_center = raw_center is Array and raw_center.size()==2
	check(valid_center,"The annular arc has a two-dimensional center")
	if not valid_center: return {}
	var arc_center = Vector2(float(raw_center[0]),float(raw_center[1]))
	var inner = float(shape.get("inner_radius",0))
	var outer = float(shape.get("outer_radius",0))
	var sweep = float(shape.get("sweep_degrees",0))
	var start = float(shape.get("start_angle_degrees",0))
	var direction = float(shape.get("direction",0))
	var intended = shape.get("kind","")=="annular_arc" and is_equal_approx(float(shape.get("coverage",0)),1.0/3.0) and is_equal_approx(sweep,120) and is_equal_approx(start,210)
	check(intended,"The compact map occupies a 120-degree sector centered above the ring center")
	var usable = arc_center.is_finite() and is_finite(inner) and is_finite(outer) and is_finite(start) and absf(direction)==1 and outer>inner and inner>tile_size.length()*.5
	check(usable,"Finite annular bounds leave a central hole wider than a tile")
	if not usable or not intended: return {}
	var within = true
	var min_radius = INF
	var max_radius = -INF
	var min_angle = INF
	var max_angle = -INF
	var quarters = [0,0,0,0]
	var first_angle = 0.0
	for node in positions:
		var relative: Vector2 = positions[node]-arc_center
		var radius = relative.length()
		var angle = fposmod(direction*(rad_to_deg(relative.angle())-start),360.0)
		# The authored JSON rounds coordinates. A point at the start can land a
		# fraction below zero after conversion, which wraps to almost 360 degrees.
		if angle>359.999: angle=0.0
		min_radius=minf(min_radius,radius)
		max_radius=maxf(max_radius,radius)
		min_angle=minf(min_angle,angle)
		max_angle=maxf(max_angle,angle)
		within=within and radius>=inner-.1 and radius<=outer+.1 and angle<=sweep+.01
		quarters[clampi(int(angle/sweep*4),0,3)]+=1
		if node==Vector2i(0,1): first_angle=angle
	check(within,"Every recipe center stays within the annular sector")
	check(absf((max_angle-min_angle)-120)<=1,"Actual placements span approximately 120 degrees")
	check(max_radius-min_radius>maxf(tile_size.length(),(outer-inner)*.45),"Recipes occupy the ring's width instead of a single curved row")
	check(quarters.min()>=3,"Recipes populate all four parts of the arc")
	check(positions[Vector2i(0,1)].is_equal_approx(Vector2.ZERO) and first_angle<=1,"Feed 1 remains at the camera origin and the starting end of the arc")
	return {"arc_span_degrees":max_angle-min_angle,"arc_radial_spread":max_radius-min_radius,"arc_quarter_counts":quarters}

func inspect_layout(game):
	var map=game.upgrade_map
	var nodes=Graph.nodes()
	var positions: Dictionary=map._positions
	var paths: Dictionary=map._paths
	var expected={}
	for child in nodes:
		for parent in Graph.prerequisites(child.x,child.y):
			expected[Vector4i(parent.x,parent.y,child.x,child.y)]=true
	var complete=positions.size()==62 and positions.size()==nodes.size()
	for node in nodes: complete=complete and positions.has(node)
	check(complete,"Every original recipe has exactly one production-map position")
	if not complete: return
	var exact=paths.size()==expected.size()
	for key in expected: exact=exact and paths.has(key)
	check(exact,"Rendered routes match every authoritative prerequisite with no missing or invented edges")
	if not exact: return
	var finite=true
	var attached=true
	var nonsingular=true
	var straight=true
	for node in nodes: finite=finite and positions[node].is_finite()
	for edge in paths:
		var path: PackedVector2Array=paths[edge]
		straight=straight and path.size()==2
		if path.size()<2:
			nonsingular=false
			continue
		for p in path: finite=finite and p.is_finite()
		var source: Vector2=positions[Vector2i(edge.x,edge.y)]
		var destination: Vector2=positions[Vector2i(edge.z,edge.w)]
		attached=attached and Rect2(source-map.TILE_SIZE*.5,map.TILE_SIZE).grow(EPS).has_point(path[0]) and Rect2(destination-map.TILE_SIZE*.5,map.TILE_SIZE).grow(EPS).has_point(path[-1])
		for i in range(path.size()-1): nonsingular=nonsingular and path[i].distance_to(path[i+1])>EPS
	check(finite,"All positions and rendered path points are finite")
	check(straight and paths.size()==61,"Every prerequisite is rendered as one of 61 straight two-point connections")
	check(nonsingular,"Every route has at least two distinct points and no zero-length segments")
	check(attached,"Every rendered route attaches to its own source and destination tile")
	if not finite or not nonsingular: return
	var arc_report=inspect_arc(positions,map.TILE_SIZE)
	var layout_bounds=Rect2(positions[nodes[0]],Vector2.ZERO)
	for node in nodes: layout_bounds=layout_bounds.expand(positions[node])
	var overview_size=(layout_bounds.size+map.TILE_SIZE)*map.MIN_ZOOM
	check(overview_size.x<=map.FOCUS_AREA.size.x and overview_size.y<=map.FOCUS_AREA.size.y,"The entire map including tile edges fits the usable viewport at minimum zoom")
	var first_choices_fit=true
	for node in [Vector2i(2,1),Vector2i(7,1),Vector2i(6,1)]:
		var initial_center: Vector2=map.ORIGIN+positions[node]*map.INITIAL_ZOOM
		var initial_size: Vector2=map.TILE_SIZE*map.INITIAL_ZOOM
		first_choices_fit=first_choices_fit and map.FOCUS_AREA.encloses(Rect2(initial_center-initial_size*.5,initial_size))
	check(first_choices_fit,"All three first revealed choices fit the usable viewport at the default camera")
	var crowded=[]
	var minimum_gap=INF
	for i in range(nodes.size()):
		for j in range(i+1,nodes.size()):
			var delta: Vector2=(positions[nodes[i]]-positions[nodes[j]]).abs()-map.TILE_SIZE
			var gap=maxf(delta.x,delta.y)
			minimum_gap=minf(minimum_gap,gap)
			if gap<MIN_TILE_GAP-EPS: crowded.append([nodes[i],nodes[j],gap])
	check(crowded.is_empty(),"All 62 tiles retain at least 36 logical pixels of axis clearance")
	note_examples("crowded tiles",crowded)
	var obstructions=[]
	var self_crossings=[]
	for edge in paths:
		var path: PackedVector2Array=paths[edge]
		for node in nodes:
			if node==Vector2i(edge.x,edge.y) or node==Vector2i(edge.z,edge.w): continue
			var tile=Rect2(positions[node]-map.TILE_SIZE*.5,map.TILE_SIZE).grow(4)
			for i in range(path.size()-1):
				if segment_enters_rect(path[i],path[i+1],tile):
					obstructions.append([edge,node])
					break
		for i in range(path.size()-1):
			for j in range(i+1,path.size()-1):
				var intersections=contacts(path[i],path[i+1],path[j],path[j+1])
				if (j==i+1 and intersections.size()>1) or (j>i+1 and not intersections.is_empty()):
					self_crossings.append([edge,i,j])
	check(obstructions.is_empty(),"No route passes through an unrelated tile, including undiscovered recipes")
	note_examples("obstructed routes",obstructions)
	check(self_crossings.is_empty(),"No individual route loops across or back over itself")
	note_examples("self-crossing routes",self_crossings)
	var crossing=[]
	var edge_ids=paths.keys()
	for i in range(edge_ids.size()):
		for j in range(i+1,edge_ids.size()):
			var a: Vector4i=edge_ids[i]
			var b: Vector4i=edge_ids[j]
			if paths_cross(paths[a],paths[b],shared_nodes(a,b),positions,map.TILE_SIZE): crossing.append([a,b])
	check(crossing.is_empty(),"No two routes intersect or overlap outside their legitimate shared tile")
	note_examples("crossing routes",crossing)
	report={"nodes":nodes.size(),"edges":paths.size(),"minimum_axis_tile_gap":minimum_gap,"crowded_pairs":crowded.size(),"obstructed_routes":obstructions.size(),"self_crossings":self_crossings.size(),"crossing_edge_pairs":crossing.size()}
	report.merge(arc_report)
	var before=var_to_bytes([positions,paths])
	game.mode="shop"
	game.levels.fill(0)
	map.update(0)
	game.levels=Graph.CAPS.duplicate()
	map.update(0)
	check(before==var_to_bytes([map._positions,map._paths]),"Discovering and buying all recipes never reroutes or moves the map")
	var transformed=true
	for z in [map.MIN_ZOOM,1.0,map.MAX_ZOOM]:
		map.zoom=z
		map.pan=Vector2(137,-93)
		for node in nodes:
			transformed=transformed and map.point(node.x,node.y).is_equal_approx(map.center()+positions[node]*z)
	check(transformed,"Tile positions use the same pan and zoom transform as their rendered routes")

func _initialize():
	checker_contract()
	var game=Main.new()
	game.testing=true
	game.sound_on=false
	inspect_layout(game)
	game.free()
	print("UPGRADE_LAYOUT_METRICS ",JSON.stringify(report))
	print("UPGRADE_LAYOUT_QA_RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
