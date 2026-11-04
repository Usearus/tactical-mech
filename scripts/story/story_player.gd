@tool
class_name StoryPlayer
extends Control

## Fired after the last line, before the next scene opens.
signal finished

## Dialogue Manager file for this scene. A blank cue starts at the first one.
@export var dialogue: DialogueResource:
	set(value):
		dialogue = value
		if Engine.is_editor_hint() and is_node_ready():
			_preview_dialogue()
@export var start_cue: String = "":
	set(value):
		start_cue = value
		if Engine.is_editor_hint() and is_node_ready():
			_preview_dialogue()
## Opened after the last advance. Blank stays on the last line.
@export_file("*.tscn") var next_scene: String = ""

const LISTENING := Color(0.45, 0.48, 0.55, 1)
const _TAG_PATTERN := "\\[#.*?\\]"

@onready var cast: Control = %Cast
@onready var dialogue_bar: DialogueBar = %DialogueBar

var _leaving := false
## art_id -> cast nodes that brighten and gray together.
var _cast_groups: Dictionary = {}
var _tag_regex: RegEx


func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_dialogue()
		call_deferred("_preview_dialogue")
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dialogue != null and dialogue.resource_path.ends_with("story_bridge.dialogue"):
		SoundBank.loop("rain")
	elif dialogue != null and dialogue.resource_path.ends_with("story_alley.dialogue"):
		SoundBank.loop("wind")
	_bind_cast()
	dialogue_bar.line_shown.connect(_on_line_shown)
	_play()


func _preview_dialogue() -> void:
	if dialogue_bar == null:
		dialogue_bar = get_node_or_null("DialogueBar") as DialogueBar
	if dialogue_bar == null or dialogue == null:
		return
	var spoken := _opening_line(dialogue.resource_path, start_cue)
	dialogue_bar.preview(spoken.speaker, spoken.text, DialogueBar.portrait_for_name(spoken.speaker))


func _opening_line(path: String, cue: String) -> Dictionary:
	var spoken := {"speaker": "", "text": ""}
	if path == "" or not FileAccess.file_exists(path):
		return spoken
	var active := cue.is_empty()
	var passed_cue := false
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("~ "):
			var name := line.substr(2).strip_edges()
			if cue.is_empty():
				if passed_cue:
					break
				active = true
				passed_cue = true
			else:
				if active and passed_cue:
					break
				active = name == cue
				passed_cue = active
			continue
		if not active:
			continue
		if line.begins_with("=>"):
			break
		if line.begins_with("- "):
			continue
		line = _without_tags(line)
		if ": " in line:
			var bits := line.split(": ", true, 1)
			spoken.speaker = bits[0].strip_edges()
			spoken.text = bits[1].strip_edges()
		else:
			spoken.text = line
		return spoken
	return spoken


func _without_tags(line: String) -> String:
	if _tag_regex == null:
		_tag_regex = RegEx.new()
		_tag_regex.compile(_TAG_PATTERN)
	return _tag_regex.sub(line, "", true).strip_edges()


func _play() -> void:
	await dialogue_bar.play(dialogue, start_cue)
	if is_inside_tree():
		_finish()


func _on_line_shown(line: DialogueLine) -> void:
	var art_id := ""
	if line != null:
		art_id = line.get_tag_value("art")
	_mark_speaker(art_id)


## Plays the mechs placed under Cast. Pilots that share an art_id gray with them.
## Position, scale, and flip stay on the node.
func _bind_cast() -> void:
	_cast_groups.clear()
	if cast == null:
		return
	for child in cast.get_children():
		if not child.has_meta("art_id"):
			continue
		var art_id := str(child.get_meta("art_id"))
		if art_id == "":
			continue
		var animated := child as AnimatedSprite2D
		if animated != null:
			var frames := MechSprites.frames_for(art_id)
			if frames != null and frames.has_animation("idle"):
				animated.sprite_frames = frames
				animated.play("idle")
		if not _cast_groups.has(art_id):
			_cast_groups[art_id] = []
		(_cast_groups[art_id] as Array).append(child)


func _mark_speaker(art_id: String) -> void:
	for id in _cast_groups:
		var talking: bool = art_id.is_empty() or str(id) == art_id
		var tint := Color.WHITE if talking else LISTENING
		for node in _cast_groups[id]:
			var item := node as CanvasItem
			if item != null:
				item.modulate = tint


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
