extends Control

@onready var _back: BaseButton = %BackButton
@onready var _title: Label = %Title

var _leaving := false


func _ready() -> void:
	_back.pressed.connect(_on_back)
	var member := _member()
	if member != null and member.display_name != "":
		_title.text = "%s progression" % member.display_name


func _member() -> MechData:
	var mech_id := GameManager.progression_mech_id
	if mech_id == "":
		return null
	var source: Array = GameManager.available_mechs
	if source.is_empty():
		source = StartingRoster.player_roster()
	for data in source:
		if data != null and data.id == mech_id:
			return data
	return null


func _on_back() -> void:
	if _leaving:
		return
	_leaving = true
	_back.disabled = true
	GameManager.go_to_progression()
