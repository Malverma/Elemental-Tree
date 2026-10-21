class_name MapLayout
extends RefCounted
## A fresh world map for each prestige: where every land and dungeon spot
## stands, rolled from a seed, and the terrain painted to fit. The terrain
## painter is the one in art/gen/map.gd that made the first map's map_bg.png.

## Lands stay inside this box, clear of the top bar, the bottom card and their names.
const AREA := Rect2(85, 270, 510, 960)
## Lands keep this far apart across and up/down, to leave room for their names.
const GAP := Vector2(175, 145)
const ROOT_MIN := 165.0
const ROOT_MAX := 330.0
const CANDIDATES := 6
const DUNGEON_SPOT_COUNT := 5
const LABEL_MARGIN := 10.0
## Bump when the layout or terrain rules change, so saved terrain is painted again.
const VERSION := 4
## Prestiges 1 to this each get their own map; later prestiges keep the last one.
const MAP_LAYOUTS := 10


## The layout for `seed`: land id -> { pos, from, label_above }, plus
## "dungeon_spots". Empty if no layout fits (the first map is used instead).
## Fitting every land can take a few seconds, so each seed's layout is saved
## under user:// and only worked out once.
static func generate(seed: int) -> Dictionary:
	var cached := _load_layout(seed)
	if not cached.is_empty():
		return cached
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for attempt in 300:
		var lay := _try(rng)
		if not lay.is_empty():
			_save_layout(seed, lay)
			return lay
	return {}


static func _layout_path(seed: int) -> String:
	return "user://map_layout_v%d_%d.json" % [VERSION, seed]


static func _save_layout(seed: int, lay: Dictionary) -> void:
	var out := {"dungeon_spots": lay["dungeon_spots"].map(func(p): return [p.x, p.y])}
	for id in lay:
		if id != "dungeon_spots":
			out[id] = {"pos": [lay[id]["pos"].x, lay[id]["pos"].y], "from": lay[id]["from"], "label_above": lay[id]["label_above"]}
	var f := FileAccess.open(_layout_path(seed), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


# A saved layout, or {} if there is none (or it misses a land).
static func _load_layout(seed: int) -> Dictionary:
	if not FileAccess.file_exists(_layout_path(seed)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(_layout_path(seed)))
	if not data is Dictionary or not data.has("dungeon_spots"):
		return {}
	var lay := {"dungeon_spots": data["dungeon_spots"].map(func(p): return Vector2(p[0], p[1]))}
	for id in GameData.LEVEL_ORDER + GameData.PRESTIGE_LEVEL_ORDER:
		if not data.has(id):
			return {}
		var l: Dictionary = data[id]
		lay[id] = {"pos": Vector2(l["pos"][0], l["pos"][1]), "from": l["from"], "label_above": l["label_above"]}
	return lay


static func _try(rng: RandomNumberGenerator) -> Dictionary:
	var pos := {"grove": GameData.GROVE}
	var from := {}
	var paths := []  # [PackedVector2Array]
	for id in GameData.LEVEL_ORDER + GameData.PRESTIGE_LEVEL_ORDER:
		# Of a few spots that fit, take the one with the most open ground around it,
		# so the lands spread over the whole map.
		var best := {}
		var found := 0
		for t in 120:
			if found == CANDIDATES:
				break
			var parent: String = pos.keys()[rng.randi_range(0, pos.size() - 1)]
			var p: Vector2 = pos[parent] + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(ROOT_MIN, ROOT_MAX)
			if not AREA.has_point(p) or pos.values().any(func(q): return _crowded(p, q)):
				continue
			var path := _path(pos[parent], p)
			if not _path_clear(path, pos, [parent]) or paths.any(func(o): return _near(p, o, 60.0) or _crosses(path, o)):
				continue
			found += 1
			var room := INF
			for q in pos.values():
				room = minf(room, p.distance_to(q))
			if best.is_empty() or room > best["room"]:
				best = {"pos": p, "from": parent, "path": path, "room": room}
		if best.is_empty():
			return {}
		pos[id] = best["pos"]
		from[id] = best["from"]
		paths.append(best["path"])
	var lay := {}
	# Every plate and name on the map, which must not overlap.
	var boxes := _spot_boxes(pos["grove"], "Home Grove", false, false)
	for id in GameData.LEVEL_ORDER + GameData.PRESTIGE_LEVEL_ORDER:
		lay[id] = {"pos": pos[id], "from": from[id], "label_above": _label_above(id, pos, from)}
		# Room for the longest of the land's names, as they change with each prestige.
		var longest: String = GameData.LAND_NAMES.get(id, [GameData.LEVELS[id]["name"]]).reduce(func(a, b): return a if a.length() >= b.length() else b)
		var mine := _spot_boxes(pos[id], longest, lay[id]["label_above"], false)
		if _overlaps(mine, boxes):
			return {}
		boxes.append_array(mine)
	var spots := []
	for t in 400:
		if spots.size() == DUNGEON_SPOT_COUNT:
			break
		var p := Vector2(rng.randf_range(70, 610), rng.randf_range(GameData.MAP_SAFE_TOP + 60, GameData.MAP_SAFE_BOTTOM - 80))
		var mine := _spot_boxes(p, "Overgrown Burrow", false, true)
		if _overlaps(mine, boxes) or paths.any(func(o): return _near(p, o, 45.0)):
			continue
		spots.append(p)
		boxes.append_array(mine)
	if spots.size() < DUNGEON_SPOT_COUNT:
		return {}
	lay["dungeon_spots"] = spots
	return lay


# The plate and the name tab of a spot at `p`, in map units, as MapScene draws
# them (a land plate is 120x96 units, a dungeon's 80x72; names are ~10 units a letter).
static func _spot_boxes(p: Vector2, name: String, above: bool, dungeon: bool) -> Array:
	var plate := Rect2(p + Vector2(-40, -48), Vector2(80, 72)) if dungeon else Rect2(p + Vector2(-60, -72), Vector2(120, 96))
	var w := name.length() * 10.0 + 20.0
	var top := plate.position.y - 26.0 if above else plate.end.y
	return [plate, Rect2(p.x - w / 2.0, top, w, 26.0)]


static func _overlaps(mine: Array, boxes: Array) -> bool:
	for a in mine:
		for b in boxes:
			if a.grow(LABEL_MARGIN).intersects(b):
				return true
	return false


# Whether `p` sits too close to `q` for both names to fit.
static func _crowded(p: Vector2, q: Vector2, k := 1.0) -> bool:
	var d := (p - q) / (GAP * k)
	return d.length_squared() < 1.0


static func _path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var mid := (a + b) / 2.0 + Vector2(b.y - a.y, -(b.x - a.x)) * 0.15
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


# A root must keep clear of every other spot's plate and the name under it.
static func _path_clear(path: PackedVector2Array, pos: Dictionary, skip: Array) -> bool:
	for id in pos:
		if id in skip:
			continue
		var q: Vector2 = pos[id]
		for i in range(1, path.size() - 1):
			var d := path[i] - q
			if absf(d.x) < 80.0 and d.y > -70.0 and d.y < 105.0:
				return false
	return true


static func _near(p: Vector2, path: PackedVector2Array, r: float) -> bool:
	for q in path:
		if p.distance_to(q) < r:
			return true
	return false


# Whether two roots cross (sharing a start point is fine).
static func _crosses(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in range(1, a.size() - 1):
		for j in range(1, b.size() - 1):
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1]) != null:
				return true
	return false


# A name goes above its land when a root leaves it heading down, or a spot sits just below.
static func _label_above(id: String, pos: Dictionary, from: Dictionary) -> bool:
	var p: Vector2 = pos[id]
	var others := [from[id]]
	for k in from:
		if from[k] == id:
			others.append(k)
	for k in others:
		var d: Vector2 = _path(p, pos[k])[3] - p
		if d.y > 0.0 and absf(d.x) < d.y * 1.2:
			return true
	for k in pos:
		var d: Vector2 = pos[k] - p
		if k != id and d.y > 0.0 and d.y < 190.0 and absf(d.x) < 150.0:
			return true
	return p.y > 1180.0


# --- Terrain ----------------------------------------------------------------------

const W := 170
const H := 380
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a"), Color("#a06a3a"), Color("#c08850")]
const T_PAL := {
	"grass": [Color("#4c9a40"), Color("#5cae4a"), Color("#72c25a")],
	"home": [Color("#4c9a40"), Color("#5cae4a"), Color("#72c25a")],
	"nature": [Color("#3f8738"), Color("#4c9a40"), Color("#5cae4a")],
	"water": [Color("#2f64b5"), Color("#3a78c9"), Color("#5ba4e8")],
	"shore": [Color("#d6c48a"), Color("#e8d9a0"), Color("#f3e8bd")],
	"marsh": [Color("#4a8a5a"), Color("#5a9a66"), Color("#6aaa72")],
	"fire": [Color("#4a2a22"), Color("#6b3a2a"), Color("#8a4a32")],
	"ice": [Color("#a9d3ea"), Color("#cfe6f2"), Color("#eef6fa")],
	"dark": [Color("#3a2c48"), Color("#4a3a5a"), Color("#5e4a6e")],
}
const GREENS := ["grass", "home", "nature", "marsh"]
const BLEND := 6.0

var img: Image
var _lands := []  # [{ c: Vector2 (art px), els }]


static var _painting := {}  # seed -> WorkerThreadPool task id


static func _bg_path(seed: int) -> String:
	return "user://map_bg_v%d_%d.png" % [VERSION, seed]


## Starts painting the terrain (170x380, 1 art px = 4 map units) for the current
## GameData layout on a worker thread, unless it is saved already. It is saved
## under user:// per seed, so each map is only painted once.
static func prepare_background(seed: int) -> void:
	if _painting.has(seed) or FileAccess.file_exists(_bg_path(seed)):
		return
	_painting[seed] = WorkerThreadPool.add_task(func():
		var tmp := _bg_path(seed) + ".tmp"
		MapLayout.new().paint().save_png(tmp)
		DirAccess.rename_absolute(tmp, _bg_path(seed)))


## The terrain for `seed`, or null while it is still being painted.
static func background(seed: int) -> Texture2D:
	prepare_background(seed)
	if _painting.has(seed):
		if not WorkerThreadPool.is_task_completed(_painting[seed]):
			return null
		WorkerThreadPool.wait_for_task_completion(_painting[seed])
		_painting.erase(seed)
	var image := Image.load_from_file(_bg_path(seed))
	return ImageTexture.create_from_image(image) if image and not image.is_empty() else null


## Removes saved terrain of other maps.
static func clear_backgrounds(keep_seed: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("map_bg_") and "user://" + f != _bg_path(keep_seed):
			dir.remove(f)


func paint() -> Image:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for id in GameData.map_lands():
		_lands.append({"c": GameData.node_pos(id) / 4.0, "els": GameData.LEVELS[id]["elements"]})
	var kinds := []
	var firm := []
	for y in H:
		var row := []
		var trow := []
		for x in W:
			var m := _terrain_mix(x, y)
			var t: float = m[2]
			var c1 := _terrain_px(m[0], x, y, t > 0.6)
			var c2 := _terrain_px(m[1], x, y, false)
			# A ragged natural edge between the two terrains; greens meet more loosely.
			var greens: bool = m[0] in GREENS and m[1] in GREENS
			var e := t * BLEND + (0.6 * _noise(x * 1.3, y * 1.1) + 0.4 * _noise(y * 2.9, x * 2.5)) * (4.0 if greens else 2.0)
			img.set_pixel(x, y, c1 if e >= 0.0 else c2)
			row.append(m[0])
			trow.append(t)
		kinds.append(row)
		firm.append(trow)
	_decorate(kinds, firm)
	var frame := Color("#14231a")
	for x in W:
		_px(x, 0, frame)
		_px(x, H - 1, frame)
	for y in H:
		_px(0, y, frame)
		_px(W - 1, y, frame)
	return img


# Trees, reeds, rocks and the like, kept clear of the spots and the roots.
func _decorate(kinds: Array, firm: Array) -> void:
	var keep := [GameData.GROVE / 4.0]
	for l in _lands:
		keep.append(l["c"])
	var path_px := {}
	for id in GameData.map_lands():
		var path := GameData.root_path_points(GameData.node_from(id), id)
		for i in range(path.size() - 1):
			var a := path[i] / 4.0
			var b := path[i + 1] / 4.0
			for s in 8:
				var p := a.lerp(b, s / 8.0)
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						path_px[Vector2i(int(p.x) + ox, int(p.y) + oy)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var placed := []
	for i in 450:
		var p := Vector2(rng.randi_range(3, W - 4), rng.randi_range(4, H - 3))
		if keep.any(func(k): return p.distance_to(k + Vector2(0, -7)) < 24) or placed.any(func(q): return p.distance_to(q) < 8) \
				or path_px.has(Vector2i(p)) or firm[int(p.y)][int(p.x)] < 0.5:
			continue
		match kinds[int(p.y)][int(p.x)]:
			"grass", "home", "nature":
				var k: String = kinds[int(p.y)][int(p.x)]
				if rng.randf() < (0.35 if k == "nature" else 0.12):
					_tree(p.x, p.y, rng.randf() < 0.5)
				elif rng.randf() < 0.2:
					_flower(p.x, p.y, [Color("#fff1a8"), Color("#f6a6c1"), Color.WHITE][rng.randi_range(0, 2)])
				else:
					continue
			"marsh":
				if rng.randf() < 0.4: _reeds(p.x, p.y)
				else: continue
			"water":
				if rng.randf() < 0.15: _blob(p.x, p.y, 1.8, 1.0, [LEAF[1], LEAF[2], LEAF[3]])
				else: continue
			"fire":
				if rng.randf() < 0.3: _blob(p.x, p.y - 1, 2.2, 1.6, [Color("#2e1a14"), Color("#4a2a22"), Color("#6b4a3a")])
				elif rng.randf() < 0.2: _blob(p.x, p.y, 2.5, 1.4, [Color("#c8321e"), Color("#f0642d"), Color("#ffb347")])
				else: continue
			"ice":
				if rng.randf() < 0.3: _pine(p.x, p.y)
				elif rng.randf() < 0.15: _blob(p.x, p.y - 1, 2.2, 1.6, [Color("#6f9ab5"), Color("#a9d3ea"), Color("#e8f6ff")])
				else: continue
			"dark":
				if rng.randf() < 0.25: _dead_tree(p.x, p.y)
				elif rng.randf() < 0.25: _shroom(p.x, p.y)
				else: continue
			_:
				continue
		placed.append(p)


# A water land is a lake ringed by a sandy shore, then marshy grass.
static func _water_ring(dist: float) -> String:
	return "water" if dist < 15.0 else ("shore" if dist < 18.0 else "marsh")


# The two terrains nearest a pixel and how firmly it belongs to the first:
# [kind, other kind, t] with t 0 right on the border and 1 well inside.
func _terrain_mix(px_x: int, px_y: int) -> Array:
	# Warp where we sample with slow, wide noise so borders curve like coastlines.
	var x := px_x + 9.0 * _noise(px_y * 0.31 + 11.0, px_x * 0.23) + 3.0 * _noise(px_x * 0.9, px_y * 0.8 + 4.0)
	var y := px_y + 9.0 * _noise(px_x * 0.27 + 5.0, px_y * 0.33) + 3.0 * _noise(px_y * 0.85 + 2.0, px_x * 0.95)
	var at := Vector2(x, y)
	var nz := _noise(x, y) * 7.0
	# The grove keeps a little meadow of its own, whichever lands crowd round it.
	var near := {"grass": 34.0, "home": at.distance_to(GameData.GROVE / 4.0) * 1.6 + nz - 6.0}
	for l in _lands:
		var c: Vector2 = l["c"]
		var dist := at.distance_to(c) + nz
		var els: Array = l["els"]
		var options := [[els[0], dist]]
		if els.size() > 1:
			# two elements share the land, one on each side, meeting down the middle
			var off := (x - c.x) + _noise(y, x) * 3.0
			options = [[els[0], dist + maxf(0.0, off)], [els[1], dist + maxf(0.0, -off)]]
		for o in options:
			var kind: String = _water_ring(dist) if o[0] == "water" else o[0]
			near[kind] = minf(near.get(kind, 1e9), o[1])
	var k1 := ""
	var d1 := 1e9
	for k in near:
		if near[k] < d1:
			d1 = near[k]
			k1 = k
	var k2 := k1
	var d2 := 1e9
	for k in near:
		if k != k1 and near[k] < d2:
			d2 = near[k]
			k2 = k
	# lake, shore and marsh rings meet crisply; everything else blends
	var crisp := k1 in ["water", "shore"] or k2 in ["water", "shore"]
	return [k1, k2, clampf((d2 - d1) / (2.0 if crisp else BLEND), 0.0, 1.0)]


# One pixel of a terrain's texture; lava cracks, ripples and sparkles only well inside it.
static func _terrain_px(k: String, x: int, y: int, deep: bool) -> Color:
	var pal: Array = T_PAL[k]
	var v := _noise(x * 2.3, y * 2.3) + (_bayer(x, y) - 0.5) * 0.6
	var c: Color = pal[1]
	if v > 0.62:
		c = pal[2]
	elif v < -0.62:
		c = pal[0]
	if deep:
		if k == "fire" and absf(_noise(x * 1.7, y * 1.1)) < 0.05:
			c = Color("#f0642d") if _bayer(x, y) > 0.3 else Color("#ffb347")
		if k == "water" and posmod(x + int(_noise(y, x) * 4), 9) == 0 and posmod(y, 5) == 0:
			c = Color("#9fd2f5")
		if k == "ice" and _bayer(x, y) > 0.94 and v > 0.2:
			c = Color.WHITE
	return c


static func _bayer(x: int, y: int) -> float:
	const M := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (M[posmod(y, 4) * 4 + posmod(x, 4)] + 0.5) / 16.0


static func _noise(x: float, y: float) -> float:
	return 0.5 * sin(x * 0.21 + sin(y * 0.13) * 2.0) + 0.3 * sin(y * 0.17 + x * 0.05) + 0.2 * sin((x + y) * 0.41)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c if c.a >= 1.0 else img.get_pixel(x, y).blend(c))


func _blob(cx: float, cy: float, rx: float, ry: float, pal: Array) -> void:
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var n := Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0:
				var t := n.dot(Vector2(0.55, -0.83)) + _bayer(x, y) * 0.3 - 0.15
				_px(x, y, pal[3] if t > 0.45 and pal.size() > 3 else (pal[2] if t > 0.05 else (pal[1] if t > -0.45 else pal[0])))


func _tree(x: float, y: float, big: bool) -> void:
	var r := 3.0 if big else 2.2
	_px(int(x), int(y), BARK[1])
	_px(int(x), int(y) - 1, BARK[2])
	_px(int(x) - 1, int(y) + 1, Color(0, 0, 0, 0.25))
	_px(int(x) + 1, int(y) + 1, Color(0, 0, 0, 0.25))
	_blob(x, y - r - 1, r, r, [LEAF[0], LEAF[1], LEAF[2], LEAF[3]])


func _pine(x: float, y: float) -> void:
	_px(int(x), int(y), BARK[1])
	for row in 6:
		var hw := row / 2 + 1 if row > 0 else 0
		for dx in range(-hw, hw + 1):
			var c := Color("#2e6b4a") if dx > 0 else Color("#3f8a5e")
			if row < 3 or (row % 2 == 0 and absi(dx) == hw):
				c = Color("#eef6fa")
			_px(int(x) + dx, int(y) - 6 + row, c)


func _dead_tree(x: float, y: float) -> void:
	var c := Color("#2a1f30")
	for i in 6:
		_px(int(x), int(y) - i, c)
	for d in [Vector2i(-1, -4), Vector2i(-2, -5), Vector2i(1, -3), Vector2i(2, -4), Vector2i(2, -5)]:
		_px(int(x) + d.x, int(y) + d.y, c)


func _shroom(x: float, y: float) -> void:
	_px(int(x), int(y), Color("#e8dcc8"))
	_px(int(x) - 1, int(y) - 1, Color("#9a6ad8"))
	_px(int(x), int(y) - 1, Color("#c8a2ff"))
	_px(int(x) + 1, int(y) - 1, Color("#9a6ad8"))


func _reeds(x: float, y: float) -> void:
	for dx in [-1, 1]:
		for i in 3:
			_px(int(x) + dx, int(y) - i, Color("#3f7a2a"))
	_px(int(x) - 1, int(y) - 3, Color("#7a4e26"))
	_px(int(x) + 1, int(y) - 3, Color("#7a4e26"))


func _flower(x: float, y: float, c: Color) -> void:
	_px(int(x), int(y), Color("#ffd166"))
	_px(int(x) - 1, int(y), c)
	_px(int(x) + 1, int(y), c)
	_px(int(x), int(y) - 1, c)
