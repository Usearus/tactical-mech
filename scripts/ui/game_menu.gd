extends CanvasLayer

const TITLE_SCENE := "res://scenes/command/command.tscn"
const BOOT_SCENE := "res://scenes/main/main.tscn"
## Above scene overlays such as the discard tray (layer 60). The screen fade stays at 100.
const POPUP_LAYER := 90

@onready var root: Control = %Root
@onready var scrim: ColorRect = %Scrim
@onready var menu_panel: PanelContainer = %MenuPanel
@onready var detail: PanelContainer = %MenuPage
@onready var howto: Control = %HowTo
@onready var topics: VBoxContainer = %Topics
@onready var directions: ScrollContainer = %Directions
@onready var pages: Control = %Pages
@onready var howto_close: Button = %HowToClose
@onready var log_body: VBoxContainer = %LogBody
@onready var legend: VBoxContainer = %Legend


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
	howto_close.pressed.connect(_close_help)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for child in topics.get_children():
		var topic := child as BaseButton
		if topic == null:
			continue
		topic.button_group = group
		topic.pressed.connect(_select_topic.bind(topic.name))
	directions.resized.connect(_fit_directions)
	_select_topic("Loadout")
	_fit_directions.call_deferred()
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


func toggle() -> void:
	if howto != null and howto.visible:
		return
	if is_open():
		close()
		return
	detail.visible = false
	howto.visible = false
	menu_panel.visible = true
	scrim.visible = true


func _open_log() -> void:
	_show_page(true)


func _open_legend() -> void:
	_show_page(false)


func open_help() -> void:
	if howto != null and howto.visible:
		return
	menu_panel.visible = false
	detail.visible = false
	_select_topic("Loadout")
	howto.visible = true
	scrim.visible = true


func _close_help() -> void:
	if howto != null:
		howto.visible = false
	if scrim != null and not menu_panel.visible and not detail.visible:
		scrim.visible = false


func _select_topic(topic_name: String) -> void:
	for child in topics.get_children():
		var button := child as BaseButton
		if button == null:
			continue
		button.set_pressed_no_signal(button.name == topic_name)
	if pages == null:
		return
	for page in pages.get_children():
		page.visible = page.name == topic_name
	_fit_directions()


func _fit_directions() -> void:
	if directions == null or pages == null:
		return
	var width := directions.size.x
	var bar := directions.get_v_scroll_bar()
	if bar != null:
		width -= bar.get_combined_minimum_size().x
	width = maxf(width, 0.0)
	pages.custom_minimum_size.x = width
	for page in pages.get_children():
		var label := page as Control
		if label != null:
			label.custom_minimum_size.x = width


func _show_page(showing_log: bool) -> void:
	menu_panel.visible = false
	howto.visible = false
	log_body.visible = showing_log
	legend.visible = not showing_log
	detail.visible = true
	scrim.visible = true


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


func _on_scrim_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if howto != null and howto.visible:
		return
	if pressed:
		close()


func _quit() -> void:
	close()
	GameManager.quit_stage()
