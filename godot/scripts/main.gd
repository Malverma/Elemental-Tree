extends Control
## App shell: resource bar, bottom navigation, the current screen, toasts and the battle overlay.

const GroveView := preload("res://scripts/ui/grove_view.gd")
const BarracksView := preload("res://scripts/ui/barracks_view.gd")
const GardenView := preload("res://scripts/ui/garden_view.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const BattleView := preload("res://scripts/ui/battle_view.gd")
const InventoryPanel := preload("res://scripts/ui/inventory_panel.gd")

const TABS := [["grove", "Grove"], ["garden", "Garden"], ["barracks", "Barracks"], ["map", "World Map"]]

var tab := "grove"
## Screen state that survives redraws.
## selected_level is a land id, a dungeon id ("dungeon_<n>"), or "grove" for the Home Grove (expeditions).
var ui := {"selected_plot": -1, "selected_troop": -1, "selected_level": "sunny_meadow"}

var _content: Control
var _view: Control
var _resources: HBoxContainer
var _powers: HBoxContainer
var _nav := {}
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

	var root := UI.vbox(0)
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())
	_content = Control.new()
	_content.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_content)
	root.add_child(_build_nav())

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
	var row := UI.hbox(10)
	_resources = UI.hbox(8)
	row.add_child(_resources)
	row.add_child(UI.spacer())
	# Debug builds (like the test APK) get a time warp and reset for testing.
	if OS.is_debug_build():
		var warp := UI.button("+1h", func() -> void:
			Game.advance(60)
			Game.changed.emit())
		warp.add_theme_font_size_override("font_size", 18)
		row.add_child(warp)
		var reset := UI.button("Reset", _confirm_reset, "DangerButton")
		reset.add_theme_font_size_override("font_size", 18)
		row.add_child(reset)
	col.add_child(row)
	_powers = UI.hbox(6)
	col.add_child(_powers)
	return UI.panel(col, "TopBar")


func _build_nav() -> Control:
	var row := UI.hbox(0)
	for t in TABS:
		var b := UI.button(t[1], switch_tab.bind(t[0]), "NavButton")
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		_nav[t[0]] = b
		row.add_child(b)
	return row


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
	_nav["garden"].modulate.a = 1.0 if Game.garden_unlocked() else 0.4
	_resources.add_child(UI.panel(UI.label("Lv %d" % s["tree"]["level"], "Heading"), "LevelChip"))
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


func switch_tab(id: String) -> void:
	if id == "garden" and not Game.garden_unlocked():
		Game.toast.emit("The garden opens after the tree's first prestige.", false)
		return
	tab = id
	for k in _nav:
		_nav[k].theme_type_variation = "NavButtonActive" if k == id else "NavButton"
	render(false)


# Several actions can fire in one frame (e.g. a battle result); redraw once.
func _queue_render() -> void:
	if not _render_queued:
		_render_queued = true
		render.call_deferred()


## Rebuilds the current screen, keeping its scroll position when `keep_scroll`.
func render(keep_scroll := true) -> void:
	_render_queued = false
	_refresh_resources()
	var scroll := 0
	if _view:
		if keep_scroll and _view is ScrollContainer:
			scroll = _view.scroll_vertical
		_view.queue_free()
	match tab:
		"grove":
			_view = GroveView.new(self)
		"garden":
			_view = GardenView.new(self)
		"barracks":
			_view = BarracksView.new(self)
		_:
			_view = MapView.new(self)
	_view.set_anchors_preset(PRESET_FULL_RECT)
	_content.add_child(_view)
	if scroll > 0:
		await get_tree().process_frame
		if is_instance_valid(_view):
			_view.scroll_vertical = scroll


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


## Sends the formation out from the Home Grove on an endless expedition.
func start_expedition() -> void:
	var check := Game.can_start_expedition()
	if not check["ok"]:
		show_toast(check["msg"], false)
		return
	_open_battle(BattleSim.new_expedition(Game.formation_troops(), Game.take_queued_potions(), Game.prestige_mult()))


func _open_battle(sim: BattleSim) -> void:
	_battle = BattleView.new(self, sim)
	_battle.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_battle)
	move_child(_overlay, -1)


## Opens the inventory over the current screen (outside of battle).
func open_inventory() -> void:
	add_child(InventoryPanel.new())
	move_child(_overlay, -1)


func close_battle() -> void:
	if _battle:
		_battle.queue_free()
		_battle = null
	render()


func _confirm_reset() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = "Delete your save and start over?"
	d.confirmed.connect(Game.reset)
	add_child(d)
	d.popup_centered()
