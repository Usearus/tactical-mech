class_name BattleCell
extends RefCounted

var coords: Vector2i = Vector2i.ZERO
var terrain_type: String = "normal"
var occupant_id: String = ""
var cover: int = 0
var elevation: int = 0


func is_occupied() -> bool:
	return occupant_id != ""


func is_solid() -> bool:
	return terrain_type == "solid"
