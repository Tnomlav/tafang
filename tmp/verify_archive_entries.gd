extends SceneTree

## Verifies the stage catalog structure that the archive and level select screens
## read, and that the archive screen builds one entry per unit scene.

const VerifyScript := preload("res://tmp/verify_common.gd")
const StageCatalog := preload("res://scripts/systems/stage_catalog.gd")

const TITLE := "archive entries"
const ARCHIVE_SCENE_PATH := "res://scenes/screens/archive.tscn"
const CHARACTER_SCENE_DIR := "res://scenes/units/characters"
const ENEMY_SCENE_DIR := "res://scenes/units/enemies"
const ENEMY_SCENE_PREFIX := "enemy_"
const VARIANT_ID_PATTERN := "^[a-z]+[0-9]+$"
const CHAPTER_STAGE_COUNT := 12
const SCENE_PATH_FORMAT := "res://scenes/stage/chapter%02d/c%02d_s%02d.tscn"
const WAVE_PATH_FORMAT := "res://resources/waves/c%02d_s%02d_wave_data.tres"

var verify: RefCounted


func _initialize() -> void:
	verify = VerifyScript.new()
	_check_catalog_entries()
	_run()


func _run() -> void:
	await _check_archive_screen()
	quit(verify.report(TITLE))


func _check_catalog_entries() -> void:
	var entries := StageCatalog.get_entries()
	if not verify.check(not entries.is_empty(), "stage catalog must not be empty"):
		return

	var seen_numbers := {}
	var previous_number := 0
	for entry in entries:
		var chapter := int(entry.get("chapter", 0))
		var stage := int(entry.get("stage", 0))
		var number := int(entry.get("global_stage_number", 0))
		var label := str(entry.get("display_name", "?"))

		verify.check(chapter >= 1, "%s must belong to a chapter" % label)
		verify.check(stage >= 1, "%s must have a stage number" % label)
		verify.check_eq(number, (chapter - 1) * CHAPTER_STAGE_COUNT + stage, "%s global stage number" % label)
		verify.check_eq(label, "%d-%d" % [chapter, stage], "%s display name" % label)
		verify.check(number > previous_number, "%s must be sorted after global stage %d" % [label, previous_number])
		verify.check(not seen_numbers.has(number), "%s must not repeat global stage %d" % [label, number])
		seen_numbers[number] = true
		previous_number = number

		var scene_path := str(entry.get("scene_path", ""))
		verify.check_eq(scene_path, SCENE_PATH_FORMAT % [chapter, chapter, stage], "%s scene path" % label)
		verify.check_resource_path(scene_path, "%s scene" % label)

		var wave_path := str(entry.get("wave_data_path", ""))
		if not wave_path.is_empty():
			verify.check_eq(wave_path, WAVE_PATH_FORMAT % [chapter, stage], "%s wave data path" % label)

		var reward_character := str(entry.get("reward_character", ""))
		if not reward_character.is_empty():
			var reward_path := "%s/%s.tscn" % [CHARACTER_SCENE_DIR, reward_character]
			verify.check_resource_path(reward_path, "%s reward character %s" % [label, reward_character])

	verify.check(entries.size() == seen_numbers.size(), "stage catalog must not contain duplicate entries")


func _check_archive_screen() -> void:
	if not verify.check_resource_path(ARCHIVE_SCENE_PATH, "archive screen"):
		return

	var packed := load(ARCHIVE_SCENE_PATH) as PackedScene
	if not verify.check(packed != null, "archive screen must load as PackedScene"):
		return

	var instance := packed.instantiate()
	if not verify.check(instance != null, "archive screen must instantiate"):
		return

	root.add_child(instance)
	await process_frame
	await process_frame

	var character_entries = instance.get("character_entries")
	var enemy_entries = instance.get("enemy_entries")

	if verify.check(character_entries != null, "archive screen must expose character entries"):
		var expected_character_ids := _expected_character_ids()
		var actual_character_ids: Array = []
		for entry in character_entries:
			actual_character_ids.append(str(entry.get("id", "")))
		actual_character_ids.sort()
		verify.check_eq(actual_character_ids, expected_character_ids, "archive character entry ids")
		for entry in character_entries:
			var entry_id := str(entry.get("id", ""))
			verify.check_resource_path(str(entry.get("scene", "")), "archive entry scene for %s" % entry_id)

	if verify.check(enemy_entries != null, "archive screen must expose enemy entries"):
		var expected_enemy_ids := _expected_enemy_ids()
		var actual_enemy_ids: Array = []
		for entry in enemy_entries:
			actual_enemy_ids.append(str(entry.get("id", "")))
			verify.check(entry.has("is_boss"), "archive enemy entry %s must expose is_boss" % str(entry.get("id", "")))
		actual_enemy_ids.sort()
		verify.check_eq(actual_enemy_ids, expected_enemy_ids, "archive enemy entry ids")

	instance.queue_free()
	await process_frame


func _expected_character_ids() -> Array:
	var files: Array = []
	verify.collect_files(CHARACTER_SCENE_DIR, ".tscn", files)
	var variant_pattern := RegEx.create_from_string(VARIANT_ID_PATTERN)
	var ids: Array = []
	for file in files:
		var entry_id := str(file).get_file().get_basename().to_lower()
		if variant_pattern.search(entry_id) == null:
			ids.append(entry_id)
	ids.sort()
	return ids


func _expected_enemy_ids() -> Array:
	var files: Array = []
	verify.collect_files(ENEMY_SCENE_DIR, ".tscn", files)
	var ids: Array = []
	for file in files:
		var base_name := str(file).get_file().get_basename().to_lower()
		if base_name.begins_with(ENEMY_SCENE_PREFIX):
			ids.append(base_name.trim_prefix(ENEMY_SCENE_PREFIX))
	ids.sort()
	return ids
