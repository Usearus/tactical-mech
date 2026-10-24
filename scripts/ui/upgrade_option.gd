class_name UpgradeOption
extends Control

signal pressed

const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const GROUP_CARD_SCENE := preload("res://scenes/ui/mech_card_group.tscn")
const BADGE_SCENE := preload("res://scenes/ui/hand_owner_badge.tscn")
const TAG_SCENE := preload("res://scenes/ui/offer_kind_badge.tscn")
const CARD_SIZE := Vector2(176, 268)
const RISE := 42.0
const REVEAL_TIME := 0.34
const STAGGER := 0.14
const GOLD_LOW := 0.35
const GOLD_HIGH := 0.85

@onready var _column: Control = $Column
@onready var _card_host: Control = %CardHost
@onready var _hit: Control = %Hit
@onready var _shadow: CanvasItem = %RareShadow

var _card: MechCard
var _kind_tag: Control
var _stars: Array[TextureRect] = []
var _reveal: Tween
var _shadow_tween: Tween
var _shine_after := false


func _ready() -> void:
	_stars = [%Star1, %Star2, %Star3]
	if _hit != null and not _hit.gui_input.is_connected(_on_hit):
		_hit.gui_input.connect(_on_hit)


func show_choice(choice: UpgradeChoice) -> void:
	if choice == null or choice.preview == null or _card_host == null:
		return
	var group := choice.kind == "Immediate"
	if _card == null:
		var scene: PackedScene = GROUP_CARD_SCENE if group else CARD_SCENE
		_card = scene.instantiate() as MechCard
		_card.custom_minimum_size = CARD_SIZE
		_card.size = CARD_SIZE
		_card_host.add_child(_card)
	var stroke := MechCard.stroke_for(null)
	if choice.bound_mech != null:
		stroke = MechCard.stroke_for(choice.bound_mech.data)
	_card.present(choice.preview, stroke)
	_card.set_pull_enabled(false)
	if group:
		_card.show_instant_use()
	for index in _stars.size():
		_stars[index].visible = index < choice.rarity
	_shine_after = choice.rarity >= 3
	_set_rare_shadow(_shine_after)
	var badges := _show_badges(choice.mechs)
	_show_kind_tag(_kind_caption(choice.kind), badges)
	_prime_reveal()


## Rise into place after the card to its left. Clicks wait until this one starts.
func play_reveal(index: int) -> void:
	_prime_reveal()
	if _reveal != null:
		_reveal.kill()
	_reveal = create_tween()
	_reveal.tween_interval(maxf(index, 0) * STAGGER)
	_reveal.tween_callback(_arm_hit)
	_reveal.set_parallel(true)
	if _column != null:
		_reveal.tween_property(_column, "modulate:a", 1.0, REVEAL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var rise := _reveal.tween_method(_set_rise, RISE, 0.0, REVEAL_TIME)
	rise.set_trans(Tween.TRANS_CUBIC)
	rise.set_ease(Tween.EASE_OUT)
	if _shine_after and _card != null:
		_reveal.chain().tween_callback(_card.play_shine)


func _prime_reveal() -> void:
	_set_rise(RISE)
	if _column != null:
		_column.modulate.a = 0.0
	if _hit != null:
		_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_rise(amount: float) -> void:
	for node in [_column, _hit]:
		if node == null:
			continue
		node.offset_top = amount
		node.offset_bottom = amount


func _arm_hit() -> void:
	if _hit != null:
		_hit.mouse_filter = Control.MOUSE_FILTER_STOP


func set_selected(selected: bool) -> void:
	if _card != null:
		_card.set_chosen(selected)


func _set_rare_shadow(enabled: bool) -> void:
	if _shadow == null:
		return
	if _shadow_tween != null:
		_shadow_tween.kill()
		_shadow_tween = null
	_shadow.visible = enabled
	if not enabled:
		return
	_shadow.modulate = Color(1, 1, 1, GOLD_LOW)
	_shadow_tween = create_tween()
	_shadow_tween.set_loops()
	_shadow_tween.tween_property(_shadow, "modulate:a", GOLD_HIGH, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shadow_tween.tween_property(_shadow, "modulate:a", GOLD_LOW, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kind_caption(kind: String) -> String:
	if kind == "Modify":
		return "Upgrade"
	if kind == "Grant":
		return "New Card"
	return ""


## Sits to the right of the portrait pin. Upgrade and new-card offers only.
func _show_kind_tag(caption: String, badge_count: int) -> void:
	if _card_host == null:
		return
	if caption == "":
		if _kind_tag != null and is_instance_valid(_kind_tag):
			_kind_tag.visible = false
		return
	if _kind_tag == null or not is_instance_valid(_kind_tag):
		_kind_tag = TAG_SCENE.instantiate()
		_kind_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_kind_tag.z_as_relative = true
		_kind_tag.z_index = HandOwnerBadge.DRAW_Z
		_card_host.add_child(_kind_tag)
	_kind_tag.visible = true
	var caption_label := _kind_tag.get_node_or_null("Caption") as Label
	if caption_label != null:
		caption_label.text = caption
	_kind_tag.reset_size()
	var pin_h := 78.0 * HandOwnerBadge.PIN_SCALE
	var x := 0.0
	if badge_count > 0:
		x = float(badge_count - 1) * 52.0 + 80.0 * HandOwnerBadge.PIN_SCALE + 8.0
	_kind_tag.position = Vector2(x, -(pin_h + _kind_tag.size.y) * 0.5)


## Same seat as the hand: the pin's bottom sits on the card's top-left corner.
func _show_badges(mechs: Array[MechState]) -> int:
	if _card_host == null:
		return 0
	for child in _card_host.get_children():
		if child is HandOwnerBadge:
			_card_host.remove_child(child)
			child.free()
	var shown := 0
	for unit in mechs:
		if unit == null or unit.data == null:
			continue
		var badge := BADGE_SCENE.instantiate() as HandOwnerBadge
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.z_as_relative = true
		badge.z_index = HandOwnerBadge.DRAW_Z
		badge.scale = Vector2(HandOwnerBadge.PIN_SCALE, HandOwnerBadge.PIN_SCALE)
		_card_host.add_child(badge)
		badge.position = Vector2(shown * 52, 0)
		badge.show_head(unit.art_id, MechCard.stroke_for(unit.data))
		shown += 1
	return shown


func _on_hit(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		_hit.accept_event()
