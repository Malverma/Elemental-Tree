# Pixelorama eval_gdscript generator for battle projectiles ("shots").
# Same palette and shading model as units.gd: light from the upper right,
# 3 tones per ramp with ordered dither and a dark auto-outline. Each shot is
# 12x12, centred on (6, 6) and pointing right (+x), so the battle view can
# turn it toward its target. Drawn at the units' pixel scale.
var img: Image
const W := 12
const H := 12
const L := Vector2(0.5, -0.85)

const SHOTS := ["arrow", "acorn", "tide", "sap", "droplet", "ember", "icicle", "pollen", "bubble", "foam"]

var R := {
	"wood": [Color("#4a3420"), Color("#8a6a42"), Color("#b8945e"), Color("#dcc08a")],
	"leaf": [Color("#1f4d2b"), Color("#2e6b34"), Color("#4f9a3f"), Color("#8fd36c")],
	"water": [Color("#1d3b6b"), Color("#2f64b5"), Color("#5ba4e8"), Color("#bfe6ff")],
	"fire": [Color("#7a1a10"), Color("#c8361e"), Color("#f0742d"), Color("#ffd166")],
	"ice": [Color("#24546e"), Color("#4aa3c9"), Color("#a6dcf0"), Color("#effbff")],
	"fur": [Color("#3e2414"), Color("#7a4a28"), Color("#a87444"), Color("#d6a46c")],
	"shell": [Color("#3a2a14"), Color("#6a4e26"), Color("#967040"), Color("#c49c62")],
	"ash": [Color("#2e2826"), Color("#5e5450"), Color("#968a84"), Color("#d4c8c0")],
	"gold": [Color("#6a4a08"), Color("#b88a14"), Color("#f0c43a"), Color("#fff0a0")],
	"pollen": [Color("#7a5a10"), Color("#d0a020"), Color("#ffd447"), Color("#fff6b0")],
	"eel": [Color("#123c48"), Color("#1f6a78"), Color("#3aa0a8"), Color("#9ae0dc")],
	"cream": [Color("#7a6e5c"), Color("#b8ab92"), Color("#e2d8c2"), Color("#fffaf0")],
}

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func put(x: int, y: int, c: Color):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func tone(t: float, x: int, y: int, ramp: Array) -> Color:
	t += (bayer(x, y) - 0.5) * 0.3
	return ramp[3] if t > 0.45 else (ramp[2] if t > -0.15 else ramp[1])

func E(cx: float, cy: float, rx: float, ry: float, ramp: Array):
	for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
		for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
			var n = Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			if n.length_squared() <= 1.0:
				put(x, y, tone(n.dot(L) * 0.9 + 0.05, x, y, ramp))

func P(pts: Array, ramp: Array):
	var poly = PackedVector2Array()
	for i in range(0, pts.size(), 2):
		poly.append(Vector2(pts[i], pts[i + 1]))
	var r = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	var c = r.get_center()
	var half = r.size / 2.0 + Vector2(0.5, 0.5)
	for y in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for x in range(int(r.position.x) - 1, int(r.end.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				put(x, y, tone(((Vector2(x + 0.5, y + 0.5) - c) / half).dot(L) * 0.9 + 0.05, x, y, ramp))

func D(x: int, y: int, c: Color):
	put(x, y, c)

func outline():
	var src = img.duplicate()
	for y in H:
		for x in W:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and src.get_pixel(q.x, q.y).a > 0.5:
					var c = src.get_pixel(q.x, q.y).darkened(0.72)
					c.a = 1.0
					img.set_pixel(x, y, c)
					break

func shot(name: String):
	match name:
		"arrow":
			# A twig shaft with a flint head and leaf fletching (Twig Archer).
			for x in range(2, 9): D(x, 6, R["wood"][2])
			D(4, 6, R["wood"][1]); D(7, 6, R["wood"][3])
			D(9, 5, R["ash"][1]); D(9, 6, R["ash"][3]); D(9, 7, R["ash"][1]); D(10, 6, R["ash"][2]); D(11, 6, R["ash"][3])
			D(1, 5, R["leaf"][3]); D(2, 5, R["leaf"][2]); D(0, 4, R["leaf"][2])
			D(1, 7, R["leaf"][1]); D(2, 7, R["leaf"][2]); D(0, 8, R["leaf"][1])
		"acorn":
			# An acorn with its cap on (Acorn Slinger); it tumbles in flight.
			E(6, 7, 2.5, 2.8, R["fur"])
			E(6, 4.8, 3, 1.4, R["shell"])
			D(5, 4, R["shell"][3]); D(7, 5, R["shell"][0])
			D(6, 3, R["wood"][1]); D(7, 9, R["fur"][0])
		"tide":
			# A swirling water orb with a spray tail (Tide Caller).
			E(7, 6, 3, 3, R["water"])
			D(7, 5, R["water"][3]); D(8, 5, Color.WHITE); D(6, 7, R["water"][1])
			D(3, 5, R["water"][3]); D(2, 7, R["water"][2]); D(1, 6, R["water"][3])
		"sap":
			# A glowing glob of amber sap (Sap Mender's staff).
			P([2, 6, 6, 4, 6, 8], R["gold"])
			E(7.5, 6, 2.5, 2.5, R["gold"])
			D(8, 5, R["gold"][3]); D(9, 5, Color.WHITE)
		"droplet":
			# A small falling water drop (Ripple Sprite).
			P([3, 6, 7, 4.5, 7, 7.5], R["water"])
			E(7.5, 6, 2, 2, R["water"])
			D(8, 5, Color.WHITE)
		"ember":
			# A fireball trailing flame (Ash Moth).
			P([1, 6, 6, 3.5, 6, 8.5], [R["fire"][1], R["fire"][1], R["fire"][2], R["fire"][2]])
			E(7.5, 6, 2.6, 2.6, R["fire"])
			D(8, 6, Color("#fff6c0")); D(8, 5, R["fire"][3]); D(3, 5, R["fire"][2])
		"icicle":
			# A sharp shard of ice (Icicle Bat).
			# Rows taper from 5 px at the back to a 1 px point.
			for x in range(1, 12):
				var half = 2 if x < 4 else (1 if x < 7 else 0)
				for y in range(6 - half, 7 + half):
					D(x, y, R["ice"][1] if y > 6 else (R["ice"][3] if y < 6 or x > 8 else R["ice"][2]))
			D(2, 5, Color.WHITE); D(4, 5, Color.WHITE); D(11, 6, Color.WHITE)
		"pollen":
			# A fuzzy puff of pollen (Pollen Wisp).
			E(6, 6.5, 2.2, 2.2, R["pollen"]); E(4, 5, 1.5, 1.5, R["pollen"]); E(8, 7.5, 1.5, 1.5, R["pollen"]); E(7.5, 4.2, 1.3, 1.3, R["pollen"])
			D(7, 4, R["pollen"][3]); D(3, 8, R["pollen"][2]); D(9, 4, R["pollen"][3])
		"bubble":
			# A see-through bubble (Bubble Eel): a rim and a glint, no fill.
			for a in 16:
				var v = Vector2(cos(a * TAU / 16.0), sin(a * TAU / 16.0))
				D(int(round(6 + v.x * 3.2)), int(round(6 + v.y * 3.2)), R["eel"][3] if v.dot(L) > 0.0 else R["eel"][2])
			for y in range(4, 9):
				for x in range(4, 9):
					if Vector2(x - 6, y - 6).length() < 2.6:
						D(x, y, Color(R["eel"][3], 0.35))
			D(7, 4, Color.WHITE); D(8, 5, Color.WHITE)
		"foam":
			# A burst of sea foam blown from a conch (Wild Tide Caller).
			E(7, 6, 2.5, 2.5, R["cream"]); E(4, 4.5, 1.6, 1.6, R["water"]); E(4, 7.5, 1.6, 1.6, R["cream"]); E(9.5, 6, 1.3, 1.3, R["water"])
			D(7, 5, Color.WHITE); D(2, 6, R["water"][3])
	if name != "bubble":
		outline()

func make(name: String) -> Image:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	shot(name)
	return img

# params.save_dir: write every shot as shot_<name>.png there. Returns a sheet
# of them at 1x on a dark strip and, below it, on a light one.
func run(api, image, project, params):
	var dir: String = params.get("save_dir", "")
	var sheet = Image.create(SHOTS.size() * 14, 28, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(0, 0, sheet.get_width(), 14), Color("#3b3326"))
	sheet.fill_rect(Rect2i(0, 14, sheet.get_width(), 14), Color("#8fae6a"))
	for i in SHOTS.size():
		var im = make(SHOTS[i])
		if dir != "": im.save_png(dir + "shot_%s.png" % SHOTS[i])
		sheet.blend_rect(im, Rect2i(0, 0, W, H), Vector2i(i * 14 + 1, 1))
		sheet.blend_rect(im, Rect2i(0, 0, W, H), Vector2i(i * 14 + 1, 15))
	return sheet
