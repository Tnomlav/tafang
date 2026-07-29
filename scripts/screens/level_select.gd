extends Control

const FORMATION_SCENE := "res://scenes/screens/formation.tscn"
const MAIN_MENU_SCENE := "res://scenes/screens/main_menu.tscn"
const ARCHIVE_STATE := preload("res://scripts/systems/archive_state.gd")
const STAGE_CATALOG := preload("res://scripts/systems/stage_catalog.gd")
const UNLOCKED_FONT_COLOR := Color(0.94, 0.95, 0.92, 1.0)
const LOCKED_FONT_COLOR := Color(0.48, 0.5, 0.52, 1.0)
const LEVEL_COLUMNS := 6
const STATUS_LOCKED := "锁定"
const STATUS_DEVELOPMENT := "开发中"
const STATUS_CLEARED := "已通关"
const STATUS_CURRENT := "未通关"

@onready var chapter_list: VBoxContainer = $Center/Panel/Margin/Stack/ChapterList
@onready var back_button: Button = $Center/Panel/Margin/Stack/BackButton

var is_changing_scene := false
var unlocked_button_style: StyleBoxFlat
var unlocked_button_hover_style: StyleBoxFlat
var locked_button_style: StyleBoxFlat
var midpoint_unlocked_button_style: StyleBoxFlat
var midpoint_unlocked_button_hover_style: StyleBoxFlat
var midpoint_locked_button_style: StyleBoxFlat
var final_unlocked_button_style: StyleBoxFlat
var final_unlocked_button_hover_style: StyleBoxFlat
var final_locked_button_style: StyleBoxFlat
var development_button_style: StyleBoxFlat


func _ready() -> void:
	_create_button_styles()
	_build_chapter_list()
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _on_level_pressed(button: Button) -> void:
	if is_changing_scene:
		return

	var global_stage_number := int(button.get_meta("global_stage_number", 0))
	var stage_path := str(button.get_meta("stage_path", ""))
	var is_playable := bool(button.get_meta("is_playable", false))
	if global_stage_number <= 0 or stage_path.is_empty():
		return
	if not ARCHIVE_STATE.is_stage_unlocked(global_stage_number):
		return
	if not is_playable:
		return

	is_changing_scene = true
	ARCHIVE_STATE.set_target_stage_path(stage_path)
	get_tree().change_scene_to_file(FORMATION_SCENE)


func _build_chapter_list() -> void:
	for child in chapter_list.get_children():
		child.queue_free()

	var current_chapter := -1
	var chapter_grid: GridContainer
	for stage_entry in _get_stage_entries():
		var chapter := int(stage_entry["chapter"])
		if chapter != current_chapter:
			current_chapter = chapter
			_add_chapter_header(chapter)
			chapter_grid = _add_chapter_grid()

		var button := _create_stage_button(stage_entry)
		_configure_level_button(button)
		button.pressed.connect(_on_level_pressed.bind(button))
		chapter_grid.add_child(button)


func _create_stage_button(stage_entry: Dictionary) -> Button:
	var chapter := int(stage_entry["chapter"])
	var stage := int(stage_entry["stage"])
	var button := Button.new()
	button.name = "Chapter%dStage%dButton" % [chapter, stage]
	button.text = _get_level_button_text(stage_entry)
	button.custom_minimum_size = Vector2(86, 62)
	button.add_theme_font_size_override("font_size", 18)
	button.set_meta("global_stage_number", int(stage_entry["global_stage_number"]))
	button.set_meta("chapter", chapter)
	button.set_meta("stage", stage)
	button.set_meta("stage_path", str(stage_entry["scene_path"]))
	button.set_meta("is_playable", STAGE_CATALOG.is_stage_playable(stage_entry))
	button.set_meta("status", str(stage_entry.get("status", "")))
	return button


func _add_chapter_header(chapter: int) -> void:
	var label := Label.new()
	label.text = "第%d章" % chapter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42, 1))
	label.add_theme_font_size_override("font_size", 22)
	chapter_list.add_child(label)


func _add_chapter_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = LEVEL_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	chapter_list.add_child(grid)
	return grid


func _get_stage_entries() -> Array[Dictionary]:
	var stage_entries: Array[Dictionary] = []
	var highest_visible_stage := ARCHIVE_STATE.get_highest_unlocked_stage() + 6
	for entry in STAGE_CATALOG.get_visible_entries(highest_visible_stage):
		stage_entries.append(entry)

	stage_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["global_stage_number"]) < int(b["global_stage_number"])
	)
	return stage_entries


func _input(event: InputEvent) -> void:
	if _is_back_input_event(event):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if is_changing_scene:
		return

	is_changing_scene = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _is_back_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	return event.is_action_pressed("ui_back")


func _configure_level_button(button: Button) -> void:
	var global_stage_number := int(button.get_meta("global_stage_number", 0))
	var stage := int(button.get_meta("stage", 0))
	var is_playable := bool(button.get_meta("is_playable", false))
	var is_unlocked := ARCHIVE_STATE.is_stage_unlocked(global_stage_number) and is_playable
	var is_development := not is_playable
	var is_chapter_midpoint := stage == 6
	var is_chapter_final := stage == 12
	var normal_style := final_unlocked_button_style if is_chapter_final else midpoint_unlocked_button_style if is_chapter_midpoint else unlocked_button_style
	var hover_style := final_unlocked_button_hover_style if is_chapter_final else midpoint_unlocked_button_hover_style if is_chapter_midpoint else unlocked_button_hover_style
	var disabled_style := development_button_style if is_development else final_locked_button_style if is_chapter_final else midpoint_locked_button_style if is_chapter_midpoint else locked_button_style
	button.disabled = not is_unlocked
	button.focus_mode = Control.FOCUS_ALL if is_unlocked else Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN
	button.add_theme_color_override("font_color", UNLOCKED_FONT_COLOR if is_unlocked else LOCKED_FONT_COLOR)
	button.add_theme_color_override("font_disabled_color", LOCKED_FONT_COLOR)
	button.add_theme_stylebox_override("normal", normal_style if is_unlocked else disabled_style)
	button.add_theme_stylebox_override("hover", hover_style if is_unlocked else disabled_style)
	button.add_theme_stylebox_override("pressed", hover_style if is_unlocked else disabled_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _get_level_button_text(stage_entry: Dictionary) -> String:
	var stage := int(stage_entry["stage"])
	var global_stage_number := int(stage_entry["global_stage_number"])
	var is_playable := STAGE_CATALOG.is_stage_playable(stage_entry)
	var is_unlocked := ARCHIVE_STATE.is_stage_unlocked(global_stage_number)
	var status := STATUS_LOCKED
	if STAGE_CATALOG.is_stage_development(stage_entry) or not is_playable:
		status = STATUS_DEVELOPMENT
	elif ARCHIVE_STATE.is_stage_cleared(global_stage_number):
		status = STATUS_CLEARED
	elif is_unlocked:
		status = STATUS_CURRENT
	return "%d\n%s" % [stage, status]


func _create_button_styles() -> void:
	unlocked_button_style = _make_button_style(Color(0.18, 0.22, 0.28, 1), Color(0.58, 0.63, 0.68, 1))
	unlocked_button_hover_style = _make_button_style(Color(0.28, 0.24, 0.18, 1), Color(0.95, 0.76, 0.36, 1))
	locked_button_style = _make_button_style(Color(0.13, 0.14, 0.15, 1), Color(0.3, 0.32, 0.34, 1))
	development_button_style = _make_button_style(Color(0.1, 0.11, 0.13, 1), Color(0.22, 0.45, 0.58, 1))
	midpoint_unlocked_button_style = _make_button_style(Color(0.22, 0.2, 0.12, 1), Color(0.98, 0.78, 0.18, 1))
	midpoint_unlocked_button_hover_style = _make_button_style(Color(0.3, 0.24, 0.12, 1), Color(1.0, 0.88, 0.32, 1))
	midpoint_locked_button_style = _make_button_style(Color(0.15, 0.14, 0.11, 1), Color(0.62, 0.48, 0.12, 1))
	final_unlocked_button_style = _make_button_style(Color(0.2, 0.12, 0.13, 1), Color(0.95, 0.18, 0.16, 1))
	final_unlocked_button_hover_style = _make_button_style(Color(0.3, 0.14, 0.12, 1), Color(1.0, 0.36, 0.24, 1))
	final_locked_button_style = _make_button_style(Color(0.14, 0.12, 0.13, 1), Color(0.62, 0.12, 0.12, 1))


func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
