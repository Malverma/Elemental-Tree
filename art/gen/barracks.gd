# Barracks art. params.part: "bg" (180x400 root hollow) or "sheet" (96x32:
# stump pad 40x26 at 0,0; selection ring 44x30 at 44,0).
var img: Image
var W := 180
var H := 400
const BARK := [Color("#2e1a0e"), Color("#5e3a20"), Color("#8a5530"), Color("#b07a45")]
const WOOD := [Color("#6e5032"), Color("#a07c4c"), Color("#b8945e"), Color("#d6b27a")]
const MOSS := [Color("#2d4a1f"), Color("#4a6e2a"), Color("#78a040"), Color("#b2d36a")]
const SAP := Color("#ffb347")
const SAP_HI := Color("#fff0b0")
const LIGHT := Vector2(90, 96)  # where the glowing roots light the hollow from

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func put(x, y, c: Color):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func at(x, y) -> Color:
	if x >= 0 and y >= 0 and x < W and y < H:
		return img.get_pixel(x, y)
	return Color(0, 0, 0, 0)

# Picks from a dark-to-light ramp by a 0..1 value, dithering between steps.
func ramp(cols: Array, v: float, x: int, y: int) -> Color:
	var f = clampf(v, 0.0, 0.999) * (cols.size() - 1)
	var i = int(f)
	return cols[mini(i + 1, cols.size() - 1)] if f - i > bayer(x, y) else cols[i]

func light(x, y) -> float:
	var d = Vector2(x, y * 0.8).distance_to(Vector2(LIGHT.x, LIGHT.y * 0.8))
	return clampf(1.0 - d / 170.0, 0.0, 1.0)

func wall_edge(x) -> int:
	return int(150 + 4 * sin(x * 0.11) + 2 * sin(x * 0.37 + 1.0))

func root(pts: Array, w0: float, w1: float, tip_glow: bool):
	var n = pts.size() / 2 - 1
	var total = 0.0
	var segs = []
	for i in n:
		var a = Vector2(pts[i * 2], pts[i * 2 + 1])
		var b = Vector2(pts[i * 2 + 2], pts[i * 2 + 3])
		segs.append([a, b, total])
		total += a.distance_to(b)
	var mask = {}
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var steps = int(a.distance_to(b) * 2) + 1
		for k in steps + 1:
			var p = a.lerp(b, float(k) / steps)
			var t = (s[2] + a.distance_to(p)) / total
			var w = lerpf(w0, w1, t)
			for yy in range(int(p.y - w) - 1, int(p.y + w) + 2):
				for xx in range(int(p.x - w) - 1, int(p.x + w) + 2):
					var d = Vector2(xx + 0.5, yy + 0.5) - p
					if d.length() <= w:
						var key = Vector2i(xx, yy)
						var v = d.x / maxf(w, 0.6)
						if not mask.has(key) or absf(v) < absf(mask[key]):
							mask[key] = v
	for k in mask:
		var v = mask[k]
		var c = BARK[2]
		if v > 0.35: c = BARK[3] if bayer(k.x, k.y) > 0.3 else BARK[2]
		if v < -0.4: c = BARK[1]
		if absf(v) > 0.85: c = BARK[0]
		if posmod(k.y + int(k.x * 0.5), 7) == 0 and absf(v) < 0.5: c = BARK[1]
		put(k.x, k.y, c)
	if tip_glow:
		var e = Vector2(pts[pts.size() - 2], pts[pts.size() - 1])
		for yy in range(int(e.y) - 7, int(e.y) + 8):
			for xx in range(int(e.x) - 7, int(e.x) + 8):
				var d = Vector2(xx, yy).distance_to(e)
				if d < 7 and bayer(xx, yy) > d / 7.0 + 0.15 and not mask.has(Vector2i(xx, yy)):
					put(xx, yy, at(xx, yy).lerp(SAP, 0.35))
		put(int(e.x), int(e.y), SAP_HI); put(int(e.x), int(e.y) + 1, SAP)
		put(int(e.x) - 1, int(e.y), SAP); put(int(e.x) + 1, int(e.y), SAP)

func mushroom(x: int, y: int, cap: Color, s: int):
	for yy in range(y - s, y + 1):
		put(x, yy, Color("#d8cfb8")); put(x + 1, yy, Color("#b8ae96"))
	for yy in range(-s, 1):
		for xx in range(-s - 1, s + 3):
			if pow((xx - 0.5) / (s + 1.5), 2) + pow(yy / float(s) * 1.4, 2) <= 1.0:
				var c = cap
				if yy < -s / 2 and xx > 0: c = cap.lightened(0.35)
				if yy == 0: c = cap.darkened(0.3)
				put(x + xx, y - s - 1 + yy, c)
	# soft glow on the floor around it
	for yy in range(y - 6, y + 4):
		for xx in range(x - 6, x + 8):
			var d = Vector2(xx, yy).distance_to(Vector2(x, y))
			if d < 7 and bayer(xx, yy) > d / 7.0 + 0.3 and at(xx, yy).get_luminance() < 0.45:
				put(xx, yy, at(xx, yy).lerp(cap, 0.25))

func bg():
	var wall = [Color("#160d08"), Color("#24160d"), Color("#342114"), Color("#4a3020"), Color("#5e3e28")]
	var floor = [Color("#2a1a10"), Color("#3e2818"), Color("#553822"), Color("#6c4a2e"), Color("#86603c")]
	for y in H:
		for x in W:
			var e = wall_edge(x)
			var lv = light(x, y)
			if y < e:
				# back wall with soil strata
				var strata = sin(y * 0.45 + sin(x * 0.07) * 2.0) * 0.035
				put(x, y, ramp(wall, lv * 0.85 + strata, x, y))
			else:
				# floor: brighter toward the far wall, darker at the edges and the bottom
				var side = pow(absf(x - 90) / 90.0, 2.0)
				var v = lv * 0.85 + 0.2 - side * 0.25 - (y - e) / 900.0
				put(x, y, ramp(floor, v, x, y))
	var rng = RandomNumberGenerator.new()
	rng.seed = 21
	# pebbles and flecks
	for i in 700:
		var x = rng.randi_range(0, W - 1)
		var y = rng.randi_range(0, H - 1)
		var c = at(x, y)
		put(x, y, c.lightened(0.12) if rng.randf() < 0.5 else c.darkened(0.18))
	for i in 40:
		var x = rng.randi_range(2, W - 3)
		var y = rng.randi_range(wall_edge(x) + 6, H - 2)
		var c = at(x, y).lightened(0.22)
		put(x, y, c); put(x + 1, y, c.darkened(0.15)); put(x, y + 1, Color(0, 0, 0, 1).lerp(at(x, y + 1), 0.6))
	for i in 30:
		var x = rng.randi_range(2, W - 3)
		var y = rng.randi_range(4, wall_edge(x) - 6)
		var c = Color("#6e5a4a").lerp(at(x, y), 0.4)
		put(x, y, c); put(x + 1, y, c.darkened(0.2))
	# the crease where wall meets floor, with moss along it
	for x in W:
		var e = wall_edge(x)
		put(x, e - 1, Color("#120a06"))
		put(x, e, at(x, e).darkened(0.25))
		var m = 0.5 + 0.5 * sin(x * 0.23) * sin(x * 0.07 + 2.0)
		if m > 0.45:
			var h = int(m * 3.0)
			for k in h:
				put(x, e - 1 - k, MOSS[1] if k < h - 1 else MOSS[2])
			if bayer(x, e) > 0.6:
				put(x, e, MOSS[1])
	# roots hanging from the ceiling (thick at the top), some with glowing sap tips
	root([62, -4, 60, 18, 52, 38, 48, 62, 50, 84], 6.0, 1.4, true)
	root([104, -4, 108, 22, 118, 44, 120, 70], 5.5, 1.2, true)
	root([84, -4, 86, 16, 82, 30, 84, 48], 3.5, 1.0, true)
	root([140, -4, 146, 30, 136, 56, 138, 94, 132, 112], 4.0, 1.0, true)
	root([30, -4, 24, 26, 34, 52, 28, 78], 3.6, 1.0, true)
	root([72, 12, 74, 30, 70, 40], 1.6, 0.6, false)
	root([126, 20, 124, 36, 128, 48], 1.6, 0.6, false)
	root([48, 40, 40, 52, 42, 64], 1.4, 0.6, true)
	# great roots framing the hollow down both sides to the floor
	root([-6, 60, 8, 110, 6, 170, 16, 240, 10, 330, 18, 410], 9.0, 6.0, false)
	root([186, 40, 172, 100, 176, 180, 164, 260, 172, 340, 164, 410], 9.0, 6.0, false)
	root([10, 190, 26, 200, 32, 214], 2.4, 0.8, true)
	root([168, 230, 154, 238, 150, 252], 2.4, 0.8, true)
	# glowing mushrooms by the walls and in the corners
	for mu in [[28, 160, Color("#6fe0d8"), 3], [34, 163, Color("#6fe0d8"), 2], [150, 158, Color("#ffb36b"), 3],
			[26, 352, Color("#6fe0d8"), 4], [34, 356, Color("#6fe0d8"), 2], [152, 360, Color("#c890ff"), 4], [144, 364, Color("#c890ff"), 2],
			[24, 276, Color("#ffb36b"), 2], [156, 300, Color("#6fe0d8"), 3]]:
		mushroom(mu[0], mu[1], mu[2], mu[3])
	# moss patches on the floor near the walls
	for i in 160:
		var side = -1 if rng.randf() < 0.5 else 1
		var x = 90 + side * rng.randi_range(58, 80)
		var y = rng.randi_range(160, H - 1)
		if rng.randf() < 0.6:
			put(x, y, MOSS[1]); put(x + 1, y, MOSS[2] if rng.randf() < 0.5 else MOSS[1])

# A sliced log for a troop to stand on: rings on top, bark around the side.
func pad():
	var c = Vector2(20, 10)
	for y in range(0, 26):
		for x in range(0, 40):
			var p = Vector2(x + 0.5, y + 0.5)
			var top = pow((p.x - c.x) / 19.0, 2) + pow((p.y - c.y) / 9.0, 2)
			var side = pow((p.x - c.x) / 19.0, 2) + pow((p.y - c.y - 5.0) / 9.0, 2)
			if top <= 1.0:
				var r = sqrt(pow((p.x - c.x) / 19.0, 2) + pow((p.y - c.y) / 9.0, 2))
				var col = WOOD[2]
				var ring = int(r * 7.0 + 0.3 * sin(atan2(p.y - c.y, p.x - c.x) * 3.0))
				if ring % 2 == 1: col = WOOD[1]
				if r > 0.82: col = BARK[2] if p.y < c.y else BARK[1]
				if r > 0.92: col = BARK[1]
				if r < 0.12: col = WOOD[0]
				if r < 0.75 and p.x > c.x + 2 and p.y < c.y - 2 and col == WOOD[2] and bayer(x, y) > 0.5: col = WOOD[3]
				put(x, y, col)
			elif side <= 1.0 and p.y > c.y:
				var col = BARK[2]
				if posmod(x * 3 + y, 5) == 0: col = BARK[1]
				if x > 28: col = BARK[3] if bayer(x, y) > 0.5 else BARK[2]
				if x < 9: col = BARK[1]
				put(x, y, col)
	# a crack and a moss tuft
	for k in [[12, 7], [13, 8], [13, 9], [14, 10]]:
		put(k[0], k[1], WOOD[0])
	for k in [[4, 13], [5, 12], [6, 12], [5, 13], [3, 14], [6, 13], [7, 12]]:
		put(k[0], k[1], MOSS[2] if k[1] == 12 else MOSS[1])
	outline(Rect2i(0, 0, 40, 26))

func ring():
	var c = Vector2(66, 12)
	for y in range(0, 30):
		for x in range(44, 88):
			var p = Vector2(x + 0.5, y + 0.5)
			var r = sqrt(pow((p.x - c.x) / 21.0, 2) + pow((p.y - c.y) / 11.0, 2))
			if r <= 1.0 and r > 0.86:
				put(x, y, Color("#ffd447") if bayer(x, y) > 0.25 else Color("#fff6b0"))
	for sp in [[46, 4], [86, 20], [62, 0], [70, 24]]:
		put(sp[0], sp[1], Color("#fff6b0"))

func outline(r: Rect2i):
	var src = img.duplicate()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= r.position.x and q.y >= r.position.y and q.x < r.end.x and q.y < r.end.y and src.get_pixel(q.x, q.y).a > 0.5:
					var col = src.get_pixel(q.x, q.y).darkened(0.72)
					col.a = 1.0
					img.set_pixel(x, y, col)
					break

func run(api, image, project, params):
	if params.get("part", "bg") == "bg":
		W = 180; H = 400
		img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		bg()
	else:
		W = 96; H = 32
		img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		pad()
		ring()
	var out: String = params.get("save_dir", "")
	if out != "":
		if params.get("part", "bg") == "bg":
			img.save_png(out + "barracks_bg.png")
		else:
			img.get_region(Rect2i(0, 0, 40, 26)).save_png(out + "barracks_pad.png")
			img.get_region(Rect2i(44, 0, 44, 30)).save_png(out + "barracks_ring.png")
	return img
