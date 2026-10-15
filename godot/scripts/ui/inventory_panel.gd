extends Control
## Inventory overlay: potions found on expeditions. Opened from the Grove, where
## potions are readied for the next battle, or from a battle, where they work at once.

signal closed

## The running battle, or null when opened from the Grove.
var sim: BattleSim
var _list: VBoxContainer


func _init(p_sim: BattleSim = null) -> void:
	sim = p_sim


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var box := UI.vbox(14)
	var head := UI.hbox(10)
	head.add_child(UI.icon("icon_inventory", 40))
	head.add_child(UI.label("Inventory", "Title"))
	head.add_child(UI.spacer())
	head.add_child(UI.button("Close", close))
	box.add_child(head)
	var how := ("Drink a potion now. It works right away and lasts %d waves." if sim
		else "Drink a potion here and it takes effect when your next battle or expedition starts. Each lasts %d waves.")
	box.add_child(UI.label(how % GameData.POTION_WAVES, "Small", true))
	_list = UI.vbox(10)
	box.add_child(_list)

	var panel := UI.panel(box, "Result")
	panel.custom_minimum_size.x = 600
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.add_child(panel)
	add_child(center)

	Game.changed.connect(_refresh)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var total := 0
	for id in GameData.ITEM_ORDER:
		total += Game.item_count(id)
		_list.add_child(_row(id))
	if total == 0 and Game.state["queued_potions"].is_empty():
		_list.add_child(UI.label("No potions yet. Expeditions on the World Map turn them up.", "Small", true))


func _row(id: String) -> Control:
	var item: Dictionary = GameData.ITEMS[id]
	var count := Game.item_count(id)
	var row := UI.hbox(12)
	row.add_child(UI.icon(item["img"], 56))
	var text := UI.vbox(2)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	var title := UI.hbox(8)
	title.add_child(UI.label(item["name"], "Heading"))
	title.add_child(UI.label("×%d" % count, "Muted"))
	text.add_child(title)
	text.add_child(UI.label(item["desc"], "Small", true))
	var status := _status(id)
	if status != "":
		var s := UI.label(status, "Small", true)
		s.add_theme_color_override("font_color", UI.ACCENT)
		text.add_child(s)
	row.add_child(text)

	var b: Button
	if sim:
		b = UI.button("Drink", func() -> void: Game.drink_in_battle(sim, id), "PrimaryButton")
		b.disabled = count <= 0 or not sim.can_drink(id)
	elif Game.is_queued(id):
		b = UI.button("Put back", Game.unqueue_potion.bind(id))
	else:
		b = UI.button("Drink", Game.queue_potion.bind(id), "PrimaryButton")
		b.disabled = count <= 0
	b.custom_minimum_size.x = 140
	row.add_child(b)
	var card := UI.panel(row, "Card")
	if count <= 0 and status == "":
		card.modulate.a = 0.55
	return card


func _status(id: String) -> String:
	if sim:
		if sim.potion_active(id):
			var left := sim.potion_waves_left(id)
			return "Active · %d wave%s left" % [left, "" if left == 1 else "s"]
	elif Game.is_queued(id):
		return "Ready for your next battle"
	return ""
