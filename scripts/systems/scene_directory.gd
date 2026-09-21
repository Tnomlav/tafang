extends RefCounted

## Helpers for listing scene files inside a project directory.
##
## Exported builds convert text resources to their binary form and list them
## with a ".remap" suffix (for example "u.tscn.remap"), so a directory scan must
## normalize file names instead of comparing against ".tscn" directly.

const SCENE_SUFFIX := ".tscn"
const REMAP_SUFFIX := ".remap"


static func list_scene_file_names(directory_path: String) -> Array[String]:
	var scene_file_names: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return scene_file_names

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			var scene_file_name := normalize_scene_file_name(file_name)
			if not scene_file_name.is_empty() and not scene_file_names.has(scene_file_name):
				scene_file_names.append(scene_file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	scene_file_names.sort()
	return scene_file_names


static func normalize_scene_file_name(file_name: String) -> String:
	var normalized_file_name := file_name.strip_edges()
	if normalized_file_name.ends_with(REMAP_SUFFIX):
		normalized_file_name = normalized_file_name.trim_suffix(REMAP_SUFFIX)
	if not normalized_file_name.ends_with(SCENE_SUFFIX):
		return ""
	return normalized_file_name
