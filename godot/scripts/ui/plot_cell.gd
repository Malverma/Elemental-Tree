class_name PlotCell
extends Control
## One garden plot: bare soil, a sprout that grows for GROW_MINUTES, then the
## grown plant. Tapping it emits `tapped` with the tap's global position.

signal tapped(index: int, global_pos: Vector2)

const ART := 124.0  # size of the plot/plant art, drawn above the status line

var index: int
var selected := false
var _status: Label
var _bob := 0.0


func _init(p_index: int, p_selected: bool) -> void:
	index = p_index
	selected = p_selected
	mouse_filter = MOUSE_FILTER_PASS  # taps are handled here; drags scroll the page
	custom_minimum_size = Vector2(0, ART + 52)
	size_flags_horizontal = SIZE_EXPAND_FILL
	_status = UI.label("", "Small")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_status.offset_top = -40
	_status.offset_bottom = -8
	_status.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_status)
	refresh()


func _plot() -> Dictionary:
	return Game.state["garden"][index]


func is_grown() -> bool:
	return _plot()["seed"] != "" and _plot()["grow_left"] <= 0.0


## Anything the grown plant has ready to collect (whole units only).
func has_harvest() -> bool:
	if not is_grown():
		return false
	for res in _plot()["stored"]:
		if _plot()["stored"][res] >= 1.0:
			return true
	return false


## Updates the status line; called every second by the garden view.
func refresh() -> void:
	var plot := _plot()
	if plot["seed"] == "":
		_status.text = "Empty plot"
	elif plot["grow_left"] > 0.0:
		var secs := ceili(plot["grow_left"] * 60.0)
		_status.text = "Growing %d:%02d" % [secs / 60, secs % 60]
	elif has_harvest():
		_status.text = "Tap to collect"
	else:
		_status.text = "Gathering…"
	_status.add_theme_color_override("font_color", UI.ACCENT if has_harvest() else UI.MUTED)
	queue_redraw()


func _process(delta: float) -> void:
	# Bob the "ready" badge so grown plants catch the eye.
	if has_harvest():
		_bob = fmod(_bob + delta * 3.0, TAU)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index, get_global_transform() * event.position)
		accept_event()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#EAF4E4")
	box.border_color = UI.ACCENT if selected else UI.LINE
	box.set_border_width_all(4 if selected else 3)
	box.set_corner_radius_all(14)
	draw_style_box(box, Rect2(Vector2.ZERO, size))

	var art := Rect2((size.x - ART) / 2.0, 4, ART, ART)
	draw_texture_rect(UI.tex("garden_plot"), art, false)
	var plot := _plot()
	if plot["seed"] == "":
		return
	var seed: Dictionary = GameData.SEEDS[plot["seed"]]
	if plot["grow_left"] > 0.0:
		# The sprout rises out of the soil as it grows.
		var t: float = 1.0 - plot["grow_left"] / GameData.GROW_MINUTES
		var s := lerpf(0.45, 1.0, t)
		# Plants stand at design y 50 of 64; scale around that point.
		var base := art.position + Vector2(ART / 2.0, ART * 50.0 / 64.0)
		var r := Rect2(base - Vector2(ART / 2.0, ART * 50.0 / 64.0) * s, Vector2(ART, ART) * s)
		draw_texture_rect(UI.tex("plant_sprout"), r, false)
		# Thin progress bar along the bottom of the art.
		var bar := Rect2(art.position.x + 20, art.end.y - 6, ART - 40, 8)
		draw_rect(bar, UI.LINE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), UI.LEAF)
		return
	draw_texture_rect(UI.tex(seed["plant_img"]), art, false)
	if has_harvest():
		var res: String = seed["makes"].keys()[0]
		var c := Vector2(art.end.x - 18, art.position.y + 24 + sin(_bob) * 4.0)
		draw_circle(c, 20, Color.WHITE)
		draw_arc(c, 20, 0, TAU, 32, UI.ACCENT, 3.0, true)
		draw_texture_rect(UI.tex(UI.RES_ICON.get(res, "icon_" + res)), Rect2(c - Vector2(14, 14), Vector2(28, 28)), false)
