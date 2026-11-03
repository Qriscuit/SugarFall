extends RefCounted
## Presentation only: a displayed-second decrease starts one growth/twist beat.
## Active run time settles it; bonuses never rewind it. State is intentionally
## unsaved and reconstructed at the current remaining fraction after a restart.
const URGENT_SECONDS = 3.0
const NORMAL_INK = Color("443b32")
const URGENT_INK = Color("b31e36")
const SOFT_INK = Color("aa626e")
const BADGE_FACE = Color("ffe4df")
const BADGE_EDGE = Color("ce5264")
const SOFT_BADGE_EDGE = Color("d49ca5")
const NORMAL_FONT_SIZE = 31
const URGENT_FONT_SIZE = 56
const MAX_FONT_SIZE = 84
const SETTLE_SECONDS = .48
const FADE_SECONDS = .95
const TICK_ANGLES = {3:-6.0,2:10.0,1:-14.0}

var _initialized = false
var _run_key = ""
var _last_elapsed = 0.0
var _last_tick = 0
var _beat_running = false
var _beat_started = 0.0

func reset():
	_initialized = false
	_run_key = ""
	_last_elapsed = 0.0
	_last_tick = 0
	_beat_running = false
	_beat_started = 0.0

func presentation(seconds: float, active_elapsed: float, reduced_motion: bool, clear_draining: bool = false, run_key: String = "") -> Dictionary:
	var safe_seconds = maxf(0.0,seconds) if is_finite(seconds) else 0.0
	var safe_elapsed = maxf(0.0,active_elapsed) if is_finite(active_elapsed) else 0.0
	var whole_seconds = ceili(safe_seconds)
	var urgent = safe_seconds > 0.0 and safe_seconds <= URGENT_SECONDS and not clear_draining
	if _initialized and (run_key != _run_key or safe_elapsed < _last_elapsed): reset()
	if not _initialized or whole_seconds < _last_tick:
		# If rendering missed the integer boundary, begin at its current phase.
		# A resumed mid-second timer therefore does not replay a full-size pop.
		_beat_running = urgent
		_beat_started = safe_elapsed-clampf(float(whole_seconds)-safe_seconds,0.0,1.0)
	elif whole_seconds > _last_tick:
		# More time is good news: changing upward never performs an urgent beat.
		_beat_running = false
	if not urgent: _beat_running = false
	_initialized = true
	_run_key = run_key
	_last_elapsed = safe_elapsed
	_last_tick = whole_seconds
	var state = {
		"urgent":urgent,
		"label":"%ds" % whole_seconds if urgent else "%02d:%02d" % [whole_seconds/60,whole_seconds%60],
		"font_size":URGENT_FONT_SIZE if urgent else NORMAL_FONT_SIZE,
		"offset":Vector2.ZERO,
		"rotation":0.0,
		"color":SOFT_INK if urgent else NORMAL_INK,
		"badge_face":BADGE_FACE,
		"badge_edge":SOFT_BADGE_EDGE,
		"icon_tint":Color("d69ba4") if urgent else Color.WHITE,
		"age":0.0,
		"beat":0.0
	}
	if not urgent or reduced_motion or not _beat_running: return state
	var age = maxf(0.0,safe_elapsed-_beat_started)
	var beat = 1.0-smoothstep(0.0,SETTLE_SECONDS,age)
	var fade = smoothstep(0.0,FADE_SECONDS,age)
	state.age = age
	state.beat = beat
	state.font_size = URGENT_FONT_SIZE+roundi((MAX_FONT_SIZE-URGENT_FONT_SIZE)*beat)
	state.rotation = deg_to_rad(TICK_ANGLES[whole_seconds])*beat
	state.color = URGENT_INK.lerp(SOFT_INK,fade)
	state.badge_edge = BADGE_EDGE.lerp(SOFT_BADGE_EDGE,fade)
	state.icon_tint = Color("d65d6b").lerp(Color("d69ba4"),fade)
	return state
