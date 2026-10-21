class_name SnareBranch
extends Node2D
## The Bird Targeting perk's branch: it lashes out of the crown at a bird like
## a whip, a wave rolling down it from the leaves to the tip, which flicks a
## little past the bird and cracks back onto it, spearing it on its sharp point
## (`caught` fires so the Grove pops it and collects the loot), then the branch
## draws back into the leaves. It's one strip of art,
## assets/pixel/snare_branch.png (see art/gen/snare_branch.gd), bent pixel by
## pixel along the whip's curve and outlined as a whole, lit from the upper
## right like the tree. Lives in the Grove scene's art space (design pixels).

signal caught(bird: Dictionary)

const L := Vector2(0.55, -0.83)
const REACH_TIME := 0.5
const HOLD_TIME := 0.18
const RETRACT_TIME := 0.45
## The whip: how far the wave swings the branch off its line at first (design
## px, for a full-length branch), how fast it dies away, how many half-waves
## fit along the branch and how fast they roll from the leaves to the tip.
const WHIP_SWING := 9.0
const WHIP_DAMP := 5.0
const WHIP_WAVES := 2.4
const WHIP_SPEED := 12.0
## How far the tip flicks past the bird before cracking back onto it.
const WHIP_OVERSHOOT := 1.6
const CURVE_POINTS := 40  # points the curve is traced through for bending the strip

var birds: GroveBirds
var _strip: Image
var _bird: Dictionary = {}
var _root := Vector2.ZERO
var _swing := 0.0  # the whip's opening swing, signed for the side it bows to
var _wave_t := 0.0  # seconds since the whip was last cracked (out or back)
var _tip := Vector2.ZERO
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
	_tip = _root
	_swing = [-1.0, 1.0].pick_random() * WHIP_SWING * randf_range(0.8, 1.2)
	_wave_t = 0.0
	_grow = 0.0
	_t = 0.0
	_phase = "reach"


func _process(delta: float) -> void:
	if _phase == "":
		return
	_t += delta
	_wave_t += delta
	match _phase:
		"reach":
			# The tip follows the bird if it moves, easing out as it closes in.
			if _alive():
				_tip = GroveBirds.body(_bird)
			# Out fast, a flick past the bird, and back onto it (an ease-out-back).
			var x := minf(_t / REACH_TIME, 1.0) - 1.0
			_grow = 1.0 + (WHIP_OVERSHOOT + 1.0) * x * x * x + WHIP_OVERSHOOT * x * x
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
				# A smaller lash the other way as it lets go.
				_swing *= -0.5
				_wave_t = 0.0
		"retract":
			var x := minf(_t / RETRACT_TIME, 1.0)
			_grow = 1.0 - x * x * (3.0 - 2.0 * x)
			if _t >= RETRACT_TIME:
				_phase = ""
	queue_redraw()


func _alive() -> bool:
	return not _bird.is_empty() and birds.is_alive(_bird)


# A point `s` (0..1) along the branch as far as it has grown: the straight line
# from the leaves to the tip, swung off it by a wave rolling out toward the tip
# and dying away. It's pinned at both ends, so the root stays in the leaves
# and the tip stays on its mark.
func _at(s: float) -> Vector2:
	var end := _root.lerp(_tip, _grow)
	var dir := end - _root
	var length := dir.length()
	if length < 0.01:
		return _root
	var n := Vector2(-dir.y, dir.x) / length
	var swing := _swing * exp(-WHIP_DAMP * _wave_t) * clampf(length / 30.0, 0.25, 1.0)
	var wave := sin(PI * s) * cos(WHIP_WAVES * PI * s - WHIP_SPEED * _wave_t)
	return _root + dir * s + n * swing * wave


func _draw() -> void:
	if _phase == "":
		return
	# The curve as a polyline with the distance along it at each point.
	var pts: Array[Vector2] = []
	var dist: Array[float] = []
	var length := 0.0
	for k in CURVE_POINTS + 1:
		var q := _at(float(k) / CURVE_POINTS)
		if k > 0:
			length += q.distance_to(pts[k - 1])
		pts.append(q)
		dist.append(length)
	if length < 1.0:
		return
	# The strip's lit rows (the top half) go to the side facing the light;
	# fixed for the whole strike, so the shading doesn't flip as it whips.
	var line := _tip - _root
	var flip := -1.0 if Vector2(-line.y, line.x).dot(L) > 0.0 else 1.0
	# The strip bent along the curve: it slides out point first, so the column
	# at distance d along it is the one (length - d) back from the point.
	var px := {}  # Vector2i -> Color
	var seg := 0
	var d := 0.0
	while d <= length:
		while seg < CURVE_POINTS - 1 and dist[seg + 1] < d:
			seg += 1
		var a := pts[seg]
		var b := pts[seg + 1]
		var span := dist[seg + 1] - dist[seg]
		var p := a.lerp(b, (d - dist[seg]) / span if span > 0.0001 else 0.0)
		# The normal, eased across the joints so the bark bends without kinks.
		var t := b - pts[maxi(seg - 1, 0)] + pts[mini(seg + 2, CURVE_POINTS)] - a
		var n := Vector2(-t.y, t.x).normalized() * flip if t.length() > 0.0001 else Vector2.UP
		var u := clampi(int(_strip.get_width() - 1 - (length - d)), 0, _strip.get_width() - 1)
		var v := 0.0
		while v < _strip.get_height():
			var c := _strip.get_pixel(u, int(v))
			if c.a > 0.5:
				var key := Vector2i((p + n * (v + 0.25 - _strip.get_height() / 2.0)).floor())
				px[key] = c
			v += 0.5
		d += 0.5
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
