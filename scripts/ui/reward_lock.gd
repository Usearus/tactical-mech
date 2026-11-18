extends VBoxContainer

const NOTE := "Currently locked"
const LIFT := 78.0 * HandOwnerBadge.PIN_SCALE

@onready var _lift: Control = $Lift
@onready var _lock: Control = $Slot/Lock


func _ready() -> void:
	if _lift != null:
		_lift.custom_minimum_size = Vector2(0.0, LIFT)
	if _lock != null:
		_lock.visible = true


func show_locked(note: InfoNote, lifted: bool) -> void:
	if _lift != null:
		_lift.visible = lifted
		_lift.custom_minimum_size = Vector2(0.0, LIFT if lifted else 0.0)
	bind(note)


func bind(note: InfoNote) -> void:
	if _lock == null or note == null:
		return
	note.tap(_lock, NOTE)
