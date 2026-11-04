@tool
class_name BonusPanel
extends PanelContainer

const ROW_SCENE := preload("res://scenes/ui/bonus_panel_row.tscn")

@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh()


## Tactic first, then the mission bonuses in the order they were picked.
func refresh() -> void:
	var tactic := _current_tactic()
	var bonuses: Array[Dictionary] = []
	var memory := GameManager.mission_upgrades
	if memory != null:
		for offer in memory.active_edicts():
			if offer == null or offer.display_name == "":
				continue
			bonuses.append({"name": offer.display_name, "tip": offer.blurb})
	var title := ""
	var tip := ""
	if tactic != null and tactic.shows_on_panel():
		title = tactic.line_name()
		tip = tactic.note
	show_entries(title, tip, bonuses)


func show_entries(tactic_name: String, tactic_tip: String, bonuses: Array[Dictionary]) -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	if tactic_name != "":
		_add_line(tactic_name, tactic_tip)
	for bonus in bonuses:
		_add_line(str(bonus.get("name", "")), str(bonus.get("tip", "")))


func _current_tactic() -> BattleTactic:
	var encounter := GameManager.current_encounter
	if encounter != null and not encounter.grants_tactic_bonus():
		return null
	if encounter != null and encounter.tactic != null:
		return encounter.tactic
	return BattleTactic.standard()


func _add_line(title: String, tip: String) -> void:
	var row := ROW_SCENE.instantiate() as BonusPanelRow
	if row == null:
		return
	_rows.add_child(row)
	row.show_line(title, tip)
