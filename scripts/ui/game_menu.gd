extends CanvasLayer

const TITLE_SCENE := "res://scenes/command/command.tscn"
const BOOT_SCENE := "res://scenes/main/main.tscn"
## Above scene overlays such as the discard tray (layer 60). The screen fade stays at 100.
const POPUP_LAYER := 90

@onready var root: Control = %Root
@onready var scrim: ColorRect = %Scrim
@onready var menu_panel: PanelContainer = %MenuPanel
@onready var detail: PanelContainer = %MenuPage
@onready var howto: PanelContainer = %HowTo
@onready var pages: Control = %Pages
@onready var howto_back: Button = %HowToBack
@onready var howto_next: Button = %HowToNext
@onready var log_tab: Button = %LogTab
@onready var legend_tab: Button = %LegendTab
@onready var log_body: RichTextLabel = %LogBody
@onready var legend: VBoxContainer = %Legend

var _howto_index := 0
var _log: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = POPUP_LAYER
	scrim.visible = false
	menu_panel.visible = false
	detail.visible = false
	howto.visible = false
	scrim.gui_input.connect(_on_scrim_input)
	%MissionLog.pressed.connect(_open_log)
	%LegendButton.pressed.connect(_open_legend)
	%QuitButton.pressed.connect(_quit)
	log_tab.pressed.connect(func() -> void: _select_tab(true))
	legend_tab.pressed.connect(func() -> void: _select_tab(false))
	howto_back.pressed.connect(func() -> void: _turn_howto(-1))
	howto_next.pressed.connect(func() -> void: _turn_howto(1))
	_fill_howto()
	_sync_legend()
	get_tree().node_added.connect(_on_node_added)
	_sync_scene.call_deferred()


func is_open() -> bool:
	return root != null and root.visible and (
		menu_panel.visible or detail.visible or howto.visible
	)


func close() -> void:
	if menu_panel != null:
		menu_panel.visible = false
	if detail != null:
		detail.visible = false
	if howto != null:
		howto.visible = false
	if scrim != null:
		scrim.visible = false


func note_status(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	if not _log.is_empty() and _log[_log.size() - 1] == line:
		return
	_log.append(line)
	_fill_log()


func clear_log() -> void:
	_log = PackedStringArray()
	_fill_log()


func _on_node_added(node: Node) -> void:
	if node.scene_file_path.is_empty():
		return
	_sync_scene.call_deferred()


func _sync_scene() -> void:
	if root == null:
		return
	var current := get_tree().current_scene
	if current == null:
		return
	var path := current.scene_file_path
	var on_title := path == TITLE_SCENE or path == BOOT_SCENE
	var on_story := path.begins_with("res://scenes/story/")
	root.visible = not on_title and not on_story
	if on_title or on_story:
		close()
	if on_title:
		clear_log()


func toggle() -> void:
	if is_open():
		close()
		return
	detail.visible = false
	howto.visible = false
	menu_panel.visible = true
	scrim.visible = true


func _open_log() -> void:
	_show_detail(true)


func _open_legend() -> void:
	_show_detail(false)


func open_help() -> void:
	if howto != null and howto.visible:
		close()
		return
	menu_panel.visible = false
	detail.visible = false
	_howto_index = 0
	_fill_howto()
	howto.visible = true
	scrim.visible = true


func _turn_howto(step: int) -> void:
	var last := maxi(pages.get_child_count() - 1, 0)
	_howto_index = clampi(_howto_index + step, 0, last)
	_fill_howto()


func _fill_howto() -> void:
	if pages == null:
		return
	var list := pages.get_children()
	if list.is_empty():
		return
	_howto_index = clampi(_howto_index, 0, list.size() - 1)
	var total := list.size()
	for index in total:
		var page := list[index]
		page.visible = index == _howto_index
		var count := page.get_node_or_null("Header/Count") as Label
		if count != null:
			count.text = "%d/%d" % [index + 1, total]
	howto_back.disabled = _howto_index <= 0
	howto_next.disabled = _howto_index >= total - 1


func _show_detail(showing_log: bool) -> void:
	menu_panel.visible = false
	howto.visible = false
	_select_tab(showing_log)
	detail.visible = true
	scrim.visible = true


func _select_tab(showing_log: bool) -> void:
	log_body.visible = showing_log
	legend.visible = not showing_log
	_style_tab(log_tab, showing_log)
	_style_tab(legend_tab, not showing_log)
	if showing_log:
		_fill_log()


func _sync_legend() -> void:
	var rows := {
		"Attack": "atk",
		"Range": "rng",
		"Move": "mov",
		"Dodge": "dodge",
		"Defend": "def",
		"Crescent": "bar",
	}
	for row_name in rows:
		var label := legend.get_node_or_null("Scroll/List/%s/Phrase" % row_name) as Label
		if label == null:
			continue
		label.text = UiIcons.phrase(rows[row_name])


func _fill_log() -> void:
	if log_body == null:
		return
	if _log.is_empty():
		log_body.text = "No statuses yet."
	else:
		log_body.text = "\n\n".join(_log)


func _on_scrim_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		close()


func _quit() -> void:
	close()
	GameManager.quit_stage()


func _style_tab(button: Button, selected: bool) -> void:
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
