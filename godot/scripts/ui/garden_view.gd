extends ScrollContainer
## Garden: plant seeds found on expeditions. Saplings gather sunlight and sap,
## elemental flowers gather a little of their element. Tap a plant to collect.

var main: Control
var _cells: Array[PlotCell] = []
var _stored: Label
var _grown_key := ""


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

	var sel: int = main.ui["selected_plot"]
	var garden := UI.vbox(10)
	garden.add_child(UI.label("Garden", "Title"))
	garden.add_child(UI.label("Plant seeds found on expeditions. A seed takes %d minutes to grow, then its plant keeps gathering (up to %d hours' worth). Tap a grown plant to collect."
		% [GameData.GROW_MINUTES, GameData.GARDEN_CAP_MINUTES / 60.0], "Small", true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in GameData.GARDEN_PLOTS:
		var cell := PlotCell.new(i, i == sel)
		cell.tapped.connect(_on_plot_tapped)
		grid.add_child(cell)
		_cells.append(cell)
	garden.add_child(grid)
	col.add_child(UI.panel(garden))

	if sel >= 0 and Game.state["garden"][sel]["seed"] != "":
		col.add_child(UI.panel(_plant_info(sel)))
	col.add_child(UI.panel(_seed_pouch(sel)))
	_grown_key = _grown_state()
	live()


func _plant_info(i: int) -> Control:
	var plot: Dictionary = Game.state["garden"][i]
	var seed: Dictionary = GameData.SEEDS[plot["seed"]]
	var box := UI.vbox(10)
	var head := UI.hbox(10)
	head.add_child(UI.icon(seed["plant_img"], 56))
	var text := UI.vbox(2)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.add_child(UI.label(seed["plant"], "Heading"))
	text.add_child(UI.label("Plot %d · gathers %s" % [i + 1, GameData.seed_yield_text(plot["seed"])], "Small", true))
	head.add_child(text)
	box.add_child(head)
	if plot["grow_left"] <= 0.0:
		var row := UI.hbox(8)
		row.add_child(UI.label("Ready:"))
		_stored = UI.label("", "Heading")
		row.add_child(_stored)
		row.add_child(UI.spacer())
		row.add_child(UI.button("Collect", _collect.bind(i, Vector2.ZERO), "PrimaryButton"))
		box.add_child(row)
	var uproot := UI.button("Uproot", Game.uproot.bind(i), "DangerButton")
	box.add_child(uproot)
	box.add_child(UI.label("Uprooting clears the plot for a new seed. The plant and anything it gathered are lost.", "Small", true))
	return box


# The seeds the player has, with how many and a Plant button.
func _seed_pouch(sel: int) -> Control:
	var box := UI.vbox(8)
	box.add_child(UI.label("Seed pouch", "Heading"))
	if Game.state["seeds"].is_empty():
		box.add_child(UI.label("Your pouch is empty. Expeditions from the Home Grove (World Map) turn up seeds: acorns and seeds of the foes' element.", "Small", true))
		return box
	var target := _plant_target(sel)
	if target < 0:
		box.add_child(UI.label("Every plot is in use. Uproot a plant to make room.", "Small", true))
	elif sel >= 0 and target == sel:
		box.add_child(UI.label("Choose a seed for plot %d." % (sel + 1), "Small", true))
	for id in GameData.SEED_ORDER:
		var s: Dictionary = GameData.SEEDS[id]
		var have: int = Game.state["seeds"].get(id, 0)
		if have <= 0:
			continue
		var row := UI.hbox(10)
		row.add_child(UI.icon(s["img"], 40))
		var text := UI.vbox(0)
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_child(UI.label("%s ×%d" % [s["name"], have]))
		var article := "an" if s["plant"][0] in "AEIOU" else "a"
		text.add_child(UI.label("Grows %s %s: %s" % [article, s["plant"], GameData.seed_yield_text(id)], "Small", true))
		row.add_child(text)
		var plant := UI.button("Plant", _plant.bind(id))
		plant.disabled = target < 0
		row.add_child(plant)
		box.add_child(row)
	return box


# Plants go in the selected plot if it is empty, otherwise the first empty one.
func _plant_target(sel: int) -> int:
	var garden: Array = Game.state["garden"]
	if sel >= 0 and garden[sel]["seed"] == "":
		return sel
	for i in garden.size():
		if garden[i]["seed"] == "":
			return i
	return -1


func _plant(seed_id: String) -> void:
	var target := _plant_target(main.ui["selected_plot"])
	if target >= 0:
		main.ui["selected_plot"] = target
		Game.plant(target, seed_id)


func _on_plot_tapped(i: int, at: Vector2) -> void:
	if _cells[i].is_grown():
		_collect(i, at)
	if main.ui["selected_plot"] != i:
		main.ui["selected_plot"] = i
		main.render()


func _collect(i: int, at: Vector2) -> void:
	var res := Game.collect_plot(i)
	if at == Vector2.ZERO:
		at = _cells[i].get_global_rect().get_center()
	var offset := 0.0
	for r in res["gained"]:
		var color: Color = UI.SAP if r == "sap" else (UI.ROOT_GLOW if r == "sunlight" else GameData.BIOME_COLORS[r])
		main.pop_text("+%d %s" % [res["gained"][r], r], at + Vector2(-40, offset), color)
		offset -= 36


# Which plots are grown; the view rebuilds when a seed finishes growing.
func _grown_state() -> String:
	var key := ""
	for c in _cells:
		key += "1" if c.is_grown() else "0"
	return key


## Called every second by the shell to refresh timers and stored amounts.
func live() -> void:
	for c in _cells:
		c.refresh()
	var key := _grown_state()
	if key != _grown_key:
		_grown_key = key
		main.render()
		return
	if _stored:
		var plot: Dictionary = Game.state["garden"][main.ui["selected_plot"]]
		var parts := []
		for r in GameData.SEEDS[plot["seed"]]["makes"]:
			parts.append("%d %s" % [floori(plot["stored"].get(r, 0.0)), r])
		_stored.text = ", ".join(parts)
