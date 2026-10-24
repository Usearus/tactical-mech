class_name PlaceMechs
extends PanelContainer

signal start_pressed
signal auto_pressed
signal unit_returned(unit_id: String)
signal drag_started(unit_id: String)

const CHIP_SCENE := preload("res://scenes/ui/place_mech_chip.tscn")

var _chips: Dictionary = {}

@onready var _mechs: HBoxContainer = $Margin/Column/Strip/Mechs
@onready var _auto: Button = $Margin/Column/Strip/Actions/AutoPlace
@onready var _start: SciFlashingButton = $Margin/Column/Strip/Actions/StartMission


func _ready() -> void:
	_auto.pressed.connect(func() -> void: auto_pressed.emit())
	_start.pressed.connect(func() -> void: start_pressed.emit())
	set_can_start(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and is_node_ready():
		_start.stop_pulse()


func bind_squad(units: Array[MechState]) -> void:
	for child in _mechs.get_children():
		child.free()
	_chips.clear()
	for unit in units:
		if unit == null:
			continue
		var chip := CHIP_SCENE.instantiate() as PlaceMechChip
		_mechs.add_child(chip)
		chip.returned.connect(_on_returned)
		chip.drag_started.connect(_on_drag_started)
		chip.show_unit(unit)
		_chips[unit.id] = chip
	set_can_start(false)


func set_benched(unit: MechState, benched: bool) -> void:
	if unit == null or not _chips.has(unit.id):
		return
	var chip := _chips[unit.id] as PlaceMechChip
	if benched:
		chip.show_unit(unit)
	else:
		chip.clear_unit()


func set_can_start(enabled: bool) -> void:
	_start.disabled = not enabled
	_auto.disabled = enabled
	if enabled and visible:
		_start.start_pulse()
	else:
		_start.stop_pulse()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is String and str(data) != ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	unit_returned.emit(str(data))


func _on_returned(unit_id: String) -> void:
	unit_returned.emit(unit_id)


func _on_drag_started(unit_id: String) -> void:
	drag_started.emit(unit_id)
