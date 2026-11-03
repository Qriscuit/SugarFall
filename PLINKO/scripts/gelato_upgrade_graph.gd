extends RefCounted
## Fixed mixed-family purchase slots. IDs retain the original family/ordinal
## pairs, but ordinals identify slots rather than an order of purchase.
## Area-local node ownership opens the drawn parent connection; aggregate
## family levels still control upgrade prices, effects and caps.
const CAPS = [10,10,6,6,6,6,8,10]
const FEED = 0
const POWER = 1
const BOUNCE = 2
const RICOCHET = 3
const SPLIT = 4
const IMPACT = 5
const GOLD = 6
const TIME = 7
const ROUTE_FAMILIES = [
	[1,0,2,1,6,1,7,0,1,5,1,1,3,7],
	[7,6,0,3,7,4,2,6,0,5,7,0,6,7]
]
# Forks at depths 3, 6 and 9. The apparent straight continuation ends after
# 4-6 upgrades; the visually branching child becomes the next growing stem.
const BRANCH_SPECS = [
	{"anchor":[2,1],"families":[1,4,2,6,0,3],"route_index":0,"parent_branch":-1},
	{"anchor":[1,3],"families":[5,7,4,2,6,0],"route_index":0,"parent_branch":-1},
	{"anchor":[1,4],"families":[3,1,5,7,4],"route_index":0,"parent_branch":-1},
	{"anchor":[0,4],"families":[2,6,0,3,1,5],"route_index":1,"parent_branch":-1},
	{"anchor":[4,1],"families":[7,4,6,2,0,5],"route_index":1,"parent_branch":-1},
	{"anchor":[0,5],"families":[1,3,7,4],"route_index":1,"parent_branch":-1}
]
static var _route_cache: Array = []
static var _branch_cache: Array = []
static var _node_cache: Array[Vector2i] = []
static var _parents: Dictionary = {}

static func _ensure_graph():
	if not _node_cache.is_empty(): return
	var counts = [1,0,0,0,0,0,0,0]
	var root = Vector2i(FEED,1)
	_node_cache.append(root)
	var longest = 0
	for families in ROUTE_FAMILIES:
		var route: Array[Vector2i] = []
		var parent = root
		for family in families:
			counts[family] += 1
			var node = Vector2i(family,counts[family])
			route.append(node)
			_parents[node] = parent
			parent = node
		_route_cache.append(route)
		longest = maxi(longest,route.size())
	for depth in range(longest):
		for route in _route_cache:
			if depth<route.size(): _node_cache.append(route[depth])
	for spec in BRANCH_SPECS:
		var branch: Array[Vector2i] = []
		var parent = Vector2i(spec.anchor[0],spec.anchor[1])
		for family in spec.families:
			counts[family] += 1
			var node = Vector2i(family,counts[family])
			branch.append(node)
			_parents[node] = parent
			_node_cache.append(node)
			parent = node
		_branch_cache.append(branch)

static func valid_node(i: int, n: int) -> bool:
	return i>=0 and i<CAPS.size() and n>=1 and n<=CAPS[i]

static func routes() -> Array:
	_ensure_graph()
	return _route_cache.duplicate(true)

static func branches() -> Array:
	_ensure_graph()
	return _branch_cache.duplicate(true)

static func nodes() -> Array[Vector2i]:
	_ensure_graph()
	return _node_cache.duplicate()

static func rank(i: int, n: int) -> int:
	_ensure_graph()
	return _node_cache.find(Vector2i(i,n))

static func prerequisites(i: int, n: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not valid_node(i,n): return result
	_ensure_graph()
	var node = Vector2i(i,n)
	if _parents.has(node): result.append(_parents[node])
	return result

static func is_owned(levels: Array, i: int, n: int) -> bool:
	# Legacy count-prefix adapter for old tooling. Active Gelato purchases use
	# main.shop_node_* with exact area-local node ownership instead.
	return valid_node(i,n) and levels.size()==CAPS.size() and levels[i]>=n

static func missing_prerequisites(levels: Array, i: int, n: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not valid_node(i,n) or levels.size()!=CAPS.size() or is_owned(levels,i,n): return result
	for dependency in prerequisites(i,n):
		if not is_owned(levels,dependency.x,dependency.y): result.append(dependency)
	# Count-only callers cannot represent shuffled slots; retain their historic
	# sequential-tier behavior without using this adapter for live purchases.
	if result.is_empty() and n>levels[i]+1: result.append(Vector2i(i,n-1))
	return result

static func is_unlocked(levels: Array, i: int, n: int) -> bool:
	if not valid_node(i,n) or levels.size()!=CAPS.size(): return false
	if is_owned(levels,i,n): return true
	return n==levels[i]+1 and missing_prerequisites(levels,i,n).is_empty()

static func is_visible(levels: Array, i: int, n: int) -> bool:
	# Ownership and immediate eligibility determine discovery, never currency.
	return is_unlocked(levels,i,n)
