extends Control
## A pop-out card over the screen, in the same dark style as the sheet. Its
## content comes from `build` and is rebuilt when the game state changes.
## Tap outside it or Close to dismiss.

signal closed

const MAX_HEIGHT := 0.72  # share of the screen the card may take before it scrolls

var _build: Callable
var _max_width: float
var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: MarginContainer


func _init(build: Callable, max_width := 720.0) -> void:
	_build = build
	_max_width = max_width


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UI.build_sheet_theme()
	var dim := ColorRect.new()
	dim.color = Color(UI.NIGHT, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = "PopCard"
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_body = MarginContainer.new()
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	Game.changed.connect(_fill)
	resized.connect(_fit)
	_fill()
	# Pop out from the middle.
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * 0.9
	modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _fill() -> void:
	var scroll := _scroll.scroll_vertical
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var content: Control = _build.call()
	_body.add_child(content)
	# The close button joins the content's title row when it has one.
	var close_btn := UI.button("Close", close)
	var head: Node = content.get_child(0) if content.get_child_count() > 0 else null
	if head is HBoxContainer:
		head.add_child(UI.spacer())
		head.add_child(close_btn)
	else:
		var row := UI.hbox(0)
		row.add_child(UI.spacer())
		row.add_child(close_btn)
		content.add_child(row)
		content.move_child(row, 0)
	_fit.call_deferred()
	if scroll > 0:
		await get_tree().process_frame
		_scroll.scroll_vertical = scroll


# Centered, inset from the sides, as tall as the content up to MAX_HEIGHT.
func _fit() -> void:
	if not is_instance_valid(_body) or _body.get_child_count() == 0:
		return
	var w := minf(size.x - 40.0, _max_width)
	var pad := _panel.get_theme_stylebox("panel").get_minimum_size()
	# Wrapped text is as tall as its width makes it, so lay out at the final
	# width first, then measure.
	_body.custom_minimum_size.x = w - pad.x
	_scroll.custom_minimum_size.y = 0
	_panel.size = Vector2(w, 0)
	await get_tree().process_frame
	if not is_instance_valid(_body):
		return
	var h := minf(_body.get_combined_minimum_size().y + pad.y, size.y * MAX_HEIGHT)
	_scroll.custom_minimum_size.y = h - pad.y
	_panel.size = Vector2(w, h)
	_panel.position = (size - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0
