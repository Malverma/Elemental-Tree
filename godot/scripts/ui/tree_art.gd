class_name TreeArt
extends Control
## Draws the Elemental Tree. Roots, trunk and branches each grow with their level.
## Tapping the crown or the trunk emits `tapped` with the tap's global position
## and which part was hit ("branches" or "trunk").

signal tapped(global_pos: Vector2, part: String)

# Drawing happens in a 320x300 design space, scaled to fit the control.
const DESIGN := Vector2(320, 300)
const TOP := 20.0  # design y that maps to the top edge
const GROUND := 220.0
const CX := 160.0

var tree: Dictionary
var _crown_center := Vector2.ZERO
var _crown_radius := 44.0
var _crown_bottom := 0.0  # design y where the leaves end and the bare trunk begins
var _trunk_top := 0.0
var _trunk_top_w := 0.0
var _trunk_base_w := 0.0
var _seed := 7


func _init(p_tree: Dictionary) -> void:
	tree = p_tree
	mouse_filter = MOUSE_FILTER_PASS  # taps are handled here; drags scroll the page
	custom_minimum_size = Vector2(0, 520)


func _rand() -> float:
	_seed = (_seed * 9301 + 49297) % 233280
	return _seed / 233280.0


func _scale() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _origin() -> Vector2:
	return (size - DESIGN * _scale()) / 2.0


func _to_design(local: Vector2) -> Vector2:
	return (local - _origin()) / _scale() + Vector2(0, TOP)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_design(event.position)
		var part := ""
		# The bare trunk below the leaves wins over the crown's generous tap circle.
		if p.y > _crown_bottom and _hits_trunk(p):
			part = "trunk"
		elif p.distance_to(_crown_center) <= _crown_radius:
			part = "branches"
		if part != "":
			tapped.emit(get_global_transform() * event.position, part)
			accept_event()


# The trunk tapers from base to top; allow some slack so thin saplings are easy to hit.
func _hits_trunk(p: Vector2) -> bool:
	if p.y < _trunk_top or p.y > GROUND + 6.0:
		return false
	var t := (p.y - _trunk_top) / (GROUND - _trunk_top)
	return absf(p.x - CX) <= lerpf(_trunk_top_w, _trunk_base_w, t) + 10.0


static func _quad(a: Vector2, c: Vector2, b: Vector2, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


static func _cubic(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(a.bezier_interpolate(c1, c2, b, float(i) / n))
	return pts


func _leaf(p: Vector2, length: float, angle_deg: float) -> void:
	var r := deg_to_rad(angle_deg)
	var tip := p + Vector2(cos(r), sin(r)) * length
	var n := Vector2(-sin(r), cos(r)) * length * 0.35
	var mid := (p + tip) / 2.0
	var pts := _quad(p, mid + n, tip)
	pts.append_array(_quad(tip, mid - n, p))
	draw_colored_polygon(pts, UI.LEAF)
	draw_polyline(pts, UI.LEAF_DARK, 1.5, true)


func _draw() -> void:
	_seed = 7
	var level: int = tree["level"]
	var roots: int = tree["roots"]
	var trunk: int = tree["trunk"]
	var branches: int = tree["branches"]
	var height := minf(175.0, 40.0 + 16.0 * level)
	var base_w := 5.0 + 3.5 * trunk
	var top_w := maxf(2.0, base_w * 0.35)
	var top := GROUND - height
	_trunk_top = top
	_trunk_top_w = top_w
	_trunk_base_w = base_w

	draw_set_transform(_origin() - Vector2(0, TOP) * _scale(), 0.0, Vector2.ONE * _scale())

	# Sky, soil cutaway and grass line.
	draw_polygon(PackedVector2Array([Vector2(0, TOP), Vector2(320, TOP), Vector2(320, GROUND), Vector2(0, GROUND)]),
		PackedColorArray([Color("#CFE8F5"), Color("#CFE8F5"), Color("#EAF4E4"), Color("#EAF4E4")]))
	draw_rect(Rect2(0, GROUND, 320, TOP + DESIGN.y - GROUND), UI.SOIL)
	var grass := _quad(Vector2(0, GROUND), Vector2(80, GROUND - 6), Vector2(160, GROUND))
	grass.append_array(_quad(Vector2(160, GROUND), Vector2(240, GROUND + 6), Vector2(320, GROUND)))
	grass.append(Vector2(320, GROUND + 6))
	grass.append(Vector2(0, GROUND + 6))
	draw_colored_polygon(grass, UI.GRASS)

	# Roots: more and longer with each level; tips glow where they reach new land.
	var root_count := 2 + 2 * roots
	for i in root_count:
		var side := 1.0 if i % 2 else -1.0
		var spread := (floorf(i / 2.0) + 1.0) / (root_count / 2.0 + 1.0)
		var length := 30.0 + 16.0 * roots * (0.6 + _rand() * 0.4)
		var end := Vector2(CX + side * spread * minf(150.0, length * 1.6), GROUND + 18.0 + (1.0 - spread) * minf(90.0, length))
		var w := maxf(1.5, base_w * 0.5 * (1.0 - spread * 0.6))
		draw_polyline(_quad(Vector2(CX + side * base_w * 0.3, GROUND + 2), Vector2(CX + side * spread * 30.0, end.y - 8), end),
			UI.BARK_DARK, w, true)
		if roots > 0:
			draw_circle(end, 2.5, UI.ROOT_GLOW)

	# Branches: one more pair per level, each ending in a leaf cluster.
	var clusters := []
	for i in branches * 2:
		var side := 1.0 if i % 2 else -1.0
		var t := 0.35 + 0.55 * ((floorf(i / 2.0) + 0.5) / maxf(1.0, branches))
		var by := GROUND - height * t
		var length := 18.0 + height * 0.28 * (1.1 - t * 0.5)
		var end := Vector2(CX + side * length, by - length * 0.55)
		draw_polyline(_quad(Vector2(CX, by), Vector2(CX + side * length * 0.5, by - 2), end), UI.BARK, maxf(2.0, top_w), true)
		clusters.append([end, 10.0 + length * 0.35])

	# Trunk with sap veins (one per trunk level).
	var body := _cubic(Vector2(CX - base_w, GROUND + 2), Vector2(CX - base_w * 0.7, GROUND - height * 0.4),
		Vector2(CX - top_w, top + 20), Vector2(CX - top_w, top))
	body.append_array(_cubic(Vector2(CX + top_w, top), Vector2(CX + top_w, top + 20),
		Vector2(CX + base_w * 0.7, GROUND - height * 0.4), Vector2(CX + base_w, GROUND + 2)))
	draw_colored_polygon(body, UI.BARK)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, UI.BARK_DARK, 2.0, true)
	for i in trunk:
		var off := ((i + 1.0) / (trunk + 1.0) - 0.5) * base_w * 1.1
		draw_polyline(_quad(Vector2(CX + off, GROUND - 4), Vector2(CX + off * 0.6, GROUND - height * 0.5), Vector2(CX + off * 0.3, top + 12)),
			Color(UI.SAP, 0.85), 1.6, true)

	# Crown: a sapling has three leaves; a grown tree has a canopy.
	_crown_center = Vector2(CX, top)
	_crown_radius = 44.0
	_crown_bottom = top + 8.0
	if level < 3 and branches == 0:
		_leaf(Vector2(CX, top + 2), 22, -150)
		_leaf(Vector2(CX, top + 2), 22, -30)
		_leaf(Vector2(CX, top), 16, -90)
	else:
		var r := 18.0 + level * 4.0
		_crown_radius = maxf(_crown_radius, r * 1.4)
		_crown_bottom = top + r
		clusters.append([Vector2(CX, top), r])
		clusters.append([Vector2(CX - r * 0.6, top + r * 0.3), r * 0.7])
		clusters.append([Vector2(CX + r * 0.6, top + r * 0.3), r * 0.7])
	for c in clusters:
		var p: Vector2 = c[0]
		var r: float = c[1]
		draw_circle(p, r, UI.LEAF)
		draw_arc(p, r, 0, TAU, 40, UI.LEAF_DARK, 2.0, true)
		draw_circle(p - Vector2(r, r) * 0.3, r * 0.35, Color(UI.LEAF_LIGHT, 0.7))
