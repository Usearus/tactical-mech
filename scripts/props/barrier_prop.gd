class_name BarrierProp
extends AnimatedSprite2D

## Full-height contact-lens barrier. Instance this scene and call attach_to()
## with a mech sprite. The lens is drawn on the leading edge of the frame,
## so it stays in front when the mech turns.

var _host: AnimatedSprite2D
var _shown := true


func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	var frames := MechSprites.barrier_frames()
	if frames == null:
		return
	sprite_frames = frames
	play("idle")


## Parent the lens to a mech sprite and keep it on that mech's leading edge.
func attach_to(mech: AnimatedSprite2D) -> void:
	_host = mech
	if mech == null:
		return
	if get_parent() != mech:
		mech.add_child(self)
	position = Vector2.ZERO
	scale = Vector2.ONE
	_match_host()


## Hide the lens without removing it, so a mech can lose barrier and gain it back.
func set_shown(on: bool) -> void:
	_shown = on
	_match_host()


func _process(_delta: float) -> void:
	_match_host()


func _match_host() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	flip_h = _host.flip_h
	visible = _shown and _host.visible
