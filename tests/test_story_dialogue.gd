@tool
extends McpTestSuite


func suite_name() -> String:
	return "story_dialogue"


func test_alley_and_bridge_keep_their_lines() -> void:
	var alley := _spoken(load("res://dialogue/story_alley.dialogue"), "start")
	assert_eq(alley.size(), 3, "alley lines")
	assert_eq(alley[0].character, "Comet")
	assert_eq(alley[0].text, "Street's clear. The citadel is watching the far end.")
	assert_eq(alley[0].tags[0], "art=white")
	assert_eq(alley[1].character, "Raven")
	assert_eq(alley[1].text, "Then we walk it. Call them before they call us.")
	assert_eq(alley[1].tags[0], "art=purple")
	assert_eq(alley[2].text, "On your mark.")
	assert_eq(alley[2].tags[0], "art=white")

	var bridge := _spoken(load("res://dialogue/story_bridge.dialogue"), "start")
	assert_eq(bridge.size(), 3, "bridge lines")
	assert_eq(bridge[0].text, "The bridge is the only line across. Red corp owns the other end.")
	assert_eq(bridge[1].text, "They shoot farther than the citadel did. Don't give them a straight walk.")
	assert_eq(bridge[2].text, "Rain hides the first step. After that, they see us. Spread out.")
	assert_eq(bridge[2].tags[0], "art=white")


func test_mission_comms_stop_at_the_end_of_each_cue() -> void:
	var first := _spoken(load("res://dialogue/mission_comms.dialogue"), "mission_1")
	assert_eq(first.size(), 4, "mission 1 comms")
	assert_eq(first[0].character, "Comms")
	assert_eq(first[0].text, "Well that was fast. Citadel approaches. Their mechs are already on the streets.")
	assert_eq(first[3].text, "Clear every hostile and this mission is done. Then we can head back to base.")
	var second := _spoken(load("res://dialogue/mission_comms.dialogue"), "mission_2")
	assert_eq(second.size(), 4, "mission 2 comms")
	assert_eq(second[0].text, "Rain's on the bridge. Red corp holds the far bank.")
	assert_eq(second[3].text, "Clear the bridge and we pull back to base.")
	assert_ne(first[3].text, second[0].text, "the cues stay separate")
	var third := _spoken(load("res://dialogue/mission_comms.dialogue"), "mission_3")
	assert_eq(third.size(), 4, "mission 3 comms")
	assert_eq(third[0].text, "Rain's on the waterfront. Green corp holds the street, water behind the buildings.")
	assert_eq(third[3].text, "Clear the street and we pull back to base.")
	assert_ne(second[3].text, third[0].text, "mission 3 stays separate from mission 2")


func test_story_scenes_point_at_their_dialogue() -> void:
	var alley := (load("res://scenes/story/story1.tscn") as PackedScene).instantiate() as StoryPlayer
	assert_eq(alley.dialogue.resource_path, "res://dialogue/story_alley.dialogue")
	assert_eq(alley.next_scene, "res://scenes/select/mech_select.tscn")
	var opening := alley._opening_line(alley.dialogue.resource_path, alley.start_cue)
	assert_eq(opening.speaker, "Comet")
	assert_eq(opening.text, "Street's clear. The citadel is watching the far end.")
	alley.free()

	var bridge := (load("res://scenes/story/story2.tscn") as PackedScene).instantiate() as StoryPlayer
	assert_eq(bridge.dialogue.resource_path, "res://dialogue/story_bridge.dialogue")
	opening = bridge._opening_line(bridge.dialogue.resource_path, "start")
	assert_eq(opening.text, "The bridge is the only line across. Red corp owns the other end.")
	bridge.free()

	var street := _spoken(load("res://dialogue/story_street.dialogue"), "start")
	assert_eq(street.size(), 3, "street lines")
	assert_eq(street[0].character, "Comet")
	assert_eq(street[0].text, "Rain on the east bank. Green corp is in the street, water behind them.")
	assert_eq(street[0].tags[0], "art=white")
	assert_eq(street[1].character, "Raven")
	assert_eq(street[1].text, "No boss on this block. The scouts close the gap. The rest have to step in beside us.")
	assert_eq(street[1].tags[0], "art=purple")
	assert_eq(street[2].text, "Hold the open street. Let them come off the buildings.")
	assert_eq(street[2].tags[0], "art=white")

	var east_bank := (load("res://scenes/story/story3.tscn") as PackedScene).instantiate() as StoryPlayer
	assert_eq(east_bank.dialogue.resource_path, "res://dialogue/story_street.dialogue")
	assert_eq(east_bank.next_scene, "res://scenes/select/mech_select.tscn")
	opening = east_bank._opening_line(east_bank.dialogue.resource_path, east_bank.start_cue)
	assert_eq(opening.speaker, "Comet")
	assert_eq(opening.text, "Rain on the east bank. Green corp is in the street, water behind them.")
	east_bank.free()


func test_the_bar_keeps_a_response_button_and_the_known_portraits() -> void:
	var bar := (load("res://scenes/ui/dialogue_bar.tscn") as PackedScene).instantiate()
	assert_true(bar.get_node("Dialogue/Body") is DialogueLabel, "body types with Dialogue Manager")
	assert_true(bar.get_node("Responses/ResponseTemplate") is Button, "choices use the scene button")
	bar.free()
	var balloon := (load("res://scenes/ui/dialogue_balloon.tscn") as PackedScene).instantiate()
	assert_true(balloon.has_method("start"), "balloon can be shown by Dialogue Manager")
	balloon.free()
	assert_true(DialogueBar.portrait_for_name("Comet") != null)
	assert_true(DialogueBar.portrait_for_name("Raven") != null)
	assert_true(DialogueBar.portrait_for_name("Comms") != null)


func _spoken(resource: DialogueResource, cue: String) -> Array[Dictionary]:
	var key := str(resource.cues.get(cue, ""))
	var spoken: Array[Dictionary] = []
	var guard := 0
	while key != "" and key != "end" and key != "end!" and guard < 30:
		guard += 1
		if not resource.lines.has(key):
			break
		var line: Dictionary = resource.lines[key]
		if str(line.get("type", "")) == "dialogue":
			spoken.append(line)
		var next_id := str(line.get("next_id", ""))
		if next_id == key:
			break
		key = next_id
	return spoken
