extends Control

## Pick a mission on the map. The reticule and map ease to that mission.

@onready var window: PanelContainer = %Window
@onready var briefing_title: Label = %BriefingTitle
@onready var start_button: Button = %StartButton
@onready var back_button: TextureButton = %BackButton
@onready var tutorial: BaseButton = %Tutorial
@onready var mission_1: BaseButton = %Mission1
@onready var mission_2: BaseButton = %Mission2
@onready var locked: PanelContainer = %Locked
@onready var locked_title: Label = %LockedTitle
@onready var clip: Control = $Margin/Root/MapPanel/Inset/Clip
@onready var map: TextureRect = $Margin/Root/MapPanel/Inset/Clip/Map
@onready var crosshair: Control = $Margin/Root/MapPanel/Inset/Clip/Crosshair

## Center of the photo. Matches the crosshair placed in the scene.
const FOCUS_MISSION_1 := Vector2(0.5, 0.5)
const ZOOM_MISSION_1 := 1.0
## Span southwest of Mission 1, where the bridge crosses the river.
const FOCUS_MISSION_2 := Vector2(0.363, 0.604)
## A little larger than the frame so the photo can slide southwest and still cover it.
const ZOOM_MISSION_2 := 1.05
## Share of the trip the reticule takes. The map pans the rest, until the photo hits the frame.
const RETICULE_SHARE := 0.65
const FOCUS_TIME := 0.5

var _chosen_stage := GameManager.STAGE_0_0
var _focus := FOCUS_MISSION_1
var _zoom := ZOOM_MISSION_1

var _leaving := false
var _briefing_open := false
var _window_tween: Tween
var _button_tween: Tween
var _locked_tween: Tween
var _focus_tween: Tween


func _ready() -> void:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for button in [tutorial, mission_1, mission_2]:
		button.button_group = group
	back_button.pressed.connect(_on_back_pressed)
	tutorial.pressed.connect(_on_locked_pressed.bind(tutorial))
	mission_1.pressed.connect(_on_mission_pressed.bind(mission_1, GameManager.STAGE_0_0))
	mission_2.pressed.connect(_on_mission_pressed.bind(mission_2, GameManager.STAGE_0_1))
	start_button.pressed.connect(_on_start_pressed)
	window.resized.connect(_center_window_pivot)
	locked.resized.connect(_center_locked_pivot)
	_center_window_pivot()
	_center_locked_pivot()
	_prepare_map()
	clip.resized.connect(_on_clip_resized)
	_hide_briefing()
	_hide_locked()
	# Hidden until the tutorial mission is ready.
	tutorial.visible = false
	_move_map(FOCUS_MISSION_1, ZOOM_MISSION_1, false)


func _hide_briefing() -> void:
	_kill(_window_tween)
	_kill(_button_tween)
	_briefing_open = false
	window.scale = Vector2.ONE
	window.modulate.a = 0.0
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.modulate.a = 0.0
	start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.disabled = true


func _hide_locked() -> void:
	_kill(_locked_tween)
	locked.visible = false
	locked.scale = Vector2.ONE
	locked.modulate.a = 0.0
	locked.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _center_window_pivot() -> void:
	window.pivot_offset = window.size * 0.5


func _center_locked_pivot() -> void:
	locked.pivot_offset = locked.size * 0.5


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.go_to_command()


func _on_mission_pressed(button: BaseButton, stage_path: String) -> void:
	if _leaving:
		return
	_hide_locked()
	_chosen_stage = stage_path
	briefing_title.text = button.text
	_focus_mission(stage_path)
	if _briefing_open:
		return
	_briefing_open = true
	_pop_window()


func _on_locked_pressed(button: BaseButton) -> void:
	if _leaving:
		return
	_hide_briefing()
	locked_title.text = button.text
	if locked.visible:
		return
	_pop_locked()


func _pop_window() -> void:
	if _leaving:
		return
	_center_window_pivot()
	window.scale = Vector2(0.82, 0.82)
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	start_button.mouse_filter = Control.MOUSE_FILTER_STOP
	start_button.disabled = false
	_kill(_window_tween)
	_window_tween = create_tween()
	_window_tween.set_parallel(true)
	var grow := _window_tween.tween_property(window, "scale", Vector2.ONE, 0.32)
	grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := _window_tween.tween_property(window, "modulate:a", 1.0, 0.16)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kill(_button_tween)
	_button_tween = create_tween()
	_button_tween.tween_interval(0.12)
	_button_tween.tween_property(start_button, "modulate:a", 1.0, 0.18)


func _pop_locked() -> void:
	if _leaving:
		return
	_center_locked_pivot()
	locked.visible = true
	locked.scale = Vector2(0.82, 0.82)
	locked.modulate.a = 0.0
	locked.mouse_filter = Control.MOUSE_FILTER_STOP
	_kill(_locked_tween)
	_locked_tween = create_tween()
	_locked_tween.set_parallel(true)
	var grow := _locked_tween.tween_property(locked, "scale", Vector2.ONE, 0.32)
	grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := _locked_tween.tween_property(locked, "modulate:a", 1.0, 0.16)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.choose_stage(_chosen_stage)
	GameManager.play_story(GameManager.story_for_stage(_chosen_stage))


func _leave() -> void:
	_leaving = true
	start_button.disabled = true
	back_button.disabled = true
	tutorial.disabled = true
	mission_1.disabled = true
	mission_2.disabled = true


func _focus_mission(stage_path: String) -> void:
	if stage_path == GameManager.STAGE_0_1:
		_move_map(FOCUS_MISSION_2, ZOOM_MISSION_2, true)
	else:
		_move_map(FOCUS_MISSION_1, ZOOM_MISSION_1, true)


func _prepare_map() -> void:
	var cross_size := crosshair.size
	if cross_size.x < 2.0:
		cross_size = crosshair.custom_minimum_size
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	crosshair.set_anchors_preset(Control.PRESET_TOP_LEFT)
	crosshair.size = cross_size
	map.stretch_mode = TextureRect.STRETCH_SCALE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


func _on_clip_resized() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		return
	_move_map(_focus, _zoom, false)


func _move_map(focus: Vector2, zoom: float, animate: bool) -> void:
	var unchanged := focus.is_equal_approx(_focus) and is_equal_approx(zoom, _zoom)
	var tweening := _focus_tween != null and _focus_tween.is_valid()
	_focus = focus
	_zoom = zoom
	if clip.size.x < 2.0 or map.texture == null:
		return
	var end := _frame(focus, zoom)
	if not animate or (unchanged and not tweening):
		_kill(_focus_tween)
		_apply_frame(end)
		return
	if unchanged:
		return
	var start := {
		"pos": map.position,
		"size": map.size,
		"cross": crosshair.position,
	}
	_kill(_focus_tween)
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_method(_blend_frame.bind(start, end), 0.0, 1.0, FOCUS_TIME)


func _frame(focus: Vector2, zoom: float) -> Dictionary:
	var view := clip.size
	var tex := map.texture.get_size()
	var cover := maxf(view.x / tex.x, view.y / tex.y) * zoom
	var drawn := tex * cover
	var rest := (view - drawn) * 0.5 + focus * drawn
	var toward := rest - view * 0.5
	var cross_center := view * 0.5 + toward * RETICULE_SHARE
	var map_pos := cross_center - focus * drawn
	map_pos.x = _clamp_pan(map_pos.x, view.x, drawn.x)
	map_pos.y = _clamp_pan(map_pos.y, view.y, drawn.y)
	var focus_screen := map_pos + focus * drawn
	return {
		"pos": map_pos,
		"size": drawn,
		"cross": focus_screen - crosshair.size * 0.5,
	}


func _clamp_pan(pos: float, view: float, drawn: float) -> float:
	if drawn >= view:
		return clampf(pos, view - drawn, 0.0)
	return (view - drawn) * 0.5


func _apply_frame(frame: Dictionary) -> void:
	map.position = frame.pos
	map.size = frame.size
	crosshair.position = frame.cross


func _blend_frame(t: float, start: Dictionary, end: Dictionary) -> void:
	_apply_frame({
		"pos": (start.pos as Vector2).lerp(end.pos, t),
		"size": (start.size as Vector2).lerp(end.size, t),
		"cross": (start.cross as Vector2).lerp(end.cross, t),
	})


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
