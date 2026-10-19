class_name PixelScene
extends Control
## A full-screen pixel-art scene. Art is laid out in a fixed design space
## (`design`, in art pixels) inside `world`, scaled up with nearest filtering.
## By default the scene is anchored to the bottom of the screen; on short
## screens the top of the sky is cropped, and at least MIN_ROWS rows always fit.
## With `contain`, the whole design fits between the shell's bars instead,
## growing up to `fill_crop` past that (cropping the sides or ends) to close
## the bands a near-fit leaves.

const DESIGN := Vector2(180, 400)
const MIN_ROWS := 320.0
const WIND := preload("res://shaders/wind.gdshader")

## Colours that fill any space beside the art on screens wider than it.
var design := DESIGN
var contain := false
var fill_crop := 0.0
var inset_top := 0.0
var inset_bottom := 0.0
var edge_sky := Color("#7fc3f0")
var edge_ground := Color("#4c9a40")
var ground_row := 300.0

## How far (screen px) a press may travel and still count as a tap rather than a swipe.
const TAP_SLOP := 24.0

var world: Node2D
var pixel_scale := 4.0
var origin := Vector2.ZERO
## The span of design x currently on screen (wider than DESIGN on wide screens).
var view_left := 0.0
var view_right := DESIGN.x
var _press := Vector2.INF


func _init() -> void:
	if world:
		return  # already set up by a subclass's super() call
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	world = Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	resized.connect(_layout)


func _layout() -> void:
	if contain:
		var avail := Rect2(0, inset_top, size.x, maxf(1.0, size.y - inset_top - inset_bottom))
		var fit := minf(avail.size.x / design.x, avail.size.y / design.y)
		var cover := maxf(avail.size.x / design.x, avail.size.y / design.y)
		pixel_scale = minf(cover, fit * (1.0 + fill_crop))
		origin = avail.position + (avail.size - design * pixel_scale) / 2.0
	else:
		pixel_scale = minf(maxf(size.x / design.x, size.y / design.y), size.y / MIN_ROWS)
		origin = Vector2((size.x - design.x * pixel_scale) / 2.0, size.y - design.y * pixel_scale)
	world.position = origin
	world.scale = Vector2.ONE * pixel_scale
	view_left = -origin.x / pixel_scale
	view_right = view_left + size.x / pixel_scale
	queue_redraw()


# Taps fire on release, so a swipe that starts on the scene doesn't also tap it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
		elif _press != Vector2.INF:
			if event.position.distance_to(_press) < TAP_SLOP:
				_tap(event.position)
			_press = Vector2.INF


## Called with the local position of a tap. Scenes override this.
func _tap(_local: Vector2) -> void:
	pass


func _draw() -> void:
	var ground_y := origin.y + ground_row * pixel_scale
	draw_rect(Rect2(0, 0, size.x, ground_y), edge_sky)
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), edge_ground)


## Space the shell's bars cover; contained scenes fit between them.
func set_insets(top: float, bottom: float) -> void:
	inset_top = top
	inset_bottom = bottom
	_layout()


## Converts a local (screen) position to design pixels.
func to_design(local: Vector2) -> Vector2:
	return (local - origin) / pixel_scale


## Converts design pixels to a global screen position.
func design_to_global(p: Vector2) -> Vector2:
	return get_global_transform() * (origin + p * pixel_scale)


## Adds the full-size background art, mirrored out to the sides so wide
## screens see a seamless continuation instead of bars.
func backdrop(tex_name: String) -> void:
	for k in [-2, -1, 0, 1, 2]:
		var s := sprite(tex_name, Vector2(k * design.x, 0))
		s.flip_h = k % 2 != 0


## Adds a sprite with its top-left corner at `pos` (design pixels).
func sprite(tex_name: String, pos: Vector2, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = UI.tex(tex_name)
	s.centered = false
	s.position = pos
	(parent if parent else world).add_child(s)
	return s


## A wind-sway material for a sprite.
static func wind(strength: float, speed := 1.3, phase := 0.0, base_y := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WIND
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("base_y", base_y)
	return m


## True when the image has an opaque pixel within `slack` pixels of `p`.
static func hits(img: Image, p: Vector2, slack := 0) -> bool:
	var c := Vector2i(floori(p.x), floori(p.y))
	for dy in range(-slack, slack + 1):
		for dx in range(-slack, slack + 1):
			var q := c + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixel(q.x, q.y).a > 0.5:
				return true
	return false
