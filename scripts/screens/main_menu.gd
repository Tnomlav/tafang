extends Control

const LEVEL_SELECT_SCENE := "res://scenes/screens/level_select.tscn"
const ARCHIVE_SCENE := "res://scenes/screens/archive.tscn"
const FORMATION_SCENE := "res://scenes/screens/formation.tscn"
const ARCHIVE_STATE := preload("res://scripts/systems/archive_state.gd")
const STAGE_CATALOG := preload("res://scripts/systems/stage_catalog.gd")
const RESET_CONFIRM_SIZE := Vector2i(560, 300)
const GIFT_DIALOG_SIZE := Vector2i(420, 540)
const GIFT_PORTRAIT_SIZE := Vector2i(240, 240)
const GIFT_PORTRAIT_TOP_OFFSET := 32.0
const GIFT_PORTRAIT_UNIT_POSITION := Vector2(120, 168)
const GIFT_PORTRAIT_UNIT_SCALE := Vector2(7, 7)
const GIFT_CHARACTER_SCENE_TEMPLATE := "res://scenes/units/characters/%s.tscn"
const DIALOG_BUTTON_MIN_SIZE := Vector2(140, 48)
const DIALOG_PANEL_COLOR := Color(0.065, 0.072, 0.085, 0.96)
const DIALOG_PANEL_BORDER_COLOR := Color(0.82, 0.69, 0.38, 1.0)
const DIALOG_BUTTON_COLOR := Color(0.13, 0.14, 0.16, 0.96)
const DIALOG_BUTTON_HOVER_COLOR := Color(0.21, 0.19, 0.14, 1.0)
const DIALOG_BUTTON_PRESSED_COLOR := Color(0.28, 0.23, 0.14, 1.0)
const DIALOG_TEXT_COLOR := Color(0.92, 0.89, 0.78, 1.0)
const DIALOG_TITLE_COLOR := Color(0.98, 0.91, 0.64, 1.0)
const UI_TEXT := {
	"title": "荒野行动",
	"subtitle": "准备好进入战场",
	"start": "进入关卡",
	"continue": "继续游戏",
	"archive": "图鉴",
	"reset": "重置进度",
	"quit": "退出游戏",
	"reset_title": "确认重置进度",
	"reset_ok": "重置",
	"reset_body": "重置后会清空已解锁角色、敌人图鉴和编队。确定继续吗？",
	"cancel": "取消",
	"gift_ok": "确认",
	"gift_body": "新获得角色：%s",
}

@onready var start_button: Button = $Center/MenuPanel/Margin/Stack/StartButton
@onready var menu_stack: VBoxContainer = $Center/MenuPanel/Margin/Stack
@onready var continue_button: Button = get_node_or_null("Center/MenuPanel/Margin/Stack/ContinueButton") as Button
@onready var archive_button: Button = $Center/MenuPanel/Margin/Stack/ArchiveButton
@onready var reset_progress_button: Button = $Center/MenuPanel/Margin/Stack/ResetProgressButton
@onready var quit_button: Button = $Center/MenuPanel/Margin/Stack/QuitButton
@onready var reset_confirm_dialog: ConfirmationDialog = $ResetFirstConfirmDialog

var gift_dialog: ConfirmationDialog = null
var gift_content: Control = null
var gift_portrait_container: SubViewportContainer = null
var gift_portrait_root: Node2D = null


func _ready() -> void:
	ARCHIVE_STATE.ensure_initialized()
	_ensure_continue_button()
	_ensure_gift_dialog()
	_localize_menu_text()
	_configure_dialogs()
	start_button.grab_focus()
	_connect_once(start_button.pressed, _on_start_pressed)
	_connect_once(continue_button.pressed, _on_continue_pressed)
	_connect_once(archive_button.pressed, _on_archive_pressed)
	_connect_once(reset_progress_button.pressed, _on_reset_progress_pressed)
	_connect_once(quit_button.pressed, _on_quit_pressed)
	_connect_once(reset_confirm_dialog.confirmed, _on_reset_confirmed)
	call_deferred("_show_starter_gift")


func _ensure_continue_button() -> void:
	if continue_button != null:
		return

	continue_button = start_button.duplicate() as Button
	continue_button.name = "ContinueButton"
	continue_button.text = UI_TEXT["continue"]
	menu_stack.add_child(continue_button)
	menu_stack.move_child(continue_button, start_button.get_index() + 1)


func _ensure_gift_dialog() -> void:
	if gift_dialog != null:
		return

	# AcceptDialog stretches its direct Control children to the whole dialog, so
	# the portrait lives inside an extra container that keeps its own anchors.
	gift_content = Control.new()
	gift_content.name = "StarterGiftContent"
	gift_content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	gift_portrait_container = SubViewportContainer.new()
	gift_portrait_container.name = "StarterGiftPortraitContainer"
	gift_portrait_container.stretch = false
	gift_portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_portrait_container.custom_minimum_size = Vector2(GIFT_PORTRAIT_SIZE)
	gift_portrait_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	gift_portrait_container.offset_left = -GIFT_PORTRAIT_SIZE.x * 0.5
	gift_portrait_container.offset_right = GIFT_PORTRAIT_SIZE.x * 0.5
	gift_portrait_container.offset_top = GIFT_PORTRAIT_TOP_OFFSET
	gift_portrait_container.offset_bottom = GIFT_PORTRAIT_TOP_OFFSET + GIFT_PORTRAIT_SIZE.y

	var portrait_viewport := SubViewport.new()
	portrait_viewport.name = "StarterGiftPortraitViewport"
	portrait_viewport.disable_3d = true
	portrait_viewport.transparent_bg = true
	portrait_viewport.size = GIFT_PORTRAIT_SIZE
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	gift_portrait_container.add_child(portrait_viewport)

	gift_portrait_root = Node2D.new()
	gift_portrait_root.name = "StarterGiftPortraitRoot"
	portrait_viewport.add_child(gift_portrait_root)
	gift_content.add_child(gift_portrait_container)

	gift_dialog = ConfirmationDialog.new()
	gift_dialog.name = "StarterGiftDialog"
	gift_dialog.title = ""
	gift_dialog.min_size = GIFT_DIALOG_SIZE
	gift_dialog.add_child(gift_content)
	add_child(gift_dialog)


## Grants the starter character when the player enters the game for the first
## time and announces it before the player starts a stage.
func _show_starter_gift() -> void:
	if gift_dialog == null:
		return

	var granted_character_id := ARCHIVE_STATE.claim_starter_character()
	if granted_character_id.strip_edges().is_empty():
		return

	_configure_gift_dialog()
	_update_gift_portrait(granted_character_id)
	gift_dialog.dialog_text = UI_TEXT["gift_body"] % granted_character_id.to_upper()
	gift_dialog.popup_centered(GIFT_DIALOG_SIZE)


func _configure_gift_dialog() -> void:
	gift_dialog.title = ""
	gift_dialog.ok_button_text = UI_TEXT["gift_ok"]
	gift_dialog.add_theme_stylebox_override("embedded_border", _make_dialog_panel_style())
	gift_dialog.add_theme_stylebox_override("embedded_unfocused_border", _make_dialog_panel_style())
	gift_dialog.add_theme_font_size_override("title_font_size", 1)
	gift_dialog.add_theme_color_override("title_color", DIALOG_TITLE_COLOR)

	var label := gift_dialog.get_label()
	if label != null:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", DIALOG_TITLE_COLOR)
		label.add_theme_font_size_override("font_size", 34)

	var cancel_button := gift_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.visible = false

	_configure_dialog_button(gift_dialog.get_ok_button(), true)


func _update_gift_portrait(character_id: String) -> void:
	if gift_portrait_root == null:
		return

	for child in gift_portrait_root.get_children():
		gift_portrait_root.remove_child(child)
		child.queue_free()

	var scene_path := GIFT_CHARACTER_SCENE_TEMPLATE % character_id.to_lower()
	var character_scene := load(scene_path) as PackedScene
	if character_scene == null:
		return

	var unit := character_scene.instantiate()
	gift_portrait_root.add_child(unit)
	if unit is Node2D:
		unit.position = GIFT_PORTRAIT_UNIT_POSITION
		unit.scale = GIFT_PORTRAIT_UNIT_SCALE
		_hide_portrait_helpers(unit)
		_play_portrait_idle_animation(unit)


func _hide_portrait_helpers(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.visible = false
		if child.name == "HealthBar":
			child.visible = false
		_hide_portrait_helpers(child)


func _play_portrait_idle_animation(node: Node) -> void:
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


func _localize_menu_text() -> void:
	var title := get_node_or_null("Center/MenuPanel/Margin/Stack/Title") as Label
	if title != null:
		title.text = UI_TEXT["title"]
	var subtitle := get_node_or_null("Center/MenuPanel/Margin/Stack/Subtitle") as Label
	if subtitle != null:
		subtitle.text = UI_TEXT["subtitle"]

	start_button.text = UI_TEXT["start"]
	continue_button.text = UI_TEXT["continue"]
	archive_button.text = UI_TEXT["archive"]
	reset_progress_button.text = UI_TEXT["reset"]
	quit_button.text = UI_TEXT["quit"]
	reset_confirm_dialog.title = UI_TEXT["reset_title"]
	reset_confirm_dialog.ok_button_text = UI_TEXT["reset_ok"]
	reset_confirm_dialog.dialog_text = UI_TEXT["reset_body"]
	reset_confirm_dialog.cancel_button_text = UI_TEXT["cancel"]


func _connect_once(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _on_start_pressed() -> void:
	var error := get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
	if error != OK:
		push_error("Cannot open level select scene: %s" % LEVEL_SELECT_SCENE)


func _on_continue_pressed() -> void:
	var last_entered_path := ARCHIVE_STATE.get_last_entered_stage_path()
	var target_stage := STAGE_CATALOG.get_stage_by_scene_path(last_entered_path)
	if target_stage.is_empty() or not STAGE_CATALOG.is_stage_playable(target_stage):
		target_stage = STAGE_CATALOG.get_stage_by_global_number(ARCHIVE_STATE.get_highest_unlocked_stage())
	if target_stage.is_empty() or not STAGE_CATALOG.is_stage_playable(target_stage):
		_on_start_pressed()
		return

	ARCHIVE_STATE.set_target_stage_path(str(target_stage["scene_path"]))
	var error := get_tree().change_scene_to_file(FORMATION_SCENE)
	if error != OK:
		push_error("Cannot open formation scene: %s" % FORMATION_SCENE)


func _on_archive_pressed() -> void:
	var error := get_tree().change_scene_to_file(ARCHIVE_SCENE)
	if error != OK:
		push_error("Cannot open archive scene: %s" % ARCHIVE_SCENE)


func _input(event: InputEvent) -> void:
	if _is_back_input_event(event):
		get_viewport().set_input_as_handled()
		_close_reset_dialogs()


func _on_reset_progress_pressed() -> void:
	reset_confirm_dialog.popup_centered(RESET_CONFIRM_SIZE)


func _on_reset_confirmed() -> void:
	ARCHIVE_STATE.reset_progress()
	reset_confirm_dialog.hide()
	start_button.grab_focus()
	_show_starter_gift()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_reset_dialogs() -> void:
	if reset_confirm_dialog.visible:
		reset_confirm_dialog.hide()


func _configure_dialogs() -> void:
	_configure_dialog(reset_confirm_dialog)


func _configure_dialog(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return

	dialog.min_size = RESET_CONFIRM_SIZE
	dialog.add_theme_stylebox_override("embedded_border", _make_dialog_panel_style())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", _make_dialog_panel_style())
	dialog.add_theme_font_size_override("title_font_size", 28)
	dialog.add_theme_color_override("title_color", DIALOG_TITLE_COLOR)

	var label := dialog.get_label()
	if label != null:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", DIALOG_TEXT_COLOR)
		label.add_theme_font_size_override("font_size", 24)

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


func _is_back_input_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	return event.is_action_pressed("ui_back")
