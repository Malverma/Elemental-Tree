extends Control
## Barracks: the formation on its stumps in the root hollow, with the roster
## benched below. Tap a troop, then a stump to place it; tap a placed troop to
## pick it up (tap its stump again to bench it); drag between stumps to move or
## swap, or between the roster and the stumps (dropping a placed troop anywhere
## below the stumps benches it). While a troop is dragged, a
## campfire appears in the corner: drop it there to dismiss it for good. New
## troops are grown from the boxes below the roster.

const Campfire := preload("res://scripts/ui/campfire.gd")
## Roster tokens: the narrowest they get, and the gap between them.
const TOKEN_W := 80.0
const TOKEN_GAP := 8

var main: Control
var _scene: BarracksScene
var _margin: MarginContainer
var _counts: Label
var _attack: Button
var _hint: Label
var _lower: ScrollContainer
var _below: Control  # everything under the stumps, where a dragged troop goes back to the roster
var _lower_at := 0
var _bench: PanelContainer
var _bench_title: Label
var _tokens: HFlowContainer
var _shop_boxes: GridContainer
var _fire: VBoxContainer
var _fire_art: Control
var _fire_hot := false
var _insets := Vector2.ZERO


var _roster_hot := false
var _hint_before := ""


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_scene = BarracksScene.new(main.ui["selected_troop"])
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.pad_tapped.connect(_on_pad_tapped)
	_scene.resized.connect(_place_lower.call_deferred)
	add_child(_scene)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(PRESET_FULL_RECT)
	_margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_margin)
	var col := UI.vbox(2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_margin.add_child(col)
	var title := UI.label("Barracks", "SceneTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_counts = UI.label("", "SceneSmall")
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_counts)
	# Opened from the map's "Grow troops": a way back out to that land or dungeon.
	_attack = UI.button("Attack", main.attack_target, "PrimaryButton")
	_attack.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_attack)

	_below = Control.new()
	_below.mouse_filter = MOUSE_FILTER_PASS
	add_child(_below)

	# Below the formation, the roster bench and then the grow boxes, scrolling
	# together when they don't fit.
	_lower = ScrollContainer.new()
	_lower.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lower.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_lower)
	var stack := UI.vbox(8)
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	stack.minimum_size_changed.connect(_place_lower.call_deferred)
	_lower.add_child(stack)

	var box := UI.vbox(8)
	var head := UI.hbox(8)
	_bench_title = UI.label("", "Scene")
	head.add_child(_bench_title)
	head.add_child(UI.spacer())
	_hint = UI.label("", "SceneSmall")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_hint)
	box.add_child(head)
	_tokens = HFlowContainer.new()
	_tokens.add_theme_constant_override("h_separation", TOKEN_GAP)
	_tokens.add_theme_constant_override("v_separation", 8)
	_tokens.resized.connect(_fit_tokens)
	box.add_child(_tokens)
	_bench = UI.panel(box, "Pill")
	stack.add_child(_bench)
	# A troop dragged off its stump onto the roster, or anywhere else below the
	# stumps (like the grow boxes), leaves the formation.
	for c in [_below, _lower, stack, _bench, _tokens]:
		_accept_roster_drops(c)

	var shop := UI.vbox(8)
	shop.add_child(UI.label("Grow troops", "Scene"))
	_shop_boxes = GridContainer.new()
	_shop_boxes.columns = 3
	_shop_boxes.add_theme_constant_override("h_separation", 8)
	_shop_boxes.add_theme_constant_override("v_separation", 8)
	shop.add_child(_shop_boxes)
	var shop_panel := UI.panel(shop, "Pill")
	stack.add_child(shop_panel)
	for c in [shop_panel, shop, _shop_boxes]:
		_accept_roster_drops(c)

	_fire = UI.vbox(0)
	_fire.visible = false
	_fire_art = Campfire.new()
	_fire.add_child(_fire_art)
	var fire_label := UI.label("Dismiss", "SceneSmall")
	fire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fire.add_child(fire_label)
	for c in [_fire, _fire_art, fire_label]:
		c.set_drag_forwarding(Callable(), _can_drop_on_fire, _drop_on_fire)
	add_child(_fire)
	refresh()


## Keeps the overlay clear of the shell's top bar and page indicator.
func apply_insets(top: float, bottom: float) -> void:
	_insets = Vector2(top, bottom)
	_margin.add_theme_constant_override("margin_top", int(top) + 6)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_place_lower()


# The bench and grow boxes sit on the floor below the back row of stumps, as
# tall as they need but never down into the page indicator.
func _place_lower() -> void:
	if not is_instance_valid(_scene):
		return
	var top := _scene.origin.y + BarracksScene.GRID_BOTTOM * _scene.pixel_scale
	var room := size.y - _insets.y - 8.0 - top
	_below.position = Vector2(0, top)
	_below.size = Vector2(size.x, maxf(0.0, size.y - top))
	_lower.position = Vector2(16, top)
	_lower.size = Vector2(size.x - 32, clampf(_lower.get_child(0).get_combined_minimum_size().y, 0.0, maxf(0.0, room)))


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	var s: Dictionary = Game.state
	var sel: int = main.ui["selected_troop"]
	if sel >= 0 and Game.troop_by_id(sel).is_empty():
		sel = -1  # it fell in battle
		main.ui["selected_troop"] = sel
	_scene.selected_troop = sel
	_scene.sync()
	var target: String = main.ui["attack_target"]
	if target.begins_with("dungeon_") and Game.dungeon(target).is_empty():
		target = ""  # cleared, so it crumbled
		main.ui["attack_target"] = target
	_attack.visible = target != ""
	_counts.text = "Formation %d / %d  ·  ▲ the front row faces the enemy" % [s["formation"].size(), Game.formation_slots()]
	_bench_title.text = "Roster %d / %d" % [s["troops"].size(), Game.roster_cap()]
	if sel >= 0:
		_hint.text = "Tap a stump for %s" % GameData.troop_def(Game.troop_by_id(sel))["name"]
	elif s["troops"].is_empty():
		_hint.text = "No troops yet · grow some below"
	else:
		_hint.text = ""
	_build_tokens()
	_build_shop()
	_place_lower.call_deferred()


func _build_tokens() -> void:
	for c in _tokens.get_children():
		c.queue_free()
	var in_formation := {}
	for f in Game.state["formation"]:
		in_formation[f["troop_id"]] = true
	for t in Game.state["troops"]:
		_tokens.add_child(_token(t, in_formation.has(t["id"])))
	_fit_tokens()


# Widens the tokens so each row fills the roster exactly, leaving the same
# margin on both sides rather than the leftover width on the right.
func _fit_tokens() -> void:
	var w := _tokens.size.x
	if w <= 0.0:
		return
	var cols := maxi(1, floori((w + TOKEN_GAP) / (TOKEN_W + TOKEN_GAP)))
	var tw := floorf((w - TOKEN_GAP * (cols - 1)) / cols)
	for c in _tokens.get_children():
		c.custom_minimum_size.x = tw


# A roster troop: its sprite, number and element, ringed in gold when picked.
func _token(t: Dictionary, placed: bool) -> Button:
	var d := GameData.troop_def(t)
	var picked: bool = main.ui["selected_troop"] == t["id"]
	var b := Button.new()
	b.text = "#%d%s" % [t["id"], " ✓" if placed else ""]
	b.icon = UI.crisp(d["img"])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(TOKEN_W, 98)
	b.tooltip_text = d["name"]
	b.add_theme_font_size_override("font_size", 18)
	var text_col: Color = Color.WHITE if d["element"] == "" else GameData.BIOME_COLORS[d["element"]].lightened(0.35)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text_col)
	b.add_theme_color_override("font_outline_color", UI.NIGHT)
	b.add_theme_constant_override("outline_size", 6)
	var look := _token_style(picked)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, look)
	if placed and not picked:
		b.modulate.a = 0.6
	b.pressed.connect(_on_troop_pressed.bind(t["id"]))
	b.set_drag_forwarding(_drag_token.bind(t), _can_drop_on_roster, _drop_on_roster)
	return b


# Dragging a roster troop carries it toward the stumps (or the campfire).
func _drag_token(_at: Vector2, t: Dictionary) -> Variant:
	set_drag_preview(_scene.drag_preview(t))
	return {"roster_troop": t["id"]}


static func _token_style(picked: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.NIGHT, 0.85 if picked else 0.55)
	s.border_color = UI.ROOT_GLOW if picked else Color(1, 1, 1, 0.16)
	s.set_border_width_all(4 if picked else 2)
	s.set_corner_radius_all(14)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 4
	return s


# One box per troop type in reach. Elemental troops appear once your roots reach
# a land of their element and unlock when you conquer it.
func _build_shop() -> void:
	for c in _shop_boxes.get_children():
		c.queue_free()
	for type in GameData.TROOP_ORDER:
		var el: String = GameData.TROOPS[type]["element"]
		if el == "" or Game.element_in_reach(el):
			_shop_boxes.add_child(_shop_box(type))


# A buy box: sprite, name, HP / DMG / reach, and cost (or what unlocks it).
# Tapping grows the troop.
func _shop_box(type: String) -> Button:
	var d: Dictionary = GameData.TROOPS[type]
	var lock := Game.troop_lock_reason(type)
	var b := Button.new()
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 186)
	b.tooltip_text = "%s · %s" % [d["name"], lock if lock != "" else d["role"]]
	var look := _token_style(false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, look)
	b.disabled = not Game.can_summon(type)["ok"]
	# Pass drags on so the list scrolls by touch; a scroll isn't a purchase.
	b.mouse_filter = MOUSE_FILTER_PASS
	_accept_roster_drops(b)
	b.button_down.connect(func() -> void: _lower_at = _lower.scroll_vertical)
	b.pressed.connect(_on_shop_pressed.bind(type))

	var box := UI.vbox(4)
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.offset_top = 6
	box.offset_bottom = -6
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var img := UI.icon(d["img"], 54)
	box.add_child(img)
	var title := _box_label(d["name"], 19)
	box.add_child(title)
	var stats := UI.hbox(10)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["HP", d["hp"]], ["DMG", d["dmg"]], ["Reach", d["reach"]]]:
		var stat := UI.vbox(0)
		stat.custom_minimum_size.x = 52
		var cap := _box_label(pair[0], 15)
		cap.modulate.a = 0.7
		stat.add_child(cap)
		stat.add_child(_box_label(str(pair[1]), 21))
		stats.add_child(stat)
	box.add_child(stats)
	if lock != "":
		var short := "Tree Lv %d" % d["unlock_level"] if lock.begins_with("Unlocks") else "Conquer"
		box.add_child(_box_label("🔒 " + short, 19))
	else:
		var row := UI.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var res: Dictionary = Game.state["resources"]
		row.add_child(_cost_pair(UI.RES_ICON["sap"], d["sap_cost"], res["sap"] >= d["sap_cost"]))
		if d.has("power_cost"):
			row.add_child(_cost_pair("icon_" + d["element"], d["power_cost"], res["power"][d["element"]] >= d["power_cost"]))
		box.add_child(row)
	for c in box.find_children("*", "Control", true, false):
		c.mouse_filter = MOUSE_FILTER_IGNORE
	box.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(box)
	return b


# Light outlined text for the dark boxes.
static func _box_label(text: String, font_size: int) -> Label:
	var l := UI.label(text, "SceneSmall")
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# An icon and amount, red when the player can't afford it.
static func _cost_pair(icon: String, amount: int, affordable: bool) -> HBoxContainer:
	var pair := UI.hbox(4)
	pair.add_child(UI.icon(icon, 24))
	var l := _box_label(str(amount), 21)
	if not affordable:
		l.add_theme_color_override("font_color", UI.DANGER)
	pair.add_child(l)
	return pair


func _on_shop_pressed(type: String) -> void:
	if absi(_lower.scroll_vertical - _lower_at) < 8:
		Game.summon(type)


func _accept_roster_drops(c: Control) -> void:
	c.set_drag_forwarding(Callable(), _can_drop_on_roster, _drop_on_roster)


func _can_drop_on_roster(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("barracks_pad")
	_set_roster_hot(ok)
	return ok


func _drop_on_roster(_at: Vector2, data: Variant) -> void:
	_set_roster_hot(false)
	main.ui["selected_troop"] = -1
	Game.place_troop(-1, data["row"], data["lane"])


# The roster lights up while a dragged troop hovers over it.
func _set_roster_hot(on: bool) -> void:
	if on == _roster_hot:
		return
	_roster_hot = on
	_bench.self_modulate = Color(1.35, 1.3, 0.85) if on else Color.WHITE
	if on:
		_hint_before = _hint.text
		_hint.text = "Drop to take it out of the formation"
	else:
		_hint.text = _hint_before


# The campfire shows in the bottom corner while any troop is being dragged.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and _fire:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and (data.has("barracks_pad") or data.has("roster_troop")):
			_fire_art.unit = maxf(3.0, _scene.pixel_scale)
			_fire.size = Vector2.ZERO
			_fire.position = size - _fire.get_combined_minimum_size() - Vector2(16, _insets.y + 8)
			_fire.visible = true
	elif what == NOTIFICATION_DRAG_END and _fire:
		_fire.visible = false
		_set_fire_hot(false)


func _can_drop_on_fire(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and (data.has("barracks_pad") or data.has("roster_troop"))
	_set_fire_hot(ok)
	return ok


func _drop_on_fire(_at: Vector2, data: Variant) -> void:
	_set_fire_hot(false)
	var id: int = data["troop_id"] if data.has("troop_id") else data["roster_troop"]
	if main.ui["selected_troop"] == id:
		main.ui["selected_troop"] = -1
	Game.dismiss_troop(id)


func _set_fire_hot(on: bool) -> void:
	if on == _fire_hot:
		return
	_fire_hot = on
	_fire_art.hot = on


func _process(_delta: float) -> void:
	if _fire_hot and not (get_viewport().gui_is_dragging() and _fire.get_global_rect().has_point(get_global_mouse_position())):
		_set_fire_hot(false)
	var at := get_global_mouse_position()
	if _roster_hot and not (get_viewport().gui_is_dragging() and _below.get_global_rect().has_point(at)
			and not (_fire.visible and _fire.get_global_rect().has_point(at))):
		_set_roster_hot(false)


func _on_troop_pressed(id: int) -> void:
	main.ui["selected_troop"] = -1 if main.ui["selected_troop"] == id else id
	main.render()


# With a troop picked, a stump takes it (replacing whoever stood there), or
# benches it if it is the stump it already stands on. Otherwise tapping a
# placed troop picks it up.
func _on_pad_tapped(row: String, lane: int) -> void:
	var sel: int = main.ui["selected_troop"]
	var here: int = -1
	for f in Game.state["formation"]:
		if f["row"] == row and f["lane"] == lane:
			here = f["troop_id"]
	if sel >= 0:
		main.ui["selected_troop"] = -1
		Game.place_troop(-1 if here == sel else sel, row, lane)
	elif here >= 0:
		main.ui["selected_troop"] = here
	main.render()
