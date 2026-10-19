class_name BarracksScene
extends PixelScene
## The Barracks in pixel art: a hollow under the tree's roots where the
## formation stands on nine sliced-log stumps (front row nearest the top, toward
## the enemy). Troops bob in place and fireflies drift about. Tapping a stump
## emits `pad_tapped`; dragging a troop to another stump moves it (swapping).

signal pad_tapped(row: String, lane: int)

## Stump centres in design px: lanes left to right, rows front to back.
const PAD_COLS := [46, 90, 134]
const PAD_ROWS := [176, 214, 252]
## Design y just below the back row, where the shell can start its own UI.
const GRID_BOTTOM := 272.0
const FIREFLY := Color("#ffd78a")

## The roster troop picked for placing (-1 for none); its stump, and the
## stumps it could go to, show a ring.
var selected_troop := -1
var _troops := {}  # "row:lane" -> Sprite2D
var _rings := {}  # "row:lane" -> Sprite2D
var _placed := {}  # "row:lane" -> troop
var _under: Node2D
var _over: Node2D
var _flies := []
var _time := 0.0
var _drag_key := ""
var _drop_key := ""
var _dragged := false


static func key(row: String, lane: int) -> String:
	return "%s:%d" % [row, lane]


static func pad_center(row: String, lane: int) -> Vector2:
	return Vector2(PAD_COLS[lane], PAD_ROWS[BattleSim.ROWS.find(row)])


func _init(p_selected: int) -> void:
	super()
	selected_troop = p_selected
	edge_sky = Color("#24160d")
	edge_ground = Color("#3e2818")
	ground_row = 150.0


func _ready() -> void:
	backdrop("barracks_bg")
	for row in BattleSim.ROWS:
		for lane in 3:
			var c := pad_center(row, lane)
			sprite("barracks_pad", c - Vector2(20, 10))
			var ring := sprite("barracks_ring", c - Vector2(22, 12))
			ring.visible = false
			_rings[key(row, lane)] = ring
	# Shadows sit under the troops; element gems and fireflies over them.
	_under = Node2D.new()
	_under.draw.connect(_draw_under)
	world.add_child(_under)
	for row in BattleSim.ROWS:
		for lane in 3:
			var t := Sprite2D.new()
			t.centered = false
			t.position = pad_center(row, lane) - Vector2(16, 26)
			world.add_child(t)
			_troops[key(row, lane)] = t
	_over = Node2D.new()
	_over.draw.connect(_draw_over)
	world.add_child(_over)
	for i in 7:
		_flies.append({"home": Vector2(randf_range(24, 156), randf_range(40, 360)), "phase": randf() * TAU, "speed": randf_range(0.3, 0.6)})
	sync()


## Matches the troops on the stumps to the formation.
func sync() -> void:
	_placed.clear()
	for f in Game.state["formation"]:
		_placed[key(f["row"], f["lane"])] = Game.troop_by_id(f["troop_id"])
	for k in _troops:
		var t: Sprite2D = _troops[k]
		var troop: Dictionary = _placed.get(k, {})
		t.visible = not troop.is_empty()
		if t.visible:
			t.texture = UI.tex(GameData.troop_def(troop)["img"])
		t.modulate.a = 0.35 if k == _drag_key else 1.0
	_update_rings()
	_under.queue_redraw()


# Rings mark the selected troop's stump and every stump it can go to; while
# dragging, only the stump under the finger.
func _update_rings() -> void:
	var can_add: bool = Game.state["formation"].size() < Game.formation_slots()
	var sel_placed := false
	for k in _placed:
		if _placed[k].get("id", -2) == selected_troop:
			sel_placed = true
	for k in _rings:
		var on := false
		if _drag_key != "":
			on = k == _drop_key
		elif selected_troop >= 0:
			on = _placed.has(k) or can_add or sel_placed
		_rings[k].visible = on


func _process(delta: float) -> void:
	_time += delta
	# A one-pixel idle bob, each troop on its own beat; the selected one hops.
	var i := 0
	for k in _troops:
		var t: Sprite2D = _troops[k]
		var base: Vector2 = pad_center(k.get_slice(":", 0), int(k.get_slice(":", 1))) - Vector2(16, 26)
		var picked: bool = _placed.get(k, {}).get("id", -2) == selected_troop
		var beat := fmod(_time * (3.2 if picked else 1.4) + i * 0.37, 2.0)
		t.position = base - Vector2(0, (2 if picked else 1) if beat < 1.0 else 0)
		i += 1
	for k in _rings:
		var ring: Sprite2D = _rings[k]
		ring.modulate.a = 0.7 + 0.3 * sin(_time * 4.0)
	_over.queue_redraw()


func _draw_under() -> void:
	for k in _placed:
		var c: Vector2 = pad_center(k.get_slice(":", 0), int(k.get_slice(":", 1)))
		for dy in range(-1, 2):
			var hw := 8 - absi(dy) * 3
			_under.draw_rect(Rect2(c.x - hw, c.y + 3 + dy, hw * 2, 1), Color(0.08, 0.04, 0.02, 0.35))


func _draw_over() -> void:
	# A small gem at each elemental troop's shoulder.
	for k in _placed:
		var el: String = GameData.troop_def(_placed[k])["element"]
		if el == "":
			continue
		var t: Sprite2D = _troops[k]
		var p := t.position + Vector2(25, 3)
		var col: Color = GameData.BIOME_COLORS[el]
		var edge := col.darkened(0.6)
		for d in [Vector2(0, -2), Vector2(-1, -1), Vector2(1, -1), Vector2(-2, 0), Vector2(2, 0), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 2)]:
			_over.draw_rect(Rect2(p + d, Vector2.ONE), edge)
		for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]:
			_over.draw_rect(Rect2(p + d, Vector2.ONE), col)
		_over.draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), col.lightened(0.6))
	# Fireflies wander on slow loops, glowing on and off.
	for f in _flies:
		var t: float = _time * f["speed"] + f["phase"]
		var p: Vector2 = (f["home"] + Vector2(sin(t * 1.3) * 14.0, sin(t * 0.9 + 1.0) * 10.0)).floor()
		var glow := 0.5 + 0.5 * sin(t * 3.0)
		_over.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(FIREFLY, 0.18 * glow))
		_over.draw_rect(Rect2(p, Vector2.ONE), Color(FIREFLY, 0.4 + 0.6 * glow))


# The stump under a design point; the troop standing on it counts too.
func _pad_at(p: Vector2) -> String:
	for row in BattleSim.ROWS:
		for lane in 3:
			var c := pad_center(row, lane)
			if Rect2(c.x - 21, c.y - 28, 42, 42).has_point(p):
				return key(row, lane)
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragged = false
	super(event)


func _tap(local: Vector2) -> void:
	var k := _pad_at(to_design(local))
	if k != "" and not _dragged:
		pad_tapped.emit(k.get_slice(":", 0), int(k.get_slice(":", 1)))


# Dragging a placed troop uses the GUI drag-and-drop, so the shell knows it isn't a swipe.
func _get_drag_data(at: Vector2) -> Variant:
	var k := _pad_at(to_design(at))
	if k == "" or not _placed.has(k):
		return null
	_dragged = true
	_drag_key = k
	var holder := Control.new()
	var img := TextureRect.new()
	img.texture = UI.crisp(GameData.troop_def(_placed[k])["img"])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.size = Vector2(32, 32) * pixel_scale * 1.1
	img.position = -img.size * Vector2(0.5, 0.7)
	holder.add_child(img)
	set_drag_preview(holder)
	sync()
	return {"barracks_pad": true, "row": k.get_slice(":", 0), "lane": int(k.get_slice(":", 1))}


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("barracks_pad")):
		return false
	var k := _pad_at(to_design(at))
	var target := k if k != _drag_key else ""
	if target != _drop_key:
		_drop_key = target
		_update_rings()
	return target != ""


func _drop_data(at: Vector2, data: Variant) -> void:
	var k := _pad_at(to_design(at))
	Game.move_troop(data["row"], data["lane"], k.get_slice(":", 0), int(k.get_slice(":", 1)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_key != "":
		_drag_key = ""
		_drop_key = ""
		sync()
