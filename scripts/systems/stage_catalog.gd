extends RefCounted
class_name StageCatalog

const CATALOG_PATH := "res://resources/stages/stage_catalog.json"
const DEFAULT_CHAPTER_STAGE_COUNT := 12

static var cached_entries: Array[Dictionary] = []
static var cached_by_global_number := {}
static var cached_by_scene_path := {}
static var has_loaded := false


static func get_entries() -> Array[Dictionary]:
	_ensure_loaded()
	return cached_entries.duplicate(true)


static func get_visible_entries(highest_visible_stage: int) -> Array[Dictionary]:
	_ensure_loaded()
	var entries: Array[Dictionary] = []
	for entry in cached_entries:
		if int(entry.get("global_stage_number", 0)) <= highest_visible_stage:
			entries.append(entry.duplicate(true))
	return entries


static func get_stage_by_global_number(global_stage_number: int) -> Dictionary:
	_ensure_loaded()
	if not cached_by_global_number.has(global_stage_number):
		return {}
	return cached_by_global_number[global_stage_number].duplicate(true)


static func get_stage_by_scene_path(scene_path: String) -> Dictionary:
	_ensure_loaded()
	var normalized_path := scene_path.strip_edges()
	if cached_by_scene_path.has(normalized_path):
		return cached_by_scene_path[normalized_path].duplicate(true)
	return {}


static func get_next_playable_stage(global_stage_number: int) -> Dictionary:
	var next_entry := get_stage_by_global_number(global_stage_number + 1)
	if next_entry.is_empty() or not is_stage_playable(next_entry):
		return {}
	return next_entry


static func is_stage_development(entry: Dictionary) -> bool:
	return str(entry.get("status", "playable")) == "development"


static func is_stage_playable(entry: Dictionary) -> bool:
	if is_stage_development(entry):
		return false
	var scene_path := str(entry.get("scene_path", ""))
	var wave_data_path := str(entry.get("wave_data_path", ""))
	return ResourceLoader.exists(scene_path) and ResourceLoader.exists(wave_data_path)


static func get_reward_character(global_stage_number: int) -> String:
	var entry := get_stage_by_global_number(global_stage_number)
	return str(entry.get("reward_character", ""))


static func _ensure_loaded() -> void:
	if has_loaded:
		return

	has_loaded = true
	cached_entries.clear()
	cached_by_global_number.clear()
	cached_by_scene_path.clear()

	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open stage catalog: %s" % CATALOG_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid stage catalog JSON: %s" % CATALOG_PATH)
		return

	var stages: Array = parsed.get("stages", [])
	for raw_entry in stages:
		if not raw_entry is Dictionary:
			continue
		var entry := _normalize_entry(raw_entry)
		if entry.is_empty():
			continue
		cached_entries.append(entry)
		cached_by_global_number[int(entry["global_stage_number"])] = entry
		cached_by_scene_path[str(entry["scene_path"])] = entry

	cached_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["global_stage_number"]) < int(b["global_stage_number"])
	)


static func _normalize_entry(raw_entry: Dictionary) -> Dictionary:
	var chapter := int(raw_entry.get("chapter", 0))
	var stage := int(raw_entry.get("stage", 0))
	var global_stage_number := int(raw_entry.get("global_stage_number", 0))
	if chapter <= 0 or stage <= 0:
		return {}
	if global_stage_number <= 0:
		global_stage_number = (chapter - 1) * DEFAULT_CHAPTER_STAGE_COUNT + stage

	return {
		"chapter": chapter,
		"stage": stage,
		"global_stage_number": global_stage_number,
		"scene_path": str(raw_entry.get("scene_path", "")),
		"wave_data_path": str(raw_entry.get("wave_data_path", "")),
		"display_name": str(raw_entry.get("display_name", "%d-%d" % [chapter, stage])),
		"status": str(raw_entry.get("status", "playable")),
		"reward_character": str(raw_entry.get("reward_character", "")),
		"is_boss": bool(raw_entry.get("is_boss", false)),
		"is_tutorial": bool(raw_entry.get("is_tutorial", false)),
	}
