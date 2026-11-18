extends CanvasLayer

const TITLE_SCENE := "res://scenes/command/command.tscn"
const BOOT_SCENE := "res://scenes/main/main.tscn"
const HANGAR_SCENE := "res://scenes/hangar/hangar.tscn"
const BRIEFING_SCENE := "res://scenes/briefing/mission_brief.tscn"
const SETTINGS_SCENE := "res://scenes/hangar/settings.tscn"
const REWARDS_SCENE := "res://scenes/hangar/rewards.tscn"
const PROGRESSION_SCENE := "res://scenes/hangar/mech_progression.tscn"
const MECH_DETAILS_SCENE := "res://scenes/hangar/mech_details.tscn"
const PILOT_PROGRESSION_SCENE := "res://scenes/hangar/pilot_progression.tscn"
## Menu panel height while Mission Log, Legend, and Quit demo are all shown.
const MENU_FULL_HEIGHT := 240.0
## Menu panel height while only Quit demo is shown.
const MENU_QUIT_HEIGHT := 104.0
const BONUS_ROW_SCENE := preload("res://scenes/ui/bonus_row.tscn")
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
@onready var bonuses: Control = %Bonuses
@onready var bonus_empty: Label = %BonusEmpty
@onready var bonus_list: VBoxContainer = %BonusList


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
	if bonuses != null:
		bonuses.visible = false
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
	var on_hub := path == HANGAR_SCENE or path == BRIEFING_SCENE or path == SETTINGS_SCENE or path == REWARDS_SCENE or path == PROGRESSION_SCENE or path == MECH_DETAILS_SCENE or path == PILOT_PROGRESSION_SCENE
	root.visible = not on_title and not on_story and not on_hub
	if on_title or on_story or on_hub:
		close()
	_set_quit_only(false)


## A short menu shows only Quit demo. The full menu keeps the log and the legend.
func _set_quit_only(quit_only: bool) -> void:
	var log_button := %MissionLog as BaseButton
	var legend_button := %LegendButton as BaseButton
	if log_button != null:
		log_button.visible = not quit_only
	if legend_button != null:
		legend_button.visible = not quit_only
	if menu_panel == null:
		return
	var height := MENU_QUIT_HEIGHT if quit_only else MENU_FULL_HEIGHT
	menu_panel.offset_bottom = menu_panel.offset_top + height


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
	if bonuses != null:
		bonuses.visible = false
	_select_topic("Loadout")
	howto.visible = true
	scrim.visible = true


## The star on the overworld and in battle. Closes the menu and the help page.
func open_bonuses() -> void:
	if detail != null and detail.visible and bonuses != null and bonuses.visible:
		close()
		return
	menu_panel.visible = false
	if howto != null:
		howto.visible = false
	if log_body != null:
		log_body.visible = false
	if legend != null:
		legend.visible = false
	if bonuses != null:
		bonuses.visible = true
	if detail != null:
		detail.visible = true
	if scrim != null:
		scrim.visible = true
	_fill_bonuses()


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
	if bonuses != null:
		bonuses.visible = false
	log_body.visible = showing_log
	legend.visible = not showing_log
	detail.visible = true
	scrim.visible = true


func _fill_bonuses() -> void:
	if bonus_list == null:
		return
	for child in bonus_list.get_children():
		bonus_list.remove_child(child)
		child.free()
	var edicts := GameManager.mission_upgrades.active_edicts()
	if bonus_empty != null:
		bonus_empty.visible = edicts.is_empty()
	for offer in edicts:
		var row := BONUS_ROW_SCENE.instantiate() as BonusRow
		if row == null:
			continue
		bonus_list.add_child(row)
		row.show_edict(offer)


func _sync_legend() -> void:
	var rows := {
		"Heart": "hp",
		"Attack": "atk",
		"Range": "rng",
		"Move": "mov",
		"Evade": "evade",
		"Intercept": "int",
		"Defend": "def",
		"Crescent": "bar",
		"Clock": "act",
	}
	for row_name in rows:
		var label := legend.get_node_or_null("Scroll/List/%s/Phrase" % row_name) as RichTextLabel
		if label == null:
			continue
		label.text = UiIcons.gold_lead(UiIcons.phrase(rows[row_name]))


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
