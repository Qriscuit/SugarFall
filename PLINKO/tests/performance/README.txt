Performance harnesses use cloud/local CPU timing, not measured phone GPU FPS.

Physics comparison:
bash tests/performance/run.sh /absolute/path/to/project output_label
This writes isolated runtime data and timing results beside the harness. Compare the same machine and workload; do not run two benchmarks concurrently.

Rendering command generation:
Use isolated XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME directories, then:
godot --headless --path . --script res://tests/run_render_probe.gd -- 34 80
Arguments are live peg count and ball count. It measures draw-command CPU only, not actual rasterization. Warm-up is60frames and measured sample count300.

Audio bank regression:
Use isolated XDG storage. Set PEG_AUDIO_BANK_SCRIPT=res://scripts/tone_bank.gd and PEG_AUDIO_BANK_OUTPUT to a writable output JSON path, then run:
godot --headless --audio-driver Dummy --path . --script res://tests/performance/audio_cache_qa.gd
This checks the bank resources and PCM, not subjective audible quality. Stressing the Dummy playback queue may produce a teardown resource warning in this harness; it does not show a runtime gameplay error.
