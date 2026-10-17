extends ScrollContainer
## World map with the selected level's details underneath.

var main: Control
var _stored: Label


func _init(p_main: Control) -> void:
	main = p_main
	horizontal_scroll_mode = SCROLL_MODE_DISABLED


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := UI.vbox(16)
	margin.add_child(col)

	var map_box := UI.vbox(8)
	var canvas := MapCanvas.new(main.ui["selected_level"])
	canvas.level_selected.connect(func(id: String) -> void:
		main.ui["selected_level"] = id
		main.render())
	map_box.add_child(canvas)
	map_box.add_child(UI.label("Roots reach distance %d. Upgrade the roots in the Grove to reach farther lands." % Game.reach(), "Small", true))
	col.add_child(UI.panel(map_box))
	col.add_child(UI.panel(_level_info(main.ui["selected_level"])))
	live()


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
	drops.add_child(UI.icon(GameData.SEEDS["sapling"]["img"], 28))
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
	if id == "grove":
		return _grove_info()
	var l: Dictionary = GameData.LEVELS[id]
	var ls := Game.level_state(id)
	var box := UI.vbox(10)
	var head := UI.hbox(10)
	head.add_child(UI.icon("icon_" + l["element"], 34))
	head.add_child(UI.label(l["name"], "Title"))
	box.add_child(head)
	box.add_child(UI.label("%s · %s · Root distance %d" % [l["biome"], UI.capitalize(l["element"]), l["distance"]], "Muted"))
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
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var seen := {}
	for w in l["waves"]:
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
	box.add_child(flow)
	box.add_child(UI.label("%d waves + boss wave. Troops don't heal between waves." % (l["waves"].size() - 1), "Small", true))

	var counter := GameData.weak_against(l["element"])
	var tip := UI.hbox(6)
	tip.add_child(UI.label("Tip: %s troops hit these foes hard" % counter.capitalize(), "Small"))
	tip.add_child(UI.icon("icon_" + counter, 24))
	box.add_child(tip)

	box.add_child(UI.label("Rewards", "Heading"))
	var r: Dictionary = l["rewards"]
	var el: String = l["element"]
	box.add_child(UI.label("First clear: %d growth, %d sap, %d %s power" % [r["first_xp"], r["sap"], GameData.power_reward(id, true), el], "", true))
	box.add_child(UI.label("Replays: %d growth, %d sap, %d %s power" % [r["xp"], r["sap"], GameData.power_reward(id, false), el], "", true))
	box.add_child(UI.label("Once conquered: %d %s power per day" % [l["daily_yield"], el], "", true))

	if ls["conquered"]:
		var row := UI.hbox(8)
		row.add_child(UI.icon("icon_" + l["element"], 28))
		row.add_child(UI.label("Stored:"))
		_stored = UI.label("", "Heading")
		row.add_child(_stored)
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


func live() -> void:
	if _stored:
		_stored.text = str(floori(Game.level_state(main.ui["selected_level"])["stored"]))
