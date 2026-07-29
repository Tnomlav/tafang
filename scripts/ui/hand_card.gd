extends Button

signal drag_started(card: Node)
signal selected(card: Node)

const NORMAL_MODULATE := Color(1, 1, 1, 1)
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.55)

@export var unit_id := "w"
@export var unit_scene: PackedScene
@export var preview_texture: Texture2D
@export var profession_icons: Array[Texture2D] = []

@onready var icon_rect: TextureRect = $Icon
@onready var profession_icon_rect: TextureRect = get_node_or_null("ProfessionIcon") as TextureRect
@onready var floating_cannon_icon_rect: TextureRect = get_node_or_null("FloatingCannonIcon") as TextureRect
@onready var cost_label: Label = get_node_or_null("CostLabel") as Label
@onready var name_label: Label = $NameLabel
@onready var cooldown_mask: ColorRect = $CooldownMask
@onready var cooldown_label: Label = $CooldownLabel

var cooldown_remaining := 0.0
var is_affordable := true
var skill_charges := 0
var skill_charge_limit := 1
var skill_system_enabled := true
var skill_charge_label: Label
var skill_glow: Panel


func _ready() -> void:
	icon_rect.texture = preview_texture
	if floating_cannon_icon_rect != null:
		floating_cannon_icon_rect.visible = _is_variant_with_floating_cannon()
	_update_profession_icon()
	_update_cost_label()
	_update_name_label()
	_update_cooldown_display()
	_create_skill_display()
	cooldown_mask.visible = disabled
	button_down.connect(_on_button_down)


func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	if get_tree().paused:
		return

	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if cooldown_remaining <= 0.0:
		set_available(true)
	else:
		_update_cooldown_display()


func set_available(is_available: bool) -> void:
	if is_available:
		disabled = cooldown_remaining > 0.0 and skill_charges <= 0
		cooldown_mask.visible = cooldown_remaining > 0.0
	else:
		disabled = true
		cooldown_mask.visible = true
	_update_cooldown_display()


func set_skill_charge_limit(value: int) -> void:
	skill_charge_limit = clampi(value, 1, 2)
	skill_charges = mini(skill_charges, skill_charge_limit)
	_update_skill_display()


func set_skill_system_enabled(value: bool) -> void:
	skill_system_enabled = value
	if not skill_system_enabled:
		skill_charges = 0
	_update_skill_display()


func add_skill_charge() -> void:
	if not skill_system_enabled:
		return
	skill_charges = mini(skill_charges + 1, skill_charge_limit)
	if skill_charges > 0:
		disabled = false
	_update_skill_display()


func get_skill_charges() -> int:
	return skill_charges if skill_system_enabled else 0


func consume_skill_charge() -> bool:
	if not skill_system_enabled:
		return false
	if skill_charges <= 0:
		return false
	skill_charges -= 1
	if skill_charges <= 0 and cooldown_remaining > 0.0:
		disabled = true
	_update_skill_display()
	return true


func get_active_unit_scene() -> PackedScene:
	return unit_scene


func _create_skill_display() -> void:
	skill_charge_label = Label.new()
	skill_charge_label.name = "SkillChargeLabel"
	skill_charge_label.position = Vector2(48.0, -18.0)
	skill_charge_label.size = Vector2(22.0, 18.0)
	skill_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_charge_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	skill_charge_label.add_theme_font_size_override("font_size", 16)
	skill_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_charge_label)

	skill_glow = Panel.new()
	skill_glow.name = "SkillGlow"
	skill_glow.position = Vector2(-3.0, -3.0)
	skill_glow.size = Vector2(78.0, 94.0)
	skill_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_glow.z_index = -1
	skill_glow.add_theme_stylebox_override("panel", _make_glow_style())
	add_child(skill_glow)
	_update_skill_display()


func _update_skill_display() -> void:
	var visible_charges := skill_charges if skill_system_enabled else 0
	if skill_charge_label != null:
		var charge_marks := ["", "①", "②"]
		skill_charge_label.text = charge_marks[visible_charges]
		skill_charge_label.visible = visible_charges > 0
	if skill_glow != null:
		skill_glow.visible = visible_charges > 0
	self_modulate = Color(1.35, 1.2, 0.65, 1.0) if visible_charges > 0 else Color.WHITE


func _make_glow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.78, 0.12, 0.24)
	style.border_color = Color(1.0, 0.9, 0.28, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	return style


func set_affordable(value: bool) -> void:
	is_affordable = value
	modulate = NORMAL_MODULATE if is_affordable else UNAFFORDABLE_MODULATE


func start_cooldown(duration: float) -> void:
	cooldown_remaining = maxf(duration, 0.0)
	if cooldown_remaining <= 0.0:
		set_available(true)
		return

	disabled = skill_charges <= 0
	cooldown_mask.visible = true
	_update_cooldown_display()


func is_on_cooldown() -> bool:
	return cooldown_remaining > 0.0


func _update_name_label() -> void:
	if name_label == null:
		return

	name_label.text = get_unit_display_name()


func _update_cooldown_display() -> void:
	if cooldown_label == null:
		return
	if skill_system_enabled and skill_charges > 0:
		cooldown_label.visible = false
		return

	if cooldown_remaining > 0.0:
		cooldown_label.text = str(ceili(cooldown_remaining))
		cooldown_label.visible = true
	else:
		cooldown_label.visible = false


func _on_button_down() -> void:
	if disabled:
		return

	selected.emit(self)
	drag_started.emit(self)


func _update_profession_icon() -> void:
	if profession_icon_rect == null:
		return

	var profession := _get_unit_profession()
	if profession < 0 or profession >= profession_icons.size():
		profession_icon_rect.visible = false
		return

	profession_icon_rect.texture = profession_icons[profession]
	profession_icon_rect.visible = profession_icon_rect.texture != null


func _is_variant_with_floating_cannon() -> bool:
	var active_scene := unit_scene
	if active_scene == null:
		return false
	var unit: Node = active_scene.instantiate()
	var has_cannon := bool(unit.has_floating_cannon) if "has_floating_cannon" in unit else false
	unit.queue_free()
	return has_cannon


func _get_unit_profession() -> int:
	var active_scene := unit_scene
	if active_scene == null:
		return -1

	var unit: Node = active_scene.instantiate()
	var profession := -1
	if "profession" in unit:
		profession = int(unit.profession)
	unit.queue_free()
	return profession


func get_unit_profession() -> int:
	return _get_unit_profession()


func get_unit_display_name() -> String:
	var profession_name := ["盗贼", "战士", "骑士", "弓手", "法师", "牧师"]
	var profession := _get_unit_profession()
	var level := 1
	var suffix := unit_id.substr(1)
	if suffix.is_valid_int():
		level = suffix.to_int() + 1
	var display_name: String = profession_name[profession] if profession >= 0 and profession < profession_name.size() else "角色"
	return "%s Lv.%d" % [display_name, level]


func get_deploy_cost() -> int:
	var active_scene := get_active_unit_scene()
	if active_scene == null:
		return 0

	var unit: Node = active_scene.instantiate()
	var deploy_cost := 0
	if "deploy_cost" in unit:
		deploy_cost = int(unit.deploy_cost)
	unit.queue_free()
	return deploy_cost


func get_deployment_cooldown() -> float:
	var active_scene := get_active_unit_scene()
	if active_scene == null:
		return 0.0
	var unit: Node = active_scene.instantiate()
	var cooldown := float(unit.deployment_cooldown) if "deployment_cooldown" in unit else 0.0
	unit.queue_free()
	return cooldown


func get_deployment_limit() -> int:
	var active_scene := get_active_unit_scene()
	if active_scene == null:
		return 0
	var unit: Node = active_scene.instantiate()
	var limit := int(unit.deployment_limit) if "deployment_limit" in unit else 0
	unit.queue_free()
	return limit


func _update_cost_label() -> void:
	if cost_label == null:
		return

	cost_label.text = str(get_deploy_cost())

