class_name PitchMark
extends HBoxContainer

## Lightning 1 held over a card for the whole round banner.
## The tree is paused while that banner plays, so the pop keeps running.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func pop_on(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	top_level = true
	z_as_relative = false
	z_index = 20
	update_minimum_size()
	var box := get_combined_minimum_size()
	if box.x < 1.0 or box.y < 1.0:
		box = Vector2(120, 64)
	size = box
	pivot_offset = box * 0.5
	var center := card.get_global_rect().get_center()
	global_position = center - box * 0.5
	scale = Vector2(0.35, 0.35)
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
