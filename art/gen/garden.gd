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

# --- lot (40x26): a soil bed ringed by two braided roots, root curls at the sides ---
func lot(ox: int, oy: int):
	var c = Vector2(20, 11.5)
	var rx = 18.0
	var ry = 10.5
	# little roots curling out from the rim, drawn first so the ring sits on top
	for t in [[c + Vector2(-16, 4), Vector2(-1, 0.5), 1.0], [c + Vector2(16, 4), Vector2(1, 0.5), -1.0]]:
		var p: Vector2 = t[0]
		var d: Vector2 = t[1].normalized()
		for i in 5:
			var q = p + d * i
			d = d.rotated(0.45 * t[2])
			px(ox + int(round(q.x)), oy + int(round(q.y)), BARK[3] if i < 2 else BARK[2])
			px(ox + int(round(q.x)), oy + int(round(q.y)) + 1, BARK[1])
	for y in 24:
		for x in 40:
			var n = Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry)
			var r = n.length()
			if r > 1.0:
				continue
			var col: Color
			if r > 0.6:
				# two root strands crossing as they wind round the bed, lit from the top left
				var a = atan2(n.y, n.x)
				var u = (r - 0.6) / 0.4
				var wave = 0.5 + 0.32 * sin(a * 6.0)
				var ca = absf(u - wave)
				var cb = absf(u - (1.0 - wave))
				var on_a = ca < cb if cos(a * 6.0) > 0.0 else ca <= cb  # strands swap over at each crossing
				var dc = minf(ca, cb)
				var lit = -n.y * 0.8 - n.x * 0.35
				col = (BARK[3] if on_a else BARK[2]) if lit > -0.1 else (BARK[2] if on_a else BARK[1])
				if dc < 0.1 and lit > 0.2: col = BARK[4]
				if dc > 0.3: col = BARK[0]  # the gap between strands
				if r > 0.96: col = BARK[0]
			else:
				# dark loam with furrows, shaded under the top rim
				var ridge = posmod(y - 3, 3)
				col = Color("#4e2e18")
				if ridge == 0: col = Color("#6a4226")
				elif ridge == 2: col = Color("#36200f")
				if n.y < -0.35: col = col.darkened(0.3)
				if r > 0.55: col = Color("#2a160a")
			px(ox + x, oy + y, col)
	# moss on the rim
	for m in [[10, 2], [11, 2], [29, 3], [5, 15], [34, 16]]:
		px(ox + m[0], oy + m[1], LEAF[3])
	# a soft shadow just under the bed
	for x in range(3, 37):
		var low = -1
		for y in 24:
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				low = y
		if low >= 0 and low + 1 < 26:
			px(ox + x, oy + low + 1, Color(0.1, 0.25, 0.08, 0.4))
			if low + 2 < 26 and bayer(x, 0) > 0.5:
				px(ox + x, oy + low + 2, Color(0.1, 0.25, 0.08, 0.2))

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

# --- meadow background: the Home Grove's roots run through it ---
# A root along points `pts` (smoothed), `w0` thick at the start tapering to `w1`.
# Roots are gathered into `net` and drawn together by `flush_roots()`, so a branch
# grows out of its parent instead of being laid over it: where two roots overlap,
# each pixel belongs to whichever root it lies deeper inside.
var net = {}

func root(pts: Array, w0: float, w1: float):
	var samples = []
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var pa: Vector2 = pts[i - 1] if i > 0 else a
		var pb: Vector2 = pts[i + 2] if i + 2 < pts.size() else b
		var steps = maxi(1, int(a.distance_to(b) * 3.0))
		for s in steps:
			var t = float(s) / steps
			# Catmull-Rom between a and b
			var p = 0.5 * ((2.0 * a) + (-pa + b) * t + (2.0 * pa - 5.0 * a + 4.0 * b - pb) * t * t + (-pa + 3.0 * a - 3.0 * b + pb) * t * t * t)
			samples.append(p)
	samples.append(pts[pts.size() - 1])
	var along = 0.0
	for i in samples.size():
		var p: Vector2 = samples[i]
		if i > 0:
			along += p.distance_to(samples[i - 1])
		var dir = (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var nrm = Vector2(-dir.y, dir.x)
		if nrm.y > 0.0 or (nrm.y == 0.0 and nrm.x > 0.0):
			nrm = -nrm  # point the normal up, towards the light
		var t = float(i) / samples.size()
		# taper fast near the base, so a branch flares where it leaves its parent
		var w = lerpf(w0, w1, 1.0 - pow(1.0 - t, 1.25))
		for y in range(int(p.y - w - 1), int(p.y + w + 2)):
			for x in range(int(p.x - w - 1), int(p.x + w + 2)):
				var d = Vector2(x + 0.5, y + 0.5) - p
				var dist = d.length()
				if dist > w:
					continue
				var k = Vector2i(x, y)
				if net.has(k) and net[k][3] - net[k][0] >= w - dist:
					continue
				net[k] = [dist, d.dot(nrm) / w, along + pts[0].x * 0.37, w]

# Draws the gathered roots: shadow on the grass, then bark lit from the top left
# with grain and knots running along it, outlined only where it meets the ground.
func flush_roots():
	for k in net:
		var s = k + Vector2i(1, 2)
		if not net.has(s) and s.y > 112 and s.x >= 0 and s.x < img.get_width() and s.y < img.get_height():
			px(s.x, s.y, img.get_pixel(s.x, s.y).darkened(0.22))
	# grain: each pixel falls in a band across the root; a dark line runs where
	# the band changes, so the lines follow the root unbroken
	var band = {}
	for k in net:
		var e = net[k]
		band[k] = floori(e[1] * clampf(e[3] * 0.7, 1.0, 2.6) + 0.35 * sin(e[2] * 0.3))
	for k in net:
		var e = net[k]
		var v: float = e[1]
		var w: float = e[3]
		var c = BARK[2]
		if v > 0.4: c = BARK[3]
		elif v < -0.45: c = BARK[1]
		if v > 0.75 and w > 1.6: c = BARK[4]
		var up = k + Vector2i(0, -1)
		if w > 1.5 and v < 0.7 and band.has(up) and band[up] != band[k] and absf(net[up][3] - w) < 0.6:
			c = BARK[1]
		# a knot every so often along the thicker roots
		if w > 2.6 and fmod(e[2] + 3.0, 23.0) < 1.8 and absf(v + 0.1) < 0.3:
			c = BARK[0] if absf(v + 0.1) < 0.12 else BARK[1]
		# outline only against the grass, not between roots
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not net.has(k + o):
				c = BARK[0]
		px(k.x, k.y, c)
	net = {}

# A short rootlet from `p` heading `ang`, curling by `curl` per step.
func rootlet(p: Vector2, ang: float, n: int, curl: float):
	var pts = [p]
	var d = Vector2.from_angle(ang)
	for i in n:
		d = d.rotated(curl)
		pts.append(pts[pts.size() - 1] + d * 4.5)
	root(pts, 2.8, 1.0)

# Smooth rolling noise in about -1..1, for the meadow's drifts of colour.
func meadow_noise(x: float, y: float) -> float:
	return 0.5 * sin(x * 1.7 + sin(y * 1.3) * 1.8) + 0.3 * sin(y * 2.1 + x * 0.6) + 0.2 * sin((x - y) * 2.9)

# Bare earth where a root breaks the ground, `w` wide.
func mound(x: int, y: int, w: int):
	for yy in range(y - 4, y + 5):
		for xx in range(x - w - 2, x + w + 3):
			var n = Vector2((xx - x) / float(w), (yy - y) / 3.0)
			if n.length() <= 1.0 + 0.15 * sin(xx * 1.7 + y):
				px(xx, yy, Color("#7a5232") if n.y < 0.0 or bayer(xx, yy) > 0.5 else Color("#5e3c22"))

func moss(x: int, y: int, rng: RandomNumberGenerator):
	for i in 5:
		var q = Vector2i(x + rng.randi_range(-2, 2), y + rng.randi_range(-1, 0))
		px(q.x, q.y, LEAF[3] if rng.randf() < 0.6 else LEAF[4])

func shroom(x: int, y: int, cap: Color):
	px(x, y, Color("#efe4cc")); px(x, y - 1, Color("#efe4cc"))
	for dx in range(-2, 3):
		px(x + dx, y - 2, cap)
	for dx in range(-1, 2):
		px(x + dx, y - 3, cap.lightened(0.2))
	px(x - 1, y - 2, Color.WHITE)

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
	# meadow: soft drifts of lighter and deeper green, dithered into each other,
	# shaded under the tree line and dappled with sun
	var greens = [Color("#3f8a39"), Color("#4a9a40"), Color("#55a846"), Color("#62b54e"), Color("#73c45a")]
	for y in range(112, 400):
		for x in 180:
			var v = 0.5 + 0.22 * meadow_noise(x * 0.07, y * 0.05) + 0.12 * meadow_noise(x * 0.23 + 7.0, y * 0.19)
			v += 0.08 * clampf((y - 112) / 90.0, 0.0, 1.0)  # brighter away from the trees
			v -= 0.3 * clampf(1.0 - (y - 112) / 14.0, 0.0, 1.0)  # the tree line's shade
			v = clampf(v, 0.0, 0.999) * (greens.size() - 1)
			var i = int(v)
			px(x, y, greens[mini(i + 1, greens.size() - 1)] if v - i > bayer(x, y) else greens[i])
	var rng = RandomNumberGenerator.new()
	rng.seed = 9
	# grass tufts: a few blades each, lit at the tips
	for i in 650:
		var x = rng.randi_range(1, 178)
		var y = rng.randi_range(118, 398)
		var base = img.get_pixel(x, y)
		var tip = base.lightened(0.28)
		var blades = [[-1, 2], [0, 3], [1, 2]] if rng.randf() < 0.6 else [[0, 2], [1, 3]]
		for bl in blades:
			for h in bl[1]:
				px(x + bl[0] + (1 if h == bl[1] - 1 and bl[0] > 0 else 0), y - h, tip if h == bl[1] - 1 else base.darkened(0.08))
	# clover patches
	for i in 14:
		var cx = rng.randi_range(6, 174)
		var cy = rng.randi_range(130, 392)
		for j in 6:
			var q = Vector2i(cx + rng.randi_range(-4, 4), cy + rng.randi_range(-2, 2))
			px(q.x, q.y, Color("#7fd062")); px(q.x + 1, q.y, Color("#5fb04a")); px(q.x, q.y + 1, Color("#5fb04a"))
	# specks of light and shade
	for i in 700:
		var x = rng.randi_range(0, 179)
		var y = rng.randi_range(114, 399)
		var b = img.get_pixel(x, y)
		px(x, y, b.lightened(0.14) if rng.randf() < 0.6 else b.darkened(0.1))
	# The Home Grove's roots wander through the meadow: no two alike, threading
	# between the plots and breaking the ground here and there.
	# Bare earth first, where a root breaks the ground.
	for m in [[150, 113, 4], [178, 125, 4], [116, 398, 5], [-2, 104, 8]]:
		mound(m[0], m[1], m[2])
	# a great root sweeping in from behind the tree line on the left...
	# ...curving down through the middle and on off to the right, in one unbroken run
	root([Vector2(-8, 102), Vector2(10, 114), Vector2(32, 126), Vector2(52, 136), Vector2(63, 156),
		Vector2(62, 178), Vector2(72, 200), Vector2(90, 216), Vector2(116, 226), Vector2(138, 223),
		Vector2(158, 226), Vector2(174, 236), Vector2(188, 246)], 7.5, 3.0)
	root([Vector2(40, 130), Vector2(30, 140), Vector2(25, 152), Vector2(28, 163)], 4.6, 0.8)

	root([Vector2(158, 226), Vector2(166, 214), Vector2(164, 202), Vector2(170, 194)], 3.4, 1.0)
	# a gnarled root curling in from the right and down to the bottom
	root([Vector2(188, 296), Vector2(164, 284), Vector2(136, 278), Vector2(119, 290), Vector2(115, 318),
		Vector2(102, 338), Vector2(80, 349), Vector2(58, 346), Vector2(48, 336)], 6.5, 2.0)
	root([Vector2(115, 318), Vector2(126, 340), Vector2(120, 364), Vector2(124, 384), Vector2(116, 398)], 4.8, 2.4)
	# a small arch breaking the ground in the top right
	root([Vector2(150, 113), Vector2(158, 106), Vector2(169, 108), Vector2(178, 125)], 3.2, 2.6)
	# a thin one creeping in on the left
	root([Vector2(-6, 236), Vector2(9, 244), Vector2(17, 258), Vector2(13, 274), Vector2(5, 280)], 4.8, 1.2)
	# and an old sprawl along the bottom left
	root([Vector2(-8, 376), Vector2(16, 368), Vector2(38, 374), Vector2(50, 392), Vector2(44, 406)], 7.0, 4.0)
	root([Vector2(16, 368), Vector2(22, 354), Vector2(34, 348)], 4.2, 1.0)
	# fine rootlets, each its own way
	rootlet(Vector2(62, 166), 0.3, 3, -0.4)
	rootlet(Vector2(128, 226), 1.9, 3, 0.5)
	rootlet(Vector2(146, 283), -1.6, 3, 0.45)
	rootlet(Vector2(90, 346), 1.3, 3, -0.6)
	rootlet(Vector2(26, 150), 2.6, 3, -0.5)
	rootlet(Vector2(40, 378), -0.9, 3, -0.3)
	rootlet(Vector2(166, 210), 0.1, 3, 0.5)
	rootlet(Vector2(121, 362), 3.0, 3, -0.5)
	rootlet(Vector2(24, 355), -1.9, 3, 0.4)
	flush_roots()
	# moss and mushrooms along the roots
	for m in [[24, 120], [57, 140], [130, 223], [150, 279], [100, 336], [30, 368], [162, 107]]:
		moss(m[0], m[1], rng)
	for s in [[74, 152, Color("#d9573b")], [104, 230, Color("#c8a2ff")], [128, 302, Color("#e8b04a")],
			[56, 358, Color("#d9573b")], [22, 268, Color("#c8a2ff")], [178, 290, Color("#d9573b")]]:
		shroom(s[0], s[1], s[2])
	# flowers in the corners and along the bottom
	var fl = [Color("#fff1a8"), Color("#f6a6c1"), Color("#ffffff"), Color("#c8a2ff"), Color("#ffb36b")]
	for i in 60:
		var x = rng.randi_range(2, 177)
		var y = rng.randi_range(132, 396)
		if not (x < 12 or x > 167 or y > 342):
			continue
		var b = img.get_pixel(x, y)
		if b.r > b.g:
			continue  # not on roots or earth
		var c = fl[rng.randi_range(0, fl.size() - 1)]
		px(x, y + 1, LEAF[1])
		px(x, y, Color("#ffd166")); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c)
	# bushes in the corners
	for b in [[6, 134, 9], [174, 138, 10], [8, 388, 10], [172, 392, 9]]:
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
