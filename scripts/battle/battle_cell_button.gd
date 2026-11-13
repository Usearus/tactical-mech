extends Button

## The mech is drawn larger than its tile. During the tutorial aim step, that art belongs to this tile.


func _has_point(point: Vector2) -> bool:
	if Rect2(Vector2.ZERO, size).has_point(point):
		return true
	if not bool(get_meta("tutorial_aim", false)):
		return false
	return _sprite_contains(point)


func _sprite_contains(point: Vector2) -> bool:
	var sprite := get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite == null or not sprite.visible or sprite.sprite_frames == null:
		return false
	var anim_name := String(sprite.animation)
	if anim_name == "" or not sprite.sprite_frames.has_animation(anim_name):
		anim_name = "idle"
	if not sprite.sprite_frames.has_animation(anim_name):
		return false
	var frame := mini(sprite.frame, sprite.sprite_frames.get_frame_count(anim_name) - 1)
	var tex := sprite.sprite_frames.get_frame_texture(anim_name, frame)
	if tex == null:
		return false
	var drawn := tex.get_size() * sprite.scale.abs()
	var center := sprite.position + sprite.offset * sprite.scale
	return Rect2(center - drawn * 0.5, drawn).has_point(point)
