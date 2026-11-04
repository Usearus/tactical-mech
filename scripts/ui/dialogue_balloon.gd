extends CanvasLayer

## Screen for Dialogue Manager's test balloon. Story scenes keep their own bar.

@onready var bar: DialogueBar = $DialogueBar


func start(dialogue_resource: DialogueResource, cue: String = "", extra_game_states: Array = []) -> void:
	await bar.play(dialogue_resource, cue, extra_game_states)
	if is_inside_tree():
		queue_free()
