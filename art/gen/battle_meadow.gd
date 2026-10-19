# Sunny Meadow battlefield, 180x320 (shown at about 4x, covering the screen).
# Enemies come from the top, your squad holds the bottom. The middle stays
# calm so the fighters read; the edges carry bushes, flowers and a treeline.
var img: Image
const W := 180
const H := 320
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a")]

func px(x, y, c):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func noise(x: float, y: float) -> float:
	return 0.5 * sin(x * 0.21 + sin(y * 0.13) * 2.0) + 0.3 * sin(y * 0.17 + x * 0.05) + 0.2 * sin((x + y) * 0.41)

func shade(n: Vector2, x, y, pal: Array) -> Color:
	var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
	return pal[3] if t > 0.45 else (pal[2] if t > 0.05 else (pal[1] if t > -0.45 else pal[0]))

func blob(cx: float, cy: float, rx: float, ry: float, pal: Array, lumpy := 0.0):
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var n = Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0 + lumpy * sin(atan2(n.y, n.x) * 6.0 + cx):
				px(x, y, shade(n, x, y, pal))

func outline_dark(r: Rect2i, ref: Image):
	# darken grass pixels just outside the shapes drawn since `ref`
	var after = img.duplicate()
	for y in range(maxi(r.position.y, 0), mini(r.end.y, H)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, W)):
			if after.get_pixel(x, y) != ref.get_pixel(x, y):
				continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and after.get_pixel(q.x, q.y) != ref.get_pixel(q.x, q.y):
					img.set_pixel(x, y, after.get_pixel(q.x, q.y).darkened(0.72))
					break

func bush(cx, cy, r):
	var ref = img.duplicate()
	for y in range(int(cy) - 1, int(cy + r * 0.8) + 2):
		for x in range(int(cx - r * 1.3), int(cx + r * 1.3) + 1):
			if pow((x - cx) / (r * 1.3), 2) + pow((y - cy - r * 0.6) / 2.0, 2) <= 1.0:
				px(x, y, img.get_pixel(clampi(x, 0, W - 1), clampi(y, 0, H - 1)).darkened(0.25))
	blob(cx - r * 0.5, cy, r * 0.8, r * 0.7, LEAF.slice(1, 5), 0.08)
	blob(cx + r * 0.5, cy + 0.5, r * 0.75, r * 0.65, LEAF.slice(1, 5), 0.08)
	blob(cx, cy - r * 0.35, r * 0.85, r * 0.75, LEAF.slice(1, 5), 0.08)
	outline_dark(Rect2i(int(cx - r * 2), int(cy - r * 2), int(r * 4) + 2, int(r * 3) + 2), ref)

func flower(x, y, c):
	px(x, y + 1, LEAF[1])
	px(x, y, Color("#ffd166")); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c)

func run(api, image, project, params):
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	# grass with a gentle, noisy texture
	for y in H:
		for x in W:
			var c = Color("#56a646")
			var v = noise(x * 1.9, y * 1.9) + (bayer(x, y) - 0.5) * 0.5
			if v > 0.72: c = Color("#5fb04c")
			elif v < -0.72: c = Color("#4c9a40")
			px(x, y, c)
	# soft clover patches
	for i in 26:
		var cx = rng.randf_range(0, W)
		var cy = rng.randf_range(30, H)
		var r = rng.randf_range(4, 9)
		for y in range(int(cy - r) - 2, int(cy + r) + 2):
			for x in range(int(cx - r * 1.4) - 2, int(cx + r * 1.4) + 2):
				if pow((x - cx) / (r * 1.4), 2) + pow((y - cy) / r, 2) + noise(x * 3.0, y * 3.0) * 0.3 <= 1.0:
					px(x, y, Color("#4f9e42"))
		for k in int(r):
			px(int(cx + rng.randf_range(-r, r)), int(cy + rng.randf_range(-r * 0.7, r * 0.7)), Color("#e8f4d8"))
	for i in 420:
		var x = rng.randi_range(0, W - 1)
		var y = rng.randi_range(24, H - 1)
		var c = Color("#72c25a") if rng.randf() < 0.6 else Color("#3f8738")
		px(x, y, c)
		if rng.randf() < 0.5:
			px(x, y - 1, c.lightened(0.08))
	# a distant treeline along the enemy edge
	for x in W:
		var top = int(10 + 4 * sin(x * 0.19) + 3 * sin(x * 0.47 + 1.0))
		for y in range(0, top + 6):
			var c = Color("#2e6b34") if y < top else Color("#3f8738")
			if y < top and bayer(x, y) > 0.8: c = Color("#3f8f3a")
			px(x, y, c)
	for i in 14:
		blob(rng.randf_range(0, W), rng.randf_range(4, 12), rng.randf_range(6, 10), rng.randf_range(5, 8), [LEAF[0], LEAF[1], LEAF[2], LEAF[3]], 0.08)
	for x in W:
		var y = int(16 + 3 * sin(x * 0.23))
		if bayer(x, y) > 0.3:
			px(x, y, Color("#2a5a2a"))
	# bushes and flower beds along both sides, clear of the lanes
	for side in [0, 1]:
		var y = 40.0
		while y < H - 10:
			var x = rng.randf_range(4, 14) if side == 0 else rng.randf_range(166, 176)
			if rng.randf() < 0.55:
				bush(x, y, rng.randf_range(5, 8))
			else:
				for k in rng.randi_range(4, 8):
					flower(int(x + rng.randf_range(-6, 6)), int(y + rng.randf_range(-5, 5)), [Color("#fff1a8"), Color.WHITE, Color("#f6a6c1"), Color("#c8a2ff")][rng.randi_range(0, 3)])
			y += rng.randf_range(22, 36)
	# scattered wildflowers, sparse in the middle
	for i in 140:
		var x = rng.randi_range(2, W - 3)
		var y = rng.randi_range(24, H - 2)
		var edge = absf(x - W / 2.0) / (W / 2.0)
		if rng.randf() > 0.25 + edge * 0.75:
			continue
		var c = [Color("#fff1a8"), Color.WHITE, Color("#f6a6c1"), Color("#ffb36b")][rng.randi_range(0, 3)]
		if rng.randf() < 0.5:
			px(x, y, c)
		else:
			flower(x, y, c)
	# a few pebbles
	for i in 10:
		var x = rng.randi_range(4, W - 5)
		var y = rng.randi_range(30, H - 4)
		px(x, y, Color("#b7b2a3")); px(x + 1, y, Color("#8f8a7c")); px(x, y - 1, Color("#d6d2c4"))
	return img
