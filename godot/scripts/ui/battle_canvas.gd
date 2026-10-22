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

# How each kind of shot (GameData "shot", art in assets/pixel/shot_<name>.png)
# is readied, thrown and flies:
#   windup  before the shot: "nock" (laid on the bow, drawn back), "orbit"
#           (whirled round the sling) or "grow" (gathers at the weapon)
#   kick    the shooter's jolt on release: 1 lunges toward the target, -1 recoils
#   orient  turns to face where it flies; `spin` (radians/s) tumbles it instead
#   arc     lob height as a fraction of the distance; `wobble` sways it sideways (art px)
#   trail   colours of the pixels it leaves behind; `burst` of the spray where it lands
const SHOTS := {
	"arrow": {"windup": "nock", "kick": -1, "orient": true, "trail": [Color("#E8E2D0")], "burst": [Color("#B8945E"), Color("#DCC08A"), Color("#4F9A3F")]},
	"acorn": {"windup": "orbit", "kick": 1, "spin": 14.0, "arc": 0.3, "trail": [], "burst": [Color("#A87444"), Color("#967040"), Color("#D6A46C")]},
	"tide": {"windup": "grow", "kick": 1, "orient": true, "wobble": 1.0, "trail": [Color("#BFE6FF"), Color("#5BA4E8")], "burst": [Color("#BFE6FF"), Color("#5BA4E8"), Color.WHITE]},
	"sap": {"windup": "grow", "kick": 1, "orient": true, "arc": 0.15, "trail": [Color("#F0C43A")], "burst": [Color("#F0C43A"), Color("#FFF0A0")]},
	"droplet": {"windup": "grow", "kick": 1, "orient": true, "trail": [Color("#BFE6FF")], "burst": [Color("#BFE6FF"), Color("#5BA4E8")]},
	"ember": {"windup": "grow", "kick": 1, "orient": true, "trail": [Color("#FFD166"), Color("#F0742D"), Color("#5E5450")], "burst": [Color("#FFD166"), Color("#F0742D"), Color("#C8361E")]},
	"icicle": {"windup": "grow", "kick": 1, "orient": true, "trail": [Color("#EFFBFF")], "burst": [Color("#EFFBFF"), Color("#A6DCF0"), Color("#4AA3C9")]},
	"pollen": {"windup": "grow", "kick": 1, "spin": 2.5, "wobble": 2.5, "trail": [Color("#FFF6B0"), Color("#FFD447")], "burst": [Color("#FFD447"), Color("#FFF6B0")]},
	"bubble": {"windup": "grow", "kick": 1, "wobble": 1.5, "trail": [], "burst": [Color("#9AE0DC"), Color.WHITE]},
	"foam": {"windup": "grow", "kick": 1, "orient": true, "wobble": 1.0, "trail": [Color("#E2D8C2"), Color("#BFE6FF")], "burst": [Color("#FFFAF0"), Color("#BFE6FF"), Color("#5BA4E8")]},
}
## Where each ranged unit holds its weapon, in its sprite's art pixels.
const MUZZLE := {
	"troop_archer": Vector2(24, 18), "troop_acorn_slinger": Vector2(28, 8), "troop_tide_caller": Vector2(25.5, 12.5),
	"troop_sap_mender": Vector2(25, 1), "enemy_ripple_sprite": Vector2(6, 15), "enemy_ash_moth": Vector2(12, 10),
	"enemy_icicle_bat": Vector2(15.5, 23), "enemy_pollen_wisp": Vector2(16, 27), "enemy_bubble_eel": Vector2(3, 14),
	"enemy_wild_tide_caller": Vector2(6, 13),
}
const WINDUP_TIME := 0.3  # seconds of readying before a shot
const KICK_TIME := 0.18
const SHOT_ART := 12.0  # shot sprites are 12 art px square


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
		draw_texture_rect(UI.crisp(u.def["img"]), Rect2(u.pos + _pose(u) - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, tint_u)
		var bw := sz * 0.7
		var top: Vector2 = u.pos - Vector2(bw / 2, sz / 2 + 10)
		draw_rect(Rect2(top, Vector2(bw, 7)), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(top, Vector2(bw * u.hp / u.max_hp, 7)), UI.LEAF if u.side == "ally" else Color("#D9534F"))
		if el != "":
			draw_texture_rect(UI.crisp("icon_" + el), Rect2(top + Vector2(-20, -7), Vector2(18, 18)), false)

	var base := origin - VIEW.position * s
	for u in units:
		if u.def.has("shot"):
			_draw_shooter(u, base, s)
	for p in sim.projectiles:
		_draw_projectile(p, base, s)
	for im in sim.impacts:
		_draw_impact(im)

	var font := UI.bold_font()
	for p in sim.popups:
		var a := 1.0 - p.t / 0.8
		var at: Vector2 = p.pos - Vector2(60, p.t * 30)
		var col := Color("#B83A2E") if p.side == "ally" else Color("#FFF6D8")
		if p.burn:
			col = Color("#FF8A3D")
		if p.heal:
			col = Color("#8FE07A")
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


# --- Shots ---------------------------------------------------------------------

# Field units per art pixel of a unit's sprite.
static func _art_px(u: BattleSim.Unit) -> float:
	return u.size * 1.25 / (48.0 if u.def.get("large", false) else 32.0)


# Where `u` holds its weapon, as an offset from its middle.
static func _muzzle(u: BattleSim.Unit) -> Vector2:
	var m: Vector2 = MUZZLE.get(u.def["img"], Vector2(16, 16))
	return (m - Vector2(16, 16)) * _art_px(u)


# 0..1 while `u` readies a shot at a foe in reach, else 0.
func _windup(u: BattleSim.Unit) -> float:
	if not u.def.has("shot") or u.frozen_t > 0.0 or u.cd >= WINDUP_TIME or u.target == null or not u.target.alive():
		return 0.0
	var reach: float = (u.def["reach"] + (sim.boost("reach") if u.side == "ally" else 0.0)) * GameData.REACH_UNIT + BattleSim.BODY * 1.6
	if u.pos.distance_to(u.target.pos) > reach + 2.0:
		return 0.0
	return clampf(1.0 - u.cd / WINDUP_TIME, 0.0, 1.0)


# A shooter's lean while readying (away from the target) and its jolt on
# release, in whole art pixels so the sprite stays on its grid.
func _pose(u: BattleSim.Unit) -> Vector2:
	if not u.def.has("shot"):
		return Vector2.ZERO
	var px := _art_px(u)
	var look: Dictionary = SHOTS.get(u.def["shot"], {})
	var off := Vector2.ZERO
	var w := _windup(u)
	if w > 0.0:
		off -= (u.target.pos - u.pos).normalized() * w
	if u.shot_t < KICK_TIME:
		off += u.aim * look.get("kick", 1) * 1.5 * (1.0 - u.shot_t / KICK_TIME)
	return off.round() * px


# Draws a shot sprite at `pos` (field units), turned by `angle` and scaled.
func _draw_shot(shot: String, pos: Vector2, angle: float, scale: float, px: float, base: Vector2, s: float, alpha := 1.0) -> void:
	if not UI.is_pixel("shot_" + shot):
		draw_circle(pos, 5, Color.WHITE)
		return
	var half := SHOT_ART * px * scale / 2.0
	draw_set_transform(base + pos * s, angle, Vector2(s, s))
	draw_texture_rect(UI.crisp("shot_" + shot), Rect2(-half, -half, half * 2.0, half * 2.0), false, Color(1, 1, 1, alpha))
	draw_set_transform(base, 0.0, Vector2(s, s))


# The shot readied at the weapon, and the puff as it leaves.
func _draw_shooter(u: BattleSim.Unit, base: Vector2, s: float) -> void:
	var look: Dictionary = SHOTS.get(u.def["shot"], {})
	var px := _art_px(u)
	var at: Vector2 = u.pos + _pose(u) + _muzzle(u)
	var w := _windup(u)
	if w > 0.0:
		var dir: Vector2 = (u.target.pos - at).normalized()
		match look.get("windup", "grow"):
			"nock":
				# Laid on the string and drawn back as the bow bends.
				_draw_shot(u.def["shot"], at - dir * w * 2.0 * px, dir.angle(), 1.0, px, base, s)
			"orbit":
				# Whirled round the sling, faster as it builds.
				var a := sim.time * (10.0 + 14.0 * w)
				_draw_shot(u.def["shot"], at + Vector2(cos(a), sin(a) * 0.6) * 3.0 * px, a * 1.5, 1.0, px, base, s)
			_:
				# Gathers at the weapon, swelling and flickering.
				var grow := 0.35 + 0.65 * w + 0.06 * sin(sim.time * 40.0)
				_draw_shot(u.def["shot"], at, dir.angle() if look.get("orient", false) else 0.0, grow, px, base, s, 0.6 + 0.4 * w)
	if u.shot_t < 0.12:
		var k := u.shot_t / 0.12
		var cols: Array = look.get("burst", [Color.WHITE])
		for i in 4:
			var a := u.aim.angle() + (i - 1.5) * 0.6
			var d := Vector2(cos(a), sin(a)) * (1.0 + 4.0 * k) * px
			draw_rect(Rect2((at + d - Vector2(px, px) / 2.0).snapped(Vector2(px, px)), Vector2(px, px)), Color(cols[i % cols.size()], 1.0 - k))


func _draw_projectile(p: BattleSim.Projectile, base: Vector2, s: float) -> void:
	var look: Dictionary = SHOTS.get(p.shot, {})
	var px := _art_px(p.attacker)
	var prog := clampf(p.age * BattleSim.PROJECTILE_SPEED / p.dist0, 0.0, 1.0)
	# It leaves from the weapon and eases onto the sim's straight line,
	# lobbed up in an arc and swaying if its kind does.
	var pos: Vector2 = p.pos + _muzzle(p.attacker) * (1.0 - prog)
	var arc: float = look.get("arc", 0.0) * p.dist0
	pos.y -= arc * sin(PI * prog)
	var fly: Vector2 = (p.target.pos - p.pos).normalized() if p.target.pos.distance_to(p.pos) > 0.5 else p.attacker.aim
	var vel: Vector2 = fly * p.dist0 + Vector2(0.0, -arc * PI * cos(PI * prog))
	pos += fly.orthogonal() * sin(p.age * 16.0) * look.get("wobble", 0.0) * px
	var back := -vel.normalized()
	var trail: Array = look.get("trail", [])
	for i in trail.size() * 2:
		var flick := 0.5 + 0.5 * sin(p.age * 50.0 + i * 2.1)
		var tp: Vector2 = pos + back * (4.0 + i * 2.5) * px + back.orthogonal() * (flick - 0.5) * px
		draw_rect(Rect2(tp - Vector2(px, px) / 2.0, Vector2(px, px)), Color(trail[i % trail.size()], (1.0 - float(i) / (trail.size() * 2)) * 0.85))
	var angle: float = vel.angle() if look.get("orient", false) else p.age * look.get("spin", 0.0)
	_draw_shot(p.shot, pos, angle, 1.0, px, base, s)


# Where a shot lands: a spray of pixels in its colours. A heal sends up green sparks.
func _draw_impact(im: BattleSim.Impact) -> void:
	var px := 2.0
	var k := im.t / 0.4
	if im.shot == "heal":
		for i in 4:
			var at := im.pos + Vector2((i - 1.5) * 9.0, -10.0 - k * 26.0 - (i % 2) * 8.0)
			var c := Color("#8FE07A", 1.0 - k)
			draw_rect(Rect2(at - Vector2(px * 1.5, px / 2.0), Vector2(px * 3.0, px)), c)
			draw_rect(Rect2(at - Vector2(px / 2.0, px * 1.5), Vector2(px, px * 3.0)), c)
		return
	var cols: Array = SHOTS.get(im.shot, {}).get("burst", [Color.WHITE])
	for i in 7:
		var a := i * TAU / 7.0 + 0.4
		var at := im.pos + Vector2(cos(a), sin(a) * 0.8) * (3.0 + k * 9.0) * px
		var sz := px * (1.0 if i % 2 else 1.5)
		draw_rect(Rect2((at - Vector2(sz, sz) / 2.0).snapped(Vector2(px, px)), Vector2(sz, sz)), Color(cols[i % cols.size()], 1.0 - k * k))
