extends Node

enum Phase { COMMAND, OVERWORLD, BATTLE, SELECT, STORY, BRIEFING }

const COMMAND_SCENE := "res://scenes/command/command.tscn"
const SELECT_SCENE := "res://scenes/select/mech_select.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/overworld.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const STORY1_SCENE := "res://scenes/story/story1.tscn"
const STORY2_SCENE := "res://scenes/story/story2.tscn"
const BRIEFING_SCENE := "res://scenes/briefing/mission_brief.tscn"
## Side-by-side battle board, in columns then rows. North-south fights use the swapped size.
const BATTLE_SIZE := Vector2i(6, 3)
## stage-{act}-{mission}. Mission 1 is act 0 mission 0. Mission 2 is act 0 mission 1.
const STAGE_0_0 := "res://scenes/stage/stage-0-0.tscn"
const STAGE_0_1 := "res://scenes/stage/stage-0-1.tscn"
## Stage scene for the current mission. Each stage is a Node2D of tile layers.
var stage_scene := STAGE_0_0


func overworld_size() -> Vector2i:
	StageMap.use(stage_scene)
	return StageMap.bounds.size
## Squad Overdrive gauge length. The same for every mission.
const SQUAD_ATTACK_MAX := 12

var phase: Phase = Phase.COMMAND
var available_mechs: Array[MechData] = []
var player_mechs: Array[MechState] = []
var enemy_mechs: Array[MechState] = []
var turn_number: int = 1
var current_encounter: EncounterData
var battle_report: String = ""
## Per player mech for the mission scoreboard. Keys are mech ids.
var mission_tally: Dictionary = {}
var enemy_phase_pending := false
var player_attack_gauge := 0
var player_attack_max := SQUAD_ATTACK_MAX
## Charge waiting for the gauge that remains after Overdrive spends this one.
var player_banked_gauge := 0
const SPARK_CHARGE := 2
const FADE_SECONDS := 0.45
const FADE_SCENE := preload("res://scenes/ui/screen_fade.tscn")
## True once the player activates Overdrive in a battle. That fight spends the gauge.
var battle_offense := false
## Grants and card boosts picked after a fight. Cleared when a mission starts.
var mission_upgrades := MissionUpgrades.new()
var battle_zoom_scale := 2.4
var overworld_cell_size := 48.0
var zoom_focus_cells: Array[Vector2i] = []
var _booted := false
var _fade: ColorRect
var _fade_tween: Tween
var _transitioning := false
var _pending_scene := ""

signal battle_finished
signal transition_finished


func _ready() -> void:
	var layer := FADE_SCENE.instantiate()
	add_child(layer)
	_fade = layer.get_node("Fade") as ColorRect


func boot() -> void:
	if _booted:
		return
	_booted = true
	available_mechs = StartingRoster.player_roster()
	player_mechs = []
	enemy_mechs = StartingRoster.create_enemies()
	clear_mission_tally()
	go_to_command()


func all_mechs() -> Array[MechState]:
	var everyone: Array[MechState] = []
	everyone.append_array(player_mechs)
	everyone.append_array(enemy_mechs)
	return everyone


func go_to_command() -> void:
	phase = Phase.COMMAND
	_change_scene(COMMAND_SCENE)


## Story beat. The scene plays its lines, then opens its own next scene.
func play_story(scene_path: String) -> void:
	open_scene(scene_path)


## Fade into a scene and set the phase when the path is one this game knows.
func open_scene(scene_path: String) -> void:
	if scene_path == COMMAND_SCENE:
		phase = Phase.COMMAND
	elif scene_path == SELECT_SCENE:
		phase = Phase.SELECT
	elif scene_path == OVERWORLD_SCENE:
		phase = Phase.OVERWORLD
	elif scene_path == BATTLE_SCENE:
		phase = Phase.BATTLE
	elif scene_path.begins_with("res://scenes/story/"):
		phase = Phase.STORY
	elif scene_path == BRIEFING_SCENE:
		phase = Phase.BRIEFING
	_change_scene(scene_path)


func quit_stage() -> void:
	player_mechs = []
	enemy_mechs = StartingRoster.create_enemies()
	turn_number = 1
	current_encounter = null
	battle_report = ""
	enemy_phase_pending = false
	player_attack_max = SQUAD_ATTACK_MAX
	battle_offense = false
	reset_attack_gauges()
	zoom_focus_cells.clear()
	clear_mission_tally()
	clear_mission_upgrades()
	go_to_command()


func start_mission() -> void:
	open_scene(BRIEFING_SCENE)


## Mission 1 opens on the alley. Mission 2 opens on the bridge.
func story_for_stage(path: String) -> String:
	if path == STAGE_0_1:
		return STORY2_SCENE
	return STORY1_SCENE


## The briefing picks this before the story. Later screens read stage_scene.
## Each stage brings its own enemy spawns.
func choose_stage(path: String) -> void:
	stage_scene = path
	StageMap.use(path)
	enemy_mechs = StartingRoster.create_enemies()


## Mechs this stage's player seats require. Stage 1 has three.
func squad_size() -> int:
	return StartingRoster.squad_size()


func deploy(chosen: Array[MechData]) -> void:
	var required := squad_size()
	if required <= 0 or chosen.size() != required:
		return
	player_mechs = StartingRoster.deploy_players(chosen)
	phase = Phase.OVERWORLD
	clear_mission_tally()
	clear_mission_upgrades()
	reset_attack_gauges()
	player_attack_max = SQUAD_ATTACK_MAX
	_change_scene(OVERWORLD_SCENE)


## Every fight opens standard. Overdrive is a choice the player makes inside the battle.
func begin_encounter(encounter: EncounterData) -> void:
	current_encounter = encounter
	phase = Phase.BATTLE
	battle_offense = false
	var attacker := encounter.attacker
	if attacker != null:
		attacker.has_moved = true


func finish_battle(reason: String = "", battle_positions: Dictionary = {}) -> void:
	if phase != Phase.BATTLE:
		return
	for unit in player_mechs:
		unit.close_battle_guard()
	if current_encounter != null:
		BattleDeployment.commit_to_overworld(
			current_encounter,
			battle_positions,
			all_mechs(),
			overworld_size()
		)
	var destroyed: PackedStringArray = []
	for unit in all_mechs():
		if not unit.alive:
			destroyed.append(unit.display_name)
	if not destroyed.is_empty():
		battle_report = "Destroyed: %s. Returned to the overworld." % ", ".join(destroyed)
	elif reason != "":
		battle_report = reason
	else:
		battle_report = "Battle ended. Returned to the overworld."
	var gauge := preview_battle_return()
	current_encounter = null
	phase = Phase.OVERWORLD
	player_attack_max = int(gauge["max"])
	player_attack_gauge = int(gauge["charge"])
	player_banked_gauge = int(gauge["banked"])
	battle_offense = false
	battle_finished.emit()


func reset_attack_gauges() -> void:
	player_attack_gauge = 0
	player_banked_gauge = 0


func clear_mission_tally() -> void:
	mission_tally.clear()


func clear_mission_upgrades() -> void:
	if mission_upgrades == null:
		mission_upgrades = MissionUpgrades.new()
	mission_upgrades.clear()


## Health actually lost. Guard and barrier that soak a hit stay off this record.
func note_strike(attacker: MechState, defender: MechState, hp_lost: int, killed: bool) -> void:
	if attacker == null or defender == null:
		return
	var lost := maxi(hp_lost, 0)
	if attacker.team == "player" and defender.team == "enemy":
		var attack := _tally_row(attacker.id)
		attack["dealt"] = int(attack["dealt"]) + lost
		if killed:
			attack["destroyed"] = int(attack["destroyed"]) + 1
	if defender.team == "player":
		var defense := _tally_row(defender.id)
		defense["taken"] = int(defense["taken"]) + lost


func tally_for(unit_id: String) -> Dictionary:
	var row: Dictionary = mission_tally.get(unit_id, {})
	return {
		"destroyed": int(row.get("destroyed", 0)),
		"dealt": int(row.get("dealt", 0)),
		"taken": int(row.get("taken", 0)),
	}


func _tally_row(unit_id: String) -> Dictionary:
	if not mission_tally.has(unit_id):
		mission_tally[unit_id] = {"destroyed": 0, "dealt": 0, "taken": 0}
	return mission_tally[unit_id]


## Stepped quarter-step. 1–4 gains 1, 5–10 gains 2, 11–15 gains 3.
static func tactic_bonus(amount: int) -> int:
	if amount <= 4:
		return 1 if amount > 0 else 0
	if amount <= 10:
		return 2
	if amount <= 15:
		return 3
	return 4


## Attack cards in Overdrive. Printed damage in a standard fight, and for every enemy attack.
func card_damage(card: CardData) -> int:
	var amount := 0 if card == null else maxi(card.damage, 0)
	if battle_offense and card != null and card.card_type == "Attack":
		amount += tactic_bonus(maxi(card.damage, 0))
	return amount


## Guard cards in Overdrive. Printed block in a standard fight.
func card_block(card: CardData) -> int:
	var amount := 0 if card == null else maxi(card.block, 0)
	if battle_offense and card != null and card.is_guard():
		amount += tactic_bonus(maxi(card.block, 0))
	return amount


## One charge off the squad gauge. Refuses when the gauge is short.
func spend_charge() -> bool:
	if player_attack_gauge < 1:
		return false
	player_attack_gauge -= 1
	return true


func charge_from_pitch() -> bool:
	if player_attack_gauge >= player_attack_max:
		return false
	player_attack_gauge += 1
	return true


## Live charge first. Overflow waits for the next gauge only while Overdrive is spending this one.
func charge_from_spark() -> Dictionary:
	var room := maxi(player_attack_max - player_attack_gauge, 0)
	var live := mini(SPARK_CHARGE, room)
	player_attack_gauge += live
	var banked := 0
	if battle_offense:
		banked = SPARK_CHARGE - live
		player_banked_gauge += banked
	return {
		"live": live,
		"banked": banked,
		"filled": live > 0 and attack_ready("player"),
	}


## Gauge values finish_battle will write. Overdrive spends the bar, then banked Spark fills what is left.
func preview_battle_return() -> Dictionary:
	var max_after := SQUAD_ATTACK_MAX
	var charge := mini(player_attack_gauge, max_after)
	var banked := player_banked_gauge
	var grant := 0
	if battle_offense:
		grant = mini(max_after, banked)
		charge = grant
		banked -= grant
	return {
		"max": max_after,
		"charge": charge,
		"banked": banked,
		"grant": grant,
		"offense": battle_offense,
	}


func attack_ready(team: String) -> bool:
	return team == "player" and player_attack_gauge >= player_attack_max


func end_overworld_turn() -> void:
	turn_number += 1
	enemy_phase_pending = false
	for unit in all_mechs():
		unit.has_moved = false


## Same cover used from the title into mech select: fade to black, swap, fade back in.
func _change_scene(path: String) -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == "res://scenes/main/main.tscn":
		get_tree().call_deferred("change_scene_to_file", path)
		return
	if _transitioning:
		return
	_transitioning = true
	_fade_then_swap(path)


func _fade_then_swap(path: String) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if _fade.color.a >= 0.98:
		_swap_scene(path)
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	_fade_tween.finished.connect(_swap_scene.bind(path), CONNECT_ONE_SHOT)


func _swap_scene(path: String) -> void:
	_pending_scene = path
	_apply_scene.call_deferred()


func _apply_scene() -> void:
	var path := _pending_scene
	get_tree().change_scene_to_file(path)
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	_fade_tween.finished.connect(_finish_transition, CONNECT_ONE_SHOT)


func _finish_transition() -> void:
	if _fade.color.a <= 0.01:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	transition_finished.emit()


## The new scene is on screen. Scene changes fade in after _ready, so wait before an opening banner.
func wait_until_shown() -> void:
	if not _transitioning:
		return
	await transition_finished
