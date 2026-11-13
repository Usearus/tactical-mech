class_name TutorialCoach
extends CanvasLayer

## Presses outside the outlined control are eaten.

signal continued

const COMMS_PORTRAIT := preload("res://art/characters/npc/comms.png")

@onready var shade: Control = %Shade
@onready var dim_top: ColorRect = %DimTop
@onready var dim_bottom: ColorRect = %DimBottom
@onready var dim_left: ColorRect = %DimLeft
@onready var dim_right: ColorRect = %DimRight
@onready var outline: Panel = %Outline
@onready var callout: PanelContainer = %Callout
@onready var body: RichTextLabel = %Body
@onready var portrait: TextureRect = %Portrait
@onready var continue_button: SciFlashingButton = %Continue

const TIP_WIDTH := 220.0
const EXPLAINER_WIDTH := 340.0
const HOLE_MARGIN := 8.0

var _target: Control
var _aimed: Array[Control] = []
var _centered := false
var _span := false
var _above := false
var _bottom := false
var _top := false
var _gesture := false
var _pulse: Tween


func _ready() -> void:
	visible = false
	if portrait != null and portrait.texture == null:
		portrait.texture = COMMS_PORTRAIT
	continue_button.pressed.connect(func() -> void:
		continued.emit()
	)


func _process(_delta: float) -> void:
	if not visible:
		return
	# Input is delivered last-registered first. Stay at the front so a press is eaten before the battle acts on it.
	_lead_input()
	_sync_aim()
	if _target != null and is_instance_valid(_target):
		_place(_outline_rect())
	elif _centered:
		_place_center()
	else:
		_place_loose()
	_place_dim()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	var menu_open := _menu_open()
	var holes := _lesson_holes()
	var point := button.global_position
	if not pointer_passes(button.pressed, point, holes, menu_open, _gesture):
		get_viewport().set_input_as_handled()
	if menu_open:
		_gesture = false
		return
	if button.pressed:
		_gesture = _in_holes(point, holes)
	else:
		_gesture = false


func _lead_input() -> void:
	set_process_input(false)
	set_process_input(true)


## A press passes when it lands in a hole. A release passes only for a gesture that started in one.
static func pointer_passes(
	pressed: bool,
	point: Vector2,
	holes: Array[Rect2],
	menu_open: bool,
	gesture: bool
) -> bool:
	if menu_open:
		return true
	if not pressed:
		return gesture
	return _in_holes(point, holes)


## Continue steps keep only the Continue button. Do steps keep the outlined control, grown once.
static func lesson_holes(
	show_continue: bool,
	target: Rect2,
	has_target: bool,
	continue_rect: Rect2,
	menu: Rect2
) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	if show_continue:
		if continue_rect.has_area():
			holes.append(continue_rect)
	elif has_target and target.has_area():
		holes.append(target.grow(HOLE_MARGIN))
	if menu.has_area():
		holes.append(menu)
	return holes


## A spanning step draws one frame around every listed contact.
static func span_bounds(primary: Rect2, extras: Array[Rect2]) -> Rect2:
	var rect := primary
	for extra in extras:
		if not extra.has_area():
			continue
		rect = extra if not rect.has_area() else rect.merge(extra)
	return rect


## Aim steps treat the mech sprite as part of the tile. Other steps stay on the button.
static func aim_bounds(button: Rect2, sprite: Rect2, aiming: bool) -> Rect2:
	if not aiming or not sprite.has_area():
		return button
	return button.merge(sprite)


func show_step(text: String, target: Control, show_continue: bool, _open_view: bool, span := false, above := false, bottom := false, top := false, front := false) -> void:
	visible = true
	_gesture = false
	_span = span
	_above = above
	_bottom = bottom
	_top = top
	layer = 92 if front else 40
	body.text = text
	continue_button.visible = show_continue
	if show_continue:
		continue_button.start_pulse()
	else:
		continue_button.stop_pulse()
	callout.visible = true
	var aimed := target != null and is_instance_valid(target)
	_target = target if aimed else null
	_centered = show_continue and not aimed
	body.custom_minimum_size.x = EXPLAINER_WIDTH if show_continue else TIP_WIDTH
	outline.visible = aimed
	_sync_aim()
	if aimed:
		_place(_outline_rect())
		_start_pulse()
	elif _centered:
		_stop_pulse()
		_place_center()
	else:
		_stop_pulse()
		_place_loose()
	_place_dim()


func hide_tip() -> void:
	visible = false
	_gesture = false
	_span = false
	_above = false
	_bottom = false
	_top = false
	layer = 40
	_target = null
	_centered = false
	_sync_aim()
	outline.visible = false
	callout.visible = false
	if continue_button != null:
		continue_button.stop_pulse()
	_hide_dim()
	_stop_pulse()


func _outline_rect() -> Rect2:
	var primary := _target_bounds().grow(HOLE_MARGIN)
	if not _span:
		return primary
	var extras: Array[Rect2] = []
	for control in _company():
		var bounds := _control_bounds(control).grow(HOLE_MARGIN)
		if bounds.has_area():
			extras.append(bounds)
	return span_bounds(primary, extras)


func _target_bounds() -> Rect2:
	return aim_bounds(
		_drawn_rect(_target),
		_sprite_rect(_target),
		bool(_target.get_meta("tutorial_aim", false))
	)


func _lesson_holes() -> Array[Rect2]:
	var has_target := _target != null and is_instance_valid(_target)
	var target := _target_bounds() if has_target else Rect2()
	var cont := continue_button.get_global_rect() if continue_button.visible else Rect2()
	var holes := lesson_holes(continue_button.visible, target, has_target, cont, _menu_rect())
	for control in _company():
		var bounds := _control_bounds(control)
		if bounds.has_area():
			holes.append(bounds.grow(HOLE_MARGIN))
	return holes


func _cutout() -> Rect2:
	if continue_button.visible or _target == null or not is_instance_valid(_target):
		return Rect2()
	var global := _outline_rect()
	for control in _company():
		var bounds := _control_bounds(control).grow(HOLE_MARGIN)
		if bounds.has_area():
			global = global.merge(bounds) if global.has_area() else bounds
	return _to_local(global)


func _control_bounds(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	var aiming := control.get_node_or_null("MechSprite") != null
	return aim_bounds(_drawn_rect(control), _sprite_rect(control), aiming)


## Art that hangs outside its control, such as a mech badge, still belongs to the highlight.
func _drawn_rect(control: Control) -> Rect2:
	if control != null and control.has_method("visual_rect"):
		var painted: Rect2 = control.call("visual_rect")
		if painted.has_area():
			return painted
	return control.get_global_rect()


## Every contact listed on the outlined cell. Open aim steps set this so any red-tile enemy accepts the click.
func _company() -> Array[Control]:
	var found: Array[Control] = []
	if _target == null or not is_instance_valid(_target) or not _target.has_meta("tutorial_company"):
		return found
	var listed: Variant = _target.get_meta("tutorial_company")
	if listed is Array:
		for entry in listed:
			var control := entry as Control
			if control != null and is_instance_valid(control):
				found.append(control)
	return found


## The outlined mech's art belongs to its tile for this step. Open aim steps include the other contacts.
func _sync_aim() -> void:
	var want: Array[Control] = []
	if visible and not continue_button.visible:
		for control in _aim_controls():
			if control.get_node_or_null("MechSprite") != null:
				want.append(control)
	for old in _aimed:
		if is_instance_valid(old) and not want.has(old):
			old.set_meta("tutorial_aim", false)
	_aimed = want
	for control in want:
		control.set_meta("tutorial_aim", true)


func _aim_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _target != null and is_instance_valid(_target):
		controls.append(_target)
	for control in _company():
		if not controls.has(control):
			controls.append(control)
	return controls


func _menu_open() -> bool:
	return is_instance_valid(GameMenu) and GameMenu.is_open()


func _menu_rect() -> Rect2:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return Rect2()
	for node in tree.root.find_children("MenuCorner", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.has_area():
			return rect
	return Rect2()


## The same local box BattleCellButton uses when tutorial_aim is set, in viewport space.
func _sprite_rect(control: Control) -> Rect2:
	var sprite := control.get_node_or_null("MechSprite") as AnimatedSprite2D
	if sprite == null or not sprite.visible or sprite.sprite_frames == null:
		return Rect2()
	var anim_name := String(sprite.animation)
	if anim_name == "" or not sprite.sprite_frames.has_animation(anim_name):
		anim_name = "idle"
	if not sprite.sprite_frames.has_animation(anim_name):
		return Rect2()
	var frame_count := sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		return Rect2()
	var frame := mini(sprite.frame, frame_count - 1)
	var tex := sprite.sprite_frames.get_frame_texture(anim_name, frame)
	if tex == null:
		return Rect2()
	var drawn := tex.get_size() * sprite.scale.abs()
	if drawn.x <= 0.0 or drawn.y <= 0.0:
		return Rect2()
	var center := sprite.position + sprite.offset * sprite.scale
	var local := Rect2(center - drawn * 0.5, drawn)
	var xform := control.get_global_transform()
	var origin: Vector2 = xform * local.position
	var corner: Vector2 = xform * (local.position + local.size)
	return Rect2(origin, corner - origin)


func _place_dim() -> void:
	if dim_top == null:
		return
	if _menu_open():
		_hide_dim()
		return
	var view := shade.size
	var hole := _cutout()
	if not hole.has_area():
		_fill(dim_top, Rect2(Vector2.ZERO, view))
		_fill(dim_bottom, Rect2())
		_fill(dim_left, Rect2())
		_fill(dim_right, Rect2())
		return
	_fill(dim_top, Rect2(0.0, 0.0, view.x, maxf(hole.position.y, 0.0)))
	_fill(dim_bottom, Rect2(0.0, hole.end.y, view.x, maxf(view.y - hole.end.y, 0.0)))
	_fill(dim_left, Rect2(0.0, hole.position.y, maxf(hole.position.x, 0.0), maxf(hole.size.y, 0.0)))
	_fill(dim_right, Rect2(hole.end.x, hole.position.y, maxf(view.x - hole.end.x, 0.0), maxf(hole.size.y, 0.0)))


func _fill(panel: ColorRect, rect: Rect2) -> void:
	panel.position = rect.position
	panel.size = rect.size
	panel.visible = rect.has_area()


func _hide_dim() -> void:
	if dim_top == null:
		return
	dim_top.visible = false
	dim_bottom.visible = false
	dim_left.visible = false
	dim_right.visible = false


func _place(hole: Rect2) -> void:
	var rect := _to_local(hole)
	outline.position = rect.position
	outline.size = rect.size
	_place_callout(rect, shade.size)


func _to_local(global_rect: Rect2) -> Rect2:
	var xform := shade.get_global_transform().affine_inverse()
	var origin: Vector2 = xform * global_rect.position
	var corner: Vector2 = xform * global_rect.end
	return Rect2(origin, corner - origin)


func _place_loose() -> void:
	var box := _callout_size()
	var view := shade.size
	var x := (view.x - box.x) * 0.5
	var y := view.y * 0.22
	callout.position = Vector2(clampf(x, 12.0, maxf(view.x - box.x - 12.0, 12.0)), clampf(y, 12.0, maxf(view.y - box.y - 12.0, 12.0)))
	callout.size = box


func _place_center() -> void:
	var box := _callout_size()
	callout.position = center_spot(box, shade.size, _bottom, _top)
	callout.size = box


## A continue step with no highlight sits in the middle, along the top, or along the bottom.
static func center_spot(box: Vector2, view: Vector2, bottom: bool, top := false) -> Vector2:
	var x := (view.x - box.x) * 0.5
	var y := (view.y - box.y) * 0.5
	if top:
		y = 12.0
	elif bottom:
		y = view.y - box.y - 12.0
	return Vector2(clampf(x, 12.0, maxf(view.x - box.x - 12.0, 12.0)), clampf(y, 12.0, maxf(view.y - box.y - 12.0, 12.0)))


func _callout_size() -> Vector2:
	var box := callout.get_combined_minimum_size()
	if box.x < 8.0:
		box = callout.size
	return box


func _place_callout(hole: Rect2, view: Vector2) -> void:
	var box := _callout_size()
	callout.position = callout_spot(hole, box, view, _above)
	callout.size = box


## The callout sits beside the highlight, or centered above it when a step asks for that.
static func callout_spot(hole: Rect2, box: Vector2, view: Vector2, above: bool) -> Vector2:
	var x: float
	var y: float
	if above:
		x = hole.get_center().x - box.x * 0.5
		y = hole.position.y - box.y - 12.0
		if y < 12.0:
			y = hole.end.y + 12.0
	else:
		x = hole.end.x + 12.0
		if x + box.x > view.x - 12.0:
			x = hole.position.x - box.x - 12.0
		y = hole.position.y
	x = clampf(x, 12.0, maxf(view.x - box.x - 12.0, 12.0))
	y = clampf(y, 12.0, maxf(view.y - box.y - 12.0, 12.0))
	return Vector2(x, y)


func _start_pulse() -> void:
	_stop_pulse()
	outline.modulate.a = 1.0
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(outline, "modulate:a", 0.35, 0.55)
	_pulse.tween_property(outline, "modulate:a", 1.0, 0.55)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	if outline != null:
		outline.modulate.a = 1.0


static func _in_holes(point: Vector2, holes: Array[Rect2]) -> bool:
	for hole in holes:
		if hole.has_point(point):
			return true
	return false
