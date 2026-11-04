extends SceneTree
## Replay the same frozen capture inputs to expose contact coordinates for editing.
const Capture = preload("res://capture/trailer_capture.gd")
var helper
var hits: Array = []
var clip = ""
var frame = 0

func damaged(position: Vector2, damage: float, impact: bool):
	if clip.is_empty():return
	hits.append({"clip":clip,"frame":frame,"time":float(frame)/60.0,
		"board_position":[position.x,position.y],"pixel_position":[position.x*1.5,position.y*1.5],
		"damage":damage,"impact_first_hit":impact})

func _initialize(): call_deferred("run")

func sample(name: String, frames: int, policy: Callable, action: Callable=Callable()):
	clip=name
	for i in range(frames):
		frame=i
		var t=float(i)/60.0
		if action.is_valid():action.call(t)
		var aim: Vector2=policy.call(t)
		helper.fixed_step(aim);helper.fixed_step(aim)

func run():
	helper=Capture.new()
	var viewport=SubViewport.new();viewport.size=Vector2i(1080,1920);root.add_child(viewport)
	helper.g=Capture.CaptureGame.new();viewport.add_child(helper.g)
	helper.g.peg_damaged.connect(damaged)
	helper.prepare("bakery",1,[2,2,1,0,0,0,1,2]);helper.g.equipped=[];helper.start_run();helper.advance(.3,Vector2(315,700))
	hits=[]
	sample("01-bakery-sparse",240,func(t):return Vector2(315+sin(t*.8)*90,700))
	clip=""
	helper.prepare("gelato",4,[4,3,2,2,2,2,2,2]);helper.start_run();helper.advance(1.8,Vector2(570,770))
	sample("02-gelato-aim",300,func(t):return Vector2(520+sin(t*1.1)*90,740+cos(t*.5)*55))
	clip=""
	helper.prepare("crystal",4,[6,5,3,2,3,3,3,4]);helper.start_run();helper.advance(2.4,Vector2(530,760))
	var collected=[false]
	sample("03-crystal-prism",360,func(t):return Vector2(480+sin(t*.9)*80,760),func(t):
		if not collected[0] and t>=1.0 and helper.g.crystal_run.offer_life>0:
			collected[0]=helper.g.crystal_launcher.try_collect(helper.g.crystal_run.offer_position))
	var destination=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):destination=arg.trim_prefix("--output=")
	if not destination.is_absolute_path():quit(2);return
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Deterministic headless replay of frozen capture inputs; edit coordinates only, not another video capture","hits":hits},"\t"))
	print("IMPACT_TRACE_OK hits=",hits.size())
	helper.g.free();viewport.free();helper.free();quit()
