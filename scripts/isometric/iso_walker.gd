class_name IsoWalker
extends Node2D

const FRAME := 64.0
## Bottom of the drawn mech inside the 64px idle frame.
const FEET := 63.0

@export var art_id := "purple"
@export var face_left := false
@export var cell := Vector2i.ZERO

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	var frames := MechSprites.frames_for(art_id)
	if frames == null:
		return
	_sprite.sprite_frames = frames
	_sprite.play("idle")
	_sprite.centered = true
	_sprite.offset = Vector2(0.0, -(FEET - FRAME * 0.5))
	_sprite.flip_h = face_left


## The drawn mech faces right. Left-up and left-down mirror it.
func face_move(from: Vector2i, to: Vector2i) -> void:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == dy:
		return
	_sprite.flip_h = dx < dy
