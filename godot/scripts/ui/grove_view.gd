extends ScrollContainer
## Grove: the tree, collecting production, growth and tree-part upgrades.

const SAP_POP := Color("#F5821F")  # orange "+1" for trunk taps (sunlight pops are yellow)
const STAGES := [[35, "World Tree"], [20, "Elder Tree"], [10, "Grown Tree"], [5, "Young Tree"], [1, "Sapling"]]

var main: Control
var _pending_sun: Label
var _pending_sap: Label


func _init(p_main: Control) -> void:
	main = p_main
	horizontal_scroll_mode = SCROLL_MODE_DISABLED


func _ready() -> void:
	var s: Dictionary = Game.state
	var tree: Dictionary = s["tree"]
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := UI.vbox(16)
	margin.add_child(col)

	# Tree, tap hint and collection.
	var tree_box := UI.vbox(10)
	tree_box.add_child(_inventory_row())
	var art := TreeArt.new(tree)
	art.tapped.connect(_on_tap)
	tree_box.add_child(art)
	var hint := UI.hbox(6)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	for part in [["Tap the branches", "icon_sunlight", GameData.TAP_SUNLIGHT, UI.SUN], ["· the trunk", "icon_sap", GameData.TAP_SAP, SAP_POP]]:
		var text := UI.label(part[0], "Heading")
		text.add_theme_color_override("font_color", part[3])
		hint.add_child(text)
		hint.add_child(UI.icon(part[1], 24))
		var amt := UI.label("+%d" % part[2], "Heading")
		amt.add_theme_color_override("font_color", part[3])
		hint.add_child(amt)
	tree_box.add_child(hint)

	var pending := UI.hbox(24)
	pending.alignment = BoxContainer.ALIGNMENT_CENTER
	_pending_sun = UI.label("", "Title")
	_pending_sap = UI.label("", "Title")
	for pair in [["icon_sunlight", _pending_sun], ["icon_sap", _pending_sap]]:
		var p := UI.hbox(6)
		p.add_child(UI.icon(pair[0], 30))
		p.add_child(pair[1])
		pending.add_child(p)
	var collect := UI.button("Collect", Game.collect, "PrimaryButton")
	collect.custom_minimum_size.x = 200
	pending.add_child(collect)
	tree_box.add_child(pending)
	var note := UI.label("Stores up to 24 hours of production.", "Small")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tree_box.add_child(note)
	col.add_child(UI.panel(tree_box))

	# Growth.
	var need := GameData.xp_to_next(tree["level"])
	var g := UI.vbox(10)
	var title := UI.hbox(8)
	title.add_child(UI.label(_stage_name(tree["level"]), "Title"))
	title.add_child(UI.label("· Level %d" % tree["level"], "Muted"))
	g.add_child(title)
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = tree["xp"]
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	g.add_child(bar)
	g.add_child(UI.label("%d / %d sunlight. Channel sunlight or win battles to grow. Each tree part can be upgraded up to the tree's level."
		% [tree["xp"], need], "Small", true))
	var ch_max := UI.button("Channel to next level", Game.channel.bind(-1))
	ch_max.size_flags_horizontal = SIZE_EXPAND_FILL
	g.add_child(ch_max)
	var r := Game.rates()
	for pair in [["icon_sunlight", "%d sunlight / min" % r["sunlight"]], ["icon_sap", "%d sap / min" % r["sap"]]]:
		var row := UI.hbox(8)
		row.add_child(UI.icon(pair[0], 26))
		row.add_child(UI.label(pair[1]))
		g.add_child(row)
	col.add_child(UI.panel(g))

	for part in GameData.PART_ORDER:
		col.add_child(_part_card(part))
	live()


# Inventory button, plus the potions readied for the next battle.
func _inventory_row() -> Control:
	var row := UI.hbox(8)
	var total := 0
	for id in GameData.ITEM_ORDER:
		total += Game.item_count(id)
	var inv := UI.button("Inventory (%d)" % total, main.open_inventory)
	inv.icon = UI.tex("icon_inventory")
	inv.add_theme_constant_override("icon_max_width", 30)
	row.add_child(inv)
	row.add_child(UI.spacer())
	var queued: Array = Game.state["queued_potions"]
	if not queued.is_empty():
		row.add_child(UI.label("Next battle:", "Small"))
		for id in queued:
			row.add_child(UI.icon(GameData.ITEMS[id]["img"], 32))
	return row


func _stage_name(lvl: int) -> String:
	for st in STAGES:
		if lvl >= st[0]:
			return st[1]
	return "Sapling"


func _part_card(part: String) -> Control:
	var s: Dictionary = Game.state
	var lvl: int = s["tree"][part]
	var check := Game.can_upgrade(part)
	var box := UI.vbox(8)
	var head := UI.hbox(8)
	head.add_child(UI.label(GameData.PARTS[part]["name"], "Heading"))
	head.add_child(UI.label("Lv %d" % lvl, "Muted"))
	head.add_child(UI.spacer())
	var effect := UI.label("%s → %s" % [GameData.part_effect(part, lvl), GameData.part_effect(part, lvl + 1)], "Small")
	effect.add_theme_color_override("font_color", UI.INK)
	head.add_child(effect)
	box.add_child(head)
	box.add_child(UI.label(GameData.PARTS[part]["blurb"], "Small", true))
	var row := UI.hbox(10)
	row.add_child(UI.cost_row(Game.part_cost(part), s["resources"]))
	row.add_child(UI.spacer())
	var up := UI.button("Upgrade", Game.upgrade_part.bind(part))
	up.disabled = not check["ok"]
	row.add_child(up)
	box.add_child(row)
	if lvl >= s["tree"]["level"]:
		box.add_child(UI.label("Needs tree level %d." % (lvl + 1), "Hint"))
	return UI.panel(box)


func _on_tap(at: Vector2, part: String) -> void:
	if part == "trunk":
		Game.tap_trunk()
		main.pop_text("+%d" % GameData.TAP_SAP, at, SAP_POP)
	else:
		Game.tap_branches()
		main.pop_text("+%d" % GameData.TAP_SUNLIGHT, at, UI.ROOT_GLOW)


## Called every second by the shell to refresh production counters.
func live() -> void:
	_pending_sun.text = UI.fmt(Game.state["pending"]["sunlight"])
	_pending_sap.text = UI.fmt(Game.state["pending"]["sap"])
