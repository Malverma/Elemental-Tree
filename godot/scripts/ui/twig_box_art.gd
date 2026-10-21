extends Control
## The Barracks' root box in pixel art, drawn in code around its sprites
## (twig_box_<tier> and its lid). Sap shows as liquid in the box's round window
## and elemental energy as motes circling it. `pour_sap()` and `pour_power()`
## play the injection effects; `open()` shakes the box, pops the lid and lifts
## the new troop out in a burst of its rarity's colour. It emits `revealed`
## once the troop is out (the Barracks swaps in its card there) and `opened`
## when a fresh box is back. Tapping the box emits `tapped`.

signal tapped
signal revealed
signal opened

const ART := Vector2(64, 72)  # art pixels
const BOX := Vector2(9, 30)  # top-left of the lid; the body sits 2 in and 11 down
const WINDOW := Vector2(32, 56)  # centre of the sap window
const SAP := [Color("#8a4a12"), Color("#e08a22"), Color("#ffb347"), Color("#fff0b0")]
const OPEN_SHAKE := 0.9  # seconds of shaking before the lid pops
const REVEAL_AT := 1.45  # the troop has risen out and hands over to its card
const OPEN_TIME := 2.4  # until a fresh box sits there
const TAP_SLOP := 16.0  # px a press can move and still count as a tap

## Screen px per art pixel.
var unit := 3.0:
	set(v):
		unit = v
		custom_minimum_size = ART * unit
		queue_redraw()
var tier := 1
## Sap in the box, 0..1 of its brim, and the injected element and its 0..1 share.
var fill := 0.0
var element := ""
var energy := 0.0
## Hops now and then to show it can be opened.
var can_open := false

var _time := 0.0
var _shown_fill := 0.0  # eases toward `fill`
var _hop := 0.0  # seconds left of the little jump an injection gives
var _flash := 0.0
var _flash_col := Color.WHITE
var _parts := []
var _open_t := -1.0  # seconds into the opening, or < 0
var _troop_img := ""
var _rarity_col := Color.WHITE
var _press_at := Vector2.INF


func _init() -> void:
	custom_minimum_size = ART * unit
	# Passes drags on so the Barracks still scrolls by touch over the box.
	mouse_filter = MOUSE_FILTER_PASS
	texture_filter = TEXTURE_FILTER_NEAREST


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
		elif _press_at != Vector2.INF and event.position.distance_to(_press_at) < TAP_SLOP:
			_press_at = Vector2.INF
			tapped.emit()
	elif event is InputEventMouseMotion and _press_at != Vector2.INF and event.position.distance_to(_press_at) >= TAP_SLOP:
		_press_at = Vector2.INF


## Where the risen troop's middle is, in this control's coordinates.
func troop_center() -> Vector2:
	return Vector2(32, 20) * unit


func is_opening() -> bool:
	return _open_t >= 0.0


## Sap drips into the lid and the box gives a hop.
func pour_sap() -> void:
	for i in 4:
		_parts.append({"kind": "drop", "p": Vector2(randf_range(26, 38), -4.0 - i * 5.0), "v": Vector2(0, 40), "life": 2.0,
			"col": SAP[2]})


## Motes of the element's colour spiral in to the window.
func pour_power(el: String) -> void:
	var col: Color = GameData.BIOME_COLORS[el]
	var a0 := randf() * TAU
	for i in 7:
		_parts.append({"kind": "spark", "a": a0 + i * TAU / 7.0, "r": 30.0 + randf() * 6.0, "life": 0.7 + i * 0.05,
			"col": col.lightened(0.3 * (i % 2))})


## Opens the box on `troop`, revealed in its rarity's colour.
func open(troop: Dictionary) -> void:
	var def := GameData.troop_def(troop)
	_troop_img = def["img"]
	_rarity_col = GameData.RARITY[def["rarity"]]["color"]
	_open_t = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_shown_fill = move_toward(_shown_fill, fill, delta * 0.8)
	_hop = maxf(0.0, _hop - delta)
	if can_open and _open_t < 0.0 and _hop <= 0.0 and fmod(_time, 1.8) < delta:
		_hop = 0.25
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _open_t >= 0.0:
		var before := _open_t
		_open_t += delta
		if before < OPEN_SHAKE and _open_t >= OPEN_SHAKE:
			_burst()
		if before < REVEAL_AT and _open_t >= REVEAL_AT:
			revealed.emit()
		if _open_t >= OPEN_TIME:
			_open_t = -1.0
			_hop = 0.25
			opened.emit()
	_step_parts(delta)
	queue_redraw()


func _step_parts(delta: float) -> void:
	for p in _parts.duplicate():
		p["life"] -= delta
		match p["kind"]:
			"drop":
				p["v"].y += 260.0 * delta
				p["p"] += p["v"] * delta
				if p["p"].y >= BOX.y + 1:
					p["life"] = 0.0
					_hop = 0.18
					_flash = maxf(_flash, 0.5)
					_flash_col = SAP[2]
					for i in 3:
						_parts.append({"kind": "bit", "p": p["p"], "v": Vector2(randf_range(-30, 30), randf_range(-50, -20)),
							"life": 0.35, "col": SAP[3] if i == 0 else SAP[2]})
			"spark":
				p["a"] += delta * 6.0
				p["r"] = maxf(0.0, p["r"] - delta * 46.0)
				if p["r"] <= 1.0:
					p["life"] = 0.0
					_flash = 1.0
					_flash_col = p["col"]
			"bit":
				p["v"].y += 140.0 * delta
				p["p"] += p["v"] * delta
		if p["life"] <= 0.0:
			_parts.erase(p)


# The lid pops: light bursts out and bits of the rarity's colour scatter.
func _burst() -> void:
	_flash = 1.0
	_flash_col = _rarity_col
	for i in 22:
		var a := randf_range(PI * 1.05, PI * 1.95)
		var s := randf_range(40, 95)
		_parts.append({"kind": "bit", "p": Vector2(32, BOX.y + 10), "v": Vector2(cos(a), sin(a)) * s, "life": randf_range(0.7, 1.3),
			"col": _rarity_col if i % 3 else Color("#fff6b0")})


func _px(x: float, y: float, c: Color, w := 1.0, h := 1.0) -> void:
	draw_rect(Rect2(Vector2(floorf(x), floorf(y)) * unit, Vector2(w, h) * unit), c)


func _tex(name: String, at: Vector2, alpha := 1.0) -> void:
	var t := UI.tex(name)
	draw_texture_rect(t, Rect2(at.floor() * unit, t.get_size() * unit), false, Color(1, 1, 1, alpha))


func _draw() -> void:
	var o := _open_t
	var offset := Vector2.ZERO
	if _hop > 0.0:
		offset.y = -roundf(sin(_hop / 0.25 * PI) * 2.0)
	if o >= 0.0 and o < OPEN_SHAKE:
		# Shaking harder and harder before the lid gives.
		var k := o / OPEN_SHAKE
		offset.x = roundf(sin(o * 70.0) * (0.6 + k * 1.6))
	var glow_col: Color = GameData.BIOME_COLORS[element] if element != "" and energy > 0.0 else SAP[2]
	# Glow on the floor under the box, from the sap (and energy) inside.
	var glow := 0.05 + 0.1 * _shown_fill + 0.08 * energy + 0.05 * sin(_time * 2.5)
	if o >= 0.0:
		glow += 0.2 * clampf(o / OPEN_SHAKE, 0.0, 1.0)
	for r in [26.0, 19.0, 12.0]:
		draw_circle(Vector2(32, 66) * unit, r * unit, Color(glow_col, glow * 0.4))
	# Energy motes circling the box while it holds an element.
	if element != "" and energy > 0.0:
		var col: Color = GameData.BIOME_COLORS[element]
		for i in int(2 + energy * 6):
			var a := _time * 1.1 + i * TAU / int(2 + energy * 6)
			var p := Vector2(32 + cos(a) * 27.0, 50 + sin(a) * 9.0 + sin(_time * 3.0 + i) * 2.0)
			var behind := sin(a) < 0.0
			if behind:
				_px(p.x, p.y, Color(col, 0.6))
	var body_at := BOX + Vector2(2, 11) + offset
	var lid_at := BOX + offset
	var lid_alpha := 1.0
	if o >= OPEN_SHAKE:
		# The lid flies up and off to the side, fading.
		var t := o - OPEN_SHAKE
		lid_at += Vector2(roundf(t * 34.0), roundf(-t * 70.0 + t * t * 60.0))
		lid_alpha = clampf(1.0 - t * 1.6, 0.0, 1.0)
		# Fading back in once the troop has gone: a fresh box.
		if o > OPEN_TIME - 0.5:
			lid_at = BOX + offset
			lid_alpha = (o - (OPEN_TIME - 0.5)) / 0.5
	# Rays from the open box.
	if o >= OPEN_SHAKE * 0.5:
		var k := clampf((o - OPEN_SHAKE * 0.5) / (OPEN_SHAKE * 0.5), 0.0, 1.0)
		var fade := 1.0 - clampf((o - OPEN_TIME + 1.0), 0.0, 1.0)
		var c := Vector2(32, BOX.y + 11) * unit
		for i in 7:
			var a := PI + PI * (i + 0.5) / 7.0 + sin(_time * 1.5) * 0.06
			var len := (22.0 + 8.0 * sin(_time * 4.0 + i)) * unit * (1.0 if o >= OPEN_SHAKE else 0.4)
			var w := 0.09
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * len, c + Vector2(cos(a + w), sin(a + w)) * len]),
				Color(_rarity_col, 0.28 * k * fade))
	_tex("twig_box_%d" % tier, body_at)
	_draw_window(body_at)
	if o < 0.0 or o < OPEN_SHAKE:
		# Light leaking from under the lid as it strains.
		if o >= 0.0:
			var k := o / OPEN_SHAKE
			for x in range(4, 42, 3):
				if fmod(x * 7.0 + _time * 20.0, 5.0) < 4.0 * k:
					_px(body_at.x + x, body_at.y - 1, Color(_rarity_col.lightened(0.4), k))
	_tex("twig_box_lid_%d" % tier, lid_at, lid_alpha)
	# The new troop rises out of the box, until its card takes over.
	if o >= OPEN_SHAKE and o < REVEAL_AT:
		var t := o - OPEN_SHAKE
		var y := lerpf(BOX.y + 6, 4.0, minf(1.0, t / 0.45))
		for r in [14.0, 10.0]:
			draw_circle(Vector2(32, y + 18) * unit, r * unit, Color(_rarity_col, 0.18))
		var tex := UI.tex(_troop_img)
		var sz := tex.get_size() * unit
		draw_texture_rect(tex, Rect2(Vector2(32 * unit - sz.x * 0.5, roundf(y) * unit), sz), false)
	for p in _parts:
		match p["kind"]:
			"drop":
				_px(p["p"].x, p["p"].y, SAP[2], 1, 2)
				_px(p["p"].x, p["p"].y, SAP[3])
				_px(p["p"].x, p["p"].y + 2, SAP[1])
			"spark":
				var at := WINDOW + Vector2(cos(p["a"]) * p["r"], sin(p["a"]) * p["r"] * 0.6)
				_px(at.x - 1, at.y - 1, Color(p["col"], 0.25), 3, 3)
				_px(at.x, at.y, p["col"])
			"bit":
				_px(p["p"].x, p["p"].y, Color(p["col"], clampf(p["life"] * 3.0, 0.0, 1.0)))
	# Motes passing in front of the box.
	if element != "" and energy > 0.0:
		var col: Color = GameData.BIOME_COLORS[element]
		var n := int(2 + energy * 6)
		for i in n:
			var a := _time * 1.1 + i * TAU / n
			if sin(a) >= 0.0:
				var p := Vector2(32 + cos(a) * 27.0, 50 + sin(a) * 9.0 + sin(_time * 3.0 + i) * 2.0)
				_px(p.x - 1, p.y - 1, Color(col, 0.25), 3, 3)
				_px(p.x, p.y, col.lightened(0.4))


# The sap level in the round window, with a wobbling surface; energy tints it.
func _draw_window(body_at: Vector2) -> void:
	var c := body_at + Vector2(21, 15)
	var level := c.y + 5.0 - _shown_fill * 10.0
	var tint: Color = GameData.BIOME_COLORS[element] if element != "" else SAP[2]
	for y in range(-5, 5):
		for x in range(-5, 5):
			if Vector2(x + 0.5, y + 0.5).length() > 5.0:
				continue
			var surface := level + sin(_time * 3.0 + x * 0.8) * 0.6
			var py := c.y + y
			if py + 0.5 < surface or _shown_fill <= 0.0:
				continue
			var col: Color = SAP[1]
			if py < surface + 1.2:
				col = SAP[3]
			elif x > 1 and y < 2:
				col = SAP[2]
			elif y > 2:
				col = SAP[0]
			if element != "":
				col = col.lerp(tint, 0.55 * energy)
			_px(c.x + x, py, col)
	if _flash > 0.0:
		for y in range(-5, 5):
			for x in range(-5, 5):
				if Vector2(x + 0.5, y + 0.5).length() <= 5.0:
					_px(c.x + x, c.y + y, Color(_flash_col.lightened(0.5), _flash * 0.6))
	# The glint stays on top of the glass.
	_px(c.x + 2, c.y - 3, Color(1, 1, 1, 0.55))
