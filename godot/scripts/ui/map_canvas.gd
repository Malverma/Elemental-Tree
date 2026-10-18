class_name MapCanvas
extends Control
## Draws the world map: biomes, root paths, the home grove and level nodes.
## Tapping a level node emits `level_selected` (with "grove" for the Home Grove,
## or a dungeon's id for one of the dungeons that come and go on the map).

signal level_selected(id: String)

const DESIGN := GameData.MAP_SIZE
const NODE_R := 36.0
const DUNGEON_R := 30.0

var selected: String


func _init(p_selected: String) -> void:
	selected = p_selected
	mouse_filter = MOUSE_FILTER_PASS  # taps are handled here; drags scroll the page
	clip_contents = true  # keeps biome tints inside the map
	custom_minimum_size = Vector2(0, DESIGN.y)


func _scale() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _origin() -> Vector2:
	return (size - DESIGN * _scale()) / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event.position - _origin()) / _scale()
		if p.distance_to(GameData.GROVE) <= 40 + 10:
			level_selected.emit("grove")
			accept_event()
			return
		for id in GameData.LEVEL_ORDER:
			if p.distance_to(GameData.LEVELS[id]["pos"]) <= NODE_R + 10:
				level_selected.emit(id)
				accept_event()
				return
		for d in Game.state["dungeons"]:
			if p.distance_to(Vector2(d["x"], d["y"])) <= DUNGEON_R + 10:
				level_selected.emit(Game.dungeon_id(d))
				accept_event()
				return


static func _path_points(from: String, to: String) -> PackedVector2Array:
	return GameData.root_path_points(from, to)


func _dashed(pts: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], color, width, true)


# `halo` rims the text in the map colour so root paths crossing it stay readable.
func _text(at: Vector2, text: String, font_size: int, color: Color, bold := false, halo := false) -> void:
	var font: Font = UI.bold_font() if bold else ThemeDB.fallback_font
	if halo:
		draw_string_outline(font, at - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, 8, Color(UI.MAP_BG, 0.9))
	draw_string(font, at - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, color)


# Half of a disc, starting at angle `from` and sweeping clockwise by PI.
func _half_disc(center: Vector2, r: float, from: float, color: Color) -> void:
	var pts := PackedVector2Array([center])
	for i in 25:
		pts.append(center + Vector2.from_angle(from + PI * i / 24.0) * r)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	draw_set_transform(_origin(), 0.0, Vector2.ONE * _scale())
	draw_rect(Rect2(Vector2.ZERO, DESIGN), UI.MAP_BG)
	var reach := Game.reach()

	# Biome regions: a two-element land blends two patches side by side.
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var els: Array = l["elements"]
		for i in els.size():
			var off := Vector2(0.0 if els.size() == 1 else (i - 0.5) * 50.0, 0.0)
			draw_set_transform(_origin() + (l["pos"] + off) * _scale(), 0.0, Vector2(1.2, 1.0) * _scale())
			draw_circle(Vector2.ZERO, 80 if els.size() == 1 else 62, Color(GameData.BIOME_COLORS[els[i]], 0.18))
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
	if selected == "grove":
		draw_arc(g, 40, 0, TAU, 48, UI.ROOT_GLOW, 6, true)
	else:
		draw_arc(g, 40, 0, TAU, 48, UI.LEAF_DARK, 3, true)
	_text(g + Vector2(0, 66), "Home Grove", 20, UI.INK, true)

	# Level nodes.
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var ls := Game.level_state(id)
		var p: Vector2 = l["pos"]
		var alpha := 1.0
		var els: Array = l["elements"]
		if not l["playable"]:
			alpha = 0.65
		elif not Game.can_reach(id):
			alpha = 0.55
		# One element fills the node; two split it down the middle, each with its icon.
		for i in els.size():
			var fill: Color = GameData.BIOME_COLORS[els[i]]
			if not l["playable"]:
				fill = fill.lerp(Color(0.6, 0.6, 0.6), 0.75)
			if els.size() == 1:
				draw_circle(p, NODE_R, Color(fill, alpha))
			else:
				_half_disc(p, NODE_R, PI / 2 + PI * i, Color(fill, alpha))
		if els.size() == 2:
			draw_line(p - Vector2(0, NODE_R), p + Vector2(0, NODE_R), Color(UI.INK, alpha), 2, true)
		var ring := UI.ROOT_GLOW if id == selected else UI.INK
		draw_arc(p, NODE_R, 0, TAU, 48, Color(ring, alpha), 6 if id == selected else 3, true)
		if els.size() == 1:
			draw_texture_rect(UI.tex("icon_" + els[0]), Rect2(p - Vector2(20, 20), Vector2(40, 40)), false, Color(1, 1, 1, alpha))
		else:
			for i in 2:
				draw_texture_rect(UI.tex("icon_" + els[i]), Rect2(p + Vector2(-30 + 32 * i, -14), Vector2(28, 28)), false, Color(1, 1, 1, alpha))
		if ls["conquered"]:
			draw_circle(p + Vector2(27, -27), 10, UI.ROOT_GLOW)
			draw_arc(p + Vector2(27, -27), 10, 0, TAU, 24, UI.INK, 2, true)

	_draw_dungeons()

	# Land names, drawn last so roots and dungeons never cover them.
	for id in GameData.LEVEL_ORDER:
		var l: Dictionary = GameData.LEVELS[id]
		var p: Vector2 = l["pos"]
		var alpha := 1.0 if Game.can_reach(id) else 0.55
		var sub := "Reach %d" % l["distance"] if l["playable"] else "Coming soon"
		var top := p + (Vector2(0, -NODE_R - 54) if GameData.label_above(id) else Vector2(0, NODE_R + 4))
		_text(top + Vector2(0, 22), l["name"], 20, Color(UI.INK, maxf(alpha, 0.8)), true, true)
		_text(top + Vector2(0, 44), sub, 17, UI.MUTED, false, true)


# Dungeons: a cave mouth on a patch of its element's colour, faded until the roots reach it.
func _draw_dungeons() -> void:
	for d in Game.state["dungeons"]:
		var p := Vector2(d["x"], d["y"])
		var id := Game.dungeon_id(d)
		var alpha := 1.0 if d["distance"] <= Game.reach() else 0.55
		draw_circle(p, DUNGEON_R + 8, Color(GameData.BIOME_COLORS[d["element"]], 0.35 * alpha))
		draw_circle(p, DUNGEON_R, Color(UI.BARK_DARK, alpha))
		var ring: Color = UI.ROOT_GLOW if id == selected else GameData.BIOME_COLORS[d["element"]]
		draw_arc(p, DUNGEON_R, 0, TAU, 40, Color(ring, alpha), 5 if id == selected else 3, true)
		draw_texture_rect(UI.tex("dungeon"), Rect2(p - Vector2(26, 26), Vector2(52, 52)), false, Color(1, 1, 1, alpha))
		draw_texture_rect(UI.tex("icon_" + d["element"]), Rect2(p + Vector2(14, -34), Vector2(22, 22)), false, Color(1, 1, 1, alpha))
		_text(p + Vector2(0, DUNGEON_R + 24), GameData.DUNGEON_NAMES[d["element"]], 18, Color(UI.INK, maxf(alpha, 0.8)), true)
		_text(p + Vector2(0, DUNGEON_R + 44), "Dungeon · Reach %d" % d["distance"], 16, UI.MUTED)
