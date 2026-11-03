extends SceneTree
func _initialize():
	var game=load("res://scripts/main.gd").new()
	game.testing=true
	var invalids=[
		{"version":1,"bank":{},"levels":[0,0,0,0,0,0,0,0]},
		{"version":1,"bank":10,"levels":[[],0,0,0,0,0,0,0]},
		{"version":1,"bank":10,"current_level":{},"levels":[0,0,0,0,0,0,0,0]}]
	for i in range(invalids.size()):
		var f=FileAccess.open(game.SAVE_FILE,FileAccess.WRITE)
		f.store_string(JSON.stringify(invalids[i]))
		f.close()
		print("MALFORMED_CASE ",i)
		game.load_game()
	game.free()
	quit()
