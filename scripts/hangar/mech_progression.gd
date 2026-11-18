extends Control

const TAB_SCENE := preload("res://scenes/ui/squad_member_tab.tscn")
const TAB_SCRIPT := preload("res://scripts/ui/squad_member_tab.gd")
const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const LOCKED_SCENE := preload("res://scenes/ui/locked_card.tscn")
const TIER_GOLD := Color(0.98, 0.84, 0.32)
## Placeholder cards after the real deck. They are not unlocks yet.
const FAKE_LOCKED := 3

@onready var _back: BaseButton = %BackButton
@onready var _tabs: HBoxContainer = %Tabs
@onready var _name_label: Label = %Name
@onready var _role: Label = %Role
@onready var _stage: Control = %Stage
@onready var _left_scroll: ScrollContainer = %LeftScroll
@onready var _pilot: AnimatedSprite2D = %Pilot
@onready var _mech: AnimatedSprite2D = %Mech
@onready var _blurb: Label = %Blurb
@onready var _stat_grid: GridContainer = %StatGrid
@onready var _hp_stat: Label = %HpStat
@onready var _hp_grade: Label = %HpGrade
@onready var _atk_stat: Label = %AtkStat
@onready var _atk_grade: Label = %AtkGrade
@onready var _rng_stat: Label = %RngStat
@onready var _rng_grade: Label = %RngGrade
@onready var _mov_stat: Label = %MovStat
@onready var _mov_grade: Label = %MovGrade
@onready var _spd_stat: Label = %SpdStat
@onready var _spd_grade: Label = %SpdGrade
@onready var _enhance: BaseButton = %EnhanceButton
@onready var _cards: HFlowContainer = %CardFlow
@onready var _special_note: InfoNote = %SpecialNote

var _data: MechData
var _leaving := false


func _ready() -> void:
	_back.pressed.connect(_on_back)
	_enhance.pressed.connect(_on_enhance)
	if _stage != null and not _stage.resized.is_connected(_place_pair):
		_stage.resized.connect(_place_pair)
		_stage.resized.connect(_fit_stage_to_width)
	if _left_scroll != null and not _left_scroll.resized.is_connected(_fit_stage_to_width):
		_left_scroll.resized.connect(_fit_stage_to_width)
	_watch_stat_tips()
	_build_tabs(_roster())


func _on_back() -> void:
	if _leaving:
		return
	_leave()
	GameManager.go_to_hangar()


func _on_enhance() -> void:
	if _leaving or _data == null:
		return
	_leave()
	GameManager.progression_mech_id = _data.id
	GameManager.go_to_pilot_progression()


func _leave() -> void:
	_leaving = true
	_back.disabled = true
	_enhance.disabled = true
	for child in _tabs.get_children():
		var tab := child as BaseButton
		if tab != null:
			tab.disabled = true


func _roster() -> Array[MechData]:
	var roster: Array[MechData] = []
	var source := GameManager.available_mechs
	if source.is_empty():
		source = StartingRoster.player_roster()
	for data in source:
		if data != null:
			roster.append(data)
	return roster


func _build_tabs(roster: Array[MechData]) -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.free()
	if roster.is_empty():
		_show(null)
		return
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var wanted := GameManager.progression_mech_id
	var pick: MechData = roster[0]
	var pick_tab: Button = null
	for data in roster:
		var tab := TAB_SCENE.instantiate() as TAB_SCRIPT
		tab.button_group = group
		tab.tooltip_text = data.display_name
		_tabs.add_child(tab)
		tab.show_pilot(data.art_id)
		tab.pressed.connect(_on_tab.bind(data))
		if data.id == wanted:
			pick = data
			pick_tab = tab
		elif pick_tab == null and pick == data:
			pick_tab = tab
	if pick_tab != null:
		# Deferred so the group keeps this tab down after the buttons enter the tree.
		pick_tab.call_deferred("set", "button_pressed", true)
	_show(pick)


func _on_tab(data: MechData) -> void:
	if _leaving:
		return
	_show(data)


func _show(data: MechData) -> void:
	_data = data
	var shown := data != null
	_enhance.disabled = not shown
	if not shown:
		_name_label.text = ""
		_role.text = ""
		_blurb.text = ""
		_pilot.visible = false
		_mech.visible = false
		_fill_cards(null)
		return
	GameManager.progression_mech_id = data.id
	_name_label.text = data.display_name
	_role.text = data.role_line()
	_blurb.text = data.blurb
	_show_stat(_hp_stat, _hp_grade, data.max_hp, data.hp_grade)
	var attack := _attack_span(data)
	_show_span(_atk_stat, _atk_grade, attack.x, attack.y, data.atk_grade)
	var reach := _reach_span(data)
	_show_span(_rng_stat, _rng_grade, reach.x, reach.y, data.rng_grade, true)
	_show_stat(_mov_stat, _mov_grade, data.move_range, data.move_grade)
	_show_stat(_spd_stat, _spd_grade, data.speed, data.speed_grade)
	var pilot := MechSprites.pilot_frames(data.art_id)
	_apply_sprite(_pilot, pilot, MechSprites.portrait_plays(pilot))
	_apply_sprite(_mech, MechSprites.frames_for(data.art_id), true)
	_place_pair()
	_fill_cards(data)


func _fill_cards(data: MechData) -> void:
	_close_special_note()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.free()
	if data != null:
		var deck := MechDecks.for_mech(data)
		if deck != null:
			var stroke := MechCard.stroke_for(data)
			for card in _strip_order(deck.cards):
				var view := CARD_SCENE.instantiate() as MechCard
				_cards.add_child(view)
				view.fit_strip()
				view.present(card, stroke)
				if card.is_special:
					_add_special_info(view)
					view.play_shine()
	for _index in FAKE_LOCKED:
		_cards.add_child(LOCKED_SCENE.instantiate())


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
	if letter == "S" or letter == "A":
		grade.add_theme_color_override("font_color", TIER_GOLD)
	else:
		grade.remove_theme_color_override("font_color")


func _watch_stat_tips() -> void:
	if _special_note == null or _stat_grid == null:
		return
	for child in _stat_grid.get_children():
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


func _attack_span(mech: MechData) -> Vector2i:
	return _card_span(mech, true)


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


func _add_special_info(view: MechCard) -> void:
	var badge := view.special_badge()
	if badge == null or _special_note == null:
		return
	_special_note.attach(badge, MechCard.SPECIAL_NOTE)


func _close_special_note() -> void:
	if _special_note != null:
		_special_note.dismiss()


func _apply_sprite(sprite: AnimatedSprite2D, frames: SpriteFrames, animate: bool) -> void:
	if sprite == null:
		return
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


## Grow the stage so the pair can fill its width, but only while the column still fits.
func _fit_stage_to_width() -> void:
	if _stage == null or _left_scroll == null:
		return
	var width := _stage.size.x
	if width < 8.0:
		return
	var desired := _mech_slot_for_span(width - 16.0) + 8.0
	var room := _stage_room()
	if room < 8.0:
		return
	var height := minf(maxf(desired, 168.0), maxf(room, 168.0))
	if absf(_stage.custom_minimum_size.y - height) <= 1.0:
		return
	_stage.custom_minimum_size = Vector2(0, height)


## Height the stage can use without pushing the stats below it into a scrollbar.
func _stage_room() -> float:
	var stage_panel := _stage.get_parent() as Control
	if stage_panel == null:
		return 0.0
	var stack := stage_panel.get_parent() as Control
	if stack == null or _left_scroll == null:
		return 0.0
	var chrome := stage_panel.get_combined_minimum_size().y - _stage.get_combined_minimum_size().y
	var others := stack.get_combined_minimum_size().y - stage_panel.get_combined_minimum_size().y
	return _left_scroll.size.y - others - chrome


## Mech slot that makes the staggered pair span this many pixels.
func _mech_slot_for_span(span: float) -> float:
	var unit := _pair_span(1.0)
	if unit <= 0.0:
		return span
	return span / unit


func _pair_span(mech_slot: float) -> float:
	var pilot_slot := mech_slot * 0.58
	var mech_offset := (pilot_slot - mech_slot) * 0.5 + mech_slot * 0.34
	return mech_offset + mech_slot


## Pilot in front, mech larger and to the right, both on one floor line. The pair is centered.
func _place_pair() -> void:
	if _stage == null or _pilot == null or _mech == null:
		return
	if _stage.size.x < 8.0 or _stage.size.y < 8.0:
		return
	var pilot_shown := _pilot.visible
	var mech_shown := _mech.visible
	if not pilot_shown and not mech_shown:
		return
	var area_height := _stage.size.y - 8.0
	var area_width := _stage.size.x - 16.0
	var mech_slot := minf(area_height, _mech_slot_for_span(area_width))
	if mech_slot < 32.0:
		return
	var pilot_slot := mech_slot * 0.58
	var baseline := _stage.size.y - 4.0
	if pilot_shown and mech_shown:
		var mech_offset := (pilot_slot - mech_slot) * 0.5 + mech_slot * 0.34
		var group_left := 4.0
		var group_right := group_left + mech_offset + mech_slot
		var nudge := (_stage.size.x - (group_right - group_left)) * 0.5 - group_left
		_place_sprite(_pilot, pilot_slot, group_left + nudge, baseline, true)
		_place_sprite(_mech, mech_slot, group_left + mech_offset + nudge, baseline, false)
	elif pilot_shown:
		_place_sprite(_pilot, pilot_slot, (_stage.size.x - pilot_slot) * 0.5, baseline, true)
	else:
		_place_sprite(_mech, mech_slot, (_stage.size.x - mech_slot) * 0.5, baseline, false)


func _place_sprite(sprite: AnimatedSprite2D, slot: float, left: float, baseline: float, use_content: bool) -> void:
	var tex_size := Vector2(MechSprites.FRAME_SIZE, MechSprites.FRAME_SIZE)
	var tex: Texture2D = null
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		tex = sprite.sprite_frames.get_frame_texture("idle", 0)
		if tex != null:
			tex_size = tex.get_size()
	var content := Rect2(Vector2.ZERO, tex_size)
	if use_content and tex != null:
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
