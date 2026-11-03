extends RefCounted
## Paths only: startup can enumerate these without synchronously loading audio.
const DIRECTORY = "res://data/audio/feedback/"
const SHARED = ["ui_tap","ui_back","ui_confirm","ui_error","upgrade","ability_purchase",
	"run_start","pause","resume","pickup_appear","time_pickup","prism","jam_splash","twin_transform",
	"tray_win","tray_loss","collect","special_split","special_impact","special_ricochet","countdown"]
const MATERIAL = ["launch","peg_hit","peg_break","cup_catch"]
const AREAS = ["bakery","gelato","crystal"]

static func resource_paths() -> Array[String]:
	var paths: Array[String]=[]
	for name in SHARED: paths.append(DIRECTORY+name+".wav")
	for area in AREAS:
		for name in MATERIAL: paths.append(DIRECTORY+area+"_"+name+".wav")
	return paths
