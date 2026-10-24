@tool
extends McpTestSuite

## Collision shapes on a stage close the mech cells they cover.


func suite_name() -> String:
	return "stage_walls"


func test_stage_0_1_collision_shapes_block_open_ground() -> void:
	_assert_shapes_close_open_ground("res://scenes/stage/stage-0-1.tscn")
	for spawn in StageMap.spawns():
		if spawn.slot <= 0:
			continue
		assert_false(StageMap.blocked(spawn.cell()), "player spawn %s stays open" % spawn.name)


func test_stage_0_0_collision_shape_blocks_open_ground() -> void:
	_assert_shapes_close_open_ground("res://scenes/stage/stage-0-0.tscn")


func _assert_shapes_close_open_ground(path: String) -> void:
	StageMap.use(path)
	var shapes := _scene_shapes()
	assert_gt(shapes.size(), 0, "%s has a collision shape" % path)
	var closed := 0
	var rect := StageMap.bounds
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coords := Vector2i(x, y)
			if _tiles_block(coords):
				continue
			var covered := _covered(coords, shapes)
			if covered:
				assert_true(StageMap.blocked(coords), "shape blocks %s on %s" % [coords, path])
				closed += 1
			else:
				assert_false(StageMap.blocked(coords), "open ground stays open at %s on %s" % [coords, path])
	assert_gt(closed, 0, "a collision shape covers open ground on %s" % path)


func _scene_shapes() -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	_collect(StageMap.root, found)
	return found


func _collect(node: Node, found: Array[PackedVector2Array]) -> void:
	if node is CollisionPolygon2D and not (node as CollisionPolygon2D).disabled:
		var points := _to_stage(node as Node2D, (node as CollisionPolygon2D).polygon)
		if points.size() >= 3:
			found.append(points)
	elif node is CollisionShape2D and not (node as CollisionShape2D).disabled:
		var shape_node := node as CollisionShape2D
		var outline := _outline(shape_node.shape)
		if outline.size() >= 3:
			found.append(_to_stage(shape_node, outline))
	for child in node.get_children():
		_collect(child, found)


func _outline(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points
	return PackedVector2Array()


func _to_stage(node: Node2D, points: PackedVector2Array) -> PackedVector2Array:
	var staged := PackedVector2Array()
	for point in points:
		var current: Node = node
		var placed := point
		while current is Node2D and current != StageMap.root:
			placed = (current as Node2D).transform * placed
			current = current.get_parent()
		if staged.is_empty() or staged[staged.size() - 1].distance_squared_to(placed) > 0.01:
			staged.append(placed)
	if staged.size() >= 2 and staged[0].distance_squared_to(staged[staged.size() - 1]) <= 0.01:
		var trimmed := PackedVector2Array()
		for i in staged.size() - 1:
			trimmed.append(staged[i])
		return trimmed
	return staged


func _tiles_block(coords: Vector2i) -> bool:
	var span := StageMap.mech_span()
	var origin := coords * span
	for oy in span:
		for ox in span:
			var data := StageMap.layer.get_cell_tile_data(origin + Vector2i(ox, oy))
			if data == null or data.get_collision_polygons_count(0) > 0:
				return true
	return false


func _covered(coords: Vector2i, shapes: Array[PackedVector2Array]) -> bool:
	var footprint := _full_cell(coords)
	for shape in shapes:
		if _area_overlap(footprint, shape):
			return true
	return false


func _full_cell(coords: Vector2i) -> PackedVector2Array:
	var span := StageMap.mech_span()
	var tile := Vector2(StageMap.layer.tile_set.tile_size)
	var top_left := StageMap.layer.map_to_local(coords * span) - tile * 0.5
	var size := tile * float(span)
	var local := PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0.0),
		top_left + size,
		top_left + Vector2(0.0, size.y),
	])
	return _to_stage(StageMap.layer, local)


func _area_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var parts: Array = Geometry2D.intersect_polygons(_ccw(a), _ccw(b))
	for part in parts:
		if part is PackedVector2Array and absf(_area(part)) > 1.0:
			return true
	return false


func _ccw(points: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	return points


func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
