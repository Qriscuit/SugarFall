extends "res://tests/area_ability_visual_qa.gd"
## Frozen actual renderer phases; every profile operation stays intercepted.

class RecordedMap extends "res://scripts/upgrade_map.gd":
	var highlights: Array[Dictionary] = []
	func _draw_signature_highlight(canvas: CanvasItem):
		highlights.append(signature_highlight())
		super._draw_signature_highlight(canvas)

class PulsePreview extends AbilityPreview:
	func _ready():
		super._ready()
		upgrade_map = RecordedMap.new(self)

func stage_entry(game,area: String):
	stage(game,area)
	game.audio_application_paused = false;game.audio_focus_lost = false
	game.reduced_motion = false;game.mode = "shop"
	game.upgrade_map.reset_view_state();game.upgrade_map.update(0)
	game.note_time = 0

func pulse_capture(game,output: String,name: String,resolution: Vector2i):
	var map = game.upgrade_map
	var node: Rect2 = map.node_rect(8,1,false)
	var card: Rect2 = map.card_rect()
	map.highlights.clear()
	await capture(game,output,name,resolution)
	check(not map.highlights.is_empty() and map.highlights[-1].visible,name+" production draw includes visible signature backdrop")
	check(map.node_rect(8,1,false)==node and map.card_rect()==card,name+" backdrop draw leaves actual node and card geometry fixed")
	var highlight = map.signature_highlight()
	var pixels: Rect2 = game.get_viewport().get_final_transform()*game.get_global_transform_with_canvas()*highlight.rect
	var clear = true
	for other in map.visible_nodes():
		if other!=map.TWIN_NODE: clear = clear and not highlight.rect.intersects(map.node_rect(other.x,other.y,false))
	check(clear,name+" backdrop does not cover a neighboring upgrade")
	observations[-1]["highlight"]={"rect":[highlight.rect.position.x,highlight.rect.position.y,highlight.rect.size.x,highlight.rect.size.y],"pixels":[pixels.position.x,pixels.position.y,pixels.size.x,pixels.size.y],"blend":highlight.blend,"opacity":highlight.opacity,"state":map.state_for(8,1)}

func run():
	var output = output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Upgrade pulse preview needs absolute output and actual GPU renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var game = PulsePreview.new();root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size = resolution;await process_frame;await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage_entry(game,area)
			var map = game.upgrade_map
			await pulse_capture(game,output,area+"-locked-rest",resolution)
			map.update(map.SIGNATURE_PULSE_DURATION*.5)
			await pulse_capture(game,output,area+"-locked-peak",resolution)
			game.reduced_motion = true;map.update(0)
			await pulse_capture(game,output,area+"-locked-reduced",resolution)
			game.reduced_motion = false
			game.highest_unlocked = 8;game.current_level = 8;game.levels[1] = 6 if area=="gelato" else 4
			if area=="gelato": game.gelato_shop_revision=0;game.ensure_gelato_shop_state()
			game.bank = 0;map.update(map.FEEDBACK_DURATION)
			map._signature_pulse_age = map.SIGNATURE_PULSE_DURATION*.5
			check(map.state_for(8,1)=="unaffordable",area+" real eligible but empty-wallet state remains unaffordable")
			await pulse_capture(game,output,area+"-unaffordable-peak",resolution)
			game.bank = game.ability_ui.cost()
			check(game.ability_ui.controller().buy(),area+" existing real transaction buys the owned-preview signature")
			map.update(map.FEEDBACK_DURATION);game.note_time=0
			map._signature_pulse_age = 0
			await pulse_capture(game,output,area+"-owned-rest",resolution)
			map.update(map.SIGNATURE_PULSE_DURATION*.5)
			await pulse_capture(game,output,area+"-owned-peak",resolution)
			stage_entry(game,area);show_card(game)
			game.upgrade_map._signature_pulse_age = map.SIGNATURE_PULSE_DURATION*.5
			await pulse_capture(game,output,area+"-selected-peak",resolution)
	check(game.persistence_attempts==0,"Pulse renderer never reads or writes player profiles")
	var report = {"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"phone_verified":false,"renderer":RenderingServer.get_video_adapter_name()}
	var saved = FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(report,"\t"));saved.close()
	print("UPGRADE_PULSE_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free();quit(0 if failures.is_empty() else 1)
