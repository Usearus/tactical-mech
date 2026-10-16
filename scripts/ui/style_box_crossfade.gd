class_name StyleBoxCrossfade
extends StyleBox

## Draws [member resting], then [member bright] over it.
## [member amount] is the bright frame's opacity, from 0 to 1.
var resting: StyleBoxTexture
var bright: StyleBoxTexture
var _faded: StyleBoxTexture
var amount := 0.0:
	set(value):
		if is_equal_approx(amount, value):
			return
		amount = value
		_apply_amount()
		emit_changed()


func set_pair(rest: StyleBox, peak: StyleBox) -> void:
	resting = rest as StyleBoxTexture
	bright = null
	if peak != null:
		bright = peak.duplicate() as StyleBoxTexture
	_faded = bright
	if resting != null:
		for side in 4:
			set_content_margin(side as Side, resting.get_margin(side as Side))
	_apply_amount()
	emit_changed()


func _apply_amount() -> void:
	if _faded == null:
		return
	var color := _faded.modulate_color
	_faded.modulate_color = Color(color.r, color.g, color.b, amount)


func _get_content_margin(margin: Side) -> float:
	if resting == null:
		return 0.0
	return resting.get_margin(margin)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if resting != null:
		resting.draw(to_canvas_item, rect)
	if _faded == null or amount <= 0.0:
		return
	_faded.draw(to_canvas_item, rect)
