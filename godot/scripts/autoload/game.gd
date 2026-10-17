extends Node
## Game state, save/load, real-time production and player actions.
## Every action returns { ok, msg }, emits `toast` when it has a message and
## `changed` so the UI can redraw.

signal changed
signal toast(message: String, good: bool)
## Sunlight or sap went up from a tap. Cheaper than `changed`: the UI only
## updates its counters instead of rebuilding the screen on every tap.
signal tapped_stock

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var state: Dictionary


func _ready() -> void:
	state = _load()
	tick()
	var autosave := Timer.new()
	autosave.wait_time = 5.0
	autosave.timeout.connect(save)
	add_child(autosave)
	autosave.start()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if state:
				save()
		NOTIFICATION_APPLICATION_RESUMED:
			if state:
				tick()
				changed.emit()


func _now() -> float:
	return Time.get_unix_time_from_system()


func new_game() -> Dictionary:
	var power := {}
	for e in GameData.ELEMENTS:
		power[e] = 0.0
	return {
		"version": SAVE_VERSION,
		"last_tick": _now(),
		"resources": {"sunlight": 0.0, "sap": 0.0, "power": power},
		"pending": {"sunlight": 0.0, "sap": 0.0},
		"tree": {
			"level": 1, "xp": 0,
			"roots": GameData.PARTS["roots"]["start"],
			"trunk": GameData.PARTS["trunk"]["start"],
			"branches": GameData.PARTS["branches"]["start"],
		},
		"troops": [],  # [{ id, type, element }] — element is "" until infused
		"next_troop_id": 1,
		"formation": [],  # [{ troop_id, row, lane }]
		"levels": {},  # level_id -> { conquered, stored, clears }
		"seen_enemies": {},  # enemy_key -> true once it has appeared in a battle
		"items": {},  # item_id -> count, found on expeditions
		"queued_potions": [],  # item ids drunk in the Grove, active from the next battle
		"seeds": {},  # seed_id -> count, found on expeditions
		"garden": _empty_garden(),
	}


# One entry per plot: { seed ("" when empty), grow_left (minutes), stored (resource -> amount) }.
func _empty_garden() -> Array:
	var plots := []
	for i in GameData.GARDEN_PLOTS:
		plots.append(_empty_plot())
	return plots


func _empty_plot() -> Dictionary:
	return {"seed": "", "grow_left": 0.0, "stored": {}}


func _load() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
			return _normalize(data)
	return new_game()


# JSON has no integer type, so restore the whole-number fields after loading.
func _normalize(s: Dictionary) -> Dictionary:
	for k in ["level", "xp", "roots", "trunk", "branches"]:
		s["tree"][k] = int(s["tree"][k])
	s["next_troop_id"] = int(s["next_troop_id"])
	for t in s["troops"]:
		t["id"] = int(t["id"])
		if not t.has("element"):
			t["element"] = ""
	for f in s["formation"]:
		f["troop_id"] = int(f["troop_id"])
		f["lane"] = int(f["lane"])
	for ls in s["levels"].values():
		ls["clears"] = int(ls["clears"])
	var items: Dictionary = s.get("items", {})
	for k in items:
		items[k] = int(items[k])
	s["items"] = items
	s["queued_potions"] = s.get("queued_potions", [])
	var seeds: Dictionary = s.get("seeds", {})
	for k in seeds:
		seeds[k] = int(seeds[k])
	s["seeds"] = seeds
	if not s.has("seen_enemies"):
		# Older saves: count every foe of an already-cleared land as seen.
		var seen := {}
		for id in s["levels"]:
			if s["levels"][id]["clears"] > 0 and GameData.LEVELS.has(id):
				for w in GameData.LEVELS[id]["waves"]:
					for key in w:
						seen[key] = true
		s["seen_enemies"] = seen
	var garden: Array = s.get("garden", [])
	while garden.size() < GameData.GARDEN_PLOTS:
		garden.append(_empty_plot())
	s["garden"] = garden
	return s


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func reset() -> void:
	state = new_game()
	save()
	changed.emit()


# --- Derived values ---------------------------------------------------------

func rates() -> Dictionary:
	return {
		"sunlight": GameData.sunlight_per_min(state["tree"]["branches"]),
		"sap": GameData.sap_per_min(state["tree"]["trunk"]),
	}

func caps() -> Dictionary:
	var r := rates()
	return {"sunlight": r["sunlight"] * GameData.STORAGE_CAP_MINUTES, "sap": r["sap"] * GameData.STORAGE_CAP_MINUTES}

func reach() -> int:
	return GameData.root_reach(state["tree"]["roots"])

func formation_slots() -> int:
	return GameData.formation_slots(state["tree"]["trunk"])

func roster_cap() -> int:
	return GameData.roster_cap(state["tree"]["level"])

func level_state(id: String) -> Dictionary:
	return state["levels"].get(id, {"conquered": false, "stored": 0.0, "clears": 0})

func has_seen_enemy(key: String) -> bool:
	return state["seen_enemies"].has(key)


func mark_enemies_seen(keys: Array) -> void:
	for key in keys:
		state["seen_enemies"][key] = true


func has_conquered_element(element: String) -> bool:
	for id in state["levels"]:
		if state["levels"][id]["conquered"] and GameData.LEVELS[id]["element"] == element:
			return true
	return false

## Whether the roots reach any land of `element` (its elemental troop is shown from then on).
func element_in_reach(element: String) -> bool:
	for id in GameData.LEVELS:
		if GameData.LEVELS[id]["element"] == element and can_reach(id):
			return true
	return false

func can_reach(id: String) -> bool:
	return GameData.LEVELS[id]["distance"] <= reach()

func troop_by_id(id: int) -> Dictionary:
	for t in state["troops"]:
		if t["id"] == id:
			return t
	return {}


# --- Time -------------------------------------------------------------------

func tick() -> void:
	var now := _now()
	var minutes := maxf(0.0, (now - state["last_tick"]) / 60.0)
	state["last_tick"] = now
	advance(minutes)


# Adds `minutes` of production. Also used by the debug time-warp button.
func advance(minutes: float) -> void:
	var r := rates()
	var c := caps()
	var p: Dictionary = state["pending"]
	p["sunlight"] = minf(c["sunlight"], p["sunlight"] + r["sunlight"] * minutes)
	p["sap"] = minf(c["sap"], p["sap"] + r["sap"] * minutes)
	for id in state["levels"]:
		var ls: Dictionary = state["levels"][id]
		if ls["conquered"]:
			var daily: float = GameData.LEVELS[id]["daily_yield"]
			ls["stored"] = minf(daily, ls["stored"] + daily / GameData.STORAGE_CAP_MINUTES * minutes)
	# Garden plants grow first, then make resources for the rest of the time.
	for plot in state["garden"]:
		if plot["seed"] == "":
			continue
		var growing := minf(plot["grow_left"], minutes)
		plot["grow_left"] -= growing
		var making := minutes - growing
		if making <= 0.0:
			continue
		var makes: Dictionary = GameData.SEEDS[plot["seed"]]["makes"]
		for res in makes:
			plot["stored"][res] = minf(makes[res] * GameData.GARDEN_CAP_MINUTES, plot["stored"].get(res, 0.0) + makes[res] * making)


# --- Actions ------------------------------------------------------------------

func _ok(msg := "") -> Dictionary:
	return {"ok": true, "msg": msg}

func _fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}

# Announces an action's result and tells the UI to redraw.
func _done(res: Dictionary) -> Dictionary:
	if res["msg"] != "":
		toast.emit(res["msg"], res["ok"])
	if res["ok"]:
		changed.emit()
	return res


func collect() -> Dictionary:
	var p: Dictionary = state["pending"]
	var sun := floorf(p["sunlight"])
	var sap := floorf(p["sap"])
	if sun + sap == 0:
		return _done(_fail("Nothing to collect yet."))
	state["resources"]["sunlight"] += sun
	state["resources"]["sap"] += sap
	p["sunlight"] -= sun
	p["sap"] -= sap
	return _done(_ok("Collected %d sunlight and %d sap." % [sun, sap]))


# Tapping the branches gathers sunlight straight into the player's stock.
func tap_branches() -> Dictionary:
	state["resources"]["sunlight"] += GameData.TAP_SUNLIGHT
	tapped_stock.emit()
	return _ok()


# Tapping the trunk gathers sap straight into the player's stock.
func tap_trunk() -> Dictionary:
	state["resources"]["sap"] += GameData.TAP_SAP
	tapped_stock.emit()
	return _ok()


func collect_level(id: String) -> Dictionary:
	var ls := level_state(id)
	var amount := floorf(ls["stored"])
	if not ls["conquered"] or amount == 0:
		return _done(_fail("No power stored yet."))
	ls["stored"] -= amount
	var el: String = GameData.LEVELS[id]["element"]
	state["resources"]["power"][el] += amount
	return _done(_ok("Collected %d %s power." % [amount, el]))


# --- Garden -------------------------------------------------------------------

func plant(plot_index: int, seed_id: String) -> Dictionary:
	if state["garden"][plot_index]["seed"] != "":
		return _done(_fail("Something is already growing there."))
	if state["seeds"].get(seed_id, 0) <= 0:
		return _done(_fail("No %s left." % GameData.SEEDS[seed_id]["name"]))
	state["seeds"][seed_id] -= 1
	if state["seeds"][seed_id] <= 0:
		state["seeds"].erase(seed_id)
	state["garden"][plot_index] = {"seed": seed_id, "grow_left": GameData.GROW_MINUTES, "stored": {}}
	return _done(_ok("Planted a %s." % GameData.SEEDS[seed_id]["name"]))


## Collects what a grown plant has made; `gained` in the result maps resource -> amount.
func collect_plot(plot_index: int) -> Dictionary:
	var plot: Dictionary = state["garden"][plot_index]
	var res := _fail("It hasn't finished growing yet.")
	res["gained"] = {}
	if plot["seed"] == "" or plot["grow_left"] > 0.0:
		return _done(res)
	for r in plot["stored"]:
		var amount := floorf(plot["stored"][r])
		if amount <= 0:
			continue
		plot["stored"][r] -= amount
		if r in ["sunlight", "sap"]:
			state["resources"][r] += amount
		else:
			state["resources"]["power"][r] += amount
		res["gained"][r] = int(amount)
	if res["gained"].is_empty():
		res["msg"] = "The %s is still gathering." % GameData.SEEDS[plot["seed"]]["plant"]
		return _done(res)
	res["ok"] = true
	res["msg"] = ""
	return _done(res)


## Clears a plot so something else can be planted. Anything uncollected is lost.
func uproot(plot_index: int) -> Dictionary:
	var plot: Dictionary = state["garden"][plot_index]
	if plot["seed"] == "":
		return _done(_fail("That plot is already empty."))
	var plant_name: String = GameData.SEEDS[plot["seed"]]["plant"]
	state["garden"][plot_index] = _empty_plot()
	return _done(_ok("Uprooted the %s." % plant_name))


func _add_xp(amount: int) -> int:
	var t: Dictionary = state["tree"]
	t["xp"] += amount
	var ups := 0
	while t["xp"] >= GameData.xp_to_next(t["level"]):
		t["xp"] -= GameData.xp_to_next(t["level"])
		t["level"] += 1
		ups += 1
	return ups


# Feeds sunlight into the tree's growth (1 sunlight = 1 growth).
# amount < 0 means "exactly enough for the next level".
func channel(amount: int = -1) -> Dictionary:
	var t: Dictionary = state["tree"]
	var needed: int = GameData.xp_to_next(t["level"]) - t["xp"]
	var spend := mini(needed if amount < 0 else amount, int(state["resources"]["sunlight"]))
	if spend <= 0:
		return _done(_fail("Not enough sunlight."))
	state["resources"]["sunlight"] -= spend
	var ups := _add_xp(spend)
	return _done(_ok("The tree grew to level %d!" % t["level"] if ups > 0 else "Channeled %d sunlight." % spend))


func part_cost(part: String) -> Dictionary:
	return GameData.part_cost(part, state["tree"][part])


func can_upgrade(part: String) -> Dictionary:
	var lvl: int = state["tree"][part]
	if lvl >= state["tree"]["level"]:
		return _fail("Grow the tree to level %d first." % (lvl + 1))
	var cost := part_cost(part)
	for res in cost:
		if state["resources"][res] < cost[res]:
			return _fail("Need %d %s." % [cost[res], res])
	return _ok()


func upgrade_part(part: String) -> Dictionary:
	var check := can_upgrade(part)
	if not check["ok"]:
		return _done(check)
	var cost := part_cost(part)
	for res in cost:
		state["resources"][res] -= cost[res]
	state["tree"][part] += 1
	return _done(_ok("%s upgraded to level %d." % [GameData.PARTS[part]["name"], state["tree"][part]]))


## Why a troop type can't be grown yet, or "" if it is unlocked.
func troop_lock_reason(type: String) -> String:
	var def: Dictionary = GameData.TROOPS[type]
	if state["tree"]["level"] < def["unlock_level"]:
		return "Unlocks at tree level %d" % def["unlock_level"]
	if def["element"] != "" and not has_conquered_element(def["element"]):
		var article := "an" if def["element"] in ["ice"] else "a"
		return "Conquer %s %s land to unlock" % [article, def["element"]]
	return ""


func can_summon(type: String) -> Dictionary:
	var def: Dictionary = GameData.TROOPS[type]
	var lock := troop_lock_reason(type)
	if lock != "":
		return _fail(lock + ".")
	if state["troops"].size() >= roster_cap():
		return _fail("Roster is full.")
	if state["resources"]["sap"] < def["sap_cost"]:
		return _fail("Need %d sap." % def["sap_cost"])
	if def.has("power_cost") and state["resources"]["power"][def["element"]] < def["power_cost"]:
		return _fail("Need %d %s power." % [def["power_cost"], def["element"]])
	return _ok()


func summon(type: String) -> Dictionary:
	var check := can_summon(type)
	if not check["ok"]:
		return _done(check)
	var def: Dictionary = GameData.TROOPS[type]
	state["resources"]["sap"] -= def["sap_cost"]
	if def.has("power_cost"):
		state["resources"]["power"][def["element"]] -= def["power_cost"]
	var troop := {"id": state["next_troop_id"], "type": type, "element": ""}
	state["next_troop_id"] += 1
	state["troops"].append(troop)
	_auto_place(troop)
	return _done(_ok("A %s sprouts from the trunk." % def["name"]))


func can_infuse(troop_id: int, element: String) -> Dictionary:
	var t := troop_by_id(troop_id)
	if t.is_empty():
		return _fail("That troop is gone.")
	if GameData.TROOPS[t["type"]]["element"] != "" or t["element"] != "":
		return _fail("This troop already has an element.")
	if state["resources"]["power"][element] < GameData.INFUSE_COST:
		return _fail("Need %d %s power." % [GameData.INFUSE_COST, element])
	return _ok()


## Upgrades a base troop with elemental power so it permanently gains that element.
func infuse(troop_id: int, element: String) -> Dictionary:
	var check := can_infuse(troop_id, element)
	if not check["ok"]:
		return _done(check)
	var t := troop_by_id(troop_id)
	state["resources"]["power"][element] -= GameData.INFUSE_COST
	t["element"] = element
	return _done(_ok("%s #%d is now a %s." % [GameData.TROOPS[t["type"]]["name"], troop_id, GameData.troop_def(t)["name"]]))


func _cell(row: String, lane: int) -> Dictionary:
	for f in state["formation"]:
		if f["row"] == row and f["lane"] == lane:
			return f
	return {}


# Puts a new troop in its preferred row if a formation slot is free.
func _auto_place(troop: Dictionary) -> void:
	if state["formation"].size() >= formation_slots():
		return
	var pref: String = GameData.TROOPS[troop["type"]]["preferred_row"]
	var order := [pref]
	for r in BattleSim.ROWS:
		if r != pref:
			order.append(r)
	for row in order:
		for lane in [1, 0, 2]:
			if _cell(row, lane).is_empty():
				state["formation"].append({"troop_id": troop["id"], "row": row, "lane": lane})
				return


# Places a troop at a cell, or clears the cell when troop_id < 0.
func place_troop(troop_id: int, row: String, lane: int) -> Dictionary:
	var f: Array = state["formation"]
	var target := _cell(row, lane)
	if troop_id < 0:
		f.erase(target)
		return _done(_ok())
	var existing := -1
	for i in f.size():
		if f[i]["troop_id"] == troop_id:
			existing = i
	if existing < 0 and target.is_empty() and f.size() >= formation_slots():
		return _done(_fail("All formation slots are used. Upgrade the trunk for more."))
	if existing >= 0:
		f.remove_at(existing)
	f.erase(target)
	f.append({"troop_id": troop_id, "row": row, "lane": lane})
	return _done(_ok())


# Moves the troop in one cell to another, swapping if the target cell is occupied.
func move_troop(from_row: String, from_lane: int, to_row: String, to_lane: int) -> Dictionary:
	var from := _cell(from_row, from_lane)
	if from.is_empty():
		return _done(_fail(""))
	var to := _cell(to_row, to_lane)
	if not to.is_empty():
		to["row"] = from_row
		to["lane"] = from_lane
	from["row"] = to_row
	from["lane"] = to_lane
	return _done(_ok())


# --- Potions -----------------------------------------------------------------

func item_count(id: String) -> int:
	return state["items"].get(id, 0)


func is_queued(id: String) -> bool:
	return id in state["queued_potions"]


## Drinks a potion in the Grove: it takes effect when the next battle starts.
func queue_potion(id: String) -> Dictionary:
	if item_count(id) <= 0:
		return _done(_fail("No %s left." % GameData.ITEMS[id]["name"]))
	if is_queued(id):
		return _done(_fail("%s is already waiting for the next battle." % GameData.ITEMS[id]["name"]))
	state["items"][id] -= 1
	state["queued_potions"].append(id)
	save()
	return _done(_ok("%s is ready for your next battle." % GameData.ITEMS[id]["name"]))


## Puts a potion queued in the Grove back in the inventory.
func unqueue_potion(id: String) -> Dictionary:
	if not is_queued(id):
		return _done(_fail("That potion isn't waiting for a battle."))
	state["queued_potions"].erase(id)
	state["items"][id] = item_count(id) + 1
	save()
	return _done(_ok("%s put back." % GameData.ITEMS[id]["name"]))


## Hands the queued potions to a battle that is starting.
func take_queued_potions() -> Array:
	var out: Array = state["queued_potions"]
	state["queued_potions"] = []
	save()
	return out


## Drinks a potion during a battle or expedition; it takes effect at once.
func drink_in_battle(b: BattleSim, id: String) -> Dictionary:
	var item_name: String = GameData.ITEMS[id]["name"]
	if item_count(id) <= 0:
		return _done(_fail("No %s left." % item_name))
	if not b.can_drink(id):
		return _done(_fail("%s is still working." % item_name))
	state["items"][id] -= 1
	b.drink(id)
	save()
	return _done(_ok("Drank %s!" % item_name))


func formation_troops() -> Array:
	var out := []
	for f in state["formation"]:
		var t := troop_by_id(f["troop_id"])
		if not t.is_empty():
			out.append({"troop": t, "row": f["row"], "lane": f["lane"]})
	return out


func can_enter(id: String) -> Dictionary:
	var lvl: Dictionary = GameData.LEVELS[id]
	if not lvl["playable"]:
		return _fail("Coming soon.")
	if not can_reach(id):
		return _fail("Roots must reach distance %d." % lvl["distance"])
	if formation_troops().is_empty():
		return _fail("Place troops in your formation first.")
	return _ok()


func can_start_expedition() -> Dictionary:
	if formation_troops().is_empty():
		return _fail("Place troops in your formation first.")
	return _ok()


# Applies a finished battle. Fallen troops are lost for good.
func apply_battle_result(b: BattleSim) -> Dictionary:
	var lost := _remove_fallen(b)

	var lvl := b.level
	if not state["levels"].has(b.level_id):
		state["levels"][b.level_id] = {"conquered": false, "stored": 0.0, "clears": 0}
	var ls: Dictionary = state["levels"][b.level_id]
	var won := b.phase == "won"
	var first_clear: bool = won and not ls["conquered"]
	var xp := 10 * b.waves_cleared
	var xp_boost := b.boost("xp")
	var sap := 0
	var power := 0
	if won:
		xp = lvl["rewards"]["first_xp"] if first_clear else lvl["rewards"]["xp"]
		sap = lvl["rewards"]["sap"]
		power = GameData.power_reward(b.level_id, first_clear)
		ls["clears"] += 1
		ls["conquered"] = true
	xp = roundi(xp * (1.0 + xp_boost))
	state["resources"]["sap"] += sap
	state["resources"]["power"][lvl["element"]] += power
	var level_ups := _add_xp(xp)
	save()
	changed.emit()
	return {"won": won, "first_clear": first_clear, "xp": xp, "xp_boost": xp_boost, "sap": sap, "power": power, "element": lvl["element"], "lost": lost,
		"level_ups": level_ups, "new_level": state["tree"]["level"]}


func _remove_fallen(b: BattleSim) -> int:
	var fallen := {}
	for id in b.fallen:
		fallen[id] = true
	state["troops"] = state["troops"].filter(func(t): return not fallen.has(t["id"]))
	state["formation"] = state["formation"].filter(func(f): return not fallen.has(f["troop_id"]))
	return fallen.size()


# Applies a finished expedition. Loot is kept only if the squad made it home
# from a checkpoint; fallen troops are lost either way.
func apply_expedition_result(b: BattleSim) -> Dictionary:
	var lost := _remove_fallen(b)
	var returned := b.phase == "won"
	var level_ups := 0
	if returned:
		for item in b.loot_items:
			state["items"][item] = state["items"].get(item, 0) + b.loot_items[item]
		for seed_id in b.loot_seeds:
			state["seeds"][seed_id] = state["seeds"].get(seed_id, 0) + b.loot_seeds[seed_id]
		for el in b.loot_power:
			state["resources"]["power"][el] += b.loot_power[el]
		level_ups = _add_xp(b.loot_xp)
	save()
	changed.emit()
	return {"returned": returned, "xp": b.loot_xp, "items": b.loot_items, "seeds": b.loot_seeds, "power": b.loot_power, "lost": lost,
		"level_ups": level_ups, "new_level": state["tree"]["level"]}
