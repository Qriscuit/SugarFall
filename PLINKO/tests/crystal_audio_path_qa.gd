extends SceneTree
## Real Prism-to-cached-player route; no player profile discovery.
const Audio=preload("res://scripts/game_audio.gd")
var passed=0
var failures: Array[String]=[]
class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func load_game(): assert(false,"Audio QA cannot load a profile")
	func save_game(): assert(false,"Audio QA cannot save a profile"); return false
func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func _initialize(): call_deferred("run_checks")
func run_checks():
	var g=Fixture.new()
	g.testing=true;g.sound_on=true;g.profile_initialization_complete=true
	g.first_run_guide.active=false;g.first_run_guide.completed=true
	g.set_active_area("crystal");g.start_shift();g.run_transition.finish()
	g.setup_audio();g.remove_child(g.game_audio);root.add_child(g.game_audio)
	var audio=g.game_audio
	var cue=Audio.stream_for("prism","crystal")
	check(cue!=null and cue.data.size()==24960,"Prism has its own original half-second cached chime")
	check(audio.prepared_stream_count==33 and audio.pcm_bytes==441600 and audio.get_child_count()==6,"Production setup uses the bounded shared/material bank and six fixed voices")
	g.spawn_ball(Vector2(360,400),"normal",Vector2.DOWN)
	g.run_elapsed=3.0;g.crystal_launcher.advance(0)
	audio.stop_all();g.testing=false
	var before=audio.accepted_events
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position),"Actual Prism collection succeeds with testing disabled")
	var playing=false
	for voice in audio._voices: playing=playing or (voice.playing and voice.stream==cue)
	check(playing and audio.accepted_events==before+1,"Real Prism path plays the exact cached Prism resource")
	check(g.balls.size()==2 and g.crystal_run.collected==1,"Audio retains once-only live-ball duplication")
	check(not g.crystal_launcher.try_collect(g.crystal_run.offer_position) and audio.accepted_events==before+1,"Consumed pickup cannot repeat its sound or grant")
	audio.stop_all();g.testing=true;g.start_shift();g.run_transition.finish()
	g.spawn_ball(Vector2(360,400),"normal",Vector2.DOWN)
	g.run_elapsed=3.0;g.crystal_launcher.advance(0)
	g.testing=false;g.sound_on=false;before=audio.accepted_events
	check(g.crystal_launcher.try_collect(g.crystal_run.offer_position),"Muted Prism still completes its gameplay action")
	check(audio.active_voice_count()==0 and audio.accepted_events==before,"Sound off blocks the actual Prism playback path")
	g.sound_on=true
	var rng_before=str(g.rng.state)
	for index in range(64): audio.advance(.31);g.feedback("prism")
	check(audio.prepared_stream_count==33 and audio.pcm_bytes==441600 and audio.get_child_count()==6,"Repeated feedback requests reuse the same cache and fixed voices")
	check(str(g.rng.state)==rng_before,"Feedback playback does not consume gameplay RNG")
	before=audio.accepted_events;g.testing=true;audio.advance(1);g.feedback("prism")
	check(audio.accepted_events==before,"Testing mode continues to suppress actual playback")
	audio.stop_all();await create_timer(.15).timeout
	audio.free();g.game_audio=null;g.free()
	await process_frame;await process_frame
	print("CRYSTAL_AUDIO_PATH_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
