extends Control
## App shell: the resource bar, the current screen, toasts and the battle overlay.
## Swipe left/right to move between screens; on the Grove and Garden, swipe up
## for a sheet with that screen's upgrades or seeds (swipe down to close it).

const GroveView := preload("res://scripts/ui/grove_view.gd")
const BarracksView := preload("res://scripts/ui/barracks_view.gd")
const GardenView := preload("res://scripts/ui/garden_view.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const BattleView := preload("res://scripts/ui/battle_view.gd")
const InventoryPanel := preload("res://scripts/ui/inventory_panel.gd")
const InfoPopup := preload("res://scripts/ui/info_popup.gd")

const TABS := [["grove", "Grove"], ["map", "World Map"], ["barracks", "Barracks"], ["garden", "Garden"]]
## How far (screen px) a drag must travel to count as a swipe, and how much it
## must favour that direction over the other.
const SWIPE_MIN := 90.0
const SWIPE_BIAS := 1.3
## Sideways drags past this (screen px) pick up the screen, which then follows
## the finger with its neighbour alongside. Let go past DRAG_COMMIT of the
## width, or with a flick faster than DRAG_FLICK (px/s), to move over.
const DRAG_START := 24.0
const DRAG_COMMIT := 0.25
const DRAG_FLICK := 700.0
const DRAG_EDGE := 0.3  # how far the screen gives when there's no neighbour that way
const SLIDE_TIME := 0.28
const SHEET_HEIGHT := 0.8  # share of the screen the pull-up sheet covers

var tab := "grove"
## Screen state that survives redraws.
## selected_level is a land id, a dungeon id ("dungeon_<n>"), or "grove" for the Home Grove (expeditions).
var ui := {"selected_plot": -1, "selected_troop": -1, "selected_level": "sunny_meadow", "attack_target": ""}

var _content: Control
var _view: Control
var _view_tab := ""
var _top_bar: Control
var _bottom: Control
var _resources: HBoxContainer
var _powers: HBoxContainer
var _pages := {}
var _handle: Button
var _sheet_layer: Control
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_scroll: ScrollContainer
var _sheet_body: MarginContainer
var _sheet_open := false
var _swipe_start := Vector2.INF
var _swipe_blocked := false
var _swipe_sheet_scroll := 0
var _swipe_scrolls := Vector2i.ZERO  # axes a list under the press scrolls along
var _dragging := false  # a sideways drag is carrying the screen
var _drag_dir := 0  # which side the neighbour being dragged in sits on (-1 left, 1 right)
var _drag_next: Control
var _drag_next_tab := ""
var _drag_vx := 0.0
var _toasts: VBoxContainer
var _overlay: Control
var _battle: Control
var _render_queued := false
var _sun_label: Label
var _sap_label: Label
## Redraws the screen once tapping pauses, so upgrade buttons catch up with the new stock.
var _tap_settle: Timer


func _ready() -> void:
	theme = UI.build_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Screens fill the window; the top bar and page indicator float over them.
	_content = Control.new()
	_content.set_anchors_preset(PRESET_FULL_RECT)
	_content.clip_contents = true
	add_child(_content)
	_top_bar = _build_top_bar()
	_top_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_top_bar.resized.connect(_apply_insets)
	add_child(_top_bar)
	_bottom = _build_pages()
	_bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = GROW_DIRECTION_BEGIN
	_bottom.resized.connect(_apply_insets)
	add_child(_bottom)
	add_child(_build_sheet())

	# Floating layer for toasts and tap pops, above everything.
	_overlay = Control.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_toasts = UI.vbox(8)
	_toasts.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_toasts.grow_horizontal = GROW_DIRECTION_BOTH
	_toasts.grow_vertical = GROW_DIRECTION_BEGIN
	_toasts.position.y -= 130
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.add_child(_toasts)

	Game.changed.connect(_queue_render)
	Game.toast.connect(show_toast)
	Game.tapped_stock.connect(_on_tapped_stock)
	_tap_settle = Timer.new()
	_tap_settle.one_shot = true
	_tap_settle.wait_time = 0.6
	_tap_settle.timeout.connect(_queue_render)
	add_child(_tap_settle)

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(_on_tick)
	add_child(ticker)
	ticker.start()

	switch_tab("grove")


func _build_top_bar() -> Control:
	var col := UI.vbox(8)
	var row := UI.hbox(8)
	_resources = UI.hbox(8)
	row.add_child(_resources)
	row.add_child(UI.spacer())
	row.add_child(_icon_button("icon_inventory", open_inventory))
	row.add_child(_icon_button("icon_menu", open_menu))
	col.add_child(row)
	_powers = UI.hbox(6)
	col.add_child(_powers)
	return UI.panel(col, "TopBar")


# A round pixel-icon button in the same bubble as the counters beside it.
func _icon_button(icon_name: String, on_press: Callable) -> Button:
	var b := UI.button("", on_press, "ChipButton")
	b.icon = UI.crisp(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.custom_minimum_size = Vector2(58, 58)
	return b


# The pull-up handle and the row of screen names along the bottom.
func _build_pages() -> Control:
	var col := UI.vbox(0)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_handle = UI.button("", open_sheet, "FlatButton")
	_handle.size_flags_horizontal = SIZE_SHRINK_CENTER
	_handle.add_theme_font_size_override("font_size", 22)
	_handle.icon = UI.crisp("handle_up")
	_handle.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_handle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handle.add_theme_constant_override("icon_max_width", 33)
	col.add_child(_handle)
	var row := UI.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	for t in TABS:
		# Each name is also a button: tap it, or swipe, to change screens.
		var l := UI.button(t[1], _on_page_pressed.bind(t[0]), "FlatButton")
		l.custom_minimum_size.y = 44
		_pages[t[0]] = l
		row.add_child(l)
	var pill := UI.panel(row, "Pill")
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	var center := UI.hbox(0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(pill)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_bottom", 14)
	pad.add_theme_constant_override("margin_top", 2)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(center)
	col.add_child(pad)
	return col


# The pull-up sheet: a dimmed backdrop and a panel that slides up from the bottom.
func _build_sheet() -> Control:
	_sheet_layer = Control.new()
	_sheet_layer.set_anchors_preset(PRESET_FULL_RECT)
	_sheet_layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UI.NIGHT, 0.45)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_sheet())
	_sheet_layer.add_child(dim)
	_sheet = PanelContainer.new()
	_sheet.theme_type_variation = "Sheet"
	_sheet.theme = UI.build_sheet_theme()
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet_layer.add_child(_sheet)
	var col := UI.vbox(6)
	_sheet.add_child(col)
	var grab := ColorRect.new()
	grab.color = Color(1, 1, 1, 0.3)
	grab.custom_minimum_size = Vector2(90, 8)
	grab.size_flags_horizontal = SIZE_SHRINK_CENTER
	var grab_pad := MarginContainer.new()
	grab_pad.add_theme_constant_override("margin_top", 12)
	grab_pad.add_child(grab)
	col.add_child(grab_pad)
	var head := UI.hbox(10)
	var head_pad := MarginContainer.new()
	for side in ["left", "right"]:
		head_pad.add_theme_constant_override("margin_" + side, 20)
	head_pad.add_child(head)
	_sheet_title = UI.label("", "Title")
	head.add_child(_sheet_title)
	head.add_child(UI.spacer())
	head.add_child(UI.button("Close", close_sheet))
	col.add_child(head_pad)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_sheet_scroll)
	_sheet_body = MarginContainer.new()
	_sheet_body.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		_sheet_body.add_theme_constant_override("margin_" + side, 16)
	_sheet_scroll.add_child(_sheet_body)
	return _sheet_layer


func _chip(icon_name: String, value: float, icon_size := 26) -> Control:
	var chip := UI.hbox(4)
	chip.add_child(UI.icon(icon_name, icon_size))
	chip.add_child(UI.label(UI.fmt(value), "OnDarkBold"))
	return UI.panel(chip, "Chip")


static func _chip_label(chip: Control) -> Label:
	return chip.get_child(0).get_child(1)


# Taps only touch the counters; the full redraw waits until tapping pauses.
func _on_tapped_stock() -> void:
	_sun_label.text = UI.fmt(Game.state["resources"]["sunlight"])
	_sap_label.text = UI.fmt(Game.state["resources"]["sap"])
	_tap_settle.start()


func _refresh_resources() -> void:
	for box in [_resources, _powers]:
		for c in box.get_children():
			c.queue_free()
	var s: Dictionary = Game.state
	_resources.add_child(UI.panel(UI.label("Lv %d" % s["tree"]["level"], "OnDarkBold"), "Chip"))
	var sun := _chip("icon_sunlight", s["resources"]["sunlight"])
	var sap := _chip("icon_sap", s["resources"]["sap"])
	_sun_label = _chip_label(sun)
	_sap_label = _chip_label(sap)
	_resources.add_child(sun)
	_resources.add_child(sap)
	for el in GameData.ELEMENTS:
		var c := _chip("icon_" + el, s["resources"]["power"][el], 22)
		c.size_flags_horizontal = SIZE_EXPAND_FILL
		_powers.add_child(c)


# Names along the bottom: the current screen bright. The garden only joins
# the row once it opens, after the tree's first prestige.
func _refresh_pages() -> void:
	for k in _pages:
		var l: Button = _pages[k]
		l.add_theme_font_size_override("font_size", 26 if k == tab else 21)
		l.modulate.a = 1.0 if k == tab else 0.7
		l.visible = k != "garden" or Game.garden_unlocked()
	var has_sheet := _view != null and _view.has_method("build_sheet")
	var show_handle := has_sheet and not _sheet_open
	if _handle.visible != show_handle:
		_handle.visible = show_handle
		_bottom.offset_top = _bottom.offset_bottom  # regrow to fit, then re-inset the screen
	if has_sheet:
		_handle.text = _view.sheet_title()


func switch_tab(id: String, dir := 0) -> void:
	if id == "garden" and not Game.garden_unlocked():
		Game.toast.emit("The garden opens after the tree's first prestige.", false)
		return
	if id == tab and _view:
		return
	if id != "barracks":
		ui["attack_target"] = ""
	close_sheet(false)
	tab = id
	if dir == 0 or _view == null:
		render(false)
		return
	# Slide the old screen out and the new one in from the side swiped toward.
	var old := _view
	_view = null
	render(false)
	var w := size.x
	_view.position.x = w * dir
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_view, "position:x", 0.0, SLIDE_TIME)
	tw.tween_property(old, "position:x", -w * dir, SLIDE_TIME)
	tw.chain().tween_callback(old.queue_free)


# Slides toward the tapped screen, from the side it sits on in the row.
func _on_page_pressed(id: String) -> void:
	var ids := TABS.map(func(t): return t[0])
	switch_tab(id, signi(ids.find(id) - ids.find(tab)))


## Moves one screen left (-1) or right (+1); a locked garden isn't there yet.
func step_tab(dir: int) -> void:
	var id := _neighbor(dir)
	if id != "":
		switch_tab(id, dir)


## The screen beside the current one (-1 left, 1 right), or "" at the end of the row.
func _neighbor(dir: int) -> String:
	var ids := TABS.map(func(t): return t[0])
	if not Game.garden_unlocked():
		ids.erase("garden")
	var i: int = ids.find(tab) + dir
	return ids[i] if i >= 0 and i < ids.size() else ""


# Several actions can fire in one frame (e.g. a battle result); redraw once.
func _queue_render() -> void:
	if not _render_queued:
		_render_queued = true
		render.call_deferred()


## Redraws the current screen, keeping its scroll position when `keep_scroll`.
## Screens with a `refresh` method update in place so their scenes keep animating.
func render(keep_scroll := true) -> void:
	_render_queued = false
	_refresh_resources()
	if _view and _view_tab == tab and _view.has_method("refresh"):
		_view.refresh()
	else:
		_rebuild_view(keep_scroll)
	_refresh_pages()
	if _sheet_open:
		_fill_sheet()


func _rebuild_view(keep_scroll: bool) -> void:
	var scroll := 0
	if _view:
		if keep_scroll and _view is ScrollContainer:
			scroll = _view.scroll_vertical
		_view.queue_free()
	_view = _new_view(tab)
	_view_tab = tab
	if scroll > 0:
		await get_tree().process_frame
		if is_instance_valid(_view):
			_view.scroll_vertical = scroll


# Builds screen `id` into the content area, fitted between the bars.
func _new_view(id: String) -> Control:
	var v: Control
	match id:
		"grove":
			v = GroveView.new(self)
		"garden":
			v = GardenView.new(self)
		"barracks":
			v = BarracksView.new(self)
		_:
			v = MapView.new(self)
	v.set_anchors_preset(PRESET_FULL_RECT)
	_content.add_child(v)
	_inset(v)
	return v


func _apply_insets() -> void:
	for v in [_view, _drag_next]:
		if v and is_instance_valid(v):
			_inset(v)


# Full-screen scenes get told how much the bars cover; list screens sit between them.
func _inset(v: Control) -> void:
	var top := _top_bar.size.y
	var bottom := _bottom.size.y
	if v.has_method("apply_insets"):
		v.apply_insets(top, bottom)
	else:
		v.offset_top = top
		v.offset_bottom = -bottom


## Opens the current screen's pull-up sheet (Grove upgrades, Garden seeds).
func open_sheet() -> void:
	if _sheet_open or not _view or not _view.has_method("build_sheet"):
		return
	_sheet_open = true
	_fill_sheet()
	_sheet_layer.visible = true
	move_child(_sheet_layer, -1)
	move_child(_overlay, -1)
	_handle.visible = false
	var h := size.y * SHEET_HEIGHT
	_sheet.offset_top = 0.0
	_sheet.offset_bottom = h
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sheet, "offset_top", -h, 0.3)
	tw.tween_property(_sheet, "offset_bottom", 0.0, 0.3)


func close_sheet(animate := true) -> void:
	if not _sheet_open:
		return
	_sheet_open = false
	_refresh_pages()
	if not animate:
		_sheet_layer.visible = false
		return
	var h := -_sheet.offset_top
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_sheet, "offset_top", 0.0, 0.22)
	tw.tween_property(_sheet, "offset_bottom", h, 0.22)
	tw.chain().tween_callback(func() -> void:
		if not _sheet_open:
			_sheet_layer.visible = false)


func _fill_sheet() -> void:
	var scroll := _sheet_scroll.scroll_vertical
	for c in _sheet_body.get_children():
		_sheet_body.remove_child(c)
		c.queue_free()
	_sheet_title.text = _view.sheet_title()
	_sheet_body.add_child(_view.build_sheet())
	if scroll > 0:
		await get_tree().process_frame
		_sheet_scroll.scroll_vertical = scroll


# Swipes are read here, ahead of the screens, so they work wherever they start.
# A drag that becomes a drag-and-drop (moving troops) is never a swipe.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_swipe_start = event.position
			_swipe_blocked = _battle != null or _modal_open()
			_swipe_scrolls = _scroll_axes()
			_swipe_sheet_scroll = _sheet_scroll.scroll_vertical
		elif _swipe_start != Vector2.INF:
			var d: Vector2 = event.position - _swipe_start
			_swipe_start = Vector2.INF
			if _dragging:
				# The screen was following the finger; the press isn't a tap underneath.
				get_viewport().set_input_as_handled()
				_end_drag(d.x)
			elif not _swipe_blocked and not get_viewport().gui_is_dragging():
				_on_swipe(d)
	elif event is InputEventMouseMotion and _swipe_start != Vector2.INF:
		if get_viewport().gui_is_dragging():
			_swipe_blocked = true
			return
		var d: Vector2 = event.position - _swipe_start
		if not _dragging and not _swipe_blocked and not _sheet_open and not _swipe_scrolls.x and _view \
				and absf(d.x) >= DRAG_START and absf(d.x) > absf(d.y) * SWIPE_BIAS:
			_dragging = true
		if _dragging:
			get_viewport().set_input_as_handled()
			_drag_vx = event.velocity.x
			_drag_to(d.x)


# Carries the screen `dx` px sideways, with the neighbour on that side
# following alongside (built the first time the drag heads its way).
func _drag_to(dx: float) -> void:
	var w := size.x
	var dir := -signi(int(signf(dx))) if dx != 0.0 else _drag_dir
	if dir != _drag_dir:
		_drop_drag_next()
		_drag_dir = dir
		var id := _neighbor(dir)
		if id != "":
			_drag_next_tab = id
			_drag_next = _new_view(id)
	if not _drag_next:
		dx *= DRAG_EDGE  # nothing that way: the screen only gives a little
	_view.position.x = dx
	if _drag_next:
		_drag_next.position.x = dx + w * _drag_dir


# Lets go of a sideways drag: moves on to the neighbour if the drag went far
# or fast enough, otherwise springs back.
func _end_drag(dx: float) -> void:
	_dragging = false
	var w := size.x
	var flick := absf(_drag_vx) >= DRAG_FLICK and signf(_drag_vx) == signf(dx)
	var go := _drag_next != null and (absf(dx) >= w * DRAG_COMMIT or flick)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if go:
		var old := _view
		_view = _drag_next
		_drag_next = null
		tab = _drag_next_tab
		_view_tab = tab
		# The rest of the way takes as long as the distance left, so it keeps the finger's pace.
		var t := clampf(SLIDE_TIME * (1.0 - absf(dx) / w), 0.12, SLIDE_TIME)
		tw.tween_property(_view, "position:x", 0.0, t)
		tw.tween_property(old, "position:x", -w * _drag_dir, t)
		tw.chain().tween_callback(old.queue_free)
		_drag_dir = 0
		_refresh_pages()
		_refresh_resources()
		return
	tw.tween_property(_view, "position:x", 0.0, 0.2)
	if _drag_next:
		var gone := _drag_next
		_drag_next = null
		tw.tween_property(gone, "position:x", w * _drag_dir, 0.2)
		tw.chain().tween_callback(gone.queue_free)
	_drag_dir = 0


func _drop_drag_next() -> void:
	if _drag_next:
		_drag_next.queue_free()
		_drag_next = null
	_drag_next_tab = ""


func _on_swipe(d: Vector2) -> void:
	var horizontal := absf(d.x) >= SWIPE_MIN and absf(d.x) > absf(d.y) * SWIPE_BIAS
	var vertical := absf(d.y) >= SWIPE_MIN and absf(d.y) > absf(d.x) * SWIPE_BIAS
	if _sheet_open:
		# Swiping down closes the sheet, unless it was scrolling its list.
		if vertical and d.y > 0 and _swipe_sheet_scroll == 0:
			close_sheet()
		return
	if (horizontal and _swipe_scrolls.x) or (vertical and _swipe_scrolls.y):
		return  # that drag scrolled a list
	if horizontal:
		step_tab(-1 if d.x > 0 else 1)
	elif vertical and d.y < 0:
		open_sheet()


# A drag along a list that scrolls that way (other than the sheet) moves the
# list, not the screen.
func _scroll_axes() -> Vector2i:
	var axes := Vector2i.ZERO
	var c: Node = get_viewport().gui_get_hovered_control()
	while c and c != self:
		if c is ScrollContainer and c != _sheet_scroll and c.get_child_count() > 0:
			var inner: Control = c.get_child(0)
			axes.x |= int(inner.size.x > c.size.x + 1)
			axes.y |= int(inner.size.y > c.size.y + 1)
		c = c.get_parent()
	return axes


# Inventory panels and dialogs take the screen; swipes wait until they close.
func _modal_open() -> bool:
	for c in get_children():
		if c.has_signal("closed") or (c is Window and c.visible):
			return true
	return false


func _on_tick() -> void:
	Game.tick()
	if _view and _view.has_method("live"):
		_view.live()


func show_toast(message: String, good: bool) -> void:
	var t := UI.panel(UI.label(message, "OnDark"), "Toast" if good else "ToastBad")
	t.mouse_filter = MOUSE_FILTER_IGNORE
	_toasts.add_child(t)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := t.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.tween_callback(t.queue_free)


## Floats a short text (like "+1") up from a screen position.
func pop_text(text: String, at: Vector2, color: Color) -> void:
	var l := UI.label(text, "Title")
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UI.INK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	# A little random spread so rapid taps fan out instead of stacking on one spot.
	var start := at - get_global_rect().position - l.size / 2.0 + Vector2(randf_range(-8.0, 8.0), 0.0)
	l.position = start
	l.scale = Vector2.ONE * 0.4
	var rise := l.create_tween()
	rise.tween_property(l, "position", start + Vector2(randf_range(-26.0, 26.0), -95.0), 0.9) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var pop := l.create_tween()
	pop.tween_property(l, "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Stay solid while rising, then fade out over the second half.
	var fade := l.create_tween()
	fade.tween_interval(0.4)
	fade.tween_property(l, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_callback(l.queue_free)


func start_battle(level_id: String) -> void:
	var check := Game.can_enter(level_id)
	if not check["ok"]:
		show_toast(check["msg"], false)
		return
	_open_battle(BattleSim.new(level_id, Game.formation_troops(), false, Game.take_queued_potions(), Game.prestige_mult()))


func start_dungeon(id: String) -> void:
	var check := Game.can_enter_dungeon(id)
	if not check["ok"]:
		show_toast(check["msg"], false)
		return
	_open_battle(BattleSim.new(id, Game.formation_troops(), false, Game.take_queued_potions(), Game.prestige_mult(),
		Game.dungeon_level(Game.dungeon(id))))


## Opens the Barracks to grow troops for a land or dungeon, with an Attack
## button there to set out for it once the formation is ready.
func grow_troops_for(id: String) -> void:
	ui["attack_target"] = id
	if tab == "barracks":
		render()
	else:
		_on_page_pressed("barracks")


## Attacks the land or dungeon the Barracks was opened for.
func attack_target() -> void:
	var id: String = ui["attack_target"]
	if id.begins_with("dungeon_"):
		start_dungeon(id)
	elif id != "":
		start_battle(id)


## Sends the formation out from the Home Grove on an endless expedition.
func start_expedition() -> void:
	var check := Game.can_start_expedition()
	if not check["ok"]:
		show_toast(check["msg"], false)
		return
	_open_battle(BattleSim.new_expedition(Game.formation_troops(), Game.take_queued_potions(), Game.prestige_mult()))


func _open_battle(sim: BattleSim) -> void:
	_close_popups()
	_battle = BattleView.new(self, sim)
	_battle.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_battle)
	move_child(_overlay, -1)


## Shows a pop-out (or other modal panel) over the current screen.
func open_popup(popup: Control) -> void:
	add_child(popup)
	move_child(_overlay, -1)


func _close_popups() -> void:
	for c in get_children():
		if c.has_signal("closed") and c.has_method("close"):
			c.close()


## Opens the inventory over the current screen (outside of battle).
func open_inventory() -> void:
	_close_popups()
	open_popup(InventoryPanel.new())


## The menu pop-out. For now it only holds the developer tools.
func open_menu() -> void:
	_close_popups()
	open_popup(InfoPopup.new(_menu_content, 440.0))


func _menu_content() -> Control:
	var col := UI.vbox(14)
	var head := UI.hbox(10)
	head.add_child(UI.icon("icon_menu", 36))
	head.add_child(UI.label("Menu", "Title"))
	col.add_child(head)
	# Debug builds (like the test APK) get a time warp and reset for testing.
	if OS.is_debug_build():
		col.add_child(UI.label("Developer", "Heading"))
		col.add_child(UI.button("+1h", func() -> void:
			Game.advance(60)
			Game.changed.emit(), "PrimaryButton"))
		col.add_child(UI.button("Zero sunlight & sap", Game.dev_clear_stock, "PrimaryButton"))
		col.add_child(UI.button("Prestige", Game.dev_prestige, "PrimaryButton"))
		col.add_child(UI.button("Reset", _confirm_reset, "DangerButton"))
		col.add_child(UI.label("+1h skips an hour of growth. Zero empties your sunlight and sap. Prestige conquers the lands the tree needs, grows it to level %d and prestiges. Reset deletes the save." % GameData.MAX_LEVEL, "Small", true))
	else:
		col.add_child(UI.label("Nothing here yet.", "Muted"))
	return col


func close_battle() -> void:
	if _battle:
		_battle.queue_free()
		_battle = null
	render()


func _confirm_reset() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = "Delete your save and start over?"
	d.confirmed.connect(func() -> void:
		_close_popups()
		Game.reset())
	add_child(d)
	d.popup_centered()
