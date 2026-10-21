class_name SnareBranch
extends Node2D
## The Bird Targeting perk's branch: it spears out of the crown at a bird,
## straight and stiff, thrusting a touch past it and settling back onto it
## (`caught` fires so the Grove pops it and collects the loot), then slides
## back into the leaves. It's one strip of art, assets/pixel/snare_branch.png
## (see art/gen/snare_branch.gd), laid along the line from the leaves to the
## bird and outlined as a whole, lit from the upper right like the tree. Its
## line is fixed for the whole strike, so the branch only slides along it and
## its pixels don't shimmer. Lives in the Grove scene's art space (design pixels).

signal caught(bird: Dictionary)

const L := Vector2(0.55, -0.83)
const REACH_TIME := 0.32
const HOLD_TIME := 0.22
const RETRACT_TIME := 0.4
## How far the point thrusts past the bird before settling back onto it.
const OVERSHOOT := 0.7

var birds: GroveBirds
var _strip: Image
var _bird: Dictionary = {}
var _root := Vector2.ZERO
var _dir := Vector2.RIGHT  # unit, from the leaves toward the bird
var _reach := 0.0  # design px from the root to the bird
var _grow := 0.0  # 0..1 of the way out
var _t := 0.0
var _phase := ""  # "", "reach", "hold", "retract"


func _init(p_birds: GroveBirds) -> void:
	birds = p_birds
	_strip = UI.tex("snare_branch").get_image()
	texture_filter = TEXTURE_FILTER_NEAREST


func busy() -> bool:
	return _phase != ""


## Shoots out from `root` (a point in the leaves) at `bird`.
func strike(root: Vector2, bird: Dictionary) -> void:
	_root = root.round()
	_bird = bird
	var to := GroveBirds.body(bird) - _root
	_reach = to.length()
	_dir = to / _reach if _reach > 0.01 else Vector2.RIGHT
	_grow = 0.0
	_t = 0.0
	_phase = "reach"


func _process(delta: float) -> void:
	if _phase == "":
		return
	_t += delta
	match _phase:
		"reach":
			# Out fast, a little past the bird and back onto it (an ease-out-back).
			var x := minf(_t / REACH_TIME, 1.0) - 1.0
			_grow = 1.0 + (OVERSHOOT + 1.0) * x * x * x + OVERSHOOT * x * x
			if _t >= REACH_TIME:
				_phase = "hold"
				_t = 0.0
				if _alive():
					caught.emit(_bird)
				_bird = {}
		"hold":
			if _t >= HOLD_TIME:
				_phase = "retract"
				_t = 0.0
		"retract":
			var x := minf(_t / RETRACT_TIME, 1.0)
			_grow = 1.0 - x * x * (3.0 - 2.0 * x)
			if _t >= RETRACT_TIME:
				_phase = ""
	queue_redraw()


func _alive() -> bool:
	return not _bird.is_empty() and birds.is_alive(_bird)


func _draw() -> void:
	if _phase == "":
		return
	# Whole design pixels only, so the branch steps out a pixel at a time.
	var length := roundf(_reach * _grow)
	if length < 1.0:
		return
	var w := _strip.get_width()
	var h := _strip.get_height()
	# The strip's lit rows (the top half) go to the side facing the light.
	var n := Vector2(-_dir.y, _dir.x)
	if n.dot(L) > 0.0:
		n = -n
	# Each pixel near the line takes the strip pixel under it: the point at the
	# far end, the column (length - along) back from it, so the strip slides
	# out point first.
	var tip := _root + _dir * length
	var lo := Vector2(minf(_root.x, tip.x), minf(_root.y, tip.y)).floor() - Vector2(h, h)
	var hi := Vector2(maxf(_root.x, tip.x), maxf(_root.y, tip.y)).ceil() + Vector2(h, h)
	var px := {}  # Vector2i -> Color
	for y in range(int(lo.y), int(hi.y)):
		for x in range(int(lo.x), int(hi.x)):
			var q := Vector2(x + 0.5, y + 0.5) - _root
			var along := q.dot(_dir)
			if along < 0.0 or along > length:
				continue
			var u := w - 1 - int(length - along)
			var v := int(floorf(q.dot(n) + h / 2.0))
			if u < 0 or v < 0 or v >= h:
				continue
			var c := _strip.get_pixel(u, v)
			if c.a > 0.5:
				px[Vector2i(x, y)] = c
	for key in px:
		draw_rect(Rect2(Vector2(key), Vector2.ONE), px[key])
	# One dark edge round the whole branch, a shade of what it borders, as the tree has.
	var edge := {}
	for key in px:
		for o in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var q: Vector2i = key + o
			if not px.has(q) and not edge.has(q):
				edge[q] = true
				draw_rect(Rect2(Vector2(q), Vector2.ONE), (px[key] as Color).darkened(0.6))
