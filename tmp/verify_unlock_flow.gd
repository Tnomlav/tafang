extends SceneTree

## Exercises the archive progress rules that gate level select, formations, and
## skills. The player save file is restored before the script exits.

const VerifyScript := preload("res://tmp/verify_common.gd")
const ArchiveState := preload("res://scripts/systems/archive_state.gd")
const StageCatalog := preload("res://scripts/systems/stage_catalog.gd")

const TITLE := "unlock flow"
const SAVE_PATH := "user://archive_unlocks.cfg"
const SKILL_UNLOCK_STAGE := 18
const CHAPTER2_BOSS_STAGE := 18
const VISIBLE_STAGE_LOOKAHEAD := 6

var verify: RefCounted
var saved_data := PackedByteArray()
var had_save := false


func _initialize() -> void:
	verify = VerifyScript.new()
	_backup_save()
	_check_fresh_save()
	_check_stage_unlocks()
	_check_character_unlocks()
	_check_skill_unlocks()
	_check_enemy_unlocks()
	_check_level_select_visibility()
	_restore_save()
	quit(verify.report(TITLE))


func _backup_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	saved_data = file.get_buffer(file.get_length())
	file.close()
	had_save = true


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_data)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check_fresh_save() -> void:
	ArchiveState.reset_progress()
	verify.check_eq(ArchiveState.get_highest_unlocked_stage(), 1, "a fresh save must unlock only stage 1")
	verify.check(ArchiveState.is_stage_unlocked(1), "stage 1 must be unlocked on a fresh save")
	verify.check(not ArchiveState.is_stage_unlocked(2), "stage 2 must stay locked on a fresh save")
	verify.check(not ArchiveState.is_stage_cleared(1), "stage 1 must not be cleared on a fresh save")
	verify.check(not ArchiveState.is_stage_unlocked(0), "stage 0 must never be unlocked")
	verify.check_eq(ArchiveState.get_save_version(), 1, "fresh saves must use the current save version")


func _check_stage_unlocks() -> void:
	ArchiveState.reset_progress()
	ArchiveState.mark_stage_cleared(1)
	verify.check(ArchiveState.is_stage_cleared(1), "clearing stage 1 must be recorded")
	verify.check(ArchiveState.is_stage_unlocked(2), "clearing stage 1 must unlock stage 2")

	ArchiveState.unlock_stage(5)
	verify.check_eq(ArchiveState.get_highest_unlocked_stage(), 5, "unlock_stage must raise the unlocked frontier")
	verify.check(ArchiveState.is_stage_unlocked(5), "stage 5 must be unlocked")
	verify.check(not ArchiveState.is_stage_unlocked(6), "stage 6 must stay locked")
	verify.check(ArchiveState.is_stage_cleared(4), "stages below the frontier count as cleared")
	verify.check(not ArchiveState.is_stage_cleared(5), "the frontier stage must not count as cleared")

	ArchiveState.unlock_stage(3)
	verify.check_eq(ArchiveState.get_highest_unlocked_stage(), 5, "unlock_stage must not lower the frontier")

	ArchiveState.reset_progress()
	ArchiveState.unlock_stage(7)
	for entry in StageCatalog.get_entries():
		var number := int(entry.get("global_stage_number", 0))
		var expected := number <= 7
		verify.check_eq(ArchiveState.is_stage_unlocked(number), expected, "unlock state of stage %d with frontier 7" % number)


func _check_character_unlocks() -> void:
	ArchiveState.reset_progress()
	verify.check(ArchiveState.is_character_unlocked("u"), "the default character must be unlocked")
	verify.check(not ArchiveState.is_character_unlocked("v"), "character v must start locked")
	verify.check(not ArchiveState.is_character_unlocked(""), "an empty character id must not be unlocked")

	ArchiveState.unlock_character("v")
	verify.check(ArchiveState.is_character_unlocked("v"), "unlock_character must unlock the character")

	ArchiveState.unlock_character("u1")
	verify.check_eq(ArchiveState.get_character_variant("u"), "u1", "the highest unlocked variant must be reported")
	verify.check_eq(ArchiveState.get_character_variant("v"), "v", "characters without variants keep their base id")

	ArchiveState.set_selected_squad(["u", "v", "u1", "missing"])
	var squad := ArchiveState.get_selected_squad()
	verify.check_eq(squad.size(), 3, "the selected squad must keep unlocked characters and drop duplicates")
	if squad.size() == 3:
		verify.check_eq(squad[0], "u", "selected squad order must be preserved")
		verify.check_eq(squad[1], "v", "selected squad must keep unlocked characters")
		verify.check_eq(squad[2], "u1", "selected squad must keep unlocked variants")

	ArchiveState.reset_progress()
	var default_squad := ArchiveState.get_selected_squad()
	verify.check_eq(default_squad.size(), 1, "a fresh save must fall back to a single squad member")
	if default_squad.size() == 1:
		verify.check_eq(default_squad[0], "u", "a fresh save must fall back to the default character")


func _check_skill_unlocks() -> void:
	ArchiveState.reset_progress()
	verify.check(not ArchiveState.is_skill_system_unlocked(), "the skill system must start locked")
	verify.check(not ArchiveState.is_character_skill_unlocked("u"), "character skills must start locked")

	ArchiveState.unlock_stage(SKILL_UNLOCK_STAGE)
	verify.check_eq(SKILL_UNLOCK_STAGE, CHAPTER2_BOSS_STAGE, "the skill system must unlock at the chapter 2 boss stage")
	verify.check(ArchiveState.is_skill_system_unlocked(), "the skill system must unlock at stage 18")
	verify.check(ArchiveState.is_character_skill_unlocked("u"), "character u skill must unlock at stage 18")
	verify.check(not ArchiveState.is_character_skill_unlocked("v"), "character v skill must stay locked at stage 18")

	ArchiveState.unlock_stage(SKILL_UNLOCK_STAGE + 1)
	verify.check(ArchiveState.is_character_skill_unlocked("v"), "character v skill must unlock at stage 19")
	verify.check(ArchiveState.is_character_skill_unlocked("u1"), "variant ids must reuse the base character skill gate")


func _check_enemy_unlocks() -> void:
	ArchiveState.reset_progress()
	verify.check(not ArchiveState.is_enemy_unlocked("a"), "enemies must start locked")
	ArchiveState.unlock_enemy("a")
	verify.check(ArchiveState.is_enemy_unlocked("a"), "unlock_enemy must unlock the enemy")
	ArchiveState.unlock_enemy("b")
	verify.check(ArchiveState.is_enemy_unlocked("1b"), "legacy enemy ids must map to the current id")


func _check_level_select_visibility() -> void:
	ArchiveState.reset_progress()
	var visible := StageCatalog.get_visible_entries(ArchiveState.get_highest_unlocked_stage() + VISIBLE_STAGE_LOOKAHEAD)
	verify.check_eq(visible.size(), 7, "level select must preview six stages beyond the unlocked frontier")
	if visible.size() == 7:
		verify.check_eq(int(visible[visible.size() - 1].get("global_stage_number", 0)), 7, "level select must stop at the preview frontier")

	ArchiveState.unlock_stage(12)
	var late_visible := StageCatalog.get_visible_entries(ArchiveState.get_highest_unlocked_stage() + VISIBLE_STAGE_LOOKAHEAD)
	verify.check(late_visible.size() <= StageCatalog.get_entries().size(), "level select must not invent entries past the catalog")
	verify.check_eq(int(late_visible[late_visible.size() - 1].get("global_stage_number", 0)), 18, "level select must reach the last catalog entry")
