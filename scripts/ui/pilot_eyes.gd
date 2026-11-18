class_name PilotEyes
extends Control

## Same eye crop as the squad tabs, sized to this slot.
const ZOOM := 5.0
const EYES := {
	"blue": Vector2(39.2, 28.4),
	"orange": Vector2(34.0, 27.0),
	"purple": Vector2(37.8, 30.2),
	"red": Vector2(39.8, 28.5),
	"tan": Vector2(33.7, 26.7),
	"white": Vector2(41.6, 30.1),
}
const DIM := Color(0.48, 0.52, 0.6)

@onready var _portrait: AnimatedSprite2D = %Portrait

var _art_id := ""


func _ready() -> void:
	if not resized.is_connected(_place_face):
		resized.connect(_place_face)
	set_lit(false)


func show_pilot(art_id: String) -> void:
	_art_id = art_id
	var frames := MechSprites.pilot_frames(art_id)
	if _portrait == null:
		return
	if frames == null or not frames.has_animation("idle"):
		_portrait.visible = false
		return
	_portrait.visible = true
	if _portrait.sprite_frames != frames:
		_portrait.sprite_frames = frames
	_portrait.animation = "idle"
	_portrait.pause()
	_portrait.frame = 0
	_portrait.flip_h = false
	_place_face()


func set_lit(on: bool) -> void:
	if _portrait == null:
		return
	_portrait.modulate = Color.WHITE if on else DIM


func _place_face() -> void:
	if _portrait == null or size.x < 4.0 or size.y < 4.0:
		return
	if _portrait.sprite_frames == null or not _portrait.sprite_frames.has_animation("idle"):
		return
	var tex := _portrait.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var frame := tex.get_size()
	var eye := _eye_point(tex)
	_portrait.scale = Vector2(ZOOM, ZOOM)
	_portrait.position = size * 0.5 - (eye - frame * 0.5) * ZOOM


func _eye_point(tex: Texture2D) -> Vector2:
	if EYES.has(_art_id):
		return EYES[_art_id]
	var content := MechSprites.content_rect(tex)
	return Vector2(
		content.position.x + content.size.x * 0.5,
		content.position.y + content.size.y * 0.42
	)
