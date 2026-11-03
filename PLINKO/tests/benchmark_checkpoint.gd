extends SceneTree
func _initialize():
	var g=load("res://scripts/main.gd").new()
	g.testing=true
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.current_level=12;g.highest_unlocked=12
	g.start_shift()
	for i in range(80):g.spawn_ball(Vector2(80+(i%8)*70,270+(i/8)*20),"normal")
	var samples=[]
	for i in range(120):
		var before=Time.get_ticks_usec()
		g.save_game()
		var took=Time.get_ticks_usec()-before
		if i>=20:samples.append(took/1000.0)
	samples.sort()
	var total=0.0
	for value in samples:total+=value
	print("CHECKPOINT_BENCHMARK samples=",samples.size()," mean_ms=",total/samples.size()," p95_ms=",samples[94]," max_ms=",samples[-1]," bytes=",FileAccess.get_file_as_bytes(g.SAVE_FILE).size())
	g.free();quit()
