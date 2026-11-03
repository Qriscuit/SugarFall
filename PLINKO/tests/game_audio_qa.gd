extends SceneTree
## Actual Godot mixing through Dummy output; no player profiles or device claims.
const Audio = preload("res://scripts/game_audio.gd")
var passed=0
var failures: Array[String]=[]
var capture: AudioEffectCapture
var recordings=PackedVector2Array()
var clip_results: Array[Dictionary]=[]

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func take() -> PackedVector2Array: return capture.get_buffer(capture.get_frames_available())
func peak(frames: PackedVector2Array) -> float:
	var value=0.0
	for frame in frames: value=maxf(value,maxf(absf(frame.x),absf(frame.y)))
	return value

func _initialize(): call_deferred("run")

func run():
	var output=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output=argument.trim_prefix("--output-dir=")
	if not output.is_absolute_path(): print("AUDIO_QA needs an isolated output directory"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	AudioServer.add_bus(); var bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"Feedback QA")
	capture=AudioEffectCapture.new(); capture.buffer_length=3.0
	AudioServer.add_bus_effect(bus,capture)
	var audio=Audio.new(); audio.set_enabled(false); root.add_child(audio)
	for voice in audio._voices: voice.bus="Feedback QA"
	check(audio.prepared and audio.get_child_count()==6 and audio.prepared_stream_count==33 and audio.pcm_bytes==441600,"One-time bank contains 33 original cached clips and six persistent voices")
	check(Audio.resource_paths().size()==33 and Audio.EVENTS.size()==25,"String-only startup catalog covers all 25 events and 33 sound assets")
	var source=FileAccess.get_file_as_string("res://scripts/audio_catalog.gd")
	check(not "preload(" in source and not "load(" in source,"Startup catalog creates no synchronous asset loads")
	var voices=[]
	for voice in audio._voices: voices.append(voice.get_instance_id())
	audio.prepare()
	check(audio.get_child_count()==6 and audio.prepared_stream_count==33,"Repeated prepare does not allocate another bank or voice")
	check(not audio.play_event("ui_tap"),"Saved Sound off blocks playback before the first voice")
	await create_timer(.08).timeout
	check(peak(take())<.0001,"Initial muted mixer is silent")
	audio.set_enabled(true)
	check(audio.play_event("peg_hit","bakery") and not audio.play_event("peg_hit","bakery"),"Contact storm obeys a shared 55ms hit cooldown")
	audio.advance(.055)
	check(audio.play_event("peg_hit","bakery"),"Hit cooldown expires without queued or delayed playback")
	check(not audio.play_event("not_an_event"),"Unknown events stay silent")
	check(Audio.stream_for("peg_hit","unknown")==Audio.stream_for("peg_hit","bakery"),"Unknown areas use the stable Bakery fallback")
	audio.stop_all()
	for event in ["launch","peg_hit","peg_break","cup_catch","special_split","jam_splash"]: audio.play_event(event)
	check(audio.active_gameplay_count()<=3 and audio.active_voice_count()<=3,"Frequent gameplay cues cannot occupy the three reserved reward/UI slots")
	check(audio.play_event("prism") and audio.play_event("upgrade") and audio.play_event("ui_tap") and audio.active_voice_count()==6,"Prism, purchase and UI cues coexist with a saturated board")
	audio.stop_gameplay()
	check(audio.active_gameplay_count()==0 and audio.active_voice_count()==3,"Stopping gameplay tails preserves committed reward and UI sounds")
	audio.stop_all()
	for event in ["ability_purchase","prism","twin_transform","tray_win","tray_loss","collect"]: audio.play_event(event)
	check(audio.active_voice_count()==6 and not audio.play_event("peg_hit"),"Six important cues cannot be stolen by a low-priority impact")
	await create_timer(.22).timeout
	var burst=take()
	check(peak(burst)>.01 and peak(burst)<.85,"Actual overlapping reward mix remains audible with peak headroom")
	recordings.append_array(burst)
	audio.set_suspended(true)
	var accepted=audio.accepted_events
	check(audio.active_voice_count()==0 and not audio.play_event("tray_win"),"Backgrounding stops every voice and rejects incoming events")
	await create_timer(.10).timeout; take()
	await create_timer(.10).timeout
	check(peak(take())<.0001,"Background stop reaches actual mixer silence")
	audio.set_suspended(false); audio.advance(.5)
	await create_timer(.10).timeout
	check(peak(take())<.0001 and audio.accepted_events==accepted,"Foreground does not replay stale events")
	for area in ["bakery","gelato","crystal"]:
		for event in ["launch","peg_hit","peg_break","cup_catch"]:
			await record_clip(audio,event,area)
	for event in Audio.SHARED:
		await record_clip(audio,event,"bakery")
	audio.stop_all()
	check(audio.play_event("ui_tap","bakery",{"pitch":INF,"intensity":NAN}),"Nonfinite option values use safe audible defaults")
	var playing: AudioStreamPlayer=null
	for voice in audio._voices:
		if voice.playing: playing=voice
	check(playing!=null and playing.pitch_scale==1.0 and is_finite(playing.volume_db),"Invalid options never reach mixer pitch or gain")
	audio.set_enabled(false)
	check(audio.active_voice_count()==0 and not audio.play_event("collect"),"Sound off immediately stops existing tails and future playback")
	await create_timer(.10).timeout; take()
	await create_timer(.10).timeout
	check(peak(take())<.0001,"Sound off produces actual mixer silence")
	audio.set_enabled(true)
	for iteration in range(1000):
		audio.advance(.1); audio.play_event("peg_hit","gelato")
	var same_voices=true
	for index in range(6): same_voices=same_voices and voices[index]==audio._voices[index].get_instance_id()
	check(same_voices and audio.prepared_stream_count==33 and audio.pcm_bytes==441600 and audio.get_child_count()==6,"A thousand impacts reuse the same six voices and original PCM bank")
	audio.stop_all()
	var pcm=PackedByteArray(); pcm.resize(recordings.size()*4)
	for index in range(recordings.size()):
		pcm.encode_s16(index*4,roundi(clampf(recordings[index].x,-1,1)*32767))
		pcm.encode_s16(index*4+2,roundi(clampf(recordings[index].y,-1,1)*32767))
	var recording=AudioStreamWAV.new(); recording.format=AudioStreamWAV.FORMAT_16_BITS; recording.stereo=true
	recording.mix_rate=roundi(AudioServer.get_mix_rate()); recording.data=pcm
	check(recording.save_to_wav(output.path_join("feedback-mixer.wav"))==OK,"Actual mixed cue reel is saved for later human listening")
	var demo=PackedVector2Array()
	var sequence=[["ui_tap","bakery"],["ui_back","bakery"],["upgrade","bakery"],
		["peg_hit","bakery"],["peg_break","bakery"],["peg_hit","gelato"],["peg_break","gelato"],
		["peg_hit","crystal"],["peg_break","crystal"],["time_pickup","bakery"],["jam_splash","bakery"],
		["prism","crystal"],["twin_transform","gelato"],["tray_win","bakery"],["collect","bakery"]]
	for cue in sequence:
		audio.stop_all(); await create_timer(.035).timeout; take()
		audio.play_event(cue[0],cue[1])
		await create_timer(Audio.stream_for(cue[0],cue[1]).get_length()+.08).timeout
		demo.append_array(take())
	pcm.resize(demo.size()*4)
	for index in range(demo.size()):
		pcm.encode_s16(index*4,roundi(clampf(demo[index].x,-1,1)*32767))
		pcm.encode_s16(index*4+2,roundi(clampf(demo[index].y,-1,1)*32767))
	recording.data=pcm
	check(recording.save_to_wav(output.path_join("feedback-demo.wav"))==OK,"Short UI/material/ability audition records the actual controller mix")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"clips":clip_results,"mixed_peak":peak(recordings),"mix_rate":AudioServer.get_mix_rate(),"pcm_bytes":audio.pcm_bytes,"voices":6,"gameplay_voice_limit":3,"demo_sequence":sequence,"demo_duration":float(demo.size())/AudioServer.get_mix_rate(),"human_listening_verified":false,"phone_verified":false,"profile_io":0}
	var file=FileAccess.open(output.path_join("audio-results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	audio.free(); await create_timer(.10).timeout; AudioServer.remove_bus(bus)
	print("GAME_AUDIO_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)

func record_clip(audio,event: String,area: String):
	audio.stop_all(); await create_timer(.035).timeout; take()
	var stream=Audio.stream_for(event,area)
	check(stream!=null and stream.mix_rate==24000 and not stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Cached PCM format: "+area+"/"+event)
	var started=audio.play_event(event,area)
	await create_timer(stream.get_length()+.055).timeout
	var frames=take();var maximum=peak(frames)
	check(started and maximum>.001 and maximum<.30,"Actual mixer output and conservative gain: "+area+"/"+event)
	recordings.append_array(frames)
	clip_results.append({"area":area,"event":event,"source":stream.resource_path,"peak":maximum,"captured_frames":frames.size()})
