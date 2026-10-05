extends Control

const DESIGN := Vector2(1280.0, 720.0)
const MECH_FRAME := 64.0
## Bottom of the drawn mech inside the 64px idle frame.
const MECH_FEET := 63.0
## Full-body pilot art, cut through the lower thigh so knees and below stay hidden.
const PILOT_THIGH := 82.0

@onready var start_button: Button = %StartButton
@onready var start_flash: ColorRect = %Flash
@onready var mech_sprite: AnimatedSprite2D = %Mech
@onready var pilot_sprite: Sprite2D = %Pilot

var _leaving := false


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	_setup_cast()
	resized.connect(_layout_cast)
	_layout_cast()
	call_deferred("_layout_cast")


func _setup_cast() -> void:
	var frames := MechSprites.frames_for("purple")
	if frames != null:
		mech_sprite.sprite_frames = frames
		mech_sprite.play("idle")
	_plant_feet(mech_sprite, MECH_FRAME, MECH_FEET)
	if pilot_sprite.texture != null:
		pilot_sprite.region_enabled = true
		pilot_sprite.region_rect = Rect2(0, 0, pilot_sprite.texture.get_width(), PILOT_THIGH)
	_plant_feet(pilot_sprite, PILOT_THIGH, PILOT_THIGH)


## Puts the sprite origin on the foot line so position is where it stands.
func _plant_feet(sprite: Node2D, frame_height: float, content_bottom: float) -> void:
	sprite.set("centered", true)
	sprite.set("offset", Vector2(0.0, -(content_bottom - frame_height * 0.5)))


func _layout_cast() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var sx := size.x / DESIGN.x
	var sy := size.y / DESIGN.y
	# Further up the roof, behind the pilot. Faces the title.
	mech_sprite.position = Vector2(270.0 * sx, 600.0 * sy)
	mech_sprite.scale = Vector2(5.0, 5.0)
	# Foreground. The frame cuts her off at the thighs.
	pilot_sprite.position = Vector2(390.0 * sx, size.y)
	pilot_sprite.scale = Vector2(6.0, 6.0)


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	start_button.disabled = true
	await _flash_start_button()
	GameManager.start_mission()


func _flash_start_button() -> void:
	start_flash.visible = true
	start_flash.color = Color(1, 1, 1, 0)
	var tween := create_tween()
	for _pulse in 2:
		tween.tween_property(start_flash, "color:a", 0.9, 0.08)
		tween.tween_property(start_flash, "color:a", 0.0, 0.12)
	await tween.finished
	start_flash.visible = false
