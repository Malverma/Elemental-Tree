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


func _level_info(id: String) -> Control:
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
			var pic := UI.icon(e["img"], 44)
			if not known:
				pic.modulate = Color(0, 0, 0, 0.55)  # silhouette until met in battle
			chip.add_child(pic)
			var name_l := UI.label((e["name"] if known else "???") + (" (boss)" if e.get("boss", false) else ""))
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

	box.add_child(UI.label("Expedition", "Heading"))
	box.add_child(UI.label("Fight endless, ever-stronger waves of this land's foes for growth, potions and garden seeds. Every %d waves a boss guards a checkpoint where you can head home with your loot. If the squad falls or retreats before then, the loot is lost, and fallen troops are gone for good."
		% GameData.EXPEDITION_CHECKPOINT, "Small", true))
	box.add_child(UI.button("Start expedition", main.start_battle.bind(id, true)))
	return box


func live() -> void:
	if _stored:
		_stored.text = str(floori(Game.level_state(main.ui["selected_level"])["stored"]))
