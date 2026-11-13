class_name TutorialDirector
extends Node

const COACH_SCENE := preload("res://scenes/ui/tutorial_coach.tscn")
const RETRY_LINE := "Same drill."

var _map: Node
var _coach: TutorialCoach
var _steps: Array[Dictionary] = []
var _index := 0
var _shown := false
var _waiting := false
var _retry := false
var _fight_phase := "b1"


func bind(map: Node) -> void:
	_map = map
	_steps = TutorialScript.steps()
	_coach = COACH_SCENE.instantiate() as TutorialCoach
	add_child(_coach)
	_coach.continued.connect(_on_continue)
	TutorialHooks.director = self


func _exit_tree() -> void:
	if TutorialHooks.director == self:
		TutorialHooks.director = null


func begin(phase: String) -> void:
	_retry = false
	_fight_phase = phase
	_index = _first(phase)
	_shown = false
	_waiting = true
	if _coach != null:
		_coach.hide_tip()


func phase_name() -> String:
	if _index < 0 or _index >= _steps.size():
		return ""
	return str(_steps[_index].get("phase", ""))


func fight_index() -> int:
	var phase := phase_name()
	if phase.ends_with("1"):
		return 1
	if phase.ends_with("2"):
		return 2
	return 3


func current_detail() -> String:
	if _index < 0 or _index >= _steps.size():
		return ""
	return str(_steps[_index].get("detail", ""))


## These aim steps name one contact, but any enemy on a red tile is a legal click.
func any_target() -> bool:
	if not _shown or _index < 0 or _index >= _steps.size():
		return false
	return bool(_steps[_index].get("any_target", false))


func on_map() -> bool:
	return phase_name().begins_with("m")


func seat(fight: int) -> void:
	var raven := _pilot("raven")
	var comet := _pilot("comet")
	var barrage := _pilot("barrage")
	_park(raven)
	_park(comet)
	_park(barrage)
	if raven != null:
		raven.alive = true
	if fight <= 1:
		_stand(raven, TutorialStage.lead_cell(1, true), false)
		return
	if fight == 2:
		_stand(comet, TutorialStage.lead_cell(2, true), false)
		_stand(raven, TutorialStage.cell("Player2"), true)
		return
	_stand(comet, TutorialStage.cell("Player2"), true)
	_stand(raven, TutorialStage.raven_cell(3, true), true)


func ally_dest(who: String) -> Vector2i:
	if who == "comet":
		return TutorialStage.cell("Player2")
	return TutorialStage.cell("Player3")


func park_ally(who: String) -> void:
	_park(_pilot(who))


func _park(unit: MechState) -> void:
	if unit == null:
		return
	unit.overworld_position = StartingRoster.UNPLACED
	unit.has_moved = true


func _stand(unit: MechState, coords: Vector2i, moved: bool) -> void:
	if unit == null:
		return
	unit.overworld_position = coords
	unit.has_moved = moved


func allows(action: String, detail: String) -> bool:
	if _retry or not _shown or _index >= _steps.size():
		return false
	var step := _steps[_index]
	if str(step.get("event", "")) != action:
		return false
	return _detail_matches(str(step.get("detail", "")), detail)


func notify(event: String, detail: String = "") -> void:
	if event == "won":
		_skip_to_next_phase()
		return
	if _retry:
		if event == "continue":
			_retry = false
			_show_current()
		return
	if not _shown or _index >= _steps.size():
		return
	var step := _steps[_index]
	if str(step.get("event", "")) != event:
		return
	if not _detail_matches(str(step.get("detail", "")), detail):
		return
	_advance()


func settled() -> void:
	if _retry or not _waiting:
		return
	_show_current()


func retry_fight() -> void:
	_retry = true
	_waiting = false
	_shown = true
	_index = _first(_fight_phase)
	if _coach != null:
		_coach.show_step(RETRY_LINE, null, true, false)


func _on_continue() -> void:
	notify("continue")


func _advance() -> void:
	var previous := _fight_phase
	_index += 1
	_shown = false
	if _coach != null:
		_coach.hide_tip()
	if _index >= _steps.size():
		_waiting = false
		return
	var entered := str(_steps[_index].get("phase", ""))
	if entered.begins_with("b") and previous.begins_with("m"):
		_fight_phase = entered
	if bool(_steps[_index].get("wait", false)):
		_waiting = true
		return
	_show_current()


func _skip_to_next_phase() -> void:
	var next := _phase_after(_fight_phase)
	_shown = false
	_waiting = true
	_retry = false
	if _coach != null:
		_coach.hide_tip()
	if next == "":
		_fight_phase = ""
		_index = _steps.size()
		return
	_fight_phase = next
	_index = _first(next)


func _show_current() -> void:
	if _index < 0 or _index >= _steps.size() or _coach == null:
		return
	_waiting = false
	_shown = true
	var step := _steps[_index]
	_fight_phase = str(step.get("phase", _fight_phase))
	var anchor := str(step.get("anchor", ""))
	var event := str(step.get("event", ""))
	var target: Control = null
	if anchor != "" and _map != null and _map.has_method("tutorial_anchor"):
		target = _map.call("tutorial_anchor", anchor) as Control
	var show_continue := event == "continue"
	var open_view := event == "player_turn" or event == "arrived" or event == "pitch"
	var phase := str(step.get("phase", ""))
	_coach.show_step(
		str(step.get("say", "")),
		target,
		show_continue,
		open_view,
		bool(step.get("span", false)),
		bool(step.get("above", false)),
		bool(step.get("bottom", false)),
		bool(step.get("top", false)),
		phase.begins_with("r")
	)


func _first(phase: String) -> int:
	for index in _steps.size():
		if str(_steps[index].get("phase", "")) == phase:
			return index
	return _steps.size()


func _phase_after(phase: String) -> String:
	var seen := false
	var previous := ""
	for step in _steps:
		var name := str(step.get("phase", ""))
		if seen and name != previous:
			return name
		if name == phase:
			seen = true
			previous = name
		elif seen:
			previous = name
	return ""


func _detail_matches(want: String, got: String) -> bool:
	if want == "":
		return true
	if want == "attack":
		return got == "attack"
	return got == want or got.begins_with(want)


func _pilot(data_id: String) -> MechState:
	for unit in GameManager.player_mechs:
		if unit != null and unit.data != null and unit.data.id == data_id:
			return unit
	return null
