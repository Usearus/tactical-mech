## Overdrive bars carry their own readout: the name on the left end, the charge on the right end.
## A mirrored bar flips that, so the charge sits on the left and the name on the right.
class_name OverdriveGauge
extends RefCounted

const SQUAD_CAPTION := "Squad"
const OVERDRIVE := "Overdrive"
const TITLE_NAME := "Title"
const CHARGE_NAME := "Charge"
## Matches the project theme so the readout is the same size as other UI text.
const TEXT_SIZE := 32
const TEXT_PAD := 10.0
## Tall enough for standard text, and the same height as a button.
const BAR_HEIGHT := 48.0
## Fallbacks when a bar has no SquadGauge theme style yet.
const FILL_COLOR := Color(0.25, 0.72, 0.95)
const FLASH_COLOR := Color(0.72, 0.94, 1.0)
const _FLASH_META := "overdrive_flash"
const _FILL_OWNED := "fill_owned"
const _FILL_REST := "fill_rest"


## Safe to call again. Existing readouts keep the font and color set on the scene.
static func dress(bar: ProgressBar, mirror: bool = false) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, BAR_HEIGHT)
	var title_align := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	var charge_align := HORIZONTAL_ALIGNMENT_LEFT if mirror else HORIZONTAL_ALIGNMENT_RIGHT
	var title := bar.get_node_or_null(TITLE_NAME) as Label
	if title != null:
		title.text = OVERDRIVE
		title.horizontal_alignment = title_align
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var charge := bar.get_node_or_null(CHARGE_NAME) as Label
	if charge != null:
		charge.horizontal_alignment = charge_align
		charge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## A private copy of the theme fill, so a pulse does not recolor every gauge.
static func claim_fill(bar: ProgressBar) -> StyleBoxFlat:
	if bar == null:
		return null
	if bar.has_meta(_FILL_OWNED):
		return bar.get_theme_stylebox("fill") as StyleBoxFlat
	var source := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if source == null:
		return null
	var copy := source.duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override("fill", copy)
	bar.set_meta(_FILL_OWNED, true)
	bar.set_meta(_FILL_REST, copy.bg_color)
	return copy


## Pulse between the theme fill and the SquadGauge flash style while the gauge is full.
static func pulse(bar: ProgressBar, fill: StyleBoxFlat, full: bool) -> void:
	if bar == null or fill == null:
		return
	var rest := _rest_color(bar, fill)
	var flash := _flash_color(bar)
	var running: Tween = bar.get_meta(_FLASH_META) as Tween if bar.has_meta(_FLASH_META) else null
	if full:
		if running != null and is_instance_valid(running) and running.is_running():
			return
		if not bar.is_inside_tree():
			fill.bg_color = rest
			return
		var tween := bar.create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(fill, "bg_color", flash, 0.45)
		tween.tween_property(fill, "bg_color", rest, 0.45)
		bar.set_meta(_FLASH_META, tween)
		return
	if running != null and is_instance_valid(running):
		running.kill()
	if bar.has_meta(_FLASH_META):
		bar.remove_meta(_FLASH_META)
	fill.bg_color = rest


static func _rest_color(bar: ProgressBar, fill: StyleBoxFlat) -> Color:
	if bar.has_meta(_FILL_REST):
		return bar.get_meta(_FILL_REST)
	return fill.bg_color


static func _flash_color(bar: ProgressBar) -> Color:
	var flash := bar.get_theme_stylebox("flash")
	if flash is StyleBoxFlat:
		return (flash as StyleBoxFlat).bg_color
	return FLASH_COLOR


static func write(bar: ProgressBar, charge: int, maximum: int) -> void:
	if bar == null:
		return
	var count := bar.get_node_or_null(CHARGE_NAME) as Label
	if count == null:
		return
	count.text = "%d/%d" % [charge, maximum]
