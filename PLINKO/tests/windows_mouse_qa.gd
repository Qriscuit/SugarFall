extends SceneTree
## Windows input regression for raw hover and the emulated touch event path.
class Fixture extends "res://scripts/main.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _draw(): pass
	func load_game(): assert(false, "No player profile reads")
	func save_game(): assert(false, "No player profile writes")

var failed: Array[String] = []
var passed = 0
var game
func check(value: bool, label: String):
	if value: passed += 1
	else: failed.append(label)
	print("PASS: " if value else "FAIL: ", label)

func mouse_motion(point: Vector2, held: bool):
	var ev = InputEventMouseMotion.new()
	ev.position = point
	ev.global_position = point
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	ev.relative = Vector2(80,0)
	game._input(ev)
	if held:
		var drag = InputEventScreenDrag.new()
		drag.position = point
		game._input(drag)

func mouse_button(point: Vector2, down: bool):
	var ev = InputEventMouseButton.new()
	ev.position = point
	ev.global_position = point
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	game._input(ev)
	var touch = InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = down
	game._input(touch)

func run_area(area: String):
	game = Fixture.new()
	game.testing = true
	game.sound_on = false
	game.first_run_guide.completed = true
	game.first_run_guide.active = false
	game.set_active_area(area)
	game.start_shift()
	game.navigation_delay = 0
	root.add_child(game)
	var start = game.board_to_screen(Vector2(210,500))
	var target = game.board_to_screen(Vector2(480,500))
	var t = game.remaining
	game.pickups = [{"p":Vector2(480,500), "life":4.0}]
	mouse_motion(target, false)
	check(is_equal_approx(game.aim_x,360) and game.remaining == t, area+" hover cannot steer or collect")
	mouse_button(start, true)
	check(is_equal_approx(game.aim_x,210), area+" left press starts steering")
	mouse_motion(target, true)
	check(is_equal_approx(game.aim_x,480) and is_equal_approx(game.remaining,t+2), area+" held left drag steers and collects")
	mouse_button(target, false)
	game.pickups = [{"p":Vector2(210,500), "life":4.0}]
	mouse_motion(start, false)
	check(is_equal_approx(game.aim_x,480) and is_equal_approx(game.remaining,t+2), area+" release ends steering and pickup collection")
	game.queue_free()

func _initialize():
	call_deferred("run")

func run():
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), "Mouse-to-touch emulation is enabled")
	for area in ["bakery", "gelato", "crystal"]:
		run_area(area)
	print("WINDOWS_MOUSE_QA_RESULT passed=",passed," failed=",failed.size())
	quit(1 if failed.size() else 0)


