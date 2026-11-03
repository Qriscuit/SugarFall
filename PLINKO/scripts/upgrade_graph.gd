extends RefCounted
## Three independent mixed routes. Every non-root upgrade has one parent, and
## all tiers of a family stay on one route so count-based saves imply no joins.
const CAPS = [10,10,6,6,6,6,8,10]
const FEED = 0
const POWER = 1
const BOUNCE = 2
const RICOCHET = 3
const SPLIT = 4
const IMPACT = 5
const GOLD = 6
const TIME = 7
# Numeric family sequences are also read by tools/author_upgrade_arc.py.
# A: Bounce/Power/Impact. B: Time/Ricochet/Split. C: Gold/remaining Feed.
const ROUTE_FAMILIES = [
	[2,1,5,1,2,5,1,2,1,5,1,2,5,1,2,1,5,1,2,1,5,1],
	[7,3,7,4,3,7,4,7,3,7,4,3,7,4,7,3,4,7,3,7,4,7],
	[6,0,6,0,0,6,0,6,0,6,6,0,6,0,6,0,0]
]
static var _route_cache: Array = []
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
	# Stable topological order; the player may finish any route independently.
	for depth in range(longest):
		for route in _route_cache:
			if depth<route.size(): _node_cache.append(route[depth])

static func valid_node(i: int, n: int) -> bool:
	return i>=0 and i<CAPS.size() and n>=1 and n<=CAPS[i]

static func routes() -> Array:
	_ensure_graph()
	return _route_cache.duplicate(true)

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
	return valid_node(i,n) and levels.size()==CAPS.size() and levels[i]>=n

static func missing_prerequisites(levels: Array, i: int, n: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not valid_node(i,n) or levels.size()!=CAPS.size() or is_owned(levels,i,n): return result
	for dependency in prerequisites(i,n):
		if not is_owned(levels,dependency.x,dependency.y): result.append(dependency)
	# Irregular legacy profiles may have an owned route segment but an earlier
	# missing family tier. That fallback is an ancestor on the SAME route.
	# Only one prerequisite is reported; no second route creates an AND lock.
	if result.is_empty() and n>levels[i]+1: result.append(Vector2i(i,n-1))
	return result

static func is_unlocked(levels: Array, i: int, n: int) -> bool:
	if not valid_node(i,n) or levels.size()!=CAPS.size(): return false
	if is_owned(levels,i,n): return true
	return n==levels[i]+1 and missing_prerequisites(levels,i,n).is_empty()

static func is_visible(levels: Array, i: int, n: int) -> bool:
	# Keep owned upgrades and the next purchasable step on each route revealed.
	# Currency does not affect discovery; deeper route nodes stay hidden.
	return is_unlocked(levels,i,n)
