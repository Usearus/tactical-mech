class_name MechState
extends RefCounted

var data: MechData
var hp: int = 1
## Card guard for this battle. Spent before barrier, then dropped when the fight ends.
var guard: int = 0
## Barrier this mech deployed with, plus any gained from cards. It is not refilled, so it lasts until attacks wear it down.
var standing_guard: int = 0
## Catches the next hit aimed at an adjacent ally. Cleared after that hit or the battle.
var intercepting: bool = false
## Played cards left before this enemy acts. Starts at turn_count and refills after each action.
var cards_until_turn: int = 0
var alive: bool = true
var overworld_position: Vector2i = Vector2i.ZERO
var has_moved: bool = false
## 1 faces right, matching the source art. -1 faces left.
var facing := 1

## Unique for this spawned unit. Two copies of the same mech resource stay separate.
var instance_id: String = ""

static var _next_serial := 0

var id: String:
	get:
		if instance_id != "":
			return instance_id
		return data.id if data != null else ""

var display_name: String:
	get:
		return data.display_name if data != null else ""

var short_name: String:
	get:
		return data.short_name if data != null else ""

var team: String:
	get:
		return data.team if data != null else ""

var move_range: int:
	get:
		return data.move_range if data != null else 1

var attack_range: int:
	get:
		return data.attack_range if data != null else 1

## Nearest cell this mech can open a fight from. Matches attack_range when the reach is exact.
var attack_range_min: int:
	get:
		var reach := maxi(attack_range, 1)
		if data == null or data.attack_range_min <= 0:
			return reach
		return clampi(data.attack_range_min, 1, reach)

var speed: int:
	get:
		return data.speed if data != null else 1

var turn_count: int:
	get:
		return data.turn_count if data != null else 3

var color: Color:
	get:
		return data.color if data != null else Color.WHITE

var art_id: String:
	get:
		return data.art_id if data != null else ""


func body_scale() -> float:
	if data == null or data.sprite_scale <= 0.0:
		return 1.0
	return data.sprite_scale


## Guard is spent first. Whatever is left comes off the barrier.
func spend_guard(amount: int) -> int:
	var left := maxi(amount, 0)
	var from_guard := mini(maxi(guard, 0), left)
	guard -= from_guard
	left -= from_guard
	var from_barrier := mini(maxi(standing_guard, 0), left)
	standing_guard -= from_barrier
	return from_guard + from_barrier


func add_guard(amount: int) -> void:
	guard += maxi(amount, 0)


func add_barrier(amount: int) -> void:
	standing_guard += maxi(amount, 0)


## Drops card guard. Whatever barrier survived the fight carries on as it stands.
func close_battle_guard() -> void:
	guard = 0
	intercepting = false


## True when this distance is inside the overworld attack reach.
func attacks_at(distance: int) -> bool:
	var reach := maxi(attack_range, 1)
	return distance >= attack_range_min and distance <= reach


## "2" when the reach is exact. "1-2" when nearer cells count too.
func attack_range_text() -> String:
	var reach := maxi(attack_range, 1)
	var near := attack_range_min
	if near == reach:
		return str(reach)
	return "%d-%d" % [near, reach]


func face_toward_x(from_x: float, to_x: float) -> void:
	if to_x < from_x - 0.5:
		facing = -1
	elif to_x > from_x + 0.5:
		facing = 1


static func from_data(mech_data: MechData, position: Vector2i) -> MechState:
	var state := MechState.new()
	state.data = mech_data
	_next_serial += 1
	var catalog := "" if mech_data == null else mech_data.id
	state.instance_id = "%s#%d" % [catalog, _next_serial]
	state.hp = mech_data.max_hp
	state.standing_guard = 0 if mech_data.team == "player" else maxi(mech_data.barrier, 0)
	state.guard = 0
	state.alive = true
	state.overworld_position = position
	state.cards_until_turn = maxi(mech_data.turn_count, 1)
	return state
