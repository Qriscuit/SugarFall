extends RefCounted
## Pause presentation only: the run is frozen until both Resume fades settle.
const OPEN_DURATION = .22
const MENU_OUT_DURATION = .16
const BLUR_OUT_DURATION = .18
const PAUSED_MODES = ["paused", "abandon_confirm"]
const BLUR_SHADER = preload("res://data/art/transitions/pause_blur.gdshader")
var g
var active = false
var phase = "idle"
var time = 0.0
var menu_alpha = 0.0
var blur_amount = 0.0
var menu_mode = ""
var settled_this_frame = false
var backdrop: ColorRect
var panel: Node2D
var panel_signature: Array = []

class PausePanel extends Node2D:
	var presentation
	func _draw():
		if presentation.menu_mode == "abandon_confirm":
			presentation.g.draw_abandon_confirm(self)
		else:
			presentation.g.draw_pause(self)

func _init(game):
	g = game

func attach():
	if not g.is_inside_tree() or is_instance_valid(backdrop): return
	backdrop = ColorRect.new()
	backdrop.name = "PauseBackdrop"
	backdrop.z_index = 50
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = ShaderMaterial.new()
	shader.shader = BLUR_SHADER
	backdrop.material = shader
	g.add_child(backdrop)
	panel = PausePanel.new()
	panel.name = "PausePanel"
	panel.z_index = 51
	panel.presentation = self
	g.add_child(panel)
	sync_visuals()

func begin(previous: String, destination: String):
	settled_this_frame = false
	if not g.page_transition.enabled or g.reduced_motion:
		_settle_mode(destination)
	elif previous == "play" and destination == "paused":
		phase = "opening"
		time = 0.0
		active = true
		menu_mode = destination
		menu_alpha = 0.0
		blur_amount = 0.0
	elif previous in PAUSED_MODES and destination == "play":
		phase = "closing"
		time = 0.0
		active = true
		menu_mode = previous
		menu_alpha = 1.0
		blur_amount = 1.0
	else:
		_settle_mode(destination)
	sync_visuals()

func _settle_mode(destination: String):
	active = false
	phase = "idle"
	time = 0.0
	menu_mode = destination if destination in PAUSED_MODES else ""
	menu_alpha = 1.0 if destination in PAUSED_MODES else 0.0
	blur_amount = menu_alpha

func settle():
	_settle_mode(g.mode)
	settled_this_frame = false
	sync_visuals()

func is_blocking() -> bool:
	return active or settled_this_frame

func update(delta: float) -> bool:
	settled_this_frame = false
	if not active:
		sync_visuals()
		return false
	if not g.page_transition.enabled or g.reduced_motion:
		_settle_mode(g.mode)
		settled_this_frame = true
	elif is_finite(delta) and delta > 0:
		var duration = OPEN_DURATION if phase == "opening" else MENU_OUT_DURATION+BLUR_OUT_DURATION
		time = minf(duration,time+delta)
		if phase == "opening":
			menu_alpha = smoothstep(0.0,OPEN_DURATION,time)
			blur_amount = menu_alpha
		else:
			menu_alpha = 1.0-smoothstep(0.0,MENU_OUT_DURATION,time)
			blur_amount = 1.0-smoothstep(MENU_OUT_DURATION,duration,time)
		if time >= duration:
			_settle_mode(g.mode)
			settled_this_frame = true
	sync_visuals()
	return true

func sync_visuals():
	if not is_instance_valid(backdrop): return
	var bounds: Rect2 = g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()
	backdrop.position = bounds.position
	backdrop.size = bounds.size
	backdrop.visible = blur_amount > 0.0
	backdrop.material.set_shader_parameter("amount",blur_amount)
	backdrop.material.set_shader_parameter("shade",g.area_surface("overlay"))
	# The same gentle blur radius in design pixels at normal and tall phone sizes.
	var pixel_scale = (g.get_viewport().get_screen_transform()*g.get_global_transform_with_canvas()).get_scale().x
	backdrop.material.set_shader_parameter("blur_lod",clampf(log(maxf(1.0,4.5*pixel_scale))/log(2.0),.6,3.0))
	panel.visible = menu_alpha > 0.0
	panel.modulate.a = menu_alpha
	var signature = [menu_mode,g.area_id,g.sound_on,g.reduced_motion,g.resumed_run]
	if signature != panel_signature:
		panel_signature = signature
		panel.queue_redraw()
