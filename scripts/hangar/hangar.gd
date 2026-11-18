extends Control

@onready var back_button: BaseButton = %BackButton
@onready var campaign_button: BaseButton = %CampaignButton
@onready var rewards_button: BaseButton = %RewardsButton
@onready var progression_button: BaseButton = %ProgressionButton

var _leaving := false


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	campaign_button.pressed.connect(_on_campaign_pressed)
	rewards_button.pressed.connect(_on_rewards_pressed)
	progression_button.pressed.connect(_on_progression_pressed)


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.go_to_command()


func _on_campaign_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.start_mission()


func _on_rewards_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.go_to_rewards()


func _on_progression_pressed() -> void:
	if _leaving:
		return
	_leave()
	GameManager.go_to_progression()


func _leave() -> void:
	_leaving = true
	back_button.disabled = true
	campaign_button.disabled = true
	rewards_button.disabled = true
	progression_button.disabled = true
