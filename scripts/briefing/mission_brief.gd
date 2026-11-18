extends Control

## Pick a mission on the map. The view opens north of the missions, with no reticule until one is chosen.
## The briefing art shows that mission's tiles, cropped to the frame. No mechs and no weather.

@onready var window: PanelContainer = %Window
@onready var briefing_title: Label = %BriefingTitle
@onready var start_button: Button = %StartButton
@onready var back_button: TextureButton = %BackButton
@onready var tutorial: BaseButton = %Tutorial
@onready var mission_1: BaseButton = %Mission1
@onready var mission_2: BaseButton = %Mission2
@onready var mission_3: BaseButton = %Mission3
@onready var locked: PanelContainer = %Locked
@onready var locked_title: Label = %LockedTitle
@onready var win_block: VBoxContainer = %Win
@onready var lose_block: VBoxContainer = %Lose
@onready var tutorial_brief: Label = %TutorialBrief
@onready var clip: Control = $Margin/Root/MapPanel/Inset/Clip
@onready var map: TextureRect = $Margin/Root/MapPanel/Inset/Clip/Map
@onready var crosshair: Control = $Margin/Root/MapPanel/Inset/Clip/Crosshair
@onready var art_clip: Control = %ArtClip
@onready var _stage_view: SubViewportContainer = %StageView
@onready var _stage_camera: Camera2D = %StageCamera
@onready var _stage_host: Node2D = %StageHost

## Center of the photo. Matches the crosshair placed in the scene.
const FOCUS_MISSION_1 := Vector2(0.5, 0.5)
const ZOOM_MISSION_1 := 1.0
## Span southwest of Mission 1, where the bridge crosses the river.
const FOCUS_MISSION_2 := Vector2(0.363, 0.604)
## A little larger than the frame so the photo can slide southwest and still cover it.
const ZOOM_MISSION_2 := 1.05
## East bank of the river, south of the tutorial pin and east of the bridge.
const FOCUS_MISSION_3 := Vector2(0.62, 0.48)
const ZOOM_MISSION_3 := 1.05
## Northeast of the other missions, over the upper east side of the island.
const FOCUS_TUTORIAL := Vector2(0.55, 0.32)
## A little larger than the frame so the photo can slide northeast and still cover it.
const ZOOM_TUTORIAL := 1.05
## Top of the photo, over the upper river. No mission sits here.
const FOCUS_OPENING := Vector2(0.5, 0.0)
const ZOOM_OPENING := 1.0
## Share of the trip the reticule takes. The map pans the rest, until the photo hits the frame.
const RETICULE_SHARE := 0.65
const FOCUS_TIME := 0.5

var _chosen_stage := GameManager.STAGE_0_0
var _focus := FOCUS_OPENING
var _zoom := ZOOM_OPENING
## Zero until a mission is chosen, so the opening pan sits on its focus instead of a hidden reticule.
var _reticule_share := 0.0
var _show_cursor := false

var _leaving := false
var _briefing_open := false
var _window_tween: Tween
var _button_tween: Tween
var _locked_tween: Tween
var _focus_tween: Tween


func _ready() -> void:
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for button in [tutorial, mission_1, mission_2, mission_3]:
		button.button_group = group
	back_button.pressed.connect(_on_back_pressed)
	tutorial.pressed.connect(_on_mission_pressed.bind(tutorial, GameManager.STAGE_TUTORIAL))
	mission_1.pressed.connect(_on_mission_pressed.bind(mission_1, GameManager.STAGE_0_0))
	mission_2.pressed.connect(_on_mission_pressed.bind(mission_2, GameManager.STAGE_0_1))
	mission_3.pressed.connect(_on_mission_pressed.bind(mission_3, GameManager.STAGE_0_2))
	start_button.pressed.connect(_on_start_pressed)
	window.resized.connect(_center_window_pivot)
	locked.resized.connect(_center_locked_pivot)
	_center_window_pivot()
	_center_locked_pivot()
	_prepare_map()
	clip.resized.connect(_on_clip_resized)
	art_clip.resized.connect(_fit_stage)
	_hide_briefing()
	_hide_locked()
	tutorial.visible = true
	crosshair.visible = false
	_move_map(FOCUS_OPENING, ZOOM_OPENING, false)


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
	GameManager.go_to_hangar()


func _on_mission_pressed(button: BaseButton, stage_path: String) -> void:
	if _leaving:
		return
	_hide_locked()
	_chosen_stage = stage_path
	briefing_title.text = button.text
	_show_conditions(stage_path)
	_focus_mission(stage_path)
	_show_stage_map(stage_path)
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
	if _chosen_stage == GameManager.STAGE_TUTORIAL:
		GameManager.deploy_tutorial()
		return
	GameManager.choose_stage(_chosen_stage)
	GameManager.play_story(GameManager.story_for_stage(_chosen_stage))


func _leave() -> void:
	_leaving = true
	start_button.disabled = true
	back_button.disabled = true
	tutorial.disabled = true
	mission_1.disabled = true
	mission_2.disabled = true
	mission_3.disabled = true


func _show_conditions(stage_path: String) -> void:
	var teaching := stage_path == GameManager.STAGE_TUTORIAL
	win_block.visible = not teaching
	lose_block.visible = not teaching
	tutorial_brief.visible = teaching


func _focus_mission(stage_path: String) -> void:
	var reveal := not _show_cursor
	_show_cursor = true
	_reticule_share = RETICULE_SHARE
	var focus := FOCUS_MISSION_1
	var zoom := ZOOM_MISSION_1
	if stage_path == GameManager.STAGE_TUTORIAL:
		focus = FOCUS_TUTORIAL
		zoom = ZOOM_TUTORIAL
	elif stage_path == GameManager.STAGE_0_1:
		focus = FOCUS_MISSION_2
		zoom = ZOOM_MISSION_2
	elif stage_path == GameManager.STAGE_0_2:
		focus = FOCUS_MISSION_3
		zoom = ZOOM_MISSION_3
	_move_map(focus, zoom, true, reveal)


## The stage's tiles fill the briefing art. Weather and the placed mechs stay out.
func _show_stage_map(stage_path: String) -> void:
	var packed := load(stage_path) as PackedScene
	if packed == null:
		return
	var stage := packed.instantiate() as Node2D
	if stage == null:
		return
	strip_map_preview(stage)
	var bounds := tile_bounds(stage)
	if bounds.size.x < 1.0 or bounds.size.y < 1.0:
		stage.free()
		return
	_clear_stage_host()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	_stage_host.add_child(stage)
	_stage_view.visible = true
	_fit_stage()


func _clear_stage_host() -> void:
	var stale: Array[Node] = []
	for child in _stage_host.get_children():
		stale.append(child)
	for child in stale:
		_stage_host.remove_child(child)
		child.free()


func _fit_stage() -> void:
	if _stage_host.get_child_count() == 0:
		return
	var view := art_clip.size
	if view.x < 2.0 or view.y < 2.0:
		return
	var stage := _stage_host.get_child(0) as Node2D
	var frame := cover_frame(view, tile_bounds(stage))
	_stage_camera.position = frame.center
	_stage_camera.zoom = Vector2(frame.zoom, frame.zoom)
	_stage_camera.make_current()


## Drops weather and every placed mech. Tile layers, shadows, and lights stay.
static func strip_map_preview(stage: Node) -> void:
	if stage == null:
		return
	var drop: Array[Node] = []
	_collect_preview_drop(stage, drop)
	for node in drop:
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()


static func _collect_preview_drop(node: Node, drop: Array[Node]) -> void:
	for child in node.get_children():
		if _drops_from_preview(child):
			drop.append(child)
		else:
			_collect_preview_drop(child, drop)


static func _drops_from_preview(node: Node) -> bool:
	if node.name == StageMap.WEATHER_NODE:
		return true
	return node is Marker2D


## Tile layers in the stage's parent space, so a sibling camera can frame them.
static func tile_bounds(stage: Node2D) -> Rect2:
	var bounds := Rect2()
	if stage == null:
		return bounds
	var found := false
	var layers: Array[TileMapLayer] = []
	_collect_tile_layers(stage, layers)
	for layer in layers:
		if layer.tile_set == null or not (layer as CanvasItem).visible:
			continue
		var used := layer.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var tile := Vector2(layer.tile_set.tile_size)
		var rect := Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)
		var to_stage := _layer_transform(layer, stage)
		var corners: Array[Vector2] = [
			to_stage * rect.position,
			to_stage * Vector2(rect.end.x, rect.position.y),
			to_stage * rect.end,
			to_stage * Vector2(rect.position.x, rect.end.y),
		]
		for corner in corners:
			var point: Vector2 = stage.transform * corner
			if not found:
				bounds = Rect2(point, Vector2.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	return bounds


static func _collect_tile_layers(node: Node, into: Array[TileMapLayer]) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			into.append(child)
		_collect_tile_layers(child, into)


static func _layer_transform(layer: Node2D, stage: Node2D) -> Transform2D:
	var xform := Transform2D.IDENTITY
	var node: Node = layer
	while node is Node2D and node != stage:
		xform = (node as Node2D).transform * xform
		node = node.get_parent()
	return xform


## Zoom that fills the view and crops the extra. The camera sits on the center.
static func cover_frame(view: Vector2, bounds: Rect2) -> Dictionary:
	var zoom := 1.0
	if bounds.size.x >= 1.0 and bounds.size.y >= 1.0 and view.x >= 1.0 and view.y >= 1.0:
		zoom = maxf(view.x / bounds.size.x, view.y / bounds.size.y)
	return {
		"center": bounds.get_center(),
		"zoom": zoom,
	}


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


func _move_map(focus: Vector2, zoom: float, animate: bool, reveal_cursor: bool = false) -> void:
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
	# The first pick drops the reticule on the mission. The map travels to meet it.
	var start := {
		"pos": map.position,
		"size": map.size,
		"cross": end.cross if reveal_cursor else crosshair.position,
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
	var cross_center := view * 0.5 + toward * _reticule_share
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
	crosshair.visible = _show_cursor


func _blend_frame(t: float, start: Dictionary, end: Dictionary) -> void:
	_apply_frame({
		"pos": (start.pos as Vector2).lerp(end.pos, t),
		"size": (start.size as Vector2).lerp(end.size, t),
		"cross": (start.cross as Vector2).lerp(end.cross, t),
	})


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
