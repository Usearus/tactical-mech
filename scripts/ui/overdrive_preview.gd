## Select-screen Overdrive gauge. The stage floor is always shown.
## Squad OVD colors those rectangles in. Past the floor, the row grows.
class_name OverdrivePreview
extends PanelContainer

const SEGMENT_SCENE := preload("res://scenes/ui/overdrive_segment.tscn")
const ARRIVE_STAGGER := 0.045

@onready var segments: HBoxContainer = %Segments
@onready var length_label: Label = %Length
@onready var info_badge: TextureButton = %OverdriveInfo
@onready var _mark: Control = %Mark

var _segments: Array[OverdriveSegment] = []


func _ready() -> void:
	for child in segments.get_children():
		var segment := child as OverdriveSegment
		if segment != null:
			_segments.append(segment)


## charge is the squad's OVD total. floor_size is the stage minimum.
func show_squad(charge: int, floor_size: int) -> void:
	var minimum := maxi(floor_size, 0)
	var owed := maxi(charge, 0)
	var length := maxi(minimum, owed)
	var accounted := mini(owed, minimum)
	while _segments.size() < length:
		var segment := SEGMENT_SCENE.instantiate() as OverdriveSegment
		segment.visible = false
		segments.add_child(segment)
		_segments.append(segment)
	var arrivals := 0
	for index in _segments.size():
		var segment := _segments[index]
		if index >= length:
			segment.dismiss()
			continue
		var kind := OverdriveSegment.Kind.EMPTY
		if index >= minimum:
			kind = OverdriveSegment.Kind.EXTRA
		elif index < accounted:
			kind = OverdriveSegment.Kind.ACCOUNTED
		var changed := segment.set_kind(kind)
		if changed and kind != OverdriveSegment.Kind.EMPTY:
			segment.arrive(arrivals * ARRIVE_STAGGER)
			arrivals += 1
	var spill := length > minimum and minimum > 0
	_mark.visible = spill
	_order(length, minimum, spill)
	length_label.text = str(length)


func _order(length: int, minimum: int, spill: bool) -> void:
	var slot := 0
	for index in length:
		if spill and index == minimum:
			segments.move_child(_mark, slot)
			slot += 1
		segments.move_child(_segments[index], slot)
		slot += 1
	if not spill:
		segments.move_child(_mark, segments.get_child_count() - 1)
