extends Control

const LEVEL_SELECT_SCENE := "res://scenes/screens/level_select.tscn"
const ARCHIVE_STATE := preload("res://scripts/systems/archive_state.gd")
const STAGE_CATALOG := preload("res://scripts/systems/stage_catalog.gd")
const STARTER_GIFT_DIALOG_SCRIPT := preload("res://scripts/ui/starter_gift_dialog.gd")
const MAX_SQUAD_SIZE := 10
const STARTER_GIFT_STAGE_NUMBER := 1
const UNSELECTED_FONT_COLOR := Color(0.62, 0.64, 0.66, 1.0)
const SELECTED_FONT_COLOR := Color(1.0, 0.88, 0.45, 1.0)
const CARD_SIZE := Vector2(126, 168)
const PORTRAIT_SIZE := Vector2i(96, 96)
const PORTRAIT_UNIT_POSITION := Vector2(48, 68)
const PORTRAIT_UNIT_SCALE := Vector2(3, 3)
const UI_TEXT := {
	"title": "编队",
	"back": "返回",
	"start": "开始战斗",
	"clear": "清空",
	"recommend": "全选",
	"need_character": "请至少选择一名角色",
	"ground": "地面",
	"ranged": "高台",
	"unknown": "未知",
}
const PROFESSION_NAMES := ["盗贼", "战士", "骑士", "弓手", "法师", "牧师"]
const PROFESSION_ICON_PATHS := [
	"res://assets/textures/ui/professions/rogue.png",
	"res://assets/textures/ui/professions/warrior.png",
	"res://assets/textures/ui/professions/knight.png",
	"res://assets/textures/ui/professions/archer.png",
	"res://assets/textures/ui/professions/wizard.png",
	"res://assets/textures/ui/professions/priest.png",
]
const CHARACTER_SCENE_DIR := "res://scenes/units/characters"

@onready var character_list: GridContainer = $Center/Panel/Margin/Stack/CharacterList
@onready var selected_label: Label = $Center/Panel/Margin/Stack/SelectedLabel
@onready var start_button: Button = $Center/Panel/Margin/Stack/ButtonRow/StartButton
@onready var back_button: Button = $Center/Panel/Margin/Stack/ButtonRow/BackButton
@onready var button_row: HBoxContainer = $Center/Panel/Margin/Stack/ButtonRow
@onready var clear_button: Button = get_node_or_null("Center/Panel/Margin/Stack/ButtonRow/ClearButton") as Button
@onready var recommend_button: Button = get_node_or_null("Center/Panel/Margin/Stack/ButtonRow/RecommendButton") as Button

var selected_ids: Array[String] = []
var button_by_id: Dictionary = {}
var character_entries: Array[Dictionary] = []
var is_changing_scene := false
var unselected_card_style: StyleBoxFlat
var selected_card_style: StyleBoxFlat
var gift_dialog: ConfirmationDialog = null


func _ready() -> void:
	_ensure_action_buttons()
	_localize_static_text()
	_create_card_styles()
	character_entries = _get_character_entries()
	_build_character_buttons()
	selected_ids = _filter_selectable_ids(ARCHIVE_STATE.get_selected_squad())
	_update_selection_ui()
	_connect_once(start_button.pressed, _on_start_pressed)
	_connect_once(back_button.pressed, _on_back_pressed)
	call_deferred("_show_starter_gift_for_opening_stage")
	_connect_once(clear_button.pressed, _on_clear_pressed)
	_connect_once(recommend_button.pressed, _on_recommend_pressed)


func _ensure_action_buttons() -> void:
	if clear_button == null:
		clear_button = _make_action_button(UI_TEXT["clear"])
		clear_button.name = "ClearButton"
		button_row.add_child(clear_button)
		button_row.move_child(clear_button, 1)
	if recommend_button == null:
		recommend_button = _make_action_button(UI_TEXT["recommend"])
		recommend_button.name = "RecommendButton"
		button_row.add_child(recommend_button)
		button_row.move_child(recommend_button, 2)


func _make_action_button(label_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 46)
	button.text = label_text
	button.add_theme_font_size_override("font_size", 20)
	return button


func _localize_static_text() -> void:
	var title := get_node_or_null("Center/Panel/Margin/Stack/Title") as Label
	if title != null:
		var target_stage_path := ARCHIVE_STATE.get_target_stage_path()
		var target_stage := STAGE_CATALOG.get_stage_by_scene_path(target_stage_path)
		var display_name := str(target_stage.get("display_name", "")).strip_edges()
		title.text = display_name if not display_name.is_empty() else UI_TEXT["title"]
	back_button.text = UI_TEXT["back"]
	start_button.text = UI_TEXT["start"]
	clear_button.text = UI_TEXT["clear"]
	recommend_button.text = UI_TEXT["recommend"]


func _connect_once(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


## Grants the starter character the first time the player opens the formation
## screen of the opening stage, so the gift lands right before the first battle.
func _show_starter_gift_for_opening_stage() -> void:
	if _get_target_stage_number() != STARTER_GIFT_STAGE_NUMBER:
		return
	if ARCHIVE_STATE.has_claimed_starter_character():
		return

	var granted_character_id := ARCHIVE_STATE.claim_starter_character()
	if granted_character_id.strip_edges().is_empty():
		return

	_build_character_buttons()
	selected_ids = _filter_selectable_ids(selected_ids)
	_update_selection_ui()
	_ensure_gift_dialog()
	gift_dialog.show_gift(granted_character_id)


func _get_target_stage_number() -> int:
	var target_stage := STAGE_CATALOG.get_stage_by_scene_path(ARCHIVE_STATE.get_target_stage_path())
	return int(target_stage.get("global_stage_number", 0))


func _ensure_gift_dialog() -> void:
	if gift_dialog != null:
		return

	gift_dialog = STARTER_GIFT_DIALOG_SCRIPT.new()
	gift_dialog.name = "StarterGiftDialog"
	add_child(gift_dialog)


func _get_character_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var directory := DirAccess.open(CHARACTER_SCENE_DIR)
	if directory == null:
		return entries

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tscn"):
			var character_id := file_name.get_basename().to_lower()
			if RegEx.create_from_string("^[a-z]+[0-9]+$").search(character_id) != null:
				file_name = directory.get_next()
				continue
			var variant_id := ARCHIVE_STATE.get_character_variant(character_id)
			entries.append({
				"id": character_id,
				"scene": "%s/%s.tscn" % [CHARACTER_SCENE_DIR, variant_id],
			})
		file_name = directory.get_next()
	directory.list_dir_end()
	entries.sort_custom(_is_character_entry_before)
	return entries


func _is_character_entry_before(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("id", "")) < str(b.get("id", ""))


func _input(event: InputEvent) -> void:
	if _is_back_input_event(event):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _build_character_buttons() -> void:
	for child in character_list.get_children():
		child.queue_free()

	button_by_id.clear()
	for entry in character_entries:
		var id_text := str(entry.get("id", "")).to_lower()
		if not ARCHIVE_STATE.is_character_unlocked(id_text):
			continue

		var profession := _get_entry_profession(entry)
		var button := _create_character_button(entry, id_text, profession)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta("character_id", id_text)
		button.pressed.connect(_on_character_button_pressed.bind(id_text))
		character_list.add_child(button)
		button_by_id[id_text] = button


func _create_character_button(entry: Dictionary, character_id: String, profession: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE

	var profession_icon := TextureRect.new()
	profession_icon.name = "ProfessionIcon"
	profession_icon.custom_minimum_size = Vector2(30, 30)
	profession_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	profession_icon.offset_left = -36.0
	profession_icon.offset_top = 6.0
	profession_icon.offset_right = -6.0
	profession_icon.offset_bottom = 36.0
	profession_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profession_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	profession_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profession_icon.texture = _get_profession_icon(profession)
	profession_icon.visible = profession_icon.texture != null
	button.add_child(profession_icon)

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	button.add_child(stack)

	var portrait_container := SubViewportContainer.new()
	portrait_container.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, PORTRAIT_SIZE.y)
	portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.stretch = false
	stack.add_child(portrait_container)

	var portrait_viewport := SubViewport.new()
	portrait_viewport.disable_3d = true
	portrait_viewport.transparent_bg = true
	portrait_viewport.size = PORTRAIT_SIZE
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	portrait_container.add_child(portrait_viewport)

	var portrait_root := Node2D.new()
	portrait_viewport.add_child(portrait_root)
	_add_character_portrait(portrait_root, str(entry.get("scene", "")))

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.text = _get_character_display_name(entry, profession)
	stack.add_child(name_label)

	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.text = _get_character_card_detail(entry, profession)
	stack.add_child(detail_label)

	return button


func _get_entry_profession(entry: Dictionary) -> int:
	var unit := _instantiate_entry_unit(entry)
	if unit == null:
		return 0

	var profession := _get_int_property(unit, "profession", 0)
	unit.queue_free()
	return profession


func _get_profession_icon(profession: int) -> Texture2D:
	if profession < 0 or profession >= PROFESSION_ICON_PATHS.size():
		return null
	return load(PROFESSION_ICON_PATHS[profession]) as Texture2D


func _add_character_portrait(portrait_root: Node2D, scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return

	var unit := scene.instantiate()
	portrait_root.add_child(unit)
	if unit is Node2D:
		unit.position = PORTRAIT_UNIT_POSITION
		unit.scale = PORTRAIT_UNIT_SCALE
		_hide_portrait_helpers(unit)
		_play_portrait_left_animation(unit)


func _on_character_button_pressed(character_id: String) -> void:
	if selected_ids.has(character_id):
		selected_ids.erase(character_id)
	elif selected_ids.size() < MAX_SQUAD_SIZE:
		selected_ids.append(character_id)

	_update_selection_ui()


func _on_clear_pressed() -> void:
	selected_ids.clear()
	_update_selection_ui()


func _on_recommend_pressed() -> void:
	selected_ids.clear()
	for entry in character_entries:
		var id_text := str(entry.get("id", "")).to_lower()
		if not button_by_id.has(id_text):
			continue
		selected_ids.append(id_text)
		if selected_ids.size() >= MAX_SQUAD_SIZE:
			break
	_update_selection_ui()


func _update_selection_ui() -> void:
	for character_id in button_by_id.keys():
		var button := button_by_id[character_id] as Button
		if button != null:
			_apply_character_button_selected(button, selected_ids.has(character_id))

	selected_label.text = "%d/%d  %s" % [selected_ids.size(), MAX_SQUAD_SIZE, _format_selected_ids()]
	start_button.disabled = selected_ids.is_empty() or ARCHIVE_STATE.get_target_stage_path().is_empty()
	start_button.tooltip_text = UI_TEXT["need_character"] if selected_ids.is_empty() else ""
	clear_button.disabled = selected_ids.is_empty()


func _filter_selectable_ids(character_ids: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for character_id in character_ids:
		if not button_by_id.has(character_id):
			continue
		if filtered.has(character_id):
			continue
		if filtered.size() >= MAX_SQUAD_SIZE:
			break
		filtered.append(character_id)
	return filtered


func _format_selected_ids() -> String:
	var text := ""
	for index in selected_ids.size():
		if index > 0:
			text += ", "
		text += selected_ids[index].to_upper()
	return text


func _create_card_styles() -> void:
	unselected_card_style = _make_card_style(Color(0.09, 0.105, 0.13, 0.92), Color(0.36, 0.39, 0.44, 1.0), 2)
	selected_card_style = _make_card_style(Color(0.28, 0.24, 0.13, 0.98), Color(1.0, 0.78, 0.26, 1.0), 4)


func _make_card_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


func _apply_character_button_selected(button: Button, is_selected: bool) -> void:
	button.button_pressed = is_selected
	var style := selected_card_style if is_selected else unselected_card_style
	var font_color := SELECTED_FONT_COLOR if is_selected else UNSELECTED_FONT_COLOR
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_hover_pressed_color", font_color)
	_set_child_label_color(button, "NameLabel", font_color)
	_set_child_label_color(button, "DetailLabel", font_color)


func _set_child_label_color(parent: Node, label_name: StringName, font_color: Color) -> void:
	var label := parent.find_child(label_name, true, false) as Label
	if label != null:
		label.add_theme_color_override("font_color", font_color)


func _get_character_card_detail(entry: Dictionary, profession: int) -> String:
	var unit := _instantiate_entry_unit(entry)
	if unit == null:
		return _get_profession_name(profession)

	var deploy_cost := _get_int_property(unit, "deploy_cost", 0)
	var placement := _get_placement_type_name(_get_unit_effective_placement_type(unit))
	unit.queue_free()
	return "%s  %s  费%d" % [_get_profession_name(profession), placement, deploy_cost]


func _get_character_display_name(entry: Dictionary, profession: int) -> String:
	var level := 1
	var id_text := str(entry.get("scene", "")).get_file().get_basename()
	var suffix := id_text.substr(1)
	if suffix.is_valid_int():
		level = suffix.to_int() + 1
	return "%s Lv.%d" % [_get_profession_name(profession), level]


func _instantiate_entry_unit(entry: Dictionary) -> Node:
	var scene := load(str(entry.get("scene", ""))) as PackedScene
	if scene == null:
		return null
	return scene.instantiate()


func _get_profession_name(profession: int) -> String:
	if profession < 0 or profession >= PROFESSION_NAMES.size():
		return UI_TEXT["unknown"]
	return PROFESSION_NAMES[profession]


func _get_placement_type_name(placement_type: int) -> String:
	return UI_TEXT["ranged"] if placement_type == 1 else UI_TEXT["ground"]


func _get_unit_effective_placement_type(unit: Node) -> int:
	if unit != null and unit.has_method("get_effective_placement_type"):
		return int(unit.get_effective_placement_type())
	return _get_int_property(unit, "placement_type", 0)


func _get_int_property(source: Node, property_name: StringName, fallback: int) -> int:
	if source != null and property_name in source:
		return int(source.get(property_name))
	return fallback


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


func _on_start_pressed() -> void:
	if is_changing_scene:
		return

	var target_stage_path := ARCHIVE_STATE.get_target_stage_path()
	if target_stage_path.is_empty():
		return

	is_changing_scene = true
	ARCHIVE_STATE.set_selected_squad(selected_ids)
	ARCHIVE_STATE.set_last_entered_stage_path(target_stage_path)
	get_tree().change_scene_to_file(target_stage_path)


func _on_back_pressed() -> void:
	if is_changing_scene:
		return

	is_changing_scene = true
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _is_back_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	return event.is_action_pressed("ui_back")
