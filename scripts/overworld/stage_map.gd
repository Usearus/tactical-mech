class_name StageMap
extends RefCounted

## The overworld stage is a Node2D of TileMapLayers. Ground is the map.
## A tile with a collision polygon is solid. Units cannot enter it.
## Collision polygons and shapes on the stage block the same way. A mech
## cannot stand on a cell whose footprint overlaps one of those shapes.
const DEFAULT_SCENE := "res://scenes/stage/stage-0-0.tscn"
## Above mechs and their barrier. Overworld cells are z 1, sprites add 4, barrier adds 1.
## A stage layer that covers those mechs (In Front Of Characters) is z 8.
## Rain is 9 and the Above layer is 10. Battle shade and HP badges are z 8. HUD starts at 15.
const SHADOW_Z := 7
## Rain, lightning, and later effects live under this child. Battle copies each one.
const WEATHER_NODE := "Weather"

## A shape that only shares a cell edge does not block that cell.
const FOOTPRINT_INSET := 0.5

static var scene_path := DEFAULT_SCENE
static var root: Node2D
static var layer: TileMapLayer
static var bounds := Rect2i()
static var _solid_shapes: Array[PackedVector2Array] = []
static var _shapes_for: Node2D = null


static func use(path: String) -> void:
	if path == "":
		path = DEFAULT_SCENE
	if root != null and scene_path == path and is_instance_valid(root):
		return
	scene_path = path
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	layer = null
	_solid_shapes = []
	_shapes_for = null
	var packed := load(scene_path) as PackedScene
	var node := packed.instantiate()
	root = node as Node2D
	if root == null:
		push_error("Stage scene root must be a Node2D: %s" % scene_path)
		node.queue_free()
		bounds = Rect2i()
		return
	layer = root.get_node_or_null("Ground") as TileMapLayer
	var shadows := root.get_node_or_null("Shadows") as CanvasItem
	if shadows != null:
		shadows.z_index = SHADOW_Z
	if layer == null:
		push_error("Stage scene is missing Ground: %s" % scene_path)
		bounds = Rect2i()
		return
	bounds = mech_bounds(layer.get_used_rect())


## Tile layers in draw order. Ground, then Shadow, then Props.
static func visual_layers() -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if root == null or not is_instance_valid(root):
		return found
	for child in root.get_children():
		if child is TileMapLayer:
			found.append(child)
	return found


static func ensure() -> void:
	if layer != null and is_instance_valid(layer):
		return
	use(scene_path)


static func contains(coords: Vector2i) -> bool:
	ensure()
	return bounds.has_point(coords)


## Tiles under one mech. A 64px mech on a 32px grid covers a 2×2 block.
static func mech_span() -> int:
	ensure()
	if layer == null or layer.tile_set == null or layer.tile_set.tile_size.x <= 0:
		return 1
	@warning_ignore("integer_division")
	return maxi(1, MechSprites.FRAME_SIZE / layer.tile_set.tile_size.x)


## Map bounds in mech cells. A 64px tileset is unchanged.
static func mech_bounds(used: Rect2i) -> Rect2i:
	var span := 1
	if layer != null and layer.tile_set != null and layer.tile_set.tile_size.x > 0:
		@warning_ignore("integer_division")
		span = maxi(1, MechSprites.FRAME_SIZE / layer.tile_set.tile_size.x)
	if span <= 1:
		return used
	var end := used.position + used.size
	@warning_ignore("integer_division")
	var origin := Vector2i(used.position.x / span, used.position.y / span)
	var limit := Vector2i(ceili(float(end.x) / float(span)), ceili(float(end.y) / float(span)))
	return Rect2i(origin, limit - origin)


static func blocked(coords: Vector2i) -> bool:
	ensure()
	if not bounds.has_point(coords):
		return true
	if _tiles_block(coords):
		return true
	return _footprint_hits_shape(coords)


static func _tiles_block(coords: Vector2i) -> bool:
	var span := mech_span()
	var origin := coords * span
	for oy in span:
		for ox in span:
			var data := layer.get_cell_tile_data(origin + Vector2i(ox, oy))
			if data == null or data.get_collision_polygons_count(0) > 0:
				return true
	return false


static func _footprint_hits_shape(coords: Vector2i) -> bool:
	var shapes := _shapes()
	if shapes.is_empty() or layer == null or layer.tile_set == null:
		return false
	var footprint := _cell_polygon(coords)
	for shape in shapes:
		if _polygons_overlap(footprint, shape):
			return true
	return false


static func _shapes() -> Array[PackedVector2Array]:
	if _shapes_for == root and root != null and is_instance_valid(root):
		return _solid_shapes
	_solid_shapes = _collision_polygons()
	_shapes_for = root
	return _solid_shapes


static func _collision_polygons() -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	if root == null:
		return found
	_collect_collision(root, found)
	return found


static func _collect_collision(node: Node, found: Array[PackedVector2Array]) -> void:
	if node is CollisionPolygon2D:
		var poly := node as CollisionPolygon2D
		if not poly.disabled:
			var points := _clean(_to_stage(poly, poly.polygon))
			if points.size() >= 3:
				found.append(points)
	elif node is CollisionShape2D:
		var shape_node := node as CollisionShape2D
		if not shape_node.disabled and shape_node.shape != null:
			var points := _clean(_to_stage(shape_node, _shape_outline(shape_node.shape)))
			if points.size() >= 3:
				found.append(points)
	for child in node.get_children():
		_collect_collision(child, found)


static func _shape_outline(shape: Shape2D) -> PackedVector2Array:
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


## Points in the stage root's space. The stage is not in the tree when the map loads.
static func _to_stage(node: Node2D, points: PackedVector2Array) -> PackedVector2Array:
	var staged := PackedVector2Array()
	staged.resize(points.size())
	for i in points.size():
		var point := points[i]
		var current: Node = node
		while current is Node2D and current != root:
			point = (current as Node2D).transform * point
			current = current.get_parent()
		staged[i] = point
	return staged


static func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	for point in points:
		if not cleaned.is_empty() and cleaned[cleaned.size() - 1].distance_squared_to(point) <= 0.01:
			continue
		cleaned.append(point)
	if cleaned.size() < 2 or cleaned[0].distance_squared_to(cleaned[cleaned.size() - 1]) > 0.01:
		return cleaned
	var trimmed := PackedVector2Array()
	for i in cleaned.size() - 1:
		trimmed.append(cleaned[i])
	return trimmed


static func _cell_polygon(coords: Vector2i) -> PackedVector2Array:
	var span := mech_span()
	var tile := Vector2(layer.tile_set.tile_size)
	var top_left := layer.map_to_local(coords * span) - tile * 0.5
	var size := tile * float(span) - Vector2(FOOTPRINT_INSET, FOOTPRINT_INSET) * 2.0
	top_left += Vector2(FOOTPRINT_INSET, FOOTPRINT_INSET)
	return _to_stage(layer, PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0.0),
		top_left + size,
		top_left + Vector2(0.0, size.y),
	]))


static func _polygons_overlap(footprint: PackedVector2Array, shape: PackedVector2Array) -> bool:
	if footprint.size() < 3 or shape.size() < 3:
		return false
	for corner in footprint:
		if Geometry2D.is_point_in_polygon(corner, shape):
			return true
	for corner in shape:
		if Geometry2D.is_point_in_polygon(corner, footprint):
			return true
	var footprint_count := footprint.size()
	var shape_count := shape.size()
	for i in footprint_count:
		var a := footprint[i]
		var b := footprint[(i + 1) % footprint_count]
		for j in shape_count:
			var c := shape[j]
			var d := shape[(j + 1) % shape_count]
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
			if hit is Vector2:
				return true
	return false


static func spawns() -> Array[StageSpawn]:
	ensure()
	var found: Array[StageSpawn] = []
	for child in layer.get_children():
		if child is StageSpawn:
			found.append(child)
	return found


static func nearest_open(desired: Vector2i, taken: Dictionary) -> Vector2i:
	ensure()
	var best := Vector2i(-1, -1)
	var best_score := 999999
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var coords := Vector2i(x, y)
			if taken.has(coords) or blocked(coords):
				continue
			var score := absi(coords.x - desired.x) + absi(coords.y - desired.y)
			if score < best_score:
				best_score = score
				best = coords
	return best
