extends Control


const ENGAGE_COLOR := Color(0.45, 0.18, 0.18)
const STEP_SECONDS := 0.22
const SELECT_BLUE := Color(0.55, 0.82, 1.0)
const SELECT_RED := Color(1.0, 0.48, 0.45)
const ATTACK_SHADE := Color(0.95, 0.18, 0.14, 0.58)
const TIMELINE_DIM := 0.38
const TIMELINE_LEAD_SIZE := 80.0
const TIMELINE_QUEUE_SIZE := 40.0
const MAP_ZOOM_MIN := 1.0
const MAP_ZOOM_MAX := 2.0
const MAP_ZOOM_STEP := 1.1
const MAP_PAN_THRESHOLD := 8.0
const BATTLE_WINDOW_LINE := Color(1.0, 0.94, 0.72, 0.96)
const BATTLE_WINDOW_FILL := Color(1.0, 0.9, 0.45, 0.16)
const BARRIER_SCENE: PackedScene = preload("res://scenes/props/barrier.tscn")
const CELL_SCENE := preload("res://scenes/overworld/map_cell.tscn")
const CHIP_SCENE := preload("res://scenes/ui/timeline_chip.tscn")
const COMMENCE_TEXT := "COMMENCE"
const ATTACK_TEXT := "ATTACK"
const ACTION_BUTTON_SIZE := Vector2(180, 96)
const PORTRAIT_SCENE := preload("res://scenes/ui/confirm_portrait.tscn")
const APPROACH_BOX_SCENE := preload("res://scenes/ui/approach_box.tscn")
const APPROACH_NONE := Vector2i(-99999, -99999)

var _selected: MechState
var _undo_button: Button
var _undo_unit: MechState
var _undo_origin := Vector2i.ZERO
var _undo_facing := 1
var _status_unit: MechState
var _moving_unit: MechState
var _animating := false
var _targeting := false
var _map_locked := false
var _battle_layer: Node
var _zoom_pivot_local := Vector2.ZERO
var _zoom_origin_focus := Vector2.ZERO
var _map_zoom := 1.0
var _map_placed := false
var _intro_holds_center := true
var _intro_tweening := false
var _map_pan := Vector2.ZERO
var _reveal_tween: Tween
var _saved_map_zoom := 1.0
var _saved_map_pan := Vector2.ZERO
var _map_dragging := false
var _map_drag_total := 0.0
var _gesture_panned := false
var _touch_points: Dictionary = {}
var _pinch_distance := -1.0
var _status_override := ""
var _buttons: Dictionary = {}
var _stage: TileMapLayer
var _cell_px := 1.0
var _round: Array[MechState] = []
var _turn_busy := false
var _head_windows: Dictionary = {}
var _timeline_key := ""
var _rotated_id := ""
var _squad_fill: StyleBoxFlat
var _ally_pulse: Tween
var _ally_pulse_frame: CanvasItem
var _ally_pulse_id := ""
var _select_pulse: Tween
var _select_shade: ColorRect
var _select_id := ""
var _confirming := false
var _confirm_target: MechState
var _commence_pressed := false
var _cancel_button: Button
var _engage_pulse: Tween
var _engage_shades: Array[ColorRect] = []
var _engage_key := ""
var _approach_from := APPROACH_NONE
var _approach_enemy_id := ""
var _approach_boxes: Array[ApproachBox] = []
var _confirm_key := ""
var _header_row: HBoxContainer
var _confirm_strip: HBoxContainer
var _confirm_squad_gauge: ProgressBar
var _confirm_squad_fill: StyleBoxFlat
var _confirm_players: HBoxContainer
var _confirm_enemies: HBoxContainer
var _commence_flash: Tween
var _players_before_battle := 0
var _enemies_before_battle := 0
var _campaign_over := false
## Holds every turn until the opening banner has left the screen.
var _opening := true

@onready var grid_host: Control = %GridHost
@onready var grid: GridContainer = %Grid
@onready var approach_layer: Control = %ApproachLayer
@onready var status_label: Label = %StatusLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var attack_button: Button = %AttackButton
@onready var cancel_button: Button = %CancelButton
@onready var undo_button: Button = %UndoMoveButton
@onready var action_bar: Control = $Actions
@onready var stats_window: PanelContainer = %StatsWindow
@onready var mech_panel: MechPanel = %StatsBody
@onready var deck_overlay: DeckOverlay = %DeckOverlay
@onready var timeline_column: HBoxContainer = %TimelineColumn
@onready var turn_lead: HBoxContainer = %TurnLead
@onready var timeline_queue: GridContainer = %TimelineQueue
@onready var turn_timeline: HBoxContainer = %TurnTimeline
@onready var player_gauge: ProgressBar = %PlayerGauge
@onready var next_gauge_label: Label = %NextGaugeLabel
@onready var resolution_overlay: Control = %Resolution
@onready var resolution_title: Label = %ResolutionTitle
@onready var back_to_title_button: Button = %BackToTitleButton
@onready var mode_banner: ModeBanner = %ModeBanner
@onready var dialogue_bar: DialogueBar = %DialogueBar


func _can_attack() -> bool:
	var actor := _current_actor()
	return (
		actor != null
		and actor.alive
		and actor.team == "player"
		and not _animating
		and not _map_locked
		and not _turn_busy
		and not _opening
		and not _enemies_in_range(actor).is_empty()
	)


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn)
	attack_button.pressed.connect(_on_attack_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	mech_panel.deck_pressed.connect(_on_deck_pressed)
	resolution_overlay.visible = false
	grid_host.resized.connect(_fit_grid)
	GameManager.battle_finished.connect(_close_battle)
	StageMap.use(GameManager.stage_scene)
	_stage = StageMap.layer
	grid.add_child(_stage)
	_stage.z_as_relative = true
	_stage.z_index = 0
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_style_gauge(player_gauge)
	_style_attack_button()
	_size_action_button(attack_button)
	_size_action_button(end_turn_button)
	_build_confirm_strip()
	_fill_round()
	_rebuild()
	await GameManager.wait_until_shown()
	if not is_inside_tree():
		return
	await _play_mission_start()
	if not is_inside_tree():
		return
	_opening = false
	_begin_actor_turn()


func _rebuild() -> void:
	for child in grid.get_children():
		if child == _stage:
			continue
		child.queue_free()
	_buttons.clear()
	_seat_on_stage()
	var rect := StageMap.bounds
	grid.columns = rect.size.x
	for y in rect.size.y:
		for x in rect.size.x:
			var coords := rect.position + Vector2i(x, y)
			var button := CELL_SCENE.instantiate() as Button
			button.pressed.connect(_on_cell_pressed.bind(coords))
			button.resized.connect(_on_cell_resized.bind(button))
			grid.add_child(button)
			_buttons[coords] = button
	_face_enemies_toward_squad()
	_refresh()
	_fit_grid()


func _face_enemies_toward_squad() -> void:
	var squad_x := 0.0
	var count := 0
	for player in GameManager.player_mechs:
		if not player.alive:
			continue
		squad_x += player.overworld_position.x
		count += 1
	if count == 0:
		return
	squad_x /= float(count)
	for enemy in GameManager.enemy_mechs:
		if enemy.alive:
			enemy.face_toward_x(enemy.overworld_position.x, squad_x)


func _fill_round() -> void:
	var living: Array[MechState] = []
	for unit in GameManager.all_mechs():
		if unit != null and unit.alive:
			living.append(unit)
	living.sort_custom(func(a: MechState, b: MechState) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		if a.team != b.team:
			return a.team == "player"
		return a.display_name < b.display_name
	)
	_round = living


func _prune_queue() -> void:
	var living: Array[MechState] = []
	for unit in _round:
		if unit != null and unit.alive:
			living.append(unit)
	_round = living


## True once every mech still in the queue has acted. A death removes a slot, so the round follows whoever is left.
func _round_complete() -> bool:
	if _round.is_empty():
		return false
	for unit in _round:
		if unit != null and not unit.has_moved:
			return false
	return true


func _current_actor() -> MechState:
	_prune_queue()
	if _round.is_empty():
		return null
	return _round[0]


func _advance_actor() -> void:
	if _round.is_empty():
		return
	var finished: MechState = _round.pop_front()
	if finished != null and finished.alive:
		finished.has_moved = true
		_round.append(finished)
		_rotated_id = finished.id
	_prune_queue()
	if _round_complete():
		GameManager.end_overworld_turn()


func _refresh_timeline() -> void:
	if turn_timeline == null or turn_lead == null:
		return
	var ids: PackedStringArray = []
	for unit in _round:
		if unit != null and unit.alive:
			ids.append(unit.id)
	var key := ",".join(ids)
	if key == _timeline_key and _timeline_chip_count() == ids.size():
		_apply_timeline_focus()
		return
	_timeline_key = key
	for child in turn_lead.get_children():
		child.free()
	for child in turn_timeline.get_children():
		child.free()
	var actor := null if _opening else _current_actor()
	var index := 0
	for unit in _round:
		if unit == null or not unit.alive:
			continue
		var chip := _make_timeline_chip(unit, unit == actor, index == 0)
		var arrived := _rotated_id != "" and unit.id == _rotated_id and index == ids.size() - 1
		var host: Node = turn_lead if index == 0 else turn_timeline
		host.add_child(chip)
		if arrived:
			chip.modulate.a = 0.0
			var tween := chip.create_tween()
			tween.tween_property(chip, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		index += 1
	_rotated_id = ""
	if timeline_queue != null:
		timeline_queue.visible = turn_timeline.get_child_count() > 0
	_apply_timeline_focus()


func _timeline_chip_count() -> int:
	var lead := 0 if turn_lead == null else turn_lead.get_child_count()
	var queued := 0 if turn_timeline == null else turn_timeline.get_child_count()
	return lead + queued


func _timeline_chips() -> Array[Panel]:
	var chips: Array[Panel] = []
	for host in [turn_lead, turn_timeline]:
		if host == null:
			continue
		for child in host.get_children():
			var chip := child as Panel
			if chip != null:
				chips.append(chip)
	return chips


func _team_stroke(unit: MechState) -> Color:
	return SELECT_BLUE if unit.team == "player" else SELECT_RED


func _make_timeline_chip(unit: MechState, active: bool, lead: bool) -> Panel:
	var chip := CHIP_SCENE.instantiate() as Panel
	var side := TIMELINE_LEAD_SIZE if lead else TIMELINE_QUEUE_SIZE
	chip.custom_minimum_size = Vector2(side, side)
	chip.set_meta("unit_id", unit.id)
	chip.gui_input.connect(_on_timeline_input.bind(unit))
	var style := (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.set_border_width_all(3 if active else 2)
	style.border_color = _team_stroke(unit)
	chip.add_theme_stylebox_override("panel", style)
	chip.set_meta("panel_style", style)
	var portrait := chip.get_node("Portrait") as AnimatedSprite2D
	var pilot := false
	var frames: SpriteFrames = null
	if unit.team == "player":
		frames = MechSprites.pilot_frames(unit.art_id)
		pilot = frames != null
	if frames == null:
		frames = MechSprites.frames_for(unit.art_id)
	if frames != null and frames.has_animation("idle"):
		portrait.sprite_frames = frames
		portrait.play("idle")
		if unit.team != "player" or not MechSprites.portrait_plays(frames):
			portrait.pause()
			portrait.frame = 0
		portrait.flip_h = false if pilot else unit.facing < 0
	portrait.set_meta("pilot", pilot)
	var caption := chip.get_node("Caption") as Label
	caption.text = unit.short_name
	caption.add_theme_font_size_override("font_size", 32 if lead else 14)
	chip.resized.connect(_place_timeline_portrait.bind(chip))
	return chip


func _place_timeline_portrait(chip: Panel) -> void:
	var portrait := chip.get_node_or_null("Portrait") as AnimatedSprite2D
	if portrait == null or portrait.sprite_frames == null or chip.size.x < 1.0:
		return
	if not portrait.sprite_frames.has_animation("idle"):
		return
	var tex := portrait.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var pilot := bool(portrait.get_meta("pilot", false))
	if pilot:
		var longest := maxf(tex.get_width(), tex.get_height())
		if longest <= 0.0:
			return
		var fitted := minf(chip.size.x, chip.size.y) * 0.92 / longest
		portrait.scale = Vector2(fitted, fitted)
		portrait.position = chip.size * 0.5
		return
	var window := _head_window(tex)
	if window.size.x < 1.0:
		return
	var fit := minf(chip.size.x, chip.size.y) / window.size.x
	portrait.scale = Vector2(fit, fit)
	var frame := tex.get_size()
	var head_center := window.position + window.size * 0.5
	var shift := (head_center - frame * 0.5) * fit
	if portrait.flip_h:
		shift.x = -shift.x
	portrait.position = chip.size * 0.5 - shift


func _head_window(texture: Texture2D) -> Rect2:
	if _head_windows.has(texture):
		return _head_windows[texture]
	var frame := texture.get_size()
	var used := Rect2(Vector2.ZERO, frame)
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var opaque := image.get_used_rect()
		if opaque.size.x >= 1.0 and opaque.size.y >= 1.0:
			used = opaque
	var standing := used.size.y >= used.size.x * 0.85
	var fraction := 0.5 if standing else 0.82
	var side := minf(used.size.x, used.size.y * fraction)
	var window := Rect2(
		used.position.x + (used.size.x - side) * 0.5,
		used.position.y,
		side,
		side
	)
	_head_windows[texture] = window
	return window


func _refresh_gauges() -> void:
	if player_gauge == null:
		return
	var squad_charge := GameManager.player_attack_gauge
	var squad_max := GameManager.player_attack_max
	player_gauge.max_value = squad_max
	player_gauge.value = squad_charge
	OverdriveGauge.write(player_gauge, squad_charge, squad_max)
	if next_gauge_label != null:
		var banked := GameManager.player_banked_gauge
		next_gauge_label.visible = banked > 0
		next_gauge_label.text = "Next Gauge +%d" % banked
		next_gauge_label.add_theme_color_override("font_color", SELECT_BLUE)
	_update_squad_flash()
	_sync_confirm_gauges()


func _style_gauge(bar: ProgressBar) -> void:
	OverdriveGauge.dress(bar)
	if bar == player_gauge:
		_squad_fill = OverdriveGauge.claim_fill(bar)


func _update_squad_flash() -> void:
	OverdriveGauge.pulse(player_gauge, _squad_fill, GameManager.attack_ready("player"))


func _sync_ally_pulse(actor: MechState) -> void:
	var active := actor != null and actor.team == "player" and actor.alive and not _map_locked
	var frame: CanvasItem = null
	if active:
		var button: Button = _buttons.get(actor.overworld_position) as Button
		if button != null:
			frame = button.get_node_or_null("Frame") as CanvasItem
	if not active or frame == null:
		_stop_ally_pulse()
		return
	if (
		_ally_pulse_id == actor.id
		and _ally_pulse_frame == frame
		and _ally_pulse != null
		and _ally_pulse.is_valid()
		and _ally_pulse.is_running()
	):
		return
	_stop_ally_pulse()
	_ally_pulse_id = actor.id
	_ally_pulse_frame = frame
	frame.modulate.a = 1.0
	_ally_pulse = create_tween()
	_ally_pulse.set_loops()
	_ally_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ally_pulse.tween_property(frame, "modulate:a", 0.0, 0.45)
	_ally_pulse.tween_property(frame, "modulate:a", 1.0, 0.45)


func _stop_ally_pulse() -> void:
	if _ally_pulse != null and _ally_pulse.is_valid():
		_ally_pulse.kill()
	_ally_pulse = null
	if _ally_pulse_frame != null and is_instance_valid(_ally_pulse_frame):
		_ally_pulse_frame.modulate.a = 1.0
	_ally_pulse_frame = null
	_ally_pulse_id = ""


func _note_status(text: String) -> void:
	status_label.text = text
	GameMenu.note_status(text)


func _quit_stage() -> void:
	GameManager.quit_stage()


func _on_back_to_title_pressed() -> void:
	back_to_title_button.disabled = true
	_quit_stage()


func _style_attack_button() -> void:
	AccentPulse.clear(attack_button)


func _size_action_button(button: Button) -> void:
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Keep the action buttons pinned to the bottom-right corner, over the map.
func _pin_actions() -> void:
	var box := attack_button.get_parent() as Control
	if box == null:
		return
	var box_size := box.get_combined_minimum_size()
	box.offset_right = -12.0
	box.offset_bottom = -8.0
	box.offset_left = box.offset_right - box_size.x
	box.offset_top = box.offset_bottom - box_size.y


func _build_confirm_strip() -> void:
	_header_row = get_node("Layout/TopBar/Chrome/TopStack/HeaderRow") as HBoxContainer
	_confirm_strip = get_node("Layout/TopBar/Chrome/TopStack/ConfirmStrip") as HBoxContainer
	_confirm_players = _confirm_strip.get_node("Players") as HBoxContainer
	_confirm_enemies = _confirm_strip.get_node("Enemies") as HBoxContainer
	_confirm_squad_gauge = _confirm_strip.get_node("SquadGauge") as ProgressBar
	_confirm_squad_fill = OverdriveGauge.claim_fill(_confirm_squad_gauge)
	OverdriveGauge.dress(_confirm_squad_gauge)
	_cancel_button = cancel_button
	_undo_button = undo_button
	if not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if not _undo_button.pressed.is_connected(_on_undo_move):
		_undo_button.pressed.connect(_on_undo_move)


func _apply_confirm_bar() -> void:
	var confirming := _confirming and _confirm_target != null
	var actor := _current_actor()
	var choosing := _targeting and actor != null and actor.team == "player"
	end_turn_button.visible = not confirming
	if _cancel_button != null:
		_cancel_button.visible = (confirming or choosing) and actor != null and actor.team == "player"
	if _confirm_strip != null and _confirm_strip.visible != confirming:
		_confirm_strip.visible = confirming
		_place_confirm_chrome(confirming)
	if not confirming:
		if attack_button.text != ATTACK_TEXT:
			attack_button.text = ATTACK_TEXT
			_stop_commence_flash()
		_confirm_key = ""
		_pin_actions()
		return
	attack_button.text = COMMENCE_TEXT
	attack_button.visible = true
	_pin_actions()
	_fill_confirm_bar()
	_start_commence_flash()


func _fill_confirm_bar() -> void:
	var actor := _current_actor()
	if actor == null or _confirm_target == null:
		return
	var step := _confirm_target.overworld_position - actor.overworld_position
	var encounter := EncounterData.create(actor, step, GameManager.all_mechs())
	var players: Array[MechState] = []
	var enemies: Array[MechState] = []
	for unit in encounter.participants:
		if unit.team == "player":
			players.append(unit)
		else:
			enemies.append(unit)
	var player_lead := actor if actor.team == "player" else _confirm_target
	var enemy_lead := _confirm_target if actor.team == "player" else actor
	_order_side(players, player_lead)
	_order_side(enemies, enemy_lead)
	var key := _side_ids(players) + "|" + _side_ids(enemies)
	if key == _confirm_key:
		return
	_confirm_key = key
	_fill_portrait_row(_confirm_players, players)
	_fill_portrait_row(_confirm_enemies, enemies)


func _order_side(units: Array[MechState], lead: MechState) -> void:
	units.sort_custom(func(a: MechState, b: MechState) -> bool:
		if a == lead:
			return true
		if b == lead:
			return false
		if a.overworld_position.x == b.overworld_position.x:
			return a.overworld_position.y < b.overworld_position.y
		return a.overworld_position.x < b.overworld_position.x
	)


func _side_ids(units: Array[MechState]) -> String:
	var ids: PackedStringArray = []
	for unit in units:
		ids.append(unit.id)
	return "|".join(ids)


func _sync_confirm_gauges() -> void:
	if _confirm_squad_gauge == null:
		return
	var squad_charge := GameManager.player_attack_gauge
	var squad_max := GameManager.player_attack_max
	_confirm_squad_gauge.max_value = squad_max
	_confirm_squad_gauge.value = squad_charge
	OverdriveGauge.write(_confirm_squad_gauge, squad_charge, squad_max)
	OverdriveGauge.pulse(
		_confirm_squad_gauge,
		_confirm_squad_fill,
		squad_max > 0 and squad_charge >= squad_max
	)


func _place_confirm_chrome(confirming: bool) -> void:
	_header_row.visible = not confirming


func _fill_portrait_row(row: HBoxContainer, units: Array[MechState]) -> void:
	for child in row.get_children():
		child.free()
	for unit in units:
		row.add_child(_make_confirm_portrait(unit))


func _make_confirm_portrait(unit: MechState) -> Panel:
	var chip := PORTRAIT_SCENE.instantiate() as Panel
	var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style = style.duplicate() as StyleBoxFlat
		style.border_color = SELECT_BLUE if unit.team == "player" else SELECT_RED
		chip.add_theme_stylebox_override("panel", style)
	var portrait := chip.get_node("Portrait") as AnimatedSprite2D
	var pilot := false
	var frames: SpriteFrames = null
	if unit.team == "player":
		frames = MechSprites.pilot_frames(unit.art_id)
		pilot = frames != null
	if frames == null:
		frames = MechSprites.frames_for(unit.art_id)
	if frames != null and frames.has_animation("idle"):
		portrait.sprite_frames = frames
		portrait.play("idle")
		if unit.team != "player" or not MechSprites.portrait_plays(frames):
			portrait.pause()
			portrait.frame = 0
		portrait.flip_h = false if pilot else unit.facing < 0
	portrait.set_meta("pilot", pilot)
	chip.resized.connect(_place_timeline_portrait.bind(chip))
	return chip


func _start_commence_flash() -> void:
	if _commence_flash != null and _commence_flash.is_valid() and _commence_flash.is_running():
		return
	_commence_flash = AccentPulse.start(self, attack_button)


func _stop_commence_flash() -> void:
	if _commence_flash != null and _commence_flash.is_valid():
		_commence_flash.kill()
	_commence_flash = null
	AccentPulse.clear(attack_button)


func _enemies_in_range(unit: MechState) -> Array[MechState]:
	var found: Array[MechState] = []
	if unit == null:
		return found
	var reach := maxi(unit.attack_range, 1)
	for distance in range(1, reach + 1):
		for step in _attack_ring(distance):
			var other := _unit_at(unit.overworld_position + step)
			if other != null and other.alive and other.team == "enemy":
				found.append(other)
	return found


## Distance 1 keeps the old right, left, down, up order. Farther rings fill in after that.
func _attack_ring(distance: int) -> Array[Vector2i]:
	if distance <= 1:
		return [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	var steps: Array[Vector2i] = []
	for y in range(-distance, distance + 1):
		for x in range(-distance, distance + 1):
			if absi(x) + absi(y) == distance:
				steps.append(Vector2i(x, y))
	return steps


func _clear_confirm() -> void:
	_confirming = false
	_confirm_target = null
	_confirm_key = ""
	_stop_engage_pulse()


func _confirm_roster() -> Array[MechState]:
	var roster: Array[MechState] = []
	var actor := _current_actor()
	if actor == null or _confirm_target == null:
		return roster
	var step := _confirm_target.overworld_position - actor.overworld_position
	var encounter := EncounterData.create(actor, step, GameManager.all_mechs())
	roster.assign(encounter.participants)
	return roster


func _engage_color(unit: MechState) -> Color:
	var color := SELECT_BLUE if unit.team == "player" else SELECT_RED
	color.a = 0.85
	return color


func _sync_engage_pulse() -> void:
	if _map_locked or (_confirming == false and not _approach_open()):
		_stop_engage_pulse()
		return
	var roster := _shown_fight_roster()
	var key := _side_ids(roster)
	var shades: Array[ColorRect] = []
	for unit in roster:
		var button: Button = _buttons.get(unit.overworld_position) as Button
		var shade := button.get_node_or_null("Shade") as ColorRect if button != null else null
		if shade != null:
			shades.append(shade)
	if (
		key == _engage_key
		and shades.size() == _engage_shades.size()
		and _engage_pulse != null
		and _engage_pulse.is_valid()
		and _engage_pulse.is_running()
	):
		return
	_stop_engage_pulse()
	if shades.is_empty():
		return
	_engage_key = key
	_engage_shades = shades
	for shade in shades:
		shade.color.a = 0.85
	_engage_pulse = create_tween()
	_engage_pulse.set_loops()
	_engage_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_engage_pulse.tween_property(shades[0], "color:a", 0.0, 0.45)
	for index in range(1, shades.size()):
		_engage_pulse.parallel().tween_property(shades[index], "color:a", 0.0, 0.45)
	_engage_pulse.tween_property(shades[0], "color:a", 0.85, 0.45)
	for index in range(1, shades.size()):
		_engage_pulse.parallel().tween_property(shades[index], "color:a", 0.85, 0.45)


func _stop_engage_pulse() -> void:
	if _engage_pulse != null and _engage_pulse.is_valid():
		_engage_pulse.kill()
	_engage_pulse = null
	_engage_shades.clear()
	_engage_key = ""


func _fit_grid() -> void:
	var rect := StageMap.bounds
	var columns := rect.size.x
	var rows := rect.size.y
	if _map_locked or columns <= 0 or rows <= 0 or grid_host.size.x <= 1.0 or grid_host.size.y <= 1.0:
		return
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	var cell_h := (grid_host.size.y - v_sep * (rows - 1)) / float(rows)
	var cell := floorf(cell_h)
	if cell < 1.0:
		return
	var side := Vector2(cell, cell)
	for child in grid.get_children():
		if child is Control:
			child.custom_minimum_size = side
	var grid_size := Vector2(
		cell * columns + h_sep * (columns - 1),
		cell * rows + v_sep * (rows - 1)
	)
	# Position mode. Godot 4.7 still type-checks this as an enum that has no member for 0.
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	grid.layout_mode = 0
	grid.size = grid_size
	_cell_px = cell
	_sync_stage()
	if _opening and not _intro_tweening:
		_map_zoom = _overview_zoom()
		_map_pan = Vector2.ZERO
		_intro_holds_center = true
	elif not _map_placed:
		_map_pan = (grid_size * _map_zoom - grid_host.size) * 0.5
		_map_placed = true
	elif not _intro_tweening and not _map_locked:
		_map_zoom = clampf(_map_zoom, _map_zoom_floor(), MAP_ZOOM_MAX)
	_apply_map_view()


func _apply_map_view() -> void:
	grid.scale = Vector2(_map_zoom, _map_zoom)
	var visual := grid.size * _map_zoom
	var slack := visual - grid_host.size
	if _intro_holds_center:
		_map_pan = Vector2.ZERO
	elif not _intro_tweening:
		_map_pan.x = slack.x * 0.5 if slack.x <= 1.0 else clampf(_map_pan.x, -slack.x * 0.5, slack.x * 0.5)
		_map_pan.y = slack.y * 0.5 if slack.y <= 1.0 else clampf(_map_pan.y, -slack.y * 0.5, slack.y * 0.5)
	grid.position = (grid_host.size - visual) * 0.5 + _map_pan
	_sync_approach_boxes()
	_place_status_tip()


func _sync_stage() -> void:
	if _stage == null or _stage.tile_set == null:
		return
	var tile := Vector2(_stage.tile_set.tile_size)
	_stage.scale = Vector2(_cell_px / tile.x, _cell_px / tile.y)
	_stage.position = -Vector2(StageMap.bounds.position) * _cell_px


func _seat_on_stage() -> void:
	var taken := {}
	for unit in GameManager.all_mechs():
		if unit == null or not unit.alive:
			continue
		var spot := unit.overworld_position
		if StageMap.contains(spot) and not StageMap.blocked(spot) and not taken.has(spot):
			taken[spot] = true
			continue
		spot = StageMap.nearest_open(unit.overworld_position, taken)
		if spot.x < 0:
			continue
		unit.overworld_position = spot
		taken[spot] = true


func _battle_window_cells() -> Array[Vector2i]:
	if _campaign_over:
		var none: Array[Vector2i] = []
		return none
	if _map_locked and not GameManager.zoom_focus_cells.is_empty():
		return GameManager.zoom_focus_cells
	if _confirming and _confirm_target != null:
		var actor := _current_actor()
		if actor != null:
			return BattleDeployment.overworld_cells(
				actor.overworld_position,
				_confirm_target.overworld_position,
				GameManager.overworld_size()
			)
	if _approach_open():
		return BattleDeployment.overworld_cells(
			_approach_from,
			_selected.overworld_position,
			GameManager.overworld_size()
		)
	var empty: Array[Vector2i] = []
	return empty


## Inspecting an enemy. Direction boxes stay up until the player clicks off that enemy.
func _scouting() -> bool:
	return (
		_selected != null
		and _selected.alive
		and _selected.team == "enemy"
		and not _opening
		and not _campaign_over
		and not _map_locked
		and not _animating
		and not _turn_busy
		and not _targeting
		and not _confirming
	)


func _approach_steps() -> Array[Vector2i]:
	var steps: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP
	]
	return steps


func _sync_approach_owner() -> void:
	if not _scouting():
		_approach_from = APPROACH_NONE
		_approach_enemy_id = ""
		return
	if _approach_enemy_id != _selected.id:
		_approach_from = APPROACH_NONE
		_approach_enemy_id = _selected.id


func _approach_open() -> bool:
	return (
		_scouting()
		and _approach_enemy_id == _selected.id
		and _approach_from != APPROACH_NONE
	)


func _is_approach_cell(coords: Vector2i) -> bool:
	if not _scouting():
		return false
	var step := coords - _selected.overworld_position
	return absi(step.x) + absi(step.y) == 1


func _pick_approach(coords: Vector2i) -> void:
	if not _scouting() or not _is_approach_cell(coords):
		return
	_approach_enemy_id = _selected.id
	_approach_from = coords
	_open_status_tip(_selected)
	_refresh()


func _leave_scout() -> void:
	if not _scouting():
		return
	_selected = null
	_approach_from = APPROACH_NONE
	_approach_enemy_id = ""
	_hide_status_tip()
	_refresh()


func _preview_roster() -> Array[MechState]:
	var roster: Array[MechState] = []
	if not _approach_open():
		return roster
	var inside := {}
	for cell in _battle_window_cells():
		inside[cell] = true
	for unit in GameManager.all_mechs():
		if unit != null and unit.alive and inside.has(unit.overworld_position):
			roster.append(unit)
	return roster


func _shown_fight_roster() -> Array[MechState]:
	if _confirming and not _map_locked:
		return _confirm_roster()
	if _approach_open():
		return _preview_roster()
	var empty: Array[MechState] = []
	return empty


func _ensure_approach_boxes() -> void:
	if approach_layer == null or not _approach_boxes.is_empty():
		return
	for _step in _approach_steps():
		var box := APPROACH_BOX_SCENE.instantiate() as ApproachBox
		approach_layer.add_child(box)
		box.direction_chosen.connect(_on_approach_chosen)
		_approach_boxes.append(box)


func _on_approach_chosen(coords: Vector2i) -> void:
	if _gesture_panned:
		_gesture_panned = false
		return
	if _opening or _campaign_over or _confirming or _turn_busy or _animating:
		return
	_pick_approach(coords)


func _sync_approach_boxes() -> void:
	if approach_layer == null or grid == null:
		return
	_ensure_approach_boxes()
	approach_layer.position = grid.position
	approach_layer.scale = grid.scale
	approach_layer.rotation = 0.0
	var spots: Array[Vector2i] = []
	var anchor: Control = null
	if _scouting():
		anchor = _buttons.get(_selected.overworld_position) as Control
		if anchor != null:
			for step in _approach_steps():
				spots.append(_selected.overworld_position + step)
	for index in _approach_boxes.size():
		var box := _approach_boxes[index]
		if anchor == null or index >= spots.size():
			box.hide_direction()
			continue
		var coords := spots[index]
		box.approach_cell = coords
		box.show_direction(_approach_open() and coords == _approach_from)
		var step := coords - _selected.overworld_position
		box.position = anchor.position + Vector2(step) * anchor.size
		box.size = anchor.size
		box.custom_minimum_size = anchor.size


func _mark_battle_window(button: Button, coords: Vector2i, window: Dictionary) -> void:
	var panel := button.get_node_or_null("BattleWindow") as Panel
	if panel == null:
		return
	var style := _owned_panel_style(panel, "window_style")
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	if window.has(coords) and not is_instance_valid(_battle_layer):
		style.bg_color = BATTLE_WINDOW_FILL
		style.border_color = BATTLE_WINDOW_LINE
		style.border_width_left = 3 if not window.has(coords + Vector2i.LEFT) else 1
		style.border_width_top = 3 if not window.has(coords + Vector2i.UP) else 1
		style.border_width_right = 3 if not window.has(coords + Vector2i.RIGHT) else 1
		style.border_width_bottom = 3 if not window.has(coords + Vector2i.DOWN) else 1
	panel.visible = window.has(coords) and not is_instance_valid(_battle_layer)


func _input(event: InputEvent) -> void:
	if _deck_overlay_open():
		return
	if _opening or _campaign_over or _map_locked or _animating or grid_host == null:
		return
	if event is InputEventMouseButton:
		_on_map_mouse_button(event)
	elif event is InputEventMouseMotion and _map_dragging:
		_on_map_mouse_drag(event)
	elif event is InputEventMagnifyGesture and _pointer_on_map(event.position):
		_zoom_map_by(_to_map_local(event.position), event.factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture and _pointer_on_map(event.position) and _map_can_pan():
		_pan_map(event.delta)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_on_map_touch(event)


func _on_map_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not event.pressed or not _pointer_on_map(event.global_position):
			return
		var step := MAP_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / MAP_ZOOM_STEP
		_zoom_map_by(_to_map_local(event.global_position), step)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if stats_window != null and stats_window.visible and stats_window.get_global_rect().has_point(event.global_position):
		return
	if event.pressed:
		_gesture_panned = false
		_map_drag_total = 0.0
		_map_dragging = _pointer_on_map(event.global_position) and (
			event.button_index == MOUSE_BUTTON_MIDDLE or _map_can_pan()
		)
	else:
		var panned := _gesture_panned
		_map_dragging = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_status_click(event.global_position, panned)


func _on_map_mouse_drag(event: InputEventMouseMotion) -> void:
	if _touch_points.size() >= 2:
		return
	if not _map_can_pan() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	_map_drag_total += event.relative.length()
	if _map_drag_total < MAP_PAN_THRESHOLD:
		return
	_gesture_panned = true
	_pan_map(event.relative)
	get_viewport().set_input_as_handled()


func _on_map_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			if _touch_points.size() == 1:
				_gesture_panned = false
				_map_drag_total = 0.0
		else:
			_touch_points.erase(event.index)
		_pinch_distance = _touch_span() if _touch_points.size() >= 2 else -1.0
		return
	var drag := event as InputEventScreenDrag
	if drag == null or not _touch_points.has(drag.index):
		return
	_touch_points[drag.index] = drag.position
	if _touch_points.size() < 2:
		return
	var span := _touch_span()
	if _pinch_distance > 1.0 and span > 1.0:
		_zoom_map_by(_to_map_local(_touch_center()), span / _pinch_distance)
	_pinch_distance = span
	_gesture_panned = true
	get_viewport().set_input_as_handled()


func _zoom_map_by(local_pos: Vector2, factor: float) -> void:
	_stop_reveal()
	var old := _map_zoom
	var next := clampf(old * factor, _map_zoom_floor(), MAP_ZOOM_MAX)
	if is_equal_approx(old, next):
		return
	var anchor := (local_pos - grid.position) / old
	_map_zoom = next
	var visual := grid.size * _map_zoom
	var origin := (grid_host.size - visual) * 0.5
	_map_pan = (local_pos - anchor * _map_zoom) - origin
	_apply_map_view()


func _map_can_pan() -> bool:
	var visual := grid.size * _map_zoom
	var slack := visual - grid_host.size
	return slack.x > 1.0 or slack.y > 1.0 or _map_zoom > _map_zoom_floor()


func _pan_map(delta: Vector2) -> void:
	_stop_reveal()
	_map_pan += delta
	_apply_map_view()


func _reveal_unit(unit: MechState) -> void:
	if unit == null or _opening or _map_locked or _intro_tweening or grid == null or grid_host == null:
		return
	var button := _button_for_unit(unit)
	if button == null:
		return
	var zoom := _map_zoom
	var visual := grid.size * zoom
	var origin := (grid_host.size - visual) * 0.5
	var cell_pos := origin + _map_pan + button.position * zoom
	var cell_size := button.size * zoom
	var pad := maxf(18.0, cell_size.x * 0.45)
	var shift := _view_shift(cell_pos, cell_size, grid_host.size, pad)
	if shift.length_squared() < 1.0:
		return
	var slack := visual - grid_host.size
	var dest := _map_pan + shift
	if slack.x > 1.0:
		dest.x = clampf(dest.x, -slack.x * 0.5, slack.x * 0.5)
	else:
		dest.x = slack.x * 0.5
	if slack.y > 1.0:
		dest.y = clampf(dest.y, -slack.y * 0.5, slack.y * 0.5)
	else:
		dest.y = slack.y * 0.5
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_method(_set_map_pan, _map_pan, dest, 0.32)


func _view_shift(cell_pos: Vector2, cell_size: Vector2, view_size: Vector2, pad: float) -> Vector2:
	var shift := Vector2.ZERO
	if cell_size.x + pad * 2.0 >= view_size.x:
		shift.x = (view_size.x - cell_size.x) * 0.5 - cell_pos.x
	elif cell_pos.x < pad:
		shift.x = pad - cell_pos.x
	elif cell_pos.x + cell_size.x > view_size.x - pad:
		shift.x = view_size.x - pad - (cell_pos.x + cell_size.x)
	if cell_size.y + pad * 2.0 >= view_size.y:
		shift.y = (view_size.y - cell_size.y) * 0.5 - cell_pos.y
	elif cell_pos.y < pad:
		shift.y = pad - cell_pos.y
	elif cell_pos.y + cell_size.y > view_size.y - pad:
		shift.y = view_size.y - pad - (cell_pos.y + cell_size.y)
	return shift


func _set_map_pan(value: Vector2) -> void:
	_map_pan = value
	_apply_map_view()


func _stop_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _pointer_on_map(point: Vector2) -> bool:
	return grid_host.get_global_rect().has_point(point)


func _to_map_local(point: Vector2) -> Vector2:
	return grid_host.get_global_transform().affine_inverse() * point


func _touch_span() -> float:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _touch_center() -> Vector2:
	var points: Array = _touch_points.values()
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _apply_timeline_focus() -> void:
	if turn_timeline == null:
		return
	var selected_id := _selected.id if _selected != null else ""
	var actor := null if _opening else _current_actor()
	for chip in _timeline_chips():
		var id := str(chip.get_meta("unit_id", ""))
		var picked := selected_id != "" and id == selected_id
		var portrait := chip.get_node_or_null("Portrait") as CanvasItem
		if portrait != null:
			portrait.modulate.a = 1.0 if picked else TIMELINE_DIM
		var style := chip.get_meta("panel_style") as StyleBoxFlat
		if style == null:
			continue
		var unit := _unit_by_id(id)
		if unit == null:
			continue
		var marked := (picked and _selected != null) or unit == actor
		style.set_border_width_all(3 if marked else 2)
		style.border_color = _team_stroke(unit)


func _on_timeline_input(event: InputEvent, unit: MechState) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _status_click_blocked() or _blocks_status_tip(unit):
		_hide_status_tip()
	_on_cell_pressed(unit.overworld_position)
	_reveal_unit(unit)


func _unit_by_id(id: String) -> MechState:
	for unit in GameManager.all_mechs():
		if unit.id == id:
			return unit
	return null


func _refresh() -> void:
	var selected_id := _selected.id if _selected != null else ""
	if selected_id != _select_id:
		_stop_selection_pulse()
	_sync_approach_owner()
	var actor := null if _opening else _current_actor()
	var involved := {}
	var roster_key := ""
	var roster := _shown_fight_roster()
	if not roster.is_empty():
		roster_key = _side_ids(roster)
		for fighter in roster:
			if fighter != null:
				involved[fighter.id] = true
	if roster_key != _engage_key:
		_stop_engage_pulse()
	var window := {}
	for cell in _battle_window_cells():
		window[cell] = true
	var distances := {}
	var move_cells := {}
	var range_tint := Color(0, 0, 0, 0)
	var show_reach := (
		_selected != null
		and _selected.alive
		and not _targeting
		and not _confirming
		and not _map_locked
		and not _animating
		and not _turn_busy
		and not _opening
		and (not _selected.has_moved or _selected.team == "enemy")
	)
	if show_reach:
		distances = OverworldAi.reachable(_selected, GameManager.all_mechs(), GameManager.overworld_size())
		range_tint = _range_color(_selected)
		for cell in distances:
			if int(distances[cell]) <= 0:
				continue
			var standing := _unit_at(cell)
			if standing != null and standing.alive:
				continue
			move_cells[cell] = true
	var threat_cells := _threat_cells(actor, show_reach)
	for coords in _buttons:
		var button: Button = _buttons[coords]
		var unit := _unit_at(coords)
		if unit == _moving_unit:
			unit = null
		var focus := _map_locked and GameManager.zoom_focus_cells.has(coords)
		var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
		var border := Color(0, 0, 0, 0)
		var shade := Color(0, 0, 0, 0)
		var ally_turn := unit == actor and actor != null and actor.team == "player"
		if _map_locked and not focus:
			shade = Color(0.02, 0.02, 0.03, 0.72)
		if unit == null:
			if sprite != null:
				sprite.visible = false
			button.text = ""
			button.disabled = _map_locked
			if move_cells.has(coords):
				shade = range_tint
			_paint(button, Color(0, 0, 0, 0), border)
			_set_shade(button, shade)
			_mark_battle_window(button, coords, window)
			_paint_cell_mark(button, null)
		elif _show_unit_sprite(button, unit, focus):
			button.text = ""
			button.disabled = _map_locked
			if involved.has(unit.id):
				shade = _engage_color(unit)
			elif ally_turn:
				shade = _selection_color(unit)
			elif threat_cells.has(coords):
				shade = ATTACK_SHADE
			elif _targeting and unit.team == "enemy" and _in_attack_range(actor, unit):
				border = Color(0.85, 0.28, 0.22)
				shade = ATTACK_SHADE
			elif _confirming and unit.team == "enemy" and _in_attack_range(actor, unit):
				border = SELECT_RED if unit == _confirm_target else Color(0.85, 0.28, 0.22)
			_paint(button, Color(0, 0, 0, 0), border)
			_set_shade(button, shade)
			_mark_battle_window(button, coords, window)
			_paint_cell_mark(button, unit)
		else:
			if sprite != null:
				sprite.visible = false
			button.text = unit.short_name
			button.disabled = _map_locked
			var tint := unit.color
			if not unit.alive:
				tint = Color(0.25, 0.25, 0.25)
			elif unit.has_moved and unit != actor:
				tint = tint.darkened(0.35)
			elif (_targeting or _confirming) and unit.team == "enemy" and _in_attack_range(actor, unit):
				tint = tint.lerp(ENGAGE_COLOR, 0.55)
			if _map_locked and not focus:
				tint = tint.lerp(Color(0.02, 0.02, 0.03), 0.72)
			if involved.has(unit.id):
				shade = _engage_color(unit)
			elif ally_turn:
				shade = _selection_color(unit)
			elif threat_cells.has(coords):
				shade = ATTACK_SHADE
			elif _targeting and unit.team == "enemy" and _in_attack_range(actor, unit):
				shade = ATTACK_SHADE
			_paint(button, tint, border)
			_set_shade(button, shade)
			if unit == _selected:
				button.add_theme_color_override("font_color", Color.BLACK)
			_mark_battle_window(button, coords, window)
			_paint_cell_mark(button, unit)
	_sync_ally_pulse(actor)
	_sync_selection_pulse(actor)
	_sync_engage_pulse()
	_sync_approach_boxes()
	var report := GameManager.battle_report
	var prefix := (report + "\n") if report != "" else ""
	var phase_note := "Waiting."
	if actor != null:
		if _confirming:
			phase_note = "Review both sides, then Commence."
		elif _targeting:
			phase_note = "Select an enemy to attack."
		elif actor.team == "enemy":
			phase_note = "%s is acting." % actor.display_name
		elif not _enemies_in_range(actor).is_empty():
			phase_note = "%s can attack." % actor.display_name
		else:
			phase_note = "%s's turn." % actor.display_name
	if not _opening:
		if _status_override != "":
			_note_status(_status_override)
		else:
			_note_status("%sRound %d    %s" % [prefix, GameManager.turn_number, phase_note])
	end_turn_button.disabled = (
		_opening or _animating or _turn_busy or actor == null or actor.team != "player"
	)
	if _undo_button != null:
		_undo_button.visible = _can_undo() and not _confirming
		_undo_button.disabled = _opening or _animating or _turn_busy
	attack_button.visible = _can_attack() and not _targeting
	_sync_status_tip()
	_apply_confirm_bar()
	_refresh_timeline()
	_refresh_gauges()


func _try_status_click(point: Vector2, panned: bool) -> void:
	if panned:
		return
	if _status_click_blocked():
		_hide_status_tip()
		return
	if stats_window != null and stats_window.visible and stats_window.get_global_rect().has_point(point):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and not _has_ancestor(hovered, grid):
		if approach_layer != null and _has_ancestor(hovered, approach_layer):
			return
		var timeline_root: Node = timeline_column if timeline_column != null else turn_timeline
		if not _has_ancestor(hovered, timeline_root):
			_leave_scout()
			_hide_status_tip()
		return
	var coords := _coords_at_global(point)
	if coords.x < 0:
		_leave_scout()
		_hide_status_tip()
		return
	if _scouting() and (_is_approach_cell(coords) or _unit_at(coords) == _selected):
		return
	var unit := _unit_at(coords)
	if unit == null or _blocks_status_tip(unit):
		_hide_status_tip()


func _status_click_blocked() -> bool:
	if _opening or _campaign_over or _map_locked or _animating:
		return true
	if resolution_overlay != null and resolution_overlay.visible:
		return true
	if GameMenu.is_open():
		return true
	if mode_banner != null and mode_banner.visible:
		return true
	return false


## Picking an enemy to attack uses that click for the attack, so it must not open the inspect popup.
func _blocks_status_tip(unit: MechState) -> bool:
	if _confirming:
		return true
	return _targeting and (unit == null or unit.team == "enemy")


func _has_ancestor(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _coords_at_global(point: Vector2) -> Vector2i:
	for coords in _buttons:
		var button := _buttons[coords] as Control
		if button != null and button.get_global_rect().has_point(point):
			return coords
	return Vector2i(-1, -1)


func _open_status_tip(unit: MechState) -> void:
	if _status_click_blocked() or _blocks_status_tip(unit):
		_hide_status_tip()
		return
	_show_status_tip(unit)


func _show_status_tip(unit: MechState) -> void:
	if unit == null or stats_window == null or mech_panel == null:
		return
	if _status_unit != unit:
		_close_deck_overlay()
	_status_unit = unit
	stats_window.visible = true
	mech_panel.present_unit(unit, false)
	_place_status_tip()


func _hide_status_tip() -> void:
	_close_deck_overlay()
	_status_unit = null
	if stats_window != null:
		stats_window.visible = false


func _on_deck_pressed() -> void:
	if _status_unit == null or _status_unit.team != "player" or deck_overlay == null:
		return
	deck_overlay.open_for(_status_unit)


func _deck_overlay_open() -> bool:
	return deck_overlay != null and deck_overlay.is_open()


func _close_deck_overlay() -> void:
	if _deck_overlay_open():
		deck_overlay.close()


func _sync_status_tip() -> void:
	if stats_window == null:
		return
	if _confirming or _status_click_blocked():
		_hide_status_tip()
		return
	if _status_unit == null or not stats_window.visible:
		return
	if _targeting and _status_unit.team == "enemy":
		_hide_status_tip()
		return
	if _unit_at(_status_unit.overworld_position) != _status_unit:
		_hide_status_tip()
		return
	mech_panel.present_unit(_status_unit, false)
	_place_status_tip()


func _place_status_tip() -> void:
	if stats_window == null or not stats_window.visible or _status_unit == null:
		return
	if stats_window.size.y < 1.0:
		var minimum := stats_window.get_combined_minimum_size()
		stats_window.size = Vector2(maxf(380.0, minimum.x), stats_window.size.y)
		call_deferred("_anchor_status_tip")
		return
	_anchor_status_tip()


func _anchor_status_tip() -> void:
	const margin_x := 12.0
	const margin_bottom := 8.0
	if stats_window == null or not stats_window.visible or _status_unit == null:
		return
	var tip := stats_window.get_combined_minimum_size()
	tip.x = maxf(tip.x, 380.0)
	tip.y = maxf(tip.y, 104.0)
	stats_window.size = tip
	var bounds := get_global_rect()
	stats_window.global_position = Vector2(
		bounds.position.x + margin_x,
		bounds.end.y - margin_bottom - tip.y
	)


func _button_for_unit(unit: MechState) -> Button:
	if unit == null or not _buttons.has(unit.overworld_position):
		return null
	return _buttons[unit.overworld_position] as Button


func _on_cell_pressed(coords: Vector2i) -> void:
	if _opening or _campaign_over:
		return
	if _gesture_panned:
		_gesture_panned = false
		return
	if _confirming:
		return
	if _turn_busy or _animating:
		return
	var actor := _current_actor()
	var unit := _unit_at(coords)
	if _targeting:
		if unit != null and unit.alive and unit.team == "player":
			_targeting = false
			_selected = unit
			_open_status_tip(unit)
			_refresh()
			return
		_hide_status_tip()
		if unit == null or not unit.alive or unit.team != "enemy":
			_note_status("Select an enemy to attack.")
			return
		if actor == null or not _in_attack_range(actor, unit):
			_note_status("Get within range of %s before attacking." % unit.display_name)
			return
		_arm_attack(actor, unit)
		return
	if _scouting() and _is_approach_cell(coords):
		_pick_approach(coords)
		return
	if _scouting() and unit == _selected:
		_open_status_tip(unit)
		_refresh()
		return
	if _scouting():
		_selected = null
		_approach_from = APPROACH_NONE
		_approach_enemy_id = ""
		_hide_status_tip()
		if unit == null or not unit.alive:
			_refresh()
			return
	if unit != null and unit.alive:
		_selected = unit
		_open_status_tip(unit)
		_refresh()
		return
	if unit != null:
		return
	if StageMap.blocked(coords):
		_note_status("Rubble is blocking that cell.")
		return
	if actor == null or actor.team != "player" or not actor.alive:
		_note_status("Wait for your mech's turn.")
		return
	if _selected != actor:
		_note_status("It's %s's turn." % actor.display_name)
		return
	if actor.has_moved:
		_note_status("%s has already moved. End the turn, or attack." % actor.display_name)
		return
	var distances: Dictionary = OverworldAi.reachable(actor, GameManager.all_mechs(), GameManager.overworld_size())
	if not distances.has(coords):
		_note_status("%s can move %d cells." % [actor.display_name, actor.move_range])
		return
	_move_player_to(coords, distances)


func _on_cancel_pressed() -> void:
	var actor := _current_actor()
	if actor == null or actor.team != "player":
		return
	if not _confirming and not _targeting:
		return
	_targeting = false
	_clear_confirm()
	_selected = actor
	_refresh()


func _on_attack_pressed() -> void:
	if _opening or _campaign_over:
		return
	var actor := _current_actor()
	if _confirming:
		if actor != null and actor.team == "enemy":
			_commence_pressed = true
			return
		var target := _confirm_target
		_clear_confirm()
		_try_attack(target)
		return
	if _targeting:
		return
	if not _can_attack():
		return
	var enemies := _enemies_in_range(actor)
	if enemies.is_empty():
		return
	var chosen := _chosen_attack_target(enemies)
	if chosen == null:
		_targeting = true
		_selected = actor
		_hide_status_tip()
		_refresh()
		return
	_arm_attack(actor, chosen)


func _chosen_attack_target(enemies: Array[MechState]) -> MechState:
	if enemies.size() == 1:
		return enemies[0]
	if _selected != null and _selected.alive and _selected.team == "enemy" and enemies.has(_selected):
		return _selected
	return null


func _arm_attack(actor: MechState, target: MechState) -> void:
	_targeting = false
	_confirming = true
	_confirm_target = target
	_selected = actor
	_hide_status_tip()
	_refresh()


func _try_attack(unit: MechState) -> void:
	var actor := _current_actor()
	if unit == null or unit.team != "enemy" or not unit.alive or actor == null:
		_targeting = false
		_refresh()
		return
	if not _in_attack_range(actor, unit):
		_note_status("Get within range of %s before attacking." % unit.display_name)
		return
	if _undo_unit == actor:
		GameManager.note_move("player")
	_clear_undo()
	_targeting = false
	_animating = true
	actor.face_toward_x(actor.overworld_position.x, unit.overworld_position.x)
	_status_override = "%s attacks %s." % [actor.display_name, unit.display_name]
	_refresh()
	var step := unit.overworld_position - actor.overworld_position
	await _zoom_into(EncounterData.create(actor, step, GameManager.all_mechs()))


func _move_player_to(coords: Vector2i, distances: Dictionary) -> void:
	_animating = true
	_targeting = false
	_clear_confirm()
	_status_override = "%s is moving." % _selected.display_name
	_refresh()
	var mover := _selected
	var origin := mover.overworld_position
	var facing := mover.facing
	var path := OverworldAi.path_from_distances(origin, coords, distances)
	await _animate_move(mover, path)
	mover.has_moved = true
	if mover.overworld_position != origin:
		_undo_unit = mover
		_undo_origin = origin
		_undo_facing = facing
	_animating = false
	_status_override = ""
	_refresh()


func _on_end_turn() -> void:
	if _opening or _campaign_over or _turn_busy or _animating:
		return
	var actor := _current_actor()
	if actor == null or actor.team != "player":
		return
	_targeting = false
	_clear_confirm()
	_clear_undo()
	GameManager.battle_report = ""
	var already_ready := GameManager.attack_ready("player")
	GameManager.note_move("player")
	actor.has_moved = true
	if not already_ready and GameManager.attack_ready("player"):
		_refresh()
		return
	_advance_actor()
	await _begin_actor_turn()


func _map_zoom_floor() -> float:
	if grid == null or grid_host == null or grid.size.x <= 1.0 or grid_host.size.x <= 1.0:
		return MAP_ZOOM_MIN
	return minf(MAP_ZOOM_MIN, grid_host.size.x / grid.size.x)


func _overview_zoom() -> float:
	if grid.size.x <= 1.0 or grid.size.y <= 1.0:
		return 1.0
	return minf(grid_host.size.x / grid.size.x, grid_host.size.y / grid.size.y)


func _zoom_from_overview() -> Tween:
	if grid.size.x <= 1.0 or grid_host.size.y <= 1.0:
		_settle_intro_view()
		return null
	var from_zoom := _overview_zoom()
	var start_visual := grid.size * from_zoom
	var start_pos := (grid_host.size - start_visual) * 0.5
	_intro_holds_center = false
	_intro_tweening = true
	_map_zoom = from_zoom
	_map_pan = Vector2.ZERO
	_apply_map_view()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_place_intro_zoom.bind(from_zoom, start_pos), 0.0, 1.0, 1.05)
	return tween


func _settle_intro_view() -> void:
	_intro_holds_center = false
	_intro_tweening = false
	_map_zoom = 1.0
	_map_pan = (grid.size - grid_host.size) * 0.5
	_map_placed = true
	_apply_map_view()


func _place_intro_zoom(amount: float, from_zoom: float, start_pos: Vector2) -> void:
	_map_zoom = lerpf(from_zoom, 1.0, amount)
	var visual := grid.size * _map_zoom
	var pos := start_pos.lerp(Vector2.ZERO, amount)
	_map_pan = pos - (grid_host.size - visual) * 0.5
	_apply_map_view()


func _play_mission_start() -> void:
	var zoom_in := _zoom_from_overview()
	if mode_banner != null:
		await mode_banner.play("Mission start", true)
	if not is_inside_tree():
		return
	if dialogue_bar != null:
		await dialogue_bar.play(_briefing_lines())
	if not is_inside_tree():
		return
	if zoom_in != null and zoom_in.is_valid() and zoom_in.is_running():
		await zoom_in.finished
	if _intro_tweening:
		_settle_intro_view()


func _briefing_lines() -> Array[StoryLine]:
	var unit := _briefing_unit()
	var speaker := "Squad" if unit == null else unit.display_name
	var portrait := _pilot_portrait(unit)
	var lines: Array[StoryLine] = []
	lines.append(_brief(speaker, portrait, "Well that was fast. Citadel approaches. Their mechs are already on the streets."))
	lines.append(_brief(speaker, portrait, "Move beside one and the fight starts right there."))
	lines.append(_brief(speaker, portrait, "Fight as a squad, you'll be at a disadvantage if you attack alone."))
	lines.append(_brief(speaker, portrait, "Clear every hostile and this mission is done. Then we can head back to base."))
	return lines


func _briefing_unit() -> MechState:
	for unit in GameManager.player_mechs:
		if unit != null and unit.alive:
			return unit
	return null


func _pilot_portrait(unit: MechState) -> Texture2D:
	if unit == null or unit.art_id == "":
		return null
	var path := "res://art/mechs/player/%s/pilot.png" % unit.art_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _brief(speaker: String, portrait: Texture2D, text: String) -> StoryLine:
	var line := StoryLine.new()
	line.speaker = speaker
	line.text = text
	line.portrait = portrait
	return line


func _begin_actor_turn() -> void:
	if _opening or _turn_busy:
		return
	_prune_queue()
	var actor := _current_actor()
	if actor == null:
		_fill_round()
		actor = _current_actor()
	if actor == null:
		_refresh()
		return
	_selected = actor
	_targeting = false
	_clear_confirm()
	if actor.team == "enemy":
		await _run_one_enemy_turn(actor)
		return
	_refresh()


func _run_one_enemy_turn(enemy: MechState) -> void:
	_turn_busy = true
	_animating = true
	_selected = enemy
	if _adjacent_player(enemy) != null:
		if await _offer_enemy_attack(enemy):
			_turn_busy = false
			return
		if not is_inside_tree():
			return
		_animating = false
		_status_override = ""
		_turn_busy = false
		_advance_actor()
		await _begin_actor_turn()
		return
	_status_override = "%s is moving." % enemy.display_name
	_refresh()
	var plan: Dictionary = OverworldAi.plan_enemy_move(
		enemy,
		GameManager.all_mechs(),
		GameManager.overworld_size()
	)
	var path: Array[Vector2i] = []
	path.assign(plan["path"])
	await _animate_move(enemy, path)
	if not is_inside_tree():
		return
	if _adjacent_player(enemy) != null:
		if await _offer_enemy_attack(enemy):
			_turn_busy = false
			return
		if not is_inside_tree():
			return
		_animating = false
		_status_override = ""
		_turn_busy = false
		_advance_actor()
		await _begin_actor_turn()
		return
	await get_tree().create_timer(0.12).timeout
	_animating = false
	_status_override = ""
	_turn_busy = false
	_advance_actor()
	await _begin_actor_turn()


func _offer_enemy_attack(enemy: MechState) -> bool:
	var prey := _adjacent_player(enemy)
	if prey == null:
		return false
	_animating = false
	_confirming = true
	_confirm_target = prey
	_selected = enemy
	_status_override = ""
	_commence_pressed = false
	_refresh()
	while not _commence_pressed:
		if not is_inside_tree():
			return false
		await get_tree().process_frame
	var proceed := is_inside_tree()
	_commence_pressed = false
	_clear_confirm()
	if not proceed:
		return false
	_animating = true
	await _start_enemy_attack(enemy)
	return true


func _start_enemy_attack(enemy: MechState) -> void:
	var prey := _adjacent_player(enemy)
	if prey == null:
		return
	enemy.face_toward_x(enemy.overworld_position.x, prey.overworld_position.x)
	_status_override = "%s attacks %s." % [enemy.display_name, prey.display_name]
	_refresh()
	var step := prey.overworld_position - enemy.overworld_position
	await _zoom_into(EncounterData.create(enemy, step, GameManager.all_mechs()))


func _animate_move(unit: MechState, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not path.is_empty():
		unit.face_toward_x(unit.overworld_position.x, path[0].x)
	_moving_unit = unit
	var token := _make_token(unit)
	_refresh()
	_slide_token(token, unit.overworld_position)
	var points: Array[Vector2] = [_cell_global_position(unit.overworld_position)]
	for cell in path:
		points.append(_cell_global_position(cell))
	var tween := create_tween()
	var motion := tween.tween_method(
		_follow_path.bind(token, points, unit),
		0.0,
		1.0,
		STEP_SECONDS * path.size()
	)
	motion.set_trans(Tween.TRANS_CUBIC)
	motion.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	unit.overworld_position = path[path.size() - 1]
	_moving_unit = null
	token.queue_free()
	if is_inside_tree():
		_refresh()


func _close_battle() -> void:
	_animating = true
	if is_instance_valid(_battle_layer):
		_battle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fade := create_tween()
		fade.tween_property(_battle_layer, "modulate:a", 0.0, 0.2)
		await fade.finished
		if is_instance_valid(_battle_layer):
			_battle_layer.queue_free()
	_battle_layer = null
	_status_override = ""
	_refresh()
	grid.visible = true
	_set_chrome_alpha(1.0)
	await _zoom_out_to_map()
	if not is_inside_tree():
		return
	_animating = false
	_turn_busy = false
	_status_override = ""
	_refresh()
	if await _show_campaign_resolution():
		return
	_map_locked = false
	_advance_actor()
	await _begin_actor_turn()


func _living_count(roster: Array[MechState]) -> int:
	var count := 0
	for unit in roster:
		if unit != null and unit.alive:
			count += 1
	return count


func _show_campaign_resolution() -> bool:
	var players := _living_count(GameManager.player_mechs)
	var enemies := _living_count(GameManager.enemy_mechs)
	var players_wiped := _players_before_battle > 0 and players == 0
	var enemies_wiped := _enemies_before_battle > 0 and enemies == 0
	if not players_wiped and not enemies_wiped:
		return false
	_campaign_over = true
	_map_locked = true
	_clear_confirm()
	GameMenu.close()
	var won := enemies_wiped and not players_wiped
	if won and mode_banner != null:
		await mode_banner.play("Mission Complete", true)
		if not is_inside_tree():
			return true
	resolution_title.text = "Game over" if players_wiped else "End of Demo"
	resolution_overlay.visible = true
	return true


func _zoom_into(encounter: EncounterData) -> void:
	var cells := BattleDeployment.overworld_cells(
		encounter.attacker.overworld_position,
		encounter.encounter_location,
		GameManager.overworld_size()
	)
	GameManager.zoom_focus_cells = cells.duplicate()
	_map_locked = true
	_refresh()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_saved_map_zoom = _map_zoom
	_saved_map_pan = _map_pan
	_map_zoom = 1.0
	_map_pan = Vector2.ZERO
	_apply_map_view()
	var focus := _focus_point(cells)
	_zoom_origin_focus = focus
	_zoom_pivot_local = grid.get_global_transform().affine_inverse() * focus
	var cell_size := 48.0
	if not cells.is_empty() and _buttons.has(cells[0]):
		cell_size = maxf((_buttons[cells[0]] as Control).size.x, 1.0)
	var board := BattleDeployment.window_size(
		encounter.attacker.overworld_position,
		encounter.encounter_location
	)
	var fit_x := grid_host.size.x / (cell_size * float(board.x))
	var fit_y := grid_host.size.y / (cell_size * float(board.y))
	var target := clampf(minf(fit_x, fit_y), 1.5, 5.0)
	GameManager.overworld_cell_size = cell_size
	GameManager.battle_zoom_scale = target
	_set_chrome_alpha(0.0)
	_spawn_battle(encounter)
	var host_center := grid_host.get_global_rect().get_center()
	var tween := create_tween()
	var push := tween.tween_method(
		_place_zoomed_grid.bind(focus, host_center, 1.0, target),
		0.0,
		1.0,
		0.7
	)
	push.set_trans(Tween.TRANS_CUBIC)
	push.set_ease(Tween.EASE_IN_OUT)
	var fade := tween.parallel().tween_property(_battle_layer, "modulate:a", 1.0, 0.35)
	fade.set_delay(0.4)
	fade.set_trans(Tween.TRANS_CUBIC)
	fade.set_ease(Tween.EASE_OUT)
	var cover := tween.parallel().tween_callback(_cover_overworld_grid)
	cover.set_delay(0.4)
	await tween.finished


func _cover_overworld_grid() -> void:
	grid.visible = false
	for coords in _buttons:
		var button := _buttons[coords] as Button
		if button == null:
			continue
		var panel := button.get_node_or_null("BattleWindow") as CanvasItem
		if panel != null:
			panel.visible = false


func _spawn_battle(encounter: EncounterData) -> void:
	_players_before_battle = _living_count(GameManager.player_mechs)
	_enemies_before_battle = _living_count(GameManager.enemy_mechs)
	GameManager.begin_encounter(encounter)
	_battle_layer = load(GameManager.BATTLE_SCENE).instantiate()
	_battle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_layer.z_index = 30
	_battle_layer.modulate.a = 0.0
	add_child(_battle_layer)


func _zoom_out_to_map() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var host_center := grid_host.get_global_rect().get_center()
	var start_scale := grid.scale.x
	var tween := create_tween()
	var pull := tween.tween_method(
		_place_zoomed_grid.bind(host_center, _zoom_origin_focus, start_scale, 1.0),
		0.0,
		1.0,
		0.6
	)
	pull.set_trans(Tween.TRANS_CUBIC)
	pull.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_map_locked = false
	GameManager.zoom_focus_cells.clear()
	grid.scale = Vector2.ONE
	grid.pivot_offset = Vector2.ZERO
	_map_zoom = _saved_map_zoom
	_map_pan = _saved_map_pan
	_fit_grid()


func _place_zoomed_grid(amount: float, start_focus: Vector2, end_focus: Vector2, start_scale: float, end_scale: float) -> void:
	var zoom := lerpf(start_scale, end_scale, amount)
	var pivot := start_focus.lerp(end_focus, amount)
	grid.scale = Vector2(zoom, zoom)
	grid.global_position = pivot - _zoom_pivot_local * zoom


func _set_chrome_alpha(alpha: float) -> void:
	get_node("Layout/TopBar").modulate.a = alpha
	action_bar.modulate.a = alpha
	if alpha <= 0.0:
		_hide_status_tip()


func _focus_point(cells: Array[Vector2i]) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for coords in cells:
		if not _buttons.has(coords):
			continue
		var button := _buttons[coords] as Control
		sum += button.global_position + button.size * 0.5
		count += 1
	if count == 0:
		return grid_host.global_position + grid_host.size * 0.5
	return sum / float(count)


func _adjacent_player(unit: MechState) -> MechState:
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var other := _unit_at(unit.overworld_position + step)
		if other != null and other.alive and other.team == "player":
			return other
	return null


func _make_token(unit: MechState) -> Button:
	var token := CELL_SCENE.instantiate() as Button
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.z_index = 10
	var source: Button = _buttons[unit.overworld_position]
	token.size = source.size
	token.global_position = source.global_position
	add_child(token)
	token.resized.connect(_on_cell_resized.bind(token))
	_ensure_sprite(token)
	if not _show_unit_sprite(token, unit, true):
		token.text = unit.short_name
		_paint(token, unit.color)
	else:
		token.text = ""
		token.flat = true
		_paint(token, Color(0, 0, 0, 0))
	return token


func _follow_path(amount: float, token: Control, points: Array[Vector2], unit: MechState) -> void:
	if not is_instance_valid(token) or points.size() < 2:
		return
	var total := 0.0
	var lengths: Array[float] = []
	for index in range(1, points.size()):
		var length := points[index - 1].distance_to(points[index])
		lengths.append(length)
		total += length
	if total <= 0.0:
		token.global_position = points[points.size() - 1]
		return
	var traveled := clampf(amount, 0.0, 1.0) * total
	var walked := 0.0
	for index in lengths.size():
		var length := lengths[index]
		if walked + length >= traveled or index == lengths.size() - 1:
			var blend := 0.0 if length <= 0.0 else (traveled - walked) / length
			token.global_position = points[index].lerp(points[index + 1], clampf(blend, 0.0, 1.0))
			if unit != null:
				unit.face_toward_x(points[index].x, points[index + 1].x)
				var sprite := token.get_node_or_null("MechSprite") as AnimatedSprite2D
				if sprite != null:
					sprite.flip_h = unit.facing < 0
			return
		walked += length


func _slide_token(token: Control, coords: Vector2i) -> void:
	var source: Button = _buttons[coords]
	token.size = source.size
	token.global_position = source.global_position


func _cell_global_position(coords: Vector2i) -> Vector2:
	var source: Button = _buttons[coords]
	return source.global_position


func _in_attack_range(attacker: MechState, target: MechState) -> bool:
	var reach := 1 if attacker == null else maxi(attacker.attack_range, 1)
	return _within(attacker, target, reach)


func _within(a: MechState, b: MechState, reach: int) -> bool:
	if a == null or b == null:
		return false
	var delta := a.overworld_position - b.overworld_position
	var distance := absi(delta.x) + absi(delta.y)
	return distance > 0 and distance <= reach


func _unit_at(coords: Vector2i) -> MechState:
	for unit in GameManager.all_mechs():
		if unit.alive and unit.overworld_position == coords:
			return unit
	return null


func _ensure_sprite(button: Button) -> AnimatedSprite2D:
	return button.get_node_or_null("MechSprite") as AnimatedSprite2D


func _show_unit_sprite(button: Button, unit: MechState, focus: bool) -> bool:
	var sprite := _ensure_sprite(button)
	sprite.z_index = 4
	var frames := MechSprites.frames_for(unit.art_id)
	if frames == null:
		sprite.visible = false
		return false
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	sprite.flip_h = unit.facing < 0
	sprite.visible = true
	var shade := Color.WHITE
	if not unit.alive:
		shade = Color(0.35, 0.35, 0.35)
	elif unit.has_moved and unit != _current_actor():
		shade = Color(0.62, 0.62, 0.62)
	if _map_locked and not focus:
		shade = shade.darkened(0.65)
	sprite.modulate = shade
	_place_unit_sprite(button, sprite)
	_sync_barrier(sprite, unit)
	return true


func _on_cell_resized(button: Button) -> void:
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite != null and sprite.visible:
		_place_unit_sprite(button, sprite)
	_sync_approach_boxes()


func _place_unit_sprite(button: Button, sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or button.size.x < 1.0:
		return
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var frame := tex.get_size()
	var longest := maxf(frame.x, frame.y)
	if longest <= 0.0:
		return
	var fit := minf(button.size.x, button.size.y) * 0.9 * 1.5 / longest
	var lift := frame.y * fit * 0.1 + 6.0
	sprite.position = Vector2(button.size.x * 0.5, button.size.y * 0.5 - lift)
	sprite.scale = Vector2(fit, fit)


func _sync_barrier(sprite: AnimatedSprite2D, unit: MechState) -> void:
	var active := unit != null and unit.alive and unit.standing_guard > 0
	var barrier := sprite.get_node_or_null("Barrier") as BarrierProp
	if not active:
		if barrier != null:
			barrier.set_shown(false)
		return
	if barrier == null:
		barrier = BARRIER_SCENE.instantiate() as BarrierProp
		barrier.name = "Barrier"
	barrier.attach_to(sprite)
	barrier.set_shown(true)


func _paint(button: Button, color: Color, border: Color = Color(0, 0, 0, 0)) -> void:
	var style := _owned_button_style(button)
	style.bg_color = color
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color.WHITE)
	var frame := button.get_node_or_null("Frame") as Panel
	if frame == null:
		return
	var frame_style := _owned_panel_style(frame, "frame_style")
	frame_style.bg_color = Color(0, 0, 0, 0)
	if border.a > 0.0:
		frame_style.set_border_width_all(2)
		frame_style.border_color = border
	else:
		frame_style.set_border_width_all(0)


func _owned_button_style(button: Button) -> StyleBoxFlat:
	var style: StyleBoxFlat = button.get_meta("fill_style") as StyleBoxFlat if button.has_meta("fill_style") else null
	if style != null:
		return style
	style = (button.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	button.set_meta("fill_style", style)
	return style


func _owned_panel_style(panel: Panel, meta_name: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel.get_meta(meta_name) as StyleBoxFlat if panel.has_meta(meta_name) else null
	if style != null:
		return style
	style = (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta(meta_name, style)
	return style


func _can_undo() -> bool:
	var actor := _current_actor()
	return (
		_undo_unit != null
		and actor == _undo_unit
		and actor.alive
		and actor.team == "player"
		and actor.has_moved
		and not _opening
		and not _animating
		and not _turn_busy
		and not _map_locked
		and not _targeting
	)


func _on_undo_move() -> void:
	if not _can_undo():
		return
	var unit := _undo_unit
	unit.overworld_position = _undo_origin
	unit.facing = _undo_facing
	unit.has_moved = false
	_clear_undo()
	_selected = unit
	_refresh()


func _clear_undo() -> void:
	_undo_unit = null


func _paint_cell_mark(button: Button, unit: MechState) -> void:
	var mark := button.get_node_or_null("CellMark") as CellMark
	if mark == null:
		return
	var actor := _current_actor()
	if _targeting and unit != null and unit.alive and unit.team == "enemy" and _in_attack_range(actor, unit):
		mark.show_reticule(SELECT_RED)
		return
	var picked := unit != null and unit == _selected and unit.alive and not _map_locked
	if picked:
		mark.show_reticule(SELECT_BLUE if unit.team == "player" else SELECT_RED)
	else:
		mark.show_reticule(Color(0, 0, 0, 0))


func _selection_color(unit: MechState) -> Color:
	var color := SELECT_BLUE if unit.team == "player" else SELECT_RED
	color.a = 0.34
	return color


func _range_color(unit: MechState) -> Color:
	var color := SELECT_BLUE if unit.team == "player" else SELECT_RED
	color.a = 0.45
	return color


## Enemies the selected mech can attack. Before the move, that includes anyone
## reachable from a square they can still walk to. After the move, only who is in range now.
func _threat_cells(actor: MechState, show_reach: bool) -> Dictionary:
	var marked := {}
	if show_reach and _selected != null and _selected.alive and _selected.team == "player" and not _selected.has_moved:
		_mark_threats(_selected, marked, true)
	elif not show_reach and _shows_standing_threats(actor):
		_mark_threats(actor, marked, false)
	return marked


func _mark_threats(mover: MechState, marked: Dictionary, from_moves: bool) -> void:
	if not from_moves:
		for enemy in _enemies_in_range(mover):
			marked[enemy.overworld_position] = true
		return
	var reach := maxi(mover.attack_range, 1)
	var origin := mover.overworld_position
	var distances: Dictionary = OverworldAi.reachable(mover, GameManager.all_mechs(), GameManager.overworld_size())
	for enemy in GameManager.all_mechs():
		if enemy == null or not enemy.alive or enemy.team != "enemy":
			continue
		if _can_attack_after_move(origin, enemy.overworld_position, reach, distances):
			marked[enemy.overworld_position] = true


func _can_attack_after_move(origin: Vector2i, enemy_pos: Vector2i, reach: int, distances: Dictionary) -> bool:
	var here := absi(origin.x - enemy_pos.x) + absi(origin.y - enemy_pos.y)
	if here > 0 and here <= reach:
		return true
	for raw in distances:
		var cell: Vector2i = raw
		if int(distances[cell]) <= 0:
			continue
		var occupant := _unit_at(cell)
		if occupant != null and occupant.alive:
			continue
		var distance := absi(cell.x - enemy_pos.x) + absi(cell.y - enemy_pos.y)
		if distance > 0 and distance <= reach:
			return true
	return false


func _shows_standing_threats(actor: MechState) -> bool:
	return (
		actor != null
		and actor.alive
		and actor.team == "player"
		and actor.has_moved
		and not _targeting
		and not _confirming
		and not _map_locked
		and not _animating
		and not _turn_busy
		and not _opening
	)


func _sync_selection_pulse(actor: MechState) -> void:
	if actor == null or not actor.alive or actor.team != "player" or _map_locked or _confirming:
		_stop_selection_pulse()
		return
	if _shown_fight_roster().has(actor):
		_stop_selection_pulse()
		return
	var button: Button = _buttons.get(actor.overworld_position) as Button
	var shade := button.get_node_or_null("Shade") as ColorRect if button != null else null
	if shade == null:
		_stop_selection_pulse()
		return
	if (
		_select_id == actor.id
		and _select_shade == shade
		and _select_pulse != null
		and _select_pulse.is_valid()
		and _select_pulse.is_running()
	):
		return
	_stop_selection_pulse()
	_select_id = actor.id
	_select_shade = shade
	var base := SELECT_BLUE
	shade.color = Color(base.r, base.g, base.b, 0.38)
	_select_pulse = create_tween()
	_select_pulse.set_loops()
	_select_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_pulse.tween_property(shade, "color:a", 0.1, 0.45)
	_select_pulse.tween_property(shade, "color:a", 0.42, 0.45)


func _stop_selection_pulse() -> void:
	if _select_pulse != null and _select_pulse.is_valid():
		_select_pulse.kill()
	_select_pulse = null
	_select_shade = null
	_select_id = ""


func _set_shade(button: Button, color: Color) -> void:
	var shade := button.get_node_or_null("Shade") as ColorRect
	if shade == null:
		return
	var actor := _current_actor()
	var still_pulsing: bool = (
		shade == _select_shade
		and actor != null
		and _buttons.get(actor.overworld_position) == button
		and _select_pulse != null
		and _select_pulse.is_valid()
		and _select_pulse.is_running()
	)
	if still_pulsing:
		return
	if (
		_engage_shades.has(shade)
		and _engage_pulse != null
		and _engage_pulse.is_valid()
		and _engage_pulse.is_running()
	):
		return
	shade.color = color
