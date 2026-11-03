extends RefCounted
## Two finished campaign runs per area, independent of purchases and wallets.
## Optional save metadata: bad history never invalidates campaign progression.
const VERSION = 1
const AREAS = ["bakery","gelato","crystal"]
var areas: Dictionary = {}

func reset():
	areas.clear()

static func _number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func _integer(value, low: int, high: int) -> bool:
	return _number(value,low,high) and float(value) == floorf(float(value))

static func _valid_record(value) -> bool:
	if not value is Dictionary: return false
	if not value.get("run_id") is String or value.run_id.is_empty() or value.run_id.length() > 128: return false
	if not _number(value.get("coins"),0,10000000): return false
	if absf(float(value.coins)*100-roundf(float(value.coins)*100)) > .00001: return false
	if not _integer(value.get("peg_total"),1,48): return false
	return _integer(value.get("destroyed"),0,int(value.peg_total)) and _integer(value.get("combo"),0,48) and _integer(value.get("wave"),1,12)

static func _record(value: Dictionary) -> Dictionary:
	return {"run_id":value.run_id,"coins":roundf(float(value.coins)*100)/100,
		"destroyed":int(value.destroyed),"peg_total":int(value.peg_total),
		"combo":int(value.combo),"wave":int(value.wave)}

func export_state() -> Dictionary:
	return {"version":VERSION,"areas":areas.duplicate(true)}

func import_state(value):
	reset()
	if not value is Dictionary or not _integer(value.get("version"),VERSION,VERSION) or not value.get("areas") is Dictionary: return
	for area_id in AREAS:
		var bucket = value.areas.get(area_id,{})
		if not bucket is Dictionary or not _valid_record(bucket.get("latest")): continue
		var latest = _record(bucket.latest)
		var previous: Dictionary = {}
		if _valid_record(bucket.get("previous")) and bucket.previous.run_id != latest.run_id:
			previous = _record(bucket.previous)
		areas[area_id] = {"latest":latest,"previous":previous}

func record_run(area_id: String, value: Dictionary) -> bool:
	if area_id not in AREAS or not _valid_record(value): return false
	var latest: Dictionary = areas.get(area_id,{}).get("latest",{})
	# Reloads, extra saves and repeat collection cannot roll the baseline twice.
	if latest.get("run_id","") == value.run_id: return false
	areas[area_id] = {"latest":_record(value),"previous":latest.duplicate(true)}
	return true

func comparison(area_id: String, current: Dictionary) -> Dictionary:
	var bucket: Dictionary = areas.get(area_id,{})
	var latest: Dictionary = bucket.get("latest",{})
	var previous: Dictionary = bucket.get("previous",{}) if latest.get("run_id","") == current.get("run_id","") else latest
	var result = {"current":current.duplicate(true),"previous":previous.duplicate(true),"direction":"first","percent_text":""}
	if previous.is_empty(): return result
	var now_cents = roundi(float(current.coins)*100)
	var old_cents = roundi(float(previous.coins)*100)
	var change = now_cents-old_cents
	if change == 0:
		result.direction = "same"
		result.percent_text = "0%"
	elif old_cents == 0:
		result.direction = "from_zero"
	else:
		result.direction = "up" if change > 0 else "down"
		var percentage = absf(float(change))*100.0/float(old_cents)
		if percentage < .1:
			result.percent_text = "<0.1%"
		else:
			var tenths = roundi(percentage*10)
			result.percent_text = (str(int(tenths/10)) if tenths%10 == 0 else "%d.%d" % [int(tenths/10),tenths%10])+"%"
	return result
