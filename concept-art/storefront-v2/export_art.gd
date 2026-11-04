extends SceneTree

# Format conversion and aspect-preserving store-size exports only.
# All illustration/composition is authored by image_gen, never by this script.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass the absolute repository root after --")
		quit(1)
		return
	var base: String = args[0].replace("\\", "/").trim_suffix("/") + "/concept-art/storefront-v2"
	DirAccess.make_dir_recursive_absolute(base + "/exports")
	var icon := Image.load_from_file(base + "/source/mabel-icon.png")
	var feature := Image.load_from_file(base + "/source/mabel-feature.png")
	if icon == null or feature == null or icon.is_empty() or feature.is_empty():
		push_error("Missing generated icon or feature artwork")
		quit(1)
		return
	if icon.get_width() != icon.get_height():
		push_error("Icon source must be square")
		quit(1)
		return
	var feature_source := feature.get_size()
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.convert(Image.FORMAT_RGBA8)
	if icon.save_png(base + "/exports/google-play-icon-512.png") != OK:
		quit(1)
		return
	# Cover the required rectangle without stretching. Only centered edge trim.
	var scale_factor := maxf(1024.0 / feature.get_width(), 500.0 / feature.get_height())
	var scaled := Vector2i(ceili(feature.get_width() * scale_factor), ceili(feature.get_height() * scale_factor))
	feature.resize(scaled.x, scaled.y, Image.INTERPOLATE_LANCZOS)
	feature = feature.get_region(Rect2i((scaled.x - 1024) / 2, (scaled.y - 500) / 2, 1024, 500))
	feature.convert(Image.FORMAT_RGB8)
	if feature.save_png(base + "/exports/google-play-feature-1024x500.png") != OK:
		quit(1)
		return
	print("Store exports: icon RGBA 512x512; feature RGB 1024x500; feature source ", feature_source, " scaled ", scaled)
	quit(0)
