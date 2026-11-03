extends Node
## Original offline WAVs, cached once. Playback never synthesizes or creates a voice.
## The host advances cooldown time and owns foreground/settings lifecycle.
const VOICE_LIMIT = 6
const GAMEPLAY_VOICE_LIMIT = 3
const MASTER_DB = -6.0
const GAMEPLAY = 0
const UI = 1
const REWARD = 2
const SHARED = {
	"ui_tap":preload("res://data/audio/feedback/ui_tap.wav"),
	"ui_back":preload("res://data/audio/feedback/ui_back.wav"),
	"ui_confirm":preload("res://data/audio/feedback/ui_confirm.wav"),
	"ui_error":preload("res://data/audio/feedback/ui_error.wav"),
	"upgrade":preload("res://data/audio/feedback/upgrade.wav"),
	"ability_purchase":preload("res://data/audio/feedback/ability_purchase.wav"),
	"run_start":preload("res://data/audio/feedback/run_start.wav"),
	"pause":preload("res://data/audio/feedback/pause.wav"),
	"resume":preload("res://data/audio/feedback/resume.wav"),
	"pickup_appear":preload("res://data/audio/feedback/pickup_appear.wav"),
	"time_pickup":preload("res://data/audio/feedback/time_pickup.wav"),
	"prism":preload("res://data/audio/feedback/prism.wav"),
	"jam_splash":preload("res://data/audio/feedback/jam_splash.wav"),
	"twin_transform":preload("res://data/audio/feedback/twin_transform.wav"),
	"tray_win":preload("res://data/audio/feedback/tray_win.wav"),
	"tray_loss":preload("res://data/audio/feedback/tray_loss.wav"),
	"collect":preload("res://data/audio/feedback/collect.wav"),
	"special_split":preload("res://data/audio/feedback/special_split.wav"),
	"special_impact":preload("res://data/audio/feedback/special_impact.wav"),
	"special_ricochet":preload("res://data/audio/feedback/special_ricochet.wav"),
	"countdown":preload("res://data/audio/feedback/countdown.wav")}
const MATERIAL = {
	"bakery":{
		"launch":preload("res://data/audio/feedback/bakery_launch.wav"),
		"peg_hit":preload("res://data/audio/feedback/bakery_peg_hit.wav"),
		"peg_break":preload("res://data/audio/feedback/bakery_peg_break.wav"),
		"cup_catch":preload("res://data/audio/feedback/bakery_cup_catch.wav")},
	"gelato":{
		"launch":preload("res://data/audio/feedback/gelato_launch.wav"),
		"peg_hit":preload("res://data/audio/feedback/gelato_peg_hit.wav"),
		"peg_break":preload("res://data/audio/feedback/gelato_peg_break.wav"),
		"cup_catch":preload("res://data/audio/feedback/gelato_cup_catch.wav")},
	"crystal":{
		"launch":preload("res://data/audio/feedback/crystal_launch.wav"),
		"peg_hit":preload("res://data/audio/feedback/crystal_peg_hit.wav"),
		"peg_break":preload("res://data/audio/feedback/crystal_peg_break.wav"),
		"cup_catch":preload("res://data/audio/feedback/crystal_cup_catch.wav")}}
# cooldown seconds, priority, gain dB, category. Six voices leave room above
# the three-voice gameplay cap for player decisions and earned rewards.
const EVENTS = {
	"ui_tap":[.07,4,-5.0,UI], "ui_back":[.12,4,-4.0,UI],
	"ui_confirm":[.12,4,-3.0,UI], "ui_error":[.25,4,-5.0,UI],
	"upgrade":[.16,5,-2.0,REWARD], "ability_purchase":[.35,6,-1.0,REWARD],
	"run_start":[.30,5,-3.0,UI], "pause":[.20,7,-4.0,UI], "resume":[.20,7,-4.0,UI],
	"launch":[.14,0,-11.0,GAMEPLAY], "peg_hit":[.055,1,-7.0,GAMEPLAY],
	"peg_break":[.08,2,-5.0,GAMEPLAY], "cup_catch":[.12,1,-6.0,GAMEPLAY],
	"pickup_appear":[.60,2,-9.0,REWARD], "time_pickup":[.18,5,-2.0,REWARD], "prism":[.30,6,-1.0,REWARD],
	"jam_splash":[.16,4,-4.0,GAMEPLAY], "twin_transform":[.40,6,-1.0,REWARD],
	"tray_win":[.50,8,-1.0,REWARD], "tray_loss":[.50,8,-3.0,REWARD],
	"collect":[.30,6,-2.0,REWARD], "special_split":[.14,3,-5.0,GAMEPLAY],
	"special_impact":[.12,3,-4.0,GAMEPLAY], "special_ricochet":[.14,2,-6.0,GAMEPLAY],
	"countdown":[.80,3,-5.0,UI]}

var enabled = true
var suspended = false
var prepared = false
var accepted_events = 0
var prepared_stream_count = 0
var pcm_bytes = 0
var _clock = 0.0
var _last: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _priorities = PackedInt32Array()
var _categories = PackedInt32Array()
var _started = PackedFloat64Array()

static func resource_paths() -> Array[String]:
	return preload("res://scripts/audio_catalog.gd").resource_paths()

static func stream_for(event: String, area: String = "bakery") -> AudioStreamWAV:
	if not EVENTS.has(event): return null
	if SHARED.has(event): return SHARED[event]
	return MATERIAL.get(area,MATERIAL.bakery).get(event,null)

func _ready(): prepare()

func prepare():
	if prepared: return
	for event in EVENTS: _last[event]=-1000.0
	_priorities.resize(VOICE_LIMIT); _categories.resize(VOICE_LIMIT); _started.resize(VOICE_LIMIT)
	for index in range(VOICE_LIMIT):
		var voice=AudioStreamPlayer.new()
		voice.name="FeedbackVoice%d"%index
		voice.max_polyphony=1
		add_child(voice)
		_voices.append(voice)
		_priorities[index]=-1; _categories[index]=-1
	for stream in SHARED.values():
		prepared_stream_count+=1; pcm_bytes+=stream.data.size()
	for bank in MATERIAL.values():
		for stream in bank.values():
			prepared_stream_count+=1; pcm_bytes+=stream.data.size()
	prepared=true

func set_enabled(value: bool):
	enabled=value
	if not enabled: stop_all()

func set_suspended(value: bool):
	suspended=value
	if suspended: stop_all()

func advance(delta: float):
	if not is_finite(delta) or delta<=0.0 or suspended: return
	_clock+=minf(delta,1.0)

func stop_all():
	for index in range(_voices.size()):
		_voices[index].stop()
		_priorities[index]=-1; _categories[index]=-1
	for event in _last: _last[event]=-1000.0

func stop_gameplay():
	for index in range(_voices.size()):
		if _categories[index]==GAMEPLAY:
			_voices[index].stop(); _priorities[index]=-1; _categories[index]=-1

func active_voice_count() -> int:
	var count=0
	for voice in _voices:
		if voice.playing: count+=1
	return count

func active_gameplay_count() -> int:
	var count=0
	for index in range(_voices.size()):
		if _voices[index].playing and _categories[index]==GAMEPLAY: count+=1
	return count

func _voice_for(priority: int, category: int) -> int:
	var gameplay_full=category==GAMEPLAY and active_gameplay_count()>=GAMEPLAY_VOICE_LIMIT
	var candidate=-1
	for index in range(_voices.size()):
		if not _voices[index].playing and not gameplay_full: return index
		if not _voices[index].playing or (gameplay_full and _categories[index]!=GAMEPLAY): continue
		if _priorities[index]>priority: continue
		if candidate<0 or _priorities[index]<_priorities[candidate] or (_priorities[index]==_priorities[candidate] and _started[index]<_started[candidate]): candidate=index
	return candidate

func play_event(event: String, area: String = "bakery", options: Dictionary = {}) -> bool:
	if not prepared or not enabled or suspended or not is_inside_tree() or not EVENTS.has(event): return false
	var spec: Array=EVENTS[event]
	if _clock-float(_last[event])<float(spec[0]): return false
	var stream=stream_for(event,area)
	if stream==null: return false
	var index=_voice_for(int(spec[1]),int(spec[3]))
	if index<0: return false
	var intensity=_number(options.get("intensity",1.0),0.0,1.0,1.0)
	var pitch=_number(options.get("pitch",1.0),.9,1.1,1.0)
	var voice=_voices[index]
	voice.stop()
	voice.stream=stream
	voice.pitch_scale=pitch
	voice.volume_db=MASTER_DB+float(spec[2])+lerpf(-6.0,0.0,intensity)
	_priorities[index]=int(spec[1]); _categories[index]=int(spec[3]); _started[index]=_clock
	_last[event]=_clock
	voice.play()
	accepted_events+=1
	return true

static func _number(value: Variant, minimum: float, maximum: float, fallback: float) -> float:
	return clampf(float(value),minimum,maximum) if (value is int or value is float) and is_finite(float(value)) else fallback
