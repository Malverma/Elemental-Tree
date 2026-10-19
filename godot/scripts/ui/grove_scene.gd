class_name GroveScene
extends PixelScene
## The Grove in pixel art: the tree on its hill under a drifting sky. The crown
## sways in the wind, gusts pass now and then, leaves drift down and birds
## visit (see GroveBirds).
## Tapping the leaves or the trunk emits `tapped` ("branches" or "trunk");
## tapping a bird emits `bird_tapped`.

signal tapped(global_pos: Vector2, part: String)
## A visiting bird was tapped (and burst into feathers).
signal bird_tapped(global_pos: Vector2)

## Top-left of the 176x200 tree art; its base (88, 194) stands on the hilltop at (90, 304).
const TREE_POS := Vector2(2, 110)
const TREE_BASE_V := 194.0 / 200.0
const CROWN_SWAY := 1.2
const LEAF_FALL := 30.0  # design px / s
## Cloud positions survive rebuilds so the sky doesn't jump.
static var _cloud_x := [20.0, 120.0, -40.0]

var stage: int
var _trunk_img: Image
var _crown_img: Image
var _crown_box: Rect2
var _crown_mat: ShaderMaterial
var _grass_mat: ShaderMaterial
var _clouds: Array[Sprite2D] = []
var _leaves := []
var _leaf_in := 8.0
var _gust_in := 15.0
var _gust := 0.0
var _birds: GroveBirds


## Which art stage a tree level shows: one per level, from a sprout at level 1
## to the full Elemental Tree at level 10.
static func stage_for(level: int) -> int:
	return clampi(level, 1, GameData.MAX_LEVEL) - 1


func _init(p_stage: int) -> void:
	super()
	stage = p_stage
	edge_sky = Color("#5aa9e6")
	edge_ground = Color("#3f8738")
	ground_row = 300.0


func _ready() -> void:
	backdrop("grove_bg")
	var cloud_specs := [["cloud_a", 112.0], ["cloud_b", 150.0], ["cloud_b", 92.0]]
	for i in cloud_specs.size():
		var c := sprite(cloud_specs[i][0], Vector2(_cloud_x[i], cloud_specs[i][1]))
		c.modulate.a = 0.92
		_clouds.append(c)
	var trunk := sprite("tree_trunk_%d" % stage, TREE_POS)
	var crown := sprite("tree_crown_%d" % stage, TREE_POS)
	_crown_mat = wind(CROWN_SWAY, 1.1, 0.0, TREE_BASE_V)
	crown.material = _crown_mat
	_trunk_img = trunk.texture.get_image()
	_crown_img = crown.texture.get_image()
	_crown_box = Rect2(_crown_img.get_used_rect())
	_crown_box.position += TREE_POS
	# Birds perch on the crown and hop about behind the front grass.
	_birds = GroveBirds.new(self)
	world.add_child(_birds)
	var grass := sprite("grass_front", Vector2(0, 380))
	_grass_mat = wind(1.0, 1.8, 1.0)
	grass.material = _grass_mat


func _process(delta: float) -> void:
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x += delta * (1.6 + i * 0.7)
		if c.position.x > view_right + 4:
			c.position.x = view_left - c.texture.get_width() - 4.0
		_cloud_x[i] = c.position.x

	# Gusts: the wind picks up for a few seconds and shakes a few leaves loose.
	_gust_in -= delta
	if _gust_in <= 0.0:
		_gust_in = randf_range(15.0, 25.0)
		var tw := create_tween()
		tw.tween_property(self, "_gust", 2.2, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_gust", 0.0, 2.4).set_trans(Tween.TRANS_SINE)
		for i in randi_range(0, 1):
			get_tree().create_timer(randf_range(0.2, 1.6)).timeout.connect(_drop_leaf)
	_crown_mat.set_shader_parameter("strength", CROWN_SWAY + _gust)
	_grass_mat.set_shader_parameter("strength", 1.0 + _gust * 0.6)

	_leaf_in -= delta
	if _leaf_in <= 0.0:
		_leaf_in = randf_range(14.0, 26.0)
		_drop_leaf()
	for leaf in _leaves.duplicate():
		_fall(leaf, delta)


## Lets a leaf go from somewhere in the crown (or from `at`, in design px).
func _drop_leaf(at := Vector2.INF) -> void:
	if not is_inside_tree():
		return
	if at == Vector2.INF:
		for i in 12:
			var p := _crown_box.position + Vector2(randf(), randf_range(0.3, 1.0)) * _crown_box.size
			if hits(_crown_img, p - TREE_POS):
				at = p
				break
		if at == Vector2.INF:
			return
	var s := sprite("leaf_fall", at.floor())
	s.hframes = 4
	s.frame = randi() % 4
	s.offset = Vector2(-4, -4)
	_leaves.append({"node": s, "x": at.x, "y": at.y, "t": randf() * TAU, "ground": randf_range(306.0, 360.0), "drift": randf_range(1.5, 3.0), "dir": [-1.0, 1.0].pick_random()})


func _fall(leaf: Dictionary, delta: float) -> void:
	var s: Sprite2D = leaf["node"]
	leaf["t"] += delta
	var t: float = leaf["t"]
	leaf["x"] += delta * leaf["dir"] * (1.0 + _gust * 2.0)
	leaf["y"] += delta * LEAF_FALL
	# Whole-pixel steps keep the leaf on the art's grid.
	s.position = Vector2(leaf["x"] + sin(t * 3.0) * leaf["drift"], leaf["y"]).round()
	s.frame = int(t * 6.0) % 4
	if s.position.y >= leaf["ground"]:
		_leaves.erase(leaf)
		s.frame = 2  # lies flat on the grass
		var tw := s.create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(s, "modulate:a", 0.0, 0.8)
		tw.tween_callback(s.queue_free)


func _tap(local: Vector2) -> void:
	# Birds sit in front of the tree, so they catch the tap first.
	if _birds.pop_at(to_design(local)):
		bird_tapped.emit(get_global_transform() * local)
		return
	var p := to_design(local) - TREE_POS
	var part := ""
	if hits(_crown_img, p, 2):
		part = "branches"
	elif hits(_trunk_img, p, 3):
		part = "trunk"
	if part == "":
		return
	if part == "branches":
		# A rustle that startles any birds, and sometimes a leaf shaken loose.
		_birds.scare_tree()
		_gust = maxf(_gust, 1.2)
		create_tween().tween_property(self, "_gust", 0.0, 0.6)
		if randf() < 0.06:
			_drop_leaf(p + TREE_POS)
	tapped.emit(get_global_transform() * local, part)
