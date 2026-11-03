extends SceneTree
## Exercises the real playback path with Dummy audio; never loads player data.
var passed = 0
var failures: Array[String] = []

class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): assert(false, "Audio QA cannot load a profile")
	func save_game(): assert(false, "Audio QA cannot save a profile"); return false

func check(ok: bool, label: String):
	if ok: passed += 1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ", label)

func _initialize():
	call_deferred("run_checks")

func run_checks():
	var g = Fixture.new()
	g.testing = true; g.sound_on = true
	g.first_run_guide.active = false; g.first_run_guide.completed = true
	g.set_active_area("crystal")
	g.start_shift(); g.run_transition.finish()
	g.setup_audio()
	g.remove_child(g.synth); root.add_child(g.synth)
	var bank = g.tone_bank
	var cue = bank.stream_for(950, .08)
	var streams = bank.generated_stream_count
	var pcm = bank.pcm_bytes
	check(cue != null and cue.data.size() == 3528, "Crystal's shared pickup cue has prewarmed PCM")
	check(streams == 31 and pcm == 53346, "Shared cue keeps the original bounded bank allocation")
	check(bank.stream_for(1040, .08) == null, "The old unsupported Prism pitch remains an unsupported request")
	g.spawn_ball(Vector2(360, 400), "normal", Vector2.DOWN)
	g.run_elapsed = 3.0; g.crystal_launcher.advance(0)
	g.testing = false; g.sound_cooldown = 0
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position), "Actual Prism collection succeeds with testing disabled")
	check(g.synth.stream == cue and g.synth.playing, "Prism collection sends the cached pickup stream to the real AudioStreamPlayer")
	check(is_equal_approx(g.sound_cooldown, .055), "Crystal pickup preserves the existing 55ms audio gate")
	check(g.balls.size() == 2 and g.crystal_run.collected == 1, "Audio fix retains once-only live-ball duplication")
	check(not g.crystal_launcher.try_collect(g.crystal_run.offer_position), "Repeated collection does not replay the consumed pickup")
	g.synth.stop(); g.synth.stream = null
	g.crystal_second_prism = true
	g.run_elapsed = 7.5; g.crystal_launcher.advance(0)
	g.sound_on = false; g.sound_cooldown = 0
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position), "Muted pickup still completes its gameplay action")
	check(g.synth.stream == null and not g.synth.playing and g.sound_cooldown == 0, "Sound off prevents playback and stream replacement through the real Prism path")
	g.sound_on = true; g.sound_cooldown = 0
	for _index in range(64):
		g.sound_cooldown = 0
		g.tone(950, .08)
	check(g.synth.stream == cue and bank.generated_stream_count == streams and bank.pcm_bytes == pcm, "Repeated runtime pickup requests reuse one stream with no PCM synthesis/allocation")
	g.synth.stop(); g.synth.free(); g.free()
	await process_frame
	await process_frame
	print("CRYSTAL_AUDIO_PATH_QA_RESULT passed=%d failed=%d" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)
