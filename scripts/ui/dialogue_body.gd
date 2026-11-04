@tool
extends DialogueLabel

## Emitted when letters hold for a sentence break, and again when they resume.
signal typing_held(held: bool)

var _held := false


func _process(delta: float) -> void:
	super._process(delta)
	# A sentence break waits much longer than the gap between two letters.
	var held := _is_typing and (_is_awaiting_mutation or _waiting_seconds > seconds_per_step * 2.0)
	if held == _held:
		return
	_held = held
	typing_held.emit(held)
