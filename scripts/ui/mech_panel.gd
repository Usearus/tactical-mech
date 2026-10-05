class_name MechPanel
extends HBoxContainer

signal deck_pressed

var _unit: MechState
var _head_windows: Dictionary = {}
var _pilot_portrait := false

@onready var portrait_host: Panel = get_node_or_null("PortraitHost") as Panel
@onready var portrait: AnimatedSprite2D = get_node_or_null("PortraitHost/Portrait") as AnimatedSprite2D
@onready var name_label: Label = get_node_or_null("Stats/Name") as Label
@onready var map_line: Label = get_node_or_null("Stats/MapLine") as Label
@onready var hit_points: HBoxContainer = _find_badge("HitPoints")
@onready var barrier_row: HBoxContainer = _find_badge("Barrier")
@onready var guard_row: HBoxContainer = _find_badge("Guard")
@onready var action_row: HBoxContainer = _find_badge("Action")
@onready var attack_row: HBoxContainer = _find_badge("Attack")
@onready var attack_button: Button = get_node_or_null("AttackButton") as Button
@onready var deck_button: Button = get_node_or_null("DeckButton") as Button


func _ready() -> void:
	if portrait_host != null and portrait != null:
		portrait.centered = true
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_host.resized.connect(_place_portrait)
		portrait_host.clip_contents = true
	if deck_button != null and not deck_button.pressed.is_connected(_on_deck_pressed):
		deck_button.pressed.connect(_on_deck_pressed)
	show_message("Select a mech")


func present_unit(unit: MechState, show_attack: bool) -> void:
	if attack_button != null:
		attack_button.visible = show_attack
	_unit = unit
	if unit == null:
		show_message("Select a mech")
		return
	if map_line != null:
		_present_overworld(unit)
	elif name_label != null:
		_present_rows(unit)
	_show_deck_button(unit)
	_show_portrait(unit)


func show_message(text: String) -> void:
	_unit = null
	if attack_button != null:
		attack_button.visible = false
	_show_deck_button(null)
	if portrait != null:
		portrait.visible = false
	if name_label != null:
		name_label.text = text
	if map_line != null:
		map_line.visible = false
	_set_badge(hit_points, false, "")
	_set_badge(barrier_row, false, "")
	_set_badge(guard_row, false, "")
	_set_badge(action_row, false, "")
	_set_badge(attack_row, false, "")


func _present_overworld(unit: MechState) -> void:
	var enemy := unit.team == "enemy"
	var max_hp := unit.hp
	if unit.data != null:
		max_hp = unit.data.max_hp
	name_label.text = unit.display_name
	_set_badge(hit_points, true, "%d / %d" % [unit.hp, max_hp])
	_set_badge(barrier_row, unit.standing_guard > 0, str(unit.standing_guard))
	_set_badge(action_row, enemy, str(unit.turn_count))
	_present_attack(unit, enemy)
	map_line.visible = true
	map_line.text = "MOV %d, ATR %d, SPD %d" % [unit.move_range, unit.attack_range, unit.speed]


func _present_rows(unit: MechState) -> void:
	var enemy := unit.team == "enemy"
	name_label.text = unit.display_name
	_set_badge(hit_points, true, str(unit.hp))
	_set_badge(barrier_row, unit.standing_guard > 0, str(unit.standing_guard))
	_set_badge(guard_row, not enemy and unit.guard > 0, str(unit.guard))
	_set_badge(action_row, enemy, str(maxi(unit.cards_until_turn, 0)))
	_present_attack(unit, enemy)


func _present_attack(unit: MechState, enemy: bool) -> void:
	if attack_row == null:
		return
	if not enemy:
		attack_row.visible = false
		return
	var cards := _attack_cards(unit)
	if cards.is_empty():
		attack_row.visible = false
		return
	var low := cards[0].damage
	var high := low
	for card in cards:
		low = mini(low, card.damage)
		high = maxi(high, card.damage)
	var amount := str(low) if cards.size() == 1 or low == high else "%d-%d" % [low, high]
	_set_badge(attack_row, true, amount)


func _attack_cards(unit: MechState) -> Array[CardData]:
	var found: Array[CardData] = []
	if unit == null or unit.data == null:
		return found
	var deck := MechDecks.for_mech(unit.data)
	if deck == null:
		return found
	for card in deck.cards:
		if card != null and card.card_type == "Attack":
			found.append(card)
	return found


func _find_badge(node_name: String) -> HBoxContainer:
	var direct := get_node_or_null("Stats/" + node_name) as HBoxContainer
	if direct != null:
		return direct
	return get_node_or_null("Stats/Vitals/" + node_name) as HBoxContainer


func _set_badge(badge: HBoxContainer, shown: bool, amount: String) -> void:
	if badge == null:
		return
	badge.visible = shown
	if not shown:
		return
	var label := badge.get_node_or_null("Amount") as Label
	if label != null:
		label.text = amount


func _show_deck_button(unit: MechState) -> void:
	if deck_button == null:
		return
	deck_button.visible = unit != null and unit.team == "player"


func _on_deck_pressed() -> void:
	deck_pressed.emit()


func _show_portrait(unit: MechState) -> void:
	if portrait == null or portrait_host == null:
		return
	var frames: SpriteFrames = null
	if unit.team == "player":
		frames = MechSprites.pilot_frames(unit.art_id)
	_pilot_portrait = frames != null
	if frames == null:
		frames = MechSprites.frames_for(unit.art_id)
	if frames == null or not frames.has_animation("idle"):
		portrait.visible = false
		return
	portrait.visible = true
	if portrait.sprite_frames != frames:
		portrait.sprite_frames = frames
		portrait.play("idle")
	if unit.team != "player" or (_pilot_portrait and not MechSprites.portrait_plays(frames)):
		portrait.pause()
		portrait.frame = 0
	elif not portrait.is_playing():
		portrait.play("idle")
	portrait.flip_h = false if _pilot_portrait else unit.facing < 0
	_place_portrait()


func _place_portrait() -> void:
	if not portrait.visible or portrait.sprite_frames == null:
		return
	if not portrait.sprite_frames.has_animation("idle"):
		return
	var tex := portrait.sprite_frames.get_frame_texture("idle", 0)
	if tex == null or portrait_host.size.x < 1.0:
		return
	if _pilot_portrait:
		var longest := maxf(tex.get_width(), tex.get_height())
		if longest <= 0.0:
			return
		var fitted := minf(portrait_host.size.x, portrait_host.size.y) * 0.92 / longest
		portrait.scale = Vector2(fitted, fitted)
		portrait.position = portrait_host.size * 0.5
		return
	var window := _head_window(tex)
	if window.size.x < 1.0:
		return
	var fit := minf(portrait_host.size.x, portrait_host.size.y) / window.size.x
	portrait.scale = Vector2(fit, fit)
	var frame := tex.get_size()
	var head_center := window.position + window.size * 0.5
	var shift := (head_center - frame * 0.5) * fit
	if portrait.flip_h:
		shift.x = -shift.x
	portrait.position = portrait_host.size * 0.5 - shift


## Square over the top of the sprite so the portrait is the head, not the legs.
func _head_window(texture: Texture2D) -> Rect2:
	if _head_windows.has(texture):
		return _head_windows[texture]
	var frame := texture.get_size()
	var used := Rect2(Vector2.ZERO, frame)
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var opaque := image.get_used_rect()
		if opaque.size.x >= 1.0 and opaque.size.y >= 1.0:
			used = opaque
	var standing := used.size.y >= used.size.x * 0.85
	var fraction := 0.5 if standing else 0.82
	var side := minf(used.size.x, used.size.y * fraction)
	var window := Rect2(
		used.position.x + (used.size.x - side) * 0.5,
		used.position.y,
		side,
		side
	)
	_head_windows[texture] = window
	return window
