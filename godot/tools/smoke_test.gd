extends SceneTree
## Headless smoke test: builds every screen and plays through the core loop.
## Run: godot --headless --path godot --script res://tools/smoke_test.gd
## Uses a throwaway save (it resets the game state first).

var main: Control


func _frames(n := 3) -> void:
	for i in n:
		await process_frame


func _check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)


# Feeds the shell a press and release `d` apart, as a finger swipe would.
func _swipe(d: Vector2) -> void:
	var from := Vector2(360, 700)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = from if pressed else from + d
		main._input(e)


# Feeds the shell a finger dragged `d` in `steps` moves, then lifted.
# Returns the current screen's x offset at the last move, before letting go
# (INF if no neighbouring screen had come in alongside it).
func _drag(d: Vector2, steps := 8) -> float:
	var from := Vector2(360, 700)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = from
	main._input(e)
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.position = from + d * (i + 1) / steps
		m.velocity = d / steps * 60.0 * 0.2  # an unhurried drag, well under a flick
		main._input(m)
	var x: float = main._view.position.x
	var alongside: bool = main._drag_next != null
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = from + d
	main._input(up)
	return x if alongside else INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	game.state = game.new_game()
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _frames()

	for i in 25:
		game.tap_branches()
	_check(game.state["resources"]["sunlight"] == 25, "25 taps give 25 sunlight")
	for i in 10:
		game.tap_trunk()
	_check(game.state["resources"]["sap"] == 10, "10 trunk taps give 10 sap")
	var cycle_ok := true
	for pair in [["nature", "water", "dark"], ["water", "fire", "nature"], ["fire", "ice", "water"], ["ice", "dark", "fire"], ["dark", "nature", "ice"]]:
		cycle_ok = cycle_ok and GameData.element_multiplier(pair[0], pair[1]) > 1.0 and GameData.element_multiplier(pair[0], pair[2]) < 1.0 \
			and GameData.strong_against(pair[0]) == pair[1] and GameData.weak_against(pair[0]) == pair[2]
	_check(cycle_ok, "nature beats water, water fire, fire ice, ice dark, dark nature")
	var taps_ok := true
	for lvl in range(0, GameData.MAX_LEVEL + 1):
		var taps: float = GameData.xp_to_next(lvl + 1) / float(GameData.tap_sunlight(lvl))
		taps_ok = taps_ok and absf(taps - GameData.TAPS_PER_GROWTH) <= GameData.TAPS_PER_GROWTH * 0.15
	_check(taps_ok, "tap sunlight keeps pace with growth (~%d taps a level at every tapping level)" % GameData.TAPS_PER_GROWTH)
	game.state["tree"]["tap"] = 1
	var sun_before: float = game.state["resources"]["sunlight"]
	var sap_before: float = game.state["resources"]["sap"]
	game.tap_branches()
	game.tap_trunk()
	_check(game.state["resources"]["sunlight"] - sun_before == GameData.tap_sunlight(1) and GameData.tap_sunlight(1) > 1
		and game.state["resources"]["sap"] - sap_before == GameData.tap_sap(1), "tapping level 1 gives more per tap")
	game.state["tree"]["tap"] = 0
	game.state["resources"]["sunlight"] = sun_before
	game.state["resources"]["sap"] = sap_before
	var old_tree: Dictionary = JSON.parse_string(JSON.stringify(game.state))
	old_tree["tree"].erase("tap")
	_check(game._normalize(old_tree)["tree"]["tap"] == 0, "older saves start with tapping at level 0")
	old_tree["items"] = {"growth_tonic": 2}
	old_tree["queued_potions"] = ["growth_tonic"]
	var swapped: Dictionary = game._normalize(old_tree)
	_check(swapped["items"] == {"reach_tonic": 2} and swapped["queued_potions"] == ["reach_tonic"], "old growth tonics become longreach tonics")

	# Tapped grove birds leave sap or sunlight for the tree's level, power of a conquered element, or rarely a potion.
	var bird_kinds := {}
	var res0: Dictionary = game.state["resources"].duplicate(true)
	var items0: Dictionary = game.state["items"].duplicate()
	var levels0: Dictionary = game.state["levels"].duplicate(true)
	game.state["levels"]["sunny_meadow"] = {"conquered": true, "stored": 0.0, "clears": 1}
	var bird_ok := true
	for i in 300:
		var sap0: float = game.state["resources"]["sap"]
		var sun0: float = game.state["resources"]["sunlight"]
		var drop: Dictionary = game.tap_bird()
		bird_kinds[drop["kind"]] = true
		if drop["kind"] == "sap":
			bird_ok = bird_ok and game.state["resources"]["sap"] - sap0 == GameData.bird_sap(game.state["tree"]["level"])
		elif drop["kind"] == "sunlight":
			bird_ok = bird_ok and game.state["resources"]["sunlight"] - sun0 == GameData.bird_sunlight(game.state["tree"]["level"])
		elif drop["kind"] == "power":
			bird_ok = bird_ok and drop["id"] == "nature"
	_check(bird_ok and bird_kinds.size() == 4, "tapped birds give sap or sunlight for the tree's level, conquered power or a potion (%s)" % str(bird_kinds.keys()))
	_check(GameData.bird_sap(10) > GameData.bird_sap(1) and GameData.bird_sunlight(10) > GameData.bird_sunlight(1), "bird sap and sunlight grow with the tree")
	game.state["levels"] = levels0
	_check(range(100).all(func(_i): return game.tap_bird()["kind"] != "power"), "birds give no power before a land is conquered")
	game.state["resources"] = res0
	game.state["items"] = items0
	var birds: GroveBirds = main._view._scene._birds
	var bird := birds._new_bird(0, Vector2(60, 330))
	_check(not birds.pop_at(Vector2(150, 200)) and birds.pop_at(Vector2(61, 327)) and not birds._birds.has(bird)
		and birds._feathers.size() >= 1, "a tapped bird bursts into feathers")

	game.advance(60)
	game.collect()
	game.upgrade_part("roots")
	game.upgrade_part("branches")
	# Growing past level 1 waits on conquering the reach 1 land.
	var sun_gate: float = game.state["resources"]["sunlight"]
	var gate_res: Dictionary = game.channel()
	_check(game.state["tree"]["level"] == 1 and game.state["tree"]["xp"] == game.growth_needed() and game.growth_blocked() == "sunny_meadow",
		"the tree can't grow past level 1 before the reach 1 land is conquered")
	_check(not game.channel()["ok"] and game.state["resources"]["sunlight"] == sun_gate - GameData.xp_to_next(1), "a full, blocked tree takes no more sunlight")
	game.state["levels"]["sunny_meadow"] = {"conquered": true, "stored": 0.0, "clears": 1}
	game.channel()
	game.state["levels"].erase("sunny_meadow")
	_check(gate_res["ok"] and game.state["tree"]["level"] == 2 and game.state["tree"]["roots"] == 1, "upgrades and level up once the land is conquered")
	_check(GameData.xp_to_next(1) == 300 and GameData.xp_to_next(2) == 1000 and GameData.xp_to_next(9) == 72000, "level 1 → 2 is 30 min, 2 → 3 is 1000 of sunlight, 9 → 10 is 24 h")
	_check(is_equal_approx(GameData.growth_minutes(12), GameData.STORAGE_CAP_MINUTES), "levels past 10 stay at 24 h of sunlight")
	_check(not GameData.part_cost("roots", 2).has("sap") and not GameData.part_cost("trunk", 2).has("sap"), "part upgrades to level 3 cost no sap")
	_check(GameData.part_cost("roots", 3).has("sap") and GameData.part_cost("trunk", 3).has("sap"), "part upgrades past level 3 cost sap")
	_check(GameData.part_cost("branches", 8)["sunlight"] == roundi(GameData.xp_to_next(8) * 0.2 / 5.0) * 5, "part sunlight follows the growth curve")
	_check(not game.has_seen_enemy("burrow_rabbit"), "meadow foes unknown before the first battle")

	# Swipes: left/right between screens (the locked garden isn't there yet), up/down for the sheet.
	_check(main.TABS.map(func(t): return t[0]) == ["grove", "map", "barracks", "garden"], "screens run grove, world map, barracks, garden")
	_swipe(Vector2(-300, 10))
	await _frames(25)
	_check(main.tab == "map", "swiping left from the grove opens the world map")
	main.switch_tab("barracks")
	await _frames(25)
	_swipe(Vector2(-300, 10))
	await _frames(25)
	_check(main.tab == "barracks", "the locked garden can't be swiped to")
	main.switch_tab("grove")
	await _frames(25)
	_swipe(Vector2(300, -10))
	await _frames(25)
	_check(main.tab == "grove", "swiping right returns to the grove")
	_swipe(Vector2(10, -300))
	await _frames(25)
	_check(main._sheet_open and main._sheet_body.get_child_count() == 1, "swiping up opens the upgrades sheet")
	_swipe(Vector2(-300, 0))
	await _frames(5)
	_check(main.tab == "grove", "sideways swipes don't change screens while the sheet is open")
	_swipe(Vector2(0, 300))
	await _frames(25)
	_check(not main._sheet_open, "swiping down closes the sheet")
	_swipe(Vector2(40, 30))
	_check(main.tab == "grove" and not main._sheet_open, "short drags aren't swipes")
	var held := _drag(Vector2(-120, 6))
	_check(is_equal_approx(held, -120.0) and main.tab == "grove", "a sideways drag carries the screen, its neighbour alongside")
	await create_timer(0.5).timeout
	_check(main.tab == "grove" and is_equal_approx(main._view.position.x, 0.0) and main._drag_next == null, "a short drag springs back")
	_drag(Vector2(-main.size.x * 0.4, 6))
	await create_timer(0.5).timeout
	_check(main.tab == "map" and is_equal_approx(main._view.position.x, 0.0), "a long drag moves on to the next screen")
	_drag(Vector2(main.size.x * 0.4, 0))
	await create_timer(0.5).timeout
	_check(main.tab == "grove", "dragging back returns to the grove")
	held = _drag(Vector2(300, 0))
	await create_timer(0.5).timeout
	_check(main.tab == "grove" and held == INF and is_equal_approx(main._view.position.x, 0.0), "the first screen only gives a little at the edge")
	main._pages["map"].pressed.emit()
	await _frames(25)
	_check(main.tab == "map", "tapping a screen's name opens it")
	main._pages["grove"].pressed.emit()
	await _frames(25)
	_check(main.tab == "grove" and not main._pages["garden"].visible, "the garden's name stays hidden until it opens")

	main.switch_tab("barracks")
	await _frames()
	game.grant_troop("soldier")
	game.grant_troop("soldier")
	game.grant_troop("spearman")
	await _frames()
	_check(game.state["formation"].size() == 3, "summoned troops auto-placed")
	var formation0: Array = game.state["formation"].duplicate(true)
	var benched: Dictionary = formation0[0]
	main._view._drop_on_roster(Vector2.ZERO, {"barracks_pad": true, "row": benched["row"], "lane": benched["lane"]})
	_check(game.state["formation"].size() == 2 and game.troop_by_id(benched["troop_id"]), "dragging a troop onto the roster takes it out of the formation")
	game.state["formation"] = formation0
	await _frames()
	var spare_id: int = game.state["troops"][-1]["id"]
	game.grant_troop("soldier")
	var gone_id: int = game.state["troops"][-1]["id"]
	main._view._drop_on_fire(Vector2.ZERO, {"roster_troop": gone_id})
	_check(game.troop_by_id(gone_id).is_empty() and game.troop_by_id(spare_id), "dropping a troop on the campfire dismisses it")
	await _frames()

	var f: Array = game.state["formation"]
	var front_id: int = f[0]["troop_id"]
	game.move_troop("front", 1, "back", 2)
	_check(game.troop_by_id(front_id) and game._cell("back", 2)["troop_id"] == front_id, "move to empty slot")
	var mid_id: int = game._cell("middle", 1)["troop_id"]
	game.move_troop("back", 2, "middle", 1)
	_check(game._cell("middle", 1)["troop_id"] == front_id and game._cell("back", 2)["troop_id"] == mid_id, "drop on occupied slot swaps")
	game.move_troop("middle", 1, "front", 1)
	await _frames()

	main.switch_tab("map")
	await _frames()
	main.start_battle("sunny_meadow")
	await _frames(10)
	var view: Node = main._battle
	_check(view != null, "battle opened")
	var speeds := []
	for i in 3:
		view._toggle_speed()
		speeds.append(view._canvas.speed)
	_check(speeds == [2.0, 5.0, 1.0] and view._speed.text == "Speed 1×", "speed button cycles 1× → 2× → 5× → 1×")
	view._canvas.speed = 50.0
	var t := 0
	while not view.sim.is_over() and t < 2000:
		await process_frame
		t += 1
	await _frames()
	_check(view.sim.is_over(), "battle finished (%s, %d waves, %d fallen)" % [view.sim.phase, view.sim.waves_cleared, view.sim.fallen.size()])
	_check(game.level_state("sunny_meadow")["conquered"] == (view.sim.phase == "won"), "conquest recorded")
	var first_won: bool = view.sim.phase == "won"
	_check(game.has_seen_enemy("burrow_rabbit"), "foes met in battle are revealed")
	main.close_battle()
	await _frames()

	game.advance(600)
	main.render()
	await _frames()
	_check(game.level_state("sunny_meadow")["stored"] > 0 or not first_won, "conquered level produces power")

	# Element rewards: a day's yield on first clear, 3 hours' worth on replays.
	var meadow_day: int = GameData.LEVELS["sunny_meadow"]["daily_yield"]
	if first_won:
		_check(game.state["resources"]["power"]["nature"] == 0 and game.level_state("sunny_meadow")["stored"] == meadow_day,
			"first clear leaves a full day of nature power waiting to collect")
	game.state["levels"]["sunny_meadow"] = {"conquered": true, "stored": 0.0, "clears": 1}
	var before: float = game.state["resources"]["power"]["nature"]
	var replay := BattleSim.new("sunny_meadow", game.formation_troops())
	replay.phase = "won"
	replay.waves_cleared = 4
	var res: Dictionary = game.apply_battle_result(replay)
	_check(res["power"] == GameData.power_reward("sunny_meadow", false) and game.state["resources"]["power"]["nature"] == before + res["power"],
		"replay gives 3 hours of power (%d)" % res["power"])
	var water0: float = game.state["resources"]["power"]["water"]
	var spring_day: int = GameData.LEVELS["whispering_spring"]["daily_yield"]
	var first := BattleSim.new("whispering_spring", game.formation_troops())
	first.phase = "won"
	first.waves_cleared = first.level["waves"].size()
	var first_res: Dictionary = game.apply_battle_result(first)
	first.dispose()
	_check(first_res["first_clear"] and game.state["resources"]["power"]["water"] == water0 and game.level_state("whispering_spring")["stored"] == spring_day,
		"a first clear leaves a full day of power waiting at the land (%d)" % spring_day)
	main.switch_tab("map")
	await _frames()
	main._view._collect_land("whispering_spring")
	_check(game.state["resources"]["power"]["water"] == water0 + spring_day and game.level_state("whispering_spring")["stored"] < 1.0,
		"collecting it from the map adds the day's power")
	game.state["levels"].erase("whispering_spring")
	game.state["resources"]["power"]["water"] = water0

	# Elemental troops and upgrading base troops with an element.
	game.state["resources"]["sap"] = 500.0
	game.state["resources"]["power"]["nature"] = 50.0
	game.state["levels"]["sunny_meadow"]["conquered"] = true
	_check(game.troop_lock_reason("tide_caller") != "", "water troop locked before conquering a water land")
	_check("vine_lasher" in game.box_pool() and not "tide_caller" in game.box_pool(), "nature troop joins the root box by conquering the meadow")
	# The root box: sap tilts the odds, energy favours its element, opening rolls a troop.
	main.switch_tab("barracks")
	await _frames()
	var bare: Dictionary = GameData.box_odds(1, 30, "", 0, game.box_pool())
	var total := 0.0
	for type in bare["types"]:
		total += bare["types"][type]
	_check(is_equal_approx(total, 1.0), "root box odds add up to 1")
	var commons := []
	var rares := []
	for sap in [30, 75, 150]:
		var by_rarity: Dictionary = GameData.box_odds(1, sap, "", 0, GameData.BASE_TROOPS + ["vine_lasher"])["rarity"]
		commons.append(by_rarity["common"])
		rares.append(by_rarity["rare"])
	_check(commons[0] > commons[1] and commons[1] > commons[2] and rares[0] < rares[1] and rares[1] < rares[2],
		"more sap in a Root Box means fewer commons and more rares (%s / %s)" % [commons, rares])
	var fresh_odds: Dictionary = GameData.box_odds(1, 30, "", 0, GameData.BASE_TROOPS)["types"]
	var repeat_odds: Dictionary = GameData.box_odds(1, 30, "", 0, GameData.BASE_TROOPS, 0, {"soldier": 4})["types"]
	_check(repeat_odds["soldier"] < fresh_odds["soldier"] * 0.5 and repeat_odds["guard"] > fresh_odds["guard"],
		"the box turns away from troops the roster already has plenty of")
	# Bird Targeting: Branches 7 unlocks a snare branch that pops a bird each minute in the Grove.
	var branches0: int = game.state["tree"]["branches"]
	game.state["tree"]["branches"] = 6
	_check(not game.has_perk("bird_targeting"), "no Bird Targeting below Branches 7")
	game.state["tree"]["branches"] = 7
	_check(game.has_perk("bird_targeting"), "Branches 7 unlocks Bird Targeting")
	GroveScene.snare_in = 5.0
	await _frames(10)
	_check(GroveScene.snare_in == 5.0, "the snare waits while the Grove isn't open")
	main.switch_tab("grove")
	await _frames(5)
	var grove_view = main._view
	var grove_birds: GroveBirds = grove_view._scene._birds
	var spot: Vector2 = grove_birds._perch_spot()
	grove_birds._visit("tree", spot)
	var perched: Dictionary = grove_birds._birds[-1]
	perched["node"].position = spot
	perched["state"] = "sit"
	perched["stay"] = 30.0
	var stock0: float = game.state["resources"]["sap"] + game.state["resources"]["sunlight"] + game.item_count("thorn_draught") + game.item_count("bark_brew") + game.item_count("reach_tonic")
	for el in GameData.ELEMENTS:
		stock0 += game.state["resources"]["power"][el]
	GroveScene.snare_in = 0.05
	await create_timer(1.5).timeout
	var stock1: float = game.state["resources"]["sap"] + game.state["resources"]["sunlight"] + game.item_count("thorn_draught") + game.item_count("bark_brew") + game.item_count("reach_tonic")
	for el in GameData.ELEMENTS:
		stock1 += game.state["resources"]["power"][el]
	_check(not grove_birds.is_alive(perched) and stock1 > stock0 and GroveScene.snare_in > 50.0, "the snare branch pops the bird, collects its drop and waits a minute")
	game.state["tree"]["branches"] = branches0
	main.switch_tab("barracks")
	await _frames(5)
	var lvl0: int = game.state["tree"]["level"]
	var gate0: String = game.growth_gate(lvl0)
	var tree_before: Dictionary = game.state["tree"].duplicate()
	var levels_before: Dictionary = game.state["levels"].duplicate(true)
	game.dev_level_up()
	_check(game.state["tree"]["level"] == lvl0 + 1 and (gate0 == "" or game.level_state(gate0)["conquered"]) and game.state["tree"]["trunk"] == mini(tree_before["trunk"] + 1, lvl0 + 1),
		"the dev button conquers the gate land and grows the tree and its parts a level")
	game.state["tree"] = tree_before
	game.state["levels"] = levels_before
	var pool_all: Array = GameData.TROOP_ORDER
	var odds_p0: Dictionary = GameData.box_odds(1, 75, "", 0, pool_all)["rarity"]
	var odds_p5: Dictionary = GameData.box_odds(1, 75, "", 0, pool_all, 5)["rarity"]
	_check(odds_p5["rare"] > odds_p0["rare"] and odds_p5["epic"] > odds_p0["epic"] and odds_p5["common"] < odds_p0["common"], "prestige tilts root box odds toward rarer troops")
	_check(game.can_open_box()["ok"] == false, "an empty root box can't open")
	var box_sap0: float = game.state["resources"]["sap"]
	game.inject_sap()
	game.inject_sap()
	_check(game.state["twig_box"]["sap"] == 30.0 and game.state["resources"]["sap"] == box_sap0 - 30.0, "injecting sap moves it into the box")
	for i in 10:
		main._view._on_inject_sap()
	var full: Dictionary = game.box_odds()
	_check(game.state["twig_box"]["sap"] == 150.0 and full["rarity"]["rare"] > bare["rarity"]["rare"], "more sap, better odds (and the box brims)")
	game.inject_power("nature")
	game.inject_power("nature")
	_check(game.box_odds()["types"]["vine_lasher"] > full["types"]["vine_lasher"], "nature energy favours the Vine Lasher")
	_check(game.power_block("water") != "", "a second element can't go in")
	for tier in [1, 2, 3]:
		var focused: Dictionary = GameData.box_odds(tier, 0, "vine_lasher", GameData.BOX_MAX_POWER, game.box_pool())["types"]
		var sum := 0.0
		for type in focused:
			sum += focused[type]
		_check(is_equal_approx(focused["vine_lasher"], 0.95) and is_equal_approx(sum, 1.0), "10 nature energy in a tier %d box: 95%% Vine Lasher" % tier)
	game.state["resources"]["sap"] += 90.0
	game.state["twig_box"]["sap"] = 30.0
	var troops0: int = game.state["troops"].size()
	main._view._lower_at = main._view._lower.scroll_vertical
	main._view._on_box_tapped()
	var new_id: int = game.state["troops"][-1]["id"]
	_check(game.state["troops"].size() == troops0 + 1 and game.state["twig_box"]["sap"] == 0.0, "tapping the box opens it: a troop, and the box empties")
	await _frames()
	_check(main._view._token_for(new_id).modulate.a == 0.0, "the new troop's token waits while its card is out")
	await create_timer(4.5).timeout
	_check(not main._view._opening and main._view._token_for(new_id).modulate.a == 1.0, "the card drops into the roster and the box returns")
	game.state["tree"]["level"] = 3
	game.state["resources"]["sunlight"] += 300.0
	game.state["resources"]["sap"] += 250.0
	_check(game.upgrade_box()["ok"] and game.state["twig_box"]["tier"] == 2, "the box upgrades to a Bark Box")
	_check(not game.upgrade_box()["ok"], "the Heartwood Box waits for tree level 6")
	game.state["tree"]["level"] = 1
	game.state["twig_box"]["tier"] = 1
	var base_id := -1
	for troop in game.state["troops"]:
		if troop["type"] == "soldier":
			base_id = troop["id"]
	if base_id < 0:
		game.grant_troop("soldier")
		base_id = game.state["troops"][-1]["id"]
	main.ui["selected_troop"] = base_id
	main.switch_tab("barracks")
	await _frames()
	var p0: float = game.state["resources"]["power"]["nature"]
	_check(game.infuse(base_id, "nature")["ok"], "base troop upgraded with nature")
	_check(game.state["resources"]["power"]["nature"] == p0 - GameData.INFUSE_COST, "upgrade costs %d power" % GameData.INFUSE_COST)
	_check(not game.infuse(base_id, "fire")["ok"], "an upgraded troop can't change element")
	var def := GameData.troop_def(game.troop_by_id(base_id))
	_check(def["element"] == "nature" and def.has("regen") and def["hp"] > GameData.TROOPS["soldier"]["hp"], "upgraded troop gets element stats (%s, %d HP)" % [def["name"], def["hp"]])
	await _frames()

	# Every new land can be fought.
	for id in ["ember_vent", "frostbite_hollow", "gloomroot_cavern"]:
		var b := BattleSim.new(id, game.formation_troops())
		b.resolve()
		_check(b.is_over(), "%s battle runs (%s)" % [id, b.phase])
		b.dispose()

	# Expeditions: endless waves from the Home Grove with a checkpoint every 5; loot only kept on a return.
	var exp_wave := GameData.expedition_wave(4)
	_check(GameData.ENEMIES[exp_wave[0]].get("boss", false), "expedition wave 5 is a boss wave")
	var stretch_ok := true
	for w in 10:
		var want := "nature" if w < 5 else "water"
		for key in GameData.expedition_wave(w):
			stretch_ok = stretch_ok and GameData.ENEMIES[key]["element"] == want
	_check(stretch_ok and GameData.expedition_element(25) == "nature", "each 5-wave stretch shares one element, cycling")
	var kill_exp := BattleSim.new_expedition(game.formation_troops())
	for e in kill_exp.enemies:
		kill_exp._apply_damage(e, 9999.0)
	kill_exp._apply_damage(kill_exp.enemies[0], 9999.0)  # already down: no extra power
	_check(kill_exp.loot_power == {"nature": kill_exp.enemies.size()}, "each defeated foe gives 1 power of its element")
	kill_exp.dispose()
	var lost_exp := BattleSim.new_expedition(game.formation_troops())
	lost_exp.loot_xp = 999
	lost_exp.loot_items = {"reach_tonic": 2}
	lost_exp.phase = "lost"
	var xp0: int = game.state["tree"]["xp"]
	var lv0: int = game.state["tree"]["level"]
	var lost_res: Dictionary = game.apply_expedition_result(lost_exp)
	_check(not lost_res["returned"] and game.state["tree"]["xp"] == xp0 and game.state["tree"]["level"] == lv0 and game.state["items"].is_empty(),
		"a lost expedition keeps no loot")
	lost_exp.dispose()

	game.state["levels"]["sunny_meadow"]["conquered"] = true
	main.switch_tab("map")
	main.ui["selected_level"] = "grove"
	main.render()
	await _frames()
	var starts: Array = main._view.find_children("*", "Button", true, false).filter(func(b): return b.text == "Start expedition")
	_check(starts.size() == 1 and not starts[0].disabled, "Home Grove offers an expedition")
	main.ui["selected_level"] = "sunny_meadow"
	main.render()
	await _frames()
	var land_btns: Array = main._view.find_children("*", "Button", true, false).map(func(b): return b.text)
	_check("Start expedition" not in land_btns and "Battle again" in land_btns, "lands offer battles, not expeditions")
	main.start_expedition()
	await _frames(5)
	view = main._battle
	_check(view != null and view.sim.expedition, "expedition opened")
	# Make the squad sturdy so the test reliably reaches the first checkpoint.
	for u in view.sim.allies:
		u.max_hp = 9999.0
		u.hp = 9999.0
	view._canvas.speed = 50.0
	t = 0
	while view.sim.phase != "checkpoint" and not view.sim.is_over() and t < 3000:
		await process_frame
		t += 1
	await _frames()
	if view.sim.phase == "checkpoint":
		_check(view._checkpoint != null, "checkpoint offers a return home")
		var loot_xp: int = view.sim.loot_xp
		var loot_items: Dictionary = view.sim.loot_items.duplicate()
		var loot_power: Dictionary = view.sim.loot_power.duplicate()
		var nature0: float = game.state["resources"]["power"]["nature"]
		_check(loot_power.keys() == ["nature"] and loot_power["nature"] == 3 * 4 + 2, "the nature stretch's 14 foes give 14 nature power (%s)" % loot_power)
		_check(loot_items.values().reduce(func(a, b): return a + b, 0) >= 1, "boss checkpoint drops an item")
		view.sim.return_home()
		await _frames(5)
		var have := 0
		for k in loot_items:
			have += 1 if game.state["items"].get(k, 0) == loot_items[k] else 0
		_check(have == loot_items.size(), "returning keeps the loot (%d growth, %s)" % [loot_xp, loot_items])
		_check(game.state["resources"]["power"]["nature"] == nature0 + loot_power["nature"], "returning keeps the elemental power")
		var seed_total: int = view.sim.loot_seeds.values().reduce(func(a, b): return a + b, 0)
		_check(seed_total >= 1 and game.state["seeds"].values().reduce(func(a, b): return a + b, 0) >= seed_total,
			"boss checkpoint drops a seed and returning keeps it (%s)" % view.sim.loot_seeds)
	else:
		print("NOTE expedition squad fell before the checkpoint (%d waves)" % view.sim.waves_cleared)
	main.close_battle()
	main.switch_tab("grove")
	await _frames()

	# Garden: seeds grow in 5 minutes, then plants make resources collected by tapping.
	game.state["seeds"] = {"sapling": 1, "fire": 1}
	main.ui["selected_plot"] = -1
	main.switch_tab("garden")
	_check(main.tab != "garden", "the garden is locked before the first prestige")
	game.state["tree"]["prestige"] = 1
	main.switch_tab("garden")
	await _frames()
	_check(main.tab == "garden", "the garden opens after the first prestige")
	game.state["tree"]["prestige"] = 0
	_check(game.plant(0, "sapling")["ok"] and game.plant(1, "fire")["ok"], "seeds planted")
	_check(not game.plant(0, "fire")["ok"], "can't plant in a used plot")
	_check(game.state["seeds"].is_empty(), "planting uses up seeds")
	_check(game.state["garden"].size() == 12, "the garden has 12 plots")
	var reach0: int = game.state["tree"]["roots"]
	game.state["tree"]["roots"] = 2
	_check(game.element_in_reach("water") and not game.element_in_reach("fire"), "elemental troops show once roots reach their land")
	game.state["tree"]["roots"] = reach0
	game.advance(4.0)
	_check(not game.collect_plot(0)["ok"], "nothing to collect while growing")
	game.advance(1.0 + 20.0)
	var sun0: float = game.state["resources"]["sunlight"]
	var sap0: float = game.state["resources"]["sap"]
	var fire0: float = game.state["resources"]["power"]["fire"]
	var got: Dictionary = game.collect_plot(0)["gained"]
	_check(got.get("sunlight", 0) == 40 and got.get("sap", 0) == 20 and game.state["resources"]["sunlight"] == sun0 + 40 and game.state["resources"]["sap"] == sap0 + 20,
		"sapling gathers sunlight and sap after growing (%s)" % got)
	got = game.collect_plot(1)["gained"]
	_check(got.get("fire", 0) == 1 and game.state["resources"]["power"]["fire"] == fire0 + 1, "fire flower gathers fire power (%s)" % got)
	game.advance(60.0 * 24)
	_check(game.state["garden"][1]["stored"]["fire"] == GameData.SEEDS["fire"]["makes"]["fire"] * GameData.GARDEN_CAP_MINUTES, "plant storage is capped")
	main._view._on_plot_tapped(1, Vector2(100, 100))
	await _frames()
	_check(game.state["garden"][1]["stored"]["fire"] < 1.0 and main.ui["selected_plot"] == 1, "tapping a grown flower collects it")
	_check(game.uproot(1)["ok"] and game.state["garden"][1]["seed"] == "", "uprooting clears the plot")
	var saved: Dictionary = game._normalize(JSON.parse_string(JSON.stringify(game.state)))
	_check(saved["garden"].size() == GameData.GARDEN_PLOTS and saved["garden"][0]["seed"] == "sapling", "garden survives save/load")
	var old_save: Dictionary = JSON.parse_string(JSON.stringify(game.state))
	old_save.erase("garden")
	old_save.erase("seeds")
	_check(game._normalize(old_save)["garden"].size() == GameData.GARDEN_PLOTS, "older saves get an empty garden")
	main.switch_tab("grove")
	await _frames()

	# Potions: readied in the Grove for the next battle, or drunk mid-battle.
	game.state["items"] = {"thorn_draught": 2, "bark_brew": 1, "reach_tonic": 1}
	main.switch_tab("grove")
	await _frames()
	main.open_inventory()
	await _frames()
	var inv: Array = main.get_children().filter(func(c): return c.has_signal("closed"))
	_check(inv.size() == 1, "inventory opens from the grove")
	_check(game.queue_potion("bark_brew")["ok"] and game.item_count("bark_brew") == 0, "bark brew readied for next battle")
	_check(not game.queue_potion("bark_brew")["ok"], "can't ready a potion you're out of")
	_check(game.unqueue_potion("bark_brew")["ok"] and game.item_count("bark_brew") == 1, "readied potion can be put back")
	game.queue_potion("bark_brew")
	game.queue_potion("reach_tonic")
	await _frames()
	inv[0].close()
	main.start_battle("sunny_meadow")
	await _frames()
	var pv: Node = main._battle
	_check(pv.sim.potion_active("bark_brew") and game.state["queued_potions"].is_empty(), "readied potions start with the battle")
	_check(pv.sim._reach(pv.sim.allies[0]) == pv.sim.allies[0].def["reach"] + 1, "longreach tonic adds 1 reach")
	_check(pv.sim._reach(pv.sim.enemies[0]) == pv.sim.enemies[0].def["reach"], "longreach tonic doesn't help foes")
	var hp_base: float = GameData.troop_def(game.formation_troops()[0]["troop"])["hp"]
	_check(is_equal_approx(pv.sim.allies[0].max_hp, hp_base * 1.2), "bark brew raises max HP by 20%")
	pv._open_inventory()
	await _frames()
	_check(pv._canvas.paused and pv._inventory != null, "inventory opens in battle and pauses it")
	_check(game.drink_in_battle(pv.sim, "thorn_draught")["ok"] and game.item_count("thorn_draught") == 1, "thorn draught drunk mid-battle")
	_check(not game.drink_in_battle(pv.sim, "thorn_draught")["ok"], "the same potion doesn't stack")
	pv._inventory.close()
	await _frames()
	_check(not pv._canvas.paused, "closing the inventory resumes the battle")
	pv.sim.phase = "won"
	pv.sim.waves_cleared = 4
	var pres: Dictionary = game.apply_battle_result(pv.sim)
	_check(pres["xp"] == roundi(GameData.LEVELS["sunny_meadow"]["rewards"]["xp"]), "potions don't change growth (%d)" % pres["xp"])
	pv.sim.dispose()
	main.close_battle()
	await _frames()

	# Potions wear off after POTION_WAVES waves on an expedition.
	var ex := BattleSim.new_expedition(game.formation_troops(), ["bark_brew"])
	var max0: float = ex.allies[0].max_hp
	for w in GameData.POTION_WAVES:
		ex._expire_potions(w + 1)
	_check(not ex.potion_active("bark_brew") and is_equal_approx(ex.allies[0].max_hp, max0 / 1.2), "potions wear off after %d waves" % GameData.POTION_WAVES)
	ex.dispose()

	# Prestige at the max level: costs double the last level, resets to 0, +10% bonus.
	game.state = game.new_game()
	game.state["tree"]["level"] = GameData.MAX_LEVEL - 1
	game.state["resources"]["sunlight"] = GameData.xp_to_next(GameData.MAX_LEVEL - 1) + GameData.prestige_cost()
	for id in GameData.LEVEL_ORDER:
		if GameData.LEVELS[id]["distance"] < GameData.MAX_LEVEL:
			game.state["levels"][id] = {"conquered": true, "stored": 0.0, "clears": 1}
	game.channel()
	game.state["tree"]["xp"] = GameData.prestige_cost()
	_check(game.growth_blocked() == "blighted_heartwood" and not game.channel()["ok"] and game.state["tree"]["prestige"] == 0,
		"prestige waits on conquering the farthest land")
	game.state["levels"]["blighted_heartwood"] = {"conquered": true, "stored": 0.0, "clears": 1}
	_check(game.state["tree"]["level"] == GameData.MAX_LEVEL and game._add_xp(10 ** 7) == 0, "the tree stops at level %d" % GameData.MAX_LEVEL)
	game.state["tree"]["xp"] = 0
	main.switch_tab("grove")
	await _frames()
	_check(GameData.prestige_cost() == 2 * GameData.xp_to_next(GameData.MAX_LEVEL - 1), "prestige costs double the last level")
	var pres_sun0: float = game.state["resources"]["sunlight"]
	var base_sun: float = game.rates()["sunlight"]
	game.channel()
	_check(game.state["tree"]["level"] == 0 and game.state["tree"]["prestige"] == 1 and pres_sun0 - game.state["resources"]["sunlight"] == GameData.prestige_cost(), "prestige resets the tree to level 0")
	_check(is_equal_approx(game.rates()["sunlight"], base_sun * 1.1), "prestige boosts sunlight production by 10%")
	var squad := [{"troop": {"id": 1, "type": "soldier", "element": ""}, "row": "front", "lane": 1}]
	var strong := BattleSim.new("sunny_meadow", squad, false, [], game.prestige_mult())
	var soldier: Dictionary = GameData.TROOPS["soldier"]
	_check(is_equal_approx(strong.allies[0].def["dmg"], soldier["dmg"] * 1.1) and strong.allies[0].max_hp == roundi(soldier["hp"] * 1.1), "prestige boosts troop HP and damage by 10%")
	strong.dispose()

	# Developer prestige: meets every requirement from a fresh tree, then from a prestiged one.
	game.state = game.new_game()
	var gates_ok := true
	for i in 2:
		_check(game.dev_prestige()["ok"], "dev prestige works (prestige %d)" % (i + 1))
		for lvl in range(1, GameData.MAX_LEVEL + 1):
			gates_ok = gates_ok and game.level_state(game.growth_gate(lvl))["conquered"]
	_check(gates_ok and game.state["tree"]["prestige"] == 2 and game.state["tree"]["level"] == 0 and game.state["tree"]["xp"] == 0,
		"dev prestige conquers every gating land and prestiges")
	_check(game.state["levels"]["blighted_heartwood"]["stored"] > 0.0 and game.has_seen_enemy("blight_treant"),
		"dev-conquered lands hold their first day's power and their foes are known")

	# Dungeons: three at a time; a cleared one crumbles and another appears 30 minutes later.
	game.state = game.new_game()
	game.state["tree"]["roots"] = 4
	game.tick()
	var dgs: Array = game.state["dungeons"]
	_check(dgs.size() == GameData.DUNGEON_COUNT, "%d dungeons appear on the map" % GameData.DUNGEON_COUNT)
	var spots_ok := true
	for i in dgs.size():
		var dp := Vector2(dgs[i]["x"], dgs[i]["y"])
		spots_ok = spots_ok and dp.distance_to(GameData.GROVE) >= GameData.DUNGEON_GAP and dgs[i]["distance"] <= GameData.DUNGEON_START_MAX
		for id in GameData.LEVELS:
			spots_ok = spots_ok and dp.distance_to(GameData.LEVELS[id]["pos"]) >= GameData.DUNGEON_GAP
		for j in i:
			spots_ok = spots_ok and dp.distance_to(Vector2(dgs[j]["x"], dgs[j]["y"])) >= GameData.DUNGEON_GAP
	_check(spots_ok, "dungeons start within reach %d, clear of lands, the grove and each other" % GameData.DUNGEON_START_MAX)
	var spots_clear := GameData.DUNGEON_SPOTS.size() == 5
	for p: Vector2 in GameData.DUNGEON_SPOTS:
		# Room for the name on screen, clear of the lands, the grove and the other spots.
		spots_clear = spots_clear and p.x >= 75 and p.x <= GameData.MAP_SIZE.x - 75 \
			and p.y >= GameData.MAP_SAFE_TOP + GameData.DUNGEON_GAP and p.y <= GameData.MAP_SAFE_BOTTOM - GameData.DUNGEON_GAP \
			and p.distance_to(GameData.GROVE) >= GameData.DUNGEON_GAP
		for id in GameData.LEVELS:
			spots_clear = spots_clear and p.distance_to(GameData.LEVELS[id]["pos"]) >= GameData.DUNGEON_GAP
		for q: Vector2 in GameData.DUNGEON_SPOTS:
			spots_clear = spots_clear and (p == q or p.distance_to(q) >= 150.0)
	_check(spots_clear, "the 5 dungeon spots sit on screen, clear of lands, the grove and each other")
	_check(dgs.all(func(x): return GameData.DUNGEON_SPOTS.has(Vector2(x["x"], x["y"]))), "dungeons stand on the dungeon spots")
	var old_spot := Vector2(400, 700)
	var moved: Dictionary = game._normalize({"tree": game.state["tree"], "troops": [], "formation": [], "levels": {}, "next_troop_id": 1,
		"dungeons": [{"id": 1, "distance": 1, "x": old_spot.x, "y": old_spot.y}]})
	_check(GameData.DUNGEON_SPOTS.has(Vector2(moved["dungeons"][0]["x"], moved["dungeons"][0]["y"])), "a dungeon from an older save moves onto a spot")
	var fresh_ok := true
	for i in 50:
		var taken := GameData.DUNGEON_SPOTS.slice(0, 2)
		fresh_ok = fresh_ok and GameData.roll_dungeon_pos(taken, GameData.DUNGEON_SPOTS[2]) in GameData.DUNGEON_SPOTS.slice(3)
	_check(fresh_ok, "a respawned dungeon picks a free spot other than the one it left")
	var rolls_ok := true
	for el in GameData.ELEMENTS:
		for dist in range(1, 11):
			var r := GameData.roll_dungeon(el, dist)
			rolls_ok = rolls_ok and r["waves"].size() == GameData.DUNGEON_WAVES \
				and GameData.ENEMIES[r["waves"][-1][0]].get("boss", false)
			for w in r["waves"]:
				for key in w:
					rolls_ok = rolls_ok and GameData.ENEMIES[key]["element"] == el
	_check(rolls_ok, "every element rolls a dungeon of its own foes ending in a boss, at every distance")
	var did: String = game.dungeon_id(dgs[0])
	var cleared_at := Vector2(dgs[0]["x"], dgs[0]["y"])
	var del: String = dgs[0]["element"]
	var ddist: int = dgs[0]["distance"]
	game.state["tree"]["roots"] = maxi(game.state["tree"]["roots"], ddist)  # dungeons may start past the roots
	game.state["formation"] = []
	_check(not game.can_enter_dungeon(did)["ok"], "a dungeon needs a formation")
	game.state["troops"] = [{"id": 1, "type": "soldier", "element": ""}]
	game.state["formation"] = [{"troop_id": 1, "row": "front", "lane": 1}]
	main.ui["selected_level"] = did
	main.switch_tab("map")
	await _frames()
	main.start_dungeon(did)
	await _frames()
	var dv: Node = main._battle
	_check(dv != null and dv.sim.dungeon and dv.sim.level["elements"] == [del], "entering a dungeon opens its battle")
	dv.sim.phase = "won"
	dv.sim.waves_cleared = GameData.DUNGEON_WAVES
	var dres: Dictionary = game.apply_dungeon_result(dv.sim)
	var n_potions := 0
	for k in dres["items"]:
		n_potions += dres["items"][k]
	_check(n_potions == GameData.dungeon_reward_count(ddist), "a cleared dungeon gives potions")
	_check(dres["seeds"].values().reduce(func(a, b): return a + b, 0) <= 1, "at most one seed from a dungeon before the first prestige")
	_check(game.dungeon(did).is_empty() and game.state["dungeons"].size() == GameData.DUNGEON_COUNT - 1, "a cleared dungeon crumbles")
	game.tick()
	_check(game.state["dungeons"].size() == GameData.DUNGEON_COUNT - 1 and game.next_dungeon_in() > 29 * 60, "the next dungeon waits 30 minutes")
	dv.sim.dispose()
	main.close_battle()
	await _frames()
	var next_dist: int = game.state["dungeon_respawns"][0]["distance"]
	_check(next_dist - ddist in [1, 2] or next_dist == GameData.DUNGEON_MAX_DISTANCE, "the next dungeon is 1 or 2 reach farther out (%d → %d)" % [ddist, next_dist])
	var known_ids: Array = game.state["dungeons"].map(func(x): return x["id"])
	game.state["dungeon_respawns"][0]["at"] -= GameData.DUNGEON_RESPAWN_MINUTES * 60.0
	game.tick()
	_check(game.state["dungeons"].size() == GameData.DUNGEON_COUNT and game.next_dungeon_in() < 0, "a new dungeon appears once the wait is over")
	var fresh: Array = game.state["dungeons"].filter(func(x): return not x["id"] in known_ids)
	_check(fresh.size() == 1 and fresh[0]["distance"] == next_dist, "the new dungeon appears at its rolled distance")
	var spots_now: Array = game.state["dungeons"].map(func(x): return Vector2(x["x"], x["y"]))
	_check(Vector2(fresh[0]["x"], fresh[0]["y"]) != cleared_at and spots_now.size() == 3 and spots_now.all(func(p): return spots_now.count(p) == 1),
		"the new dungeon takes a different free spot than the one cleared")
	game.state["tree"]["prestige"] = 1
	var d2: Dictionary = game.state["dungeons"][0]
	var sim2 := BattleSim.new(game.dungeon_id(d2), game.formation_troops(), false, [], 1.0, game.dungeon_level(d2))
	sim2.phase = "won"
	var dres2: Dictionary = game.apply_dungeon_result(sim2)
	_check(not dres2["seeds"].is_empty(), "prestiged players also get garden seeds from dungeons")
	sim2.dispose()
	var dsaved: Dictionary = game._normalize(JSON.parse_string(JSON.stringify(game.state)))
	_check(dsaved["dungeons"].size() == GameData.DUNGEON_COUNT - 1 and dsaved["dungeons"][0]["id"] is int, "dungeons survive save/load")

	game.state = game.new_game()
	game.save()
	print("SMOKE TEST DONE")
	quit()
