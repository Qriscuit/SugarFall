extends SceneTree
## Real Godot mixer capture with Dummy output; no player profile discovery.
var passed=0
var failures: Array[String]=[]
var capture: AudioEffectCapture

func check(ok: bool,label: String):
	if ok: passed+=1
	else: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func take() -> PackedVector2Array:
	return capture.get_buffer(capture.get_frames_available())

func peak(frames: PackedVector2Array) -> float:
	var maximum=0.0
	for frame in frames: maximum=maxf(maximum,maxf(absf(frame.x),absf(frame.y)))
	return maximum

func _initialize(): call_deferred("run")

func run():
	var output=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output=argument.trim_prefix("--output-dir=")
	if not output.is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	AudioServer.add_bus(); var bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"Studio QA")
	capture=AudioEffectCapture.new(); capture.buffer_length=4.0
	AudioServer.add_bus_effect(bus,capture)
	var studio=load("res://startup.tscn").instantiate(); studio.testing=true; root.add_child(studio)
	studio.hum.bus="Studio QA"; studio.audio_preference_read=true; studio.sound_on=false
	studio._start_hum(); await create_timer(.2).timeout
	check(not studio.hum.playing and peak(take())==0,"Saved mute produces no mixer samples before first play")
	studio.sound_on=true; studio.heartbeat_elapsed=0; studio._start_hum()
	await create_timer(1.8).timeout
	var audible=take()
	check(audible.size()>AudioServer.get_mix_rate(),"Real audio mixer captures more than a second of the original hum")
	check(peak(audible)>.01 and peak(audible)<.30,"Hum is audible and leaves ample peak headroom at the chosen -7dB gain")
	var elapsed=studio.heartbeat_elapsed; studio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await create_timer(.15).timeout; take()
	await create_timer(.15).timeout
	check(peak(take())<.0001 and studio.heartbeat_elapsed==elapsed,"Background has silent mixer output and a frozen visual clock")
	studio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(.9).timeout
	check(peak(take())>.01 and studio.hum_start_count==1,"Foreground resumes the same audible voice without duplication")
	studio.heartbeat_elapsed=.14; studio._update_hum_volume(); studio._stop_hum(true)
	await create_timer(.18).timeout; take()
	await create_timer(.15).timeout
	check(not studio.hum.playing and not studio.hum_releasing and peak(take())<.0001,"Handoff release ends in actual mixer silence")
	var pcm=PackedByteArray(); pcm.resize(audible.size()*4)
	for i in range(audible.size()):
		pcm.encode_s16(i*4,roundi(clampf(audible[i].x,-1,1)*32767))
		pcm.encode_s16(i*4+2,roundi(clampf(audible[i].y,-1,1)*32767))
	var recording=AudioStreamWAV.new(); recording.format=AudioStreamWAV.FORMAT_16_BITS; recording.stereo=true
	recording.mix_rate=roundi(AudioServer.get_mix_rate()); recording.data=pcm
	check(recording.save_to_wav(output.path_join("studio-mixer.wav"))==OK,"Rendered hum saved for listening without synthesizing a substitute")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"captured_frames":audible.size(),"mix_rate":AudioServer.get_mix_rate(),"peak":peak(audible),"physical_listening":false}
	var file=FileAccess.open(output.path_join("audio-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	studio.free(); AudioServer.remove_bus(bus)
	print("STARTUP_AUDIO_QA_RESULT passed=%d failed=%d"%[passed,failures.size()])
	quit(0 if failures.is_empty() else 1)
