extends Control

const MAIN_MENU_SCENE := "res://scenes/screens/main_menu.tscn"
const ARCHIVE_STATE := preload("res://scripts/systems/archive_state.gd")

const TYPE_CHARACTER := 0
const TYPE_ENEMY := 1
const PROFESSION_ALL := -1
const ENEMY_FILTER_ALL := -1
const ENEMY_FILTER_BOSS := -2
const PAGE_CATEGORY := 0
const PAGE_INFO := 1

const CHARACTER_SCENE_DIR := "res://scenes/units/characters"
const ENEMY_SCENE_DIR := "res://scenes/units/enemies"

const PROFESSION_ICON_PATHS := [
	"res://assets/textures/ui/professions/rogue.png",
	"res://assets/textures/ui/professions/warrior.png",
	"res://assets/textures/ui/professions/knight.png",
	"res://assets/textures/ui/professions/archer.png",
	"res://assets/textures/ui/professions/wizard.png",
	"res://assets/textures/ui/professions/priest.png",
]

@onready var category_page: Control = $Root/Margin/CategoryPage
@onready var info_page: Control = $Root/Margin/Main
@onready var category_character_button: Button = $Root/Margin/CategoryPage/Center/CategoryPanel/CategoryMargin/CategoryRows/CharacterPageButton
@onready var category_enemy_button: Button = $Root/Margin/CategoryPage/Center/CategoryPanel/CategoryMargin/CategoryRows/EnemyPageButton
@onready var page_title: Label = $Root/Margin/Main/Sidebar/Title
@onready var profession_filter_list: HBoxContainer = $Root/Margin/Main/Sidebar/ProfessionFilterList
@onready var entry_list: VBoxContainer = $Root/Margin/Main/Sidebar/EntryScroll/EntryMargin/EntryList
@onready var portrait_root: Node2D = $Root/Margin/Main/Detail/InfoPanel/InfoMargin/InfoRows/PortraitPanel/PortraitViewportContainer/PortraitViewport/PortraitRoot
@onready var title_label: Label = $Root/Margin/Main/Detail/InfoPanel/InfoMargin/InfoRows/TitleLabel
@onready var info_label: Label = $Root/Margin/Main/Detail/InfoPanel/InfoMargin/InfoRows/InfoLabel
@onready var back_button: Button = $Root/Margin/Main/Sidebar/BackButton

var current_page := PAGE_CATEGORY
var current_type := TYPE_CHARACTER
var character_entries: Array[Dictionary] = []
var enemy_entries: Array[Dictionary] = []
var current_entries: Array = []
var selected_index := 0
var selected_profession := PROFESSION_ALL
var selected_enemy_filter := ENEMY_FILTER_ALL
var portrait_unit: Node
var is_changing_scene := false


func _ready() -> void:
	character_entries = _get_character_entries()
	enemy_entries = _get_enemy_entries()
	current_entries = character_entries
	_setup_profession_filter()
	category_character_button.pressed.connect(_show_characters)
	category_enemy_button.pressed.connect(_show_enemies)
	back_button.pressed.connect(_go_back)
	_show_category_page()


func _input(event: InputEvent) -> void:
	if _is_back_input_event(event):
		get_viewport().set_input_as_handled()
		_go_back()


func _show_category_page() -> void:
	current_page = PAGE_CATEGORY
	_clear_portrait()
	_refresh_page_visibility()


func _show_characters() -> void:
	current_page = PAGE_INFO
	current_type = TYPE_CHARACTER
	selected_index = 0
	_setup_filter_buttons()
	_refresh_page_visibility()
	_rebuild_entry_list()
	_select_entry(0)


func _show_enemies() -> void:
	current_page = PAGE_INFO
	current_type = TYPE_ENEMY
	selected_index = 0
	_setup_filter_buttons()
	_refresh_page_visibility()
	_rebuild_entry_list()
	_select_entry(0)


func _refresh_page_visibility() -> void:
	category_page.visible = current_page == PAGE_CATEGORY
	info_page.visible = current_page == PAGE_INFO
	page_title.text = "角色" if current_type == TYPE_CHARACTER else "敌人"
	profession_filter_list.visible = current_page == PAGE_INFO


func _setup_profession_filter() -> void:
	_setup_filter_buttons()


func _setup_filter_buttons() -> void:
	for child in profession_filter_list.get_children():
		child.queue_free()

	if current_type == TYPE_ENEMY:
		_add_enemy_filter_button("ALL", ENEMY_FILTER_ALL)
		_add_enemy_filter_button("BOSS", ENEMY_FILTER_BOSS)
	else:
		_add_profession_filter_button("ALL", null, PROFESSION_ALL)
		for profession in PROFESSION_ICON_PATHS.size():
			_add_profession_filter_button("", load(PROFESSION_ICON_PATHS[profession]) as Texture2D, profession)
	_update_filter_buttons()


func _add_profession_filter_button(label_text: String, icon_texture: Texture2D, profession: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(34, 34)
	button.toggle_mode = true
	button.text = label_text
	button.icon = icon_texture
	button.expand_icon = true
	button.tooltip_text = "全部职业" if profession == PROFESSION_ALL else _get_profession_name(profession)
	button.set_meta("profession", profession)
	button.pressed.connect(_on_profession_button_pressed.bind(profession))
	profession_filter_list.add_child(button)


func _add_enemy_filter_button(label_text: String, filter: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(70, 34)
	button.toggle_mode = true
	button.text = label_text
	button.tooltip_text = "Boss" if filter == ENEMY_FILTER_BOSS else "ALL"
	button.set_meta("enemy_filter", filter)
	button.pressed.connect(_on_enemy_filter_button_pressed.bind(filter))
	profession_filter_list.add_child(button)


func _on_profession_button_pressed(profession: int) -> void:
	selected_profession = profession
	_update_filter_buttons()
	if current_type != TYPE_CHARACTER:
		return

	selected_index = 0
	_rebuild_entry_list()
	_select_entry(0)


func _on_enemy_filter_button_pressed(filter: int) -> void:
	selected_enemy_filter = filter
	_update_filter_buttons()
	if current_type != TYPE_ENEMY:
		return

	selected_index = 0
	_rebuild_entry_list()
	_select_entry(0)


func _update_filter_buttons() -> void:
	for child in profession_filter_list.get_children():
		if child is Button:
			if current_type == TYPE_ENEMY:
				child.button_pressed = int(child.get_meta("enemy_filter", ENEMY_FILTER_ALL)) == selected_enemy_filter
			else:
				child.button_pressed = int(child.get_meta("profession", PROFESSION_ALL)) == selected_profession


func _rebuild_entry_list() -> void:
	for child in entry_list.get_children():
		child.queue_free()

	current_entries = _get_visible_entries()
	for index in current_entries.size():
		var entry: Dictionary = current_entries[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 42)
		button.text = _get_entry_button_text(entry)
		button.disabled = not _is_entry_unlocked(entry)
		_apply_entry_button_style(button, entry)
		button.pressed.connect(_select_entry.bind(index))
		entry_list.add_child(button)

	if current_entries.is_empty():
		_clear_portrait()
		title_label.text = "无"
		info_label.text = ""


func _select_entry(index: int) -> void:
	if index < 0 or index >= current_entries.size():
		return

	selected_index = index
	var entry: Dictionary = current_entries[selected_index]
	if not _is_entry_unlocked(entry):
		_clear_portrait()
		title_label.text = "未解锁"
		info_label.text = "首次遇到后解锁。"
		return

	var unit := _instantiate_entry(entry)
	if unit == null:
		_clear_portrait()
		title_label.text = "读取失败"
		info_label.text = ""
		return

	title_label.text = _get_unit_title(unit, entry)
	info_label.text = _build_info_text(unit, entry)
	_show_portrait(unit)


func _get_entry_button_text(entry: Dictionary) -> String:
	if not _is_entry_unlocked(entry):
		return "???"
	var id_text := str(entry.get("id", "")).to_upper()
	return id_text


func _get_visible_entries() -> Array:
	if current_type == TYPE_ENEMY:
		if selected_enemy_filter == ENEMY_FILTER_BOSS:
			var boss_entries := []
			for entry in enemy_entries:
				if bool(entry.get("is_boss", false)):
					boss_entries.append(entry)
			return boss_entries
		return enemy_entries
	if selected_profession == PROFESSION_ALL:
		return character_entries

	var entries := []
	for entry in character_entries:
		if _get_entry_profession(entry) == selected_profession:
			entries.append(entry)
	return entries


func _get_character_entries() -> Array[Dictionary]:
	var entries := _get_scene_entries(CHARACTER_SCENE_DIR, "")
	entries = entries.filter(func(entry: Dictionary) -> bool:
		return RegEx.create_from_string("^[a-z]+[0-9]+$").search(str(entry.get("id", ""))) == null
	)
	for entry in entries:
		var base_id := str(entry.get("id", "")).to_lower()
		var variant_id := ARCHIVE_STATE.get_character_variant(base_id)
		entry["scene"] = "%s/%s.tscn" % [CHARACTER_SCENE_DIR, variant_id]
	entries.sort_custom(_is_entry_id_before)
	return entries


func _get_enemy_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _get_scene_entries(ENEMY_SCENE_DIR, "enemy_"):
		var unit := _instantiate_entry(entry)
		if unit != null:
			entry["is_boss"] = _get_bool_property(unit, "is_boss", false)
			unit.queue_free()
		entries.append(entry)
	entries.sort_custom(_is_entry_id_before)
	return entries


func _get_scene_entries(directory_path: String, file_prefix: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return entries

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tscn") and (file_prefix.is_empty() or file_name.begins_with(file_prefix)):
			var entry_id := file_name.get_basename()
			if not file_prefix.is_empty():
				entry_id = entry_id.trim_prefix(file_prefix)
			entries.append({
				"id": entry_id.to_lower(),
				"scene": "%s/%s" % [directory_path, file_name],
			})
		file_name = directory.get_next()
	directory.list_dir_end()
	return entries


func _is_entry_id_before(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("id", "")) < str(b.get("id", ""))


func _get_entry_profession(entry: Dictionary) -> int:
	var unit := _instantiate_entry(entry)
	if unit == null:
		return -1

	var profession := _get_int_property(unit, "profession", -1)
	unit.queue_free()
	return profession


func _is_entry_unlocked(entry: Dictionary) -> bool:
	if current_type == TYPE_CHARACTER:
		return ARCHIVE_STATE.is_character_unlocked(str(entry.get("id", "")))
	return ARCHIVE_STATE.is_enemy_unlocked(str(entry.get("id", "")))


func _instantiate_entry(entry: Dictionary) -> Node:
	var scene := load(str(entry.get("scene", ""))) as PackedScene
	if scene == null:
		return null
	return scene.instantiate()


func _show_portrait(unit: Node) -> void:
	_clear_portrait()
	portrait_unit = unit
	portrait_root.add_child(portrait_unit)
	if portrait_unit is Node2D:
		portrait_unit.position = Vector2(110, 150)
		portrait_unit.scale = Vector2(5, 5)
		_hide_portrait_helpers(portrait_unit)
		_play_portrait_left_animation(portrait_unit)


func _clear_portrait() -> void:
	if portrait_unit != null and is_instance_valid(portrait_unit):
		portrait_unit.queue_free()
	portrait_unit = null


func _hide_portrait_helpers(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.visible = false
		if child.name == "HealthBar":
			child.visible = false
		_hide_portrait_helpers(child)


func _play_portrait_left_animation(node: Node) -> void:
	var animated_sprite := node.get_node_or_null("BodySprite") as AnimatedSprite2D
	if animated_sprite == null:
		animated_sprite = node.get_node_or_null("Sprite") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var animation_name := StringName("normal_left")
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		animation_name = StringName("armed_left")
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		animation_name = animated_sprite.animation

	animated_sprite.visible = true
	animated_sprite.play(animation_name)

	var armed_sprite := node.get_node_or_null("ArmedSprite") as AnimatedSprite2D
	if armed_sprite != null:
		armed_sprite.visible = bool(node.get("has_floating_cannon"))


func _build_info_text(unit: Node, entry: Dictionary) -> String:
	if current_type == TYPE_CHARACTER:
		return _build_character_info_text(unit)
	return _build_enemy_info_text(unit, entry)


func _build_character_info_text(unit: Node) -> String:
	var lines: Array[String] = []
	var power_label := "治疗量" if _is_priest_unit(unit) else "攻击力"
	lines.append("职业: %s" % _get_profession_name(_get_int_property(unit, "profession", 0)))
	lines.append("职业特性: %s" % _get_profession_trait_description(unit))
	lines.append("%s: %d" % [power_label, _get_int_property(unit, "attack_power", 0)])
	lines.append("攻击速度: %s 次/秒" % _format_float(_get_float_property(unit, "attack_speed", 0.0)))
	lines.append("生命值: %d" % _get_int_property(unit, "max_health", 0))
	lines.append("部署费用: %d" % _get_int_property(unit, "deploy_cost", 0))
	lines.append("部署冷却: %s 秒" % _format_float(_get_float_property(unit, "deployment_cooldown", 0.0)))
	lines.append("单体部署上限: %d" % _get_int_property(unit, "deployment_limit", 2))
	lines.append("攻击距离: %s 格" % _format_float(_get_float_property(unit, "attack_distance_tiles", 0.0)))
	lines.append("目标数: %d" % _get_int_property(unit, "attack_target_count", 1))
	lines.append("嘲讽等级: %s" % _format_float(_get_effective_taunt_level(unit, null)))
	lines.append("部署位置: %s" % _get_placement_type_name(_get_unit_effective_placement_type(unit)))
	lines.append("阻挡: %s" % _get_block_ability_text(unit))
	lines.append("被动技能: %s" % _empty_to_none(_get_string_property(unit, "skill_description", "")))
	lines.append("主动技能: %s" % _empty_to_none(_get_string_property(unit, "active_skill_description", "")))
	lines.append("主动效果: %s" % _empty_to_none(_get_string_property(unit, "active_skill_effect", "")))
	lines.append("技能点获取: %s" % _empty_to_none(_get_string_property(unit, "upgrade_method", "")))
	return "\n".join(lines)


func _build_enemy_info_text(unit: Node, entry: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("类型: %s" % ("Boss" if bool(entry.get("is_boss", false)) or _get_bool_property(unit, "is_boss", false) else "普通敌人"))
	lines.append("移动速度: %s 格/秒" % _format_float(_get_float_property(unit, "move_speed_tiles_per_second", 0.0)))
	lines.append("攻击力: %d" % _get_int_property(unit, "attack_power", 0))
	lines.append("攻击速度: %s 次/秒" % _format_float(_get_float_property(unit, "attack_speed", 0.0)))
	lines.append("生命值: %d" % _get_int_property(unit, "max_health", 0))
	lines.append("攻击距离: %s 格" % _format_float(_get_float_property(unit, "attack_distance_tiles", 0.0)))
	lines.append("目标数: %d" % _get_int_property(unit, "attack_target_count", 1))
	lines.append("嘲讽等级: %s" % _format_float(_get_effective_taunt_level(unit, null)))
	lines.append("阻挡: %s" % _get_enemy_block_text(unit))
	lines.append("技能描述: %s" % _empty_to_none(_get_string_property(unit, "skill_description", "")))
	return "\n".join(lines)


func _get_unit_title(unit: Node, entry: Dictionary) -> String:
	if current_type == TYPE_CHARACTER and "unit_id" in unit:
		var id_text := str(unit.unit_id).to_lower()
		var base_id := ""
		for character in id_text:
			if character < "a" or character > "z":
				break
			base_id += character
		var suffix := id_text.substr(base_id.length())
		var level := suffix.to_int() + 1 if suffix.is_valid_int() else 1
		return "%s Lv.%d" % [_get_profession_name(_get_int_property(unit, "profession", 0)), level]
	if current_type == TYPE_ENEMY and "enemy_id" in unit:
		return str(unit.enemy_id).to_upper()
	return str(entry.get("id", "")).to_upper()


func _apply_entry_button_style(button: Button, entry: Dictionary) -> void:
	if current_type != TYPE_ENEMY or not bool(entry.get("is_boss", false)):
		return

	button.add_theme_stylebox_override("normal", _make_boss_button_style(Color(0.18, 0.08, 0.09, 1), Color(0.95, 0.18, 0.18, 1)))
	button.add_theme_stylebox_override("hover", _make_boss_button_style(Color(0.28, 0.10, 0.10, 1), Color(1.0, 0.32, 0.28, 1)))
	button.add_theme_stylebox_override("pressed", _make_boss_button_style(Color(0.12, 0.05, 0.06, 1), Color(1.0, 0.24, 0.20, 1)))


func _make_boss_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	return style


func _get_profession_name(profession: int) -> String:
	match profession:
		0:
			return "盗贼"
		1:
			return "战士"
		2:
			return "骑士"
		3:
			return "弓手"
		4:
			return "法师"
		5:
			return "牧师"
		_:
			return "未知"


func _get_placement_type_name(placement_type: int) -> String:
	return "高台" if placement_type == 1 else "地面"


func _get_block_ability_text(unit: Node) -> String:
	if _get_int_property(unit, "can_block", 1) != 1:
		return "无法阻挡"
	if _get_int_property(unit, "block_ability", 1) == 0:
		return "无法阻挡"
	return "可以阻挡"


func _get_enemy_block_text(unit: Node) -> String:
	return "可以被阻挡" if _get_int_property(unit, "can_be_blocked", 1) == 1 else "无法被阻挡"


func _get_profession_trait_description(unit: Node) -> String:
	if unit != null and unit.has_method("get_profession_trait_description"):
		return str(unit.get_profession_trait_description())
	return _get_string_property(unit, "profession_trait_description", "")


func _get_unit_effective_placement_type(unit: Node) -> int:
	if unit != null and unit.has_method("get_effective_placement_type"):
		return int(unit.get_effective_placement_type())
	return _get_int_property(unit, "placement_type", 0)


func _is_priest_unit(unit: Node) -> bool:
	if unit != null and unit.has_method("is_healer"):
		return unit.is_healer()
	return _get_int_property(unit, "profession", 0) == 5


func _get_effective_taunt_level(target: Node, observer: Node) -> float:
	if target != null and target.has_method("get_effective_taunt_level_for"):
		return float(target.get_effective_taunt_level_for(observer))
	return _get_float_property(target, "taunt_level", 0.0)


func _get_int_property(source: Node, property_name: StringName, fallback: int) -> int:
	if source != null and property_name in source:
		return int(source.get(property_name))
	return fallback


func _get_float_property(source: Node, property_name: StringName, fallback: float) -> float:
	if source != null and property_name in source:
		return float(source.get(property_name))
	return fallback


func _get_bool_property(source: Node, property_name: StringName, fallback: bool) -> bool:
	if source != null and property_name in source:
		return bool(source.get(property_name))
	return fallback


func _get_string_property(source: Node, property_name: StringName, fallback: String) -> String:
	if source != null and property_name in source:
		return str(source.get(property_name))
	return fallback


func _format_float(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _empty_to_none(value: String) -> String:
	return "无" if value.strip_edges().is_empty() else value


func _go_back() -> void:
	if is_changing_scene:
		return

	if current_page == PAGE_INFO:
		_show_category_page()
		return

	is_changing_scene = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _is_back_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	return event.is_action_pressed("ui_back")
