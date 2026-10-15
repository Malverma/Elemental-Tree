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


func _init(p_main: Control, p_level_id: String, expedition := false) -> void:
	main = p_main
	level_id = p_level_id
	sim = BattleSim.new(level_id, Game.formation_troops(), expedition, Game.take_queued_potions())


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
	head.add_child(UI.icon("icon_" + sim.level["element"], 34))
	head.add_child(UI.label(("Expedition: " if sim.expedition else "") + sim.level["name"], "Title"))
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
	if Game.level_state(level_id)["conquered"]:
		_controls.add_child(UI.button("Skip", sim.resolve))  # expeditions skip to the next checkpoint
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
		_loot.text = "Loot so far: %s" % _loot_text(sim.loot_xp, sim.loot_items, sim.loot_seeds)
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


static func _loot_text(xp: int, items: Dictionary, seeds: Dictionary) -> String:
	var parts := ["+%d growth" % xp]
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
	box.add_child(UI.label("Loot: " + _loot_text(sim.loot_xp, sim.loot_items, sim.loot_seeds), "Heading", true))
	var alive := sim.allies.filter(func(u) -> bool: return u.alive()).size()
	box.add_child(UI.label("%d troop%s still standing." % [alive, "" if alive == 1 else "s"]))
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
	_canvas.speed = 2.0 if _canvas.speed == 1.0 else 1.0
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
		var c := UI.label("%s is conquered! It now yields %d %s power per day." % [sim.level["name"], sim.level["daily_yield"], sim.level["element"]], "Heading", true)
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
		pw.add_child(UI.icon("icon_" + res["element"], 26))
		pw.add_child(UI.label("%s power%s" % [res["element"], " (a full day's yield)" if res["first_clear"] else " (3 hours' yield)"]))
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
		var gone := UI.label("The squad didn't make it home. Lost loot: " + _loot_text(sim.loot_xp, sim.loot_items, sim.loot_seeds), "", true)
		box.add_child(gone)
	if res["lost"] > 0:
		var lost := UI.label("%d troop%s fell and %s lost for good." % [res["lost"], "" if res["lost"] == 1 else "s", "is" if res["lost"] == 1 else "are"], "Heading", true)
		lost.add_theme_color_override("font_color", UI.DANGER)
		box.add_child(lost)
	else:
		box.add_child(UI.label("No troops lost."))
	box.add_child(UI.button("Return to map", main.close_battle, "PrimaryButton"))
	_centered(UI.panel(box, "Result"))
