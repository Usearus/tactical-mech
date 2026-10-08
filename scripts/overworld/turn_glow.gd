extends AnimatedSprite2D

## Additive copy of the mech sprite. Stays in step with the sprite it sits on.


func _ready() -> void:
	set_process(false)
	visible = false


func _process(_delta: float) -> void:
	var host := get_parent() as AnimatedSprite2D
	if host == null or not host.visible or host.sprite_frames == null or modulate.a <= 0.001:
		visible = false
		return
	if sprite_frames != host.sprite_frames:
		sprite_frames = host.sprite_frames
	if animation != host.animation:
		animation = host.animation
	frame = host.frame
	frame_progress = host.frame_progress
	flip_h = host.flip_h
	flip_v = host.flip_v
	visible = true
