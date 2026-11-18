class_name SquadMemberTab
extends Button

## Six times the pilot sprite, so the tab shows the eyes and a little skin around them.
const ZOOM := 6.0
## Eye point on the pilot sheet, in source pixels. The tab centers this point.
const EYES := {
	"blue": Vector2(39.2, 28.4),
	"orange": Vector2(34.0, 27.0),
	"purple": Vector2(37.8, 30.2),
	"red": Vector2(39.8, 28.5),
	"tan": Vector2(33.7, 26.7),
	"white": Vector2(41.6, 30.1),
}

@onready var _face: Control = %Face
@onready var _portrait: AnimatedSprite2D = %Portrait

var _art_id := ""


func _ready() -> void:
	text = ""
	pressed.connect(func() -> void:
		SoundBank.play("ui")
	)
	toggled.connect(_paint)
	if _face != null and not _face.resized.is_connected(_place_face):
		_face.resized.connect(_place_face)
	_paint(button_pressed)
	_place_face()


func show_pilot(art_id: String) -> void:
	_art_id = art_id
	text = ""
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


func _paint(on: bool) -> void:
	if _portrait == null:
		return
	_portrait.modulate = Color.WHITE if on else Color(0.94, 0.94, 0.94)


func _place_face() -> void:
	if _portrait == null or _face == null or _face.size.x < 4.0 or _face.size.y < 4.0:
		return
	if _portrait.sprite_frames == null or not _portrait.sprite_frames.has_animation("idle"):
		return
	var tex := _portrait.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var frame := tex.get_size()
	var eye := _eye_point(tex)
	_portrait.scale = Vector2(ZOOM, ZOOM)
	_portrait.position = _face.size * 0.5 - (eye - frame * 0.5) * ZOOM


func _eye_point(tex: Texture2D) -> Vector2:
	if EYES.has(_art_id):
		return EYES[_art_id]
	var content := MechSprites.content_rect(tex)
	return Vector2(
		content.position.x + content.size.x * 0.5,
		content.position.y + content.size.y * 0.42
	)
