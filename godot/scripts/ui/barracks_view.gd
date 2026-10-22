extends Control
## Barracks: the formation on its stumps in the root hollow, with the roster
## benched below. Tap a troop, then a stump to place it; tap a placed troop to
## pick it up (tap its stump again to bench it); drag between stumps to move or
## swap, or between the roster and the stumps (dropping a placed troop anywhere
## below the stumps benches it). While a troop is dragged, a
## campfire appears in the corner: drop it there to dismiss it for good. New
## troops come out of the root box below the roster: inject sap for better odds
## and an element's energy to favour that element's troop, then tap the box. It
## moves to the middle of the screen and opens, and the new troop's card shows
## there a moment before dropping into the roster.

const Campfire := preload("res://scripts/ui/campfire.gd")
const TwigBoxArt := preload("res://scripts/ui/twig_box_art.gd")
## Roster tokens: the narrowest they get, their height, and the gap between them.
const TOKEN_W := 96.0
const TOKEN_H := 118.0
const TOKEN_GAP := 8
## Holding an inject button repeats it: the wait before the first repeat, then between repeats.
const HOLD_DELAY := 0.35
const HOLD_REPEAT := 0.12
## The opening: the box flies to the middle and grows this much, and the troop's
## card holds there this long before dropping into the roster.
const OPEN_ZOOM := 1.5
const CARD_HOLD := 1.0

var main: Control
var _scene: BarracksScene
var _margin: MarginContainer
var _counts: Label
var _hint: Label
var _lower: ScrollContainer
var _below: Control  # everything under the stumps, where a dragged troop goes back to the roster
var _bench: PanelContainer
var _bench_title: Label
var _tokens: HFlowContainer
var _box_art: Control
var _box_title: Label
var _box_upgrade: Button
var _box_sap: Label
var _box_energy: Label
var _box_hint: Label
var _inject_sap: Button
var _element_buttons := {}  # element -> Button
var _odds := {}  # rarity -> [bar fill ColorRect, percent Label]
var _focus_line: Label
var _opening := false
var _arriving := -1  # the troop whose card is on its way to the roster; its token waits hidden
var _details: Control  # a roster troop's card popped out over the Barracks, while open
var _lower_at := 0
var _hold: Timer
var _hold_action := Callable()
var _hold_button: Button
var _fire: VBoxContainer
var _fire_art: Control
var _fire_hot := false
var _insets := Vector2.ZERO


var _roster_hot := false
var _hint_before := ""


func _init(p_main: Control) -> void:
	main = p_main


func _ready() -> void:
	_scene = BarracksScene.new(main.ui["selected_troop"])
	_scene.set_anchors_preset(PRESET_FULL_RECT)
	_scene.pad_tapped.connect(_on_pad_tapped)
	_scene.resized.connect(_place_lower.call_deferred)
	add_child(_scene)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(PRESET_FULL_RECT)
	_margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_margin)
	var col := UI.vbox(2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_margin.add_child(col)
	var title := UI.label("Barracks", "SceneTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_counts = UI.label("", "SceneSmall")
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_counts)

	_below = Control.new()
	_below.mouse_filter = MOUSE_FILTER_PASS
	add_child(_below)

	# Below the formation, the roster bench and then the grow boxes, scrolling
	# together when they don't fit.
	_lower = ScrollContainer.new()
	_lower.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lower.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_lower)
	var stack := UI.vbox(8)
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	stack.minimum_size_changed.connect(_place_lower.call_deferred)
	_lower.add_child(stack)

	var box := UI.vbox(8)
	var head := UI.hbox(8)
	_bench_title = UI.label("", "Scene")
	head.add_child(_bench_title)
	head.add_child(UI.spacer())
	_hint = UI.label("", "SceneSmall")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_hint)
	box.add_child(head)
	_tokens = HFlowContainer.new()
	_tokens.add_theme_constant_override("h_separation", TOKEN_GAP)
	_tokens.add_theme_constant_override("v_separation", 8)
	_tokens.resized.connect(_fit_tokens)
	box.add_child(_tokens)
	_bench = UI.panel(box, "Pill")
	stack.add_child(_bench)
	# A troop dragged off its stump onto the roster, or anywhere else below the
	# stumps (like the grow boxes), leaves the formation.
	for c in [_below, _lower, stack, _bench, _tokens]:
		_accept_roster_drops(c)

	_hold = Timer.new()
	_hold.timeout.connect(_on_hold_tick)
	add_child(_hold)
	var box_panel := UI.panel(_build_box(), "Pill")
	stack.add_child(box_panel)
	for c in [box_panel] + box_panel.find_children("*", "Container", true, false):
		_accept_roster_drops(c)

	_fire = UI.vbox(0)
	_fire.visible = false
	_fire_art = Campfire.new()
	_fire.add_child(_fire_art)
	var fire_label := UI.label("Dismiss", "SceneSmall")
	fire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fire.add_child(fire_label)
	for c in [_fire, _fire_art, fire_label]:
		c.set_drag_forwarding(Callable(), _can_drop_on_fire, _drop_on_fire)
	add_child(_fire)
	refresh()


## Keeps the overlay clear of the shell's top bar and page indicator.
func apply_insets(top: float, bottom: float) -> void:
	_insets = Vector2(top, bottom)
	_margin.add_theme_constant_override("margin_top", int(top) + 6)
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_place_lower()


# The bench and grow boxes sit on the floor below the back row of stumps, as
# tall as they need but never down into the page indicator.
func _place_lower() -> void:
	if not is_instance_valid(_scene):
		return
	var top := _scene.origin.y + BarracksScene.GRID_BOTTOM * _scene.pixel_scale
	var room := size.y - _insets.y - 8.0 - top
	_below.position = Vector2(0, top)
	_below.size = Vector2(size.x, maxf(0.0, size.y - top))
	_lower.position = Vector2(16, top)
	_lower.size = Vector2(size.x - 32, clampf(_lower.get_child(0).get_combined_minimum_size().y, 0.0, maxf(0.0, room)))


## Updates in place after a state change (the shell calls this instead of rebuilding).
func refresh() -> void:
	var s: Dictionary = Game.state
	var sel: int = main.ui["selected_troop"]
	if sel >= 0 and Game.troop_by_id(sel).is_empty():
		sel = -1  # it fell in battle
		main.ui["selected_troop"] = sel
	_scene.selected_troop = sel
	_scene.sync()
	_counts.text = "Formation %d / %d  ·  ▲ the front row faces the enemy" % [s["formation"].size(), Game.formation_slots()]
	_bench_title.text = "Roster %d / %d" % [s["troops"].size(), Game.roster_cap()]
	if sel >= 0:
		var d := GameData.troop_def(Game.troop_by_id(sel))
		_hint.text = "Tap a stump for %s · %s" % [d["name"], d["role"]]
	elif s["troops"].is_empty():
		_hint.text = "No troops yet · open the root box below"
	else:
		_hint.text = ""
	_build_tokens()
	_refresh_box()
	_place_lower.call_deferred()


func _build_tokens() -> void:
	for c in _tokens.get_children():
		c.queue_free()
	var in_formation := {}
	for f in Game.state["formation"]:
		in_formation[f["troop_id"]] = true
	for t in Game.state["troops"]:
		_tokens.add_child(_token(t, in_formation.has(t["id"])))
	_fit_tokens()


# Widens the tokens so each row fills the roster exactly, leaving the same
# margin on both sides rather than the leftover width on the right.
func _fit_tokens() -> void:
	var w := _tokens.size.x
	if w <= 0.0:
		return
	var cols := maxi(1, floori((w + TOKEN_GAP) / (TOKEN_W + TOKEN_GAP)))
	var tw := floorf((w - TOKEN_GAP * (cols - 1)) / cols)
	for c in _tokens.get_children():
		c.custom_minimum_size.x = tw


# A roster troop: its sprite, number and element, ringed in gold when picked.
func _token(t: Dictionary, placed: bool) -> Button:
	var d := GameData.troop_def(t)
	var picked: bool = main.ui["selected_troop"] == t["id"]
	var b := Button.new()
	b.text = "#%d%s" % [t["id"], " ✓" if placed else ""]
	b.icon = UI.crisp(d["img"])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(TOKEN_W, TOKEN_H)
	b.tooltip_text = d["name"]
	b.add_theme_font_size_override("font_size", 20)
	var text_col: Color = Color.WHITE if d["element"] == "" else GameData.BIOME_COLORS[d["element"]].lightened(0.35)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text_col)
	b.add_theme_color_override("font_outline_color", UI.NIGHT)
	b.add_theme_constant_override("outline_size", 6)
	var look := _token_style(picked)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, look)
	if placed and not picked:
		b.modulate.a = 0.6
	if t["id"] == _arriving:
		b.modulate.a = 0.0
	b.set_meta("troop_id", t["id"])
	b.pressed.connect(_on_troop_pressed.bind(t["id"]))
	b.set_drag_forwarding(_drag_token.bind(t), _can_drop_on_roster, _drop_on_roster)
	return b


# Dragging a roster troop carries it toward the stumps (or the campfire).
func _drag_token(_at: Vector2, t: Dictionary) -> Variant:
	set_drag_preview(_scene.drag_preview(t))
	return {"roster_troop": t["id"]}


static func _token_style(picked: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.NIGHT, 0.85 if picked else 0.55)
	s.border_color = UI.ROOT_GLOW if picked else Color(1, 1, 1, 0.16)
	s.set_border_width_all(4 if picked else 2)
	s.set_corner_radius_all(14)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 4
	return s


# --- Root box ------------------------------------------------------------------

# The root box panel: its name and upgrade, the box itself beside the inject
# buttons and odds, and Drain / Open underneath. Built once, so the box keeps
# animating while refresh() updates the numbers.
func _build_box() -> VBoxContainer:
	var col := UI.vbox(10)
	var head := UI.hbox(8)
	_box_title = UI.label("", "Scene")
	_box_title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(_box_title)
	_box_upgrade = Button.new()
	_box_upgrade.add_theme_font_size_override("font_size", 18)
	_style_button(_box_upgrade)
	_box_upgrade.pressed.connect(_on_upgrade_box)
	head.add_child(_box_upgrade)
	col.add_child(head)

	var row := UI.hbox(12)
	var art_col := UI.vbox(0)
	_box_art = TwigBoxArt.new()
	_box_art.unit = 4.0
	_box_art.tapped.connect(_on_box_tapped)
	_box_art.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_lower_at = _lower.scroll_vertical)
	art_col.add_child(_box_art)
	_box_hint = _box_label("", 18)
	_box_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box_hint.custom_minimum_size = Vector2(_box_art.custom_minimum_size.x, 48)
	art_col.add_child(_box_hint)
	row.add_child(art_col)

	var side := UI.vbox(8)
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	_box_sap = _box_label("", 18)
	_box_sap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(_box_sap)
	_inject_sap = Button.new()
	_inject_sap.icon = UI.crisp(UI.RES_ICON["sap"])
	_inject_sap.expand_icon = true
	_inject_sap.add_theme_constant_override("icon_max_width", 30)
	_inject_sap.add_theme_font_size_override("font_size", 20)
	_style_button(_inject_sap)
	_hold_to_repeat(_inject_sap, _on_inject_sap)
	side.add_child(_inject_sap)
	_box_energy = _box_label("", 18)
	_box_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(_box_energy)
	var els := UI.hbox(4)
	for el in GameData.ELEMENTS:
		var b := Button.new()
		b.icon = UI.crisp("icon_" + el)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 32)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 18)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		_style_button(b)
		_hold_to_repeat(b, _on_inject_power.bind(el))
		els.add_child(b)
		_element_buttons[el] = b
	side.add_child(els)
	for r in GameData.RARITY_ORDER:
		var line := UI.hbox(6)
		var name := _box_label(GameData.RARITY[r]["name"], 18)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.custom_minimum_size.x = 100
		name.add_theme_color_override("font_color", GameData.RARITY[r]["color"])
		line.add_child(name)
		var track := Panel.new()
		var track_look := StyleBoxFlat.new()
		track_look.bg_color = Color(UI.NIGHT, 0.7)
		track_look.set_corner_radius_all(3)
		track.add_theme_stylebox_override("panel", track_look)
		track.size_flags_horizontal = SIZE_EXPAND_FILL
		track.size_flags_vertical = SIZE_SHRINK_CENTER
		track.custom_minimum_size.y = 10
		track.mouse_filter = MOUSE_FILTER_IGNORE
		var bar := ColorRect.new()
		bar.color = GameData.RARITY[r]["color"]
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		track.add_child(bar)
		track.resized.connect(_refresh_odds)
		line.add_child(track)
		var pct := _box_label("", 18)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.custom_minimum_size.x = 56
		line.add_child(pct)
		side.add_child(line)
		_odds[r] = [bar, pct]
	_focus_line = _box_label("", 17)
	_focus_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_focus_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_focus_line)
	row.add_child(side)
	col.add_child(row)

	return col


# The dark token look for the box's own buttons, with light outlined text.
func _style_button(b: Button) -> void:
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 52)
	var look := _token_style(false)
	var down := _token_style(true)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, look)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_color_override("font_outline_color", UI.NIGHT)
	b.add_theme_constant_override("outline_size", 6)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UI.SHEET_INK)
	b.add_theme_color_override("font_disabled_color", Color(UI.SHEET_INK, 0.4))


# Fires `action` on press, then again and again while the button is held,
# until it is let go or the action fails. `action` returns whether it worked.
func _hold_to_repeat(b: Button, action: Callable) -> void:
	b.button_down.connect(func() -> void:
		_hold_action = action
		_hold_button = b
		if action.call():
			_hold.start(HOLD_DELAY))
	b.button_up.connect(_hold.stop)


func _on_hold_tick() -> void:
	_hold.wait_time = HOLD_REPEAT
	if not (is_instance_valid(_hold_button) and _hold_button.is_pressed() and not _hold_button.disabled
			and not _opening and _hold_action.call()):
		_hold.stop()


func _refresh_box() -> void:
	var box: Dictionary = Game.state["twig_box"]
	var def := GameData.twig_box(box["tier"])
	var busy := _opening
	_box_art.tier = box["tier"]
	_box_art.fill = box["sap"] / def["max_sap"]
	_box_art.element = box["element"]
	_box_art.energy = box["power"] / GameData.BOX_MAX_POWER
	_box_title.text = "%s  ·  Tier %d" % [def["name"], box["tier"]]
	if box["tier"] < GameData.TWIG_BOXES.size():
		var next := GameData.twig_box(box["tier"] + 1)
		var cost := []
		for res in next["cost"]:
			cost.append("%s %s" % [UI.fmt(next["cost"][res]), res])
		_box_upgrade.visible = true
		_box_upgrade.text = "▲ %s · %s" % [next["name"], " + ".join(cost)] if Game.state["tree"]["level"] >= next["unlock_level"] \
			else "▲ %s · Tree Lv %d" % [next["name"], next["unlock_level"]]
		_box_upgrade.disabled = busy or not Game.can_upgrade_box()["ok"]
	else:
		_box_upgrade.visible = false
	var res: Dictionary = Game.state["resources"]
	_box_sap.text = "Sap %d / %d  ·  opens at %d" % [box["sap"], def["max_sap"], def["min_sap"]]
	_inject_sap.text = "Inject %d sap" % def["sap_step"]
	_inject_sap.disabled = busy or box["sap"] >= def["max_sap"] or res["sap"] < 1.0
	if box["element"] == "":
		_box_energy.text = "Energy 0 / %d  ·  tap an element" % GameData.BOX_MAX_POWER
	else:
		_box_energy.text = "%s energy %d / %d" % [UI.capitalize(box["element"]), box["power"], GameData.BOX_MAX_POWER]
	for el in _element_buttons:
		var b: Button = _element_buttons[el]
		var open: bool = Game.has_conquered_element(el)
		b.text = UI.fmt(res["power"][el]) if open else "🔒"
		b.disabled = busy or not open or (box["element"] != "" and box["element"] != el)
		b.tooltip_text = "Inject %s energy: favours the %s" % [el, GameData.TROOPS[GameData.element_troop(el)]["name"]] if open \
			else Game.power_block(el)
	var check := Game.can_open_box()
	_box_art.can_open = check["ok"] and not busy
	_box_hint.text = "Tap the box to open it" if check["ok"] else check["msg"].trim_suffix(".")
	_box_hint.add_theme_color_override("font_color", UI.ROOT_GLOW if check["ok"] else UI.SHEET_MUTED)
	_refresh_odds()


# Odds bars and percentages, and what the injected energy favours.
func _refresh_odds() -> void:
	if _odds.is_empty():
		return
	var odds := Game.box_odds()
	for r in _odds:
		var p: float = odds["rarity"][r]
		var bar: ColorRect = _odds[r][0]
		var track := bar.get_parent() as Control
		bar.size = Vector2(roundf(track.size.x * p), track.size.y)
		_odds[r][1].text = _pct(p)
	var box: Dictionary = Game.state["twig_box"]
	if box["element"] != "" and odds["focus"] > 0.0:
		var type := GameData.element_troop(box["element"])
		_focus_line.text = "%s %s" % [GameData.TROOPS[type]["name"], _pct(odds["types"][type])]
		_focus_line.add_theme_color_override("font_color", GameData.BIOME_COLORS[box["element"]].lightened(0.35))
	else:
		_focus_line.text = "Energy raises the odds of its element's troop."
		_focus_line.add_theme_color_override("font_color", UI.SHEET_MUTED)


static func _pct(p: float) -> String:
	if p > 0.0 and p < 0.01:
		return "<1%"
	return "%d%%" % roundi(p * 100.0)


func _on_inject_sap() -> bool:
	var ok: bool = Game.inject_sap()["ok"]
	if ok:
		_box_art.pour_sap()
	return ok


func _on_inject_power(el: String) -> bool:
	var ok: bool = Game.inject_power(el)["ok"]
	if ok:
		_box_art.pour_power(el)
	return ok


func _on_upgrade_box() -> void:
	if Game.upgrade_box()["ok"]:
		_box_art.tier = Game.state["twig_box"]["tier"]
		_box_art.pour_sap()


# Tapping the box opens it (a scroll that started on it doesn't): a copy of it
# flies to the middle of the screen over a dimmed Barracks and opens there.
func _on_box_tapped() -> void:
	if _opening or absi(_lower.scroll_vertical - _lower_at) >= 8:
		return
	var box: Dictionary = Game.state["twig_box"]
	var fly := TwigBoxArt.new()
	fly.unit = _box_art.unit
	fly.tier = box["tier"]
	fly.fill = _box_art.fill
	fly.element = _box_art.element
	fly.energy = _box_art.energy
	var res := Game.open_box()
	if not res["ok"]:
		fly.free()
		return
	var troop: Dictionary = res["troop"]
	_opening = true
	_arriving = troop["id"]
	_scene.hidden_troop = troop["id"]  # it takes its stump once its card lands
	_hold.stop()
	main.render()

	var veil := Control.new()  # catches taps while the box is open
	veil.set_anchors_preset(PRESET_FULL_RECT)
	veil.mouse_filter = MOUSE_FILTER_STOP
	add_child(veil)
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(UI.NIGHT, 0.0)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	veil.add_child(dim)
	var home := _box_art.get_global_rect().position - get_global_rect().position
	fly.position = home
	veil.add_child(fly)
	_box_art.modulate.a = 0.0
	var mid := (size - fly.custom_minimum_size * OPEN_ZOOM) * 0.5
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(dim, "color:a", 0.7, 0.35)
	t.tween_property(fly, "position", mid.round(), 0.45)
	t.tween_property(fly, "scale", Vector2.ONE * OPEN_ZOOM, 0.45)
	await t.finished
	fly.open(troop)
	await fly.revealed
	# Everything injected went into the troop: the box drains while its card shows.
	fly.fill = 0.0
	fly.element = ""
	fly.energy = 0.0
	var card := _troop_card(troop)
	veil.add_child(card)
	# The card grows out of the troop as it leaves the box.
	card.reset_size()
	card.pivot_offset = card.size * 0.5
	card.position = (fly.position + fly.troop_center() * OPEN_ZOOM - card.size * 0.5).round()
	card.scale = Vector2.ONE * 0.3
	var c := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.tween_property(card, "scale", Vector2.ONE, 0.35)
	c.tween_property(card, "position", ((size - card.size) * 0.5).round(), 0.35)
	await get_tree().create_timer(0.35 + CARD_HOLD).timeout
	await _drop_card(card)
	# The fresh box goes back to its spot and the Barracks brightens.
	var back := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(dim, "color:a", 0.0, 0.35)
	back.tween_property(fly, "position", _box_art.get_global_rect().position - get_global_rect().position, 0.4)
	back.tween_property(fly, "scale", Vector2.ONE, 0.4)
	await back.finished
	veil.queue_free()
	_box_art.modulate.a = 1.0
	_opening = false
	_refresh_box()


# The card drops into the troop's new spot on the roster, which then pops in.
func _drop_card(card: Control) -> void:
	var token := _token_for(_arriving)
	if token:
		_lower.ensure_control_visible(token)
		await get_tree().process_frame
	var to := card.position + Vector2(0, size.y)  # off the bottom if its token is gone
	var shrink := 0.5
	if token:
		var r := token.get_global_rect()
		shrink = r.size.x / card.size.x
		to = r.get_center() - get_global_rect().position - card.size * 0.5
	var d := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	d.tween_property(card, "position", to.round(), 0.45)
	d.tween_property(card, "scale", Vector2.ONE * shrink, 0.45)
	d.tween_property(card, "modulate:a", 0.0, 0.15).set_delay(0.3)
	await d.finished
	card.queue_free()
	var id := _arriving
	_arriving = -1
	_scene.reveal()
	token = _token_for(id)
	if token:
		token.modulate.a = 1.0
		token.pivot_offset = token.size * 0.5
		token.scale = Vector2.ONE * 1.25
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(token, "scale", Vector2.ONE, 0.3)


func _token_for(id: int) -> Control:
	for c in _tokens.get_children():
		if not c.is_queued_for_deletion() and c.get_meta("troop_id", -1) == id:
			return c
	return null


# A troop's card: its sprite, name and rarity, and HP / DMG / reach, framed in
# its rarity's colour. With `details` (a roster troop tapped) it also shows its
# attack and move speed, element matchups, every ability, where it stands, and
# buttons to place it or take it off its stump.
func _troop_card(troop: Dictionary, details := false) -> PanelContainer:
	var d := GameData.troop_def(troop)
	var rarity: Dictionary = GameData.RARITY[d["rarity"]]
	var look := _token_style(true)
	look.border_color = rarity["color"]
	look.bg_color = Color(UI.NIGHT, 0.95)
	look.set_content_margin_all(16)
	look.shadow_color = Color(rarity["color"], 0.35)
	look.shadow_size = 18
	var col := UI.vbox(4)
	col.add_child(UI.icon(d["img"], 128))
	var rl := _box_label(rarity["name"].to_upper(), 18)
	rl.add_theme_color_override("font_color", rarity["color"])
	col.add_child(rl)
	var text_col: Color = Color.WHITE if d["element"] == "" else GameData.BIOME_COLORS[d["element"]].lightened(0.35)
	var nl := _box_label("%s  #%d" % [d["name"], troop["id"]], 24)
	nl.add_theme_color_override("font_color", text_col)
	col.add_child(nl)
	var role := _box_label(d["role"], 16)
	role.modulate.a = 0.75
	col.add_child(role)
	var stats := UI.hbox(14)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var pairs := [["HP", d["hp"]], ["DMG", d["dmg"]], ["Reach", d["reach"]]]
	if details:
		pairs += [["Attack", "%ss" % str(d["cooldown"])], ["Move", d["speed"]]]
	for pair in pairs:
		var stat := UI.vbox(0)
		var cap := _box_label(pair[0], 15)
		cap.modulate.a = 0.7
		stat.add_child(cap)
		stat.add_child(_box_label(str(pair[1]), 22))
		stats.add_child(stat)
	col.add_child(stats)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", look)
	card.custom_minimum_size.x = 280
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(col)
	if details:
		_add_details(col, troop, d, rarity["color"])
		card.custom_minimum_size.x = minf(440.0, size.x - 32.0)
		card.mouse_filter = MOUSE_FILTER_STOP  # taps on the card don't close it
		card.set_meta("troop_id", troop["id"])
	return card


func _add_details(col: VBoxContainer, troop: Dictionary, d: Dictionary, accent: Color) -> void:
	var el: String = d["element"]
	var match_line: Label
	if el == "":
		match_line = _box_label("No element · even against every foe", 16)
		match_line.modulate.a = 0.75
	else:
		match_line = _box_label("Strong vs %s  ·  Weak vs %s" % [GameData.strong_against(el).capitalize(),
			GameData.weak_against(el).capitalize()], 16)
		match_line.add_theme_color_override("font_color", GameData.BIOME_COLORS[el].lightened(0.35))
	col.add_child(match_line)
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.35)
	rule.custom_minimum_size.y = 2
	col.add_child(rule)
	for line in GameData.troop_traits(d):
		var l := _box_label("•  " + line, 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(400.0, size.x - 72.0)
		col.add_child(l)
	var spot := {}
	for f in Game.state["formation"]:
		if f["troop_id"] == troop["id"]:
			spot = f
	var where := _box_label("In the roster, not in the formation" if spot.is_empty()
		else "Stands on the %s row, %s" % [spot["row"], ["left", "middle", "right"][spot["lane"]]], 16)
	where.modulate.a = 0.75
	col.add_child(where)
	var buttons := UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var id: int = troop["id"]
	buttons.add_child(UI.button("Move" if not spot.is_empty() else "Place", func() -> void:
		main.ui["selected_troop"] = id
		_close_details()
		main.render()))
	if not spot.is_empty():
		buttons.add_child(UI.button("Bench", func() -> void:
			Game.place_troop(-1, spot["row"], spot["lane"])
			_close_details()))
	buttons.add_child(UI.button("Close", _close_details))
	col.add_child(buttons)


# Light outlined text for the dark boxes.
static func _box_label(text: String, font_size: int) -> Label:
	var l := UI.label(text, "SceneSmall")
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _accept_roster_drops(c: Control) -> void:
	c.set_drag_forwarding(Callable(), _can_drop_on_roster, _drop_on_roster)


func _can_drop_on_roster(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("barracks_pad")
	_set_roster_hot(ok)
	return ok


func _drop_on_roster(_at: Vector2, data: Variant) -> void:
	_set_roster_hot(false)
	main.ui["selected_troop"] = -1
	Game.place_troop(-1, data["row"], data["lane"])


# The roster lights up while a dragged troop hovers over it.
func _set_roster_hot(on: bool) -> void:
	if on == _roster_hot:
		return
	_roster_hot = on
	_bench.self_modulate = Color(1.35, 1.3, 0.85) if on else Color.WHITE
	if on:
		_hint_before = _hint.text
		_hint.text = "Drop to take it out of the formation"
	else:
		_hint.text = _hint_before


# The campfire shows in the bottom corner while any troop is being dragged.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and _fire:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and (data.has("barracks_pad") or data.has("roster_troop")):
			_fire_art.unit = maxf(3.0, _scene.pixel_scale)
			_fire.size = Vector2.ZERO
			_fire.position = size - _fire.get_combined_minimum_size() - Vector2(16, _insets.y + 8)
			_fire.visible = true
	elif what == NOTIFICATION_DRAG_END and _fire:
		_fire.visible = false
		_set_fire_hot(false)


func _can_drop_on_fire(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and (data.has("barracks_pad") or data.has("roster_troop"))
	_set_fire_hot(ok)
	return ok


func _drop_on_fire(_at: Vector2, data: Variant) -> void:
	_set_fire_hot(false)
	var id: int = data["troop_id"] if data.has("troop_id") else data["roster_troop"]
	if main.ui["selected_troop"] == id:
		main.ui["selected_troop"] = -1
	Game.dismiss_troop(id)


func _set_fire_hot(on: bool) -> void:
	if on == _fire_hot:
		return
	_fire_hot = on
	_fire_art.hot = on


func _process(_delta: float) -> void:
	if _fire_hot and not (get_viewport().gui_is_dragging() and _fire.get_global_rect().has_point(get_global_mouse_position())):
		_set_fire_hot(false)
	var at := get_global_mouse_position()
	if _roster_hot and not (get_viewport().gui_is_dragging() and _below.get_global_rect().has_point(at)
			and not (_fire.visible and _fire.get_global_rect().has_point(at))):
		_set_roster_hot(false)


# Tapping a roster troop pops its card out to the middle of the screen.
func _on_troop_pressed(id: int) -> void:
	if _opening or is_instance_valid(_details):
		return
	if main.ui["selected_troop"] >= 0:
		main.ui["selected_troop"] = -1
		main.render()
	_show_details(id)


# The troop's card grows out of its roster token to the middle, over a dimmed
# Barracks, with everything about it and what can be done with it. Tapping
# outside the card (or Close) sends it back into the token.
func _show_details(id: int) -> void:
	var troop := Game.troop_by_id(id)
	var token := _token_for(id)
	if troop.is_empty():
		return
	var veil := Control.new()
	veil.set_anchors_preset(PRESET_FULL_RECT)
	veil.mouse_filter = MOUSE_FILTER_STOP
	add_child(veil)
	_details = veil
	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(UI.NIGHT, 0.0)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	veil.add_child(dim)
	var card := _troop_card(troop, true)
	veil.add_child(card)
	card.reset_size()
	card.pivot_offset = card.size * 0.5
	var mid := ((size - card.size) * 0.5).round()
	var from := mid
	var shrink := 0.3
	if token:
		var r := token.get_global_rect()
		shrink = r.size.x / card.size.x
		from = r.get_center() - get_global_rect().position - card.size * 0.5
	card.position = from.round()
	card.scale = Vector2.ONE * shrink
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(dim, "color:a", 0.7, 0.25)
	t.tween_property(card, "position", mid, 0.3)
	t.tween_property(card, "scale", Vector2.ONE, 0.3)
	veil.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_details())


func _close_details() -> void:
	if not is_instance_valid(_details) or _details.has_meta("closing"):
		return
	var veil := _details
	veil.set_meta("closing", true)
	var dim: ColorRect = veil.get_child(0)
	var card: Control = veil.get_child(1)
	var token := _token_for(card.get_meta("troop_id", -1))
	var to := card.position + Vector2(0, size.y * 0.25)
	var shrink := 0.3
	if token:
		var r := token.get_global_rect()
		shrink = r.size.x / card.size.x
		to = r.get_center() - get_global_rect().position - card.size * 0.5
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(dim, "color:a", 0.0, 0.22)
	t.tween_property(card, "position", to.round(), 0.22)
	t.tween_property(card, "scale", Vector2.ONE * shrink, 0.22)
	t.tween_property(card, "modulate:a", 0.0, 0.12).set_delay(0.1)
	await t.finished
	veil.queue_free()


# With a troop picked, a stump takes it (replacing whoever stood there), or
# benches it if it is the stump it already stands on. Otherwise tapping a
# placed troop picks it up.
func _on_pad_tapped(row: String, lane: int) -> void:
	var sel: int = main.ui["selected_troop"]
	var here: int = -1
	for f in Game.state["formation"]:
		if f["row"] == row and f["lane"] == lane:
			here = f["troop_id"]
	if sel >= 0:
		main.ui["selected_troop"] = -1
		Game.place_troop(-1 if here == sel else sel, row, lane)
	elif here >= 0:
		main.ui["selected_troop"] = here
	main.render()
