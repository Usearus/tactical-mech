class_name TutorialStage
extends RefCounted

## Rally cells live on the tutorial stage. Scripts read the markers.
const SCENE_PATH := "res://scenes/stage/stage-tutorial.tscn"

const RAVEN_PATH := "res://data/mechs/player/raven.tres"
const COMET_PATH := "res://data/mechs/player/comet.tres"
const BARRAGE_PATH := "res://data/mechs/player/barrage.tres"


static func use() -> void:
	StageMap.use(SCENE_PATH)


static func cell(node_name: String) -> Vector2i:
	use()
	var node := StageMap.root.find_child(node_name, true, false) as Node2D
	if node == null:
		push_error("Tutorial stage is missing %s" % node_name)
		return Vector2i.ZERO
	if node is StageSpawn:
		return (node as StageSpawn).cell()
	return _cell(node)


## The pilot whose turn it is on the map. Fight 1 is Raven. Comet leads into fight 2, Barrage into fight 3.
static func lead_id(fight: int) -> String:
	if fight >= 3:
		return "barrage"
	if fight == 2:
		return "comet"
	return "raven"


## Where that pilot stands, and where a step lands. Fight 2 is already in range.
static func lead_cell(fight: int, stepped: bool) -> Vector2i:
	if fight >= 3:
		return cell("Player3") if stepped else cell("Player3") + Vector2i(0, 1)
	if fight == 2:
		return raven_cell(2, true)
	return raven_cell(1, true)


static func raven_cell(fight: int, stepped: bool) -> Vector2i:
	if fight <= 1:
		return cell("Player1")
	if fight == 2:
		return cell("Rally2" if stepped else "Rally2Start")
	return cell("Rally3" if stepped else "Rally3Start")


static func enemy_names(fight: int) -> PackedStringArray:
	match fight:
		1:
			return PackedStringArray(["Scout"])
		2:
			return PackedStringArray(["Scout2", "Raider", "Gunner"])
		3:
			return PackedStringArray(["Gunner2", "Scout3", "Raider2"])
	return PackedStringArray()


## Pilots and the contacts for this fight, standing on the attack cell.
static func units_for(fight: int) -> Array[MechState]:
	var units: Array[MechState] = []
	units.append(MechState.from_data(_load(RAVEN_PATH), raven_cell(fight, true)))
	if fight >= 2:
		units.append(MechState.from_data(_load(COMET_PATH), cell("Player2")))
	if fight >= 3:
		units.append(MechState.from_data(_load(BARRAGE_PATH), cell("Player3")))
	for node_name in enemy_names(fight):
		var spawn := _spawn(node_name)
		if spawn == null or spawn.mech == null:
			continue
		units.append(MechState.from_data(spawn.mech, spawn.cell()))
	return units


static func _spawn(node_name: String) -> StageSpawn:
	use()
	return StageMap.root.find_child(node_name, true, false) as StageSpawn


static func _load(path: String) -> MechData:
	return load(path) as MechData


static func _cell(marker: Node2D) -> Vector2i:
	var map := StageMap.layer
	if map == null or map.tile_set == null or map.tile_set.tile_size.x <= 0:
		return Vector2i.ZERO
	var tile := map.tile_set.tile_size
	@warning_ignore("integer_division")
	var span := maxi(1, MechSprites.FRAME_SIZE / tile.x)
	var sample := marker.position - Vector2(tile) * float(span - 1) * 0.5
	var tile_cell := map.local_to_map(sample)
	@warning_ignore("integer_division")
	return Vector2i(tile_cell.x / span, tile_cell.y / span)
