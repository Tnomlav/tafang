extends Resource
class_name EnemySpawnEntry

@export var enemy_scene: PackedScene
@export_range(0, 1, 1) var enemy_type := 0
@export_range(1, 999, 1) var count := 1
@export_range(1, 999, 1) var spawn_point_order := 1
@export_range(1, 999, 1) var target_point_order := 1
@export var waypoint_orders: Array[int] = []
@export var waypoint_waits: Dictionary = {}
@export var waypoint_wait_durations: Array[float] = []
@export var teleport_pairs: Array[Vector2i] = []
@export var teleport_waits: Array[float] = []
@export_range(0.0, 60.0, 0.1) var delay_before_start := 0.0
@export_range(0.0, 60.0, 0.1) var interval := 1.0
@export var override_move_speed := false
@export_range(0.0, 20.0, 0.1) var move_speed_tiles_per_second := 1.0
