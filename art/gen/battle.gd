# Battlefield ground: one seamless 48x48 tile per element, side by side.
var img: Image
const T := 48
const ELEMENTS := ["nature", "water", "fire", "ice", "dark"]
const PAL := {
	"nature": [Color("#4c9a40"), Color("#5cae4a"), Color("#72c25a")],
	"water": [Color("#4a8a6a"), Color("#5a9a76"), Color("#6aaa82")],
	"fire": [Color("#4a2a22"), Color("#5e342a"), Color("#744232")],
	"ice": [Color("#bcdcee"), Color("#d4e9f4"), Color("#eef6fa")],
	"dark": [Color("#3a2c48"), Color("#45364f"), Color("#544260")],
}

func px(x, y, c):
	img.set_pixel(posmod(x, T) + _ox, posmod(y, T), c)

var _ox := 0

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

# Noise that wraps every T pixels so the tile is seamless.
func wrap_noise(x: float, y: float, seed: float) -> float:
	var a = TAU / T
	return 0.45 * sin(x * a * 2 + sin(y * a + seed) * 1.5) + 0.35 * sin(y * a * 3 + x * a + seed * 2.0) + 0.2 * sin((x + y) * a * 5 + seed)

func tile(el: String, i: int):
	_ox = i * T
	var pal: Array = PAL[el]
	for y in T:
		for x in T:
			var v = wrap_noise(x, y, i * 1.7) + (bayer(x, y) - 0.5) * 0.5
			px(x, y, pal[2] if v > 0.4 else (pal[0] if v < -0.4 else pal[1]))
	var rng = RandomNumberGenerator.new()
	rng.seed = 7 + i
	match el:
		"nature":
			for k in 40:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color("#8fd36c")); px(x, y - 1, Color("#72c25a"))
			for k in 4:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				var c = [Color("#fff1a8"), Color("#f6a6c1"), Color.WHITE][k % 3]
				px(x, y, Color("#ffd166")); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c)
		"water":
			for k in 3:
				var cx = rng.randi_range(0, T - 1); var cy = rng.randi_range(0, T - 1)
				for y in range(-2, 3):
					for x in range(-5, 6):
						if pow(x / 5.0, 2) + pow(y / 2.4, 2) <= 1.0:
							px(cx + x, cy + y, Color("#5ba4e8") if y < 1 else Color("#3a78c9"))
				px(cx - 2, cy - 1, Color("#c6e8ff"))
			for k in 6:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				for j in 3: px(x, y - j, Color("#3f7a2a"))
		"fire":
			for k in 5:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				for j in rng.randi_range(4, 9):
					px(x, y, Color("#f0642d") if j % 3 else Color("#ffb347"))
					x += rng.randi_range(-1, 1); y += 1
			for k in 8:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color("#2e1a14")); px(x + 1, y, Color("#2e1a14")); px(x, y - 1, Color("#8a5a4a"))
		"ice":
			for k in 30:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color.WHITE)
			for k in 4:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color("#a9d3ea")); px(x + 1, y, Color("#a9d3ea")); px(x + 2, y + 1, Color("#a9d3ea"))
		"dark":
			for k in 10:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color("#7d5aa0"))
			for k in 4:
				var x = rng.randi_range(0, T - 1); var y = rng.randi_range(0, T - 1)
				px(x, y, Color("#e8dcc8")); px(x - 1, y - 1, Color("#9a6ad8")); px(x, y - 1, Color("#c8a2ff")); px(x + 1, y - 1, Color("#9a6ad8"))

func run(api, image, project, params):
	img = Image.create(T * ELEMENTS.size(), T, false, Image.FORMAT_RGBA8)
	for i in ELEMENTS.size():
		tile(ELEMENTS[i], i)
	return img
