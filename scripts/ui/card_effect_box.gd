class_name CardEffectBox
extends PanelContainer

const LINE_SCENE := preload("res://scenes/ui/card_effect_line.tscn")
const CHARGE_SHADER: Shader = preload("res://shaders/icon_white.gdshader")
const CLOCK_ICON: Texture2D = preload("res://art/icons/stats/clock.svg")
const ICONS := {
	"atk": preload("res://art/icons/stats/attack.svg"),
	"rng": preload("res://art/icons/stats/range.svg"),
	"mov": preload("res://art/icons/stats/move.svg"),
	"dodge": preload("res://art/icons/stats/dodge.svg"),
	"def": preload("res://art/icons/stats/defend.svg"),
	"bar": preload("res://art/icons/stats/crescent.svg"),
	"chg": preload("res://icodot-svg/ui/weather-nature/icon-lightning-ui.svg"),
}

var _shown_key := ""

@onready var _cost_lines: VBoxContainer = %CostLines
@onready var _effects_heading: Label = %EffectsHeading
@onready var _effect_lines: VBoxContainer = %EffectLines


func show_card(card: CardData, damage: int, block: int) -> void:
	if card == null:
		visible = false
		return
	var overdrive := GameManager.battle_offense
	var key := "%d|%d|%d|%d" % [card.get_instance_id(), damage, block, card.charge_due(overdrive)]
	if key == _shown_key and visible:
		return
	_shown_key = key
	visible = true
	_fill(_cost_lines, [_cost_row(card, overdrive)])
	var effects := _effect_rows(card, damage, block)
	_effects_heading.visible = not effects.is_empty()
	_fill(_effect_lines, effects)
	reset_size()


func _cost_row(card: CardData, overdrive: bool) -> Dictionary:
	if card.pays_charge():
		var owed := card.charge_due(overdrive)
		var label := "1 charge" if owed == 1 else "%d charge" % owed
		return {"kind": "chg", "text": label}
	if card.pays_action():
		return {"kind": "act", "text": "1 action point"}
	return {"kind": "act", "text": "Free"}


func _effect_rows(card: CardData, damage: int, block: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	match card.card_type:
		"Attack":
			rows.append({"kind": "atk", "text": "%d damage" % damage})
			if card.reach > 0:
				rows.append({"kind": "rng", "text": "%d range" % card.reach})
			if card.movement > 0:
				rows.append({"kind": "mov", "text": "%d movement" % card.movement})
		"Defense":
			if card.target_type == "squad":
				rows.append({"kind": "chg", "text": "%d charge" % GameManager.SPARK_CHARGE})
			elif card.barrier > 0:
				rows.append({"kind": "bar", "text": "%d barrier" % card.barrier})
			elif card.is_dodge():
				rows.append({"kind": "dodge", "text": "Negates one attack"})
			elif card.block > 0:
				rows.append({"kind": "def", "text": "%d guard" % block})
			if card.movement > 0:
				rows.append({"kind": "mov", "text": "%d movement" % card.movement})
		"Move":
			rows.append({"kind": "mov", "text": "%d movement" % card.movement})
	if card.intercept and not card.is_dodge():
		rows.append({"kind": "dodge", "text": "Intercepts one attack"})
	return rows


func _fill(host: VBoxContainer, rows: Array[Dictionary]) -> void:
	if host == null:
		return
	while host.get_child_count() > 0:
		var child := host.get_child(0)
		host.remove_child(child)
		child.free()
	for row in rows:
		var line := LINE_SCENE.instantiate()
		host.add_child(line)
		var icon := line.get_node("Icon") as TextureRect
		var text := line.get_node("Text") as Label
		var kind := str(row["kind"])
		if kind == "act":
			icon.texture = CLOCK_ICON
			icon.modulate = MechCard.COST_COLOR
			icon.material = null
		elif kind == "chg":
			icon.texture = ICONS["chg"]
			icon.modulate = Color.WHITE
			var bolt := ShaderMaterial.new()
			bolt.shader = CHARGE_SHADER
			bolt.set_shader_parameter("ink", MechCard.COST_COLOR if host == _cost_lines else Color(0.95, 0.96, 0.98))
			icon.material = bolt
		else:
			icon.texture = ICONS[kind] as Texture2D
			icon.modulate = Color(0.95, 0.96, 0.98)
			icon.material = null
		if text != null:
			text.text = str(row["text"])
