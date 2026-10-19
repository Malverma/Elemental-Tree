extends Control
## A little pixel-art campfire, drawn in code: a ring of stones, crossed logs
## and flickering flames. `hot` makes it flare up (a troop hovering over it).

const ART := Vector2(24, 24)  # art pixels
const STONE := [Color("#5a5560"), Color("#8a8590")]
const LOG := [Color("#4a2c16"), Color("#7a4a26")]
const FLAME := [Color("#d8431e"), Color("#ff8a2a"), Color("#ffd447"), Color("#fff4c0")]

## Screen px per art pixel.
var unit := 4.0:
	set(v):
		unit = v
		custom_minimum_size = ART * unit
		queue_redraw()
var hot := false:
	set(v):
		hot = v
		queue_redraw()
var _time := 0.0


func _init() -> void:
	custom_minimum_size = ART * unit
	mouse_filter = MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func _px(x: float, y: float, c: Color, w := 1.0, h := 1.0) -> void:
	draw_rect(Rect2(Vector2(x, y) * unit, Vector2(w, h) * unit), c)


func _draw() -> void:
	# Warm glow on the ground, brighter when hot.
	var glow := (0.22 if hot else 0.12) + 0.04 * sin(_time * 7.0)
	for r in [11.0, 8.0, 5.0]:
		draw_circle(Vector2(12, 19) * unit, r * unit, Color(FLAME[1], glow * 0.6))
	# Flames: columns rising from the logs, each flickering on its own beat.
	var lift := 1.35 if hot else 1.0
	for x in range(-5, 6):
		var h := (6.5 - absf(x)) * 1.6 * lift + 1.6 * sin(_time * 11.0 + x * 1.9) + sin(_time * 5.0 + x)
		h = maxf(1.0, h)
		for y in int(h):
			var t := float(y) / h
			var core := absf(x) <= 2 - int(t * 2.0)
			var c: Color = FLAME[0] if t > 0.75 else (FLAME[2] if core else FLAME[1])
			if core and t < 0.3:
				c = FLAME[3]
			_px(12 + x, 18 - y, c)
	# A spark now and then.
	var s := fmod(_time * 1.3, 1.0)
	_px(12 + roundf(sin(_time * 3.0) * 3.0), 10 - s * 8.0 * lift, Color(FLAME[2], 1.0 - s))
	# Crossed logs.
	for i in 8:
		_px(5 + i, 17 + i * 0.5, LOG[i % 2], 2, 2)
		_px(17 - i, 17 + i * 0.5, LOG[(i + 1) % 2], 2, 2)
	# Ring of stones.
	for i in 9:
		var a := PI * (0.05 + 0.9 * i / 8.0)
		_px(roundf(11 + cos(a) * 10.0), roundf(20 + sin(a) * 2.5), STONE[i % 2], 2, 2)
