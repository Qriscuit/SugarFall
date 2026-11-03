extends RefCounted
## Area-local progression only. Purchases, settings and lifetime identities live
## on the profile root; creating an area never resets the monetization service.
const IDS = ["bakery", "gelato", "crystal"]
const TITLES = {"bakery":"Bakery", "gelato":"Gelato Garden", "crystal":"Crystal Candyworks"}
const BOARD_PATHS = {"bakery":"res://data/board_design.json", "gelato":"res://data/gelato_board_design.json", "crystal":"res://data/crystal_board_design.json"}
const ECONOMY_PATHS = {"gelato":"res://data/gelato_economy.json", "crystal":"res://data/crystal_economy.json"}
const PREDECESSORS = {"gelato":"bakery", "crystal":"gelato"}
const ENTRY_COSTS = {"gelato":1000, "crystal":1500}
const SHOP_FIELDS = ["gelato_shop_revision", "gelato_owned_nodes", "gelato_reset_power_nodes"]
const GELATO_SHOP_REVISION = 1
const GelatoGraph = preload("res://scripts/gelato_upgrade_graph.gd")
const LOCAL_FIELDS = ["bank", "levels", "best_wave", "current_level", "highest_unlocked", "chapter_complete", "module_vouchers", "module_milestones", "equipped", "trial_records", "twin_launchers", "power_reset_tier", "gelato_shop_revision", "gelato_owned_nodes", "gelato_reset_power_nodes", "crystal_second_prism"]
# Revision 2 uses gravity-solved aim, exact free flight and no launcher jitter.
const LAUNCHER_RULES_REVISION = 2
# Power-scaled Impact changes practice completion times in both areas.
const COMBAT_RULES_REVISION = 1
const CAPS = [10,10,6,6,6,6,8,10]
const MODULES = ["ricochet", "splitter", "impact"]

static func default_record() -> Dictionary:
	return {"bank":0.0,"levels":[0,0,0,0,0,0,0,0],"best_wave":1,"current_level":1,"highest_unlocked":1,"chapter_complete":false,"module_vouchers":0,"module_milestones":[],"equipped":[],"trial_records":{},"twin_launchers":false,"power_reset_tier":0,"gelato_shop_revision":GELATO_SHOP_REVISION,"gelato_owned_nodes":[],"gelato_reset_power_nodes":[],"crystal_second_prism":false,"launcher_rules_revision":LAUNCHER_RULES_REVISION,"combat_rules_revision":COMBAT_RULES_REVISION}

static func predecessor(id: String) -> String:
	return PREDECESSORS.get(id,"")

static func next_area(id: String) -> String:
	for destination in IDS:
		if predecessor(destination)==id: return destination
	return ""

static func entry_cost(id: String) -> int:
	return int(ENTRY_COSTS.get(id,0))

static func capture_local(game) -> Dictionary:
	if game.area_id=="gelato" and not game.trial_active: game.ensure_gelato_shop_state()
	var record = default_record()
	for key in LOCAL_FIELDS:
		var value = game.trial_snapshot.get(key,game.get(key)) if game.trial_active and key!="trial_records" else game.get(key)
		record[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	record.bank = game.round_credits(record.bank)
	return record

static func apply_local(game, record: Dictionary):
	record = normalized(record,game.area_id)
	for key in LOCAL_FIELDS:
		var value = record.get(key,false) if key=="twin_launchers" else (record.get(key,0) if key=="power_reset_tier" else record[key])
		game.set(key,value.duplicate(true) if value is Array or value is Dictionary else value)
	game.force_special = ""

static func valid_record(record, area_id: String = "bakery") -> bool:
	if not record is Dictionary: return false
	for key in LOCAL_FIELDS:
		if key not in ["twin_launchers","power_reset_tier","crystal_second_prism"] and key not in SHOP_FIELDS and not record.has(key): return false
	# Missing ownership is a pre-launcher save, never an implicit purchase.
	if not record.get("twin_launchers",false) is bool: return false
	if not record.get("crystal_second_prism",false) is bool: return false
	if area_id!="crystal" and record.get("crystal_second_prism",false): return false
	if not integer(record.get("power_reset_tier",0),0,CAPS[1]): return false
	if not record.get("twin_launchers",false) and record.get("power_reset_tier",0)!=0: return false
	if not number(record.bank,0,100000000) or absf(record.bank*100-roundf(record.bank*100))>.00001: return false
	if not record.levels is Array or record.levels.size()!=8: return false
	for i in range(8):
		if not integer(record.levels[i],0,CAPS[i]): return false
	var has_shop_state = false
	for key in SHOP_FIELDS:
		if record.has(key): has_shop_state = true
	if has_shop_state:
		for key in SHOP_FIELDS:
			if not record.has(key): return false
		if area_id=="gelato":
			if not valid_gelato_shop_state(record): return false
		elif not integer(record.gelato_shop_revision,GELATO_SHOP_REVISION,GELATO_SHOP_REVISION) or record.gelato_owned_nodes!=[] or record.gelato_reset_power_nodes!=[]:
			return false
	if not integer(record.best_wave,1,999) or not integer(record.current_level,1,12) or not integer(record.highest_unlocked,record.current_level,12): return false
	if not record.chapter_complete is bool or (record.chapter_complete and record.highest_unlocked!=12): return false
	if not integer(record.module_vouchers,0,3) or not record.module_milestones is Array: return false
	var seen = []
	for milestone in record.module_milestones:
		if not integer(milestone,2,8) or int(milestone) not in [2,5,8] or int(milestone) in seen: return false
		seen.append(int(milestone))
	if not record.equipped is Array or record.equipped.size()>(2 if record.highest_unlocked>=4 else 1): return false
	seen = []
	for kind in record.equipped:
		if not kind is String or kind not in MODULES or kind in seen or record.levels[MODULES.find(kind)+3]<=0: return false
		seen.append(kind)
	if not record.trial_records is Dictionary: return false
	for key in record.trial_records:
		if key not in ["4","8","12"] or not number(record.trial_records[key],.000001,120): return false
	return true

static func normalized(record: Dictionary, area_id: String = "bakery") -> Dictionary:
	var result = record.duplicate(true)
	result.twin_launchers = record.get("twin_launchers",false)
	result.crystal_second_prism = record.get("crystal_second_prism",false)
	result.power_reset_tier = int(record.get("power_reset_tier",0))
	# Changed combat/aim rules invalidate practice times, never campaign progress
	# or an already earned pending result.
	if not integer(record.get("combat_rules_revision"),COMBAT_RULES_REVISION,COMBAT_RULES_REVISION):
		result.trial_records = {}
	result.combat_rules_revision = COMBAT_RULES_REVISION
	if area_id=="gelato" and (not integer(record.get("launcher_rules_revision"),LAUNCHER_RULES_REVISION,LAUNCHER_RULES_REVISION)):
		result.trial_records = {}
	result.launcher_rules_revision = LAUNCHER_RULES_REVISION
	result.bank = roundf(float(record.bank)*100)/100
	for key in ["best_wave","current_level","highest_unlocked","module_vouchers"]: result[key]=int(result[key])
	for i in range(8): result.levels[i]=int(result.levels[i])
	for i in range(result.module_milestones.size()): result.module_milestones[i]=int(result.module_milestones[i])
	for key in result.trial_records: result.trial_records[key]=float(result.trial_records[key])
	if not result.has("gelato_shop_revision"):
		var shop = legacy_gelato_shop_state(result.levels,result.twin_launchers,result.power_reset_tier) if area_id=="gelato" else {"gelato_shop_revision":GELATO_SHOP_REVISION,"gelato_owned_nodes":[],"gelato_reset_power_nodes":[]}
		result.merge(shop,true)
	else:
		result.gelato_shop_revision=int(result.gelato_shop_revision)
		for key in ["gelato_owned_nodes","gelato_reset_power_nodes"]:
			for index in range(result[key].size()):
				result[key][index]=[int(result[key][index][0]),int(result[key][index][1])]
	return result

static func legacy_gelato_shop_state(levels: Array, twin: bool, reset_tier: int) -> Dictionary:
	var owned: Array = []
	var reset: Array = []
	for family in range(CAPS.size()):
		for ordinal in range(1,int(levels[family])+1): owned.append([family,ordinal])
	if twin:
		for ordinal in range(int(levels[1])+1,reset_tier+1): reset.append([1,ordinal])
	return {"gelato_shop_revision":GELATO_SHOP_REVISION,"gelato_owned_nodes":owned,"gelato_reset_power_nodes":reset}

static func valid_shop_nodes(value, power_only: bool = false) -> bool:
	if not value is Array or value.size()>62: return false
	var seen = {}
	for node in value:
		if not node is Array or node.size()!=2: return false
		if not integer(node[0],0,7) or not integer(node[1],1,10): return false
		var family=int(node[0]); var ordinal=int(node[1])
		if not GelatoGraph.valid_node(family,ordinal) or (power_only and family!=1): return false
		var key=Vector2i(family,ordinal)
		if seen.has(key): return false
		seen[key]=true
	return true

static func valid_gelato_shop_state(record: Dictionary) -> bool:
	if not integer(record.get("gelato_shop_revision"),GELATO_SHOP_REVISION,GELATO_SHOP_REVISION): return false
	var owned=record.get("gelato_owned_nodes")
	var reset=record.get("gelato_reset_power_nodes")
	if not valid_shop_nodes(owned) or not valid_shop_nodes(reset,true): return false
	if not record.get("levels") is Array or record.levels.size()!=CAPS.size(): return false
	if not record.get("twin_launchers",false) is bool or not integer(record.get("power_reset_tier",0),0,CAPS[1]): return false
	if not record.get("twin_launchers",false) and (not reset.is_empty() or record.get("power_reset_tier",0)!=0): return false
	if reset.size()>int(record.get("power_reset_tier",0)): return false
	var counts=[0,0,0,0,0,0,0,0]
	for node in owned: counts[int(node[0])]+=1
	for node in reset:
		if node in owned: return false
	# Every Power purchase present at the reset must still be represented by
	# either an active node or a rebuild node; later new slots may add more.
	if counts[1]+reset.size()<int(record.get("power_reset_tier",0)) or counts[1]+reset.size()>CAPS[1]: return false
	for family in range(CAPS.size()):
		if not integer(record.levels[family],0,CAPS[family]) or counts[family]!=int(record.levels[family]): return false
	return true

static func decode_profile(data: Dictionary) -> Dictionary:
	if not integer(data.get("version",3),3,5): return {"ok":false}
	if not data.get("areas") is Dictionary or not data.areas.has("bakery") or not data.get("active_area_id") is String:
		return {"ok":false}
	if data.active_area_id not in IDS or not data.areas.has(data.active_area_id): return {"ok":false}
	var records = {}
	for id in data.areas:
		if data.get("version",3)>=5 and (not data.areas[id] is Dictionary or not data.areas[id].has("crystal_second_prism")): return {"ok":false}
		if data.get("version",3)>=4:
			if not data.areas[id] is Dictionary: return {"ok":false}
			for key in SHOP_FIELDS:
				if not data.areas[id].has(key): return {"ok":false}
		if id not in IDS or not valid_record(data.areas[id],id): return {"ok":false}
		if id!="gelato" and data.areas[id].get("twin_launchers",false): return {"ok":false}
		records[id] = normalized(data.areas[id],id)
	var ledger = data.get("area_entries",[])
	if not ledger is Array or ledger.size()>IDS.size()-1: return {"ok":false}
	var destinations = []
	for entry in ledger:
		if not entry is Dictionary or not entry.get("destination") is String or not entry.get("source") is String: return {"ok":false}
		if predecessor(entry.destination)!=entry.source or entry.source.is_empty() or not records.has(entry.source) or not records.has(entry.destination) or entry.destination in destinations: return {"ok":false}
		if not integer(entry.get("cost"),1,100000000) or not entry.get("id") is String or entry.id.is_empty() or entry.id.length()>128: return {"ok":false}
		destinations.append(entry.destination)
	return {"ok":true,"area_id":data.active_area_id,"records":records,"ledger":ledger.duplicate(true)}

static func number(value, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value>=minimum and value<=maximum

static func integer(value, minimum: int, maximum: int) -> bool:
	return number(value,minimum,maximum) and float(value)==floorf(float(value))
