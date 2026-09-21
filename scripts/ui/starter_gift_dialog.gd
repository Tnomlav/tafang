extends ConfirmationDialog

## Announces a character that was just granted to the player. The formation
## screen uses it for the starter character on the opening stage.

const DIALOG_SIZE := Vector2i(420, 540)
const PORTRAIT_SIZE := Vector2i(240, 240)
const PORTRAIT_TOP_OFFSET := 32.0
const PORTRAIT_UNIT_POSITION := Vector2(120, 168)
const PORTRAIT_UNIT_SCALE := Vector2(7, 7)
const CHARACTER_SCENE_TEMPLATE := "res://scenes/units/characters/%s.tscn"
const OK_TEXT := "确认"
const GIFT_TEXT := "新获得角色：%s"
const PANEL_COLOR := Color(0.065, 0.072, 0.085, 0.96)
const PANEL_BORDER_COLOR := Color(0.82, 0.69, 0.38, 1.0)
const BUTTON_COLOR := Color(0.13, 0.14, 0.16, 0.96)
const BUTTON_HOVER_COLOR := Color(0.21, 0.19, 0.14, 1.0)
const BUTTON_PRESSED_COLOR := Color(0.28, 0.23, 0.14, 1.0)
const TEXT_COLOR := Color(0.92, 0.89, 0.78, 1.0)
const TITLE_COLOR := Color(0.98, 0.91, 0.64, 1.0)
const BUTTON_MIN_SIZE := Vector2(140, 48)

var portrait_container: SubViewportContainer = null
var portrait_root: Node2D = null


func _init() -> void:
	title = ""
	min_size = DIALOG_SIZE
	ok_button_text = OK_TEXT
	_build_content()


func _ready() -> void:
	_configure_style()


func show_gift(character_id: String) -> void:
	var normalized_id := character_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return

	_update_portrait(normalized_id)
	dialog_text = GIFT_TEXT % normalized_id.to_upper()
	popup_centered(DIALOG_SIZE)


func _build_content() -> void:
	# AcceptDialog stretches direct Control children to the whole dialog, so the
	# portrait lives inside a plain Control that keeps its own anchors.
	var content := Control.new()
	content.name = "GiftContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	portrait_container = SubViewportContainer.new()
	portrait_container.name = "GiftPortraitContainer"
	portrait_container.stretch = false
	portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.custom_minimum_size = Vector2(PORTRAIT_SIZE)
	portrait_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	portrait_container.offset_left = -PORTRAIT_SIZE.x * 0.5
	portrait_container.offset_right = PORTRAIT_SIZE.x * 0.5
	portrait_container.offset_top = PORTRAIT_TOP_OFFSET
	portrait_container.offset_bottom = PORTRAIT_TOP_OFFSET + PORTRAIT_SIZE.y
	content.add_child(portrait_container)

	var portrait_viewport := SubViewport.new()
	portrait_viewport.name = "GiftPortraitViewport"
	portrait_viewport.disable_3d = true
	portrait_viewport.transparent_bg = true
	portrait_viewport.size = PORTRAIT_SIZE
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_container.add_child(portrait_viewport)

	portrait_root = Node2D.new()
	portrait_root.name = "GiftPortraitRoot"
	portrait_viewport.add_child(portrait_root)


func _configure_style() -> void:
	add_theme_stylebox_override("embedded_border", _make_panel_style())
	add_theme_stylebox_override("embedded_unfocused_border", _make_panel_style())
	add_theme_font_size_override("title_font_size", 1)
	add_theme_color_override("title_color", TITLE_COLOR)

	var label := get_label()
	if label != null:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", TITLE_COLOR)
		label.add_theme_font_size_override("font_size", 34)

	var cancel_button := get_cancel_button()
	if cancel_button != null:
		cancel_button.visible = false

	_configure_dialog_button(get_ok_button())


func _configure_dialog_button(button: Button) -> void:
	if button == null:
		return

	button.custom_minimum_size = BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TITLE_COLOR)
	button.add_theme_color_override("font_hover_color", TITLE_COLOR)
	button.add_theme_color_override("font_pressed_color", TITLE_COLOR)
	button.add_theme_stylebox_override("normal", _make_button_style(BUTTON_COLOR, PANEL_BORDER_COLOR))
	button.add_theme_stylebox_override("hover", _make_button_style(BUTTON_HOVER_COLOR, TITLE_COLOR))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUTTON_PRESSED_COLOR, TITLE_COLOR))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_top = 24.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 24.0
	return style


func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
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


func _update_portrait(character_id: String) -> void:
	if portrait_root == null:
		return

	for child in portrait_root.get_children():
		portrait_root.remove_child(child)
		child.queue_free()

	var scene_path := CHARACTER_SCENE_TEMPLATE % character_id
	var character_scene := load(scene_path) as PackedScene
	if character_scene == null:
		return

	var unit := character_scene.instantiate()
	portrait_root.add_child(unit)
	if unit is Node2D:
		unit.position = PORTRAIT_UNIT_POSITION
		unit.scale = PORTRAIT_UNIT_SCALE
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
