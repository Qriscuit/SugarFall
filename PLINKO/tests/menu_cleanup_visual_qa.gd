extends "res://tests/pause_visual_qa.gd"
## Real menu renderer and touch routing at both portrait sizes. Capabilities are
## staged explicitly; this is not a substitute for a native release gate check.
const MenuBase = preload("res://tests/area_completion_visual_qa.gd")

class MenuPreview extends MenuBase.AuditPreview:
	var preview_capabilities = true
	var drawn_buttons: Array[Dictionary] = []
	var drawn_text: Array[String] = []
	var button_bounds = Rect2()
	func developer_tools_available() -> bool: return preview_capabilities
	func test_commerce_available() -> bool:
		return preview_capabilities and super.test_commerce_available()
	func record_text(value: String, pos: Vector2, size: int, face: Font):
		drawn_text.append(value)
		if button_bounds.has_area():
			var ink = Rect2(pos-Vector2(0,face.get_ascent(size)),Vector2(face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,face.get_height(size)))
			if not button_bounds.grow(-15).encloses(ink): text_overflows.append("Button lacks safe text inset: "+value)
		super.record_text(value,pos,size,face)
	func button(rect, label, primary=false, subtitle="", painter: CanvasItem=null):
		drawn_buttons.append({"rect":rect,"label":label})
		button_bounds = rect
		super.button(rect,label,primary,subtitle,painter)
		button_bounds = Rect2()

func _initialize(): call_deferred("run")

func stage_menu(game, area: String, page: String, preview: bool):
	game.page_transition.enabled = false
	game.preview_capabilities = preview
	game.monetization = game.MonetizationService.new(preview)
	prepare(game,area)
	game.update_safe_area()
	game.mode = page
	game.pause_transition.settle()
	game.pause_transition.sync_visuals()
	game.navigation_delay = 0
	game.result_input_delay = 0
	game.test_input_enabled = true

func menu_frame(game, output: String, label: String) -> Image:
	game.drawn_buttons.clear(); game.drawn_text.clear()
	if is_instance_valid(game.pause_transition.panel): game.pause_transition.panel.queue_redraw()
	var picture = await frame(game,output,label)
	var forbidden = ["Make yourself at home","A little breather","Welcome back","Your timer is paused.","Start over from tray 1, with Mabel's introduction.","Local only. No data leaves this device.","Aim. Bounce. Crumble.","Three trials. Try a new recipe."]
	check(not forbidden.any(func(phrase): return phrase in game.drawn_text),label+" omits redundant headings, slogans and reassurance copy")
	var controls = game.drawn_buttons
	var valid = true
	for i in range(controls.size()):
		var rect: Rect2 = controls[i].rect
		valid = valid and Rect2(0,0,game.WIDTH,game.HEIGHT).encloses(rect)
		for j in range(i+1,controls.size()):
			if controls[i].label!=controls[j].label: valid = valid and not rect.intersects(controls[j].rect)
	check(valid,label+" controls are inside the safe logical canvas and do not overlap")
	check(game.text_overflows.is_empty(),label+" button labels retain at least a 15-unit inset")
	return picture

func button_starting(controls: Array, prefix: String) -> Dictionary:
	for control in controls:
		if str(control.label).begins_with(prefix): return control
	return {}

func tap_rendered(game, controls: Array, prefix: String):
	var control = button_starting(controls,prefix)
	check(not control.is_empty(),"Rendered control exists for "+prefix)
	if control.is_empty(): return
	game.navigation_delay = 0
	game.result_input_delay = 0
	# Input comes on a clean frame after a completed visual transition, just as
	# in the live loop. The completion-frame guard is verified separately.
	game.pause_transition.update(0)
	var physical = root.get_final_transform()*game.get_global_transform_with_canvas()*control.rect.get_center()
	var event = InputEventScreenTouch.new()
	# Godot maps physical window input into viewport coordinates before _input.
	# Keep that conversion explicit so tall-window centering is exercised.
	event.position = root.get_final_transform().affine_inverse()*physical
	event.index = 0; event.pressed = true
	game._input(event)
	event.pressed = false
	game._input(event)

func settings_actions(game, controls: Array, preview: bool):
	var area = game.area_id
	var sound = game.sound_on
	tap_rendered(game,controls,"Sound")
	check(game.mode=="support" and game.sound_on!=sound,area+" drawn Sound button matches its physical touch target")
	var motion = game.reduced_motion
	tap_rendered(game,controls,"Reduced motion")
	check(game.mode=="support" and game.reduced_motion!=motion,area+" drawn Reduced motion button matches its physical touch target")
	tap_rendered(game,controls,"Reset progress")
	check(game.mode=="reset_confirm",area+" drawn Reset button opens its confirmation")
	game.cancel_progress_reset(); game.navigation_delay=0
	if preview:
		tap_rendered(game,controls,"Developer settings")
		check(game.mode=="developer_areas",area+" drawn Developer settings button routes correctly")
		game.mode="support"; game.navigation_delay=0
		tap_rendered(game,controls,"Performance display")
		check(game.diagnostics_on,area+" drawn Performance button toggles diagnostics")
		game.diagnostics_on=false
		tap_rendered(game,controls,"Ads & purchases")
		check(game.mode=="monetization",area+" drawn preview commerce button routes correctly")
		game.mode="support"; game.navigation_delay=0
	else:
		check(button_starting(controls,"Developer settings").is_empty() and button_starting(controls,"Performance display").is_empty() and button_starting(controls,"Ads & purchases").is_empty(),area+" public layout has no preview controls")
		check(not game.open_developer_areas(),area+" public capability refuses direct developer entry")
	tap_rendered(game,controls,"Back")
	check(game.mode=="home",area+" drawn Back button returns home")

func pause_actions(game, controls: Array):
	var area=game.area_id
	game.page_transition.enabled=false
	var saved = frozen_state(game)
	var sound=game.sound_on
	tap_rendered(game,controls,"Sound")
	check(game.mode=="paused" and game.sound_on!=sound,area+" pause Sound touch aligns with artwork")
	tap_rendered(game,controls,"Reduced motion")
	check(game.mode=="paused" and game.reduced_motion,area+" pause Reduced motion touch aligns with artwork")
	tap_rendered(game,controls,"End shift")
	check(game.mode=="abandon_confirm",area+" pause End shift touch opens confirmation")
	game.mode="paused"; game.navigation_delay=0
	tap_rendered(game,controls,"Resume")
	check(game.mode=="play" and not game.pause_transition.active,area+" Reduced Motion resumes immediately through drawn Resume target")
	check(game.RunSnapshot.capture(game)==saved.run and game.rng.state==saved.rng,area+" menu taps do not advance or restart the run")

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Absolute output directory and GPU renderer required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game=MenuPreview.new()
	root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution
		await process_frame; await process_frame
		for area in ["bakery","gelato","crystal"]:
			for preview in [true,false]:
				stage_menu(game,area,"support",preview)
				await menu_frame(game,output,area+"-settings-"+("preview" if preview else "public"))
				var controls=game.drawn_buttons.duplicate(true)
				check(controls.size()==(7 if preview else 4),area+" Settings has only the expected controls for its capabilities")
				settings_actions(game,controls,preview)
			game.preview_capabilities=true
			game.monetization=game.MonetizationService.new(true)
			stage_pause(game,area)
			game.mode="paused"
			game.pause_transition.update(game.pause_transition.OPEN_DURATION)
			await menu_frame(game,output,area+"-pause-clean")
			var controls=game.drawn_buttons.duplicate(true)
			check("Paused" in game.drawn_text or "Pause" in game.drawn_text,area+" Pause has a direct heading")
			pause_actions(game,controls)
			if resolution==Vector2i(450,800):
				for page in ["guide","trials"]:
					stage_menu(game,area,page,true)
					await menu_frame(game,output,area+"-"+page+"-clean")
	check(game.persistence_attempts==0,"Menu visual/touch fixtures never read or write player profiles")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name(),"capabilities":"Explicit preview/public overrides exercise production layout branches; not a native release binary claim","phone_verified":false}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t")); out.close()
	print("MENU_CLEANUP_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free(); quit(0 if failures.is_empty() else 1)
