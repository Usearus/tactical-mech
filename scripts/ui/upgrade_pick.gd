class_name UpgradePick
extends Control

signal confirmed(choice: UpgradeChoice)
signal skipped

const OPTION_SCENE := preload("res://scenes/ui/upgrade_option.tscn")

@onready var _options: HBoxContainer = %Options
@onready var _refresh: Button = %RefreshButton
@onready var _skip: Button = %SkipButton
@onready var _skip_amount: Label = %SkipAmount
@onready var _continue: Button = %ContinueButton

var _units: Array = []
var _memory: MissionUpgrades
var _choices: Array = []
var _selected := -1
var _closed := false
## Pull ids already dealt on this offer. A refresh will not show them again.
var _seen: Dictionary = {}


func _ready() -> void:
	if _refresh != null:
		_refresh.pressed.connect(_on_refresh)
	if _skip != null:
		_skip.pressed.connect(_on_skip)
	if _skip_amount != null:
		_skip_amount.text = "+%d" % GameManager.SKIP_CHARGE
	if _continue != null:
		_continue.pressed.connect(_on_continue)
	visible = false


func present(units: Array, memory: MissionUpgrades) -> void:
	_units = units
	_memory = memory
	_closed = false
	_seen = {}
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = true
	visible = true
	_show_row(_deal())


func _show_row(choices: Array) -> void:
	_choices = choices
	_selected = -1
	if _options == null:
		return
	for child in _options.get_children():
		_options.remove_child(child)
		child.free()
	var shown := 0
	for index in choices.size():
		var choice := choices[index] as UpgradeChoice
		if choice == null:
			continue
		var option := OPTION_SCENE.instantiate() as UpgradeOption
		_options.add_child(option)
		option.show_choice(choice)
		option.pressed.connect(_on_option.bind(index))
		option.play_reveal(shown)
		shown += 1
	_sync_buttons()


func _on_option(index: int) -> void:
	if _closed:
		return
	_selected = index
	for child_index in _options.get_child_count():
		var option := _options.get_child(child_index) as UpgradeOption
		if option != null:
			option.set_selected(child_index == index)
	_sync_buttons()


func _sync_buttons() -> void:
	if _continue != null:
		_continue.disabled = _selected < 0 or _closed
	if _refresh != null:
		var left := _refreshes_left()
		_refresh.disabled = left <= 0 or _closed or not _has_unseen()
		_refresh.text = "Refresh (%d)" % left
	if _skip != null:
		_skip.disabled = _closed


func _on_refresh() -> void:
	if _closed or _memory == null or not _has_unseen() or not _memory.spend_refresh():
		return
	_show_row(_deal())


func _deal() -> Array:
	var row := UpgradeRoller.roll(_units, _memory, null, null, _seen)
	for choice in row:
		var item := choice as UpgradeChoice
		if item == null:
			continue
		var pull := UpgradeRoller.pull_id(item)
		if pull != "":
			_seen[pull] = true
	return row


func _has_unseen() -> bool:
	if _memory == null:
		return false
	return UpgradeRoller.has_unseen(UpgradeRoller.legal_choices(_units, _memory), _seen)


func _refreshes_left() -> int:
	if _memory == null:
		return 0
	return _memory.refreshes_left


func _on_skip() -> void:
	if _closed:
		return
	_closed = true
	_sync_buttons()
	skipped.emit()


func _on_continue() -> void:
	if _closed or _selected < 0 or _selected >= _choices.size():
		return
	_closed = true
	_sync_buttons()
	confirmed.emit(_choices[_selected] as UpgradeChoice)
