extends Node2D

const TITLE := "res://scenes/command/command.tscn"
const MOVE_RANGE := 3
const STEP_SECONDS := 0.12
const _AWAY := Vector2i(1048576, 1048576)

@onready var _ground: TileMapLayer = $Ground
@onready var _figures: Node2D = $Figures
@onready var _walker: IsoWalker = $Figures/Walker
@onready var _cursor: IsoTile = $Cursor

var _taken: Dictionary = {}
var _hot := _AWAY
var _moving := false


func _ready() -> void:
	TapFeedback.process_mode = Node.PROCESS_MODE_DISABLED
	_cursor.use_as_cursor()
	_cursor.set_span(_visual_tile_size())
	_cursor.visible = false
	if not _on_ground(_walker.cell):
		_walker.cell = _center_cell()
	for child in _figures.get_children():
		var figure := child as IsoWalker
		if figure == null:
			continue
		figure.position = _cell_position(figure, figure.cell)
		if figure != _walker:
			_taken[figure.cell] = true


func _exit_tree() -> void:
	if is_instance_valid(TapFeedback):
		TapFeedback.process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(TITLE)
		return
	if _moving:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_try_step()


func _process(_delta: float) -> void:
	_refresh_hover()


func _try_step() -> void:
	var path := _path_to(_cell_under_mouse())
	if path.is_empty():
		return
	_moving = true
	_refresh_hover()
	var tween := create_tween()
	for cell in path:
		tween.tween_callback(_begin_step.bind(cell))
		tween.tween_property(_walker, "position", _cell_position(_walker, cell), STEP_SECONDS)
	tween.finished.connect(_finish_step, CONNECT_ONE_SHOT)


func _begin_step(cell: Vector2i) -> void:
	_walker.face_move(_walker.cell, cell)
	_walker.cell = cell


func _finish_step() -> void:
	if not is_inside_tree():
		return
	_moving = false
	_refresh_hover()


func _refresh_hover() -> void:
	var next := _AWAY
	if not _moving and not _path_to(_cell_under_mouse()).is_empty():
		next = _cell_under_mouse()
	if next == _hot:
		return
	_hot = next
	_cursor.visible = next != _AWAY
	if next != _AWAY:
		_cursor.position = _cell_position(_cursor, next)


func _cell_under_mouse() -> Vector2i:
	return _ground.local_to_map(_ground.to_local(get_global_mouse_position()))


## Tile size is the coarse art size. The layer scale brings it up to the mech pixel size.
func _visual_tile_size() -> Vector2i:
	var shown := Vector2(_ground.tile_set.tile_size) * _ground.scale
	return Vector2i(roundi(shown.x), roundi(shown.y))


func _cell_position(host: Node2D, cell: Vector2i) -> Vector2:
	return host.get_parent().to_local(_ground.to_global(_ground.map_to_local(cell)))


## Edge steps on the diamond grid. Off the board counts as out of range.
func _on_ground(cell: Vector2i) -> bool:
	return _ground.get_cell_source_id(cell) != -1


func _center_cell() -> Vector2i:
	var cells := _ground.get_used_cells()
	if cells.is_empty():
		return Vector2i.ZERO
	var sum := Vector2i.ZERO
	for cell in cells:
		sum += cell
	var middle := Vector2i(sum.x / cells.size(), sum.y / cells.size())
	var best: Vector2i = cells[0]
	var best_dist := 999999
	for cell in cells:
		var dist := absi(cell.x - middle.x) + absi(cell.y - middle.y)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best


func _steps_to(cell: Vector2i) -> int:
	if not _on_ground(cell):
		return MOVE_RANGE + 1
	return absi(cell.x - _walker.cell.x) + absi(cell.y - _walker.cell.y)


## One neighbor per step. A diagonal bends along the tiles instead of cutting across them.
func _path_to(target: Vector2i) -> Array[Vector2i]:
	var steps := _steps_to(target)
	if steps < 1 or steps > MOVE_RANGE or _taken.has(target):
		return []
	var from := _walker.cell
	if target.x == from.x or target.y == from.y:
		var straight := _line(from, target)
		if _path_clear(straight):
			return straight
		return []
	var across := _bend(from, target, true)
	if _path_clear(across):
		return across
	var down := _bend(from, target, false)
	if _path_clear(down):
		return down
	return []


func _line(from: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var step := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
	var cursor := from
	while cursor != target:
		cursor += step
		path.append(cursor)
	return path


func _bend(from: Vector2i, target: Vector2i, x_first: bool) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cursor := from
	var runs: Array[Vector2i] = [
		Vector2i(target.x, from.y),
		target,
	]
	if not x_first:
		runs[0] = Vector2i(from.x, target.y)
	for stop in runs:
		path.append_array(_line(cursor, stop))
		cursor = stop
	return path


func _path_clear(path: Array[Vector2i]) -> bool:
	for cell in path:
		if _taken.has(cell) or not _on_ground(cell):
			return false
	return true
