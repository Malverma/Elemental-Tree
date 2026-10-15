class_name BattleCanvas
extends Control
## Steps a BattleSim in real time and draws it. Emits `finished` once when it ends.

signal finished

# Units only move inside the lane band, so only that part of the field is shown.
const VIEW := Rect2(BattleSim.MIN_X - 45.0, 0.0, BattleSim.MAX_X - BattleSim.MIN_X + 90.0, BattleSim.H)

var sim: BattleSim
var speed := 1.0
var paused := false
var _done := false


func _init(p_sim: BattleSim) -> void:
	sim = p_sim
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not paused and not sim.is_over():
		var remaining := minf(delta, 0.05) * speed
		while remaining > 0.0 and not sim.is_over():
			var step := minf(1.0 / 60.0, remaining)
			sim.step(step)
			remaining -= step
	queue_redraw()
	if sim.is_over() and not _done:
		_done = true
		finished.emit()


func _draw() -> void:
	var s := size.x / VIEW.size.x
	draw_set_transform(-VIEW.position * s, 0.0, Vector2(s, s))
	var x0 := VIEW.position.x
	var w := VIEW.size.x
	var h := VIEW.size.y
	var tint: Color = GameData.BIOME_COLORS[sim.level["element"]]

	# Ground, enemy territory tint and lane paths.
	draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + w, 0), Vector2(x0 + w, h), Vector2(x0, h)]),
		PackedColorArray([Color("#BFD9A8"), Color("#BFD9A8"), Color("#DCEFD8"), Color("#DCEFD8")]))
	draw_rect(Rect2(x0, 0, w, h / 2), Color(tint, 0.25))
	for x in BattleSim.LANE_X:
		draw_rect(Rect2(x - 3, 0, 6, h), Color(0.31, 0.24, 0.12, 0.12))

	# Units, back to front so lower units overlap higher ones.
	var units: Array = []
	for u in sim.allies + sim.enemies:
		if u.alive():
			units.append(u)
	units.sort_custom(func(a, b) -> bool: return a.pos.y < b.pos.y)
	for u in units:
		var sz: float = u.size * 1.25  # drawn a bit larger than the collision size
		var el: String = u.def.get("element", "")
		# Elemental troops stand on a glowing ring of their element's colour.
		if u.side == "ally" and el != "":
			draw_set_transform(-VIEW.position * s + u.pos * s + Vector2(0, sz * 0.38) * s, 0.0, Vector2(s * 1.6, s * 0.6))
			draw_circle(Vector2.ZERO, sz * 0.25, Color(GameData.BIOME_COLORS[el], 0.55))
			draw_set_transform(-VIEW.position * s, 0.0, Vector2(s, s))
		var tint_u := Color.WHITE
		if u.flash > 0.0:
			tint_u = Color(1.8, 1.8, 1.8)
		elif u.frozen_t > 0.0:
			tint_u = Color(0.55, 0.8, 1.5)
		elif u.burn_t > 0.0:
			tint_u = Color(1.5, 0.75, 0.55)
		elif u.slow_t > 0.0:
			tint_u = Color(0.75, 0.9, 1.2)
		draw_texture_rect(UI.tex(u.def["img"]), Rect2(u.pos - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, tint_u)
		var bw := sz * 0.7
		var top: Vector2 = u.pos - Vector2(bw / 2, sz / 2 + 10)
		draw_rect(Rect2(top, Vector2(bw, 7)), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(top, Vector2(bw * u.hp / u.max_hp, 7)), UI.LEAF if u.side == "ally" else Color("#D9534F"))
		if el != "":
			draw_texture_rect(UI.tex("icon_" + el), Rect2(top + Vector2(-20, -7), Vector2(18, 18)), false)

	for p in sim.projectiles:
		draw_circle(p.pos, 5, p.color)
		draw_arc(p.pos, 5, 0, TAU, 12, UI.INK, 1.5, true)

	var font := UI.bold_font()
	for p in sim.popups:
		var a := 1.0 - p.t / 0.8
		var at: Vector2 = p.pos - Vector2(60, p.t * 30)
		var col := Color("#B83A2E") if p.side == "ally" else Color("#FFF6D8")
		if p.burn:
			col = Color("#FF8A3D")
		draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 24, 5, Color(0, 0, 0, 0.6 * a))
		draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color(col, a))

	if sim.phase == "intermission":
		draw_rect(Rect2(x0, h / 2 - 40, w, 80), Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(x0, h / 2 + 12), "Wave %d cleared!" % (sim.wave + 1), HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color("#FFF6D8"))
