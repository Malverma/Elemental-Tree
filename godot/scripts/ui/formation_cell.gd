class_name FormationCell
extends PanelContainer
## One slot of the 3x3 formation grid. Tap to place/remove; drag a placed troop
## onto another slot to move it there (swapping if that slot is taken).

signal clicked(cell: FormationCell)

var row: String
var lane: int
var troop: Dictionary
var _pressed := false
var _styles := {}


func _init(p_row: String, p_lane: int, p_troop: Dictionary) -> void:
	row = p_row
	lane = p_lane
	troop = p_troop
	custom_minimum_size = Vector2(150, 150)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP
	_styles = {
		"empty": _style(Color.WHITE, UI.MUTED),
		"filled": _style(Color("#F2F9EC"), UI.INK),
		"target": _style(Color("#E3F3D8"), UI.ACCENT),
	}
	_set_look("filled" if not troop.is_empty() else "empty")
	if troop.is_empty():
		var plus := UI.label("+", "Title")
		plus.add_theme_color_override("font_color", UI.MUTED)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(plus)
	else:
		var d := GameData.troop_def(troop)
		var holder := Control.new()
		holder.mouse_filter = MOUSE_FILTER_IGNORE
		var img := UI.icon(d["img"], 120)
		img.set_anchors_preset(PRESET_FULL_RECT)
		holder.add_child(img)
		if d["element"] != "":
			var badge := UI.icon("icon_" + d["element"], 36)
			badge.set_anchors_preset(PRESET_TOP_RIGHT)
			badge.position = Vector2(-36, 0)
			holder.add_child(badge)
		add_child(holder)


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(8)
	return s


func _set_look(key: String) -> void:
	add_theme_stylebox_override("panel", _styles[key])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		elif _pressed:
			_pressed = false
			clicked.emit(self)


func _get_drag_data(_at: Vector2) -> Variant:
	if troop.is_empty():
		return null
	_pressed = false
	# Center the preview under the finger.
	var holder := Control.new()
	var img := UI.icon(GameData.troop_def(troop)["img"], 140)
	img.position = Vector2(-70, -70)
	holder.add_child(img)
	set_drag_preview(holder)
	modulate.a = 0.35
	return {"formation_cell": true, "row": row, "lane": lane}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("formation_cell") and not (data["row"] == row and data["lane"] == lane)
	if ok:
		_set_look("target")
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	Game.move_troop(data["row"], data["lane"], row, lane)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if what == NOTIFICATION_DRAG_END:
			modulate.a = 1.0
		_set_look("filled" if not troop.is_empty() else "empty")
