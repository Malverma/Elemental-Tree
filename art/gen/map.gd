# World map art. params.part: "bg" (170x380 terrain, 1 px = 4 map units) or
# "sheet" (landmarks, home grove, dungeon, flag, selection; see SHEET).
# Land positions come from map_data.json (dumped from GameData).
var img: Image
const W := 170
const H := 380
const DATA := "/home/bhizie/Projects/Elemental Tree/art/gen/map_data.json"
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a"), Color("#a06a3a"), Color("#c08850")]
# name -> [x, y, w, h] in the sprite sheet
const SHEET := {
	# One tree per land, each its own design.
	"tree_sunny_meadow": [0, 0, 20, 20], "tree_whispering_spring": [20, 0, 20, 20], "tree_ember_vent": [40, 0, 20, 20],
	"tree_frostbite_hollow": [60, 0, 20, 20], "tree_gloomroot_cavern": [80, 0, 20, 20],
	"tree_brambleheart_thicket": [100, 0, 20, 20], "tree_sunken_lagoon": [120, 0, 20, 20], "map_grove": [140, 0, 28, 32],
	"dungeon": [0, 34, 13, 12], "map_flag": [16, 34, 8, 11],
	# Dungeons take turns between these looks as they spawn; all are 13x12.
	"dungeon_ruins": [30, 34, 13, 12], "dungeon_sunken": [46, 34, 13, 12],
	"dungeon_temple": [124, 34, 13, 12], "dungeon_mine": [140, 34, 13, 12],
	# The two-element lands' trees.
	"tree_steamvent_marsh": [62, 34, 20, 20], "tree_frostshade_barrows": [82, 34, 20, 20], "tree_blighted_heartwood": [102, 34, 20, 20],
	# The two-element lands that only grow on the maps after a prestige.
	"tree_mossmire_fen": [84, 56, 20, 20], "tree_cinderfrost_peak": [104, 56, 20, 20], "tree_cindergloom_wastes": [124, 56, 20, 20],
	# Plates frame each spot on the map. They're greyscale; the game tints them
	# with the element's colour. A two-element land uses the halves.
	"map_plate": [0, 56, 30, 24], "map_plate_l": [30, 56, 15, 24], "map_plate_r": [45, 56, 15, 24],
	"map_plate_dungeon": [62, 56, 20, 18],
}
# Crown colours (dark to light) for the element trees.
const CROWN := {
	"nature": [Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a")],
	"water": [Color("#153a86"), Color("#1f5cc0"), Color("#3489e6"), Color("#7cc8ff")],
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

# A blob whose left half (x < split_x) takes `left` colours and right half `right`.
func split_blob(cx: float, cy: float, rx: float, ry: float, left: Array, right: Array, split_x: float, lumpy := 0.0):
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var n = Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0 + lumpy * sin(atan2(n.y, n.x) * 5.0 + cx):
				px(x, y, shade(n, x, y, left if x < split_x else right))

# Pixels along a quadratic curve from a through control c to b, `steps` of them.
func curve(a: Vector2, c: Vector2, b: Vector2, steps: int) -> Array:
	var out = []
	for t in steps + 1:
		var u = float(t) / steps
		out.append([a.lerp(c, u).lerp(c.lerp(b, u), u), u])
	return out

# A tapering trunk from y0 down to y1 at x 10, `hw(y)` half width, dark left, light right.
func trunk(o: Array, y0: int, y1: int, hw: Callable, dark: Color, light: Color):
	for y in range(y0, y1 + 1):
		var w: int = hw.call(y)
		for x in range(10 - w, 10 + w):
			px(o[0] + x, o[1] + y, light if x >= 10 else dark)

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
	# One tree per land.
	tree_meadow(s["tree_sunny_meadow"])
	var o
	# water: a mangrove standing in a lagoon on arching prop roots
	o = s["tree_whispering_spring"]
	var cw = CROWN["water"]
	var foam = Color("#e6f7ff")
	blob(o[0] + 10, o[1] + 17.6, 9.0, 2.0, [Color("#1d4f9e"), Color("#2a6cc4"), Color("#4b97e0")])
	for x in [3, 4, 8, 13, 14, 15]:
		px(o[0] + x, o[1] + (18 if x % 2 else 17), Color("#9fd4ff"))
	# Prop roots arch out from the trunk and curve down into the water.
	# [end x, start y, bend y]: two arches each side and a short one down the middle.
	for r in [[4.0, 12.0, 10.5], [7.0, 14.0, 14.0], [10.5, 14.0, 15.0], [13.0, 14.0, 14.0], [16.0, 12.0, 10.5]]:
		var a = Vector2(10, r[1])
		var e = Vector2(r[0], 17)
		var c = Vector2(10 + (r[0] - 10) * 0.8, r[2])
		for t in 13:
			var u = t / 12.0
			var q = a.lerp(c, u).lerp(c.lerp(e, u), u)
			px(o[0] + int(round(q.x)), o[1] + int(round(q.y)), BARK[2] if q.x < 10 else BARK[3])
		px(o[0] + int(r[0]) - 1, o[1] + 17, foam); px(o[0] + int(r[0]) + 1, o[1] + 17, foam)
	for y in range(6, 15):
		px(o[0] + 9, o[1] + y, BARK[1]); px(o[0] + 10, o[1] + y, BARK[2])
	# Leaves: clusters of glossy, pointed water leaves, each clump catching the light.
	for cl in [[3.2, 7.4, 2.6], [16.8, 7.4, 2.6], [6.2, 4.6, 2.9], [13.8, 4.6, 2.9], [10.0, 2.8, 3.0],
			[10.0, 6.8, 3.2], [6.4, 8.4, 2.4], [13.6, 8.4, 2.4]]:
		blob(o[0] + cl[0], o[1] + cl[1], cl[2], cl[2] * 0.8, cw, 0.12)
	# Break the clumps into overlapping oval leaves, staggered row to row: each
	# leaf lit along its top and parted from its neighbour by a dark vein.
	for y in range(0, 13):
		for x in range(0, 20):
			var lvl = cw.find(img.get_pixel(o[0] + x, o[1] + y))
			if lvl < 0:
				continue
			var cx = posmod(x + (y / 2 % 2) * 2, 4)
			if cx == 3:
				lvl -= 1
			elif y % 2 == 0:
				lvl += 1 if cx == 1 else 0
			else:
				lvl -= 1 if cx == 0 else 0
			px(o[0] + x, o[1] + y, cw[clampi(lvl, 0, 3)])
	# Drops dripping from the leaf tips.
	for d in [[2, 10], [18, 10]]:
		px(o[0] + d[0], o[1] + d[1], Color("#9fd4ff"))
	tree_ember(s["tree_ember_vent"])
	tree_fir(s["tree_frostbite_hollow"])
	tree_shroom(s["tree_gloomroot_cavern"])
	tree_thicket(s["tree_brambleheart_thicket"])
	tree_palm(s["tree_sunken_lagoon"])
	tree_cypress(s["tree_steamvent_marsh"])
	tree_barrow(s["tree_frostshade_barrows"])
	tree_willow(s["tree_blighted_heartwood"])
	tree_bog_oak(s["tree_mossmire_fen"])
	tree_split_fir(s["tree_cinderfrost_peak"])
	tree_obsidian(s["tree_cindergloom_wastes"])
	for key in s:
		if key.begins_with("tree_"):
			auto_outline(Rect2i(s[key][0], s[key][1], s[key][2], s[key][3]))
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
	# dungeon: a small cave in a mossy rock, eyes in the dark
	o = s["dungeon"]
	blob(o[0] + 6.5, o[1] + 7.0, 5.6, 4.3, [Color("#6f6a5e"), Color("#a39c8e"), Color("#c8c2b4")])
	for x in range(2, 11):
		for y in range(3, 5):
			if img.get_pixel(o[0] + x, o[1] + y).a > 0.5:
				px(o[0] + x, o[1] + y, LEAF[3] if bayer(x, y) > 0.4 else LEAF[2])
	for y in range(6, 12):
		var hw = 2.6 * sqrt(maxf(0.0, 1.0 - pow((y - 11) / 5.0, 2)))
		for x in range(13):
			if absf(x - 6) <= hw:
				px(o[0] + x, o[1] + y, Color("#1a120c"))
	px(o[0] + 5, o[1] + 9, Color("#ffd447")); px(o[0] + 7, o[1] + 9, Color("#ffd447"))
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: a castle, two towers and a wall with an arched gate, a pennant on top
	o = s["dungeon_ruins"]
	pattern(o[0], o[1], [
		"......pFF....",
		"......p......",
		"a.a...p...a.a",
		"aaa.a.a.a.aaa",
		"aba.aaaaa.aba",
		"adaaaaaaaaada",
		"abaaabbbaaaba",
		"abaabdddbaaba",
		"abaabdddbaaba",
		"abaabdddbaaba",
		"mmmmmdddmmmmm",
		".MMMMMMMMMMM.",
	], {"a": Color("#c8c2b4"), "b": Color("#8a8478"), "d": Color("#1a120c"), "p": BARK[2], "F": Color("#e23b22"),
		"m": LEAF[3], "M": LEAF[2]})
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: sunken ruins, old columns and a broken lintel rising from the water
	o = s["dungeon_sunken"]
	pattern(o[0], o[1], [
		".............",
		"aaaaaaaa.....",
		"bbbbbbbb..aaa",
		".ab..ab...ab.",
		".ab..ab...ab.",
		".ab..ab.a.ab.",
		".abg.ab.ab.ab",
		"WWWWWWWWWWWWW",
		"wwLwwwWwwLwww",
		"wWwwwLwwwwwWw",
		".wwwwwwwwwww.",
		".............",
	], {"a": Color("#d8dccc"), "b": Color("#9aa494"), "g": LEAF[3],
		"W": Color("#5ba4e8"), "w": Color("#2f64b5"), "L": Color("#bfe6ff")})
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: a stepped temple, stairs up the middle to a shrine with a glowing gem
	o = s["dungeon_temple"]
	pattern(o[0], o[1], [
		".....ccc.....",
		".....cyc.....",
		"....aaaaa....",
		"....bsssb....",
		"...amsssaa...",
		"...bbsssbb...",
		"..aaasssama..",
		"..bbbsssbbb..",
		".maaasssaaaa.",
		".bbbbsssbbbb.",
		"aaaaasssaaaam",
		".MMMMMMMMMMM.",
	], {"a": Color("#e4d0a0"), "b": Color("#b49a68"), "s": Color("#f4e8c8"), "c": Color("#8a7048"),
		"y": Color("#7ff0e0"), "m": LEAF[3], "M": LEAF[2]})
	auto_outline(Rect2i(o[0], o[1], o[2], o[3]))
	# dungeon: a mine, a timber-framed tunnel in a rocky hill, rails and a cart of ore
	o = s["dungeon_mine"]
	pattern(o[0], o[1], [
		"..rrrrrr.....",
		".rRRRRRRr....",
		"rRRoRRRRRr...",
		"rRtttttttRr..",
		"rRtdddddtRr..",
		"rRtdddddtRRr.",
		"rRtdddddtRgog",
		"rrtdddddtkkkk",
		"mmtdddddtkKKk",
		"sssssssssssss",
		".MMtMMMtMMtM.",
		".............",
	], {"r": Color("#5e4e40"), "R": Color("#8a7a68"), "t": BARK[3], "d": Color("#1a120c"),
		"s": Color("#b8b8b8"), "o": Color("#5ba4e8"), "g": Color("#ffd447"), "k": Color("#8a8a8a"),
		"K": Color("#3a3a3a"), "m": LEAF[3], "M": LEAF[2]})
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

# --- land trees (20x20 cells, standing on y 18) -------------------------------

const POOL := [Color("#1d4f9e"), Color("#2a6cc4"), Color("#4b97e0")]

# Sunny Meadow: a young oak with a soft, sunlit crown dotted with blossoms.
func tree_meadow(o: Array):
	var ox = o[0]; var oy = o[1]
	trunk(o, 10, 18, func(y): return 1 if y < 16 else (2 if y < 18 else 3), BARK[2], BARK[3])
	for b in [[8, 11], [7, 10], [11, 11], [12, 10]]:
		px(ox + b[0], oy + b[1], BARK[2])
	var sun = [LEAF[2], LEAF[3], LEAF[4], LEAF[5]]
	for c in [[5.0, 8.5, 3.4], [15.0, 8.5, 3.4], [7.2, 4.6, 3.6], [12.8, 4.6, 3.6], [10.0, 7.6, 4.3]]:
		blob(ox + c[0], oy + c[1], c[2], c[2] * 0.9, sun, 0.05)
	for f in [[6, 6], [13, 3], [15, 9], [9, 9], [11, 5], [4, 9]]:
		px(ox + f[0], oy + f[1], Color("#ffffff"))
		px(ox + f[0], oy + f[1] + 1, Color("#ffd166"))
	for g in [[6, 18], [7, 17], [13, 18], [14, 17]]:
		px(ox + g[0], oy + g[1], LEAF[3])

# Ember Vent: a charred tree with bare, forking branches, each one burning at its
# end, lava glowing in the cracks of its bark.
func tree_ember(o: Array):
	var ox = o[0]; var oy = o[1]
	var ch = [Color("#1a100c"), Color("#2e1d16")]
	var fl = [Color("#c8421e"), Color("#f0642d"), Color("#ffb347"), Color("#ffe08a")]
	trunk(o, 11, 18, func(y): return 1 if y < 15 else (2 if y < 17 else 3), ch[0], ch[1])
	var bough = {}
	for br in [[[9, 13], [7, 11], [5, 9], [3, 8], [2, 6]], [[6, 10], [6, 8], [7, 6]], [[10, 12], [12, 10], [14, 9], [16, 8], [18, 6]],
			[[14, 9], [14, 7]], [[10, 11], [10, 8], [9, 5]], [[10, 9], [12, 7], [13, 5]]]:
		for n in range(br.size() - 1):
			var a = Vector2(br[n][0], br[n][1]); var b = Vector2(br[n + 1][0], br[n + 1][1])
			for t in 7:
				var q = a.lerp(b, t / 6.0)
				bough[Vector2i(roundi(q.x), roundi(q.y))] = true
	for k in bough:
		px(ox + k.x, oy + k.y, ch[0] if k.x < 10 else ch[1])
	# embers smouldering along the boughs and lava in the trunk's cracks
	for c in [[5, 9], [12, 10], [10, 9], [16, 8], [9, 13], [10, 15], [9, 16]]:
		px(ox + c[0], oy + c[1], fl[0])
	px(ox + 10, oy + 16, fl[2])
	# a flame at every branch end: [x, base y, height, half width, lean]
	for tg in [[2.0, 7.0, 5.0, 1.5, -0.3], [7.0, 7.0, 5.0, 1.5, 0.0], [9.2, 6.0, 5.5, 1.6, -0.1], [13.0, 6.0, 5.0, 1.5, 0.2],
			[14.2, 8.0, 3.5, 1.3, 0.0], [18.0, 7.0, 5.0, 1.5, 0.3], [4.5, 9.5, 2.5, 1.1, 0.0], [16.0, 8.8, 2.5, 1.1, 0.0]]:
		for y in range(int(tg[1] - tg[2]) - 1, int(tg[1]) + 1):
			var t = (tg[1] - (y + 0.5)) / tg[2]
			if t < 0.0 or t > 1.0:
				continue
			var w = 0.85 * tg[3] * sin(PI * (0.5 + 0.5 * t)) * minf(1.0, sqrt(t * 5.0 + 0.15))
			var cx = tg[0] + tg[4] * t * t * 3.0
			for x in range(int(cx - w) - 1, int(cx + w) + 2):
				var dx = absf(x + 0.5 - cx) / maxf(w, 0.3)
				if dx > 1.0:
					continue
				var k = (1.0 - dx) * 0.8 + (1.0 - t) * 0.4 + bayer(x, y) * 0.15 - 0.2
				px(ox + x, oy + y, fl[0] if k < 0.35 else (fl[1] if k < 0.62 else (fl[2] if k < 0.88 else fl[3])))
	for e in [[4, 0, 2], [16, 0, 2], [11, 0, 3], [0, 3, 1], [19, 2, 1]]:
		px(ox + e[0], oy + e[1], fl[e[2]])

# Frostbite Hollow: a snow-laden fir in tiers, icicles under its boughs, on a drift.
func tree_fir(o: Array):
	var ox = o[0]; var oy = o[1]
	var pine = [Color("#10291f"), Color("#1f4a36"), Color("#33704f"), Color("#5f9c76")]
	blob(ox + 10, oy + 18.2, 6.5, 1.5, [Color("#aac8de"), Color("#dcedf8"), Color("#ffffff")])
	trunk(o, 15, 17, func(y): return 1, Color("#4a3020"), Color("#6a4630"))
	# [top, bottom, half width], bottom tier first
	for tr in [[8.0, 15.0, 8.5], [4.0, 11.0, 6.2], [0.0, 7.0, 4.0]]:
		var mask = {}
		for y in range(int(tr[0]), int(tr[1]) + 1):
			var w = lerpf(0.6, tr[2], pow((y - tr[0]) / (tr[1] - tr[0]), 0.8))
			for x in 20:
				var dx = x + 0.5 - 10.0
				if absf(dx) <= w and not (y == int(tr[1]) and posmod(x, 2) == 0):
					mask[Vector2i(x, y)] = dx / w
		for k in mask:
			var col = pine[1] if mask[k] < -0.3 else (pine[2] if mask[k] < 0.5 else pine[3])
			# snow caps the tops of the boughs in clumps; the bough tips droop dark
			if not mask.has(k + Vector2i(0, 1)):
				col = pine[0]
			elif not mask.has(k + Vector2i(0, -1)) and (absf(mask[k]) < 0.35 or bayer(k.x, k.y) > 0.4):
				col = Color("#ffffff") if mask[k] > -0.2 else Color("#dcedf8")
			px(ox + k.x, oy + k.y, col)
	for ic in [[4, 16], [8, 16], [13, 16], [16, 16], [6, 12], [14, 12]]:
		px(ox + ic[0], oy + ic[1], Color("#bfe6ff"))

# Gloomroot Cavern: a giant cave mushroom with glowing spots, little glowcaps at its foot.
func tree_shroom(o: Array):
	var ox = o[0]; var oy = o[1]
	for y in range(8, 19):
		var cx = 10 + roundi(sin(y * 0.5) * 0.6)
		var w = 1 if y < 15 else 2
		for x in range(cx - w - 1, cx + w + 1):
			var d = x - cx
			px(ox + x, oy + y, Color("#6e5a86") if d < -1 else (Color("#8f7cab") if d < 1 else Color("#b8a8d0")))
	var cap = CROWN["dark"]
	for y in range(0, 9):
		for x in range(1, 19):
			var n = Vector2((x + 0.5 - 10.0) / 8.6, (y + 0.5 - 8.5) / 8.0)
			if n.length() <= 1.0:
				px(ox + x, oy + y, shade(n, x, y, cap))
	for x in range(2, 18):
		px(ox + x, oy + 8, Color("#1c1428"))
	for x in range(5, 15):
		px(ox + x, oy + 9, Color("#2a1f3a"))
	for sp in [[6, 4], [12, 2], [14, 5], [8, 1], [4, 7], [10, 5], [16, 7]]:
		px(ox + sp[0], oy + sp[1], Color("#d9c2ff"))
	px(ox + 13, oy + 2, Color("#9fe8ff")); px(ox + 7, oy + 4, Color("#9fe8ff"))
	var glow = [Color("#2f6f7a"), Color("#3aa0a8"), Color("#7ff0e0")]
	for m in [[4, 15.2, 2.6, 1.6, 16], [16, 16.2, 2.0, 1.3, 17]]:
		for y in range(m[4], 19):
			px(ox + m[0], oy + y, Color("#b8a8d0"))
		blob(ox + m[0], oy + m[1], m[2], m[3], glow)
	for sp in [[1, 12], [18, 11], [17, 13]]:
		px(ox + sp[0], oy + sp[1], Color("#7ff0e0"))

# Brambleheart Thicket: an ancient broad oak, deep green in two layers, brambles and berries at its roots.
func tree_thicket(o: Array):
	var ox = o[0]; var oy = o[1]
	trunk(o, 9, 18, func(y): return 2 if y < 15 else (3 if y < 17 else 4), BARK[1], BARK[2])
	px(ox + 9, oy + 12, BARK[0]); px(ox + 10, oy + 14, BARK[0]); px(ox + 11, oy + 11, BARK[3])
	var deep = [Color("#173a20"), LEAF[0], LEAF[1], LEAF[2]]
	for c in [[3.8, 9.0, 3.4], [16.2, 9.0, 3.4], [10.0, 8.6, 5.2]]:
		blob(ox + c[0], oy + c[1], c[2], c[2] * 0.7, deep, 0.08)
	for c in [[6.6, 5.0, 3.6], [13.4, 5.0, 3.6], [10.0, 2.8, 3.2]]:
		blob(ox + c[0], oy + c[1], c[2], c[2] * 0.75, deep, 0.08)
	var vine = Color("#3e5a22")
	for v in [[2, 18], [3, 17], [4, 16], [5, 16], [6, 17], [5, 18], [14, 17], [15, 16], [16, 16], [17, 17], [18, 18], [15, 18]]:
		px(ox + v[0], oy + v[1], vine)
	for b in [[4, 15], [6, 16], [16, 15], [17, 16]]:
		px(ox + b[0], oy + b[1], Color("#d0304a"))
	for th in [[3, 16], [18, 17]]:
		px(ox + th[0], oy + th[1], Color("#c8b890"))

# Sunken Lagoon: a leaning palm on a sandy islet, long drooping fronds.
func tree_palm(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 17.6, 9.0, 2.0, POOL)
	for x in [2, 15, 17]:
		px(ox + x, oy + 18, Color("#9fd4ff"))
	blob(ox + 8.5, oy + 17.0, 5.0, 1.5, [Color("#b08a4a"), Color("#d8b870"), Color("#f0dca0")])
	for q in curve(Vector2(8, 17), Vector2(8, 10), Vector2(12, 5), 20):
		var ring = int(q[1] * 20 / 2.5) % 2 == 0
		px(ox + int(q[0].x), oy + int(q[0].y), BARK[3] if ring else BARK[2])
		px(ox + int(q[0].x) + 1, oy + int(q[0].y), BARK[4] if ring else BARK[3])
	var palm = [Color("#0e3e5c"), Color("#16707e"), Color("#22a4a0"), Color("#86e6d0")]
	var top = Vector2(12.5, 5)
	for f in [[Vector2(1, 9), Vector2(5, 1)], [Vector2(5, 1), Vector2(9, 0)], [Vector2(17, 1), Vector2(14, 0)],
			[Vector2(19, 8), Vector2(18, 1)], [Vector2(16, 11), Vector2(17, 6)], [Vector2(7, 10), Vector2(7, 5)]]:
		for q in curve(top, f[1], f[0], 16):
			var x = ox + int(q[0].x); var y = oy + int(q[0].y)
			px(x, y, palm[3] if q[1] > 0.25 and q[1] < 0.6 else palm[2])
			if q[1] > 0.1 and q[1] < 0.85:
				px(x, y + 1, palm[1])
	px(ox + 11, oy + 6, Color("#5a3a1a")); px(ox + 13, oy + 6, Color("#5a3a1a")); px(ox + 12, oy + 5, palm[1])

# Steamvent Marsh: a swamp cypress in a boiling pool, its feathery crown half water, half fire, hung with moss.
func tree_cypress(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 17.6, 9.0, 2.0, POOL)
	for b in [[4, 18], [15, 18], [12, 19], [7, 19]]:
		px(ox + b[0], oy + b[1], Color("#f0742d")); px(ox + b[0] + 1, oy + b[1] - 1, Color("#ffd166"))
	trunk(o, 6, 17, func(y): return 1 if y < 13 else (2 if y < 16 else 3), BARK[2], BARK[3])
	for k in [[4, 17], [4, 16], [16, 17], [16, 16]]:
		px(ox + k[0], oy + k[1], BARK[2])
	for c in [[10.0, 8.5, 6.2, 2.0], [4.0, 9.5, 3.0, 1.5], [16.0, 9.5, 3.0, 1.5], [6.5, 5.5, 3.8, 1.8], [13.5, 5.5, 3.8, 1.8], [10.0, 2.5, 3.2, 1.8]]:
		split_blob(ox + c[0], oy + c[1], c[2], c[3], CROWN["water"], CROWN["fire"], ox + 10, 0.12)
	for m in [[5, 11, 3], [8, 11, 2], [12, 11, 3], [15, 11, 2], [3, 11, 2], [17, 11, 2]]:
		for i in m[2]:
			px(ox + m[0], oy + m[1] + i, Color("#8a9a7a") if i < m[2] - 1 else Color("#b8c4a4"))
	for st in [[2.0, 3.0, 1.6, 1.2], [17.5, 1.5, 1.4, 1.1], [1.5, 0.8, 1.0, 0.8]]:
		blob(ox + st[0], oy + st[1], st[2], st[3], [Color("#c4ced6"), Color("#e8eff4"), Color("#ffffff")])

# Frostshade Barrows: a dead, frost-rimed tree on a burial mound, ghost lights hanging from its bare boughs.
func tree_barrow(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 18.4, 7.5, 2.2, [Color("#2a3040"), Color("#3e4a5e"), Color("#5d7f99")])
	for x in range(3, 18):
		for y in range(15, 20):
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				px(ox + x, oy + y, Color("#dcedf8") if bayer(x, y) > 0.3 else Color("#ffffff"))
				break
	var tk = [Color("#2e2238"), Color("#4a3a5e")]
	for y in range(8, 18):
		var cx = 10 + roundi(sin(y * 0.6) * 0.7)
		var w = 1 if y < 14 else 2
		for x in range(cx - w, cx + w):
			px(ox + x, oy + y, tk[1] if x >= cx else tk[0])
	var bough = {}
	for br in [[[10, 9], [8, 7], [6, 6], [4, 4], [3, 2]], [[6, 6], [5, 7], [3, 7]], [[10, 8], [12, 6], [14, 5], [16, 3], [17, 1]],
			[[14, 5], [16, 6], [18, 6]], [[10, 7], [10, 5], [9, 3], [10, 1]]]:
		for i in range(br.size() - 1):
			var a = Vector2(br[i][0], br[i][1]); var b = Vector2(br[i + 1][0], br[i + 1][1])
			for t in 6:
				var q = a.lerp(b, t / 5.0)
				bough[Vector2i(roundi(q.x), roundi(q.y))] = true
	for k in bough:
		px(ox + k.x, oy + k.y, tk[0])
	for k in bough:
		if not bough.has(k + Vector2i(0, -1)) and bayer(k.x, k.y) > 0.35:
			px(ox + k.x, oy + k.y - 1, Color("#ffffff"))
		elif not bough.has(k + Vector2i(0, 1)) and bayer(k.x, k.y) > 0.75:
			px(ox + k.x, oy + k.y + 1, Color("#bfe6ff"))
	for l in [[3, 8], [16, 7], [13, 7]]:
		px(ox + l[0], oy + l[1], Color("#e8dcff")); px(ox + l[0], oy + l[1] + 1, Color("#9a6ad8"))
	px(ox + 9, oy + 12, Color("#9fe8ff"))

# Blighted Heartwood: a rotting weeping willow, its curtain of strands half sickly green, half shadow.
func tree_willow(o: Array):
	var ox = o[0]; var oy = o[1]
	trunk(o, 7, 18, func(y): return 1 if y < 15 else (2 if y < 17 else 3), Color("#3e2c3a"), Color("#5e4654"))
	var sick = [Color("#2a3014"), Color("#4e5a1e"), Color("#7a8a2a"), Color("#b0c048")]
	var dk = CROWN["dark"]
	split_blob(ox + 10, oy + 4, 8.4, 3.8, sick, dk, ox + 10, 0.06)
	for x in range(1, 19):
		if (x >= 9 and x <= 10) or posmod(x, 3) == 1:
			continue
		var start = -1
		for y in range(0, 9):
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				start = y
		if start < 0:
			continue
		var pal = sick if x < 10 else dk
		var n = 4 + int(7 * absf(sin(x * 1.3 + 0.4)))
		for i in n:
			if start + 1 + i > 17:
				break
			px(ox + x, oy + start + 1 + i, pal[3] if i == n - 1 else (pal[1] if x % 2 else pal[2]))
	px(ox + 9, oy + 13, Color("#08050c")); px(ox + 10, oy + 13, Color("#08050c"))
	px(ox + 9, oy + 14, Color("#08050c")); px(ox + 10, oy + 14, Color("#a985e0"))
	px(ox + 11, oy + 15, sick[3]); px(ox + 8, oy + 16, sick[2])
	for sp in [[1, 15], [18, 14]]:
		px(ox + sp[0], oy + sp[1], Color("#c8a2ff"))

# A flame licking up from (x, base y): [x, base y, height, half width, lean], in
# `fl` colours dark to bright.
func flame(ox: int, oy: int, tg: Array, fl: Array):
	for y in range(int(tg[1] - tg[2]) - 1, int(tg[1]) + 1):
		var t = (tg[1] - (y + 0.5)) / tg[2]
		if t < 0.0 or t > 1.0:
			continue
		var w = 0.85 * tg[3] * sin(PI * (0.5 + 0.5 * t)) * minf(1.0, sqrt(t * 5.0 + 0.15))
		var cx = tg[0] + tg[4] * t * t * 3.0
		for x in range(int(cx - w) - 1, int(cx + w) + 2):
			var dx = absf(x + 0.5 - cx) / maxf(w, 0.3)
			if dx > 1.0:
				continue
			var k = (1.0 - dx) * 0.8 + (1.0 - t) * 0.4 + bayer(x, y) * 0.15 - 0.2
			px(ox + x, oy + y, fl[0] if k < 0.35 else (fl[1] if k < 0.62 else (fl[2] if k < 0.88 else fl[3])))

# Mossmire Fen: a squat bog oak knee-deep in a lily pond, its crown half leafy
# green, half glossy water leaves, beards of moss hanging from both.
func tree_bog_oak(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 17.6, 9.0, 2.0, POOL)
	for x in [3, 15, 17]:
		px(ox + x, oy + 18, Color("#9fd4ff"))
	# lily pads, one in flower
	for lp in [[3.5, 17.2], [16.0, 17.6]]:
		blob(ox + lp[0], oy + lp[1], 1.6, 0.8, [LEAF[1], LEAF[2], LEAF[3]])
	px(ox + 16, oy + 17, Color("#f6a6c1")); px(ox + 16, oy + 16, Color("#ffffff"))
	trunk(o, 8, 17, func(y): return 2 if y < 14 else (3 if y < 16 else 4), BARK[1], BARK[2])
	# a hollow in the old trunk, and two thick limbs forking out under the canopy
	for h in [[9, 13], [10, 13], [9, 14], [10, 14]]:
		px(ox + h[0], oy + h[1], Color("#1a120c"))
	for b in [[7, 8], [6, 7], [5, 7], [12, 8], [13, 7], [14, 7]]:
		px(ox + b[0], oy + b[1], BARK[1] if b[0] < 10 else BARK[2])
	# knobbly knees poking out of the water either side
	for k in [[5, 16], [5, 17], [14, 16], [14, 17], [15, 17]]:
		px(ox + k[0], oy + k[1], BARK[2] if k[0] < 10 else BARK[3])
	px(ox + 9, oy + 12, BARK[0]); px(ox + 10, oy + 14, BARK[0]); px(ox + 11, oy + 11, BARK[3])
	var green = [LEAF[0], LEAF[1], LEAF[2], LEAF[3]]
	var wet = CROWN["water"]
	# a broad, flat canopy spreading wide over the water
	for c in [[10.0, 5.6, 8.8, 2.6], [3.6, 6.2, 3.0, 1.8], [16.4, 6.2, 3.0, 1.8], [7.0, 3.4, 4.0, 2.0], [13.0, 3.4, 4.0, 2.0]]:
		split_blob(ox + c[0], oy + c[1], c[2], c[3], green, wet, ox + 10, 0.1)
	# glossy water leaves catch a shine; the green side has little buds
	for sh in [[13, 2], [16, 5], [12, 5], [18, 6]]:
		px(ox + sh[0], oy + sh[1], Color("#bfe6ff"))
	for bd in [[4, 5], [7, 2], [3, 7]]:
		px(ox + bd[0], oy + bd[1], LEAF[4])
	# moss beards hanging from under the canopy
	var moss = [Color("#6f8a4a"), Color("#9ab46a")]
	for m in [[2, 8, 3], [4, 8, 4], [6, 9, 2], [13, 9, 2], [15, 8, 4], [17, 8, 3]]:
		for i in m[2]:
			px(ox + m[0], oy + m[1] + i, moss[0] if i < m[2] - 1 else moss[1])
	for d in [[18, 12], [12, 14]]:
		px(ox + d[0], oy + d[1], Color("#9fd4ff"))

# Cinderfrost Peak: a tiered fir split down the middle on a crag, its left
# boughs heavy with snow, its right boughs charred and burning, lava on that side of the rock.
func tree_split_fir(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 17.8, 8.0, 2.0, [Color("#3a3438"), Color("#5e5458"), Color("#857a7c")])
	for x in range(2, 19):
		for y in range(15, 20):
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				if x < 10:
					px(ox + x, oy + y, Color("#dcedf8") if bayer(x, y) > 0.3 else Color("#ffffff"))
				break
	for c in [[13, 18], [14, 19], [15, 18], [16, 19], [12, 19]]:
		px(ox + c[0], oy + c[1], Color("#f0642d") if c[0] % 2 else Color("#ffb347"))
	trunk(o, 15, 17, func(y): return 1, Color("#4a3020"), Color("#2e1d16"))
	var pine = [Color("#10291f"), Color("#1f4a36"), Color("#33704f"), Color("#5f9c76")]
	var burnt = [Color("#1a100c"), Color("#2e1d16"), Color("#4a2e20"), Color("#6b3a2a")]
	var tips = []
	# [top, bottom, half width], bottom tier first
	for tr in [[8.0, 15.0, 8.5], [4.0, 11.0, 6.2], [0.0, 7.0, 4.0]]:
		var mask = {}
		for y in range(int(tr[0]), int(tr[1]) + 1):
			var w = lerpf(0.6, tr[2], pow((y - tr[0]) / (tr[1] - tr[0]), 0.8))
			for x in 20:
				var dx = x + 0.5 - 10.0
				if absf(dx) <= w and not (y == int(tr[1]) and posmod(x, 2) == 0):
					mask[Vector2i(x, y)] = dx / w
		for k in mask:
			var fire = k.x >= 10
			var pal = burnt if fire else pine
			var col = pal[1] if mask[k] < -0.3 else (pal[2] if mask[k] < 0.5 else pal[3])
			if not mask.has(k + Vector2i(0, 1)):
				col = pal[0]
				if fire and posmod(k.x, 2) == 1:
					col = Color("#c8421e")  # embers glowing along the bough tips
			elif not fire and not mask.has(k + Vector2i(0, -1)):
				col = Color("#ffffff")  # snow piled along every bough
			elif not fire and not mask.has(k + Vector2i(0, -2)) and bayer(k.x, k.y) > 0.35:
				col = Color("#dcedf8")
			elif fire and not mask.has(k + Vector2i(0, -1)):
				col = Color("#f0642d")  # flames catching along the tops of the boughs
			px(ox + k.x, oy + k.y, col)
		tips.append([10.0 + tr[2] - 1.2, tr[1] - 0.5])
	# flames on the burning side: the tier tips and the crown
	var fl = CROWN["fire"]
	for t in tips:
		flame(ox, oy, [t[0], t[1], 3.5, 1.3, 0.2], [fl[1], fl[2], fl[3], Color("#ffe08a")])
	flame(ox, oy, [12.0, 6.0, 4.0, 1.4, 0.1], [fl[1], fl[2], fl[3], Color("#ffe08a")])
	for ic in [[4, 16], [7, 16], [3, 12], [6, 12]]:
		px(ox + ic[0], oy + ic[1], Color("#bfe6ff"))
	for e in [[17, 1], [19, 4]]:
		px(ox + e[0], oy + e[1], fl[3])

# Cindergloom Wastes: a twisted obsidian tree on a mound of ash, glowing cracks
# in its bark, its boughs burning with shadow flame on one side and fire on the other.
func tree_obsidian(o: Array):
	var ox = o[0]; var oy = o[1]
	blob(ox + 10, oy + 17.6, 8.0, 1.7, [Color("#2a2428"), Color("#4a4044"), Color("#6e6266")])
	for c in [[6, 18], [7, 19], [13, 18], [14, 19]]:
		px(ox + c[0], oy + c[1], Color("#9a6ad8") if c[0] < 10 else Color("#f0642d"))
	var ob = [Color("#120c16"), Color("#2a2034")]
	for y in range(9, 18):
		var cx = 10 + roundi(sin(y * 0.7) * 0.8)
		var w = 1 if y < 14 else 2
		for x in range(cx - w, cx + w):
			px(ox + x, oy + y, ob[1] if x >= cx else ob[0])
	var bough = {}
	for br in [[[10, 10], [8, 8], [6, 7], [4, 6], [3, 4]], [[6, 7], [5, 9], [3, 10]], [[10, 9], [12, 7], [14, 6], [16, 5], [17, 4]],
			[[14, 6], [16, 7], [18, 7]], [[10, 8], [9, 6], [10, 5], [9, 3]]]:
		for i in range(br.size() - 1):
			var a = Vector2(br[i][0], br[i][1]); var b = Vector2(br[i + 1][0], br[i + 1][1])
			for t in 7:
				var q = a.lerp(b, t / 6.0)
				bough[Vector2i(roundi(q.x), roundi(q.y))] = true
	for k in bough:
		px(ox + k.x, oy + k.y, ob[0] if k.x < 10 else ob[1])
	# cracks glowing through the bark: violet on the shadow side, orange on the fire side
	for c in [[9, 12], [9, 15], [8, 16], [7, 8]]:
		px(ox + c[0], oy + c[1], Color("#9a6ad8"))
	for c in [[10, 13], [11, 16], [10, 11], [13, 7]]:
		px(ox + c[0], oy + c[1], Color("#f0642d"))
	var shade_fl = [Color("#6d4a96"), Color("#9a6ad8"), Color("#c8a2ff"), Color("#f0e8ff")]
	var fire_fl = [Color("#c8421e"), Color("#f0642d"), Color("#ffb347"), Color("#ffe08a")]
	for tg in [[3.0, 5.0, 4.8, 1.7, -0.25], [3.0, 10.5, 3.8, 1.4, -0.1], [9.0, 4.0, 4.0, 1.5, 0.0], [6.0, 7.5, 2.6, 1.1, 0.0]]:
		flame(ox, oy, tg, shade_fl)
	for tg in [[17.0, 5.0, 4.8, 1.7, 0.25], [18.0, 8.0, 3.8, 1.4, 0.1], [14.0, 6.5, 2.6, 1.1, 0.0]]:
		flame(ox, oy, tg, fire_fl)
	for e in [[1, 0], [6, 1], [12, 0], [19, 1]]:
		px(ox + e[0], oy + e[1], Color("#c8a2ff") if e[0] < 10 else Color("#ffb347"))

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
