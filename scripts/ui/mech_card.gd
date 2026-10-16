class_name MechCard
extends PanelContainer

const UI_THEME := preload("res://themes/sci_fi_ui_theme.tres")
## Each mech art uses the nearest named color on the theme Palette.
const STROKE_SWATCH := {
	"red": &"RedDark",
	"tan": &"GoldLight",
	"orange": &"RedLight",
	"purple": &"PurpleLight",
	"white": &"GrayLight",
	"cyan": &"BlueLight",
	"grunt_rifle": &"Red",
	"grunt_dog": &"RedDark",
	"grunt_slasher": &"BrownDark",
	"grunt_flyer": &"PurpleLight",
	"boss_green": &"OliveDark",
}

const BODY_COLOR := Color(0.14, 0.15, 0.19)
const FOOTER_COLOR := Color(0.09, 0.1, 0.13)
const POWER_BODY := Color(0.1, 0.3, 0.56)
const POWER_HEADER := Color(0.16, 0.46, 0.84)
const POWER_FOOTER := Color(0.07, 0.2, 0.4)
const ATTACK_ICON: Texture2D = preload("res://art/icons/stats/attack.svg")
const RANGE_ICON: Texture2D = preload("res://art/icons/stats/range.svg")
const MOVE_ICON: Texture2D = preload("res://art/icons/stats/move.svg")
const DODGE_ICON: Texture2D = preload("res://art/icons/stats/dodge.svg")
const DEFEND_ICON: Texture2D = preload("res://art/icons/stats/defend.svg")
const BARRIER_ICON: Texture2D = preload("res://art/icons/stats/crescent.svg")
const CHARGE_ICON: Texture2D = preload("res://icodot-svg/ui/weather-nature/icon-lightning-ui.svg")
const CHARGE_SHADER: Shader = preload("res://shaders/icon_white.gdshader")
const ENHANCED_COLOR := Color(0.45, 0.78, 1.0)
const CHIP_SCENE := preload("res://scenes/ui/stat_chip.tscn")
const INFO_BADGE := preload("res://scenes/ui/info_badge.tscn")
const OWNER_BADGE := preload("res://scenes/ui/hand_owner_badge.tscn")
const SPECIAL_NOTE := "Special card: Can only be used when in overdrive mode."
const ACTION_COST_NOTE := "Cost: Card costs %d action to use."

signal pulled
signal undo_dragged

const PULL_DISTANCE := 72.0
const HOVER_LIFT := -56.0
const ENEMY_DIM_ALPHA := 0.4
const ENEMY_DIM_TIME := 0.28
## How far a lifted card must be dragged down before the step is undone.
const UNDO_DROP := 36.0
## A press that barely moves is a tap: lift the card, or put an active card back.
const TAP_SLOP := 18.0
const DISCARD_PREVIEW_SCALE := 0.85
const DEAL_TIME := 0.3
const DEAL_STAGGER := 0.05
const DEAL_SCALE := 0.22

var _pull_enabled := false
var _undo_drag := false
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
var _frame_style: StyleBoxTexture
var _frame_tint: ShaderMaterial
var _wave_tween: Tween
var _wave_token := 0
var _shine_tween: Tween
var _shine_token := 0
var _enemy_dimmed := false
var _dim_tween: Tween
var _owner_badge: HandOwnerBadge
var _badge_slot: Control
var _badge_art := ""
var _badge_rim := Color.WHITE

@onready var _gauge_tag: Control = $Clip/GaugeTag
@onready var _wave_host: Control = $Clip/OverdriveWave
@onready var _wave_band: TextureRect = $Clip/OverdriveWave/Band
@onready var _power_mark: Control = $Clip/OverdriveWave/PowerMark
@onready var _shine_host: Control = $Clip/Shine
@onready var _shine_band: TextureRect = $Clip/Shine/Glint
@onready var _shine_flash: ColorRect = $Clip/Shine/Flash
@onready var _enemy_dim: ColorRect = $Clip/EnemyDim/Shade
@onready var header: MarginContainer = %Header
@onready var footer: MarginContainer = %Footer
@onready var title_label: Label = %CardTitle
@onready var strength_label: Label = %Strength
@onready var detail_label: Label = %Detail
@onready var stat_row: HBoxContainer = %Stats
@onready var _plate: NinePatchRect = %Plate
@onready var _action_cost: Label = %ActionCost/Amount


func _ready() -> void:
	_frame_style = _claim_frame(self)
	if _plate == null:
		return
	if _frame_style != null:
		_plate.texture = _frame_style.texture
		_plate.patch_margin_left = int(_frame_style.texture_margin_left)
		_plate.patch_margin_top = int(_frame_style.texture_margin_top)
		_plate.patch_margin_right = int(_frame_style.texture_margin_right)
		_plate.patch_margin_bottom = int(_frame_style.texture_margin_bottom)
	var shared := _plate.material as ShaderMaterial
	if shared != null:
		_frame_tint = shared.duplicate() as ShaderMaterial
		_plate.material = _frame_tint


func _claim_frame(panel: PanelContainer) -> StyleBoxTexture:
	var box := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if box == null:
		return null
	var copy := box.duplicate() as StyleBoxTexture
	panel.add_theme_stylebox_override("panel", copy)
	return copy


static func stroke_for(mech: MechData) -> Color:
	if mech != null and STROKE_SWATCH.has(mech.art_id):
		return _swatch(STROKE_SWATCH[mech.art_id])
	return _swatch(&"Gray")


static func _swatch(color_name: StringName) -> Color:
	return UI_THEME.get_color(color_name, &"Palette")


func has_attack() -> bool:
	if _shown == null:
		return false
	return _shown.card_type == "Attack"


## Two blue sweeps up the card. The card stays blue, with the attack and guard marks side by side, until the wash ends.
func play_overdrive_wave() -> void:
	if not has_attack():
		return
	var host := _wave_host
	_raise_node(host)
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
		header.custom_minimum_size = Vector2(0, 40)
	var detail := get_node_or_null("%Detail") as Label
	if detail != null:
		detail.custom_minimum_size = Vector2(0, 100)
		detail.max_lines_visible = 5
	var card_footer := get_node_or_null("%Footer") as PanelContainer
	if card_footer != null:
		card_footer.custom_minimum_size = Vector2(0, 40)


## Speech cloud on the first card of a mech. An empty art id takes it off.
func set_owner_badge(art_id: String, rim: Color, slot: Control = null) -> void:
	if art_id == "":
		clear_owner_badge()
		return
	_badge_art = art_id
	_badge_rim = rim
	if slot != null:
		_badge_slot = slot
	if _owner_badge == null or not is_instance_valid(_owner_badge):
		_owner_badge = OWNER_BADGE.instantiate() as HandOwnerBadge
	_owner_badge.visible = true
	_mount_owner_badge()


func clear_owner_badge() -> void:
	_badge_art = ""
	if _owner_badge == null or not is_instance_valid(_owner_badge):
		return
	_owner_badge.visible = false
	var parent := _owner_badge.get_parent()
	if parent != null and not parent.is_queued_for_deletion():
		parent.remove_child(_owner_badge)


func _mount_owner_badge() -> void:
	if _owner_badge == null or not is_instance_valid(_owner_badge) or not _owner_badge.visible:
		return
	if _badge_art == "":
		return
	var slot := _badge_slot
	if slot == null or not is_instance_valid(slot):
		var parent := get_parent() as Control
		if parent != null and parent.get_node_or_null("Empty") != null:
			slot = parent
	if slot == null or not is_instance_valid(slot) or slot.is_queued_for_deletion():
		return
	if _owner_badge.get_parent() != slot:
		var current := _owner_badge.get_parent()
		if current != null:
			current.remove_child(_owner_badge)
		slot.add_child(_owner_badge)
	_owner_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_owner_badge.position = Vector2.ZERO
	_owner_badge.rotation = 0.0
	_owner_badge.scale = Vector2(HandOwnerBadge.PIN_SCALE, HandOwnerBadge.PIN_SCALE)
	_owner_badge.z_as_relative = true
	_owner_badge.z_index = HandOwnerBadge.DRAW_Z
	_owner_badge.show_head(_badge_art, _badge_rim)
	_owner_badge.modulate = _badge_tone()


## Free the mark before this card leaves its seat. Never do this from a tree notification.
func _drop_owner_badge() -> void:
	_badge_art = ""
	_badge_slot = null
	var badge := _owner_badge
	_owner_badge = null
	if badge == null or not is_instance_valid(badge):
		return
	badge.visible = false
	var parent := badge.get_parent()
	if parent != null and not parent.is_queued_for_deletion():
		parent.remove_child(badge)
	badge.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		call_deferred("_mount_owner_badge")


func _badge_tone() -> Color:
	return Color(0.62, 0.62, 0.62) if _enemy_dimmed else Color.WHITE


func _apply_badge_tone(immediate: bool) -> void:
	if _owner_badge == null or not is_instance_valid(_owner_badge):
		return
	var tone := _badge_tone()
	if immediate or _dim_tween == null or not _dim_tween.is_valid():
		_owner_badge.modulate = tone
		return
	_dim_tween.tween_property(_owner_badge, "modulate", tone, ENEMY_DIM_TIME)


func present(card: CardData, stroke: Color, damage := -1, block := -1) -> void:
	_shown = card
	_stroke = stroke
	_stat_damage = card.damage if damage < 0 else damage
	_stat_block = card.block if block < 0 else block
	title_label.text = card.display_name
	title_label.add_theme_color_override("font_color", Color.WHITE)
	var badge := special_badge()
	if badge != null:
		badge.modulate = Color.WHITE
	detail_label.text = card.description
	_show_action_cost(card)
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
	badge.modulate = Color.WHITE
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
	if not _gliding and not _pulling and not _undo_drag:
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled and _dragging and not _undo_drag:
		_dragging = false
		settle(false)


func set_undo_drag_enabled(enabled: bool) -> void:
	_undo_drag = enabled
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_ignore_mouse(self)
		return
	if _dragging:
		_dragging = false
		_kill_preview_motion()
	if not _pull_enabled and not _gliding and not _pulling:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


## Black veil while an enemy is acting, or while a played card is resolving.
func set_enemy_dim(enabled: bool, immediate := false) -> void:
	if _enemy_dim == null or enabled == _enemy_dimmed:
		return
	var host := _enemy_dim.get_parent() as CanvasItem
	_enemy_dimmed = enabled
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = null
	var color := _enemy_dim.color
	color.a = ENEMY_DIM_ALPHA if enabled else 0.0
	if immediate:
		_enemy_dim.color = color
		if host != null:
			host.visible = enabled
		_apply_badge_tone(true)
		return
	if host != null:
		host.visible = true
	_dim_tween = create_tween()
	_dim_tween.set_parallel(true)
	_dim_tween.tween_property(_enemy_dim, "color:a", color.a, ENEMY_DIM_TIME)
	_apply_badge_tone(false)
	if not enabled:
		_dim_tween.finished.connect(_hide_enemy_dim, CONNECT_ONE_SHOT)


func _hide_enemy_dim() -> void:
	if _enemy_dimmed or _enemy_dim == null:
		return
	var host := _enemy_dim.get_parent() as CanvasItem
	if host != null:
		host.visible = false


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
	_drop_owner_badge()
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
		z_index = HandOwnerBadge.DRAW_Z + 1 if lifted else 0
		_set_slot_z(1 if lifted else 0)
		return
	_lifted = lifted
	z_index = HandOwnerBadge.DRAW_Z + 1 if lifted else 0
	_tween_to(home, target_scale, 0.0, not lifted)
	_set_slot_z(8 if lifted else 0)


func _gui_input(event: InputEvent) -> void:
	if not _pull_enabled and not _undo_drag:
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
	_kill_preview_motion()
	_discard_preview = false
	_dragging = true
	_start_position = position
	_press_global = global_pos
	z_index = HandOwnerBadge.DRAW_Z + 1
	_set_slot_z(20)


func _follow_drag(global_pos: Vector2) -> void:
	if _undo_drag:
		var next_y := _start_position.y + (global_pos.y - _press_global.y)
		next_y = clampf(next_y, _start_position.y, 8.0)
		position = Vector2(_start_position.x, next_y)
		rotation = 0.0
		return
	var delta := global_pos - _press_global
	position = _start_position + delta
	if not _discard_preview and not _preview_playing():
		scale = _drag_scale()
	rotation = deg_to_rad(clampf(delta.x / 22.0, -8.0, 8.0))
	_notify_drop(global_pos, false)


func _end_drag(global_pos: Vector2) -> void:
	_dragging = false
	var tap := _press_global.distance_to(global_pos) <= TAP_SLOP
	if _undo_drag:
		await _finish_undo_drag(tap)
		return
	if not tap and _notify_drop(global_pos, true):
		return
	if tap:
		_finish_tap()
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


func _finish_tap() -> void:
	z_index = 0
	_discard_preview = false
	_kill_preview_motion()
	if not _pull_enabled:
		settle(_lifted)
		return
	if is_inside_tree():
		pulled.emit()


func _finish_undo_drag(from_tap := false) -> void:
	z_index = 0
	var dropped := position.y - _start_position.y
	if not from_tap and dropped < UNDO_DROP:
		settle(true)
		return
	_undo_drag = false
	_pulling = true
	_tween_to(Vector2(_start_position.x, 0.0), Vector2.ONE, 0.0, false, 0.12)
	if _motion != null:
		await _motion.finished
	_pulling = false
	_lifted = false
	if is_inside_tree():
		undo_dragged.emit()


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


func _show_action_cost(card: CardData) -> void:
	if _action_cost == null:
		return
	var cost := 0 if card == null else maxi(card.action_cost, 0)
	_action_cost.text = str(cost)


func _apply_stats() -> void:
	if _shown == null or strength_label == null:
		return
	var key := "%s|%s|%d|%d|%d|%d|%d|%d|%d|%d" % [
		_shown.card_type,
		_shown.defense_kind,
		_shown.damage,
		_shown.block,
		_shown.barrier,
		_stat_damage,
		_stat_block,
		_shown.reach,
		_shown.movement,
		1 if _shown.intercept else 0,
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
				_add_stat(row, "chg", GameManager.SPARK_CHARGE)
			elif card.barrier > 0:
				_add_stat(row, "bar", card.barrier)
			elif card.is_dodge():
				_add_stat(row, "dodge", 1)
			elif card.block > 0:
				_add_stat(row, "def", _stat_block, _stat_block > card.block)
			if card.movement > 0:
				_add_stat(row, "mov", card.movement)
		"Move":
			_add_stat(row, "mov", card.movement)
	if card.intercept and not card.is_dodge():
		_add_stat(row, "dodge", 1)
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
	var cost_row: Control = null
	if _action_cost != null:
		cost_row = _action_cost.get_parent() as Control
	if cost_row != null:
		var cost := 1 if _shown == null else maxi(_shown.action_cost, 0)
		note.watch(cost_row, ACTION_COST_NOTE % cost)
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
	if kind == "chg":
		var bolt := ShaderMaterial.new()
		bolt.shader = CHARGE_SHADER
		bolt.set_shader_parameter("ink", Color(0.95, 0.96, 0.98))
		icon.material = bolt
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
		"chg":
			return CHARGE_ICON
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
	_mask_shine(host)
	_raise_node(host)
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


func _raise_node(node: Node) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	parent.move_child(node, -1)


func _mask_shine(host: Control) -> void:
	var mask := host as NinePatchRect
	if mask == null or _plate == null:
		return
	mask.texture = _plate.texture
	mask.patch_margin_left = _plate.patch_margin_left
	mask.patch_margin_top = _plate.patch_margin_top
	mask.patch_margin_right = _plate.patch_margin_right
	mask.patch_margin_bottom = _plate.patch_margin_bottom
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY


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
		_stroke.lerp(POWER_HEADER, t),
		FOOTER_COLOR.lerp(POWER_FOOTER, t)
	)


func _apply_frame(stroke: Color) -> void:
	_paint_card(BODY_COLOR, stroke, stroke, FOOTER_COLOR)


func _paint_card(_body: Color, stroke: Color, _header_fill: Color, _footer_fill: Color) -> void:
	if _frame_style != null:
		_frame_style.modulate_color = Color.WHITE
	if _frame_tint == null:
		return
	_frame_tint.set_shader_parameter("tint", Color(stroke.r, stroke.g, stroke.b, 1.0))
