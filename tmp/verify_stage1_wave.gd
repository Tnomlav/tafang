extends SceneTree

## Verifies stage 1-1 wave data, its stage catalog binding, and the wave data of
## every playable stage.

const VerifyScript := preload("res://tmp/verify_common.gd")
const StageCatalog := preload("res://scripts/systems/stage_catalog.gd")

const TITLE := "stage wave data"
const STAGE1_SCENE_PATH := "res://scenes/stage/chapter01/c01_s01.tscn"
const STAGE1_WAVE_PATH := "res://resources/waves/c01_s01_wave_data.tres"

var verify: RefCounted


func _initialize() -> void:
	verify = VerifyScript.new()
	_check_stage1_wave()
	_check_playable_wave_data()
	quit(verify.report(TITLE))


func _check_stage1_wave() -> void:
	if not verify.check_resource_path(STAGE1_WAVE_PATH, "stage 1-1 wave data"):
		return

	var wave_data = load(STAGE1_WAVE_PATH)
	if not verify.check(wave_data is WaveData, "stage 1-1 wave data must load as WaveData"):
		return

	verify.check_float(wave_data.initial_deployment_cost, 5.0, "stage 1-1 initial_deployment_cost")
	verify.check_eq(wave_data.max_total_deployed_units, 6, "stage 1-1 max_total_deployed_units")
	verify.check_eq(wave_data.waves.size(), 3, "stage 1-1 wave count")
	_check_waves(wave_data, "stage 1-1")

	var entry: Dictionary = StageCatalog.get_stage_by_scene_path(STAGE1_SCENE_PATH)
	if not verify.check(not entry.is_empty(), "stage catalog must contain %s" % STAGE1_SCENE_PATH):
		return

	verify.check_eq(str(entry.get("display_name", "")), "1-1", "stage 1-1 display name")
	verify.check_eq(str(entry.get("wave_data_path", "")), STAGE1_WAVE_PATH, "stage 1-1 wave data binding")
	verify.check_eq(int(entry.get("global_stage_number", 0)), 1, "stage 1-1 global stage number")
	verify.check(StageCatalog.is_stage_playable(entry), "stage 1-1 must be playable")
	verify.check(not StageCatalog.is_stage_development(entry), "stage 1-1 must not be flagged as development")


func _check_playable_wave_data() -> void:
	var playable_count := 0
	for entry in StageCatalog.get_entries():
		if not StageCatalog.is_stage_playable(entry):
			continue
		playable_count += 1

		var label := str(entry.get("display_name", "?"))
		var wave_path := str(entry.get("wave_data_path", ""))
		if not verify.check_resource_path(wave_path, "%s wave data" % label):
			continue

		var wave_data = load(wave_path)
		if not verify.check(wave_data is WaveData, "%s wave data must load as WaveData" % label):
			continue

		verify.check(int(wave_data.max_total_deployed_units) > 0, "%s must cap the deployed unit count" % label)
		verify.check(float(wave_data.initial_deployment_cost) >= 0.0, "%s initial deployment cost must not be negative" % label)
		_check_waves(wave_data, label)

	verify.check(playable_count > 0, "stage catalog must expose at least one playable stage")


func _check_waves(wave_data: WaveData, label: String) -> void:
	if not verify.check(not wave_data.waves.is_empty(), "%s must define at least one wave" % label):
		return

	# wave_number 0 marks a parallel wave that runs alongside the numbered waves.
	var seen_main_wave_numbers := {}
	var main_wave_count := 0
	for wave in wave_data.waves:
		var wave_number := int(wave.wave_number)
		verify.check(wave_number >= 0, "%s wave numbers must not be negative" % label)
		if wave_number > 0:
			main_wave_count += 1
			verify.check(not seen_main_wave_numbers.has(wave_number), "%s must not repeat main wave number %d" % [label, wave_number])
			seen_main_wave_numbers[wave_number] = true
		verify.check(wave.wait_after_clear >= 0.0, "%s wave %d wait_after_clear must not be negative" % [label, wave_number])
		if not verify.check(not wave.entries.is_empty(), "%s wave %d must define spawn entries" % [label, wave_number]):
			continue
		for entry in wave.entries:
			_check_spawn_entry(entry, "%s wave %d" % [label, wave_number])
	verify.check(main_wave_count > 0, "%s must define at least one numbered main wave" % label)


func _check_spawn_entry(entry, label: String) -> void:
	if not verify.check(entry != null, "%s must not contain a null spawn entry" % label):
		return
	if not verify.check(entry is EnemySpawnEntry, "%s must contain EnemySpawnEntry resources" % label):
		return

	verify.check(int(entry.count) > 0, "%s spawn count must be positive" % label)
	verify.check(float(entry.interval) >= 0.0, "%s spawn interval must not be negative" % label)
	verify.check(float(entry.delay_before_start) >= 0.0, "%s delay_before_start must not be negative" % label)
	verify.check(int(entry.spawn_point_order) >= 1, "%s spawn_point_order must start at 1" % label)
	verify.check(int(entry.target_point_order) >= 1, "%s target_point_order must start at 1" % label)

	if entry.enemy_scene == null:
		verify.check(false, "%s spawn entry must reference an enemy scene" % label)
		return
	verify.check_resource_path(entry.enemy_scene.resource_path, "%s enemy scene" % label)
