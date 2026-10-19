# Grove effects sheet (180x64): falling leaf frames, two clouds, foreground grass.
var img: Image
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

# 8x8 leaf frames: a leaf tumbling (flat, tilted, edge-on, flipped).
const LEAF_FRAMES := [
	["........", "......11", "....1341", "..13441.", ".1344 1.", ".1341...", "1.11....", "........"],
	["........", "...11...", "..1341..", "..1341..", "..1331..", "..1321..", "...11...", "....1..."],
	["........", "........", ".......1", "..11111.", ".133331.", "..1111..", "1.......", "........"],
	["........", "11......", "1431....", ".14431..", ".1 4431.", "...1431.", "....11.1", "........"],
]

func draw_leaf_frames():
	for f in 4:
		var rows: Array = LEAF_FRAMES[f]
		for y in 8:
			for x in 8:
				var ch = rows[y][x]
				var c = null
				match ch:
					"1": c = LEAF[0]
					"2": c = LEAF[2]
					"3": c = LEAF[3]
					"4": c = LEAF[4]
					" ": c = LEAF[3]
				if c != null:
					px(f * 8 + x, y, c)

func cloud(ox, oy, w, h, puffs: Array):
	var inside = {}
	for y in range(oy, oy + h):
		for x in range(ox, ox + w):
			for p in puffs:
				var c = Vector2(ox + p[0], oy + p[1])
				if Vector2(x, y).distance_to(c) <= p[2] and y <= oy + h - 2:
					inside[Vector2i(x, y)] = c
	for k in inside:
		var c: Vector2 = inside[k]
		var col = Color("#ffffff")
		var below = (k.y - (oy + h - 2))
		if k.y > oy + h - 5:
			col = Color("#e3f1fb") if bayer(k.x, k.y) > 0.4 or k.y > oy + h - 4 else col
		if k.y >= oy + h - 3:
			col = Color("#c9e3f5")
		px(k.x, k.y, col)

func grass(oy, h):
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	var cols = [Color("#2a5e2b"), Color("#357631"), Color("#3f8738"), Color("#4c9a40")]
	# dense base
	for x in 180:
		for y in range(oy + h - 5, oy + h):
			px(x, y, cols[1] if bayer(x, y) > 0.5 else cols[0])
	# blades
	for i in 120:
		var x = rng.randi_range(0, 179)
		var bh = rng.randi_range(3, h - 4)
		var lean = rng.randf_range(-0.35, 0.35)
		var c = cols[rng.randi_range(1, 3)]
		for j in bh:
			var yy = oy + h - 1 - j
			var xx = int(round(x + lean * j * j / float(bh)))
			px(xx, yy, c if j < bh - 1 else c.lightened(0.15))
			if j < bh / 2:
				px(xx + 1, yy, c.darkened(0.15))
	# a few flowers poking up
	var fl = [Color("#fff1a8"), Color("#f6a6c1"), Color("#ffffff")]
	for i in 7:
		var x = rng.randi_range(4, 175)
		var top = oy + rng.randi_range(2, 6)
		for yy in range(top + 1, oy + h - 3):
			px(x, yy, cols[2])
		var c = fl[i % 3]
		px(x, top, Color("#ffd166")); px(x - 1, top, c); px(x + 1, top, c); px(x, top - 1, c); px(x, top + 1, c)

func run(api, image, project, params):
	img = Image.create(180, 64, false, Image.FORMAT_RGBA8)
	draw_leaf_frames()
	cloud(0, 12, 52, 18, [[12, 11, 7], [24, 8, 9], [36, 10, 7], [45, 13, 5], [6, 14, 5], [30, 14, 6]])
	cloud(60, 14, 36, 14, [[9, 9, 6], [19, 6, 7], [28, 9, 5], [14, 11, 5]])
	grass(44, 20)
	return img
