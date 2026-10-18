extends Control
## Full-screen battle overlay: controls, the auto-battle and the result panel.

const InventoryPanel := preload("res://scripts/ui/inventory_panel.gd")

var main: Control
var level_id: String
var sim: BattleSim
var _canvas: BattleCanvas
var _wave: Label
var _controls: HBoxContainer
var _pause: Button
var _speed: Button
var _loot: Label
var _checkpoint: Control
var _buffs: HBoxContainer
var _buffs_key := ""
var _inventory: Control
var _seen_count := 0
var _element_icon: TextureRect
var _title: Label
var _skip: Button


func _init(p_main: Control, p_sim: BattleSim) -> void:
	main = p_main
	sim = p_sim
	level_id = sim.level_id


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.85)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var col := UI.vbox(10)
	var frame := UI.panel(col)
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(frame)

	var head := UI.hbox(10)
	_element_icon = UI.icon("icon_" + sim.element(), 34)
	head.add_child(_element_icon)
	# A land shows all of its elements; an expedition's icon follows its waves.
	if not sim.expedition:
		for el in sim.level["elements"].slice(1):
			head.add_child(UI.icon("icon_" + el, 34))
	_title = UI.label(sim.level.get("name", ""), "Title")
	head.add_child(_title)
	head.add_child(UI.spacer())
	_wave = UI.label("", "Muted")
	head.add_child(_wave)
	col.add_child(head)
	if sim.expedition:
		_loot = UI.label("", "Small")
		col.add_child(_loot)
	_buffs = UI.hbox(8)
	_buffs.visible = false
	col.add_child(_buffs)

	_controls = UI.hbox(10)
	_pause = UI.button("Pause", _toggle_pause)
	_speed = UI.button("Speed 1×", _toggle_speed)
	_controls.add_child(_pause)
	_controls.add_child(_speed)
	_controls.add_child(_potions_button())
	# Skip once the foes' land is conquered; expeditions skip to the next checkpoint.
	_skip = UI.button("Skip", sim.resolve)
	_controls.add_child(_skip)
	_controls.add_child(UI.spacer())
	_controls.add_child(UI.button("Retreat", _confirm_retreat, "DangerButton"))
	col.add_child(_controls)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = BattleCanvas.VIEW.size.x / BattleCanvas.VIEW.size.y
	aspect.size_flags_vertical = SIZE_EXPAND_FILL
	_canvas = BattleCanvas.new(sim)
	_canvas.finished.connect(_show_result)
	aspect.add_child(_canvas)
	col.add_child(aspect)


func _process(_delta: float) -> void:
	var el := sim.element()
	if sim.expedition:
		_title.text = "Expedition · %s foes" % el.capitalize()
		_element_icon.texture = UI.tex("icon_" + el)
	_skip.visible = Game.level_state(GameData.land_of(el) if sim.expedition else sim.level_id)["conquered"]
	if sim.seen.size() != _seen_count:
		_seen_count = sim.seen.size()
		Game.mark_enemies_seen(sim.seen.keys())
	if sim.phase == "intermission":
		_wave.text = "Next wave…"
	elif sim.expedition:
		_wave.text = "Wave %d%s" % [sim.wave + 1, " · Boss" if sim.is_boss_wave() else ""]
	else:
		_wave.text = "Wave %d / %d%s" % [sim.wave + 1, sim.wave_count(), " · Boss" if sim.is_boss_wave() else ""]
	if _loot:
		_loot.text = "Loot so far: %s" % _loot_text(sim)
	if sim.phase == "checkpoint" and _checkpoint == null:
		_show_checkpoint()
	_refresh_buffs()


func _potions_button() -> Button:
	var b := UI.button("Potions", _open_inventory)
	b.icon = UI.tex("icon_inventory")
	b.add_theme_constant_override("icon_max_width", 28)
	return b


# The battle pauses while the inventory is open.
func _open_inventory() -> void:
	if _inventory or sim.is_over():
		return
	var was_paused := _canvas.paused
	_canvas.paused = true
	_inventory = InventoryPanel.new(sim)
	_inventory.closed.connect(func() -> void:
		_canvas.paused = was_paused
		_inventory = null)
	add_child(_inventory)


# Active potions with the waves they have left. Rebuilt only when that changes.
func _refresh_buffs() -> void:
	var key := ""
	for id in GameData.ITEM_ORDER:
		if sim.potion_active(id):
			key += "%s:%d," % [id, sim.potion_waves_left(id)]
	if key == _buffs_key:
		return
	_buffs_key = key
	for c in _buffs.get_children():
		c.queue_free()
	_buffs.visible = key != ""
	for id in GameData.ITEM_ORDER:
		if sim.potion_active(id):
			var chip := UI.hbox(4)
			chip.add_child(UI.icon(GameData.ITEMS[id]["img"], 26))
			chip.add_child(UI.label("%s · %d" % [GameData.ITEMS[id]["name"], sim.potion_waves_left(id)], "Small"))
			_buffs.add_child(UI.panel(chip, "Card"))


static func _loot_text(b: BattleSim) -> String:
	var items := b.loot_items
	var seeds := b.loot_seeds
	var parts := ["+%d growth" % b.loot_xp]
	for el in GameData.ELEMENTS:
		if b.loot_power.get(el, 0) > 0:
			parts.append("%d %s power" % [b.loot_power[el], el])
	for id in GameData.ITEM_ORDER:
		if items.get(id, 0) > 0:
			parts.append("%d× %s" % [items[id], GameData.ITEMS[id]["name"]])
	for id in GameData.SEED_ORDER:
		if seeds.get(id, 0) > 0:
			parts.append("%d× %s" % [seeds[id], GameData.SEEDS[id]["name"]])
	return ", ".join(parts)


func _centered(panel: Control) -> Control:
	panel.custom_minimum_size.x = 560
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)
	return center


# Every 5th expedition wave: head home with the loot, or press on for more.
func _show_checkpoint() -> void:
	_controls.hide()
	var box := UI.vbox(12)
	var t := UI.label("Checkpoint: wave %d cleared!" % sim.waves_cleared, "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(UI.label("Loot: " + _loot_text(sim), "Heading", true))
	var alive := sim.allies.filter(func(u) -> bool: return u.alive()).size()
	box.add_child(UI.label("%d troop%s still standing." % [alive, "" if alive == 1 else "s"]))
	var next_el := GameData.expedition_element(sim.waves_cleared)
	var next := UI.hbox(6)
	next.add_child(UI.label("Waves %d–%d:" % [sim.waves_cleared + 1, sim.waves_cleared + GameData.EXPEDITION_CHECKPOINT]))
	next.add_child(UI.icon("icon_" + next_el, 26))
	next.add_child(UI.label("%s foes" % next_el.capitalize()))
	box.add_child(next)
	var warn := UI.label("Return now to keep everything, or press on to wave %d for more. If your squad falls or retreats before then, all the loot is lost."
		% (sim.waves_cleared + GameData.EXPEDITION_CHECKPOINT), "Small", true)
	box.add_child(warn)
	box.add_child(_potions_button())
	var row := UI.hbox(10)
	var home := UI.button("Return with loot", sim.return_home, "PrimaryButton")
	home.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(home)
	var on := UI.button("Press on", func() -> void:
		sim.press_on()
		_checkpoint.queue_free()
		_checkpoint = null
		_controls.show(), "DangerButton")
	on.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(on)
	box.add_child(row)
	_checkpoint = _centered(UI.panel(box, "Result"))


func _toggle_pause() -> void:
	_canvas.paused = not _canvas.paused
	_pause.text = "Resume" if _canvas.paused else "Pause"


func _toggle_speed() -> void:
	# Cycles 1× → 2× → 5× → 1×.
	match _canvas.speed:
		1.0:
			_canvas.speed = 2.0
		2.0:
			_canvas.speed = 5.0
		_:
			_canvas.speed = 1.0
	_speed.text = "Speed %d×" % _canvas.speed


func _confirm_retreat() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = ("Retreat? Troops that already fell stay lost,\nand all loot from this expedition is lost." if sim.expedition
		else "Retreat? Troops that already fell stay lost,\nand you earn no victory rewards.")
	d.confirmed.connect(func() -> void:
		sim.phase = "lost"
		sim.retreated = true)
	add_child(d)
	d.popup_centered()


func _show_result() -> void:
	if _inventory:
		_inventory.close()
	if _checkpoint:
		_checkpoint.queue_free()
		_checkpoint = null
	if sim.expedition:
		_show_expedition_result()
		return
	if sim.dungeon:
		_show_dungeon_result()
		return
	var res := Game.apply_battle_result(sim)
	sim.dispose()
	_controls.hide()

	var box := UI.vbox(12)
	var title := "Victory!" if res["won"] else ("Retreated" if sim.retreated else "Defeat")
	var t := UI.label(title, "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 38)
	box.add_child(t)
	if res["first_clear"]:
		var c := UI.label("%s is conquered! It now yields %d %s power per day." % [sim.level["name"], sim.level["daily_yield"], GameData.elements_text(sim.level_id)], "Heading", true)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_theme_color_override("font_color", UI.ACCENT)
		box.add_child(c)
	var growth := "+%d growth" % res["xp"]
	if res["xp_boost"] > 0.0:
		growth += " (Growth Tonic +%d%%)" % roundi(res["xp_boost"] * 100)
	if res["level_ups"] > 0:
		growth += " · Tree reached level %d!" % res["new_level"]
	box.add_child(UI.label(growth, "", true))
	if res["sap"] > 0:
		box.add_child(UI.label("+%d sap" % res["sap"]))
	if res["power"] > 0:
		var pw := UI.hbox(6)
		pw.add_child(UI.label("+%d" % res["power"]))
		for el in res["elements"]:
			pw.add_child(UI.icon("icon_" + el, 26))
		pw.add_child(UI.label("%s power%s" % [GameData.elements_text(sim.level_id), " (a full day's yield)" if res["first_clear"] else " (3 hours' yield)"], "", true))
		box.add_child(pw)
	box.add_child(UI.label("Waves cleared: %d / %d" % [sim.waves_cleared, sim.level["waves"].size()]))
	if res["lost"] > 0:
		var lost := UI.label("%d troop%s fell and %s lost for good." % [res["lost"], "" if res["lost"] == 1 else "s", "is" if res["lost"] == 1 else "are"], "Heading", true)
		lost.add_theme_color_override("font_color", UI.DANGER)
		box.add_child(lost)
	else:
		box.add_child(UI.label("No troops lost."))
	box.add_child(UI.button("Return to map", main.close_battle, "PrimaryButton"))
	_centered(UI.panel(box, "Result"))


func _show_dungeon_result() -> void:
	var res := Game.apply_dungeon_result(sim)
	sim.dispose()
	_controls.hide()

	var box := UI.vbox(12)
	var title := "Dungeon cleared!" if res["won"] else ("Retreated" if sim.retreated else "Defeat")
	var t := UI.label(title, "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 38)
	box.add_child(t)
	if res["won"]:
		box.add_child(UI.label("The %s crumbles. A new dungeon will appear in %d minutes." % [sim.level["name"], GameData.DUNGEON_RESPAWN_MINUTES], "", true))
		for id in GameData.ITEM_ORDER:
			if res["items"].get(id, 0) > 0:
				var row := UI.hbox(8)
				row.add_child(UI.icon(GameData.ITEMS[id]["img"], 32))
				row.add_child(UI.label("%d× %s" % [res["items"][id], GameData.ITEMS[id]["name"]]))
				box.add_child(row)
		for id in GameData.SEED_ORDER:
			if res["seeds"].get(id, 0) > 0:
				var row := UI.hbox(8)
				row.add_child(UI.icon(GameData.SEEDS[id]["img"], 32))
				row.add_child(UI.label("%d× %s (plant it in the Garden)" % [res["seeds"][id], GameData.SEEDS[id]["name"]]))
				box.add_child(row)
	else:
		box.add_child(UI.label("The dungeon still stands. Try again with a stronger squad.", "", true))
	box.add_child(UI.label("Waves cleared: %d / %d" % [sim.waves_cleared, sim.level["waves"].size()]))
	if res["lost"] > 0:
		var lost := UI.label("%d troop%s fell and %s lost for good." % [res["lost"], "" if res["lost"] == 1 else "s", "is" if res["lost"] == 1 else "are"], "Heading", true)
		lost.add_theme_color_override("font_color", UI.DANGER)
		box.add_child(lost)
	else:
		box.add_child(UI.label("No troops lost."))
	box.add_child(UI.button("Return to map", main.close_battle, "PrimaryButton"))
	_centered(UI.panel(box, "Result"))


func _show_expedition_result() -> void:
	var res := Game.apply_expedition_result(sim)
	sim.dispose()
	_controls.hide()

	var box := UI.vbox(12)
	var title := "Expedition complete!" if res["returned"] else ("Retreated" if sim.retreated else "Expedition lost")
	var t := UI.label(title, "Title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 38)
	box.add_child(t)
	box.add_child(UI.label("Waves cleared: %d" % sim.waves_cleared))
	if res["returned"]:
		var growth := "+%d growth" % res["xp"]
		if res["level_ups"] > 0:
			growth += " · Tree reached level %d!" % res["new_level"]
		box.add_child(UI.label(growth, "Heading"))
		for el in GameData.ELEMENTS:
			if res["power"].get(el, 0) > 0:
				var row := UI.hbox(8)
				row.add_child(UI.icon("icon_" + el, 32))
				row.add_child(UI.label("+%d %s power" % [res["power"][el], el]))
				box.add_child(row)
		for id in GameData.ITEM_ORDER:
			if res["items"].get(id, 0) > 0:
				var row := UI.hbox(8)
				row.add_child(UI.icon(GameData.ITEMS[id]["img"], 32))
				row.add_child(UI.label("%d× %s" % [res["items"][id], GameData.ITEMS[id]["name"]]))
				box.add_child(row)
		for id in GameData.SEED_ORDER:
			if res["seeds"].get(id, 0) > 0:
				var row := UI.hbox(8)
				row.add_child(UI.icon(GameData.SEEDS[id]["img"], 32))
				row.add_child(UI.label("%d× %s (plant it in the Garden)" % [res["seeds"][id], GameData.SEEDS[id]["name"]]))
				box.add_child(row)
	elif sim.loot_xp > 0:
		var gone := UI.label("The squad didn't make it home. Lost loot: " + _loot_text(sim), "", true)
		box.add_child(gone)
	if res["lost"] > 0:
		var lost := UI.label("%d troop%s fell and %s lost for good." % [res["lost"], "" if res["lost"] == 1 else "s", "is" if res["lost"] == 1 else "are"], "Heading", true)
		lost.add_theme_color_override("font_color", UI.DANGER)
		box.add_child(lost)
	else:
		box.add_child(UI.label("No troops lost."))
	box.add_child(UI.button("Return to map", main.close_battle, "PrimaryButton"))
	_centered(UI.panel(box, "Result"))
