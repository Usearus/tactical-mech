extends VBoxContainer

const BADGE_LIFT := 78.0 * HandOwnerBadge.PIN_SCALE
const ROW_GAP := 6.0

@onready var _room: Control = $BadgeRoom
@onready var _listed: ListedCard = $ListedCard
@onready var _stars = $StarRow


func present(card: CardData, stroke: Color, tag: String, stars: int, squad: bool, art_id := "") -> void:
	if _listed == null or card == null:
		return
	_listed.show_card(card, stroke, card.damage, card.block, tag, false, squad)
	_show_owner(art_id, stroke)
	if card.is_special and _listed.card_view != null:
		_listed.card_view.play_shine()
	if _stars != null:
		_stars.show_count(stars)
	_silence(self)


## The battle hand pins this mark on a mech's first card. Here it marks every card.
func _show_owner(art_id: String, rim: Color) -> void:
	var shown := art_id != "" and _listed.card_view != null
	if _room != null:
		_room.visible = shown
		_room.custom_minimum_size = Vector2(0.0, BADGE_LIFT - ROW_GAP if shown else 0.0)
	if not shown:
		return
	var host := _listed.get_node_or_null("CardHost") as Control
	_listed.card_view.set_owner_badge(art_id, rim, host)


func _silence(node: Node) -> void:
	var control := node as Control
	if control != null and not UiIcons.keeps_mouse(control):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_silence(child)
