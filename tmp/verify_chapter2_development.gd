extends SceneTree

## Verifies the chapter 2 rollout policy: stages ship as map drafts until their
## wave data exists, and progression stops before development-only stages.

const VerifyScript := preload("res://tmp/verify_common.gd")
const StageCatalog := preload("res://scripts/systems/stage_catalog.gd")

const TITLE := "chapter 2 development"
const ARCHIVE_STATE_PATH := "res://scripts/systems/archive_state.gd"
const CHAPTER := 2
const CHAPTER_STAGE_COUNT := 12
const FIRST_CHAPTER2_STAGE := 13
const DEVELOPMENT_STAGE := 18
const CHAPTER2_BOSS_STAGE := 18
const SKILL_UNLOCK_STAGE := 18

var verify: RefCounted


func _initialize() -> void:
	verify = VerifyScript.new()
	_check_status_consistency()
	_check_chapter2_entries()
	_check_progression_stops()
	quit(verify.report(TITLE))


func _check_status_consistency() -> void:
	for entry in StageCatalog.get_entries():
		var label := str(entry.get("display_name", "?"))
		var status := str(entry.get("status", ""))
		var scene_path := str(entry.get("scene_path", ""))
		var wave_path := str(entry.get("wave_data_path", ""))
		var scene_exists := FileAccess.file_exists(scene_path)
		var wave_exists := not wave_path.is_empty() and FileAccess.file_exists(wave_path)

		verify.check(status == "playable" or status == "development", "%s has an unknown status '%s'" % [label, status])
		if status == "playable":
			verify.check(scene_exists, "%s is playable but its scene is missing" % label)
			verify.check(wave_exists, "%s is playable but its wave data is missing" % label)
			verify.check(StageCatalog.is_stage_playable(entry), "%s must report as playable" % label)
		else:
			verify.check(not wave_exists, "%s is development but still ships wave data" % label)
			verify.check(wave_path.is_empty(), "%s is development but keeps a wave data path" % label)
			verify.check(not StageCatalog.is_stage_playable(entry), "%s must not report as playable" % label)
			verify.check(StageCatalog.is_stage_development(entry), "%s must report as development" % label)


func _check_chapter2_entries() -> void:
	var chapter2_entries: Array = []
	for entry in StageCatalog.get_entries():
		if int(entry.get("chapter", 0)) == CHAPTER:
			chapter2_entries.append(entry)

	if not verify.check(not chapter2_entries.is_empty(), "the catalog must expose chapter 2 entries"):
		return

	var expected_stage := 1
	for entry in chapter2_entries:
		var label := str(entry.get("display_name", "?"))
		var stage := int(entry.get("stage", 0))
		verify.check_eq(stage, expected_stage, "chapter 2 stage numbers must be contiguous at %s" % label)
		verify.check_eq(int(entry.get("global_stage_number", 0)), FIRST_CHAPTER2_STAGE + stage - 1, "%s global stage number" % label)
		verify.check_resource_path(str(entry.get("scene_path", "")), "%s scene" % label)
		if StageCatalog.is_stage_playable(entry):
			verify.check_resource_path(str(entry.get("wave_data_path", "")), "%s wave data" % label)
		expected_stage += 1

	var development_entry := StageCatalog.get_stage_by_global_number(DEVELOPMENT_STAGE)
	if not verify.check(not development_entry.is_empty(), "the chapter 2 boss gate must exist in the catalog"):
		return

	verify.check_eq(str(development_entry.get("display_name", "")), "2-6", "the development stage must be 2-6")
	verify.check(StageCatalog.is_stage_development(development_entry), "2-6 must stay a development stage")
	verify.check(not StageCatalog.is_stage_playable(development_entry), "2-6 must not be enterable")
	verify.check_eq(str(development_entry.get("wave_data_path", "")), "", "2-6 must not reference wave data")
	verify.check(bool(development_entry.get("is_boss", false)), "2-6 must stay flagged as the chapter 2 boss gate")

	var archive_script: GDScript = load(ARCHIVE_STATE_PATH)
	var constants := archive_script.get_script_constant_map()
	verify.check_eq(int(constants.get("SKILL_SYSTEM_UNLOCK_STAGE", -1)), DEVELOPMENT_STAGE, "the skill system must stay gated behind the chapter 2 boss stage")
	var character_skill_stages: Dictionary = constants.get("CHARACTER_SKILL_UNLOCK_STAGES", {})
	verify.check(not character_skill_stages.is_empty(), "character skill gates must stay configured")
	for character_id in character_skill_stages:
		var unlock_stage := int(character_skill_stages[character_id])
		verify.check(unlock_stage >= DEVELOPMENT_STAGE, "character %s skill gate must not unlock before the chapter 2 boss stage" % str(character_id))
		verify.check(unlock_stage <= CHAPTER_STAGE_COUNT * 2, "character %s skill gate must stay inside chapter 2" % str(character_id))
	verify.check_eq(SKILL_UNLOCK_STAGE, CHAPTER2_BOSS_STAGE, "the documented skill unlock stage must stay consistent")

	verify.check_eq(CHAPTER_STAGE_COUNT, 12, "the catalog must keep twelve stages per chapter")


func _check_progression_stops() -> void:
	var last_playable := StageCatalog.get_next_playable_stage(FIRST_CHAPTER2_STAGE)
	if verify.check(not last_playable.is_empty(), "progression from 2-1 must continue inside chapter 2"):
		verify.check_eq(int(last_playable.get("global_stage_number", 0)), 14, "progression from 2-1 must lead to 2-2")

	verify.check(StageCatalog.get_next_playable_stage(DEVELOPMENT_STAGE - 1).is_empty(), "progression must stop before the development stage")
	verify.check(StageCatalog.get_next_playable_stage(DEVELOPMENT_STAGE).is_empty(), "the development stage must not lead anywhere")
