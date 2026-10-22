# Pixelorama eval_gdscript generator for troops and enemies.
# One shared palette and shading model: light from the upper right, 3 tones per
# ramp with ordered dither, ramp[0] for creases, and a dark auto-outline.
# Troops face right, enemies face left. Normal units 32x32, bosses 48x48.
var img: Image
var W := 32
var H := 32
const L := Vector2(0.5, -0.85)
const GLOW := Color("#ffe36b")
const GLOW_HI := Color("#fff8d0")
const SOCKET := Color("#1a0f08")

const TROOPS := ["soldier", "guard", "spearman", "archer", "vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig",
	"scout", "acorn_slinger", "drummer", "sap_mender", "bramble_knight", "elder_oak"]
const ENEMIES := ["thorn_beetle", "burrow_rabbit", "spring_frog", "ripple_sprite", "cinder_lizard", "ash_moth", "frost_wolf", "icicle_bat",
	"cave_bat", "shadow_slime", "thornback_boar", "pollen_wisp", "snapjaw_crab", "bubble_eel"]
const BOSSES := ["bramble_hare", "mossback_turtle", "magma_salamander", "rime_elk", "hollow_mole_king", "blight_treant", "lagoon_kraken",
	"scaldmaw_hydra", "rimeshade_wight"]

var R := {
	"bark": [Color("#2e1a0e"), Color("#5e3a20"), Color("#8a5530"), Color("#b07a45")],
	"wood": [Color("#4a3420"), Color("#8a6a42"), Color("#b8945e"), Color("#dcc08a")],
	"leaf": [Color("#1f4d2b"), Color("#2e6b34"), Color("#4f9a3f"), Color("#8fd36c")],
	"moss": [Color("#2d4a1f"), Color("#4a6e2a"), Color("#78a040"), Color("#b2d36a")],
	"willow": [Color("#173f3f"), Color("#2f7a6e"), Color("#4fb0a0"), Color("#a0e6d4")],
	"water": [Color("#1d3b6b"), Color("#2f64b5"), Color("#5ba4e8"), Color("#bfe6ff")],
	"fire": [Color("#7a1a10"), Color("#c8361e"), Color("#f0742d"), Color("#ffd166")],
	"char": [Color("#120c0a"), Color("#2e211b"), Color("#4a372c"), Color("#6b5344")],
	"pine": [Color("#10291f"), Color("#1f4a36"), Color("#33704f"), Color("#5f9c76")],
	"snow": [Color("#5d7f99"), Color("#aac8de"), Color("#dcedf8"), Color("#ffffff")],
	"ice": [Color("#24546e"), Color("#4aa3c9"), Color("#a6dcf0"), Color("#effbff")],
	"shade": [Color("#0c0812"), Color("#241a30"), Color("#3e2f4e"), Color("#5f4a73")],
	"dark": [Color("#1e1030"), Color("#3a2160"), Color("#6a3fa8"), Color("#a985e0")],
	"beetle": [Color("#14301c"), Color("#25563a"), Color("#3f8a4a"), Color("#86cc6e")],
	"fur": [Color("#3e2414"), Color("#7a4a28"), Color("#a87444"), Color("#d6a46c")],
	"cream": [Color("#7a6e5c"), Color("#b8ab92"), Color("#e2d8c2"), Color("#fffaf0")],
	"frog": [Color("#163f36"), Color("#2a7356"), Color("#4fae6a"), Color("#9fdc84")],
	"lizard": [Color("#4a140c"), Color("#9c2e1a"), Color("#d8582a"), Color("#ffa060")],
	"ash": [Color("#2e2826"), Color("#5e5450"), Color("#968a84"), Color("#d4c8c0")],
	"wolf": [Color("#4f6f86"), Color("#9cbcd2"), Color("#d6eaf6"), Color("#ffffff")],
	"bat": [Color("#1a1626"), Color("#342c48"), Color("#54486e"), Color("#7e70a0")],
	"slime": [Color("#160c26"), Color("#33195a"), Color("#5a2e96"), Color("#9468d8")],
	"boar": [Color("#2e1a12"), Color("#5a3424"), Color("#86523a"), Color("#b07a5a")],
	"pollen": [Color("#7a5a10"), Color("#d0a020"), Color("#ffd447"), Color("#fff6b0")],
	"crab": [Color("#14284e"), Color("#24508e"), Color("#3f7fc8"), Color("#8cc4f0")],
	"eel": [Color("#123c48"), Color("#1f6a78"), Color("#3aa0a8"), Color("#9ae0dc")],
	"bone": [Color("#6e6650"), Color("#b0a684"), Color("#e2dabc"), Color("#fffbea")],
	"shell": [Color("#3a2a14"), Color("#6a4e26"), Color("#967040"), Color("#c49c62")],
	"rock": [Color("#141014"), Color("#2c2428"), Color("#463a3c"), Color("#685658")],
	"blight": [Color("#1c1420"), Color("#3e2c3a"), Color("#5e4654"), Color("#86687a")],
	"sick": [Color("#2a3014"), Color("#4e5a1e"), Color("#7a8a2a"), Color("#b0c048")],
	"mole": [Color("#14101a"), Color("#2c2436"), Color("#463a52"), Color("#685a78")],
	"gold": [Color("#6a4a08"), Color("#b88a14"), Color("#f0c43a"), Color("#fff0a0")],
	"pink": [Color("#7a2a4a"), Color("#c0507a"), Color("#f08cb0"), Color("#ffd0e0")],
	"thistle": [Color("#3a1a4a"), Color("#7a3a96"), Color("#b066d0"), Color("#e6b0ff")],
	"kraken": [Color("#2a1440"), Color("#4a2a78"), Color("#6e48b0"), Color("#a888e0")],
}

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func put(x: int, y: int, c: Color):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func opaque(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and img.get_pixel(x, y).a > 0.5

func tone(t: float, x: int, y: int, ramp: Array) -> Color:
	t += (bayer(x, y) - 0.5) * 0.3
	return ramp[3] if t > 0.45 else (ramp[2] if t > -0.15 else ramp[1])

# Fills a shape (given as a dict of pixel -> light term) and creases its edge
# against anything drawn before it when `edge` is set.
func commit(mask: Dictionary, ramp: Array, edge: bool):
	var under = {}
	if edge:
		for k in mask:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q = k + d
				if not mask.has(q) and opaque(q.x, q.y):
					under[k] = true
	for k in mask:
		put(k.x, k.y, ramp[0] if under.has(k) else tone(mask[k], k.x, k.y, ramp))

func E(cx: float, cy: float, rx: float, ry: float, ramp: Array, edge := false):
	var mask = {}
	for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
		for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
			var n = Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			if n.length_squared() <= 1.0:
				mask[Vector2i(x, y)] = n.dot(L) * 0.9 + 0.05
	commit(mask, ramp, edge)

func P(pts: Array, ramp: Array, edge := false):
	var poly = PackedVector2Array()
	for i in range(0, pts.size(), 2):
		poly.append(Vector2(pts[i], pts[i + 1]))
	var r = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	var c = r.get_center()
	var half = r.size / 2.0 + Vector2(0.5, 0.5)
	var mask = {}
	for y in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for x in range(int(r.position.x) - 1, int(r.end.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				var n = (Vector2(x + 0.5, y + 0.5) - c) / half
				mask[Vector2i(x, y)] = n.dot(L) * 0.9 + 0.05
	commit(mask, ramp, edge)

func Ln(x1: float, y1: float, x2: float, y2: float, w: float, ramp: Array, edge := false):
	var a = Vector2(x1, y1)
	var b = Vector2(x2, y2)
	var mask = {}
	for y in range(int(minf(y1, y2) - w) - 1, int(maxf(y1, y2) + w) + 2):
		for x in range(int(minf(x1, x2) - w) - 1, int(maxf(x1, x2) + w) + 2):
			var p = Vector2(x + 0.5, y + 0.5)
			var q = Geometry2D.get_closest_point_to_segment(p, a, b)
			var d = p - q
			if d.length() <= w:
				mask[Vector2i(x, y)] = (d / maxf(w, 0.5)).dot(L) * 0.9 + 0.1
	commit(mask, ramp, edge)

# A polyline of thick segments.
func path(pts: Array, w: float, ramp: Array, edge := false):
	var mask = {}
	for i in range(0, pts.size() - 2, 2):
		var a = Vector2(pts[i], pts[i + 1])
		var b = Vector2(pts[i + 2], pts[i + 3])
		for y in range(int(minf(a.y, b.y) - w) - 1, int(maxf(a.y, b.y) + w) + 2):
			for x in range(int(minf(a.x, b.x) - w) - 1, int(maxf(a.x, b.x) + w) + 2):
				var p = Vector2(x + 0.5, y + 0.5)
				var d = p - Geometry2D.get_closest_point_to_segment(p, a, b)
				if d.length() <= w:
					mask[Vector2i(x, y)] = (d / maxf(w, 0.5)).dot(L) * 0.9 + 0.1
	commit(mask, ramp, edge)

# A polyline that narrows from width w0 at its start to w1 at its end, like a
# root or branch.
func taper(pts: Array, w0: float, w1: float, ramp: Array, edge := false):
	var segs = []
	var total = 0.0
	for i in range(0, pts.size() - 2, 2):
		var a = Vector2(pts[i], pts[i + 1])
		var b = Vector2(pts[i + 2], pts[i + 3])
		segs.append([a, b, total])
		total += a.distance_to(b)
	var r = Rect2(Vector2(pts[0], pts[1]), Vector2.ZERO)
	for i in range(0, pts.size(), 2):
		r = r.expand(Vector2(pts[i], pts[i + 1]))
	var mask = {}
	for y in range(int(r.position.y - w0) - 1, int(r.end.y + w0) + 2):
		for x in range(int(r.position.x - w0) - 1, int(r.end.x + w0) + 2):
			var p = Vector2(x + 0.5, y + 0.5)
			for sg in segs:
				var q = Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1])
				var w = lerpf(w0, w1, (sg[2] + sg[0].distance_to(q)) / total)
				var d = p - q
				if d.length() <= w:
					mask[Vector2i(x, y)] = (d / maxf(w, 0.5)).dot(L) * 0.9 + 0.1
					break
	commit(mask, ramp, edge)

func D(x: int, y: int, c: Color):
	put(x, y, c)

func Dr(x: int, y: int, w: int, h: int, c: Color):
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			put(xx, yy, c)

# A carved eye socket with a glowing pupil (troops). `right` = looking right.
func eye(x: int, y: int, glow := GLOW, right := true):
	Dr(x, y, 2, 2, SOCKET)
	D(x + (1 if right else 0), y, glow)

# An animal eye: dark with a highlight.
func aeye(x: int, y: int, c := Color("#1a1010"), hi := Color.WHITE):
	D(x, y, c); D(x, y + 1, c)
	D(x, y, hi)
	D(x, y + 1, c)

func outline():
	var src = img.duplicate()
	for y in H:
		for x in W:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var best = null
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and src.get_pixel(q.x, q.y).a > 0.5:
					best = src.get_pixel(q.x, q.y)
					break
			if best != null:
				var c = best.darkened(0.72)
				c.a = 1.0
				img.set_pixel(x, y, c)

# --- troops (face right) ---------------------------------------------------
func troop(name: String):
	var b = R["bark"]
	var w = R["wood"]
	var lf = R["leaf"]
	match name:
		"soldier":
			# A stout stump with root legs, a bark shield and a knotted club.
			Ln(13, 23, 12, 29, 1.6, b); Ln(18, 23, 19, 29, 1.6, b)
			Dr(10, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			Ln(11, 17, 7, 21, 1.2, b)
			P([10, 12, 21, 12, 22, 24, 9, 24], b)
			for y in range(15, 23, 2): D(12, y, b[1])
			for y in range(14, 21, 3): D(20, y, b[1])
			E(15.5, 12.5, 6, 2, w)
			D(15, 12, w[1]); D(16, 12, w[1]); D(13, 12, w[1])
			Ln(16, 11, 17, 8, 0.6, lf); E(18.5, 7, 2.5, 1.5, lf); E(14, 8.5, 2, 1.3, lf)
			eye(12, 16); eye(17, 16)
			Dr(14, 20, 3, 1, SOCKET)
			E(8, 20, 4, 5, b, true)
			D(8, 20, w[3]); D(8, 19, w[2])
			Ln(21, 17, 24, 20, 1.2, b, true)
			Ln(24, 23, 28, 10, 1.8, w, true)
			D(26, 16, w[0]); D(27, 12, w[0])
			E(29, 9, 1.6, 1.1, lf)
		"guard":
			# A broad stump in an acorn-cap helm, braced behind a tall plank shield.
			var sh = R["shell"]
			Ln(12, 23, 11, 29, 1.8, b); Ln(17, 23, 18, 29, 1.8, b)
			Dr(9, 29, 3, 1, b[1]); Dr(18, 29, 3, 1, b[1])
			Ln(9, 16, 5, 20, 1.3, b, true)
			P([7, 12, 20, 12, 21, 25, 6, 25], b)
			for y in range(15, 24, 2): D(9, y, b[1])
			E(13.5, 11, 7.5, 3.5, sh)
			for x in range(8, 20, 3): D(x, 10, sh[0]); D(x + 1, 9, sh[3])
			Dr(6, 13, 15, 1, sh[0])
			Ln(13, 7, 14, 4, 0.7, sh)
			eye(10, 16); eye(14, 16)
			Dr(11, 20, 3, 1, SOCKET)
			# The shield: vertical planks in a stone rim, with a leaf on its boss.
			P([17, 12, 29, 12, 29, 22, 23, 29, 17, 22], w, true)
			for y in range(13, 26): D(21, y, w[0]); D(25, y, w[0])
			path([17, 12, 29, 12, 29, 22, 23, 28, 17, 22, 17, 12], 0.6, R["ash"])
			E(23, 18, 2.2, 2.2, R["gold"])
			D(23, 17, lf[3]); D(22, 18, lf[2]); D(24, 18, lf[1]); D(23, 19, lf[1])
		"spearman":
			# A slim sapling with a leafy crown and a stone-tipped spear.
			Ln(14, 24, 13, 29, 1.3, b); Ln(18, 24, 19, 29, 1.3, b)
			Dr(11, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([12, 11, 19, 11, 20, 25, 11, 25], b)
			for y in range(13, 24, 3): D(13, y, b[1])
			E(15.5, 8, 6, 3.5, lf); E(11.5, 9.5, 3, 2.2, lf); E(19.5, 6.5, 3, 2, lf)
			D(17, 6, lf[3]); D(14, 7, lf[3])
			eye(13, 14); eye(17, 14)
			Dr(15, 18, 2, 1, SOCKET)
			Ln(5, 28, 27, 6, 0.9, w)
			P([25, 9, 30, 2, 28, 10], R["ash"], true)
			D(25, 8, lf[2]); D(24, 9, lf[3])
			Ln(19, 16, 21, 13, 1.1, b, true)
			Ln(12, 17, 15, 19, 1.1, b, true)
		"archer":
			# A bush-hooded sprout with a bent-branch bow and vine string.
			Ln(14, 25, 13, 29, 1.2, b); Ln(18, 25, 19, 29, 1.2, b)
			Dr(11, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([12, 17, 19, 17, 20, 26, 11, 26], b)
			E(15.5, 12, 7.5, 6.5, lf)
			E(10, 15, 3, 2.5, lf); E(21, 14, 2.5, 2.5, lf)
			D(18, 8, lf[3]); D(13, 9, lf[3]); D(20, 11, lf[3])
			Dr(13, 13, 6, 4, lf[0])
			eye(13, 14); eye(16, 14)
			path([24, 6, 27, 11, 28, 17, 27, 23, 24, 28], 0.9, w, true)
			for y in range(7, 28): D(23, y, R["cream"][2])
			Ln(13, 18, 28, 18, 0.5, w)
			P([28, 16, 31, 18, 28, 20], R["ash"])
			D(12, 17, lf[3]); D(12, 19, lf[3])
			Ln(19, 19, 23, 18, 1.0, b, true)
		"vine_lasher":
			# A mossy stump that lashes with flowering vines.
			Ln(13, 24, 12, 29, 1.6, b); Ln(18, 24, 19, 29, 1.6, b)
			Dr(10, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([9, 14, 21, 14, 22, 25, 8, 25], b)
			for y in range(17, 24, 2): D(11, y, b[1])
			E(15, 13, 7.5, 3.5, R["moss"])
			E(11, 15.5, 2.5, 1.5, R["moss"]); E(19.5, 16, 2, 1.5, R["moss"])
			E(17, 10.5, 1.5, 1.5, R["pink"]); D(17, 10, R["gold"][3])
			E(12, 11, 1.2, 1.2, R["pink"])
			eye(12, 18); eye(17, 18)
			Dr(14, 22, 3, 1, SOCKET)
			path([21, 19, 25, 15, 28, 16, 30, 20, 28, 24, 25, 23], 0.8, lf, true)
			E(26, 13.5, 1.6, 1, lf); E(30, 23, 1.3, 1, lf)
			path([9, 19, 5, 22, 3, 26], 0.8, lf)
			E(3, 27, 1.3, 1, lf)
		"tide_caller":
			# A willow treant whose fronds drip water; it calls a water orb.
			Ln(13, 24, 12, 29, 1.4, b); Ln(18, 24, 19, 29, 1.4, b)
			Dr(10, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([11, 12, 20, 12, 21, 25, 10, 25], b)
			eye(12, 15); eye(17, 15)
			Dr(14, 19, 3, 1, SOCKET)
			E(15.5, 8, 7.5, 4, R["willow"])
			for fx in [8, 10, 12, 19, 21, 23]:
				var len = 8 + (fx * 7) % 5
				Ln(fx, 9, fx + (0.5 if fx > 15 else -0.5), 9 + len, 0.7, R["willow"])
			D(9, 20, R["water"][3]); D(22, 21, R["water"][3])
			Ln(20, 17, 23, 15, 1.1, b, true)
			E(25.5, 12.5, 3.5, 3.5, R["water"], true)
			D(26, 11, R["water"][3]); D(27, 11, Color.WHITE)
			D(29, 8, R["water"][3]); D(22, 8, R["water"][2])
		"ember_sprout":
			# A charred little stump crowned with fire, glowing through its cracks.
			Ln(13, 25, 12, 29, 1.5, R["char"]); Ln(18, 25, 19, 29, 1.5, R["char"])
			Dr(10, 29, 3, 1, R["char"][1]); Dr(19, 29, 3, 1, R["char"][1])
			P([10, 14, 21, 14, 21, 26, 10, 26], R["char"])
			P([9, 14, 12, 3, 14, 9, 16, 1, 18, 8, 20, 4, 22, 14], R["fire"])
			P([12, 14, 14, 7, 16, 11, 18, 6, 19, 14], [R["fire"][2], R["fire"][3], R["fire"][3], Color("#fff6c0")])
			path([12, 22, 13, 20, 12, 18], 0.4, [R["fire"][2], R["fire"][2], R["fire"][2], R["fire"][2]])
			path([19, 24, 18, 21], 0.4, [R["fire"][2], R["fire"][2], R["fire"][2], R["fire"][2]])
			eye(12, 17, Color("#ffb347")); eye(17, 17, Color("#ffb347"))
			Dr(14, 21, 3, 1, R["fire"][1])
			Ln(21, 19, 24, 18, 1.3, R["char"], true)
			E(25, 17.5, 1.7, 1.7, R["fire"])
			D(26, 13, R["fire"][3]); D(8, 8, R["fire"][2]); D(24, 9, R["fire"][3])
		"frost_warden":
			# A stout frost-bark stump in ice armour, crowned with crystals,
			# braced behind a tall tower shield of ice.
			var fb = [Color("#22344a"), Color("#4a6a86"), Color("#7c9eb8"), Color("#b4d2e6")]
			Ln(12, 24, 11, 29, 1.8, fb); Ln(18, 24, 19, 29, 1.8, fb)
			Dr(9, 29, 4, 1, fb[1]); Dr(18, 29, 4, 1, fb[1])
			P([8, 12, 21, 12, 22, 25, 7, 25], fb)
			for y in range(15, 24, 3): D(10, y, fb[0])
			for y in range(14, 22, 3): D(19, y, fb[0])
			P([8, 12, 10, 4, 12, 12], R["ice"]); P([11, 12, 14.5, 1, 18, 12], R["ice"]); P([16, 12, 19, 5, 21, 12], R["ice"])
			D(14, 4, Color.WHITE); D(10, 7, R["ice"][3]); D(19, 8, R["ice"][3])
			Ln(8, 12.5, 21, 12.5, 0.9, R["snow"])
			E(8, 14, 3.2, 2.4, R["ice"], true); E(20.5, 14, 2.8, 2.4, R["ice"], true)
			eye(11, 16, Color("#9fe8ff")); eye(16, 16, Color("#9fe8ff"))
			Dr(13, 20, 3, 1, SOCKET)
			Ln(20, 18, 23, 19, 1.3, fb, true)
			P([22, 9, 29, 8, 30, 21, 26, 28, 22, 24], R["ice"], true)
			Ln(23, 10, 28.5, 9.5, 0.4, [R["ice"][3], R["ice"][3], R["ice"][3], Color.WHITE])
			for f in [[26, 17], [25, 17], [27, 17], [26, 16], [26, 18], [24, 15], [28, 19], [24, 19], [28, 15]]:
				D(f[0], f[1], Color.WHITE if f == [26, 17] else R["ice"][3])
			D(5, 27, R["snow"][3]); D(4, 23, R["snow"][2]); D(31, 26, R["snow"][3])
		"shade_twig":
			# A gnarled black twig-imp with thorn claws and violet eyes.
			Ln(14, 23, 11, 29, 1.0, R["shade"]); Ln(17, 23, 20, 29, 1.0, R["shade"])
			Dr(9, 29, 3, 1, R["shade"][1]); Dr(20, 29, 3, 1, R["shade"][1])
			path([16, 24, 15, 19, 16, 14, 15, 10], 3.0, R["shade"])
			Ln(13, 9, 9, 3, 0.8, R["shade"]); Ln(17, 9, 21, 2, 0.8, R["shade"]); Ln(19, 6, 23, 6, 0.6, R["shade"])
			Ln(11, 6, 8, 7, 0.6, R["shade"])
			eye(13, 12, Color("#c08cff")); eye(16, 12, Color("#c08cff"))
			D(14, 16, SOCKET); D(15, 16, SOCKET); D(16, 16, SOCKET)
			path([13, 16, 9, 19, 7, 23], 0.8, R["shade"])
			path([18, 16, 22, 18, 26, 17], 1.0, R["shade"], true)
			Ln(26, 17, 30, 14, 0.6, R["shade"]); Ln(26, 17, 30, 18, 0.6, R["shade"]); Ln(26, 17, 29, 21, 0.6, R["shade"])
			D(5, 12, R["dark"][3]); D(25, 9, R["dark"][2]); D(8, 26, R["dark"][2])
		"scout":
			# A lean twig runner with a thistle-bloom head, darting in with a thorn knife.
			var th = R["thistle"]
			Ln(13, 23, 9, 28, 1.2, b); Ln(17, 23, 21, 28, 1.2, b)
			Dr(7, 29, 3, 1, b[1]); Dr(21, 29, 3, 1, b[1])
			Ln(21, 28, 21, 29, 1.0, b)
			path([11, 16, 7, 15, 3, 17], 0.8, lf)
			Ln(12, 17, 8, 21, 1.0, b)
			P([11, 14, 18, 14, 19, 24, 11, 24], b)
			for y in range(16, 23, 3): D(13, y, b[1])
			P([9.5, 12, 10.5, 5, 12.5, 9, 14, 3, 15.5, 8, 17, 4, 18, 9, 20.5, 6, 20, 12], th)
			D(14, 5, th[3]); D(17, 6, th[3]); D(11, 7, th[3])
			E(14.8, 12.5, 5.5, 2, lf)
			D(12, 12, lf[3]); D(17, 12, lf[0])
			eye(12, 16); eye(16, 16)
			Dr(14, 20, 2, 1, SOCKET)
			Ln(18, 18, 22, 17, 1.0, b, true)
			P([22, 15.5, 29.5, 16.5, 22, 18.5], R["ash"], true)
			D(24, 16, R["ash"][3]); D(26, 16, R["ash"][3])
		"acorn_slinger":
			# A stump in an acorn-cap hat, whirling a sling with an acorn in it.
			var sh = R["shell"]
			Ln(13, 24, 12, 29, 1.5, b); Ln(18, 24, 19, 29, 1.5, b)
			Dr(10, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([10, 13, 20, 13, 21, 25, 9, 25], b)
			for y in range(16, 24, 2): D(11, y, b[1])
			E(15, 11.5, 7, 3.2, sh)
			for x in range(9, 21, 2): D(x, 11, sh[0]); D(x + 1, 10, sh[3])
			Dr(8, 13, 15, 1, sh[0])
			Ln(15, 8, 16, 5, 0.6, w)
			eye(12, 16); eye(16, 16)
			Dr(13, 20, 3, 1, SOCKET)
			E(9, 22, 2.6, 2.6, R["fur"], true)
			D(8, 21, R["fur"][3]); E(8.5, 19.5, 1.2, 0.8, sh)
			Ln(19, 17, 23, 13, 1.1, b, true)
			path([23, 13, 24, 9, 27, 6], 0.4, R["cream"])
			E(28, 8.5, 2.1, 2.6, R["fur"], true)
			E(28, 6.2, 2.4, 1.2, sh)
			D(28, 5, w[1]); D(29, 8, R["fur"][3]); D(28, 11, R["fur"][0])
			D(25, 3, R["cream"][3]); D(31, 9, R["cream"][2]); D(22, 5, R["cream"][2])
		"drummer":
			# A leafy-topped stump beating a hollow-log drum slung at its belly.
			Ln(13, 25, 12, 29, 1.6, b); Ln(18, 25, 19, 29, 1.6, b)
			Dr(10, 29, 3, 1, b[1]); Dr(19, 29, 3, 1, b[1])
			P([10, 11, 21, 11, 22, 24, 9, 24], b)
			E(15.5, 11, 6, 2, w)
			D(14, 11, w[1]); D(17, 11, w[1])
			Ln(15, 10, 13, 6, 0.6, lf); E(12, 6, 2, 1.3, lf); E(17.5, 7.5, 2.2, 1.3, lf)
			eye(12, 14); eye(16, 14)
			Dr(14, 17, 2, 2, SOCKET)
			P([12, 21, 25, 21, 24, 28, 13, 28], R["shell"], true)
			for x in [15, 18, 21]:
				for y in range(23, 28): D(x, y, R["shell"][0])
			path([13, 24, 15, 27, 18, 24, 21, 27, 24, 24], 0.4, R["gold"])
			E(18.5, 21, 6.5, 1.5, R["cream"], true)
			Ln(10, 16, 7, 12, 1.0, b, true)
			Ln(7, 12, 12, 6, 0.6, w); E(12.5, 5.5, 1.2, 1.2, R["fur"])
			Ln(21, 15, 25, 13, 1.0, b, true)
			Ln(25, 13, 22, 19.5, 0.6, w); E(21.5, 20, 1.2, 1.2, R["fur"])
			D(27, 15, R["gold"][3]); D(5, 9, R["gold"][3]); D(28, 11, R["gold"][2])
		"sap_mender":
			# A hooded sapling in a moss robe, raising a staff tipped with glowing sap.
			var mo = R["moss"]
			var am = R["gold"]
			P([10, 14, 20, 14, 23, 29, 7, 29], mo)
			for y in range(18, 29, 2): D(11, y, mo[0]); D(18, y + 1, mo[0])
			Ln(9.5, 21, 21, 21, 0.6, w)
			E(15, 11.5, 6, 5.5, mo)
			E(16.8, 12.5, 3.4, 3.2, b)
			eye(15, 12); eye(18, 12)
			D(17, 15, SOCKET)
			E(12.5, 6.5, 2.2, 1.3, lf); E(17, 6.2, 1.8, 1.2, lf); D(13, 6, lf[3])
			Ln(25, 29, 25, 8, 0.8, w, true)
			Ln(19, 18, 24, 18, 1.2, mo, true)
			E(24.5, 18, 1.5, 1.5, b, true)
			P([25, 1, 28, 5.5, 27, 8.5, 23, 8.5, 22, 5.5], am, true)
			D(24, 4, am[3]); D(25, 3, Color.WHITE)
			for f in [[29, 2], [20, 3], [29, 10], [5, 12], [4, 20], [27, 22]]:
				D(f[0], f[1], R["leaf"][3])
			D(5, 11, R["leaf"][2]); D(5, 13, R["leaf"][2]); D(4, 12, R["leaf"][2]); D(6, 12, R["leaf"][2])
		"bramble_knight":
			# A bark knight in a stone helm, wrapped in thorny brambles, swinging a thorn mace.
			var pn = R["pine"]
			var bo = R["bone"]
			Ln(12, 24, 11, 29, 1.8, b); Ln(18, 24, 19, 29, 1.8, b)
			Dr(9, 29, 4, 1, b[1]); Dr(18, 29, 4, 1, b[1])
			E(7.5, 19, 4.5, 5.5, pn, true)
			for f in [[7, 13], [3, 17], [3, 21], [7, 25], [11, 15]]: D(f[0], f[1], bo[2])
			D(7, 19, R["fire"][1]); D(6, 18, R["fire"][2])
			P([9, 11, 21, 11, 22, 25, 8, 25], b, true)
			for y in range(15, 24, 3): D(20, y, b[1])
			path([9, 16, 13, 19, 17, 16, 21, 19], 0.7, pn)
			for f in [[11, 16], [15, 18], [19, 16], [13, 21]]: D(f[0], f[1], bo[2])
			D(13, 19, R["fire"][1]); D(18, 18, R["fire"][1])
			P([9, 3, 19, 3, 21, 12, 8, 12], R["ash"])
			Dr(12, 7, 9, 2, SOCKET)
			D(14, 7, GLOW); D(18, 7, GLOW)
			Ln(14, 3, 12, 0.5, 0.6, pn); Ln(12, 1, 9, 1, 0.5, pn); D(11, 0, bo[2])
			Ln(21, 17, 24, 18, 1.3, b, true)
			Ln(24, 22, 27, 11, 1.0, w, true)
			E(27.5, 8.5, 2.8, 2.8, pn, true)
			for f in [[27, 4], [31, 8], [24, 7], [30, 5], [30, 12], [25, 11]]: D(f[0], f[1], bo[2])
		"elder_oak":
			# An ancient oak treant under a broad crown, its branch arms gnarled into a club.
			var sh = R["shell"]
			taper([11, 24, 8, 28, 4, 30], 2.4, 0.6, b); taper([20, 24, 23, 28, 28, 30], 2.4, 0.6, b)
			Ln(15.5, 25, 15.5, 30, 1.8, b)
			taper([9, 16, 5, 19, 3, 24], 1.9, 0.7, b)
			E(3, 25, 1.8, 1.3, lf)
			P([9, 9, 22, 9, 24, 27, 7, 27], b)
			for g in [[10, 13], [22, 14], [9, 20], [22, 21]]:
				for y in range(g[1], g[1] + 5, 2): D(g[0], y, b[0])
			E(15.5, 5.5, 11, 4.5, lf); E(6, 8, 4.5, 3.2, lf); E(25, 7.5, 5, 3.2, lf); E(15, 2.5, 6.5, 2.3, lf)
			for f in [[13, 2], [19, 3], [9, 5], [24, 5], [16, 5], [5, 7]]: D(f[0], f[1], lf[3])
			E(8.5, 10.5, 1.2, 1.5, sh); E(21, 10.5, 1.2, 1.5, sh)
			Ln(10, 13.5, 20, 13.5, 0.7, R["bark"])
			eye(11, 15); eye(17, 15)
			Dr(12, 20, 6, 1, SOCKET)
			E(15, 23.5, 4.5, 2, R["moss"])
			D(13, 24, R["moss"][3]); D(17, 23, R["moss"][3])
			taper([22, 17, 26, 16, 29, 11], 2.2, 1.2, b, true)
			E(29, 8.5, 2.6, 2.2, lf, true)
			D(29, 7, lf[3]); D(30, 13, b[0])
	outline()

# --- enemies (face left) -----------------------------------------------------
func enemy(name: String):
	match name:
		"thorn_beetle":
			for lx in [12, 17, 22]:
				Ln(lx, 24, lx - 2, 29, 0.6, R["shade"])
			E(9, 22, 4, 3.5, R["shade"])
			P([7, 20, 1, 14, 6, 22], R["bone"], true)
			E(18, 20, 9, 6.5, R["beetle"])
			Ln(18, 14, 18, 26, 0.4, [R["beetle"][0], R["beetle"][0], R["beetle"][0], R["beetle"][0]])
			for t in [[13, 15], [21, 14], [25, 18], [15, 20]]:
				P([t[0] - 1, t[1] + 1, t[0], t[1] - 3, t[0] + 1, t[1] + 1], R["bone"])
			D(21, 17, R["beetle"][3]); D(23, 18, R["beetle"][3])
			aeye(7, 21, Color("#ffd447"))
		"burrow_rabbit":
			E(25, 21, 2.5, 2.5, R["cream"])
			E(18, 22, 7.5, 5.5, R["fur"])
			Ln(13, 15, 11, 6, 1.3, R["fur"]); Ln(15, 15, 16, 6, 1.3, R["fur"], true)
			D(11, 9, R["pink"][2]); D(11, 10, R["pink"][2]); D(16, 9, R["pink"][2])
			E(11, 18, 4.5, 4, R["fur"], true)
			E(9, 20, 2, 1.5, R["cream"])
			D(7, 19, R["pink"][1])
			aeye(10, 16)
			E(13, 27, 2.5, 1.2, R["fur"], true); E(21, 27, 3, 1.3, R["fur"])
			D(4, 28, R["fur"][1]); D(27, 29, R["fur"][1]); D(6, 26, R["fur"][2])
		"spring_frog":
			E(22, 24, 5, 3.5, R["frog"])
			E(16, 21, 9, 6, R["frog"])
			E(11, 15, 2.8, 2.8, R["frog"]); E(17, 15, 2.8, 2.8, R["frog"])
			D(10, 15, Color("#1a1010")); D(11, 15, Color("#1a1010")); D(10, 14, Color.WHITE)
			D(16, 15, Color("#1a1010")); D(17, 15, Color("#1a1010")); D(16, 14, Color.WHITE)
			Ln(8, 21, 15, 22, 0.4, [R["frog"][0], R["frog"][0], R["frog"][0], R["frog"][0]])
			E(14, 24, 4, 2.5, R["cream"])
			Ln(10, 25, 7, 28, 1.0, R["frog"], true); Dr(5, 28, 4, 1, R["frog"][2])
			Dr(23, 28, 6, 1, R["frog"][2])
			D(20, 18, R["frog"][1]); D(23, 21, R["frog"][1]); D(18, 20, R["frog"][1])
		"ripple_sprite":
			E(16, 27, 7, 1.5, [R["water"][2], R["water"][2], R["water"][3], R["water"][3]])
			P([16, 4, 23, 17, 21, 23, 16, 25, 11, 23, 9, 17], R["water"])
			E(16, 18, 6, 6.5, R["water"])
			D(13, 16, Color("#0e2040")); D(13, 17, Color("#0e2040")); D(17, 16, Color("#0e2040")); D(17, 17, Color("#0e2040"))
			D(13, 16, Color.WHITE); D(17, 16, Color.WHITE)
			Dr(14, 20, 2, 1, Color("#0e2040"))
			D(19, 13, Color.WHITE); D(19, 14, R["water"][3])
			Ln(9, 18, 5, 15, 0.7, R["water"]); Ln(23, 18, 27, 15, 0.7, R["water"])
			D(5, 10, R["water"][3]); D(27, 8, R["water"][3]); D(24, 5, R["water"][2])
		"cinder_lizard":
			path([22, 22, 27, 21, 30, 17, 29, 14], 1.5, R["lizard"])
			Ln(19, 24, 21, 28, 1.0, R["lizard"]); Dr(20, 28, 3, 1, R["lizard"][1])
			E(17, 22, 8, 4, R["lizard"])
			E(8, 20, 4.5, 3, R["lizard"])
			D(4, 21, R["lizard"][0]); Dr(4, 22, 5, 1, R["lizard"][0])
			Ln(11, 24, 9, 28, 1.0, R["lizard"], true); Dr(7, 28, 3, 1, R["lizard"][1])
			for sx in [12, 16, 20, 24]:
				P([sx - 1, 19, sx, 15, sx + 1, 19], R["fire"])
			E(16, 24, 5, 1.5, [R["fire"][2], R["fire"][2], R["fire"][3], R["fire"][3]])
			aeye(7, 19, Color("#ffd447"))
		"ash_moth":
			P([17, 12, 25, 2, 30, 8, 27, 16], R["ash"]); P([17, 16, 27, 18, 25, 25, 19, 22], R["ash"])
			E(25, 9, 1.8, 1.8, R["fire"]); E(23, 20, 1.3, 1.3, R["fire"])
			Ln(15, 11, 16, 23, 1.8, R["char"])
			E(13.5, 9.5, 2.2, 2.2, R["char"])
			path([12, 8, 9, 4, 6, 4], 0.4, R["char"]); path([14, 7, 13, 3, 11, 1], 0.4, R["char"])
			P([15, 13, 7, 4, 3, 10, 8, 18], R["ash"], true); P([15, 17, 7, 20, 8, 26, 13, 23], R["ash"], true)
			E(7, 10, 1.8, 1.8, R["fire"]); E(10, 22, 1.2, 1.2, R["fire"])
			D(5, 9, R["ash"][3]); D(26, 6, R["ash"][3])
			aeye(12, 9, Color("#ff8a3d"), Color("#ffd166"))
			D(28, 27, R["fire"][3]); D(4, 27, R["fire"][2]); D(30, 2, R["fire"][2])
		"frost_wolf":
			path([25, 18, 29, 13, 29, 9], 1.6, R["wolf"])
			Ln(23, 23, 24, 29, 1.0, R["wolf"]); Ln(13, 23, 12, 29, 1.0, R["wolf"])
			E(19, 19, 8.5, 5, R["wolf"])
			P([2, 18, 9, 13, 11, 8, 13, 13, 15, 22, 7, 22], R["wolf"])
			P([10, 9, 11, 4, 13, 11], R["wolf"])
			for sx in [14, 18, 22]:
				P([sx - 1, 16, sx + 1, 11, sx + 2, 16], R["ice"])
			Ln(20, 23, 21, 29, 1.0, R["wolf"], true); Ln(10, 23, 9, 29, 1.0, R["wolf"], true)
			D(2, 18, Color("#1a1010")); D(3, 18, Color("#1a1010"))
			D(8, 16, Color("#2a6fa0")); D(8, 15, Color("#9fe8ff"))
			Dr(3, 20, 4, 1, R["wolf"][0])
		"icicle_bat":
			P([16, 13, 3, 8, 5, 13, 2, 17, 7, 18, 9, 23, 13, 19], R["ice"])
			P([16, 13, 29, 8, 27, 13, 30, 17, 25, 18, 23, 23, 19, 19], R["ice"])
			E(16, 16, 4, 5, R["bat"])
			P([13, 12, 13, 7, 15, 11], R["bat"]); P([17, 11, 19, 7, 19, 12], R["bat"])
			D(14, 15, Color("#9fe8ff")); D(17, 15, Color("#9fe8ff"))
			D(15, 18, Color.WHITE); D(16, 18, Color.WHITE)
			for ix in [6, 11, 21, 26]:
				Ln(ix, 19, ix, 23, 0.4, R["ice"])
		"cave_bat":
			P([16, 13, 3, 9, 5, 14, 2, 18, 7, 18, 10, 23, 13, 19], R["bat"])
			P([16, 13, 29, 9, 27, 14, 30, 18, 25, 18, 22, 23, 19, 19], R["bat"])
			E(16, 16, 4, 5, R["slime"])
			P([13, 12, 13, 7, 15, 11], R["slime"]); P([17, 11, 19, 7, 19, 12], R["slime"])
			D(14, 15, Color("#ff5a5a")); D(17, 15, Color("#ff5a5a"))
			D(15, 18, Color.WHITE); D(17, 18, Color.WHITE)
			D(9, 13, R["bat"][3]); D(23, 13, R["bat"][3])
		"shadow_slime":
			E(16, 21, 11, 8, R["slime"])
			E(16, 13, 5, 4, R["slime"])
			Ln(8, 27, 8, 30, 0.8, R["slime"]); Ln(22, 27, 22, 29, 0.8, R["slime"])
			E(17, 27, 9, 2, R["slime"])
			D(12, 19, Color("#ffd447")); D(13, 19, Color("#ffd447")); D(12, 20, Color("#7a5a10")); D(13, 20, Color("#7a5a10"))
			D(18, 19, Color("#ffd447")); D(19, 19, Color("#ffd447")); D(18, 20, Color("#7a5a10")); D(19, 20, Color("#7a5a10"))
			Dr(13, 23, 6, 1, R["slime"][0]); D(14, 24, Color.WHITE); D(17, 24, Color.WHITE)
			D(20, 12, R["slime"][3]); D(21, 13, R["slime"][3]); D(22, 17, R["slime"][3])
		"thornback_boar":
			Ln(22, 23, 23, 29, 1.2, R["boar"]); Ln(12, 23, 11, 29, 1.2, R["boar"])
			E(18, 19, 9.5, 6, R["boar"])
			P([3, 20, 8, 13, 12, 13, 14, 24, 6, 24], R["boar"])
			P([9, 13, 10, 9, 12, 13], R["boar"])
			for sx in [13, 17, 21, 25]:
				P([sx - 1, 15, sx, 9, sx + 2, 14], R["beetle"])
			E(4, 21, 2, 2, R["pink"])
			D(3, 21, R["pink"][0]); D(4, 22, R["pink"][0])
			Ln(7, 23, 5, 19, 0.6, R["bone"])
			Ln(19, 23, 20, 29, 1.2, R["boar"], true); Ln(9, 23, 8, 29, 1.2, R["boar"], true)
			aeye(8, 17, Color("#ff5a3a"))
		"pollen_wisp":
			E(9, 14, 4, 2.5, R["leaf"]); E(23, 14, 4, 2.5, R["leaf"])
			E(16, 17, 7, 7, R["pollen"])
			for a in 8:
				var v = Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0))
				D(int(16 + v.x * 8), int(17 + v.y * 8), R["pollen"][2])
			Dr(13, 16, 2, 2, Color("#5a4008")); Dr(17, 16, 2, 2, Color("#5a4008"))
			D(14, 16, Color.WHITE); D(18, 16, Color.WHITE)
			D(15, 20, Color("#5a4008")); D(16, 20, Color("#5a4008"))
			D(5, 24, R["pollen"][3]); D(26, 25, R["pollen"][2]); D(24, 6, R["pollen"][3]); D(8, 6, R["pollen"][2])
		"snapjaw_crab":
			for lx in [14, 18, 22]:
				Ln(lx, 23, lx + 3, 28, 0.6, R["crab"])
			E(19, 20, 9, 5.5, R["crab"])
			D(16, 15, Color("#1a1010")); D(20, 15, Color("#1a1010"))
			Ln(16, 16, 16, 14, 0.4, R["crab"]); Ln(20, 16, 20, 14, 0.4, R["crab"])
			D(16, 13, Color("#1a1010")); D(20, 13, Color("#1a1010")); D(16, 12, Color.WHITE)
			Ln(12, 21, 8, 21, 1.0, R["crab"], true)
			P([2, 15, 8, 14, 10, 19, 8, 24, 2, 23, 5, 19], R["crab"], true)
			Dr(2, 19, 4, 1, R["crab"][0])
			D(22, 17, R["crab"][3]); D(25, 19, R["crab"][3])
		"bubble_eel":
			P([27, 25, 31, 21, 31, 29], R["eel"])
			path([28, 25, 25, 23, 21, 23, 17, 25, 13, 25, 10, 22, 8, 18, 7, 15], 2.5, R["eel"])
			for f in [[22, 21], [17, 23], [12, 22]]:
				P([f[0] - 2, f[1], f[0], f[1] - 3, f[0] + 1, f[1]], R["eel"])
			path([25, 26, 21, 25, 17, 27, 13, 27, 10, 24], 0.6, [R["eel"][3], R["eel"][3], R["eel"][3], R["eel"][3]])
			E(6, 13, 3.5, 3, R["eel"], true)
			aeye(5, 12)
			Dr(3, 14, 3, 1, R["eel"][0])
			E(4, 7, 1.5, 1.5, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
			E(9, 4, 1, 1, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
			E(12, 8, 1.2, 1.2, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
		# --- wild elementals: feral creatures of each element (red eyes, facing left) ---
		"wild_vine_lasher":
			# a snapping bulb plant on root legs, lashing thorny vines
			Ln(14, 24, 10, 30, 1.0, R["bark"]); Ln(20, 24, 23, 30, 1.0, R["bark"]); Ln(17, 25, 17, 30, 0.8, R["bark"], true)
			path([22, 16, 27, 12, 29, 7, 26, 3], 0.9, R["moss"])
			path([23, 21, 28, 22, 30, 26], 0.9, R["moss"])
			E(17, 18, 8, 7, R["leaf"])
			P([8, 13, 16, 18, 8, 23], R["pink"], true)
			P([8, 15, 13, 18, 8, 21], [R["shade"][0], R["shade"][1], R["shade"][1], R["shade"][2]])
			for t in [[9, 14], [11, 15], [9, 22], [11, 21], [13, 17]]:
				D(t[0], t[1], R["bone"][3])
			P([14, 12, 17, 5, 20, 12], R["moss"], true); P([19, 13, 25, 8, 23, 15], R["moss"], true)
			for th in [[27, 11], [29, 6], [28, 23], [25, 4]]:
				D(th[0], th[1], R["bone"][2])
			D(15, 13, Color("#ff3b2f")); D(15, 12, Color("#ffb0a0")); D(18, 14, Color("#ff3b2f"))
		"wild_tide_caller":
			# a conch-shell creature on tentacle legs, foam bubbling from its shell
			for lx in [11, 15, 19, 23]:
				path([lx, 23, lx - 2, 27, lx - 1, 30], 0.8, R["eel"])
			P([19, 13, 30, 5, 26, 17], R["cream"])
			E(18, 18, 9, 7, R["pink"], true)
			path([13, 19, 16, 14, 22, 14, 25, 18, 22, 22, 17, 21], 0.45, [R["pink"][0], R["pink"][0], R["pink"][0], R["pink"][0]])
			D(27, 9, R["pink"][1]); D(25, 12, R["pink"][1])
			E(10, 20, 4, 4, R["water"], true)
			D(8, 19, Color("#ff3b2f")); D(8, 18, Color("#ffb0a0")); D(11, 19, Color("#ff3b2f"))
			Dr(8, 22, 3, 1, R["water"][0])
			E(5, 12, 1.4, 1.4, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
			E(8, 8, 1.1, 1.1, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
			E(4, 6, 0.9, 0.9, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
		"wild_ember_sprout":
			# a living lump of coal, cracked with fire, flames for hair
			Ln(12, 24, 10, 30, 1.7, R["char"]); Ln(20, 24, 22, 30, 1.7, R["char"])
			Ln(23, 17, 27, 24, 1.5, R["char"])
			E(16, 19, 8, 7, R["char"])
			E(15, 11, 5.5, 4.5, R["char"], true)
			# flame horns, and a molten core showing through the chest
			P([10, 10, 7, 2, 12, 8], R["fire"]); P([19, 9, 23, 1, 21, 10], R["fire"])
			E(16, 19, 2.5, 2.5, [R["fire"][1], R["fire"][2], R["fire"][3], Color("#fff1a8")])
			Ln(9, 17, 4, 24, 1.5, R["char"], true)
			for c in [[14, 16], [15, 17], [15, 18], [16, 19], [16, 20], [18, 21], [19, 21], [12, 21], [13, 22], [20, 16], [21, 15]]:
				D(c[0], c[1], R["fire"][2])
			D(15, 18, R["fire"][3]); D(19, 21, R["fire"][3]); D(4, 24, R["fire"][2]); D(27, 24, R["fire"][2])
			D(11, 11, Color("#ff3b2f")); D(11, 10, Color("#ffd166")); D(14, 11, Color("#ff3b2f"))
		"wild_frost_warden":
			# an angular sentinel of ice crystal with jagged shoulders
			P([11, 24, 14, 24, 12, 30], R["ice"]); P([18, 24, 21, 24, 20, 30], R["ice"])
			P([8, 13, 3, 5, 11, 10], R["ice"]); P([24, 13, 29, 4, 22, 10], R["ice"])
			P([16, 4, 24, 13, 22, 26, 10, 26, 8, 13], R["ice"], true)
			Ln(16, 5, 16, 25, 0.4, [R["ice"][3], R["ice"][3], R["ice"][3], R["ice"][3]])
			Ln(9, 13, 23, 13, 0.4, [R["ice"][0], R["ice"][0], R["ice"][0], R["ice"][0]])
			Dr(10, 15, 5, 1, Color("#ff3b2f")); D(10, 15, Color("#ffb0a0"))
			D(20, 9, Color.WHITE); D(5, 6, Color.WHITE); D(27, 5, Color.WHITE)
		"wild_shade_twig":
			# a hooded wraith in a tattered cloak, drifting above the ground
			P([16, 3, 25, 13, 27, 27, 23, 24, 19, 28, 15, 24, 11, 28, 8, 24, 7, 13], R["shade"])
			Ln(9, 17, 3, 21, 0.7, R["dark"]); Ln(23, 17, 28, 21, 0.7, R["dark"])
			D(2, 22, R["dark"][3]); D(4, 22, R["dark"][3]); D(28, 22, R["dark"][3])
			E(14, 11, 4.5, 4, [Color("#08050c"), Color("#08050c"), Color("#100a18"), Color("#1a1226")], true)
			D(12, 11, Color("#ff3b2f")); D(12, 10, Color("#ffb0a0")); D(15, 11, Color("#ff3b2f"))
			for w in [[26, 6], [5, 8], [29, 14], [22, 2]]:
				D(w[0], w[1], R["dark"][3])
	outline()

# --- bosses (48x48, face left) --------------------------------------------------
func boss(name: String):
	match name:
		"bramble_hare":
			# Thornmaw: a vine monster of knotted creepers rising from its roots, a
			# great flytrap head gaping to the left and thorny tendrils lashing out.
			var vine = R["leaf"]
			var dvine = [R["pine"][0], R["pine"][0], R["pine"][1], R["pine"][2]]
			var maw = [Color("#3a0812"), Color("#8a1830"), Color("#d04060"), Color("#ff9ab0")]
			E(24, 45, 16, 2, [R["shade"][1], R["shade"][1], R["shade"][2], R["shade"][2]])
			# roots clawing into the ground
			for rt in [[24, 40, 12, 45, 8, 44], [26, 40, 36, 45, 42, 44], [24, 41, 22, 46], [27, 41, 30, 46]]:
				path(rt, 1.1, dvine)
			# far tendril, in shadow, curling up behind
			path([30, 26, 38, 20, 42, 12, 39, 6, 35, 7], 1.3, dvine, true)
			# the knotted body: strands twisting up to the neck
			for st in [[20, 42, 27, 35, 21, 28, 24, 20], [29, 42, 22, 35, 28, 28, 22, 21], [25, 42, 31, 34, 25, 26, 23, 19]]:
				path(st, 1.5, vine, true)
			# small tendrils curling off the back
			path([29, 33, 35, 32, 38, 28, 36, 26], 0.8, vine, true)
			path([27, 38, 34, 39, 37, 36], 0.8, vine, true)
			for kn in [[23, 30, 26, 37], [27, 26, 22, 33]]:
				Ln(kn[0], kn[1], kn[2], kn[3], 0.5, dvine)
			# near tendril reaching forward, with a thorny tip
			path([22, 31, 14, 34, 7, 32, 4, 27, 6, 24], 1.4, vine, true)
			for th in [[13, 35, 12, 37], [8, 33, 7, 35], [4, 27, 2, 26], [6, 24, 5, 22], [40, 14, 43, 14], [38, 20, 40, 22]]:
				Ln(th[0], th[1], th[2], th[3], 0.45, R["bone"])
			# leaves along the body
			for lf in [[30, 30, 1], [19, 36, -1], [31, 38, 1], [20, 25, -1]]:
				P([lf[0], lf[1], lf[0] + lf[2] * 5, lf[1] - 3, lf[0] + lf[2] * 4, lf[1] + 1], R["moss"], true)
			# the flytrap head, jaws open to the left
			E(14, 20.5, 8, 4.2, maw, true)
			P([24, 19, 20, 9, 12, 8, 4, 11, 3, 16, 12, 17], vine, true)
			P([24, 22, 12, 23, 4, 25, 6, 29, 14, 30, 22, 27], vine, true)
			E(14, 21, 6.5, 2.4, [maw[0], maw[0], maw[1], maw[1]])
			# teeth along both jaws
			for x in range(5, 21, 3):
				D(x, 17, R["bone"][3]); D(x, 18, R["bone"][2])
				D(x + 1, 24, R["bone"][3]); D(x + 1, 23, R["bone"][2])
			# spines along the trap's rims
			for sp in [[5, 11, 2, 9], [4, 14, 1, 13], [8, 9, 6, 6], [5, 26, 2, 27], [6, 29, 3, 31], [10, 30, 9, 33]]:
				Ln(sp[0], sp[1], sp[2], sp[3], 0.45, R["moss"])
			# drool and a glowing eye on the upper jaw
			D(9, 25, Color("#b8f06a")); D(9, 26, Color("#e8ff6a"))
			Dr(16, 11, 3, 2, SOCKET); D(16, 11, Color("#e8ff6a")); D(17, 11, Color("#b8e040"))
			# a crest of thorns and a blossom on top of the head
			for cr in [[13, 8, 11, 4], [17, 8, 17, 3], [21, 10, 24, 6]]:
				Ln(cr[0], cr[1], cr[2], cr[3], 0.6, R["bone"])
			E(22, 14, 2, 2, R["pink"], true); D(22, 14, Color("#ffd447"))
			for f in [[3, 6], [44, 26], [33, 3], [2, 38], [45, 36]]:
				D(f[0], f[1], Color("#e8ff6a"))
		"mossback_turtle":
			Ln(16, 36, 14, 43, 2.2, R["frog"]); Ln(34, 36, 36, 43, 2.2, R["frog"])
			E(26, 30, 15, 10, R["shell"])
			for s in [[21, 27], [29, 25], [33, 32], [23, 34]]:
				E(s[0], s[1], 3.5, 2.5, R["shell"], true)
			E(26, 22, 12, 4, R["moss"])
			Ln(27, 21, 28, 12, 1.0, R["bark"])
			E(28, 10, 5, 3.5, R["leaf"]); E(24, 12, 3, 2, R["leaf"]); E(32, 12, 3, 2, R["leaf"])
			E(8, 30, 5, 4.5, R["frog"])
			Ln(12, 31, 15, 32, 2.6, R["frog"])
			aeye(6, 28)
			Dr(3, 32, 4, 1, R["frog"][0])
			Ln(21, 37, 20, 44, 2.2, R["frog"], true); Ln(30, 38, 31, 44, 2.2, R["frog"], true)
			D(36, 23, R["moss"][3]); D(18, 24, R["pink"][2])
		"magma_salamander":
			path([34, 32, 41, 30, 45, 24, 44, 19], 2.4, R["rock"])
			Ln(31, 35, 34, 43, 1.8, R["rock"]); Dr(32, 43, 5, 1, R["rock"][1])
			# basalt spines along the back, rooted in the body and leaning back,
			# with magma welling up inside them to white-hot tips
			var spines = []
			for i in 6:
				var sx = 14.5 + i * 4.0
				var top = 31.0 - 6.5 * sqrt(maxf(0.0, 1.0 - pow((sx - 25.0) / 12.0, 2)))
				var h = [3.0, 4.5, 6.0, 6.5, 5.0, 3.5][i]
				spines.append([sx, top + 2.0, Vector2(sx + 1.6, top - h)])
				P([sx - 3.0, top + 2.5, sx + 1.6, top - h, sx + 3.0, top + 2.5], R["rock"])
			E(25, 31, 12, 6.5, R["rock"])
			E(10, 28, 7, 5, R["rock"])
			for sp in spines:
				var base = Vector2(sp[0], sp[1])
				var n = int(ceil(base.distance_to(sp[2])))
				for k in range(1, n):
					var q = base.lerp(sp[2], float(k) / n)
					var t = float(k) / n
					if t > 0.3:
						D(int(q.x), int(q.y), R["fire"][0] if t < 0.55 else (R["fire"][1] if t < 0.75 else (R["fire"][2] if t < 0.9 else R["fire"][3])))
			# a molten seam along the spine line, cooling into the hide
			for x in range(13, 38):
				var top = 31.0 - 6.5 * sqrt(maxf(0.0, 1.0 - pow((x - 25.0) / 12.0, 2)))
				var y = int(top) + 2
				if opaque(x, y):
					var near = false
					for sp in spines:
						near = near or absf(x - sp[0]) < 1.5
					D(x, y, R["fire"][1] if near else R["fire"][0])
			path([16, 29, 20, 32, 25, 29, 30, 33, 34, 30], 0.6, R["fire"])
			path([6, 27, 10, 29, 13, 26], 0.5, R["fire"])
			path([40, 28, 43, 23], 0.5, R["fire"])
			Dr(4, 31, 8, 1, R["fire"][1])
			Ln(16, 35, 13, 43, 1.8, R["rock"], true); Dr(10, 43, 5, 1, R["rock"][1])
			aeye(9, 26, Color("#ffd447"), Color("#fff6c0"))
			D(4, 22, R["fire"][3]); D(20, 14, R["fire"][2]); D(30, 15, R["fire"][3])
		"rime_elk":
			# A spirit elk of faceted ice: crystal legs, a glowing heart and great
			# crystalline antlers, frost glittering around it.
			var ice = R["ice"]
			var core = [Color("#4aa3c9"), Color("#9fe8ff"), Color("#e8fbff"), Color.WHITE]
			for leg in [[15, 30, 14, 45], [20, 31, 21, 45], [33, 30, 33, 45], [38, 29, 39, 45]]:
				P([leg[0] - 2, leg[1], leg[0] + 2, leg[1], leg[2] + 0.8, leg[3], leg[2] - 0.8, leg[3]], ice)
			P([12, 20, 26, 17, 42, 20, 44, 28, 36, 33, 16, 32], ice, true)
			for fl in [[26, 17, 30, 32], [12, 20, 36, 33], [42, 20, 22, 32], [16, 32, 34, 18]]:
				Ln(fl[0], fl[1], fl[2], fl[3], 0.35, [ice[3], ice[3], ice[3], ice[3]])
			E(28, 25, 3, 3, core)
			D(28, 24, Color.WHITE)
			P([9, 11, 16, 12, 19, 23, 12, 24], ice, true)
			P([2, 15, 9, 10, 13, 16, 6, 19], ice, true)
			Ln(9, 11, 11, 23, 0.35, [ice[3], ice[3], ice[3], ice[3]])
			D(7, 14, core[1]); D(8, 14, Color.WHITE)
			# crystalline antlers
			for sh in [[10, 10, 6, 0, 2.2], [12, 10, 16, -1, 2.2], [7, 6, 1, 3, 1.6], [14, 5, 21, 3, 1.6], [9, 4, 11, -1, 1.2]]:
				var a = Vector2(sh[0], sh[1])
				var b = Vector2(sh[2], sh[3])
				var n = (b - a).orthogonal().normalized() * sh[4]
				P([a.x + n.x, a.y + n.y, b.x, b.y, a.x - n.x, a.y - n.y], [ice[1], ice[2], ice[3], Color.WHITE], true)
			for sp in [[44, 12], [3, 26], [46, 34], [24, 9], [40, 40]]:
				D(sp[0], sp[1], Color.WHITE); D(sp[0] + 1, sp[1], ice[3]); D(sp[0], sp[1] + 1, ice[3])
		"hollow_mole_king":
			# The Hollow King: a dark elemental of floating obsidian shards around a
			# swirling void heart, crowned with drifting crystals, trailing shadow.
			var ob = R["shade"]
			var vio = [Color("#3a2160"), Color("#6a3fa8"), Color("#b48cf0"), Color("#efe2ff")]
			var void_r = [Color("#04020a"), Color("#08050c"), Color("#120a20"), Color("#1c1030")]
			E(24, 45, 14, 2, [R["shade"][0], R["shade"][0], R["shade"][1], R["shade"][1]])
			# a rift in the ground it rises from
			E(24, 45, 8, 1.2, [vio[1], vio[1], vio[2], vio[2]])
			# shadow tail trailing down into the rift
			P([16, 34, 32, 34, 28, 40, 24, 45, 20, 40], [ob[0], ob[1], ob[1], ob[2]])
			for w in [[22, 41], [26, 39], [24, 43], [19, 37], [29, 37]]:
				D(w[0], w[1], vio[1])
			# far arm: floating shards ending in a claw
			for s in [[37, 20, 3.0], [41, 26, 2.6], [43, 32, 2.2]]:
				P([s[0] - s[2], s[1], s[0], s[1] - s[2] * 1.3, s[0] + s[2], s[1], s[0], s[1] + s[2] * 1.3], ob, true)
			for c in [[43, 35, 41, 39], [44, 35, 45, 39], [43, 35, 43, 40]]:
				Ln(c[0], c[1], c[2], c[3], 0.5, vio)
			# the obsidian body
			P([12, 16, 16, 11, 20, 13, 23, 8, 28, 12, 33, 9, 37, 17, 34, 22, 37, 29, 30, 34, 27, 38, 22, 35, 15, 36, 14, 29, 10, 23], ob, true)
			for fl in [[21, 9, 18, 22], [30, 10, 32, 24], [13, 28, 22, 31], [35, 29, 28, 30], [18, 22, 32, 24]]:
				Ln(fl[0], fl[1], fl[2], fl[3], 0.35, [ob[3], ob[3], ob[3], ob[3]])
			# glowing cracks running out from the heart
			for ck in [[24, 22, 26, 13, 29, 11], [20, 29, 15, 32, 14, 35], [29, 26, 33, 23, 36, 18], [27, 31, 31, 33, 33, 30]]:
				path(ck, 0.4, [vio[1], vio[1], vio[2], vio[2]])
			# swirling void heart
			E(24, 27, 5.5, 5.5, void_r, true)
			for i in 14:
				var t = i / 14.0 * TAU
				var r = 2.0 + i * 0.22
				D(int(round(24 + cos(t * 1.4) * r)), int(round(27 + sin(t * 1.4) * r)), vio[1] if i < 9 else vio[2])
			E(24, 27, 1.4, 1.4, [vio[2], vio[3], vio[3], Color.WHITE])
			# face: glowing slit eyes looking left
			for ey in [[15, 16, 1], [21, 16, -1]]:
				Dr(ey[0], ey[1], 4, 2, void_r[0])
				D(ey[0] + (3 if ey[2] > 0 else 0), ey[1] - 1, void_r[0])
				Dr(ey[0], ey[1], 3, 1, vio[2]); D(ey[0] + 1, ey[1], Color.WHITE); D(ey[0] + 1, ey[1] + 1, vio[3])
			# near arm: shards reaching forward to a great claw
			for s in [[11, 20, 3.4], [7, 26, 3.0], [5, 32, 2.6]]:
				P([s[0] - s[2], s[1], s[0], s[1] - s[2] * 1.3, s[0] + s[2], s[1], s[0], s[1] + s[2] * 1.3], ob, true)
			for c in [[5, 35, 2, 40], [5, 35, 5, 41], [6, 35, 8, 40]]:
				Ln(c[0], c[1], c[2], c[3], 0.6, vio, true)
			# drifting crystal crown
			for cr in [[15, 7, 1.6, 4], [20, 5, 1.8, 6], [25, 4, 2.0, 7], [30, 6, 1.6, 5]]:
				P([cr[0] - cr[2], cr[1], cr[0], cr[1] - cr[3], cr[0] + cr[2], cr[1]], vio, true)
			# motes of dark energy
			for m in [[3, 14], [40, 9], [45, 22], [9, 40], [38, 42], [34, 3]]:
				D(m[0], m[1], vio[2]); D(m[0] + 1, m[1], vio[1]); D(m[0], m[1] + 1, vio[1])
		"blight_treant":
			# A towering withered treant: roots that grip the ground, a gnarled crown
			# of dead branches, a scowling hollow face aglow with blight, a crooked
			# limb reaching out with twig claws and sickly fungus on its bark.
			var bl = R["blight"]
			var crease = [bl[0], bl[0], bl[0], bl[0]]
			var glow = [Color("#6a3fa8"), Color("#a985e0"), Color("#d9c2ff"), Color.WHITE]
			var hollow = [Color("#08050c"), Color("#08050c"), Color("#100a18"), Color("#100a18")]
			# far branch, behind the trunk
			taper([30, 16, 34, 12, 36, 7, 40, 4], 2.0, 0.5, bl)
			taper([35, 9, 40, 9, 44, 6], 1.1, 0.4, bl)
			# roots curling out from the trunk and gripping the ground
			for rt in [[[19, 35, 15, 40, 10, 43, 5, 44], 2.6], [[32, 34, 37, 39, 42, 41, 46, 41], 2.4]]:
				taper(rt[0], rt[1], 0.6, bl)
			# the trunk, flared at the base and twisting as it rises
			P([18, 12, 29, 10, 30, 20, 32, 31, 37, 40, 32, 38, 28, 41, 24, 39, 20, 41, 15, 39, 18, 31, 17, 21], bl, true)
			for rt in [[[21, 38, 20, 43, 17, 46], 2.0], [[29, 38, 31, 43, 34, 46], 2.0]]:
				taper(rt[0], rt[1], 0.5, bl, true)
			path([22, 12, 20, 24, 22, 32, 21, 38], 0.4, crease)
			path([27, 11, 29, 22, 28, 30, 31, 38], 0.4, crease)
			# the crown: dead branches forking upward
			taper([22, 12, 21, 7, 18, 3, 16, 0], 1.8, 0.4, bl, true)
			taper([21, 7, 24, 3, 25, 0], 1.0, 0.3, bl, true)
			taper([27, 11, 30, 6, 34, 4, 38, 3], 1.6, 0.4, bl, true)
			taper([30, 6, 31, 1], 0.9, 0.3, bl, true)
			# near limb reaching forward to twig claws
			taper([19, 19, 14, 17, 9, 19, 5, 24], 2.4, 1.0, bl, true)
			for c in [[5, 24, 2, 21, 0, 21], [5, 24, 1, 25], [5, 24, 3, 28, 2, 31]]:
				taper(c, 1.0, 0.3, bl, true)
			# the face: scowling slanted hollows with glowing pupils and a jagged grin
			P([17, 17, 23, 20, 22, 23, 18, 22], hollow)
			P([25, 20, 30, 16, 30, 21, 26, 23], hollow)
			Ln(16, 16, 23, 19, 0.6, crease); Ln(25, 19, 31, 15, 0.6, crease)
			D(21, 21, glow[3]); D(20, 21, glow[2]); D(21, 22, glow[1]); D(27, 21, glow[3]); D(28, 21, glow[2]); D(27, 22, glow[1])
			P([18, 26, 31, 25, 30, 29, 28, 31, 26, 29, 24, 32, 22, 29, 20, 31], hollow)
			for f in [[20, 26], [23, 26], [26, 26], [29, 25]]:
				D(f[0], f[1], bl[3]); D(f[0], f[1] + 1, bl[2])
			D(24, 30, glow[1]); D(27, 29, glow[0])
			for lf in [[16, 0], [25, 0], [38, 3], [31, 1], [44, 6]]:
				D(lf[0], lf[1], R["sick"][1])
			for sh in [[17, 33, 3.2], [32, 24, 2.8], [33, 33, 2.4]]:
				E(sh[0], sh[1], sh[2], 1.2, R["sick"], true)
			for m in [[9, 10], [42, 18], [12, 5], [40, 30], [6, 34]]:
				D(m[0], m[1], glow[1])
			D(18, 35, R["sick"][3]); D(18, 36, R["sick"][2]); D(34, 36, R["sick"][3])
		"lagoon_kraken":
			# A deep-sea giant squid surging from the lagoon: a long finned mantle,
			# one great eye, glowing spots and club tentacles lashing out.
			var sq = R["eel"]
			var lum = [Color("#3aa0a8"), Color("#7ff0e0"), Color("#d0fff6"), Color.WHITE]
			path([22, 36, 12, 30, 5, 22, 2, 15], 1.3, sq)
			E(2, 13, 2.4, 3.0, sq, true)
			path([24, 38, 14, 38, 7, 34, 3, 30], 1.2, sq)
			E(3, 28, 2.2, 2.6, sq, true)
			P([24, 26, 31, 4, 37, 1, 40, 8, 35, 30], sq, true)
			P([31, 6, 25, 3, 33, 12], sq, true); P([38, 7, 46, 4, 39, 14], sq, true)
			for sp in [[33, 12], [36, 18], [31, 22], [35, 25], [34, 7]]:
				D(sp[0], sp[1], lum[1]); D(sp[0], sp[1] - 1, lum[2])
			E(28, 31, 9, 6.5, sq, true)
			E(23, 30, 4, 3.4, R["gold"], true)
			Dr(23, 28, 1, 5, Color("#0a1416")); D(22, 29, Color.WHITE)
			for tn in [[22, 36, 16, 42], [26, 37, 24, 43], [31, 37, 34, 43], [35, 35, 41, 41]]:
				path([tn[0], tn[1], (tn[0] + tn[2]) / 2.0 + 2, (tn[1] + tn[3]) / 2.0, tn[2], tn[3]], 1.6, sq)
			for su in [[8, 27], [5, 20], [12, 37], [8, 36], [18, 40], [37, 39]]:
				D(su[0], su[1], R["cream"][3])
			# the lagoon, waves cresting around it
			for x in 48:
				var top = 42 + int(round(1.6 * sin(x * 0.55) + 0.8 * sin(x * 1.3 + 1.0)))
				for y in range(top, 48):
					var c = R["water"][1] if y > top + 1 else R["water"][2]
					if y == top: c = R["water"][3]
					if y > top + 3: c = R["water"][0]
					D(x, y, c)
				if sin(x * 0.55) > 0.8:
					D(x, top - 1, Color.WHITE); D(x - 1, top, Color.WHITE)
			for sp in [[6, 39], [40, 37], [19, 40], [45, 40]]:
				D(sp[0], sp[1], R["water"][3]); D(sp[0] + 1, sp[1] - 1, Color.WHITE)
		"scaldmaw_hydra":
			# Scaldmaw: a two-headed hydra rising from a boiling pool, one head of
			# lagoon water and one of magma, steam pouring off its basalt coils.
			var wat = R["water"]
			var mag = R["lizard"]
			var basalt = [Color("#14181c"), Color("#2a3238"), Color("#46525a"), Color("#6a7a84")]
			var steam = [Color("#8a98a4"), Color("#c4ced6"), Color("#e8eff4"), Color.WHITE]
			# far neck and the water head, behind
			path([31, 34, 36, 24, 35, 13, 31, 7], 2.6, wat, true)
			for fn in [[37, 24, 41, 21], [37, 17, 41, 13], [35, 10, 38, 5]]:
				P([fn[0], fn[1] - 1.5, fn[2], fn[3], fn[0], fn[1] + 1.5], R["ice"], true)
			E(27, 7, 6, 3.4, wat, true)
			P([24, 9, 16, 10, 19, 12, 27, 11], wat, true)
			for tw in [[18, 9], [21, 9], [24, 9]]:
				D(tw[0], tw[1], R["bone"][3])
			Dr(26, 5, 2, 1, SOCKET); D(26, 5, Color("#bff6ff"))
			# water spitting from its jaws
			for dr in [[15, 10], [13, 12], [14, 14], [11, 13], [12, 16]]:
				D(dr[0], dr[1], wat[3])
			# the basalt coils, cracked with magma and wet on top
			E(29, 38, 13, 6.5, basalt, true)
			E(20, 40, 8, 4.5, basalt, true)
			path([18, 39, 23, 37, 28, 40, 34, 37, 39, 39], 0.5, R["fire"])
			path([24, 34, 29, 33, 35, 34], 0.5, [wat[2], wat[2], wat[3], wat[3]])
			# near neck and the magma head, in front
			path([22, 38, 17, 31, 15, 24, 13, 19], 2.8, mag, true)
			for sp in [[19, 33, 22, 31], [16, 27, 19, 25], [15, 22, 17, 19]]:
				P([sp[0], sp[1] + 1.5, sp[2], sp[3], sp[0], sp[1] - 1.5], R["fire"], true)
			E(9, 20, 6, 3.6, mag, true)
			P([7, 22, 1, 23, 3, 26, 11, 25], mag, true)
			for tw in [[3, 22], [6, 22], [5, 24]]:
				D(tw[0], tw[1], R["bone"][3])
			Dr(8, 18, 2, 1, SOCKET); D(8, 18, Color("#ffd447"))
			for cr in [[11, 17, 13, 13], [14, 18, 17, 14]]:
				Ln(cr[0], cr[1], cr[2], cr[3], 0.6, R["fire"])
			# embers spat from its jaws
			for em in [[1, 27, 3], [3, 29, 2], [0, 30, 3]]:
				D(em[0], em[1], R["fire"][em[2]])
			# the boiling pool
			for x in 48:
				var top = 43 + int(round(1.2 * sin(x * 0.6) + 0.6 * sin(x * 1.4 + 2.0)))
				for y in range(top, 48):
					var c = wat[1] if y > top + 1 else wat[2]
					if y == top: c = wat[3]
					if y > top + 3: c = wat[0]
					D(x, y, c)
			for bb in [[5, 44], [14, 45], [41, 44], [45, 46], [34, 46]]:
				D(bb[0], bb[1], R["fire"][2]); D(bb[0] + 1, bb[1] - 1, R["fire"][3])
			# steam rising
			for st in [[40, 30, 3.0, 2.2], [43, 26, 2.2, 1.8], [42, 9, 2.6, 2.0], [45, 5, 1.8, 1.4], [3, 6, 2.4, 1.8], [6, 3, 1.6, 1.3]]:
				E(st[0], st[1], st[2], st[3], steam)
		"rimeshade_wight":
			# Rimeshade: a hooded barrow wight in a tattered shadow robe hemmed with
			# frost, crowned with ice antlers and bearing a frozen glaive.
			var ice = R["ice"]
			var robe = R["dark"]
			var void_r = [Color("#04020a"), Color("#08050c"), Color("#120a20"), Color("#1c1030")]
			var frost = [ice[2], ice[2], ice[3], ice[3]]
			E(24, 45, 13, 2, [R["shade"][0], R["shade"][0], R["shade"][1], R["shade"][1]])
			E(24, 45, 8, 1.1, [ice[1], ice[1], ice[2], ice[2]])
			# the glaive, held behind
			Ln(38, 6, 37, 44, 0.8, R["shade"])
			P([38, 7, 35, 3, 39, -1, 44, 2, 43, 6], ice, true)
			Ln(38, 1, 42, 5, 0.35, [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
			# far arm gripping it
			path([31, 20, 35, 25, 37, 22], 1.6, robe, true)
			E(37, 22, 1.8, 1.8, ice, true)
			# tattered robe
			P([17, 15, 31, 15, 36, 28, 35, 39, 32, 36, 29, 43, 26, 37, 22, 42, 19, 36, 15, 41, 13, 32], robe, true)
			for fl in [[22, 18, 20, 38], [28, 18, 30, 38], [25, 20, 25, 36]]:
				Ln(fl[0], fl[1], fl[2], fl[3], 0.35, [robe[0], robe[0], robe[0], robe[0]])
			# frost on the hem
			path([14, 39, 15, 37, 19, 35, 22, 40, 26, 36, 29, 41, 32, 35, 34, 37], 0.6, frost)
			for ic in [[15, 41, 15, 44], [22, 42, 22, 45], [29, 43, 29, 46], [35, 39, 35, 41]]:
				Ln(ic[0], ic[1], ic[2], ic[3], 0.4, ice)
			# the hood, its face a void with two cold eyes
			E(22, 14, 8, 7.5, R["shade"], true)
			P([20, 7, 27, 4, 29, 11], R["shade"], true)
			E(19.5, 15.5, 4.6, 4.8, void_r, true)
			for ey in [[17, 14], [21, 14]]:
				Dr(ey[0], ey[1], 2, 1, ice[2]); D(ey[0], ey[1], Color.WHITE)
			D(19, 18, ice[1]); D(18, 19, ice[0])
			# ice antler crown
			for sh in [[18, 8, 11, 2, 1.8], [24, 7, 30, 0, 1.8], [15, 5, 12, -1, 1.2], [27, 3, 33, 4, 1.2], [21, 7, 21, 1, 1.3]]:
				var a = Vector2(sh[0], sh[1])
				var b = Vector2(sh[2], sh[3])
				var n = (b - a).orthogonal().normalized() * sh[4]
				P([a.x + n.x, a.y + n.y, b.x, b.y, a.x - n.x, a.y - n.y], [ice[1], ice[2], ice[3], Color.WHITE], true)
			# near arm reaching forward to an icy claw
			path([17, 21, 11, 25, 6, 24], 1.8, robe, true)
			for c in [[6, 24, 1, 21], [6, 24, 1, 25], [6, 25, 3, 29]]:
				Ln(c[0], c[1], c[2], c[3], 0.6, ice, true)
			# frost shards and shadow motes drifting around it
			for m in [[4, 12], [44, 16], [42, 32], [6, 36], [10, 7]]:
				D(m[0], m[1], Color.WHITE); D(m[0] + 1, m[1], ice[3]); D(m[0], m[1] + 1, ice[3])
			for m in [[3, 30], [40, 40], [33, 9]]:
				D(m[0], m[1], robe[3]); D(m[0] + 1, m[1], robe[2])
	outline()

func make(kind: String, name: String) -> Image:
	W = 48 if kind == "boss" else 32
	H = W
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	if kind == "troop": troop(name)
	elif kind == "enemy": enemy(name)
	else: boss(name)
	return img

# params.save_dir: write every sprite as a PNG there. Returns a contact sheet.
func run(api, image, project, params):
	var dir: String = params.get("save_dir", "")
	if params.get("troops_only", false):
		var tsheet = Image.create(TROOPS.size() * 36, 36, false, Image.FORMAT_RGBA8)
		tsheet.fill(Color("#3b3326"))
		for j in TROOPS.size():
			var im = make("troop", TROOPS[j])
			if dir != "": im.save_png(dir + "troop_%s.png" % TROOPS[j])
			tsheet.blend_rect(im, Rect2i(0, 0, 32, 32), Vector2i(j * 36 + 2, 2))
		return tsheet
	var sheet = Image.create(maxi(8, BOSSES.size()) * 50, 5 * 50, false, Image.FORMAT_RGBA8)
	var i = 0
	var troop_imgs = {}
	for n in TROOPS:
		var im = make("troop", n)
		troop_imgs[n] = im
		if dir != "": im.save_png(dir + "troop_%s.png" % n)
		sheet.blit_rect(im, Rect2i(0, 0, 32, 32), Vector2i((i % 8) * 50 + 8, (i / 8) * 50 + 8))
		i += 1
	for n in ["vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig"]:
		var im = make("enemy", "wild_" + n)
		if dir != "": im.save_png(dir + "enemy_wild_%s.png" % n)
		sheet.blit_rect(im, Rect2i(0, 0, 32, 32), Vector2i((i % 8) * 50 + 8, (i / 8) * 50 + 8))
		i += 1
	i = 16
	for n in ENEMIES:
		var im = make("enemy", n)
		if dir != "": im.save_png(dir + "enemy_%s.png" % n)
		sheet.blit_rect(im, Rect2i(0, 0, 32, 32), Vector2i((i % 8) * 50 + 8, (i / 8) * 50 + 8))
		i += 1
	i = 32 + 0
	for n in BOSSES:
		var im = make("boss", n)
		if dir != "": im.save_png(dir + "enemy_%s.png" % n)
		var col = (i - 32) % 8
		sheet.blit_rect(im, Rect2i(0, 0, 48, 48), Vector2i(col * 50 + 1, 4 * 50 + 1 - 0))
		i += 1
	return sheet
