class_name UI
## Palette, theme and small widget helpers shared by every screen.

const BG := Color("#F3EEDF")
const PANEL := Color("#FFFBF0")
const INK := Color("#2B1D12")
const MUTED := Color("#7A6A55")
const LINE := Color("#E2D7BE")
const ACCENT := Color("#4E9A3E")
const DANGER := Color("#B83A2E")
const SUN := Color("#E8A317")
const SAP := Color("#E09A2D")
const BARK := Color("#8B5A2B")
const BARK_DARK := Color("#5A3A1E")
const LEAF := Color("#5DBB4C")
const LEAF_DARK := Color("#2C6B24")
const LEAF_LIGHT := Color("#A6E08E")
const SOIL := Color("#A87C55")
const GRASS := Color("#7CC46A")
const ROOT_GLOW := Color("#FFD447")
const MAP_BG := Color("#EDE3C8")
const NIGHT := Color("#14231A")  # dark backing for text and pills over the pixel scenes
const SHEET_INK := Color("#F3EEDF")  # text on the dark pull-up sheet
const SHEET_MUTED := Color("#B5BFA8")
const SHEET_HINT := Color("#FFB3A8")

const RES_ICON := {"sunlight": "icon_sunlight", "sap": "icon_sap"}

static var _textures := {}
static var _bold: Font


## Art by name, from assets/pixel/*.png.
static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/pixel/%s.png" % name)
	return _textures[name]


static func is_pixel(name: String) -> bool:
	return ResourceLoader.exists("res://assets/pixel/%s.png" % name)


## Like tex(), but pixel art comes wrapped to draw with nearest filtering, for
## custom drawing and button icons whose node filters smoothly.
static func crisp(name: String) -> Texture2D:
	var key := "crisp:" + name
	if not _textures.has(key):
		var t := tex(name)
		if is_pixel(name):
			var ct := CanvasTexture.new()
			ct.diffuse_texture = t
			ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t = ct
		_textures[key] = t
	return _textures[key]


static func bold_font() -> Font:
	if _bold == null:
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.7
		_bold = f
	return _bold


static func _box(bg: Color, border: Color, border_w: int, radius: int, pad_x: int, pad_y: int, bottom_extra := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.border_width_bottom = border_w + bottom_extra
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = true
	return s


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", INK)

	_button_styles(t, "Button", Color.WHITE, Color("#FFF6D8"), INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_constant("h_separation", "Button", 8)

	for v in ["PrimaryButton", "DangerButton", "SelectedButton", "NavButton", "NavButtonActive"]:
		t.set_type_variation(v, "Button")
	_button_styles(t, "PrimaryButton", ACCENT, Color("#5DAF4B"), INK)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "PrimaryButton", Color.WHITE)
	_button_styles(t, "DangerButton", Color.WHITE, Color("#FBE9E6"), DANGER)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "DangerButton", DANGER)
	_button_styles(t, "SelectedButton", ROOT_GLOW, ROOT_GLOW, INK)

	# Bottom navigation tabs.
	for v in ["NavButton", "NavButtonActive"]:
		var active: bool = v == "NavButtonActive"
		var s := _box(PANEL if active else LINE, LINE, 0, 0, 12, 18)
		for state in ["normal", "hover", "pressed", "focus"]:
			t.set_stylebox(state, v, s)
		t.set_color("font_color", v, INK if active else MUTED)
		t.set_color("font_hover_color", v, INK)
		t.set_color("font_pressed_color", v, INK)
		t.set_font_size("font_size", v, 24)
	t.set_font("font", "NavButtonActive", bold_font())

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 3, 18, 20, 18))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(Color.WHITE, LINE, 3, 14, 12, 12))
	var bar := _box(Color(NIGHT, 0.72), Color.TRANSPARENT, 0, 0, 16, 12)
	bar.corner_radius_bottom_left = 22
	bar.corner_radius_bottom_right = 22
	t.set_type_variation("TopBar", "PanelContainer")
	t.set_stylebox("panel", "TopBar", bar)
	# Floating pills over the pixel scenes, and the pull-up sheet.
	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", _box(Color(NIGHT, 0.72), Color(1, 1, 1, 0.18), 2, 26, 18, 8))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _box(Color(1, 1, 1, 0.15), Color.TRANSPARENT, 0, 30, 12, 4))
	# Top-bar buttons, in the same translucent bubble as the counters.
	t.set_type_variation("ChipButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		t.set_stylebox(state, "ChipButton", _box(Color(1, 1, 1, 0.28 if state == "pressed" else 0.15), Color.TRANSPARENT, 0, 30, 14, 13))
	t.set_stylebox("focus", "ChipButton", StyleBoxEmpty.new())
	t.set_type_variation("Toast", "PanelContainer")
	t.set_stylebox("panel", "Toast", _box(INK, INK, 0, 14, 20, 12))
	t.set_type_variation("ToastBad", "PanelContainer")
	t.set_stylebox("panel", "ToastBad", _box(DANGER, DANGER, 0, 14, 20, 12))
	t.set_type_variation("Result", "PanelContainer")
	t.set_stylebox("panel", "Result", _box(PANEL, INK, 4, 18, 28, 24))

	# Outlined text that reads over the pixel scenes.
	for v in ["Scene", "SceneTitle", "SceneSmall"]:
		t.set_type_variation(v, "Label")
		t.set_color("font_color", v, Color.WHITE)
		t.set_color("font_outline_color", v, NIGHT)
		t.set_constant("outline_size", v, 8)
	t.set_font("font", "SceneTitle", bold_font())
	t.set_font_size("font_size", "SceneTitle", 32)
	t.set_font("font", "Scene", bold_font())
	t.set_font_size("font_size", "SceneSmall", 20)
	t.set_type_variation("FlatButton", "Button")
	for state in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "FlatButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "FlatButton", Color.WHITE)
	t.set_color("font_outline_color", "FlatButton", NIGHT)
	t.set_constant("outline_size", "FlatButton", 8)
	t.set_font("font", "FlatButton", bold_font())

	for v in ["Muted", "Small", "Hint", "Title", "Heading", "OnDark", "OnDarkBold"]:
		t.set_type_variation(v, "Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_color("font_color", "Small", MUTED)
	t.set_font_size("font_size", "Small", 20)
	t.set_color("font_color", "Hint", DANGER)
	t.set_font_size("font_size", "Hint", 20)
	t.set_font("font", "Title", bold_font())
	t.set_font_size("font_size", "Title", 30)
	t.set_font("font", "Heading", bold_font())
	t.set_font_size("font_size", "Heading", 25)
	t.set_color("font_color", "OnDark", Color.WHITE)
	t.set_color("font_color", "OnDarkBold", Color.WHITE)
	t.set_font("font", "OnDarkBold", bold_font())

	var bar_bg := _box(LINE, LINE, 0, 10, 0, 0)
	var bar_fill := _box(LEAF, LEAF, 0, 10, 0, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_font_size("font_size", "ProgressBar", 1)
	t.set_color("font_color", "ProgressBar", Color.TRANSPARENT)
	return t


## The pull-up sheet's and pop-outs' own theme: the same dark, softly bordered boxes and
## light text as the overlays on the pixel scenes. Only what differs from the
## main theme is set here; everything else falls through to it.
static func build_sheet_theme() -> Theme:
	var t := Theme.new()
	var sheet := _box(Color(NIGHT, 0.95), Color(1, 1, 1, 0.18), 2, 0, 0, 0)
	sheet.border_width_bottom = 0
	sheet.corner_radius_top_left = 30
	sheet.corner_radius_top_right = 30
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet)
	t.set_type_variation("PopCard", "PanelContainer")
	t.set_stylebox("panel", "PopCard", _box(Color(NIGHT, 0.97), Color(1, 1, 1, 0.22), 2, 24, 22, 20))
	t.set_stylebox("panel", "PanelContainer", _box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.16), 2, 14, 18, 16))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.16), 2, 14, 12, 10))
	t.set_color("font_color", "Label", SHEET_INK)
	for v in ["Title", "Heading"]:
		t.set_type_variation(v, "Label")
		t.set_color("font_color", v, Color.WHITE)
	for v in ["Muted", "Small"]:
		t.set_type_variation(v, "Label")
		t.set_color("font_color", v, SHEET_MUTED)
	t.set_type_variation("Hint", "Label")
	t.set_color("font_color", "Hint", SHEET_HINT)
	t.set_stylebox("background", "ProgressBar", _box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 10, 0, 0))
	return t


static func _button_styles(t: Theme, type: String, bg: Color, hover: Color, border: Color) -> void:
	var normal := _box(bg, border, 3, 14, 18, 10, 3)
	var hov := _box(hover, border, 3, 14, 18, 10, 3)
	var pressed := _box(hover, border, 3, 14, 18, 12, 0)
	pressed.content_margin_top = 13
	var disabled := _box(Color(bg, 0.5), Color(border, 0.35), 3, 14, 18, 10, 3)
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hov)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


# --- Widget helpers -----------------------------------------------------------

static func vbox(sep := 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func label(text: String, variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func icon(name: String, size := 28) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_pixel(name):
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func button(text: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(on_press)
	return b


static func panel(child: Control, variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	# Let drags fall through to the scroll view so the page scrolls by touch.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(child)
	return p


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


# Icon + amount pairs, red where the player can't afford it.
static func cost_row(cost: Dictionary, resources: Dictionary) -> HBoxContainer:
	var row := hbox(14)
	for res in cost:
		var pair := hbox(4)
		pair.add_child(icon(RES_ICON[res], 24))
		var l := label(str(cost[res]), "Heading")
		if resources[res] < cost[res]:
			l.add_theme_color_override("font_color", DANGER)
		pair.add_child(l)
		row.add_child(pair)
	return row


static func fmt(n: float) -> String:
	var i := floori(n)
	if i >= 1000000:
		return "%.1fM" % (i / 1000000.0)
	if i >= 10000:
		return "%.1fk" % (i / 1000.0)
	return str(i)


static func capitalize(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
