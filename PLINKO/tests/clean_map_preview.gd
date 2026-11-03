extends SceneTree
## Interactive production UI fixture. All profile reads/writes are intercepted.
class Preview extends "res://scripts/main.gd":
	func load_game():
		levels=[1,0,1,1,0,0,1,0]
		bank=360
		current_level=3
		highest_unlocked=3
		equipped=["ricochet"]
		mode="shop"
		upgrade_map.selected=1
		upgrade_map.tier=1
		upgrade_map.update(0)
	func save_game() -> bool: return true
	func write_profile_file(_data: Dictionary) -> bool: return true

func _initialize(): call_deferred("open_preview")
func open_preview():
	DisplayServer.window_set_title("Sugarfall — Upgrade map preview")
	var game=Preview.new()
	root.add_child(game)
