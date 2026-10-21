class_name GardenScene
extends PixelScene
## The Garden in pixel art: a meadow threaded with the tree's roots, with a
## root-ringed lot for each plot the garden owns (up to GARDEN_PLOTS). Plants
## sway in the breeze; grown plants with something to collect show a bobbing
## badge, growing ones a progress bar. The spot for the next plot shows faintly.
## Tapping a lot emits `lot_tapped`, the next plot's spot `buy_tapped`.

signal lot_tapped(index: int, global_pos: Vector2)
signal buy_tapped

## Lot centres in design px (3 columns x 4 rows), matching art/gen/garden.gd.
const LOT_COLS := [36, 90, 144]
const LOT_ROWS := [150, 200, 250, 300]

var selected := -1
var _lots: Array[Node2D] = []
var _plants: Array[Sprite2D] = []
var _seeds: Array[String] = []
var _sels: Array[Sprite2D] = []
var _marks: Control
var _bob := 0.0


static func lot_center(i: int) -> Vector2:
	return Vector2(LOT_COLS[i % 3], LOT_ROWS[i / 3])


func _init(p_selected: int) -> void:
	super()
	selected = p_selected
	edge_sky = Color("#7fc3f0")
	edge_ground = Color("#55a545")
	ground_row = 112.0


func _ready() -> void:
	backdrop("garden_bg")
	for i in GameData.GARDEN_PLOTS:
		var c := lot_center(i)
		var lot := Node2D.new()
		lot.position = c
		world.add_child(lot)
		_lots.append(lot)
		sprite("garden_lot", Vector2(-20, -12), lot)
		var sel := sprite("garden_lot_sel", Vector2(-21, -14), lot)
		sel.visible = i == selected
		_sels.append(sel)
		# Plants stand on the lot's middle furrow; their art's base is at (16, 30).
		var plant := Sprite2D.new()
		plant.centered = false
		plant.position = Vector2(-16, -26)
		plant.material = wind(0.9, 1.6, i * 0.9)
		lot.add_child(plant)
		_plants.append(plant)
		_seeds.append("?")
	# Badges, bars and hints are drawn smooth, in screen space, over the art.
	_marks = Control.new()
	_marks.set_anchors_preset(PRESET_FULL_RECT)
	_marks.mouse_filter = MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	sync()


## Matches the lots and plant sprites to the garden state.
func sync() -> void:
	var garden: Array = Game.state["garden"]
	for i in _lots.size():
		# Owned plots show in full, the next one to buy faintly, the rest not at all.
		_lots[i].visible = i <= garden.size()
		_lots[i].modulate.a = 1.0 if i < garden.size() else 0.4
	for i in garden.size():
		var plot: Dictionary = garden[i]
		var key: String = "" if plot["seed"] == "" else ("sprout" if plot["grow_left"] > 0.0 else plot["seed"])
		if key == _seeds[i]:
			continue
		_seeds[i] = key
		_plants[i].visible = key != ""
		if key == "sprout":
			_plants[i].texture = UI.tex("plant_sprout")
		elif key != "":
			_plants[i].texture = UI.tex(GameData.SEEDS[key]["plant_img"])
	_marks.queue_redraw()


func _buyable() -> bool:
	return Game.state["garden"].size() < GameData.GARDEN_PLOTS


func set_selected(i: int) -> void:
	selected = i
	for j in _sels.size():
		_sels[j].visible = j == i


static func has_harvest(plot: Dictionary) -> bool:
	if plot["seed"] == "" or plot["grow_left"] > 0.0:
		return false
	for res in plot["stored"]:
		if plot["stored"][res] >= 1.0:
			return true
	return false


func _process(delta: float) -> void:
	_bob = fmod(_bob + delta * 3.0, TAU)
	if selected >= 0:
		_sels[selected].modulate.a = 0.75 + 0.25 * sin(_bob * 1.5)
	_marks.queue_redraw()


func _draw_marks() -> void:
	var garden: Array = Game.state["garden"]
	var s := pixel_scale
	for i in garden.size():
		var plot: Dictionary = garden[i]
		var c := origin + lot_center(i) * s
		if plot["seed"] == "":
			# A soft "+" invites planting.
			var a := 0.35 + 0.15 * sin(_bob + i)
			_marks.draw_line(c + Vector2(-5, 0) * s, c + Vector2(5, 0) * s, Color(1, 1, 1, a), 1.5 * s)
			_marks.draw_line(c + Vector2(0, -5) * s, c + Vector2(0, 5) * s, Color(1, 1, 1, a), 1.5 * s)
		elif plot["grow_left"] > 0.0:
			var t: float = 1.0 - plot["grow_left"] / GameData.GROW_MINUTES
			var bar := Rect2(c + Vector2(-14, 15) * s, Vector2(28, 3) * s)
			_marks.draw_rect(bar.grow(s * 0.5), UI.NIGHT)
			_marks.draw_rect(bar, Color("#4a2c18"))
			_marks.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("#8fdc6a"))
		elif has_harvest(plot):
			var res: String = GameData.SEEDS[plot["seed"]]["makes"].keys()[0]
			var b := c + Vector2(12, -24 + sin(_bob + i * 0.7) * 1.5) * s
			var r := 6.0 * s
			_marks.draw_circle(b + Vector2(0, s * 0.6), r, Color(UI.NIGHT, 0.4))
			_marks.draw_circle(b, r, Color.WHITE)
			_marks.draw_arc(b, r, 0, TAU, 32, UI.ACCENT, s * 0.75, true)
			var icon := UI.crisp(UI.RES_ICON.get(res, "icon_" + res))
			_marks.draw_texture_rect(icon, Rect2(b - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), false)
	if _buyable():
		# The next plot's spot: a sunlight price tag.
		var c := origin + lot_center(garden.size()) * s
		var font := UI.bold_font()
		var fs := 16
		var text := UI.fmt(GameData.plot_cost(garden.size()))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs + 22.0
		var box := Rect2(c.x - w / 2.0, c.y - fs * 0.5 - 6.0, w, fs + 12.0)
		var tab := StyleBoxFlat.new()
		tab.bg_color = Color(UI.NIGHT, 0.8)
		tab.set_corner_radius_all(8)
		_marks.draw_style_box(tab, box)
		_marks.draw_texture_rect(UI.crisp("icon_sunlight"), Rect2(box.position + Vector2(6, 6), Vector2(fs, fs)), false)
		_marks.draw_string(font, Vector2(box.position.x + fs + 10, box.position.y + fs + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _tap(local: Vector2) -> void:
	var p := to_design(local)
	var owned: int = Game.state["garden"].size()
	for i in mini(owned + 1, GameData.GARDEN_PLOTS):
		var c := lot_center(i)
		if Rect2(c.x - 21, c.y - 28, 42, 44).has_point(p):
			if i < owned:
				lot_tapped.emit(i, get_global_transform() * local)
			else:
				buy_tapped.emit()
			return
