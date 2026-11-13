@tool
class_name DialogueBar
extends Control

## The line now on screen. Story scenes use the art tag to mark who is talking.
signal line_shown(line: DialogueLine)
signal finished

const PORTRAITS := {
	"Comet": preload("res://art/characters/player/white/white.pilot.png"),
	"Raven": preload("res://art/characters/player/purple/purple.pilot.png"),
	"Comms": preload("res://art/characters/npc/comms.png"),
}

@onready var dialogue: Control = %Dialogue
@onready var portrait_well: Control = %PortraitWell
@onready var portrait: TextureRect = %Portrait
@onready var speaker_label: Label = %Speaker
@onready var body: DialogueLabel = %Body
@onready var prompt: Label = %Prompt
@onready var responses_menu: DialogueResponsesMenu = %Responses

var _resource: DialogueResource
var _extra_states: Array = []
var _line: DialogueLine
var _response: DialogueResponse
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
	responses_menu.hide()
	responses_menu.response_selected.connect(_on_response_selected)
	if body != null and body.has_signal("typing_held"):
		body.connect("typing_held", _on_typing_held)


## Entry used by DialogueManager.show_dialogue_balloon.
func start(dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	await play(dialogue_resource, cue, extra_game_states)
	if owner == null and is_inside_tree():
		queue_free()


## Shows the bar, waits through the cue, then hides.
func play(dialogue_resource: DialogueResource, cue: String = "", extra_game_states: Array = []) -> void:
	if _playing:
		await finished
		return
	if dialogue_resource == null:
		push_error("Dialogue bar has no dialogue resource.")
		return
	_playing = true
	_leaving = false
	_resource = dialogue_resource
	_extra_states = extra_game_states
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var line: DialogueLine = await dialogue_resource.get_next_dialogue_line(cue, _extra_states)
	if not is_inside_tree() or _leaving:
		return
	_enter()
	while line != null and is_inside_tree() and not _leaving:
		var next_id := await _present(line)
		if not is_inside_tree() or _leaving:
			return
		if next_id == "":
			next_id = DMConstants.ID_END
		line = await _resource.get_next_dialogue_line(next_id, _extra_states)
	if is_inside_tree():
		_finish()


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
	if not _playing or not prompt.visible:
		return
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
	if _leaving or _line == null:
		return
	if _line.responses.size() > 0:
		return
	if body != null and body.is_typing:
		body.skip_typing()
		return
	if _waiting:
		_waiting = false


## Shows one line on the bar. Colors and offsets stay on the nodes.
func preview(speaker: String, text: String, picture: Texture2D = null) -> void:
	_fill_chrome(speaker, picture)
	var body_node := _body()
	if body_node == null:
		return
	body_node.text = text
	body_node.visible_characters = -1


func _present(line: DialogueLine) -> String:
	_line = line
	_response = null
	_waiting = false
	prompt.visible = false
	responses_menu.hide()
	_fill_chrome(line.character, _portrait_for(line))
	line_shown.emit(line)
	if body != null and not line.text.is_empty():
		body.dialogue_line = line
		SoundBank.play_typing()
		body.type_out()
		await body.finished_typing
		SoundBank.stop_typing()
		if not is_inside_tree() or _leaving:
			return ""
	if line.responses.size() > 0:
		responses_menu.responses = line.responses
		responses_menu.show()
		while _response == null and is_inside_tree() and not _leaving:
			await get_tree().process_frame
		responses_menu.hide()
		if _response == null:
			return ""
		return _response.next_id
	if line.time != "":
		var seconds := line.text.length() * 0.02 if line.time == "auto" else line.time.to_float()
		if seconds > 0.0 and is_inside_tree():
			await get_tree().create_timer(seconds).timeout
		return line.next_id
	_waiting = true
	prompt.visible = true
	while _waiting and is_inside_tree() and not _leaving:
		await get_tree().process_frame
	return "" if _line == null else _line.next_id


func _on_response_selected(response: Variant) -> void:
	_response = response as DialogueResponse


func _on_typing_held(held: bool) -> void:
	SoundBank.set_typing_paused(held)


func _fill_chrome(speaker: String, picture: Texture2D) -> void:
	var speaker_node := _speaker()
	var well := _well()
	var portrait_node := _portrait_rect()
	if speaker_node != null:
		speaker_node.visible = speaker != ""
		if speaker_node.text != speaker:
			speaker_node.text = speaker
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


func _portrait_for(line: DialogueLine) -> Texture2D:
	if line == null:
		return null
	var path := line.get_tag_value("portrait")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return portrait_for_name(line.character)


static func portrait_for_name(speaker: String) -> Texture2D:
	return PORTRAITS.get(speaker) as Texture2D


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
	var full := Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()))
	if used == full:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used)
	return atlas


func _speaker() -> Label:
	return speaker_label if is_instance_valid(speaker_label) else get_node_or_null("Dialogue/Speaker") as Label


func _body() -> RichTextLabel:
	return body if is_instance_valid(body) else get_node_or_null("Dialogue/Body") as RichTextLabel


func _well() -> CanvasItem:
	return portrait_well if is_instance_valid(portrait_well) else get_node_or_null("Dialogue/PortraitWell") as CanvasItem


func _portrait_rect() -> TextureRect:
	return portrait if is_instance_valid(portrait) else get_node_or_null("Dialogue/PortraitWell/Portrait") as TextureRect


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	SoundBank.stop_typing()


func _finish() -> void:
	if not Engine.is_editor_hint():
		SoundBank.stop_typing()
	if _leaving:
		return
	_leaving = true
	_playing = false
	_waiting = false
	_line = null
	prompt.visible = false
	responses_menu.hide()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
