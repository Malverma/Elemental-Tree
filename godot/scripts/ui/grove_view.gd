extends Control
## Grove: the tree, full screen. Tap the leaves for sunlight and the trunk for sap;
## swipe up for growth, tree-part upgrades and the inventory.

const SAP_POP := Color("#F5821F")  # orange "+1" for trunk taps (sunlight pops are yellow)
const STAGES := [[35, "World Tree"], [20, "Elder Tree"], [10, "Grown Tree"], [5, "Young Tree"], [1, "Sapling"]]

var main: Control
var _scene: GroveScene
var _margin: MarginContainer
var _title: Label
var _pending_sun: Label
var _pending_sap: Label


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_set_scene()
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(PRESET_FULL_RECT)
	_margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_margin)
	var col := UI.vbox(4)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_margin.add_child(col)

	_title = UI.label("", "SceneTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var hint := UI.hbox(6)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	for part in [["Tap the leaves", "icon_sunlight", GameData.TAP_SUNLIGHT], ["· the trunk", "icon_sap", GameData.TAP_SAP]]:
		hint.add_child(UI.label(part[0], "SceneSmall"))
		hint.add_child(UI.icon(part[1], 22))
		hint.add_child(UI.label("+%d" % part[2], "SceneSmall"))
	col.add_child(hint)

	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(gap)

	# Production waiting at the tree, with a Collect button.
	var pill := UI.hbox(10)
	_pending_sun = UI.label("", "Scene")
	_pending_sap = UI.label("", "Scene")
	for pair in [["icon_sunlight", _pending_sun], ["icon_sap", _pending_sap]]:
		pill.add_child(UI.icon(pair[0], 30))
		pill.add_child(pair[1])
	var collect := UI.button("Collect", Game.collect, "PrimaryButton")
	collect.custom_minimum_size.x = 150
	pill.add_child(collect)
	var row := UI.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(UI.panel(pill, "Pill"))
	col.add_child(row)
	refresh()


func _set_scene() -> void:
	if _scene:
		_scene.queue_free()
	_scene = GroveScene.new(GroveScene.stage_for(Game.state["tree"]["level"]))
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.tapped.connect(_on_tap)
	add_child(_scene)
	move_child(_scene, 0)


## Keeps the overlay clear of the shell's top bar and page indicator.
func apply_insets(top: float, bottom: float) -> void:
	_margin.add_theme_constant_override("margin_top", int(top) + 8)
	_margin.add_theme_constant_override("margin_bottom", int(bottom) + 8)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	var tree: Dictionary = Game.state["tree"]
	if GroveScene.stage_for(tree["level"]) != _scene.stage:
		_set_scene()
	_title.text = "%s · Lv %d" % [_stage_name(tree["level"]), tree["level"]]
	live()


func sheet_title() -> String:
	return "Upgrades"


## Growth, rates, tree-part upgrades and the inventory, shown in the pull-up sheet.
func build_sheet() -> Control:
	var s: Dictionary = Game.state
	var tree: Dictionary = s["tree"]
	var col := UI.vbox(16)
	col.add_child(_inventory_row())

	var need := Game.growth_needed()
	var maxed: bool = tree["level"] >= GameData.MAX_LEVEL
	var g := UI.vbox(10)
	var title := UI.hbox(8)
	title.add_child(UI.label(_stage_name(tree["level"]), "Title"))
	title.add_child(UI.label("· Level %d" % tree["level"], "Muted"))
	if tree["prestige"] > 0:
		title.add_child(UI.spacer())
		title.add_child(UI.label("Prestige %d · ×%.1f" % [tree["prestige"], Game.prestige_mult()], "Muted"))
	g.add_child(title)
	var bar := ProgressBar.new()
	bar.max_value = need
	bar.value = tree["xp"]
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	g.add_child(bar)
	if maxed:
		g.add_child(UI.label("%d / %d sunlight. The tree is fully grown. Prestige to return it to level 0 with +%d%% growth, sunlight and sap production and troop HP and damage."
			% [tree["xp"], need, roundi(GameData.PRESTIGE_BONUS * 100)], "Small", true))
	else:
		g.add_child(UI.label("%d / %d sunlight. Channel sunlight or win battles to grow. Each tree part can be upgraded up to the tree's level."
			% [tree["xp"], need], "Small", true))
	var ch_max := UI.button("Prestige" if maxed else "Channel to next level", Game.channel.bind(-1))
	ch_max.size_flags_horizontal = SIZE_EXPAND_FILL
	g.add_child(ch_max)
	var r := Game.rates()
	for pair in [["icon_sunlight", "%d sunlight / min" % r["sunlight"]], ["icon_sap", "%d sap / min" % r["sap"]]]:
		var row := UI.hbox(8)
		row.add_child(UI.icon(pair[0], 26))
		row.add_child(UI.label(pair[1]))
		g.add_child(row)
	g.add_child(UI.label("The tree stores up to 24 hours of production.", "Small"))
	col.add_child(UI.panel(g))

	for part in GameData.PART_ORDER:
		col.add_child(_part_card(part))
	return col


# Inventory button, plus the potions readied for the next battle.
func _inventory_row() -> Control:
	var row := UI.hbox(8)
	var total := 0
	for id in GameData.ITEM_ORDER:
		total += Game.item_count(id)
	var inv := UI.button("Inventory (%d)" % total, main.open_inventory)
	inv.icon = UI.crisp("icon_inventory")
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
	if lvl >= GameData.MAX_LEVEL:
		box.add_child(UI.label("Fully grown.", "Hint"))
	elif lvl >= s["tree"]["level"]:
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
