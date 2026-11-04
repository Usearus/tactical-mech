class_name BonusRow
extends PanelContainer

@onready var _name_label: Label = %Name
@onready var _blurb_label: Label = %Blurb

var _stars: Array[TextureRect] = []


func _ready() -> void:
	_stars = [%Star1 as TextureRect, %Star2 as TextureRect, %Star3 as TextureRect]


func show_edict(offer: UpgradeOffer) -> void:
	if offer == null:
		return
	if not is_node_ready():
		show_edict.call_deferred(offer)
		return
	_name_label.text = offer.display_name
	_blurb_label.text = offer.blurb
	for index in _stars.size():
		_stars[index].visible = index < offer.rarity
