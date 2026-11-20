extends "res://tests/menu_polish_visual_qa.gd"
## Actual area screens and themed cream waves, with in-memory profiles only.
const TARGET_SIZES = [Vector2i(450,800),Vector2i(450,1000)]

class AreaUIPreview extends AuditPreview:
	func record_text(value: String,pos: Vector2,size: int,face: Font):
		if mode!="boards":
			super.record_text(value,pos,size,face)
			return
		# Journey labels are culled against the expanded physical viewport. Its
		# world can extend above/below the centered 720x1280 interactive board.
		if value.is_empty() or value.is_valid_int(): return
		var ink=Rect2(pos-Vector2(0,face.get_ascent(size)),Vector2(face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,face.get_height(size)))
		if not level_map.visual_area().grow(.1).encloses(ink): text_overflows.append(capture_name+": journey text outside viewport: "+value)

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Area UI visual QA requires an absolute output and GPU renderer"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new(); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=AreaUIPreview.new(); viewport.add_child(game)
	for resolution in TARGET_SIZES:
		viewport.size=resolution
		for area in ["bakery","gelato","crystal"]:
			for page in ["home","boards","shop","support","guide","loadout"]:
				setup(game,area); game.mode=page
				game.update_safe_area()
				if page=="boards": game.highest_unlocked=8; game.current_level=5
				if page=="shop":
					game.bank=55; game.upgrade_map.selected=0; game.upgrade_map.tier=3; game.upgrade_map.update(0)
				await snap(viewport,game,output,area+"-"+page,resolution)
			setup(game,area); game.update_safe_area(); play(game)
			await snap(viewport,game,output,area+"-gameplay",resolution)
			game.mode="paused"; game.pause_transition.settle()
			await snap(viewport,game,output,area+"-pause",resolution)
			game.mode="play"; game.remaining=0; game.step(1.0/60.0)
			check(game.mode=="result","Real timeout reaches results for "+area)
			await snap(viewport,game,output,area+"-result",resolution)
			setup(game,area); game.update_safe_area()
			await settled_frame(viewport,game)
			game.page_transition.enabled=true; game.mode="shop"
			check(game.page_transition.wave_area_id==area and game.page_transition.wave_texture.resource_path==game.page_transition.WAVE_PATHS[area],"Real navigation selects destination wave for "+area)
			for fraction in [.25,.5,.75]:
				game.page_transition.time=game.page_transition.DURATION*fraction
				await snap(viewport,game,output,area+"-wave-"+str(roundi(fraction*100)),resolution)
				if fraction==.5: check(fully_white(viewport.get_texture().get_image()),"Themed wave fully covers every viewport pixel for "+area+" "+str(resolution))
			game.page_transition.finish()
			setup(game,area,true); game.update_safe_area(); await settled_frame(viewport,game)
			game.page_transition.enabled=true; game.mode="support"
			check(not game.page_transition.is_blocking(),"Reduced Motion leaves controls ready without a themed sweep: "+area)
			await snap(viewport,game,output,area+"-settings-reduced",resolution)
	check(game.persistence_attempts==0,"Zero player-profile IO")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var out=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("AREA_UI_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free(); viewport.free(); quit(0 if failures.is_empty() else 1)
