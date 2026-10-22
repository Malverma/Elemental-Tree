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
			"level": 1, "xp": 0, "prestige": 0,
			"roots": GameData.PARTS["roots"]["start"],
			"trunk": GameData.PARTS["trunk"]["start"],
			"branches": GameData.PARTS["branches"]["start"],
			"tap": GameData.PARTS["tap"]["start"],
		},
		"troops": [],  # [{ id, type, element }] — element is "" until infused
		"next_troop_id": 1,
		"twig_box": _empty_twig_box(1),
		"formation": [],  # [{ troop_id, row, lane }]
		"levels": {},  # level_id -> { conquered, stored, clears }
		"seen_enemies": {},  # enemy_key -> true once it has appeared in a battle
		"items": {},  # item_id -> count, found on expeditions
		"queued_potions": [],  # item ids drunk in the Grove, active from the next battle
		"seeds": {},  # seed_id -> count, found on expeditions
		"garden": _empty_garden(),
		"plots_bought": 0,  # plots bought with sunlight; the garden holds GARDEN_START_PLOTS more
		"dungeons": [],  # [{ id, element, level, scale, waves, x, y }]
		"dungeon_respawns": [],  # [{ at, x, y }]: when the next dungeons appear, and the spot they leave
		"next_dungeon_id": 1,
		"map_seed": 0,  # 0 is the first world map; each prestige rolls a new one (see MapLayout)
	}


# One entry per plot: { seed ("" when empty), grow_left (minutes), stored (resource -> amount) }.
func _empty_garden() -> Array:
	var plots := []
	for i in GameData.GARDEN_START_PLOTS:
		plots.append(_empty_plot())
	return plots


func _empty_plot() -> Dictionary:
	return {"seed": "", "grow_left": 0.0, "stored": {}}


# The Barracks' summoning box: its tier and what has been injected into it.
func _empty_twig_box(tier: int) -> Dictionary:
	return {"tier": tier, "sap": 0.0, "element": "", "power": 0.0}


func _load() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
			return _normalize(data)
	return new_game()


# JSON has no integer type, so restore the whole-number fields after loading.
func _normalize(s: Dictionary) -> Dictionary:
	s["map_seed"] = int(s.get("map_seed", 0))
	GameData.name_set = int(s["tree"].get("prestige", 0))
	_apply_map(s["map_seed"])
	s["tree"]["prestige"] = s["tree"].get("prestige", 0)
	s["tree"]["tap"] = s["tree"].get("tap", GameData.PARTS["tap"]["start"])
	for k in ["level", "xp", "prestige", "roots", "trunk", "branches", "tap"]:
		s["tree"][k] = int(s["tree"][k])
	s["next_troop_id"] = int(s["next_troop_id"])
	var box: Dictionary = s.get("twig_box", _empty_twig_box(1))
	box["tier"] = int(box["tier"])
	s["twig_box"] = box
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
	# The Growth Tonic was replaced by the Longreach Tonic: swap any left over.
	if items.has("growth_tonic"):
		items["reach_tonic"] = items.get("reach_tonic", 0) + items["growth_tonic"]
		items.erase("growth_tonic")
	s["items"] = items
	s["queued_potions"] = s.get("queued_potions", []).map(func(id): return "reach_tonic" if id == "growth_tonic" else id)
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
	if not s.has("plots_bought"):
		# Older saves had every plot free: keep the ones in use, moved to the front.
		garden = garden.filter(func(p): return p["seed"] != "")
		s["plots_bought"] = maxi(0, garden.size() - GameData.GARDEN_START_PLOTS)
	s["plots_bought"] = int(s["plots_bought"])
	while garden.size() < GameData.GARDEN_START_PLOTS + s["plots_bought"]:
		garden.append(_empty_plot())
	s["garden"] = garden
	var dungeons: Array = s.get("dungeons", [])
	var spots := []
	for d in dungeons:
		d["id"] = int(d["id"])
		d["level"] = int(d.get("level", d.get("distance", 1)))  # older saves kept a root distance
		d.erase("distance")
		# A dungeon off the dungeon spots (an older save, or a map layout change) moves to a free one.
		var p := Vector2(d["x"], d["y"])
		if not GameData.dungeon_spot_clear(p, spots):
			p = GameData.roll_dungeon_pos(spots)
			d["x"] = p.x
			d["y"] = p.y
		spots.append(p)
	s["dungeons"] = dungeons
	var respawns := []
	for r in s.get("dungeon_respawns", []):
		# Older saves kept only the time.
		respawns.append(r if r is Dictionary else {"at": r})
	for r in respawns:
		r.erase("distance")
	s["dungeon_respawns"] = respawns
	s["next_dungeon_id"] = int(s.get("next_dungeon_id", 1))
	return s


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func reset() -> void:
	state = new_game()
	_apply_map(0)
	GameData.name_set = 0
	save()
	changed.emit()


# --- Derived values ---------------------------------------------------------

## The garden opens after the first prestige.
func garden_unlocked() -> bool:
	return state["tree"]["prestige"] >= 1

func prestige_mult() -> float:
	return GameData.prestige_mult(state["tree"]["prestige"])

## Growth needed to finish the current level, or to prestige at the max level.
func growth_needed() -> int:
	if state["tree"]["level"] >= GameData.MAX_LEVEL:
		return GameData.prestige_cost()
	return GameData.xp_to_next(state["tree"]["level"])


## The land the tree must have conquered to grow past `level`: the land at
## that reach (so level 2 -> 3 needs the reach 2 land). At the max level it is
## the farthest land, needed to prestige. "" when nothing is required.
func growth_gate(level: int) -> String:
	for id in GameData.LEVEL_ORDER:
		if GameData.LEVELS[id]["distance"] == level:
			return id
	return ""


## The unconquered land holding the tree back right now, or "".
func growth_blocked() -> String:
	var id := growth_gate(state["tree"]["level"])
	return id if id != "" and not level_state(id)["conquered"] else ""


func growth_block_msg(id: String) -> String:
	var l: Dictionary = GameData.LEVELS[id]
	var what := "prestige" if state["tree"]["level"] >= GameData.MAX_LEVEL else "grow to level %d" % (state["tree"]["level"] + 1)
	return "Conquer %s (reach %d) on the World Map to %s." % [GameData.land_name(id), l["distance"], what]

func rates() -> Dictionary:
	var m := prestige_mult()
	return {
		"sunlight": GameData.sunlight_per_min(state["tree"]["branches"]) * m,
		"sap": GameData.sap_per_min(state["tree"]["trunk"]) * m,
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
		if state["levels"][id]["conquered"] and element in GameData.LEVELS[id]["elements"]:
			return true
	return false

## Whether the roots reach any land of `element` (its elemental troop is shown from then on).
func element_in_reach(element: String) -> bool:
	for id in GameData.map_lands():
		if element in GameData.LEVELS[id]["elements"] and can_reach(id):
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
	_update_dungeons()


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
	state["resources"]["sunlight"] += GameData.tap_sunlight(state["tree"]["tap"])
	tapped_stock.emit()
	return _ok()


# Tapping the trunk gathers sap straight into the player's stock.
func tap_trunk() -> Dictionary:
	state["resources"]["sap"] += GameData.tap_sap(state["tree"]["tap"])
	tapped_stock.emit()
	return _ok()


# Tapping a grove bird: sap or sunlight that grows with the tree, a little power
# of a conquered element, or rarely a potion. Returns
# { kind: "sap" | "sunlight" | "power" | "item", id, amount } for the pop-up.
func tap_bird() -> Dictionary:
	var r := randf()
	var elements := GameData.ELEMENTS.filter(has_conquered_element)
	var out: Dictionary
	if r < GameData.BIRD_POTION_CHANCE:
		var item: String = GameData.ITEM_ORDER.pick_random()
		state["items"][item] = item_count(item) + 1
		out = {"kind": "item", "id": item, "amount": 1}
	elif r < GameData.BIRD_POTION_CHANCE + GameData.BIRD_POWER_CHANCE and not elements.is_empty():
		var el: String = elements.pick_random()
		state["resources"]["power"][el] += GameData.BIRD_POWER
		out = {"kind": "power", "id": el, "amount": GameData.BIRD_POWER}
	else:
		var res: String = ["sap", "sunlight"].pick_random()
		var lvl: int = state["tree"]["level"]
		var amount := roundi((GameData.bird_sap(lvl) if res == "sap" else GameData.bird_sunlight(lvl)) * prestige_mult())
		state["resources"][res] += amount
		out = {"kind": res, "id": res, "amount": amount}
	tapped_stock.emit()
	if out["kind"] == "item":
		_done(_ok("A bird dropped a %s!" % GameData.ITEMS[out["id"]]["name"]))
	save()
	return out


func collect_level(id: String) -> Dictionary:
	var ls := level_state(id)
	var amount := floorf(ls["stored"])
	if not ls["conquered"] or amount == 0:
		return _done(_fail("No power stored yet."))
	ls["stored"] -= amount
	for el in GameData.LEVELS[id]["elements"]:
		state["resources"]["power"][el] += amount
	return _done(_ok("Collected %d %s power." % [amount, GameData.elements_text(id)]))


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


# Adds growth (already multiplied by the prestige bonus). At the max level it
# fills toward the prestige cost instead of levelling.
func _add_xp(amount: int) -> int:
	var t: Dictionary = state["tree"]
	t["xp"] += amount
	var ups := 0
	while t["level"] < GameData.MAX_LEVEL and t["xp"] >= GameData.xp_to_next(t["level"]) and growth_blocked() == "":
		t["xp"] -= GameData.xp_to_next(t["level"])
		t["level"] += 1
		ups += 1
	# Growth waits, full, for the land that's holding the tree back.
	t["xp"] = mini(t["xp"], growth_needed())
	return ups


# Feeds sunlight into the tree's growth (1 sunlight = 1 growth × prestige bonus).
# amount < 0 means "exactly enough for the next level". At the max level this
# fills toward the prestige cost and prestiges once it is full.
func channel(amount: int = -1) -> Dictionary:
	var t: Dictionary = state["tree"]
	var m := prestige_mult()
	var needed: int = growth_needed() - t["xp"]
	var blocked := growth_blocked()
	if needed <= 0 and blocked != "":
		return _done(_fail(growth_block_msg(blocked)))
	var spend := 0
	if needed > 0:
		spend = mini(ceili(needed / m) if amount < 0 else amount, int(state["resources"]["sunlight"]))
		if spend <= 0:
			return _done(_fail("Not enough sunlight."))
		state["resources"]["sunlight"] -= spend
	var ups := _add_xp(mini(roundi(spend * m), needed))
	if ups == 0 and blocked != "" and t["xp"] >= growth_needed():
		return _done(_ok("The tree is ready. " + growth_block_msg(blocked)))
	if t["level"] >= GameData.MAX_LEVEL and ups == 0:
		if t["xp"] >= GameData.prestige_cost():
			return _done(_prestige())
		return _done(_ok("Channeled %d sunlight toward prestige." % spend))
	return _done(_ok("The tree grew to level %d!" % t["level"] if ups > 0 else "Channeled %d sunlight." % spend))


func _prestige() -> Dictionary:
	var t: Dictionary = state["tree"]
	t["level"] = 0
	t["xp"] = 0
	t["prestige"] += 1
	GameData.name_set = t["prestige"]
	for part in GameData.PART_ORDER:
		t[part] = 1
	_new_map()
	return _ok("The tree is reborn! Prestige %d: ×%.1f growth, sunlight, sap and troop strength. The world has shifted around it." % [t["prestige"], prestige_mult()])


# Draws the world map for the tree's prestige: each of the first MAP_LAYOUTS
# prestiges has its own (the last one stays after that). The lands and dungeon
# spots move, and the dungeons out there move onto the new spots.
func _new_map() -> void:
	var seed: int = mini(state["tree"]["prestige"], MapLayout.MAP_LAYOUTS)
	state["map_seed"] = seed
	_apply_map(seed)
	var taken := []
	for d in state["dungeons"]:
		var p := GameData.roll_dungeon_pos(taken)
		d["x"] = p.x
		d["y"] = p.y
		taken.append(p)
	for r in state["dungeon_respawns"]:
		r.erase("x")
		r.erase("y")


func _apply_map(seed: int) -> void:
	GameData.layout = MapLayout.generate(seed) if seed != 0 else {}
	if seed != 0:
		MapLayout.clear_backgrounds(seed)
		MapLayout.prepare_background(seed)


## Developer tool: empties the sunlight and sap stock, along with what's waiting to be collected.
func dev_clear_stock() -> Dictionary:
	for res in ["sunlight", "sap"]:
		state["resources"][res] = 0
		state["pending"][res] = 0.0
	save()
	return _done(_ok("Sunlight and sap set to 0."))


## Developer tool: conquers the land the tree's next level needs (as a first
## clear would) and grows the tree a level, raising each part a level too.
func dev_level_up() -> Dictionary:
	var t: Dictionary = state["tree"]
	if t["level"] >= GameData.MAX_LEVEL:
		return _done(_fail("The tree is fully grown. Use Prestige."))
	_dev_conquer(growth_gate(t["level"]))
	t["level"] += 1
	t["xp"] = 0
	for part in GameData.PART_ORDER:
		t[part] = mini(t[part] + 1, t["level"])
	save()
	return _done(_ok("The tree grows to level %d." % t["level"]))


# Marks a land conquered with its first day's power waiting, as a first clear would.
func _dev_conquer(id: String) -> void:
	if id == "" or level_state(id)["conquered"]:
		return
	state["levels"][id] = {"conquered": true, "stored": float(GameData.LEVELS[id]["daily_yield"]), "clears": 1}
	for w in GameData.LEVELS[id]["waves"]:
		mark_enemies_seen(w)


## Developer tool: meets everything the next prestige needs, then prestiges.
## Conquers each land that gates the tree's growth (as a first clear would,
## with its first day's power waiting on the map), grows the tree to the max
## level with full prestige growth, and starts the tree over.
func dev_prestige() -> Dictionary:
	for lvl in range(1, GameData.MAX_LEVEL + 1):
		_dev_conquer(growth_gate(lvl))
	state["tree"]["level"] = GameData.MAX_LEVEL
	state["tree"]["xp"] = GameData.prestige_cost()
	var res := _prestige()
	save()
	return _done(res)


func part_cost(part: String) -> Dictionary:
	return GameData.part_cost(part, state["tree"][part])


func can_upgrade(part: String) -> Dictionary:
	var lvl: int = state["tree"][part]
	if lvl >= GameData.MAX_LEVEL:
		return _fail("Fully grown.")
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
	var msg := "%s upgraded to level %d." % [GameData.PARTS[part]["name"], state["tree"][part]]
	for perk in GameData.PARTS[part].get("perks", []):
		if perk["level"] == state["tree"][part]:
			msg += " %s unlocked: %s!" % [perk["kind"], perk["name"]]
	return _done(_ok(msg))


## Whether a tree part's perk (see GameData.PARTS "perks") is unlocked.
func has_perk(id: String) -> bool:
	for part in GameData.PART_ORDER:
		for perk in GameData.PARTS[part].get("perks", []):
			if perk["id"] == id:
				return state["tree"][part] >= perk["level"]
	return false


func can_buy_plot() -> Dictionary:
	var owned: int = state["garden"].size()
	if owned >= GameData.GARDEN_PLOTS:
		return _fail("The garden is full.")
	if state["resources"]["sunlight"] < GameData.plot_cost(owned):
		return _fail("Not enough sunlight.")
	return _ok()


## Buys another garden plot with sunlight.
func buy_plot() -> Dictionary:
	var check := can_buy_plot()
	if not check["ok"]:
		return _done(check)
	state["resources"]["sunlight"] -= GameData.plot_cost(state["garden"].size())
	state["garden"].append(_empty_plot())
	state["plots_bought"] += 1
	return _done(_ok("A new plot is ready for planting."))


## Why a troop type can't be grown yet, or "" if it is unlocked.
func troop_lock_reason(type: String) -> String:
	var def: Dictionary = GameData.TROOPS[type]
	if state["tree"]["level"] < def["unlock_level"]:
		return "Unlocks at tree level %d" % def["unlock_level"]
	if def["element"] != "" and not has_conquered_element(def["element"]):
		var article := "an" if def["element"] in ["ice"] else "a"
		return "Conquer %s %s land to unlock" % [article, def["element"]]
	return ""


# --- Root box ----------------------------------------------------------------

## Unlocked troop types the root box can yield.
func box_pool() -> Array:
	return GameData.TROOP_ORDER.filter(func(t): return troop_lock_reason(t) == "")


## The odds of the box as it stands (see GameData.box_odds).
func box_odds() -> Dictionary:
	var box: Dictionary = state["twig_box"]
	var owned := {}
	for t in state["troops"]:
		owned[t["type"]] = owned.get(t["type"], 0) + 1
	return GameData.box_odds(box["tier"], box["sap"], GameData.element_troop(box["element"]), box["power"], box_pool(),
		state["tree"]["prestige"], owned)


## Pours one step of sap into the box, up to its brim.
func inject_sap() -> Dictionary:
	var box: Dictionary = state["twig_box"]
	var def := GameData.twig_box(box["tier"])
	var room: float = def["max_sap"] - box["sap"]
	if room <= 0.0:
		return _done(_fail("The box is brimming with sap."))
	var amount := minf(minf(def["sap_step"], room), floorf(state["resources"]["sap"]))
	if amount <= 0.0:
		return _done(_fail("No sap to inject."))
	state["resources"]["sap"] -= amount
	box["sap"] += amount
	return _done(_ok())


## Why `element`'s power can't go into the box, or "" if it can.
func power_block(element: String) -> String:
	var box: Dictionary = state["twig_box"]
	if not has_conquered_element(element):
		var article := "an" if element in ["ice"] else "a"
		return "Conquer %s %s land first." % [article, element]
	if box["element"] != "" and box["element"] != element:
		return "The box already holds %s energy." % box["element"]
	if box["power"] >= GameData.BOX_MAX_POWER:
		return "The box can't hold more energy."
	if state["resources"]["power"][element] < 1.0:
		return "No %s power to inject." % element
	return ""


## Injects one point of an element's power, favouring that element's troop.
func inject_power(element: String) -> Dictionary:
	var block := power_block(element)
	if block != "":
		return _done(_fail(block))
	var box: Dictionary = state["twig_box"]
	state["resources"]["power"][element] -= 1.0
	box["element"] = element
	box["power"] += 1.0
	return _done(_ok())


func can_open_box() -> Dictionary:
	var box: Dictionary = state["twig_box"]
	if state["troops"].size() >= roster_cap():
		return _fail("Roster is full.")
	var need: int = GameData.twig_box(box["tier"])["min_sap"]
	if box["sap"] < need:
		return _fail("Inject at least %d sap to open the box." % need)
	return _ok()


## Opens the box: rolls a troop from its odds and uses up everything injected.
## The result carries the new troop under "troop".
func open_box() -> Dictionary:
	var check := can_open_box()
	if not check["ok"]:
		return _done(check)
	var odds: Dictionary = box_odds()["types"]
	var type := ""
	var roll := randf()
	for t in odds:
		type = t
		roll -= odds[t]
		if roll < 0.0:
			break
	state["twig_box"] = _empty_twig_box(state["twig_box"]["tier"])
	var troop := grant_troop(type)
	var res := _ok()  # the Barracks reveals it
	res["troop"] = troop
	return _done(res)


## Adds a new troop of `type` to the roster (and the formation, if there's room).
func grant_troop(type: String) -> Dictionary:
	var troop := {"id": state["next_troop_id"], "type": type, "element": ""}
	state["next_troop_id"] += 1
	state["troops"].append(troop)
	_auto_place(troop)
	return troop


func can_upgrade_box() -> Dictionary:
	var tier: int = state["twig_box"]["tier"]
	if tier >= GameData.TWIG_BOXES.size():
		return _fail("The box is fully grown.")
	var next := GameData.twig_box(tier + 1)
	if state["tree"]["level"] < next["unlock_level"]:
		return _fail("Grow the tree to level %d first." % next["unlock_level"])
	for res in next["cost"]:
		if state["resources"][res] < next["cost"][res]:
			return _fail("Need %d %s." % [next["cost"][res], res])
	return _ok()


## Upgrades the box a tier. What was injected stays in it.
func upgrade_box() -> Dictionary:
	var check := can_upgrade_box()
	if not check["ok"]:
		return _done(check)
	var box: Dictionary = state["twig_box"]
	var next := GameData.twig_box(box["tier"] + 1)
	for res in next["cost"]:
		state["resources"][res] -= next["cost"][res]
	box["tier"] += 1
	return _done(_ok("The box grows into a %s." % next["name"]))


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


# Lets a troop go for good, taking it out of the roster and the formation.
func dismiss_troop(troop_id: int) -> Dictionary:
	var t := troop_by_id(troop_id)
	if t.is_empty():
		return _done(_fail(""))
	state["troops"].erase(t)
	for f in state["formation"].duplicate():
		if f["troop_id"] == troop_id:
			state["formation"].erase(f)
	return _done(_ok("%s #%d returns to the earth." % [GameData.troop_def(t)["name"], troop_id]))


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


## Picks a battle's potion mushroom, adding its potion to the inventory.
func pick_battle_shroom(b: BattleSim) -> Dictionary:
	var id := b.pick_shroom()
	if id == "":
		return _fail("")
	state["items"][id] = item_count(id) + 1
	save()
	return _done(_ok("Picked a mushroom: +1 %s!" % GameData.ITEMS[id]["name"]))


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
	var sap := 0
	var power := 0
	if won:
		xp = lvl["rewards"]["first_xp"] if first_clear else lvl["rewards"]["xp"]
		sap = lvl["rewards"]["sap"]
		power = GameData.power_reward(b.level_id, first_clear)
		ls["clears"] += 1
		ls["conquered"] = true
	xp = roundi(xp * prestige_mult())
	state["resources"]["sap"] += sap
	if first_clear:
		# The first day's yield waits at the land, ready to collect from the map.
		ls["stored"] = float(lvl["daily_yield"])
	else:
		for el in lvl["elements"]:
			state["resources"]["power"][el] += power
	# Battles reward sunlight, which the player channels into the tree.
	state["resources"]["sunlight"] += xp
	var level_ups := 0
	save()
	changed.emit()
	return {"won": won, "first_clear": first_clear, "xp": xp, "sap": sap, "power": power, "elements": lvl["elements"], "lost": lost,
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
		state["resources"]["sunlight"] += roundi(b.loot_xp * prestige_mult())
	save()
	changed.emit()
	return {"returned": returned, "xp": roundi(b.loot_xp * prestige_mult()), "items": b.loot_items, "seeds": b.loot_seeds, "power": b.loot_power, "lost": lost,
		"level_ups": level_ups, "new_level": state["tree"]["level"]}


# --- Dungeons -------------------------------------------------------------------

func dungeon(id: String) -> Dictionary:
	for d in state["dungeons"]:
		if dungeon_id(d) == id:
			return d
	return {}


static func dungeon_id(d: Dictionary) -> String:
	return "dungeon_%d" % d["id"]


## The level a dungeon's battle is fought in, shaped like a GameData.LEVELS entry.
static func dungeon_level(d: Dictionary) -> Dictionary:
	return {"name": GameData.dungeon_name(d["element"]), "elements": [d["element"]], "distance": d["level"],
		"scale": d["scale"], "waves": d["waves"]}


## Seconds until the next dungeon appears, or -1 if none is on its way.
func next_dungeon_in() -> float:
	if state["dungeon_respawns"].is_empty():
		return -1.0
	var at: float = state["dungeon_respawns"].map(func(r): return r["at"]).min()
	return maxf(0.0, at - _now())


# Brings in dungeons whose respawn time has come, and fills any missing slots.
func _update_dungeons() -> void:
	var now := _now()
	var due: Array = state["dungeon_respawns"].filter(func(r): return r["at"] <= now)
	var waiting: Array = state["dungeon_respawns"].filter(func(r): return r["at"] > now)
	state["dungeon_respawns"] = waiting
	var spawned := false
	for r in due:
		if state["dungeons"].size() + waiting.size() < GameData.DUNGEON_COUNT:
			_spawn_dungeon(Vector2(r["x"], r["y"]) if r.has("x") else Vector2.INF)
			spawned = true
	while state["dungeons"].size() + waiting.size() < GameData.DUNGEON_COUNT:
		_spawn_dungeon()
		spawned = true
	if spawned:
		changed.emit()


# A new dungeon on a free spot, its level near the tree's; `last` is the spot of
# the one it replaces, which it avoids.
func _spawn_dungeon(last := Vector2.INF) -> void:
	var taken := []
	for d in state["dungeons"]:
		taken.append(Vector2(d["x"], d["y"]))
	var d := GameData.roll_dungeon(GameData.ELEMENTS.pick_random(), GameData.roll_dungeon_level(state["tree"]["level"]))
	var pos := GameData.roll_dungeon_pos(taken, last)
	d["id"] = state["next_dungeon_id"]
	d["x"] = pos.x
	d["y"] = pos.y
	state["next_dungeon_id"] += 1
	state["dungeons"].append(d)


func can_enter_dungeon(id: String) -> Dictionary:
	var d := dungeon(id)
	if d.is_empty():
		return _fail("That dungeon has crumbled away.")
	if formation_troops().is_empty():
		return _fail("Place troops in your formation first.")
	return _ok()


# Applies a finished dungeon battle. A cleared dungeon crumbles and gives potions
# and seeds (before the garden opens, only rarely a single one); a new one appears
# later. Fallen troops are lost.
func apply_dungeon_result(b: BattleSim) -> Dictionary:
	var lost := _remove_fallen(b)
	var won := b.phase == "won"
	var items := {}
	var seeds := {}
	var d := dungeon(b.level_id)
	if won and not d.is_empty():
		var n := GameData.dungeon_reward_count(d["level"])
		for i in n:
			var item: String = GameData.ITEM_ORDER.pick_random()
			items[item] = items.get(item, 0) + 1
			state["items"][item] = item_count(item) + 1
		var n_seeds := n if garden_unlocked() else int(randf() < GameData.DUNGEON_EARLY_SEED_CHANCE)
		for i in n_seeds:
			var seed_id := GameData.roll_seed(d["element"])
			seeds[seed_id] = seeds.get(seed_id, 0) + 1
			state["seeds"][seed_id] = state["seeds"].get(seed_id, 0) + 1
		state["dungeons"].erase(d)
		# The next one remembers this spot, so it turns up somewhere else.
		state["dungeon_respawns"].append({"at": _now() + GameData.DUNGEON_RESPAWN_MINUTES * 60.0, "x": d["x"], "y": d["y"]})
	save()
	changed.emit()
	return {"won": won, "items": items, "seeds": seeds, "lost": lost}
