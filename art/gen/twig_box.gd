# Root box art for the Barracks: three tiers of summoning box. Sheet 96x96,
# one row of 32 px per tier: body 40x26 at (0, row) and lid 44x14 at (48, row).
# In the game the lid sits on top, with the body 2 px in and 12 px down. The
# body has a round sap window (radius 5, centred at 21,15 in the saved body
# image) that the game fills.
# Tier 1 Root Box: woven twigs tied with vine. Tier 2 Bark Box: bark planks
# bound with amber resin. Tier 3 Heartwood Box: red heartwood trimmed in gold.
var img: Image
var shift := Vector2i.ZERO  # added to every put(), so the body's outline has room on the left
const BARK := [Color("#2e1a0e"), Color("#5e3a20"), Color("#8a5530"), Color("#b07a45")]
const WOOD := [Color("#6e5032"), Color("#a07c4c"), Color("#b8945e"), Color("#d6b27a")]
const MOSS := [Color("#2d4a1f"), Color("#4a6e2a"), Color("#78a040"), Color("#b2d36a")]
const HEART := [Color("#3e1610"), Color("#6e2a1a"), Color("#9a4026"), Color("#c4643a")]
const GOLD := [Color("#7a5414"), Color("#c08a24"), Color("#ffd447"), Color("#fff6b0")]
const AMBER := [Color("#8a4a12"), Color("#e08a22"), Color("#ffb347"), Color("#fff0b0")]
const GLASS := Color("#1c120a")
const WINDOW := Vector2i(20, 14)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func put(x, y, c: Color):
	x += shift.x
	y += shift.y
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func ramp(cols: Array, v: float, x: int, y: int) -> Color:
	var f = clampf(v, 0.0, 0.999) * (cols.size() - 1)
	var i = int(f)
	return cols[mini(i + 1, cols.size() - 1)] if f - i > bayer(x, y) else cols[i]

func outline(r: Rect2i):
	var src = img.duplicate()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if r.has_point(q) and src.get_pixel(q.x, q.y).a > 0.5:
					var col = src.get_pixel(q.x, q.y).darkened(0.72)
					col.a = 1.0
					img.set_pixel(x, y, col)
					break

# The sap window: a dark glass disc in a rim of `rim` colours (dark, light).
func window(ox, oy, rim: Array):
	for y in range(-6, 7):
		for x in range(-6, 7):
			var d = Vector2(x + 0.5, y + 0.5).length()
			var p = Vector2i(ox + WINDOW.x + x, oy + WINDOW.y + y)
			if d <= 5.0:
				put(p.x, p.y, GLASS)
			elif d <= 6.4:
				put(p.x, p.y, rim[1] if x + 0.5 > 0 and y + 0.5 < 0 else rim[0])
	# a glint on the glass
	put(ox + WINDOW.x + 2, oy + WINDOW.y - 3, Color(1, 1, 1, 0.55))
	put(ox + WINDOW.x + 3, oy + WINDOW.y - 2, Color(1, 1, 1, 0.35))

func leaf(x, y, flip := false):
	var s = -1 if flip else 1
	put(x, y, MOSS[2]); put(x + s, y, MOSS[3]); put(x + s, y - 1, MOSS[2]); put(x + 2 * s, y - 1, MOSS[1])

# --- Tier 1: woven twigs -------------------------------------------------------

func twig_body(oy):
	# Five horizontal twig bands between two upright posts.
	for band in 5:
		var y0 = 1 + band * 5
		for y in range(y0, y0 + 5):
			for x in range(3, 37):
				var v = 1.0 - absf(y - y0 - 2.0) / 2.6
				v += 0.12 * sin(x * 0.9 + band * 2.0)
				if (x + band * 3) % 11 == 0: v -= 0.35  # a knot
				put(x, oy + y, ramp(WOOD, clampf(v * 0.85 + 0.1, 0, 1), x, y))
			if y == y0 + 4:
				for x in range(3, 37):
					put(x, oy + y, WOOD[0])
	for post in [0, 35]:
		for y in range(0, 26):
			for x in range(post, post + 5):
				var v = 1.0 - absf(x - post - 2.0) / 2.5
				put(x, oy + y, ramp(BARK, v * 0.9 + 0.1, x, y))
		put(post + 2, oy + 0, WOOD[3]); put(post + 1, oy + 0, WOOD[2]); put(post + 3, oy + 0, WOOD[1])
	# A vine tied across the front, with leaves.
	for x in range(5, 35):
		var y = int(round(18 + 3.0 * sin(x * 0.35)))
		put(x, oy + y, MOSS[1]); put(x, oy + y - 1, MOSS[2])
	for p in [[9, 16], [17, 22], [27, 15], [32, 20]]:
		leaf(p[0], oy + p[1], p[0] > 20)
	window(0, oy, [BARK[1], WOOD[3]])
	outline(Rect2i(0, oy - 2, 44, 30))

func twig_lid(ox, oy):
	for y in range(3, 13):
		for x in range(1, 43):
			var v = 0.55 + 0.4 * (1.0 - (y - 3) / 9.0) * (0.6 + 0.4 * x / 42.0)
			if y >= 10: v = 0.2
			if (y - 3) % 4 == 3: v -= 0.4
			put(ox + x, oy + y, ramp(WOOD, clampf(v, 0, 1), x, y))
	# A bent twig handle on top.
	for p in [[17, 3], [17, 2], [18, 1], [19, 0], [20, 0], [21, 0], [22, 0], [23, 0], [24, 0], [25, 1], [26, 2], [26, 3]]:
		put(ox + p[0], oy + p[1], BARK[2])
	put(ox + 21, oy + 0, BARK[3]); put(ox + 22, oy + 0, BARK[3])
	leaf(ox + 27, oy + 3)
	outline(Rect2i(ox - 1, oy - 1, 46, 16))

# --- Tier 2: bark planks bound with resin ---------------------------------------

func bark_body(oy):
	for y in range(0, 26):
		for x in range(1, 39):
			var plank = (x - 1) / 6
			var px = (x - 1) % 6
			var v = 0.45 + 0.25 * sin(y * 0.8 + plank * 1.7) * 0.5 + 0.2 * (x / 38.0)
			if px == 0: v = 0.05
			if px == 5: v -= 0.15
			if (y * 3 + plank * 5) % 13 == 0: v -= 0.25
			put(x, oy + y, ramp(BARK, clampf(v, 0, 1), x, y))
	# Two amber resin bands with clasps.
	for band_y in [4, 21]:
		for y in range(band_y, band_y + 3):
			for x in range(1, 39):
				var v = 0.85 if y == band_y else (0.55 if y == band_y + 1 else 0.25)
				put(x, oy + y, ramp(AMBER, v, x, y))
		for cx in [4, 35]:
			for d in [[-1, -1], [0, -1], [-1, 0], [0, 0], [-1, 1], [0, 1], [1, 0], [-2, 0]]:
				put(cx + d[0], oy + band_y + 1 + d[1], GOLD[1])
			put(cx, oy + band_y, GOLD[3])
	# Moss creeping up from the bottom corner.
	for x in range(1, 12):
		for y in range(23, 26):
			if bayer(x, y) < 0.7 - x * 0.05:
				put(x, oy + y, MOSS[1 if y > 23 else 2])
	window(0, oy, [AMBER[0], AMBER[3]])
	outline(Rect2i(0, oy - 2, 44, 30))

func bark_lid(ox, oy):
	for y in range(2, 13):
		for x in range(0, 44):
			var v = 0.65 - (y - 2) * 0.04 + 0.2 * x / 44.0 + 0.1 * sin(x * 1.3)
			if y >= 10: v = 0.15
			put(ox + x, oy + y, ramp(BARK, clampf(v, 0, 1), x, y))
	for x in range(0, 44):
		put(ox + x, oy + 10, AMBER[1]); put(ox + x, oy + 11, AMBER[0])
	# Moss along the top, a fern sprig and a resin knob in the middle.
	for x in range(2, 42):
		if bayer(x, 1) < 0.55 + 0.3 * sin(x * 0.4):
			put(ox + x, oy + 1, MOSS[2])
			put(ox + x, oy + 2, MOSS[1])
	for p in [[20, 0], [21, 0], [22, 0], [23, 0], [19, 1], [24, 1]]:
		put(ox + p[0], oy + p[1], AMBER[2])
	put(ox + 21, oy + 0, AMBER[3])
	leaf(ox + 8, oy + 1)
	leaf(ox + 36, oy + 1, true)
	outline(Rect2i(ox - 1, oy - 1, 46, 16))

# --- Tier 3: heartwood with gold trim --------------------------------------------

func heart_body(oy):
	for y in range(0, 26):
		for x in range(1, 39):
			# Grain rings curving around the centre.
			var r = Vector2((x - 20) * 0.5, y - 14).length()
			var v = 0.45 + 0.18 * sin(r * 1.4) + 0.25 * (x / 38.0) - 0.15 * (y / 26.0)
			put(x, oy + y, ramp(HEART, clampf(v, 0, 1), x, y))
	# Gold frame and corner caps.
	for x in range(1, 39):
		for y in [0, 1, 24, 25]:
			put(x, oy + y, GOLD[2] if y == 0 or y == 24 else GOLD[1])
	for y in range(0, 26):
		for x in [1, 2, 37, 38]:
			put(x, oy + y, GOLD[2] if x == 2 or x == 38 else GOLD[1])
	for c in [[3, 3], [36, 3], [3, 22], [36, 22]]:
		put(c[0], oy + c[1], GOLD[3])
	# Leaf filigree either side of the window.
	for s in [-1, 1]:
		for i in 7:
			put(20 + s * (8 + i), oy + 14 + int(round(sin(i * 0.9) * 2.0)), GOLD[1])
		put(20 + s * 10, oy + 11, MOSS[3]); put(20 + s * 11, oy + 11, MOSS[2]); put(20 + s * 13, oy + 17, MOSS[2])
	window(0, oy, [GOLD[0], GOLD[3]])
	outline(Rect2i(0, oy - 2, 44, 30))

func heart_lid(ox, oy):
	# A low dome.
	for y in range(0, 13):
		for x in range(0, 44):
			var dome = 4.0 * pow((x - 21.5) / 22.0, 2)
			if y < 1 + dome:
				continue
			var v = 0.75 - (y - dome) * 0.06 + 0.18 * x / 44.0
			put(ox + x, oy + y, ramp(HEART, clampf(v, 0, 1), x, y))
	for x in range(0, 44):
		put(ox + x, oy + 10, GOLD[2]); put(ox + x, oy + 11, GOLD[1]); put(ox + x, oy + 12, GOLD[0])
	# A gold clasp with a green gem on top.
	for p in [[19, 1], [20, 0], [21, 0], [22, 0], [23, 0], [24, 1], [19, 2], [24, 2], [20, 3], [23, 3]]:
		put(ox + p[0], oy + p[1], GOLD[1])
	for p in [[20, 1], [21, 1], [22, 1], [23, 1], [20, 2], [21, 2], [22, 2], [23, 2], [21, 3], [22, 3]]:
		put(ox + p[0], oy + p[1], MOSS[2])
	put(ox + 22, oy + 1, MOSS[3]); put(ox + 23, oy + 1, Color("#eaffc0"))
	put(ox + 21, oy + 3, MOSS[0]); put(ox + 22, oy + 3, MOSS[1])
	outline(Rect2i(ox - 1, oy - 1, 46, 16))

func run(api, image, project, params):
	img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	shift = Vector2i(1, 0)
	twig_body(2); bark_body(34); heart_body(66)
	shift = Vector2i.ZERO
	twig_lid(50, 1); bark_lid(50, 33); heart_lid(50, 65)
	var out: String = params.get("save_dir", "")
	if out != "":
		for t in 3:
			# The outline pass reaches a pixel past each part, so crop with that margin.
			img.get_region(Rect2i(0, t * 32 + 1, 42, 28)).save_png(out + "twig_box_%d.png" % (t + 1))
			img.get_region(Rect2i(49, t * 32, 46, 16)).save_png(out + "twig_box_lid_%d.png" % (t + 1))
	return img
