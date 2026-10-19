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

const TROOPS := ["soldier", "spearman", "archer", "vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig"]
const ENEMIES := ["thorn_beetle", "burrow_rabbit", "spring_frog", "ripple_sprite", "cinder_lizard", "ash_moth", "frost_wolf", "icicle_bat",
	"cave_bat", "shadow_slime", "thornback_boar", "pollen_wisp", "snapjaw_crab", "bubble_eel"]
const BOSSES := ["bramble_hare", "mossback_turtle", "magma_salamander", "rime_elk", "hollow_mole_king", "blight_treant", "lagoon_kraken"]

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
			# A walking fir in snow, braced behind an ice-crystal shield.
			Ln(13, 25, 12, 29, 1.8, b); Ln(19, 25, 20, 29, 1.8, b)
			Dr(10, 29, 4, 1, b[1]); Dr(19, 29, 4, 1, b[1])
			P([5, 26, 15.5, 13, 26, 26], R["pine"])
			P([7, 19, 15.5, 7, 24, 19], R["pine"])
			P([10, 11, 15.5, 2, 21, 11], R["pine"])
			for sp in [[5, 26, 26, 26], [7, 19, 24, 19], [10, 11, 21, 11]]:
				Ln(sp[0] + 2, sp[1] - 1, sp[2] - 2, sp[3] - 1, 0.8, R["snow"])
			P([12, 3, 15.5, 1, 19, 3, 15.5, 5], R["snow"])
			eye(12, 21, Color("#9fe8ff")); eye(17, 21, Color("#9fe8ff"))
			P([22, 14, 27, 12, 30, 18, 27, 27, 22, 24], R["ice"], true)
			D(26, 15, Color.WHITE); D(25, 16, R["ice"][3]); D(27, 20, R["ice"][3])
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
	outline()

# --- bosses (48x48, face left) --------------------------------------------------
func boss(name: String):
	match name:
		"bramble_hare":
			E(36, 30, 4, 4, R["cream"])
			E(27, 31, 12, 9, R["fur"])
			Ln(17, 18, 13, 3, 2.0, R["fur"]); Ln(21, 18, 23, 4, 2.0, R["fur"], true)
			Ln(14, 6, 15, 14, 0.6, R["pink"]); Ln(22, 7, 21, 13, 0.6, R["pink"])
			E(15, 25, 7, 6.5, R["fur"], true)
			E(11, 28, 3, 2.5, R["cream"]); D(8, 27, R["pink"][1])
			aeye(13, 23, Color("#b81e1e"), Color("#ffb0a0"))
			D(10, 31, Color.WHITE); D(11, 31, Color.WHITE)
			path([18, 30, 24, 26, 30, 28, 36, 24, 40, 27], 0.9, R["leaf"])
			path([20, 36, 27, 33, 34, 36, 38, 33], 0.9, R["leaf"])
			for t in [[24, 26], [30, 28], [36, 24], [27, 33], [34, 36]]:
				P([t[0] - 1, t[1], t[0], t[1] - 3, t[0] + 1, t[1]], R["bone"])
			E(19, 41, 4, 2, R["fur"], true); E(33, 41, 5, 2, R["fur"])
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
			E(25, 31, 12, 6.5, R["rock"])
			E(10, 28, 7, 5, R["rock"])
			path([16, 28, 20, 32, 25, 29, 30, 33, 34, 30], 0.6, R["fire"])
			path([6, 27, 10, 29, 13, 26], 0.5, R["fire"])
			path([40, 28, 43, 23], 0.5, R["fire"])
			for sx in [17, 22, 27, 32]:
				P([sx - 2, 26, sx, 19, sx + 2, 26], R["fire"])
			Dr(4, 31, 8, 1, R["fire"][1])
			Ln(16, 35, 13, 43, 1.8, R["rock"], true); Dr(10, 43, 5, 1, R["rock"][1])
			aeye(9, 26, Color("#ffd447"), Color("#fff6c0"))
			D(4, 22, R["fire"][3]); D(20, 14, R["fire"][2]); D(30, 15, R["fire"][3])
		"rime_elk":
			Ln(33, 32, 34, 44, 1.6, R["wolf"]); Ln(19, 32, 18, 44, 1.6, R["wolf"])
			E(28, 28, 12, 7, R["wolf"])
			P([8, 26, 14, 18, 16, 10, 20, 12, 22, 30, 14, 31], R["wolf"])
			E(9, 25, 4, 3, R["wolf"], true)
			path([16, 11, 13, 5, 10, 1], 1.0, R["ice"]); path([13, 5, 8, 6], 0.8, R["ice"]); path([15, 8, 18, 3], 0.8, R["ice"])
			path([19, 11, 24, 6, 28, 2], 1.0, R["ice"]); path([24, 6, 27, 9], 0.8, R["ice"]); path([22, 8, 21, 2], 0.8, R["ice"])
			for sx in [22, 27, 32, 36]:
				P([sx - 1, 23, sx + 1, 17, sx + 2, 23], R["ice"])
			Ln(30, 33, 30, 44, 1.6, R["wolf"], true); Ln(15, 32, 14, 44, 1.6, R["wolf"], true)
			D(6, 26, Color("#1a1010")); D(7, 26, Color("#1a1010"))
			D(12, 22, Color("#2a6fa0")); D(12, 21, Color("#9fe8ff"))
			D(4, 10, Color.WHITE); D(40, 12, R["ice"][3]); D(30, 4, Color.WHITE)
		"hollow_mole_king":
			E(26, 31, 14, 11, R["mole"])
			E(13, 28, 7, 6, R["mole"], true)
			E(6, 30, 2.5, 2, R["pink"])
			D(11, 26, Color("#ffd447")); D(12, 26, Color("#ffd447"))
			P([10, 21, 11, 15, 14, 19, 17, 14, 20, 19, 22, 15, 22, 22, 10, 22], R["gold"], true)
			D(14, 18, Color("#c03030")); D(19, 18, Color("#9a4ad8"))
			for c in [[11, 36], [17, 38]]:
				for k in 3:
					Ln(c[0], c[1], c[0] - 5 + k * 2, c[1] + 5, 0.6, R["bone"])
			E(14, 36, 4, 3, R["pink"], true)
			E(33, 42, 6, 2, R["mole"])
			D(30, 24, R["mole"][3]); D(34, 27, R["mole"][3]); D(4, 20, R["dark"][3]); D(40, 18, R["dark"][2])
		"blight_treant":
			Ln(19, 36, 15, 44, 2.0, R["blight"]); Ln(28, 36, 32, 44, 2.0, R["blight"])
			Dr(11, 44, 6, 1, R["blight"][1]); Dr(31, 44, 6, 1, R["blight"][1])
			P([15, 16, 32, 16, 34, 38, 13, 38], R["blight"])
			for y in range(19, 36, 3): D(30, y, R["blight"][1]); D(17, y + 1, R["blight"][1])
			E(24, 12, 13, 8, R["sick"])
			E(14, 15, 6, 4, R["sick"]); E(34, 15, 6, 4, R["sick"])
			for dp in [[12, 19], [20, 20], [33, 20], [37, 17]]:
				Ln(dp[0], dp[1], dp[0], dp[1] + 4, 0.5, R["sick"])
			Dr(17, 22, 4, 3, SOCKET); Dr(25, 22, 4, 3, SOCKET)
			D(17, 23, Color("#d0f048")); D(25, 23, Color("#d0f048"))
			P([18, 29, 28, 29, 27, 32, 19, 32], [SOCKET, SOCKET, SOCKET, SOCKET])
			D(20, 29, R["bone"][2]); D(25, 29, R["bone"][2])
			path([15, 24, 9, 28, 5, 34], 1.4, R["blight"], true)
			Ln(5, 34, 2, 37, 0.6, R["blight"]); Ln(5, 34, 4, 39, 0.6, R["blight"]); Ln(5, 34, 7, 39, 0.6, R["blight"])
			path([33, 24, 38, 27, 41, 32], 1.2, R["blight"])
			D(10, 8, R["sick"][3]); D(40, 6, R["dark"][3]); D(6, 22, R["dark"][2])
		"lagoon_kraken":
			for t in [[18, 34, 10, 44, 4, 40], [22, 36, 18, 45, 13, 46], [28, 36, 30, 45, 35, 46], [33, 34, 40, 43, 45, 38]]:
				path([t[0], t[1], t[2], t[3], t[4], t[5]], 2.0, R["kraken"])
			E(25, 21, 12, 14, R["kraken"])
			for s in [[20, 12], [29, 10], [32, 18], [18, 22]]:
				E(s[0], s[1], 1.5, 1.5, [R["kraken"][3], R["kraken"][3], R["kraken"][3], R["pink"][3]])
			Dr(17, 26, 4, 3, Color("#fff0a0")); Dr(18, 27, 2, 2, Color("#1a1010"))
			Dr(27, 26, 4, 3, Color("#fff0a0")); Dr(28, 27, 2, 2, Color("#1a1010"))
			path([14, 30, 8, 26, 4, 20, 6, 15], 2.0, R["kraken"], true)
			path([25, 36, 24, 44, 21, 47], 2.0, R["kraken"], true)
			for k in [[7, 25], [5, 20], [24, 41]]:
				D(k[0], k[1], R["pink"][2])
			E(40, 8, 1.5, 1.5, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
			E(44, 14, 1, 1, [R["water"][3], R["water"][3], R["water"][3], Color.WHITE])
	outline()

# Wild twigs: the troop art mirrored to face left, darker, with red eyes.
func wildify(src: Image) -> Image:
	var out = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var c = src.get_pixel(31 - x, y)
			if c.a < 0.5:
				continue
			if c.is_equal_approx(GLOW) or c.is_equal_approx(Color("#ffb347")) or c.is_equal_approx(Color("#9fe8ff")) or c.is_equal_approx(Color("#c08cff")):
				c = Color("#ff3b2f")
			else:
				c = c.darkened(0.12).lerp(Color(c.get_luminance(), c.get_luminance(), c.get_luminance()), 0.15)
				c.a = 1.0
			out.set_pixel(x, y, c)
	return out

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
	var sheet = Image.create(8 * 50, 5 * 50, false, Image.FORMAT_RGBA8)
	var i = 0
	var troop_imgs = {}
	for n in TROOPS:
		var im = make("troop", n)
		troop_imgs[n] = im
		if dir != "": im.save_png(dir + "troop_%s.png" % n)
		sheet.blit_rect(im, Rect2i(0, 0, 32, 32), Vector2i((i % 8) * 50 + 8, (i / 8) * 50 + 8))
		i += 1
	for n in ["vine_lasher", "tide_caller", "ember_sprout", "frost_warden", "shade_twig"]:
		var im = wildify(troop_imgs[n])
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
