class_name BattleResults
extends Control

const PLAYER_ROW_SCENE := preload("res://scenes/battle/results_row_player.tscn")
const ENEMY_ROW_SCENE := preload("res://scenes/battle/results_row_enemy.tscn")
const LOSS := Color(0.92, 0.28, 0.24)
const ENEMY_BORDER := Color(0.82, 0.28, 0.24, 0.7)
const PLAYER_BORDER := Color(0.25, 0.72, 0.95, 0.55)
const GAIN := Color(0.55, 0.85, 0.45)
const GUARD_TINT := Color(0.45, 0.78, 1.0)
const SQUAD := Color(0.25, 0.72, 0.95)
const MUTED := Color(0.78, 0.8, 0.84)
const VICTORY := Color(0.62, 0.9, 0.55)
const BEAT := 0.48

signal confirmed

var _returned := false
var _outcome := "Victory"
var _rows: Array[UnitRow] = []
var _fight_offense := false
var _squad_charge := 0
var _squad_max := 5
var _after: Dictionary = {}
var _squad_fill: StyleBoxFlat

@onready var title: Label = %Title
@onready var player_list: VBoxContainer = %PlayerList
@onready var enemy_list: VBoxContainer = %EnemyList
@onready var squad_host: VBoxContainer = %SquadGaugeHost
@onready var bar_host: VBoxContainer = %OverdriveBarHost
@onready var continue_button: Button = %ContinueButton
var _squad_bar: ProgressBar
var _next_label: Label
var _squad_note: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue)
	_build_gauges()


func present(units: Array, opened: Dictionary, outcome: String) -> void:
	_returned = false
	_outcome = outcome
	_rows.clear()
	_clear_rows(player_list)
	_clear_rows(enemy_list)
	_fight_offense = GameManager.battle_offense
	_squad_charge = GameManager.player_attack_gauge
	_squad_max = GameManager.player_attack_max
	_after = GameManager.preview_battle_return()
	title.text = outcome
	title.add_theme_color_override("font_color", _outcome_color(outcome))
	for unit in units:
		if unit is MechState:
			_add_unit(unit as MechState, opened)
	_show_squad(_squad_charge, _squad_max)
	_show_bank(0)
	_set_note(_squad_note, "", MUTED)
	continue_button.disabled = true
	continue_button.text = "Return"
	visible = true
	_play_fight_counts()


func _on_continue() -> void:
	if _returned or continue_button.disabled:
		return
	_returned = true
	continue_button.disabled = true
	confirmed.emit()


func _play_fight_counts() -> void:
	var lines: Array[StatLine] = []
	for row in _rows:
		if row.hp_stat != null and row.hp_stat.opened != row.hp_stat.closed:
			lines.append(row.hp_stat)
		if row.guard_stat != null and row.guard_stat.closed < row.guard_stat.opened:
			lines.append(row.guard_stat)
	await _animate_stats(lines)
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	await _tween_gauges()
	if is_inside_tree():
		continue_button.disabled = false


## Hold the starting number and its change, count the number to the result, then drop the change.
func _animate_stats(lines: Array[StatLine]) -> void:
	if lines.is_empty() or not is_inside_tree():
		return
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var span := 0
	for line in lines:
		span = maxi(span, absi(line.closed - line.opened))
	var duration := clampf(0.28 + 0.055 * span, 0.4, 0.9)
	var tween := create_tween()
	tween.set_parallel(true)
	for line in lines:
		tween.tween_method(_paint_stat.bind(line), 0.0, 1.0, duration)
	await tween.finished
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.set_parallel(true)
	for line in lines:
		if is_instance_valid(line.delta_label) and line.delta_label.visible:
			fade.tween_property(line.delta_label, "modulate:a", 0.0, 0.22)
	await fade.finished
	if not is_inside_tree():
		return
	for line in lines:
		line.hide_delta()
		line.show_value(line.closed)


func _paint_stat(t: float, line: StatLine) -> void:
	if line == null or not is_instance_valid(line.value_label):
		return
	var value := int(round(lerpf(float(line.opened), float(line.closed), t)))
	line.show_value(value)


func _tween_gauges() -> void:
	var maximum := int(_after["max"])
	var grant := int(_after["grant"])
	var final_charge := int(_after["charge"])
	var final_bank := int(_after["banked"])
	if _fight_offense:
		if _squad_max != maximum:
			_squad_max = maximum
			var clamped := mini(_squad_charge, maximum)
			_show_squad(clamped, maximum)
			_squad_charge = clamped
		if _squad_charge > 0:
			await _tween_squad(_squad_charge, 0, maximum)
			if not is_inside_tree():
				return
			_squad_charge = 0
		if grant > 0:
			_set_note(_squad_note, "+%d added from battle" % grant, SQUAD)
			await _tween_squad(_squad_charge, grant, maximum)
			if not is_inside_tree():
				return
			_squad_charge = grant
			_show_bank(final_bank)
	elif _squad_charge != final_charge or _squad_max != maximum:
		_set_note(_squad_note, "Gauge refit", MUTED)
		await _tween_squad(_squad_charge, final_charge, maximum)
		if not is_inside_tree():
			return
		_squad_charge = final_charge
		_squad_max = maximum
	_show_squad(final_charge, maximum)
	_show_bank(final_bank)


func _tween_squad(from_value: int, to_value: int, maximum: int) -> void:
	if from_value == to_value:
		_show_squad(to_value, maximum)
		return
	var tween := create_tween()
	tween.tween_method(_paint_squad.bind(from_value, to_value, maximum), 0.0, 1.0, BEAT)
	await tween.finished
	_show_squad(to_value, maximum)


func _paint_squad(t: float, from_value: int, to_value: int, maximum: int) -> void:
	var value := int(round(lerpf(float(from_value), float(to_value), t)))
	_show_squad(value, maximum)


func _add_unit(unit: MechState, opened: Dictionary) -> void:
	var prior: Dictionary = opened.get(unit.id, {})
	var hp_open := int(prior.get("hp", unit.hp))
	var standing_open := int(prior.get("standing", unit.standing_guard))
	var enemy := unit.team != "player"
	var shell := unit.standing_guard
	var row := UnitRow.new()
	row.team = unit.team
	row.alive = unit.alive
	row.guard_end = unit.guard
	row.shell = shell
	var panel := (ENEMY_ROW_SCENE if enemy else PLAYER_ROW_SCENE).instantiate() as PanelContainer
	_paint_team_border(panel, enemy)
	var portrait := panel.get_node("%Portrait") as Control
	var name_label := panel.get_node("%Name") as Label
	var note := panel.get_node("%Note") as Label
	var stamp := panel.get_node("%Stamp") as Control
	name_label.text = unit.display_name
	_bind_portrait(portrait, unit)
	row.hp_stat = _bind_stat(panel.get_node("%Hp") as HBoxContainer, "HP", hp_open, unit.hp, false)
	var guard_row := panel.get_node("%Guard") as HBoxContainer
	if standing_open > 0 or shell > 0:
		guard_row.visible = true
		row.guard_stat = _bind_stat(guard_row, "BAR", standing_open, shell, true)
	else:
		guard_row.visible = false
		row.guard_stat = null
	note.visible = false
	row.note = note
	stamp.visible = not unit.alive
	(enemy_list if enemy else player_list).add_child(panel)
	_rows.append(row)


func _bind_portrait(host: Control, unit: MechState) -> void:
	var sprite := host.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		host.visible = false
		return
	var frames := MechSprites.frames_for(unit.art_id)
	if frames == null or not frames.has_animation("idle"):
		host.visible = false
		return
	host.visible = true
	sprite.sprite_frames = frames
	sprite.play("idle")
	sprite.modulate = Color(0.42, 0.42, 0.46) if not unit.alive else Color.WHITE
	if not host.resized.is_connected(_place_sprite):
		host.resized.connect(_place_sprite.bind(host, sprite))
	_place_sprite.call_deferred(host, sprite)


func _place_sprite(host: Control, sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or host.size.x < 1.0:
		return
	if not sprite.sprite_frames.has_animation("idle"):
		return
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var longest := maxf(tex.get_width(), tex.get_height())
	if longest <= 0.0:
		return
	var fit := minf(host.size.x, host.size.y) * 0.92 / longest
	sprite.scale = Vector2(fit, fit)
	sprite.position = host.size * 0.5


func _bind_stat(row: HBoxContainer, prefix: String, opened: int, closed: int, guard_stat: bool) -> StatLine:
	var line := StatLine.new()
	line.prefix = prefix
	line.opened = opened
	line.closed = closed
	line.guard_stat = guard_stat
	line.value_label = row.get_node("Value") as Label
	line.delta_label = row.get_node("Delta") as Label
	if guard_stat and closed > opened:
		line.show_value(closed)
		line.opened = closed
		line.hide_delta()
	else:
		line.show_value(opened)
		line.show_delta(_delta_tint(line))
	return line


func _paint_team_border(panel: PanelContainer, enemy: bool) -> void:
	var box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return
	box = box.duplicate() as StyleBoxFlat
	box.border_color = ENEMY_BORDER if enemy else PLAYER_BORDER
	panel.add_theme_stylebox_override("panel", box)


func _delta_tint(line: StatLine) -> Color:
	if line.closed < line.opened:
		return LOSS
	if line.guard_stat:
		return GUARD_TINT
	return GAIN


func _set_note(label: Label, text: String, color: Color) -> void:
	if label == null:
		return
	label.visible = text != ""
	label.text = text
	label.add_theme_color_override("font_color", color)


func _outcome_color(outcome: String) -> Color:
	if outcome == "Victory":
		return VICTORY
	if outcome == "Defeat":
		return LOSS
	return Color.WHITE


func _build_gauges() -> void:
	_squad_bar = bar_host.get_node_or_null("SquadBar") as ProgressBar
	_next_label = squad_host.get_node_or_null("NextLabel") as Label
	_squad_note = squad_host.get_node_or_null("SquadNote") as Label
	if _next_label != null:
		_next_label.visible = false
	if _squad_note != null:
		_squad_note.visible = false
	if _squad_bar == null:
		return
	_squad_fill = OverdriveGauge.claim_fill(_squad_bar)
	OverdriveGauge.dress(_squad_bar)


func _show_squad(charge: int, maximum: int) -> void:
	if _squad_bar == null:
		return
	_squad_bar.max_value = maxi(maximum, 1)
	_squad_bar.value = charge
	OverdriveGauge.write(_squad_bar, charge, maximum)
	OverdriveGauge.pulse(_squad_bar, _squad_fill, maximum > 0 and charge >= maximum)


func _show_bank(amount: int) -> void:
	if _next_label == null:
		return
	_next_label.visible = amount > 0
	_next_label.text = "NEXT +%d" % amount


func _clear_rows(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


class UnitRow extends RefCounted:
	var team := ""
	var alive := true
	var guard_end := 0
	var shell := 0
	var hp_stat: StatLine
	var guard_stat: StatLine
	var note: Label


class StatLine extends RefCounted:
	var prefix := ""
	var opened := 0
	var closed := 0
	var guard_stat := false
	var value_label: Label
	var delta_label: Label


	func show_value(amount: int) -> void:
		if is_instance_valid(value_label):
			value_label.text = "%s  %d" % [prefix, amount]


	func prepare(from_value: int, to_value: int) -> void:
		opened = from_value
		closed = to_value
		show_value(from_value)


	func show_delta(color: Color) -> void:
		if not is_instance_valid(delta_label):
			return
		var delta := closed - opened
		if delta == 0:
			delta_label.visible = false
			return
		delta_label.visible = true
		delta_label.modulate.a = 1.0
		delta_label.text = "+%d" % delta if delta > 0 else str(delta)
		delta_label.add_theme_color_override("font_color", color)


	func hide_delta() -> void:
		if not is_instance_valid(delta_label):
			return
		delta_label.visible = false
		delta_label.modulate.a = 1.0
