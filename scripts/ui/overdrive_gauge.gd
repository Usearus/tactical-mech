## Overdrive bars carry their own readout: the name on the left end, the charge on the right end.
## A mirrored bar flips that, so the charge sits on the left and the name on the right.
class_name OverdriveGauge
extends RefCounted

const SQUAD_CAPTION := "Squad"
const OVERDRIVE := "Overdrive"
const ACTIVE_READOUT := "Overdrive active"
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
## Same blue as the "+1 charge" tag on a pitched card.
const GAIN_COLOR := Color(0.45, 0.78, 1.0)
## How long the +N stays fully visible, then how long it takes to fade.
const GAIN_HOLD := 1.5
const GAIN_FADE := 0.4
const _FLASH_META := "overdrive_flash"
const _GAIN_META := "overdrive_gain"
const _GAIN_ALPHA := "overdrive_gain_alpha"
const _GAIN_TWEEN := "overdrive_gain_tween"
const _SHOWN_META := "overdrive_shown"
const _HOLD_META := "overdrive_hold"
const _FILL_OWNED := "fill_owned"
const _FILL_REST := "fill_rest"
const SWOOSH_SCENE := preload("res://scenes/ui/gauge_swoosh.tscn")
const SWOOSH_NAME := "GaugeSwoosh"


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
	var charge := bar.get_node_or_null(CHARGE_NAME) as RichTextLabel
	if charge != null:
		charge.bbcode_enabled = true
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
	if _burst_running(bar):
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


## Steady blue bar for the rest of the fight. Centered label, no charge count, no pulse.
static func show_active(bar: ProgressBar, fill: StyleBoxFlat) -> void:
	if bar == null:
		return
	bar.set_meta(_HOLD_META, true)
	_clear_swoosh(bar)
	_drop_tween(bar, _FLASH_META)
	_drop_gain(bar)
	if fill != null:
		fill.bg_color = _rest_color(bar, fill)
	var title := bar.get_node_or_null(TITLE_NAME) as Label
	if title != null:
		title.text = ACTIVE_READOUT
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var charge := bar.get_node_or_null(CHARGE_NAME) as RichTextLabel
	if charge != null:
		charge.text = ""


static func write(bar: ProgressBar, charge: int, maximum: int) -> void:
	if bar == null:
		return
	var count := bar.get_node_or_null(CHARGE_NAME) as RichTextLabel
	if count == null:
		return
	count.bbcode_enabled = true
	var gain := ""
	if bar.has_meta(_GAIN_META):
		var amount := int(bar.get_meta(_GAIN_META))
		var alpha := 1.0
		if bar.has_meta(_GAIN_ALPHA):
			alpha = float(bar.get_meta(_GAIN_ALPHA))
		if amount > 0 and alpha > 0.0:
			var color := GAIN_COLOR
			color.a = alpha
			gain = "[color=#%s]+%d[/color]  " % [color.to_html(true), amount]
	count.text = "%s%d/%d" % [gain, charge, maximum]


## One fill swoosh across the whole bar, plus a blue +N beside the charge, when the gauge grows.
static func celebrate(bar: ProgressBar, fill: StyleBoxFlat, charge: int) -> void:
	if bar == null:
		return
	var previous := -1
	if bar.has_meta(_SHOWN_META):
		previous = int(bar.get_meta(_SHOWN_META))
	bar.set_meta(_SHOWN_META, charge)
	var gained := charge - previous
	if previous < 0 or gained < 1 or not bar.is_inside_tree():
		return
	_burst(bar, fill, gained, charge)


static func _burst(bar: ProgressBar, fill: StyleBoxFlat, gained: int, charge: int) -> void:
	_drop_tween(bar, _FLASH_META)
	_clear_swoosh(bar)
	if fill != null:
		fill.bg_color = _rest_color(bar, fill)
	_show_gain(bar, gained, charge)
	var swoosh := SWOOSH_SCENE.instantiate() as GaugeSwoosh
	swoosh.name = SWOOSH_NAME
	bar.add_child(swoosh)
	bar.move_child(swoosh, 0)
	swoosh.finished.connect(_on_burst_finished.bind(bar, fill, swoosh))
	swoosh.play(_flash_color(bar))


static func _on_burst_finished(bar: ProgressBar, fill: StyleBoxFlat, swoosh: GaugeSwoosh) -> void:
	if not is_instance_valid(bar):
		return
	if bar.get_node_or_null(SWOOSH_NAME) != swoosh:
		return
	if bar.has_meta(_HOLD_META):
		return
	var full := bar.max_value > 0.0 and bar.value >= bar.max_value
	pulse(bar, fill, full)


static func _show_gain(bar: ProgressBar, gained: int, charge: int) -> void:
	_drop_tween(bar, _GAIN_TWEEN)
	bar.set_meta(_GAIN_META, gained)
	bar.set_meta(_GAIN_ALPHA, 1.0)
	write(bar, charge, int(round(bar.max_value)))
	var tween := bar.create_tween()
	tween.tween_interval(GAIN_HOLD)
	tween.tween_method(_set_gain_alpha.bind(bar), 1.0, 0.0, GAIN_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bar.set_meta(_GAIN_TWEEN, tween)
	tween.finished.connect(_clear_gain.bind(bar, tween))


static func _set_gain_alpha(alpha: float, bar: ProgressBar) -> void:
	if not is_instance_valid(bar) or not bar.has_meta(_GAIN_META):
		return
	bar.set_meta(_GAIN_ALPHA, alpha)
	write(bar, int(round(bar.value)), int(round(bar.max_value)))


static func _clear_gain(bar: ProgressBar, tween: Tween) -> void:
	if not is_instance_valid(bar):
		return
	if not bar.has_meta(_GAIN_TWEEN) or bar.get_meta(_GAIN_TWEEN) != tween:
		return
	_drop_gain(bar)
	if bar.has_meta(_HOLD_META):
		return
	write(bar, int(round(bar.value)), int(round(bar.max_value)))


static func _drop_gain(bar: ProgressBar) -> void:
	_drop_tween(bar, _GAIN_TWEEN)
	if bar.has_meta(_GAIN_META):
		bar.remove_meta(_GAIN_META)
	if bar.has_meta(_GAIN_ALPHA):
		bar.remove_meta(_GAIN_ALPHA)


static func _burst_running(bar: ProgressBar) -> bool:
	var swoosh := bar.get_node_or_null(SWOOSH_NAME)
	return swoosh != null and is_instance_valid(swoosh)


static func _clear_swoosh(bar: ProgressBar) -> void:
	var swoosh := bar.get_node_or_null(SWOOSH_NAME)
	if swoosh != null and is_instance_valid(swoosh):
		swoosh.free()


static func _drop_tween(bar: ProgressBar, meta: String) -> void:
	if not bar.has_meta(meta):
		return
	var tween: Tween = bar.get_meta(meta) as Tween
	bar.remove_meta(meta)
	if tween != null and is_instance_valid(tween):
		tween.kill()
