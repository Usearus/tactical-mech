extends Control

const TILE_SCENE := preload("res://scenes/ui/reward_tile.tscn")
const ROW_SCENE := preload("res://scenes/ui/reward_row.tscn")
const GRID_SCENE := preload("res://scenes/ui/reward_grid.tscn")
const LOCK_SCENE := preload("res://scenes/ui/reward_lock.tscn")
const CARD_STRIDE := 192.0
const LOCKED_PER_MECH := 3

@onready var back_button: BaseButton = %BackButton
@onready var tabs: HBoxContainer = %Tabs
@onready var category: Label = %Category
@onready var summary: Label = %Summary
@onready var scroll: ScrollContainer = %CardScroll
@onready var list: VBoxContainer = %CardList
@onready var _note: InfoNote = %LockedNote

var _leaving := false
var _tab := ""
var _entries: Array[Dictionary] = []
var _built := false
var _filling := false
var _columns := 0
var _row_layout := false


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for child in tabs.get_children():
		var button := child as BaseButton
		if button == null:
			continue
		button.button_group = group
		button.pressed.connect(_on_tab_pressed.bind(button.name))
	scroll.resized.connect(_rebuild)
	_fit_tabs()
	%NewCards.button_pressed = true
	_show_tab("NewCards")


## Every tab matches the widest label. The title fills the header, so the row sits on the right.
func _fit_tabs() -> void:
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var buttons: Array[Button] = []
	var widest := 0.0
	for child in tabs.get_children():
		var button := child as Button
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.x = 0.0
		buttons.append(button)
	for button in buttons:
		widest = maxf(widest, button.get_minimum_size().x)
	for button in buttons:
		button.custom_minimum_size.x = widest


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	back_button.disabled = true
	GameManager.go_to_hangar()


func _on_tab_pressed(tab_name: String) -> void:
	var button := tabs.get_node_or_null(tab_name) as BaseButton
	if button != null and not button.button_pressed:
		return
	_show_tab(tab_name)


func _show_tab(tab_name: String) -> void:
	_show_heading(tab_name)
	if summary != null:
		summary.text = _summary_for(tab_name)


func _show_heading(tab_name: String) -> void:
	if category == null:
		return
	var button := tabs.get_node_or_null(tab_name) as Button
	category.text = button.text if button != null else ""
	if tab_name == _tab and not _entries.is_empty():
		return
	_tab = tab_name
	_entries = _entries_for(tab_name)
	_built = false
	if _note != null:
		_note.dismiss()
	_rebuild()


func _rebuild() -> void:
	if _filling or list == null or scroll == null or scroll.size.x < 8.0:
		return
	var columns := maxi(1, int((scroll.size.x + 16.0) / CARD_STRIDE))
	var rows := _uses_rows()
	if _built and _columns == columns and _row_layout == rows:
		return
	_filling = true
	for child in list.get_children():
		list.remove_child(child)
		child.free()
	if rows:
		_build_rows()
	else:
		_build_grid(columns)
	_columns = columns
	_row_layout = rows
	_built = true
	_filling = false


func _summary_for(tab_name: String) -> String:
	match tab_name:
		"Upgrades":
			return "Change a card a mech already has."
		"Edicts":
			return "Rules added to change the flow of battle."
		"Instants":
			return "Take effect the moment they are chosen."
		_:
			return "Added to a mech's deck."


func _uses_rows() -> bool:
	return _tab == "NewCards" or _tab == "Upgrades"


func _build_rows() -> void:
	var pilot := ""
	var row: HFlowContainer = null
	for entry in _entries:
		var name := str(entry["pilot"])
		if row == null or name != pilot:
			pilot = name
			row = ROW_SCENE.instantiate()
			list.add_child(row)
		_add_tile(row, entry)
	for child in list.get_children():
		_add_locks(child, true)


func _build_grid(columns: int) -> void:
	var grid := GRID_SCENE.instantiate() as GridContainer
	list.add_child(grid)
	grid.columns = columns
	for entry in _entries:
		_add_tile(grid, entry)
	_add_locks(grid, false)


func _add_locks(host: Node, lifted: bool) -> void:
	for _index in LOCKED_PER_MECH:
		var locked := LOCK_SCENE.instantiate()
		host.add_child(locked)
		locked.show_locked(_note, lifted)


func _add_tile(host: Node, entry: Dictionary) -> void:
	var tile := TILE_SCENE.instantiate()
	host.add_child(tile)
	tile.present(entry["card"], entry["stroke"], entry["tag"], entry["stars"], entry["squad"], entry["art"])


func _entries_for(tab_name: String) -> Array[Dictionary]:
	match tab_name:
		"Upgrades":
			return _sorted_pilot(_pilot_offers("Modify"))
		"Edicts":
			return _sorted_name(_edicts())
		"Instants":
			return _sorted_name(_instants())
		_:
			return _sorted_pilot(_pilot_offers("Grant"))


func _pilot_offers(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for mech in StartingRoster.player_roster():
		if mech == null:
			continue
		var catalog := _catalog(UpgradeRoller.PLAYER_PATH % mech.id)
		if catalog == null:
			continue
		var pilot := mech.display_name if mech.display_name != "" else mech.id
		for offer in catalog.offers:
			if offer == null or offer.kind != kind:
				continue
			var card := _card_for(kind, offer, mech)
			if card == null:
				continue
			found.append(_entry(card, MechCard.stroke_for(mech), "", offer, false, pilot, mech.art_id))
	return found


func _edicts() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var catalog := _catalog(UpgradeRoller.EDICT_PATH)
	if catalog == null:
		return found
	for offer in catalog.offers:
		if offer == null or offer.kind != "Edict":
			continue
		var card := _squad_card(offer, false)
		if card == null:
			continue
		found.append(_entry(card, MechCard.stroke_for(null), "", offer, true, "", ""))
	return found


func _barriers() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var catalog := _catalog(UpgradeRoller.TEAM_PATH)
	if catalog == null:
		return found
	for offer in catalog.offers:
		if offer == null or offer.kind != "Immediate":
			continue
		var card := _squad_card(offer, true)
		if card == null:
			continue
		found.append(_entry(card, MechCard.stroke_for(null), "", offer, true, "", ""))
	return found


func _instants() -> Array[Dictionary]:
	var found := _barriers()
	var offer := _revive_offer()
	if offer == null:
		return found
	var card := CardData.new()
	card.id = offer.id
	card.display_name = "Revive Mech"
	card.description = offer.blurb if offer.blurb != "" else "Returns with half health."
	card.card_type = "Defense"
	card.reach = 0
	card.hide_cost = true
	card.target_type = "team"
	found.append(_entry(card, MechCard.stroke_for(null), "", offer, true, "", ""))
	return found


func _card_for(kind: String, offer: UpgradeOffer, mech: MechData) -> CardData:
	if kind == "Grant":
		if offer.card == null:
			return null
		return offer.card.duplicate() as CardData
	var source := UpgradeDeck.first_of_family(mech, offer.card_family)
	if source == null:
		return null
	var preview := source.duplicate() as CardData
	UpgradeDeck.paint(preview, UpgradeDeck.stacked_mod({}, offer))
	return preview


func _squad_card(offer: UpgradeOffer, barrier: bool) -> CardData:
	var card := CardData.new()
	card.id = offer.id
	card.display_name = offer.display_name
	if card.display_name == "" and barrier:
		card.display_name = "Squad Barrier"
	card.description = offer.blurb
	card.card_type = "Defense"
	card.reach = 0
	card.hide_cost = true
	card.target_type = "team"
	if barrier:
		card.defense_kind = "Guard"
		card.barrier = offer.barrier
	return card


func _entry(card: CardData, stroke: Color, tag: String, offer: UpgradeOffer, squad: bool, pilot: String, art_id: String) -> Dictionary:
	return {
		"card": card,
		"stroke": stroke,
		"tag": tag,
		"stars": clampi(offer.rarity, 1, 3),
		"squad": squad,
		"pilot": pilot,
		"art": art_id,
		"name": card.display_name,
		"id": offer.id,
	}


func _sorted_pilot(rows: Array[Dictionary]) -> Array[Dictionary]:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["pilot"]) != str(b["pilot"]):
			return str(a["pilot"]) < str(b["pilot"])
		if str(a["name"]) != str(b["name"]):
			return str(a["name"]) < str(b["name"])
		return str(a["id"]) < str(b["id"])
	)
	return rows


func _sorted_name(rows: Array[Dictionary]) -> Array[Dictionary]:
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["name"]) != str(b["name"]):
			return str(a["name"]) < str(b["name"])
		return str(a["id"]) < str(b["id"])
	)
	return rows


func _catalog(path: String) -> UpgradeCatalog:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as UpgradeCatalog


func _revive_offer() -> UpgradeOffer:
	if not ResourceLoader.exists(UpgradeRoller.REVIVE_PATH):
		return null
	return load(UpgradeRoller.REVIVE_PATH) as UpgradeOffer
