extends SceneTree
## Cached-playback CPU proxy; no runtime PCM synthesis or profile discovery.
const Game=preload("res://scripts/main.gd")
const Audio=preload("res://scripts/game_audio.gd")
var passed=0
var failed: Array[String]=[]
func _initialize():
	if OS.get_environment("PEG_AUDIO_BANK_OUTPUT").is_empty():
		print("AUDIO_CACHE_QA_REFUSED: use the isolated Windows runner");quit(2);return
	call_deferred("run_tests")
func check(ok: bool,label: String):
	if ok: passed+=1
	else: failed.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func run_tests():
	var g=Game.new()
	g.testing=false;g.sound_on=true;g.profile_initialization_complete=true
	# Attach only audio: Game._ready would load a profile and is never called.
	g.setup_audio();g.remove_child(g.game_audio);root.add_child(g.game_audio)
	var bank=g.game_audio
	check(bank.prepared_stream_count==33 and bank.pcm_bytes==441600,"Production prewarm has exactly 33 streams and 441,600 PCM bytes")
	check(bank.get_child_count()==6,"Production audio owns exactly six persistent voices")
	var identities={}
	for area in ["bakery","gelato","crystal"]:
		for event in Audio.EVENTS:
			var stream=Audio.stream_for(event,area)
			check(stream!=null and stream==Audio.stream_for(event,area),"Repeated lookup reuses resource identity: "+area+"/"+event)
			identities[stream.get_instance_id()]=true
	check(identities.size()==33,"Three material palettes and shared cues resolve to 33 unique resources")
	var voice_ids=[]
	for voice in bank._voices: voice_ids.append(voice.get_instance_id())
	var before_rng=str(g.rng.state)
	var samples=[]
	for index in range(2000):
		var started=Time.get_ticks_usec()
		Audio.stream_for("peg_hit","bakery")
		samples.append(Time.get_ticks_usec()-started)
	for index in range(40):
		bank.advance(.06);g.tone(300,.025)
		await create_timer(.06).timeout
	check(str(g.rng.state)==before_rng,"Compatibility playback consumes no gameplay RNG")
	var stable=true
	for index in range(6): stable=stable and bank._voices[index].get_instance_id()==voice_ids[index]
	check(stable and bank.prepared_stream_count==33 and bank.pcm_bytes==441600,"2,000 lookups and 40 paced hits reuse the fixed streams, PCM buffers and players")
	check(bank.active_voice_count()<=6 and bank.active_gameplay_count()<=3,"Stress stays inside polyphony caps")
	var accepted=bank.accepted_events
	g.sound_on=false;bank.advance(1);g.tone(720,.08)
	check(bank.accepted_events==accepted,"Sound off blocks production compatibility playback")
	g.sound_on=true;g.testing=true;g.tone(720,.08)
	check(bank.accepted_events==accepted,"Testing mode blocks production playback")
	g.testing=false
	for spec in [[100,.025],[340.01,.025],[720,.1],[NAN,.025],[720,INF]]: g.tone(spec[0],spec[1])
	check(bank.accepted_events==accepted and Audio.stream_for("unknown")==null,"Unsupported requests remain silent without synthesis")
	bank.stop_all();g.tone(720,.08)
	var has_upgrade=false
	for voice in bank._voices: has_upgrade=has_upgrade or (voice.playing and voice.stream==Audio.stream_for("upgrade"))
	check(has_upgrade,"Legacy purchase cue maps to the new cached upgrade resource")
	samples.sort()
	var report={"passed":passed,"failed":failed,"metadata":{"engine":Engine.get_version_info().string,"scope":"Headless cached-lookup CPU proxy and 40 paced playback requests, not phone FPS or human listening","source_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"pcm_bytes":bank.pcm_bytes,"streams":bank.prepared_stream_count,"voices":6,"gameplay_voices":3,"profile_io":0},"cached_lookup_microseconds":{"samples":samples.size(),"p50":samples[1000],"p95":samples[1900],"maximum":samples[-1]}}
	var file=FileAccess.open(OS.get_environment("PEG_AUDIO_BANK_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	bank.stop_all();await create_timer(.15).timeout
	bank.free();g.game_audio=null;g.free()
	await process_frame;await process_frame
	print("AUDIO_CACHE_QA_RESULT passed=%d failed=%d pcm_bytes=441600"%[passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
