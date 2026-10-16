class_name StageMap
extends RefCounted

## The overworld stage is a Node2D of TileMapLayers. Ground is the map.
## A tile with a collision polygon is solid. Units cannot enter it.
const DEFAULT_SCENE := "res://scenes/stage/stage1b.tscn"
## Above mechs and their barrier. Overworld cells are z 1, sprites add 4, barrier adds 1.
## Battle scenery shade and HP badges are z 8. HUD chrome starts at z 15.
const SHADOW_Z := 7
## Rain, lightning, and later effects live under this child. Battle copies each one.
const WEATHER_NODE := "Weather"

static var scene_path := DEFAULT_SCENE
static var root: Node2D
static var layer: TileMapLayer
static var bounds := Rect2i()


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


static func tile_origin(coords: Vector2i) -> Vector2i:
	return coords * mech_span()


## Atlas picture of one painted cell. Empty when the cell has no tile.
static func tile_texture(coords: Vector2i) -> AtlasTexture:
	ensure()
	if layer == null or layer.tile_set == null:
		return null
	var source_id := layer.get_cell_source_id(tile_origin(coords))
	if source_id < 0:
		return null
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return null
	var picture := AtlasTexture.new()
	picture.atlas = atlas.texture
	picture.region = atlas.get_tile_texture_region(layer.get_cell_atlas_coords(tile_origin(coords)))
	return picture


static func tile_flip(coords: Vector2i) -> Vector2i:
	ensure()
	var data := layer.get_cell_tile_data(tile_origin(coords))
	if data == null:
		return Vector2i.ZERO
	return Vector2i(1 if data.flip_h else 0, 1 if data.flip_v else 0)


static func blocked(coords: Vector2i) -> bool:
	ensure()
	if not bounds.has_point(coords):
		return true
	var span := mech_span()
	var origin := coords * span
	for oy in span:
		for ox in span:
			var data := layer.get_cell_tile_data(origin + Vector2i(ox, oy))
			if data == null or data.get_collision_polygons_count(0) > 0:
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
