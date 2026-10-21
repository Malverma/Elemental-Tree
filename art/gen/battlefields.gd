# World-map land battlefields, 180x320 each (shown at about 7x, covering the
# screen), side by side in LANDS order on one sheet. Enemies come from the top
# and the squad holds the bottom. Units fight across the middle, so it stays
# low-contrast and free of anything column-like; the life sits around it: a
# backdrop along the enemy edge, props down both sides, soft patches between.
# A tall phone crops about 18px off each side; units span about x 40..140.
var img: Image
var rng := RandomNumberGenerator.new()
const W := 180
const H := 320
const LANDS := ["sunny_meadow", "whispering_spring", "ember_vent", "frostbite_hollow", "gloomroot_cavern",
	"brambleheart_thicket", "sunken_lagoon", "steamvent_marsh", "frostshade_barrows", "blighted_heartwood",
	"mossmire_fen", "cinderfrost_peak", "cindergloom_wastes"]

const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a")]
const WATER := [Color("#2f64b5"), Color("#3f86d0"), Color("#9fd6f5")]
const LAVA := [Color("#a8281a"), Color("#f0642d"), Color("#ffd166")]
const STONE := [Color("#4a4a52"), Color("#66666e"), Color("#85858c"), Color("#a8a8ae")]
const FLOWERS := [Color("#fff1a8"), Color.WHITE, Color("#f6a6c1"), Color("#c8a2ff"), Color("#ffb36b")]

# --- Pixels ---------------------------------------------------------------------

func px(x, y, c: Color):
	var ix := int(floor(x))
	var iy := int(floor(y))
	if ix >= 0 and iy >= 0 and ix < W and iy < H:
		img.set_pixel(ix, iy, c)

func at(x, y) -> Color:
	return img.get_pixel(clampi(int(floor(x)), 0, W - 1), clampi(int(floor(y)), 0, H - 1))

func tint(x, y, c: Color, a: float):
	px(x, y, at(x, y).lerp(c, clampf(a, 0.0, 1.0)))

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(int(y), 4)) * 4 + posmod(int(x), 4)] + 0.5) / 16.0

func noise(x: float, y: float, s := 0.0) -> float:
	return 0.5 * sin(x * 0.21 + sin(y * 0.13 + s) * 2.0 + s) + 0.3 * sin(y * 0.17 + x * 0.05 + s * 1.7) + 0.2 * sin((x + y) * 0.41 + s * 0.6)

# Smooth value noise in 0..1 (no directional streaks), and a few octaves of it.
func hash2(ix: float, iy: float, s: float) -> float:
	return fposmod(sin(ix * 127.1 + iy * 311.7 + s * 74.7) * 43758.5453, 1.0)

func vnoise(x: float, y: float, s := 0.0) -> float:
	var ix = floor(x)
	var iy = floor(y)
	var fx = x - ix
	var fy = y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a = lerpf(hash2(ix, iy, s), hash2(ix + 1, iy, s), fx)
	var b = lerpf(hash2(ix, iy + 1, s), hash2(ix + 1, iy + 1, s), fx)
	return lerpf(a, b, fy)

func fbm(x: float, y: float, s := 0.0) -> float:
	return vnoise(x / 14.0, y / 14.0, s) * 0.5 + vnoise(x / 6.0, y / 6.0, s + 1.3) * 0.3 + vnoise(x / 2.5, y / 2.5, s + 2.7) * 0.2

# A spot down one side of the field, clear of the fighting.
func edge_x(side: int) -> float:
	return rng.randf_range(12, 46) if side == 0 else rng.randf_range(134, 168)


# How far from the middle a column is, 0 at the centre and 1 at the sides.
func edginess(x) -> float:
	return absf(x - W / 2.0) / (W / 2.0)

# --- Ground ---------------------------------------------------------------------

# Three-tone dithered ground, with broad lighter and darker swathes for depth.
func ground(pal: Array, s: float):
	for y in H:
		for x in W:
			var v = fbm(x, y, s) + (bayer(x, y) - 0.5) * 0.16
			var c: Color = pal[1]
			if v > 0.6: c = pal[2]
			elif v < 0.4: c = pal[0]
			var broad = vnoise(x / 34.0, y / 34.0, s + 9.0) + (bayer(x, y) - 0.5) * 0.12
			if broad > 0.68: c = c.lightened(0.05)
			elif broad < 0.3: c = c.darkened(0.06)
			# The sides sink a little into shade, framing the fight.
			var e = edginess(x)
			if e > 0.78 + bayer(x, y) * 0.12: c = c.darkened(0.1)
			px(x, y, c)

# A soft patch blended into the ground at strength `a`, its rim dithered away.
func patch(cx, cy, r, c: Color, squash := 1.4, a := 1.0):
	for y in range(int(cy - r * 1.4) - 2, int(cy + r * 1.4) + 3):
		for x in range(int(cx - r * squash * 1.4) - 2, int(cx + r * squash * 1.4) + 3):
			var d = sqrt(pow((x - cx) / (r * squash), 2) + pow((y - cy) / r, 2)) + (vnoise(x / 3.0, y / 3.0, cx) - 0.5) * 0.6
			if d < 0.7 or (d < 1.0 and bayer(x, y) > (d - 0.7) / 0.3):
				tint(x, y, c, a)

# Soft patches of a colour mixed into the ground, `n` of them anywhere below the backdrop.
func patches(n: int, c: Color, rmin: float, rmax: float, a := 0.45, top := 40):
	for i in n:
		patch(rng.randf_range(0, W), rng.randf_range(top, H), rng.randf_range(rmin, rmax), c, 1.4, a)

func specks(n: int, cols: Array, top := 36, tall := 0.5):
	for i in n:
		var x = rng.randi_range(0, W - 1)
		var y = rng.randi_range(top, H - 1)
		var c: Color = cols[rng.randi_range(0, cols.size() - 1)]
		px(x, y, c)
		if rng.randf() < tall:
			px(x, y - 1, c.lightened(0.08))

func glow(cx, cy, r, c: Color, strength := 0.5):
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			var d = Vector2(x - cx, y - cy).length() / r
			if d < 1.0:
				var a = snappedf(strength * (1.0 - d) * (1.0 - d) + (bayer(x, y) - 0.5) * 0.1, 0.1)
				if a > 0.0:
					tint(x, y, c, a)

func shadow(cx, cy, rx, ry, amt := 0.3):
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1.0:
				px(x, y, at(x, y).darkened(amt))

# --- Shapes ---------------------------------------------------------------------

func shade(n: Vector2, x, y, pal: Array) -> Color:
	var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
	return pal[3] if t > 0.45 else (pal[2] if t > 0.05 else (pal[1] if t > -0.45 else pal[0]))

func blob(cx: float, cy: float, rx: float, ry: float, pal: Array, lumpy := 0.0):
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var n = Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0 + lumpy * sin(atan2(n.y, n.x) * 6.0 + cx):
				px(x, y, shade(n, x, y, pal))

# Darkens the pixels just outside whatever was drawn since `ref` was taken.
func outline_since(ref: Image, r: Rect2i, amt := 0.72):
	var after = img.duplicate()
	for y in range(maxi(r.position.y, 0), mini(r.end.y, H)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, W)):
			if after.get_pixel(x, y) != ref.get_pixel(x, y):
				continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and after.get_pixel(q.x, q.y) != ref.get_pixel(q.x, q.y):
					img.set_pixel(x, y, after.get_pixel(q.x, q.y).darkened(amt))
					break

func box(cx, cy, r) -> Rect2i:
	return Rect2i(int(cx - r) - 2, int(cy - r) - 2, int(r * 2) + 5, int(r * 2) + 5)

# --- Props ----------------------------------------------------------------------

func bush(cx, cy, r, pal: Array, dots := []):
	shadow(cx, cy + r * 0.6, r * 1.4, 2.2, 0.25)
	var ref = img.duplicate()
	blob(cx - r * 0.5, cy, r * 0.8, r * 0.7, pal, 0.08)
	blob(cx + r * 0.5, cy + 0.5, r * 0.75, r * 0.65, pal, 0.08)
	blob(cx, cy - r * 0.35, r * 0.85, r * 0.75, pal, 0.08)
	for k in (int(r) if not dots.is_empty() else 0):
		px(cx + rng.randf_range(-r, r), cy + rng.randf_range(-r * 0.8, r * 0.4), dots[rng.randi_range(0, dots.size() - 1)])
	outline_since(ref, box(cx, cy, r * 1.6))

func tree(cx, base, r, leaf: Array, bark := BARK):
	shadow(cx + 2, base + 1, r * 1.2, 2.5, 0.3)
	var ref = img.duplicate()
	for y in range(int(base - r * 1.3), int(base) + 1):
		px(cx - 1, y, bark[0]); px(cx, y, bark[1]); px(cx + 1, y, bark[2])
	blob(cx - r * 0.55, base - r * 1.4, r * 0.7, r * 0.62, leaf, 0.1)
	blob(cx + r * 0.55, base - r * 1.35, r * 0.7, r * 0.6, leaf, 0.1)
	blob(cx, base - r * 1.9, r * 0.8, r * 0.7, leaf, 0.1)
	outline_since(ref, Rect2i(int(cx - r * 2), int(base - r * 3), int(r * 4) + 2, int(r * 3) + 4))

func pine(cx, base, h, pal: Array, snow := false):
	shadow(cx + 1, base + 1, h * 0.32, 2.0, 0.3)
	var ref = img.duplicate()
	var top = base - h
	for y in range(int(top), int(base - 2)):
		var t = (y - top) / (h - 2.0)
		var tier = fmod(t * 3.0, 1.0)
		var hw = (0.12 + 0.88 * t) * h * 0.3 * (0.5 + 0.5 * tier)
		for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
			var side = (x - cx) / maxf(hw, 1.0)
			var c: Color = pal[2] if side > 0.2 + bayer(x, y) * 0.3 else (pal[1] if side > -0.5 else pal[0])
			if snow and tier < 0.22 + bayer(x, y) * 0.15:
				c = Color("#eef6fa") if side > -0.3 else Color("#c6deec")
			px(x, y, c)
	for y in range(int(base - 2), int(base) + 1):
		px(cx, y, BARK[1])
	outline_since(ref, Rect2i(int(cx - h * 0.4) - 2, int(top) - 2, int(h * 0.8) + 5, int(h) + 5))

func rock(cx, cy, r, pal: Array, cap = null):
	shadow(cx + 1, cy + r * 0.6, r * 1.2, 1.8, 0.3)
	var ref = img.duplicate()
	blob(cx, cy, r, r * 0.72, pal, 0.06)
	if cap != null:
		for x in range(int(cx - r), int(cx + r) + 1):
			var top_y = cy - r * 0.72 * sqrt(maxf(0.0, 1.0 - pow((x - cx) / r, 2)))
			for y in range(int(top_y), int(top_y + 1.5 + bayer(x, 0) * 1.5)):
				px(x, y, cap)
	outline_since(ref, box(cx, cy, r))

func shard(cx, base, h, w, pal: Array, lean):
	var top = base - h
	for y in range(int(top), int(base) + 1):
		var hw = minf((y - top) * 0.7, w)
		var mx = cx + lean * (base - y) / h
		for x in range(int(round(mx - hw)), int(round(mx + hw)) + 1):
			px(x, y, pal[1] if x < mx - 0.4 else (pal[3] if absf(x - mx) < 0.6 else pal[2]))

func crystals(cx, base, s, pal: Array, glow_c = null):
	if glow_c != null:
		glow(cx, base - s * 0.8, s * 2.6, glow_c, 0.4)
	shadow(cx, base + 1, s * 1.3, 1.6, 0.3)
	var ref = img.duplicate()
	shard(cx - s * 0.6, base, s * 1.1, s * 0.32, pal, -2)
	shard(cx + s * 0.65, base, s * 0.9, s * 0.3, pal, 2)
	shard(cx, base, s * 1.8, s * 0.4, pal, 0)
	outline_since(ref, Rect2i(int(cx - s * 2), int(base - s * 2.2), int(s * 4) + 3, int(s * 2.4) + 4))

# A mushroom drawn from a fixed pattern so it stays crisp at this size: a big
# spotted cap (r >= 2.5) or a small plain one, outlined on its own.
const MUSH_BIG := [
	"..MML..",
	".MMMLL.",
	"MSMMMLM",
	"DMMMSMM",
	".DDDDD.",
	"..TTt..",
	"..TTt..",
]
const MUSH_SMALL := [
	".MML.",
	"MSMMM",
	".DDD.",
	"..Tt.",
	"..Tt.",
]

func mushroom(cx, base, r, cap: Array, glow_c = null):
	var rows: Array = MUSH_BIG if r >= 2.5 else MUSH_SMALL
	var w: int = rows[0].length()
	var ox = int(cx) - w / 2
	var oy = int(base) - rows.size() + 1
	if glow_c != null:
		glow(cx, oy + 2, w * 1.6, glow_c, 0.45)
	var ref = img.duplicate()
	var cols = {"D": cap[0], "M": cap[1], "L": cap[2], "S": Color("#fff6e8"), "T": Color("#e8dcc8"), "t": Color("#b8a890")}
	for y in rows.size():
		for x in w:
			var ch = rows[y][x]
			if cols.has(ch):
				px(ox + x, oy + y, cols[ch])
	outline_since(ref, Rect2i(ox - 1, oy - 1, w + 2, rows.size() + 2))

# Two or three mushrooms side by side, the nearer (lower) ones drawn last so
# each keeps its own outline.
func mushrooms(cx, cy, cap: Array, glow_c = null):
	var spots = [Vector2(cx, cy - 1), Vector2(cx - 6, cy + 1)]
	if rng.randf() < 0.6:
		spots.append(Vector2(cx + 6, cy + 2))
	spots.sort_custom(func(a, b): return a.y < b.y)
	for i in spots.size():
		var p: Vector2 = spots[i]
		mushroom(p.x, p.y, 3.0 if i == 0 else rng.randf_range(1.5, 3.2), cap, glow_c)

# A pool of water or lava; `hot` lights its middle instead of deepening it.
func pool(cx, cy, rx, ry, pal: Array, shore: Color, hot := false):
	if hot:
		glow(cx, cy, maxf(rx, ry) * 1.8, pal[1], 0.4)
	for y in range(int(cy - ry * 1.3) - 3, int(cy + ry * 1.3) + 4):
		for x in range(int(cx - rx * 1.3) - 3, int(cx + rx * 1.3) + 4):
			var d = pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) + (vnoise(x / 3.0, y / 3.0, cx) - 0.5) * 0.3
			if d <= 1.0:
				var depth = 1.0 - d + (bayer(x, y) - 0.5) * 0.2
				var c: Color
				if hot:
					c = pal[2] if depth > 0.65 else (pal[1] if depth > 0.25 else pal[0])
				else:
					c = pal[0] if depth > 0.45 else pal[1]
					if y < cy - ry * 0.55 and depth < 0.3: c = pal[2]
				px(x, y, c)
			elif d <= 1.0 + 2.4 / minf(rx, ry):
				px(x, y, shore)
	for k in maxi(1, int(rx / 4)):
		var gx = cx + rng.randf_range(-rx * 0.55, rx * 0.4)
		var gy = cy + rng.randf_range(-ry * 0.4, ry * 0.3)
		for j in rng.randi_range(2, 4):
			px(gx + j, gy, pal[2])

func lilypad(cx, cy, r := 2.2, bloom := false):
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r * 1.3), int(cx + r * 1.3) + 1):
			var n = Vector2((x - cx) / (r * 1.3), (y - cy) / r)
			if n.length() <= 1.0 and not (n.x > 0.1 and absf(n.y) < 0.3):
				px(x, y, LEAF[3] if n.y < -0.2 else LEAF[2])
	if bloom:
		px(cx - 1, cy - 1, Color("#f6a6c1")); px(cx, cy - 2, Color("#ffd4e2")); px(cx, cy - 1, Color("#fff1a8"))

func reeds(cx, cy, n: int, green: Color, tip = null):
	for k in n:
		var x = cx + rng.randf_range(-4, 4)
		var h = rng.randi_range(4, 8)
		var lean = rng.randf_range(-0.25, 0.25)
		for j in h:
			px(x + lean * j, cy - j, green if j < h - 1 else green.lightened(0.2))
		if tip != null and rng.randf() < 0.6:
			px(x + lean * (h - 1), cy - h, tip); px(x + lean * (h - 1), cy - h - 1, tip)

func flower(x, y, c: Color, stem := LEAF[1]):
	px(x, y + 1, stem)
	px(x, y, Color("#ffd166")); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c)

func tuft(x, y, c: Color):
	px(x, y, c); px(x - 1, y - 1, c); px(x + 1, y - 1, c); px(x, y - 2, c.lightened(0.1))

func fern(cx, cy, pal: Array):
	for k in 5:
		var dir = Vector2.from_angle(-PI / 2 + (k - 2) * 0.55)
		for j in 7:
			var p = Vector2(cx, cy) + dir * j + Vector2(0, j * j * 0.06)
			px(p.x, p.y, pal[2] if j % 2 == 0 else pal[1])
			if j > 1 and j < 6:
				px(p.x - dir.y, p.y + dir.x * 0.5, pal[1])

func log_prop(cx, cy, length, bark := BARK, moss = null):
	shadow(cx, cy + 3, length * 0.55, 1.8, 0.3)
	var ref = img.duplicate()
	for x in range(int(cx - length / 2), int(cx + length / 2)):
		for y in range(-2, 3):
			px(x, cy + y, bark[2] if y == -2 else (bark[0] if y == 2 else bark[1]))
		if moss != null and bayer(x, cy) > 0.35:
			px(x, cy - 3, moss)
	var ex = cx + length / 2
	for y in range(-2, 3):
		for x in range(0, 3):
			if Vector2(x - 1, y).length() <= 2.4:
				px(ex + x - 1, cy + y, Color("#c49a62") if Vector2(x - 1, y).length() > 1.2 else Color("#8a5f34"))
	outline_since(ref, Rect2i(int(cx - length / 2) - 2, int(cy) - 5, int(length) + 6, 10))

func pillar(cx, base, h, pal: Array, moss = null):
	shadow(cx + 2, base + 1, 6, 2, 0.3)
	var ref = img.duplicate()
	var top = base - h
	for y in range(int(top), int(base) + 1):
		var w = 3 if y < base - 2 else 4
		var jag = 0
		if y < top + 2:
			jag = 1
		for x in range(int(cx - w), int(cx + w) + 1):
			if y < top + 2 and bayer(x, y) > 0.55:
				continue
			var side = x - cx
			px(x, y, pal[3] if side >= 2 else (pal[2] if side >= 0 else (pal[1] if side > -3 else pal[0])))
		if (y - int(top)) % 5 == 4:
			for x in range(int(cx - w), int(cx + w) + 1):
				px(x, y, pal[0])
	if moss != null:
		for k in 6:
			px(cx + rng.randf_range(-3, 3), top + rng.randf_range(0, h), moss)
	outline_since(ref, Rect2i(int(cx) - 7, int(top) - 2, 15, int(h) + 5))

func tomb(cx, base, pal: Array, frost = null):
	shadow(cx + 1, base + 1, 5, 1.6, 0.3)
	var ref = img.duplicate()
	for y in range(int(base - 9), int(base) + 1):
		for x in range(int(cx - 3), int(cx + 4)):
			var n = Vector2((x - cx - 0.5) / 3.5, (y - (base - 6)) / 3.5)
			if y >= base - 6 or n.length() <= 1.0:
				px(x, y, pal[2] if x > cx + 1 else (pal[1] if x > cx - 2 else pal[0]))
	px(cx, base - 6, pal[0]); px(cx, base - 5, pal[0]); px(cx - 1, base - 5, pal[0]); px(cx + 1, base - 5, pal[0]); px(cx, base - 4, pal[0])
	if frost != null:
		for x in range(int(cx - 2), int(cx + 3)):
			px(x, base - 9 + (1 if absf(x - cx) > 1 else 0), frost)
	outline_since(ref, Rect2i(int(cx) - 6, int(base) - 12, 13, 15))

func dead_tree(cx, base, h, c: Color):
	shadow(cx + 2, base + 1, 5, 1.5, 0.3)
	var ref = img.duplicate()
	_branch(Vector2(cx, base), -PI / 2, h, 2, c)
	outline_since(ref, Rect2i(int(cx - h), int(base - h * 1.6), int(h * 2) + 2, int(h * 1.6) + 4), 0.5)

func _branch(p: Vector2, a: float, length: float, width: int, c: Color):
	var dir = Vector2.from_angle(a)
	for j in int(length):
		var q = p + dir * j
		for w in width:
			px(q.x + w, q.y, c if w == 0 else c.lightened(0.15))
	if length > 3:
		var end = p + dir * length
		_branch(end, a - rng.randf_range(0.35, 0.7), length * 0.6, maxi(1, width - 1), c)
		_branch(end, a + rng.randf_range(0.35, 0.7), length * 0.55, maxi(1, width - 1), c)

func bones(x, y):
	var c = Color("#e8e0cc")
	px(x, y, c); px(x + 1, y, c); px(x + 2, y, c); px(x - 1, y - 1, c); px(x - 1, y + 1, c); px(x + 3, y - 1, c); px(x + 3, y + 1, c)

# A glowing crack wandering over the ground.
func crack(x, y, steps: int, core: Color, glow_c = null, glow_amt := 0.3):
	var pts := []
	var p = Vector2(x, y)
	var a = rng.randf_range(0, TAU)
	for i in steps:
		pts.append(p.floor())
		a += rng.randf_range(-0.7, 0.7)
		p += Vector2.from_angle(a)
	if glow_c != null:
		for i in range(0, pts.size(), 3):
			glow(pts[i].x, pts[i].y, 4.5, glow_c, glow_amt)
	for q in pts:
		px(q.x, q.y, core)

func steam(cx, cy):
	for k in 7:
		var y = cy - k * 1.6
		var x = cx + sin(k * 1.3) * 2.0
		tint(x, y, Color.WHITE, 0.55 - k * 0.06)
		tint(x + 1, y, Color.WHITE, 0.4 - k * 0.05)

func root(x0, y0, x1, y1, thick: float, pal: Array):
	var ref = img.duplicate()
	var n = int(Vector2(x1 - x0, y1 - y0).length())
	for i in n:
		var t = float(i) / n
		var p = Vector2(lerp(x0, x1, t), lerp(y0, y1, t)) + Vector2(0, sin(t * 7.0 + x0) * 3.0)
		var r = thick * (1.0 - t * 0.6)
		for dy in range(int(-r), int(r) + 1):
			px(p.x, p.y + dy, pal[2] if dy < -r * 0.3 else (pal[1] if dy < r * 0.5 else pal[0]))
	outline_since(ref, Rect2i(int(mini(x0, x1)) - 4, int(mini(y0, y1)) - int(thick) - 6, int(absf(x1 - x0)) + 9, int(absf(y1 - y0) + thick * 2) + 13))

# --- Backdrops along the enemy edge -------------------------------------------------

func treeline(pal: Array, base := 12.0, trees := 14):
	for x in W:
		var top = int(base + 4 * sin(x * 0.19) + 3 * sin(x * 0.47 + 1.0))
		for y in range(0, top + 6):
			var c: Color = pal[1] if y < top else pal[2]
			if y < top and bayer(x, y) > 0.8: c = pal[2]
			px(x, y, c)
	for i in trees:
		blob(rng.randf_range(0, W), rng.randf_range(base - 8, base), rng.randf_range(6, 10), rng.randf_range(5, 8), pal, 0.08)
	for x in W:
		var y = int(base + 4 + 3 * sin(x * 0.23))
		if bayer(x, y) > 0.3:
			px(x, y, pal[0].darkened(0.2))

func cliffs(pal: Array, base := 22.0):
	for x in W:
		var bottom = base + 3 * sin(x * 0.13) + 2 * sin(x * 0.51 + 2.0)
		for y in range(0, int(bottom) + 1):
			var strata = sin(y * 0.9 + sin(x * 0.2) * 1.5)
			var c: Color = pal[1]
			if strata > 0.55: c = pal[2]
			elif strata < -0.6: c = pal[0]
			if bayer(x, y) > 0.92: c = pal[3]
			px(x, y, c)
		px(x, bottom + 1, pal[0].darkened(0.4))
		px(x, bottom + 2, at(x, bottom + 2).darkened(0.25))

func fall(x0, base, pal: Array, width := 4):
	for y in range(0, int(base) + 2):
		for x in range(x0, x0 + width):
			px(x, y, pal[2] if (x + y / 2) % 3 == 0 else pal[1])
	for k in 9:
		px(x0 + rng.randf_range(-3, width + 3), base + rng.randf_range(0, 4), pal[2])

func cave_wall(pal: Array, base := 20.0):
	cliffs(pal, base)
	var x = 2.0
	while x < W:
		var h = rng.randf_range(4, 12)
		var w = rng.randf_range(2, 4)
		var top_y = base + 2 * sin(x * 0.13)
		for y in range(int(top_y), int(top_y + h)):
			var hw = w * (1.0 - (y - top_y) / h)
			for xx in range(int(x - hw), int(x + hw) + 1):
				px(xx, y, pal[2] if xx > x else pal[1])
		x += rng.randf_range(7, 15)

func pine_row(pal: Array, snow: bool):
	for x in W:
		for y in range(0, 14):
			px(x, y, pal[0])
	var x = -4.0
	while x < W + 4:
		pine(x, rng.randf_range(22, 30), rng.randf_range(18, 26), pal, snow)
		x += rng.randf_range(9, 14)

func mist(top: int, bottom: int, c: Color, amt := 0.35):
	for y in range(top, bottom):
		var a = amt * (1.0 - float(y - top) / (bottom - top))
		for x in W:
			if bayer(x, y) < a * 2.0:
				tint(x, y, c, 0.35)

# --- Lands ----------------------------------------------------------------------

func land(id: String):
	match id:
		"sunny_meadow":
			ground([Color("#4c9a40"), Color("#56a646"), Color("#5fb04c")], 0.0)
			patches(10, Color("#66b852"), 6, 12)
			patches(24, Color("#4f9e42"), 4, 9)
			specks(80, [Color("#e8f4d8")], 40, 0.0)
			specks(460, [Color("#72c25a"), Color("#72c25a"), Color("#3f8738")])
			treeline([LEAF[0], LEAF[1], LEAF[2], LEAF[3]])
			for x in [24, 64, 118, 158]:
				tree(x + rng.randf_range(-6, 6), rng.randf_range(24, 30), rng.randf_range(7, 9), [LEAF[1], LEAF[2], LEAF[3], LEAF[4]])
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.4: bush(x, y, rng.randf_range(5, 8), [LEAF[1], LEAF[2], LEAF[3], LEAF[4]], [Color("#ff9c8f"), Color("#fff1a8")] if rng.randf() < 0.4 else [])
				elif r < 0.65:
					for k in rng.randi_range(5, 9): flower(x + rng.randf_range(-7, 7), y + rng.randf_range(-5, 5), FLOWERS[rng.randi_range(0, 4)])
				elif r < 0.8: rock(x, y, rng.randf_range(3, 5), STONE)
				elif r < 0.92: mushrooms(x, y, [Color("#a8321e"), Color("#d9534f"), Color("#ff9c8f")])
				else: tree(x + (-8 if side == 0 else 8), y, 8, [LEAF[1], LEAF[2], LEAF[3], LEAF[4]]), 28.0)
			_scatter(150, func(x, y): flower(x, y, FLOWERS[rng.randi_range(0, 4)]) if rng.randf() < 0.5 else px(x, y, FLOWERS[rng.randi_range(0, 4)]))
			_scatter(30, func(x, y): tuft(x, y, Color("#3f8738")), 0.1)
		"whispering_spring":
			ground([Color("#3f8f5e"), Color("#4a9c68"), Color("#56a872")], 1.0)
			patches(20, Color("#52a46e"), 5, 10)
			patches(10, Color("#44925f"), 6, 12)
			specks(420, [Color("#6cc08a"), Color("#3a8054")])
			var spring_pal = [Color("#3c5a6a"), Color("#56788a"), Color("#7898a8"), Color("#a8c4d0")]
			cliffs(spring_pal, 20)
			for k in 2:
				fall(40 + k * 92 + rng.randi_range(-6, 6), 21, WATER)
			for x in W:
				for y in range(26, 34):
					var d = absf(y - 30 - 1.5 * sin(x * 0.12))
					if d < 3.2: px(x, y, WATER[2] if (x + y) % 7 == 0 else (WATER[1] if d < 2.0 else Color("#8fc4a8")))
			for side in [0, 1]:
				for k in 3:
					var x = edge_x(side)
					var y = 70 + k * 80 + rng.randf_range(-10, 10)
					pool(x, y, rng.randf_range(9, 13), rng.randf_range(5, 7), WATER, Color("#6f8a60"))
					lilypad(x + rng.randf_range(-5, 5), y + rng.randf_range(-2, 2), 2.0, rng.randf() < 0.5)
					reeds(x + rng.randf_range(-8, 8), y + 6, 6, Color("#2e7a4a"), Color("#7a4e26"))
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.35: fern(x, y, [Color("#1f5a3a"), Color("#2e7a4a"), Color("#5dbb7c")])
				elif r < 0.6: rock(x, y, rng.randf_range(3, 5), spring_pal, Color("#5dbb7c"))
				elif r < 0.85:
					for k in rng.randi_range(4, 7): flower(x + rng.randf_range(-6, 6), y + rng.randf_range(-4, 4), [Color("#9fd6f5"), Color.WHITE, Color("#c8a2ff")][rng.randi_range(0, 2)], Color("#2e7a4a"))
				else: bush(x, y, rng.randf_range(5, 7), [Color("#1f5a3a"), Color("#2e7a4a"), Color("#3f9a5e"), Color("#7ad69a")]), 34.0)
			_scatter(110, func(x, y): px(x, y, [Color("#9fd6f5"), Color.WHITE, Color("#c8a2ff")][rng.randi_range(0, 2)]))
			_scatter(14, func(x, y): rock(x, y, 1.6, spring_pal), 0.3)
		"ember_vent":
			var basalt = [Color("#2a1a16"), Color("#3e2620"), Color("#5a3a2e"), Color("#7a5444")]
			ground([Color("#3a2420"), Color("#472c26"), Color("#553630")], 2.0)
			patches(16, Color("#4e302a"), 6, 12)
			specks(260, [Color("#5e3e34"), Color("#2e1a14"), Color("#6a6260")], 36, 0.1)
			for k in 12:
				crack(rng.randf_range(0, W), rng.randf_range(50, H - 10), rng.randi_range(10, 22), Color("#c8321e"), LAVA[1], 0.18)
			cliffs(basalt, 22)
			for k in 3:
				var fx = 20 + k * 65 + rng.randi_range(-8, 8)
				glow(fx + 1, 20, 12, LAVA[1], 0.45)
				fall(fx, 22, LAVA, 3)
			for side in [0, 1]:
				for k in 2:
					var x = edge_x(side)
					var y = 90 + k * 120 + rng.randf_range(-15, 15)
					pool(x, y, rng.randf_range(9, 12), rng.randf_range(5, 7), LAVA, Color("#2a1a16"), true)
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.5: rock(x, y, rng.randf_range(3, 6), basalt)
				elif r < 0.75:
					glow(x, y - 2, 8, LAVA[1], 0.4)
					rock(x, y, 3.5, basalt)
					for k in 4: px(x + rng.randf_range(-2, 2), y - 4 - k * 2, LAVA[2] if k % 2 else LAVA[1])
				else: crystals(x, y, 3.5, [Color("#5a1a10"), Color("#a8281a"), Color("#f0642d"), Color("#ffd166")], LAVA[1]), 30.0)
			_scatter(70, func(x, y): px(x, y, LAVA[1] if rng.randf() < 0.5 else LAVA[2]), 0.4)
			_scatter(20, func(x, y): rock(x, y, 1.6, basalt), 0.3)
		"frostbite_hollow":
			ground([Color("#c6deec"), Color("#d8eaf4"), Color("#ecf5fa")], 3.0)
			patches(18, Color("#bcd6e8"), 6, 14)
			patches(10, Color("#f4f9fc"), 5, 10)
			specks(160, [Color.WHITE, Color("#a9d3ea")], 36, 0.0)
			var pines = [Color("#1f4d3b"), Color("#2e6b4c"), Color("#3f8a5e"), Color("#5aa878")]
			pine_row(pines, true)
			var ice = [Color("#5ba4e8"), Color("#9fddf5"), Color("#c6eeff"), Color.WHITE]
			for side in [0, 1]:
				var x = edge_x(side)
				var y = rng.randf_range(120, 200)
				pool(x, y, 13, 7, [Color("#8cc4e4"), Color("#a9d6ee"), Color("#e8f8ff")], Color("#b4d0e2"))
				for k in 3:
					var a = rng.randf_range(0, TAU)
					for j in 6: px(x + cos(a) * j * 1.5, y + sin(a) * j * 0.7, Color("#e8f8ff"))
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.4: pine(x, y, rng.randf_range(14, 20), pines, true)
				elif r < 0.65: crystals(x, y, rng.randf_range(3, 4.5), ice, Color("#c6eeff"))
				elif r < 0.85: rock(x, y, rng.randf_range(3, 5), [Color("#4a5a6e"), Color("#66788c"), Color("#8496aa"), Color("#a8b8c8")], Color("#f4f9fc"))
				else:
					patch(x, y, 5, Color("#f4f9fc"), 1.8)
					shadow(x + 1, y + 3, 6, 1.5, 0.08), 30.0)
			_scatter(60, func(x, y): px(x, y, Color.WHITE) if rng.randf() < 0.6 else px(x, y, Color("#9fddf5")))
			_scatter(12, func(x, y): crystals(x, y, 1.6, ice), 0.4)
		"gloomroot_cavern":
			var cave = [Color("#1c1624"), Color("#2a2034"), Color("#3a2e48"), Color("#4c3e5c")]
			ground([Color("#2e2538"), Color("#382d44"), Color("#433650")], 4.0)
			patches(14, Color("#3e3249"), 6, 12)
			specks(240, [Color("#4c3e5c"), Color("#241c2e")], 36, 0.0)
			cave_wall(cave, 20)
			var roots = [Color("#2a1a14"), Color("#4a2e20"), Color("#6a4630")]
			root(-4, 40, 30, 70, 3.0, roots); root(184, 60, 150, 96, 3.0, roots)
			root(-4, 200, 26, 236, 2.6, roots); root(184, 250, 156, 280, 2.6, roots)
			var glow_caps = [[Color("#4a2a7a"), Color("#8a5ad0"), Color("#c8a2ff")], [Color("#1f6a6a"), Color("#3fb0a0"), Color("#9ff0e0")]]
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.4:
					var k = rng.randi_range(0, 1)
					mushrooms(x, y, glow_caps[k], glow_caps[k][1])
				elif r < 0.65: crystals(x, y, rng.randf_range(3, 4.5), [Color("#3a1f5a"), Color("#6a3fa0"), Color("#a77ce0"), Color("#e8d8ff")], Color("#a77ce0"))
				elif r < 0.85: crystals(x, y, rng.randf_range(4, 6), cave)
				else: rock(x, y, rng.randf_range(3, 5), cave), 30.0)
			_scatter(40, func(x, y):
				glow(x, y, 3, Color("#9ff0e0"), 0.35)
				px(x, y, Color("#9ff0e0")), 0.3)
			_scatter(10, func(x, y): mushroom(x, y, 1.6, glow_caps[1], glow_caps[1][1]), 0.5)
		"brambleheart_thicket":
			ground([Color("#3a5a2a"), Color("#446830"), Color("#4f7636")], 5.0)
			patches(14, Color("#5d8a40"), 6, 12)
			patches(20, Color("#5a5a2a"), 3, 7)
			specks(300, [Color("#7d6a30"), Color("#8a5530"), Color("#5d8a40"), Color("#2e4a22")])
			var dark_leaf = [Color("#14301c"), Color("#1f4426"), Color("#2e6030"), Color("#4a8a3a")]
			treeline(dark_leaf, 16, 20)
			for x in [14, 52, 96, 140, 172]:
				tree(x + rng.randf_range(-5, 5), rng.randf_range(26, 32), rng.randf_range(8, 10), dark_leaf)
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.4: bush(x, y, rng.randf_range(5, 8), dark_leaf, [Color("#c8321e"), Color("#8a1a2a"), Color("#e8dcc8")])
				elif r < 0.6: fern(x, y, [Color("#1f4426"), Color("#2e6030"), Color("#6aaa4a")])
				elif r < 0.75: log_prop(x, y, rng.randf_range(12, 16), BARK, Color("#5dbb4c"))
				elif r < 0.9: mushrooms(x, y, [Color("#8a3a1a"), Color("#c8642d"), Color("#ffb347")])
				else: tree(x + (-6 if side == 0 else 6), y, 9, dark_leaf), 26.0)
			_scatter(70, func(x, y): px(x, y, [Color("#c8a040"), Color("#a86a2a"), Color("#e8dcc8")][rng.randi_range(0, 2)]))
			_scatter(16, func(x, y): tuft(x, y, Color("#2e4a22")), 0.2)
		"sunken_lagoon":
			ground([Color("#c8b07a"), Color("#d4bf8a"), Color("#dfcc9a")], 6.0)
			patches(16, Color("#c2aa74"), 6, 12)
			specks(220, [Color("#ebdcae"), Color("#b09868")], 36, 0.0)
			for k in 10:
				var x = rng.randf_range(0, W)
				var y = rng.randf_range(60, H - 20)
				var shallow = Color("#9cc8b8") if edginess(x) > 0.5 else Color("#c0c8a4")
				patch(x, y, rng.randf_range(4, 8), shallow, 1.8, 0.6)
			var ruin = [Color("#5a6a6e"), Color("#7a8a8a"), Color("#9aa8a4"), Color("#c0ccc4")]
			for x in W:
				for y in range(0, 30):
					var d = y - (26 + 2 * sin(x * 0.15))
					var c = Color("#2f64b5") if d < -10 else (Color("#3f86d0") if d < -3 else (Color("#7ec4d8") if d < 0 else Color("#e8f4f0") if d < 1.2 else at(x, y)))
					if d < -3 and (x * 3 + y * 7) % 23 == 0: c = Color("#9fd6f5")
					px(x, y, c)
			for x in [18, 62, 112, 160]:
				pillar(x + rng.randf_range(-6, 6), rng.randf_range(20, 26), rng.randf_range(12, 20), ruin, Color("#3f8f5e"))
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.3: pillar(x, y, rng.randf_range(7, 13), ruin, Color("#3f8f5e"))
				elif r < 0.55:
					pool(x, y, rng.randf_range(7, 10), rng.randf_range(4, 5), [Color("#2f86a8"), Color("#4fb0c8"), Color("#c6eef5")], Color("#b09868"))
					reeds(x + 3, y + 1, 3, Color("#2e7a5a"))
				elif r < 0.75: rock(x, y, rng.randf_range(3, 5), ruin, Color("#4fa070"))
				else:
					for k in 3:
						var cx = x + rng.randf_range(-5, 5)
						var cy = y + rng.randf_range(-3, 3)
						px(cx, cy, Color("#f6a6c1")); px(cx + 1, cy, Color("#ffd4e2")); px(cx, cy - 1, Color("#f08aa8")), 30.0)
			_scatter(50, func(x, y):
				var c = [Color("#ffd4e2"), Color("#f8f0e0"), Color("#e8a070")][rng.randi_range(0, 2)]
				px(x, y, c); px(x + 1, y, c.darkened(0.2)))
		"steamvent_marsh":
			ground([Color("#4a5a3a"), Color("#546644"), Color("#5f724c")], 7.0)
			patches(18, Color("#5a4e34"), 5, 11)
			patches(10, Color("#627a50"), 5, 10)
			specks(280, [Color("#6f8a58"), Color("#3e4a30")])
			var hot_water = [Color("#2f6a6a"), Color("#4a9080"), Color("#b8e8d4")]
			treeline([Color("#2a3a2a"), Color("#3a4e3a"), Color("#4e6450"), Color("#6a8068")], 14, 12)
			mist(0, 40, Color("#e8f0ec"), 0.45)
			for side in [0, 1]:
				for k in 3:
					var x = edge_x(side)
					var y = 70 + k * 85 + rng.randf_range(-10, 10)
					glow(x, y, 16, Color("#ffb347"), 0.2)
					pool(x, y, rng.randf_range(9, 12), rng.randf_range(5, 7), hot_water, Color("#7a5a3a"))
					steam(x - 2, y - 4); steam(x + 4, y - 3)
					reeds(x + rng.randf_range(-8, 8), y + 6, 5, Color("#4a6a3a"), Color("#6a3a1a"))
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.35: reeds(x, y, 7, Color("#4a6a3a"), Color("#6a3a1a"))
				elif r < 0.6:
					glow(x, y - 2, 7, LAVA[1], 0.35)
					rock(x, y, 3.5, [Color("#2a2420"), Color("#4a3e34"), Color("#6a5a4a"), Color("#8a7a68")])
					steam(x, y - 5)
				elif r < 0.8:
					patch(x, y, 4, Color("#5a4630"), 1.6)
					for k in 3: px(x + rng.randf_range(-4, 4), y + rng.randf_range(-2, 2), Color("#8a7050"))
				else: dead_tree(x, y, 11, Color("#3a3024")), 30.0)
			_scatter(40, func(x, y): px(x, y, Color("#8a7050")), 0.4)
			_scatter(8, func(x, y): steam(x, y), 0.6)
		"frostshade_barrows":
			ground([Color("#5f6a8c"), Color("#6c789a"), Color("#7a86a8")], 8.0)
			patches(16, Color("#8e9abc"), 5, 12)
			patches(10, Color("#56607f"), 6, 12)
			specks(200, [Color("#a8b4d4"), Color("#4a5474")], 36, 0.0)
			var hill = [Color("#2e3450"), Color("#3e4666"), Color("#525c80"), Color("#a8b4d4")]
			# Two rows of frosted burial mounds against a dusky sky.
			for x in W:
				var back = 8 + 5 * sin(x * 0.06 + 1.0) + 2 * sin(x * 0.23)
				var front = 20 + 4 * sin(x * 0.09 + 2.5) + 2 * sin(x * 0.31)
				for y in range(0, 36):
					var c: Color = Color("#161a2c") if bayer(x, y) > float(y) / 10.0 else Color("#1e2238")
					if y >= back: c = hill[0] if y > back + 1 or bayer(x, y) < 0.5 else hill[1]
					if y >= front:
						c = hill[1] if bayer(x, y) > (y - front) / 14.0 else hill[2]
						if y < front + 1.5 + bayer(x, 0): c = hill[3]
					if y >= 33 and bayer(x, y) < (y - 33) / 3.0: continue
					px(x, y, c)
			for x in [28, 80, 126, 162]:
				tomb(x + rng.randf_range(-6, 6), rng.randf_range(23, 28), hill, Color("#e8f0ff"))
			var stone = [Color("#3a3e56"), Color("#545a76"), Color("#727a96"), Color("#9aa2bc")]
			var ice = [Color("#5b7ae8"), Color("#9fb8f5"), Color("#c6d8ff"), Color.WHITE]
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.35: tomb(x, y, stone, Color("#e8f0ff"))
				elif r < 0.55: dead_tree(x, y, rng.randf_range(10, 14), Color("#262a3a"))
				elif r < 0.75: crystals(x, y, rng.randf_range(3, 4), ice, Color("#9fddf5"))
				elif r < 0.9:
					glow(x, y, 9, Color("#9fddf5"), 0.4)
					px(x, y, Color("#e8f8ff")); px(x, y - 1, Color("#c6eeff")); px(x + 1, y - 2, Color("#9fddf5"))
				else: rock(x, y, rng.randf_range(3, 5), stone, Color("#c6d8ff")), 28.0)
			_scatter(30, func(x, y):
				glow(x, y, 3, Color("#9fddf5"), 0.3)
				px(x, y, Color("#e8f8ff")), 0.3)
			_scatter(8, func(x, y): bones(x, y), 0.4)
		"blighted_heartwood":
			ground([Color("#3e3340"), Color("#48394a"), Color("#534254")], 9.0)
			patches(16, Color("#5a6440"), 4, 9)
			patches(12, Color("#5e4470"), 5, 10)
			specks(280, [Color("#6a5a4a"), Color("#7a6a3a"), Color("#2e2430"), Color("#7a5a9a")])
			var rot = [Color("#1e1418"), Color("#3a2a26"), Color("#54403a"), Color("#6e5648")]
			for x in W:
				for y in range(0, 26):
					var trunk = sin(x * 0.09 + 0.6) > 0.35
					var c = rot[1] if trunk else Color("#1e1a24")
					if trunk and sin(x * 0.9) > 0.6: c = rot[2]
					if y > 18 + 3 * sin(x * 0.3): c = rot[0]
					px(x, y, c)
			treeline([Color("#1e1a24"), Color("#2e2438"), Color("#46345a"), Color("#6a4a7a")], 8, 10)
			var roots = [Color("#2a1a18"), Color("#4a3428"), Color("#6a4c3a")]
			root(-4, 60, 34, 100, 4.0, roots); root(184, 120, 146, 160, 4.0, roots)
			root(-4, 230, 30, 262, 3.5, roots); root(184, 40, 150, 70, 3.0, roots)
			var fungus = [Color("#4a6a1a"), Color("#8ac040"), Color("#d4f08a")]
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.35: mushrooms(x, y, fungus, Color("#b6ec8a"))
				elif r < 0.55: log_prop(x, y, rng.randf_range(12, 16), rot, Color("#7a5a9a"))
				elif r < 0.75: bush(x, y, rng.randf_range(5, 7), [Color("#2e2438"), Color("#46345a"), Color("#6a4a7a"), Color("#9a7ab0")], [Color("#c8a2ff")])
				else: dead_tree(x, y, rng.randf_range(10, 14), Color("#2a2024")), 28.0)
			_scatter(40, func(x, y):
				glow(x, y, 3, Color("#b6ec8a"), 0.3)
				px(x, y, Color("#d4f08a")), 0.3)
			_scatter(50, func(x, y): px(x, y, [Color("#8a5a3a"), Color("#a8703a")][rng.randi_range(0, 1)]))
		"mossmire_fen":
			ground([Color("#3f7044"), Color("#4a7c4c"), Color("#558856")], 10.0)
			patches(16, Color("#4a5a3a"), 5, 10)
			patches(14, Color("#62985c"), 5, 10)
			specks(380, [Color("#6aaa62"), Color("#2e5a34")])
			var willow = [Color("#1f4a32"), Color("#2e6a40"), Color("#4a8a50"), Color("#7ab070")]
			treeline(willow, 12, 14)
			for x in W:
				if bayer(x, 0) > 0.6:
					var len_ = int(6 + 5 * absf(sin(x * 0.37)))
					for y in range(14, 14 + len_):
						px(x, y, willow[2] if y % 3 else willow[3])
			for side in [0, 1]:
				for k in 3:
					var x = edge_x(side)
					var y = 75 + k * 80 + rng.randf_range(-10, 10)
					pool(x, y, rng.randf_range(10, 13), rng.randf_range(5, 7), [Color("#1f4a5a"), Color("#2f6a72"), Color("#8ac4b8")], Color("#3a5a34"))
					for j in 3: lilypad(x + rng.randf_range(-7, 7), y + rng.randf_range(-3, 3), 2.0, rng.randf() < 0.4)
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.35: reeds(x, y, 7, Color("#2e6a3a"), Color("#6a3a1a"))
				elif r < 0.55: log_prop(x, y, rng.randf_range(12, 16), BARK, Color("#7ab070"))
				elif r < 0.75: mushrooms(x, y, [Color("#8a6a2a"), Color("#c8a040"), Color("#f0d890")])
				else: fern(x, y, [Color("#1f4a32"), Color("#2e6a40"), Color("#7ab070")]), 30.0)
			_scatter(30, func(x, y):
				glow(x, y, 3, Color("#f4ff9a"), 0.35)
				px(x, y, Color("#f4ff9a")), 0.2)
			_scatter(60, func(x, y): px(x, y, [Color("#fff1a8"), Color.WHITE, Color("#9fd6f5")][rng.randi_range(0, 2)]))
		"cinderfrost_peak":
			ground([Color("#5a5560"), Color("#66616c"), Color("#736e7a")], 11.0)
			for k in 7:
				var x = rng.randf_range(0, W * 0.6)
				patch(x, rng.randf_range(40, H), rng.randf_range(4, 7), Color("#d8eaf4") if rng.randf() < 0.7 else Color("#c6deec"), 1.6, 0.45)
			for k in 10:
				crack(rng.randf_range(W * 0.45, W), rng.randf_range(50, H - 10), rng.randi_range(10, 20), Color("#c8321e"), LAVA[1], 0.2)
			specks(120, [Color("#85808c"), Color("#4a4550")], 36, 0.0)
			var rockp = [Color("#3a3640"), Color("#55505c"), Color("#757080"), Color("#9a96a4")]
			# Peaks under one hazy sky: snowcapped toward the left, smouldering toward the right.
			var top_at = func(x): return 3 + 17 * absf(sin(x * 0.045 + 0.4)) + 3 * sin(x * 0.3)
			for x in W:
				var top = top_at.call(x)
				var lit = sin(2.0 * (x * 0.045 + 0.4)) < 0.0  # whole faces turned to the light, upper right
				var cold = clampf(1.0 - (x - 60.0) / 70.0, 0.0, 1.0)
				for y in range(0, 38):
					if y < top:
						px(x, y, Color("#2a2636") if bayer(x, y) > float(y) / 16.0 else Color("#342e42"))
						continue
					var depth = y - top
					var c: Color = (rockp[2] if bayer(x, y) > 0.35 else rockp[3]) if lit else (rockp[0] if bayer(x, y) > 0.6 else rockp[1])
					if depth < 5 + 3 * cold and bayer(x, y + 1) < cold * 1.3 - depth * 0.08:
						c = Color("#eef6fa") if lit else Color("#b4cce0")
					if y >= 33 and bayer(x, y) < (y - 33) / 5.0: continue
					px(x, y, c)
			glow(150, 20, 18, LAVA[1], 0.35)
			fall(148, 32, LAVA, 3)
			var ice = [Color("#5ba4e8"), Color("#9fddf5"), Color("#c6eeff"), Color.WHITE]
			_sides(func(side, x, y):
				var r = rng.randf()
				if side == 0:
					if r < 0.45: crystals(x, y, rng.randf_range(3, 4.5), ice, Color("#c6eeff"))
					else: rock(x, y, rng.randf_range(3, 5), rockp, Color("#eef6fa"))
				else:
					if r < 0.4: pool(x, y, rng.randf_range(7, 10), rng.randf_range(4, 6), LAVA, Color("#3a3640"), true)
					elif r < 0.7:
						glow(x, y - 2, 8, LAVA[1], 0.4)
						rock(x, y, 3.5, rockp)
					else: rock(x, y, rng.randf_range(3, 5), rockp), 30.0)
			_scatter(20, func(x, y): px(x, y, Color.WHITE if x < W / 2 else LAVA[2]), 0.3)
		"cindergloom_wastes":
			ground([Color("#3a3236"), Color("#453b40"), Color("#51464c")], 12.0)
			patches(8, Color("#5a5054"), 6, 12)
			patches(6, Color("#3e2a34"), 5, 10)
			for k in 12:
				var x = rng.randf_range(0, W)
				var y = rng.randf_range(44, H)
				var a = rng.randf_range(0, TAU)
				for j in rng.randi_range(4, 8):
					px(x + cos(a) * j, y + sin(a) * j * 0.6, Color("#2a2226"))
			for k in 9:
				crack(rng.randf_range(0, W), rng.randf_range(50, H - 10), rng.randi_range(10, 20), Color("#a8281a"), Color("#c8321e"), 0.18)
			specks(90, [Color("#6a5e64"), Color("#2a2226"), Color("#7a3a2a")], 36, 0.0)
			var ridge = [Color("#1e161c"), Color("#2e2228"), Color("#45343c"), Color("#5e4a54")]
			for x in W:
				for y in range(0, 10):
					px(x, y, Color("#3a2440") if bayer(x, y) > float(y) / 10.0 else Color("#4a2a3a"))
			cliffs(ridge, 22)
			for k in 3:
				var sx = 30 + k * 60 + rng.randf_range(-10, 10)
				glow(sx, 10, 10, Color("#c8321e"), 0.4)
				for j in 8: tint(sx + sin(j) * 2, 10 - j, Color("#8a8088"), 0.5)
			var crys = [Color("#3a1f5a"), Color("#6a3fa0"), Color("#a77ce0"), Color("#e8d8ff")]
			_sides(func(side, x, y):
				var r = rng.randf()
				if r < 0.3: dead_tree(x, y, rng.randf_range(10, 14), Color("#1e161a"))
				elif r < 0.5: crystals(x, y, rng.randf_range(3, 4), crys, Color("#a77ce0"))
				elif r < 0.7:
					glow(x, y - 2, 8, LAVA[1], 0.35)
					rock(x, y, 3.5, ridge)
				elif r < 0.85: bones(x, y)
				else: rock(x, y, rng.randf_range(3, 5), ridge), 30.0)
			_scatter(25, func(x, y): px(x, y, LAVA[1] if rng.randf() < 0.6 else Color("#c8a2ff")), 0.3)
			_scatter(10, func(x, y): bones(x, y), 0.5)

# A small touch just inside the side props: tufts, pebbles, flowers and the like.
func accent(id: String, x, y):
	var r = rng.randf()
	var pebble = [Color("#7a7a80"), Color("#9a9aa0"), Color("#c0c0c4"), Color("#e0e0e4")]
	match id:
		"sunny_meadow":
			if r < 0.4: tuft(x, y, Color("#3f8738"))
			elif r < 0.8: flower(x, y, FLOWERS[rng.randi_range(0, 4)])
			else: rock(x, y, 1.8, STONE)
		"whispering_spring":
			if r < 0.45: tuft(x, y, Color("#2e7a4a"))
			elif r < 0.75: flower(x, y, [Color("#9fd6f5"), Color.WHITE][rng.randi_range(0, 1)], Color("#2e7a4a"))
			else: rock(x, y, 1.8, [Color("#3c5a6a"), Color("#56788a"), Color("#7898a8"), Color("#a8c4d0")])
		"ember_vent", "cindergloom_wastes":
			if r < 0.5: rock(x, y, rng.randf_range(1.5, 2.5), [Color("#2a1a16"), Color("#3e2620"), Color("#5a3a2e"), Color("#7a5444")])
			else:
				glow(x, y, 3, LAVA[1], 0.3)
				px(x, y, LAVA[2])
		"frostbite_hollow":
			if r < 0.5: crystals(x, y, 1.4, [Color("#5ba4e8"), Color("#9fddf5"), Color("#c6eeff"), Color.WHITE])
			else: tuft(x, y, Color("#a9c8dc"))
		"gloomroot_cavern":
			if r < 0.5: mushroom(x, y, 1.5, [Color("#1f6a6a"), Color("#3fb0a0"), Color("#9ff0e0")], Color("#3fb0a0"))
			else: rock(x, y, 1.8, [Color("#1c1624"), Color("#2a2034"), Color("#3a2e48"), Color("#4c3e5c")])
		"brambleheart_thicket":
			if r < 0.5: tuft(x, y, Color("#2e4a22"))
			elif r < 0.8: px(x, y, Color("#c8321e")); px(x + 1, y - 1, Color("#8a1a2a"))
			else: mushroom(x, y, 1.6, [Color("#8a3a1a"), Color("#c8642d"), Color("#ffb347")])
		"sunken_lagoon":
			if r < 0.5: px(x, y, Color("#ffd4e2")); px(x + 1, y, Color("#f8f0e0"))
			else: rock(x, y, 1.8, [Color("#5a6a6e"), Color("#7a8a8a"), Color("#9aa8a4"), Color("#c0ccc4")])
		"steamvent_marsh", "mossmire_fen":
			if r < 0.5: reeds(x, y, 2, Color("#3a6a3a"), Color("#6a3a1a"))
			elif r < 0.8: tuft(x, y, Color("#3a5a34"))
			else: px(x, y, Color("#fff1a8"))
		"frostshade_barrows":
			if r < 0.5: tuft(x, y, Color("#a8b4d4"))
			else: rock(x, y, 1.8, [Color("#3a3e56"), Color("#545a76"), Color("#727a96"), Color("#9aa2bc")])
		"blighted_heartwood":
			if r < 0.5: mushroom(x, y, 1.5, [Color("#4a6a1a"), Color("#8ac040"), Color("#d4f08a")], Color("#b6ec8a"))
			else: px(x, y, Color("#a8703a")); px(x + 1, y, Color("#8a5a3a"))
		"cinderfrost_peak":
			if x < W / 2: crystals(x, y, 1.4, [Color("#5ba4e8"), Color("#9fddf5"), Color("#c6eeff"), Color.WHITE])
			else: rock(x, y, 1.8, pebble)

# Calls `draw(side, x, y)` at spots down both sides, about `step` apart.
func _sides(draw: Callable, step: float):
	for side in [0, 1]:
		var y = 44.0 + rng.randf_range(0, step * 0.5)
		while y < H - 6:
			draw.call(side, edge_x(side), y)
			y += rng.randf_range(step * 0.75, step * 1.25)

# Calls `draw(x, y)` at `n` random spots, thinning out toward the middle:
# `mid` is how likely a spot in the very centre is kept (1 at the sides).
func _scatter(n: int, draw: Callable, mid := 0.25):
	for i in n:
		var x = rng.randi_range(3, W - 4)
		var y = rng.randi_range(40, H - 3)
		if rng.randf() > mid + edginess(x) * (1.0 - mid):
			continue
		draw.call(x, y)

func run(api, image, project, params):
	var sheet = Image.create(W * LANDS.size(), H, false, Image.FORMAT_RGBA8)
	for i in LANDS.size():
		img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		rng.seed = 77 + i * 101
		land(LANDS[i])
		var quiet = LANDS[i] in ["cinderfrost_peak", "cindergloom_wastes"]  # busy enough already
		_scatter(45 if quiet else 90, func(x, y): accent(LANDS[i], x, y), 0.12)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	return sheet
