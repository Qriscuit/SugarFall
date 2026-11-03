extends RefCounted
## Loads explicitly named textures once. Pixel bounds are authored metadata,
## never inferred during drawing or used to alter collision geometry.

const CRYSTAL_ROOT = "res://data/art/crystal/"

static func read_set(root: String, names: Array, shared_damage_frames: bool = false, atlas_entries: bool = false) -> Dictionary:
	var result = {"textures":{},"regions":{},"complete":false}
	var path = root+"regions.json"
	if not FileAccess.file_exists(path): return result
	var bounds = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bounds is Dictionary: return result
	# Atlas metadata is explicit and confined to Crystal's native source art.
	# Existing area metadata keeps its original per-file lookup and crop behavior.
	if atlas_entries and not root.begins_with(CRYSTAL_ROOT): return result
	var texture_cache: Dictionary = {}
	for name in names:
		var source_name: String = str(name).get_slice("_damage_",0) if shared_damage_frames else str(name)
		var uv = bounds.get(source_name)
		var texture_path = root+str(name)+".png"
		if atlas_entries:
			var entry = bounds.get(str(name))
			if not entry is Dictionary: continue
			texture_path = str(entry.get("texture",""))
			if not texture_path.begins_with(CRYSTAL_ROOT) or ".." in texture_path or not texture_path.ends_with(".png"): continue
			uv = entry.get("uv")
		if not valid_bounds(uv): continue
		if not ResourceLoader.exists(texture_path): continue
		if not texture_cache.has(texture_path): texture_cache[texture_path] = load(texture_path) as Texture2D
		var texture = texture_cache[texture_path] as Texture2D
		if texture == null: continue
		result.textures[name] = texture
		result.regions[name] = Rect2(Vector2(uv[0],uv[1])*texture.get_size(),Vector2(uv[2],uv[3])*texture.get_size())
	result.complete = result.textures.size()==names.size()
	return result

static func valid_bounds(value) -> bool:
	if not value is Array or value.size()!=4: return false
	for part in value:
		if typeof(part) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(part)): return false
	return value[0]>=0 and value[1]>=0 and value[2]>0 and value[3]>0 and value[0]+value[2]<=1.00001 and value[1]+value[3]<=1.00001
