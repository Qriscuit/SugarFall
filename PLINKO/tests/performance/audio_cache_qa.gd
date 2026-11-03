extends SceneTree
const Game = preload("res://scripts/main.gd")
var Bank
var bank
var g
var passed=0
var failed=[]
var report={}
func _initialize():
	if OS.get_environment("PEG_AUDIO_BANK_SCRIPT").is_empty() or OS.get_environment("PEG_AUDIO_BANK_OUTPUT").is_empty():
		print("AUDIO_CACHE_QA_REFUSED: use run_audio_cache_tests.sh")
		quit(2); return
	Bank=load(OS.get_environment("PEG_AUDIO_BANK_SCRIPT"))
	call_deferred("run_tests")
func check(ok,label):
	if ok: passed+=1; print("PASS: ",label)
	else: failed.append(label); print("FAIL: ",label)
func run_tests():
	bank=Bank.new()
	g=Game.new()
	g.testing=false; g.sound_on=true
	# Initialize the production bank without attaching Game and triggering save loading.
	g.setup_audio()
	g.remove_child(g.synth); root.add_child(g.synth)
	check(g.tone_bank!=null,"Production audio setup initializes its tone bank")
	check(bank.generated_stream_count==31,"Prewarm creates exactly thirty-one bounded streams")
	check(bank.pcm_bytes==53346,"Prewarm PCM payload is exactly 53,346 bytes, excluding resource overhead")
	for combo in range(11): check_exact(520.0+combo*65.0,.045)
	check_exact(950,.08); check_exact(720,.08); check_exact(130,.13)
	var valid=true
	var max_error=0.0
	var identities={}
	var before_rng=str(g.rng.state)
	for i in range(8001):
		var frequency=260.0+float(i)/100.0
		var rounded=roundi(frequency/5.0)*5
		max_error=maxf(max_error,absf(frequency-rounded))
		var stream=bank.stream_for(frequency,.025)
		if stream==null or stream!=bank.stream_for(rounded,.025): valid=false
		else: identities[stream.get_instance_id()]=true
	check(valid and max_error<=2.50000001,"All 8,001 hit frequencies use nearest-five-Hz pitch within 2.5 Hz")
	check(identities.size()==17,"Entire hit-frequency range reuses exactly seventeen resource identities")
	check(str(g.rng.state)==before_rng,"Tone-bank construction and lookup consume no gameplay RNG")
	check(bank.generated_stream_count==31 and bank.pcm_bytes==53346,"Lookup creates no extra streams or PCM payload")
	var fixed=g.tone_bank.stream_for(650,.045)
	g.sound_cooldown=0; g.tone(650,.045)
	check(g.synth.stream==fixed and g.sound_cooldown==.055,"Cached playback reuses the stream and preserves the 55-ms gate")
	g.tone(720,.08)
	check(g.synth.stream==fixed,"A second tone during the gate cannot replace playback")
	g.sound_cooldown=0; g.sound_on=false; g.tone(720,.08)
	check(g.synth.stream==fixed,"Muted playback remains silent without replacing the stream")
	g.sound_on=true; g.testing=true; g.tone(720,.08)
	check(g.synth.stream==fixed,"Testing mode still suppresses sound")
	g.testing=false
	check(bank.stream_for(100,.025)==null and bank.stream_for(340.01,.025)==null and bank.stream_for(666,.045)==null and bank.stream_for(720,.1)==null and bank.stream_for(NAN,.025)==null,"Unsupported sound requests stay silent instead of synthesizing at runtime")
	report.metadata={"engine":Engine.get_version_info().string,"scope":"Headless CPU proxy with Dummy audio, not phone FPS or audible-quality validation","source_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"pcm_bytes":bank.pcm_bytes,"streams":bank.generated_stream_count,"hit_pitches":identities.size(),"maximum_hit_pitch_error_hz":max_error}
	measure("bank_prewarm_once",func(): Bank.new(),50,1,5)
	for spec in [[300.0,.025],[650.0,.045],[720.0,.08],[130.0,.13]]:
		var label="%03dms" % int(spec[1]*1000)
		measure("legacy_synthesis_"+label,func():
			g.sound_cooldown=0
			g.synth.stream=legacy_pcm(spec[0],spec[1])
			g.synth.play(),150,4,20)
		measure("production_cached_"+label,func():
			g.sound_cooldown=0
			g.tone(spec[0],spec[1]),150,4,20)
	report.passed=passed; report.failed=failed
	var f=FileAccess.open(OS.get_environment("PEG_AUDIO_BANK_OUTPUT"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t",true,true)); f.close()
	g.synth.stop(); g.synth.free(); g.free()
	g=null
	bank=null
	# Let the Dummy audio mixer release the last playback before engine teardown.
	await process_frame
	await process_frame
	print("AUDIO_CACHE_QA_RESULT passed=",passed," failed=",failed.size()," pcm_bytes=",report.metadata.pcm_bytes," maximum_pitch_error_hz=",max_error)
	quit(0 if failed.is_empty() else 1)
func check_exact(frequency,duration):
	g.sound_cooldown=0
	g.tone(frequency,duration)
	var cached=bank.stream_for(frequency,duration)
	var expected=legacy_pcm(frequency,duration)
	var played=g.synth.stream
	check(cached!=null and played!=null and cached.format==expected.format and cached.mix_rate==expected.mix_rate and cached.data==expected.data and played.format==expected.format and played.mix_rate==expected.mix_rate and played.data==expected.data,"Exact v0.4 PCM preserved by the bank and production playback at %d Hz / %d ms" % [frequency,int(duration*1000)])
func legacy_pcm(frequency,duration):
	# Frozen v0.4 synthesis oracle; deliberately independent of tone_bank.gd.
	var audio=AudioStreamWAV.new()
	audio.format=AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate=22050
	var samples=int(22050*duration)
	var bytes=PackedByteArray()
	bytes.resize(samples*2)
	for i in range(samples):
		var envelope=pow(1.0-float(i)/samples,2)
		var value=int(sin(float(i)/22050*TAU*frequency)*envelope*11000)
		bytes.encode_s16(i*2,value)
	audio.data=bytes
	return audio
func measure(label,operation:Callable,count,batch,warmup):
	for i in range(warmup): operation.call()
	var values=[]
	for i in range(count):
		var start=Time.get_ticks_usec()
		for n in range(batch): operation.call()
		values.append(float(Time.get_ticks_usec()-start)/batch)
	var sorted=values.duplicate(); sorted.sort()
	var sum=0.0
	for value in values: sum+=value
	var result={"samples":count,"batch":batch,"warmup":warmup,"mean_us":sum/count,"p50_us":sorted[int(count*.50)],"p95_us":sorted[int(count*.95)],"p99_us":sorted[int(count*.99)],"max_us":sorted[-1],"raw_us":values}
	report[label]=result
	var concise=result.duplicate(); concise.erase("raw_us")
	print(label," ",JSON.stringify(concise))
