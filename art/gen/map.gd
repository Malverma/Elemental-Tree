# World map art. params.part: "bg" (170x250 terrain, 1 px = 4 map units) or
# "sheet" (landmarks, home grove, dungeon, flag, selection; see SHEET).
# Land positions come from map_data.json (dumped from GameData).
var img: Image
const W := 170
const H := 250
const DATA := "/home/bhizie/Projects/Elemental Tree/art/gen/map_data.json"
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a"), Color("#a06a3a"), Color("#c08850")]
# name -> [x, y, w, h] in the sprite sheet
const SHEET := {
	"map_nature": [0, 0, 20, 20], "map_water": [20, 0, 20, 20], "map_fire": [40, 0, 20, 20],
	"map_ice": [60, 0, 20, 20], "map_dark": [80, 0, 20, 20], "map_grove": [140, 0, 28, 32],
	"dungeon": [0, 34, 13, 12], "map_flag": [16, 34, 8, 11],
	# Dungeons take turns between these looks as they spawn; all are 13x12.
	"dungeon_ruins": [30, 34, 13, 12], "dungeon_stump": [46, 34, 13, 12],
	# Two-element lands: one tree, its crown half one element and half the other.
	"map_water_fire": [62, 34, 20, 20], "map_ice_dark": [82, 34, 20, 20], "map_nature_dark": [102, 34, 20, 20],
	# Plates frame each spot on the map. They're greyscale; the game tints them
	# with the element's colour. A two-element land uses the halves.
	"map_plate": [0, 56, 30, 24], "map_plate_l": [30, 56, 15, 24], "map_plate_r": [45, 56, 15, 24],
	"map_plate_dungeon": [62, 56, 20, 18],
}
# Crown colours (dark to light) for the element trees.
const CROWN := {
	"nature": [Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a")],
	"water": [Color("#1f5f7a"), Color("#2f86a8"), Color("#5bb4d8"), Color("#a8e0f0")],
	"fire": [Color("#8a2a16"), Color("#c8421e"), Color("#f0642d"), Color("#ffb347")],
	"ice": [Color("#7fb0c8"), Color("#bcdcee"), Color("#e2f2fa"), Color("#ffffff")],
	"dark": [Color("#2a1f3a"), Color("#4a3366"), Color("#6d4a96"), Color("#9a6ad8")],
}

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func at(x, y) -> Color:
	return img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func noise(x: float, y: float) -> float:
	return 0.5 * sin(x * 0.21 + sin(y * 0.13) * 2.0) + 0.3 * sin(y * 0.17 + x * 0.05) + 0.2 * sin((x + y) * 0.41)

func shade(n: Vector2, x, y, pal: Array) -> Color:
	var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
	return pal[3] if t > 0.45 and pal.size() > 3 else (pal[2] if t > 0.05 else (pal[1] if t > -0.45 else pal[0]))

func auto_outline(r: Rect2i, amt := 0.72):
	var src = img.get_region(r)
	for y in r.size.y:
		for x in r.size.x:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < r.size.x and q.y < r.size.y and src.get_pixel(q.x, q.y).a > 0.5:
					var c = src.get_pixel(q.x, q.y).darkened(amt)
					c.a = 1.0
					img.set_pixel(r.position.x + x, r.position.y + y, c)
					break

# A round-crowned tree in a 20x20 cell: the crown's left half in `left` colours,
# its right half in `right` (the same for a one-element tree).
func tree_icon(o: Array, left: Array, right: Array, bark: Array):
	for y in range(11, 19):
		var hw = 1 if y < 16 else 2
		for x in range(10 - hw, 10 + hw):
			px(o[0] + x, o[1] + y, bark[1] if x >= 10 else bark[0])
	for c in [[5.5, 10, 4.3], [14.5, 10, 4.5], [10, 6, 5.4]]:
		var cx = o[0] + c[0]
		var cy = o[1] + c[1]
		var r = c[2]
		for y in range(int(cy - r - 1), int(cy + r + 2)):
			for x in range(int(cx - r - 1), int(cx + r + 2)):
				var n = Vector2((x - cx) / r, (y - cy) / (r * 0.95))
				if n.length() <= 1.0 + 0.06 * sin(atan2(n.y, n.x) * 5.0 + cx):
					var pal = left if x < o[0] + 10 else right
					px(x, y, shade(n, x, y, pal))

func pattern(ox, oy, rows: Array, cols: Dictionary):
	for y in rows.size():
		for x in rows[y].length():
			if cols.has(rows[y][x]):
				px(ox + x, oy + y, cols[rows[y][x]])

func blob(cx: float, cy: float, rx: float, ry: float, pal: Array, lumpy := 0.0):
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var n = Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0 + lumpy * sin(atan2(n.y, n.x) * 5.0 + cx):
				px(x, y, shade(n, x, y, pal))

# --- terrain ---------------------------------------------------------------
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
# How wide (art px) the blend between two neighbouring terrains is.
const BLEND := 6.0

# A water land is a lake ringed by a sandy shore, then marshy grass.
func water_ring(dist: float) -> String:
	return "water" if dist < 15.0 else ("shore" if dist < 18.0 else "marsh")

# The two terrains nearest a pixel and how firmly it belongs to the first:
# [kind, other kind, t] with t 0 right on the border and 1 well inside.
func terrain_mix(px_x: int, px_y: int, d: Dictionary) -> Array:
	# Warp where we sample with slow, wide noise so borders curve like coastlines
	# instead of running straight between neighbouring lands.
	var x = px_x + 9.0 * noise(px_y * 0.31 + 11.0, px_x * 0.23) + 3.0 * noise(px_x * 0.9, px_y * 0.8 + 4.0)
	var y = px_y + 9.0 * noise(px_x * 0.27 + 5.0, px_y * 0.33) + 3.0 * noise(px_y * 0.85 + 2.0, px_x * 0.95)
	var nz = noise(x, y) * 7.0
	var near = {"grass": 34.0}
	var g = Vector2(d["grove"][0], d["grove"][1]) / 4.0
	near["home"] = Vector2(x, y).distance_to(g) + nz + 8.0
	for l in d["lands"]:
		var c = Vector2(l["x"], l["y"]) / 4.0
		var dist = Vector2(x, y).distance_to(c) * (1.0 / l.get("scale", 1.0)) + nz
		var els: Array = l["els"]
		var options = [[els[0], dist]]
		if els.size() > 1:
			# two elements share the land, one on each side, meeting down the middle
			var off = (x - c.x) + noise(y, x) * 3.0
			options = [[els[0], dist + maxf(0.0, off)], [els[1], dist + maxf(0.0, -off)]]
		for o in options:
			var kind = water_ring(dist) if o[0] == "water" else o[0]
			near[kind] = minf(near.get(kind, 1e9), o[1])
	var k1 = ""
	var d1 = 1e9
	for k in near:
		if near[k] < d1:
			d1 = near[k]
			k1 = k
	var k2 = k1
	var d2 = 1e9
	for k in near:
		if k != k1 and near[k] < d2:
			d2 = near[k]
			k2 = k
	# lake, shore and marsh rings meet crisply; everything else blends
	var crisp = k1 in ["water", "shore"] or k2 in ["water", "shore"]
	var t = clampf((d2 - d1) / (2.0 if crisp else BLEND), 0.0, 1.0)
	return [k1, k2, t]

# One pixel of a terrain's texture; lava cracks, ripples and sparkles only well inside it.
func terrain_px(k: String, x: int, y: int, deep: bool) -> Color:
	var pal: Array = T_PAL[k]
	var v = noise(x * 2.3, y * 2.3) + (bayer(x, y) - 0.5) * 0.6
	var c: Color = pal[1]
	if v > 0.62: c = pal[2]
	elif v < -0.62: c = pal[0]
	if deep:
		if k == "fire" and absf(noise(x * 1.7, y * 1.1)) < 0.05:
			c = Color("#f0642d") if bayer(x, y) > 0.3 else Color("#ffb347")
		if k == "water" and posmod(x + int(noise(y, x) * 4), 9) == 0 and posmod(y, 5) == 0:
			c = Color("#9fd2f5")
		if k == "ice" and bayer(x, y) > 0.94 and v > 0.2:
			c = Color.WHITE
	return c

func paint_bg():
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var kinds = []
	var firm = []
	for y in H:
		var row = []
		var trow = []
		for x in W:
			var m = terrain_mix(x, y, d)
			var t: float = m[2]
			var c1 = terrain_px(m[0], x, y, t > 0.6)
			var c2 = terrain_px(m[1], x, y, false)
			# A ragged natural edge between the two terrains; greens meet more loosely.
			var greens = m[0] in GREENS and m[1] in GREENS
			var e = t * BLEND + (0.6 * noise(x * 1.3, y * 1.1) + 0.4 * noise(y * 2.9, x * 2.5)) * (4.0 if greens else 2.0)
			var c = c1 if e >= 0.0 else c2
			px(x, y, c)
			row.append(m[0])
			trow.append(t)
		kinds.append(row)
		firm.append(trow)
	# decorations, kept clear of land markers and root paths
	var keep = []
	keep.append(Vector2(d["grove"][0], d["grove"][1]) / 4.0)
	for l in d["lands"]:
		keep.append(Vector2(l["x"], l["y"]) / 4.0)
	var path_px = {}
	for path in d["paths"]:
		for i in range(path.size() - 1):
			var a = Vector2(path[i][0], path[i][1]) / 4.0
			var b = Vector2(path[i + 1][0], path[i + 1][1]) / 4.0
			for s in 8:
				var p = a.lerp(b, s / 8.0)
				for oy in range(-3, 4):
					for ox in range(-3, 4):
						path_px[Vector2i(int(p.x) + ox, int(p.y) + oy)] = true
	var rng = RandomNumberGenerator.new()
	rng.seed = 21
	var placed = []
	for i in 450:
		var p = Vector2(rng.randi_range(3, W - 4), rng.randi_range(4, H - 3))
		var ok = true
		for k in keep:
			if p.distance_to(k + Vector2(0, -7)) < 24:
				ok = false
		for q in placed:
			if p.distance_to(q) < 8:
				ok = false
		if not ok or path_px.has(Vector2i(p)) or firm[int(p.y)][int(p.x)] < 0.5:
			continue
		var k = kinds[int(p.y)][int(p.x)]
		match k:
			"grass", "home", "nature":
				if rng.randf() < (0.35 if k == "nature" else 0.12):
					tree(p.x, p.y, rng.randf() < 0.5)
				elif rng.randf() < 0.2:
					flower(p.x, p.y, [Color("#fff1a8"), Color("#f6a6c1"), Color.WHITE][rng.randi_range(0, 2)])
				else:
					continue
			"marsh":
				if rng.randf() < 0.4: reeds(p.x, p.y)
				else: continue
			"water":
				if rng.randf() < 0.15: lily(p.x, p.y)
				else: continue
			"fire":
				if rng.randf() < 0.3: rock(p.x, p.y, [Color("#2e1a14"), Color("#4a2a22"), Color("#6b4a3a")])
				elif rng.randf() < 0.2: lava(p.x, p.y)
				else: continue
			"ice":
				if rng.randf() < 0.3: pine(p.x, p.y)
				elif rng.randf() < 0.15: rock(p.x, p.y, [Color("#6f9ab5"), Color("#a9d3ea"), Color("#e8f6ff")])
				else: continue
			"dark":
				if rng.randf() < 0.25: dead_tree(p.x, p.y)
				elif rng.randf() < 0.25: shroom(p.x, p.y)
				else: continue
			_:
				continue
		placed.append(p)
	# frame
	for x in W:
		px(x, 0, Color("#14231a")); px(x, H - 1, Color("#14231a"))
	for y in H:
		px(0, y, Color("#14231a")); px(W - 1, y, Color("#14231a"))

func tree(x, y, big: bool):
	var r = 3.0 if big else 2.2
	px(int(x), int(y), BARK[1]); px(int(x), int(y) - 1, BARK[2])
	px(int(x) - 1, int(y) + 1, Color(0, 0, 0, 0.25)); px(int(x) + 1, int(y) + 1, Color(0, 0, 0, 0.25))
	blob(x, y - r - 1, r, r, [LEAF[0], LEAF[1], LEAF[2], LEAF[3]])

func pine(x, y):
	px(int(x), int(y), BARK[1])
	for row in 6:
		var hw = int(row / 2) + 1 if row > 0 else 0
		for dx in range(-hw, hw + 1):
			var c = Color("#2e6b4a") if dx > 0 else Color("#3f8a5e")
			if row < 3 or (row % 2 == 0 and absi(dx) == hw): c = Color("#eef6fa")
			px(int(x) + dx, int(y) - 6 + row, c)

func dead_tree(x, y):
	var c = Color("#2a1f30")
	for i in 6:
		px(int(x), int(y) - i, c)
	px(int(x) - 1, int(y) - 4, c); px(int(x) - 2, int(y) - 5, c); px(int(x) + 1, int(y) - 3, c); px(int(x) + 2, int(y) - 4, c); px(int(x) + 2, int(y) - 5, c)

func shroom(x, y):
	px(int(x), int(y), Color("#e8dcc8"))
	px(int(x) - 1, int(y) - 1, Color("#9a6ad8")); px(int(x), int(y) - 1, Color("#c8a2ff")); px(int(x) + 1, int(y) - 1, Color("#9a6ad8"))

func rock(x, y, pal):
	blob(x, y - 1, 2.2, 1.6, pal)

func lava(x, y):
	blob(x, y, 2.5, 1.4, [Color("#c8321e"), Color("#f0642d"), Color("#ffb347")])

func reeds(x, y):
	for dx in [-1, 1]:
		for i in 3:
			px(int(x) + dx, int(y) - i, Color("#3f7a2a"))
	px(int(x) - 1, int(y) - 3, Color("#7a4e26")); px(int(x) + 1, int(y) - 3, Color("#7a4e26"))

func lily(x, y):
	blob(x, y, 1.8, 1.0, [LEAF[1], LEAF[2], LEAF[3]])

func flower(x, y, c):
	px(int(x), int(y), Color("#ffd166")); px(int(x) - 1, int(y), c); px(int(x) + 1, int(y), c); px(int(x), int(y) - 1, c)

# --- sprites ---------------------------------------------------------------
func sprite_sheet():
	var s = SHEET
	# nature: three round trees
	var o = s["map_nature"]
	for t in [[6, 11, 4.3], [14, 11, 4.6], [10, 7, 5.0]]:
		for i in 4:
			px(o[0] + int(t[0]), o[1] + int(t[1] + t[2]) - 1 + i, BARK[2])
		blob(o[0] + t[0], o[1] + t[1], t[2], t[2] * 0.95, [LEAF[1], LEAF[2], LEAF[3], LEAF[4]], 0.06)
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# water: a weeping willow over a little pool
	o = s["map_water"]
	blob(o[0] + 10, o[1] + 18.2, 5.5, 1.4, [Color("#2f64b5"), Color("#3a78c9"), Color("#5ba4e8")])
	for y in range(9, 19):
		px(o[0] + 10, o[1] + y, BARK[2]); px(o[0] + 9, o[1] + y, BARK[1] if y > 14 else BARK[2])
	blob(o[0] + 10, o[1] + 7.5, 7.0, 4.6, CROWN["water"], 0.05)
	for strand in [[4, 13], [6, 15], [8, 12], [12, 14], [14, 12], [16, 14]]:
		for y in range(10, strand[1]):
			px(o[0] + strand[0], o[1] + y, CROWN["water"][1] if y % 2 else CROWN["water"][2])
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# fire: an ember tree with a blazing crown
	o = s["map_fire"]
	tree_icon(o, CROWN["fire"], CROWN["fire"], [Color("#2a1810"), Color("#3a2212")])
	for f in [[7, 2], [12, 1], [15, 4], [5, 5]]:
		px(o[0] + f[0], o[1] + f[1], Color("#ffd166"))
	px(o[0] + 10, o[1] + 0, Color("#ffb347"))
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# ice: a snowy pine
	o = s["map_ice"]
	for y in range(15, 19):
		px(o[0] + 10, o[1] + y, BARK[2]); px(o[0] + 9, o[1] + y, BARK[1])
	for tier in [[2, 7, 4.0], [6, 12, 6.0], [10, 16, 7.5]]:
		for y in range(tier[0], tier[1]):
			var hw = (y - tier[0] + 1) / float(tier[1] - tier[0]) * tier[2]
			for x in range(int(10 - hw), int(10 + hw) + 1):
				var c = Color("#3f8a6e") if x >= 10 else Color("#2e6b5a")
				if y - tier[0] < 2 or (y == tier[1] - 1 and posmod(x, 2) == 0):
					c = Color("#ffffff") if x >= 10 else Color("#cfe6f2")
				px(o[0] + x, o[1] + y, c)
	px(o[0] + 16, o[1] + 3, Color.WHITE); px(o[0] + 3, o[1] + 8, Color("#e2f2fa"))
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dark: a gnarled tree with a glowing hollow
	o = s["map_dark"]
	var trunk = Color("#3a2c48")
	var tl = Color("#5e4a6e")
	for y in range(7, 18):
		var hw = 1 if y < 14 else (2 if y < 16 else 3)
		for x in range(10 - hw, 10 + hw + 1):
			px(o[0] + x, o[1] + y, tl if x > 10 else trunk)
	for br in [[[10, 9], [7, 6], [5, 5], [4, 3]], [[10, 8], [13, 5], [15, 4], [16, 2]], [[10, 7], [10, 4], [9, 2]]]:
		for i in range(br.size() - 1):
			var a = Vector2(br[i][0], br[i][1])
			var b = Vector2(br[i + 1][0], br[i + 1][1])
			for t in 6:
				var q = a.lerp(b, t / 5.0)
				px(o[0] + int(q.x), o[1] + int(q.y), trunk)
	px(o[0] + 10, o[1] + 12, Color("#d9c2ff")); px(o[0] + 10, o[1] + 13, Color("#9a6ad8"))
	px(o[0] + 4, o[1] + 9, Color("#c8a2ff")); px(o[0] + 16, o[1] + 8, Color("#c8a2ff"))
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# home grove: a full tree with glowing roots
	o = s["map_grove"]
	for y in range(16, 30):
		var hw = 1.5 if y < 26 else 2.5
		for x in range(int(14 - hw), int(14 + hw) + 1):
			px(o[0] + x, o[1] + y, BARK[3] if x > 14 else BARK[2])
	for rt in [[-1, 1, -5, 2], [1, 1, 5, 2], [-1, 2, -3, 3], [1, 2, 3, 3]]:
		for i in 5:
			var t = i / 4.0
			px(o[0] + 14 + int(rt[2] * t), o[1] + 29 + int(rt[3] * t * 0.5), Color("#ffd447") if i == 4 else BARK[1])
	for c in [[14, 7, 7.0], [8, 12, 5.5], [20, 12, 5.5], [14, 13, 6.0]]:
		blob(o[0] + c[0], o[1] + c[1], c[2], c[2] * 0.9, [LEAF[1], LEAF[2], LEAF[3], LEAF[4]], 0.06)
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# two-element lands: one tree, crown split between the elements
	for combo in [["water", "fire"], ["ice", "dark"], ["nature", "dark"]]:
		o = s["map_%s_%s" % combo]
		tree_icon(o, CROWN[combo[0]], CROWN[combo[1]], [BARK[1], BARK[2]])
		auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: a small cave in a mossy rock, eyes in the dark
	o = s["dungeon"]
	blob(o[0] + 6.5, o[1] + 7.0, 5.6, 4.3, [Color("#6f6a5e"), Color("#a39c8e"), Color("#c8c2b4")])
	for x in range(2, 11):
		for y in range(3, 5):
			if img.get_pixel(o[0] + x, o[1] + y).a > 0.5:
				px(o[0] + x, o[1] + y, LEAF[3] if bayer(x, y) > 0.4 else LEAF[2])
	for y in range(6, 12):
		var hw = 2.4 * sqrt(maxf(0.0, 1.0 - pow((y - 11) / 5.0, 2)))
		for x in range(int(6.5 - hw), int(6.5 + hw) + 1):
			px(o[0] + x, o[1] + y, Color("#1a120c"))
	px(o[0] + 5, o[1] + 8, Color("#ffd447")); px(o[0] + 8, o[1] + 8, Color("#ffd447"))
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: small castle ruins, a light in the tower and eyes in the gate
	o = s["dungeon_ruins"]
	pattern(o[0], o[1], [
		"..a.a........",
		"..aaa....b.b.",
		"..aya....bab.",
		"..aab....bab.",
		".maab.c..bab.",
		"..aabcbc.bya.",
		"..aabcccbbab.",
		"..aabcddcbab.",
		"..aabdydybab.",
		".maabddddbabm",
		"mmmmmddddmmmm",
		".MMMMMMMMMMM.",
	], {"a": Color("#c8c2b4"), "b": Color("#a39c8e"), "c": Color("#6f6a5e"), "d": Color("#1a120c"),
		"y": Color("#ffd447"), "m": LEAF[3], "M": LEAF[2]})
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: a great hollow stump, eyes in the dark and mushrooms on its roots
	o = s["dungeon_stump"]
	pattern(o[0], o[1], [
		".............",
		"...TTTTTTT...",
		"..TttTTTttT..",
		"..TtTTtTTtT..",
		"..bTTTTTTTB..",
		"..bbbbbbbbB..",
		".gbbBddBbbBg.",
		".wbbddddbbBw.",
		"..bddydydbB..",
		".rbddddddbBr.",
		"rrbbddddbbBrr",
		".mmmmmmmmmmm.",
	], {"T": Color("#a06a3a"), "t": Color("#d8a868"), "b": Color("#7d4e2a"), "B": Color("#5e3a20"),
		"d": Color("#1a120c"), "y": Color("#ffd447"), "r": BARK[1], "g": Color("#e23b22"), "w": Color("#e8dcc8"), "m": LEAF[3]})
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# conquered flag
	o = s["map_flag"]
	for y in range(1, 10):
		px(o[0] + 1, o[1] + y, BARK[2])
	for y in range(1, 6):
		for x in range(2, 2 + 5 - absi(y - 3)):
			px(o[0] + x, o[1] + y, Color("#ffd447") if y < 3 else Color("#f0b020"))
	px(o[0] + 3, o[1] + 3, LEAF[2])
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# plates
	var round_rim = func(_a): return 1.0
	o = s["map_plate"]
	plate(o[0] + 14.5, o[1] + 11.5, 13.0, 10.0, round_rim)
	# a plate centred on the seam between the two half cells splits into its halves
	plate(s["map_plate_r"][0] - 0.5, s["map_plate_l"][1] + 11.5, 13.0, 10.0, round_rim)
	o = s["map_plate_dungeon"]
	plate(o[0] + 9.5, o[1] + 8.5, 8.5, 7.5, func(a): return 1.0 + 0.09 * absf(sin(a * 4.0)) - 0.05 * absf(sin(a * 7.0 + 1.0)))

# A framed oval: dark outline, a shaded ring, and a see-through middle.
# `rim(angle)` scales the radius, for the dungeon's craggy rock ring.
func plate(cx: float, cy: float, rx: float, ry: float, rim: Callable):
	var shadow = Color(0.08, 0.14, 0.08, 0.45)
	for y in range(int(cy - ry - 3), int(cy + ry + 4)):
		for x in range(int(cx - rx - 3), int(cx + rx + 4)):
			var d = Vector2((x - cx) / rx, (y - cy) / ry)
			var k = rim.call(atan2(d.y, d.x))
			var r = d.length() / k
			var ring = 2.6 / ry
			var c = Color(0, 0, 0, 0)
			if r <= 1.0 - ring:
				c = Color(0.62, 0.62, 0.62, 0.42)
			elif r <= 1.0:
				var t = d.normalized().dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
				c = Color("#ffffff") if t > 0.35 else (Color("#d8d8d8") if t > -0.35 else Color("#a8a8a8"))
				if r < 1.0 - ring * 0.55:
					c = c.darkened(0.25)
			elif r <= 1.0 + 1.3 / ry:
				c = Color("#14231a")
			else:
				# drop shadow just under the bottom edge
				var below = Vector2((x - cx) / rx, (y - 1.5 - cy) / ry)
				if below.length() / rim.call(atan2(below.y, below.x)) <= 1.0 + 1.3 / ry and y > cy:
					c = shadow
			if c.a > 0.0:
				px(x, y, c)

func run(api, image, project, params):
	if params.get("part", "bg") == "bg":
		img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		paint_bg()
		return img
	img = Image.create(170, 82, false, Image.FORMAT_RGBA8)
	sprite_sheet()
	return img
