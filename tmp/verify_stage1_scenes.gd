extends SceneTree

## Instantiates every stage scene from the catalog and verifies the nodes,
## markers, and wave data binding the stage game script relies on.

const VerifyScript := preload("res://tmp/verify_common.gd")
const StageCatalog := preload("res://scripts/systems/stage_catalog.gd")

const TITLE := "stage scenes"
const REQUIRED_NODES := ["Camera2D", "Ground_TML", "Overlay_TML", "Units", "DeployPreview", "UI"]
const GAME_SCRIPT_PATH := "res://scripts/stage/game.gd"

var verify: RefCounted


func _initialize() -> void:
	verify = VerifyScript.new()
	_run()


func _run() -> void:
	var entries := StageCatalog.get_entries()
	verify.check(not entries.is_empty(), "stage catalog must not be empty")
	verify.check(ResourceLoader.exists(GAME_SCRIPT_PATH), "stage game script must exist: %s" % GAME_SCRIPT_PATH)

	var used_game_script := false
	for entry in entries:
		var label := str(entry.get("display_name", "?"))
		var scene_path := str(entry.get("scene_path", ""))
		if not verify.check_resource_path(scene_path, "%s scene" % label):
			continue

		var packed := load(scene_path) as PackedScene
		if not verify.check(packed != null, "%s must load as PackedScene" % label):
			continue

		var instance := packed.instantiate()
		if not verify.check(instance != null, "%s must instantiate" % label):
			continue

		root.add_child(instance)
		await process_frame
		await process_frame
		if _check_instance(entry, instance):
			used_game_script = true
		instance.queue_free()
		await process_frame

	verify.check(used_game_script, "at least one stage scene must run the stage game script")
	quit(verify.report(TITLE))


func _check_instance(entry: Dictionary, instance: Node) -> bool:
	var label := str(entry.get("display_name", "?"))
	var is_playable := StageCatalog.is_stage_playable(entry)

	for node_name in REQUIRED_NODES:
		verify.check(instance.get_node_or_null(node_name) != null, "%s must contain node %s" % [label, node_name])

	var script: Script = instance.get_script()
	var has_game_script := script != null and str(script.resource_path) == GAME_SCRIPT_PATH
	verify.check(has_game_script, "%s root node must run %s" % [label, GAME_SCRIPT_PATH])

	var ground := instance.get_node_or_null("Ground_TML")
	if ground is TileMapLayer:
		verify.check(ground.get_used_cells().size() > 0, "%s ground tile map must not be empty" % label)

	var spawn_points = instance.get("enemy_spawn_points")
	var target_points = instance.get("enemy_target_points")
	var waypoint_points = instance.get("enemy_waypoint_points")
	var teleport_points = instance.get("enemy_teleport_points")

	var spawn_count: int = spawn_points.size() if spawn_points != null else 0
	var target_count: int = target_points.size() if target_points != null else 0
	var waypoint_count: int = waypoint_points.size() if waypoint_points != null else 0
	var teleport_count: int = teleport_points.size() if teleport_points != null else 0

	var wave_data = instance.get("wave_data")
	if not is_playable:
		# Development stages only ship a map draft, so markers are not required yet.
		verify.check(wave_data == null, "%s is development content and must not resolve wave data" % label)
		return has_game_script

	verify.check(spawn_count > 0, "%s must define at least one enemy spawn marker" % label)
	verify.check(target_count > 0, "%s must define at least one enemy target marker" % label)

	if not verify.check(wave_data != null, "%s must resolve its wave data on load" % label):
		return has_game_script
	if not verify.check(wave_data is WaveData, "%s wave data must be a WaveData resource" % label):
		return has_game_script

	for wave in wave_data.waves:
		for spawn_entry in wave.entries:
			verify.check(int(spawn_entry.spawn_point_order) <= spawn_count, "%s spawn_point_order %d exceeds the %d spawn markers on the map" % [label, int(spawn_entry.spawn_point_order), spawn_count])
			verify.check(int(spawn_entry.target_point_order) <= target_count, "%s target_point_order %d exceeds the %d target markers on the map" % [label, int(spawn_entry.target_point_order), target_count])
			for order in spawn_entry.waypoint_orders:
				verify.check(int(order) >= 1 and int(order) <= waypoint_count, "%s waypoint order %d must be within the %d waypoints on the map" % [label, int(order), waypoint_count])
			if not spawn_entry.teleport_pairs.is_empty():
				verify.check(teleport_count > 0, "%s uses teleport pairs but the map has no teleport markers" % label)
			for pair in spawn_entry.teleport_pairs:
				var teleport_pair: Vector2i = pair
				verify.check(teleport_pair.x >= 1 and teleport_pair.x <= teleport_count, "%s teleport pair index %d must be within the %d teleport markers on the map" % [label, teleport_pair.x, teleport_count])
				verify.check(teleport_pair.y >= 1 and teleport_pair.y <= teleport_count, "%s teleport pair index %d must be within the %d teleport markers on the map" % [label, teleport_pair.y, teleport_count])

	return has_game_script
