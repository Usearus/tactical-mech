extends Control


## Played cards tick each enemy's own turn count. The battle ends after this many rounds.
const ROUND_LIMIT := 2
const ENEMY_ATTACK_DELAY := 1.5
## One allied mech draws 3, two draw 4, three draw 6.
const HAND_BASE := 2
const HAND_CAP := 6
const CARD_SIZE := Vector2(176, 268)
const STACK_PIECE := Vector2(176, 56)
const CARD_SLIDE_TIME := 0.24
const CARD_STAGGER := MechCard.DEAL_STAGGER
## Enemy turns and a resolving player card sink the hand by this share of a card, leaving the top in view.
const HAND_DROP_RATIO := 0.3
const HAND_TUCK_TIME := 0.28
const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const LISTED_CARD := preload("res://scenes/ui/listed_card.tscn")
const CELL_SCENE := preload("res://scenes/battle/battle_cell.tscn")
const FLOAT_SCENE := preload("res://scenes/ui/float_number.tscn")
const GAUGE_PITCH_SCENE := preload("res://scenes/ui/gauge_pitch.tscn")
const PITCH_MARK_SCENE := preload("res://scenes/ui/pitch_mark.tscn")
const SLOT_SCENE := preload("res://scenes/ui/empty_card_slot.tscn")
const BARRIER_SCENE: PackedScene = preload("res://scenes/props/barrier.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/battle/explosion.tscn")
## Cards of this damage and up throw eight blasts. Weaker hits throw two.
const HEAVY_IMPACT_DAMAGE := 6
## Every blast, mini through medium, is drawn this much larger than the body it hits.
const IMPACT_VISUAL_SCALE := 1.3
## Medium sheet frame where the core covers the body. The mech leaves on that frame.
const MEDIUM_VANISH_FRAME := 6
const POWER_UP_SCENE: PackedScene = preload("res://scenes/battle/power_up.tscn")
## Standing sprites sit under badges. A reaching attack draws over the next cell's mech.
const MECH_SPRITE_Z := 4
const MECH_REACH_Z := 5
## A lit cell has to read while a mech fills it. Badges stay above this.
const RANGE_OVER_BODY_Z := 6
## The ring veil sits under every mech sprite. Outsiders are dimmed on the sprite itself, so the whole body stays dim.
const SCENERY_SHADE_Z := 2
const BYSTANDER_SPRITE_Z := 3
const WeatherFitScript = preload("res://scripts/stage/weather_fit.gd")
const StrikeRangeScript := preload("res://scripts/battle/strike_range.gd")
const GUARD_COLOR := Color(0.45, 0.78, 1.0)
const DAMAGE_COLOR := Color(1.0, 0.32, 0.28)
const CELL_FLOOR := Color(0.14, 0.16, 0.2)
const MOVE_FILL := Color(0.16, 0.46, 0.78)
const GUARD_FILL := Color(0.16, 0.4, 0.68)
const ATTACK_FILL := Color(0.45, 0.18, 0.18)
const FLOAT_RISE := 72.0
const FLOAT_TIME := 0.82
const ACTIVATE_TEXT := "Activate Overdrive"
const FIELD_ZOOM_STEP := 1.1
const FIELD_PAN_THRESHOLD := 8.0
## 75% closer than the normal board. Attacks punch in this far, and the wheel can reach it too.
const FIELD_ZOOM_MAX := 1.75
const ATTACK_ZOOM_IN := 0.16
const ATTACK_ZOOM_OUT := 0.22
## Hand and sidebar follow the board, once the overworld fade has finished.
const HUD_REVEAL_SECONDS := 0.15

var _attack_offered := false
## Pips already drawn while discard +1s are still in the air. -1 follows the real gauge.
var _gauge_visual := -1
var _pitch_pending := 0
## Power-up aura for each mech, including one riding a move token.
var _overdrive_fx: Dictionary = {}
var _active_cell_style: StyleBoxFlat
var _active_cell_pulse: Tween

var state: BattleState
var _closing := false
var _tutorial_gauge := 0
var _tutorial_bank := 0
var _tutorial_pitch_id := ""
var _selected: MechState
var _status_unit: MechState
## True while _refresh is painting, so a status change inside it does not paint twice.
var _refreshing := false
var _chosen: CardData
var _targeting := false
var _play_step := ""
var _followup_move := false
var _moved_for_card := false
## Step from a move-then card, still reversible until the follow-up resolves.
var _step_undo := false
var _step_origin := Vector2i(-1, -1)
var _step_facing := 1
var _move_targets: Dictionary = {}
var _animating := false
var _buttons: Dictionary = {}
## View cells outside the 6x3. Keyed by view coordinates.
var _scenery: Dictionary = {}
## Living mechs standing on the scenery ring. Keyed by view coordinates.
var _bystanders: Dictionary = {}
## 1 keeps the 6x3 at today's size. Smaller values pull back until the 10x7 fits.
## FIELD_ZOOM_MAX is 75% closer than that close-up.
var _field_zoom := 1.0
## Field-local point kept at the middle of the board view.
var _field_focus := Vector2.ZERO
var _attack_zoom_active := false
var _attack_zoom_from := 1.0
var _attack_zoom_focus := Vector2.ZERO
var _zoom_tween: Tween
var _touch_points := {}
var _pinch_distance := -1.0
var _field_dragging := false
var _field_drag_total := 0.0
var _gesture_panned := false
## Drag offset from the play-area center, in field pixels. Resize recenters, then reapplies this.
var _field_pan := Vector2.ZERO
var _play_center := Vector2.ZERO
var _deck: Array[CardData] = []
## Each mech's overdrive card. Counted in the deck, dealt only after Overdrive starts.
var _specials: Array[CardData] = []
var _special_ids := {}
var _hand: Array[CardData] = []
var _discard: Array[CardData] = []
## Hand cards taken off a mech who just died. Kept only when that death ends the battle.
var _ending_hand: Array[CardData] = []
var _owner: Dictionary = {}
var _card_views: Dictionary = {}
var _deck_discards: Array[CardData] = []
var _pile_view := ""
var _hand_layout_pending := false
var _hand_layout_tries := 0
var _hand_tucked := false
## True from the moment a player card is spent until that attack, breach, or fan finishes.
var _resolving_card := false
var _hand_drop_px := 0.0
## Seat size taken from the card slots. The end-round button keeps the size set on the scene.
var _hand_card_size := CARD_SIZE
var _hand_drop_tween: Tween
## -1 is an end-of-round tick. A spent card sets 0 or 1, and the next clock step uses it once.
var _pending_clock_steps := -1
var _opened: Dictionary = {}
var _results_reason := ""
## Matches the Overdrive row on the bonus panel, so a refresh rebuilds that list only when the mode changes.
var _bonus_shows_overdrive := false
var _pitch_marks: Array[PitchMark] = []

@onready var grid_host: Control = %GridHost
@onready var grid: GridContainer = %Grid
@onready var shots: Node2D = %Shots
@onready var mech_panel: MechPanel = $StatsWindow/Actions
@onready var stats_window: PanelContainer = %StatsWindow
@onready var discard_pile: Button = %DiscardPile
@onready var discard_glow: CardActiveGlow = %DiscardGlow
@onready var discard_label: Label = %DiscardLabel
@onready var deck_pile: Button = %DeckPile
@onready var deck_count: Label = %DeckCount
@onready var discard_overlay: Control = %DiscardOverlay
@onready var discard_scroll: ScrollContainer = %DiscardScroll
@onready var discard_list: GridContainer = %DiscardList
@onready var discard_close: Button = %DiscardClose
@onready var skip_button: Button = %SkipButton
@onready var hand_box: HBoxContainer = %Hand
@onready var _hand_anchor: Control = $"MarginContainer/Full Layout/Hand Margin/HandAnchor"
@onready var _hand_row: Control = $"MarginContainer/Full Layout/Hand Margin/HandAnchor/HandRow"
@onready var _corner_column: Control = $"MarginContainer/Full Layout/Hand Margin/HandAnchor/CornerColumn"
@onready var player_gauge: OverdriveMeter = %PlayerGauge
@onready var activate_button: SciFlashingButton = %ActivateButton
@onready var charge_slot: Control = %ChargeSlot
@onready var charge_bar: PanelContainer = %ChargeBar
@onready var round_label: Label = %Title
@onready var _effect_box: CardEffectBox = %CardEffectBox
@onready var mode_banner: ModeBanner = %ModeBanner
@onready var finisher_banner: FinisherBanner = %FinisherBanner
@onready var results: BattleResults = %BattleResults
@onready var upgrade_pick: UpgradePick = %UpgradePick
@onready var _info_note: InfoNote = %SpecialNote
@onready var _play_prompt: PlayPrompt = %PlayPrompt
@onready var _hand_chrome: CanvasItem = $"MarginContainer/Full Layout/Hand Margin"
@onready var _side_chrome: CanvasItem = $"MarginContainer/Full Layout/Board Row/SideBar"
@onready var _tip_host: CanvasItem = $TipLayer/TipHost
@onready var _banner_layer: CanvasLayer = $BannerLayer
@onready var bonus_panel: BonusPanel = %"Bonus Panel"


func _process(_delta: float) -> void:
	if _effect_box != null and _effect_box.visible:
		_place_effect_box()


func _ready() -> void:
	skip_button.pressed.connect(_on_end_turn)
	discard_pile.gui_input.connect(_on_discard_pile_input)
	deck_pile.gui_input.connect(_on_deck_pile_input)
	discard_close.pressed.connect(_close_discard_view)
	activate_button.pressed.connect(_on_activate_pressed)
	results.confirmed.connect(_on_results_confirmed)
	if upgrade_pick != null:
		upgrade_pick.confirmed.connect(_on_upgrade_confirmed)
		upgrade_pick.skipped.connect(_on_upgrade_skipped)
	grid_host.resized.connect(_fit_grid)
	_hand_anchor.resized.connect(_place_hand_row)
	_place_hand_row()
	_place_discard_glow()
	_style_end_turn()
	_style_pile(discard_pile)
	_style_pile(deck_pile)
	_style_squad_gauge()
	_style_discard_close()
	_hold_battle_hud()
	_setup_battle()
	_build_grid()
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
		await _reveal_battle_hud()
		if not is_inside_tree() or state == null or _closing:
			return
		await _announce_primed()
		if not is_inside_tree() or state == null or _closing:
			return
		await _announce_round()
	if not is_inside_tree() or state == null or _closing:
		return
	if state.phase == "enemy" and state.battle_status == "active":
		await _finish_enemy_side(false)
	elif state.battle_status == "active" and state.phase == "player":
		await _return_to_player(true)
		_tutorial_player_ready()


func _style_end_turn() -> void:
	skip_button.text = ""
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_button.size_flags_vertical = Control.SIZE_SHRINK_END
	skip_button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_pile(pile: Button, hot := false) -> void:
	if pile == null:
		return
	if hot:
		var hover := pile.get_theme_stylebox("hover")
		if hover != null:
			pile.add_theme_stylebox_override("normal", hover)
			pile.add_theme_stylebox_override("disabled", hover)
		return
	pile.remove_theme_stylebox_override("normal")
	pile.remove_theme_stylebox_override("disabled")


func _style_discard_close() -> void:
	discard_close.text = "X"
	discard_close.custom_minimum_size = Vector2(56, 56)


func _refresh_discard() -> void:
	var discarded := _discard.size()
	var remaining := _deck.size() + _specials.size()
	if discard_label != null:
		discard_label.text = str(discarded)
	if deck_count != null:
		deck_count.text = str(remaining)
	if discard_pile != null:
		discard_pile.disabled = discarded < 1
		_set_pile_caption_color(discard_pile, discard_pile.disabled)
	_show_pile_stack(discard_pile, discarded > 1)
	_show_pile_stack(deck_pile, remaining > 1)


func _set_pile_caption_color(pile: Button, disabled: bool) -> void:
	var color := pile.get_theme_color(&"font_disabled_color") if disabled else Color.WHITE
	_tint_labels(pile, color)


func _tint_labels(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is Label:
			(child as Label).add_theme_color_override(&"font_color", color)
		_tint_labels(child, color)


func _show_pile_stack(pile: Button, stacked: bool) -> void:
	if pile == null:
		return
	var stack := pile.get_parent()
	if stack == null:
		return
	for child in stack.get_children():
		if child == pile or child is CardActiveGlow or not child is CanvasItem:
			continue
		(child as CanvasItem).visible = stacked
		if child is BaseButton:
			(child as BaseButton).disabled = pile.disabled


func _on_discard_pile_input(event: InputEvent) -> void:
	if discard_pile != null and discard_pile.disabled:
		return
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
		var mech := holder.data if holder != null else null
		var stroke := MechCard.stroke_for(mech)
		var slot := LISTED_CARD.instantiate() as ListedCard
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		discard_list.add_child(slot)
		slot.show_card(card, stroke, card.damage, card.block, UpgradeDeck.listing_tag(card, mech), false)
		if slot.card_view != null:
			_shine_if_special(slot.card_view, card)
		_silence_mouse(slot)


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
	if GameManager.stage_scene == GameManager.STAGE_0_1 or GameManager.stage_scene == GameManager.STAGE_0_2:
		SoundBank.loop("rain")
	else:
		SoundBank.loop("wind")
	GameManager.reset_opening_edicts()
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
	if GameManager.tutorial_mission:
		var phase := TutorialHooks.phase()
		GameManager.tutorial_charge_open = phase == "b3"
		if phase == "b3":
			GameManager.player_attack_gauge = maxi(GameManager.player_attack_max - 1, 0)
			GameManager.player_banked_gauge = 0
			GameManager.battle_offense = false
		_tutorial_gauge = GameManager.player_attack_gauge
		_tutorial_bank = GameManager.player_banked_gauge
		_refresh_squad_gauge()


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
	_scenery.clear()
	_bystanders.clear()
	var encounter := GameManager.current_encounter
	var view_size := BattleDeployment.view_size(encounter)
	grid.columns = view_size.x
	for y in view_size.y:
		for x in view_size.x:
			var view := Vector2i(x, y)
			var button := CELL_SCENE.instantiate() as Button
			button.resized.connect(_on_cell_resized.bind(button))
			if BattleDeployment.is_play_cell(view, encounter):
				var play := BattleDeployment.play_cell(view, encounter)
				button.pressed.connect(_on_cell_pressed.bind(play))
				_buttons[play] = button
			else:
				_scenery[view] = button
			grid.add_child(button)
	_gather_bystanders()
	_fit_grid()


func _fit_grid() -> void:
	if state == null or state.grid == null:
		return
	var play_cols := state.grid.width
	var play_rows := state.grid.height
	var encounter := GameManager.current_encounter
	var view := BattleDeployment.view_size(encounter)
	if play_cols <= 0 or play_rows <= 0 or grid_host.size.x <= 1.0 or grid_host.size.y <= 1.0:
		return
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	var pad := 8.0
	var cell_w := (grid_host.size.x - pad * 2.0 - h_sep * (play_cols - 1)) / float(play_cols)
	var cell_h := (grid_host.size.y - pad * 2.0 - v_sep * (play_rows - 1)) / float(play_rows)
	var cell := floorf(minf(cell_w, cell_h))
	if cell < 1.0:
		return
	var side := Vector2(cell, cell)
	for child in grid.get_children():
		if child is Control:
			child.custom_minimum_size = side
	var play_size := Vector2(
		cell * play_cols + h_sep * (play_cols - 1),
		cell * play_rows + v_sep * (play_rows - 1)
	)
	var grid_size := Vector2(
		cell * view.x + h_sep * (view.x - 1),
		cell * view.y + v_sep * (view.y - 1)
	)
	var margin := float(BattleDeployment.view_margin(encounter))
	var play_offset := Vector2(margin * (cell + h_sep), margin * (cell + v_sep))
	var field := grid.get_parent() as Control
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	grid.layout_mode = 0
	grid.position = Vector2.ZERO
	grid.size = grid_size
	var board := field.get_node_or_null("Board") as ColorRect
	if board != null:
		@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
		board.layout_mode = 0
		board.position = Vector2.ZERO
		board.size = grid_size
	var play_center := play_offset + play_size * 0.5
	field.pivot_offset = play_center
	field.size = grid_size
	_place_scenery_shade(field, play_offset, play_size, grid_size)
	_stamp_terrain(cell)
	_play_center = play_center
	_field_zoom = clampf(_field_zoom, _field_zoom_floor(), FIELD_ZOOM_MAX)
	if not _attack_zoom_active:
		_field_focus = _clamp_field_focus(_play_center + _field_pan, _field_zoom)
		_field_pan = _field_focus - _play_center
	_apply_field_zoom()
	call_deferred("_place_status_tip")


func _refresh() -> void:
	if GameManager.current_encounter == null or state == null:
		return
	_refreshing = true
	var player_phase := state.battle_status == "active" and state.phase == "player" and not _animating
	skip_button.disabled = not player_phase or _moved_for_card
	var end_label := skip_button.get_node_or_null("Content") as CanvasItem
	if end_label != null:
		end_label.modulate.a = 0.35 if skip_button.disabled else 1.0
	_sync_status_tip()
	if state.phase == "player" and not _animating:
		_pull_specials()
	_rebuild_move_targets()
	var active_marked := false
	for coords in _buttons:
		var button: Button = _buttons[coords]
		var unit := _unit_at(coords)
		_present_cell(button, coords, unit)
		if _is_active_unit(unit):
			active_marked = true
	if not active_marked:
		_stop_active_cell_pulse()
	_refresh_scenery()
	_refresh_hand()
	_refresh_discard()
	_refresh_round()
	_refresh_squad_gauge()
	_sync_bonus_overdrive()
	_sync_play_prompt()
	_refreshing = false


## Rebuilds the bonus list only when Overdrive turns on or off.
func _sync_bonus_overdrive() -> void:
	var on := GameManager.battle_offense
	if bonus_panel == null or on == _bonus_shows_overdrive:
		return
	_bonus_shows_overdrive = on
	bonus_panel.refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_field_mouse_button(event)
		return
	if not _field_pointer_open():
		return
	if event is InputEventMouseMotion and _field_dragging:
		_on_field_mouse_drag(event)
	elif event is InputEventMagnifyGesture and _pointer_on_field(event.position):
		_zoom_field(event.factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture and _pointer_on_field(event.position) and _field_can_pan():
		_pan_field(event.delta)
		_gesture_panned = true
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _pinch_field(event):
			get_viewport().set_input_as_handled()


func _on_field_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not _field_pointer_open() or not event.pressed or not _pointer_on_field(event.global_position):
			return
		var step := FIELD_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / FIELD_ZOOM_STEP
		_zoom_field(step)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if not _field_pointer_open():
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_field_status_click(event.global_position, false)
		return
	if event.pressed:
		if stats_window != null and stats_window.visible and stats_window.get_global_rect().has_point(event.global_position):
			return
		_gesture_panned = false
		_field_drag_total = 0.0
		_field_dragging = _pointer_on_field(event.global_position) and (
			_field_can_pan() or (event.button_index == MOUSE_BUTTON_MIDDLE and not GameManager.tutorial_mission)
		)
	else:
		var panned := _gesture_panned
		_field_dragging = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_field_status_click(event.global_position, panned)


func _on_field_mouse_drag(event: InputEventMouseMotion) -> void:
	if _touch_points.size() >= 2:
		return
	if not _field_can_pan() and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not GameManager.tutorial_mission):
		return
	_field_drag_total += event.relative.length()
	if _field_drag_total < FIELD_PAN_THRESHOLD:
		return
	_gesture_panned = true
	_pan_field(event.relative)
	get_viewport().set_input_as_handled()


func _try_field_status_click(point: Vector2, panned: bool) -> void:
	if panned:
		return
	if _status_click_blocked():
		_hide_status_tip()
		return
	if stats_window != null and stats_window.visible and stats_window.get_global_rect().has_point(point):
		return
	var unit := _unit_at_global(point)
	if unit == null:
		_hide_status_tip()
		return
	_show_status_tip(unit)


func _status_click_blocked() -> bool:
	if _upgrade_open():
		return true
	if results != null and results.visible:
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


func _unit_at_global(point: Vector2) -> MechState:
	if state == null or not _pointer_on_field(point):
		return null
	var coords := _coords_at_global(point)
	if coords.x >= 0:
		return _unit_at(coords)
	for view in _scenery:
		var button := _scenery[view] as Control
		if button != null and button.get_global_rect().has_point(point):
			return _bystanders.get(view) as MechState
	return null


func _gather_bystanders() -> void:
	_bystanders.clear()
	var encounter := GameManager.current_encounter
	if encounter == null or state == null:
		return
	var fighting := {}
	for unit in state.units:
		if unit != null:
			fighting[unit.id] = true
	for unit in GameManager.all_mechs():
		if unit == null or not unit.alive or fighting.has(unit.id):
			continue
		var view := BattleDeployment.view_cell_for_overworld(encounter, unit.overworld_position)
		if not _scenery.has(view):
			continue
		_bystanders[view] = unit


func _bystander_view(unit: MechState) -> Vector2i:
	if unit == null:
		return Vector2i(-1, -1)
	for view in _bystanders:
		var standing := _bystanders[view] as MechState
		if standing != null and standing.id == unit.id:
			return view
	return Vector2i(-1, -1)


func _refresh_scenery() -> void:
	for view in _scenery:
		var button := _scenery[view] as Button
		if button == null:
			continue
		var unit := _bystanders.get(view) as MechState
		var sprite := button.get_node("MechSprite") as AnimatedSprite2D
		var caption := button.get_node("Caption") as Label
		_show_turn_count(button, null)
		_show_hit_points(button, null)
		_show_barrier(button, null)
		_show_guard(button, null)
		_show_evade(button, null)
		_sync_overdrive_cell(button, null)
		_sync_intercept_cell(button, false, null)
		_paint_cell_mark(button, view, null)
		if unit != null and unit.art_id != "" and _show_mech_sprite(sprite, unit):
			button.text = ""
			caption.visible = false
			_place_sprite(button, sprite)
			sprite.z_index = BYSTANDER_SPRITE_Z
			sprite.modulate = _scenery_dim()
		else:
			_hide_mech_sprite(sprite, caption)
			button.text = ""
		_paint(button, CELL_FLOOR)


func _place_scenery_shade(field: Control, play_offset: Vector2, play_size: Vector2, grid_size: Vector2) -> void:
	var shade := field.get_node_or_null("SceneryShade") as Control
	if shade == null:
		return
	shade.z_index = SCENERY_SHADE_Z
	shade.position = Vector2.ZERO
	shade.size = grid_size
	var top := shade.get_node_or_null("Top") as ColorRect
	var bottom := shade.get_node_or_null("Bottom") as ColorRect
	var left := shade.get_node_or_null("Left") as ColorRect
	var right := shade.get_node_or_null("Right") as ColorRect
	if top != null:
		top.position = Vector2.ZERO
		top.size = Vector2(grid_size.x, play_offset.y)
	if bottom != null:
		bottom.position = Vector2(0.0, play_offset.y + play_size.y)
		bottom.size = Vector2(grid_size.x, maxf(grid_size.y - bottom.position.y, 0.0))
	if left != null:
		left.position = Vector2(0.0, play_offset.y)
		left.size = Vector2(play_offset.x, play_size.y)
	if right != null:
		right.position = Vector2(play_offset.x + play_size.x, play_offset.y)
		right.size = Vector2(maxf(grid_size.x - right.position.x, 0.0), play_size.y)


func _bystander_sprite(sprite: AnimatedSprite2D) -> bool:
	var button := sprite.get_parent() as Button
	if button == null:
		return false
	for view in _scenery:
		if _scenery[view] == button:
			return true
	return false


## Matches the scenery veil, for a layer that draws above that veil.
func _scenery_dim() -> Color:
	var veil := Color(0, 0, 0, 0.3)
	var field := grid.get_parent() as Control
	if field != null:
		var top := field.get_node_or_null("SceneryShade/Top") as ColorRect
		if top != null:
			veil = top.color
	return Color(1, 1, 1).lerp(Color(veil.r, veil.g, veil.b), veil.a)


func _upgrade_open() -> bool:
	return upgrade_pick != null and upgrade_pick.visible


func _field_pointer_open() -> bool:
	if grid_host == null or grid_host.size.x < 1.0:
		return false
	if _upgrade_open():
		return false
	if results != null and results.visible:
		return false
	if discard_overlay != null and discard_overlay.visible:
		return false
	return true


func _pointer_on_field(point: Vector2) -> bool:
	return grid_host.get_global_rect().has_point(point)


func _zoom_field(factor: float) -> void:
	if GameManager.tutorial_mission or _attack_zoom_active:
		return
	var next := clampf(_field_zoom * factor, _field_zoom_floor(), FIELD_ZOOM_MAX)
	if is_equal_approx(next, _field_zoom):
		return
	_field_zoom = next
	_field_focus = _clamp_field_focus(_field_focus, _field_zoom)
	_field_pan = _field_focus - _play_center
	_apply_field_zoom()


func _field_can_pan() -> bool:
	if GameManager.tutorial_mission:
		return false
	var field := grid.get_parent() as Control
	if field == null or grid_host == null or _attack_zoom_active:
		return false
	var visual := field.size * _field_zoom
	var slack := visual - grid_host.size
	return slack.x > 1.0 or slack.y > 1.0 or _field_zoom > _field_zoom_floor()


func _pan_field(delta: Vector2) -> void:
	if GameManager.tutorial_mission or _attack_zoom_active or _field_zoom <= 0.0:
		return
	_field_focus -= delta / _field_zoom
	_field_focus = _clamp_field_focus(_field_focus, _field_zoom)
	_field_pan = _field_focus - _play_center
	_apply_field_zoom()


func _field_zoom_floor() -> float:
	var field := grid.get_parent() as Control
	if field == null or field.size.x < 1.0 or field.size.y < 1.0 or grid_host.size.x < 1.0:
		return 1.0
	return minf(grid_host.size.x / field.size.x, grid_host.size.y / field.size.y)


func _apply_field_zoom() -> void:
	var field := grid.get_parent() as Control
	if field == null or grid_host == null:
		return
	field.scale = Vector2(_field_zoom, _field_zoom)
	var pivot := field.pivot_offset
	var host_center := grid_host.size * 0.5
	field.position = host_center - pivot - (_field_focus - pivot) * _field_zoom


func _pinch_field(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _pointer_on_field(touch.position):
				_touch_points[touch.index] = touch.position
				if _touch_points.size() == 1:
					_gesture_panned = false
					_field_drag_total = 0.0
		else:
			_touch_points.erase(touch.index)
		_pinch_distance = _touch_span() if _touch_points.size() >= 2 else -1.0
		return _touch_points.size() >= 2
	var drag := event as InputEventScreenDrag
	if drag == null or not _touch_points.has(drag.index):
		return false
	_touch_points[drag.index] = drag.position
	if _touch_points.size() < 2:
		return false
	var span := _touch_span()
	if _pinch_distance > 1.0 and span > 1.0:
		_zoom_field(span / _pinch_distance)
	_pinch_distance = span
	_gesture_panned = true
	return true


func _touch_span() -> float:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _show_status_tip(unit: MechState) -> void:
	if unit == null or stats_window == null or mech_panel == null:
		return
	var previous := _status_unit
	_status_unit = unit
	stats_window.visible = true
	mech_panel.present_unit(unit, false)
	_place_status_tip()
	if previous != unit:
		_repaint_enemy_range()


func _hide_status_tip() -> void:
	var had := _status_unit
	_status_unit = null
	if stats_window != null:
		stats_window.visible = false
	if had != null:
		_repaint_enemy_range()


func _repaint_enemy_range() -> void:
	if _refreshing or _animating or state == null:
		return
	for coords in _buttons:
		var button := _buttons[coords] as Button
		if button != null:
			_paint(button, _cell_color(coords))


func _sync_status_tip() -> void:
	if _chosen != null:
		_hide_status_tip()
		return
	if _status_unit == null or stats_window == null or not stats_window.visible:
		return
	if _bystander_view(_status_unit).x < 0 and (state == null or state.unit_by_id(_status_unit.id) == null):
		_hide_status_tip()
		return
	if _bystander_view(_status_unit).x >= 0 and not _status_unit.alive:
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
	return grid_host.get_global_rect()


func _on_cell_pressed(coords: Vector2i) -> void:
	if _gesture_panned:
		_gesture_panned = false
		return
	if _animating or state.battle_status != "active" or state.phase != "player":
		return
	var unit := _unit_at(coords)
	if _targeting:
		if _play_step == "confirm":
			await _on_confirm_cell(unit)
			return
		if _play_step == "guard":
			if _can_keep_step(unit):
				await _keep_step()
				return
			await _on_guard_cell(unit)
			return
		if _play_step == "move":
			await _on_move_cell(coords)
			return
		if _play_step == "breach":
			await _on_breach_cell(coords)
			return
		if _play_step == "front":
			await _try_front(coords)
			return
		if unit != null and unit.alive and unit.team == "player":
			if _moved_for_card:
				if _can_keep_step(unit):
					await _keep_step()
				return
			if unit != _selected:
				_chosen = null
				_play_step = ""
			_targeting = false
			_selected = unit
			_refresh()
			return
		if _moved_for_card and (unit == null or not unit.alive or unit.team != "enemy"):
			return
		await _try_attack(unit)
		return
	if unit != null and unit.alive:
		if GameManager.tutorial_mission:
			var who := unit.data.id if unit.data != null else ""
			if not TutorialHooks.allows("select", who):
				return
			_chosen = null
			_targeting = false
			_selected = unit
			_refresh()
			TutorialHooks.notify("select", who)
			return
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
		_refresh()
		return
	if target == null or target.team != "enemy" or not target.alive:
		_clear_play()
		_selected = null
		_refresh()
		return
	var attacker := _owner_of(card)
	if attacker == null or not attacker.alive:
		_refresh()
		return
	_selected = attacker
	var attacker_pos := state.position_of(attacker)
	var target_pos := state.position_of(target)
	if not _in_strike_range(attacker_pos, target_pos, card):
		_chosen = card
		_targeting = true
		_refresh()
		return
	if GameManager.tutorial_mission and not TutorialHooks.allows("target"):
		_chosen = card
		_targeting = true
		_refresh()
		return
	if GameManager.tutorial_mission and not TutorialHooks.any_target():
		var aimed := _tutorial_enemy_target()
		if aimed != null and target != aimed:
			_chosen = card
			_targeting = true
			_refresh()
			return
	TutorialHooks.notify("target")
	attacker.face_toward_x(attacker_pos.x, target_pos.x)
	_animating = true
	_play_step = ""
	_step_undo = false
	_spend(card)
	_resolving_card = true
	_refresh()
	var shoots := WeaponVolley.has_profile(attacker.art_id)
	var finishing := _is_winning_blow(attacker, [target], card)
	if finishing:
		await _play_finisher(attacker)
		if not is_inside_tree() or state == null:
			return
		if not shoots:
			await _play_attack(_sprite_for(attacker), _button_for(target), null, {}, _impact_heavy(card), true)
			if not is_inside_tree() or state == null:
				return
	var result := _strike(attacker, target, card, not shoots)
	_spend_opening_strike(card)
	if not is_inside_tree() or state == null:
		return
	if shoots:
		await _play_attack(_sprite_for(attacker), _button_for(_struck(result, target)), attacker, result, _impact_heavy(card))
	elif not finishing:
		await _play_attack(_sprite_for(attacker), _button_for(_struck(result, target)), null, result, _impact_heavy(card))
	if not is_inside_tree() or state == null:
		return
	_moved_for_card = false
	state.sync_occupants()
	_note_outcome()
	_animating = false
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_finish_if_over()
	if _closing or state == null or state.battle_status != "active":
		_resolving_card = false
		_clear_play()
		_refresh()
		return
	if not attacker.alive:
		_clear_play()
		await _after_card_played()
		await _return_to_player()
		return
	if card.moves_after():
		_resolving_card = false
		_followup_move = true
		_play_step = "move"
		_targeting = true
		_chosen = card
		_refresh()
		return
	_clear_play()
	await _after_card_played()
	await _return_to_player()


func _try_front(coords: Vector2i) -> void:
	var card := _chosen
	if card == null or not card.hits_front():
		_clear_play()
		_refresh()
		return
	var attacker := _owner_of(card)
	if attacker == null or not attacker.alive:
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
	_spend(card)
	_resolving_card = true
	_refresh()
	var finishing := _is_winning_blow(attacker, victims, card)
	if finishing:
		await _play_finisher(attacker)
		if not is_inside_tree() or state == null:
			return
		await _play_area(_sprite_for(attacker), fan, _impact_heavy(card), true)
		if not is_inside_tree() or state == null:
			return
	for unit in victims:
		if not attacker.alive:
			break
		if not unit.alive:
			continue
		var result := _strike(attacker, unit, card)
	_spend_opening_strike(card)
	if not finishing:
		await _play_area(_sprite_for(attacker), fan, _impact_heavy(card), false)
	if not is_inside_tree():
		return
	state.sync_occupants()
	_note_outcome()
	_animating = false
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_finish_if_over()
	if _closing or state == null or state.battle_status != "active":
		_resolving_card = false
		_clear_play()
		_refresh()
		return
	_clear_play()
	await _after_card_played()
	await _return_to_player()


func _front_cells(origin: Vector2i, direction: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ahead := origin + Vector2i(direction, 0)
	for rise in [-1, 0, 1]:
		var spot := ahead + Vector2i(0, rise)
		if state.grid.in_bounds(spot):
			cells.append(spot)
	return cells


func _on_end_turn() -> void:
	if _animating or _moved_for_card:
		return
	if GameManager.tutorial_mission and not TutorialHooks.allows("end_round"):
		return
	if GameManager.tutorial_mission:
		TutorialHooks.notify("end_round")
	await _finish_player_turn()


## Cards without Retain leave when a round continues, feeding Overdrive until the gauge is full.
## Past full, they still leave the hand. The last round takes Retain too, since nothing follows it.
func _pitch_unretained(include_retain := false) -> void:
	_clear_play()
	_selected = null
	var pitched: Array[CardData] = []
	var kept: Array[CardData] = []
	for card in _hand:
		if card == null:
			continue
		if card.retain and not include_retain:
			kept.append(card)
		else:
			pitched.append(card)
	if pitched.is_empty():
		return
	_hand = kept
	for card in pitched:
		_discard.append(card)
	pitched.sort_custom(func(a: CardData, b: CardData) -> bool:
		return _pitch_origin(_view_for(a)).x < _pitch_origin(_view_for(b)).x
	)
	for index in pitched.size():
		var view := _view_for(pitched[index])
		var start_scale := view.scale.x if view != null else 1.0
		_grant_pitch_charge(_pitch_origin(view), index * CARD_STAGGER, start_scale)


## The last round pitches the whole hand, Retain included. Results wait until those cards have left.
func _pitch_before_results() -> void:
	var leaving := 0
	for card in _hand:
		if card != null:
			leaving += 1
	_pitch_unretained(true)
	_refresh()
	if leaving <= 0 or not is_inside_tree():
		return
	var tail := CARD_STAGGER * float(leaving - 1)
	await get_tree().create_timer(GaugePitch.FLIGHT + tail).timeout


## Next-round banner plays while leaving cards are still in hand, each marked with a lightning 1.
func _announce_pitch(include_retain: bool) -> void:
	var tucked := _hand_tucked
	# Held true so the pre-banner refresh raises the hand without drawing Overdrive cards into it.
	_animating = true
	state.phase = "player"
	state.active_unit_id = ""
	_refresh()
	if tucked and is_inside_tree():
		await get_tree().create_timer(HAND_TUCK_TIME).timeout
	if _closing or not is_inside_tree() or state == null:
		_animating = false
		return
	_show_pitch_marks(include_retain)
	await _announce_round(state.turn + 1, true)
	_animating = false
	_clear_pitch_marks()


func _show_pitch_marks(include_retain: bool) -> void:
	_clear_pitch_marks()
	if _banner_layer == null:
		return
	var leaving: Array[CardData] = []
	for card in _hand:
		if card == null:
			continue
		if card.retain and not include_retain:
			continue
		leaving.append(card)
	for card in leaving:
		var view := _view_for(card)
		if view == null:
			continue
		var mark := PITCH_MARK_SCENE.instantiate() as PitchMark
		_banner_layer.add_child(mark)
		_pitch_marks.append(mark)
		mark.pop_on(view)


func _clear_pitch_marks() -> void:
	for mark in _pitch_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_pitch_marks.clear()


func _finish_player_turn() -> void:
	var played := _followup_move
	_clear_play()
	_selected = null
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	if played:
		# The card's own tick was waiting on the follow-up. The call below is the round.
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
		if not (GameManager.tutorial_mission and _tutorial_loss(true)):
			await _pitch_before_results()
		if _closing or not is_inside_tree() or state == null:
			return
		_finish_if_over(true)
		return
	await _announce_pitch(false)
	if _closing or not is_inside_tree() or state == null:
		return
	_pitch_unretained()
	_advance_round()
	state.phase = "player"
	state.active_unit_id = ""
	_refresh()
	await _return_to_player(true)
	_tutorial_player_ready()


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
	_refresh()
	await _execute_enemy_phase()
	_animating = false
	if state.battle_status != "active":
		_refresh()
		_finish_if_over()
		return
	if advance_round:
		if state.turn >= ROUND_LIMIT:
			if not (GameManager.tutorial_mission and _tutorial_loss(true)):
				await _pitch_before_results()
			if _closing or not is_inside_tree() or state == null:
				return
			_finish_if_over(true)
			return
		await _announce_pitch(false)
		if _closing or not is_inside_tree() or state == null:
			return
		_pitch_unretained()
		_advance_round()
	else:
		_draw_up()
	state.phase = "player"
	state.active_unit_id = ""
	_refresh()
	await _return_to_player(true)
	_tutorial_player_ready()


func _execute_enemy_phase() -> void:
	await _act_enemies(_by_speed(state.living_units("enemy")), false)


func _arm_enemy_turns() -> void:
	for unit in state.units:
		if unit != null and unit.team == "enemy":
			unit.cards_until_turn = maxi(unit.turn_count, 1)


## One step on every enemy clock. A 1-action card does this, and so does ending the round.
## A free card and a charge card leave the clocks where they are.
func _after_card_played() -> void:
	var steps := 1
	if _pending_clock_steps >= 0:
		steps = _pending_clock_steps
		_pending_clock_steps = -1
	_resolving_card = false
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	if steps <= 0:
		_refresh()
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
		var ward := MechDecks.ward_card(enemy.data)
		if ward != null:
			await get_tree().create_timer(ENEMY_ATTACK_DELAY).timeout
			if not is_inside_tree() or state == null or state.battle_status != "active":
				break
			if enemy.alive:
				SoundBank.play_card(ward)
				_grant_team_barrier(enemy, ward)
				_refresh()
		var strike := MechDecks.strike_card(enemy.data) if ward == null else null
		var plan := EnemyAi.act(enemy, state, strike)
		var step: Vector2i = plan.get("step", state.position_of(enemy))
		var target := plan.get("target") as MechState
		_refresh()
		var stepping := step != state.position_of(enemy)
		if (stepping or target != null) and state.battle_status == "active":
			await get_tree().create_timer(ENEMY_ATTACK_DELAY).timeout
			if not is_inside_tree() or state == null or state.battle_status != "active":
				break
			if not enemy.alive:
				state.active_unit_id = ""
				continue
			if stepping:
				var arrived := await _slide_unit(enemy, step)
				if not is_inside_tree() or state == null or state.battle_status != "active":
					break
				if not enemy.alive:
					state.active_unit_id = ""
					continue
				if not arrived:
					target = null
			if target != null and target.alive:
				var enemy_cell := state.position_of(enemy)
				var target_cell := state.position_of(target)
				enemy.face_toward_x(enemy_cell.x, target_cell.x)
				var attacker_sprite := _sprite_for(enemy)
				if attacker_sprite != null:
					attacker_sprite.flip_h = enemy.facing < 0
				SoundBank.play_card(strike)
				var result := _strike(enemy, target, strike)
				await _play_attack(attacker_sprite, _button_for(_struck(result, target)), null, result, _impact_heavy(strike))
				if not is_inside_tree() or state == null:
					return
				state.sync_occupants()
				_note_outcome()
		if enemy.alive and state != null and state.battle_status == "active":
			if recharge:
				enemy.cards_until_turn = maxi(enemy.turn_count, 1)
			else:
				_note_acted(enemy)
		state.active_unit_id = ""
		_refresh()
	if state != null:
		state.active_unit_id = ""


func _grant_team_barrier(enemy: MechState, card: CardData) -> void:
	var amount := 0 if card == null else maxi(card.barrier, 0)
	if amount <= 0 or state == null:
		return
	for ally in state.living_units(enemy.team):
		ally.add_barrier(amount)
		_show_guard_gain(ally, amount)


## A death's hand cards count only when that blow ends the battle.
func _note_outcome() -> void:
	if state == null:
		return
	state.check_outcome()
	if state.battle_status == "active":
		_ending_hand.clear()


## Cards still in hand, plus a hand just lost on the finishing blow, each add 1 charge.
func _charge_ending_hand() -> void:
	var held: Array[CardData] = _hand.duplicate()
	_hand.clear()
	for card in held:
		if card == null:
			continue
		_discard.append(card)
		GameManager.charge_from_pitch()
	for card in _ending_hand:
		if card != null:
			GameManager.charge_from_pitch()
	_ending_hand.clear()
	_refresh_squad_gauge()


func _finish_if_over(round_limit := false) -> void:
	if _closing or state == null:
		return
	if state.battle_status == "active" and not round_limit:
		return
	if GameManager.tutorial_mission and _tutorial_loss(round_limit):
		_closing = true
		_targeting = false
		_clear_play()
		_restart_tutorial_fight()
		return
	_closing = true
	_targeting = false
	_clear_play()
	_charge_ending_hand()
	if activate_button != null:
		activate_button.disabled = true
		_stop_activate_flash()
	_release_overdrive_fx()
	_stop_active_cell_pulse()
	if discard_overlay != null:
		discard_overlay.visible = false
	_hide_status_tip()
	var reason := ""
	if round_limit:
		reason = "Battle ended after %d rounds." % ROUND_LIMIT
	_results_reason = reason
	if GameManager.tutorial_mission and state != null and state.battle_status == "victory":
		TutorialHooks.notify("won")
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
	if results != null:
		results.visible = false
	var units: Array = []
	if state != null:
		units = state.units
	var reward_lesson := GameManager.tutorial_mission and TutorialHooks.phase().begins_with("r")
	var no_reward := upgrade_pick == null or _mission_is_won() or UpgradeRoller.legal_choices(units, GameManager.mission_upgrades).is_empty()
	if (GameManager.tutorial_mission and not reward_lesson) or no_reward:
		if reward_lesson:
			TutorialHooks.notify("won")
		_leave_battle()
		return
	upgrade_pick.present(units, GameManager.mission_upgrades)
	if reward_lesson:
		_tutorial_reward_ready()


func _tutorial_reward_ready() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	TutorialHooks.settled()


## The last fight of a mission has nothing left to spend an upgrade on.
func _mission_is_won() -> bool:
	if _results_reason != "" or state == null or state.battle_status != "victory":
		return false
	return not UpgradeRoller.any_alive(GameManager.enemy_mechs)


func _on_upgrade_confirmed(choice: UpgradeChoice) -> void:
	SoundBank.play("upgrade")
	UpgradeDeck.apply(choice, GameManager.mission_upgrades)
	if upgrade_pick != null:
		upgrade_pick.visible = false
	if GameManager.tutorial_mission:
		TutorialHooks.notify("reward")
	_leave_battle()


func _on_upgrade_skipped() -> void:
	GameManager.charge_from_skip()
	if upgrade_pick != null:
		upgrade_pick.visible = false
	if GameManager.tutorial_mission and TutorialHooks.phase().begins_with("r"):
		TutorialHooks.notify("won")
	_leave_battle()


func _leave_battle() -> void:
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
	_step_undo = false
	_step_origin = Vector2i(-1, -1)
	_step_facing = 1
	_chosen = null
	_move_targets.clear()
	_sync_play_prompt()


## The grid banner names the click the board is waiting for. A slide or a strike hides it.
func _sync_play_prompt() -> void:
	if _play_prompt == null:
		return
	var line := _play_prompt_line()
	if line == "":
		_play_prompt.clear()
	else:
		_play_prompt.show_line(line)


func _play_prompt_line() -> String:
	if _animating or not _targeting or _chosen == null or _play_step == "" or _selected == null:
		return ""
	if state == null or state.phase != "player" or state.battle_status != "active":
		return ""
	var who := _selected.display_name
	if (_play_step == "attack" or _play_step == "breach") and _can_keep_step(_selected):
		return "Select %s to finish" % who
	match _play_step:
		"move":
			return "Move %s" % who
		"attack":
			return "Select enemy to attack"
		"guard":
			return _guard_prompt_line(_chosen)
		"breach":
			return "Attack every enemy in range"
		"front":
			return "Choose a direction"
		"confirm":
			return _confirm_prompt_line(_chosen, who)
	return ""


func _guard_prompt_line(card: CardData) -> String:
	if card == null:
		return ""
	var gift := "Barrier" if card.barrier > 0 else "Guard"
	if card.target_type == "friendly":
		return "Select a mech to add %s to" % gift
	return "Select ally to add %s to" % gift


func _confirm_prompt_line(card: CardData, who: String) -> String:
	if card == null:
		return ""
	if card.is_dodge():
		return "Keep card in hand to activate"
	if card.guards_self():
		var gift := "Barrier" if card.barrier > 0 else "Guard"
		return "Select %s to add %s" % [who, gift]
	if card.target_type == "squad":
		return "Select %s to add charge" % who
	if card.target_type == "team":
		return "Select %s to shield the squad" % who
	if card.target_type == "enemies":
		return "Select %s to attack every enemy in range" % who
	return ""


func _on_move_cell(coords: Vector2i) -> void:
	if _animating or _chosen == null or _selected == null:
		return
	var actor := _selected
	var origin := state.position_of(actor)
	var facing := actor.facing
	if coords == origin:
		if _followup_move:
			await _finish_followup()
		elif _guards_then_steps(_chosen):
			await _grant_guard(actor, actor, _chosen, false)
		elif _chosen.moves_only():
			_clear_play()
			_refresh()
		elif _chosen.target_type == "enemies" and _chosen.moves_before():
			if GameManager.tutorial_mission and not TutorialHooks.allows("stay"):
				return
			if _can_strike_from(origin, _chosen):
				TutorialHooks.notify("stay")
				await _play_breach(actor, _chosen)
		elif _steps_before_guard(_chosen):
			_stay_for_guard(actor)
		elif _can_strike_from(origin, _chosen):
			_play_step = "attack"
			_refresh()
		return
	var unit := _unit_at(coords)
	if _steps_before_guard(_chosen) and unit != null and _guard_targets(actor, _chosen).has(unit):
		await _grant_guard(actor, unit, _chosen)
		return
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
	if _guards_then_steps(_chosen):
		await _grant_guard(actor, actor, _chosen, false)
		return
	if _chosen != null and _steps_before_guard(_chosen):
		if _guard_targets(actor, _chosen).is_empty():
			await _keep_step()
		else:
			_moved_for_card = true
			_play_step = "guard"
			_targeting = true
			_refresh()
		return
	if _chosen != null and _chosen.steps_then_acts() and not _followup_move:
		_arm_step_undo(origin, facing)
		_offer_followup()
		return
	if _chosen != null and _chosen.moves_only():
		var stepped := _chosen
		_spend(stepped)
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
			return
		var landing := _best_landing(target_pos, _chosen)
		if landing.x < 0:
			return
		if not await _commit_step(_selected, landing):
			return
		_moved_for_card = true
	_play_step = "attack"
	await _try_attack(target)


func _commit_step(actor: MechState, coords: Vector2i) -> bool:
	_animating = true
	_sync_play_prompt()
	var moved := await _slide_unit(actor, coords)
	if not is_inside_tree():
		return false
	_animating = false
	_sync_play_prompt()
	return moved


func _finish_followup() -> void:
	_clear_play()
	await _after_card_played()
	await _return_to_player()


func _arm_step_undo(origin: Vector2i, facing: int) -> void:
	_step_origin = origin
	_step_facing = facing
	_step_undo = true


func _offer_followup() -> void:
	_moved_for_card = true
	_targeting = true
	if _chosen != null and _chosen.target_type == "enemies":
		_play_step = "breach"
	elif _steps_before_guard(_chosen):
		_play_step = "guard"
	else:
		_play_step = "attack"
	_refresh()


func _followup_ready(actor: MechState) -> bool:
	var card := _chosen
	if actor == null or card == null or state == null:
		return false
	if _steps_before_guard(card):
		return not _guard_targets(actor, card).is_empty()
	return _can_strike_from(state.position_of(actor), card)


func _can_keep_step(unit: MechState) -> bool:
	return _step_undo and unit != null and unit == _selected and not _followup_ready(_selected)


func _keep_step() -> void:
	var card := _chosen
	var actor := _selected
	if card == null or actor == null or _animating:
		return
	_step_undo = false
	_spend(card)
	await _finish_followup()


func _on_breach_cell(coords: Vector2i) -> void:
	var card := _chosen
	var actor := _selected
	if card == null or actor == null or state == null:
		return
	var origin := state.position_of(actor)
	if coords == origin:
		if _followup_ready(actor):
			await _play_breach(actor, card)
		else:
			await _keep_step()
		return
	var unit := _unit_at(coords)
	if unit != null and unit.alive and unit.team == "enemy" and card.reaches(_manhattan(origin, state.position_of(unit))):
		await _play_breach(actor, card)


func _on_card_undo_drag(card: CardData) -> void:
	if card != _chosen or not _step_undo or _animating:
		return
	await _on_undo_step()


func _can_undo_drag(card: CardData) -> bool:
	return (
		_step_undo
		and card == _chosen
		and not _animating
		and state != null
		and state.battle_status == "active"
		and state.phase == "player"
	)


func _on_undo_step() -> void:
	if not _step_undo or _animating or _selected == null or state == null:
		return
	var actor := _selected
	var dest := _step_origin
	var facing := _step_facing
	_animating = true
	_sync_play_prompt()
	if state.position_of(actor) != dest:
		var walked := await _slide_unit(actor, dest)
		if not is_inside_tree():
			return
		if not walked:
			state.move_unit(actor, dest)
	if not is_inside_tree() or state == null:
		return
	actor.facing = facing
	_animating = false
	_clear_play()
	_refresh()


func _rebuild_move_targets() -> void:
	_move_targets.clear()
	if _play_step != "move" or _chosen == null or _selected == null:
		return
	var origin := state.position_of(_selected)
	var cells := _reachable(origin, _chosen.movement)
	if cells.is_empty():
		return
	for coords in cells:
		_move_targets[coords] = true
	# Staying put is a legal step whenever the unit can move at least one space.
	_move_targets[origin] = true


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
		# Same band as a standing sprite, under StageMap.SHADOW_Z.
		token.z_index = MECH_SPRITE_Z
		token.scale = sprite.scale
		token.flip_h = sprite.flip_h
		MechSprites.play_moving(token)
		add_child(token)
		token.global_position = sprite.global_position
		_sync_barrier(token, unit)
		var aura := sprite.get_node_or_null("PowerUp") as PowerUp
		if aura != null:
			aura.reparent(token, false)
			aura.position = Vector2.ZERO
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
	state.move_unit(unit, dest)
	var dest_sprite: AnimatedSprite2D = null
	var dest_button := _buttons.get(dest) as Button
	if dest_button != null:
		dest_sprite = dest_button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if token != null and dest_sprite != null:
		var aura := token.get_node_or_null("PowerUp") as PowerUp
		if aura != null:
			aura.reparent(dest_sprite, false)
			aura.position = Vector2.ZERO
	# The walk hides the cell sprite. Put it back before an attack plays on it.
	_present_cell_at(origin)
	_present_cell_at(dest)
	if token != null:
		token.queue_free()
	return true


func _cell_color(coords: Vector2i) -> Color:
	var idle := CELL_FLOOR
	if _play_step == "confirm" and _chosen != null:
		if _chosen.is_dodge():
			return idle
		var owner := _owner_of(_chosen)
		if owner != null and state.position_of(owner) == coords:
			return MOVE_FILL
		return idle
	if _play_step == "guard" and _chosen != null and _chosen.guards_ally():
		if _selected != null and _can_keep_step(_selected) and state.position_of(_selected) == coords:
			return MOVE_FILL
		var holder := _owner_of(_chosen)
		for ally in _guard_targets(holder, _chosen):
			if state.position_of(ally) == coords:
				return GUARD_FILL
		return idle
	if state == null or state.battle_status != "active":
		return idle
	if _selected != null and _play_step == "move" and _move_targets.has(coords):
		return MOVE_FILL
	if _selected == null or not _targeting or _chosen == null:
		if _enemy_reaches(coords):
			return ATTACK_FILL
		return idle
	if _play_step == "move" and _chosen.moves_before() and not _followup_move:
		var unit := _unit_at(coords)
		if unit != null and unit.alive and unit.team == "enemy" and _enemy_in_reach(unit):
			return ATTACK_FILL
		return idle
	if _play_step == "breach":
		var stood := state.position_of(_selected)
		if coords == stood:
			return MOVE_FILL
		if _chosen.reaches(_manhattan(stood, coords)):
			var struck := _unit_at(coords)
			if struck != null and struck.alive and struck.team == "enemy":
				return ATTACK_FILL
		return idle
	if _play_step == "attack":
		var current := state.position_of(_selected)
		if coords == current and _can_keep_step(_selected):
			return MOVE_FILL
		if _chosen.reaches(_manhattan(current, coords)) and _shows_strike_square(coords):
			return ATTACK_FILL
	if _play_step == "front":
		var origin := state.position_of(_selected)
		if _front_cells(origin, 1).has(coords) or _front_cells(origin, -1).has(coords):
			return ATTACK_FILL
	return idle


## The enemy opened in the status tip, when their strike range should show on the board.
func _ranged_enemy() -> MechState:
	if _chosen != null or state == null or state.battle_status != "active":
		return null
	var unit := _status_unit
	if unit == null or not unit.alive or unit.team != "enemy":
		return null
	if state.unit_by_id(unit.id) == null:
		return null
	return unit


func _enemy_reaches(coords: Vector2i) -> bool:
	var unit := _ranged_enemy()
	if unit == null or state.grid == null:
		return false
	var card := MechDecks.strike_card(unit.data)
	if card == null:
		return false
	var origin := state.position_of(unit)
	var bounds := Vector2i(state.grid.width, state.grid.height)
	return StrikeRangeScript.attack_cells(origin, card, bounds).has(coords)


## Range squares stay off allied mechs unless this attack hits them too.
func _shows_strike_square(coords: Vector2i) -> bool:
	if _selected == null or _selected.team != "player":
		return true
	if _chosen != null and _chosen.hits_front():
		return true
	var unit := _unit_at(coords)
	return unit == null or not unit.alive or unit.team != "player"


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _present_cell_at(coords: Vector2i) -> void:
	var button := _buttons.get(coords) as Button
	if button == null:
		return
	_present_cell(button, coords, _unit_at(coords))


func _present_cell(button: Button, coords: Vector2i, unit: MechState) -> void:
	var sprite := button.get_node("MechSprite") as AnimatedSprite2D
	var caption := button.get_node("Caption") as Label
	_show_turn_count(button, unit)
	_show_hit_points(button, unit)
	_show_barrier(button, unit)
	_show_guard(button, unit)
	_show_evade(button, unit)
	if unit != null and unit.art_id != "" and _show_mech_sprite(sprite, unit):
		button.text = ""
		caption.visible = false
		caption.text = ""
		_place_sprite(button, sprite)
	else:
		_hide_mech_sprite(sprite, caption)
		button.text = ""
	_paint(button, _cell_color(coords))
	_paint_cell_mark(button, coords, unit)
	_sync_overdrive_cell(button, unit)
	_sync_intercept_cell(button, _cell_in_intercept_zone(coords), unit)


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
	sprite.set_meta("body_scale", unit.body_scale())
	_plant_mech_sprite(sprite)
	sprite.visible = true
	sprite.modulate = Color.WHITE if unit.alive else Color(0.35, 0.35, 0.35)
	_sync_barrier(sprite, unit)
	return true


func _button_for(unit: MechState) -> Button:
	if unit == null or state == null:
		return null
	var button := _buttons.get(state.position_of(unit)) as Button
	if button != null:
		return button
	return _scenery.get(_bystander_view(unit)) as Button


func _sprite_for(unit: MechState) -> AnimatedSprite2D:
	var button := _button_for(unit)
	if button == null:
		return null
	return button.get_node_or_null("MechSprite") as AnimatedSprite2D


func _play_attack(
	attacker: AnimatedSprite2D,
	target_button: Button,
	unit: MechState = null,
	held: Dictionary = {},
	heavy: bool = false,
	killed: bool = false,
) -> void:
	if unit != null and WeaponVolley.has_profile(unit.art_id):
		var buttons: Array[Button] = []
		var results: Array[Dictionary] = []
		if target_button != null:
			buttons.append(target_button)
			results.append(held)
		elif not held.is_empty():
			_show_strike_numbers(_struck(held, null), held)
		await _play_projectile_attack(attacker, unit, buttons, results, heavy)
		return
	var zoom_in := _begin_attack_zoom(attacker, [target_button])
	var waits: Array[AnimatedSprite2D] = []
	if _play_mech_anim(attacker, "attack"):
		waits.append(attacker)
	var flash := _begin_hit_flash(target_button)
	var flash_done: Array = [flash == null]
	if flash != null:
		flash.finished.connect(func() -> void:
			flash_done[0] = true
		)
	var pending := [0]
	var dodged := str(held.get("defense_kind", "")) == "Dodge"
	if not dodged:
		var destroyed := killed or bool(held.get("destroyed", false))
		_spawn_impacts(target_button, heavy, destroyed, pending)
	await _wait_for_sprites(waits)
	await _await_impacts(pending)
	while not flash_done[0]:
		await get_tree().process_frame
	if is_instance_valid(attacker) and attacker.animation == "attack":
		_play_mech_anim(attacker, "idle")
	await _finish_attack_zoom(zoom_in)


## Fire pose, then real rounds. The floating number waits until a round arrives.
func _play_projectile_attack(
	attacker: AnimatedSprite2D,
	unit: MechState,
	buttons: Array[Button],
	results: Array[Dictionary],
	heavy: bool = false,
) -> void:
	var aimed: Array = []
	for button in buttons:
		if button != null:
			aimed.append(button)
	var zoom_in := _begin_attack_zoom(attacker, aimed)
	if attacker != null and unit != null:
		attacker.flip_h = unit.facing < 0
	var posed := _play_mech_anim(attacker, "attack")
	var delay := WeaponVolley.muzzle_delay(unit.art_id) if unit != null else 0.0
	if delay > 0.0 and is_inside_tree():
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var flashes: Array[Tween] = []
	var pending := [0]
	if shots != null and attacker != null and unit != null and not buttons.is_empty():
		var centers: Array[Vector2] = []
		var dodged: Array[bool] = []
		for i in buttons.size():
			centers.append(_aim_global(buttons[i]))
			var result: Dictionary = results[i] if i < results.size() else {}
			dodged.append(str(result.get("defense_kind", "")) == "Dodge")
		await WeaponVolley.play(shots, attacker, centers, dodged, unit.art_id, func(index: int) -> void:
			var landed: Dictionary = results[index] if index < results.size() else {}
			var button: Button = buttons[index] if index < buttons.size() else null
			var flash := _land_projectile(button, landed, heavy, pending)
			if flash != null:
				flashes.append(flash)
		)
	if not is_inside_tree():
		return
	while posed and is_instance_valid(attacker) and attacker.animation == "attack" and attacker.is_playing():
		if not is_inside_tree():
			return
		await get_tree().process_frame
	var waiting := true
	while waiting:
		waiting = false
		for flash in flashes:
			if flash != null and flash.is_valid() and flash.is_running():
				waiting = true
				break
		if waiting:
			if not is_inside_tree():
				return
			await get_tree().process_frame
	await _await_impacts(pending)
	if is_instance_valid(attacker) and attacker.animation == "attack":
		_play_mech_anim(attacker, "idle")
	await _finish_attack_zoom(zoom_in)


func _land_projectile(button: Button, result: Dictionary, heavy: bool, pending: Array) -> Tween:
	var dodged := str(result.get("defense_kind", "")) == "Dodge"
	var flash: Tween = null
	if button != null and not dodged:
		flash = _begin_hit_flash(button)
		_spawn_impacts(button, heavy, bool(result.get("destroyed", false)), pending)
	if not result.is_empty():
		_show_strike_numbers(_struck(result, null), result)
	return flash


func _aim_global(button: Button) -> Vector2:
	if button == null or not is_instance_valid(button):
		return Vector2.ZERO
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite != null:
		return sprite.global_position
	return button.get_global_rect().get_center()


func _play_area(attacker: AnimatedSprite2D, cells: Array[Vector2i], heavy: bool = false, pre_kill: bool = false) -> void:
	var aimed: Array[Node] = []
	for coords in cells:
		var aimed_button := _buttons.get(coords) as Button
		if aimed_button != null:
			aimed.append(aimed_button)
	var zoom_in := _begin_attack_zoom(attacker, aimed)
	var waits: Array[AnimatedSprite2D] = []
	if _play_mech_anim(attacker, "attack"):
		waits.append(attacker)
	var flashes: Array[Tween] = []
	var pending := [0]
	for coords in cells:
		var button := _buttons.get(coords) as Button
		var flash := _begin_hit_flash(button)
		if flash != null:
			flashes.append(flash)
		_spawn_impacts(button, heavy, _impact_destroyed(coords, pre_kill), pending)
	await _wait_for_sprites(waits)
	await _await_impacts(pending)
	var running := true
	while running:
		running = false
		for flash in flashes:
			if flash != null and flash.is_valid() and flash.is_running():
				running = true
				break
		if running:
			await get_tree().process_frame
	if is_instance_valid(attacker) and attacker.animation == "attack":
		_play_mech_anim(attacker, "idle")
	await _finish_attack_zoom(zoom_in)


func _play_mech_anim(sprite: AnimatedSprite2D, anim_name: String) -> bool:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return false
	sprite.play(anim_name)
	_plant_mech_sprite(sprite)
	return true


## Keeps a wide attack's back edge on the idle back edge, and draws that reach over the next cell.
func _plant_mech_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	sprite.offset = MechSprites.reach_offset(sprite)
	sprite.z_index = MECH_REACH_Z if absf(sprite.offset.x) > 0.01 else MECH_SPRITE_Z
	if _bystander_sprite(sprite):
		sprite.z_index = BYSTANDER_SPRITE_Z


func _begin_attack_zoom(attacker: Node, targets: Array) -> Tween:
	var points: Array[Vector2] = []
	_add_focus_point(attacker, points)
	for node in targets:
		_add_focus_point(node as Node, points)
	if not _attack_zoom_active:
		_attack_zoom_from = _field_zoom
		_attack_zoom_focus = _field_focus
		_attack_zoom_active = true
	var to_zoom := minf(_attack_zoom_from * FIELD_ZOOM_MAX, FIELD_ZOOM_MAX)
	var to_focus := _attack_zoom_focus
	if not points.is_empty() and grid_host != null:
		var min_p := points[0]
		var max_p := points[0]
		for point in points:
			min_p.x = minf(min_p.x, point.x)
			min_p.y = minf(min_p.y, point.y)
			max_p.x = maxf(max_p.x, point.x)
			max_p.y = maxf(max_p.y, point.y)
		to_focus = (min_p + max_p) * 0.5
		var pad := _cell_span() * 1.45
		var span := (max_p - min_p) + Vector2(pad, pad)
		if span.x > 1.0 and span.y > 1.0:
			var fit := minf(grid_host.size.x / span.x, grid_host.size.y / span.y)
			to_zoom = clampf(minf(to_zoom, fit), _attack_zoom_from, to_zoom)
		to_focus = _clamp_field_focus(to_focus, to_zoom)
	if to_zoom <= _attack_zoom_from + 0.001:
		to_zoom = _attack_zoom_from
		to_focus = _attack_zoom_focus
	return _tween_field_view(to_zoom, to_focus, ATTACK_ZOOM_IN, Tween.EASE_OUT)


func _finish_attack_zoom(zoom_in: Tween) -> void:
	if zoom_in != null and zoom_in.is_valid() and zoom_in.is_running():
		await zoom_in.finished
	if not is_inside_tree():
		_attack_zoom_active = false
		return
	if not _attack_zoom_active:
		return
	var back := _tween_field_view(_attack_zoom_from, _attack_zoom_focus, ATTACK_ZOOM_OUT, Tween.EASE_IN_OUT)
	if back != null and back.is_valid() and back.is_running():
		await back.finished
	_attack_zoom_active = false


func _tween_field_view(to_zoom: float, to_focus: Vector2, seconds: float, ease: Tween.EaseType) -> Tween:
	var from_zoom := _field_zoom
	var from_focus := _field_focus
	if is_equal_approx(from_zoom, to_zoom) and from_focus.distance_to(to_focus) < 1.0:
		_field_zoom = to_zoom
		_field_focus = to_focus
		_apply_field_zoom()
		return null
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	_zoom_tween.tween_method(_step_field_view.bind(from_zoom, to_zoom, from_focus, to_focus), 0.0, 1.0, seconds)
	return _zoom_tween


func _step_field_view(t: float, from_zoom: float, to_zoom: float, from_focus: Vector2, to_focus: Vector2) -> void:
	_field_zoom = lerpf(from_zoom, to_zoom, t)
	_field_focus = _clamp_field_focus(from_focus.lerp(to_focus, t), _field_zoom)
	_apply_field_zoom()


func _add_focus_point(node: Node, points: Array[Vector2]) -> void:
	if node == null or not is_instance_valid(node):
		return
	var field := grid.get_parent() as Control
	if field == null:
		return
	var control := node as Control
	if control == null:
		control = node.get_parent() as Control
	var global_point := Vector2.ZERO
	if control != null:
		global_point = control.get_global_rect().get_center()
	elif node is CanvasItem:
		global_point = (node as CanvasItem).get_global_transform().origin
	else:
		return
	points.append(field.get_global_transform().affine_inverse() * global_point)


func _cell_span() -> float:
	for coords in _buttons:
		var button := _buttons[coords] as Control
		if button != null and button.size.x > 1.0:
			return maxf(button.size.x, button.size.y)
	return 64.0


func _clamp_field_focus(focus: Vector2, zoom: float) -> Vector2:
	var field := grid.get_parent() as Control
	if field == null or grid_host == null or zoom <= 0.0:
		return focus
	var visible := grid_host.size / zoom
	var pivot := field.pivot_offset
	return Vector2(
		_clamp_focus_axis(focus.x, visible.x, field.size.x, pivot.x),
		_clamp_focus_axis(focus.y, visible.y, field.size.y, pivot.y)
	)


func _clamp_focus_axis(value: float, visible: float, length: float, fallback: float) -> float:
	if visible >= length - 0.5:
		return fallback
	var half := visible * 0.5
	return clampf(value, half, maxf(half, length - half))


func _begin_hit_flash(button: Button) -> Tween:
	if button == null or not is_instance_valid(button):
		return null
	var flashes := 1
	if button.has_meta("hit_flash"):
		flashes = int(button.get_meta("hit_flash")) + 1
	button.set_meta("hit_flash", flashes)
	var lit := Color(0.95, 0.62, 0.62)
	var dim := CELL_FLOOR
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


func _impact_heavy(card: CardData) -> bool:
	return card != null and card.damage >= HEAVY_IMPACT_DAMAGE


## A finisher plays before the strike, so the mech is still standing. Afterwards, death is already applied.
func _impact_destroyed(coords: Vector2i, pre_kill: bool) -> bool:
	var unit := _unit_at(coords)
	if unit == null:
		return false
	if pre_kill:
		return unit.alive
	return not unit.alive


func _spawn_impacts(button: Button, heavy: bool, destroyed: bool, pending: Array) -> void:
	if button == null or not is_instance_valid(button):
		return
	SoundBank.play("explosion")
	var again := create_tween()
	again.tween_interval(0.5)
	again.tween_callback(SoundBank.play.bind("explosion"))
	if destroyed:
		SoundBank.play("explosion_large")
	var center := _impact_center(button)
	var fitted := _impact_scale(button)
	var span := minf(button.size.x, button.size.y)
	if span < 1.0:
		span = 72.0
	var scatter := span * 0.2
	for size_name in _impact_mix(heavy):
		_spawn_explosion(button, size_name, center, fitted, scatter, randf() * 0.16, pending)
	if destroyed:
		_spawn_explosion(button, "medium", center, fitted, scatter * 0.18, 0.28, pending)


func _impact_mix(heavy: bool) -> Array[String]:
	var sheets: Array[String] = []
	var mini_count := 5 if heavy else 1
	var total := 8 if heavy else 2
	for index in total:
		sheets.append("mini" if index < mini_count else "small")
	sheets.shuffle()
	return sheets


func _spawn_explosion(
	button: Button,
	size_name: String,
	center: Vector2,
	fitted: Vector2,
	radius: float,
	delay: float,
	pending: Array,
) -> void:
	var frames := MechSprites.explosion_frames(size_name)
	if frames == null:
		return
	var burst := EXPLOSION_SCENE.instantiate() as AnimatedSprite2D
	if burst == null:
		return
	button.add_child(burst)
	burst.sprite_frames = frames
	burst.position = center + _scatter_offset(radius)
	burst.scale = fitted * IMPACT_VISUAL_SCALE
	burst.flip_h = randf() < 0.5
	burst.z_index = 7 if size_name == "medium" else 6
	burst.visible = false
	pending[0] += 1
	burst.animation_finished.connect(func() -> void:
		pending[0] -= 1
		if is_instance_valid(burst):
			burst.queue_free()
	, CONNECT_ONE_SHOT)
	if size_name == "medium":
		_vanish_on_medium_frame(button, burst)
	_arm_explosion(burst, delay, pending)


## The body stays through the opening frames, then leaves while the core covers it.
func _vanish_on_medium_frame(button: Button, burst: AnimatedSprite2D) -> void:
	var hide := _on_medium_vanish_frame.bind(button, burst)
	burst.set_meta("vanish_hide", hide)
	burst.frame_changed.connect(hide)


func _on_medium_vanish_frame(button: Button, burst: AnimatedSprite2D) -> void:
	if not is_instance_valid(burst) or burst.frame < MEDIUM_VANISH_FRAME:
		return
	var hide: Callable = burst.get_meta("vanish_hide", Callable())
	if hide.is_valid() and burst.frame_changed.is_connected(hide):
		burst.frame_changed.disconnect(hide)
	_vanish_destroyed_mech(button)


func _vanish_destroyed_mech(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	var caption := button.get_node_or_null("Caption") as Label
	if sprite != null and caption != null:
		_hide_mech_sprite(sprite, caption)
	elif sprite != null:
		sprite.visible = false


func _scatter_offset(radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle)) * sqrt(randf()) * radius


func _arm_explosion(burst: AnimatedSprite2D, delay: float, pending: Array) -> void:
	var start := func() -> void:
		if not is_instance_valid(burst) or burst.sprite_frames == null:
			pending[0] -= 1
			return
		burst.visible = true
		burst.play("burst")
	if delay <= 0.0 or not is_inside_tree():
		start.call()
		return
	get_tree().create_timer(delay).timeout.connect(start, CONNECT_ONE_SHOT)


func _await_impacts(pending: Array) -> void:
	while int(pending[0]) > 0:
		if not is_inside_tree():
			return
		await get_tree().process_frame


func _impact_center(button: Button) -> Vector2:
	var mech := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if mech != null:
		return mech.position
	return button.size * 0.5


func _impact_scale(button: Button) -> Vector2:
	var mech := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if mech != null and mech.sprite_frames != null:
		return mech.scale
	var span := minf(button.size.x, button.size.y)
	if span < 1.0:
		return Vector2.ONE
	return Vector2.ONE * span * 0.72 * 1.4 / 64.0


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
	var fit := minf(button.size.x, button.size.y) * 0.72 * 1.4 / longest
	var body := float(sprite.get_meta("body_scale", 1.0))
	sprite.position = button.size * 0.5 + Vector2(0.0, frame.y * fit * (1.0 - body) * 0.5)
	sprite.scale = Vector2(fit, fit) * body


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
	for id in _card_views.keys():
		var old := _card_views[id] as MechCard
		if is_instance_valid(old):
			old.queue_free()
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
		var deck := UpgradeDeck.runtime_cards(unit.data, GameManager.mission_upgrades)
		if deck.is_empty() and MechDecks.for_mech(unit.data) == null:
			continue
		for card in deck:
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
	if count >= 3:
		return HAND_CAP
	return count + HAND_BASE


func _draw_up() -> void:
	_pull_specials()
	var favored := _favored_draw()
	while _hand.size() < _hand_limit() and not _deck.is_empty():
		var card := TacticDraw.take(_deck, favored)
		if card != null:
			_hand.append(card)
	if GameManager.tutorial_mission:
		var round := 1 if state == null else state.turn
		TutorialHands.arrange(_deck, _hand, TutorialHooks.phase(), _hand_limit(), round)
	_layout_hand()


func _favored_draw() -> String:
	var encounter := GameManager.current_encounter
	if encounter == null:
		return ""
	return encounter.favored_card_type()


func _advance_round() -> void:
	state.turn += 1
	state.reset_round_actions()
	_chosen = null
	_targeting = false
	_draw_up()


func _note_acted(unit: MechState) -> void:
	if unit == null:
		return
	state.mark_attacked(unit)


func _owner_of(card: CardData) -> MechState:
	if card == null:
		return null
	return _owner.get(card.get_instance_id()) as MechState


func _on_card_drop(global_pos: Vector2, released: bool, card: CardData, view: MechCard) -> bool:
	var can_drop := _can_drop_discard()
	var over_bar := (
		can_drop
		and _charge_bar_open()
		and charge_bar.get_global_rect().has_point(global_pos)
	)
	var over_pile := (
		can_drop
		and not over_bar
		and discard_pile != null
		and discard_pile.get_global_rect().has_point(global_pos)
	)
	if discard_pile != null:
		_style_pile(discard_pile, over_pile and not released)
	_style_charge_bar(over_bar and not released)
	if is_instance_valid(view):
		var pitch := over_bar and GameManager.player_attack_gauge < GameManager.player_attack_max
		view.set_discard_preview(over_bar or over_pile, over_bar)
		view.set_gauge_pitch_visible(pitch)
	# A drag is not a chosen card yet. The bar still brightens for the whole pull.
	var still_dragging := not released and is_instance_valid(view) and view.is_dragging()
	_sync_discard_glow(still_dragging)
	if card == _chosen and still_dragging:
		view.set_active_pulse(false)
		if _effect_box != null:
			_effect_box.visible = false
	if not released or not (over_bar or over_pile):
		if card == _chosen and is_instance_valid(view) and not view.is_dragging():
			view.set_active_pulse(true)
			_sync_effect_box()
		return false
	if over_bar and GameManager.tutorial_mission and not TutorialHooks.allows("pitch", card.id if card != null else ""):
		return false
	_commit_discard(card, view, over_bar)
	if over_bar and GameManager.tutorial_mission:
		var pitched := card.id if card != null else ""
		if _pitch_pending > 0:
			_tutorial_pitch_id = pitched
		else:
			TutorialHooks.notify("pitch", pitched)
			TutorialHooks.settled()
	_sync_discard_glow(false)
	_sync_effect_box()
	return true


func _charge_bar_open() -> bool:
	return charge_bar != null and charge_bar.is_visible_in_tree() and charge_bar.size.x > 1.0


func _style_charge_bar(hot: bool) -> void:
	if charge_bar == null:
		return
	charge_bar.modulate = Color(1.25, 1.4, 1.45, 1) if hot else Color.WHITE


func _can_drop_discard() -> bool:
	return (
		state != null
		and state.battle_status == "active"
		and state.phase == "player"
		and not _animating
		and not _moved_for_card
		and not _followup_move
	)


func _commit_discard(card: CardData, view: MechCard, grant_charge: bool) -> void:
	if card == null or view == null or not is_instance_valid(view):
		return
	if _hand.find(card) < 0:
		return
	if _chosen == card:
		_clear_play()
	_card_views.erase(card.get_instance_id())
	_hand.erase(card)
	_discard.append(card)
	_pull_specials()
	var landing: Control = discard_pile
	if grant_charge:
		_grant_pitch_charge(_pitch_origin(view), 0.0, view.scale.x)
		if _charge_bar_open():
			landing = charge_bar
	_launch_discard(view, 0.0, landing)
	await _return_to_player()


func _on_activate_pressed() -> void:
	if _closing or GameManager.battle_offense or not GameManager.attack_ready("player"):
		return
	if GameManager.tutorial_mission and not TutorialHooks.allows("overdrive"):
		return
	GameManager.battle_offense = true
	SoundBank.music("overdrive")
	_specials.shuffle()
	_pull_specials()
	_layout_hand()
	_repaint_hand()
	_play_overdrive_waves()
	_refresh()
	if GameManager.tutorial_mission:
		_deal_tutorial_salvo()
		_layout_hand()
		_repaint_hand()
		_refresh()
		await mode_banner.play("Overdrive mode", true)
		TutorialHooks.notify("overdrive")
		return
	mode_banner.play("Overdrive mode", true)


func _tutorial_player_ready() -> void:
	if not GameManager.tutorial_mission or _closing:
		return
	TutorialHooks.notify("player_turn")
	TutorialHooks.settled()


func _deal_tutorial_salvo() -> void:
	for card in _hand:
		if card != null and card.id == "barrage_salvo":
			return
	var salvo: CardData = null
	for card in _specials:
		if card != null and card.id == "barrage_salvo":
			salvo = card
			break
	if salvo == null:
		return
	_specials.erase(salvo)
	if _hand.size() >= _hand_limit() and not _hand.is_empty():
		var bumped := _hand.pop_back() as CardData
		if bumped != null:
			_discard.append(bumped)
	_hand.append(salvo)


func _tutorial_card_token(card: CardData) -> String:
	if card == null:
		return ""
	if TutorialHooks.detail() == "attack" and card.card_type == "Attack":
		return "attack"
	return card.id


func _note_tutorial_card(card: CardData) -> void:
	if not GameManager.tutorial_mission or card == null:
		return
	if not _targeting or _chosen != card:
		return
	TutorialHooks.notify("card", _tutorial_card_token(card))


func _tutorial_loss(round_limit: bool) -> bool:
	if state == null:
		return false
	if state.battle_status == "defeat":
		return true
	return round_limit and not state.living_units("enemy").is_empty()


func _restart_tutorial_fight() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or state == null:
		return
	TutorialHooks.retry()
	for unit in state.units:
		var opened: Dictionary = _opened.get(unit.id, {})
		if opened.is_empty():
			continue
		unit.hp = int(opened.get("hp", unit.hp))
		unit.guard = int(opened.get("guard", 0))
		unit.standing_guard = int(opened.get("standing", 0))
		unit.alive = true
	GameManager.player_attack_gauge = _tutorial_gauge
	GameManager.player_banked_gauge = _tutorial_bank
	GameManager.battle_offense = false
	SoundBank.music("battle")
	_closing = false
	_animating = false
	_targeting = false
	_clear_play()
	_setup_battle()
	_build_grid()
	_refresh()
	await get_tree().process_frame
	await _return_to_player(true)


func tutorial_anchor(anchor: String) -> Control:
	if anchor == "battle.end_round":
		return skip_button
	if anchor == "battle.charge":
		return charge_bar
	if anchor == "battle.overdrive":
		return activate_button
	if anchor == "battle.card" or anchor == "battle.pitch":
		return _tutorial_card_view()
	if anchor == "battle.badge" or anchor == "battle.cost":
		return _tutorial_card_mark(anchor)
	if anchor == "battle.clock":
		return _tutorial_enemy_clock()
	if anchor == "battle.rewards":
		return upgrade_pick.options_row() if upgrade_pick != null else null
	if anchor == "battle.reward_continue":
		return upgrade_pick.continue_button() if upgrade_pick != null else null
	if anchor == "battle.reward_tools":
		return _tutorial_reward_tools()
	if anchor == "battle.enemy":
		var button := _button_for(_tutorial_enemy_target())
		if button != null and TutorialHooks.any_target():
			var company: Array[Control] = []
			for enemy in state.living_units("enemy"):
				var other := _button_for(enemy)
				if other != null:
					company.append(other)
			button.set_meta("tutorial_company", company)
		elif button != null and button.has_meta("tutorial_company"):
			button.remove_meta("tutorial_company")
		return button
	if anchor.begins_with("battle."):
		return _button_for(_tutorial_unit(anchor.trim_prefix("battle.")))
	return null


func _tutorial_reward_tools() -> Control:
	if upgrade_pick == null:
		return null
	var refresh := upgrade_pick.refresh_button()
	var skip := upgrade_pick.skip_button()
	if refresh == null:
		return skip
	var company: Array[Control] = []
	if skip != null:
		company.append(skip)
	refresh.set_meta("tutorial_company", company)
	return refresh


func _tutorial_unit(data_id: String) -> MechState:
	if state == null:
		return null
	for unit in state.units:
		if unit != null and unit.data != null and unit.data.id == data_id and unit.alive:
			return unit
	return null


## The contact this card can actually hit. Closest one, so Dart is not aimed past its reach.
func _tutorial_enemy_target() -> MechState:
	if state == null:
		return null
	var enemies := state.living_units("enemy")
	if enemies.is_empty():
		return null
	var card := _chosen
	var attacker := _selected if _selected != null else _owner_of(card)
	if card == null or attacker == null:
		return enemies[0]
	var origin := state.position_of(attacker)
	var best: MechState = null
	var best_distance := 999999
	for enemy in enemies:
		var distance := _manhattan(origin, state.position_of(enemy))
		if not card.reaches(distance):
			continue
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best if best != null else enemies[0]


func _tutorial_card_mark(anchor: String) -> Control:
	if anchor == "battle.badge":
		return _tutorial_owner_badges()
	var view := _tutorial_card_view() as MechCard
	if view == null:
		return null
	return view.cost_mark()


## The lead card of each mech. The first badge is the outline; the rest join it on a spanning step.
func _tutorial_owner_badges() -> Control:
	var marks: Array[Control] = []
	var seen := {}
	for card in _hand:
		if card == null:
			continue
		var holder := _owner_of(card)
		var key := holder.id if holder != null else ""
		if key == "" or seen.has(key):
			continue
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null:
			continue
		var mark := view.owner_mark()
		if mark == null:
			continue
		seen[key] = true
		marks.append(mark)
	if marks.is_empty():
		return null
	var lead := marks[0]
	if marks.size() > 1:
		lead.set_meta("tutorial_company", marks)
	elif lead.has_meta("tutorial_company"):
		lead.remove_meta("tutorial_company")
	return lead


func _tutorial_enemy_clock() -> Control:
	var enemy := _tutorial_unit("scout")
	if enemy == null and state != null:
		var enemies := state.living_units("enemy")
		if not enemies.is_empty():
			enemy = enemies[0]
	var button := _button_for(enemy)
	if button == null:
		return null
	return button.get_node_or_null("Vitals/TurnCount") as Control


func _tutorial_card_view() -> Control:
	var want := TutorialHooks.detail()
	for card in _hand:
		if card == null:
			continue
		if want != "" and want != "attack" and not card.id.begins_with(want):
			continue
		if want == "attack" and card.card_type != "Attack":
			continue
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view != null and is_instance_valid(view):
			return view
	return null


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
	if player_gauge == null:
		_style_activate_button()
		return
	var parent := player_gauge.get_parent() as Control
	var face := parent.get_parent() as Control if parent != null else null
	if face != null:
		face.custom_minimum_size.y = STACK_PIECE.y
	if player_gauge.info_badge != null and _info_note != null:
		player_gauge.info_badge.set_meta("tip_width", 480.0)
		_info_note.attach(player_gauge.info_badge, OverdriveMeter.NOTE)
	_style_activate_button()


## The round stripe is on a CanvasLayer, so it ignores the fade that brings the board in.
func _wait_until_faded_in() -> void:
	while is_inside_tree() and modulate.a < 0.98:
		await get_tree().process_frame


func _hold_battle_hud() -> void:
	for node in [_hand_chrome, _side_chrome, _tip_host]:
		if node == null:
			continue
		node.modulate.a = 0.0


func _reveal_battle_hud() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	var revealing := false
	for node in [_hand_chrome, _side_chrome, _tip_host]:
		if node == null:
			continue
		tween.tween_property(node, "modulate:a", 1.0, HUD_REVEAL_SECONDS)
		revealing = true
	if not revealing:
		return
	await tween.finished


func _announce_primed() -> void:
	if GameManager.mission_upgrades == null or not GameManager.mission_upgrades.has_edict("edict_primed"):
		return
	GameManager.grant_primed_charge()
	_refresh_squad_gauge()
	if mode_banner == null or state == null or _closing:
		return
	_hide_status_tip()
	_animating = true
	_refresh()
	await mode_banner.play("Primed +3", true, true, true)
	if not is_inside_tree():
		return
	_animating = false
	if not _closing and state != null and state.battle_status == "active":
		_refresh()


func _announce_round(shown_turn := -1, hold_layout := false) -> void:
	if mode_banner == null or state == null or _closing:
		return
	var turn := state.turn if shown_turn < 1 else shown_turn
	_hide_status_tip()
	_animating = true
	if not hold_layout:
		_refresh()
	await mode_banner.play("Round %d/%d" % [turn, ROUND_LIMIT], true, true)
	if not is_inside_tree():
		return
	_animating = false
	if not hold_layout and not _closing and state != null and state.battle_status == "active":
		_refresh()


func _refresh_round() -> void:
	if state == null:
		return
	if round_label != null:
		round_label.text = "Round %d/%d" % [state.turn, ROUND_LIMIT]
		round_label.visible = false
	if skip_button == null:
		return
	var caption := skip_button.get_node_or_null("Content/Caption") as Label
	if caption != null:
		caption.text = "End round %d/%d" % [state.turn, ROUND_LIMIT]


func _style_activate_button() -> void:
	if activate_button == null:
		return
	activate_button.text = ACTIVATE_TEXT
	activate_button.stop_pulse()


func _start_activate_flash() -> void:
	activate_button.start_pulse()


func _stop_activate_flash() -> void:
	activate_button.stop_pulse()


func _view_for(card: CardData) -> MechCard:
	if card == null:
		return null
	var view := _card_views.get(card.get_instance_id()) as MechCard
	if view != null and is_instance_valid(view):
		return view
	return null


func _pitch_origin(view: MechCard) -> Vector2:
	if view != null and is_instance_valid(view):
		return view.gauge_pitch_origin()
	if discard_pile != null and discard_pile.size.x > 1.0:
		return discard_pile.get_global_rect().get_center()
	return size * 0.5


## One discarded card fills one pip. The +1 arcs to the gauge, and the pip lights when it lands.
func _grant_pitch_charge(origin: Vector2, delay: float, start_scale: float = 1.0) -> bool:
	var before := GameManager.player_attack_gauge
	if not GameManager.charge_from_pitch():
		return false
	if not _spawn_gauge_pitch(origin, delay, start_scale):
		return true
	if _gauge_visual < 0:
		_gauge_visual = before
	_pitch_pending += 1
	return true


func _spawn_gauge_pitch(origin: Vector2, delay: float, start_scale: float) -> bool:
	if _closing or player_gauge == null or not is_instance_valid(player_gauge):
		return false
	var target := player_gauge.charge_point()
	if origin.distance_squared_to(target) < 4.0:
		return false
	var pitch := GAUGE_PITCH_SCENE.instantiate() as GaugePitch
	add_child(pitch)
	pitch.arrived.connect(_on_gauge_pitch_arrived)
	pitch.fly(origin, target, delay, start_scale)
	return true


func _on_gauge_pitch_arrived() -> void:
	_pitch_pending = maxi(_pitch_pending - 1, 0)
	if _gauge_visual >= 0:
		_gauge_visual += 1
	if _pitch_pending == 0:
		_gauge_visual = -1
	if is_inside_tree():
		_refresh_squad_gauge()
	if _pitch_pending == 0 and _tutorial_pitch_id != "":
		var pitched := _tutorial_pitch_id
		_tutorial_pitch_id = ""
		TutorialHooks.notify("pitch", pitched)
		TutorialHooks.settled()


func _refresh_squad_gauge() -> void:
	if player_gauge == null:
		return
	var squad_max := GameManager.player_attack_max
	var squad_charge := mini(GameManager.player_attack_gauge, squad_max)
	if _gauge_visual >= 0:
		squad_charge = mini(_gauge_visual, squad_charge)
	player_gauge.show_charge(squad_charge, squad_max, GameManager.battle_offense)
	var gauge_full := GameManager.attack_ready("player") and _pitch_pending == 0
	var can_activate := (
		gauge_full
		and not _closing
		and state != null
		and state.battle_status == "active"
		and not GameManager.battle_offense
	)
	if activate_button != null:
		activate_button.visible = gauge_full
		activate_button.disabled = not can_activate
		if can_activate:
			_start_activate_flash()
			if not _attack_offered:
				_attack_offered = true
		else:
			_stop_activate_flash()
			_attack_offered = false
	if charge_slot != null:
		charge_slot.visible = not gauge_full


func _fly_card_into_pile(
	view: MechCard,
	start_center: Vector2,
	start_scale: Vector2,
	start_rot: float,
	delay: float = 0.0,
	target: Control = null
) -> void:
	var landing := target if target != null else discard_pile
	if not is_instance_valid(view) or landing == null:
		if is_instance_valid(view):
			view.queue_free()
		return
	var end_center := landing.get_global_rect().get_center()
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
	var free := GameManager.opener_is_free()
	_pending_clock_steps = 0 if free or not card.pays_action() else 1
	var due := 0 if free else card.charge_due(GameManager.battle_offense)
	if due > 0 and GameManager.spend_charge(due):
		_refresh_squad_gauge()
	var index := _hand.find(card)
	if index >= 0:
		_hand.remove_at(index)
		_discard.append(card)
		_pull_specials()
		_layout_hand()
	if free and GameManager.spend_free_opener():
		_repaint_hand()
	SoundBank.play_card(card)


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


func _strike(attacker: MechState, defender: MechState, card: CardData, announce := true) -> Dictionary:
	var catcher := _interceptor_for(defender)
	if catcher != null:
		catcher.intercepting = false
		defender = catcher
	var result := CombatResolver.resolve_attack(attacker, defender, card, _take_dodge(defender))
	result["struck"] = defender
	if str(result.get("defense_kind", "")) == "Dodge":
		SoundBank.play("dodge")
	elif int(result.get("blocked", 0)) > 0:
		SoundBank.play("guard")
	GameManager.note_strike(attacker, defender, int(result.get("damage", 0)), bool(result.get("destroyed", false)))
	if announce:
		_show_strike_numbers(defender, result)
	if result.get("destroyed", false):
		_discard_unit_cards(defender)
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
			_ending_hand.append(card)
			moved += 1
		else:
			kept_hand.append(card)
	_hand = kept_hand
	if moved == 0:
		return
	if _chosen != null and _owner_of(_chosen) == unit:
		_clear_play()
	_layout_hand()
	if discard_overlay != null and discard_overlay.visible:
		_fill_discard_list()


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
	var field := grid.get_parent() as Control
	if field != null:
		field.add_child(label)
	else:
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
	if _animating or _moved_for_card:
		return
	# Staying put is a legal end to "shoot, then step". Choosing another card does that, then plays.
	if _followup_move:
		await _finish_followup()
		if (
			_animating
			or _moved_for_card
			or _followup_move
			or _closing
			or not is_inside_tree()
		):
			return
	if state == null or state.battle_status != "active" or state.phase != "player":
		return
	if card == null or _hand.find(card) < 0:
		return
	if GameManager.tutorial_mission and not TutorialHooks.allows("card", _tutorial_card_token(card)):
		return
	var due := GameManager.card_charge_due(card) if card != null else 0
	if due > GameManager.player_attack_gauge:
		_refuse_card(card, "Need %d charge." % due, true)
		return
	if _needs_owner_confirm(card):
		_arm_owner_confirm(card)
		return
	if card.guards_self():
		_begin_self_guard(card)
		return
	if card.moves_only():
		_begin_move(card)
		return
	if _steps_before_guard(card):
		_begin_step_then_guard(card)
		return
	if card.target_type == "squad" or card.target_type == "team" or card.target_type == "enemies" or card.hits_front():
		await _play_special(card)
		_note_tutorial_card(card)
		return
	if card.is_guard():
		await _begin_guard(card)
		return
	if card.card_type != "Attack":
		_refresh()
		return
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
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
	_note_tutorial_card(card)
	_refresh()


func _steps_before_guard(card: CardData) -> bool:
	return card != null and card.guards_ally() and card.movement > 0 and card.move_timing == "Before"


## Staying on the current cell is a finished step of 0. The ally pick comes next.
func _stay_for_guard(actor: MechState) -> void:
	if _guard_targets(actor, _chosen).is_empty():
		if mode_banner != null:
			mode_banner.play("No adjacent ally.", false)
		return
	_play_step = "guard"
	_refresh()


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
		_clear_play()
		_refresh()


func _begin_step_then_guard(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
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
	if _move_targets.is_empty() and _guard_targets(holder, card).is_empty():
		_refuse_card(card, "No adjacent ally.")
	elif _move_targets.is_empty():
		_play_step = "guard"
		_refresh()


func _refuse_card(card: CardData, reason: String, gauge := false) -> void:
	_clear_play()
	_refresh()
	var view: MechCard = null
	if card != null:
		view = _card_views.get(card.get_instance_id()) as MechCard
	if view != null and is_instance_valid(view):
		view.refuse()
	if gauge and player_gauge != null:
		player_gauge.flash_empty()
	if mode_banner != null and reason != "":
		mode_banner.play(reason, false)


func _begin_move(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_refresh()
		return
	if _reachable(state.position_of(holder), card.movement).is_empty():
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
		_refresh()
		return
	_selected = holder
	if card.guards_ally():
		if _guard_targets(holder, card).is_empty():
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
	_begin_self_guard(card)


## A guard with a step lands when that step is taken. A guard with nothing else still confirms on the owner.
func _guards_then_steps(card: CardData) -> bool:
	return card != null and card.guards_self() and card.movement > 0 and not _followup_move


func _begin_self_guard(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_refresh()
		return
	if card.movement > 0 and not _reachable(state.position_of(holder), card.movement).is_empty():
		_selected = holder
		if _chosen == card and _play_step == "move":
			_clear_play()
		else:
			_chosen = card
			_targeting = true
			_play_step = "move"
		_refresh()
		return
	_arm_owner_confirm(card)


func _needs_owner_confirm(card: CardData) -> bool:
	if card == null:
		return false
	if card.is_dodge():
		return true
	if card.target_type == "squad" or card.target_type == "team":
		return true
	return card.target_type == "enemies" and not card.moves_before() and not card.hits_front()


## These cards used to resolve on the card tap. The owner's tile is the confirm.
func _arm_owner_confirm(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
		_refresh()
		return
	if card.target_type == "squad" and not GameManager.battle_offense:
		_refresh()
		return
	_selected = holder
	if _chosen == card and _play_step == "confirm":
		_clear_play()
	else:
		_chosen = card
		_targeting = true
		_play_step = "confirm"
	_refresh()


func _on_confirm_cell(unit: MechState) -> void:
	var card := _chosen
	var holder := _owner_of(card)
	if card == null or holder == null:
		_clear_play()
		_refresh()
		return
	if unit != holder:
		_refresh()
		return
	if card.is_dodge():
		_clear_play()
		_refresh()
		return
	if card.guards_self():
		await _grant_guard(holder, holder, card)
		return
	await _play_special(card)


func _on_guard_cell(unit: MechState) -> void:
	var card := _chosen
	var holder := _owner_of(card)
	if card == null or holder == null:
		_clear_play()
		_refresh()
		return
	if unit == null or not _guard_targets(holder, card).has(unit):
		_refresh()
		return
	await _grant_guard(holder, unit, card)


func _play_special(card: CardData) -> void:
	var holder := _owner_of(card)
	if holder == null or not holder.alive:
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
		_clear_play()
		await _after_card_played()
		await _return_to_player()
		return
	if card.target_type == "squad":
		if not GameManager.battle_offense:
			_refresh()
			return
		_spend(card)
		GameManager.charge_from_spark()
		_clear_play()
		await _after_card_played()
		await _return_to_player()
		return
	_refresh()


func _play_breach(holder: MechState, card: CardData) -> void:
	_animating = true
	_sync_play_prompt()
	_step_undo = false
	var origin := state.position_of(holder)
	var victims: Array[MechState] = []
	for enemy in state.living_units("enemy"):
		if card.reaches(_manhattan(origin, state.position_of(enemy))):
			victims.append(enemy)
	_spend(card)
	_resolving_card = true
	_update_hand_controls()
	var shoots := holder != null and WeaponVolley.has_profile(holder.art_id)
	var finishing := _is_winning_blow(holder, victims, card)
	if finishing:
		await _play_finisher(holder)
		if not is_inside_tree() or state == null:
			return
		if not shoots:
			var lead: Button = null
			if not victims.is_empty():
				lead = _button_for(victims[0])
			await _play_attack(_sprite_for(holder), lead, null, {}, _impact_heavy(card), true)
			if not is_inside_tree() or state == null:
				return
	var outcomes: Array[Dictionary] = []
	for enemy in victims:
		if not holder.alive or not enemy.alive:
			continue
		var result := _strike(holder, enemy, card, not shoots)
		outcomes.append(result)
	_spend_opening_strike(card)
	if shoots:
		if not victims.is_empty() and state != null:
			var aim := state.position_of(victims[0])
			holder.face_toward_x(float(origin.x), float(aim.x))
		var buttons: Array[Button] = []
		var flown: Array[Dictionary] = []
		for result in outcomes:
			var struck := _struck(result, null)
			var button := _button_for(struck)
			if button == null:
				_show_strike_numbers(struck, result)
				continue
			buttons.append(button)
			flown.append(result)
		await _play_projectile_attack(_sprite_for(holder), holder, buttons, flown, _impact_heavy(card))
		if not is_inside_tree() or state == null:
			return
	state.sync_occupants()
	_note_outcome()
	if finishing:
		await _show_finisher_kill()
		if not is_inside_tree() or state == null:
			return
	_animating = false
	_finish_if_over()
	_clear_play()
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	await _after_card_played()
	await _return_to_player()


## The strike already used the bonus. Cards still in hand lose the blue +2 unless another bonus remains.
func _spend_opening_strike(card: CardData) -> void:
	if card == null or card.card_type != "Attack":
		return
	var holder := _owner_of(card)
	if holder == null or holder.team != "player":
		return
	if not GameManager.spend_opening_strike():
		return
	if GameManager.mission_upgrades != null and GameManager.mission_upgrades.has_edict("edict_opening_strike"):
		_repaint_hand()
		_repaint_open_pile()


## The guard amount was already taken. Later guards drop the opening +2 the same way attacks do.
func _spend_opening_guard(card: CardData) -> void:
	if card == null or not card.is_guard():
		return
	var holder := _owner_of(card)
	if holder == null or holder.team != "player":
		return
	if not GameManager.spend_opening_guard():
		return
	if GameManager.mission_upgrades != null and GameManager.mission_upgrades.has_edict("edict_opening_guard"):
		_repaint_hand()
		_repaint_open_pile()


func _repaint_open_pile() -> void:
	if discard_overlay != null and discard_overlay.visible:
		_fill_discard_list()


func _grant_guard(holder: MechState, target: MechState, card: CardData, offer_step: bool = true) -> void:
	var amount := GameManager.card_block(card)
	var barrier := 0 if card == null else maxi(card.barrier, 0)
	_spend(card)
	_spend_opening_guard(card)
	if amount > 0:
		target.add_guard(amount)
		_show_guard_gain(target, amount)
	if barrier > 0:
		target.add_barrier(barrier)
		_show_guard_gain(target, barrier)
	if card.intercept and holder != null:
		holder.intercepting = true
	if offer_step and card.movement > 0 and card.move_timing != "Before" and holder != null and holder.alive and not _reachable(state.position_of(holder), card.movement).is_empty():
		_selected = holder
		_chosen = card
		_followup_move = true
		_play_step = "move"
		_targeting = true
		_refresh()
		return
	_clear_play()
	await _after_card_played()
	await _return_to_player()


## An empty hand has nothing left to play, so End Round runs on its own once any attack from the last card is done.
## A round that just opened only checks the new hand. It does not advance again.
func _return_to_player(round_opened: bool = false) -> void:
	if _closing or not is_inside_tree() or state == null or state.battle_status != "active":
		return
	if await _end_round_if_no_cards():
		return
	if round_opened:
		return
	if _next_ready_player() == null and not _guard_waiting():
		await _complete_player_side()
		return
	_refresh()
	_tutorial_player_ready()


func _end_round_if_no_cards() -> bool:
	if state == null or state.battle_status != "active" or state.phase != "player":
		return false
	if _animating or _moved_for_card or _followup_move or _chosen != null or _play_step != "":
		return false
	_pull_specials()
	if not _hand.is_empty():
		return false
	await _finish_player_turn()
	return true


func _guard_targets(holder: MechState, card: CardData = null) -> Array[MechState]:
	var found: Array[MechState] = []
	if holder == null or state == null:
		return found
	if card != null and card.target_type == "friendly" and holder.alive:
		found.append(holder)
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
		if card.guards_ally() and _guard_targets(holder, card).is_empty():
			continue
		return true
	return false


func _refresh_hand() -> void:
	if hand_box == null:
		return
	_layout_hand()
	_update_hand_controls()


func _update_hand_controls() -> void:
	_sync_discard_glow()
	var can_pull := (
		state != null
		and state.battle_status == "active"
		and state.phase == "player"
		and not _animating
		and not _moved_for_card
	)
	for card in _hand:
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null or not is_instance_valid(view):
			continue
		view.set_drop_handler(_on_card_drop.bind(card, view))
		view.set_pull_enabled(can_pull)
		view.set_undo_drag_enabled(_can_undo_drag(card))
		view.set_enemy_dim(_hand_aside())
		view.set_chosen(card == _chosen)
		if not view.is_gliding():
			var names_only := _chosen != null and not _hand_aside()
			view.settle(card == _chosen, names_only and card != _chosen)
	_sync_hand_tuck()
	_sync_effect_box()


func _place_discard_glow() -> void:
	if discard_glow == null:
		return
	# The battle root is raised above the map. An absolute z index falls behind that root.
	discard_glow.z_as_relative = true
	discard_glow.z_index = 1
	discard_glow.show_behind_parent = false
	discard_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_discard_glow(dragging: bool = false) -> void:
	if discard_glow == null:
		return
	discard_glow.set_lit(_chosen != null or dragging)


func _sync_effect_box() -> void:
	if _effect_box == null:
		return
	if _chosen == null:
		_effect_box.visible = false
		return
	var view := _card_views.get(_chosen.get_instance_id()) as MechCard
	if view == null or not is_instance_valid(view) or view.is_dragging():
		_effect_box.visible = false
		return
	_effect_box.show_card(_chosen, GameManager.card_damage(_chosen), GameManager.card_block(_chosen))
	_place_effect_box()


func _place_effect_box() -> void:
	if _effect_box == null or _chosen == null:
		return
	var view := _card_views.get(_chosen.get_instance_id()) as MechCard
	if view == null or not is_instance_valid(view):
		_effect_box.visible = false
		return
	_effect_box.hug()
	var box_size := _effect_box.size
	var origin := view.global_position + Vector2(view.size.x + 12.0, 0.0)
	var view_size := get_viewport_rect().size
	if origin.x + box_size.x > view_size.x - 8.0:
		origin.x = maxf(8.0, view.global_position.x - box_size.x - 12.0)
	if origin.y + box_size.y > view_size.y - 8.0:
		origin.y = maxf(8.0, view_size.y - box_size.y - 8.0)
	_effect_box.global_position = origin


func _enemy_turn() -> bool:
	return state != null and state.battle_status == "active" and state.phase == "enemy"


func _hand_aside() -> bool:
	return _enemy_turn() or _resolving_card


func _sync_hand_tuck() -> void:
	var tuck := _hand_aside()
	if tuck == _hand_tucked:
		return
	_hand_tucked = tuck
	var target := _hand_card_size.y * HAND_DROP_RATIO if tuck else 0.0
	if _hand_drop_tween != null and _hand_drop_tween.is_valid():
		_hand_drop_tween.kill()
	_hand_drop_tween = create_tween()
	_hand_drop_tween.set_trans(Tween.TRANS_CUBIC)
	_hand_drop_tween.set_ease(Tween.EASE_OUT)
	_hand_drop_tween.tween_method(_set_hand_drop, _hand_drop_px, target, HAND_TUCK_TIME)


func _set_hand_drop(px: float) -> void:
	_hand_drop_px = px
	_place_hand_row()


func _place_hand_row() -> void:
	if _hand_anchor == null or _hand_row == null:
		return
	var reserved := 0.0
	if _corner_column != null:
		var width := _corner_column.custom_minimum_size.x
		if width < 2.0:
			width = _corner_column.size.x
		if width >= 2.0:
			reserved = width + _hand_row.get_theme_constant("separation")
	_hand_row.position = Vector2(0.0, _hand_drop_px)
	_hand_row.size = Vector2(maxf(0.0, _hand_anchor.size.x - reserved), _hand_anchor.size.y)
	_fit_hand_widths()


func _sync_hand_min_size() -> void:
	_fit_hand_widths()


## Dealt cards match the seats. The end-round button keeps its own size and stays in the corner.
func _fit_hand_widths() -> void:
	if hand_box == null or hand_box.get_child_count() == 0:
		return
	var slot := hand_box.get_child(0) as Control
	if slot == null:
		return
	var size := slot.custom_minimum_size
	if size.x < 2.0 or size.y < 2.0 or size.is_equal_approx(_hand_card_size):
		return
	_hand_card_size = size
	for id in _card_views.keys():
		var view := _card_views[id] as MechCard
		if view == null or not is_instance_valid(view) or view.top_level:
			continue
		view.custom_minimum_size = _hand_card_size
		view.size = _hand_card_size


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
	_cluster_hand()
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
	_place_hand_row()
	_sync_hand_min_size()
	_sync_locked_slots()
	_mark_owner_badges()
	_refresh_discard()


## Pull each mech's cards into one run, keeping the order those mechs first showed up.
func _cluster_hand() -> void:
	var order: Array = []
	var buckets: Dictionary = {}
	for card in _hand:
		if card == null:
			continue
		var holder := _owner_of(card)
		var key := holder.id if holder != null else "card:%d" % card.get_instance_id()
		if not buckets.has(key):
			var pile: Array[CardData] = []
			buckets[key] = pile
			order.append(key)
		(buckets[key] as Array[CardData]).append(card)
	var clustered: Array[CardData] = []
	for key in order:
		for card in buckets[key]:
			clustered.append(card)
	_hand = clustered


## The first card of each mech carries that mech's head. A single card still does.
func _mark_owner_badges() -> void:
	var seen := {}
	for index in _hand.size():
		var card := _hand[index]
		if card == null:
			continue
		var view := _card_views.get(card.get_instance_id()) as MechCard
		if view == null or not is_instance_valid(view):
			continue
		var holder := _owner_of(card)
		var key := holder.id if holder != null else ""
		var lead := holder != null and key != "" and not seen.has(key)
		if lead:
			seen[key] = true
			view.set_owner_badge(holder.art_id, MechCard.stroke_for(holder.data), _hand_slot(index))
		else:
			view.clear_owner_badge()


func _ensure_hand_slots() -> void:
	var needed := maxi(HAND_CAP, _hand.size())
	while hand_box.get_child_count() > needed:
		var extra := hand_box.get_child(hand_box.get_child_count() - 1)
		_park_slot_cards(extra)
		hand_box.remove_child(extra)
		extra.queue_free()
	while hand_box.get_child_count() < needed:
		var slot := SLOT_SCENE.instantiate()
		slot.name = "CardSlot%d" % (hand_box.get_child_count() + 1)
		hand_box.add_child(slot)


## Seats past the third stay in the row. A short squad never draws into them, so those blanks show a lock.
## The 5th and 6th seats open together, with a third mech.
func _sync_locked_slots() -> void:
	if hand_box == null:
		return
	var limit := _hand_limit()
	for index in hand_box.get_child_count():
		var slot := hand_box.get_child(index)
		var lock_icon := slot.get_node_or_null("Lock") as Control
		if lock_icon == null:
			continue
		var held := _slot_holds_card(slot)
		var locked := index >= 3 and index >= limit and not held
		lock_icon.visible = locked
		var plate := slot.get_node_or_null("Empty") as CanvasItem
		if plate != null:
			plate.visible = not held
		if locked and _info_note != null:
			var mechs := 3 if index >= 4 else index - HAND_BASE + 1
			_info_note.watch(lock_icon, "Fight with %d mechs to unlock slot" % mechs)


func _slot_holds_card(slot: Node) -> bool:
	var host := _card_host(slot)
	for child in host.get_children():
		if child is MechCard:
			return true
	return false


func _park_slot_cards(slot: Node) -> void:
	var host := _card_host(slot)
	for child in host.get_children():
		if child is MechCard:
			child.reparent(self)


func _card_host(slot: Node) -> Node:
	var host := slot.get_node_or_null("CardHost")
	return host if host != null else slot


func _hand_slot(hand_index: int) -> Control:
	# Cards pack to the left, so removing one slides the others left.
	return hand_box.get_child(hand_index) as Control


func _place_held_card(view: MechCard, slot: Control) -> void:
	var host := _card_host(slot)
	if view.get_parent() == host:
		return
	view.reparent(host)
	view.begin_glide(CARD_SLIDE_TIME)


func _deal_card(card: CardData, slot: Control, delay: float) -> void:
	var view := CARD_SCENE.instantiate() as MechCard
	view.custom_minimum_size = _hand_card_size
	view.size = _hand_card_size
	_card_host(slot).add_child(view)
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
	view.set_enemy_dim(_hand_tucked, true)
	view.set_drop_handler(_on_card_drop.bind(card, view))
	view.pulled.connect(_on_hand_card_pressed.bind(card))
	view.undo_dragged.connect(_on_card_undo_drag.bind(card))


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


func _launch_discard(view: MechCard, delay: float, target: Control = null) -> void:
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
	_fly_card_into_pile(view, start_center, start_scale, start_rot, delay, target)


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


func _show_evade(button: Button, unit: MechState) -> void:
	var active := unit != null and unit.alive and unit.intercepting
	_show_vital(button, "Evade", 1, active)


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
	var turn_count := button.get_node_or_null("Vitals/TurnCount") as HBoxContainer
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


## Pale yellow wash on the four cells beside a mech who will catch the next hit.
func _sync_intercept_cell(button: Button, in_zone: bool, _unit: MechState) -> void:
	var fill := button.get_node_or_null("InterceptFill") as CanvasItem
	if fill != null:
		fill.visible = in_zone


func _cell_in_intercept_zone(coords: Vector2i) -> bool:
	if state == null:
		return false
	for unit in state.living_units("player"):
		if unit == null or not unit.intercepting:
			continue
		if _manhattan(state.position_of(unit), coords) == 1:
			return true
	return false


func _sync_overdrive_cell(button: Button, unit: MechState) -> void:
	var sprite := button.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite == null:
		return
	var active := (
		GameManager.battle_offense
		and not _closing
		and unit != null
		and unit.alive
		and unit.team == "player"
		and sprite.sprite_frames != null
	)
	var aura := sprite.get_node_or_null("PowerUp") as PowerUp
	if aura == null and unit != null:
		aura = _overdrive_fx_for(unit)
	if not active:
		if aura != null and is_instance_valid(aura) and aura.get_parent() == sprite:
			aura.release()
		return
	if aura == null or not is_instance_valid(aura):
		aura = POWER_UP_SCENE.instantiate() as PowerUp
		aura.name = "PowerUp"
		_overdrive_fx[unit.id] = aura
		aura.attach(sprite)
		return
	_overdrive_fx[unit.id] = aura
	if aura.get_parent() == sprite:
		aura.attach(sprite)
	else:
		aura.hold()


func _overdrive_fx_for(unit: MechState) -> PowerUp:
	if unit == null:
		return null
	var aura := _overdrive_fx.get(unit.id) as PowerUp
	if aura != null and not is_instance_valid(aura):
		_overdrive_fx.erase(unit.id)
		return null
	return aura


func _release_overdrive_fx() -> void:
	for key in _overdrive_fx.keys():
		var aura := _overdrive_fx[key] as PowerUp
		if aura != null and is_instance_valid(aura):
			aura.release()


func _unit_on_button(button: Button) -> MechState:
	for coords in _buttons:
		if _buttons[coords] == button:
			return _unit_at(coords)
	return null


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


## Copies every stage tile layer this fight was cut from, including Props nested under Ground.
## z 0 layers sit behind the cells. A layer keeps its stage z, so In Front (8) and Above (10) cover the mechs.
## Those higher layers are dimmed on the ring, because they draw above the scenery veil.
func _stamp_terrain(cell_px: float) -> void:
	var host := grid.get_parent()
	var existing := host.get_node_or_null("Terrain")
	if existing is TileMapLayer:
		host.remove_child(existing)
		existing.free()
		existing = null
	var terrain := existing as Node2D
	if terrain == null:
		terrain = Node2D.new()
		terrain.name = "Terrain"
		terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.add_child(terrain)
	var stale: Array[Node] = []
	for child in terrain.get_children():
		stale.append(child)
	for child in stale:
		terrain.remove_child(child)
		child.free()
	StageMap.ensure()
	var sources := StageMap.visual_layers()
	var ground := StageMap.layer
	if ground == null or ground.tile_set == null or sources.is_empty() or state == null or state.grid == null:
		terrain.visible = false
		return
	var encounter := GameManager.current_encounter
	var view_size := BattleDeployment.view_size(encounter)
	var painted_any := false
	var span := StageMap.mech_span()
	for source in sources:
		var draw_z := StageMap.layer_draw_z(source)
		var copy := _terrain_layer_copy(source, terrain, draw_z, false)
		var ring: TileMapLayer = null
		if draw_z > SCENERY_SHADE_Z:
			ring = _terrain_layer_copy(source, terrain, draw_z, true)
		if source.tile_set == null:
			copy.visible = false
			if ring != null:
				ring.visible = false
			continue
		var painted := false
		var ring_painted := false
		for y in view_size.y:
			for x in view_size.x:
				var battle := Vector2i(x, y)
				var world := BattleDeployment.overworld_cell_for_view(encounter, battle)
				if not StageMap.contains(world):
					continue
				var target := copy
				if ring != null and not BattleDeployment.is_play_cell(battle, encounter):
					target = ring
				var origin := world * span
				var cell_painted := false
				for oy in span:
					for ox in span:
						var tile_coords := origin + Vector2i(ox, oy)
						var source_id := source.get_cell_source_id(tile_coords)
						if source_id < 0:
							continue
						var atlas_coords := source.get_cell_atlas_coords(tile_coords)
						var alternative := source.get_cell_alternative_tile(tile_coords)
						target.set_cell(battle * span + Vector2i(ox, oy), source_id, atlas_coords, alternative)
						cell_painted = true
				if not cell_painted:
					continue
				if target == ring:
					ring_painted = true
				else:
					painted = true
		copy.visible = painted
		if ring != null:
			ring.visible = ring_painted
		painted_any = painted_any or painted or ring_painted
	terrain.visible = painted_any
	if not painted_any:
		return
	var tile := Vector2(ground.tile_set.tile_size)
	var step := tile * float(StageMap.mech_span())
	_stamp_shadows(terrain, encounter, step)
	_stamp_weather(terrain, step)
	var h_sep := grid.get_theme_constant("h_separation")
	var v_sep := grid.get_theme_constant("v_separation")
	terrain.scale = Vector2((cell_px + h_sep) / step.x, (cell_px + v_sep) / step.y)
	terrain.position = grid.position
	_seat_terrain(host, terrain)
	for coords in _buttons:
		_paint(_buttons[coords], _cell_color(coords))


func _terrain_layer_copy(source: TileMapLayer, terrain: Node2D, draw_z: int, ring: bool) -> TileMapLayer:
	var copy := TileMapLayer.new()
	copy.name = "%sRing" % source.name if ring else source.name
	copy.z_as_relative = true
	copy.z_index = draw_z
	copy.y_sort_enabled = source.y_sort_enabled
	copy.modulate = source.modulate * (_scenery_dim() if ring else Color.WHITE)
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copy.tile_set = source.tile_set
	copy.rendering_quadrant_size = source.rendering_quadrant_size
	copy.physics_quadrant_size = source.physics_quadrant_size
	terrain.add_child(copy)
	return copy


## Keeps the stage art under the cells. Godot removes a child before inserting it and
## does not shift the target index down, so moving the tiles to the grid's index while
## they are already behind the grid draws them on top and hides move and attack colors.
func _seat_terrain(host: Node, terrain: Node) -> void:
	var grid_at := grid.get_index()
	var terrain_at := terrain.get_index()
	if terrain_at == grid_at - 1:
		return
	var slot := grid_at
	if terrain_at < grid_at:
		slot = grid_at - 1
	host.move_child(terrain, slot)


## Cuts the stage Shadows polygons into the same window as the tiles.
func _stamp_shadows(terrain: Node2D, encounter: EncounterData, mech_px: Vector2) -> void:
	if encounter == null or encounter.attacker == null or StageMap.root == null:
		return
	if mech_px.x <= 0.0 or mech_px.y <= 0.0:
		return
	var source := StageMap.root.get_node_or_null("Shadows") as Node2D
	if source == null:
		return
	var view := BattleDeployment.view_size(encounter)
	var bounds := Rect2(Vector2.ZERO, Vector2(view) * mech_px)
	var host := Node2D.new()
	host.name = "Shadows"
	host.z_index = StageMap.SHADOW_Z
	var kept := false
	var polygons: Array[Polygon2D] = []
	_collect_shadows(source, polygons)
	for poly in polygons:
		var mapped := PackedVector2Array()
		for point in poly.polygon:
			mapped.append(BattleDeployment.terrain_point(encounter, _stage_shadow_point(poly, point), mech_px))
		var clipped := _clip_polygon(mapped, bounds)
		if clipped.size() < 3:
			continue
		var copy := poly.duplicate() as Polygon2D
		copy.transform = Transform2D.IDENTITY
		copy.modulate = _shadow_tint(poly)
		copy.polygon = clipped
		host.add_child(copy)
		kept = true
	if kept:
		terrain.add_child(host)


## Stage weather covers the whole map. The copy is refit to this fight's view.
func _stamp_weather(terrain: Node2D, mech_px: Vector2) -> void:
	if StageMap.root == null or mech_px.x <= 0.0 or mech_px.y <= 0.0:
		return
	var view := BattleDeployment.view_size(GameManager.current_encounter)
	var area := Rect2(Vector2.ZERO, Vector2(view) * mech_px)
	var host := Node2D.new()
	host.name = StageMap.WEATHER_NODE
	var kept := false
	for child in WeatherFitScript.layers(StageMap.root):
		var copy := child.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		host.add_child(copy)
		WeatherFitScript.apply(copy, area)
		kept = true
	if not kept:
		host.free()
		return
	terrain.add_child(host)


func _collect_shadows(node: Node, into: Array[Polygon2D]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Polygon2D:
			into.append(child)
		_collect_shadows(child, into)


## Polygon point in stage pixels, before the overworld scales the stage root.
func _stage_shadow_point(poly: Polygon2D, local: Vector2) -> Vector2:
	var point := local
	var node: Node = poly
	while node is Node2D and node != StageMap.root:
		point = (node as Node2D).transform * point
		node = node.get_parent()
	return point


func _shadow_tint(poly: Polygon2D) -> Color:
	var tint := poly.modulate
	var node := poly.get_parent()
	while node is CanvasItem and node != StageMap.root:
		tint *= (node as CanvasItem).modulate
		node = node.get_parent()
	return tint


func _clip_polygon(points: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var clipped := _clip_axis(points, rect.position.x, true, true)
	clipped = _clip_axis(clipped, rect.end.x, true, false)
	clipped = _clip_axis(clipped, rect.position.y, false, true)
	clipped = _clip_axis(clipped, rect.end.y, false, false)
	return clipped


func _clip_axis(points: PackedVector2Array, limit: float, on_x: bool, keep_greater: bool) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()
	var output := PackedVector2Array()
	var previous: Vector2 = points[points.size() - 1]
	var previous_in := _clip_inside(previous, limit, on_x, keep_greater)
	for point in points:
		var current_in := _clip_inside(point, limit, on_x, keep_greater)
		if current_in:
			if not previous_in:
				output.append(_clip_cross(previous, point, limit, on_x))
			output.append(point)
		elif previous_in:
			output.append(_clip_cross(previous, point, limit, on_x))
		previous = point
		previous_in = current_in
	return output


func _clip_inside(point: Vector2, limit: float, on_x: bool, keep_greater: bool) -> bool:
	var value := point.x if on_x else point.y
	if keep_greater:
		return value >= limit - 0.001
	return value <= limit + 0.001


func _clip_cross(a: Vector2, b: Vector2, limit: float, on_x: bool) -> Vector2:
	var delta := b - a
	if on_x:
		if is_zero_approx(delta.x):
			return Vector2(limit, a.y)
		var t := (limit - a.x) / delta.x
		return Vector2(limit, a.y + delta.y * t)
	if is_zero_approx(delta.y):
		return Vector2(a.x, limit)
	var ty := (limit - a.y) / delta.y
	return Vector2(a.x + delta.x * ty, limit)


func _paint(button: Button, color: Color, selected: bool = false) -> void:
	var style: StyleBoxFlat
	if selected:
		style = _ensure_active_cell_style()
		_start_active_cell_pulse()
		_set_range_fill(button, "Shade", Color(0, 0, 0, 0))
		_set_range_fill(button, "AttackShade", Color(0, 0, 0, 0))
	else:
		style = _owned_cell_style(button)
		var floor := color
		var move_fill := Color(0, 0, 0, 0)
		var attack_fill := Color(0, 0, 0, 0)
		if color.is_equal_approx(ATTACK_FILL):
			attack_fill = color
			floor = CELL_FLOOR
		elif color.is_equal_approx(MOVE_FILL) or color.is_equal_approx(GUARD_FILL):
			move_fill = color
			floor = Color(0, 0, 0, 0)
		var terrain := grid.get_parent().get_node_or_null("Terrain") as Node2D
		if terrain != null and terrain.visible:
			if floor.is_equal_approx(CELL_FLOOR):
				floor = Color(0, 0, 0, 0)
			elif floor.a > 0.0:
				floor.a = 0.45
			if move_fill.a > 0.0:
				move_fill.a = 0.45
			if attack_fill.a > 0.0:
				attack_fill.a = 0.45
		style.bg_color = floor
		_set_range_fill(button, "Shade", move_fill)
		_set_range_fill(button, "AttackShade", attack_fill)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color.WHITE)


func _set_range_fill(button: Button, node_name: String, color: Color) -> void:
	var panel := button.get_node_or_null(node_name) as Panel
	if panel == null:
		return
	var style := _owned_panel_style(panel)
	style.bg_color = color
	# A blue cell drawn under the body disappears once the mech fills the square.
	if node_name == "Shade":
		var sprite := button.get_node_or_null("MechSprite") as CanvasItem
		var over_body := color.a > 0.01 and sprite != null and sprite.visible
		panel.z_as_relative = true
		panel.z_index = RANGE_OVER_BODY_Z if over_body else 1
		if over_body and style.bg_color.a > 0.55:
			style.bg_color.a = 0.45


func _owned_panel_style(panel: Panel) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel.get_meta("fill_style") as StyleBoxFlat if panel.has_meta("fill_style") else null
	if style != null:
		return style
	style = (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("fill_style", style)
	return style


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
