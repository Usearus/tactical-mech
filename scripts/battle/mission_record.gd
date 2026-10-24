class_name MissionRecord
extends Control

const ROW_SCENE := preload("res://scenes/ui/mission_record_row.tscn")

signal confirmed

@onready var _rows: VBoxContainer = %Rows
@onready var _back_button: Button = %BackButton

var _left := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_back_button.pressed.connect(_on_back)


func present(units: Array) -> void:
	_left = false
	_back_button.disabled = false
	_fill(units)
	visible = true


func _fill(units: Array) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	var lines: Array[Dictionary] = []
	for unit in units:
		if unit is not MechState or unit.team != "player":
			continue
		var stats := GameManager.tally_for(unit.id)
		lines.append({
			"unit": unit,
			"destroyed": int(stats["destroyed"]),
			"dealt": int(stats["dealt"]),
			"taken": int(stats["taken"]),
		})
	var leaders := MissionTally.column_leaders(lines)
	var mvp := MissionTally.mvp_index(lines)
	var destroyed_leaders: Array = leaders["destroyed"]
	var dealt_leaders: Array = leaders["dealt"]
	var taken_leaders: Array = leaders["taken"]
	for index in lines.size():
		var line: Dictionary = lines[index]
		var row := ROW_SCENE.instantiate() as MissionRecordRow
		_rows.add_child(row)
		row.show_line(
			line["unit"],
			int(line["destroyed"]),
			int(line["dealt"]),
			int(line["taken"]),
			index == mvp,
			destroyed_leaders.has(index),
			dealt_leaders.has(index),
			taken_leaders.has(index)
		)


func _on_back() -> void:
	if _left:
		return
	_left = true
	_back_button.disabled = true
	confirmed.emit()
