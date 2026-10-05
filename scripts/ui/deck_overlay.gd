class_name DeckOverlay
extends CanvasLayer

const CARD_SCENE := preload("res://scenes/ui/mech_card.tscn")
const CARD_SIZE := Vector2(176, 268)

@onready var _overlay: Control = $Overlay
@onready var _title: Label = %Title
@onready var _close: Button = %Close
@onready var _scroll: ScrollContainer = %CardScroll
@onready var _list: GridContainer = %CardList
@onready var _info_note: InfoNote = %SpecialNote


func _ready() -> void:
	_close.pressed.connect(close)
	_overlay.visible = false


func is_open() -> bool:
	return _overlay.visible


func open_for(unit: MechState) -> void:
	if unit == null or unit.data == null or unit.team != "player":
		return
	var deck := MechDecks.for_mech(unit.data)
	if deck == null:
		return
	_title.text = "Deck"
	_overlay.visible = true
	_fill.call_deferred(unit, deck)


func close() -> void:
	if _info_note != null:
		_info_note.dismiss()
	if _overlay != null:
		_overlay.visible = false
	_clear()


func _fill(unit: MechState, deck: MechDeck) -> void:
	if not is_inside_tree() or not is_open() or unit == null or deck == null:
		return
	_clear()
	var width := _scroll.size.x
	if width < CARD_SIZE.x:
		width = 1100.0
	var stride := CARD_SIZE.x + 16.0
	_list.columns = maxi(1, int((width + 16.0) / stride))
	var cards: Array[CardData] = []
	for card in deck.cards:
		if card != null:
			cards.append(card)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.display_name < b.display_name
	)
	var stroke := MechCard.stroke_for(unit.data)
	for card in cards:
		var view := CARD_SCENE.instantiate() as MechCard
		view.custom_minimum_size = CARD_SIZE
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_list.add_child(view)
		view.present(card, stroke, GameManager.card_damage(card), GameManager.card_block(card))
		if card.is_special:
			view.play_shine()
			var badge := view.special_badge()
			if badge != null and _info_note != null:
				_info_note.attach(badge, MechCard.SPECIAL_NOTE)
		_silence_mouse(view)


func _clear() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()


func _silence_mouse(node: Node) -> void:
	var control := node as Control
	if control != null and not UiIcons.keeps_mouse(control):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_silence_mouse(child)
