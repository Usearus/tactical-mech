@tool
class_name DialogueBar
extends Control

## The line now on screen. Story scenes use this to mark who is talking.
signal line_shown(line: StoryLine)
signal finished

const REVEAL_CPS := 46.0

@onready var dialogue: Control = %Dialogue
@onready var portrait_well: Control = %PortraitWell
@onready var portrait: TextureRect = %Portrait
@onready var speaker_label: Label = %Speaker
@onready var body: Label = %Body
@onready var prompt: Label = %Prompt

var _lines: Array[StoryLine] = []
var _index := -1
var _line_text := ""
var _shown := 0.0
var _revealing := false
var _waiting := false
var _leaving := false
var _playing := false
var _prompt_time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false


## Top of the bar before it slides in. Story scenes stand mechs on this line.
func rest_top() -> float:
	var bar := dialogue if is_instance_valid(dialogue) else get_node_or_null("Dialogue") as Control
	if bar == null:
		return 0.0
	return bar.offset_top


## Shows the bar, waits through every line, then hides.
func play(lines: Array[StoryLine]) -> void:
	if _playing:
		await finished
		return
	_playing = true
	_leaving = false
	_lines = lines
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_line(0)
	_enter()
	await finished


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


func _gui_input(event: InputEvent) -> void:
	if not _playing:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		accept_event()
		_advance()


func _process(delta: float) -> void:
	if not _playing:
		return
	if _revealing:
		_shown += REVEAL_CPS * delta
		var count := mini(int(_shown), _line_text.length())
		body.visible_characters = count
		if count >= _line_text.length():
			_revealing = false
			_waiting = true
			prompt.visible = true
	if prompt.visible:
		_prompt_time += delta
		prompt.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_prompt_time * 5.0))


func _enter() -> void:
	var rest := dialogue.offset_top
	dialogue.offset_top = rest + 36.0
	dialogue.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialogue, "offset_top", rest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(dialogue, "modulate:a", 1.0, 0.2)


func _advance() -> void:
	if _leaving:
		return
	if _revealing:
		_complete_line()
		return
	if not _waiting:
		return
	if _index + 1 >= _lines.size():
		_finish()
		return
	_show_line(_index + 1)


## Shows one line on the bar. Colors and offsets stay on the nodes.
func preview(line: StoryLine) -> void:
	_fill(line)
	var body_node := _body()
	if body_node != null:
		body_node.visible_characters = -1


func _show_line(index: int) -> void:
	_index = index
	_waiting = false
	prompt.visible = false
	if _lines.is_empty():
		_fill(null)
		_line_text = "Add lines on this scene."
		var body_node := _body()
		if body_node != null:
			body_node.text = _line_text
		_start_reveal()
		return
	var line := _lines[index]
	_fill(line)
	_line_text = "" if line == null else line.text
	line_shown.emit(line)
	_start_reveal()


func _start_reveal() -> void:
	body.text = _line_text
	body.visible_characters = 0
	_shown = 0.0
	if _line_text.is_empty():
		_revealing = false
		_waiting = true
		prompt.visible = true
		return
	_revealing = true


func _complete_line() -> void:
	_revealing = false
	_waiting = true
	body.visible_characters = -1
	prompt.visible = true


func _fill(line: StoryLine) -> void:
	var speaker_node := _speaker()
	var body_node := _body()
	var well := _well()
	var portrait_node := _portrait_rect()
	var speaker := "" if line == null else line.speaker
	var written := "" if line == null else line.text
	var picture: Texture2D = null if line == null else line.portrait
	if speaker_node != null:
		speaker_node.visible = speaker != ""
		if speaker_node.text != speaker:
			speaker_node.text = speaker
	if body_node != null and line != null and body_node.text != written:
		body_node.text = written
	if well != null:
		well.visible = picture != null
	if portrait_node == null:
		return
	var current: Texture2D = portrait_node.texture
	if current is AtlasTexture:
		current = (current as AtlasTexture).atlas
	if current == picture:
		return
	portrait_node.texture = _cropped(picture)


func _cropped(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	var full: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()))
	if used == full:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used)
	return atlas


func _speaker() -> Label:
	return speaker_label if is_instance_valid(speaker_label) else get_node_or_null("Dialogue/Speaker") as Label


func _body() -> Label:
	return body if is_instance_valid(body) else get_node_or_null("Dialogue/Body") as Label


func _well() -> CanvasItem:
	return portrait_well if is_instance_valid(portrait_well) else get_node_or_null("Dialogue/PortraitWell") as CanvasItem


func _portrait_rect() -> TextureRect:
	return portrait if is_instance_valid(portrait) else get_node_or_null("Dialogue/PortraitWell/Portrait") as TextureRect


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	_playing = false
	_waiting = false
	prompt.visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
