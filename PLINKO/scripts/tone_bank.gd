extends RefCounted
## Prewarmed presentation-only sound bank. Contains no random-number calls.
## Save as res://scripts/tone_bank.gd and instantiate once before gameplay.
## Runtime stream_for() never synthesizes audio or creates another stream.
const SAMPLE_RATE = 22050
const HIT_STEP_HZ = 5
const HIT_MIN_HZ = 260
const HIT_MAX_HZ = 340
var _streams: Dictionary = {}
var pcm_bytes = 0
var generated_stream_count = 0

func _init():
	for frequency in range(HIT_MIN_HZ, HIT_MAX_HZ + 1, HIT_STEP_HZ):
		_prewarm(frequency, 0.025)
	for combo in range(11):
		_prewarm(520 + combo * 65, 0.045)
	_prewarm(950, 0.08) # Collected pickup.
	_prewarm(720, 0.08) # Purchased upgrade.
	_prewarm(130, 0.13) # Pulse.

func stream_for(frequency: float, duration: float = 0.045) -> AudioStreamWAV:
	var key = _lookup_key(frequency, duration)
	return _streams.get(key, null)

func _lookup_key(frequency: float, duration: float) -> int:
	if not is_finite(frequency) or not is_finite(duration): return -1
	if is_equal_approx(duration, 0.025):
		if frequency < HIT_MIN_HZ or frequency > HIT_MAX_HZ: return -1
		# Existing callers still draw the same random float. Only its audible pitch
		# is rounded to the nearest 5 Hz, changing it by at most 2.5 Hz.
		return 250000 + roundi(frequency / HIT_STEP_HZ) * HIT_STEP_HZ
	if is_equal_approx(duration, 0.045):
		var combo = roundi((frequency - 520.0) / 65.0)
		if combo < 0 or combo > 10 or not is_equal_approx(frequency, 520.0 + combo * 65.0): return -1
		return 450000 + 520 + combo * 65
	if is_equal_approx(duration, 0.08):
		if is_equal_approx(frequency, 950.0): return 800950
		if is_equal_approx(frequency, 720.0): return 800720
	if is_equal_approx(duration, 0.13) and is_equal_approx(frequency, 130.0): return 1300130
	# All production call sites are prewarmed above. Unsupported requests remain
	# silent rather than unexpectedly allocating or synthesizing during play.
	return -1

func _prewarm(frequency: int, duration: float):
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = SAMPLE_RATE
	var samples = int(SAMPLE_RATE * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var envelope = pow(1.0 - float(i) / samples, 2)
		var value = int(sin(float(i) / SAMPLE_RATE * TAU * frequency) * envelope * 11000)
		bytes.encode_s16(i * 2, value)
	audio.data = bytes
	_streams[_lookup_key(frequency, duration)] = audio
	pcm_bytes += bytes.size()
	generated_stream_count += 1
