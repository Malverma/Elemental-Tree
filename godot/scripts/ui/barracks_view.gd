extends Control
## Barracks: the formation on its stumps in the root hollow, with the roster
## benched below. Tap a troop, then a stump to place it; tap a placed troop to
## pick it up (tap its stump again to bench it); drag between stumps to move or
## swap. Swipe up for the selected troop's details, element upgrades and growing
## new troops.

const ROW_LABEL := {"front": "Front", "middle": "Middle", "back": "Back"}

var main: Control
var _scene: BarracksScene
var _margin: MarginContainer
var _counts: Label
var _hint: Label
var _bench: PanelContainer
var _bench_title: Label
var _tokens: HFlowContainer
var _insets := Vector2.ZERO


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_scene = BarracksScene.new(main.ui["selected_troop"])
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.pad_tapped.connect(_on_pad_tapped)
	_scene.resized.connect(_place_bench.call_deferred)
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

	# The roster bench floats below the formation.
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
	_tokens.add_theme_constant_override("h_separation", 8)
	_tokens.add_theme_constant_override("v_separation", 8)
	box.add_child(_tokens)
	_bench = UI.panel(box, "Pill")
	_bench.clip_contents = true
	add_child(_bench)
	refresh()


## Keeps the overlay clear of the shell's top bar and page indicator.
func apply_insets(top: float, bottom: float) -> void:
	_insets = Vector2(top, bottom)
	_margin.add_theme_constant_override("margin_top", int(top) + 6)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_place_bench()


# The bench sits on the floor below the back row of stumps, as tall as its
# troops need but never down into the page indicator.
func _place_bench() -> void:
	if not is_instance_valid(_scene):
		return
	var top := _scene.origin.y + BarracksScene.GRID_BOTTOM * _scene.pixel_scale
	var room := size.y - _insets.y - 8.0 - top
	_bench.position = Vector2(16, top)
	_bench.size = Vector2(size.x - 32, 0)
	_bench.size.y = clampf(_bench.get_combined_minimum_size().y, 0.0, maxf(0.0, room))


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	var s: Dictionary = Game.state
	var sel: int = main.ui["selected_troop"]
	if sel >= 0 and Game.troop_by_id(sel).is_empty():
		sel = -1  # it fell in battle
		main.ui["selected_troop"] = sel
	_scene.selected_troop = sel
	_scene.sync()
	_counts.text = "Formation %d / %d  ·  ▲ the front row faces the enemy" % [s["formation"].size(), Game.formation_slots()]
	_bench_title.text = "Roster %d / %d" % [s["troops"].size(), Game.roster_cap()]
	if sel >= 0:
		_hint.text = "Tap a stump for %s" % GameData.troop_def(Game.troop_by_id(sel))["name"]
	elif s["troops"].is_empty():
		_hint.text = "No troops yet · swipe up to grow some"
	else:
		_hint.text = "Tap a troop, then a stump"
	_build_tokens()
	_place_bench.call_deferred()


func _build_tokens() -> void:
	for c in _tokens.get_children():
		c.queue_free()
	var in_formation := {}
	for f in Game.state["formation"]:
		in_formation[f["troop_id"]] = true
	for t in Game.state["troops"]:
		_tokens.add_child(_token(t, in_formation.has(t["id"])))


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
	b.custom_minimum_size = Vector2(80, 98)
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
	return b


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


func sheet_title() -> String:
	return "Troops"


## The selected troop's details and element upgrades, then growing new troops.
func build_sheet() -> Control:
	var col := UI.vbox(16)
	var selected := Game.troop_by_id(main.ui["selected_troop"])
	if not selected.is_empty():
		col.add_child(_upgrade_panel(selected))
	var grow := UI.vbox(10)
	grow.add_child(UI.label("Grow troops", "Title"))
	grow.add_child(UI.label("Troops sprout from the trunk and cost sap. Elemental troops also cost power. They appear once your roots reach a land of their element and unlock when you conquer it. Fallen troops are lost for good.", "Small", true))
	var cards := GridContainer.new()
	cards.columns = 3
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	for type in GameData.TROOP_ORDER:
		var el: String = GameData.TROOPS[type]["element"]
		if el == "" or Game.element_in_reach(el):
			cards.add_child(_summon_card(type))
	grow.add_child(cards)
	col.add_child(UI.panel(grow))
	return col


## Short "Strong vs X · Weak vs Y" line for an element.
static func matchup_text(element: String) -> String:
	return "Strong vs %s · Weak vs %s" % [GameData.strong_against(element).capitalize(), GameData.weak_against(element).capitalize()]


func _summon_card(type: String) -> Control:
	var d: Dictionary = GameData.TROOPS[type]
	var lock := Game.troop_lock_reason(type)
	var box := UI.vbox(6)
	var img := UI.icon(d["img"], 96)
	if lock != "":
		img.modulate = Color(0.6, 0.6, 0.6, 0.5)
	box.add_child(img)
	var title_row := UI.hbox(4)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if d["element"] != "":
		title_row.add_child(UI.icon("icon_" + d["element"], 22))
	var title := UI.label(d["name"], "Heading")
	title.add_theme_font_size_override("font_size", 20)
	title_row.add_child(title)
	box.add_child(title_row)
	var role := UI.label(d["role"], "Small", true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 17)
	box.add_child(role)
	box.add_child(_stats_grid(d))
	if lock != "":
		var hint := UI.label(lock, "Hint", true)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
	else:
		var b := UI.button("Grow", Game.summon.bind(type))
		b.disabled = not Game.can_summon(type)["ok"]
		b.size_flags_horizontal = SIZE_SHRINK_CENTER
		box.add_child(b)
		var cost := {"sap": d["sap_cost"]}
		var row := UI.cost_row(cost, Game.state["resources"])
		if d.has("power_cost"):
			var pair := UI.hbox(4)
			pair.add_child(UI.icon("icon_" + d["element"], 22))
			var l := UI.label(str(d["power_cost"]), "Heading")
			if Game.state["resources"]["power"][d["element"]] < d["power_cost"]:
				l.add_theme_color_override("font_color", UI.DANGER)
			pair.add_child(l)
			row.add_child(pair)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
	var card := UI.panel(box, "Card")
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	return card


func _stats_grid(d: Dictionary) -> GridContainer:
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 10)
	stats.size_flags_horizontal = SIZE_SHRINK_CENTER
	var reach := "%d (melee)" % d["reach"] if d["reach"] == 1 else str(d["reach"])
	for pair in [["HP", str(d["hp"])], ["DMG", str(d["dmg"])], ["Reach", reach]]:
		stats.add_child(UI.label(pair[0], "Small"))
		var v := UI.label(pair[1])
		v.add_theme_font_size_override("font_size", 20)
		stats.add_child(v)
	return stats


# Details for the selected troop, with element upgrades for base troops.
func _upgrade_panel(troop: Dictionary) -> Control:
	var d := GameData.troop_def(troop)
	var box := UI.vbox(10)
	var head := UI.hbox(12)
	head.add_child(UI.icon(d["img"], 96))
	var titles := UI.vbox(2)
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	titles.add_child(UI.label("%s #%d" % [d["name"], troop["id"]], "Title"))
	titles.add_child(UI.label(d["role"], "Small", true))
	if d["element"] != "":
		titles.add_child(UI.label(matchup_text(d["element"]), "Small", true))
	var stats := _stats_grid(d)
	stats.size_flags_horizontal = SIZE_SHRINK_BEGIN
	titles.add_child(stats)
	head.add_child(titles)
	box.add_child(head)
	var where := _troop_cell(troop["id"])
	if where.is_empty():
		box.add_child(UI.label("On the bench. Close this and tap a stump to place it.", "Muted", true))
	else:
		var row := UI.hbox(10)
		row.add_child(UI.label("%s row, lane %d" % [ROW_LABEL[where["row"]], where["lane"] + 1], "Muted"))
		row.add_child(UI.spacer())
		row.add_child(UI.button("Bench it", _bench_troop.bind(where), "DangerButton"))
		box.add_child(row)

	if d["element"] != "":
		var note := "This troop's element is %s and can't be changed." % d["element"].capitalize()
		box.add_child(UI.label(note, "Muted", true))
		return UI.panel(box)

	box.add_child(UI.label("Upgrade with an element", "Heading"))
	box.add_child(UI.label("Spend %d elemental power to permanently give this troop that element: its strengths, weaknesses and ability." % GameData.INFUSE_COST, "Small", true))
	for el in GameData.ELEMENTS:
		var inf: Dictionary = GameData.INFUSION[el]
		var row := UI.hbox(10)
		row.add_child(UI.icon("icon_" + el, 36))
		var text := UI.vbox(0)
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_child(UI.label(el.capitalize(), "Heading"))
		text.add_child(UI.label(inf["desc"], "Small", true))
		text.add_child(UI.label(matchup_text(el), "Small", true))
		row.add_child(text)
		var b := UI.button("%d" % GameData.INFUSE_COST, Game.infuse.bind(troop["id"], el))
		b.icon = UI.crisp("icon_" + el)
		b.add_theme_constant_override("icon_max_width", 24)
		b.disabled = not Game.can_infuse(troop["id"], el)["ok"]
		row.add_child(b)
		box.add_child(row)
	return UI.panel(box)


func _troop_cell(id: int) -> Dictionary:
	for f in Game.state["formation"]:
		if f["troop_id"] == id:
			return f
	return {}


func _bench_troop(cell: Dictionary) -> void:
	main.ui["selected_troop"] = -1
	Game.place_troop(-1, cell["row"], cell["lane"])


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
