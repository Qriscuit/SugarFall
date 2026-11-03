extends SceneTree
## Render the engine's static first frame through the same native stamp shader.
func _initialize(): call_deferred("run")

func run():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new(); viewport.size=Vector2i(720,1280)
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg=ColorRect.new(); bg.color=Color.WHITE; bg.size=Vector2(720,1280); viewport.add_child(bg)
	var backdrop=ShaderMaterial.new(); backdrop.shader=load("res://data/art/branding/studio_spotlight.gdshader")
	bg.material=backdrop
	var logo=TextureRect.new(); logo.texture=load("res://data/art/branding/studio_stamp.png")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material=ShaderMaterial.new(); material.shader=load("res://data/art/branding/studio_stamp.gdshader")
	logo.material=material; viewport.add_child(logo)
	for peak in [0.0,1.0]:
		var h=600.0
		logo.size=Vector2(h*301.0/855.0,h); logo.position=(Vector2(720,1280)-logo.size)*.5
		logo.pivot_offset=Vector2(logo.size.x*.5,logo.size.y); logo.scale=Vector2.ONE*(1.0+.055*peak)
		backdrop.set_shader_parameter("heartbeat",peak)
		material.set_shader_parameter("heartbeat",peak)
		await process_frame; await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image()
		var name="studio_boot.png" if peak==0 else "studio_peak.png"
		if image.save_png(output.path_join(name))!=OK: quit(3); return
	print("STUDIO_BOOT_RENDER_RESULT passed=2 failed=0")
	viewport.free(); quit()
