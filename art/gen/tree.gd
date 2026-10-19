# Pixelorama eval_gdscript generator for the Grove tree, after example.png in
# the project folder: a gnarled old tree with deep flowing grooves in its bark,
# buttress roots spreading into the ground, twisting boughs reaching out
# sideways, and a crown of separate leaf clumps, each lit along its top, with
# sky between them.
# One stage per tree level: a sprout, a seedling, then the tree growing from a
# sapling into the full Elemental Tree, which hangs a fruit of each element.
# params: stage (0-9), part ("trunk" | "crown")
var img: Image
const W := 176
const H := 200
const B := Vector2(88, 194)
const L := Vector2(0.55, -0.83)  # light from the upper right
# Leaves, dark to light.
const LEAF := [Color("#17321f"), Color("#24492b"), Color("#356a36"), Color("#4f8c3e"), Color("#78b04e"), Color("#a8d46c")]
const BARK := [Color("#26150c"), Color("#432716"), Color("#633b20"), Color("#86552f"), Color("#a87444")]
const SAP := [Color("#b07818"), Color("#e8b84a"), Color("#ffd447"), Color("#fff3a0")]
const ORBS := [Color("#8fd36c"), Color("#5ba4e8"), Color("#f0742d"), Color("#bfe6ff"), Color("#a985e0")]

# The full-grown tree, relative to its base; younger stages are this scaled
# down by SCALE[stage], with only the parts their stage has grown (the last
# number of each entry).
const SCALE := [0.0, 0.0, 0.34, 0.42, 0.52, 0.61, 0.7, 0.79, 0.89, 1.0]
const TRUNK := {"h": 76.0, "bw": 14.0, "tw": 9.0}
# boughs: [start, control, end, width at start, width at end, from stage,
# sway (how far it wanders off the curve), waves along it]
const BOUGHS := [
	[Vector2(-3, -72), Vector2(-18, -100), Vector2(-26, -134), 6.0, 2.0, 2, 3.0, 1.5],
	[Vector2(3, -70), Vector2(16, -104), Vector2(26, -140), 6.0, 2.0, 2, -2.5, 2.0],
	[Vector2(-6, -58), Vector2(-30, -66), Vector2(-60, -102), 6.5, 2.0, 4, 4.0, 2.0],
	[Vector2(6, -64), Vector2(30, -74), Vector2(56, -96), 6.0, 2.0, 4, -3.0, 1.5],
	[Vector2(-60, -102), Vector2(-70, -104), Vector2(-72, -116), 2.0, 1.0, 5, 1.0, 1.0],
	[Vector2(-7, -46), Vector2(-26, -48), Vector2(-46, -66), 3.5, 1.0, 6, 2.5, 2.0],
	[Vector2(7, -50), Vector2(24, -58), Vector2(40, -62), 3.0, 1.0, 7, -2.0, 1.5],
	[Vector2(-26, -134), Vector2(-22, -154), Vector2(-12, -166), 2.0, 1.0, 8, 1.5, 1.0],
	[Vector2(26, -140), Vector2(26, -156), Vector2(18, -170), 2.0, 1.0, 8, -1.5, 1.0],
]
# leaf clumps: [centre, half width, half height, from stage]
const CLUMPS := [
	[Vector2(0, -128), 24.0, 15.0, 2],
	[Vector2(0, -156), 28.0, 16.0, 2],
	[Vector2(-28, -142), 22.0, 15.0, 3],
	[Vector2(32, -146), 22.0, 15.0, 3],
	[Vector2(-58, -110), 22.0, 14.0, 4],
	[Vector2(54, -104), 20.0, 14.0, 4],
	[Vector2(0, -106), 22.0, 13.0, 4],
	[Vector2(-20, -116), 18.0, 12.0, 5],
	[Vector2(20, -120), 18.0, 12.0, 5],
	[Vector2(-66, -92), 14.0, 9.0, 6],
	[Vector2(62, -88), 13.0, 9.0, 6],
	[Vector2(-44, -72), 14.0, 9.0, 6],
	[Vector2(40, -66), 13.0, 9.0, 7],
	[Vector2(2, -92), 16.0, 10.0, 7],
	[Vector2(-14, -174), 18.0, 10.0, 8],
	[Vector2(18, -172), 16.0, 10.0, 8],
]
# roots: [end x, how far down they reach, width, from stage]
const ROOTS := [
	[32.0, 2.0, 8.0, 3], [-32.0, 2.0, 8.0, 3],
	[48.0, 1.0, 5.5, 5], [-46.0, 1.0, 5.5, 5],
	[20.0, 4.0, 5.5, 6], [-18.0, 4.0, 5.5, 7],
	[62.0, 0.0, 4.0, 8], [-60.0, 0.0, 4.0, 9],
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

# Bark: `u` runs -1..1 across the wood (toward the light is +), `along` down
# its length. Ridges run along the wood, wandering, with dark grooves between.
func bark(u: float, along: float, ridges: float, x: int, y: int) -> Color:
	var l = u * 0.55 + 0.05 + (bayer(x, y) - 0.5) * 0.2
	var ph = (u * 0.5 + 0.5) * ridges + sin(along * 0.09 + u * 2.2) * 0.55
	var f = ph - floor(ph)
	if f < 0.2:
		l -= 0.75
	elif f > 0.55 and f < 0.72:
		l += 0.35
	if u < -0.8:
		l -= 0.3
	return BARK[0] if l < -0.65 else (BARK[1] if l < -0.2 else (BARK[2] if l < 0.2 else (BARK[3] if l < 0.5 else BARK[4])))

# A tapering, bending length of wood along a quadratic curve a -> c -> b.
func tube(a: Vector2, c: Vector2, b: Vector2, w0: float, w1: float, sway := 0.0, waves := 1.0):
	var pts = []
	var n = int(a.distance_to(c) + c.distance_to(b)) + 2
	var side = (b - a).normalized().orthogonal()
	for i in n + 1:
		var t = float(i) / n
		# wander off the curve and back, so the wood bends naturally
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t) + side * sin(t * PI * waves) * sway * sin(t * PI))
	var r = Rect2(a, Vector2.ZERO).expand(b).expand(c).grow(maxf(w0, w1) + absf(sway) + 2)
	for y in range(int(r.position.y), int(r.end.y) + 1):
		for x in range(int(r.position.x), int(r.end.x) + 1):
			var p = Vector2(x + 0.5, y + 0.5)
			var best = 1e9
			var bi = 0
			for i in pts.size():
				var d = p.distance_squared_to(pts[i])
				if d < best:
					best = d
					bi = i
			var t = float(bi) / n
			var w = lerpf(w0, w1, t)
			if sqrt(best) > w + 0.2:
				continue
			var dir = (pts[mini(bi + 1, n)] - pts[maxi(bi - 1, 0)]).normalized()
			var nrm = Vector2(-dir.y, dir.x)
			if nrm.dot(L) < 0:
				nrm = -nrm
			var u = (p - pts[bi]).dot(nrm) / maxf(w, 1.0)
			px(x, y, bark(clampf(u, -1, 1), t * n, maxf(1.5, w / 2.2), x, y))

func draw_trunk(stage: int):
	var f: float = SCALE[stage]
	var h = TRUNK["h"] * f
	var bw = maxf(1.5, TRUNK["bw"] * f)
	var tw = maxf(1.0, TRUNK["tw"] * f)
	# roots: buttresses flaring out of the foot and diving into the ground
	for rt in ROOTS:
		if stage < rt[3]:
			continue
		var side = signf(rt[0])
		var a = B + Vector2(side * bw * 0.3, -bw * 1.9)
		var b = B + Vector2(rt[0] * f, rt[1])
		var c = B + Vector2(side * bw * 1.2 + rt[0] * f * 0.25, -bw * 0.2)
		tube(a, c, b, rt[2] * f, 0.7)
	# the trunk, twisting a little as it rises, its foot flared
	for up in range(0, int(h) + 1):
		var t = up / h
		var hw = lerpf(bw, tw, pow(t, 0.8)) + bw * 0.6 * pow(maxf(0.0, 1.0 - up / (bw * 1.6)), 2.0)
		var cx = B.x + sin(up * 0.06) * bw * 0.25
		var y = int(B.y) - up
		for x in range(int(floor(cx - hw)), int(ceil(cx + hw))):
			var u = (x + 0.5 - cx) / hw
			px(x, y, bark(u, up, maxf(2.0, hw / 2.4), x, y))
	for bg in BOUGHS:
		if stage >= bg[5]:
			tube(B + bg[0] * f, B + bg[1] * f, B + bg[2] * f, maxf(1.0, bg[3] * f), maxf(0.8, bg[4] * f), bg[6] * f, bg[7])
	if stage >= 6:
		# ivy climbing the trunk
		for up in range(3, int(h * 0.75)):
			var x = int(round(B.x + sin(up * 0.06) * bw * 0.25 + sin(up * 0.21) * bw * 0.45))
			var y = int(B.y) - up
			if posmod(up, 3) != 0:
				px(x, y, LEAF[2])
			if posmod(up, 5) == 0:
				px(x + 1, y, LEAF[4]); px(x - 1, y - 1, LEAF[3])
	if stage == 9:
		# a glowing knot in the heart of the trunk
		var k = Vector2(B.x + 3, B.y - 30)
		for y in range(int(k.y) - 4, int(k.y) + 5):
			for x in range(int(k.x) - 4, int(k.x) + 5):
				var d = Vector2(x + 0.5, y + 0.5).distance_to(k)
				if d <= 3.4:
					px(x, y, SAP[3] if d < 1.2 else (SAP[2] if d < 2.3 else SAP[0]))
	outline(BARK[0])
	# soft ground shadow
	var sw = 14 + 60 * f
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
			var v = d.dot(nrm) / (wid * (1.0 - maxf(0.0, u) * 0.35))
			if u * u + v * v <= 1.0:
				var c = LEAF[4]
				if v > 0.35: c = LEAF[3]
				if v < -0.3: c = LEAF[5]
				if absf(v) < 0.18 and u < 0.7: c = LEAF[3]
				px(x, y, c)

# A clump of foliage: overlapping puffs, each lit along its top and shaded
# beneath, so the clump reads as layered leaves.
func clump(c: Vector2, rx: float, ry: float, pal: Array, rng: RandomNumberGenerator):
	var rp = clampf(minf(rx, ry) * 0.55, 3.0, 8.0)
	var puffs = []
	var count = int(rx * ry / (rp * rp) * 1.6) + 2
	for i in count:
		var a = rng.randf_range(0, TAU)
		var d = sqrt(rng.randf())
		puffs.append([c + Vector2(cos(a) * rx, sin(a) * ry) * d * 0.85, rp * rng.randf_range(0.75, 1.15)])
	puffs.sort_custom(func(p, q): return p[0].y < q[0].y)
	var mine = {}
	for pi in puffs.size():
		var pc: Vector2 = puffs[pi][0]
		var pr: float = puffs[pi][1]
		for y in range(int(pc.y - pr) - 2, int(pc.y + pr) + 3):
			for x in range(int(pc.x - pr) - 2, int(pc.x + pr) + 3):
				var d = Vector2(x + 0.5, y + 0.5) - pc
				var rr = pr * (1.0 + 0.18 * sin(d.angle() * 5.0 + pi * 2.1))
				if d.length() <= rr:
					mine[Vector2i(x, y)] = [pi, d / pr]
	for k in mine:
		var pi = mine[k][0]
		var n: Vector2 = mine[k][1]
		# the puff's own top is lit; the clump darkens toward its underside
		var l = -n.y * 0.55 + n.x * 0.2 - (k.y + 0.5 - c.y) / ry * 0.35 + (bayer(k.x, k.y) - 0.5) * 0.25
		var ci = 0 if l < -0.7 else (1 if l < -0.3 else (2 if l < 0.05 else (3 if l < 0.35 else (4 if l < 0.6 else 5))))
		# shade where a puff in front starts below this one
		if mine.has(k + Vector2i(0, 1)) and mine[k + Vector2i(0, 1)][0] > pi and n.y > 0.2:
			ci = maxi(0, ci - 2)
		px(k.x, k.y, pal[ci])
	# leaf tufts along the clump's edge
	for k in mine:
		var out = Vector2.ZERO
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not mine.has(k + d):
				out += Vector2(d)
		if out == Vector2.ZERO or rng.randf() > 0.25:
			continue
		var dir = (out.normalized() + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.6))).normalized()
		var col = img.get_pixel(k.x, k.y)
		for s in range(1, rng.randi_range(2, 3)):
			var q = Vector2i((Vector2(k) + dir * s).round())
			if not solid(q.x, q.y):
				px(q.x, q.y, col)

func draw_crown(stage: int):
	if stage == 0:
		var top = B + Vector2(0, -12)
		leaf_shape(top + Vector2(-1, 2), deg_to_rad(-165), 10, 3.4)
		leaf_shape(top + Vector2(1, 2), deg_to_rad(-15), 10, 3.4)
		leaf_shape(top + Vector2(0, 1), deg_to_rad(-80), 6, 2.2)
		outline(LEAF[0])
		return
	if stage == 1:
		for lf in [[8, -1, 9.0], [15, 1, 10.0], [21, -1, 10.0], [26, 1, 8.0]]:
			leaf_shape(Vector2(B.x, B.y - lf[0]), deg_to_rad(-90 - lf[1] * 62), lf[2], 3.2)
		leaf_shape(B + Vector2(0, -29), deg_to_rad(-100), 8, 2.6)
		leaf_shape(B + Vector2(0, -29), deg_to_rad(-70), 6, 2.0)
		outline(LEAF[0])
		return
	var f: float = SCALE[stage]
	var rng = RandomNumberGenerator.new()
	rng.seed = 17 + stage * 7
	var list = []
	for cl in CLUMPS:
		if stage >= cl[3]:
			list.append(cl)
	# back to front: the higher clumps sit behind the lower ones
	list.sort_custom(func(a, b): return a[0].y < b[0].y)
	for cl in list:
		# young crowns are fuller for their size
		var fc = pow(f, 0.7)
		clump(B + cl[0] * f, cl[1] * fc, cl[2] * fc, LEAF, rng)
	outline(LEAF[0])
	if stage == 9:
		# a fruit of each element hanging under the crown, glowing
		for i in ORBS.size():
			var fx = int(B.x + [-56, -24, 4, 30, 58][i])
			var fy = 0
			for y in range(int(B.y) - 50, 0, -1):
				if solid(fx, y):
					fy = y
					break
			if fy == 0:
				continue
			var o = Vector2(fx, fy + 4 + (i % 2) * 2)
			for y in range(fy + 1, int(o.y) - 1):
				px(fx, y, LEAF[0])
			for y in range(int(o.y) - 3, int(o.y) + 4):
				for x in range(int(o.x) - 3, int(o.x) + 4):
					var d = Vector2(x, y).distance_to(o)
					if d <= 3.0:
						px(x, y, ORBS[i].darkened(0.5) if d > 2.3 else (ORBS[i].lightened(0.35) if d < 1.2 else ORBS[i]))
			px(int(o.x) + 1, int(o.y) - 1, Color.WHITE)

func run(api, image, project, params):
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var stage: int = int(params.get("stage", SCALE.size() - 1))
	if params.get("part", "trunk") == "trunk":
		if stage < 2:
			# a slender stem
			var h = 12 if stage == 0 else 30
			for up in range(0, h + 1):
				px(int(B.x) - 1, int(B.y) - up, BARK[2]); px(int(B.x), int(B.y) - up, BARK[3])
			outline(BARK[0])
		else:
			draw_trunk(stage)
	else:
		draw_crown(stage)
	return img
