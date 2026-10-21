class_name BattleCanvas
extends Control
## Steps a BattleSim in real time and draws it. Emits `finished` once when it ends.

signal finished

# Units only move inside the lane band, so only that part of the field is shown.
const VIEW := Rect2(BattleSim.MIN_X - 45.0, 0.0, BattleSim.MAX_X - BattleSim.MIN_X + 90.0, BattleSim.H)

## Screen pixels per art pixel for the tiled pixel-art ground.
const PIXEL := 4.0

var sim: BattleSim
var speed := 1.0
## Screen space the battle view's controls cover at the top; the fight fits below.
var inset_top := 0.0:
	set(v):
		inset_top = v
		queue_redraw()
var _grounds := {}
## The potion mushroom's drawn size in field units: on a painted battlefield its
## 16 px sprite takes that art's pixel size, so it matches the mushrooms in it.
var _shroom_size := SHROOM_SIZE
var paused := false
var _done := false
var _t := 0.0  # seconds since the battle opened, for the drifting motes

# Dungeons and expeditions fight on the battlefield of their element's home land.
const ELEMENT_BACKDROP := {
	"nature": "brambleheart_thicket", "water": "sunken_lagoon", "fire": "ember_vent",
	"ice": "frostbite_hollow", "dark": "gloomroot_cavern",
}
# Motes drifting over the field, per element: pollen, spray, embers, snow, spores.
# `vel` and `sway` are in art pixels per second.
const MOTES := {
	"nature": {"color": Color("#F4FF9A"), "vel": Vector2(1.6, -1.0), "sway": 3.0},
	"water": {"color": Color("#D8F4FF"), "vel": Vector2(0.6, -2.2), "sway": 2.0},
	"fire": {"color": Color("#FFB347"), "vel": Vector2(0.4, -6.0), "sway": 2.0},
	"ice": {"color": Color("#FFFFFF"), "vel": Vector2(-1.0, 4.5), "sway": 3.0},
	"dark": {"color": Color("#C8A2FF"), "vel": Vector2(-0.4, -1.6), "sway": 2.5},
}
const MOTE_COUNT := 28
const SHROOM_SIZE := 46.0  # drawn size of a potion mushroom, in field units, on the tiled ground
const SHROOM_REACH := 48.0  # how far from its middle a tap still picks it


func _init(p_sim: BattleSim) -> void:
	sim = p_sim
	# Taps pass through to the battle view unless they pick the potion mushroom.
	mouse_filter = MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if sim.shroom == "" or sim.is_over():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var xf := _view_xf()
		var at: Vector2 = (event.position - xf[0]) / xf[1] + VIEW.position
		if at.distance_to(sim.shroom_pos - Vector2(0, _shroom_size * 0.45)) <= SHROOM_REACH:
			Game.pick_battle_shroom(sim)
			accept_event()


func _process(delta: float) -> void:
	_t += delta
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


# The ground tile for an element, set to repeat with crisp pixels.
func _ground(element: String) -> CanvasTexture:
	if not _grounds.has(element):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = UI.tex("ground_" + element)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_grounds[element] = ct
	return _grounds[element]


# The battle area in screen space: VIEW fitted below the controls, centred.
func _view_xf() -> Array:
	var avail := Vector2(size.x, maxf(1.0, size.y - inset_top - 12.0))
	var s := minf(avail.x / VIEW.size.x, avail.y / VIEW.size.y)
	var origin := Vector2((size.x - VIEW.size.x * s) / 2.0, inset_top + (avail.y - VIEW.size.y * s) / 2.0)
	return [origin, s]


# The painted battlefield (assets/pixel/battle_<land>.png): the land's own, or
# for a dungeon or an expedition wave, its element's home land's.
func _backdrop() -> Texture2D:
	var id: String = sim.level_id if GameData.LEVELS.has(sim.level_id) else ELEMENT_BACKDROP.get(sim.element(), "")
	if not UI.is_pixel("battle_" + id):
		return null
	return UI.crisp("battle_" + id)


func _mote_elements() -> Array:
	return GameData.LEVELS[sim.level_id]["elements"] if GameData.LEVELS.has(sim.level_id) else [sim.element()]


# Motes snap to the art's pixel grid (`px` screen pixels per art pixel) and wrap around the screen.
func _draw_motes(px: float) -> void:
	var els := _mote_elements()
	for i in MOTE_COUNT:
		var m: Dictionary = MOTES[els[i % els.size()]]
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var p: Vector2 = Vector2(h1 * size.x, h2 * size.y) + m["vel"] * (0.7 + h1 * 0.6) * _t * px
		p.x += sin(_t * (0.5 + h2) + i) * m["sway"] * px
		p = (Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y)) / px).floor() * px
		var a := 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * (1.2 + h1 * 2.0) + i * 2.0))
		draw_rect(Rect2(p, Vector2(px, px)), Color(m["color"], a))


func _draw() -> void:
	var xf := _view_xf()
	var origin: Vector2 = xf[0]
	var s: float = xf[1]
	var x0 := VIEW.position.x
	var w := VIEW.size.x
	var h := VIEW.size.y
	var tint: Color = GameData.BIOME_COLORS[sim.element()]

	# The ground fills the whole screen: a land's painted battlefield, or its element's tiles.
	var bg := _backdrop()
	var art_px := PIXEL
	if bg:
		var bs := maxf(size.x / bg.get_width(), size.y / bg.get_height())
		var bsize := Vector2(bg.get_width(), bg.get_height()) * bs
		draw_texture_rect(bg, Rect2((size - bsize) / 2.0, bsize), false)
		art_px = bs
	else:
		var px_size := size / PIXEL
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(PIXEL, PIXEL))
		draw_texture_rect(_ground(sim.element()), Rect2(Vector2.ZERO, px_size), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The enemy side shades softly toward the top.
	var mid := origin.y + h * s / 2.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, mid), Vector2(0, mid)]),
		PackedColorArray([Color(tint.darkened(0.6), 0.22), Color(tint.darkened(0.6), 0.22), Color(tint.darkened(0.6), 0.0), Color(tint.darkened(0.6), 0.0)]))
	_draw_motes(art_px)
	draw_set_transform(origin - VIEW.position * s, 0.0, Vector2(s, s))

	# The potion mushroom bobs gently, a glint winking on its cap.
	if sim.shroom != "":
		_shroom_size = 16.0 * art_px / s if bg else SHROOM_SIZE
		var size_f := _shroom_size
		var bob := sin(_t * 2.4) * 2.0
		var r := Rect2(sim.shroom_pos - Vector2(size_f / 2, size_f - bob), Vector2(size_f, size_f))
		draw_set_transform(origin - VIEW.position * s + Vector2(0, -size_f * 0.1) * s, 0.0, Vector2(s, s * 0.35))
		draw_circle(Vector2(sim.shroom_pos.x, sim.shroom_pos.y / 0.35), size_f * 0.26, Color(0, 0, 0, 0.25))
		draw_set_transform(origin - VIEW.position * s, 0.0, Vector2(s, s))
		draw_texture_rect(UI.crisp(GameData.ITEMS[sim.shroom]["shroom"]), r, false)
		if fmod(_t, 1.6) < 0.25:
			draw_rect(Rect2(r.position + Vector2(9, 6) * size_f / 16.0, Vector2.ONE * size_f / 16.0), Color.WHITE)  # one art pixel on the cap's lit side

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
			draw_set_transform(origin - VIEW.position * s + u.pos * s + Vector2(0, sz * 0.38) * s, 0.0, Vector2(s * 1.6, s * 0.6))
			draw_circle(Vector2.ZERO, sz * 0.25, Color(GameData.BIOME_COLORS[el], 0.55))
			draw_set_transform(origin - VIEW.position * s, 0.0, Vector2(s, s))
		var tint_u := Color.WHITE
		if u.flash > 0.0:
			tint_u = Color(1.8, 1.8, 1.8)
		elif u.frozen_t > 0.0:
			tint_u = Color(0.55, 0.8, 1.5)
		elif u.burn_t > 0.0:
			tint_u = Color(1.5, 0.75, 0.55)
		elif u.slow_t > 0.0:
			tint_u = Color(0.75, 0.9, 1.2)
		draw_texture_rect(UI.crisp(u.def["img"]), Rect2(u.pos - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, tint_u)
		var bw := sz * 0.7
		var top: Vector2 = u.pos - Vector2(bw / 2, sz / 2 + 10)
		draw_rect(Rect2(top, Vector2(bw, 7)), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(top, Vector2(bw * u.hp / u.max_hp, 7)), UI.LEAF if u.side == "ally" else Color("#D9534F"))
		if el != "":
			draw_texture_rect(UI.crisp("icon_" + el), Rect2(top + Vector2(-20, -7), Vector2(18, 18)), false)

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
		var size := 24
		if p.crit:
			# Critical hits stand out: a bigger gold number under a "CRIT!" tag.
			col = Color("#FFD447") if p.side == "enemy" else Color("#FF5A3C")
			size = 32
			var tag := at - Vector2(0, 28)
			draw_string_outline(font, tag, "CRIT!", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 5, Color(0, 0, 0, 0.7 * a))
			draw_string(font, tag, "CRIT!", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(col, a))
		draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, 5, Color(0, 0, 0, 0.6 * a))
		draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(col, a))

	if sim.phase == "intermission":
		draw_rect(Rect2(x0, h / 2 - 40, w, 80), Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(x0, h / 2 + 12), "Wave %d cleared!" % (sim.wave + 1), HORIZONTAL_ALIGNMENT_CENTER, w, 36, Color("#FFF6D8"))
