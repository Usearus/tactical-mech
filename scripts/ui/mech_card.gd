class_name MechCard
extends PanelContainer

const STROKES := {
	"red": Color(0.84, 0.2, 0.18),
	"tan": Color(0.74, 0.6, 0.36),
	"orange": Color(0.95, 0.48, 0.14),
	"purple": Color(0.58, 0.36, 0.88),
	"white": Color(0.86, 0.9, 0.96),
	"cyan": Color(0.22, 0.8, 0.88),
}

const BODY_COLOR := Color(0.14, 0.15, 0.19)
const FOOTER_COLOR := Color(0.09, 0.1, 0.13)
const POWER_BODY := Color(0.1, 0.3, 0.56)
const POWER_HEADER := Color(0.16, 0.46, 0.84)
const POWER_FOOTER := Color(0.07, 0.2, 0.4)
const ATTACK_ICON: Texture2D = preload("res://art/icons/stats/attack.png")
const RANGE_ICON: Texture2D = preload("res://art/icons/stats/range.png")
const MOVE_ICON: Texture2D = preload("res://art/icons/stats/move.png")
const DODGE_ICON: Texture2D = preload("res://art/icons/stats/dodge.png")
const DEFEND_ICON: Texture2D = preload("res://art/icons/stats/defend.png")
const BARRIER_ICON: Texture2D = preload("res://art/icons/stats/crescent.png")
const ENHANCED_COLOR := Color(0.45, 0.78, 1.0)
const CHIP_SCENE := preload("res://scenes/ui/stat_chip.tscn")
const INFO_BADGE := preload("res://scenes/ui/info_badge.tscn")
const SPECIAL_NOTE := "Special card: Can only be used when in overdrive mode."

signal pulled

const PULL_DISTANCE := 72.0
const HOVER_LIFT := -56.0
const DISCARD_PREVIEW_SCALE := 0.85
const DEAL_TIME := 0.3
const DEAL_STAGGER := 0.05
const DEAL_SCALE := 0.22

var _pull_enabled := false
var _dragging := false
var _pulling := false
var _press_global := Vector2.ZERO
var _start_position := Vector2.ZERO
var _lifted := false
var _gliding := false
var _glide_token := 0
var _motion: Tween
var _preview_motion: Tween
var _discard_preview := false
var _drop_handler: Callable
var _shown: CardData
var _stroke := Color.WHITE
var _power_amount := 0.0
var _stat_key := ""
var _stat_damage := 0
var _stat_block := 0
var _frame_style: StyleBoxFlat
var _header_style: StyleBoxFlat
var _footer_style: StyleBoxFlat
var _wave_tween: Tween
var _wave_token := 0
var _shine_tween: Tween
var _shine_token := 0

@onready var _gauge_tag: Label = $GaugeTag
@onready var _wave_host: Control = $OverdriveWave
@onready var _wave_band: TextureRect = $OverdriveWave/Band
@onready var _power_mark: Control = $OverdriveWave/PowerMark
@onready var _shine_host: Control = $Shine
@onready var _shine_band: TextureRect = $Shine/Glint
@onready var _shine_flash: ColorRect = $Shine/Flash
@onready var header: PanelContainer = %Header
@onready var footer: PanelContainer = %Footer
@onready var title_label: Label = %CardTitle
@onready var strength_label: Label = %Strength
@onready var detail_label: Label = %Detail
@onready var stat_row: HBoxContainer = %Stats


func _ready() -> void:
	_frame_style = _claim_style(self)
	_header_style = _claim_style(header)
	_footer_style = _claim_style(footer)


func _claim_style(panel: PanelContainer) -> StyleBoxFlat:
	var box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return null
	var copy := box.duplicate() as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", copy)
	return copy


static func stroke_for(mech: MechData) -> Color:
	if mech == null:
		return Color.WHITE
	if STROKES.has(mech.art_id):
		return STROKES[mech.art_id]
	return mech.color


func has_attack() -> bool:
	if _shown == null:
		return false
	return _shown.card_type == "Attack"


## Two blue sweeps up the card. The card stays blue, with the attack and guard marks side by side, until the wash ends.
func play_overdrive_wave() -> void:
	if not has_attack():
		return
	var host := _wave_host
	move_child(host, -1)
	if _wave_band != null:
		_wave_band.position = Vector2(0.0, size.y)
	host.visible = true
	_wave_token += 1
	var token := _wave_token
	if _wave_tween != null and _wave_tween.is_valid():
		_wave_tween.kill()
	_wave_tween = null
	_run_overdrive_wave.call_deferred(token)


## Looping glint that marks an overdrive card.
func play_shine() -> void:
	_shine_token += 1
	var token := _shine_token
	_run_shine.call_deferred(token)


## Short fixed card for the select-screen strip. Battle cards keep the taller layout.
func fit_strip() -> void:
	custom_minimum_size = Vector2(168, 228)
	size_flags_horizontal = SIZE_SHRINK_BEGIN
	size_flags_vertical = SIZE_SHRINK_CENTER
	var header := get_node_or_null("%Header") as PanelContainer
	if header != null:
		header.custom_minimum_size = Vector2(0, 36)
	var detail := get_node_or_null("%Detail") as Label
	if detail != null:
		detail.custom_minimum_size = Vector2(0, 100)
		detail.max_lines_visible = 5
	var card_footer := get_node_or_null("%Footer") as PanelContainer
	if card_footer != null:
		card_footer.custom_minimum_size = Vector2(0, 36)


func present(card: CardData, stroke: Color, damage := -1, block := -1) -> void:
	_shown = card
	_stroke = stroke
	_stat_damage = card.damage if damage < 0 else damage
	_stat_block = card.block if block < 0 else block
	title_label.text = card.display_name
	title_label.add_theme_color_override("font_color", Color.WHITE)
	detail_label.text = card.description
	_set_power_amount(_power_amount)
	_apply_stats()
	_sync_special_mark(card)
	_bind_tips()


func special_badge() -> TextureButton:
	if title_label == null:
		return null
	return title_label.get_node_or_null("SpecialInfo") as TextureButton


func _sync_special_mark(card: CardData) -> void:
	if title_label == null:
		return
	var existing := special_badge()
	if card == null or not card.is_special:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var badge := INFO_BADGE.instantiate() as TextureButton
	badge.name = "SpecialInfo"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_child(badge)


func arm_press() -> void:
	_pull_enabled = true
	mouse_filter = MOUSE_FILTER_STOP
	_ignore_mouse(self)
	resized.connect(_on_resized)
	_on_resized()


func set_pull_enabled(enabled: bool) -> void:
	_pull_enabled = enabled
	if not _gliding and not _pulling:
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled and _dragging:
		_dragging = false
		settle(false)


func set_drop_handler(handler: Callable) -> void:
	_drop_handler = handler


func set_discard_preview(active: bool) -> void:
	var preview := active and _dragging
	if preview == _discard_preview:
		return
	_discard_preview = preview
	if not _dragging:
		return
	var target := Vector2(DISCARD_PREVIEW_SCALE, DISCARD_PREVIEW_SCALE) if preview else _drag_scale()
	_tween_preview_scale(target)


func set_gauge_pitch_visible(show_tag: bool) -> void:
	_gauge_tag.visible = show_tag


func release_for_discard() -> void:
	_pull_enabled = false
	_dragging = false
	_pulling = true
	_cancel_glide()
	_discard_preview = false
	_kill_preview_motion()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_gliding() -> bool:
	return _gliding


func deal_from(origin: Vector2, delay: float, order: int = -1, count: int = 0) -> void:
	scale = Vector2(DEAL_SCALE, DEAL_SCALE)
	var current: Vector2 = get_global_transform() * (size * 0.5)
	global_position += origin - current
	if order < 0:
		begin_glide(DEAL_TIME, delay)
		return
	_deal_ordered(delay, order, count)


## Earlier cards stay above the ones still stacked on the pile. The moving card is above both.
func _deal_ordered(delay: float, order: int, count: int) -> void:
	_cancel_glide()
	_gliding = true
	var token := _glide_token
	z_as_relative = true
	z_index = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_slot_z(20 + count - order)
	_tween_to(Vector2.ZERO, Vector2.ONE, 0.0, false, DEAL_TIME, delay)
	if _motion == null:
		_end_glide()
		return
	_motion.tween_callback(func() -> void:
		if token != _glide_token:
			return
		_set_slot_z(80)
	).set_delay(delay)
	_motion.finished.connect(func() -> void:
		if token != _glide_token:
			return
		_end_glide()
		_set_slot_z(40)
	, CONNECT_ONE_SHOT)


func begin_glide(duration: float, delay: float = 0.0) -> void:
	_cancel_glide()
	_gliding = true
	var token := _glide_token
	z_as_relative = false
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween_to(Vector2.ZERO, Vector2.ONE, 0.0, false, duration, delay)
	if _motion == null:
		_end_glide()
		return
	_motion.finished.connect(func() -> void:
		if token != _glide_token:
			return
		_end_glide()
	, CONNECT_ONE_SHOT)


func _cancel_glide() -> void:
	_glide_token += 1
	_gliding = false
	if _motion != null and _motion.is_valid():
		_motion.kill()


func _end_glide() -> void:
	_gliding = false
	z_as_relative = true
	z_index = 0
	_set_slot_z(0)
	mouse_filter = Control.MOUSE_FILTER_STOP if _pull_enabled else Control.MOUSE_FILTER_IGNORE


func set_chosen(chosen: bool) -> void:
	modulate = Color(1.08, 1.0, 0.72) if chosen else Color.WHITE


func settle(lifted: bool) -> void:
	if _dragging or _pulling or _gliding:
		return
	var home := Vector2(0, HOVER_LIFT) if lifted else Vector2.ZERO
	var target_scale := Vector2(1.04, 1.04) if lifted else Vector2.ONE
	if lifted == _lifted and position.distance_to(home) < 2.0 and scale.distance_to(target_scale) < 0.02:
		_set_slot_z(1 if lifted else 0)
		return
	_lifted = lifted
	_tween_to(home, target_scale, 0.0, not lifted)
	_set_slot_z(8 if lifted else 0)


func _gui_input(event: InputEvent) -> void:
	if not _pull_enabled:
		return
	if _pulling:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag(event.global_position)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_follow_drag(event.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.global_position)
		get_viewport().set_input_as_handled()


func _begin_drag(global_pos: Vector2) -> void:
	_cancel_glide()
	z_as_relative = true
	z_index = 0
	_kill_preview_motion()
	_discard_preview = false
	_dragging = true
	_start_position = position
	_press_global = global_pos
	_set_slot_z(20)


func _follow_drag(global_pos: Vector2) -> void:
	var delta := global_pos - _press_global
	position = _start_position + delta
	if not _discard_preview and not _preview_playing():
		scale = _drag_scale()
	rotation = deg_to_rad(clampf(delta.x / 22.0, -8.0, 8.0))
	_notify_drop(global_pos, false)


func _end_drag(global_pos: Vector2) -> void:
	_dragging = false
	if _notify_drop(global_pos, true):
		return
	var delta := position - _start_position
	if delta.length() >= PULL_DISTANCE:
		_pulling = true
		await _play_pull(delta)
		_pulling = false
		if is_inside_tree():
			pulled.emit()
	else:
		settle(_lifted)


func _notify_drop(global_pos: Vector2, released: bool) -> bool:
	if not _drop_handler.is_valid():
		return false
	return bool(_drop_handler.call(global_pos, released))


func _play_pull(delta: Vector2) -> void:
	var direction := delta.normalized() if delta.length() > 1.0 else Vector2.UP
	var tilt := clampf(direction.x * 8.0, -8.0, 8.0)
	_tween_to(position + direction * 48.0, Vector2(1.1, 1.1), deg_to_rad(tilt), false)
	if _motion != null:
		await _motion.finished


func _drag_scale() -> Vector2:
	var amount := clampf((position - _start_position).length() / 160.0, 0.0, 1.0)
	return Vector2.ONE.lerp(Vector2(1.07, 1.07), amount)


func _tween_preview_scale(target: Vector2) -> void:
	_kill_preview_motion()
	_preview_motion = create_tween()
	_preview_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_motion.tween_property(self, "scale", target, 0.16)


func _preview_playing() -> bool:
	return _preview_motion != null and _preview_motion.is_valid() and _preview_motion.is_running()


func _kill_preview_motion() -> void:
	if _preview_motion != null and _preview_motion.is_valid():
		_preview_motion.kill()


func _tween_to(
	home: Vector2,
	target_scale: Vector2,
	target_rotation: float,
	spring: bool,
	duration: float = 0.2,
	delay: float = 0.0
) -> void:
	_kill_preview_motion()
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = create_tween()
	_motion.set_parallel(true)
	if spring:
		_motion.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "position", home, duration).set_delay(delay)
	_motion.tween_property(self, "scale", target_scale, duration).set_delay(delay)
	_motion.tween_property(self, "rotation", target_rotation, duration).set_delay(delay)


func _set_slot_z(value: int) -> void:
	var slot := get_parent()
	if slot is CanvasItem:
		slot.z_index = value


func _on_resized() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		var control := child as Control
		if control != null and not UiIcons.keeps_mouse(control):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


func _apply_stats() -> void:
	if _shown == null or strength_label == null:
		return
	var key := "%s|%s|%d|%d|%d|%d|%d|%d|%d" % [
		_shown.card_type,
		_shown.defense_kind,
		_shown.damage,
		_shown.block,
		_shown.barrier,
		_stat_damage,
		_stat_block,
		_shown.reach,
		_shown.movement,
	]
	if key == _stat_key:
		return
	_stat_key = key
	strength_label.visible = false
	_show_icon_stats(_shown)


func _show_icon_stats(card: CardData) -> void:
	var row := _ensure_stat_row()
	_clear_stat_row()
	match card.card_type:
		"Attack":
			_add_stat(row, "atk", _stat_damage, _stat_damage > card.damage)
			if card.reach > 0:
				_add_stat(row, "rng", card.reach)
			if card.movement > 0:
				_add_stat(row, "mov", card.movement)
		"Defense":
			if card.target_type == "squad":
				row.add_child(_stat_word("+%d CHG" % GameManager.SPARK_CHARGE))
			elif card.barrier > 0:
				_add_stat(row, "bar", card.barrier)
			elif card.is_dodge():
				_add_stat(row, "dodge", -1)
			elif card.block > 0:
				_add_stat(row, "def", _stat_block, _stat_block > card.block)
			if card.movement > 0:
				_add_stat(row, "mov", card.movement)
		"Move":
			_add_stat(row, "mov", card.movement)
	row.visible = row.get_child_count() > 0


func _add_stat(row: HBoxContainer, kind: String, amount: int, enhanced := false) -> void:
	var chip := _stat_chip(kind, amount, enhanced)
	chip.set_meta("tip_kind", kind)
	row.add_child(chip)


func _bind_tips() -> void:
	if not is_inside_tree():
		if not tree_entered.is_connected(_bind_tips):
			tree_entered.connect(_bind_tips, CONNECT_ONE_SHOT)
		return
	var note := tip_host()
	if note == null:
		return
	if stat_row != null:
		for child in stat_row.get_children():
			var kind := str(child.get_meta("tip_kind", ""))
			var phrase := UiIcons.phrase(kind)
			if phrase == "":
				continue
			note.watch(child, phrase)
	var badge := special_badge()
	if badge != null and _shown != null and _shown.is_special:
		note.attach(badge, SPECIAL_NOTE)


## The note that shares this card's screen, including one nested on a canvas layer above the cards.
func tip_host() -> InfoNote:
	if not is_inside_tree():
		return null
	var node: Node = self
	while node != null:
		var note := node.get_node_or_null("SpecialNote") as InfoNote
		if note != null:
			return note
		for child in node.get_children():
			note = child.get_node_or_null("SpecialNote") as InfoNote
			if note != null:
				return note
			note = child.get_node_or_null("TipHost/SpecialNote") as InfoNote
			if note != null:
				return note
		node = node.get_parent()
	return null


func _stat_chip(kind: String, amount: int, enhanced := false) -> Control:
	var chip := CHIP_SCENE.instantiate()
	var icon := chip.get_node("Icon") as TextureRect
	var number := chip.get_node("Number") as Label
	icon.texture = _stat_texture(kind)
	if amount < 0:
		number.visible = false
	else:
		number.text = str(amount)
	if enhanced:
		icon.modulate = ENHANCED_COLOR
		number.add_theme_color_override("font_color", ENHANCED_COLOR)
	return chip


func _stat_word(text: String) -> Control:
	var chip := CHIP_SCENE.instantiate()
	var icon := chip.get_node("Icon") as CanvasItem
	var number := chip.get_node("Number") as Label
	icon.visible = false
	number.text = text
	return chip


func _stat_texture(kind: String) -> Texture2D:
	match kind:
		"atk":
			return ATTACK_ICON
		"rng":
			return RANGE_ICON
		"dodge":
			return DODGE_ICON
		"def":
			return DEFEND_ICON
		"bar":
			return BARRIER_ICON
		_:
			return MOVE_ICON


func _ensure_stat_row() -> HBoxContainer:
	return stat_row


func _clear_stat_row() -> void:
	if stat_row == null:
		return
	for child in stat_row.get_children():
		stat_row.remove_child(child)
		child.free()
	stat_row.visible = false


func _run_overdrive_wave(token: int) -> void:
	if token != _wave_token or not is_inside_tree():
		return
	var host := _wave_host
	var band := _wave_band
	if host == null or band == null:
		return
	if host.size.x < 1.0 or host.size.y < 1.0:
		host.position = Vector2.ZERO
		host.size = size
	var height := host.size.y
	var width := host.size.x
	if height < 1.0:
		height = size.y
	if width < 1.0:
		width = size.x
	var band_h := height * 0.5
	band.size = Vector2(width, band_h)
	band.position = Vector2(0.0, height)
	var mark := _power_mark
	if mark != null and is_instance_valid(mark):
		_layout_power_mark(mark, Vector2(width, height))
		mark.scale = Vector2(0.35, 0.35)
		mark.modulate = Color(1, 1, 1, 0)
		host.move_child(mark, -1)
	_set_power_amount(1.0)
	_wave_tween = create_tween()
	_wave_tween.tween_property(band, "position:y", -band_h, 0.42).from(height) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mark != null and is_instance_valid(mark):
		_wave_tween.parallel().tween_property(mark, "modulate:a", 1.0, 0.1)
		_wave_tween.parallel().tween_property(mark, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wave_tween.chain().tween_property(band, "position:y", -band_h, 0.42).from(height) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wave_tween.chain().tween_method(_set_power_amount, 1.0, 0.0, 0.16)
	if mark != null and is_instance_valid(mark):
		_wave_tween.parallel().tween_property(mark, "modulate:a", 0.0, 0.16)
	_wave_tween.chain().tween_callback(func() -> void:
		if token != _wave_token or not is_instance_valid(host):
			return
		host.visible = false
		_set_power_amount(0.0)
	)


func _run_shine(token: int) -> void:
	if token != _shine_token or not is_inside_tree():
		return
	if size.x < 2.0 or size.y < 2.0:
		if not resized.is_connected(_retry_shine):
			resized.connect(_retry_shine, CONNECT_ONE_SHOT)
		return
	var host := _shine_host
	move_child(host, -1)
	host.visible = true
	host.position = Vector2.ZERO
	host.size = size
	if _shine_tween != null and _shine_tween.is_valid():
		_shine_tween.kill()
	_shine_tween = create_tween()
	_shine_tween.set_loops()
	_shine_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shine_tween.tween_method(_place_shine_glint, 0.0, 1.0, 0.72)
	_shine_tween.tween_interval(1.05)


func _retry_shine() -> void:
	_run_shine(_shine_token)


func _place_shine_glint(t: float) -> void:
	var host := _shine_host
	var band := _shine_band
	if host == null or band == null or not is_instance_valid(band):
		return
	host.position = Vector2.ZERO
	host.size = size
	var band_w := maxf(size.x * 0.42, 40.0)
	var band_h := size.y * 1.35
	band.size = Vector2(band_w, band_h)
	band.pivot_offset = band.size * 0.5
	var angle := deg_to_rad(-28.0)
	band.rotation = angle
	var reach := absf(cos(angle)) * band_w * 0.5 + absf(sin(angle)) * band_h * 0.5 + 4.0
	var center_x := lerpf(-reach, size.x + reach, t)
	band.position = Vector2(center_x - band_w * 0.5, (size.y - band_h) * 0.5)
	if _shine_flash != null and is_instance_valid(_shine_flash):
		_shine_flash.position = Vector2.ZERO
		_shine_flash.size = host.size
		_shine_flash.modulate.a = sin(t * PI) * 0.36


func _layout_power_mark(mark: Control, card_size: Vector2) -> void:
	var box := mark.get_combined_minimum_size()
	if box.x < 1.0 or box.y < 1.0:
		box = Vector2(186, 72)
	mark.size = box
	mark.pivot_offset = box * 0.5
	mark.position = (card_size - box) * 0.5


func _set_power_amount(amount: float) -> void:
	_power_amount = clampf(amount, 0.0, 1.0)
	if _power_amount <= 0.0:
		_apply_frame(_stroke)
		return
	var t := _power_amount
	_paint_card(
		BODY_COLOR.lerp(POWER_BODY, t),
		_stroke.lerp(ENHANCED_COLOR, t),
		_header_fill(_stroke).lerp(POWER_HEADER, t),
		FOOTER_COLOR.lerp(POWER_FOOTER, t)
	)


func _apply_frame(stroke: Color) -> void:
	_paint_card(BODY_COLOR, stroke, _header_fill(stroke), FOOTER_COLOR)


func _paint_card(body: Color, stroke: Color, header_fill: Color, footer_fill: Color) -> void:
	if _frame_style == null or _header_style == null or _footer_style == null:
		return
	_frame_style.bg_color = body
	_frame_style.border_color = stroke
	_header_style.bg_color = header_fill
	_footer_style.bg_color = footer_fill


func _header_fill(stroke: Color) -> Color:
	var fill := stroke
	var guard := 0
	while fill.get_luminance() > 0.42 and guard < 6:
		fill = fill.darkened(0.18)
		guard += 1
	return fill
