extends SceneTree

## Verifies the art and audio assets the project ships: required files load, every
## referenced resource exists, and unit scenes carry usable sprite frames.

const VerifyScript := preload("res://tmp/verify_common.gd")

const TITLE := "art assets"
const CHARACTER_SCENE_DIR := "res://scenes/units/characters"
const ENEMY_SCENE_DIR := "res://scenes/units/enemies"
const AUDIO_DIR := "res://assets/audio"
const FONT_DIR := "res://assets/fonts"
const TEXTURE_DIR := "res://assets/textures"
const ICON_DIR := "res://assets/icons"
const BRANDING_DIR := "res://assets/branding"
const RESOURCE_SCAN_DIRS := ["res://assets", "res://resources", "res://scenes", "res://scripts"]
const RESOURCE_REFERENCE_PATTERN := "res://[^\"'\\s\\]\\)]+"

const REQUIRED_TEXTURES := [
	"res://assets/icons/icon.png",
	"res://assets/icons/icon.svg",
	"res://assets/branding/logo.svg",
	"res://assets/textures/tiles/瓦片.png",
	"res://assets/textures/tiles/动态瓦片_红蓝标记.png",
	"res://assets/textures/tiles/动态瓦片_红蓝绿标记.png",
	"res://assets/textures/ui/道具ui.png",
	"res://assets/textures/ui/unit_health_bar_back.png",
	"res://assets/textures/ui/unit_health_bar_green.png",
	"res://assets/textures/ui/unit_health_bar_green_fill.png",
	"res://assets/textures/ui/unit_health_bar_red.png",
	"res://assets/textures/ui/unit_health_bar_red_fill.png",
	"res://assets/textures/ui/professions/archer.png",
	"res://assets/textures/ui/professions/knight.png",
	"res://assets/textures/ui/professions/priest.png",
	"res://assets/textures/ui/professions/rogue.png",
	"res://assets/textures/ui/professions/warrior.png",
	"res://assets/textures/ui/professions/wizard.png",
	"res://assets/textures/ui/tools/exit.png",
	"res://assets/textures/ui/tools/pause.png",
	"res://assets/textures/ui/tools/restart.png",
	"res://assets/textures/ui/tools/resume.png",
	"res://assets/textures/ui/tools/shovel.png",
	"res://assets/textures/ui/tools/shovel_target.png",
	"res://assets/textures/effects/爆炸特效.png",
]

const REQUIRED_FONTS := [
	"res://assets/fonts/IPix.ttf",
]

var verify: RefCounted


func _initialize() -> void:
	verify = VerifyScript.new()
	_check_required_assets()
	_check_asset_directories()
	_check_resource_references()
	_check_unit_sprites()
	quit(verify.report(TITLE))


func _check_required_assets() -> void:
	for path in REQUIRED_TEXTURES:
		_check_texture(path)
	for path in REQUIRED_FONTS:
		if not verify.check_resource_path(path, "required font"):
			continue
		var font = load(path)
		verify.check(font is Font, "required font must load as a Font: %s" % path)

	for file in _list_asset_files(AUDIO_DIR):
		_check_audio(file)


func _check_asset_directories() -> void:
	for file in _list_asset_files(TEXTURE_DIR):
		_check_texture(file)
	for directory in [ICON_DIR, BRANDING_DIR]:
		for file in _list_asset_files(directory):
			_check_texture(file)


func _list_asset_files(directory_path: String) -> Array:
	var files: Array = []
	verify.collect_files(directory_path, ".png", files)
	verify.collect_files(directory_path, ".svg", files)
	verify.collect_files(directory_path, ".jpg", files)
	verify.collect_files(directory_path, ".mp3", files)
	verify.collect_files(directory_path, ".wav", files)
	return files


func _check_texture(path: String) -> void:
	if not verify.check_resource_path(path, "texture"):
		return
	var texture = load(path)
	if not verify.check(texture is Texture2D, "texture must load as Texture2D: %s" % path):
		return
	verify.check(texture.get_width() > 0 and texture.get_height() > 0, "texture must have a non-empty size: %s" % path)


func _check_audio(path: String) -> void:
	if not verify.check_resource_path(path, "audio stream"):
		return
	var stream = load(path)
	if not verify.check(stream is AudioStream, "audio asset must load as AudioStream: %s" % path):
		return
	verify.check(stream.get_length() > 0.0, "audio stream must not be empty: %s" % path)


func _check_resource_references() -> void:
	var files: Array = []
	for directory_path in RESOURCE_SCAN_DIRS:
		verify.collect_files(directory_path, ".tscn", files)
		verify.collect_files(directory_path, ".tres", files)
		verify.collect_files(directory_path, ".gd", files)
	files.append("res://project.godot")

	var pattern := RegEx.create_from_string(RESOURCE_REFERENCE_PATTERN)
	var seen := {}
	for file in files:
		var text := FileAccess.get_file_as_string(file)
		if text.is_empty():
			continue
		for result in pattern.search_all(text):
			var reference := result.get_string().rstrip(".,;:")
			if reference.contains("%") or seen.has(reference):
				continue
			seen[reference] = true
			if DirAccess.dir_exists_absolute(reference):
				continue
			verify.check(FileAccess.file_exists(reference), "%s must reference an existing file: %s" % [file, reference])


func _check_unit_sprites() -> void:
	var scenes: Array = []
	verify.collect_files(CHARACTER_SCENE_DIR, ".tscn", scenes)
	verify.collect_files(ENEMY_SCENE_DIR, ".tscn", scenes)
	if not verify.check(not scenes.is_empty(), "unit scenes must exist"):
		return

	for scene_path in scenes:
		var packed := load(scene_path) as PackedScene
		if not verify.check(packed != null, "unit scene must load: %s" % scene_path):
			continue
		var instance := packed.instantiate()
		var sprites: Array = []
		_collect_animated_sprites(instance, sprites)
		var file_name := str(scene_path).get_file()
		if not verify.check(not sprites.is_empty(), "%s must define an animated sprite" % file_name):
			instance.free()
			continue
		for sprite in sprites:
			var frames: SpriteFrames = sprite.sprite_frames
			if not verify.check(frames != null, "%s/%s must define sprite frames" % [file_name, sprite.name]):
				continue
			var animation_names := frames.get_animation_names()
			verify.check(not animation_names.is_empty(), "%s/%s must define at least one animation" % [file_name, sprite.name])
			for animation_name in animation_names:
				var frame_count := frames.get_frame_count(animation_name)
				verify.check(frame_count > 0, "%s/%s animation %s must define frames" % [file_name, sprite.name, animation_name])
				for frame_index in frame_count:
					var texture := frames.get_frame_texture(animation_name, frame_index)
					verify.check(texture != null and texture.get_width() > 0, "%s/%s animation %s frame %d must have a texture" % [file_name, sprite.name, animation_name, frame_index])
		instance.free()


func _collect_animated_sprites(node: Node, out: Array) -> void:
	if node is AnimatedSprite2D:
		out.append(node)
	for child in node.get_children():
		_collect_animated_sprites(child, out)
