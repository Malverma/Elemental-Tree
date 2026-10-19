extends Control
## Garden: a meadow of lots for seeds found on expeditions. Saplings gather
## sunlight and sap, elemental flowers a little of their element. Tap a grown
## plant to collect, tap an empty lot to plant, swipe up for the seed pouch.

var main: Control
var _scene: GardenScene
var _margin: MarginContainer
var _card_row: HBoxContainer
var _status: Label
var _card_key := ""


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_scene = GardenScene.new(main.ui["selected_plot"])
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.lot_tapped.connect(_on_plot_tapped)
	add_child(_scene)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(PRESET_FULL_RECT)
	_margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_margin)
	var col := UI.vbox(4)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_margin.add_child(col)
	var gap := Control.new()
	gap.size_flags_vertical = SIZE_EXPAND_FILL
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_card_row = UI.hbox(0)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_card_row)
	refresh()


## Keeps the overlay clear of the shell's top bar and page indicator.
func apply_insets(top: float, bottom: float) -> void:
	_margin.add_theme_constant_override("margin_top", int(top) + 8)
	_margin.add_theme_constant_override("margin_bottom", int(bottom) + 8)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	_scene.set_selected(main.ui["selected_plot"])
	_scene.sync()
	_card_key = ""
	live()


func sheet_title() -> String:
	return "Seeds"


# What the selected plot holds; the card rebuilds when this changes.
func _card_state() -> String:
	var sel: int = main.ui["selected_plot"]
	if sel < 0 or Game.state["garden"][sel]["seed"] == "":
		return ""
	var plot: Dictionary = Game.state["garden"][sel]
	return "%d:%s:%s" % [sel, plot["seed"], "grown" if plot["grow_left"] <= 0.0 else "growing"]


# A floating card for the selected plant: what it is, how it's doing, collect and uproot.
func _build_card() -> void:
	for c in _card_row.get_children():
		c.queue_free()
	_status = null
	if _card_key == "":
		return
	var i: int = main.ui["selected_plot"]
	var plot: Dictionary = Game.state["garden"][i]
	var seed: Dictionary = GameData.SEEDS[plot["seed"]]
	var row := UI.hbox(12)
	row.add_child(UI.icon("plant_sprout" if plot["grow_left"] > 0.0 else seed["plant_img"], 64))
	var text := UI.vbox(2)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.add_child(UI.label(seed["plant"], "Scene"))
	_status = UI.label("", "SceneSmall")
	text.add_child(_status)
	var yields := UI.label("Gathers " + GameData.seed_yield_text(plot["seed"]), "SceneSmall")
	yields.modulate.a = 0.8
	text.add_child(yields)
	row.add_child(text)
	var buttons := UI.vbox(6)
	if plot["grow_left"] <= 0.0:
		buttons.add_child(UI.button("Collect", _collect.bind(i, Vector2.ZERO), "PrimaryButton"))
	buttons.add_child(UI.button("Uproot", Game.uproot.bind(i), "DangerButton"))
	row.add_child(buttons)
	var card := UI.panel(row, "Pill")
	card.custom_minimum_size.x = 640
	_card_row.add_child(card)


## The seed pouch, shown in the pull-up sheet.
func build_sheet() -> Control:
	var sel: int = main.ui["selected_plot"]
	var box := UI.vbox(12)
	if Game.state["seeds"].is_empty():
		box.add_child(UI.label("Your pouch is empty. Expeditions from the Home Grove (World Map) turn up seeds: acorns and seeds of the foes' element.", "Small", true))
		return UI.panel(box)
	var target := _plant_target(sel)
	if target < 0:
		box.add_child(UI.label("Every lot is in use. Uproot a plant to make room.", "Small", true))
	else:
		box.add_child(UI.label("Choose a seed for lot %d." % (target + 1), "Small", true))
	for id in GameData.SEED_ORDER:
		var s: Dictionary = GameData.SEEDS[id]
		var have: int = Game.state["seeds"].get(id, 0)
		if have <= 0:
			continue
		var row := UI.hbox(12)
		row.add_child(UI.icon(s["img"], 48))
		var text := UI.vbox(0)
		text.size_flags_horizontal = SIZE_EXPAND_FILL
		text.add_child(UI.label("%s ×%d" % [s["name"], have], "Heading"))
		var article := "an" if s["plant"][0] in "AEIOU" else "a"
		text.add_child(UI.label("Grows %s %s: %s" % [article, s["plant"], GameData.seed_yield_text(id)], "Small", true))
		row.add_child(text)
		var plant := UI.button("Plant", _plant.bind(id))
		plant.disabled = target < 0
		row.add_child(plant)
		box.add_child(UI.panel(row, "Card"))
	box.add_child(UI.label("A seed takes %d minutes to grow, then its plant keeps gathering (up to %d hours' worth). Uprooting a plant loses it and anything it gathered."
		% [GameData.GROW_MINUTES, GameData.GARDEN_CAP_MINUTES / 60.0], "Small", true))
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
		main.close_sheet()
		Game.plant(target, seed_id)


func _on_plot_tapped(i: int, at: Vector2) -> void:
	var plot: Dictionary = Game.state["garden"][i]
	if GardenScene.has_harvest(plot):
		_collect(i, at)
	main.ui["selected_plot"] = i
	if plot["seed"] == "":
		main.open_sheet()
	main.render()


func _collect(i: int, at: Vector2) -> void:
	var res := Game.collect_plot(i)
	if at == Vector2.ZERO:
		at = _scene.design_to_global(GardenScene.lot_center(i) + Vector2(0, -12))
	var offset := 0.0
	for r in res["gained"]:
		var color: Color = UI.SAP if r == "sap" else (UI.ROOT_GLOW if r == "sunlight" else GameData.BIOME_COLORS[r])
		main.pop_text("+%d %s" % [res["gained"][r], r], at + Vector2(-40, offset), color)
		offset -= 36


## Called every second by the shell to refresh timers and stored amounts.
func live() -> void:
	_scene.sync()
	var key := _card_state()
	if key != _card_key:
		_card_key = key
		_build_card()
	if _status == null:
		return
	var plot: Dictionary = Game.state["garden"][main.ui["selected_plot"]]
	if plot["grow_left"] > 0.0:
		var secs := ceili(plot["grow_left"] * 60.0)
		_status.text = "Growing · %d:%02d left" % [secs / 60, secs % 60]
		return
	var parts := []
	for r in GameData.SEEDS[plot["seed"]]["makes"]:
		parts.append("%d %s" % [floori(plot["stored"].get(r, 0.0)), r])
	_status.text = "Ready: " + ", ".join(parts)
