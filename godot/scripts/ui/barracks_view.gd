extends ScrollContainer
## Barracks: grow troops, arrange the formation, view the roster and upgrade troops with elements.

const ROW_LABEL := {"front": "Front", "middle": "Middle", "back": "Back"}

var main: Control


func _init(p_main: Control) -> void:
	main = p_main
	horizontal_scroll_mode = SCROLL_MODE_DISABLED


func _ready() -> void:
	var s: Dictionary = Game.state
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := UI.vbox(16)
	margin.add_child(col)

	# Grow troops.
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

	# Formation.
	var form := UI.vbox(10)
	var head := UI.hbox(8)
	head.add_child(UI.label("Formation", "Title"))
	head.add_child(UI.spacer())
	head.add_child(UI.label("%d / %d slots" % [s["formation"].size(), Game.formation_slots()], "Muted"))
	form.add_child(head)
	form.add_child(UI.label("Tap a roster troop, then a slot. Drag a placed troop to move it; dropping on another troop swaps them. Tap a placed troop to remove it. Upgrade the trunk for more slots.", "Small", true))
	var ahead := UI.label("↑ Enemies ahead ↑", "Heading")
	ahead.add_theme_color_override("font_color", UI.DANGER)
	ahead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_child(ahead)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(Control.new())
	for lane in 3:
		var l := UI.label("Lane %d" % (lane + 1), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)
	var placed := {}
	for f in s["formation"]:
		placed["%s:%d" % [f["row"], f["lane"]]] = f["troop_id"]
	for row in BattleSim.ROWS:
		var rl := UI.label(ROW_LABEL[row], "Heading")
		rl.custom_minimum_size.x = 100
		if row == "front":
			rl.add_theme_color_override("font_color", UI.ACCENT)
		grid.add_child(rl)
		for lane in 3:
			var troop := Game.troop_by_id(placed.get("%s:%d" % [row, lane], -1))
			var cell := FormationCell.new(row, lane, troop)
			cell.clicked.connect(_on_cell_clicked)
			grid.add_child(cell)
	form.add_child(grid)
	col.add_child(UI.panel(form))

	# Roster.
	var roster := UI.vbox(10)
	var rhead := UI.hbox(8)
	rhead.add_child(UI.label("Roster", "Title"))
	rhead.add_child(UI.spacer())
	rhead.add_child(UI.label("%d / %d" % [s["troops"].size(), Game.roster_cap()], "Muted"))
	roster.add_child(rhead)
	if s["troops"].is_empty():
		roster.add_child(UI.label("No troops yet. Grow some above.", "Muted"))
	else:
		roster.add_child(UI.label("Tap a troop to place it, or to upgrade it with an element.", "Small", true))
	var in_formation := {}
	for f in s["formation"]:
		in_formation[f["troop_id"]] = true
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for t in s["troops"]:
		var d := GameData.troop_def(t)
		var text := "%s #%d%s" % [d["name"], t["id"], "  ✓" if in_formation.has(t["id"]) else ""]
		var b := UI.button(text, _on_troop_pressed.bind(t["id"]),
			"SelectedButton" if main.ui["selected_troop"] == t["id"] else "")
		b.icon = UI.tex(d["img"])
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 20)
		if d["element"] != "":
			b.add_theme_color_override("font_color", GameData.BIOME_COLORS[d["element"]].darkened(0.45))
		flow.add_child(b)
	roster.add_child(flow)
	col.add_child(UI.panel(roster))

	var selected := Game.troop_by_id(main.ui["selected_troop"])
	if not selected.is_empty():
		col.add_child(_upgrade_panel(selected))


## Short "Strong vs X · Weak vs Y" line for an element.
static func matchup_text(element: String) -> String:
	return "Strong vs %s · Weak vs %s" % [GameData.strong_against(element).capitalize(), GameData.weak_against(element).capitalize()]


func _summon_card(type: String) -> Control:
	var d: Dictionary = GameData.TROOPS[type]
	var lock := Game.troop_lock_reason(type)
	var box := UI.vbox(6)
	var img := UI.icon(d["img"], 88)
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
	var head := UI.hbox(10)
	head.add_child(UI.icon(d["img"], 64))
	var titles := UI.vbox(2)
	titles.add_child(UI.label("%s #%d" % [d["name"], troop["id"]], "Title"))
	if d["element"] != "":
		titles.add_child(UI.label(matchup_text(d["element"]), "Small"))
	head.add_child(titles)
	box.add_child(head)

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
		b.icon = UI.tex("icon_" + el)
		b.add_theme_constant_override("icon_max_width", 24)
		b.disabled = not Game.can_infuse(troop["id"], el)["ok"]
		row.add_child(b)
		box.add_child(row)
	return UI.panel(box)


func _on_troop_pressed(id: int) -> void:
	main.ui["selected_troop"] = -1 if main.ui["selected_troop"] == id else id
	main.render()


func _on_cell_clicked(cell: FormationCell) -> void:
	var sel: int = main.ui["selected_troop"]
	if sel >= 0:
		main.ui["selected_troop"] = -1
		Game.place_troop(sel, cell.row, cell.lane)
		main.render()
	elif not cell.troop.is_empty():
		Game.place_troop(-1, cell.row, cell.lane)
