class_name GroveBirds
extends Node2D
## Birds that visit the Grove now and then: small flocks fly across the sky,
## a bird lands on the crown to look around and peck, or one hops about the
## meadow. A tapped bird bursts into feathers (see pop_at). Lives in the Grove
## scene's art space (design pixels).

## Bird sheet (assets/pixel/birds.png): one row per kind, six 12x10 frames:
## 0-2 wing flap, 3 perched, 4 pecking, 5 hop.
const KINDS := 5
const FRAMES := 6
const FLAP := [0, 1, 2, 1]
const FLY_SPEED := 46.0  # design px / s
const MAX_ON_TREE := 2
## Pop sheet (assets/pixel/bird_pop.png): one row per kind, eight 16x16 frames:
## 0-3 the burst, 4-7 a feather tumbling (4 lies flat).
const POP_COLS := 8
const POP_FRAMES := 4
const TAP_RADIUS := 10.0  # design px; generous, birds are small and quick
const FEATHER_FALL := 20.0  # design px / s

var scene: GroveScene
var _birds := []
var _feathers := []
var _flyby_in := randf_range(8.0, 18.0)
var _tree_in := randf_range(14.0, 28.0)
var _ground_in := randf_range(25.0, 45.0)


func _init(p_scene: GroveScene) -> void:
	scene = p_scene


func _process(delta: float) -> void:
	_flyby_in -= delta
	if _flyby_in <= 0.0:
		_flyby_in = randf_range(25.0, 50.0)
		_flyby()
	_tree_in -= delta
	if _tree_in <= 0.0:
		_tree_in = randf_range(35.0, 70.0)
		if _count("tree") < MAX_ON_TREE:
			_visit("tree", _perch_spot())
	_ground_in -= delta
	if _ground_in <= 0.0:
		_ground_in = randf_range(45.0, 90.0)
		if _count("ground") == 0:
			_visit("ground", _ground_spot())
	for b in _birds.duplicate():
		_step(b, delta)
	for f in _feathers.duplicate():
		_fall(f, delta)


## Pops the bird at design point `p`, if any: it bursts into a puff and 1-3
## feathers that drift down to the grass. Returns whether a bird was hit.
func pop_at(p: Vector2) -> bool:
	var best: Dictionary = {}
	for b in _birds:
		# The origin sits at the feet; aim at the body.
		var d: float = (b["node"].position + Vector2(0, -4)).distance_to(p)
		if d <= TAP_RADIUS and (best.is_empty() or d < best["d"]):
			best = {"b": b, "d": d}
	if best.is_empty():
		return false
	burst(best["b"])
	return true


## Bursts bird `b` into a puff and feathers.
func burst(b: Dictionary) -> void:
	var at := body(b)
	_birds.erase(b)
	b["node"].queue_free()
	var puff := _pop_sprite(b["kind"], 0, at)
	var tw := puff.create_tween()
	for f in range(1, POP_FRAMES):
		tw.tween_interval(0.07)
		tw.tween_callback(func(): puff.frame = b["kind"] * POP_COLS + f)
	tw.tween_interval(0.07)
	tw.tween_callback(puff.queue_free)
	# Feathers land where the bird stood, or on the meadow below the tree and sky.
	var floor_y: float = b["to"].y if b["where"] == "ground" and b["state"] == "sit" else randf_range(306.0, 350.0)
	for i in randi_range(1, 3):
		var s := _pop_sprite(b["kind"], POP_FRAMES + randi() % 4, at)
		_feathers.append({"node": s, "kind": b["kind"], "x": at.x, "y": at.y, "t": randf() * TAU,
			"vx": randf_range(-28.0, 28.0), "vy": randf_range(-26.0, -8.0),
			"ground": floor_y + randf_range(-2.0, 4.0), "drift": randf_range(1.5, 3.0)})


## Where bird `b`'s body is (its origin sits at its feet).
static func body(b: Dictionary) -> Vector2:
	return b["node"].position + Vector2(0, -4)


func is_alive(b: Dictionary) -> bool:
	return b in _birds


## Birds in view, for the snare branch to aim at.
func visible_birds() -> Array:
	return _birds.filter(func(b): return body(b).x > scene.view_left + 4.0 and body(b).x < scene.view_right - 4.0 and body(b).y > 4.0)


## Calls a bird in to land on the crown, unless one is already there or on its way.
func call_bird() -> void:
	if _count("tree") == 0:
		_visit("tree", _perch_spot())


func _pop_sprite(kind: int, f: int, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.tex("bird_pop")
	s.hframes = POP_COLS
	s.vframes = KINDS
	s.frame = kind * POP_COLS + f
	s.position = at.round()
	add_child(s)
	return s


# A feather flung out by the burst, then rocking gently down to the grass.
func _fall(f: Dictionary, delta: float) -> void:
	var s: Sprite2D = f["node"]
	f["t"] += delta
	f["vx"] = move_toward(f["vx"], 0.0, 40.0 * delta)
	f["vy"] = move_toward(f["vy"], FEATHER_FALL, 50.0 * delta)
	f["x"] += f["vx"] * delta
	f["y"] += f["vy"] * delta
	var t: float = f["t"]
	s.position = Vector2(f["x"] + sin(t * 2.5) * f["drift"], f["y"]).round()
	s.frame = f["kind"] * POP_COLS + POP_FRAMES + int(t * 5.0) % 4
	if f["y"] >= f["ground"]:
		_feathers.erase(f)
		s.frame = f["kind"] * POP_COLS + POP_FRAMES  # lies flat on the grass
		var tw := s.create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(s, "modulate:a", 0.0, 0.6)
		tw.tween_callback(s.queue_free)


## Sends any birds sitting in the tree flying off (a tap on the leaves startles them).
func scare_tree() -> void:
	for b in _birds:
		if b["where"] == "tree" and b["state"] in ["arrive", "sit"]:
			_leave(b, 1.5)


func _count(where: String) -> int:
	var n := 0
	for b in _birds:
		if b["where"] == where and b["state"] != "leave":
			n += 1
	return n


func _new_bird(kind: int, at: Vector2) -> Dictionary:
	var s := Sprite2D.new()
	s.texture = UI.tex("birds")
	s.hframes = FRAMES
	s.vframes = KINDS
	s.centered = false
	s.offset = Vector2(-6, -9)  # the origin sits at the bird's feet
	s.position = at.round()
	add_child(s)
	var b := {"node": s, "kind": kind, "where": "sky", "state": "fly", "t": 0.0, "dur": 1.0,
		"from": at, "ctrl": at, "to": at, "anim": randf(), "idle_in": 0.0, "stay": 0.0, "pose": 3, "pose_t": 0.0}
	_birds.append(b)
	return b


# Sets a bird off along a gentle arc from where it is to `to`.
func _fly_to(b: Dictionary, to: Vector2, speed := FLY_SPEED, lift := 18.0) -> void:
	var from: Vector2 = b["node"].position
	b["from"] = from
	b["to"] = to
	b["ctrl"] = (from + to) / 2.0 + Vector2(0, -lift)
	b["t"] = 0.0
	b["dur"] = maxf(0.4, from.distance_to(to) / speed)
	b["node"].flip_h = to.x < from.x


func _offscreen(side: float, y: float) -> Vector2:
	return Vector2(scene.view_left - 12.0 if side < 0.0 else scene.view_right + 12.0, y)


# A flock of one to three birds of a kind crossing the sky.
func _flyby() -> void:
	var kind := randi() % KINDS
	var side: float = [-1.0, 1.0].pick_random()
	var y := randf_range(105.0, 200.0)
	for i in randi_range(1, 3):
		var start := _offscreen(side, y + randf_range(-8.0, 8.0)) + Vector2(side * i * randf_range(10.0, 16.0), 0)
		var b := _new_bird(kind, start)
		b["state"] = "leave"
		_fly_to(b, _offscreen(-side, y + randf_range(-25.0, 25.0)) + Vector2(-side * 30.0, 0), randf_range(38.0, 52.0), randf_range(-10.0, 14.0))


# One bird flies in to land on `spot` in the tree or on the meadow.
func _visit(where: String, spot: Vector2) -> void:
	if spot == Vector2.INF:
		return
	var side: float = [-1.0, 1.0].pick_random()
	var b := _new_bird(randi() % KINDS, _offscreen(side, randf_range(90.0, 160.0)))
	b["where"] = where
	b["state"] = "arrive"
	b["stay"] = randf_range(5.0, 10.0) if where == "tree" else randf_range(6.0, 12.0)
	_fly_to(b, spot)


func _leave(b: Dictionary, hurry := 1.0) -> void:
	b["state"] = "leave"
	var side: float = [-1.0, 1.0].pick_random()
	_fly_to(b, _offscreen(side, randf_range(60.0, 130.0)), FLY_SPEED * hurry, 24.0)


# A spot on the top edge of the crown, where a bird can stand.
func _perch_spot() -> Vector2:
	var img: Image = scene._crown_img
	var used := img.get_used_rect()
	for attempt in 10:
		var x := randi_range(used.position.x + 3, used.end.x - 4)
		for y in range(used.position.y, used.end.y):
			if img.get_pixel(x, y).a > 0.5:
				var spot := GroveScene.TREE_POS + Vector2(x, y)
				var taken := false
				for b in _birds:
					if b["where"] == "tree" and b["to"].distance_to(spot) < 12.0:
						taken = true
				if not taken:
					return spot
				break
	return Vector2.INF


# A spot on the meadow in front of the hill, clear of the trunk.
func _ground_spot() -> Vector2:
	for attempt in 10:
		var x := randf_range(maxf(scene.view_left, 0.0) + 10.0, minf(scene.view_right, GroveScene.DESIGN.x) - 10.0)
		if absf(x - 90.0) < 24.0:
			continue
		var dx := (x - 90.0) / 90.0
		return Vector2(x, minf(300.0 + 22.0 * dx * dx + randf_range(5.0, 45.0), 372.0)).round()
	return Vector2.INF


func _step(b: Dictionary, delta: float) -> void:
	var s: Sprite2D = b["node"]
	b["anim"] += delta
	match b["state"]:
		"arrive", "leave":
			b["t"] = minf(b["t"] + delta / b["dur"], 1.0)
			var t: float = b["t"]
			var p: Vector2 = b["from"].lerp(b["ctrl"], t).lerp(b["ctrl"].lerp(b["to"], t), t)
			s.position = p.round()
			# Flap all the way, gliding with wings level for the last bit of a landing.
			var f: int = FLAP[int(b["anim"] * 10.0) % FLAP.size()]
			if b["state"] == "arrive" and t > 0.85:
				f = 1
			s.frame = b["kind"] * FRAMES + f
			if t >= 1.0:
				if b["state"] == "leave":
					_birds.erase(b)
					s.queue_free()
				else:
					b["state"] = "sit"
					b["idle_in"] = randf_range(0.4, 1.0)
					_pose(b, 3)
		"sit":
			b["stay"] -= delta
			if b["stay"] <= 0.0:
				_leave(b)
				return
			# Settle back to standing after a peck or a hop.
			if b["pose"] != 3:
				b["pose_t"] -= delta
				if b["pose_t"] <= 0.0:
					_pose(b, 3)
					s.position = b["to"].round()
			b["idle_in"] -= delta
			if b["idle_in"] <= 0.0:
				b["idle_in"] = randf_range(0.5, 1.4)
				var r := randf()
				if r < 0.45:
					_pose(b, 4, 0.35)
				elif r < 0.7:
					_pose(b, 5, 0.18)
					if b["where"] == "ground":
						# hop along the grass a little
						b["to"] += Vector2(randf_range(-3.0, 3.0), 0).round()
					s.position = (b["to"] + Vector2(0, -1)).round()
				elif r < 0.9:
					s.flip_h = not s.flip_h


func _pose(b: Dictionary, f: int, hold := 0.0) -> void:
	b["pose"] = f
	b["pose_t"] = hold
	b["node"].frame = b["kind"] * FRAMES + f
