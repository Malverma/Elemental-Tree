class_name MapScene
extends PixelScene
## The world map in pixel art: biome terrain, a landmark for each land, the
## Home Grove and the dungeons that come and go. Roots run from the grove to
## every land; the ones your roots reach are solid, with sap pulsing along them.
## Tapping a land, the grove or a dungeon emits `level_selected`.

signal level_selected(id: String)

## One art pixel is this many map units (GameData.MAP_SIZE is 680x1520).
const UNIT := 4.0
const PULSE_SPEED := 14.0  # art px / s
const ROOT := Color("#5e3a20")
const ROOT_LIGHT := Color("#a06a3a")
const ROOT_FAINT := Color(0.23, 0.13, 0.07, 0.5)
const GLOW := Color("#ffd447")
const GLOW_RINGS := [1.0, 0.6, 0.25]  # opacity of each ring of the selection glow

## Where each kind of plate sits relative to its spot, and each plate sprite's centre.
const LAND_PLATE := Vector2(0, -6)
const GROVE_PLATE := Vector2(0, -6)
const DUNGEON_PLATE := Vector2(0, -3)
const PLATES := {"map_plate": Vector2(15, 12), "map_plate_l": Vector2(15, 12), "map_plate_r": Vector2(0, 12),
	"map_plate_dungeon": Vector2(10, 9)}
## Dungeon looks, taken in turn: each new dungeon gets the next id, so a fresh
## spawn shows the next look while existing dungeons keep theirs.
const DUNGEON_ARTS := ["dungeon", "dungeon_ruins", "dungeon_sunken", "dungeon_temple", "dungeon_mine"]
## Half the height of each kind of plate, for placing names under them.
const LAND_HALF := 11.0
const DUNGEON_HALF := 8.5

var selected: String
var _paths := []  # [{"px": Array[Vector2i], "reached": bool, "phase": float}]
var _roots: Node2D
var _hl: Node2D
## The glow around the selected plate: rings of art pixels outward from its
## dark rim, each fainter than the last.
var _glow: Array = []
## Conquered lands glow in their element as their stored power builds up:
## faint from HUE_FROM full, strongest when full. id -> rings like _glow.
const HUE_FROM := 0.25
## Brighter than the biome colours, so each reads against its own terrain.
const HUE_COLORS := {"nature": Color("#c8ff5a"), "water": Color("#3fb4ff"), "fire": Color("#ff7a2e"),
	"ice": Color("#5fd0ff"), "dark": Color("#b77bff")}
var _hue: Node2D
var _hue_rings := {}
var _labels: Control
var _time := 0.0


static func dungeon_art(d: Dictionary) -> String:
	return DUNGEON_ARTS[int(d["id"]) % DUNGEON_ARTS.size()]


static func to_art(p: Vector2) -> Vector2:
	return p / UNIT


func _init(p_selected: String) -> void:
	super()
	selected = p_selected
	design = GameData.MAP_SIZE / UNIT
	contain = true
	# Fill the screen down under the page bar, trimming a sliver off the sides.
	fill_crop = 0.08
	edge_sky = Color("#1f3a24")
	edge_ground = Color("#1f3a24")


func _ready() -> void:
	sprite("map_bg", Vector2.ZERO)
	_build_paths()
	_roots = Node2D.new()
	_roots.draw.connect(_draw_roots)
	world.add_child(_roots)
	# The glows sit under the plates, so they only show around their rims.
	_hue = Node2D.new()
	_hue.draw.connect(_draw_hue)
	world.add_child(_hue)
	for id in GameData.LEVEL_ORDER:
		_hue_rings[id] = _rings_around(_plates_for(id))
	_hl = Node2D.new()
	_hl.draw.connect(_draw_selection)
	world.add_child(_hl)

	# Each spot stands on a plate tinted with its element, so it reads at a glance.
	var g := to_art(GameData.GROVE)
	_plate("map_plate_l", g + GROVE_PLATE, UI.ROOT_GLOW)
	_plate("map_plate_r", g + GROVE_PLATE, UI.ROOT_GLOW)
	_place("map_grove", g, Vector2(14, 28), Color.WHITE)
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var p := to_art(l["pos"])
		var dim := 1.0
		if not l["playable"]:
			dim = 0.45
		elif not Game.can_reach(id):
			dim = 0.6
		var els: Array = l["elements"]
		if els.size() == 1:
			_plate("map_plate", p + LAND_PLATE, _tint(els[0], dim))
		else:
			_plate("map_plate_l", p + LAND_PLATE, _tint(els[0], dim))
			_plate("map_plate_r", p + LAND_PLATE, _tint(els[1], dim))
		# Every land has its own tree.
		_place("tree_" + id, p, Vector2(10, 16), Color.WHITE if dim == 1.0 else Color(0.7, 0.7, 0.75))
		if Game.level_state(id)["conquered"]:
			_place("map_flag", p + Vector2(10, -13), Vector2(1, 10), Color.WHITE)
	for d in Game.state["dungeons"]:
		var reached: bool = d["distance"] <= Game.reach()
		var at := to_art(Vector2(d["x"], d["y"]))
		_plate("map_plate_dungeon", at + DUNGEON_PLATE, _tint(d["element"], 1.0 if reached else 0.6))
		_place(dungeon_art(d), at, Vector2(6, 9), Color.WHITE if reached else Color(0.7, 0.7, 0.75))

	set_selected(selected)

	# Names are drawn smooth, in screen space, over the art.
	_labels = Control.new()
	_labels.set_anchors_preset(PRESET_FULL_RECT)
	_labels.mouse_filter = MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_labels)
	add_child(_labels)


# Plate art is greyscale; this is the tint for an element, faded when out of reach.
static func _tint(element: String, dim: float) -> Color:
	var c: Color = GameData.BIOME_COLORS[element].lightened(0.15)
	return c if dim >= 1.0 else c.lerp(Color(0.55, 0.55, 0.6), 1.0 - dim + 0.2)


# A plate centred on `center`; each plate sprite's own centre is in PLATES.
func _plate(tex_name: String, center: Vector2, tint: Color) -> void:
	_place(tex_name, center, PLATES[tex_name], tint)


# A sprite whose `anchor` (art px inside it) sits on `at`.
func _place(tex_name: String, at: Vector2, anchor: Vector2, tint: Color) -> Sprite2D:
	var s := sprite(tex_name, (at - anchor).round())
	s.modulate = tint
	return s


# Every root path as an ordered run of art pixels, from the grove outward.
func _build_paths() -> void:
	var nodes := GameData.WAYPOINTS.duplicate()
	nodes.merge(GameData.LEVELS)
	var reach := Game.reach()
	for id in nodes:
		var n: Dictionary = nodes[id]
		var pts := GameData.root_path_points(n["from"], id)
		var run: Array[Vector2i] = []
		for i in range(pts.size() - 1):
			var a := to_art(pts[i])
			var b := to_art(pts[i + 1])
			var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
			for s in steps:
				var q := Vector2i(a.lerp(b, float(s) / steps).floor())
				if run.is_empty() or run[-1] != q:
					run.append(q)
		_paths.append({"px": run, "reached": n["distance"] <= reach, "phase": randf() * 100.0})


func set_selected(id: String) -> void:
	selected = id
	_glow = _rings_around(_plates_for(id))
	if _hl:
		_hl.queue_redraw()


# The plate sprites under a spot, as [plate sprite, centre].
func _plates_for(id: String) -> Array:
	var plates := []
	if id == "grove":
		var g := to_art(GameData.GROVE) + GROVE_PLATE
		plates = [["map_plate_l", g], ["map_plate_r", g]]
	elif GameData.LEVELS.has(id):
		var p := to_art(GameData.LEVELS[id]["pos"]) + LAND_PLATE
		plates = [["map_plate", p]] if GameData.LEVELS[id]["elements"].size() == 1 else [["map_plate_l", p], ["map_plate_r", p]]
	else:
		var d := Game.dungeon(id)
		if not d.is_empty():
			plates = [["map_plate_dungeon", to_art(Vector2(d["x"], d["y"])) + DUNGEON_PLATE]]
	return plates


# The rings of art pixels hugging the outside of the given plates, innermost first.
func _rings_around(plates: Array) -> Array:
	var rings := []
	var taken := {}
	for pl in plates:
		var img: Image = UI.tex(pl[0]).get_image()
		var origin := Vector2i((pl[1] - PLATES[pl[0]]).round())
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					taken[origin + Vector2i(x, y)] = true
	var edge: Array = taken.keys()
	for ring in GLOW_RINGS.size():
		var next := {}
		for q in edge:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					# The first ring hugs the rim all round; later ones round off the corners.
					if ring > 0 and dx != 0 and dy != 0:
						continue
					var n: Vector2i = q + Vector2i(dx, dy)
					if not taken.has(n):
						next[n] = true
		for n in next:
			taken[n] = true
		edge = next.keys()
		rings.append(edge)
	return rings


# A pulsing gold glow around the selected plate's dark rim.
func _draw_selection() -> void:
	var a := 0.8 + 0.2 * sin(_time * 4.5)
	for ring in _glow.size():
		for q in _glow[ring]:
			_hl.draw_rect(Rect2(q, Vector2.ONE), Color(GLOW, a * GLOW_RINGS[ring]))


# Each conquered land with power waiting glows in its element(s), a two-element
# land split down the middle; the glow deepens as its store fills.
func _draw_hue() -> void:
	var pulse := 0.85 + 0.15 * sin(_time * 2.5)
	for id in _hue_rings:
		var ls := Game.level_state(id)
		if not ls["conquered"]:
			continue
		var fill: float = ls["stored"] / maxf(1.0, GameData.LEVELS[id]["daily_yield"])
		if fill < HUE_FROM:
			continue
		var strength := lerpf(0.3, 1.0, clampf((fill - HUE_FROM) / (1.0 - HUE_FROM), 0.0, 1.0)) * pulse
		var els: Array = GameData.LEVELS[id]["elements"]
		var mid := roundi(to_art(GameData.LEVELS[id]["pos"]).x + LAND_PLATE.x)
		var rings: Array = _hue_rings[id]
		for ring in rings.size():
			for q in rings[ring]:
				var el: String = els[0] if els.size() == 1 or q.x < mid else els[1]
				_hue.draw_rect(Rect2(q, Vector2.ONE), Color(HUE_COLORS[el], strength * GLOW_RINGS[ring]))


func _process(delta: float) -> void:
	_time += delta
	_hue.queue_redraw()
	_roots.queue_redraw()
	_hl.queue_redraw()
	_labels.queue_redraw()  # follows the map when it's refitted between the bars


func _draw_roots() -> void:
	for path in _paths:
		var run: Array = path["px"]
		if not path["reached"]:
			for i in range(0, run.size(), 3):
				_roots.draw_rect(Rect2(run[i], Vector2.ONE), ROOT_FAINT)
			continue
		for q in run:
			_roots.draw_rect(Rect2(q, Vector2(2, 2)), ROOT)
		for q in run:
			_roots.draw_rect(Rect2(q, Vector2.ONE), ROOT_LIGHT)
		# Sap pulses travelling out from the grove.
		var n := run.size()
		for k in 2:
			var head := int(fmod(_time * PULSE_SPEED + path["phase"] + k * n / 2.0, float(n + 12))) - 6
			for j in 3:
				var i := head - j
				if i >= 0 and i < n:
					_roots.draw_rect(Rect2(run[i], Vector2(2, 2)), Color(GLOW, 1.0 - j * 0.3))


# Names sit on small dark tabs just under their plate (or above it, near the bottom edge).
func _draw_labels() -> void:
	var font := UI.bold_font()
	var fs := 17
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(UI.NIGHT, 0.82)
	tab.set_corner_radius_all(8)
	var lines := [[to_art(GameData.GROVE) + GROVE_PLATE, "Home Grove", Color.WHITE, false, LAND_HALF]]
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var c := to_art(l["pos"]) + LAND_PLATE
		var col := Color.WHITE if Game.can_reach(id) else Color(0.75, 0.75, 0.8)
		lines.append([c, l["name"], col, GameData.label_above(id), LAND_HALF])
	for d in Game.state["dungeons"]:
		var c := to_art(Vector2(d["x"], d["y"])) + DUNGEON_PLATE
		var col := Color.WHITE if d["distance"] <= Game.reach() else Color(0.75, 0.75, 0.8)
		lines.append([c, GameData.DUNGEON_NAMES[d["element"]], col, false, DUNGEON_HALF])
	for line in lines:
		var text: String = line[1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		var h := fs + 8.0
		var c: Vector2 = origin + line[0] * pixel_scale
		var half: float = line[4] * pixel_scale
		var above: bool = line[3] or c.y + half + h > origin.y + design.y * pixel_scale
		var top := c.y - half - h if above else c.y + half
		var box := Rect2(c.x - w / 2.0, top, w, h)
		_labels.draw_style_box(tab, box)
		_labels.draw_string(font, Vector2(box.position.x, box.position.y + fs + 1), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, line[2])


func _tap(local: Vector2) -> void:
	var p := to_design(local)
	var best := ""
	var best_d := 15.0
	var spots := [["grove", to_art(GameData.GROVE) + GROVE_PLATE]]
	for id in GameData.LEVEL_ORDER:
		spots.append([id, to_art(GameData.LEVELS[id]["pos"]) + LAND_PLATE])
	for d in Game.state["dungeons"]:
		spots.append([Game.dungeon_id(d), to_art(Vector2(d["x"], d["y"])) + DUNGEON_PLATE])
	for s in spots:
		var dist: float = p.distance_to(s[1])
		if dist < best_d:
			best_d = dist
			best = s[0]
	if best != "":
		level_selected.emit(best)
