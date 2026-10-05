@tool
class_name StoryPlayer
extends Control

## Fired after the last line, before the next scene opens.
signal finished

## Spoken in order. Inherit this scene as story2 and replace the list.
@export var lines: Array[StoryLine] = []:
	set(value):
		lines = value
		if Engine.is_editor_hint() and is_node_ready():
			_preview_dialogue()
			_watch_lines()
## Opened after the last advance. Blank stays on the last line.
@export_file("*.tscn") var next_scene: String = ""

const LISTENING := Color(0.45, 0.48, 0.55, 1)

@onready var cast: Control = %Cast
@onready var dialogue_bar: DialogueBar = %DialogueBar

var _leaving := false
var _cast_sprites: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_dialogue()
		call_deferred("_preview_dialogue")
		_watch_lines()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_cast()
	dialogue_bar.line_shown.connect(_on_line_shown)
	_play()


func _preview_dialogue() -> void:
	if dialogue_bar == null:
		dialogue_bar = get_node_or_null("DialogueBar") as DialogueBar
	if dialogue_bar == null:
		return
	var line: StoryLine = null
	if not lines.is_empty():
		line = lines[0]
	dialogue_bar.preview(line)


func _watch_lines() -> void:
	for line in lines:
		if line == null or line.changed.is_connected(_preview_dialogue):
			continue
		line.changed.connect(_preview_dialogue)


func _play() -> void:
	await dialogue_bar.play(lines)
	if is_inside_tree():
		_finish()


func _on_line_shown(line: StoryLine) -> void:
	_mark_speaker("" if line == null else line.art_id)


## Plays the mechs placed under Cast.
## Position, scale, and flip stay on the node.
func _bind_cast() -> void:
	_cast_sprites.clear()
	if cast == null:
		return
	for child in cast.get_children():
		var sprite := child as AnimatedSprite2D
		if sprite == null or not sprite.has_meta("art_id"):
			continue
		var art_id := str(sprite.get_meta("art_id"))
		if art_id == "":
			continue
		var frames := MechSprites.frames_for(art_id)
		if frames != null and frames.has_animation("idle"):
			sprite.sprite_frames = frames
			sprite.play("idle")
		_cast_sprites[art_id] = sprite


func _mark_speaker(art_id: String) -> void:
	for id in _cast_sprites:
		var sprite: AnimatedSprite2D = _cast_sprites[id]
		var talking: bool = art_id.is_empty() or str(id) == art_id
		sprite.modulate = Color.WHITE if talking else LISTENING


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	if next_scene == "":
		return
	if next_scene.begins_with("res://scenes/story/"):
		GameManager.play_story(next_scene)
	else:
		GameManager.open_scene(next_scene)
