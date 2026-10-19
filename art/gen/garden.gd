# Garden art. params.part: "bg" (180x400 meadow) or "sheet" (224x80 sprites:
# row 0 = 32x32 plants, row 1 = lot + lot_sel (40x26), row 2 = 16x16 seeds).
var img: Image
const PLANTS := ["sprout", "sapling", "nature", "water", "fire", "ice", "dark"]
const SEEDS := ["sapling", "nature", "water", "fire", "ice", "dark"]
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a"), Color("#a06a3a"), Color("#c08850")]
# Lot centres in the 180x400 meadow (3 columns x 4 rows); kept in sync with garden_view.gd.
const LOT_COLS := [36, 90, 144]
const LOT_ROWS := [150, 200, 250, 300]

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func band(x, y, stops: Array, ys: Array) -> Color:
	for i in range(ys.size() - 1):
		if y < ys[i + 1]:
			var t = float(y - ys[i]) / float(ys[i + 1] - ys[i])
			return stops[i + 1] if t > bayer(x, y) else stops[i]
	return stops[stops.size() - 1]

# Outline everything inside rect r with a darkened copy of the neighbouring colour.
func auto_outline(r: Rect2i, amt := 0.6):
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

func disk(cx: float, cy: float, r: float, c: Color):
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			if Vector2(x, y).distance_to(Vector2(cx, cy)) <= r:
				px(x, y, c)

func leaf(base: Vector2, ang: float, length: float, wid: float, pal: Array):
	var dir = Vector2(cos(ang), sin(ang))
	var nrm = Vector2(-dir.y, dir.x)
	var mid = base + dir * length * 0.5
	for y in range(int(mid.y - length), int(mid.y + length) + 1):
		for x in range(int(mid.x - length), int(mid.x + length) + 1):
			var d = Vector2(x, y) - mid
			var u = d.dot(dir) / (length * 0.5)
			var v = d.dot(nrm) / wid
			if u * u + v * v <= 1.0:
				var c = pal[1]
				if v * signf(dir.x + 0.001) < -0.2: c = pal[2]
				px(x, y, c)

func stem(x: int, top: int, base: int, curve := 0.0):
	for y in range(top, base + 1):
		var t = float(base - y) / maxf(1.0, base - top)
		var xx = int(round(x + sin(t * PI) * curve))
		px(xx, y, LEAF[2])

# --- plants (32x32 cell at ox, base at ox+16, 30) ---
func plant(kind: String, ox: int):
	var bx = ox + 16
	var by = 30
	match kind:
		"sprout":
			stem(bx, by - 7, by)
			leaf(Vector2(bx, by - 6), deg_to_rad(-150), 7, 2.6, [null, LEAF[3], LEAF[4]])
			leaf(Vector2(bx, by - 6), deg_to_rad(-30), 7, 2.6, [null, LEAF[3], LEAF[4]])
		"sapling":
			for y in range(by - 14, by + 1):
				px(bx, y, BARK[2]); px(bx - 1, y, BARK[1] if y > by - 6 else BARK[2])
			px(bx - 2, by, BARK[1]); px(bx + 1, by, BARK[2])
			var cl = [[0, -18, 8], [-6, -14, 5.5], [6, -15, 6], [0, -24, 5]]
			for c in cl:
				disk(bx + c[0], by + c[1], c[2], LEAF[2])
			for c in cl:
				for y in range(by + int(c[1] - c[2]), by + int(c[1] + c[2]) + 1):
					for x in range(bx + int(c[0] - c[2]), bx + int(c[0] + c[2]) + 1):
						var n = (Vector2(x, y) - Vector2(bx + c[0], by + c[1])) / c[2]
						if n.length() <= 1.0:
							var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
							px(x, y, LEAF[4] if t > 0.45 else (LEAF[3] if t > 0.0 else (LEAF[2] if t > -0.5 else LEAF[1])))
			px(bx + 3, by - 22, LEAF[5]); px(bx + 5, by - 19, LEAF[5]); px(bx - 2, by - 20, LEAF[5])
		"nature":
			stem(bx, by - 15, by, 1.0)
			leaf(Vector2(bx, by - 4), deg_to_rad(-155), 8, 2.6, [null, LEAF[2], LEAF[3]])
			leaf(Vector2(bx + 1, by - 7), deg_to_rad(-25), 8, 2.6, [null, LEAF[2], LEAF[3]])
			var hc = Vector2(bx, by - 19)
			for i in 10:
				var a = TAU * i / 10.0
				for r in range(2, 7):
					var p = hc + Vector2(cos(a), sin(a) * 0.9) * r
					px(int(round(p.x)), int(round(p.y)), Color("#ffffff") if r < 5 else Color("#e2f5c8"))
			disk(hc.x, hc.y, 2.2, Color("#f2b632"))
			px(int(hc.x), int(hc.y) - 1, Color("#ffe27a")); px(int(hc.x) - 1, int(hc.y) - 1, Color("#ffe27a"))
		"water":
			# lily pads at the base, a blue cup lily on a short stem
			for pad in [[-6, 0, 6.0], [6, -1, 5.0]]:
				for y in range(by - 4, by + 1):
					for x in range(-7, 8):
						var dx = x / pad[2]
						var dy = (y - by + 1.5 - pad[1]) / 2.2
						var notch = absi(x) <= 1 and y < by - 1 + pad[1]
						if dx * dx + dy * dy <= 1.0 and not notch:
							px(bx + pad[0] + x, y + pad[1], LEAF[3] if dy < 0.0 else LEAF[2])
			stem(bx, by - 12, by - 2)
			var pat = [
				"....b.b.b....",
				"...bcbcbcb...",
				"..bccbcbccb..",
				".bcccbcbcccb.",
				".bccccbccccb.",
				"..bccccccccb.",
				"...bbbbbbbb..",
			]
			var cols = {"b": Color("#3a78c9"), "c": Color("#7cc4f2")}
			for y in pat.size():
				for x in pat[y].length():
					var ch = pat[y][x]
					if cols.has(ch):
						px(bx - 6 + x, by - 19 + y, cols[ch])
			px(bx - 2, by - 16, Color("#d8f1ff")); px(bx + 3, by - 16, Color("#d8f1ff"))
			# dewdrop
			px(bx + 7, by - 22, Color("#d8f1ff")); px(bx + 7, by - 21, Color("#7cc4f2")); px(bx + 6, by - 21, Color("#7cc4f2"))
		"fire":
			stem(bx, by - 14, by, -1.0)
			leaf(Vector2(bx, by - 3), deg_to_rad(-160), 8, 2.4, [null, LEAF[2], LEAF[3]])
			leaf(Vector2(bx, by - 6), deg_to_rad(-20), 7, 2.4, [null, LEAF[2], LEAF[3]])
			var hc = Vector2(bx, by - 18)
			for pc in [[-3, 0], [3, 0], [0, -3], [0, 2]]:
				disk(hc.x + pc[0], hc.y + pc[1], 3.6, Color("#e23b22"))
			for pc in [[-3, -1], [3, -1], [0, -4]]:
				disk(hc.x + pc[0] + 0.6, hc.y + pc[1] - 0.6, 1.6, Color("#ff7a3d"))
			disk(hc.x, hc.y, 1.5, Color("#3a1410"))
			px(int(hc.x) + 1, int(hc.y) - 6, Color("#ffd166"))
			# rising embers
			px(bx - 5, by - 27, Color("#ffb347")); px(bx + 4, by - 29, Color("#ffd166")); px(bx + 6, by - 25, Color("#ff7a3d"))
		"ice":
			# an arched stem with two hanging bells
			var arch = [[0, 0], [0, -1], [0, -2], [0, -3], [0, -4], [0, -5], [0, -6], [0, -7], [0, -8], [0, -9], [0, -10], [1, -11], [1, -12], [2, -13], [3, -14], [4, -14], [5, -14], [6, -13], [7, -12], [8, -11]]
			for a in arch:
				px(bx - 3 + a[0], by + a[1], LEAF[2])
			for a in [[-3, -10], [-4, -11], [-4, -12], [-5, -13], [-6, -14]]:
				px(bx + a[0], by + a[1], LEAF[2])
			leaf(Vector2(bx - 3, by - 2), deg_to_rad(-140), 7, 2.2, [null, LEAF[2], LEAF[3]])
			var bell = ["..bb..", ".bccb.", ".bcwb.", "bccwcb", "bccccb", "b.bb.b"]
			var cols = {"b": Color("#4aa3c9"), "c": Color("#bfeaf7"), "w": Color("#ffffff")}
			for spot in [[bx + 2, by - 11], [bx - 9, by - 13]]:
				for y in bell.size():
					for x in bell[y].length():
						var ch = bell[y][x]
						if cols.has(ch):
							px(spot[0] + x, spot[1] + y, cols[ch])
			px(bx + 8, by - 22, Color("#ffffff")); px(bx + 7, by - 23, Color("#bfeaf7")); px(bx + 9, by - 23, Color("#bfeaf7")); px(bx + 8, by - 24, Color("#bfeaf7"))
		"dark":
			stem(bx, by - 15, by, 1.0)
			var dl = [null, Color("#2f6b45"), Color("#4f8f5e")]
			leaf(Vector2(bx, by - 4), deg_to_rad(-150), 8, 2.6, dl)
			leaf(Vector2(bx + 1, by - 8), deg_to_rad(-30), 8, 2.6, dl)
			var hc = Vector2(bx, by - 19)
			for y in range(int(hc.y) - 7, int(hc.y) + 8):
				for x in range(int(hc.x) - 7, int(hc.x) + 8):
					var d = Vector2(x, y) - hc
					var a = d.angle() + PI / 2.0
					var r = 3.0 + 3.6 * pow(absf(cos(a * 2.5)), 3.0)
					if d.length() <= r:
						px(x, y, Color("#6d3fb0") if d.length() > 2.5 else Color("#9a6ad8"))
			disk(hc.x, hc.y, 1.2, Color("#f2d16b"))
			px(bx - 7, by - 26, Color("#c8a2ff")); px(bx + 6, by - 28, Color("#9a6ad8")); px(bx + 8, by - 24, Color("#c8a2ff"))
	auto_outline(Rect2i(ox, 0, 32, 32))

# --- lot (40x26) and selection brackets ---
func lot(ox: int, oy: int):
	var w = 40
	var h = 24
	for y in h:
		for x in w:
			var edge = x < 2 or x >= w - 2 or y < 2 or y >= h - 3
			var corner = (x < 2 or x >= w - 2) and (y < 2 or y >= h - 3)
			if corner and (x == 0 or x == w - 1) and (y == 0 or y == h - 1):
				continue
			var c: Color
			if edge:
				c = BARK[3] if y < 2 else (BARK[1] if y >= h - 3 else BARK[2])
				if y >= h - 3 and y == h - 1: c = BARK[0]
				if not (y < 2 or y >= h - 3) and posmod(y, 6) == 0: c = BARK[1]
				if (y < 2 or y >= h - 3) and posmod(x, 10) == 9: c = BARK[1]
			else:
				var ridge = posmod(y - 2, 4)
				c = Color("#6b4226")
				if ridge == 0: c = Color("#8a5a34")
				elif ridge == 3: c = Color("#4a2c18")
				if ridge == 1 and bayer(x, y) > 0.8: c = Color("#7a4d2c")
				if y == 2: c = Color("#3f2414")
			px(ox + x, oy + y, c)
	# shadow on the grass below
	for x in range(1, w - 1):
		px(ox + x, oy + h, Color(0.1, 0.25, 0.08, 0.35))
		if bayer(x, 0) > 0.5:
			px(ox + x, oy + h + 1, Color(0.1, 0.25, 0.08, 0.25))

func lot_sel(ox: int, oy: int):
	var w = 40
	var h = 26
	var c = Color("#ffd447")
	var hi = Color("#fff6b0")
	var dk = Color("#7a5a10")
	for corner in [[0, 0, 1, 1], [w - 1, 0, -1, 1], [0, h - 1, 1, -1], [w - 1, h - 1, -1, -1]]:
		for i in 6:
			for t in 2:
				px(ox + corner[0] + corner[2] * i, oy + corner[1] + corner[3] * t, c if t == 0 else hi)
				px(ox + corner[0] + corner[2] * t, oy + corner[1] + corner[3] * i, c if t == 0 else hi)
	auto_outline(Rect2i(ox - 1, oy - 1, w + 2, h + 2), 0.55)

# --- seeds (16x16) ---
func seed_icon(kind: String, ox: int, oy: int):
	if kind == "sapling":
		# acorn
		for y in range(5, 15):
			for x in range(3, 13):
				var d = pow((x - 7.5) / 4.6, 2) + pow((y - 9.5) / 5.2, 2)
				if d <= 1.0 and y >= 7:
					px(ox + x, oy + y, Color("#d39a52") if x > 7 - (y - 10) * 0.2 else Color("#b07a3c"))
		for x in range(3, 13):
			for y in range(4, 8):
				if pow((x - 7.5) / 5.2, 2) + pow((y - 7.0) / 3.2, 2) <= 1.0:
					px(ox + x, oy + y, BARK[1] if posmod(x + y, 2) == 0 else BARK[2])
		px(ox + 8, oy + 2, BARK[1]); px(ox + 8, oy + 3, BARK[1])
		px(ox + 10, oy + 10, Color("#f0c27a")); px(ox + 10, oy + 9, Color("#f0c27a"))
		auto_outline(Rect2i(ox, oy, 16, 16))
		return
	var pal = {"nature": [Color("#2e8a3a"), Color("#5dbb4c"), Color("#b6ec8a")],
		"water": [Color("#2f64b5"), Color("#5ba4e8"), Color("#c6e8ff")],
		"fire": [Color("#b52a1c"), Color("#f0642d"), Color("#ffc46b")],
		"ice": [Color("#3d8fb5"), Color("#8fd6f0"), Color("#ffffff")],
		"dark": [Color("#4a2580"), Color("#7d4bc4"), Color("#d2b4ff")]}[kind]
	# teardrop seed, point up
	for y in range(2, 15):
		for x in range(2, 14):
			var fy = (y - 9.5) / 5.0
			var hw = 4.6 * sqrt(maxf(0.0, 1.0 - fy * fy)) if fy > -0.2 else 4.6 * (1.0 - (-fy - 0.2) / 1.3)
			if absf(x - 7.5) <= hw and y >= 3:
				var t = (x - 7.5) / 4.6 - fy * 0.5
				var c = pal[1]
				if t > 0.45: c = pal[2]
				elif t < -0.35: c = pal[0]
				px(ox + x, oy + y, c)
	px(ox + 9, oy + 7, Color("#ffffff")); px(ox + 9, oy + 8, pal[2])
	match kind:
		"nature":
			px(ox + 8, oy + 2, LEAF[2]); px(ox + 9, oy + 1, LEAF[3]); px(ox + 10, oy + 1, LEAF[3]); px(ox + 10, oy + 2, LEAF[2])
		"fire":
			px(ox + 7, oy + 1, Color("#ffd166")); px(ox + 8, oy + 2, Color("#ffd166")); px(ox + 7, oy + 2, Color("#ff7a3d"))
		"ice":
			px(ox + 12, oy + 3, Color("#ffffff")); px(ox + 13, oy + 4, Color("#bfeaf7")); px(ox + 11, oy + 4, Color("#bfeaf7")); px(ox + 12, oy + 5, Color("#bfeaf7"))
		"dark":
			px(ox + 6, oy + 10, pal[0]); px(ox + 7, oy + 11, pal[0]); px(ox + 8, oy + 11, pal[0])
	auto_outline(Rect2i(ox, oy, 16, 16))

# --- meadow background ---
func bg():
	var sky = [Color("#7fc3f0"), Color("#a8dcf5"), Color("#d2eef5"), Color("#f3f4dc")]
	for y in 400:
		for x in 180:
			px(x, y, band(x, y, sky, [0, 40, 80, 104]))
	# distant tree line
	for x in 180:
		var h = int(98 - 5 * (0.6 * sin(x * 0.21) + 0.4 * sin(x * 0.53 + 1.0)) - 3 * abs(sin(x * 0.09)))
		for y in range(h, 116):
			px(x, y, Color("#3f7f4a") if y > h + 1 else Color("#5a9a5c"))
	# meadow with soft mowing stripes
	for y in range(112, 400):
		for x in 180:
			var stripe = posmod(int((y - 112) / 24), 2) == 0
			var c = Color("#5cae4a") if stripe else Color("#55a545")
			if posmod(y - 112, 24) == 0 and bayer(x, y) > 0.5:
				c = Color("#55a545") if stripe else Color("#5cae4a")
			px(x, y, c)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9
	for i in 900:
		var x = rng.randi_range(0, 179)
		var y = rng.randi_range(114, 399)
		var b = img.get_pixel(x, y)
		px(x, y, b.lightened(0.16) if rng.randf() < 0.6 else b.darkened(0.12))
	# wooden fence along the top of the meadow
	for x in 180:
		for y in [112, 118]:
			px(x, y, BARK[3]); px(x, y + 1, BARK[2]); px(x, y + 2, BARK[1])
	for x in range(2, 180, 12):
		for y in range(106, 126):
			for dx in 3:
				var c = BARK[3] if dx == 2 else BARK[2]
				if y == 106 and dx != 1: continue
				if y == 125: c = BARK[0]
				px(x + dx, y, c)
		px(x - 1, 126, Color(0.1, 0.25, 0.08, 0.35)); px(x + 3, 126, Color(0.1, 0.25, 0.08, 0.35))
	# stepping stones between the lot columns
	for sx in [63, 117]:
		for y in range(136, 352, 13):
			var ox = sx + (2 if posmod(y / 13, 2) == 0 else -2)
			for yy in range(0, 5):
				for xx in range(-3, 4):
					if pow(xx / 3.5, 2) + pow((yy - 2) / 2.5, 2) <= 1.0:
						px(ox + xx, y + yy, Color("#b7b2a3") if yy < 3 else Color("#8f8a7c"))
			px(ox - 1, y + 1, Color("#d6d2c4"))
	# flower borders down both sides and along the bottom
	var fl = [Color("#fff1a8"), Color("#f6a6c1"), Color("#ffffff"), Color("#c8a2ff"), Color("#ffb36b")]
	for i in 70:
		var side = rng.randi_range(0, 2)
		var x: int
		var y: int
		if side == 0:
			x = rng.randi_range(1, 12); y = rng.randi_range(132, 396)
		elif side == 1:
			x = rng.randi_range(167, 178); y = rng.randi_range(132, 396)
		else:
			x = rng.randi_range(4, 175); y = rng.randi_range(334, 396)
			if y < 340: continue
		var c = fl[rng.randi_range(0, fl.size() - 1)]
		px(x, y + 1, LEAF[1])
		px(x, y, Color("#ffd166")); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c)
	# a couple of bushes in the corners
	for b in [[6, 130, 9], [174, 134, 10], [8, 388, 10], [172, 392, 9]]:
		for y in range(b[1] - b[2], b[1] + b[2]):
			for x in range(b[0] - b[2] - 2, b[0] + b[2] + 2):
				var n = Vector2((x - b[0]) / (b[2] + 2.0), (y - b[1]) / float(b[2]))
				if n.length() <= 1.0 + 0.08 * sin(atan2(n.y, n.x) * 6.0):
					var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
					px(x, y, LEAF[4] if t > 0.5 else (LEAF[3] if t > 0.05 else (LEAF[2] if t > -0.45 else LEAF[1])))

func run(api, image, project, params):
	if params.get("part", "bg") == "bg":
		img = Image.create(180, 400, false, Image.FORMAT_RGBA8)
		bg()
		return img
	img = Image.create(224, 80, false, Image.FORMAT_RGBA8)
	for i in PLANTS.size():
		plant(PLANTS[i], i * 32)
	lot(0, 34)
	lot_sel(46, 33)
	for i in SEEDS.size():
		seed_icon(SEEDS[i], i * 16, 62)
	return img
