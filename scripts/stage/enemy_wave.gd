extends Resource
class_name EnemyWave

@export var wave_number := 1
@export var entries: Array[EnemySpawnEntry] = []
@export_range(0.0, 60.0, 0.1) var wait_after_clear := 3.0
