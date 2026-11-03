extends "res://tests/area_completion_visual_qa.gd"
## Actual Home/offer/node and Jam Burst artwork at phone-scale portrait sizes.
const SIZES=[Vector2i(450,800),Vector2i(450,1000)]
const Access=preload("res://scripts/area_ability_access.gd")

class AbilityPreview extends AuditPreview:
	var drawn_buttons: Array[Dictionary]=[]
	var inside_button=Rect2()
	func record_text(value: String,pos: Vector2,size: int,face: Font):
		if inside_button.has_area() and not value.is_empty():
			var ink=Rect2(pos-Vector2(0,face.get_ascent(size)),Vector2(face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,face.get_height(size)))
			if not inside_button.grow(-14).encloses(ink): text_overflows.append("Button text lacks safe inset: "+value)
		super.record_text(value,pos,size,face)
	func button(rect,label,primary=false,subtitle="",painter: CanvasItem=null):
		drawn_buttons.append({"rect":rect,"label":label})
		inside_button=rect
		super.button(rect,label,primary,subtitle,painter)
		inside_button=Rect2()

func _initialize(): call_deferred("run")

func stage(game,area: String):
	game.page_transition.enabled=false
	game.ability_access=Access.new(true)
	prepare(game,area)
	game.update_safe_area()
	game.current_level=1;game.highest_unlocked=1;game.levels.fill(0);game.bank=0
	game.gelato_shop_revision=0
	if area=="gelato": game.ensure_gelato_shop_state()
	game.ability_unlock_source="earned";game.bakery_jam_burst=false;game.bakery_run={}
	game.ability_ui.stage="details";game.ability_ui.message=""
	game.pause_transition.settle()

func capture(game,output: String,name: String,resolution: Vector2i):
	game.drawn_buttons.clear()
	await snap(root,game,output,name,resolution)
	var controls=game.drawn_buttons
	var aligned=true
	for i in range(controls.size()):
		aligned=aligned and Rect2(0,0,720,1280).encloses(controls[i].rect)
		for j in range(i+1,controls.size()):
			if controls[i].label!=controls[j].label: aligned=aligned and not controls[i].rect.intersects(controls[j].rect)
	check(aligned,name+" controls fit without overlap")

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Ability visual QA requires an absolute output folder and actual GPU renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var game=AbilityPreview.new();root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution
		await process_frame;await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage(game,area)
			await capture(game,output,area+"-ability-home",resolution)
			game.ability_ui.open("home")
			await capture(game,output,area+"-ability-locked",resolution)
			game.ability_ui.stage="confirm"
			await capture(game,output,area+"-ability-confirm",resolution)
			game.ability_ui.stage="details"
			game.current_level=8;game.highest_unlocked=8;game.bank=5000;game.levels[1]=6 if area=="gelato" else 4
			if area=="gelato": game.gelato_shop_revision=0;game.ensure_gelato_shop_state()
			game.mode="shop";game.upgrade_map.reset_view_state();game.upgrade_map.update(0)
			game.upgrade_map.twin_selected=true;game.upgrade_map.selected=-1
			await capture(game,output,area+"-ability-node",resolution)
		stage(game,"bakery")
		game.bakery_jam_burst=true;game.current_level=8;game.highest_unlocked=8
		game.start_shift();game.run_transition.finish();game.spawn_clock=100;game.pickup_clock=100
		for index in range(4): game.spawn_ball(Vector2(160+index*80,400),"normal",Vector2(0,85),false)
		await capture(game,output,"bakery-jam-charging",resolution)
		var direct: Dictionary=game.pegs[5]
		game.spawn_ball(direct.p+Vector2(0,-40),"normal",Vector2(0,85),false)
		await capture(game,output,"bakery-jam-filled",resolution)
		game.bakery_ability.on_hit(game.balls[-1],direct)
		check(not game.bakery_ability.bursts.is_empty(),"Actual Jam hit creates its transient splash")
		await capture(game,output,"bakery-jam-burst",resolution)
	check(game.persistence_attempts==0,"Ability renderer never reads or writes player profiles")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"phone_verified":false,"renderer":RenderingServer.get_video_adapter_name()}
	var saved=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(report,"\t"));saved.close()
	print("AREA_ABILITY_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free();quit(0 if failures.is_empty() else 1)
