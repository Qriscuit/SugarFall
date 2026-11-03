extends RefCounted
## Page changes commit immediately. This overlay keeps the last rendered page
## visible until an opaque cream body covers it, then reveals the new page.
const DURATION = .62
const WAVE_PATH = "res://data/art/transitions/cream_wave.png"
const WAVE_REGION = Rect2(0,0,1536,768)
const BODY_JOIN_Y = 520.0
var g
var enabled = false:
	set(value):
		enabled = value
		if not enabled: finish()
var active = false
var time = DURATION
var from_mode = ""
var to_mode = ""
var snapshot: Texture2D
var wave_texture: Texture2D
var settled_this_frame = false
var canvas: Node2D

class PageCanvas extends Node2D:
	var presentation
	func _draw(): presentation.draw(self)

func _init(game):
	g = game

func load_assets():
	if ResourceLoader.exists(WAVE_PATH): wave_texture = load(WAVE_PATH)
	attach()

func attach():
	if not g.is_inside_tree() or is_instance_valid(canvas): return
	canvas = PageCanvas.new()
	canvas.name = "PageTransition"
	canvas.z_index = 100
	canvas.presentation = self
	g.add_child(canvas)

func redraw():
	if is_instance_valid(canvas): canvas.queue_redraw()

func uses_cream(previous: String, destination: String) -> bool:
	# Entering a run from its Home tray has a matching board/equipment morph.
	# End-of-run results and their reward dialogs stay over the frozen board.
	# Studio still reveals every restored destination with the shared cream wave.
	if previous == "studio": return true
	if previous == "home" and destination == "play": return false
	if previous in ["play","paused","abandon_confirm"] and destination in ["play","paused","abandon_confirm"]: return false
	if destination == "result" and previous in ["play","paused","abandon_confirm"]: return false
	if previous in ["result","bonus_confirm","test_ad"] and destination in ["result","bonus_confirm","test_ad"]: return false
	return true

func begin(previous: String, destination: String):
	if previous == destination: return
	if not enabled:
		finish()
		return
	g.cancel_page_gestures()
	g.run_transition.finish()
	if g.reduced_motion or not uses_cream(previous,destination):
		finish()
		return
	if active:
		# Several synchronous logical writes can form one transaction (for
		# example Result -> test ad). Retain its original image and animation.
		to_mode = destination
		return
	from_mode = previous
	to_mode = destination
	snapshot = null
	if g.is_inside_tree():
		var viewport_texture = g.get_viewport().get_texture()
		if viewport_texture != null:
			var image = viewport_texture.get_image()
			if image != null and not image.is_empty(): snapshot = ImageTexture.create_from_image(image)
	time = 0.0
	active = true
	settled_this_frame = false
	g.queue_redraw()
	redraw()

func finish():
	active = false
	time = DURATION
	snapshot = null
	settled_this_frame = false
	redraw()

func progress() -> float:
	return clampf(time/DURATION,0.0,1.0)

func is_blocking() -> bool:
	return active or settled_this_frame

func covered() -> bool:
	var bounds = Rect2(0,0,g.WIDTH,g.HEIGHT)
	if g.is_inside_tree(): bounds = g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()
	return active and geometry(bounds).fully_covered

func update(delta: float) -> bool:
	settled_this_frame = false
	if not active: return false
	if not enabled or g.reduced_motion:
		finish()
		settled_this_frame = true
		return true
	if not is_finite(delta) or delta <= 0: return false
	time = minf(DURATION,time+delta)
	if time >= DURATION:
		finish()
		settled_this_frame = true
	redraw()
	return true

func geometry(bounds: Rect2) -> Dictionary:
	var covering = progress() < .5
	var phase = progress()*2.0 if covering else (progress()-.5)*2.0
	var move = smoothstep(0.0,1.0,phase)
	var scale = bounds.size.x/WAVE_REGION.size.x
	var height = WAVE_REGION.size.y*scale
	var top = lerpf(bounds.end.y,bounds.position.y-height,move)
	var join = top+BODY_JOIN_Y*scale if covering else top+height-BODY_JOIN_Y*scale
	var body = Rect2(bounds.position.x,join,bounds.size.x,maxf(0.0,bounds.end.y-join)) if covering else Rect2(bounds.position,Vector2(bounds.size.x,maxf(0.0,join-bounds.position.y)))
	body = body.intersection(bounds)
	return {"covering":covering,"image":Rect2(bounds.position.x,top,bounds.size.x,height),"body":body,"join":join,"flip_y":not covering,"fully_covered":body.encloses(bounds)}

func draw(painter: CanvasItem = null):
	if not active: return
	var target = painter if painter != null else g
	var bounds: Rect2 = g.get_global_transform_with_canvas().affine_inverse()*g.get_viewport_rect()
	var shape = geometry(bounds)
	target.draw_set_transform(Vector2.ZERO)
	if shape.covering and snapshot != null:
		target.draw_texture_rect(snapshot,bounds,false)
	# Native art has translucent pixels. The opaque body, rather than artwork
	# alpha, guarantees complete coverage before the underlying page is swapped.
	if shape.body.has_area(): target.draw_rect(shape.body,Color.WHITE)
	if wave_texture != null:
		if shape.flip_y:
			target.draw_set_transform(Vector2(0,shape.image.position.y+shape.image.size.y),0,Vector2(1,-1))
			target.draw_texture_rect_region(wave_texture,Rect2(shape.image.position.x,0,shape.image.size.x,shape.image.size.y),WAVE_REGION)
		else:
			target.draw_texture_rect_region(wave_texture,shape.image,WAVE_REGION)
	else:
		# Missing artwork still gives a complete, bounded opaque wipe.
		var edge = shape.join
		for index in range(12):
			target.draw_circle(Vector2(bounds.position.x+index*bounds.size.x/11.0,edge),bounds.size.x/14.0,Color.WHITE)
	target.draw_set_transform(Vector2.ZERO)
