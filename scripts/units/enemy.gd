extends CharacterBody2D

signal defeated(enemy_id: String)
signal reached_target(enemy_id: String)

const CAN_NOT_BE_BLOCKED := 0
const CAN_BE_BLOCKED := 1
const HIT_FLASH_COLOR := Color(1.0, 0.05, 0.05, 0.85)
const HIT_FLASH_AMOUNT := 0.9
const HIT_FLASH_FRAMES := 3
const SLOW_TINT_COLOR := Color(0.2, 0.55, 1.0, 0.85)
const SLOW_TINT_AMOUNT := 0.45
const ENEMY_SPRITE_Z := 0
const ENEMY_HEALTH_BAR_Z := 2
const BOSS_HEALTH_BAR_SCALE := 1.3
const NORMAL_HEALTH_FILL_COLOR := Color(1, 1, 1, 1)
const BOSS_HEALTH_FILL_COLOR := Color(0.45, 0.0, 0.0, 1)

@export_category("Identity")
@export var enemy_id := "A"

@export_category("Combat")
@export var max_health := 1
@export var attack_power := 1
@export var attack_speed := 1.0
@export var attack_distance_tiles := 1.0
@export var taunt_level := 0
@export var incoming_damage_reduction := 0
@export var half_health_attack_speed_multiplier := 1.0
@export var half_health_move_speed_multiplier := 1.0
@export var half_health_attack_power_bonus := 0
@export_range(1, 99, 1) var attack_target_count := 1
@export_range(0.0, 99.0, 0.1) var splash_damage_radius_tiles := 0.0
@export_multiline var skill_description := ""
@export var attack_stun_duration := 0.0
@export var is_boss := false

@export_category("Movement")
@export var move_speed_tiles_per_second := 1.0:
	set(value):
		move_speed_tiles_per_second = maxf(value, 0.0)
		_update_move_speed()

@export_category("Blocking")
@export_range(0, 1, 1) var can_be_blocked := CAN_BE_BLOCKED

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health_bar: Node2D = $HealthBar
@onready var health_back: Sprite2D = $HealthBar/Back
@onready var health_fill: Sprite2D = $HealthBar/Fill

var health := max_health
var is_defeated := false
var target_position := Vector2.ZERO
var has_target := false
var path_points: Array[Vector2] = []
var path_point_index := 0
var path_point_waits: Dictionary = {}
var path_point_teleports: Dictionary = {}
var path_wait_remaining := 0.0
var skip_path_point_after_wait := false
var teleport_remaining := 0.0
var teleport_exit_position := Vector2.ZERO
var is_teleporting := false
var tile_size := Vector2(32, 32)
var move_speed := 32.0
var speed_modifiers: Dictionary = {}
var speed_modifier_versions: Dictionary = {}
var blocker: Node
var hit_flash_material: ShaderMaterial
var hit_flash_version := 0
var attack_stop_remaining := 0.0
var stun_remaining := 0.0


func _ready() -> void:
	health = max_health
	_configure_render_order()
	_configure_health_bar_ticks()
	_update_move_speed()
	_update_health_bar_style()
	_update_health_bar()
	sprite.play("active")


func _physics_process(delta: float) -> void:
	if is_defeated or get_tree().paused or not has_target or is_blocked():
		velocity = Vector2.ZERO
		return
	if stun_remaining > 0.0:
		stun_remaining = maxf(stun_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		return
	if attack_stop_remaining > 0.0:
		attack_stop_remaining = maxf(attack_stop_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		return
	if is_teleporting:
		teleport_remaining = maxf(teleport_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		if teleport_remaining <= 0.0:
			_finish_teleport()
		return
	if path_wait_remaining > 0.0:
		path_wait_remaining = maxf(path_wait_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		if path_wait_remaining <= 0.0 and skip_path_point_after_wait:
			skip_path_point_after_wait = false
			if not _move_to_next_path_point():
				has_target = false
				reached_target.emit(enemy_id)
				queue_free()
		return

	var offset := target_position - global_position
	var distance := offset.length()
	var step_distance := move_speed * delta
	if distance <= maxf(step_distance, 0.25):
		var should_snap_to_target := _should_snap_to_current_path_point()
		if should_snap_to_target:
			global_position = target_position
		if not _advance_to_next_path_point(not should_snap_to_target):
			has_target = false
			velocity = Vector2.ZERO
			reached_target.emit(enemy_id)
			queue_free()
		return

	velocity = offset / distance * move_speed
	global_position += velocity * delta


func set_target_position(value: Vector2) -> void:
	path_points.clear()
	path_point_waits.clear()
	path_point_teleports.clear()
	path_wait_remaining = 0.0
	skip_path_point_after_wait = false
	teleport_remaining = 0.0
	is_teleporting = false
	visible = true
	path_point_index = 0
	target_position = value
	has_target = true


func set_path_points(value: Array[Vector2], waits := {}, teleports := {}) -> void:
	path_points = value.duplicate()
	path_point_waits = waits.duplicate()
	path_point_teleports = teleports.duplicate()
	path_wait_remaining = 0.0
	skip_path_point_after_wait = false
	teleport_remaining = 0.0
	is_teleporting = false
	visible = true
	path_point_index = 0
	if path_points.is_empty():
		has_target = false
		return
	target_position = path_points[0]
	has_target = true


func _advance_to_next_path_point(skip_current_after_wait := false) -> bool:
	if path_points.is_empty():
		return false

	if path_point_teleports.has(path_point_index):
		var teleport_data: Dictionary = path_point_teleports[path_point_index]
		path_point_teleports.erase(path_point_index)
		_start_teleport(teleport_data)
		return true

	var wait_duration := maxf(float(path_point_waits.get(path_point_index, 0.0)), 0.0)
	if wait_duration > 0.0:
		path_point_waits.erase(path_point_index)
		path_wait_remaining = wait_duration
		skip_path_point_after_wait = skip_current_after_wait
		velocity = Vector2.ZERO
		return true

	return _move_to_next_path_point()


func _move_to_next_path_point() -> bool:
	path_point_index += 1
	if path_point_index >= path_points.size():
		return false

	target_position = path_points[path_point_index]
	return true


func _should_snap_to_current_path_point() -> bool:
	if path_points.is_empty():
		return true
	if path_point_index < 0 or path_point_index >= path_points.size():
		return true
	if path_point_teleports.has(path_point_index):
		return false

	var wait_duration := maxf(float(path_point_waits.get(path_point_index, 0.0)), 0.0)
	return wait_duration <= 0.0


func _start_teleport(teleport_data: Dictionary) -> void:
	clear_blocker()
	teleport_exit_position = Vector2(teleport_data.get("exit_position", global_position))
	teleport_remaining = maxf(float(teleport_data.get("wait", 0.0)), 0.0)
	is_teleporting = true
	visible = false
	velocity = Vector2.ZERO
	if teleport_remaining <= 0.0:
		_finish_teleport()


func _finish_teleport() -> void:
	global_position = teleport_exit_position
	is_teleporting = false
	teleport_remaining = 0.0
	visible = true
	path_point_index += 1
	if path_point_index >= path_points.size():
		has_target = false
		velocity = Vector2.ZERO
		reached_target.emit(enemy_id)
		queue_free()
		return

	target_position = path_points[path_point_index]


func set_tile_size(value: Vector2) -> void:
	tile_size = value
	_update_move_speed()


func _update_move_speed() -> void:
	var half_health_multiplier := half_health_move_speed_multiplier if _is_below_half_health() else 1.0
	move_speed = move_speed_tiles_per_second * tile_size.x * half_health_multiplier * get_speed_multiplier()


func add_slow_modifier(source_id: StringName, percent: float) -> int:
	return set_speed_modifier(source_id, 1.0 - percent)


func add_haste_modifier(source_id: StringName, percent: float) -> int:
	return set_speed_modifier(source_id, 1.0 + percent)


func set_speed_modifier(source_id: StringName, multiplier: float) -> int:
	var version := int(speed_modifier_versions.get(source_id, 0)) + 1
	speed_modifier_versions[source_id] = version
	speed_modifiers[source_id] = maxf(multiplier, 0.0)
	_update_move_speed()
	_update_slow_tint()
	return version


func remove_speed_modifier(source_id: StringName, expected_version := -1) -> void:
	if expected_version >= 0 and int(speed_modifier_versions.get(source_id, -1)) != expected_version:
		return
	speed_modifiers.erase(source_id)
	speed_modifier_versions.erase(source_id)
	_update_move_speed()
	_update_slow_tint()


func clear_speed_modifiers() -> void:
	speed_modifiers.clear()
	speed_modifier_versions.clear()
	_update_move_speed()
	_update_slow_tint()


func add_stun(duration: float) -> void:
	if is_defeated:
		return

	stun_remaining += maxf(duration, 0.0)
	if stun_remaining > 0.0:
		velocity = Vector2.ZERO


func is_stunned() -> bool:
	return stun_remaining > 0.0


func get_speed_multiplier() -> float:
	var multiplier := 1.0
	for value in speed_modifiers.values():
		multiplier *= maxf(float(value), 0.0)
	return multiplier


func pause_after_attack() -> void:
	if move_speed_tiles_per_second <= 0.0:
		return

	attack_stop_remaining = maxf(attack_stop_remaining, 0.1 / move_speed_tiles_per_second)


func is_target_in_attack_range(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	return is_position_in_attack_range(target.global_position)


func is_position_in_attack_range(target_position: Vector2) -> bool:
	var tile_length := maxf(tile_size.x, tile_size.y)
	var attack_radius := maxf(attack_distance_tiles, 0.0) * tile_length
	return global_position.distance_squared_to(target_position) <= attack_radius * attack_radius


func get_effective_taunt_level_for(_observer: Node) -> float:
	return float(taunt_level)


func get_effective_attack_speed() -> float:
	var half_health_multiplier := half_health_attack_speed_multiplier if _is_below_half_health() else 1.0
	return maxf(attack_speed * half_health_multiplier, 0.0)


func get_effective_attack_power() -> int:
	var half_health_bonus := half_health_attack_power_bonus if _is_below_half_health() else 0
	return maxi(attack_power + half_health_bonus, 0)


func set_blocker(value: Node) -> void:
	blocker = value
	velocity = Vector2.ZERO


func clear_blocker() -> void:
	blocker = null


func is_blocked() -> bool:
	if can_be_blocked != CAN_BE_BLOCKED:
		return false
	if blocker == null or not is_instance_valid(blocker):
		return false
	if blocker.is_queued_for_deletion():
		return false
	if "is_defeated" in blocker and blocker.is_defeated:
		return false
	return true


func defeat() -> void:
	if is_defeated:
		return

	is_defeated = true
	modulate = Color(1, 1, 1, 0.55)
	health_bar.visible = false
	while get_tree().paused:
		await get_tree().process_frame
	sprite.play("death")
	await sprite.animation_finished
	defeated.emit(enemy_id)
	queue_free()


func take_damage(amount: int) -> int:
	var actual_damage := maxi(amount - incoming_damage_reduction, 0)
	set_health(health - actual_damage)
	if health <= 0:
		defeat()
	return actual_damage


func flash_hit() -> void:
	if is_defeated:
		return

	if sprite == null:
		return

	hit_flash_version += 1
	var current_version := hit_flash_version
	_set_hit_flash_amount(HIT_FLASH_AMOUNT)
	for _frame in HIT_FLASH_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(self) and current_version == hit_flash_version:
		_set_hit_flash_amount(0.0)


func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	_update_move_speed()
	_update_health_bar()


func _is_below_half_health() -> bool:
	return max_health > 0 and health * 2 < max_health


func set_health_bar_size(tile_size: Vector2) -> void:
	if health_bar == null or health_back == null or health_back.texture == null:
		return

	var back_width := float(health_back.texture.get_width())
	if back_width <= 0.0:
		return

	var bar_scale := BOSS_HEALTH_BAR_SCALE if is_boss else 1.0
	health_bar.scale = Vector2(tile_size.x * bar_scale / back_width, 0.4)
	health_bar.position = Vector2(-tile_size.x * 0.5, tile_size.y * 0.5 - 3.0)


func _configure_health_bar_ticks() -> void:
	if health_bar == null:
		return

	var ticks := health_bar.get_node_or_null("Ticks") as Node2D
	if ticks == null:
		ticks = Node2D.new()
		ticks.name = "Ticks"
		ticks.set_script(preload("res://scripts/ui/health_bar_ticks.gd"))
		health_bar.add_child(ticks)
	ticks.set("max_health", max_health)
	ticks.queue_redraw()


func _configure_render_order() -> void:
	if sprite != null:
		sprite.z_as_relative = true
		sprite.z_index = ENEMY_SPRITE_Z
		sprite.material = _get_hit_flash_material()
	if health_bar != null:
		health_bar.z_as_relative = true
		health_bar.z_index = ENEMY_HEALTH_BAR_Z


func _get_hit_flash_material() -> ShaderMaterial:
	if hit_flash_material != null:
		return hit_flash_material

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.05, 0.05, 0.85);
uniform float flash_amount = 0.0;
uniform vec4 tint_color : source_color = vec4(0.2, 0.55, 1.0, 0.85);
uniform float tint_amount = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec3 tinted_rgb = mix(tex.rgb, tint_color.rgb, tint_amount);
	COLOR = vec4(mix(tinted_rgb, flash_color.rgb, flash_amount), tex.a);
}
"""

	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = shader
	hit_flash_material.set_shader_parameter("flash_color", HIT_FLASH_COLOR)
	hit_flash_material.set_shader_parameter("flash_amount", 0.0)
	hit_flash_material.set_shader_parameter("tint_color", SLOW_TINT_COLOR)
	hit_flash_material.set_shader_parameter("tint_amount", 0.0)
	return hit_flash_material


func _set_hit_flash_amount(value: float) -> void:
	var material := _get_hit_flash_material()
	material.set_shader_parameter("flash_amount", clampf(value, 0.0, 1.0))


func _update_slow_tint() -> void:
	var material := _get_hit_flash_material()
	var amount := SLOW_TINT_AMOUNT if _has_active_slow_modifier() else 0.0
	material.set_shader_parameter("tint_amount", amount)


func _update_health_bar_style() -> void:
	if health_fill != null:
		health_fill.modulate = BOSS_HEALTH_FILL_COLOR if is_boss else NORMAL_HEALTH_FILL_COLOR


func _has_active_slow_modifier() -> bool:
	for value in speed_modifiers.values():
		if float(value) < 1.0:
			return true
	return false


func _update_health_bar() -> void:
	if health_fill == null:
		return

	var health_ratio := 0.0
	if max_health > 0:
		health_ratio = float(health) / float(max_health)
	health_fill.scale.x = clampf(health_ratio, 0.0, 1.0)
