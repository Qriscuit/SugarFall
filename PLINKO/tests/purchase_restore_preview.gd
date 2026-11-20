extends "res://tests/ui_art_preview.gd"
## Real Home renderer for the paid-checkpoint restore/retry state; no profile IO.
var files: Array[String]=[]
func _initialize(): call_deferred("run")
func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("GPU renderer and an absolute --output-dir are required");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new();viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=PreviewGame.new();viewport.add_child(game)
	for resolution in RESOLUTIONS:
		viewport.size=resolution;game.scale=Vector2.ONE*float(resolution.x)/720.0
		for area in ["bakery","gelato","crystal"]:
			game.set_active_area(area);game.current_level=1;game.highest_unlocked=8;game.bank=123
			game.first_run_guide.active=false;game.first_run_guide.completed=true
			game._defer_paid_checkpoint({},game.run_rules_revision,{},"isolated-render-fixture")
			for state in ["unavailable","retry"]:
				game.purchase_restore_message="Purchases unavailable. Your saved run is kept." if state=="unavailable" else "Tap Restore run to retry. Your run is kept."
				game.text_overflows.clear()
				var before=game.run_serial
				game.home_menu.press(game.home_menu.PLAY_RECT.get_center())
				check(game.mode=="home" and game.run_serial==before and game.has_deferred_paid_run(),"Restore button retains the deferred run: %s/%s" % [area,state])
				game.purchase_restore_message="Purchases unavailable. Your saved run is kept." if state=="unavailable" else "Tap Restore run to retry. Your run is kept."
				game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
				var picture=viewport.get_texture().get_image()
				var file="%s-restore-%s-%d.png" % [area,state,resolution.x]
				check(picture!=null and picture.get_size()==resolution,"GPU Home restore frame "+file)
				check(game.text_overflows.is_empty(),"Restore controls and inline copy fit "+file)
				check(picture.save_png(output.path_join(file))==OK,"Saved "+file)
				files.append(file)
	check(game.persistence_attempts==0,"Restore rendering performs zero player profile reads or writes")
	var report={"captures":files,"checks":checks,"failures":failures,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name()}
	var file=FileAccess.open(output.path_join("restore-preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	game.free();viewport.free()
	print("PURCHASE_RESTORE_PREVIEW_RESULT passed=%d failed=%d captures=%d" % [checks-failures.size(),failures.size(),files.size()])
	quit(0 if failures.is_empty() else 1)
