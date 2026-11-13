class_name ListedCard
extends Control

const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const CARD_SIZE := Vector2(176, 268)
const TAG_GAP := 4.0

@onready var _host: Control = %CardHost
@onready var _tag: OfferKindBadge = %Tag

var card_view: MechCard


func _ready() -> void:
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	_pin_bounds()


func show_card(card: CardData, stroke: Color, damage: int, block: int, tag: String, battle_rules := true) -> void:
	if _host == null or card == null:
		return
	if card_view == null:
		card_view = CARD_SCENE.instantiate() as MechCard
		card_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card_view.position = Vector2.ZERO
		card_view.custom_minimum_size = CARD_SIZE
		card_view.custom_maximum_size = CARD_SIZE
		card_view.size = CARD_SIZE
		card_view.size_flags_horizontal = SIZE_SHRINK_CENTER
		card_view.size_flags_vertical = SIZE_SHRINK_CENTER
		card_view.scale = Vector2.ONE
		_host.add_child(card_view)
	card_view.present(card, stroke, damage, block, battle_rules)
	if _tag == null:
		return
	_tag.show_caption(tag, _tone_for(tag))
	_pin_bounds()


func _tone_for(tag: String) -> String:
	if tag == UpgradeDeck.TAG_STANDARD:
		return "grey"
	if tag == UpgradeDeck.TAG_OVERDRIVE:
		return "gold"
	return ""


## Keeps the card at the hand size. The grid must not stretch the frame.
func _pin_bounds() -> void:
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER
	var tag_h := 28.0
	var tag_w := 0.0
	if _tag != null:
		_tag.reset_size()
		tag_h = _tag.size.y + TAG_GAP
		tag_w = _tag.size.x
	var width := maxf(CARD_SIZE.x, tag_w)
	var bounds := Vector2(width, CARD_SIZE.y + tag_h)
	custom_minimum_size = bounds
	custom_maximum_size = bounds
	if _host != null:
		_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_host.position = Vector2(0.0, tag_h)
		_host.custom_minimum_size = CARD_SIZE
		_host.custom_maximum_size = CARD_SIZE
		_host.size = CARD_SIZE
	if _tag != null:
		_tag.position = Vector2.ZERO
	if card_view != null:
		card_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card_view.position = Vector2.ZERO
		card_view.size = CARD_SIZE
		card_view.scale = Vector2.ONE
