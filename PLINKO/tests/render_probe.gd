extends "res://scripts/main.gd"
var samples=[]
var setup=false
func _ready():
	font=ThemeDB.fallback_font
	testing=true
	board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	current_level=12
	start_shift()
	var args=OS.get_cmdline_user_args()
	var peg_count=int(args[0]) if args.size()>0 else 34
	var ball_count=int(args[1]) if args.size()>1 else 80
	pegs.resize(peg_count)
	for p in pegs: p.hp=6;p.max=6
	for i in range(ball_count): spawn_ball(Vector2(70+(i%10)*60,300+int(i/10)*60),"normal")
	set_physics_process(false)
	setup=true
func _draw():
	if not setup:return
	var t=Time.get_ticks_usec()
	super._draw()
	samples.append(Time.get_ticks_usec()-t)
	if samples.size()==360:
		var measured=samples.slice(60);measured.sort()
		print("RENDER_PROBE ",JSON.stringify({"samples":300,"pegs":pegs.size(),"balls":balls.size(),"p50_us":measured[150],"p95_us":measured[285],"max_us":measured[-1],"scope":"CPU draw-command generation only; no phone/GPU FPS"}))
		get_tree().quit()
