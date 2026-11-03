extends SceneTree
func _initialize():
	root.add_child(load("res://tests/render_probe.gd").new())
