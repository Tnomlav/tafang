extends CharacterBody2D

signal defeated(unit_id: String)
signal defeat_started(unit_id: String)
signal skill_ready(unit: Node)
signal skill_activated(unit: Node)

const DEFEAT_FADE_FRAMES := 4
const DEFEAT_TARGET_ALPHA := 0.55
const HIT_FLASH_COLOR := Color(1.0, 0.05, 0.05, 0.85)
const HIT_FLASH_AMOUNT := 0.9
const HIT_FLASH_FRAMES := 3
const CHARACTER_SPRITE_Z := 0
const CHARACTER_HEALTH_BAR_Z := 3
const BLOCK_NONE := 0
const BLOCK_INFINITE := 1
const PLACEMENT_GROUND := 0
const PLACEMENT_HIGH_GROUND := 1
const CAN_NOT_BLOCK := 0
const CAN_BLOCK := 1
const PROFESSION_ROGUE := 0
const PROFESSION_WARRIOR := 1
const PROFESSION_KNIGHT := 2
const PROFESSION_ARCHER := 3
const PROFESSION_WIZARD := 4
const PROFESSION_PRIEST := 5

@export_category("Identity")
@export var unit_id := "w"
@export_enum("Rogue", "Warrior", "Knight", "Archer", "Wizard", "Priest")
var profession := PROFESSION_ROGUE:
	set(value):
		profession = value
		placement_type = _get_placement_type_for_profession(profession)

@export_category("Placement")
@export_enum("Ground", "High Ground") var placement_type := PLACEMENT_GROUND

@export_category("Combat")
@export var attack_power := 1
@export var attack_speed := 1.0
@export var max_health := 1
@export var deploy_cost := 1
@export var taunt_level := 0
@export_range(1, 99, 1) var attack_target_count := 1
@export_range(0.0, 99.0, 0.1) var splash_damage_radius_tiles := 0.0
@export var even_enemy_taunt_bonus := 0

@export_category("Profession Trait")
@export_multiline var profession_trait_description := ""

@export_category("Skill")
@export_multiline var skill_description := ""
@export_multiline var active_skill_description := ""
@export_multiline var active_skill_effect := ""
@export_multiline var upgrade_method := ""
@export var deployment_cost_growth_bonus := 0.0
@export var attack_hits_cell_enemies := false
@export_range(0.0, 99.0, 0.01) var attack_heal_amount := 0.0
@export_range(0.0, 1.0, 0.05) var attack_slow_percent := 0.0
@export var attack_slow_duration := 0.0
@export var attack_stun_duration := 0.0
@export_range(0.0, 1.0, 0.01) var critical_hit_chance := 0.0
@export var critical_hit_multiplier := 2.0
@export var incoming_damage_reduction := 0.0
@export_range(0.0, 1.0, 0.01) var incoming_damage_multiplier := 1.0
@export_range(0.0, 100.0, 1.0) var skill_charge_max := 100.0

@export_category("Visual")
@export var has_floating_cannon := false
@export var floating_cannon_scale := Vector2(0.544, 0.544)

@export_category("Deployment")
@export var deployment_cooldown := 1.0
@export_range(1, 99, 1) var deployment_limit := 2

@export_category("Range")
@export var attack_distance_tiles := 1.0

@export_category("Blocking")
@export_range(0, 1, 1) var can_block := CAN_BLOCK
@export_enum("Cannot Block", "Block Infinite") var block_ability := BLOCK_INFINITE

@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var armed_sprite: AnimatedSprite2D = $ArmedSprite
@onready var health_bar: Node2D = $HealthBar
@onready var health_back: Sprite2D = $HealthBar/Back
@onready var health_fill: Sprite2D = $HealthBar/Fill

var health: float = max_health
var is_defeated := false
var is_armed := false
var facing_direction := "right"
var hit_flash_material: ShaderMaterial
var hit_flash_version := 0
var stun_remaining := 0.0
var skill_charge := 0.0
var skill_ready_emitted := false
var skill_active := false
var skill_effects_enabled := true


func _ready() -> void:
	health = max_health
	_configure_render_order()
	_configure_health_bar_ticks()
	set_armed(false)
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if stun_remaining > 0.0 and not get_tree().paused:
		stun_remaining = maxf(stun_remaining - delta, 0.0)
	velocity = Vector2.ZERO


func defeat() -> void:
	if is_defeated:
		return

	is_defeated = true
	defeat_started.emit(unit_id)
	modulate = Color(1, 1, 1, modulate.a)
	set_armed(false)
	await _play_defeat_fade()
	armed_sprite.visible = false
	body_sprite.visible = true
	modulate = Color(1, 1, 1, 1)
	while get_tree().paused:
		await get_tree().process_frame
	health_bar.visible = false
	body_sprite.play("death")
	await _wait_for_death_animation()
	defeated.emit(unit_id)
	body_sprite.visible = false
	queue_free()


func take_damage(amount: float) -> float:
	var actual_damage := amount
	if skill_effects_enabled:
		actual_damage = maxf((amount - incoming_damage_reduction) * incoming_damage_multiplier, 0.0)
	set_health(health - actual_damage)
	if health <= 0:
		defeat()
	return actual_damage


func heal(amount: float) -> float:
	if is_defeated:
		return 0.0

	var previous_health := health
	set_health(health + amount)
	return health - previous_health


func heal_fractional(amount: float) -> float:
	if is_defeated or health >= max_health:
		return 0.0

	var previous_health := health
	set_health(health + maxf(amount, 0.0))
	return health - previous_health


func add_skill_charge(amount: float) -> void:
	if is_defeated or amount <= 0.0 or skill_ready_emitted:
		return

	skill_charge = minf(skill_charge + amount, skill_charge_max)
	_update_skill_bar()
	if skill_charge >= skill_charge_max:
		skill_ready_emitted = true
		skill_ready.emit(self)


func reset_skill_charge() -> void:
	skill_charge = 0.0
	skill_ready_emitted = false
	_update_skill_bar()


func activate_skill() -> void:
	if is_defeated:
		return
	skill_active = true
	skill_activated.emit(self)


func flash_hit() -> void:
	if is_defeated:
		return

	if body_sprite == null:
		return

	hit_flash_version += 1
	var current_version := hit_flash_version
	_set_hit_flash_amount(HIT_FLASH_AMOUNT)
	for _frame in HIT_FLASH_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(self) and current_version == hit_flash_version:
		_set_hit_flash_amount(0.0)


func needs_healing() -> bool:
	return not is_defeated and health < max_health


func add_stun(duration: float) -> void:
	if is_defeated:
		return

	stun_remaining = maxf(stun_remaining, maxf(duration, 0.0))
	if stun_remaining > 0.0:
		set_armed(false)


func is_stunned() -> bool:
	return stun_remaining > 0.0


func is_healer() -> bool:
	return profession == PROFESSION_PRIEST


func is_warrior() -> bool:
	return profession == PROFESSION_WARRIOR


func is_archer() -> bool:
	return profession == PROFESSION_ARCHER


func set_armed(value: bool) -> void:
	if is_defeated:
		return

	var was_armed := is_armed
	is_armed = value
	if body_sprite != null:
		body_sprite.visible = true
		_play_body_stance_animation("armed" if is_armed else "normal", was_armed != is_armed)
	if armed_sprite != null:
		armed_sprite.scale = floating_cannon_scale
		# The cannon is part of the variant's identity and remains present outside combat.
		armed_sprite.visible = has_floating_cannon


func face_target_position(target_position: Vector2) -> void:
	if is_defeated:
		return

	var offset := target_position - global_position
	if offset.length_squared() <= 0.001:
		return

	var next_direction := _get_closest_direction(offset)
	if next_direction == facing_direction:
		return

	facing_direction = next_direction
	_play_body_stance_animation("armed" if is_armed else "normal", true)


func _play_body_stance_animation(stance: String, force_restart := false) -> void:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return

	var current_animation := String(body_sprite.animation)
	if current_animation.contains("_") and not force_restart:
		facing_direction = current_animation.get_slice("_", current_animation.get_slice_count("_") - 1)

	var animation_name := StringName("%s_%s" % [stance, facing_direction])
	if not body_sprite.sprite_frames.has_animation(animation_name):
		animation_name = _get_closest_available_animation(stance)
	if body_sprite.sprite_frames.has_animation(animation_name) and (force_restart or body_sprite.animation != animation_name):
		body_sprite.play(animation_name)


func _get_closest_direction(offset: Vector2) -> String:
	if absf(offset.x) >= absf(offset.y):
		return "right" if offset.x >= 0.0 else "left"
	return "down" if offset.y >= 0.0 else "up"


func _get_closest_available_animation(stance: String) -> StringName:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return StringName("")

	var preferred_directions := _get_direction_fallbacks(facing_direction)
	for direction in preferred_directions:
		var animation_name := StringName("%s_%s" % [stance, direction])
		if body_sprite.sprite_frames.has_animation(animation_name):
			return animation_name
	return StringName("")


func _get_direction_fallbacks(direction: String) -> Array[String]:
	match direction:
		"up":
			return ["up", "left", "right", "down"]
		"down":
			return ["down", "left", "right", "up"]
		"left":
			return ["left", "up", "down", "right"]
		_:
			return ["right", "up", "down", "left"]


func _wait_for_death_animation() -> void:
	if body_sprite == null or body_sprite.sprite_frames == null:
		await get_tree().process_frame
		return
	var animation_name := StringName("death")
	if not body_sprite.sprite_frames.has_animation(animation_name):
		await get_tree().process_frame
		return

	var speed := body_sprite.sprite_frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		await get_tree().process_frame
		return

	var frame_count := body_sprite.sprite_frames.get_frame_count(animation_name)
	for frame_index in frame_count:
		body_sprite.set_frame_and_progress(frame_index, 0.0)
		var frame_duration := body_sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / speed
		var frames_to_wait := maxi(1, ceili(frame_duration * 60.0))
		for _wait_frame in frames_to_wait:
			while get_tree().paused:
				await get_tree().process_frame
			await get_tree().process_frame


func get_effective_placement_type() -> int:
	return _get_placement_type_for_profession(profession)


func _get_placement_type_for_profession(value: int) -> int:
	match value:
		PROFESSION_ARCHER, PROFESSION_WIZARD, PROFESSION_PRIEST:
			return PLACEMENT_HIGH_GROUND
		_:
			return PLACEMENT_GROUND


func get_effective_taunt_level_for(_observer: Node) -> float:
	var effective_taunt := float(taunt_level)
	if profession == PROFESSION_KNIGHT:
		effective_taunt += 1.0
	return effective_taunt


func get_profession_trait_description() -> String:
	if not profession_trait_description.is_empty():
		return profession_trait_description

	match profession:
		PROFESSION_ROGUE:
			return "可以回复部署费用"
		PROFESSION_WARRIOR:
			return "同时攻击阻挡的所有敌人"
		PROFESSION_KNIGHT:
			return "优先受到敌人的攻击"
		PROFESSION_ARCHER:
			return "优先攻击生命值最低的目标"
		PROFESSION_WIZARD:
			return "可以造成多样化的远程攻击"
		PROFESSION_PRIEST:
			return "可以治疗队友"
		_:
			return ""


func get_taunt_bonus_against(target: Node) -> float:
	if even_enemy_taunt_bonus != 0 and _is_even_enemy(target):
		return float(even_enemy_taunt_bonus)
	return 0.0


func _is_even_enemy(target: Node) -> bool:
	if target == null:
		return false
	if target.has_meta("spawn_order"):
		return int(target.get_meta("spawn_order")) % 2 == 0
	if "enemy_id" in target:
		var text := str(target.enemy_id)
		if text.is_valid_int():
			return int(text) % 2 == 0
	return false


func set_health(value: float) -> void:
	health = clampf(value, 0.0, float(max_health))
	_update_health_bar()


func _play_defeat_fade() -> void:
	var start_alpha := modulate.a
	var start_health := health
	for frame in DEFEAT_FADE_FRAMES:
		var ratio := float(frame + 1) / float(DEFEAT_FADE_FRAMES)
		health = clampf(lerpf(float(start_health), 0.0, ratio), 0.0, float(max_health))
		_update_health_bar_ratio(lerpf(_get_health_ratio(start_health), 0.0, ratio))
		modulate.a = lerpf(start_alpha, DEFEAT_TARGET_ALPHA, ratio)
		await get_tree().process_frame

	health = 0
	_update_health_bar_ratio(0.0)
	modulate.a = DEFEAT_TARGET_ALPHA


func set_health_bar_size(tile_size: Vector2) -> void:
	if health_bar == null or health_back == null or health_back.texture == null:
		return

	var back_width := float(health_back.texture.get_width())
	if back_width <= 0.0:
		return

	health_bar.scale = Vector2(tile_size.x / back_width, 0.4)
	health_bar.position = Vector2(-tile_size.x * 0.5, tile_size.y * 0.5 - 3.0)
	var skill_bar := get_node_or_null("SkillBar") as Node2D
	if skill_bar != null:
		_position_skill_bar(skill_bar)


func set_health_bar_width(width: float) -> void:
	set_health_bar_size(Vector2(width, width))


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


func _configure_skill_bar() -> void:
	if health_bar == null:
		return

	var skill_bar := get_node_or_null("SkillBar") as Node2D
	if skill_bar == null:
		skill_bar = Node2D.new()
		skill_bar.name = "SkillBar"
		skill_bar.set_script(preload("res://scripts/ui/skill_bar.gd"))
		add_child(skill_bar)
	skill_bar.max_value = skill_charge_max
	skill_bar.value = skill_charge
	# Keep the skill bar independent from the health bar's display scaling.
	_position_skill_bar(skill_bar)
	skill_bar.z_as_relative = true
	skill_bar.z_index = CHARACTER_HEALTH_BAR_Z + 1
	skill_bar.visible = true


func set_skill_bar_visible(value: bool) -> void:
	if value:
		_configure_skill_bar()
		return
	var skill_bar := get_node_or_null("SkillBar") as Node2D
	if skill_bar != null:
		skill_bar.visible = false


func set_skill_effects_enabled(value: bool) -> void:
	skill_effects_enabled = value


func _update_skill_bar() -> void:
	if health_bar == null:
		return
	var skill_bar := get_node_or_null("SkillBar") as Node2D
	if skill_bar == null:
		return
	skill_bar.max_value = skill_charge_max
	skill_bar.value = skill_charge
	_position_skill_bar(skill_bar)


func _position_skill_bar(skill_bar: Node2D) -> void:
	if skill_bar == null or health_bar == null:
		return
	var health_height := 6.0 * health_bar.scale.y
	var health_length := 32.0 * health_bar.scale.x
	if health_back != null and health_back.texture != null:
		health_height = float(health_back.texture.get_height()) * health_bar.scale.y
		health_length = float(health_back.texture.get_width()) * health_bar.scale.x
	var skill_height := maxf(health_height * 0.5, 1.0)
	skill_bar.set("bar_size", Vector2(health_length, skill_height))
	# HealthBar/Back is top-left aligned, so its position is the visual top edge.
	skill_bar.position = Vector2(health_bar.position.x, health_bar.position.y - skill_height)


func _configure_render_order() -> void:
	if body_sprite != null:
		body_sprite.z_as_relative = true
		body_sprite.z_index = CHARACTER_SPRITE_Z
		body_sprite.material = _get_hit_flash_material()
	if armed_sprite != null:
		armed_sprite.z_as_relative = true
		armed_sprite.z_index = CHARACTER_SPRITE_Z
		armed_sprite.material = _get_hit_flash_material()
	if health_bar != null:
		health_bar.z_as_relative = true
		health_bar.z_index = CHARACTER_HEALTH_BAR_Z


func _get_hit_flash_material() -> ShaderMaterial:
	if hit_flash_material != null:
		return hit_flash_material

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.05, 0.05, 0.85);
uniform float flash_amount = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
}
"""

	hit_flash_material = ShaderMaterial.new()
	hit_flash_material.shader = shader
	hit_flash_material.set_shader_parameter("flash_color", HIT_FLASH_COLOR)
	hit_flash_material.set_shader_parameter("flash_amount", 0.0)
	return hit_flash_material


func _set_hit_flash_amount(value: float) -> void:
	var material := _get_hit_flash_material()
	material.set_shader_parameter("flash_amount", clampf(value, 0.0, 1.0))


func is_target_in_attack_range(target: Node2D, tile_size: Vector2) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	return is_position_in_attack_range(target.global_position, tile_size)


func is_position_in_attack_range(target_position: Vector2, tile_size: Vector2) -> bool:
	var tile_length := maxf(tile_size.x, tile_size.y)
	var attack_radius := (maxf(attack_distance_tiles, 0.0) + 0.6) * tile_length
	return global_position.distance_squared_to(target_position) <= attack_radius * attack_radius


func _update_health_bar() -> void:
	if health_fill == null:
		return

	_update_health_bar_ratio(_get_health_ratio(health))


func _update_health_bar_ratio(health_ratio: float) -> void:
	if health_fill == null:
		return

	health_fill.scale.x = clampf(health_ratio, 0.0, 1.0)


func _get_health_ratio(value: float) -> float:
	if max_health <= 0:
		return 0.0

	return float(value) / float(max_health)
