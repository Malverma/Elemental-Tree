# Bird Targeting perk art for the Grove: the snare branch that whips out of
# the crown to spear a bird. One straight strip, 96x10, that the game bends
# along the whip's curve pixel by pixel, so the branch reads as one piece.
# Columns run from the base (x = 0, hidden in the leaves) to the point
# (x = 95); rows run across it, its middle line between rows 4 and 5. Rows above the middle
# face the light (the game flips the strip so they always do).
# The tree's bark and leaf palette (see tree.gd), lit from above:
#   - bark tapering from 6 px across at the base to 4 near the end (its top
#     and bottom edges step in at different places, so the taper is smooth), with
#     grooves along the grain and a couple of knots
#   - two leaf sprigs off it, one on each side
#   - a sharp point: the bark ends in a ragged ring and the stripped pale
#     wood beneath narrows in a wedge to a single pixel
# No outline: the game outlines the bent branch as a whole.
var img: Image
const W := 96
const H := 10
const MID := 5.0  # the middle line, between rows 4 and 5
const LEAF := [Color("#17321f"), Color("#24492b"), Color("#356a36"), Color("#4f8c3e"), Color("#78b04e"), Color("#a8d46c")]
const BARK := [Color("#26150c"), Color("#432716"), Color("#633b20"), Color("#86552f"), Color("#a87444")]
const WOOD := [Color("#7a5a36"), Color("#a8865a"), Color("#cfb184"), Color("#ecd8aa")]
const POINT_LEN := 12  # columns of stripped wood at the end
const STAGGER := 7  # the bottom edge steps in this many columns after the top

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func put(x, y, c: Color):
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)

func ramp(cols: Array, v: float, x: int, y: int) -> Color:
	var f = clampf(v, 0.0, 0.999) * (cols.size() - 1)
	var i = int(f)
	return cols[mini(i + 1, cols.size() - 1)] if f - i > bayer(x, y) else cols[i]

# Half-width of the branch at column x (in rows either side of the middle).
func half(x: float) -> float:
	var tip_start = W - POINT_LEN
	if x < tip_start:
		return lerpf(3.0, 2.0, x / tip_start)
	# the point: a straight taper to nothing
	return lerpf(2.0, 0.0, clampf((x - tip_start) / float(POINT_LEN), 0.0, 1.0))

# Whether row y is inside the branch at column x: the top edge follows half(x),
# the bottom edge the same a few columns later, so they step in at different places.
func inside(x: int, y: int) -> bool:
	var tip_start = W - POINT_LEN
	if x >= tip_start:
		# The point: a wedge from 4 rows (3-6) down to one, its lit top edge
		# sloping in twice as fast as the bottom.
		var f = (x - tip_start) / float(POINT_LEN)
		return y >= 3 + int(f * 2.99) and y <= 6 - int(f * 1.99)
	var dy = y + 0.5 - MID
	if dy < 0.0:
		return -dy <= half(x + 0.5)
	return dy <= half(minf(x + 0.5 + STAGGER, W - 0.5)) if x < W - POINT_LEN - STAGGER else dy <= half(x + 0.5)

func bark():
	var tip_start = W - POINT_LEN
	for x in W:
		var h = half(x + 0.5)
		for y in H:
			if not inside(x, y):
				continue
			var v = clampf((y + 0.5 - MID) / maxf(h, 0.5), -1.0, 1.0)  # -1 at the lit edge, +1 at the shaded one
			# The bark ends in a ragged ring a couple of columns into the point.
			var ring = tip_start + 2 + int(bayer(x, y * 3) * 3.0)
			if x >= ring:
				var lw = 0.55 - 0.45 * v
				put(x, y, ramp(WOOD, lw, x, y))
				continue
			var lit = 0.5 - 0.42 * v
			# grooves running along the grain
			if (posmod(x * 2 + y * 7, 11) == 0 or posmod(x + y * 5, 17) == 0) and absf(v) < 0.8:
				lit -= 0.3
			put(x, y, ramp(BARK.slice(1), lit, x, y))
		# the bark lip where the point was stripped
		if x == tip_start + 1:
			for y in H:
				if inside(x, y):
					put(x, y, BARK[1])
	# a couple of knots
	for k in [[22, 5], [61, 5]]:
		put(k[0], k[1], BARK[1]); put(k[0] + 1, k[1], BARK[0]); put(k[0], k[1] - 1, BARK[3])

# A leaf sprig growing off the branch at column x, up (side -1) or down (+1).
func sprig(x0: int, side: int):
	# a short stalk
	var edge = 1 if side < 0 else 8  # the row just off the branch on that side
	put(x0, edge, BARK[2])
	put(x0 + 1, edge + side, BARK[2])
	# the leaf, lying back along the branch toward the base
	var c = Vector2(x0 - 1.5, edge + 0.5 + side * 0.6)
	for y in H:
		for x in range(x0 - 6, x0 + 3):
			var d = Vector2(x + 0.5, y + 0.5) - c
			var u = Vector2(d.x / 3.4, d.y / 1.3)
			if u.length() > 1.0:
				continue
			var v = 0.55 - 0.35 * u.y * side + 0.15 * (d.x / 3.4)
			if absf(d.y) < 0.4 and d.x > -2.5:
				v -= 0.2  # the vein
			put(x, y, ramp(LEAF, v, x, y))

func run(api, image, project, params):
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	bark()
	sprig(40, -1)
	sprig(66, 1)
	var out: String = params.get("save_dir", "")
	if out != "":
		img.save_png(out + "snare_branch.png")
	return img
