class_name StageMap
extends RefCounted

## The overworld is a TileMapLayer scene. Painted cells are the map.
## A tile with a collision polygon is solid. Units cannot enter it.
const DEFAULT_SCENE := "res://scenes/stage/stage1.tscn"

static var scene_path := DEFAULT_SCENE
static var layer: TileMapLayer
static var bounds := Rect2i()


static func use(path: String) -> void:
	if path == "":
		path = DEFAULT_SCENE
	if layer != null and scene_path == path and is_instance_valid(layer):
		return
	scene_path = path
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	var packed := load(scene_path) as PackedScene
	var node := packed.instantiate()
	layer = node as TileMapLayer
	if layer == null:
		layer = node.find_child("*", true, false) as TileMapLayer
	bounds = layer.get_used_rect()


static func ensure() -> void:
	if layer != null and is_instance_valid(layer):
		return
	use(scene_path)


static func contains(coords: Vector2i) -> bool:
	ensure()
	return bounds.has_point(coords)


## Atlas picture of one painted cell. Empty when the cell has no tile.
static func tile_texture(coords: Vector2i) -> AtlasTexture:
	ensure()
	if layer == null or layer.tile_set == null:
		return null
	var source_id := layer.get_cell_source_id(coords)
	if source_id < 0:
		return null
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return null
	var picture := AtlasTexture.new()
	picture.atlas = atlas.texture
	picture.region = atlas.get_tile_texture_region(layer.get_cell_atlas_coords(coords))
	return picture


static func tile_flip(coords: Vector2i) -> Vector2i:
	ensure()
	var data := layer.get_cell_tile_data(coords)
	if data == null:
		return Vector2i.ZERO
	return Vector2i(1 if data.flip_h else 0, 1 if data.flip_v else 0)


static func blocked(coords: Vector2i) -> bool:
	ensure()
	if not bounds.has_point(coords):
		return true
	var data := layer.get_cell_tile_data(coords)
	if data == null:
		return true
	return data.get_collision_polygons_count(0) > 0


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
