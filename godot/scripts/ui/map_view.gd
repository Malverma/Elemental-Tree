extends Control
## World map, full screen. Tap a land, the Home Grove or a dungeon to select it;
## the card at the bottom has its main action, and the pull-up sheet the details.

var main: Control
var _scene: MapScene
var _margin: MarginContainer
var _reach: Label
var _dungeon_timer: Label
var _card_row: HBoxContainer
var _insets := Vector2.ZERO
var _stored: Label
var _sheet_stored: Label  # the stored count in the details sheet


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_scene = MapScene.new(main.ui["selected_level"])
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.level_selected.connect(func(id: String) -> void:
		main.ui["selected_level"] = id
		main.render())
	add_child(_scene)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(PRESET_FULL_RECT)
	_margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_margin)
	var col := UI.vbox(2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_margin.add_child(col)
	_reach = UI.label("", "SceneSmall")
	_reach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_reach)
	_dungeon_timer = UI.label("", "SceneSmall")
	_dungeon_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_dungeon_timer)
	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_card_row = UI.hbox(0)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_card_row)
	_card_row.resized.connect(_fit_map)
	_reach.resized.connect(_fit_map)
	refresh()


## Keeps the overlay clear of the shell's top bar and page indicator; the map
## itself fits in the space between them.
func apply_insets(top: float, bottom: float) -> void:
	_margin.add_theme_constant_override("margin_top", int(top) + 4)
	_margin.add_theme_constant_override("margin_bottom", int(bottom) + 8)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_insets = Vector2(top, bottom)
	_fit_map()


# The map fits between the hint at the top and the card at the bottom, so no land hides behind them.
func _fit_map() -> void:
	_scene.set_insets(_insets.x + 4 + _reach.size.y, _insets.y + 12 + _card_row.size.y)


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	var id: String = main.ui["selected_level"]
	if id.begins_with("dungeon_") and Game.dungeon(id).is_empty():
		id = "grove"  # a cleared dungeon crumbles
		main.ui["selected_level"] = id
	_scene.set_selected(id)
	_reach.text = "Roots reach %d" % Game.reach()
	_build_card(id)
	live()


func sheet_title() -> String:
	return "Details"


## Everything about the selected spot, shown in the pull-up sheet.
func build_sheet() -> Control:
	return _level_info(main.ui["selected_level"])


# A floating card for the selection: its name, how it stands, and what you can do there.
func _build_card(id: String) -> void:
	for c in _card_row.get_children():
		c.queue_free()
	_stored = null
	var title := ""
	var status := ""
	var buttons: Array[Button] = []
	var hint := ""
	if id == "grove":
		title = "Home Grove"
		status = "Expeditions set out from here."
		var check := Game.can_start_expedition()
		var start := UI.button("Start expedition", main.start_expedition, "PrimaryButton")
		start.disabled = not check["ok"]
		buttons.append(start)
		hint = "" if check["ok"] else check["msg"]
	elif id.begins_with("dungeon_"):
		var d := Game.dungeon(id)
		title = GameData.DUNGEON_NAMES[d["element"]]
		status = "Dungeon · %s · Reach %d" % [UI.capitalize(d["element"]), d["distance"]]
		var enter := Game.can_enter_dungeon(id)
		var go := UI.button("Enter dungeon", main.start_dungeon.bind(id), "PrimaryButton")
		go.disabled = not enter["ok"]
		buttons.append(go)
		hint = "" if enter["ok"] else enter["msg"]
	else:
		var l: Dictionary = GameData.LEVELS[id]
		var ls := Game.level_state(id)
		title = l["name"]
		if not l["playable"]:
			status = "Coming soon"
		else:
			status = "%s · Reach %d" % [" + ".join(l["elements"].map(UI.capitalize)), l["distance"]]
			if ls["conquered"]:
				status += " · Conquered"
				buttons.append(UI.button("Collect", Game.collect_level.bind(id)))
			elif not Game.can_reach(id):
				status += " · Out of reach"
			var enter := Game.can_enter(id)
			var attack := UI.button("Battle again" if ls["conquered"] else "Attack", main.start_battle.bind(id), "PrimaryButton")
			attack.disabled = not enter["ok"]
			buttons.append(attack)
			hint = "" if enter["ok"] else enter["msg"]

	var row := UI.hbox(12)
	var text := UI.vbox(2)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.add_child(UI.label(title, "Scene"))
	var sub := UI.label(status, "SceneSmall", true)
	text.add_child(sub)
	if GameData.LEVELS.has(id) and Game.level_state(id)["conquered"]:
		_stored = UI.label("", "SceneSmall")
		text.add_child(_stored)
	if hint != "":
		var h := UI.label(hint, "SceneSmall", true)
		h.add_theme_color_override("font_color", Color("#FFB3A8"))
		text.add_child(h)
	row.add_child(text)
	var col := UI.vbox(6)
	for b in buttons:
		col.add_child(b)
	row.add_child(col)
	var card := UI.panel(row, "Pill")
	card.custom_minimum_size.x = 660
	_card_row.add_child(card)


# The Home Grove: where expeditions set out from.
func _grove_info() -> Control:
	var box := UI.vbox(10)
	var head := UI.hbox(10)
	head.add_child(UI.icon("icon_nature", 34))
	head.add_child(UI.label("Home Grove", "Title"))
	box.add_child(head)
	box.add_child(UI.label("Your tree's home. Expeditions set out from here.", "Muted", true))

	box.add_child(UI.label("Expedition", "Heading"))
	box.add_child(UI.label("Fight endless, ever-stronger waves for loot. Every %d waves share one element, and each stretch ends with that element's boss at a checkpoint where you can head home with your loot. If the squad falls or retreats before then, the loot is lost, and fallen troops are gone for good."
		% GameData.EXPEDITION_CHECKPOINT, "", true))

	box.add_child(UI.label("Element order", "Heading"))
	var order := HFlowContainer.new()
	order.add_theme_constant_override("h_separation", 8)
	order.add_theme_constant_override("v_separation", 8)
	for i in GameData.ELEMENTS.size():
		var el := GameData.expedition_element(i * GameData.EXPEDITION_CHECKPOINT)
		var chip := UI.hbox(6)
		chip.add_child(UI.icon("icon_" + el, 26))
		chip.add_child(UI.label("Waves %d–%d" % [i * GameData.EXPEDITION_CHECKPOINT + 1, (i + 1) * GameData.EXPEDITION_CHECKPOINT], "Small"))
		order.add_child(UI.panel(chip, "Card"))
	box.add_child(order)
	box.add_child(UI.label("Then the cycle repeats, stronger each time.", "Small", true))

	box.add_child(UI.label("Rewards", "Heading"))
	box.add_child(UI.label("• Growth for every wave cleared (double for bosses)", "", true))
	box.add_child(UI.label("• %d elemental power for each foe defeated, of that foe's element" % GameData.EXPEDITION_KILL_POWER, "", true))
	var drops := UI.hbox(6)
	drops.add_child(UI.label("• Potions and garden seeds"))
	drops.add_child(UI.icon(GameData.ITEMS["thorn_draught"]["img"], 28))
	drops.add_child(UI.icon(GameData.SEEDS["sapling"]["img"], 32))
	box.add_child(drops)
	box.add_child(UI.label("Each boss checkpoint always drops a potion and a seed.", "Small", true))

	var check := Game.can_start_expedition()
	var start := UI.button("Start expedition", main.start_expedition, "PrimaryButton")
	start.disabled = not check["ok"]
	box.add_child(start)
	if not check["ok"]:
		box.add_child(UI.label(check["msg"], "Hint"))
	return box


func _level_info(id: String) -> Control:
	if id.begins_with("dungeon_"):
		var d := Game.dungeon(id)
		# A cleared dungeon crumbles; fall back to the grove.
		return _grove_info() if d.is_empty() else _dungeon_info(id, d)
	if id == "grove":
		return _grove_info()
	var l: Dictionary = GameData.LEVELS[id]
	var ls := Game.level_state(id)
	var box := UI.vbox(10)
	var head := UI.hbox(10)
	for el in l["elements"]:
		head.add_child(UI.icon("icon_" + el, 34))
	head.add_child(UI.label(l["name"], "Title", true))
	box.add_child(head)
	box.add_child(UI.label("%s · %s · Root distance %d" % [l["biome"], " + ".join(l["elements"].map(UI.capitalize)), l["distance"]], "Muted", true))
	if not l["playable"]:
		box.add_child(UI.label("This land is still being prepared. Coming in a future build.", "", true))
		return box

	var status := "Out of reach"
	if ls["conquered"]:
		status = "Conquered (%d clear%s)" % [ls["clears"], "" if ls["clears"] == 1 else "s"]
	elif Game.can_reach(id):
		status = "Rooted, ready to attack"
	box.add_child(UI.label("Status: " + status))

	box.add_child(UI.label("Enemies", "Heading"))
	box.add_child(_enemy_chips(l["waves"]))
	box.add_child(UI.label("%d waves + boss wave. Troops don't heal between waves." % (l["waves"].size() - 1), "Small", true))

	for el in l["elements"]:
		var counter := GameData.weak_against(el)
		var tip := UI.hbox(6)
		tip.add_child(UI.label("Tip: %s troops hit %s foes hard" % [counter.capitalize(), el], "Small"))
		tip.add_child(UI.icon("icon_" + counter, 24))
		box.add_child(tip)
	if l["elements"].size() > 1:
		box.add_child(UI.label("Wild twigs guard this land: rival elemental troops, as tough as your own.", "Small", true))

	box.add_child(UI.label("Rewards", "Heading"))
	var r: Dictionary = l["rewards"]
	var el := GameData.elements_text(id)
	box.add_child(UI.label("First clear: %d growth, %d sap, %d %s power" % [r["first_xp"], r["sap"], GameData.power_reward(id, true), el], "", true))
	box.add_child(UI.label("Replays: %d growth, %d sap, %d %s power" % [r["xp"], r["sap"], GameData.power_reward(id, false), el], "", true))
	box.add_child(UI.label("Once conquered: %d %s power per day" % [l["daily_yield"], el], "", true))

	if ls["conquered"]:
		var row := UI.hbox(8)
		for e in l["elements"]:
			row.add_child(UI.icon("icon_" + e, 28))
		row.add_child(UI.label("Stored:"))
		_sheet_stored = UI.label(str(floori(ls["stored"])), "Heading")
		row.add_child(_sheet_stored)
		row.add_child(UI.label("/ %d" % l["daily_yield"]))
		row.add_child(UI.spacer())
		row.add_child(UI.button("Collect", Game.collect_level.bind(id)))
		box.add_child(row)

	var enter := Game.can_enter(id)
	var attack := UI.button("Battle again" if ls["conquered"] else "Attack", main.start_battle.bind(id), "PrimaryButton")
	attack.disabled = not enter["ok"]
	box.add_child(attack)
	if not enter["ok"]:
		box.add_child(UI.label(enter["msg"], "Hint"))
	return box


# One chip per kind of foe in `waves`.
func _enemy_chips(waves: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var seen := {}
	for w in waves:
		for key in w:
			if seen.has(key):
				continue
			seen[key] = true
			var e: Dictionary = GameData.ENEMIES[key]
			var known := Game.has_seen_enemy(key)
			var chip := UI.hbox(6)
			if known:
				chip.add_child(UI.icon(e["img"], 44))
			else:
				# Blank until met in battle: no picture, name or boss tag.
				var blank := UI.label("?", "Title")
				blank.custom_minimum_size = Vector2(44, 44)
				blank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				blank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				chip.add_child(blank)
			var name_l := UI.label((e["name"] + (" (boss)" if e.get("boss", false) else "")) if known else "???")
			name_l.add_theme_font_size_override("font_size", 20)
			chip.add_child(name_l)
			flow.add_child(UI.panel(chip, "Card"))
	return flow


func _dungeon_info(id: String, d: Dictionary) -> Control:
	var el: String = d["element"]
	var box := UI.vbox(10)
	var head := UI.hbox(10)
	head.add_child(UI.icon(MapScene.dungeon_art(d), 39))
	head.add_child(UI.label(GameData.DUNGEON_NAMES[el], "Title", true))
	box.add_child(head)
	var sub := UI.hbox(6)
	sub.add_child(UI.label("Dungeon · %s · Root distance %d" % [UI.capitalize(el), d["distance"]], "Muted", true))
	sub.add_child(UI.icon("icon_" + el, 24))
	box.add_child(sub)
	box.add_child(UI.label("A dungeon has opened up. Clear it before it's gone: once cleared it crumbles, and a new one appears somewhere on the map %d minutes later." % GameData.DUNGEON_RESPAWN_MINUTES, "", true))

	box.add_child(UI.label("Enemies", "Heading"))
	box.add_child(_enemy_chips(d["waves"]))
	box.add_child(UI.label("%d waves + boss wave. Troops don't heal between waves." % (d["waves"].size() - 1), "Small", true))
	var counter := GameData.weak_against(el)
	var tip := UI.hbox(6)
	tip.add_child(UI.label("Tip: %s troops hit %s foes hard" % [counter.capitalize(), el], "Small"))
	tip.add_child(UI.icon("icon_" + counter, 24))
	box.add_child(tip)

	box.add_child(UI.label("Rewards", "Heading"))
	var n := GameData.dungeon_reward_count(d["distance"])
	var potions := UI.hbox(6)
	potions.add_child(UI.label("• %d random potion%s" % [n, "" if n == 1 else "s"]))
	potions.add_child(UI.icon(GameData.ITEMS["thorn_draught"]["img"], 28))
	box.add_child(potions)
	var seeds := UI.hbox(6)
	seeds.add_child(UI.label("• %d garden seed%s" % [n, "" if n == 1 else "s"]))
	seeds.add_child(UI.icon(GameData.SEEDS[el]["img"], 32))
	if not Game.garden_unlocked():
		seeds.add_child(UI.label("(after the tree's first prestige)", "Hint"))
	box.add_child(seeds)

	var enter := Game.can_enter_dungeon(id)
	var attack := UI.button("Enter dungeon", main.start_dungeon.bind(id), "PrimaryButton")
	attack.disabled = not enter["ok"]
	box.add_child(attack)
	if not enter["ok"]:
		box.add_child(UI.label(enter["msg"], "Hint"))
	return box


func live() -> void:
	var wait := Game.next_dungeon_in()
	_dungeon_timer.visible = wait >= 0.0
	if wait >= 0.0:
		_dungeon_timer.text = "Next dungeon appears in %d:%02d" % [int(wait) / 60, int(wait) % 60]
	if is_instance_valid(_sheet_stored):
		_sheet_stored.text = str(floori(Game.level_state(main.ui["selected_level"])["stored"]))
	if _stored:
		var id: String = main.ui["selected_level"]
		_stored.text = "Stored: %d / %d power" % [floori(Game.level_state(id)["stored"]), GameData.LEVELS[id]["daily_yield"]]
