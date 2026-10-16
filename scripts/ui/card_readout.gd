class_name CardReadout
extends VBoxContainer

const ENHANCED_COLOR := Color(0.45, 0.78, 1.0)
const CHARGE_SHADER: Shader = preload("res://shaders/icon_white.gdshader")
const ICONS := {
	"atk": preload("res://art/icons/stats/attack.svg"),
	"rng": preload("res://art/icons/stats/range.svg"),
	"mov": preload("res://art/icons/stats/move.svg"),
	"dodge": preload("res://art/icons/stats/dodge.svg"),
	"def": preload("res://art/icons/stats/defend.svg"),
	"bar": preload("res://art/icons/stats/crescent.svg"),
	"chg": preload("res://icodot-svg/ui/weather-nature/icon-lightning-ui.svg"),
}

var _chips: Array[HBoxContainer] = []
var _shown_key: String = ""

@onready var title_label: Label = %Title
@onready var kind_label: Label = %Kind
@onready var action_amount: Label = %ActionCost/Amount
@onready var special_label: Label = %Special
@onready var body: RichTextLabel = %Body
@onready var stats: HBoxContainer = %Stats


func _ready() -> void:
	for child in stats.get_children():
		var chip := child as HBoxContainer
		if chip == null:
			continue
		_chips.append(chip)
		chip.visible = false


func present(card: CardData, damage: int, block: int) -> void:
	if card == null:
		return
	var key := "%d|%d|%d" % [card.get_instance_id(), damage, block]
	if key == _shown_key:
		return
	_shown_key = key
	title_label.text = card.display_name
	kind_label.text = _kind_line(card)
	action_amount.text = str(maxi(card.action_cost, 0))
	special_label.text = MechCard.SPECIAL_NOTE
	special_label.visible = card.is_special
	var copy := card.description.strip_edges()
	body.text = copy
	body.visible = copy != ""
	_show_stats(card, damage, block)


func _kind_line(card: CardData) -> String:
	var kind := card.card_type
	if card.moves_only():
		kind = "Move"
	elif card.is_dodge():
		kind = "Dodge"
	elif card.is_guard():
		kind = "Guard"
	elif card.barrier > 0 and card.card_type == "Defense":
		kind = "Barrier"
	var cost := maxi(card.action_cost, 0)
	if cost == 0:
		return "%s · Free" % kind
	if cost == 1:
		return "%s · 1 action" % kind
	return "%s · %d actions" % [kind, cost]


func _show_stats(card: CardData, damage: int, block: int) -> void:
	var rows := _stat_rows(card, damage, block)
	for index in _chips.size():
		var chip := _chips[index]
		if index >= rows.size():
			chip.visible = false
			continue
		var row: Dictionary = rows[index]
		_paint_chip(chip, str(row["kind"]), int(row["amount"]), bool(row["enhanced"]))
	stats.visible = not rows.is_empty()


func _stat_rows(card: CardData, damage: int, block: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	match card.card_type:
		"Attack":
			rows.append({"kind": "atk", "amount": damage, "enhanced": damage > card.damage})
			if card.reach > 0:
				rows.append({"kind": "rng", "amount": card.reach, "enhanced": false})
			if card.movement > 0:
				rows.append({"kind": "mov", "amount": card.movement, "enhanced": false})
		"Defense":
			if card.target_type == "squad":
				rows.append({"kind": "chg", "amount": GameManager.SPARK_CHARGE, "enhanced": false})
			elif card.barrier > 0:
				rows.append({"kind": "bar", "amount": card.barrier, "enhanced": false})
			elif card.is_dodge():
				rows.append({"kind": "dodge", "amount": 1, "enhanced": false})
			elif card.block > 0:
				rows.append({"kind": "def", "amount": block, "enhanced": block > card.block})
			if card.movement > 0:
				rows.append({"kind": "mov", "amount": card.movement, "enhanced": false})
		"Move":
			rows.append({"kind": "mov", "amount": card.movement, "enhanced": false})
	if card.intercept and not card.is_dodge():
		rows.append({"kind": "dodge", "amount": 1, "enhanced": false})
	return rows


func _paint_chip(chip: HBoxContainer, kind: String, amount: int, enhanced: bool) -> void:
	chip.visible = true
	var icon := chip.get_node("Icon") as TextureRect
	var number := chip.get_node("Number") as Label
	icon.texture = ICONS[kind] as Texture2D
	number.text = str(amount)
	number.visible = true
	if enhanced:
		icon.modulate = ENHANCED_COLOR
		number.add_theme_color_override("font_color", ENHANCED_COLOR)
	else:
		icon.modulate = Color(0.95, 0.96, 0.98)
		number.remove_theme_color_override("font_color")
	if kind == "chg":
		var bolt := ShaderMaterial.new()
		bolt.shader = CHARGE_SHADER
		bolt.set_shader_parameter("ink", Color(0.95, 0.96, 0.98))
		icon.material = bolt
	else:
		icon.material = null
