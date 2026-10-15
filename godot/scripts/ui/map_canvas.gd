class_name MapCanvas
extends Control
## Draws the world map: biomes, root paths, the home grove and level nodes.
## Tapping a level node emits `level_selected`.

signal level_selected(id: String)

const DESIGN := Vector2(680, 640)
const NODE_R := 36.0

var selected: String


func _init(p_selected: String) -> void:
	selected = p_selected
	mouse_filter = MOUSE_FILTER_PASS  # taps are handled here; drags scroll the page
	clip_contents = true  # keeps biome tints inside the map
	custom_minimum_size = Vector2(0, 640)


func _scale() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _origin() -> Vector2:
	return (size - DESIGN * _scale()) / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event.position - _origin()) / _scale()
		for id in GameData.LEVEL_ORDER:
			if p.distance_to(GameData.LEVELS[id]["pos"]) <= NODE_R + 10:
				level_selected.emit(id)
				accept_event()
				return


static func _path_points(from: String, to: String) -> PackedVector2Array:
	var a := GameData.node_pos(from)
	var b := GameData.node_pos(to)
	var mid := (a + b) / 2.0 + Vector2(b.y - a.y, -(b.x - a.x)) * 0.15
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


func _dashed(pts: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], color, width, true)


func _text(at: Vector2, text: String, font_size: int, color: Color, bold := false) -> void:
	var font: Font = UI.bold_font() if bold else ThemeDB.fallback_font
	draw_string(font, at - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, color)


func _draw() -> void:
	draw_set_transform(_origin(), 0.0, Vector2.ONE * _scale())
	draw_rect(Rect2(Vector2.ZERO, DESIGN), UI.MAP_BG)
	var reach := Game.reach()

	# Biome regions.
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		draw_set_transform(_origin() + l["pos"] * _scale(), 0.0, Vector2(1.2, 1.0) * _scale())
		draw_circle(Vector2.ZERO, 85, Color(GameData.BIOME_COLORS[l["element"]], 0.18))
	draw_set_transform(_origin(), 0.0, Vector2.ONE * _scale())

	# Root paths: thick and glowing once the roots reach them, dashed before.
	var nodes := GameData.WAYPOINTS.duplicate()
	nodes.merge(GameData.LEVELS)
	for id in nodes:
		var n: Dictionary = nodes[id]
		var pts := _path_points(n["from"], id)
		if n["distance"] <= reach:
			draw_polyline(pts, UI.BARK_DARK, 12, true)
			_dashed(pts, UI.ROOT_GLOW, 3)
		else:
			_dashed(pts, Color(UI.BARK, 0.45), 4)

	# Home grove.
	var g := GameData.GROVE
	draw_rect(Rect2(g + Vector2(-5, 0), Vector2(10, 28)), UI.BARK)
	draw_circle(g, 40, UI.LEAF)
	draw_arc(g, 40, 0, TAU, 48, UI.LEAF_DARK, 3, true)
	_text(g + Vector2(0, 66), "Home Grove", 20, UI.INK, true)

	# Level nodes.
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var ls := Game.level_state(id)
		var p: Vector2 = l["pos"]
		var alpha := 1.0
		var fill: Color = GameData.BIOME_COLORS[l["element"]]
		if not l["playable"]:
			fill = fill.lerp(Color(0.6, 0.6, 0.6), 0.75)
			alpha = 0.65
		elif not Game.can_reach(id):
			alpha = 0.55
		draw_circle(p, NODE_R, Color(fill, alpha))
		var ring := UI.ROOT_GLOW if id == selected else UI.INK
		draw_arc(p, NODE_R, 0, TAU, 48, Color(ring, alpha), 6 if id == selected else 3, true)
		draw_texture_rect(UI.tex("icon_" + l["element"]), Rect2(p - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 1, 1, alpha))
		if ls["conquered"]:
			draw_circle(p + Vector2(27, -27), 10, UI.ROOT_GLOW)
			draw_arc(p + Vector2(27, -27), 10, 0, TAU, 24, UI.INK, 2, true)
		_text(p + Vector2(0, NODE_R + 26), l["name"], 20, Color(UI.INK, maxf(alpha, 0.8)), true)
		_text(p + Vector2(0, NODE_R + 48), "Reach %d" % l["distance"] if l["playable"] else "Coming soon", 17, UI.MUTED)
