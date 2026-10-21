# App icon art: the Grove's tree (drawn by tree.gd) on a curved hill under the sky.
# params.part: "legacy" (96x96 full icon), "bg" / "fg" (216x216 adaptive layers;
# Android keeps roughly the middle 132x132 safe from masking). Exported at 2x.
var img: Image
const TREE_GEN := "/home/bhizie/Projects/Elemental Tree/art/gen/tree.gd"
const TREE_BASE := Vector2(88, 194)  # where tree.gd stands its tree

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func band(x, y, stops: Array, ys: Array) -> Color:
	for i in range(ys.size() - 1):
		if y < ys[i + 1]:
			var t = float(y - ys[i]) / float(ys[i + 1] - ys[i])
			return stops[i + 1] if t > bayer(x, y) else stops[i]
	return stops[stops.size() - 1]

func hill_top(x: float, n: int) -> int:
	var dx = (x - n / 2.0) / (n / 2.0)
	return int(n * 0.68 + n * 0.16 * dx * dx)

# Sky with a soft sun, and the curved grassy hill from the Grove.
func scenery(n: int):
	for y in n:
		for x in n:
			px(x, y, band(x, y, [Color("#5aa9e6"), Color("#7fc3f0"), Color("#a8dcf5"), Color("#d2eef5")], [0, int(n * 0.2), int(n * 0.42), int(n * 0.62)]))
	var sc = Vector2(n * 0.78, n * 0.2)
	for y in n:
		for x in n:
			var d = Vector2(x, y).distance_to(sc)
			if d < n * 0.07:
				px(x, y, Color("#fffbe6"))
			elif d < n * 0.085:
				px(x, y, Color("#fff3c2"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	for x in n:
		var top = hill_top(x, n)
		for y in range(top, n):
			var c = band(x, y, [Color("#5cae4a"), Color("#4c9a40"), Color("#3f8738")], [top, top + int(n * 0.1), top + int(n * 0.22)])
			if y == top: c = Color("#8fd36c")
			elif y == top + 1: c = Color("#72c25a")
			px(x, y, c)
	for i in n * 2:
		var x = rng.randi_range(0, n - 1)
		var y = rng.randi_range(hill_top(x, n) + 3, n - 1)
		px(x, y, img.get_pixel(x, y).lightened(0.18))
	for i in int(n / 8):
		var x = rng.randi_range(2, n - 3)
		var y = rng.randi_range(hill_top(x, n) + 5, n - 2)
		var c = [Color("#fff1a8"), Color.WHITE, Color("#f6a6c1")][i % 3]
		px(x, y, c)

# The Grove's full-grown Elemental Tree (tree.gd's last stage), drawn at `s`
# times its size; its base is at TREE_BASE.
func grove_tree(s: float) -> Image:
	var g = GDScript.new()
	g.source_code = FileAccess.get_file_as_string(TREE_GEN)
	g.reload()
	var out: Image = g.new().run(null, null, null, {"stage": 9, "part": "trunk", "scale": s})
	var crown: Image = g.new().run(null, null, null, {"stage": 9, "part": "crown", "scale": s})
	out.blend_rect(crown, Rect2i(0, 0, crown.get_width(), crown.get_height()), Vector2i.ZERO)
	return out

# Stands the tree on the hilltop of an n-pixel image. Its soft ground shadow
# only falls on the hill, not on the sky past the hill's curve.
func plant_tree(n: int, s: float):
	var tree = grove_tree(s)
	var off = Vector2i((Vector2(n / 2.0, hill_top(n / 2.0, n) + 1) - TREE_BASE).round())
	for y in tree.get_height():
		for x in tree.get_width():
			var c: Color = tree.get_pixel(x, y)
			var q = Vector2i(x, y) + off
			if c.a == 0.0 or q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
				continue
			if c.a < 1.0 and q.y < hill_top(q.x, n):
				continue
			px(q.x, q.y, img.get_pixel(q.x, q.y).blend(c))

func run(api, image, project, params):
	var part = params.get("part", "legacy")
	if part == "legacy":
		img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
		scenery(96)
		plant_tree(96, 0.28)
		return img
	img = Image.create(216, 216, false, Image.FORMAT_RGBA8)
	if part == "bg":
		scenery(216)
	else:
		plant_tree(216, 0.55)
	return img
