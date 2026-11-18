extends Control

const DESIGN := Vector2(1280.0, 720.0)
const ISO_STAGE := "res://scenes/stage/stage-isometric.tscn"
const MECH_FRAME := 64.0
## Bottom of the drawn mech inside the 64px idle frame.
const MECH_FEET := 63.0
## Feet sit this far above the bottom of the screen, in design pixels.
const PILOT_LIFT := 50.0
## Extra drop applied after she is fitted, in design pixels.
const PILOT_DROP := 150.0
## Clearance kept above her head so the full body can scale to fit.
const PILOT_TOP := 48.0

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var test_button: Button = %TestButton
@onready var mech_sprite: AnimatedSprite2D = %Mech
@onready var pilot_sprite: Sprite2D = %Pilot

var _leaving := false
var _pilot_frame_height := 0.0
var _pilot_feet := 0.0
var _pilot_body := 0.0


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	test_button.pressed.connect(_on_test_pressed)
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
		pilot_sprite.region_enabled = false
		var bounds := _opaque_bounds(pilot_sprite.texture)
		_pilot_frame_height = pilot_sprite.texture.get_height()
		_pilot_feet = bounds.end.y
		_pilot_body = bounds.size.y
	_plant_feet(pilot_sprite, _pilot_frame_height, _pilot_feet)


func _opaque_bounds(texture: Texture2D) -> Rect2:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(0, 0, texture.get_width(), texture.get_height())
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x < 1 or used.size.y < 1:
		return Rect2(0, 0, texture.get_width(), texture.get_height())
	return used


## Largest whole-pixel scale that keeps her body inside the open vertical space.
func _pilot_scale(available_height: float) -> float:
	if _pilot_body < 1.0:
		return 1.0
	return maxf(1.0, floor(available_height / _pilot_body))


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
	# Foreground. Whole body, then shifted down from the fitted spot.
	var lift := PILOT_LIFT * sy
	var scale := _pilot_scale(size.y - lift - PILOT_TOP * sy)
	pilot_sprite.position = Vector2(390.0 * sx, size.y - lift + PILOT_DROP * sy)
	pilot_sprite.scale = Vector2(scale, scale)


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	start_button.disabled = true
	settings_button.disabled = true
	test_button.disabled = true
	GameManager.go_to_hangar()


func _on_test_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	start_button.disabled = true
	settings_button.disabled = true
	test_button.disabled = true
	get_tree().change_scene_to_file(ISO_STAGE)


func _on_settings_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	start_button.disabled = true
	settings_button.disabled = true
	test_button.disabled = true
	GameManager.go_to_settings()
