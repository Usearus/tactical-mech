class_name StartingRoster
extends RefCounted

const PLAYER_MECHS: Array[String] = [
	"res://data/mechs/player/raven.tres",
	"res://data/mechs/player/bulldog.tres",
	"res://data/mechs/player/lancer.tres",
	"res://data/mechs/player/barrage.tres",
	"res://data/mechs/player/comet.tres",
]


static func player_roster() -> Array[MechData]:
	var mechs: Array[MechData] = []
	for path in PLAYER_MECHS:
		var data := load(path) as MechData
		if data != null:
			mechs.append(data)
	return mechs


static func create_enemies() -> Array[MechState]:
	var enemies: Array[MechState] = []
	for spawn in _spawns():
		if spawn.mech == null or spawn.mech.team == "player":
			continue
		enemies.append(MechState.from_data(spawn.mech, spawn.cell()))
	return enemies


## How many mechs this stage expects. Each numbered player spawn is one seat.
static func squad_size() -> int:
	return player_slots().size()


## Chosen mechs fill the stage's player slots in pick order.
static func deploy_players(chosen: Array[MechData]) -> Array[MechState]:
	var slots := player_slots()
	var players: Array[MechState] = []
	var count := mini(chosen.size(), slots.size())
	for index in count:
		var data := chosen[index]
		if data == null:
			continue
		players.append(MechState.from_data(data, slots[index].cell()))
	return players


static func create_units() -> Dictionary:
	return {
		"players": deploy_players(player_roster()),
		"enemies": create_enemies(),
	}


static func player_slots() -> Array[StageSpawn]:
	var slots: Array[StageSpawn] = []
	for spawn in _spawns():
		if spawn.slot > 0:
			slots.append(spawn)
	slots.sort_custom(func(a: StageSpawn, b: StageSpawn) -> bool:
		return a.slot < b.slot
	)
	return slots


static func _spawns() -> Array[StageSpawn]:
	StageMap.use(GameManager.stage_scene)
	return StageMap.spawns()
