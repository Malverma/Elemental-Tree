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

	game.advance(60)
	game.collect()
	game.upgrade_part("roots")
	game.upgrade_part("branches")
	game.channel()
	_check(game.state["tree"]["level"] == 2 and game.state["tree"]["roots"] == 1, "upgrades and level up")
	_check(GameData.xp_to_next(1) == 150 and GameData.xp_to_next(9) == 72000, "level 1 → 2 is 15 min of sunlight, 9 → 10 is 24 h")
	_check(is_equal_approx(GameData.growth_minutes(12), GameData.STORAGE_CAP_MINUTES), "levels past 10 stay at 24 h of sunlight")
	_check(not GameData.part_cost("roots", 2).has("sap") and not GameData.part_cost("trunk", 2).has("sap"), "part upgrades to level 3 cost no sap")
	_check(GameData.part_cost("roots", 3).has("sap") and GameData.part_cost("trunk", 3).has("sap"), "part upgrades past level 3 cost sap")
	_check(GameData.part_cost("branches", 8)["sunlight"] == roundi(GameData.xp_to_next(8) * 0.2 / 5.0) * 5, "part sunlight follows the growth curve")
	_check(not game.has_seen_enemy("burrow_rabbit"), "meadow foes unknown before the first battle")

	main.switch_tab("barracks")
	await _frames()
	game.summon("soldier")
	game.summon("soldier")
	game.summon("spearman")
	await _frames()
	_check(game.state["formation"].size() == 3, "summoned troops auto-placed")

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
		_check(game.state["resources"]["power"]["nature"] == meadow_day, "first clear gives a day of nature power")
	game.state["levels"]["sunny_meadow"] = {"conquered": true, "stored": 0.0, "clears": 1}
	var before: float = game.state["resources"]["power"]["nature"]
	var replay := BattleSim.new("sunny_meadow", game.formation_troops())
	replay.phase = "won"
	replay.waves_cleared = 4
	var res: Dictionary = game.apply_battle_result(replay)
	_check(res["power"] == GameData.power_reward("sunny_meadow", false) and game.state["resources"]["power"]["nature"] == before + res["power"],
		"replay gives 3 hours of power (%d)" % res["power"])

	# Elemental troops and upgrading base troops with an element.
	game.state["resources"]["sap"] = 500.0
	game.state["resources"]["power"]["nature"] = 50.0
	game.state["levels"]["sunny_meadow"]["conquered"] = true
	_check(game.troop_lock_reason("tide_caller") != "", "water troop locked before conquering a water land")
	_check(game.summon("vine_lasher")["ok"], "nature troop unlocked by conquering the meadow")
	var base_id := -1
	for troop in game.state["troops"]:
		if troop["type"] == "soldier":
			base_id = troop["id"]
	if base_id < 0:
		game.summon("soldier")
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
	lost_exp.loot_items = {"growth_tonic": 2}
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
	await _frames()
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
	game.state["items"] = {"thorn_draught": 2, "bark_brew": 1, "growth_tonic": 1}
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
	game.queue_potion("growth_tonic")
	await _frames()
	inv[0].close()
	main.start_battle("sunny_meadow")
	await _frames()
	var pv: Node = main._battle
	_check(pv.sim.potion_active("bark_brew") and game.state["queued_potions"].is_empty(), "readied potions start with the battle")
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
	_check(pres["xp"] == roundi(GameData.LEVELS["sunny_meadow"]["rewards"]["xp"] * 1.5), "growth tonic gives +50%% growth (%d)" % pres["xp"])
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

	game.state = game.new_game()
	game.save()
	print("SMOKE TEST DONE")
	quit()
