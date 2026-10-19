# Pixelorama eval_gdscript generator for the Grove tree.
# params: stage (0-3), part ("trunk" | "crown")
var img: Image
const W := 176
const H := 200
const B := Vector2(88, 194)
const LEAF := [Color("#1f4d2b"), Color("#2e6b34"), Color("#3f8f3a"), Color("#5dbb4c"), Color("#9ad86a"), Color("#c8ef8f")]
const BARK := [Color("#3a2212"), Color("#5e3a20"), Color("#7d4e2a"), Color("#a06a3a"), Color("#c08850")]
const STAGES := [
	{"h": 16, "bw": 1.0, "tw": 1.0, "flare": 0.0, "clusters": []},
	{"h": 58, "bw": 4.0, "tw": 2.0, "flare": 3.0, "clusters": [[0, -80, 12], [-13, -58, 12], [13, -59, 13], [0, -67, 18]]},
	{"h": 92, "bw": 7.0, "tw": 3.0, "flare": 5.0, "clusters": [[0, -128, 14], [-30, -108, 13], [30, -110, 13], [0, -110, 21], [-24, -92, 17], [24, -94, 18], [-10, -82, 15], [12, -80, 15]]},
	{"h": 124, "bw": 11.0, "tw": 4.0, "flare": 8.0, "clusters": [[-16, -168, 15], [18, -166, 16], [-36, -150, 16], [38, -150, 15], [0, -152, 24], [-24, -136, 24], [24, -138, 24], [-44, -118, 20], [44, -120, 21], [-52, -100, 15], [52, -102, 15], [0, -120, 22], [-18, -106, 16], [20, -104, 16]]},
]

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func px(x, y, c):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func solid(x, y) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and img.get_pixel(x, y).a > 0.5

func outline(col: Color):
	var src = img.duplicate()
	for y in H:
		for x in W:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and src.get_pixel(q.x, q.y).a > 0.5 and src.get_pixel(q.x, q.y) != col:
					img.set_pixel(x, y, col)
					break

func trunk_half(st, up: float) -> float:
	var t = clampf(up / st["h"], 0.0, 1.0)
	var w = lerpf(st["bw"], st["tw"], pow(t, 0.7))
	if up < 8.0:
		w += st["flare"] * pow(1.0 - up / 8.0, 2.0)
	return w

func bark_col(x, y, cx, hw) -> Color:
	var u = (x - cx) / maxf(hw, 1.0)  # -1 left .. 1 right; light from the upper right
	var grain = sin(x * 2.3 + floor((y + x * 3) / 11.0) * 1.7) > 0.8
	var i = 2
	if u > 0.45: i = 3
	if u > 0.75 and hw > 3: i = 4 if bayer(x, y) > 0.5 else 3
	if u < -0.5: i = 1
	if grain and i >= 2: i -= 1
	return BARK[i]

func draw_trunk(st):
	var h: int = st["h"]
	for up in range(0, h + 1):
		var y = int(B.y) - up
		var hw = trunk_half(st, up)
		var lean = sin(up * 0.05) * (st["bw"] * 0.15)
		var cx = B.x + lean
		for x in range(int(floor(cx - hw)), int(ceil(cx + hw))):
			px(x, y, bark_col(x, y, cx, hw))
	# branches out to the crown clusters
	for c in st["clusters"]:
		var target = B + Vector2(c[0], c[1])
		if absf(c[0]) < 4:
			continue
		var start_up = clampf(-c[1] - c[2] * 1.4, h * 0.45, h - 4)
		var start = Vector2(B.x, B.y - start_up)
		var wid = maxf(1.0, st["tw"] * 0.8)
		var n = int(start.distance_to(target))
		for i in n:
			var t = float(i) / n
			var p = start.lerp(target, t) + Vector2(0, -sin(t * PI) * 4)
			var r = lerpf(wid, 0.8, t)
			for yy in range(int(p.y - r), int(p.y + r) + 1):
				for xx in range(int(p.x - r), int(p.x + r) + 1):
					if Vector2(xx, yy).distance_to(p) <= r + 0.2:
						px(xx, yy, BARK[3] if yy < p.y - r * 0.3 else BARK[2])
	outline(BARK[0])
	# soft ground shadow under everything (drawn under the trunk)
	var sw = 10 + st["bw"] * 4
	for y in range(int(B.y) - 2, int(B.y) + 5):
		for x in range(int(B.x - sw), int(B.x + sw) + 1):
			var d = pow((x - B.x) / sw, 2) + pow((y - B.y - 1) / 3.5, 2)
			if d <= 1.0 and not solid(x, y) and bayer(x, y) < 0.75:
				px(x, y, Color(0.08, 0.2, 0.06, 0.35))

func leaf_shape(base: Vector2, ang: float, length: float, wid: float):
	var dir = Vector2(cos(ang), sin(ang))
	var nrm = Vector2(-dir.y, dir.x)
	var mid = base + dir * length * 0.5
	for y in range(int(mid.y - length), int(mid.y + length)):
		for x in range(int(mid.x - length), int(mid.x + length)):
			var d = Vector2(x, y) - mid
			var u = d.dot(dir) / (length * 0.5)
			var v = d.dot(nrm) / wid
			if u * u + v * v <= 1.0:
				var c = LEAF[3]
				if v > 0.35: c = LEAF[2]
				if v < -0.3: c = LEAF[4]
				if absf(v) < 0.18 and u < 0.7: c = LEAF[2]
				px(x, y, c)

func draw_crown(st, stage):
	if stage == 0:
		var top = B + Vector2(0, -st["h"])
		leaf_shape(top + Vector2(-1, 2), deg_to_rad(-160), 12, 3.6)
		leaf_shape(top + Vector2(1, 2), deg_to_rad(-20), 12, 3.6)
		leaf_shape(top + Vector2(0, 0), deg_to_rad(-90), 9, 3.0)
		outline(LEAF[0])
		return
	var cl: Array = st["clusters"]
	var owner = {}
	var L = Vector2(0.55, -0.83)
	for y in H:
		for x in W:
			var best = -1
			for i in cl.size():
				var c = B + Vector2(cl[i][0], cl[i][1])
				var d = Vector2(x, y) - c
				var ang = d.angle()
				var r = cl[i][2] * (1.0 + 0.1 * sin(ang * 5.0 + i * 1.7) + 0.05 * sin(ang * 11.0 + i))
				if d.length() <= r:
					best = i
			if best >= 0:
				owner[Vector2i(x, y)] = best
	for key in owner:
		var i = owner[key]
		var c = B + Vector2(cl[i][0], cl[i][1])
		var n = (Vector2(key) - c) / cl[i][2]
		var t = n.dot(L) - n.length() * 0.15
		var dz = bayer(key.x, key.y) * 0.25 - 0.125
		var ci = 2
		if t + dz > 0.42: ci = 4
		elif t + dz > 0.05: ci = 3
		elif t + dz < -0.45: ci = 1
		# a darker seam where a front cluster overlaps this one
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if owner.get(key + d, -1) > i:
				ci = maxi(1, ci - 2)
				break
		px(key.x, key.y, LEAF[ci])
	# leafy specks: highlights up top, shadows below
	var rng = RandomNumberGenerator.new()
	rng.seed = 11 + stage
	var keys = owner.keys()
	for k in int(keys.size() / 14):
		var p: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var cur = img.get_pixel(p.x, p.y)
		if cur == LEAF[4]:
			px(p.x, p.y, LEAF[5]); px(p.x + 1, p.y, LEAF[5])
		elif cur == LEAF[3]:
			px(p.x, p.y, LEAF[4]); px(p.x, p.y - 1, LEAF[4])
		elif cur == LEAF[2]:
			px(p.x, p.y, LEAF[1]); px(p.x - 1, p.y + 1, LEAF[1])
	outline(LEAF[0])

func run(api, image, project, params):
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var stage: int = int(params.get("stage", 3))
	var st = STAGES[stage]
	if params.get("part", "trunk") == "trunk":
		draw_trunk(st)
	else:
		draw_crown(st, stage)
	return img
