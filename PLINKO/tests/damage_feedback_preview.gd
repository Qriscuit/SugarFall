extends "res://tests/ui_art_preview.gd"
## Staged actual gameplay renderer; never accesses a player profile or advances physics.
var output_files: Array[String] = []

func _initialize(): call_deferred("run_damage_preview")

func run_damage_preview():
	var directory = output_directory()
	if not directory.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("An absolute --output-dir and a GPU renderer are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = PreviewGame.new()
	viewport.add_child(game)
	for resolution in RESOLUTIONS:
		viewport.size = resolution
		game.scale = Vector2.ONE*float(resolution.x)/720.0
		for area in ["bakery","gelato"]:
			for phase in ["hit","settling","reduced","large-wallet"]:
				game.set_active_area(area)
				game.current_level = 10
				game.highest_unlocked = 10
				game.first_run_guide.active = false
				game.first_run_guide.completed = true
				game.start_shift()
				game.run_transition.finish()
				game.remaining = 7.5
				game.shift_coins = 999999999 if phase=="large-wallet" else 127
				game.reduced_motion = phase=="reduced"
				game.run_coin_feedback.reset()
				game.run_coin_feedback.observe(0,game.run_id)
				game.run_coin_feedback.observe(game.shift_coins,game.run_id)
				game.run_coin_feedback.advance(.56 if phase=="settling" else .09)
				game.spawn_ball(Vector2(260,350),"impact",Vector2(70,220),false)
				game.balls[-1].life = .3
				game.spawn_ball(Vector2(440,350),"impact",Vector2(-70,220),false)
				game.balls[-1].life = .3
				game.balls[-1].used = true
				var sample_count = mini(4,game.pegs.size())
				for index in range(sample_count):
					var peg = game.pegs[index*2]
					game.impact_feedback.show_damage(peg.p,18.2 if index==1 else (1.5 if index==2 else 4.0),index==1)
					peg.flash = .12
				if phase=="settling": game.impact_feedback.advance(.22)
				var state = var_to_bytes(game.RunSnapshot.capture(game))
				var rng_state = game.rng.state
				game.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var picture = viewport.get_texture().get_image()
				var filename = "%s-%s-%d.png" % [area,phase,resolution.x]
				check(picture!=null and picture.get_size()==resolution,"Actual GPU rendered "+filename)
				check(picture.save_png(directory.path_join(filename))==OK,"Saved "+filename)
				check(state==var_to_bytes(game.RunSnapshot.capture(game)) and rng_state==game.rng.state,"Rendering leaves gameplay and RNG unchanged: "+filename)
				for label in game.impact_feedback.damage_labels:
					var layout = game.impact_feedback.damage_label_layout(label,game.number_font,game.reduced_motion)
					check(Rect2(40,270,640,770).encloses(layout.bounds),"Hit number fits board in "+filename)
				output_files.append(filename)
			for phase in ["peak","settled"]:
				game.mode = "home"
				game.reduced_motion = false
				game.bank = 999999999
				game.bank_coin_feedback.reset()
				game.bank_coin_feedback.observe(0,game.area_id)
				game.bank_coin_feedback.observe(game.bank,game.area_id)
				game.bank_coin_feedback.advance(.09 if phase=="peak" else .56)
				game.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var picture = viewport.get_texture().get_image()
				var filename = "%s-wallet-%s-%d.png" % [area,phase,resolution.x]
				check(picture!=null and picture.get_size()==resolution,"Actual GPU rendered "+filename)
				check(picture.save_png(directory.path_join(filename))==OK,"Saved "+filename)
				output_files.append(filename)
	check(game.persistence_attempts==0,"All preview states performed zero player profile accesses")
	var report = {"captures":output_files,"checks":checks,"failures":failures,"profile_io":game.persistence_attempts,"renderer":RenderingServer.get_video_adapter_name(),"note":"Staged gameplay at 720x1280 and450x800, not a physical-device playtest. Left Impact ball is charged; right is spent."}
	var file = FileAccess.open(directory.path_join("damage-preview-summary.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	game.free()
	viewport.free()
	print("DAMAGE_FEEDBACK_PREVIEW_RESULT passed=%d failed=%d captures=%d" % [checks-failures.size(),failures.size(),output_files.size()])
	quit(0 if failures.is_empty() else 1)
