class_name PlaceMechChip
extends Panel

signal returned(unit_id: String)
signal drag_started(unit_id: String)

const DragTileScript := preload("res://scripts/ui/drag_tile.gd")

var _unit: MechState
var _art := ""
var _dragging := false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	resized.connect(_fit_sprite)
	_fit_sprite()


func _body() -> AnimatedSprite2D:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	return _sprite


func show_unit(unit: MechState) -> void:
	_unit = unit
	if unit == null:
		clear_unit()
		return
	var body := _body()
	if body == null:
		return
	var art := unit.art_id
	if _art != art or body.sprite_frames == null:
		_art = art
		var frames := MechSprites.frames_for(art)
		if frames != null and frames.has_animation("idle"):
			body.sprite_frames = frames
			body.play("idle")
			body.flip_h = false
	if size.x < 1.0:
		size = custom_minimum_size
	body.visible = not _dragging
	_fit_sprite()


func clear_unit() -> void:
	_unit = null
	_dragging = false
	var body := _body()
	if body != null:
		body.visible = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _unit == null:
		return null
	_dragging = true
	var body := _body()
	if body != null:
		body.visible = false
	var preview := duplicate(DUPLICATE_SCRIPTS | DUPLICATE_USE_INSTANTIATION) as PlaceMechChip
	preview._sprite = null
	preview._dragging = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.show_unit(_unit)
	set_drag_preview(center_drag_tile(preview))
	drag_started.emit(_unit.id)
	return _unit.id


## Godot pins a drag preview's top-left to the cursor. A plain parent keeps this tile's center on the pointer.
static func center_drag_tile(tile: Control) -> Control:
	return DragTileScript.center_on_cursor(tile)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is String and str(data) != ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	returned.emit(str(data))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragging = false
		var body := _body()
		if body != null:
			body.visible = _unit != null


func _fit_sprite() -> void:
	var body := _body()
	if body == null or body.sprite_frames == null or size.x < 1.0:
		return
	if not body.sprite_frames.has_animation("idle"):
		return
	var tex := body.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var frame := tex.get_size()
	var longest := maxf(frame.x, frame.y)
	if longest <= 0.0:
		return
	var fit := minf(size.x, size.y) * 0.86 / longest
	var lift := frame.y * fit * 0.08
	body.position = Vector2(size.x * 0.5, size.y * 0.62 - lift)
	body.scale = Vector2(fit, fit)
