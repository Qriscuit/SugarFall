extends SceneTree

# Technical store exports only. Creative artwork is produced with imagegen.
# Run with Godot --headless --script <this file> -- <repository root>.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the repository root after --")
		quit(1)
		return
	var base: String = args[0].replace("\\", "/").trim_suffix("/")
	var output := base + "/concept-art/storefront-v1/exports"
	DirAccess.make_dir_recursive_absolute(output)
	var feature := Image.load_from_file(base + "/concept-art/storefront-v1/source/feature-v2.png")
	if feature == null or feature.is_empty():
		quit(1)
		return
	var original := feature.get_size()
	# Preserve aspect ratio. The 2:1 source loses only six resampled pixels at
	# each vertical edge to meet Play's fixed 1024x500 feature-graphic dimensions.
	var scaled_height := roundi(float(feature.get_height()) * 1024.0 / float(feature.get_width()))
	feature.resize(1024, scaled_height, Image.INTERPOLATE_LANCZOS)
	feature = feature.get_region(Rect2i(0, (scaled_height - 500) / 2, 1024, 500))
	feature.convert(Image.FORMAT_RGB8)
	if feature.save_png(output + "/google-play-feature-1024x500.png") != OK:
		quit(1)
		return
	var icon := Image.load_from_file(base + "/PLINKO/data/art/branding/sugarfall_icon.png")
	if icon == null or icon.is_empty() or icon.get_width() != icon.get_height():
		quit(1)
		return
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.convert(Image.FORMAT_RGBA8)
	if icon.save_png(output + "/google-play-icon-512.png") != OK:
		quit(1)
		return
	print("Store exports: feature RGB 1024x500; existing icon RGBA 512x512; source ", original)
	quit(0)
