extends Node2D

const VIEWPORT_FIT_SHOW_WHOLE_MAP := 0
const VIEWPORT_FIT_FILL_WINDOW := 1
const TOOL_NONE := 0
const TOOL_SHOVEL := 1
const BLOCK_NONE := 0
const LEVEL_SELECT_SCENE := "res://scenes/screens/level_select.tscn"
const FORMATION_SCENE := "res://scenes/screens/formation.tscn"
const CHAPTER_STAGE_COUNT := 12
const STAGE_SCENE_TEMPLATE := "res://scenes/stage/chapter%02d/c%02d_s%02d.tscn"
const LONG_STAGE_SCENE_TEMPLATE := "res://scenes/stage/chapter%02d_stage%02d.tscn"
const LEGACY_STAGE_SCENE_TEMPLATE := "res://scenes/stage/stage%d.tscn"
const WAVE_DATA_TEMPLATE := "res://resources/waves/c%02d_s%02d_wave_data.tres"
const LONG_WAVE_DATA_TEMPLATE := "res://resources/waves/chapter%02d_stage%02d_wave_data.tres"
const LEGACY_WAVE_DATA_TEMPLATE := "res://resources/waves/stage%d_wave_data.tres"
const GLOBAL_GROUND_TILE_RULE_STAGE := "res://scenes/stage/stage0.tscn"
const GLOBAL_GROUND_TILE_RULE_LAYER := "Ground_TML"
const GLOBAL_GROUND_TILE_DATA_LAYER_TYPES := {
	"deployable": TYPE_BOOL,
	"placement_type": TYPE_INT,
	"enemy_waypoint": TYPE_BOOL,
}
const STAGE_CLEAR_CHARACTER_UNLOCKS := {
	1: "v",
	2: "z",
	3: "y",
	4: "x",
	5: "w",
}
const CHARACTER_SCENE_TEMPLATE := "res://scenes/units/characters/%s.tscn"
const CHARACTER_TEXTURE_TEMPLATE := "res://assets/textures/characters/%s.png"
const HAND_CARD_SCENE := preload("res://scenes/ui/hand_card.tscn")
const UNIT_VISUAL_OFFSET := Vector2(0, -5)
const DEFAULT_ENEMY_SCENE := preload("res://scenes/units/enemies/enemy_1a.tscn")
const ATTACK_RANGE_PREVIEW_SCRIPT := preload("res://scripts/stage/attack_range_preview.gd")
const DAMAGE_NUMBER_SCRIPT := preload("res://scripts/ui/damage_number.gd")
const ARCHIVE_STATE := preload("res://scripts/systems/archive_state.gd")
const STAGE_CATALOG := preload("res://scripts/systems/stage_catalog.gd")
const WAVE_STATE_SPAWNING := 0
const WAVE_STATE_WAITING_FOR_CLEAR := 1
const WAVE_STATE_WAITING_AFTER_CLEAR := 2
const WAVE_STATE_FINISHED := 3
const GROUND_LAYER_Z := -20
const COMBAT_LAYER_Z := 0
const ENEMY_BODY_Z := 0
const UNIT_BODY_Z := 1
const DEPLOYABLE_TILE_OVERLAY_Z := 10
const DEPLOY_PREVIEW_Z := 20
const PROJECTILE_LAYER_Z := 25
const OVERLAY_LAYER_Z := 30
const SPLASH_PROJECTILE_HIT_SCALE_MULTIPLIER := 3.0
const SPLASH_PROJECTILE_HIT_HOLD_FRAMES := 3
const ENEMY_MARKER_POINT_OFFSET := Vector2i.ZERO
const DEFAULT_PROJECTILE_TEXTURE := preload("res://assets/textures/ui/道具ui.png")
const DEFAULT_RESUME_ICON_PATH := "res://assets/textures/ui/tools/resume.png"
const PAUSE_BUTTON_TEXT := "暂停"
const RESUME_BUTTON_TEXT := "继续"
const CONFIRM_DIALOG_SIZE := Vector2i(560, 300)
const STAGE_CLEAR_DIALOG_SIZE := Vector2i(660, 480)
const DIALOG_BUTTON_MIN_SIZE := Vector2(140, 48)
const FEEDBACK_LABEL_SIZE := Vector2(520, 54)
const FEEDBACK_LABEL_OFFSET_Y := 86.0
const DIALOG_PANEL_COLOR := Color(0.065, 0.072, 0.085, 0.96)
const DIALOG_PANEL_BORDER_COLOR := Color(0.82, 0.69, 0.38, 1.0)
const DIALOG_BUTTON_COLOR := Color(0.13, 0.14, 0.16, 0.96)
const DIALOG_BUTTON_HOVER_COLOR := Color(0.21, 0.19, 0.14, 1.0)
const DIALOG_BUTTON_PRESSED_COLOR := Color(0.28, 0.23, 0.14, 1.0)
const DIALOG_TEXT_COLOR := Color(0.92, 0.89, 0.78, 1.0)
const DIALOG_TITLE_COLOR := Color(0.98, 0.91, 0.64, 1.0)

@export_category("Stage")
@export var starting_lives := 3
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var enemy_spawn_interval := 3.0
@export var override_enemy_move_speed := false
@export var enemy_move_speed_tiles_per_second := 1.0
@export var wave_data: WaveData
@export var initial_deployment_cost := 0.0
@export var max_total_deployed_units := 0
@export var deployment_cost_growth_per_second := 0.5
@export var max_deployment_cost := 100.0

@export_category("Projectile")
@export var projectile_texture: Texture2D = DEFAULT_PROJECTILE_TEXTURE
@export var projectile_texture_region := Rect2(16, 16, 16, 16)
@export var projectile_speed_tiles_per_second := 5.0
@export var projectile_scale := Vector2.ONE
@export var priest_projectile_color := Color(0.25, 1.0, 0.35, 1.0)
@export var enemy_projectile_color := Color(1.0, 0.15, 0.1, 1.0)

@export_category("Deployment Preview")
@export var show_attack_range_preview := true
@export var attack_range_preview_fill_color := Color(0.25, 0.65, 1.0, 0.18)
@export var attack_range_preview_outline_color := Color(0.45, 0.85, 1.0, 0.75)
@export var deployable_tile_overlay_color := Color(0.1, 1.0, 0.25, 0.28)
@export_range(0.0, 8.0, 0.5)
var attack_range_preview_outline_width := 2.0

@export_category("Viewport")
@export_enum("Show Whole Map", "Fill Window Crop Edges")
var viewport_fit_mode: int = VIEWPORT_FIT_SHOW_WHOLE_MAP:
	set(value):
		viewport_fit_mode = value
		if is_node_ready():
			call_deferred("_focus_camera_on_map")

@export_range(0.5, 2.0, 0.05)
var zoom_multiplier: float = 1.0:
	set(value):
		zoom_multiplier = value
		if is_node_ready():
			call_deferred("_focus_camera_on_map")

@export var reserve_ui_safe_area := true:
	set(value):
		reserve_ui_safe_area = value
		if is_node_ready():
			call_deferred("_focus_camera_on_map")

@export_range(0.0, 128.0, 1.0)
var reserved_ui_margin := 0.0:
	set(value):
		reserved_ui_margin = value
		if is_node_ready():
			call_deferred("_focus_camera_on_map")

@export_category("Tools")
@export var shovel_cursor_texture: Texture2D
@export var shovel_target_cursor_texture: Texture2D
@export var resume_icon_texture: Texture2D
@export_range(1.0, 6.0, 0.5)
var shovel_cursor_scale: float = 3.0:
	set(value):
		shovel_cursor_scale = value
		scaled_shovel_cursor_texture = null
		scaled_shovel_target_cursor_texture = null
		has_custom_cursor = false
		if is_node_ready():
			_update_shovel_cursor()

@export var shovel_cursor_hotspot := Vector2(48, 48):
	set(value):
		shovel_cursor_hotspot = value
		has_custom_cursor = false
		if is_node_ready():
			_update_shovel_cursor()

@onready var camera: Camera2D = $Camera2D
@onready var grid_layer: TileMapLayer = $Ground_TML
@onready var overlay_layer: TileMapLayer = $Overlay_TML
@onready var units: Node2D = $Units
@onready var deploy_preview: Node2D = $DeployPreview
@onready var hand_bar: Control = $UI/HandBar
@onready var card_list: HBoxContainer = $UI/HandBar/HandMargin/CardList
@onready var tool_bar: Control = $UI/ToolBar
@onready var shovel_button: Button = $UI/ToolBar/ShovelButton
@onready var restart_button: Button = $UI/ToolBar/RestartButton
@onready var pause_button: Button = $UI/ToolBar/PauseButton
@onready var exit_button: Button = $UI/ExitButton
@onready var exit_confirm_dialog: ConfirmationDialog = $UI/ExitConfirmDialog
@onready var restart_confirm_dialog: ConfirmationDialog = $UI/RestartConfirmDialog
@onready var stage_clear_dialog: ConfirmationDialog = $UI/StageClearDialog
@onready var stage_clear_reward_portrait_container: SubViewportContainer = $UI/StageClearDialog/RewardPortraitContainer
@onready var stage_clear_reward_portrait_root: Node2D = $UI/StageClearDialog/RewardPortraitContainer/RewardPortraitViewport/RewardPortraitRoot
@onready var timer_panel: Control = $UI/TimerPanel
@onready var wave_label: Label = $UI/TimerPanel/WaveLabel
@onready var timer_label: Label = $UI/TimerPanel/TimerLabel
@onready var kill_label: Label = $UI/TimerPanel/KillLabel
@onready var cost_label: Label = $UI/CostPanel/CostLabel
@onready var cost_fraction_bar: ProgressBar = $UI/CostFractionBar
@onready var lives_label: Label = $UI/LivesLabel
@onready var failure_label: Label = $UI/FailureLabel
@onready var feedback_label: Label = $UI/FeedbackLabel
@onready var info_panel: Control = $UI/InfoPanel
@onready var info_title: Label = $UI/InfoPanel/InfoMargin/InfoRows/InfoTitle
@onready var info_body: Label = $UI/InfoPanel/InfoMargin/InfoRows/InfoBody

var dragging_card: Node
var preview_unit: Node2D
var deployable_tile_overlay: Node2D
var deploy_attack_range_preview: Node2D
var selected_unit_attack_range: Node2D
var selected_unit: Node2D
var moving_unit: Node2D
var moving_origin_position := Vector2.ZERO
var moving_origin_cell := Vector2i.ZERO
var selected_tool := TOOL_NONE
var units_by_cell: Dictionary = {}
var manual_pause_active := false
var interaction_pause_active := false
var is_using_target_cursor := false
var has_custom_cursor := false
var elapsed_time := 0.0
var scaled_shovel_cursor_texture: Texture2D
var scaled_shovel_target_cursor_texture: Texture2D
var pause_icon_texture: Texture2D
var enemies: Node2D
var projectiles: Node2D
var enemy_spawn_points: Array[Vector2] = []
var enemy_target_points: Array[Vector2] = []
var enemy_waypoint_points: Array[Vector2] = []
var enemy_teleport_points: Array[Vector2] = []
var enemy_spawn_elapsed := 0.0
var next_enemy_spawn_index := 0
var remaining_lives := 0
var is_stage_failed := false
var is_stage_cleared := false
var wave_state := WAVE_STATE_SPAWNING
var active_wave_index := 0
var main_wave_indices: Array[int] = []
var parallel_wave_indices: Array[int] = []
var wave_clear_wait_elapsed := 0.0
var active_wave_entry_states: Array[Dictionary] = []
var parallel_wave_entry_states: Dictionary = {}
var current_deployment_cost := 0.0
var spawned_enemy_count := 0
var defeated_enemy_count := 0
var total_enemy_count := 0
var deployed_unit_count := 0
var block_order_count := 0
var stage_clear_reward_unit: Node
var is_changing_scene := false
var is_stage_clear_dialog_handled := false
var is_stage_exiting := false
var feedback_tween: Tween
var skill_system_enabled := false


func _ready() -> void:
	is_stage_exiting = false
	is_changing_scene = false
	is_stage_clear_dialog_handled = false
	skill_system_enabled = ARCHIVE_STATE.is_skill_system_unlocked()
	camera.make_current()
	_load_stage_config_from_wave_resource()
	_apply_global_ground_tile_rules()
	enemies = _ensure_enemies_container()
	projectiles = _ensure_projectiles_container()
	pause_icon_texture = pause_button.icon
	if resume_icon_texture == null:
		resume_icon_texture = _load_png_texture(DEFAULT_RESUME_ICON_PATH)
	_reset_stage_pause_state()
	_configure_dialogs()
	_configure_render_order()
	remaining_lives = starting_lives
	current_deployment_cost = clampf(initial_deployment_cost, 0.0, max_deployment_cost)
	is_stage_failed = false
	is_stage_cleared = false
	_refresh_wave_runtime_indices()
	total_enemy_count = _get_total_configured_enemy_count()
	defeated_enemy_count = 0
	_collect_enemy_markers()
	_rebuild_hand_cards_from_selected_squad()
	_sort_hand_cards()
	_update_cost_label()
	_update_wave_progress_display()
	_update_enemy_defeat_display()
	_update_unlocked_hand_cards()
	_update_hand_card_affordability()
	_update_lives_display()
	failure_label.visible = false
	failure_label.text = "关卡失败"
	_configure_feedback_label()
	if _has_wave_data():
		_show_stage_feedback("第 %d 波来袭" % _get_active_main_wave_number(), Color(1.0, 0.88, 0.42, 1.0), 1.6)
	get_viewport().size_changed.connect(_focus_camera_on_map)
	_sort_hand_cards()
	for card in card_list.get_children():
		if card.has_signal("drag_started"):
			card.drag_started.connect(_on_card_drag_started)
		if card.has_signal("selected"):
			card.selected.connect(_on_card_selected)
	shovel_button.pressed.connect(_on_shovel_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
	exit_confirm_dialog.close_requested.connect(_on_modal_interaction_cancelled)
	exit_confirm_dialog.canceled.connect(_on_modal_interaction_cancelled)
	restart_confirm_dialog.confirmed.connect(_on_restart_confirmed)
	restart_confirm_dialog.close_requested.connect(_on_modal_interaction_cancelled)
	restart_confirm_dialog.canceled.connect(_on_modal_interaction_cancelled)
	stage_clear_dialog.confirmed.connect(_on_stage_clear_next_confirmed)
	stage_clear_dialog.close_requested.connect(_on_stage_clear_return_requested)
	stage_clear_dialog.canceled.connect(_on_stage_clear_return_requested)
	call_deferred("_focus_camera_on_map")


func _load_stage_config_from_wave_resource() -> void:
	if wave_data == null:
		var wave_data_path := _get_current_stage_wave_data_path()
		if not wave_data_path.is_empty():
			wave_data = load(wave_data_path) as WaveData

	if wave_data == null:
		return

	initial_deployment_cost = maxf(float(wave_data.initial_deployment_cost), 0.0)
	max_total_deployed_units = maxi(int(wave_data.max_total_deployed_units), 0)


func _exit_tree() -> void:
	is_stage_exiting = true
	Input.set_custom_mouse_cursor(null)
	_clear_projectiles()


func _configure_dialogs() -> void:
	_configure_dialog(exit_confirm_dialog, CONFIRM_DIALOG_SIZE)
	_configure_dialog(restart_confirm_dialog, CONFIRM_DIALOG_SIZE)
	_configure_dialog(stage_clear_dialog, STAGE_CLEAR_DIALOG_SIZE)
	_configure_stage_clear_reward_portrait()


func _configure_dialog(dialog: ConfirmationDialog, dialog_size: Vector2i) -> void:
	if dialog == null:
		return

	dialog.min_size = dialog_size
	if dialog.has_method("add_theme_stylebox_override"):
		dialog.call("add_theme_stylebox_override", "embedded_border", _make_dialog_panel_style())
		dialog.call("add_theme_stylebox_override", "embedded_unfocused_border", _make_dialog_panel_style())
	if dialog.has_method("add_theme_font_size_override"):
		dialog.call("add_theme_font_size_override", "title_font_size", 28)
		if dialog == stage_clear_dialog:
			dialog.call("add_theme_font_size_override", "title_font_size", 1)
	if dialog.has_method("add_theme_color_override"):
		dialog.call("add_theme_color_override", "title_color", DIALOG_TITLE_COLOR)

	var label := dialog.get_label()
	if label != null:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", DIALOG_TEXT_COLOR)
		label.add_theme_font_size_override("font_size", 24)
		if dialog == stage_clear_dialog:
			label.add_theme_color_override("font_color", DIALOG_TITLE_COLOR)
			label.add_theme_font_size_override("font_size", 46)

	_configure_dialog_button(dialog.get_ok_button(), true)
	_configure_dialog_button(dialog.get_cancel_button(), false)


func _configure_dialog_button(button: Button, is_primary: bool) -> void:
	if button == null:
		return

	button.custom_minimum_size = DIALOG_BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", DIALOG_TITLE_COLOR if is_primary else DIALOG_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", DIALOG_TITLE_COLOR)
	button.add_theme_color_override("font_pressed_color", DIALOG_TITLE_COLOR)
	button.add_theme_stylebox_override("normal", _make_dialog_button_style(DIALOG_BUTTON_COLOR, DIALOG_PANEL_BORDER_COLOR))
	button.add_theme_stylebox_override("hover", _make_dialog_button_style(DIALOG_BUTTON_HOVER_COLOR, DIALOG_TITLE_COLOR))
	button.add_theme_stylebox_override("pressed", _make_dialog_button_style(DIALOG_BUTTON_PRESSED_COLOR, DIALOG_TITLE_COLOR))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _configure_stage_clear_reward_portrait() -> void:
	if stage_clear_reward_portrait_container == null:
		return

	stage_clear_reward_portrait_container.offset_left = 210.0
	stage_clear_reward_portrait_container.offset_top = 112.0
	stage_clear_reward_portrait_container.offset_right = 450.0
	stage_clear_reward_portrait_container.offset_bottom = 352.0
	stage_clear_reward_portrait_container.custom_minimum_size = Vector2(240, 240)
	stage_clear_reward_portrait_container.stretch = false

	var reward_viewport := stage_clear_reward_portrait_container.get_node_or_null("RewardPortraitViewport") as SubViewport
	if reward_viewport != null:
		reward_viewport.size = Vector2i(240, 240)


func _make_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DIALOG_PANEL_COLOR
	style.border_color = DIALOG_PANEL_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_top = 24.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 24.0
	return style


func _make_dialog_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	return style


func _process(_delta: float) -> void:
	_refresh_unit_cells()
	_update_enemy_blockers()
	_update_unit_armed_states()
	_update_shovel_cursor()
	if not get_tree().paused and not is_stage_failed and not is_stage_cleared:
		elapsed_time += _delta
		current_deployment_cost = clampf(
			current_deployment_cost + maxf(_get_effective_deployment_cost_growth_per_second(), 0.0) * _delta,
			0.0,
			max_deployment_cost
		)
		_update_timer_label()
		_update_cost_label()
		_process_unit_actions(_delta)
		_process_enemy_actions(_delta)
		if _has_wave_data():
			_process_wave_spawning(_delta)
		else:
			_process_enemy_spawning(_delta)

	if preview_unit == null:
		return

	var preview_position := _get_mouse_cell_center()
	preview_unit.global_position = preview_position
	_update_attack_range_preview(preview_position)
	var can_afford_preview := current_deployment_cost >= _get_deploy_source_cost(preview_unit)
	var preview_cell := _get_mouse_cell()
	preview_unit.modulate = Color(1, 1, 1, 0.55) if can_afford_preview and _can_deploy_at_cell(preview_cell, preview_unit) and _can_deploy_source_with_limit(preview_unit, preview_cell) and _can_deploy_with_total_limit(preview_cell) else Color(1, 0.25, 0.25, 0.55)


func _input(event: InputEvent) -> void:
	if _is_back_input_event(event) and _close_visible_confirm_dialog():
		get_viewport().set_input_as_handled()
		return

	if _is_pause_toggle_event(event):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit_stage"):
		_hide_unit_info_panel()
		_on_exit_button_pressed()
		get_viewport().set_input_as_handled()
		return

	if _is_back_input_event(event):
		_handle_back_input()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_tool == TOOL_SHOVEL:
			_try_remove_unit_at_mouse()
			get_viewport().set_input_as_handled()
			return
		if dragging_card == null:
			_handle_unit_selection_at_mouse()
			get_viewport().set_input_as_handled()
			return

	if dragging_card != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_deploy()
		get_viewport().set_input_as_handled()


func _focus_camera_on_map() -> void:
	var map_bounds := _get_map_bounds()
	if map_bounds.size.x <= 0.0 or map_bounds.size.y <= 0.0:
		return

	var viewport_size := Vector2(get_viewport_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var safe_area := _get_camera_safe_area()
	var fit_size := safe_area.size
	var width_zoom: float = fit_size.x / map_bounds.size.x
	var height_zoom: float = fit_size.y / map_bounds.size.y
	var zoom_to_fit_map: float = min(width_zoom, height_zoom)
	if viewport_fit_mode == VIEWPORT_FIT_FILL_WINDOW:
		zoom_to_fit_map = max(width_zoom, height_zoom)

	camera.zoom = Vector2.ONE * zoom_to_fit_map * zoom_multiplier
	var screen_offset := safe_area.get_center() - viewport_size * 0.5
	camera.global_position = map_bounds.get_center() - screen_offset / camera.zoom


func _get_camera_safe_area() -> Rect2:
	var viewport_size := Vector2(get_viewport_rect().size)
	if not reserve_ui_safe_area:
		return Rect2(Vector2.ZERO, viewport_size)

	var safe_top := reserved_ui_margin
	var safe_bottom := viewport_size.y - reserved_ui_margin

	for control in [exit_button, timer_panel, tool_bar]:
		if control is Control and control.visible:
			var rect: Rect2 = control.get_global_rect()
			if rect.size.y > 0.0:
				safe_top = maxf(safe_top, rect.end.y + reserved_ui_margin)

	for control in [hand_bar]:
		if control is Control and control.visible:
			var rect: Rect2 = control.get_global_rect()
			if rect.size.y > 0.0:
				safe_bottom = minf(safe_bottom, rect.position.y - reserved_ui_margin)

	if safe_bottom <= safe_top:
		return Rect2(Vector2.ZERO, viewport_size)

	return Rect2(Vector2(0.0, safe_top), Vector2(viewport_size.x, safe_bottom - safe_top))


func _rebuild_hand_cards_from_selected_squad() -> void:
	if card_list == null:
		return

	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()

	var added_base_ids: Array[String] = []
	for unit_id in ARCHIVE_STATE.get_selected_squad():
		var normalized_id := _get_base_character_id(str(unit_id).to_lower())
		if normalized_id.is_empty() or not ARCHIVE_STATE.is_character_unlocked(normalized_id):
			continue
		if added_base_ids.has(normalized_id):
			continue
		added_base_ids.append(normalized_id)

		var variant_id := ARCHIVE_STATE.get_character_variant(normalized_id)
		var unit_scene := load(CHARACTER_SCENE_TEMPLATE % variant_id) as PackedScene
		if unit_scene == null:
			continue

		var card := HAND_CARD_SCENE.instantiate()
		card.name = "%sCard" % variant_id.to_upper()
		if "unit_id" in card:
			card.unit_id = variant_id
		if "unit_scene" in card:
			card.unit_scene = unit_scene
		if card.has_method("set_skill_system_enabled"):
			card.set_skill_system_enabled(ARCHIVE_STATE.is_character_skill_unlocked(variant_id))
		if card.has_method("set_skill_charge_limit"):
			card.set_skill_charge_limit(mini(2, _get_deploy_source_limit(card)))
		if "preview_texture" in card:
			card.preview_texture = _get_character_preview_texture(normalized_id)
		card_list.add_child(card)


func _get_character_preview_texture(unit_id: String) -> Texture2D:
	var texture_id := _get_base_character_id(unit_id)
	if texture_id.is_empty():
		texture_id = unit_id
	var texture_path := CHARACTER_TEXTURE_TEMPLATE % texture_id
	if not ResourceLoader.exists(texture_path):
		return null
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(0, 0, 32, 32)
	return atlas_texture


func _get_base_character_id(unit_id: String) -> String:
	var result := ""
	for index in unit_id.length():
		var character := unit_id.substr(index, 1)
		if character < "a" or character > "z":
			break
		result += character
	return result


func _is_character_skill_enabled(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit) or not "unit_id" in unit:
		return false
	var base_id := _get_base_character_id(str(unit.unit_id).to_lower())
	return not base_id.is_empty() and ARCHIVE_STATE.is_character_skill_unlocked(base_id)


func _sort_hand_cards() -> void:
	if card_list == null:
		return

	var cards := card_list.get_children()
	cards.sort_custom(_is_hand_card_before)
	for index in cards.size():
		card_list.move_child(cards[index], index)


func _update_unlocked_hand_cards() -> void:
	if card_list == null:
		return

	var selected_squad := ARCHIVE_STATE.get_selected_squad()
	var selected_base_ids: Array[String] = []
	for selected_id in selected_squad:
		var base_id := _get_base_character_id(str(selected_id).to_lower())
		if not selected_base_ids.has(base_id):
			selected_base_ids.append(base_id)
	for card in card_list.get_children():
		if not "unit_id" in card:
			continue
		var unit_id := str(card.unit_id).to_lower()
		var card_base_id := _get_base_character_id(unit_id)
		card.visible = selected_base_ids.has(card_base_id) and ARCHIVE_STATE.is_character_unlocked(card_base_id)
	_resize_hand_bar_to_visible_cards()


func _resize_hand_bar_to_visible_cards() -> void:
	if hand_bar == null or card_list == null:
		return

	var visible_count := 0
	var cards_width := 0.0
	for card in card_list.get_children():
		if card is Control and card.visible:
			visible_count += 1
			cards_width += (card as Control).custom_minimum_size.x

	var width := _get_hand_bar_horizontal_padding()
	if visible_count > 0:
		width += cards_width + _get_card_list_separation() * max(visible_count - 1, 0)

	hand_bar.offset_left = hand_bar.offset_right - width
	call_deferred("_focus_camera_on_map")


func _get_hand_bar_horizontal_padding() -> float:
	var margin := hand_bar.get_node_or_null("HandMargin") as MarginContainer
	if margin == null:
		return 0.0

	return float(margin.get_theme_constant("margin_left")) + float(margin.get_theme_constant("margin_right"))


func _get_card_list_separation() -> float:
	return float(card_list.get_theme_constant("separation"))


func _is_hand_card_before(a: Node, b: Node) -> bool:
	var a_cost := _get_hand_card_deploy_cost(a)
	var b_cost := _get_hand_card_deploy_cost(b)
	if a_cost != b_cost:
		return a_cost < b_cost

	var a_profession := _get_hand_card_profession(a)
	var b_profession := _get_hand_card_profession(b)
	if a_profession != b_profession:
		return a_profession < b_profession

	return str(a.name) < str(b.name)


func _get_hand_card_deploy_cost(card: Node) -> int:
	if card != null and card.has_method("get_deploy_cost"):
		return int(card.get_deploy_cost())
	return _get_deploy_source_cost(card)


func _get_hand_card_profession(card: Node) -> int:
	if card != null and card.has_method("get_unit_profession"):
		return int(card.get_unit_profession())
	if card != null and "unit_scene" in card and card.unit_scene is PackedScene:
		var unit: Node = card.unit_scene.instantiate()
		var profession := 0
		if "profession" in unit:
			profession = int(unit.profession)
		unit.queue_free()
		return profession
	return 0


func _on_card_drag_started(card: Node) -> void:
	if dragging_card == card:
		return

	_begin_interaction_pause()
	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
		_clear_deploy_preview()
	_clear_selected_unit_attack_range()
	_hide_unit_info_panel()
	_cancel_shovel_tool(false)
	dragging_card = card
	dragging_card.set_available(false)
	_create_deploy_preview()


func _on_card_selected(card: Node) -> void:
	var unit := _instantiate_card_unit(card)
	if unit == null:
		_hide_unit_info_panel()
		return

	_show_unit_info_panel(unit, card, false)
	unit.queue_free()


func _get_hand_card_for_base_id(base_id: String) -> Node:
	if card_list == null:
		return null
	for card in card_list.get_children():
		if card != null and "unit_id" in card and _get_base_character_id(str(card.unit_id).to_lower()) == base_id:
			return card
	return null


func _on_unit_skill_ready(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit) or _is_invalid_combat_unit(unit) or not _is_character_skill_enabled(unit):
		return
	var base_id := _get_base_character_id(_get_unit_id(unit))
	var card := _get_hand_card_for_base_id(base_id)
	if card == null or not card.has_method("add_skill_charge"):
		return
	card.add_skill_charge()
	var charge_limit := int(card.skill_charge_limit) if "skill_charge_limit" in card else 1
	if int(card.get_skill_charges()) < charge_limit and unit.has_method("reset_skill_charge"):
		unit.reset_skill_charge()


func _convert_oldest_full_skill_bar(base_id: String) -> void:
	if units == null or base_id.is_empty():
		return

	var full_units: Array[Node] = []
	for unit in units.get_children():
		if unit == null or not is_instance_valid(unit) or _is_invalid_combat_unit(unit):
			continue
		if _get_base_character_id(_get_unit_id(unit)) != base_id:
			continue
		if not ("skill_charge" in unit and "skill_charge_max" in unit):
			continue
		if float(unit.skill_charge) < float(unit.skill_charge_max):
			continue
		full_units.append(unit)

	if full_units.is_empty():
		return
	full_units.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta("deploy_order", 0)) < int(b.get_meta("deploy_order", 0))
	)
	var oldest_full_unit := full_units[0]
	if oldest_full_unit.has_method("reset_skill_charge"):
		oldest_full_unit.reset_skill_charge()


func add_unit_skill_charge(unit: Node, amount: float) -> void:
	if _is_character_skill_enabled(unit) and unit.has_method("add_skill_charge"):
		unit.add_skill_charge(amount)


func _add_skill_charge_from_method(unit: Node, amount: float) -> void:
	if unit == null or not is_instance_valid(unit) or amount <= 0.0 or not _is_character_skill_enabled(unit):
		return
	if unit.has_method("add_skill_charge"):
		unit.add_skill_charge(amount)


func _apply_field_time_skill_charge(unit: Node, delta: float) -> void:
	var method := _get_string_property(unit, "upgrade_method", "")
	if method.is_empty() or not method.contains("在场") or not method.contains("秒"):
		return
	_add_skill_charge_from_method(unit, _extract_number_after(method, "获得", 0.0) * delta)


func _award_skill_charge_for_attack_hit(source: Node, target: Node, actual_damage: float) -> void:
	if source == null or not is_instance_valid(source) or actual_damage <= 0.0:
		return
	_track_enemy_skill_charge_contributor(target, source)
	var method := _get_string_property(source, "upgrade_method", "")
	if method.is_empty():
		return
	if method.contains("攻击到"):
		_add_skill_charge_from_method(source, _extract_number_after(method, "获得", 0.0))
	if method.contains("造成") and method.contains("伤害"):
		var damage_step := maxf(_extract_number_after(method, "每造成", 1.0), 0.001)
		var gain := _extract_number_after(method, "获得", 1.0)
		_add_skill_charge_from_method(source, actual_damage / damage_step * gain)


func _award_skill_charge_for_damage_taken(unit: Node, actual_damage: float) -> void:
	if unit == null or not is_instance_valid(unit) or actual_damage <= 0.0:
		return
	var method := _get_string_property(unit, "upgrade_method", "")
	if method.is_empty() or not method.contains("受到") or not method.contains("伤害"):
		return
	_add_skill_charge_from_method(unit, actual_damage * _extract_number_after(method, "获得", 1.0))


func _award_skill_charge_for_healing(source: Node, healed_amount: float) -> void:
	if source == null or not is_instance_valid(source) or healed_amount <= 0.0:
		return
	var method := _get_string_property(source, "upgrade_method", "")
	if method.is_empty() or not method.contains("治疗"):
		return
	_add_skill_charge_from_method(source, healed_amount * _extract_number_after(method, "获得", 1.0))


func _award_skill_charge_for_kill_participants(enemy: Node) -> void:
	if enemy == null or not enemy.has_meta("skill_charge_contributors"):
		return
	for contributor in enemy.get_meta("skill_charge_contributors", []):
		if contributor == null or not is_instance_valid(contributor):
			continue
		var method := _get_string_property(contributor, "upgrade_method", "")
		if method.contains("击杀"):
			_add_skill_charge_from_method(contributor, _extract_number_after(method, "获得", 0.0))


func _track_enemy_skill_charge_contributor(enemy: Node, contributor: Node) -> void:
	if enemy == null or contributor == null or not is_instance_valid(enemy) or not is_instance_valid(contributor):
		return
	if not ("enemy_id" in enemy):
		return
	var contributors: Array = enemy.get_meta("skill_charge_contributors", [])
	if not contributors.has(contributor):
		contributors.append(contributor)
		enemy.set_meta("skill_charge_contributors", contributors)


func _extract_number_after(text: String, marker: String, fallback: float) -> float:
	var marker_index := text.find(marker)
	if marker_index < 0:
		return fallback
	var start_index := marker_index + marker.length()
	var number_text := ""
	var has_digit := false
	for index in range(start_index, text.length()):
		var character := text.substr(index, 1)
		if character.is_valid_int():
			number_text += character
			has_digit = true
		elif character == "." and has_digit and not number_text.contains("."):
			number_text += character
		elif has_digit:
			break
	if number_text.is_valid_float():
		return number_text.to_float()
	return fallback


func _create_deploy_preview() -> void:
	_clear_deploy_preview()

	var unit_scene := _get_dragging_card_unit_scene()
	if unit_scene == null:
		return

	preview_unit = unit_scene.instantiate()
	deploy_preview.add_child(preview_unit)
	preview_unit.modulate = Color(1, 1, 1, 0.72)
	preview_unit.process_mode = Node.PROCESS_MODE_DISABLED
	preview_unit.global_position = _get_mouse_cell_center()
	_configure_unit_for_grid(preview_unit)
	_show_deployable_tile_overlay(dragging_card)
	_create_attack_range_preview(preview_unit)
	_update_attack_range_preview(preview_unit.global_position)


func _finish_deploy() -> void:
	_hide_unit_info_panel()
	_refresh_unit_cells()
	var skill_target := _get_unit_at_mouse()
	if _try_activate_skill_on_unit(skill_target):
		_clear_deploy_preview()
		dragging_card.set_available(true)
		dragging_card = null
		_end_interaction_pause()
		return
	var deploy_cell := _get_mouse_cell()
	_try_deploy_dragging_card_at_cell(deploy_cell)
	_end_interaction_pause()


func _try_activate_skill_on_unit(target: Node) -> bool:
	if dragging_card == null or target == null or not is_instance_valid(target) or not _is_character_skill_enabled(dragging_card):
		return false
	if not dragging_card.has_method("get_skill_charges") or dragging_card.get_skill_charges() <= 0:
		return false
	var card_base_id := _get_base_character_id(str(dragging_card.unit_id).to_lower())
	if _get_base_character_id(_get_unit_id(target)) != card_base_id:
		return false
	if target.has_method("activate_skill"):
		target.activate_skill()
	if dragging_card.has_method("consume_skill_charge"):
		if dragging_card.consume_skill_charge():
			_convert_oldest_full_skill_bar(card_base_id)
	return true


func _try_deploy_dragging_card_at_cell(deploy_cell: Vector2i) -> bool:
	if dragging_card == null:
		return false

	var deploy_position := _cell_to_global_center(deploy_cell)
	_clear_deploy_preview()

	var deploy_cost := _get_deploy_source_cost(dragging_card)
	if dragging_card.has_method("is_on_cooldown") and dragging_card.is_on_cooldown():
		_show_stage_feedback("角色部署冷却中", Color(1.0, 0.38, 0.25, 1.0))
		dragging_card.set_available(true)
		dragging_card = null
		return false
	if current_deployment_cost < deploy_cost or not _can_deploy_at_cell(deploy_cell, dragging_card) or not _can_deploy_source_with_limit(dragging_card, deploy_cell) or not _can_deploy_with_total_limit(deploy_cell):
		_show_stage_feedback(_get_deploy_failure_reason(deploy_cell, dragging_card, deploy_cost), Color(1.0, 0.38, 0.25, 1.0))
		dragging_card.set_available(true)
		dragging_card = null
		return false

	var unit_scene := _get_dragging_card_unit_scene()
	if unit_scene == null:
		_show_stage_feedback("无法读取单位", Color(1.0, 0.38, 0.25, 1.0))
		dragging_card.set_available(true)
		dragging_card = null
		return false

	_replace_unit_at_cell_for_deploy(deploy_cell)

	var unit: Node2D = unit_scene.instantiate()
	units.add_child(unit)
	unit.z_as_relative = true
	unit.z_index = UNIT_BODY_Z
	unit.global_position = deploy_position
	unit.set_meta("deploy_order", deployed_unit_count)
	deployed_unit_count += 1
	_configure_unit_for_grid(unit)
	unit.set_meta("grid_cell", deploy_cell)
	if unit.has_signal("defeat_started"):
		unit.defeat_started.connect(_on_unit_defeat_started.bind(unit))
	if unit.has_signal("defeated"):
		unit.defeated.connect(_on_unit_defeated.bind(unit))
	if unit.has_signal("skill_ready"):
		unit.skill_ready.connect(_on_unit_skill_ready)

	units_by_cell[deploy_cell] = unit
	current_deployment_cost = maxf(current_deployment_cost - deploy_cost, 0.0)
	_update_cost_label()
	_show_stage_feedback("部署成功", Color(0.58, 0.92, 0.62, 1.0))

	if dragging_card.has_method("start_cooldown"):
		dragging_card.start_cooldown(_get_deploy_source_cooldown(dragging_card))
	else:
		dragging_card.set_available(true)
	dragging_card = null
	return true


func _clear_deploy_preview() -> void:
	_clear_deploy_attack_range_preview()
	_clear_deployable_tile_overlay()

	if preview_unit == null:
		return

	preview_unit.queue_free()
	preview_unit = null


func _get_dragging_card_unit_scene() -> PackedScene:
	if dragging_card == null:
		return null
	if dragging_card.has_method("get_active_unit_scene"):
		return dragging_card.get_active_unit_scene()
	if not ("unit_scene" in dragging_card):
		return null
	return dragging_card.unit_scene


func _on_unit_defeated(unit_id: String, unit: Node) -> void:
	_remove_unit_from_stage_tracking(unit)


func _on_unit_defeat_started(unit_id: String, unit: Node) -> void:
	_remove_unit_from_stage_tracking(unit)


func _remove_unit_from_stage_tracking(unit: Node) -> void:
	if unit.has_meta("grid_cell"):
		units_by_cell.erase(unit.get_meta("grid_cell"))
	if unit == selected_unit:
		_clear_selected_unit_attack_range()


func _on_shovel_button_pressed() -> void:
	_hide_unit_info_panel()
	_clear_selected_unit_attack_range()
	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
		_clear_deploy_preview()
	if shovel_button.button_pressed:
		_begin_interaction_pause()
		selected_tool = TOOL_SHOVEL
	else:
		selected_tool = TOOL_NONE
		_end_interaction_pause()
	_update_shovel_cursor()


func _try_remove_unit_at_mouse() -> void:
	_refresh_unit_cells()
	var unit := _get_unit_at_mouse()
	if unit == null:
		_cancel_shovel_tool()
		return

	_refund_removed_unit_deploy_cost(unit)
	_remove_unit_from_stage_tracking(unit)
	if unit.has_method("defeat"):
		unit.defeat()
	_cancel_shovel_tool()


func _replace_unit_at_cell_for_deploy(cell: Vector2i) -> void:
	_refresh_unit_cells()
	if not units_by_cell.has(cell):
		return

	var unit: Node = units_by_cell[cell]
	_refund_removed_unit_deploy_cost(unit)
	_remove_unit_from_stage_tracking(unit)
	if unit.has_method("defeat"):
		unit.defeat()
	else:
		unit.queue_free()


func _refund_removed_unit_deploy_cost(unit: Node) -> void:
	if unit == null:
		return
	if not ("deploy_cost" in unit):
		return

	current_deployment_cost = clampf(current_deployment_cost + float(unit.deploy_cost) * 0.5, 0.0, max_deployment_cost)
	_update_cost_label()


func _update_shovel_cursor() -> void:
	var is_active := selected_tool == TOOL_SHOVEL
	if not is_active:
		Input.set_custom_mouse_cursor(null)
		is_using_target_cursor = false
		has_custom_cursor = false
		return

	var should_use_target_cursor := _get_unit_at_mouse() != null
	if has_custom_cursor and should_use_target_cursor == is_using_target_cursor:
		return

	is_using_target_cursor = should_use_target_cursor
	has_custom_cursor = true
	var cursor_texture := _get_scaled_shovel_cursor_texture(should_use_target_cursor)
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, shovel_cursor_hotspot)


func _get_scaled_shovel_cursor_texture(use_target_cursor: bool) -> Texture2D:
	if use_target_cursor:
		if scaled_shovel_target_cursor_texture == null:
			scaled_shovel_target_cursor_texture = _make_scaled_cursor_texture(shovel_target_cursor_texture)
		return scaled_shovel_target_cursor_texture

	if scaled_shovel_cursor_texture == null:
		scaled_shovel_cursor_texture = _make_scaled_cursor_texture(shovel_cursor_texture)
	return scaled_shovel_cursor_texture


func _make_scaled_cursor_texture(source_texture: Texture2D) -> Texture2D:
	if source_texture == null:
		return null

	var image := source_texture.get_image()
	if image == null:
		return source_texture

	image.resize(
		int(image.get_width() * shovel_cursor_scale),
		int(image.get_height() * shovel_cursor_scale),
		Image.INTERPOLATE_NEAREST
	)
	return ImageTexture.create_from_image(image)


func _cancel_shovel_tool(should_end_interaction_pause := true) -> void:
	selected_tool = TOOL_NONE
	shovel_button.button_pressed = false
	_update_shovel_cursor()
	if should_end_interaction_pause:
		_end_interaction_pause()


func _begin_modal_interaction() -> void:
	_begin_interaction_pause()
	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
		_clear_deploy_preview()
	_clear_selected_unit_attack_range()
	_hide_unit_info_panel()
	_cancel_shovel_tool(false)


func _on_restart_button_pressed() -> void:
	if is_stage_failed or is_stage_cleared:
		_restart_stage_without_confirm()
		return

	_begin_modal_interaction()
	exit_confirm_dialog.hide()
	stage_clear_dialog.hide()
	restart_confirm_dialog.popup_centered(CONFIRM_DIALOG_SIZE)


func _on_pause_button_pressed() -> void:
	if is_stage_failed or is_stage_cleared:
		_restart_stage_without_confirm()
		return

	var was_paused := get_tree().paused or manual_pause_active or interaction_pause_active
	if was_paused:
		_cancel_current_operation()
		manual_pause_active = false
		interaction_pause_active = false
		_sync_stage_pause()
		return
	_set_manual_pause(true)


func _toggle_pause() -> void:
	if is_stage_failed or is_stage_cleared:
		_restart_stage_without_confirm()
		return

	_clear_stale_interaction_pause()
	_set_manual_pause(not manual_pause_active)


func _is_pause_toggle_event(event: InputEvent) -> bool:
	if not event.is_action_pressed("pause_toggle"):
		return false
	if event is InputEventKey and event.echo:
		return false
	return true


func _set_manual_pause(is_paused: bool) -> void:
	manual_pause_active = is_paused
	_sync_stage_pause()


func _begin_interaction_pause() -> void:
	if interaction_pause_active:
		return

	interaction_pause_active = true
	_sync_stage_pause()


func _end_interaction_pause() -> void:
	if not interaction_pause_active:
		return

	interaction_pause_active = false
	_sync_stage_pause()


func _set_stage_paused(is_paused: bool) -> void:
	manual_pause_active = is_paused
	interaction_pause_active = false
	_sync_stage_pause()


func _reset_stage_pause_state() -> void:
	manual_pause_active = false
	interaction_pause_active = false
	get_tree().paused = false
	if pause_button != null:
		pause_button.button_pressed = false
		pause_button.text = PAUSE_BUTTON_TEXT
		pause_button.icon = pause_icon_texture


func _sync_stage_pause() -> void:
	var is_paused := manual_pause_active or interaction_pause_active or is_stage_failed or is_stage_cleared
	get_tree().paused = is_paused
	pause_button.button_pressed = is_paused
	pause_button.text = RESUME_BUTTON_TEXT if is_paused else PAUSE_BUTTON_TEXT
	pause_button.icon = resume_icon_texture if is_paused and resume_icon_texture != null else pause_icon_texture


func _configure_feedback_label() -> void:
	if feedback_label == null:
		return

	feedback_label.visible = false
	feedback_label.modulate.a = 0.0
	feedback_label.custom_minimum_size = FEEDBACK_LABEL_SIZE
	feedback_label.offset_left = -FEEDBACK_LABEL_SIZE.x * 0.5
	feedback_label.offset_top = FEEDBACK_LABEL_OFFSET_Y
	feedback_label.offset_right = FEEDBACK_LABEL_SIZE.x * 0.5
	feedback_label.offset_bottom = FEEDBACK_LABEL_OFFSET_Y + FEEDBACK_LABEL_SIZE.y


func _show_stage_feedback(message: String, color := Color(0.96, 0.93, 0.76, 1.0), hold_time := 1.35) -> void:
	if feedback_label == null or message.strip_edges().is_empty():
		return

	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.visible = true
	feedback_label.modulate.a = 1.0
	feedback_tween = create_tween()
	feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	feedback_tween.tween_interval(hold_time)
	feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.3)
	feedback_tween.tween_callback(func() -> void:
		if feedback_label != null:
			feedback_label.visible = false
	)


func _load_png_texture(path: String) -> Texture2D:
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return null

	var image := Image.new()
	if image.load_png_from_buffer(data) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _update_timer_label() -> void:
	var total_seconds := int(elapsed_time)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _update_wave_progress_display() -> void:
	if wave_label == null:
		return

	if not _has_wave_data() or main_wave_indices.is_empty():
		wave_label.text = "波次 -"
		return

	var total_waves := main_wave_indices.size()
	var display_wave := clampi(active_wave_index + 1, 1, total_waves)
	var remaining_in_wave := _get_active_wave_remaining_count()
	wave_label.text = "波次 %d/%d  剩余 %d" % [display_wave, total_waves, remaining_in_wave]


func _update_enemy_defeat_display() -> void:
	if kill_label == null:
		return

	if total_enemy_count <= 0:
		kill_label.text = "击杀 %d" % defeated_enemy_count
		_update_wave_progress_display()
		return

	kill_label.text = "击杀 %d/%d" % [defeated_enemy_count, total_enemy_count]
	_update_wave_progress_display()


func _get_active_wave_remaining_count() -> int:
	if not _has_wave_data() or active_wave_index < 0 or active_wave_index >= main_wave_indices.size():
		return 0

	var remaining := _get_active_main_wave_enemy_count()
	for state in active_wave_entry_states:
		var entry: EnemySpawnEntry = state.get("entry", null)
		if entry == null:
			continue
		remaining += maxi(entry.count - int(state.get("spawned", 0)), 0)
	return remaining


func _update_cost_label() -> void:
	if cost_label == null:
		return

	current_deployment_cost = clampf(current_deployment_cost, 0.0, max_deployment_cost)
	cost_label.text = "%d（%s/s）" % [
		int(floorf(current_deployment_cost)),
		_format_float(maxf(_get_effective_deployment_cost_growth_per_second(), 0.0))
	]
	if cost_fraction_bar != null:
		cost_fraction_bar.value = (current_deployment_cost - floorf(current_deployment_cost)) * 100.0
	_update_hand_card_affordability()

func _update_hand_card_affordability() -> void:
	if card_list == null:
		return

	for card in card_list.get_children():
		if not card.has_method("set_affordable"):
			continue
		var can_afford := current_deployment_cost >= _get_hand_card_deploy_cost(card) and _can_deploy_source_with_limit(card)
		card.set_affordable(can_afford)


func _get_effective_deployment_cost_growth_per_second() -> float:
	var growth := deployment_cost_growth_per_second
	if units == null:
		return growth

	for unit in units.get_children():
		if _is_invalid_combat_unit(unit):
			continue
		growth += _get_float_property(unit, "deployment_cost_growth_bonus", 0.0)
	return growth


func _on_exit_button_pressed() -> void:
	_begin_modal_interaction()
	restart_confirm_dialog.hide()
	stage_clear_dialog.hide()
	exit_confirm_dialog.popup_centered(CONFIRM_DIALOG_SIZE)


func _handle_back_input() -> void:
	if _close_visible_confirm_dialog():
		return

	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
		_clear_deploy_preview()
		_end_interaction_pause()
		return

	if selected_tool == TOOL_SHOVEL:
		_cancel_shovel_tool()
		return

	_on_exit_button_pressed()


func _on_exit_confirmed() -> void:
	_reset_stage_pause_state()
	Input.set_custom_mouse_cursor(null)
	_change_scene_to_file_once(LEVEL_SELECT_SCENE)


func _on_restart_confirmed() -> void:
	restart_confirm_dialog.hide()
	exit_confirm_dialog.hide()
	stage_clear_dialog.hide()
	_restart_stage_without_confirm()


func _on_stage_clear_return_requested() -> void:
	if is_stage_clear_dialog_handled:
		return

	is_stage_clear_dialog_handled = true
	_reset_stage_pause_state()
	Input.set_custom_mouse_cursor(null)
	_change_scene_to_file_once(LEVEL_SELECT_SCENE)


func _on_stage_clear_next_confirmed() -> void:
	if is_stage_clear_dialog_handled:
		return

	is_stage_clear_dialog_handled = true
	_reset_stage_pause_state()
	Input.set_custom_mouse_cursor(null)
	var next_stage_path := _get_next_stage_scene_path()
	if next_stage_path.is_empty():
		_change_scene_to_file_once(LEVEL_SELECT_SCENE)
		return

	ARCHIVE_STATE.set_target_stage_path(next_stage_path)
	_change_scene_to_file_once(FORMATION_SCENE)


func _change_scene_to_file_once(scene_path: String) -> void:
	if is_changing_scene:
		return
	if scene_path.strip_edges().is_empty():
		return

	is_changing_scene = true
	is_stage_exiting = true
	_clear_projectiles()
	call_deferred("_change_scene_to_file_deferred", scene_path)


func _change_scene_to_file_deferred(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _clear_projectiles() -> void:
	if projectiles == null or not is_instance_valid(projectiles):
		return

	for projectile in projectiles.get_children():
		projectile.queue_free()


func _restart_stage_without_confirm() -> void:
	is_stage_exiting = true
	_clear_projectiles()
	_reset_stage_pause_state()
	Input.set_custom_mouse_cursor(null)
	_reload_current_scene_unpaused()


func _reload_current_scene_unpaused() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().reload_current_scene()


func _get_current_stage_number() -> int:
	var stage_ref := _get_current_stage_reference()
	if stage_ref.is_empty():
		return 0
	return int(stage_ref["global_stage_number"])


func _get_current_stage_reference() -> Dictionary:
	var scene_path := scene_file_path
	var catalog_entry := STAGE_CATALOG.get_stage_by_scene_path(scene_path)
	if not catalog_entry.is_empty():
		return catalog_entry

	var file_name := scene_path.get_file().get_basename()
	var short_match := RegEx.create_from_string("^c(\\d+)_s(\\d+)$").search(file_name)
	if short_match != null:
		var chapter := short_match.get_string(1).to_int()
		var stage := short_match.get_string(2).to_int()
		if chapter > 0 and stage > 0:
			return _make_stage_reference(chapter, stage)

	var chapter_match := RegEx.create_from_string("^chapter(\\d+)_stage(\\d+)$").search(file_name)
	if chapter_match != null:
		var chapter := chapter_match.get_string(1).to_int()
		var stage := chapter_match.get_string(2).to_int()
		if chapter > 0 and stage > 0:
			return _make_stage_reference(chapter, stage)

	if file_name.begins_with("stage"):
		var global_stage_number := file_name.trim_prefix("stage").to_int()
		if global_stage_number > 0:
			var chapter := int((global_stage_number - 1) / CHAPTER_STAGE_COUNT) + 1
			var stage := ((global_stage_number - 1) % CHAPTER_STAGE_COUNT) + 1
			return _make_stage_reference(chapter, stage)

	return {}


func _make_stage_reference(chapter: int, stage: int) -> Dictionary:
	return {
		"chapter": chapter,
		"stage": stage,
		"global_stage_number": (chapter - 1) * CHAPTER_STAGE_COUNT + stage,
	}


func _get_current_stage_wave_data_path() -> String:
	var stage_ref := _get_current_stage_reference()
	if stage_ref.is_empty():
		return ""
	if stage_ref.has("wave_data_path"):
		var catalog_wave_data_path := str(stage_ref["wave_data_path"])
		if ResourceLoader.exists(catalog_wave_data_path):
			return catalog_wave_data_path

	var chapter := int(stage_ref["chapter"])
	var stage := int(stage_ref["stage"])
	var global_stage_number := int(stage_ref["global_stage_number"])
	return _get_stage_wave_data_path(chapter, stage, global_stage_number)


func _get_stage_wave_data_path(chapter: int, stage: int, global_stage_number: int) -> String:
	var wave_data_path := WAVE_DATA_TEMPLATE % [chapter, stage]
	if ResourceLoader.exists(wave_data_path):
		return wave_data_path

	var long_wave_data_path := LONG_WAVE_DATA_TEMPLATE % [chapter, stage]
	if ResourceLoader.exists(long_wave_data_path):
		return long_wave_data_path

	var legacy_wave_data_path := LEGACY_WAVE_DATA_TEMPLATE % global_stage_number
	if ResourceLoader.exists(legacy_wave_data_path):
		return legacy_wave_data_path
	return ""


func _get_next_stage_scene_path() -> String:
	var current_stage_number := _get_current_stage_number()
	if current_stage_number <= 0:
		return ""

	var next_stage := STAGE_CATALOG.get_next_playable_stage(current_stage_number)
	if not next_stage.is_empty():
		return str(next_stage["scene_path"])

	return ""


func _get_stage_wave_data_path_by_global_number(global_stage_number: int) -> String:
	if global_stage_number <= 0:
		return ""
	var catalog_entry := STAGE_CATALOG.get_stage_by_global_number(global_stage_number)
	if not catalog_entry.is_empty():
		var catalog_wave_data_path := str(catalog_entry.get("wave_data_path", ""))
		if ResourceLoader.exists(catalog_wave_data_path):
			return catalog_wave_data_path

	var chapter := int((global_stage_number - 1) / CHAPTER_STAGE_COUNT) + 1
	var stage := ((global_stage_number - 1) % CHAPTER_STAGE_COUNT) + 1
	return _get_stage_wave_data_path(chapter, stage, global_stage_number)


func _get_stage_scene_path_by_global_number(global_stage_number: int) -> String:
	if global_stage_number <= 0:
		return ""
	var catalog_entry := STAGE_CATALOG.get_stage_by_global_number(global_stage_number)
	if not catalog_entry.is_empty():
		return str(catalog_entry.get("scene_path", ""))

	var chapter := int((global_stage_number - 1) / CHAPTER_STAGE_COUNT) + 1
	var stage := ((global_stage_number - 1) % CHAPTER_STAGE_COUNT) + 1
	var stage_path := STAGE_SCENE_TEMPLATE % [chapter, stage]
	if ResourceLoader.exists(stage_path):
		return stage_path

	var long_stage_path := LONG_STAGE_SCENE_TEMPLATE % [chapter, stage]
	if ResourceLoader.exists(long_stage_path):
		return long_stage_path

	var legacy_stage_path := LEGACY_STAGE_SCENE_TEMPLATE % global_stage_number
	if ResourceLoader.exists(legacy_stage_path):
		return legacy_stage_path
	return stage_path


func _on_modal_interaction_cancelled() -> void:
	_end_interaction_pause()


func _close_visible_confirm_dialog() -> bool:
	if stage_clear_dialog.visible:
		stage_clear_dialog.hide()
		_on_stage_clear_return_requested()
		return true

	if exit_confirm_dialog.visible:
		exit_confirm_dialog.hide()
		_on_modal_interaction_cancelled()
		return true

	if restart_confirm_dialog.visible:
		restart_confirm_dialog.hide()
		_on_modal_interaction_cancelled()
		return true

	return false


func _clear_stale_interaction_pause() -> void:
	if not interaction_pause_active:
		return
	if dragging_card != null:
		return
	if selected_tool != TOOL_NONE:
		return
	if selected_unit != null:
		return
	if exit_confirm_dialog.visible or restart_confirm_dialog.visible or stage_clear_dialog.visible:
		return
	_end_interaction_pause()


func _is_back_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	return event.is_action_pressed("ui_back")


func _can_deploy_at_cell(cell: Vector2i, deploy_source: Node = null) -> bool:
	_refresh_unit_cells()
	return _is_cell_deployable_for_source(cell, deploy_source)


func _get_deploy_failure_reason(cell: Vector2i, deploy_source: Node, deploy_cost: int) -> String:
	if current_deployment_cost < deploy_cost:
		return "费用不足：需要 %d" % deploy_cost
	if not _can_deploy_at_cell(cell, deploy_source):
		return _get_cell_deploy_failure_reason(cell, deploy_source)
	if not _can_deploy_source_with_limit(deploy_source, cell):
		return "该单位已达到部署上限"
	if not _can_deploy_with_total_limit(cell):
		return "场上部署数量已满"
	return "无法部署到这里"


func _get_cell_deploy_failure_reason(cell: Vector2i, deploy_source: Node) -> String:
	if grid_layer == null:
		return "地图未准备好"

	var tile_data := grid_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return "超出可部署区域"
	if tile_data.get_custom_data("deployable") != true:
		return "这里不能部署"
	if _cell_has_enemy_spawn_or_target_marker(cell):
		return "出入口不能部署"

	var required_type := _get_deploy_source_placement_type(deploy_source)
	var cell_type := int(tile_data.get_custom_data("placement_type"))
	if required_type != cell_type:
		return "部署位置不匹配：该单位需要%s" % _get_placement_type_display_name(required_type)
	return "无法部署到这里"


func _get_placement_type_display_name(placement_type: int) -> String:
	return "高台" if placement_type == 1 else "地面"


func _can_deploy_source_with_limit(deploy_source: Node, deploy_cell := Vector2i(2147483647, 2147483647)) -> bool:
	var deploy_limit := _get_deploy_source_limit(deploy_source)
	if deploy_limit <= 0:
		return true

	var unit_id := _get_deploy_source_unit_id(deploy_source)
	if unit_id.is_empty():
		return true

	var deployed_count := _get_deployed_unit_count_by_id(unit_id)
	if units_by_cell.has(deploy_cell):
		var replaced_unit: Node = units_by_cell[deploy_cell]
		if _get_base_character_id(_get_unit_id(replaced_unit)) == _get_base_character_id(unit_id):
			deployed_count = maxi(deployed_count - 1, 0)

	return deployed_count < deploy_limit


func _can_deploy_with_total_limit(deploy_cell := Vector2i(2147483647, 2147483647)) -> bool:
	if max_total_deployed_units <= 0:
		return true

	_refresh_unit_cells()
	var projected_count := units_by_cell.size()
	if not units_by_cell.has(deploy_cell):
		projected_count += 1
	return projected_count <= max_total_deployed_units


func _is_cell_deployable_for_source(cell: Vector2i, deploy_source: Node = null) -> bool:
	if grid_layer == null:
		return false

	var tile_data := grid_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false

	if tile_data.get_custom_data("deployable") != true:
		return false

	if _cell_has_enemy_spawn_or_target_marker(cell):
		return false

	return _get_deploy_source_placement_type(deploy_source) == int(tile_data.get_custom_data("placement_type"))


func _cell_has_enemy_spawn_or_target_marker(cell: Vector2i) -> bool:
	if grid_layer == null:
		return false

	var cell_center := _cell_to_global_center(cell)
	for layer in _get_tile_map_layers(self):
		var marker_cell := layer.local_to_map(layer.to_local(cell_center))
		if _is_enemy_spawn_cell(layer, marker_cell) or _is_enemy_target_cell(layer, marker_cell):
			return true

	return false


func _show_deployable_tile_overlay(deploy_source: Node) -> void:
	_clear_deployable_tile_overlay()

	if grid_layer == null or grid_layer.tile_set == null or deploy_source == null:
		return

	var tile_size := Vector2(grid_layer.tile_set.tile_size)
	var half_size := tile_size * 0.5
	deployable_tile_overlay = Node2D.new()
	deployable_tile_overlay.name = "DeployableTileOverlay"
	deployable_tile_overlay.z_as_relative = false
	deployable_tile_overlay.z_index = DEPLOYABLE_TILE_OVERLAY_Z
	add_child(deployable_tile_overlay)

	for cell in grid_layer.get_used_cells():
		if not _is_cell_deployable_for_source(cell, deploy_source):
			continue
		if not _can_deploy_source_with_limit(deploy_source, cell):
			continue
		if not _can_deploy_with_total_limit(cell):
			continue

		var tile := Polygon2D.new()
		tile.color = deployable_tile_overlay_color
		tile.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
		deployable_tile_overlay.add_child(tile)
		tile.global_position = _cell_to_global_center(cell)


func _clear_deployable_tile_overlay() -> void:
	if deployable_tile_overlay == null:
		return

	deployable_tile_overlay.queue_free()
	deployable_tile_overlay = null


func _apply_global_ground_tile_rules() -> void:
	if grid_layer == null or grid_layer.tile_set == null:
		return

	var rules := _load_global_ground_tile_rules()
	if rules.is_empty():
		return

	_ensure_global_ground_tile_custom_layers(grid_layer.tile_set)
	_apply_ground_tile_rules_to_layer(grid_layer, rules)


func _load_global_ground_tile_rules() -> Dictionary:
	var scene := load(GLOBAL_GROUND_TILE_RULE_STAGE) as PackedScene
	if scene == null:
		return {}

	var stage := scene.instantiate()
	var source_layer := stage.get_node_or_null(GLOBAL_GROUND_TILE_RULE_LAYER) as TileMapLayer
	var rules := _collect_ground_tile_rules(source_layer)
	stage.queue_free()
	return rules


func _collect_ground_tile_rules(layer: TileMapLayer) -> Dictionary:
	var rules := {}
	if layer == null or layer.tile_set == null:
		return rules

	var tile_set := layer.tile_set
	for source_index in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(source_index)
		var source := tile_set.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue

		var atlas_source := source as TileSetAtlasSource
		if atlas_source.texture == null:
			continue

		var texture_path := atlas_source.texture.resource_path
		if texture_path.is_empty():
			continue

		var source_rules := {}
		for tile_index in atlas_source.get_tiles_count():
			var atlas_coords := atlas_source.get_tile_id(tile_index)
			var tile_data := atlas_source.get_tile_data(atlas_coords, 0)
			if tile_data == null:
				continue

			var tile_rules := {}
			for layer_name in GLOBAL_GROUND_TILE_DATA_LAYER_TYPES.keys():
				if _tile_set_has_custom_data_layer(tile_set, StringName(layer_name)):
					tile_rules[layer_name] = tile_data.get_custom_data(layer_name)
			source_rules[atlas_coords] = tile_rules

		if not source_rules.is_empty():
			rules[texture_path] = source_rules

	return rules


func _apply_ground_tile_rules_to_layer(layer: TileMapLayer, rules: Dictionary) -> void:
	if layer == null or layer.tile_set == null:
		return

	var tile_set := layer.tile_set
	for source_index in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(source_index)
		var source := tile_set.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue

		var atlas_source := source as TileSetAtlasSource
		if atlas_source.texture == null:
			continue

		var texture_path := atlas_source.texture.resource_path
		if not rules.has(texture_path):
			continue

		var source_rules: Dictionary = rules[texture_path]
		for atlas_coords in source_rules.keys():
			if not atlas_source.has_tile(atlas_coords):
				continue
			var tile_data := atlas_source.get_tile_data(atlas_coords, 0)
			if tile_data == null:
				continue
			for layer_name in source_rules[atlas_coords].keys():
				tile_data.set_custom_data(layer_name, source_rules[atlas_coords][layer_name])


func _ensure_global_ground_tile_custom_layers(tile_set: TileSet) -> void:
	for layer_name in GLOBAL_GROUND_TILE_DATA_LAYER_TYPES.keys():
		var name := StringName(layer_name)
		if _tile_set_has_custom_data_layer(tile_set, name):
			continue

		var layer_index := tile_set.get_custom_data_layers_count()
		tile_set.add_custom_data_layer(layer_index)
		tile_set.set_custom_data_layer_name(layer_index, name)
		tile_set.set_custom_data_layer_type(layer_index, GLOBAL_GROUND_TILE_DATA_LAYER_TYPES[layer_name])


func _get_deploy_source_placement_type(deploy_source: Node) -> int:
	if deploy_source == null:
		return 0
	if deploy_source.has_method("get_effective_placement_type"):
		return int(deploy_source.get_effective_placement_type())
	if "placement_type" in deploy_source:
		return int(deploy_source.placement_type)
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var placement_type := 0
		if unit.has_method("get_effective_placement_type"):
			placement_type = int(unit.get_effective_placement_type())
		elif "placement_type" in unit:
			placement_type = int(unit.placement_type)
		unit.queue_free()
		return placement_type
	return 0


func _get_deploy_source_cost(deploy_source: Node) -> int:
	if deploy_source == null:
		return 0
	if "deploy_cost" in deploy_source:
		return int(deploy_source.deploy_cost)
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var deploy_cost := 0
		if "deploy_cost" in unit:
			deploy_cost = int(unit.deploy_cost)
		unit.queue_free()
		return deploy_cost
	return 0


func _get_deploy_source_cooldown(deploy_source: Node) -> float:
	if deploy_source == null:
		return 0.0
	if deploy_source.has_method("get_deployment_cooldown"):
		return float(deploy_source.get_deployment_cooldown())
	if "deployment_cooldown" in deploy_source:
		return float(deploy_source.deployment_cooldown)
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var cooldown := 0.0
		if "deployment_cooldown" in unit:
			cooldown = float(unit.deployment_cooldown)
		unit.queue_free()
		return cooldown
	return 0.0


func _get_deploy_source_limit(deploy_source: Node) -> int:
	if deploy_source == null:
		return 0
	if deploy_source.has_method("get_deployment_limit"):
		return int(deploy_source.get_deployment_limit())
	if "deployment_limit" in deploy_source:
		return int(deploy_source.deployment_limit)
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var deployment_limit := 0
		if "deployment_limit" in unit:
			deployment_limit = int(unit.deployment_limit)
		unit.queue_free()
		return deployment_limit
	return 0


func _get_deploy_source_unit_id(deploy_source: Node) -> String:
	if deploy_source == null:
		return ""
	if "unit_id" in deploy_source:
		return str(deploy_source.unit_id).to_lower()
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var unit_id := _get_unit_id(unit)
		unit.queue_free()
		return unit_id
	return ""


func _get_unit_id(unit: Node) -> String:
	if unit != null and "unit_id" in unit:
		return str(unit.unit_id).to_lower()
	return ""


func _get_deployed_unit_count_by_id(unit_id: String) -> int:
	var normalized_id := _get_base_character_id(unit_id.to_lower())
	if normalized_id.is_empty() or units == null:
		return 0

	var count := 0
	for unit in units.get_children():
		if _is_invalid_combat_unit(unit):
			continue
		if _get_base_character_id(_get_unit_id(unit)) == normalized_id:
			count += 1
	return count


func _get_deploy_source_attack_distance(deploy_source: Node) -> float:
	if deploy_source == null:
		return 0.0
	if "attack_distance_tiles" in deploy_source:
		return float(deploy_source.attack_distance_tiles)
	if "unit_scene" in deploy_source and deploy_source.unit_scene is PackedScene:
		var unit: Node = deploy_source.unit_scene.instantiate()
		var attack_distance := 0.0
		if "attack_distance_tiles" in unit:
			attack_distance = float(unit.attack_distance_tiles)
		unit.queue_free()
		return attack_distance
	return 0.0


func _create_attack_range_preview_node(range_name: String, parent: Node, deploy_source: Node) -> Node2D:
	var preview := Node2D.new()
	preview.name = range_name
	preview.set_script(ATTACK_RANGE_PREVIEW_SCRIPT)
	parent.add_child(preview)
	preview.radius = _get_attack_range_preview_radius(deploy_source)
	preview.fill_color = attack_range_preview_fill_color
	preview.outline_color = attack_range_preview_outline_color
	preview.outline_width = attack_range_preview_outline_width
	return preview


func _create_attack_range_preview(deploy_source: Node) -> void:
	if not show_attack_range_preview:
		return

	_clear_deploy_attack_range_preview()
	deploy_attack_range_preview = _create_attack_range_preview_node("AttackRangePreview", deploy_preview, deploy_source)
	deploy_preview.move_child(deploy_attack_range_preview, 0)


func _update_attack_range_preview(preview_position: Vector2) -> void:
	if deploy_attack_range_preview == null:
		return

	deploy_attack_range_preview.global_position = preview_position
	deploy_attack_range_preview.visible = show_attack_range_preview and not _is_mouse_over_hand_bar()


func _clear_deploy_attack_range_preview() -> void:
	if deploy_attack_range_preview == null:
		return

	deploy_attack_range_preview.queue_free()
	deploy_attack_range_preview = null


func _handle_unit_selection_at_mouse() -> void:
	var unit := _get_unit_at_mouse()
	if unit == null:
		if dragging_card != null:
			dragging_card.set_available(true)
			dragging_card = null
			_clear_deploy_preview()
		if selected_tool == TOOL_SHOVEL:
			_cancel_shovel_tool(false)
		_clear_selected_unit_attack_range()
		_hide_unit_info_panel()
		_end_interaction_pause()
		return

	_begin_interaction_pause()
	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
		_clear_deploy_preview()
	_cancel_shovel_tool(false)
	_show_selected_unit_attack_range(unit)
	_show_unit_info_panel(unit, null, true)


func _show_selected_unit_attack_range(unit: Node2D) -> void:
	_clear_selected_unit_attack_range()
	if not show_attack_range_preview:
		return

	selected_unit = unit
	selected_unit_attack_range = _create_attack_range_preview_node("SelectedUnitAttackRange", deploy_preview, unit)
	deploy_preview.move_child(selected_unit_attack_range, 0)
	selected_unit_attack_range.global_position = unit.global_position
	selected_unit_attack_range.visible = true


func _clear_selected_unit_attack_range() -> void:
	selected_unit = null
	if selected_unit_attack_range == null:
		return

	selected_unit_attack_range.queue_free()
	selected_unit_attack_range = null


func _try_move_selected_unit(destination_cell: Vector2i) -> bool:
	if moving_unit == null or not is_instance_valid(moving_unit):
		return false
	_refresh_unit_cells()
	var origin_cell: Vector2i = moving_origin_cell
	if destination_cell == origin_cell:
		return false
	if not _is_cell_deployable_for_source(destination_cell, moving_unit):
		_show_stage_feedback(_get_cell_deploy_failure_reason(destination_cell, moving_unit), Color(1.0, 0.38, 0.25, 1.0))
		return false
	if units_by_cell.has(destination_cell) and units_by_cell[destination_cell] != moving_unit:
		_show_stage_feedback("目标格已有角色", Color(1.0, 0.38, 0.25, 1.0))
		return false
	var move_cost := float(_get_deploy_source_cost(moving_unit)) * 0.5
	if current_deployment_cost < move_cost:
		_show_stage_feedback("费用不足", Color(1.0, 0.38, 0.25, 1.0))
		return false

	moving_unit.global_position = _cell_to_global_center(destination_cell)
	moving_unit.set_meta("grid_cell", destination_cell)
	current_deployment_cost = maxf(current_deployment_cost - move_cost, 0.0)
	_update_cost_label()
	_refresh_unit_cells()
	return true


func _cancel_current_operation() -> void:
	if moving_unit != null and is_instance_valid(moving_unit):
		moving_unit.global_position = moving_origin_position
		moving_unit.set_meta("grid_cell", moving_origin_cell)
	if dragging_card != null:
		dragging_card.set_available(true)
		dragging_card = null
	_clear_deploy_preview()
	_cancel_shovel_tool(false)
	_clear_selected_unit_attack_range()
	_hide_unit_info_panel()
	_end_interaction_pause()


func _instantiate_card_unit(card: Node) -> Node:
	if card == null:
		return null
	if card.has_method("get_active_unit_scene"):
		var active_scene: PackedScene = card.get_active_unit_scene()
		return active_scene.instantiate() if active_scene != null else null
	if not ("unit_scene" in card):
		return null
	if not card.unit_scene is PackedScene:
		return null
	return card.unit_scene.instantiate()


func _show_unit_info_panel(unit: Node, source_card: Node, is_deployed: bool) -> void:
	if info_panel == null or info_title == null or info_body == null:
		return

	info_panel.visible = true
	info_title.text = _get_unit_display_name(unit, source_card)
	info_body.text = _build_unit_info_text(unit, source_card, is_deployed)


func _hide_unit_info_panel() -> void:
	if info_panel == null:
		return

	info_panel.visible = false


func _build_unit_info_text(unit: Node, source_card: Node, is_deployed: bool) -> String:
	var lines: Array[String] = []
	var status_text := "已部署" if is_deployed else "手牌"
	var power_label := "治疗量" if _is_priest_unit(unit) else "攻击力"
	lines.append("状态: %s" % status_text)
	lines.append("职业: %s" % _get_profession_name(_get_int_property(unit, "profession", 0)))
	lines.append("职业特性: %s" % _get_profession_trait_description(unit))
	lines.append("%s: %d" % [power_label, _get_int_property(unit, "attack_power", 0)])
	lines.append("攻击速度: %s 次/秒" % _format_float(_get_float_property(unit, "attack_speed", 0.0)))
	if is_deployed:
		lines.append("生命值: %s/%d" % [_format_float(_get_float_property(unit, "health", 0.0)), _get_int_property(unit, "max_health", 0)])
	else:
		lines.append("生命值: %d" % _get_int_property(unit, "max_health", 0))
	lines.append("部署费用: %d" % _get_int_property(unit, "deploy_cost", _get_deploy_source_cost(source_card)))
	lines.append("部署冷却: %s 秒" % _format_float(_get_float_property(unit, "deployment_cooldown", _get_deploy_source_cooldown(source_card))))
	lines.append("单体部署上限: %d" % _get_int_property(unit, "deployment_limit", _get_deploy_source_limit(source_card)))
	lines.append("攻击距离: %s 格" % _format_float(_get_float_property(unit, "attack_distance_tiles", 0.0)))
	lines.append("目标数: %d" % _get_int_property(unit, "attack_target_count", 1))
	lines.append("嘲讽等级: %s" % _format_float(_get_effective_taunt_level(unit, null)))
	lines.append("部署位置: %s" % _get_placement_type_name(_get_unit_effective_placement_type(unit)))
	lines.append("阻挡: %s" % _get_block_ability_text(unit))
	lines.append("被动技能: %s" % _get_string_property(unit, "skill_description", ""))
	lines.append("主动技能: %s" % _get_string_property(unit, "active_skill_description", ""))
	lines.append("主动效果: %s" % _get_string_property(unit, "active_skill_effect", ""))
	lines.append("技能点获取: %s" % _get_string_property(unit, "upgrade_method", "待填写"))
	return "\n".join(lines)

func _get_unit_display_name(unit: Node, source_card: Node) -> String:
	var source := unit
	if source == null and source_card != null and source_card.has_method("get_active_unit_scene"):
		var scene: PackedScene = source_card.get_active_unit_scene()
		if scene != null:
			source = scene.instantiate()
	if source == null:
		return ""
	var id_text := _get_unit_id(source)
	var base_id := _get_base_character_id(id_text)
	var suffix := id_text.substr(base_id.length())
	var level := suffix.to_int() + 1 if suffix.is_valid_int() else 1
	var result := "%s Lv.%d" % [_get_profession_name(_get_int_property(source, "profession", 0)), level]
	if source != unit:
		source.queue_free()
	return result


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


func _get_unit_effective_placement_type(unit: Node) -> int:
	if unit != null and unit.has_method("get_effective_placement_type"):
		return int(unit.get_effective_placement_type())
	return _get_int_property(unit, "placement_type", 0)


func _get_block_ability_text(unit: Node) -> String:
	if _get_int_property(unit, "can_block", 1) != 1:
		return "无法阻挡"
	if _get_int_property(unit, "block_ability", 1) == BLOCK_NONE:
		return "无法阻挡"
	return "可以阻挡"


func _get_profession_trait_description(unit: Node) -> String:
	if unit != null and unit.has_method("get_profession_trait_description"):
		return str(unit.get_profession_trait_description())
	return _get_string_property(unit, "profession_trait_description", "")


func _get_int_property(source, property_name: StringName, fallback: int) -> int:
	if is_instance_valid(source) and property_name in source:
		return int(source.get(property_name))
	return fallback


func _get_float_property(source, property_name: StringName, fallback: float) -> float:
	if is_instance_valid(source) and property_name in source:
		return float(source.get(property_name))
	return fallback


func _get_string_property(source, property_name: StringName, fallback: String) -> String:
	if is_instance_valid(source) and property_name in source:
		return str(source.get(property_name))
	return fallback


func _get_bool_property(source, property_name: StringName, fallback: bool) -> bool:
	if is_instance_valid(source) and property_name in source:
		return bool(source.get(property_name))
	return fallback


func _format_float(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _get_attack_range_preview_radius(deploy_source: Node) -> float:
	var tile_size := Vector2(grid_layer.tile_set.tile_size)
	var tile_length := maxf(tile_size.x, tile_size.y)
	return (maxf(_get_deploy_source_attack_distance(deploy_source), 0.0) + 0.6) * tile_length


func _is_mouse_over_hand_bar() -> bool:
	if hand_bar == null:
		return false

	return hand_bar.get_global_rect().has_point(get_viewport().get_mouse_position())


func _get_mouse_cell() -> Vector2i:
	return grid_layer.local_to_map(grid_layer.to_local(get_global_mouse_position()))


func _get_mouse_cell_center() -> Vector2:
	return _cell_to_global_center(_get_mouse_cell())


func _cell_to_global_center(cell: Vector2i) -> Vector2:
	return grid_layer.to_global(grid_layer.map_to_local(cell))


func _get_unit_at_mouse() -> Node:
	var mouse_position := get_global_mouse_position()
	var mouse_cell := _get_mouse_cell()
	if units_by_cell.has(mouse_cell):
		return units_by_cell[mouse_cell]

	var half_tile_size := Vector2(grid_layer.tile_set.tile_size) * 0.5
	for unit in units.get_children():
		if not unit is Node2D:
			continue
		if "is_defeated" in unit and unit.is_defeated:
			continue

		var visual_center: Vector2 = unit.global_position + UNIT_VISUAL_OFFSET
		var local_mouse := mouse_position - visual_center
		if absf(local_mouse.x) <= half_tile_size.x and absf(local_mouse.y) <= half_tile_size.y:
			return unit

	return null


func _refresh_unit_cells() -> void:
	units_by_cell.clear()
	for unit in units.get_children():
		if not unit is Node2D:
			continue
		if "is_defeated" in unit and unit.is_defeated:
			continue

		_configure_unit_for_grid(unit)
		if not unit.has_meta("deploy_order"):
			unit.set_meta("deploy_order", deployed_unit_count)
			deployed_unit_count += 1
		var cell := grid_layer.local_to_map(grid_layer.to_local(unit.global_position))
		unit.set_meta("grid_cell", cell)
		units_by_cell[cell] = unit


func _update_enemy_blockers() -> void:
	if enemies == null:
		return

	for enemy in enemies.get_children():
		if not enemy is Node2D:
			continue
		if "is_defeated" in enemy and enemy.is_defeated:
			_clear_enemy_blocker(enemy)
			continue
		if "is_teleporting" in enemy and enemy.is_teleporting:
			_clear_enemy_blocker(enemy)
			continue
		if "can_be_blocked" in enemy and int(enemy.can_be_blocked) != 1:
			_clear_enemy_blocker(enemy)
			continue
		if _get_enemy_blocker(enemy) != null:
			continue
		enemy.remove_meta("block_order")

		var cell := grid_layer.local_to_map(grid_layer.to_local(enemy.global_position))
		var blocker := _get_blocking_unit_at_cell(cell)
		if blocker != null:
			_set_enemy_blocker(enemy, blocker)
		else:
			_clear_enemy_blocker(enemy)


func _process_unit_actions(delta: float) -> void:
	var tile_size := Vector2(grid_layer.tile_set.tile_size)
	for unit in units.get_children():
		if not unit is Node2D:
			continue
		if _is_invalid_combat_unit(unit):
			continue
		_apply_field_time_skill_charge(unit, delta)
		if _is_stunned(unit):
			if unit.has_method("set_armed"):
				unit.set_armed(false)
			continue

		var cooldown := maxf(float(unit.get_meta("action_cooldown", 0.0)) - delta, 0.0)
		unit.set_meta("action_cooldown", cooldown)
		if cooldown > 0.0:
			continue

		if _try_perform_unit_action(unit, tile_size):
			unit.set_meta("action_cooldown", _get_unit_action_interval(unit))


func _update_unit_armed_states() -> void:
	if units == null or grid_layer == null or grid_layer.tile_set == null:
		return

	var tile_size := Vector2(grid_layer.tile_set.tile_size)
	for unit in units.get_children():
		if not unit is Node2D:
			continue
		if not unit.has_method("set_armed"):
			continue

		if _is_invalid_combat_unit(unit):
			unit.set_armed(false)
			continue
		if _is_stunned(unit):
			unit.set_armed(false)
			continue

		var priority_target: Node2D
		if _is_priest_unit(unit):
			var heal_targets := _find_heal_targets_for_unit(unit, tile_size, 1)
			if not heal_targets.is_empty() and heal_targets[0] is Node2D:
				priority_target = heal_targets[0]
		else:
			var attack_targets := _find_attack_targets_for_unit(unit, tile_size, 1)
			if not attack_targets.is_empty() and attack_targets[0] is Node2D:
				priority_target = attack_targets[0]

		unit.set_armed(priority_target != null)
		if priority_target != null and unit.has_method("face_target_position"):
			unit.face_target_position(priority_target.global_position)


func _try_perform_unit_action(unit: Node2D, tile_size: Vector2) -> bool:
	if _is_priest_unit(unit):
		var allies := _find_heal_targets_for_unit(unit, tile_size, _get_attack_target_count(unit))
		if allies.is_empty():
			return false
		for ally in allies:
			_fire_projectile(unit, ally, _get_unit_attack_power(unit), true)
		return true

	var targets := _find_attack_targets_for_unit(unit, tile_size, _get_attack_target_count(unit))
	if targets.is_empty():
		return false
	for enemy in targets:
		_fire_projectile(unit, enemy, _get_unit_attack_amount(unit), false, false, bool(unit.get_meta("last_attack_was_critical", false)))
	return true


func _fire_projectile(source: Node2D, target: Node, amount: int, is_heal_projectile: bool, is_enemy_projectile := false, show_damage_number := false) -> void:
	if source == null or target == null or not target is Node2D:
		return
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	if is_stage_exiting or projectiles == null or not is_instance_valid(projectiles):
		return

	var projectile := Sprite2D.new()
	projectile.texture = _get_projectile_texture()
	projectile.centered = true
	projectile.scale = projectile_scale
	projectile.z_as_relative = true
	projectile.z_index = 0
	projectile.global_position = source.global_position
	if is_heal_projectile:
		projectile.modulate = priest_projectile_color
	elif is_enemy_projectile:
		projectile.modulate = enemy_projectile_color

	projectiles.add_child(projectile)
	_fly_projectile_to_target(projectile, source, target as Node2D, amount, is_heal_projectile, is_enemy_projectile, show_damage_number)


func _get_projectile_texture() -> Texture2D:
	if projectile_texture == null:
		return null

	if projectile_texture_region.size.x <= 0.0 or projectile_texture_region.size.y <= 0.0:
		return projectile_texture

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = projectile_texture
	atlas_texture.region = projectile_texture_region
	return atlas_texture


func _fly_projectile_to_target(projectile: Sprite2D, source: Node2D, target: Node2D, amount: int, is_heal_projectile: bool, is_enemy_projectile := false, show_damage_number := false) -> void:
	if _should_stop_projectile_task(projectile):
		return

	var tile_length := maxf(float(grid_layer.tile_set.tile_size.x), float(grid_layer.tile_set.tile_size.y))
	var speed := maxf(projectile_speed_tiles_per_second, 0.1) * tile_length

	while is_instance_valid(projectile) and is_instance_valid(target):
		var tree := get_tree()
		if _should_stop_projectile_task(projectile) or tree == null:
			_free_projectile_if_valid(projectile)
			return

		while tree.paused:
			await tree.process_frame
			tree = get_tree()
			if _should_stop_projectile_task(projectile) or tree == null:
				_free_projectile_if_valid(projectile)
				return

		if _is_invalid_combat_unit(target):
			_free_projectile_if_valid(projectile)
			return

		var delta := get_process_delta_time()
		var offset := target.global_position - projectile.global_position
		var distance := offset.length()
		if distance <= maxf(speed * delta, 1.0):
			projectile.global_position = target.global_position
			break

		projectile.global_position += offset / distance * speed * delta
		await tree.process_frame
		if _should_stop_projectile_task(projectile):
			_free_projectile_if_valid(projectile)
			return

	if _should_stop_projectile_task(projectile):
		_free_projectile_if_valid(projectile)
		return

	if is_instance_valid(target) and not _is_invalid_combat_unit(target):
		# The attacker can be freed while its projectile is still in flight.
		# Keep resolving the projectile against its target without passing a stale object.
		var hit_source = source if is_instance_valid(source) else null
		var should_hold_splash_projectile := _should_hold_splash_projectile_on_hit(hit_source, is_heal_projectile, is_enemy_projectile)
		if is_heal_projectile and target.has_method("heal"):
			var healed_amount := float(target.heal(amount))
			_award_skill_charge_for_healing(hit_source, healed_amount)
			if is_instance_valid(hit_source) and hit_source.get_parent() == units and hit_source.has_method("heal_fractional"):
				hit_source.heal_fractional(_get_float_property(hit_source, "attack_heal_amount", 0.0))
		elif is_enemy_projectile:
			_apply_enemy_attack_hit(hit_source, target, amount)
		elif not is_heal_projectile:
			_apply_unit_attack_hit(hit_source, target, amount, show_damage_number)
		if should_hold_splash_projectile:
			await _hold_splash_projectile_hit(projectile)

	_free_projectile_if_valid(projectile)


func _should_stop_projectile_task(projectile) -> bool:
	return is_stage_exiting or not is_inside_tree() or not is_instance_valid(projectile) or projectile.is_queued_for_deletion()


func _free_projectile_if_valid(projectile) -> void:
	if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
		projectile.queue_free()


func _should_hold_splash_projectile_on_hit(source, is_heal_projectile: bool, is_enemy_projectile: bool) -> bool:
	if is_heal_projectile or source == null:
		return false
	if _get_float_property(source, "splash_damage_radius_tiles", 0.0) > 0.0:
		return true
	return not is_enemy_projectile and _get_bool_property(source, "attack_hits_cell_enemies", false)


func _hold_splash_projectile_hit(projectile: Sprite2D) -> void:
	if _should_stop_projectile_task(projectile):
		return

	projectile.scale *= SPLASH_PROJECTILE_HIT_SCALE_MULTIPLIER
	for _frame in SPLASH_PROJECTILE_HIT_HOLD_FRAMES:
		var tree := get_tree()
		if _should_stop_projectile_task(projectile) or tree == null:
			return
		while tree.paused:
			await tree.process_frame
			tree = get_tree()
			if _should_stop_projectile_task(projectile) or tree == null:
				return
		await tree.process_frame


func _apply_unit_attack_hit(source, target: Node2D, amount: int, show_damage_number := false) -> void:
	var hit_targets: Array[Node] = []
	if target != null and is_instance_valid(target):
		hit_targets.append(target)

	if is_instance_valid(source) and source.get_parent() == units and _get_bool_property(source, "attack_hits_cell_enemies", false):
		for enemy in _get_enemies_in_same_cell(target):
			if not hit_targets.has(enemy):
				hit_targets.append(enemy)

	_append_splash_targets(hit_targets, source, target.global_position, false)
	for hit_target in hit_targets:
		if not _is_invalid_combat_unit(hit_target):
			var actual_damage := _apply_damage_and_attack_effects(source, hit_target, amount)
			if show_damage_number:
				_show_damage_number(hit_target, actual_damage)
			_award_skill_charge_for_attack_hit(source, hit_target, actual_damage)
			if is_instance_valid(source) and source.get_parent() == units and source.has_method("heal_fractional"):
				source.heal_fractional(_get_float_property(source, "attack_heal_amount", 0.0))


func apply_skill_damage(source: Node, target: Node2D, amount: int) -> void:
	if source == null or target == null or _is_invalid_combat_unit(target) or not _is_character_skill_enabled(source):
		return
	var actual_damage := _apply_damage_and_attack_effects(source, target, amount)
	_show_damage_number(target, actual_damage)


func _show_damage_number(target: Node, amount: float) -> void:
	if target == null or not is_instance_valid(target) or amount <= 0.0:
		return
	var number := Label.new()
	number.set_script(DAMAGE_NUMBER_SCRIPT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08, 1.0))
	number.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.0, 0.9))
	number.add_theme_constant_override("outline_size", 2)
	number.add_theme_font_size_override("font_size", 14)
	number.size = Vector2(36.0, 20.0)
	number.pivot_offset = number.size * 0.5
	var tile_length := maxf(float(grid_layer.tile_set.tile_size.x), float(grid_layer.tile_set.tile_size.y))
	var angle := randf_range(0.0, TAU)
	var radius := sqrt(randf()) * tile_length * 0.5
	var center: Vector2 = target.global_position
	var body := target.get_node_or_null("BodySprite") as Node2D
	if body != null:
		center += body.position
	add_child(number)
	number.global_position = center + Vector2(cos(angle), sin(angle)) * radius - number.size * 0.5
	number.show_damage(amount)


func _apply_enemy_attack_hit(source, target: Node2D, amount: int) -> void:
	var hit_targets: Array[Node] = []
	if target != null and is_instance_valid(target):
		hit_targets.append(target)
	_append_splash_targets(hit_targets, source, target.global_position, true)
	for hit_target in hit_targets:
		if not _is_invalid_combat_unit(hit_target):
			var actual_damage := _apply_damage_and_attack_effects(source, hit_target, amount)
			_award_skill_charge_for_damage_taken(hit_target, actual_damage)


func _append_splash_targets(targets: Array[Node], source: Node, impact_position: Vector2, is_enemy_projectile: bool) -> void:
	var radius_tiles := _get_float_property(source, "splash_damage_radius_tiles", 0.0)
	if radius_tiles <= 0.0:
		return

	var tile_length := maxf(float(grid_layer.tile_set.tile_size.x), float(grid_layer.tile_set.tile_size.y))
	var radius := radius_tiles * tile_length
	var radius_squared := radius * radius
	var candidate_container: Node = units if is_enemy_projectile else enemies
	if candidate_container == null or not is_instance_valid(candidate_container):
		return

	for candidate in candidate_container.get_children():
		if not candidate is Node2D or _is_invalid_combat_unit(candidate):
			continue
		if candidate.global_position.distance_squared_to(impact_position) > radius_squared:
			continue
		if not targets.has(candidate):
			targets.append(candidate)


func _apply_damage_and_attack_effects(source, target: Node, amount: int) -> float:
	var actual_damage := float(amount)
	if target.has_method("flash_hit"):
		target.flash_hit()
	if target.has_method("take_damage"):
		var result = target.take_damage(amount)
		if result != null:
			actual_damage = float(result)

	if not is_instance_valid(source):
		return actual_damage

	var slow_percent := _get_float_property(source, "attack_slow_percent", 0.0)
	var slow_duration := _get_float_property(source, "attack_slow_duration", 0.0)
	if slow_percent > 0.0 and slow_duration > 0.0 and target.has_method("add_slow_modifier"):
		var source_id := StringName("attack_slow_%s_%d" % [str(source.get_instance_id()), target.get_instance_id()])
		var modifier_version := int(target.add_slow_modifier(source_id, slow_percent))
		_remove_speed_modifier_after(target, source_id, slow_duration, modifier_version)

	var stun_duration := _get_float_property(source, "attack_stun_duration", 0.0)
	if stun_duration > 0.0 and target.has_method("add_stun"):
		target.add_stun(stun_duration)
	return actual_damage


func _remove_speed_modifier_after(target: Node, source_id: StringName, duration: float, modifier_version: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(duration, false).timeout
	if is_stage_exiting or not is_inside_tree():
		return
	if is_instance_valid(target) and target.has_method("remove_speed_modifier"):
		target.remove_speed_modifier(source_id, modifier_version)


func _get_enemies_in_same_cell(target: Node2D) -> Array[Node]:
	var result: Array[Node] = []
	if enemies == null:
		return result

	var target_cell := grid_layer.local_to_map(grid_layer.to_local(target.global_position))
	for enemy in enemies.get_children():
		if not enemy is Node2D:
			continue
		if _is_invalid_combat_unit(enemy):
			continue
		var enemy_cell := grid_layer.local_to_map(grid_layer.to_local(enemy.global_position))
		if enemy_cell == target_cell:
			result.append(enemy)
	return result


func _find_attack_target_for_unit(unit: Node2D, tile_size: Vector2) -> Node:
	var targets := _find_attack_targets_for_unit(unit, tile_size, 1)
	if targets.is_empty():
		return null
	return targets[0]


func _find_attack_targets_for_unit(unit: Node2D, tile_size: Vector2, target_count: int) -> Array[Node]:
	if enemies == null:
		var empty_targets: Array[Node] = []
		return empty_targets

	var targets: Array[Node] = []
	for enemy in enemies.get_children():
		if not enemy is Node2D:
			continue
		if _is_invalid_combat_unit(enemy):
			continue
		if not _is_in_unit_attack_range(unit, enemy, tile_size):
			continue

		_insert_unit_attack_target_sorted(targets, enemy, unit)
	return _limit_node_array(targets, target_count)


func _find_heal_target_for_unit(unit: Node2D, tile_size: Vector2) -> Node:
	var targets := _find_heal_targets_for_unit(unit, tile_size, 1)
	if targets.is_empty():
		return null
	return targets[0]


func _find_heal_targets_for_unit(unit: Node2D, tile_size: Vector2, target_count: int) -> Array[Node]:
	var targets: Array[Node] = []
	for ally in units.get_children():
		if not ally is Node2D:
			continue
		if _is_invalid_combat_unit(ally):
			continue
		if not ally.has_method("needs_healing") or not ally.needs_healing():
			continue
		if not _is_in_unit_attack_range(unit, ally, tile_size):
			continue

		_insert_heal_target_sorted(targets, ally)
	return _limit_node_array(targets, target_count)


func _process_enemy_actions(delta: float) -> void:
	if enemies == null:
		return

	for enemy in enemies.get_children():
		if not enemy is Node2D:
			continue
		if _is_invalid_combat_unit(enemy):
			continue
		if _is_stunned(enemy):
			continue

		var cooldown := maxf(float(enemy.get_meta("action_cooldown", 0.0)) - delta, 0.0)
		enemy.set_meta("action_cooldown", cooldown)
		if cooldown > 0.0:
			continue

		if _try_perform_enemy_action(enemy):
			enemy.set_meta("action_cooldown", _get_unit_action_interval(enemy))


func _try_perform_enemy_action(enemy: Node2D) -> bool:
	var targets := _find_attack_targets_for_enemy(enemy, _get_attack_target_count(enemy))
	if targets.is_empty():
		return false
	if enemy.has_method("pause_after_attack"):
		enemy.pause_after_attack()
	for target in targets:
		_fire_projectile(enemy, target, _get_unit_attack_power(enemy), false, true)
	return true


func _find_attack_target_for_enemy(enemy: Node2D) -> Node:
	var targets := _find_attack_targets_for_enemy(enemy, 1)
	if targets.is_empty():
		return null
	return targets[0]


func _find_attack_targets_for_enemy(enemy: Node2D, target_count: int) -> Array[Node]:
	if _get_enemy_attack_distance(enemy) <= 0.0:
		var blocker := _get_enemy_blocker(enemy)
		var blocker_targets: Array[Node] = []
		if blocker != null:
			blocker_targets.append(blocker)
		return blocker_targets

	var targets: Array[Node] = []
	for unit in units.get_children():
		if not unit is Node2D:
			continue
		if _is_invalid_combat_unit(unit):
			continue
		if not _is_in_enemy_attack_range(enemy, unit):
			continue

		_insert_enemy_attack_target_sorted(targets, unit, enemy)
	return _limit_node_array(targets, target_count)


func _limit_node_array(nodes: Array[Node], limit: int) -> Array[Node]:
	var limited: Array[Node] = []
	for node in nodes.slice(0, maxi(limit, 0)):
		limited.append(node)
	return limited


func _is_in_unit_attack_range(unit: Node2D, target: Node2D, tile_size: Vector2) -> bool:
	if unit.has_method("is_target_in_attack_range"):
		return unit.is_target_in_attack_range(target, tile_size)
	return false


func _is_in_enemy_attack_range(enemy: Node2D, target: Node2D) -> bool:
	if enemy.has_method("is_target_in_attack_range"):
		return enemy.is_target_in_attack_range(target)
	return false


func _insert_unit_attack_target_sorted(targets: Array[Node], candidate: Node, attacker: Node) -> void:
	for index in targets.size():
		if _is_unit_attack_candidate_better(candidate, targets[index], attacker):
			targets.insert(index, candidate)
			return
	targets.append(candidate)


func _is_unit_attack_candidate_better(candidate: Node, current: Node, attacker: Node) -> bool:
	var candidate_taunt := _get_effective_taunt_level(candidate, attacker)
	var current_taunt := _get_effective_taunt_level(current, attacker)
	if candidate_taunt != current_taunt:
		return candidate_taunt > current_taunt

	var candidate_health := _get_unit_current_health(candidate)
	var current_health := _get_unit_current_health(current)
	if _is_archer_unit(attacker) and candidate_health != current_health:
		return candidate_health < current_health

	var candidate_progress := _get_enemy_distance_to_target(candidate as Node2D)
	var current_progress := _get_enemy_distance_to_target(current as Node2D)
	if candidate_progress != current_progress:
		return candidate_progress < current_progress

	var candidate_is_blocked := _get_enemy_blocker(candidate) != null
	var current_is_blocked := _get_enemy_blocker(current) != null
	if candidate_is_blocked != current_is_blocked:
		return not candidate_is_blocked

	var candidate_block_order := _get_enemy_block_order(candidate)
	var current_block_order := _get_enemy_block_order(current)
	if candidate_block_order != current_block_order:
		return candidate_block_order < current_block_order

	var candidate_spawn_order := _get_enemy_spawn_order(candidate)
	var current_spawn_order := _get_enemy_spawn_order(current)
	if candidate_spawn_order != current_spawn_order:
		return candidate_spawn_order < current_spawn_order

	if candidate_health != current_health:
		return candidate_health < current_health

	return randf() < 0.5


func _insert_heal_target_sorted(targets: Array[Node], candidate: Node) -> void:
	for index in targets.size():
		if _get_unit_current_health(candidate) < _get_unit_current_health(targets[index]):
			targets.insert(index, candidate)
			return
	targets.append(candidate)


func _insert_enemy_attack_target_sorted(targets: Array[Node], candidate: Node, attacker: Node) -> void:
	for index in targets.size():
		if _is_enemy_attack_candidate_better(candidate, targets[index], attacker):
			targets.insert(index, candidate)
			return
	targets.append(candidate)


func _is_enemy_attack_candidate_better(candidate: Node, current: Node, attacker: Node) -> bool:
	var candidate_taunt := _get_effective_taunt_level(candidate, attacker)
	var current_taunt := _get_effective_taunt_level(current, attacker)
	if candidate_taunt != current_taunt:
		return candidate_taunt > current_taunt

	return int(candidate.get_meta("deploy_order", -1)) > int(current.get_meta("deploy_order", -1))


func _get_enemy_attack_distance(enemy: Node) -> float:
	if "attack_distance_tiles" in enemy:
		return float(enemy.attack_distance_tiles)
	return 0.0


func _get_enemy_blocker(enemy: Node) -> Node:
	if "blocker" in enemy:
		var blocker: Node = enemy.blocker
		if _is_invalid_combat_unit(blocker):
			return null
		return blocker
	return null


func _is_block_relation(observer: Node, target: Node) -> bool:
	if observer == null or target == null:
		return false
	if _get_enemy_blocker(observer) == target:
		return true
	if _get_enemy_blocker(target) == observer:
		return true
	return false


func _get_enemy_block_order_for(enemy: Node, blocker: Node) -> int:
	if _get_enemy_blocker(enemy) != blocker:
		return 2147483647
	return int(enemy.get_meta("block_order", 2147483647))


func _get_enemy_block_order(enemy: Node) -> int:
	if _get_enemy_blocker(enemy) == null:
		return 2147483647
	return int(enemy.get_meta("block_order", 2147483647))


func _get_enemy_spawn_order(enemy: Node) -> int:
	return int(enemy.get_meta("spawn_order", 2147483647))


func _get_enemy_distance_to_target(enemy: Node2D) -> float:
	if enemy == null:
		return INF
	if "path_points" in enemy:
		var path_points: Array = enemy.path_points
		if not path_points.is_empty():
			var path_index := 0
			if "path_point_index" in enemy:
				path_index = int(enemy.path_point_index)
			if path_index >= path_points.size():
				return 0.0
			path_index = clampi(path_index, 0, path_points.size() - 1)

			var distance := enemy.global_position.distance_to(Vector2(path_points[path_index]))
			for point_index in range(path_index, path_points.size() - 1):
				distance += Vector2(path_points[point_index]).distance_to(Vector2(path_points[point_index + 1]))
			return distance
	if "has_target" in enemy and enemy.has_target and "target_position" in enemy:
		return enemy.global_position.distance_to(enemy.target_position)
	if not enemy_target_points.is_empty():
		return enemy.global_position.distance_to(_get_nearest_enemy_target(enemy.global_position))
	return INF


func _get_unit_current_health(unit: Node) -> float:
	if "health" in unit:
		return float(unit.health)
	return INF


func _get_attack_target_count(unit: Node) -> int:
	if _is_warrior_unit(unit):
		return maxi(_get_blocked_enemy_count_for_unit(unit), 1)
	if "attack_target_count" in unit:
		return maxi(int(unit.attack_target_count), 1)
	return 1


func _get_blocked_enemy_count_for_unit(unit: Node) -> int:
	if enemies == null or unit == null:
		return 0

	var count := 0
	for enemy in enemies.get_children():
		if _is_invalid_combat_unit(enemy):
			continue
		if _get_enemy_blocker(enemy) == unit:
			count += 1
	return count


func _get_taunt_level(unit: Node) -> float:
	if "taunt_level" in unit:
		return float(unit.taunt_level)
	return 0.0


func _get_effective_taunt_level(target: Node, observer: Node) -> float:
	var taunt_level := _get_taunt_level(target)
	if target.has_method("get_effective_taunt_level_for"):
		taunt_level = float(target.get_effective_taunt_level_for(observer))
	if observer != null and observer.has_method("get_taunt_bonus_against"):
		taunt_level += float(observer.get_taunt_bonus_against(target))
	if _is_block_relation(observer, target):
		taunt_level += 100.0
	return taunt_level


func _is_priest_unit(unit: Node) -> bool:
	if unit.has_method("is_healer"):
		return unit.is_healer()
	if "profession" in unit:
		return int(unit.profession) == 5
	return false


func _is_warrior_unit(unit: Node) -> bool:
	if unit == null:
		return false
	if unit.has_method("is_warrior"):
		return unit.is_warrior()
	if "profession" in unit:
		return int(unit.profession) == 1
	return false


func _is_archer_unit(unit: Node) -> bool:
	if unit == null:
		return false
	if unit.has_method("is_archer"):
		return unit.is_archer()
	if "profession" in unit:
		return int(unit.profession) == 3
	return false


func _get_unit_attack_power(unit: Node) -> int:
	if unit.has_method("get_effective_attack_power"):
		return int(unit.get_effective_attack_power())
	if "attack_power" in unit:
		return int(unit.attack_power)
	return 0


func _get_unit_attack_amount(unit: Node) -> int:
	var amount := _get_unit_attack_power(unit)
	unit.set_meta("last_attack_was_critical", false)
	var critical_chance := _get_float_property(unit, "critical_hit_chance", 0.0)
	if critical_chance > 0.0 and randf() < critical_chance:
		unit.set_meta("last_attack_was_critical", true)
		amount = maxi(1, int(roundf(float(amount) * _get_float_property(unit, "critical_hit_multiplier", 2.0))))
	return amount


func _get_unit_action_interval(unit: Node) -> float:
	if unit.has_method("get_effective_attack_speed"):
		var effective_speed := maxf(float(unit.get_effective_attack_speed()), 0.0)
		if effective_speed <= 0.0:
			return INF
		return 1.0 / effective_speed
	if not ("attack_speed" in unit):
		return 1.0
	var speed := maxf(float(unit.attack_speed), 0.0)
	if speed <= 0.0:
		return INF
	return 1.0 / speed


func _is_invalid_combat_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return true
	if unit.is_queued_for_deletion():
		return true
	if "is_defeated" in unit and unit.is_defeated:
		return true
	if "is_teleporting" in unit and unit.is_teleporting:
		return true
	return false


func _is_stunned(unit: Node) -> bool:
	return unit != null and unit.has_method("is_stunned") and bool(unit.is_stunned())


func _get_blocking_unit_at_cell(cell: Vector2i) -> Node:
	if not units_by_cell.has(cell):
		return null

	var unit: Node = units_by_cell[cell]
	if unit == null or not is_instance_valid(unit):
		return null
	if unit.is_queued_for_deletion():
		return null
	if "is_defeated" in unit and unit.is_defeated:
		return null
	if "can_block" in unit and int(unit.can_block) != 1:
		return null
	if "block_ability" in unit and int(unit.block_ability) == BLOCK_NONE:
		return null

	return unit


func _set_enemy_blocker(enemy: Node, blocker: Node) -> void:
	if enemy.has_method("set_blocker"):
		enemy.set_blocker(blocker)
		if not enemy.has_meta("block_order"):
			enemy.set_meta("block_order", block_order_count)
			block_order_count += 1


func _clear_enemy_blocker(enemy: Node) -> void:
	if enemy.has_method("clear_blocker"):
		enemy.clear_blocker()
	enemy.remove_meta("block_order")


func _configure_unit_for_grid(unit: Node) -> void:
	if unit.has_method("set_tile_size"):
		unit.set_tile_size(Vector2(grid_layer.tile_set.tile_size))
	if unit.has_method("set_health_bar_size"):
		unit.set_health_bar_size(Vector2(grid_layer.tile_set.tile_size))
	elif unit.has_method("set_health_bar_width"):
		unit.set_health_bar_width(float(grid_layer.tile_set.tile_size.x))
	if unit.has_method("set_skill_bar_visible"):
		unit.set_skill_bar_visible(unit.get_parent() == units and _is_character_skill_enabled(unit))
	if unit.has_method("set_skill_effects_enabled"):
		unit.set_skill_effects_enabled(unit.get_parent() == units)


func _configure_render_order() -> void:
	if grid_layer != null:
		grid_layer.z_index = GROUND_LAYER_Z
	if enemies != null:
		enemies.z_index = COMBAT_LAYER_Z
	if units != null:
		units.z_index = COMBAT_LAYER_Z
	if deploy_preview != null:
		deploy_preview.z_index = DEPLOY_PREVIEW_Z
	if projectiles != null:
		projectiles.z_index = PROJECTILE_LAYER_Z
	if overlay_layer != null:
		overlay_layer.z_index = OVERLAY_LAYER_Z


func _ensure_enemies_container() -> Node2D:
	var existing := get_node_or_null("Enemies")
	if existing is Node2D:
		return existing

	var container := Node2D.new()
	container.name = "Enemies"
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(container)
	return container


func _ensure_projectiles_container() -> Node2D:
	var existing := get_node_or_null("Projectiles")
	if existing is Node2D:
		return existing

	var container := Node2D.new()
	container.name = "Projectiles"
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(container)
	return container


func _collect_enemy_markers() -> void:
	enemy_spawn_points.clear()
	enemy_target_points.clear()
	enemy_waypoint_points.clear()
	enemy_teleport_points.clear()

	var spawn_markers: Array[Dictionary] = []
	var target_markers: Array[Dictionary] = []
	var waypoint_markers: Array[Dictionary] = []
	var teleport_markers: Array[Dictionary] = []
	var exclusive_marker_cells := {}
	var waypoint_marker_cells := {}
	for layer in _get_tile_map_layers(self):
		for cell in layer.get_used_cells():
			var marker := _make_enemy_marker_data(layer, cell)
			if _is_enemy_spawn_cell(layer, cell):
				_add_exclusive_enemy_marker(spawn_markers, exclusive_marker_cells, marker, "spawn")
			if _is_enemy_target_cell(layer, cell):
				_add_exclusive_enemy_marker(target_markers, exclusive_marker_cells, marker, "target")
			if _is_enemy_waypoint_cell(layer, cell):
				_add_enemy_waypoint_marker(waypoint_markers, waypoint_marker_cells, marker)
			if _is_enemy_teleport_cell(layer, cell):
				_add_exclusive_enemy_marker(teleport_markers, exclusive_marker_cells, marker, "teleport")

	_sort_enemy_marker_data(spawn_markers)
	_sort_enemy_marker_data(target_markers)
	_sort_enemy_marker_data(waypoint_markers)
	_sort_enemy_marker_data(teleport_markers)

	for marker in spawn_markers:
		enemy_spawn_points.append(marker["point"])
	for marker in target_markers:
		enemy_target_points.append(marker["point"])
	for marker in waypoint_markers:
		enemy_waypoint_points.append(marker["point"])
	for marker in teleport_markers:
		enemy_teleport_points.append(marker["point"])


func _add_exclusive_enemy_marker(markers: Array[Dictionary], occupied_cells: Dictionary, marker: Dictionary, marker_type: String) -> void:
	var grid_cell: Vector2i = marker["grid_cell"]
	if occupied_cells.has(grid_cell):
		var existing_type := str(occupied_cells[grid_cell])
		if existing_type != marker_type:
			push_warning("Enemy marker cell %s already has %s, ignoring %s." % [str(grid_cell), existing_type, marker_type])
		return

	occupied_cells[grid_cell] = marker_type
	markers.append(marker)


func _add_enemy_waypoint_marker(markers: Array[Dictionary], occupied_cells: Dictionary, marker: Dictionary) -> void:
	var grid_cell: Vector2i = marker["grid_cell"]
	if occupied_cells.has(grid_cell):
		return

	occupied_cells[grid_cell] = true
	markers.append(marker)


func _make_enemy_marker_data(layer: TileMapLayer, cell: Vector2i) -> Dictionary:
	var point := _get_enemy_marker_point(layer, cell)
	return {
		"cell": cell,
		"grid_cell": _get_enemy_marker_sort_cell(cell, point),
		"point": point,
	}


func _sort_enemy_marker_data(markers: Array[Dictionary]) -> void:
	markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cell_a: Vector2i = a["grid_cell"]
		var cell_b: Vector2i = b["grid_cell"]
		if cell_a.y != cell_b.y:
			return cell_a.y < cell_b.y
		return cell_a.x < cell_b.x
	)


func _get_enemy_marker_point(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	var marker_point := layer.to_global(layer.map_to_local(cell + ENEMY_MARKER_POINT_OFFSET))
	if grid_layer == null or grid_layer.tile_set == null:
		return marker_point
	return _cell_to_global_center(_global_to_grid_cell(marker_point))


func _global_to_grid_cell(point: Vector2) -> Vector2i:
	return grid_layer.local_to_map(grid_layer.to_local(point))


func _get_enemy_marker_sort_cell(fallback_cell: Vector2i, point: Vector2) -> Vector2i:
	if grid_layer == null:
		return fallback_cell
	return _global_to_grid_cell(point)


func _is_enemy_spawn_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	var source_id := layer.get_cell_source_id(cell)
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	if not _is_enemy_marker_lower_cell(atlas_coords):
		return false
	if _get_cell_custom_data_bool(layer, cell, "enemy_spawn"):
		return true
	if _get_cell_custom_data_bool(layer, cell, "enemy_target"):
		return false
	if not _is_enemy_marker_source(layer, source_id):
		return false
	if _is_combined_enemy_marker_source(layer, source_id):
		return _is_red_enemy_marker_lower_cell(atlas_coords)
	return not _is_blue_enemy_marker_source(layer, source_id)


func _is_enemy_target_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	var source_id := layer.get_cell_source_id(cell)
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	if not _is_enemy_marker_lower_cell(atlas_coords):
		return false
	if _get_cell_custom_data_bool(layer, cell, "enemy_target"):
		return true
	if _get_cell_custom_data_bool(layer, cell, "enemy_spawn"):
		return false
	if not _is_enemy_marker_source(layer, source_id):
		return false
	if _is_combined_enemy_marker_source(layer, source_id):
		return _is_blue_enemy_marker_lower_cell(atlas_coords)
	return _is_blue_enemy_marker_source(layer, source_id)


func _is_enemy_waypoint_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	return _get_cell_custom_data_bool(layer, cell, "enemy_waypoint")


func _is_enemy_teleport_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	var source_id := layer.get_cell_source_id(cell)
	var atlas_coords := layer.get_cell_atlas_coords(cell)
	return _is_green_enemy_marker_lower_cell(atlas_coords) and _is_enemy_marker_source(layer, source_id)


func _is_enemy_marker_lower_cell(atlas_coords: Vector2i) -> bool:
	return _is_red_enemy_marker_lower_cell(atlas_coords) or _is_blue_enemy_marker_lower_cell(atlas_coords)


func _is_red_enemy_marker_lower_cell(atlas_coords: Vector2i) -> bool:
	return atlas_coords == Vector2i(0, 1)


func _is_blue_enemy_marker_lower_cell(atlas_coords: Vector2i) -> bool:
	return atlas_coords == Vector2i(1, 1)


func _is_green_enemy_marker_lower_cell(atlas_coords: Vector2i) -> bool:
	return atlas_coords == Vector2i(2, 1)


func _get_cell_custom_data_bool(layer: TileMapLayer, cell: Vector2i, key: StringName) -> bool:
	var data := layer.get_cell_tile_data(cell)
	if data == null or layer.tile_set == null or not _tile_set_has_custom_data_layer(layer.tile_set, key):
		return false

	var value = data.get_custom_data(key)
	return value is bool and value


func _tile_set_has_custom_data_layer(tile_set: TileSet, key: StringName) -> bool:
	for index in tile_set.get_custom_data_layers_count():
		if tile_set.get_custom_data_layer_name(index) == key:
			return true
	return false


func _is_enemy_marker_source(layer: TileMapLayer, source_id: int) -> bool:
	var texture_path := _get_tile_source_texture_path(layer, source_id)
	return texture_path.get_file().begins_with("\u52a8\u6001\u74e6\u7247")


func _is_combined_enemy_marker_source(layer: TileMapLayer, source_id: int) -> bool:
	return _is_enemy_marker_source(layer, source_id)


func _is_blue_enemy_marker_source(layer: TileMapLayer, source_id: int) -> bool:
	var texture_path := _get_tile_source_texture_path(layer, source_id)
	return texture_path.contains("\u84dd\u8272")


func _get_tile_source_texture_path(layer: TileMapLayer, source_id: int) -> String:
	if source_id < 0 or layer.tile_set == null:
		return ""

	var source := layer.tile_set.get_source(source_id)
	if source is TileSetAtlasSource and source.texture != null:
		return source.texture.resource_path

	return ""


func _process_enemy_spawning(delta: float) -> void:
	if enemy_scene == null or enemy_spawn_points.is_empty() or enemy_target_points.is_empty():
		return

	enemy_spawn_elapsed += delta
	if enemy_spawn_elapsed < enemy_spawn_interval:
		return

	enemy_spawn_elapsed = 0.0
	_spawn_enemy(enemy_scene, next_enemy_spawn_index)
	next_enemy_spawn_index += 1


func _has_wave_data() -> bool:
	return wave_data != null and not wave_data.waves.is_empty()


func _get_total_configured_enemy_count() -> int:
	if not _has_wave_data():
		return 0

	var total := 0
	for wave in wave_data.waves:
		if wave == null:
			continue
		for entry in wave.entries:
			if entry == null or entry.enemy_scene == null:
				continue
			total += maxi(entry.count, 0)
	return total


func _process_wave_spawning(delta: float) -> void:
	if enemy_spawn_points.is_empty() or enemy_target_points.is_empty():
		return

	_process_parallel_wave_spawning(delta)

	if active_wave_index >= main_wave_indices.size():
		if _is_stage_clear_ready():
			wave_state = WAVE_STATE_FINISHED
			_clear_stage()
		else:
			wave_state = WAVE_STATE_WAITING_FOR_CLEAR
		return

	match wave_state:
		WAVE_STATE_SPAWNING:
			_process_active_wave_spawning(delta)
		WAVE_STATE_WAITING_FOR_CLEAR:
			if _get_active_main_wave_enemy_count() <= 0:
				wave_clear_wait_elapsed = 0.0
				if active_wave_index >= main_wave_indices.size() - 1:
					if _is_stage_clear_ready():
						_clear_stage()
				else:
					wave_state = WAVE_STATE_WAITING_AFTER_CLEAR
		WAVE_STATE_WAITING_AFTER_CLEAR:
			var wave := _get_active_main_wave()
			if wave == null:
				_advance_to_next_wave()
				return
			wave_clear_wait_elapsed += delta
			if wave_clear_wait_elapsed >= wave.wait_after_clear:
				_advance_to_next_wave()


func _process_active_wave_spawning(delta: float) -> void:
	var wave := _get_active_main_wave()
	if wave == null:
		wave_state = WAVE_STATE_WAITING_FOR_CLEAR
		return

	_ensure_wave_entry_states(active_wave_entry_states, wave)
	if active_wave_entry_states.is_empty():
		wave_state = WAVE_STATE_WAITING_FOR_CLEAR
		return

	if _process_wave_entry_states(active_wave_entry_states, delta, _get_wave_number(wave, active_wave_index)):
		wave_state = WAVE_STATE_WAITING_FOR_CLEAR


func _process_parallel_wave_spawning(delta: float) -> void:
	for wave_index in parallel_wave_indices:
		var wave := wave_data.waves[wave_index]
		if wave == null:
			continue

		var key := str(wave_index)
		var states: Array[Dictionary] = []
		if parallel_wave_entry_states.has(key):
			states = parallel_wave_entry_states[key]
		_ensure_wave_entry_states(states, wave)
		if states.is_empty():
			parallel_wave_entry_states[key] = states
			continue
		_process_wave_entry_states(states, delta, _get_wave_number(wave, wave_index))
		parallel_wave_entry_states[key] = states


func _process_wave_entry_states(states: Array[Dictionary], delta: float, wave_number: int) -> bool:
	var all_finished := true
	for index in states.size():
		var state := states[index]
		if bool(state.get("finished", false)):
			continue

		all_finished = false
		var entry: EnemySpawnEntry = state["entry"]
		state["elapsed"] = float(state.get("elapsed", 0.0)) + delta

		var spawned := int(state.get("spawned", 0))
		var next_spawn_time := entry.delay_before_start
		if spawned > 0:
			next_spawn_time = entry.delay_before_start + entry.interval * spawned

		if float(state["elapsed"]) < next_spawn_time:
			states[index] = state
			continue

		_spawn_enemy(
			entry.enemy_scene,
			_get_entry_spawn_point_index(entry),
			_get_entry_target_point_index(entry),
			_get_entry_waypoint_indices(entry),
			entry.override_move_speed,
			entry.move_speed_tiles_per_second,
			entry,
			wave_number
		)

		spawned += 1
		state["spawned"] = spawned
		state["finished"] = spawned >= entry.count
		states[index] = state
		_update_wave_progress_display()
	return all_finished


func _ensure_wave_entry_states(states: Array[Dictionary], wave: EnemyWave) -> void:
	if not states.is_empty():
		return

	for entry in wave.entries:
		if entry == null or entry.enemy_scene == null or entry.count <= 0:
			continue
		states.append({
			"entry": entry,
			"elapsed": 0.0,
			"spawned": 0,
			"finished": false,
		})


func _advance_to_next_wave() -> void:
	active_wave_index += 1
	active_wave_entry_states.clear()
	wave_clear_wait_elapsed = 0.0
	wave_state = WAVE_STATE_SPAWNING
	_update_wave_progress_display()
	if active_wave_index >= main_wave_indices.size():
		if _is_stage_clear_ready():
			wave_state = WAVE_STATE_FINISHED
			_clear_stage()
		else:
			wave_state = WAVE_STATE_WAITING_FOR_CLEAR
	else:
		_show_stage_feedback("第 %d 波来袭" % _get_active_main_wave_number(), Color(1.0, 0.88, 0.42, 1.0), 1.6)


func _is_stage_clear_ready() -> bool:
	return _are_parallel_waves_finished_spawning() and _get_active_enemy_count() <= 0


func _are_parallel_waves_finished_spawning() -> bool:
	for wave_index in parallel_wave_indices:
		var key := str(wave_index)
		if not parallel_wave_entry_states.has(key):
			return false

		var states: Array[Dictionary] = parallel_wave_entry_states[key]
		for state in states:
			if not bool(state.get("finished", false)):
				return false
	return true


func _get_active_enemy_count() -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		count += 1
	return count


func _get_active_main_wave_enemy_count() -> int:
	var count := 0
	var wave_number := _get_active_main_wave_number()
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if int(enemy.get_meta("wave_number", -1)) != wave_number:
			continue
		count += 1
	return count


func _get_active_main_wave() -> EnemyWave:
	if not _has_wave_data() or active_wave_index < 0 or active_wave_index >= main_wave_indices.size():
		return null
	return wave_data.waves[main_wave_indices[active_wave_index]]


func _get_active_main_wave_number() -> int:
	var wave := _get_active_main_wave()
	if wave == null:
		return -1
	return _get_wave_number(wave, active_wave_index)


func _refresh_wave_runtime_indices() -> void:
	main_wave_indices.clear()
	parallel_wave_indices.clear()
	parallel_wave_entry_states.clear()
	active_wave_index = 0
	active_wave_entry_states.clear()
	wave_clear_wait_elapsed = 0.0
	wave_state = WAVE_STATE_SPAWNING

	if not _has_wave_data():
		return

	for index in wave_data.waves.size():
		var wave := wave_data.waves[index]
		if wave == null:
			continue
		if _get_wave_number(wave, index) == 0:
			parallel_wave_indices.append(index)
		else:
			main_wave_indices.append(index)


func _get_wave_number(wave: EnemyWave, fallback_index: int) -> int:
	if wave != null and "wave_number" in wave:
		return int(wave.wave_number)
	return fallback_index + 1


func _spawn_enemy(
	spawn_enemy_scene: PackedScene,
	spawn_point_index: int,
	target_point_index := -1,
	waypoint_indices: Array[int] = [],
	should_override_move_speed := override_enemy_move_speed,
	override_move_speed_value := enemy_move_speed_tiles_per_second,
	entry: EnemySpawnEntry = null,
	wave_number := -1
) -> void:
	if spawn_enemy_scene == null:
		return

	var enemy := spawn_enemy_scene.instantiate()
	if not enemy is Node2D:
		enemy.queue_free()
		return

	var is_boss_enemy := entry != null and "enemy_type" in entry and int(entry.enemy_type) == 1
	if "is_boss" in enemy:
		enemy.is_boss = is_boss_enemy
	if is_boss_enemy:
		_show_stage_feedback("Boss 出场", Color(1.0, 0.28, 0.18, 1.0), 2.0)

	enemies.add_child(enemy)
	enemy.z_as_relative = true
	enemy.z_index = ENEMY_BODY_Z
	enemies.move_child(enemy, 0)
	if "enemy_id" in enemy:
		ARCHIVE_STATE.unlock_enemy(str(enemy.enemy_id))
	enemy.set_meta("spawn_order", spawned_enemy_count + 1)
	enemy.set_meta("wave_number", wave_number)
	enemy.set_meta("is_boss", is_boss_enemy)
	spawned_enemy_count += 1
	var spawn_point := enemy_spawn_points[wrapi(spawn_point_index, 0, enemy_spawn_points.size())]
	enemy.global_position = spawn_point
	_configure_unit_for_grid(enemy)
	if should_override_move_speed and "move_speed_tiles_per_second" in enemy:
		enemy.move_speed_tiles_per_second = override_move_speed_value

	var target_point := _get_enemy_target_by_index(target_point_index, spawn_point)
	var waypoint_points := _get_enemy_waypoints_by_indices(waypoint_indices)
	var path_data := _find_enemy_path_data(
		spawn_point,
		target_point,
		waypoint_points,
		_get_entry_waypoint_waits_from_indices(waypoint_indices, entry),
		_get_entry_teleport_events(entry)
	)
	var path_points: Array[Vector2] = path_data.get("points", [])
	if enemy.has_method("set_path_points") and not path_points.is_empty():
		enemy.set_path_points(path_points, path_data.get("waits", {}), path_data.get("teleports", {}))
	elif enemy.has_method("set_target_position"):
		enemy.set_target_position(target_point)
	if enemy.has_signal("reached_target"):
		enemy.reached_target.connect(_on_enemy_reached_target.bind(enemy))
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy))


func _find_enemy_path_points(spawn_point: Vector2, target_point: Vector2, waypoint_points: Array[Vector2] = []) -> Array[Vector2]:
	return _find_enemy_path_data(spawn_point, target_point, waypoint_points).get("points", [])


func _find_enemy_path_data(
	spawn_point: Vector2,
	target_point: Vector2,
	waypoint_points: Array[Vector2] = [],
	waypoint_waits: Dictionary = {},
	teleport_events: Array[Dictionary] = []
) -> Dictionary:
	var result: Array[Vector2] = []
	var waits := {}
	var teleports := {}
	if grid_layer == null or grid_layer.tile_set == null:
		return {
			"points": result,
			"waits": waits,
			"teleports": teleports,
		}

	var current_point := spawn_point
	for index in waypoint_points.size():
		if not _append_enemy_path_segment(result, current_point, waypoint_points[index]):
			var empty_result: Array[Vector2] = []
			return {
				"points": empty_result,
				"waits": waits,
				"teleports": teleports,
			}
		var wait_duration := maxf(float(waypoint_waits.get(index, 0.0)), 0.0)
		if wait_duration > 0.0 and not result.is_empty():
			waits[result.size() - 1] = wait_duration
		current_point = waypoint_points[index]

	for teleport_event in teleport_events:
		var enter_point: Vector2 = teleport_event.get("enter_point", current_point)
		var exit_point: Vector2 = teleport_event.get("exit_point", enter_point)
		if not _append_enemy_path_segment(result, current_point, enter_point):
			var empty_result: Array[Vector2] = []
			return {
				"points": empty_result,
				"waits": waits,
				"teleports": teleports,
			}
		if not result.is_empty():
			teleports[result.size() - 1] = {
				"exit_position": exit_point,
				"wait": maxf(float(teleport_event.get("wait", 0.0)), 0.0),
			}
		current_point = exit_point

	if not _append_enemy_path_segment(result, current_point, target_point):
		var empty_result: Array[Vector2] = []
		return {
			"points": empty_result,
			"waits": waits,
			"teleports": teleports,
		}

	return {
		"points": result,
		"waits": waits,
		"teleports": teleports,
	}


func _append_enemy_path_segment(result: Array[Vector2], start_point: Vector2, target_point: Vector2) -> bool:
	var start_cell := grid_layer.local_to_map(grid_layer.to_local(start_point))
	var target_cell := grid_layer.local_to_map(grid_layer.to_local(target_point))
	var cells := _find_enemy_path_cells(start_cell, target_cell)
	if cells.is_empty():
		return false
	if cells.size() == 1:
		result.append(_cell_to_global_center(cells[0]))
		return true

	for cell_index in range(1, cells.size()):
		result.append(_cell_to_global_center(cells[cell_index]))
	return true


func _find_enemy_path_cells(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if start_cell == target_cell:
		return [target_cell]

	var queue: Array[Vector2i] = [start_cell]
	var visited := {
		start_cell: true,
	}
	var came_from := {}
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]

	var queue_index := 0
	while queue_index < queue.size():
		var current := queue[queue_index]
		queue_index += 1

		for direction in directions:
			var next_cell := current + direction
			if visited.has(next_cell):
				continue
			if next_cell != target_cell and not _is_enemy_path_cell_walkable(next_cell):
				continue

			visited[next_cell] = true
			came_from[next_cell] = current
			if next_cell == target_cell:
				return _reconstruct_enemy_path(came_from, start_cell, target_cell)
			queue.append(next_cell)

	return empty_path


func _reconstruct_enemy_path(came_from: Dictionary, start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [target_cell]
	var current := target_cell
	while current != start_cell:
		if not came_from.has(current):
			var empty_path: Array[Vector2i] = []
			return empty_path
		current = came_from[current]
		path.push_front(current)
	return path


func _is_enemy_path_cell_walkable(cell: Vector2i) -> bool:
	var tile_data := grid_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	return int(tile_data.get_custom_data("placement_type")) != 1


func _get_entry_spawn_point_index(entry: EnemySpawnEntry) -> int:
	if entry == null:
		return 0
	return maxi(entry.spawn_point_order - 1, 0)


func _get_entry_target_point_index(entry: EnemySpawnEntry) -> int:
	if entry == null:
		return 0
	return maxi(entry.target_point_order - 1, 0)


func _get_entry_waypoint_indices(entry: EnemySpawnEntry) -> Array[int]:
	var indices: Array[int] = []
	if entry == null:
		return indices

	for order in entry.waypoint_orders:
		indices.append(maxi(int(order) - 1, 0))
	return indices


func _get_entry_waypoint_waits_from_indices(waypoint_indices: Array[int], entry: EnemySpawnEntry) -> Dictionary:
	var waits := {}
	if entry == null:
		return waits

	if "waypoint_wait_durations" in entry and not entry.waypoint_wait_durations.is_empty():
		for route_index in mini(waypoint_indices.size(), entry.waypoint_wait_durations.size()):
			var wait_duration := maxf(float(entry.waypoint_wait_durations[route_index]), 0.0)
			if wait_duration > 0.0:
				waits[route_index] = wait_duration
		return waits

	for route_index in waypoint_indices.size():
		var waypoint_order := waypoint_indices[route_index] + 1
		var wait_duration := _get_waypoint_wait_duration(entry, waypoint_order)
		if wait_duration > 0.0:
			waits[route_index] = wait_duration
	return waits


func _get_entry_teleport_events(entry: EnemySpawnEntry) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if entry == null or enemy_teleport_points.is_empty():
		return events
	if not ("teleport_pairs" in entry):
		return events

	var pairs: Array[Vector2i] = entry.teleport_pairs
	for index in pairs.size():
		var pair := pairs[index]
		if pair.x <= 0 or pair.y <= 0:
			continue

		events.append({
			"enter_point": enemy_teleport_points[wrapi(pair.x - 1, 0, enemy_teleport_points.size())],
			"exit_point": enemy_teleport_points[wrapi(pair.y - 1, 0, enemy_teleport_points.size())],
			"wait": _get_entry_teleport_wait(entry, index),
		})
	return events


func _get_entry_teleport_wait(entry: EnemySpawnEntry, index: int) -> float:
	if entry == null or not ("teleport_waits" in entry):
		return 0.0

	var waits: Array[float] = entry.teleport_waits
	if waits.is_empty():
		return 0.0
	if index >= 0 and index < waits.size():
		return maxf(float(waits[index]), 0.0)
	return maxf(float(waits[0]), 0.0)


func _get_waypoint_wait_duration(entry: EnemySpawnEntry, waypoint_order: int) -> float:
	if not ("waypoint_waits" in entry):
		return 0.0

	var waits: Dictionary = entry.waypoint_waits
	var string_key := str(waypoint_order)
	if waits.has(waypoint_order):
		return maxf(float(waits[waypoint_order]), 0.0)
	if waits.has(string_key):
		return maxf(float(waits[string_key]), 0.0)
	return 0.0


func _get_enemy_waypoints_by_indices(waypoint_indices: Array[int]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if enemy_waypoint_points.is_empty():
		return points

	for index in waypoint_indices:
		points.append(enemy_waypoint_points[wrapi(index, 0, enemy_waypoint_points.size())])
	return points


func _get_enemy_target_by_index(target_point_index: int, from_point: Vector2) -> Vector2:
	if enemy_target_points.is_empty():
		return from_point
	if target_point_index < 0:
		return _get_nearest_enemy_target(from_point)
	return enemy_target_points[wrapi(target_point_index, 0, enemy_target_points.size())]


func _get_nearest_enemy_target(from_point: Vector2) -> Vector2:
	var nearest := enemy_target_points[0]
	var nearest_distance := from_point.distance_squared_to(nearest)
	for point in enemy_target_points:
		var distance := from_point.distance_squared_to(point)
		if distance < nearest_distance:
			nearest = point
			nearest_distance = distance

	return nearest


func _on_enemy_reached_target(_enemy_id: String, _enemy: Node) -> void:
	if is_stage_failed:
		return

	if _is_boss_enemy(_enemy):
		_fail_stage("Boss 进入目标点")
		return

	remaining_lives = maxi(remaining_lives - 1, 0)
	_update_lives_display()
	if remaining_lives <= 0:
		_fail_stage("生命值归零")


func _on_enemy_defeated(_enemy_id: String, _enemy: Node) -> void:
	if is_stage_failed:
		return

	_award_skill_charge_for_kill_participants(_enemy)
	defeated_enemy_count += 1
	_update_enemy_defeat_display()


func _is_boss_enemy(enemy: Node) -> bool:
	if enemy == null:
		return false
	if "is_boss" in enemy and bool(enemy.is_boss):
		return true
	return bool(enemy.get_meta("is_boss", false))


func _update_lives_display() -> void:
	if lives_label == null:
		return

	lives_label.text = "♥".repeat(maxi(remaining_lives, 0))


func _fail_stage(reason := "防线失守") -> void:
	is_stage_failed = true
	Input.set_custom_mouse_cursor(null)
	failure_label.visible = true
	failure_label.text = "关卡失败\n%s" % reason
	_show_stage_feedback(reason, Color(1.0, 0.32, 0.25, 1.0), 2.2)
	_sync_stage_pause()


func _clear_stage() -> void:
	if is_stage_cleared or is_stage_failed:
		return

	is_stage_cleared = true
	is_stage_clear_dialog_handled = false
	Input.set_custom_mouse_cursor(null)
	ARCHIVE_STATE.mark_stage_cleared(_get_current_stage_number())
	_unlock_next_stage()
	var unlocked_character_id := _unlock_stage_clear_character()
	_update_stage_clear_dialog_text(unlocked_character_id)
	failure_label.visible = false
	exit_confirm_dialog.hide()
	restart_confirm_dialog.hide()
	stage_clear_dialog.popup_centered(STAGE_CLEAR_DIALOG_SIZE)
	_sync_stage_pause()


func _unlock_stage_clear_character() -> String:
	var current_stage_number := _get_current_stage_number()
	var character_id := STAGE_CATALOG.get_reward_character(current_stage_number)
	if character_id.strip_edges().is_empty() and STAGE_CLEAR_CHARACTER_UNLOCKS.has(current_stage_number):
		character_id = str(STAGE_CLEAR_CHARACTER_UNLOCKS[current_stage_number])
	if character_id.strip_edges().is_empty():
		return ""
	if ARCHIVE_STATE.is_character_unlocked(character_id):
		return ""

	ARCHIVE_STATE.unlock_character(character_id)
	return character_id


func _unlock_next_stage() -> void:
	var current_stage_number := _get_current_stage_number()
	if current_stage_number <= 0:
		return
	if current_stage_number != ARCHIVE_STATE.get_highest_unlocked_stage():
		return

	var next_stage := STAGE_CATALOG.get_stage_by_global_number(current_stage_number + 1)
	if next_stage.is_empty():
		return

	ARCHIVE_STATE.unlock_stage(current_stage_number + 1)


func _update_stage_clear_dialog_text(unlocked_character_id: String) -> void:
	var has_next_stage := not _get_next_stage_scene_path().is_empty()
	var ok_button := stage_clear_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = "下一关" if has_next_stage else "返回"

	stage_clear_dialog.title = ""
	if unlocked_character_id.strip_edges().is_empty():
		stage_clear_dialog.dialog_text = "关卡胜利"
		_update_stage_clear_reward_portrait("")
		return

	stage_clear_dialog.dialog_text = "关卡胜利\n新获得角色：%s" % unlocked_character_id.to_upper()
	_update_stage_clear_reward_portrait(unlocked_character_id)

func _update_stage_clear_reward_portrait(character_id: String) -> void:
	_clear_stage_clear_reward_portrait()
	if stage_clear_reward_portrait_container == null or stage_clear_reward_portrait_root == null:
		return

	var normalized_id := character_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		stage_clear_reward_portrait_container.visible = false
		return

	var scene := load(CHARACTER_SCENE_TEMPLATE % normalized_id) as PackedScene
	if scene == null:
		stage_clear_reward_portrait_container.visible = false
		return

	stage_clear_reward_unit = scene.instantiate()
	stage_clear_reward_portrait_root.add_child(stage_clear_reward_unit)
	if stage_clear_reward_unit is Node2D:
		stage_clear_reward_unit.position = Vector2(84, 96)
		stage_clear_reward_unit.scale = Vector2(5, 5)
		_hide_portrait_helpers(stage_clear_reward_unit)
		_play_portrait_left_animation(stage_clear_reward_unit)
	stage_clear_reward_portrait_container.visible = true


func _clear_stage_clear_reward_portrait() -> void:
	if stage_clear_reward_unit != null and is_instance_valid(stage_clear_reward_unit):
		stage_clear_reward_unit.queue_free()
	stage_clear_reward_unit = null


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

func _get_map_bounds() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false

	for layer in _get_tile_map_layers(self):
		var layer_bounds := _get_tile_map_layer_bounds(layer)
		if layer_bounds.size.x <= 0.0 or layer_bounds.size.y <= 0.0:
			continue

		if has_bounds:
			bounds = bounds.merge(layer_bounds)
		else:
			bounds = layer_bounds
			has_bounds = true

	return bounds


func _get_tile_map_layers(node: Node) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []

	for child in node.get_children():
		if child is TileMapLayer:
			layers.append(child)

		layers.append_array(_get_tile_map_layers(child))

	return layers


func _get_tile_map_layer_bounds(layer: TileMapLayer) -> Rect2:
	var used_rect := layer.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0 or layer.tile_set == null:
		return Rect2()

	var half_tile_size := Vector2(layer.tile_set.tile_size) * 0.5
	var first_cell := used_rect.position
	var last_cell := used_rect.position + used_rect.size - Vector2i.ONE
	var local_top_left := layer.map_to_local(first_cell) - half_tile_size
	var local_bottom_right := layer.map_to_local(last_cell) + half_tile_size

	var global_points := [
		layer.to_global(local_top_left),
		layer.to_global(Vector2(local_bottom_right.x, local_top_left.y)),
		layer.to_global(local_bottom_right),
		layer.to_global(Vector2(local_top_left.x, local_bottom_right.y)),
	]

	var min_point: Vector2 = global_points[0]
	var max_point: Vector2 = global_points[0]
	for point in global_points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)

	return Rect2(min_point, max_point - min_point)
