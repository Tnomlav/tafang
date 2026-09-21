extends Node

const SAVE_PATH := "user://archive_unlocks.cfg"
const META_SECTION := "meta"
const ENEMY_SECTION := "enemies"
const CHARACTER_SECTION := "characters"
const CLEARED_STAGE_SECTION := "cleared_stages"
const FORMATION_SECTION := "formation"
const PROGRESS_SECTION := "progress"
const SAVE_VERSION_KEY := "save_version"
const SELECTED_SQUAD_KEY := "selected_squad"
const TARGET_STAGE_KEY := "target_stage"
const LAST_ENTERED_STAGE_KEY := "last_entered_stage"
const HIGHEST_UNLOCKED_STAGE_KEY := "highest_unlocked_stage"
const CURRENT_SAVE_VERSION := 1
const DEFAULT_CHARACTER_ID := "u"
const STARTER_CHARACTER_ID := DEFAULT_CHARACTER_ID
const STARTER_GIFT_KEY := "starter_gift"
const DEFAULT_UNLOCKED_STAGE := 1
const SKILL_SYSTEM_UNLOCK_STAGE := 18 # Chapter 2 stage 6.
const CHARACTER_SKILL_UNLOCK_STAGES := {
	"u": 18,
	"v": 19,
	"w": 20,
	"x": 21,
	"y": 22,
	"z": 23,
}
const LEGACY_ENEMY_ID_MAP := {
	"1a": "a",
	"1b": "b",
	"1c": "c",
	"1d": "d",
	"1e": "e",
	"1f": "f",
}


static func reset_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


static func unlock_enemy(enemy_id: String) -> void:
	_unlock_id(ENEMY_SECTION, enemy_id)


static func unlock_character(character_id: String) -> void:
	_unlock_id(CHARACTER_SECTION, character_id)


## Grants the starter character the first time the player enters the game and
## reports it so the caller can announce the gift. Returns "" when the starter
## character was already granted for this save.
static func claim_starter_character() -> String:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error == OK and bool(config.get_value(META_SECTION, STARTER_GIFT_KEY, false)):
		return ""

	_prepare_config_for_save(config)
	config.set_value(META_SECTION, STARTER_GIFT_KEY, true)
	config.set_value(CHARACTER_SECTION, STARTER_CHARACTER_ID, true)
	config.save(SAVE_PATH)
	return STARTER_CHARACTER_ID


static func has_claimed_starter_character() -> bool:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return false

	return bool(config.get_value(META_SECTION, STARTER_GIFT_KEY, false))


static func get_character_variant(base_id: String) -> String:
	var normalized_base := _normalize_id(base_id)
	if normalized_base.is_empty():
		return ""

	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return normalized_base

	var best_id := normalized_base
	var best_level := 0
	for key in config.get_section_keys(CHARACTER_SECTION):
		var candidate := str(key).to_lower()
		if not candidate.begins_with(normalized_base):
			continue
		var suffix := candidate.substr(normalized_base.length())
		if suffix.is_empty() or not suffix.is_valid_int():
			continue
		if not bool(config.get_value(CHARACTER_SECTION, key, false)):
			continue
		var level := suffix.to_int()
		if level > best_level:
			best_level = level
			best_id = candidate

	return best_id


static func unlock_stage(stage_number: int) -> void:
	if stage_number <= DEFAULT_UNLOCKED_STAGE:
		return

	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	var highest_unlocked_stage := int(config.get_value(PROGRESS_SECTION, HIGHEST_UNLOCKED_STAGE_KEY, DEFAULT_UNLOCKED_STAGE))
	if stage_number <= highest_unlocked_stage:
		return

	config.set_value(PROGRESS_SECTION, HIGHEST_UNLOCKED_STAGE_KEY, stage_number)
	config.save(SAVE_PATH)


static func mark_stage_cleared(stage_number: int) -> void:
	if stage_number <= 0:
		return

	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	config.set_value(CLEARED_STAGE_SECTION, str(stage_number), true)
	config.save(SAVE_PATH)


static func get_highest_unlocked_stage() -> int:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return DEFAULT_UNLOCKED_STAGE

	return maxi(int(config.get_value(PROGRESS_SECTION, HIGHEST_UNLOCKED_STAGE_KEY, DEFAULT_UNLOCKED_STAGE)), DEFAULT_UNLOCKED_STAGE)


static func is_skill_system_unlocked() -> bool:
	return get_highest_unlocked_stage() >= SKILL_SYSTEM_UNLOCK_STAGE


static func is_character_skill_unlocked(character_id: String) -> bool:
	var normalized_id := _normalize_id(character_id)
	while not normalized_id.is_empty() and normalized_id.right(1).is_valid_int():
		normalized_id = normalized_id.substr(0, normalized_id.length() - 1)
	var unlock_stage := int(CHARACTER_SKILL_UNLOCK_STAGES.get(normalized_id, 999999))
	return get_highest_unlocked_stage() >= unlock_stage


static func is_stage_unlocked(stage_number: int) -> bool:
	if stage_number <= 0:
		return false

	if stage_number <= get_highest_unlocked_stage():
		return true

	return is_stage_cleared(stage_number - 1)


static func is_stage_cleared(stage_number: int) -> bool:
	if stage_number <= 0:
		return false

	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error == OK and bool(config.get_value(CLEARED_STAGE_SECTION, str(stage_number), false)):
		return true

	return stage_number < get_highest_unlocked_stage()


static func is_character_unlocked(character_id: String) -> bool:
	var normalized_id := _normalize_id(character_id)
	if normalized_id.is_empty():
		return false
	if normalized_id == DEFAULT_CHARACTER_ID:
		return true

	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return false

	if bool(config.get_value(CHARACTER_SECTION, normalized_id, false)):
		return true
	for key in config.get_section_keys(CHARACTER_SECTION):
		var candidate := str(key).to_lower()
		if candidate.begins_with(normalized_id) and candidate.substr(normalized_id.length()).is_valid_int() and bool(config.get_value(CHARACTER_SECTION, key, false)):
			return true
	return false


static func set_selected_squad(character_ids: Array) -> void:
	var normalized_ids: Array[String] = []
	for character_id in character_ids:
		var normalized_id := _normalize_id(character_id)
		if normalized_id.is_empty():
			continue
		if normalized_ids.has(normalized_id):
			continue
		if not is_character_unlocked(normalized_id):
			continue
		normalized_ids.append(normalized_id)

	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	config.set_value(FORMATION_SECTION, SELECTED_SQUAD_KEY, normalized_ids)
	config.save(SAVE_PATH)


static func get_selected_squad() -> Array[String]:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return [DEFAULT_CHARACTER_ID]
	if not config.has_section_key(FORMATION_SECTION, SELECTED_SQUAD_KEY):
		return [DEFAULT_CHARACTER_ID]

	var raw_value = config.get_value(FORMATION_SECTION, SELECTED_SQUAD_KEY, [])
	var selected: Array[String] = []
	for character_id in raw_value:
		var normalized_id := _normalize_id(str(character_id))
		if normalized_id.is_empty():
			continue
		if selected.has(normalized_id):
			continue
		if not is_character_unlocked(normalized_id):
			continue
		selected.append(normalized_id)

	return selected


static func set_target_stage_path(stage_path: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	config.set_value(FORMATION_SECTION, TARGET_STAGE_KEY, stage_path)
	config.save(SAVE_PATH)


static func get_target_stage_path() -> String:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return ""

	return str(config.get_value(FORMATION_SECTION, TARGET_STAGE_KEY, ""))


static func set_last_entered_stage_path(stage_path: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	config.set_value(PROGRESS_SECTION, LAST_ENTERED_STAGE_KEY, stage_path)
	config.save(SAVE_PATH)


static func get_last_entered_stage_path() -> String:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return ""

	return str(config.get_value(PROGRESS_SECTION, LAST_ENTERED_STAGE_KEY, ""))


static func _unlock_id(section: String, id: String) -> void:
	var normalized_id := _normalize_id(id)
	if normalized_id.is_empty():
		return

	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	if bool(config.get_value(section, normalized_id, false)):
		return

	config.set_value(section, normalized_id, true)
	config.save(SAVE_PATH)


static func is_enemy_unlocked(enemy_id: String) -> bool:
	var normalized_id := _normalize_id(enemy_id)
	if normalized_id.is_empty():
		return false

	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return false

	if bool(config.get_value(ENEMY_SECTION, normalized_id, false)):
		return true
	if LEGACY_ENEMY_ID_MAP.has(normalized_id):
		return bool(config.get_value(ENEMY_SECTION, str(LEGACY_ENEMY_ID_MAP[normalized_id]), false))
	return false


static func _normalize_id(id: String) -> String:
	return id.strip_edges().to_lower()


static func ensure_initialized() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_prepare_config_for_save(config)
	config.save(SAVE_PATH)


static func get_save_version() -> int:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return CURRENT_SAVE_VERSION
	return int(config.get_value(META_SECTION, SAVE_VERSION_KEY, CURRENT_SAVE_VERSION))


static func _prepare_config_for_save(config: ConfigFile) -> void:
	var saved_version := int(config.get_value(META_SECTION, SAVE_VERSION_KEY, 0))
	if saved_version <= 0:
		config.set_value(META_SECTION, SAVE_VERSION_KEY, CURRENT_SAVE_VERSION)
	elif saved_version < CURRENT_SAVE_VERSION:
		_migrate_config(config, saved_version, CURRENT_SAVE_VERSION)

	if not config.has_section_key(PROGRESS_SECTION, HIGHEST_UNLOCKED_STAGE_KEY):
		config.set_value(PROGRESS_SECTION, HIGHEST_UNLOCKED_STAGE_KEY, DEFAULT_UNLOCKED_STAGE)
	if not config.has_section_key(CHARACTER_SECTION, DEFAULT_CHARACTER_ID):
		config.set_value(CHARACTER_SECTION, DEFAULT_CHARACTER_ID, true)
	if not config.has_section_key(FORMATION_SECTION, SELECTED_SQUAD_KEY):
		config.set_value(FORMATION_SECTION, SELECTED_SQUAD_KEY, [DEFAULT_CHARACTER_ID])


static func _migrate_config(config: ConfigFile, _from_version: int, to_version: int) -> void:
	config.set_value(META_SECTION, SAVE_VERSION_KEY, to_version)
