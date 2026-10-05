extends Control


## Played cards tick each enemy's own turn count. The battle ends after this many rounds.
const ROUND_LIMIT := 2
const ENEMY_ATTACK_DELAY := 1.5
## One allied mech draws 3, two draw 4, three draw 5.
const HAND_BASE := 2
const HAND_CAP := 5
const CARD_SIZE := Vector2(176, 268)
const STACK_PIECE := Vector2(176, 56)
const CARD_SLIDE_TIME := 0.24
const CARD_STAGGER := MechCard.DEAL_STAGGER
const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const CELL_SCENE := preload("res://scenes/battle/battle_cell.tscn")
const FLOAT_SCENE := preload("res://scenes/ui/float_number.tscn")
const SLOT_SCENE := preload("res://scenes/ui/empty_card_slot.tscn")
const BARRIER_SCENE: PackedScene = preload("res://scenes/props/barrier.tscn")
const GUARD_COLOR := Color(0.45, 0.78, 1.0)
const DAMAGE_COLOR := Color(1.0, 0.32, 0.28)
const FLOAT_RISE := 72.0
const FLOAT_TIME := 0.82
const ACTIVATE_TEXT := "Activate Overdrive"

var _attack_offered := false
var _squad_fill: StyleBoxFlat
var _activate_flash: Tween
var _overdrive_pulse: Tween
var _overdrive_glow := 0.2
var _active_cell_style: StyleBoxFlat
var _active_cell_pulse: Tween

var state: BattleState
var _closing := false
var _selected: MechState
var _status_unit: MechState
var _chosen: CardData
var _targeting := false
var _play_step := ""
var _followup_move := false
var _moved_for_card := false
var _move_targets: Dictionary = {}
var _animating := false
var _buttons: Dictionary = {}
var _deck: Array[CardData] = []
## Each mech's overdrive card. Counted in the deck, dealt only after Overdrive starts.
var _specials: Array[CardData] = []
var _special_ids := {}
var _hand: Array[CardData] = []
var _discard: Array[CardData] = []
var _owner: Dictionary = {}
var _card_views: Dictionary = {}
var _deck_discards: Array[CardData] = []
var _pile_view := ""
var _hand_layout_pending := false
var _hand_layout_tries := 0
var _played_a_card := false
## Discard pile size when this player turn's hand was dealt. A larger pile means a card left the hand.
var _discard_at_turn := 0
var _prompting := false
var _opened: Dictionary = {}
var _results_reason := ""

@onready var grid_host: Control = %GridHost
@onready var grid: GridContainer = %Grid
@onready var mech_panel: MechPanel = $StatsWindow/StatsMargin/Actions
@onready var stats_window: PanelContainer = %StatsWindow
@onready var battle_log: RichTextLabel = %BattleLog
@onready var discard_pile: PanelContainer = %DiscardPile
@onready var discard_label: Label = %DiscardLabel
@onready var deck_pile: PanelContainer = %DeckPile
@onready var deck_count: Label = %DeckCount
@onready var discard_overlay: Control = %DiscardOverlay
@onready var discard_scroll: ScrollContainer = %DiscardScroll
@onready var discard_list: GridContainer = %DiscardList
@onready var discard_close: Button = %DiscardClose
@onready var skip_button: Button = %SkipButton
@onready var hand_box: HBoxContainer = %Hand
@onready var player_gauge: ProgressBar = %PlayerGauge
@onready var activate_button: Button = %ActivateButton
@onready var round_label: Label = %Title
@onready var mode_banner: ModeBanner = %ModeBanner
@onready var finisher_banner: FinisherBanner = %FinisherBanner
@onready var results: BattleResults = %BattleResults
@onready var hand_prompt: HandPrompt = %HandPrompt
@onready var _info_note: InfoNote = %SpecialNote


func _ready() -> void:
	skip_button.pressed.connect(_on_end_turn)
	discard_pile.gui_input.connect(_on_discard_pile_input)
	deck_pile.gui_input.connect(_on_deck_pile_input)
	discard_close.pressed.connect(_close_discard_view)
	activate_button.pressed.connect(_on_activate_pressed)
	results.confirmed.connect(_on_results_confirmed)
	hand_prompt.new_hand_chosen.connect(_on_new_hand_chosen)
	hand_prompt.end_turn_chosen.connect(_on_confirm_end_turn)
	hand_prompt.dismissed.connect(_close_hand_prompt)
	grid_host.resized.connect(_fit_grid)
	_style_end_turn()
	_style_pile(discard_pile)
	_style_pile(deck_pile)
	_style_squad_gauge()
	_style_discard_close()
	_setup_battle()
	_build_grid()
	_log_opening()
	_refresh()
	await GameManager.wait_until_shown()
	if not is_inside_tree() or state == null:
		return
	if state.battle_status == "active":
		_animating = true
		_refresh()
		await _wait_until_faded_in()
		if not is_inside_tree() or state == null or _closing:
			return
		await _announce_round()
	if not is_inside_tree() or state == null or _closing:
		return
	if state.phase == "enemy" and state.battle_status == "active":
		await _finish_enemy_side(false)


func _style_end_turn() -> void:
	skip_button.text = "End round"
	skip_button.custom_minimum_size = Vector2(0, STACK_PIECE.y)
	skip_button.size_flags_horizontal = Control.SIZE_FILL
	skip_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_button.add_theme_font_size_override("font_size", 22)
	skip_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


func _style_pile(pile: PanelContainer, hot := false) -> void:
	if pile == null:
		return
	pile.remove_theme_stylebox_override("panel")
	pile.theme_type_variation = &"PileHot" if hot else &"Pile"


func _style_discard_close() -> void:
	discard_close.text = "X"
	discard_close.custom_minimum_size = Vector2(56, 56)


func _log_opening() -> void:
	if state == null:
		return
	_log("Overdrive attack." if GameManager.battle_offense else "Standard attack.")
	_log("Round %d." % state.turn)
	if state.phase == "player":
		_log("Your turn.")


func _log(line: String) -> void:
	if battle_log == null:
		return
	var text := line.strip_edges()
	if text == "":
		return
	if battle_log.get_parsed_text().strip_edges() == "":
		battle_log.text = text
	else:
		battle_log.append_text("\n" + text)


func _refresh_discard() -> void:
	if discard_label != null:
		discard_label.text = str(_discard.size())
	if deck_count != null:
		deck_count.text = str(_deck.size() + _specials.size())


func _on_discard_pile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_pile_view("discard")
		discard_pile.accept_event()


func _on_deck_pile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_pile_view("deck")
		deck_pile.accept_event()


func _open_pile_view(kind: String) -> void:
	if discard_overlay.visible and _pile_view == kind:
		return
	_pile_view = kind
	if _info_note != null:
		_info_note.dismiss()
	var title := discard_overlay.get_node_or_null("Margin/Body/Header/Title") as Label
	if title != null:
		title.text = "Deck" if kind == "deck" else "Discard"
	discard_overlay.visible = true
	await get_tree().process_frame
	if not is_inside_tree() or not discard_overlay.visible:
		return
	_fill_discard_list()


func _close_discard_view() -> void:
	if _info_note != null:
		_info_note.dismiss()
	discard_overlay.visible = false
	_pile_view = ""
	for child in discard_list.get_children():
		child.queue_free()


func _fill_discard_list() -> void:
	for child in discard_list.get_children():
		child.queue_free()
	var width := discard_scroll.size.x
	if width < CARD_SIZE.x:
		width = 1100.0
	var stride := CARD_SIZE.x + 16.0
	discard_list.columns = maxi(1, int((width + 16.0) / stride))
	var cards := _deck_listing() if _pile_view == "deck" else _discard_listing()
	for card in cards:
		if card == null:
			continue
		var holder := _owner_of(card)
		var stroke := MechCard.stroke_for(holder.data if holder != null else null)
		var view := CARD_SCENE.instantiate() as MechCard
		view.custom_minimum_size = CARD_SIZE
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		discard_list.add_child(view)
		_present_card(view, card, stroke)
		_shine_if_special(view, card)
		_silence_mouse(view)


func _discard_listing() -> Array[CardData]:
	var cards: Array[CardData] = []
	for index in range(_discard.size() - 1, -1, -1):
		var card := _discard[index] as CardData
		if card != null:
			cards.append(card)
	return cards


## Cards still in the pile, including overdrive cards that have not been dealt.
## Listed by name so opening the deck does not show the next draw.
func _deck_listing() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card in _deck:
		if card != null:
			cards.append(card)
	for card in _specials:
		if card != null:
			cards.append(card)
	cards.sort_custom(_card_name_before)
	return cards


func _card_name_before(a: CardData, b: CardData) -> bool:
	var left := "" if a == null else a.display_name
	var right := "" if b == null else b.display_name
	return left < right


func _silence_mouse(node: Node) -> void:
	var control := node as Control
	if control != null and not UiIcons.keeps_mouse(control):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_silence_mouse(child)


func _setup_battle() -> void:
	var encounter := GameManager.current_encounter
	state = BattleState.new()
	var battle_board := BattleDeployment.grid_size(encounter)
	state.grid = BattleGrid.create(battle_board.x, battle_board.y)
	state.units = encounter.participants.duplicate()
	state.positions = BattleDeployment.place(encounter, state.grid)
	var attacker := encounter.attacker
	state.initiative = "enemy" if attacker != null and attacker.team == "enemy" else "player"
	state.phase = state.initiative
	state.sync_occupants()
	_arm_enemy_turns()
	_remember_opening()
	_build_deck()


func _remember_opening() -> void:
	_opened.clear()
	for unit in state.units:
		if unit == null:
			continue
		_opened[unit.id] = {
			"hp": unit.hp,
			"guard": unit.guard,
			"standing": unit.standing_guard,
		}


func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	_buttons.clear()
	grid.columns = state.grid.width
	for y in state.grid.height:
		for x in state.grid.width:
			var coords := Vector2i(x, y)
			var button := CELL_SCENE.instantiate() as Button
			button.pressed.connect(_on_cell_pressed.bind(coords))
			button.resized.connect(_on_cell_resized.bind(button))
			grid.add_child(button)
			_buttons[coords] = button
	_fit_grid()


func _fit_grid() -> void:
	if state == null or state.grid == null:
		return
	var columns := state.grid.width
	var rows := state.grid.height
	if columns <= 0 or rows <= 0 or grid_host.size.x <= 1.0 or grid_host.size.y <= 1.0:
		return
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	var pad := 8.0
	var cell_w := (grid_host.size.x - pad * 2.0 - h_sep * (columns - 1)) / float(columns)
	var cell_h := (grid_host.size.y - pad * 2.0 - v_sep * (rows - 1)) / float(rows)
	var cell := floorf(minf(cell_w, cell_h))
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
	var board_size := grid_size + Vector2(pad * 2.0, pad * 2.0)
	var origin := (grid_host.size - board_size) * 0.5
	origin.x = maxf(origin.x, 0.0)
	origin.y = maxf(origin.y, 0.0)
	var board := grid.get_parent().get_node_or_null("Board") as ColorRect
	if board != null:
		@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
		board.layout_mode = 0
		board.position = origin
		board.size = board_size
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	grid.layout_mode = 0
	grid.position = origin + Vector2(pad, pad)
	grid.size = grid_size
	_stamp_terrain(cell)
	call_deferred("_place_status_tip")


func _refresh() -> void:
	if GameManager.current_encounter == null or state == null:
		return
	var player_phase := state.battle_status == "active" and state.phase == "player" and not _animating
	skip_button.disabled = not player_phase or _moved_for_card or _prompting
	_sync_status_tip()
	if state.phase == "player" and not _animating:
		_pull_specials()
	_rebuild_move_targets()
	var active_marked := false
	for coords in _buttons:
		var button: Button = _buttons[coords]
		var unit := _unit_at(coords)
		var sprite := button.get_node("MechSprite") as AnimatedSprite2D
		var caption := button.get_node("Caption") as Label
		_show_turn_count(button, unit)
		_show_hit_points(button, unit)
		_show_barrier(button, unit)
		_show_guard(button, unit)
		if unit != null and unit.art_id != "" and _show_mech_sprite(sprite, unit):
			button.text = ""
			caption.visible = false
			caption.text = ""
			_place_sprite(button, sprite)
			_paint(button, _cell_color(coords))
			_paint_cell_mark(button, coords, unit)
		elif unit == null:
			_hide_mech_sprite(sprite, caption)
			button.text = ""
			_paint(button, _cell_color(coords))
			_paint_cell_mark(button, coords, null)
		else:
			_hide_mech_sprite(sprite, caption)
			button.text = ""
			_paint(button, _cell_color(coords))
			_paint_cell_mark(button, coords, unit)
		_sync_overdrive_cell(button, unit)
		if _is_active_unit(unit):
			active_marked = true
	if not active_marked:
		_stop_active_cell_pulse()
	_refresh_hand()
	_refresh_discard()
	_refresh_round()
	_refresh_squad_gauge()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _status_click_blocked():
		_hide_status_tip()
		return
	if stats_window != null and stats_window.visible and stats_window.get_global_rect().has_point(mouse.global_position):
		return
	var coords := _coords_at_global(mouse.global_position)
	if coords.x < 0:
		_hide_status_tip()
		return
	var unit := _unit_at(coords) if state != null else null
	if unit == null:
		_hide_status_tip()
		return
	_show_status_tip(unit)


func _status_click_blocked() -> bool:
	if results != null and results.visible:
		return true
	if hand_prompt != null and hand_prompt.visible:
		return true
	if discard_overlay != null and discard_overlay.visible:
		return true
	if mode_banner != null and mode_banner.visible:
		return true
	if _chosen != null:
		return true
	return false


func _coords_at_global(point: Vector2) -> Vector2i:
	for coords in _buttons:
		var button := _buttons[coords] as Control
		if button != null and button.get_global_rect().has_point(point):
			return coords
	return Vector2i(-1, -1)


func _show_status_tip(unit: MechState) -> void:
	if unit == null or stats_window == null or mech_panel == null:
		return
	_status_unit = unit
	stats_window.visible = true
	mech_panel.present_unit(unit, false)
	_place_status_tip()


func _hide_status_tip() -> void:
	_status_unit = null
	if stats_window != null:
		stats_window.visible = false


func _sync_status_tip() -> void:
	if _chosen != null:
		_hide_status_tip()
		return
	if _status_unit == null or stats_window == null or not stats_window.visible:
		return
	if state == null or state.unit_by_id(_status_unit.id) == null:
		_hide_status_tip()
		return
	mech_panel.present_unit(_status_unit, false)
	_place_status_tip()


func _place_status_tip() -> void:
	if stats_window == null or not stats_window.visible or _status_unit == null or state == null:
		return
	call_deferred("_anchor_status_tip")


func _anchor_status_tip() -> void:
	const inset := 8.0
	if stats_window == null or not stats_window.visible or _status_unit == null or state == null:
		return
	var button := _button_for(_status_unit)
	if button == null:
		return
	var tip := stats_window.get_combined_minimum_size()
	tip.x = maxf(tip.x, 1.0)
	tip.y = maxf(tip.y, 104.0)
	stats_window.size = tip
	var map := _battle_map_rect()
	var top_left := Vector2(map.position.x + inset, map.position.y + inset)
	var top_right := Vector2(map.end.x - inset - tip.x, map.position.y + inset)
	var covers_unit := Rect2(top_left, tip).intersects(button.get_global_rect())
	var place := top_right if covers_unit else top_left
	var bounds := get_global_rect()
	place.x = clampf(place.x, bounds.position.x + inset, maxf(bounds.position.x + inset, bounds.end.x - tip.x - inset))
	place.y = clampf(place.y, bounds.position.y + inset, maxf(bounds.position.y + inset, bounds.end.y - tip.y - inset))
	stats_window.global_position = place


func _battle_map_rect() -> Rect2:
	var board := grid.get_parent().get_node_or_null("Board") as Control
	if board != null and board.size.x > 1.0 and board.size.y > 1.0:
		return board.get_global_rect()
	return grid_host.get_global_rect()


func _on_cell_pressed(coords: Vector2i) -> void:
	if _animating or _prompting or state.battle_status != "active" or state.phase != "player":
		return
	var unit := _unit_at(coords)
	if _targeting:
		if _play_step == "guard":
			await _on_guard_cell(unit)
			return
		if _play_step == "move":
			await _on_move_cell(coords)
			return
		if _play_step == "front":
			await _try_front(coords)
			return
		if unit != null and unit.alive and unit.team == "player":
			if _moved_for_card:
				return
			if unit != _selected:
				_chosen = null
				_play_step = ""
			_targeting = false
			_selected = unit
			_refresh()
			return
		await _try_attack(unit)
		return
	if unit != null and unit.alive:
		if unit == _selected:
			_selected = null
		else:
			_chosen = null
			_targeting = false
			_selected = unit
		_refresh()
		return
	_selected = null
	_refresh()


func _try_attack(target: MechState) -> void:
	_targeting = false
	var card := _chosen
	_chosen = null
	if card == null or card.card_type != "Attack":
		_log("Choose an attack card.")
		_refresh()
		return
	if target == null or target.team != "enemy" or not target.alive:
		_clear_play()
		_selected = null
		_refresh()
		return
	var attacker := _owner_of(card)
	if attacker == null or not attacker.alive:
		_log("That mech can't act.")
		_refresh()
		return
	_selected = attacker
	var attacker_pos := state.position_of(attacker)
	var target_pos := state.position_of(target)
	if not _in_strike_range(attacker_pos, target_pos, card):
		if card.exact_range:
			_log("%s only hits at exactly %d cells." % [card.display_name, card.reach])
		else:
			_log("Target is out of range.")
		_chosen = card
		_targeting = true
		_refresh()
		return
	attacker.face_toward_x(attacker_pos.x, target_pos.x)
	_animating = true
	_play_step = ""
	_log("%s uses %s." % [attacker.display_name, card.display_name])
	_spend(card)
	_refresh()
	var finishing := _is_winning_blow(attacker, [target], card)
	if finishing:
		await _play_finisher(attacker)
		if not is_inside_tree() or state == null:
			return
		await _play_attack(_sprite_for(attacker), _button_for(target))
		if not is_inside_tree() or state == null:
			return
	var result := _strike(attacker, target, card)
	if not finishing:
		await _play_attack(_sprite_for(attacker), _button_for(_struck(result, target)))
	if not is_inside_tree() or state == null:
		return
	_moved_for_card = false
	state.sync_occupants()
	state.check_outcome()
	_animating = false
	_log(_hit_notice(_selected, _struck(result, target), result))
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_finish_if_over()
	if _closing or state == null or state.battle_status != "active":
		_clear_play()
		_refresh()
		return
	if not attacker.alive:
		_clear_play()
		await _after_card_played()
		return
	if card.moves_after():
		_followup_move = true
		_play_step = "move"
		_targeting = true
		_chosen = card
		_refresh()
		return
	_clear_play()
	await _after_card_played()
	if _closing or state == null or state.battle_status != "active":
		return
	if _next_ready_player() == null and not _guard_waiting():
		await _complete_player_side()
		return
	_refresh()


func _try_front(coords: Vector2i) -> void:
	var card := _chosen
	if card == null or not card.hits_front():
		_clear_play()
		_refresh()
		return
	var attacker := _owner_of(card)
	if attacker == null or not attacker.alive:
		_log("That mech can't act.")
		_refresh()
		return
	var origin := state.position_of(attacker)
	var direction := 0
	if _front_cells(origin, 1).has(coords):
		direction = 1
	elif _front_cells(origin, -1).has(coords):
		direction = -1
	if direction == 0:
		var unit := _unit_at(coords)
		if unit != null and unit.alive and unit.team == "player" and unit != attacker:
			_clear_play()
			_selected = unit
			_refresh()
			return
		_log("Point %s left or right." % card.display_name)
		_refresh()
		return
	var fan := _front_cells(origin, direction)
	var victims: Array[MechState] = []
	for cell in fan:
		var unit := _unit_at(cell)
		if unit != null and unit.alive:
			victims.append(unit)
	attacker.face_toward_x(float(origin.x), float(origin.x + direction))
	_selected = attacker
	_animating = true
	_targeting = false
	_play_step = ""
	_log("%s uses %s." % [attacker.display_name, card.display_name])
	_spend(card)
	_refresh()
	var finishing := _is_winning_blow(attacker, victims, card)
	if finishing:
		await _play_finisher(attacker)
		if not is_inside_tree() or state == null:
			return
		await _play_area(_sprite_for(attacker), fan)
		if not is_inside_tree() or state == null:
			return
	if victims.is_empty():
		_log("%s hits no one." % card.display_name)
	for unit in victims:
		if not attacker.alive:
			break
		if not unit.alive:
			continue
		var result := _strike(attacker, unit, card)
		_log(_hit_notice(attacker, _struck(result, unit), result))
	if not finishing:
		await _play_area(_sprite_for(attacker), fan)
	if not is_inside_tree():
		return
	state.sync_occupants()
	state.check_outcome()
	_animating = false
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_finish_if_over()
	if _closing or state == null or state.battle_status != "active":
		_clear_play()
		_refresh()
		return
	_clear_play()
	await _after_card_played()
	if _closing or state == null or state.battle_status != "active":
		return
	if _next_ready_player() == null and not _guard_waiting():
		await _complete_player_side()
		return
	_refresh()


func _front_cells(origin: Vector2i, direction: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ahead := origin + Vector2i(direction, 0)
	for rise in [-1, 0, 1]:
		var spot := ahead + Vector2i(0, rise)
		if state.grid.in_bounds(spot):
			cells.append(spot)
	return cells


func _on_end_turn() -> void:
	if _animating or _moved_for_card or _prompting:
		return
	if _offer_unused_hand() and hand_prompt != null:
		_open_hand_prompt()
		return
	await _finish_player_turn()


func _on_new_hand_chosen() -> void:
	if _animating or _moved_for_card:
		_close_hand_prompt()
		return
	_close_hand_prompt()
	_replace_hand()
	await _finish_player_turn()


func _on_confirm_end_turn() -> void:
	if _animating or _moved_for_card:
		_close_hand_prompt()
		return
	_close_hand_prompt()
	await _finish_player_turn()


## Round 2 ends the battle, so the unused-hand choice only exists on round 1.
func _offer_unused_hand() -> bool:
	return state != null and state.turn < ROUND_LIMIT and not _cards_were_used()


## A spent card, a pitched card, a readied dodge, or a card still being aimed all count as used.
func _cards_were_used() -> bool:
	return (
		_played_a_card
		or _chosen != null
		or _followup_move
		or _discard.size() > _discard_at_turn
	)


func _remember_turn_hand() -> void:
	_played_a_card = false
	_discard_at_turn = _discard.size()


func _open_hand_prompt() -> void:
	_prompting = true
	_clear_play()
	_hide_status_tip()
	if discard_overlay != null and discard_overlay.visible:
		_close_discard_view()
	hand_prompt.open()
	_refresh()


func _close_hand_prompt() -> void:
	_prompting = false
	if hand_prompt != null:
		hand_prompt.close()


func _replace_hand() -> void:
	_clear_play()
	_selected = null
	var pitched: Array[CardData] = _hand.duplicate()
	_hand.clear()
	for card in pitched:
		_discard.append(card)
	_log("Drew a new hand.")
	_draw_up()
	_remember_turn_hand()
	_refresh()


func _finish_player_turn() -> void:
	var played := _followup_move
	_clear_play()
	_selected = null
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	if played:
		await _after_card_played()
		if _closing or state == null or state.battle_status != "active":
			return
	await _after_card_played()
	if _closing or state == null or state.battle_status != "active":
		return
	await _complete_player_side()


func _complete_player_side() -> void:
	_targeting = false
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	if state.turn >= ROUND_LIMIT:
		_refresh()
		_finish_if_over(true)
		return
	_advance_round()
	state.phase = "player"
	state.active_unit_id = ""
	_log("Your turn.")
	_refresh()
	await _announce_round()


func _next_ready_player() -> MechState:
	for unit in _battle_order():
		if unit.team != "player" or not unit.alive:
			continue
		if state.attacked.get(unit.id, false):
			continue
		return unit
	return null


func _finish_enemy_side(advance_round: bool) -> void:
	_animating = true
	state.phase = "enemy"
	_log("Enemy phase.")
	_refresh()
	await _execute_enemy_phase()
	_animating = false
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	if advance_round:
		if state.turn >= ROUND_LIMIT:
			_refresh()
			_finish_if_over(true)
			return
		_advance_round()
	else:
		_draw_up()
	_remember_turn_hand()
	state.phase = "player"
	state.active_unit_id = ""
	_log("Your turn.")
	_refresh()
	if advance_round:
		await _announce_round()


func _execute_enemy_phase() -> void:
	await _act_enemies(_by_speed(state.living_units("enemy")), false)


func _arm_enemy_turns() -> void:
	for unit in state.units:
		if unit != null and unit.team == "enemy":
			unit.cards_until_turn = maxi(unit.turn_count, 1)


## One step on every enemy clock. A played card does this, and so does ending the round.
func _after_card_played() -> void:
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	var due: Array[MechState] = []
	for enemy in state.living_units("enemy"):
		enemy.cards_until_turn = maxi(enemy.cards_until_turn - 1, 0)
		if enemy.cards_until_turn <= 0:
			due.append(enemy)
	if due.is_empty():
		_refresh()
		return
	_animating = true
	state.phase = "enemy"
	_refresh()
	await _act_enemies(_by_speed(due), true)
	_animating = false
	if not is_inside_tree() or state == null:
		return
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	state.phase = "player"
	state.active_unit_id = ""
	_refresh()


func _act_enemies(enemies: Array[MechState], recharge: bool) -> void:
	for enemy in enemies:
		if not is_inside_tree() or state == null or state.battle_status != "active":
			break
		if not enemy.alive:
			continue
		state.active_unit_id = enemy.id
		if recharge:
			_log("%s acts." % enemy.display_name)
		var strike := MechDecks.strike_card(enemy.data)
		var target := EnemyAi.act(enemy, state, strike)
		_refresh()
		if target != null and state.battle_status == "active":
			await get_tree().create_timer(ENEMY_ATTACK_DELAY).timeout
			if not is_inside_tree() or state == null or state.battle_status != "active":
				break
			if not enemy.alive:
				state.active_unit_id = ""
				continue
			var result := _strike(enemy, target, strike)
			await _play_attack(_sprite_for(enemy), _button_for(_struck(result, target)))
			if not is_inside_tree() or state == null:
				return
			state.sync_occupants()
			state.check_outcome()
			_log(_hit_notice(enemy, _struck(result, target), result))
		if enemy.alive and state != null and state.battle_status == "active":
			if recharge:
				enemy.cards_until_turn = maxi(enemy.turn_count, 1)
			else:
				_note_acted(enemy)
		state.active_unit_id = ""
		_refresh()
	if state != null:
		state.active_unit_id = ""


func _finish_if_over(round_limit := false) -> void:
	if _closing or state == null:
		return
	if state.battle_status == "active" and not round_limit:
		return
	_closing = true
	_targeting = false
	_clear_play()
	if activate_button != null:
		activate_button.visible = false
		_stop_activate_flash()
	_stop_overdrive_pulse()
	_stop_active_cell_pulse()
	if discard_overlay != null:
		discard_overlay.visible = false
	_close_hand_prompt()
	_hide_status_tip()
	var reason := ""
	if round_limit:
		reason = "Battle ended after %d rounds." % ROUND_LIMIT
		_log(reason)
	elif state.battle_status == "victory":
		_log("Victory.")
	elif state.battle_status == "defeat":
		_log("Defeat.")
	_results_reason = reason
	_show_results()


func _show_results() -> void:
	var outcome := "Victory"
	if _results_reason != "":
		outcome = "Time"
	elif state != null and state.battle_status == "defeat":
		outcome = "Defeat"
	results.present(state.units, _opened, outcome)


func _on_results_confirmed() -> void:
	if GameManager.phase != GameManager.Phase.BATTLE:
		return
	var battle_positions := {}
	if state != null:
		battle_positions = state.positions.duplicate()
	GameManager.finish_battle(_results_reason, battle_positions)


func _unit_at(coords: Vector2i) -> MechState:
	var occupant_id := state.grid.occupant_at(coords)
	if occupant_id == "":
		return null
	return state.unit_by_id(occupant_id)


func _clear_play() -> void:
	_targeting = false
	_play_step = ""
	_followup_move = false
	_moved_for_card = false
	_chosen = null
	_move_targets.clear()


func _on_move_cell(coords: Vector2i) -> void:
	if _animating or _chosen == null or _selected == null:
		return
	var actor := _selected
	var origin := state.position_of(actor)
	if coords == origin:
		if _followup_move:
			await _finish_followup()
		elif _chosen.moves_only():
			_clear_play()
			_refresh()
		elif _chosen.target_type == "enemies" and _chosen.moves_before():
			if _can_strike_from(origin, _chosen):
				await _play_breach(actor, _chosen)
		elif _steps_before_guard(_chosen):
			if _guard_targets(actor).is_empty():
				_log("No adjacent ally.")
			else:
				_play_step = "guard"
				_refresh()
		elif _can_strike_from(origin, _chosen):
			_play_step = "attack"
			_refresh()
		return
	var unit := _unit_at(coords)
	if unit != null and unit.alive and unit.team == "enemy" and _chosen.moves_before() and not _followup_move:
		if _chosen.target_type == "enemies":
			return
		await _close_and_strike(unit)
		return
	if not _move_targets.has(coords):
		_clear_play()
		_selected = null
		_refresh()
		return
	if not await _commit_step(actor, coords):
		return
	if _chosen != null and _chosen.target_type == "enemies" and _chosen.moves_before():
		await _play_breach(actor, _chosen)
		return
	if _chosen != null and _steps_before_guard(_chosen):
		_moved_for_card = true
		_play_step = "guard"
		_targeting = true
		_refresh()
		return
	if _chosen != null and _chosen.moves_only():
		var stepped := _chosen
		_spend(stepped)
		_log("%s uses %s." % [actor.display_name, stepped.display_name])
		await _finish_followup()
		return
	if _followup_move:
		await _finish_followup()
		return
	_moved_for_card = true
	_play_step = "attack"
	_refresh()


func _close_and_strike(target: MechState) -> void:
	if _chosen == null or _selected == null or target == null:
		return
	var origin := state.position_of(_selected)
	var target_pos := state.position_of(target)
	if not _in_strike_range(origin, target_pos, _chosen):
		if not _enemy_in_reach(target):
			_log("Can't reach %s." % target.display_name)
			return
		var landing := _best_landing(target_pos, _chosen)
		if landing.x < 0:
			_log("Can't reach %s." % target.display_name)
			return
		if not await _commit_step(_selected, landing):
			if is_inside_tree():
				_log("Can't reach %s." % target.display_name)
			return
		_moved_for_card = true
	_play_step = "attack"
	await _try_attack(target)


func _commit_step(actor: MechState, coords: Vector2i) -> bool:
	_animating = true
	var moved := await _slide_unit(actor, coords)
	if not is_inside_tree():
		return false
	_animating = false
	return moved


func _finish_followup() -> void:
	_clear_play()
	await _after_card_played()
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	if _next_ready_player() == null and not _guard_waiting():
		await _complete_player_side()
		return
	_refresh()


func _rebuild_move_targets() -> void:
	_move_targets.clear()
	if _play_step != "move" or _chosen == null or _selected == null:
		return
	var origin := state.position_of(_selected)
	for coords in _reachable(origin, _chosen.movement):
		if _steps_before_guard(_chosen):
			if not _allies_beside(coords, _selected).is_empty():
				_move_targets[coords] = true
		elif _followup_move or not _chosen.moves_before():
			_move_targets[coords] = true
		elif _can_strike_from(coords, _chosen):
			_move_targets[coords] = true


func _can_strike_from(coords: Vector2i, card: CardData) -> bool:
	for enemy in state.living_units("enemy"):
		if _in_strike_range(coords, state.position_of(enemy), card):
			return true
	return false


func _in_strike_range(from_pos: Vector2i, to_pos: Vector2i, card: CardData) -> bool:
	if card == null:
		return false
	return card.reaches(_manhattan(from_pos, to_pos))


func _enemy_in_reach(enemy: MechState) -> bool:
	if enemy == null or _chosen == null or _selected == null:
		return false
	var enemy_pos := state.position_of(enemy)
	if _in_strike_range(state.position_of(_selected), enemy_pos, _chosen):
		return true
	for key in _move_targets:
		if _in_strike_range(key as Vector2i, enemy_pos, _chosen):
			return true
	return false


func _best_landing(enemy_pos: Vector2i, card: CardData) -> Vector2i:
	var origin := state.position_of(_selected)
	var best := Vector2i(-1, -1)
	var best_steps := 999999
	var best_gap := 999999
	for key in _move_targets:
		var coords := key as Vector2i
		if not _in_strike_range(coords, enemy_pos, card):
			continue
		var steps := _path_between(origin, coords, card.movement).size()
		if steps <= 0:
			continue
		var gap := _manhattan(coords, enemy_pos)
		if steps < best_steps or (steps == best_steps and gap < best_gap):
			best = coords
			best_steps = steps
			best_gap = gap
	return best


func _reachable(origin: Vector2i, steps: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if steps <= 0:
		return found
	var seen := {origin: true}
	var frontier: Array[Vector2i] = [origin]
	for _i in steps:
		var next: Array[Vector2i] = []
		for cell in frontier:
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var neighbor: Vector2i = cell + (step as Vector2i)
				if seen.has(neighbor):
					continue
				if not state.grid.in_bounds(neighbor) or state.grid.impassable(neighbor):
					continue
				var occupied := state.grid.occupant_at(neighbor) != ""
				seen[neighbor] = true
				if not occupied:
					found.append(neighbor)
				next.append(neighbor)
		frontier = next
	return found


func _path_between(origin: Vector2i, dest: Vector2i, steps: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if origin == dest or steps <= 0:
		return path
	var parents := {}
	var seen := {origin: true}
	var frontier: Array[Vector2i] = [origin]
	var found := false
	for _i in steps:
		var next: Array[Vector2i] = []
		for cell in frontier:
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var neighbor: Vector2i = cell + (step as Vector2i)
				if seen.has(neighbor):
					continue
				if not state.grid.in_bounds(neighbor) or state.grid.impassable(neighbor):
					continue
				var occupied := state.grid.occupant_at(neighbor) != ""
				if occupied and neighbor == dest:
					continue
				seen[neighbor] = true
				parents[neighbor] = cell
				if neighbor == dest:
					found = true
					break
				next.append(neighbor)
			if found:
				break
		if found:
			break
		frontier = next
	if not found:
		return path
	var cursor: Vector2i = dest
	while cursor != origin:
		path.push_front(cursor)
		cursor = parents[cursor] as Vector2i
	return path


func _slide_unit(unit: MechState, dest: Vector2i) -> bool:
	var origin := state.position_of(unit)
	var path := _path_between(origin, dest, _chosen.movement if _chosen != null else 1)
	if path.is_empty():
		return false
	var from_button := _buttons.get(origin) as Button
	var sprite: AnimatedSprite2D = null
	if from_button != null:
		sprite = from_button.get_node_or_null("MechSprite") as AnimatedSprite2D
	var token: AnimatedSprite2D = null
	if sprite != null:
		token = AnimatedSprite2D.new()
		token.sprite_frames = sprite.sprite_frames
		token.centered = true
		token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		token.z_index = 30
		token.scale = sprite.scale
		token.flip_h = sprite.flip_h
		if token.sprite_frames != null and token.sprite_frames.has_animation("idle"):
			token.play("idle")
		add_child(token)
		token.global_position = sprite.global_position
		_sync_barrier(token, unit)
		sprite.visible = false
	var previous := origin
	for cell in path:
		unit.face_toward_x(previous.x, cell.x)
		if token != null:
			token.flip_h = unit.facing < 0
			var button := _buttons.get(cell) as Button
			if button != null:
				var goal := button.global_position + Vector2(button.size.x * 0.5, button.size.y * 0.44)
				var tween := create_tween()
				tween.tween_property(token, "global_position", goal, 0.14)
				await tween.finished
		previous = cell
	if token != null:
		token.queue_free()
	state.move_unit(unit, dest)
	_log("%s moves." % unit.display_name)
	return true


func _cell_color(coords: Vector2i) -> Color:
	var idle := Color(0.14, 0.16, 0.2)
	if _play_step == "guard" and _chosen != null and _chosen.guards_ally():
		var holder := _owner_of(_chosen)
		for ally in _guard_targets(holder):
			if state.position_of(ally) == coords:
				return Color(0.16, 0.4, 0.68)
		return idle
	if _selected == null or state.battle_status != "active":
		return idle
	if _play_step == "move" and _move_targets.has(coords):
		return Color(0.16, 0.46, 0.78)
	if not _targeting or _chosen == null:
		return idle
	if _play_step == "move" and _chosen.moves_before() and not _followup_move:
		var unit := _unit_at(coords)
		if unit != null and unit.alive and unit.team == "enemy" and _enemy_in_reach(unit):
			return Color(0.45, 0.18, 0.18)
		return idle
	if _play_step == "attack":
		var current := state.position_of(_selected)
		if _chosen.reaches(_manhattan(current, coords)):
			return Color(0.45, 0.18, 0.18)
	if _play_step == "front":
		var origin := state.position_of(_selected)
		if _front_cells(origin, 1).has(coords) or _front_cells(origin, -1).has(coords):
			return Color(0.45, 0.18, 0.18)
	return idle


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _show_mech_sprite(sprite: AnimatedSprite2D, unit: MechState) -> bool:
	var frames := MechSprites.frames_for(unit.art_id)
	if frames == null:
		sprite.visible = false
		_sync_barrier(sprite, null)
		return false
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	sprite.flip_h = unit.facing < 0
	sprite.visible = true
	sprite.modulate = Color.WHITE if unit.alive else Color(0.35, 0.35, 0.35)
	_sync_barrier(sprite, unit)
	return true


func _button_for(unit: MechState) -> Button:
	if unit == null:
		return null
	return _buttons.get(state.position_of(unit)) as Button


func _sprite_for(unit: MechState) -> AnimatedSprite2D:
	var button := _button_for(unit)
	if button == null:
		return null
	return button.get_node_or_null("MechSprite") as AnimatedSprite2D


func _play_attack(attacker: AnimatedSprite2D, target_button: Button) -> void:
	var waits: Array[AnimatedSprite2D] = []
	if attacker != null and attacker.sprite_frames != null and attacker.sprite_frames.has_animation("attack"):
		attacker.play("attack")
		waits.append(attacker)
	var flash := _begin_hit_flash(target_button)
	var flash_done: Array = [flash == null]
	if flash != null:
		flash.finished.connect(func() -> void:
			flash_done[0] = true
		)
	var impact := _begin_impact(target_button)
	if impact != null:
		impact.play("impact")
		waits.append(impact)
	await _wait_for_sprites(waits)
	while not flash_done[0]:
		await get_tree().process_frame
	if is_instance_valid(attacker) and attacker.sprite_frames != null and attacker.sprite_frames.has_animation("idle"):
		if attacker.animation == "attack":
			attacker.play("idle")
	if is_instance_valid(impact):
		impact.visible = false


func _play_area(attacker: AnimatedSprite2D, cells: Array[Vector2i]) -> void:
	var waits: Array[AnimatedSprite2D] = []
	if attacker != null and attacker.sprite_frames != null and attacker.sprite_frames.has_animation("attack"):
		attacker.play("attack")
		waits.append(attacker)
	var flashes: Array[Tween] = []
	var impacts: Array[AnimatedSprite2D] = []
	for coords in cells:
		var button := _buttons.get(coords) as Button
		var flash := _begin_hit_flash(button)
		if flash != null:
			flashes.append(flash)
		var impact := _begin_impact(button)
		if impact != null:
			impact.play("impact")
			waits.append(impact)
			impacts.append(impact)
	await _wait_for_sprites(waits)
	var running := true
	while running:
		running = false
		for flash in flashes:
			if flash != null and flash.is_valid() and flash.is_running():
				running = true
				break
		if running:
			await get_tree().process_frame
	if is_instance_valid(attacker) and attacker.sprite_frames != null and attacker.sprite_frames.has_animation("idle"):
		if attacker.animation == "attack":
			attacker.play("idle")
	for impact in impacts:
		if is_instance_valid(impact):
			impact.visible = false


func _begin_hit_flash(button: Button) -> Tween:
	if button == null or not is_instance_valid(button):
		return null
	var flashes := 1
	if button.has_meta("hit_flash"):
		flashes = int(button.get_meta("hit_flash")) + 1
	button.set_meta("hit_flash", flashes)
	var glow := button.get_node_or_null("OverdriveGlow") as ColorRect
	if glow != null:
		glow.visible = false
	var lit := Color(0.95, 0.62, 0.62)
	var dim := Color(0.14, 0.16, 0.2)
	var tween := create_tween()
	tween.tween_callback(_paint_hit_flash.bind(button, lit))
	tween.tween_interval(0.12)
	tween.tween_callback(_paint_hit_flash.bind(button, dim))
	tween.tween_interval(0.08)
	tween.tween_callback(_paint_hit_flash.bind(button, lit))
	tween.tween_interval(0.12)
	tween.tween_callback(_paint_hit_flash.bind(button, dim))
	tween.tween_callback(_end_hit_flash.bind(button))
	return tween


func _paint_hit_flash(button: Button, color: Color) -> void:
	if is_instance_valid(button):
		_paint(button, color)


func _end_hit_flash(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var flashes := int(button.get_meta("hit_flash", 1)) - 1
	if flashes > 0:
		button.set_meta("hit_flash", flashes)
		return
	if button.has_meta("hit_flash"):
		button.remove_meta("hit_flash")
	_sync_overdrive_cell(button, _unit_on_button(button))


func _begin_impact(button: Button) -> AnimatedSprite2D:
	var frames := MechSprites.impact_frames()
	if button == null or frames == null:
		return null
	var impact := button.get_node_or_null("ImpactSprite") as AnimatedSprite2D
	if impact == null:
		return null
	impact.sprite_frames = frames
	var mech_sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if mech_sprite != null:
		impact.position = mech_sprite.position
		impact.scale = mech_sprite.scale
	impact.visible = true
	return impact


func _wait_for_sprites(sprites: Array[AnimatedSprite2D]) -> void:
	if sprites.is_empty():
		return
	var remaining := [sprites.size()]
	for sprite in sprites:
		sprite.animation_finished.connect(func() -> void:
			remaining[0] -= 1
		, CONNECT_ONE_SHOT)
	while remaining[0] > 0:
		await get_tree().process_frame


func _hide_mech_sprite(sprite: AnimatedSprite2D, caption: Label) -> void:
	sprite.visible = false
	caption.visible = false
	caption.text = ""


func _on_cell_resized(button: Button) -> void:
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite != null and sprite.visible:
		_place_sprite(button, sprite)


func _place_sprite(button: Button, sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or button.size.x < 1.0:
		return
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var frame := tex.get_size()
	var longest := maxf(frame.x, frame.y)
	if longest <= 0.0:
		return
	sprite.position = Vector2(button.size.x * 0.5, button.size.y * 0.44)
	var fit := minf(button.size.x, button.size.y) * 0.72 / longest
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


func _build_deck() -> void:
	_deck.clear()
	_specials.clear()
	_special_ids.clear()
	_hand.clear()
	_discard.clear()
	_owner.clear()
	_card_views.clear()
	var pile: Array[CardData] = []
	for unit in state.units:
		if unit.team != "player" or unit.data == null:
			continue
		var deck := MechDecks.for_mech(unit.data)
		if deck == null:
			continue
		for card in deck.cards:
			if card == null:
				continue
			_owner[card.get_instance_id()] = unit
			if card.is_special:
				_specials.append(card)
				_special_ids[card.get_instance_id()] = true
			else:
				pile.append(card)
	pile.shuffle()
	_deck = pile
	# An enemy who forced the fight attacks before the player is dealt a hand.
	if state == null or state.phase != "enemy":
		_draw_up()
	_remember_turn_hand()


## Fill open hand slots from the overdrive pile. No-op until Overdrive is on.
func _pull_specials() -> void:
	if not GameManager.battle_offense or _specials.is_empty():
		return
	if state == null or state.battle_status != "active":
		return
	while _hand.size() < _hand_limit() and not _specials.is_empty():
		var card := _specials.pop_back() as CardData
		if card == null:
			continue
		var holder := _owner_of(card)
		if holder == null or not holder.alive:
			_discard.append(card)
			_deck_discards.append(card)
			continue
		_hand.append(card)


func _hand_limit() -> int:
	if state == null:
		return HAND_CAP
	var count := 0
	for unit in state.units:
		if unit != null and unit.alive and unit.team == "player":
			count += 1
	if count <= 0:
		return 0
	return mini(HAND_CAP, count + HAND_BASE)


func _draw_up() -> void:
	_pull_specials()
	while _hand.size() < _hand_limit() and not _deck.is_empty():
		var card := _deck.pop_back() as CardData
		if card != null:
			_hand.append(card)
	_layout_hand()


func _advance_round() -> void:
	state.turn += 1
	_log("Round %d." % state.turn)
	state.reset_round_actions()
	_chosen = null
	_targeting = false
	_draw_up()
	_remember_turn_hand()


func _note_acted(unit: MechState) -> void:
	if unit == null:
		return
	state.mark_attacked(unit)


func _owner_of(card: CardData) -> MechState:
	if card == null:
		return null
	return _owner.get(card.get_instance_id()) as MechState


func _on_card_drop(global_pos: Vector2, released: bool, card: CardData, view: MechCard) -> bool:
	var over := (
		_can_drop_discard()
		and discard_pile != null
		and discard_pile.get_global_rect().has_point(global_pos)
	)
	if discard_pile != null:
		_style_pile(discard_pile, over and not released)
	if is_instance_valid(view):
		var pitch := over and GameManager.player_attack_gauge < GameManager.player_attack_max
		view.set_discard_preview(over)
		view.set_gauge_pitch_visible(pitch)
	if not released or not over:
		return false
	_commit_discard(card, view)
	return true


func _can_drop_discard() -> bool:
	return (
		state != null
		and state.battle_status == "active"
		and state.phase == "player"
		and not _animating
		and not _prompting
		and not _moved_for_card
		and not _followup_move
	)


func _commit_discard(card: CardData, view: MechCard) -> void:
	if card == null or view == null or not is_instance_valid(view):
		return
	if _hand.find(card) < 0:
		return
	if _chosen == card:
		_clear_play()
	_card_views.erase(card.get_instance_id())
	_hand.erase(card)
	_discard.append(card)
	_played_a_card = true
	_pull_specials()
	var gained := GameManager.charge_from_pitch()
	view.set_gauge_pitch_visible(gained)
	_log("Discarded %s." % card.display_name)
	_launch_discard(view, 0.0)
	_refresh()


func _on_activate_pressed() -> void:
	if _closing or _prompting or GameManager.battle_offense or not GameManager.attack_ready("player"):
		return
	GameManager.battle_offense = true
	_log("Overdrive attack.")
	_specials.shuffle()
	_pull_specials()
	_layout_hand()
	_repaint_hand()
	_play_overdrive_waves()
	_refresh()
	mode_banner.play("Overdrive mode", true)


func _note_squad_loss() -> void:
	var fit := GameManager.refit_squad_gauge()
	if fit.get("shrunk", false):
		_log(
			"Squad gauge is now %d/%d."
			% [GameManager.player_attack_gauge, GameManager.player_attack_max]
		)


func _repaint_hand() -> void:
	for card in _hand:
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null or not is_instance_valid(view):
			continue
		var holder := _owner_of(card)
		var stroke := MechCard.stroke_for(holder.data if holder != null else null)
		_present_card(view, card, stroke)


func _play_overdrive_waves() -> void:
	for card in _hand:
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null or not is_instance_valid(view):
			continue
		if view.has_attack():
			view.play_overdrive_wave()


func _style_squad_gauge() -> void:
	_squad_fill = OverdriveGauge.claim_fill(player_gauge)
	OverdriveGauge.dress(player_gauge)
	if player_gauge != null:
		player_gauge.custom_minimum_size.y = STACK_PIECE.y
		var face := player_gauge.get_parent() as Control
		if face != null:
			face.custom_minimum_size.y = STACK_PIECE.y
	_style_activate_button()


## The round stripe is on a CanvasLayer, so it ignores the fade that brings the board in.
func _wait_until_faded_in() -> void:
	while is_inside_tree() and modulate.a < 0.98:
		await get_tree().process_frame


func _announce_round() -> void:
	if mode_banner == null or state == null or _closing:
		return
	_hide_status_tip()
	_animating = true
	_refresh()
	await mode_banner.play("Round %d/%d" % [state.turn, ROUND_LIMIT], true, true)
	if not is_inside_tree():
		return
	_animating = false
	if not _closing and state != null and state.battle_status == "active":
		_refresh()


func _refresh_round() -> void:
	if round_label == null or state == null:
		return
	round_label.text = "Round %d/%d" % [state.turn, ROUND_LIMIT]


func _style_activate_button() -> void:
	if activate_button == null:
		return
	activate_button.text = ACTIVATE_TEXT
	activate_button.add_theme_font_size_override("font_size", OverdriveGauge.TEXT_SIZE)
	AccentPulse.clear(activate_button)


func _start_activate_flash() -> void:
	if _activate_flash != null and _activate_flash.is_valid() and _activate_flash.is_running():
		return
	_activate_flash = AccentPulse.start(self, activate_button)


func _stop_activate_flash() -> void:
	if _activate_flash != null and _activate_flash.is_valid():
		_activate_flash.kill()
	_activate_flash = null
	AccentPulse.clear(activate_button)


func _refresh_squad_gauge() -> void:
	if player_gauge == null:
		return
	var squad_max := GameManager.player_attack_max
	var squad_charge := mini(GameManager.player_attack_gauge, squad_max)
	player_gauge.max_value = squad_max
	player_gauge.value = squad_charge
	OverdriveGauge.write(player_gauge, squad_charge, squad_max)
	OverdriveGauge.pulse(player_gauge, _squad_fill, squad_max > 0 and squad_charge >= squad_max)
	var can_activate := (
		not _closing
		and not _prompting
		and state != null
		and state.battle_status == "active"
		and not GameManager.battle_offense
		and GameManager.attack_ready("player")
	)
	if activate_button != null:
		activate_button.visible = can_activate
		if can_activate:
			_start_activate_flash()
			if not _attack_offered:
				_attack_offered = true
				_log("Gauge full.")
		else:
			_stop_activate_flash()
			_attack_offered = false


func _fly_card_into_pile(
	view: MechCard,
	start_center: Vector2,
	start_scale: Vector2,
	start_rot: float,
	delay: float = 0.0
) -> void:
	if not is_instance_valid(view) or discard_pile == null:
		if is_instance_valid(view):
			view.queue_free()
		return
	var end_center := discard_pile.get_global_rect().get_center()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(
		_place_discard_flight.bind(view, start_center, end_center, start_scale, start_rot),
		0.0,
		1.0,
		0.32
	).set_delay(delay)
	tween.tween_callback(func() -> void:
		if is_instance_valid(view):
			view.queue_free()
	)


func _place_discard_flight(
	t: float,
	view: MechCard,
	start_center: Vector2,
	end_center: Vector2,
	start_scale: Vector2,
	start_rot: float
) -> void:
	if not is_instance_valid(view):
		return
	var center := start_center.lerp(end_center, t)
	view.scale = start_scale.lerp(Vector2(0.12, 0.12), t)
	view.rotation = lerpf(start_rot, 0.0, t)
	view.modulate.a = 1.0 - smoothstep(0.62, 1.0, t)
	var current: Vector2 = view.get_global_transform() * (view.size * 0.5)
	view.global_position += center - current


func _spend(card: CardData) -> void:
	if card == null:
		return
	_played_a_card = true
	var index := _hand.find(card)
	if index >= 0:
		_hand.remove_at(index)
		_discard.append(card)
		_pull_specials()
		_layout_hand()


func _take_dodge(unit: MechState) -> CardData:
	if unit == null or unit.team != "player":
		return null
	for index in _hand.size():
		var card := _hand[index] as CardData
		if card != null and card.is_dodge() and _owner_of(card) == unit:
			_hand.remove_at(index)
			_discard.append(card)
			_layout_hand()
			return card
	return null


func _is_winning_blow(attacker: MechState, targets: Array, card: CardData) -> bool:
	if state == null or attacker == null or attacker.team != "player" or card == null:
		return false
	var living := state.living_units("enemy")
	if living.is_empty():
		return false
	var doomed := {}
	for entry in targets:
		var enemy := entry as MechState
		if enemy == null or enemy.team != "enemy" or not enemy.alive:
			continue
		if CombatResolver.would_destroy(attacker, enemy, card):
			doomed[enemy.id] = true
	for enemy in living:
		if not doomed.has(enemy.id):
			return false
	return true


func _play_finisher(attacker: MechState) -> void:
	if finisher_banner == null or attacker == null:
		return
	await finisher_banner.play(attacker)


func _show_finisher_kill() -> void:
	_refresh()
	if is_inside_tree():
		await get_tree().create_timer(0.45).timeout


func _strike(attacker: MechState, defender: MechState, card: CardData) -> Dictionary:
	var catcher := _interceptor_for(defender)
	if catcher != null:
		catcher.intercepting = false
		_log("%s catches the hit meant for %s." % [catcher.display_name, defender.display_name])
		defender = catcher
	var result := CombatResolver.resolve_attack(attacker, defender, card, _take_dodge(defender))
	result["struck"] = defender
	_show_strike_numbers(defender, result)
	if result.get("destroyed", false):
		_discard_unit_cards(defender)
		if defender.team == "player":
			_note_squad_loss()
	return result


func _struck(result: Dictionary, fallback: MechState) -> MechState:
	var struck := result.get("struck") as MechState
	return struck if struck != null else fallback


func _interceptor_for(defender: MechState) -> MechState:
	if defender == null or not defender.alive or defender.team != "player" or state == null:
		return null
	var defender_pos := state.position_of(defender)
	for unit in state.living_units("player"):
		if unit == defender or not unit.intercepting:
			continue
		if _manhattan(state.position_of(unit), defender_pos) == 1:
			return unit
	return null


func _discard_unit_cards(unit: MechState) -> void:
	if unit == null:
		return
	var moved := 0
	var kept_deck: Array[CardData] = []
	for card in _deck:
		if _owner_of(card) == unit:
			_discard.append(card)
			_deck_discards.append(card)
			moved += 1
		else:
			kept_deck.append(card)
	_deck = kept_deck
	var kept_specials: Array[CardData] = []
	for card in _specials:
		if _owner_of(card) == unit:
			_discard.append(card)
			_deck_discards.append(card)
			moved += 1
		else:
			kept_specials.append(card)
	_specials = kept_specials
	var kept_hand: Array[CardData] = []
	for card in _hand:
		if _owner_of(card) == unit:
			_discard.append(card)
			moved += 1
		else:
			kept_hand.append(card)
	_hand = kept_hand
	if moved == 0:
		return
	if _chosen != null and _owner_of(_chosen) == unit:
		_clear_play()
	_log("Discarded %s's cards." % unit.display_name)
	_layout_hand()
	if discard_overlay != null and discard_overlay.visible:
		_fill_discard_list()


func _hit_notice(attacker: MechState, defender: MechState, result: Dictionary) -> String:
	if result.get("destroyed", false):
		return "%s destroyed %s." % [attacker.display_name, defender.display_name]
	var kind := str(result.get("defense_kind", ""))
	var defense_name := str(result.get("defense_name", ""))
	var dealt := int(result.get("damage", 0))
	if kind == "Dodge":
		return "%s used %s and dodged the attack." % [defender.display_name, defense_name]
	var blocked := int(result.get("blocked", 0))
	var shield := _shield_name(int(result.get("from_guard", 0)), int(result.get("from_barrier", 0)))
	if blocked > 0 and dealt <= 0:
		return "%s's %s absorbed the attack." % [defender.display_name, shield]
	if blocked > 0:
		return "%s's %s blocked %d. %s hit for %d." % [defender.display_name, shield, blocked, attacker.display_name, dealt]
	return "%s hit %s for %d." % [attacker.display_name, defender.display_name, dealt]


func _shield_name(from_guard: int, from_barrier: int) -> String:
	if from_guard > 0 and from_barrier > 0:
		return "guard and barrier"
	if from_barrier > 0:
		return "barrier"
	return "guard"


## Lost health floats in red. Guard gained, or a hit soaked by guard or barrier, floats in blue.
func _show_strike_numbers(unit: MechState, result: Dictionary) -> void:
	if unit == null:
		return
	if str(result.get("defense_kind", "")) == "Dodge":
		_float_number(unit, "DODGE", Color(0.86, 0.95, 1.0), 0)
		return
	var dealt := int(result.get("damage", 0))
	var blocked := int(result.get("blocked", 0))
	var stacked := dealt > 0 and blocked > 0
	if dealt > 0:
		_float_number(unit, "-%d" % dealt, DAMAGE_COLOR, 0)
	if blocked > 0:
		_float_number(unit, "-%d" % blocked, GUARD_COLOR, 1 if stacked else 0)


func _show_guard_gain(unit: MechState, amount: int) -> void:
	if unit == null or amount <= 0:
		return
	_float_number(unit, "+%d" % amount, GUARD_COLOR, 0)


func _float_number(unit: MechState, text: String, color: Color, slot: int) -> void:
	var button := _button_for(unit)
	if button == null or not is_instance_valid(button):
		return
	var anchor := button.get_global_rect().get_center()
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite != null and sprite.visible:
		anchor = sprite.global_position
		anchor.y -= _sprite_reach(sprite)
	var label := FLOAT_SCENE.instantiate() as Label
	label.text = text
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var box := label.get_combined_minimum_size()
	if box.x < 1.0 or box.y < 1.0:
		box = Vector2(72, 48)
	label.size = box
	label.pivot_offset = box * 0.5
	anchor.y += float(slot) * box.y * 0.9
	label.global_position = anchor - box * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE, FLOAT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.34).set_delay(FLOAT_TIME - 0.34)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)


func _sprite_reach(sprite: AnimatedSprite2D) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 28.0
	var anim := "idle"
	if sprite.animation != &"":
		anim = String(sprite.animation)
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if not sprite.sprite_frames.has_animation(anim):
		return 28.0
	var tex := sprite.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return 28.0
	return tex.get_height() * absf(sprite.scale.y) * 0.42


func _on_hand_card_pressed(card: CardData) -> void:
	if _animating or _prompting or _followup_move or _moved_for_card:
		return
	if state == null or state.battle_status != "active" or state.phase != "player":
		return
	if card.is_dodge():
		_played_a_card = true
		_log("%s stays in hand and dodges the next attack on its mech." % card.display_name)
		_refresh()
		return
	if card.moves_only():
		_begin_move(card)
		return
	if _steps_before_guard(card):
		_begin_step_then_guard(card)
		return
	if card.target_type == "squad" or card.target_type == "team" or card.target_type == "enemies" or card.hits_front():
		await _play_special(card)
		return
	if card.is_guard():
		await _begin_guard(card)
		return
	if card.card_type != "Attack":
		_log("%s isn't coded yet." % card.display_name)
		_refresh()
		return
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_log("That mech can't act.")
		_refresh()
		return
	_selected = holder
	if _chosen == card and _targeting:
		_clear_play()
	else:
		_chosen = card
		_targeting = true
		if card.hits_front():
			_play_step = "front"
		else:
			_play_step = "move" if card.moves_before() else "attack"
	_refresh()


func _steps_before_guard(card: CardData) -> bool:
	return card != null and card.guards_ally() and card.movement > 0 and card.move_timing == "Before"


func _allies_beside(origin: Vector2i, holder: MechState) -> Array[MechState]:
	var found: Array[MechState] = []
	if holder == null or state == null:
		return found
	for unit in state.living_units("player"):
		if unit == holder:
			continue
		if _manhattan(origin, state.position_of(unit)) == 1:
			found.append(unit)
	return found


func _begin_breach_step(holder: MechState, card: CardData) -> void:
	_selected = holder
	if _chosen == card and _play_step == "move":
		_clear_play()
		_refresh()
		return
	_chosen = card
	_targeting = true
	_play_step = "move"
	_refresh()
	if _move_targets.is_empty() and not _can_strike_from(state.position_of(holder), card):
		_log("Can't reach an enemy.")
		_clear_play()
		_refresh()


func _begin_step_then_guard(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_log("That mech can't act.")
		_refresh()
		return
	_selected = holder
	if _chosen == card and _play_step == "move":
		_clear_play()
		_refresh()
		return
	_chosen = card
	_targeting = true
	_play_step = "move"
	_refresh()
	if _move_targets.is_empty() and _guard_targets(holder).is_empty():
		_log("No adjacent ally.")
		_clear_play()
		_refresh()


func _begin_move(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_log("That mech can't act.")
		_refresh()
		return
	if _reachable(state.position_of(holder), card.movement).is_empty():
		_log("%s has nowhere to step." % holder.display_name)
		_refresh()
		return
	_selected = holder
	if _chosen == card and _play_step == "move":
		_clear_play()
	else:
		_chosen = card
		_targeting = true
		_play_step = "move"
	_refresh()


func _begin_guard(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_log("That mech can't act.")
		_refresh()
		return
	_selected = holder
	if card.guards_ally():
		if _guard_targets(holder).is_empty():
			_log("No adjacent ally.")
			_clear_play()
			_refresh()
			return
		if _chosen == card and _play_step == "guard":
			_clear_play()
		else:
			_chosen = card
			_targeting = true
			_play_step = "guard"
		_refresh()
		return
	await _grant_guard(holder, holder, card)


func _on_guard_cell(unit: MechState) -> void:
	var card := _chosen
	var holder := _owner_of(card)
	if card == null or holder == null:
		_clear_play()
		_refresh()
		return
	if unit == null or not _guard_targets(holder).has(unit):
		_log("Choose an adjacent ally.")
		_refresh()
		return
	await _grant_guard(holder, unit, card)


func _play_special(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_log("That mech can't act.")
		_refresh()
		return
	_selected = holder
	if card.hits_front():
		_chosen = card
		_targeting = true
		_play_step = "front"
		_refresh()
		return
	if card.damage > 0 and card.target_type == "enemies":
		if card.moves_before():
			_begin_breach_step(holder, card)
			return
		await _play_breach(holder, card)
		return
	if card.barrier > 0 and card.target_type == "team":
		_spend(card)
		var amount := maxi(card.barrier, 0)
		for ally in state.living_units("player"):
			ally.add_barrier(amount)
			_show_guard_gain(ally, amount)
		_log("%s gives every teammate %d barrier." % [card.display_name, amount])
		_clear_play()
		await _after_card_played()
		return
	if card.target_type == "squad":
		if not GameManager.battle_offense:
			_log("%s can only be used in Overdrive." % card.display_name)
			_refresh()
			return
		_spend(card)
		var spark := GameManager.charge_from_spark()
		var banked := int(spark.get("banked", 0))
		_log("%s adds %d charge to the next gauge." % [card.display_name, banked])
		_clear_play()
		await _after_card_played()
		return
	_log("%s isn't coded yet." % card.display_name)
	_refresh()


func _play_breach(holder: MechState, card: CardData) -> void:
	var origin := state.position_of(holder)
	var victims: Array[MechState] = []
	for enemy in state.living_units("enemy"):
		if card.reaches(_manhattan(origin, state.position_of(enemy))):
			victims.append(enemy)
	_spend(card)
	_log("%s uses %s." % [holder.display_name, card.display_name])
	var finishing := _is_winning_blow(holder, victims, card)
	if finishing:
		await _play_finisher(holder)
		if not is_inside_tree() or state == null:
			return
		var lead: Button = null
		if not victims.is_empty():
			lead = _button_for(victims[0])
		await _play_attack(_sprite_for(holder), lead)
		if not is_inside_tree() or state == null:
			return
	if victims.is_empty():
		_log("%s hits no one." % card.display_name)
	for enemy in victims:
		if not holder.alive or not enemy.alive:
			continue
		var result := _strike(holder, enemy, card)
		_log(_hit_notice(holder, _struck(result, enemy), result))
	state.sync_occupants()
	state.check_outcome()
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_finish_if_over()
	_clear_play()
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	await _after_card_played()


func _grant_guard(holder: MechState, target: MechState, card: CardData) -> void:
	var amount := GameManager.card_block(card)
	var barrier := 0 if card == null else maxi(card.barrier, 0)
	_spend(card)
	if amount > 0:
		target.add_guard(amount)
		_show_guard_gain(target, amount)
	if barrier > 0:
		target.add_barrier(barrier)
		_show_guard_gain(target, barrier)
	if card.intercept and holder != null:
		holder.intercepting = true
		_log("%s will catch the next hit on an adjacent ally." % holder.display_name)
	if amount > 0:
		if holder == target:
			_log("%s gains %d guard." % [target.display_name, amount])
		else:
			_log("%s gives %s %d guard." % [holder.display_name, target.display_name, amount])
	if barrier > 0:
		if holder == target:
			_log("%s gains %d barrier." % [target.display_name, barrier])
		else:
			_log("%s gives %s %d barrier." % [holder.display_name, target.display_name, barrier])
	if card.movement > 0 and card.move_timing != "Before" and holder != null and holder.alive and not _reachable(state.position_of(holder), card.movement).is_empty():
		_selected = holder
		_chosen = card
		_followup_move = true
		_play_step = "move"
		_targeting = true
		_log("Step %d cell, or click %s to stay." % [card.movement, holder.display_name])
		_refresh()
		return
	_clear_play()
	await _after_card_played()


func _guard_targets(holder: MechState) -> Array[MechState]:
	var found: Array[MechState] = []
	if holder == null or state == null:
		return found
	var origin := state.position_of(holder)
	for unit in state.living_units("player"):
		if unit == holder:
			continue
		if _manhattan(origin, state.position_of(unit)) == 1:
			found.append(unit)
	return found


func _guard_waiting() -> bool:
	for card in _hand:
		if card == null or not card.is_guard():
			continue
		var holder := _owner_of(card)
		if holder == null or not holder.alive:
			continue
		if card.guards_ally() and _guard_targets(holder).is_empty():
			continue
		return true
	return false


func _refresh_hand() -> void:
	if hand_box == null:
		return
	_layout_hand()
	_update_hand_controls()


func _update_hand_controls() -> void:
	var can_pull := (
		state != null
		and state.battle_status == "active"
		and state.phase == "player"
		and not _animating
		and not _prompting
		and not _moved_for_card
		and not _followup_move
	)
	for card in _hand:
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null or not is_instance_valid(view):
			continue
		view.set_drop_handler(_on_card_drop.bind(card, view))
		view.set_pull_enabled(can_pull)
		view.set_chosen(card == _chosen)
		if not view.is_gliding():
			view.settle(card == _chosen)


func _finish_pending_hand_layout() -> void:
	_hand_layout_pending = false
	if is_inside_tree():
		_layout_hand()
		_update_hand_controls()


func _layout_hand() -> void:
	if hand_box == null:
		return
	if (deck_pile == null or deck_pile.size.x < 2.0) and _hand_layout_tries < 8:
		if not _hand_layout_pending:
			_hand_layout_pending = true
			_hand_layout_tries += 1
			get_tree().process_frame.connect(_finish_pending_hand_layout, CONNECT_ONE_SHOT)
		return
	_hand_layout_pending = false
	_hand_layout_tries = 0
	_ensure_hand_slots()
	var keep := {}
	for card in _hand:
		keep[card.get_instance_id()] = true
	var leaving: Array[MechCard] = []
	for id in _card_views.keys():
		if keep.has(id):
			continue
		var view := _card_views[id] as MechCard
		_card_views.erase(id)
		if is_instance_valid(view):
			leaving.append(view)
	leaving.sort_custom(func(a: MechCard, b: MechCard) -> bool:
		return a.global_position.x < b.global_position.x
	)
	for i in leaving.size():
		_launch_discard(leaving[i], i * CARD_STAGGER)
	var dealt := 0
	for index in _hand.size():
		var card := _hand[index]
		var slot := _hand_slot(index)
		var existing := _card_views.get(card.get_instance_id()) as MechCard
		if existing != null and is_instance_valid(existing):
			_place_held_card(existing, slot)
		else:
			_deal_card(card, slot, dealt * CARD_STAGGER)
			dealt += 1
	var dumped := _deck_discards.duplicate()
	_deck_discards.clear()
	for i in dumped.size():
		_spawn_deck_discard(dumped[i], i)
	_refresh_discard()


func _ensure_hand_slots() -> void:
	var needed := maxi(_hand_limit(), _hand.size())
	hand_box.clip_contents = false
	while hand_box.get_child_count() > needed:
		var extra := hand_box.get_child(hand_box.get_child_count() - 1)
		_park_slot_cards(extra)
		hand_box.remove_child(extra)
		extra.queue_free()
	while hand_box.get_child_count() < needed:
		hand_box.add_child(SLOT_SCENE.instantiate())


func _park_slot_cards(slot: Node) -> void:
	for child in slot.get_children():
		if child is MechCard:
			child.reparent(self)


func _hand_slot(hand_index: int) -> Control:
	# Cards pack to the left, so removing one slides the others left.
	return hand_box.get_child(hand_index) as Control


func _place_held_card(view: MechCard, slot: Control) -> void:
	if view.get_parent() == slot:
		return
	view.reparent(slot)
	view.begin_glide(CARD_SLIDE_TIME)


func _deal_card(card: CardData, slot: Control, delay: float) -> void:
	var view := CARD_SCENE.instantiate() as MechCard
	view.custom_minimum_size = CARD_SIZE
	view.size = CARD_SIZE
	slot.add_child(view)
	_bind_hand_card(view, card)
	_card_views[card.get_instance_id()] = view
	var origin := _pile_center(deck_pile)
	if origin == Vector2.ZERO:
		view.scale = Vector2.ONE
		view.position = Vector2.ZERO
		return
	view.deal_from(origin, delay)


func _present_card(view: MechCard, card: CardData, stroke: Color) -> void:
	view.present(card, stroke, GameManager.card_damage(card), GameManager.card_block(card))


func _shine_if_special(view: MechCard, card: CardData) -> void:
	if card == null or not _special_ids.has(card.get_instance_id()):
		return
	view.play_shine()
	var badge := view.special_badge()
	var note := view.tip_host()
	if badge != null and note != null:
		note.attach(badge, MechCard.SPECIAL_NOTE)


func _bind_hand_card(view: MechCard, card: CardData) -> void:
	var holder := _owner_of(card)
	var stroke := MechCard.stroke_for(holder.data if holder != null else null)
	_present_card(view, card, stroke)
	_shine_if_special(view, card)
	view.arm_press()
	view.set_drop_handler(_on_card_drop.bind(card, view))
	view.pulled.connect(_on_hand_card_pressed.bind(card))


func _spawn_deck_discard(card: CardData, order: int) -> void:
	var view := CARD_SCENE.instantiate() as MechCard
	view.custom_minimum_size = CARD_SIZE
	view.size = CARD_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var holder := _owner_of(card)
	var stroke := MechCard.stroke_for(holder.data if holder != null else null)
	_present_card(view, card, stroke)
	_silence_mouse(view)
	view.top_level = true
	view.z_as_relative = false
	view.z_index = 100
	view.scale = Vector2(0.42, 0.42)
	view.pivot_offset = view.size * 0.5
	var origin := _pile_center(deck_pile)
	_align_card_center(view, origin)
	_fly_card_into_pile(view, origin, view.scale, 0.0, order * CARD_STAGGER)


func _launch_discard(view: MechCard, delay: float) -> void:
	if not is_instance_valid(view):
		return
	view.release_for_discard()
	var start_center: Vector2 = view.get_global_transform() * (view.size * 0.5)
	var start_scale := view.scale
	var start_rot := view.rotation
	var parent := view.get_parent()
	if parent != null:
		parent.remove_child(view)
	add_child(view)
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	view.layout_mode = 0
	view.top_level = true
	view.z_as_relative = false
	view.z_index = 100
	view.pivot_offset = view.size * 0.5
	view.scale = start_scale
	view.rotation = start_rot
	_align_card_center(view, start_center)
	_fly_card_into_pile(view, start_center, start_scale, start_rot, delay)


func _align_card_center(view: Control, center: Vector2) -> void:
	var current: Vector2 = view.get_global_transform() * (view.size * 0.5)
	view.global_position += center - current


func _pile_center(pile: Control) -> Vector2:
	if pile == null or pile.size.x < 1.0:
		return Vector2.ZERO
	return pile.get_global_rect().get_center()




func _show_hit_points(button: Button, unit: MechState) -> void:
	_show_vital(button, "HitPoints", unit.hp if unit != null else 0, unit != null)


func _show_barrier(button: Button, unit: MechState) -> void:
	var active := unit != null and unit.alive and unit.standing_guard > 0
	_show_vital(button, "Barrier", unit.standing_guard if active else 0, active)


func _show_guard(button: Button, unit: MechState) -> void:
	var active := unit != null and unit.alive and unit.guard > 0
	_show_vital(button, "Guard", unit.guard if active else 0, active)


func _show_vital(button: Button, node_name: String, amount_value: int, shown: bool) -> void:
	var badge := button.get_node_or_null("Vitals/" + node_name) as HBoxContainer
	if badge == null:
		return
	badge.visible = shown
	if not shown:
		return
	var amount := badge.get_node_or_null("Amount") as Label
	if amount != null:
		amount.text = str(amount_value)


func _show_turn_count(button: Button, unit: MechState) -> void:
	var turn_count := button.get_node_or_null("Counters/TurnCount") as HBoxContainer
	if turn_count == null:
		return
	var counting := (
		unit != null
		and unit.alive
		and unit.team == "enemy"
		and state != null
		and state.battle_status == "active"
	)
	turn_count.visible = counting
	if not counting:
		return
	var amount := turn_count.get_node_or_null("Amount") as Label
	if amount != null:
		amount.text = str(maxi(unit.cards_until_turn, 0))


func _battle_order() -> Array[MechState]:
	var players := _by_speed(state.living_units("player"))
	var enemies := _by_speed(state.living_units("enemy"))
	var order: Array[MechState] = []
	if state.initiative == "enemy":
		order.append_array(enemies)
		order.append_array(players)
	else:
		order.append_array(players)
		order.append_array(enemies)
	return order


func _by_speed(units: Array[MechState]) -> Array[MechState]:
	var ordered: Array[MechState] = []
	ordered.assign(units)
	ordered.sort_custom(func(a: MechState, b: MechState) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.display_name < b.display_name
	)
	return ordered


func _sync_overdrive_cell(button: Button, unit: MechState) -> void:
	var glow := button.get_node_or_null("OverdriveGlow") as ColorRect
	if glow == null:
		return
	if button.has_meta("hit_flash"):
		glow.visible = false
		return
	var active := (
		GameManager.battle_offense
		and not _closing
		and unit != null
		and unit.alive
		and unit.team == "player"
	)
	glow.visible = active
	var inset := 3.0 if unit != null and unit == _selected else 0.0
	glow.offset_left = inset
	glow.offset_top = inset
	glow.offset_right = -inset
	glow.offset_bottom = -inset
	if not active:
		return
	_paint_overdrive_glow(glow)
	_start_overdrive_pulse()


func _unit_on_button(button: Button) -> MechState:
	for coords in _buttons:
		if _buttons[coords] == button:
			return _unit_at(coords)
	return null


func _start_overdrive_pulse() -> void:
	if _overdrive_pulse != null and _overdrive_pulse.is_valid() and _overdrive_pulse.is_running():
		return
	_overdrive_pulse = create_tween()
	_overdrive_pulse.set_loops()
	_overdrive_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_overdrive_pulse.tween_method(_set_overdrive_glow, 0.2, 1.0, 0.55)
	_overdrive_pulse.tween_method(_set_overdrive_glow, 1.0, 0.2, 0.55)


func _stop_overdrive_pulse() -> void:
	if _overdrive_pulse != null and _overdrive_pulse.is_valid():
		_overdrive_pulse.kill()
	_overdrive_pulse = null
	for coords in _buttons:
		var button: Button = _buttons[coords]
		var glow := button.get_node_or_null("OverdriveGlow") as ColorRect
		if glow != null:
			glow.visible = false


func _set_overdrive_glow(amount: float) -> void:
	_overdrive_glow = amount
	for coords in _buttons:
		var button: Button = _buttons[coords]
		var glow := button.get_node_or_null("OverdriveGlow") as ColorRect
		if glow != null and glow.visible:
			_paint_overdrive_glow(glow)


func _paint_overdrive_glow(glow: ColorRect) -> void:
	var dim := Color(0.08, 0.2, 0.34)
	var hot := Color(0.32, 0.74, 1.0)
	glow.color = dim.lerp(hot, _overdrive_glow)


func _show_active_reticule(unit: MechState) -> bool:
	if unit == null or not unit.alive or state == null or state.battle_status != "active":
		return false
	if state.active_unit_id != "":
		return unit.id == state.active_unit_id
	return unit == _selected and _chosen != null and _targeting


func _is_active_unit(unit: MechState) -> bool:
	if unit == null or not unit.alive or state == null or state.battle_status != "active":
		return false
	if state.active_unit_id != "":
		return unit.id == state.active_unit_id
	return unit == _selected


func _paint_cell_mark(button: Button, _coords: Vector2i, unit: MechState) -> void:
	var mark := button.get_node_or_null("CellMark") as CellMark
	if mark == null:
		return
	if _show_active_reticule(unit):
		var tint := Color(1.0, 0.35, 0.32) if unit.team == "enemy" else Color(0.35, 0.95, 1.0)
		mark.show_reticule(tint)
	else:
		mark.show_reticule(Color(0, 0, 0, 0))


## Copies the stage cells this fight was cut from onto a tile layer behind the board.
func _stamp_terrain(cell_px: float) -> void:
	var host := grid.get_parent()
	var terrain := host.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null:
		terrain = TileMapLayer.new()
		terrain.name = "Terrain"
		terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.add_child(terrain)
	StageMap.ensure()
	var source := StageMap.layer
	if source == null or source.tile_set == null or state == null or state.grid == null:
		terrain.visible = false
		return
	var encounter := GameManager.current_encounter
	var quarter := BattleDeployment.terrain_quarter(encounter)
	terrain.tile_set = source.tile_set
	terrain.clear()
	var painted := false
	for y in state.grid.height:
		for x in state.grid.width:
			var battle := Vector2i(x, y)
			var world := BattleDeployment.overworld_cell_for(encounter, battle)
			if not StageMap.contains(world):
				continue
			var source_id := source.get_cell_source_id(world)
			if source_id < 0:
				continue
			var atlas_coords := source.get_cell_atlas_coords(world)
			var alternative := source.get_cell_alternative_tile(world)
			if quarter != 0:
				alternative = _turn_alternative(alternative, quarter < 0)
			terrain.set_cell(battle, source_id, atlas_coords, alternative)
			painted = true
	terrain.visible = painted
	if not painted:
		return
	var tile := Vector2(source.tile_set.tile_size)
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	terrain.scale = Vector2((cell_px + h_sep) / tile.x, (cell_px + v_sep) / tile.y)
	terrain.position = grid.position
	host.move_child(terrain, grid.get_index())
	for coords in _buttons:
		_paint(_buttons[coords], _cell_color(coords))


## Godot stores a cell's flip in the alternative id, above the tile index.
const _TILE_FLIP_H := 1 << 12
const _TILE_FLIP_V := 1 << 13
const _TILE_TRANSPOSE := 1 << 14
const _TILE_ID_MASK := ~(1 << 12 | 1 << 13 | 1 << 14)


## Turns a painted cell one quarter, keeping the flip it already had on the stage.
func _turn_alternative(alternative: int, clockwise: bool) -> int:
	var tile_id := alternative & _TILE_ID_MASK
	var flip_h := (alternative & _TILE_FLIP_H) != 0
	var flip_v := (alternative & _TILE_FLIP_V) != 0
	var transpose := (alternative & _TILE_TRANSPOSE) != 0
	var want := {}
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var placed := _tile_place(corner, flip_h, flip_v, transpose)
		want[corner] = _turn_place(placed, clockwise)
	for next_transpose in [false, true]:
		for next_h in [false, true]:
			for next_v in [false, true]:
				var matched := true
				for corner in want:
					if _tile_place(corner, next_h, next_v, next_transpose) != want[corner]:
						matched = false
						break
				if not matched:
					continue
				if next_h:
					tile_id |= _TILE_FLIP_H
				if next_v:
					tile_id |= _TILE_FLIP_V
				if next_transpose:
					tile_id |= _TILE_TRANSPOSE
				return tile_id
	return alternative


func _tile_place(corner: Vector2i, flip_h: bool, flip_v: bool, transpose: bool) -> Vector2i:
	var x := corner.x
	var y := corner.y
	if flip_h:
		x = 1 - x
	if flip_v:
		y = 1 - y
	if transpose:
		var swap := x
		x = y
		y = swap
	return Vector2i(x, y)


func _turn_place(placed: Vector2i, clockwise: bool) -> Vector2i:
	if clockwise:
		return Vector2i(1 - placed.y, placed.x)
	return Vector2i(placed.y, 1 - placed.x)


func _paint(button: Button, color: Color, selected: bool = false) -> void:
	var style: StyleBoxFlat
	if selected:
		style = _ensure_active_cell_style()
		_start_active_cell_pulse()
	else:
		style = _owned_cell_style(button)
		var terrain := grid.get_parent().get_node_or_null("Terrain") as TileMapLayer
		if terrain != null and terrain.visible:
			if color.is_equal_approx(Color(0.14, 0.16, 0.2)):
				color = Color(0, 0, 0, 0)
			else:
				color.a = 0.45
		style.bg_color = color
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color.WHITE)


func _owned_cell_style(button: Button) -> StyleBoxFlat:
	var style: StyleBoxFlat = button.get_meta("cell_style") as StyleBoxFlat if button.has_meta("cell_style") else null
	if style != null:
		return style
	var source := button.get_theme_stylebox("normal") as StyleBoxFlat
	style = source.duplicate() as StyleBoxFlat
	button.set_meta("cell_style", style)
	return style


func _ensure_active_cell_style() -> StyleBoxFlat:
	if _active_cell_style == null:
		var sample := CELL_SCENE.instantiate() as Button
		_active_cell_style = (sample.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
		sample.free()
		_active_cell_style.bg_color = Color(0.10, 0.28, 0.48)
	return _active_cell_style


func _start_active_cell_pulse() -> void:
	if _active_cell_pulse != null and _active_cell_pulse.is_valid() and _active_cell_pulse.is_running():
		return
	var style := _ensure_active_cell_style()
	var dim := Color(0.10, 0.26, 0.44)
	var hot := Color(0.28, 0.62, 0.95)
	style.bg_color = dim
	_active_cell_pulse = create_tween()
	_active_cell_pulse.set_loops()
	_active_cell_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_cell_pulse.tween_property(style, "bg_color", hot, 0.45)
	_active_cell_pulse.tween_property(style, "bg_color", dim, 0.45)


func _stop_active_cell_pulse() -> void:
	if _active_cell_pulse != null and _active_cell_pulse.is_valid():
		_active_cell_pulse.kill()
	_active_cell_pulse = null
