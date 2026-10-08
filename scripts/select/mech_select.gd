extends Control

const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const SLOT_SCENE := preload("res://scenes/ui/strip_card_slot.tscn")
const ROW_SCENE := preload("res://scenes/ui/roster_row.tscn")
const OVERDRIVE_NOTE := "Actions to fill this gauge. The stage sets a minimum. High OVD makes it longer. A full gauge boosts attack and guard."
const TIER_GOLD := Color(0.98, 0.84, 0.32)
## Screen pixels the cut moves right for each pixel down. Matches the squad-screen reference.
const SHAPE_SLOPE := 0.46
## Where the cut crosses the bottom of the portrait, as a fraction of that panel's width.
const SHAPE_ANCHOR := 0.98
## Gap inside the preview stroke before the first card. It scrolls away with the row.
const CARD_LEAD := 16.0

var _squad: Array[MechData] = []
var _focused: MechData
var _deck_mech_id := ""
var _deal_token := 0
var _deal_tries := 0
var _buttons: Dictionary = {}
var _checks: Dictionary = {}
var _syncing := false
var _deploy_flash: Tween

@onready var _special_note: InfoNote = %SpecialNote

@onready var back_button: Button = %BackButton
@onready var roster: VBoxContainer = %Roster
@onready var frame: PanelContainer = %Frame
@onready var stage: Panel = %Stage
@onready var shape: ColorRect = %Shape
@onready var pilot_sprite: AnimatedSprite2D = %Pilot
@onready var mech_sprite: AnimatedSprite2D = %Mech
@onready var preview_name: Label = %PreviewName
@onready var blurb: Label = %Blurb
@onready var stat_table: VBoxContainer = %StatTable
@onready var stat_grid: GridContainer = %StatGrid
@onready var hp_stat: Label = %HpStat
@onready var hp_grade: Label = %HpGrade
@onready var atk_stat: Label = %AtkStat
@onready var atk_grade: Label = %AtkGrade
@onready var rng_stat: Label = %RngStat
@onready var rng_grade: Label = %RngGrade
@onready var mov_stat: Label = %MovStat
@onready var mov_grade: Label = %MovGrade
@onready var spd_stat: Label = %SpdStat
@onready var spd_grade: Label = %SpdGrade
@onready var ovd_stat: Label = %OvdStat
@onready var ovd_grade: Label = %OvdGrade
@onready var card_row: MarginContainer = %CardRow
@onready var deck_lead: MarginContainer = %DeckLead
@onready var deck: HBoxContainer = %Deck
@onready var deck_scroll: ScrollContainer = %DeckScroll
@onready var card_fade: TextureRect = %CardFade
@onready var overdrive_preview: OverdrivePreview = %OverdrivePreview
@onready var deploy_button: Button = %DeployButton


func _ready() -> void:
	if GameManager.available_mechs.is_empty():
		GameManager.available_mechs = StartingRoster.player_roster()
	back_button.pressed.connect(func() -> void:
		GameManager.go_to_command()
	)
	deploy_button.pressed.connect(_on_deploy)
	stage.resized.connect(_place_pair)
	shape.material = shape.material.duplicate()
	stage.resized.connect(_stretch_shape)
	shape.resized.connect(_stretch_shape)
	deck.resized.connect(_sync_card_fade)
	deck_lead.resized.connect(_sync_card_fade)
	deck_scroll.resized.connect(_sync_card_fade)
	deck_scroll.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void:
		_sync_card_fade()
	)
	_style_frame()
	_add_overdrive_info()
	_watch_stat_tips()
	_build_roster()
	if not GameManager.available_mechs.is_empty():
		_focused = GameManager.available_mechs[0]
	_refresh()


func _build_roster() -> void:
	for child in roster.get_children():
		roster.remove_child(child)
		child.free()
	for data in GameManager.available_mechs:
		var button := ROW_SCENE.instantiate() as Button
		button.pressed.connect(_on_roster_pressed.bind(data))
		var check := button.get_node("%Check") as CheckBox
		check.toggled.connect(_on_check_toggled.bind(data))
		roster.add_child(button)
		_buttons[data.id] = button
		_checks[data.id] = check


func _on_roster_pressed(data: MechData) -> void:
	_focused = data
	_refresh()


func _on_check_toggled(pressed: bool, data: MechData) -> void:
	if _syncing:
		return
	_focused = data
	var index := _index_of(data)
	if pressed:
		if index < 0 and _squad.size() < _squad_limit():
			_squad.append(data)
		elif index < 0:
			_syncing = true
			var check := _checks.get(data.id) as CheckBox
			if check != null:
				check.button_pressed = false
			_syncing = false
	elif index >= 0:
		_squad.remove_at(index)
	_refresh()


func _on_deploy() -> void:
	if _squad.size() != _squad_limit():
		return
	GameManager.deploy(_squad)


func _squad_limit() -> int:
	return GameManager.squad_size()


func _sync_deploy_pulse(ready: bool) -> void:
	deploy_button.disabled = not ready
	if ready:
		_start_deploy_flash()
	else:
		_stop_deploy_flash()


func _start_deploy_flash() -> void:
	if _deploy_flash != null and _deploy_flash.is_valid() and _deploy_flash.is_running():
		return
	_deploy_flash = AccentPulse.start(self, deploy_button)


func _stop_deploy_flash() -> void:
	if _deploy_flash != null and _deploy_flash.is_valid():
		_deploy_flash.kill()
	_deploy_flash = null
	if deploy_button == null:
		return
	deploy_button.theme_type_variation = &""
	for slot in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		deploy_button.remove_theme_stylebox_override(slot)


func _refresh() -> void:
	var limit := _squad_limit()
	deploy_button.text = "Deploy Squad %d/%d" % [_squad.size(), limit]
	_syncing = true
	for data in GameManager.available_mechs:
		var button := _buttons.get(data.id) as Button
		if button == null:
			continue
		var slot := _index_of(data)
		button.text = data.display_name
		var check := _checks.get(data.id) as CheckBox
		if check != null:
			check.button_pressed = slot >= 0
		_paint_roster_button(button, data, slot >= 0)
	_syncing = false
	_show_focused()
	_show_totals()
	_sync_deploy_pulse(_squad.size() == _squad_limit())
	_place_pair()


func _show_focused() -> void:
	_style_frame()
	var show_stats := _focused != null
	blurb.visible = show_stats
	stat_table.visible = show_stats
	if _focused == null:
		preview_name.text = "Select a mech"
		pilot_sprite.visible = false
		mech_sprite.visible = false
		_show_deck()
		return
	preview_name.text = _focused.display_name
	blurb.text = _focused.blurb
	_show_stat(hp_stat, hp_grade, _focused.max_hp, _focused.hp_grade)
	var attack := _attack_span(_focused)
	_show_span(atk_stat, atk_grade, attack.x, attack.y, _focused.atk_grade)
	var reach := _reach_span(_focused)
	_show_span(rng_stat, rng_grade, reach.x, reach.y, _focused.rng_grade, true)
	_show_stat(mov_stat, mov_grade, _focused.move_range, _focused.move_grade)
	_show_stat(spd_stat, spd_grade, _focused.speed, _focused.speed_grade)
	_show_stat(ovd_stat, ovd_grade, _focused.charge, _focused.charge_grade)
	var pilot := MechSprites.pilot_frames(_focused.art_id)
	_apply_sprite(pilot_sprite, pilot, MechSprites.portrait_plays(pilot))
	_apply_sprite(mech_sprite, MechSprites.frames_for(_focused.art_id), true)
	_show_deck()


## Lowest and highest damage on this mech's attack cards.
func _attack_span(mech: MechData) -> Vector2i:
	return _card_span(mech, true)


## Lowest and highest reach on this mech's attack cards.
func _reach_span(mech: MechData) -> Vector2i:
	return _card_span(mech, false)


func _card_span(mech: MechData, damage: bool) -> Vector2i:
	var low := 0
	var high := 0
	var found := false
	var mech_deck := MechDecks.for_mech(mech)
	if mech_deck == null:
		return Vector2i.ZERO
	for card in mech_deck.cards:
		if card == null or card.card_type != "Attack":
			continue
		var amount := card.damage if damage else card.reach
		if not found:
			low = amount
			high = amount
			found = true
		else:
			low = mini(low, amount)
			high = maxi(high, amount)
	return Vector2i(low, high)


func _show_stat(value: Label, grade: Label, amount: int, letter: String) -> void:
	value.text = str(amount)
	_show_grade(grade, letter)


func _show_span(value: Label, grade: Label, low: int, high: int, letter: String, single_when_equal := false) -> void:
	if single_when_equal and low == high:
		value.text = str(low)
	else:
		value.text = "%d-%d" % [low, high]
	_show_grade(grade, letter)


func _show_grade(grade: Label, letter: String) -> void:
	grade.text = letter
	var gold := letter == "S" or letter == "A"
	grade.add_theme_color_override("font_color", TIER_GOLD if gold else Color.WHITE)


func _watch_stat_tips() -> void:
	if _special_note == null or stat_grid == null:
		return
	for child in stat_grid.get_children():
		var stat := child as Control
		if stat == null:
			continue
		var note := _stat_tip(stat.name)
		if note.is_empty():
			continue
		_special_note.tap(stat, note)


func _stat_tip(node_name: String) -> String:
	for key in MechData.STAT_TIPS:
		if node_name.begins_with(key):
			return MechData.STAT_TIPS[key]
	return ""


func _show_deck() -> void:
	var mech_id := "" if _focused == null else _focused.id
	if mech_id == _deck_mech_id:
		return
	_deck_mech_id = mech_id
	_deal_token += 1
	_deal_tries = 0
	_close_special_note()
	for child in deck.get_children():
		deck.remove_child(child)
		child.free()
	if _focused == null:
		return
	var cards := MechDecks.for_mech(_focused)
	if cards == null:
		return
	var stroke := MechCard.stroke_for(_focused)
	var views: Array[MechCard] = []
	for card in _strip_order(cards.cards):
		var slot := SLOT_SCENE.instantiate() as Control
		deck.add_child(slot)
		var view := CARD_SCENE.instantiate() as MechCard
		view.fit_strip()
		view.size = view.custom_minimum_size
		view.visible = false
		slot.add_child(view)
		view.present(card, stroke)
		if card.is_special:
			_add_special_info(view)
			view.play_shine()
		views.append(view)
	if views.is_empty():
		return
	deck_scroll.scroll_horizontal = 0
	get_tree().process_frame.connect(_start_deal.bind(views, _deal_token), CONNECT_ONE_SHOT)


func _start_deal(views: Array[MechCard], token: int) -> void:
	if token != _deal_token or views.is_empty():
		return
	var first := views[0]
	if not is_instance_valid(first):
		return
	var placed := first.size.x >= 2.0 and first.global_position.x > 8.0
	if not placed:
		if _deal_tries < 8:
			_deal_tries += 1
			get_tree().process_frame.connect(_start_deal.bind(views, token), CONNECT_ONE_SHOT)
		else:
			for view in views:
				if is_instance_valid(view):
					view.visible = true
					view.scale = Vector2.ONE
		return
	deck_scroll.scroll_horizontal = 0
	var rest: Vector2 = first.get_global_transform() * (first.size * 0.5)
	var origin_x := deck_scroll.get_global_rect().end.x + first.size.x * 0.5
	var origin := Vector2(origin_x, rest.y)
	for index in views.size():
		var view := views[index]
		if not is_instance_valid(view):
			continue
		view.visible = true
		view.deal_from(origin, float(index) * MechCard.DEAL_STAGGER, index, views.size())


func _show_totals() -> void:
	var total_charge := 0
	for data in _squad:
		total_charge += data.charge
	if overdrive_preview != null:
		overdrive_preview.show_squad(total_charge, GameManager.SQUAD_ATTACK_MAX)


func _apply_sprite(sprite: AnimatedSprite2D, frames: SpriteFrames, animate: bool) -> void:
	if frames == null or not frames.has_animation("idle"):
		sprite.visible = false
		return
	sprite.visible = true
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	if animate:
		if not sprite.is_playing():
			sprite.play("idle")
	else:
		sprite.pause()
		sprite.frame = 0
	sprite.flip_h = false


func _strip_order(cards: Array[CardData]) -> Array[CardData]:
	var specials: Array[CardData] = []
	var regular: Array[CardData] = []
	for card in cards:
		if card == null:
			continue
		if card.is_special:
			specials.append(card)
		else:
			regular.append(card)
	specials.append_array(regular)
	return specials


func _sync_card_fade() -> void:
	card_fade.z_as_relative = false
	card_fade.z_index = 120
	var leftover := deck_lead.size.x - deck_scroll.scroll_horizontal - deck_scroll.size.x
	card_fade.visible = leftover > 4.0


func _stretch_shape() -> void:
	if shape.size.x < 8.0 or stage.size.x < 8.0 or stage.size.y < 8.0:
		return
	var mat := shape.material as ShaderMaterial
	if mat == null:
		return
	var anchor_y := stage.size.y / shape.size.y
	if anchor_y < 0.01:
		return
	var anchor_x := SHAPE_ANCHOR * stage.size.x / shape.size.x
	var slope := SHAPE_SLOPE * shape.size.y / shape.size.x
	mat.set_shader_parameter("edge_top", anchor_x - slope * anchor_y)
	mat.set_shader_parameter("edge_bottom", anchor_x + slope * (1.0 - anchor_y))


func _place_pair() -> void:
	if stage.size.x < 8.0 or stage.size.y < 8.0:
		return
	var show_pilot := pilot_sprite.visible
	var show_mech := mech_sprite.visible
	if not show_pilot and not show_mech:
		return
	var area_height := stage.size.y - 8.0
	var area_width := stage.size.x - 16.0
	var mech_slot := minf(area_height, area_width * 0.78)
	if mech_slot < 32.0:
		return
	var pilot_slot := mech_slot * 0.58
	var baseline := stage.size.y - 4.0
	var pilot_left := 4.0
	if show_pilot and show_mech:
		var shift := mech_slot * 0.34
		var mech_left := (pilot_slot - mech_slot) * 0.5 + shift
		pilot_sprite.z_index = 2
		mech_sprite.z_index = 1
		_place_sprite(pilot_sprite, pilot_slot, pilot_left, baseline)
		_place_sprite(mech_sprite, mech_slot, pilot_left + mech_left, baseline)
	elif show_pilot:
		_place_sprite(pilot_sprite, pilot_slot, pilot_left, baseline)
	else:
		_place_sprite(mech_sprite, mech_slot, (stage.size.x - mech_slot) * 0.5, baseline)


func _place_sprite(sprite: AnimatedSprite2D, slot: float, left: float, baseline: float) -> void:
	var tex_size := Vector2(MechSprites.FRAME_SIZE, MechSprites.FRAME_SIZE)
	var tex: Texture2D = null
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		tex = sprite.sprite_frames.get_frame_texture("idle", 0)
		if tex != null:
			tex_size = tex.get_size()
	var content := Rect2(Vector2.ZERO, tex_size)
	if sprite == pilot_sprite and tex != null:
		content = MechSprites.content_rect(tex)
	var longest := maxf(content.size.x, content.size.y)
	if longest < 1.0:
		longest = maxf(tex_size.x, tex_size.y)
	var fit := slot / longest
	sprite.scale = Vector2(fit, fit)
	var content_center_x := content.position.x + content.size.x * 0.5
	var content_bottom := content.position.y + content.size.y
	sprite.position = Vector2(
		left + slot * 0.5 - (content_center_x - tex_size.x * 0.5) * fit,
		baseline - (content_bottom - tex_size.y * 0.5) * fit
	)


func _index_of(data: MechData) -> int:
	for index in _squad.size():
		if _squad[index] == data:
			return index
	return -1


func _paint_roster_button(button: Button, data: MechData, selected: bool) -> void:
	if selected:
		button.theme_type_variation = &"RosterButtonSelected"
	elif data == _focused:
		button.theme_type_variation = &"RosterButtonActive"
	else:
		button.theme_type_variation = &"RosterButton"
	for slot in ["normal", "hover", "pressed", "focus"]:
		button.remove_theme_stylebox_override(slot)


func _style_frame() -> void:
	frame.theme_type_variation = &"PreviewFrameFocused" if _focused != null else &"PreviewFrame"
	card_row.add_theme_constant_override("margin_left", 0)
	card_row.add_theme_constant_override("margin_right", 0)
	deck_lead.add_theme_constant_override("margin_left", int(CARD_LEAD))


func _add_overdrive_info() -> void:
	if overdrive_preview == null or overdrive_preview.info_badge == null or _special_note == null:
		return
	overdrive_preview.info_badge.set_meta("tip_width", 480.0)
	_special_note.attach(overdrive_preview.info_badge, OVERDRIVE_NOTE)


func _add_special_info(view: MechCard) -> void:
	var badge := view.special_badge()
	if badge == null or _special_note == null:
		return
	_special_note.attach(badge, MechCard.SPECIAL_NOTE)


func _close_special_note() -> void:
	if _special_note != null:
		_special_note.dismiss()
