## Live Overdrive gauge for the map, the battle preview, and the fight.
## Every pill starts muted. Charge turns them accent. A full gauge pulses.
class_name OverdriveMeter
extends HBoxContainer

const SEGMENT_SCENE := preload("res://scenes/ui/overdrive_segment.tscn")
const NOTE := "Discarding a card fills this gauge, and cards left in hand when a battle ends do too. When it is full, press Activate Overdrive. Attacks hit harder, guards block more, and each mech's overdrive card can enter the hand."
const MUTED := Color(0.18, 0.38, 0.5)
const ACCENT := Color(0.25, 0.72, 0.95)
## Pulse target, and the type size of the Activate button beside the gauge.
const FLASH_COLOR := Color(0.72, 0.94, 1.0)
const TEXT_SIZE := 32
## Matches the squad gauge flash: a short swing toward white, then back.
const PULSE_STEP := 0.45

@onready var info_badge: TextureButton = %OverdriveInfo
@onready var _segments_box: HBoxContainer = %Segments

var _segments: Array[OverdriveSegment] = []
var _muted_style: StyleBoxFlat
var _accent_style: StyleBoxFlat
var _pulse: Tween
var _shown := -1
var _length := 0
var _filled := 0


func _ready() -> void:
	_muted_style = _pill(MUTED)
	_accent_style = _pill(ACCENT)
	for child in _segments_box.get_children():
		var segment := child as OverdriveSegment
		if segment == null:
			continue
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_segments.append(segment)
		segment.apply_style(_muted_style)


## steady holds a full gauge on the accent color. Battle uses that once Overdrive is on.
## announce flashes each newly filled pill. A results snapshot can skip that.
func show_charge(charge: int, maximum: int, steady: bool = false, announce: bool = true) -> void:
	var length := maxi(maximum, 0)
	var filled := clampi(charge, 0, length)
	var previous := _shown
	_shown = filled
	_length = length
	_filled = filled
	while _segments.size() < length:
		var segment := SEGMENT_SCENE.instantiate() as OverdriveSegment
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_segments_box.add_child(segment)
		_segments.append(segment)
	for index in _segments.size():
		var segment := _segments[index]
		if segment.is_flashing():
			continue
		if index >= length:
			segment.dismiss()
			continue
		segment.apply_style(_accent_style if index < filled else _muted_style)
	if announce and previous >= 0 and filled > previous:
		var last := mini(filled, _segments.size())
		for index in range(previous, last):
			_segments[index].flash_white(ACCENT, _restore_segment.bind(index))
	_set_pulse(not steady and length > 0 and filled >= length)


## Draw the eye to the gauge when a charge card is played with nothing to spend.
func flash_empty() -> void:
	for index in _segments.size():
		if index >= _length:
			continue
		var rest := ACCENT if index < _filled else MUTED
		_segments[index].flash_white(rest, _restore_segment.bind(index))


func _restore_segment(index: int) -> void:
	if index < 0 or index >= _segments.size():
		return
	var segment := _segments[index]
	if index >= _length:
		segment.dismiss()
		return
	segment.apply_style(_accent_style if index < _filled else _muted_style)


func _set_pulse(full: bool) -> void:
	if _accent_style == null:
		return
	if full:
		if _pulse != null and _pulse.is_valid() and _pulse.is_running():
			return
		if not is_inside_tree():
			_accent_style.bg_color = ACCENT
			return
		_pulse = create_tween()
		_pulse.set_loops()
		_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(_accent_style, "bg_color", FLASH_COLOR, PULSE_STEP)
		_pulse.tween_property(_accent_style, "bg_color", ACCENT, PULSE_STEP)
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_accent_style.bg_color = ACCENT


func _pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
