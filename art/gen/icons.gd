# Icons sheet (16x16 cells): resources, elements, inventory, potions, and the
# menu bars and pull-up chevron. Cell order is ICONS; the chevron (9x6) sits in the last cell.
var img: Image
const ICONS := ["icon_sunlight", "icon_sap", "icon_nature", "icon_water", "icon_fire", "icon_ice", "icon_dark",
	"icon_inventory", "item_thorn_draught", "item_bark_brew", "item_reach_tonic", "item_keen_elixir", "item_gale_brew", "icon_menu", "handle_up",
	"shroom_thorn_draught", "shroom_bark_brew", "shroom_reach_tonic", "shroom_keen_elixir", "shroom_gale_brew"]
# Each potion's liquid (dark, mid, light). Its battlefield mushroom wears the same colours.
const POTION_LIQUID := {
	"thorn_draught": [Color("#9e2a26"), Color("#d9534f"), Color("#ff9c8f")],
	"bark_brew": [Color("#173d22"), Color("#2a6a3a"), Color("#5ea86a")],
	"reach_tonic": [Color("#16346a"), Color("#2a58a0"), Color("#78a8e0")],
	"keen_elixir": [Color("#b07a12"), Color("#ffc93c"), Color("#fff1a8")],
	"gale_brew": [Color("#2a7f78"), Color("#62d2c2"), Color("#d4fff6")],
}

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func bayer(x, y) -> float:
	var m = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (m[(posmod(y, 4)) * 4 + posmod(x, 4)] + 0.5) / 16.0

func auto_outline(r: Rect2i, amt := 0.72):
	var src = img.get_region(r)
	for y in r.size.y:
		for x in r.size.x:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < r.size.x and q.y < r.size.y and src.get_pixel(q.x, q.y).a > 0.5:
					var c = src.get_pixel(q.x, q.y).darkened(amt)
					c.a = 1.0
					img.set_pixel(r.position.x + x, r.position.y + y, c)
					break

func pattern(ox, oy, rows: Array, cols: Dictionary):
	for y in rows.size():
		for x in rows[y].length():
			var ch = rows[y][x]
			if cols.has(ch):
				px(ox + x, oy + y, cols[ch])

# Shaded round blob: light from the upper right.
func ball(ox, cx, cy, rx, ry, pal: Array):
	for y in 16:
		for x in 16:
			var n = Vector2((x - cx) / rx, (y - cy) / ry)
			if n.length() <= 1.0:
				var t = n.dot(Vector2(0.55, -0.83)) + bayer(x, y) * 0.3 - 0.15
				px(ox + x, y, pal[2] if t > 0.4 else (pal[1] if t > -0.35 else pal[0]))

func drop(ox, pal: Array):
	for y in range(1, 15):
		for x in range(1, 15):
			var fy = (y - 9.5) / 5.0
			var hw = 5.0 * sqrt(maxf(0.0, 1.0 - fy * fy)) if fy > -0.25 else 5.0 * (1.0 - (-fy - 0.25) / 1.45)
			if absf(x - 7.5) <= hw and y >= 2:
				var t = (x - 7.5) / 5.0 - fy * 0.45 + bayer(x, y) * 0.25 - 0.12
				px(ox + x, y, pal[2] if t > 0.4 else (pal[1] if t > -0.35 else pal[0]))
	px(ox + 9, 8, Color.WHITE); px(ox + 9, 9, pal[2]); px(ox + 10, 10, pal[2])

# Every potion shares one tall, square-shouldered bottle with a bark root wound
# around its middle; only the liquid's colour tells them apart.
func potion(ox, liquid: Array):
	pattern(ox, 0, [
		".......cC.......",
		".......cC.......",
		"......gggg......",
		".......gg.......",
		"......gLLg......",
		".....gLLLLg.....",
		"....gLlLLLLg....",
		"....gLlLLLLg....",
		"....gLlLLLLg....",
		"....gLLLLLLg....",
		"....gLLLLLLg....",
		"....gLLLLLLg....",
		"....gLLLLLDg....",
		"....gDDDDDDg....",
		".....gggggg.....",
	], {"c": Color("#8a5530"), "C": Color("#b07d48"), "g": Color("#e8f4f0"), "L": liquid[1], "l": liquid[2], "D": liquid[0]})
	var bark = [Color("#3a2212"), Color("#6a4226"), Color("#9a6a40")]
	# Behind the bottle the root shows darker through the liquid, from upper right to lower left.
	for x in range(5, 11):
		px(ox + x, int(round(9.0 + (10 - x) * 0.6)), liquid[0].darkened(0.45))
	# In front it climbs from lower left to upper right, hugging the glass at both sides.
	for x in range(4, 12):
		var y = int(round(11.0 - (x - 4) * 0.38))
		px(ox + x, y, bark[2] if x % 3 == 0 else bark[1])
		px(ox + x, y + 1, bark[0])

# A battlefield mushroom in a potion's colours: tap it in battle for that potion.
# Drawn like the battlefields' own mushrooms (see battlefields.gd MUSH_BIG), one
# size up so it stands out to tap, and outlined the same way.
func shroom(ox, cap: Array):
	var rows := [
		"...MML...",
		"..MMMLL..",
		".MSMMMLL.",
		"MSSMMMSLM",
		"DMMMMSSMM",
		".DDDDDDD.",
		"...TTt...",
		"...TTt...",
		"...TTt...",
	]
	var oy = 14 - rows.size()
	var cx = ox + 4
	pattern(cx - 4 + 3, oy, rows, {"M": cap[1], "L": cap[2], "D": cap[0], "S": Color("#fff6e8"), "T": Color("#e8dcc8"), "t": Color("#b8a890")})
	# A dark edge in a shade of what it borders, as the battlefield props have.
	var ref = img.duplicate()
	for y in 16:
		for x in range(ox, ox + 16):
			if ref.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var q = Vector2i(x, y) + d
				if q.x >= ox and q.x < ox + 16 and q.y >= 0 and q.y < 16 and ref.get_pixel(q.x, q.y).a > 0.0:
					img.set_pixel(x, y, ref.get_pixel(q.x, q.y).darkened(0.72))
					break

func icon(name: String, ox: int):
	match name:
		"icon_sunlight":
			var ray = Color("#ffb627")
			for a in 8:
				var dir = Vector2.from_angle(a * PI / 4.0)
				var n = 2 if a % 2 == 0 else 1
				for r in n:
					var p = Vector2(7.5, 7.5) + dir * (5.4 + r)
					px(ox + int(round(p.x)), int(round(p.y)), ray)
			ball(ox, 7.5, 7.5, 4.0, 4.0, [Color("#f0a020"), Color("#ffd447"), Color("#fff3a8")])
		"icon_sap":
			drop(ox, [Color("#c9761a"), Color("#f0a02d"), Color("#ffd27a")])
		"icon_water":
			drop(ox, [Color("#2f64b5"), Color("#5ba4e8"), Color("#c6e8ff")])
		"icon_nature":
			pattern(ox, 0, [
				"................",
				"..........DDD...",
				"........DDLLLD..",
				"......DDLLLLHD..",
				".....DLLLLLHHD..",
				"....DLLLLLLHD...",
				"...DLLLLLLHHD...",
				"...DLLLLLHLD....",
				"..DLLLLLHLLD....",
				"..DLLLLHLLD.....",
				"..DLLLHLLD......",
				"...DLHLDD.......",
				"..S.HDD.........",
				".S..............",
				"S...............",
			], {"D": Color("#2e8a3a"), "L": Color("#5dbb4c"), "H": Color("#b6ec8a"), "S": Color("#3f7a2a")})
		"icon_fire":
			pattern(ox, 0, [
				".......R........",
				"......RR........",
				"......ROR.......",
				".....ROOR...R...",
				"....ROOOOR..RR..",
				"...ROOOYOOR.ROR.",
				"...ROOYYOORROOR.",
				"..ROOOYYYOOOOOR.",
				"..ROOYYWYYOOOR..",
				"..ROYYWWWYYOOR..",
				"..ROYYWWWYYOR...",
				"...ROYYWYYOR....",
				"....ROOYOOR.....",
				".....RRRRR......",
			], {"R": Color("#c8321e"), "O": Color("#f0642d"), "Y": Color("#ffb347"), "W": Color("#fff1a8")})
		"icon_ice":
			pattern(ox, 0, [
				".......W........",
				"......BWB.......",
				"..W....W....W...",
				"..BW...W...WB...",
				"...BW..W..WB....",
				"....BW.W.WB.....",
				".....BWWWB......",
				".WWWWWWLWWWWWW..",
				".....BWWWB......",
				"....BW.W.WB.....",
				"...BW..W..WB....",
				"..BW...W...WB...",
				"..W....W....W...",
				"......BWB.......",
				".......W........",
			], {"W": Color("#e8f8ff"), "B": Color("#7fc8f0"), "L": Color("#ffffff")})
		"icon_dark":
			pattern(ox, 0, [
				"................",
				".....PPPP.......",
				"...PPLLPP.......",
				"..PLLPP.....s...",
				"..PLPP.....sSs..",
				".PLLP.......s...",
				".PLP............",
				".PLP............",
				".PLLP...........",
				".PLLPP......PP..",
				"..PLLPPP..PPLP..",
				"..PPLLLLPPLLP...",
				"...PPLLLLLLPP...",
				".....PPPPPP.....",
			], {"P": Color("#6a3fa0"), "L": Color("#a77ce0"), "s": Color("#d9c2ff"), "S": Color("#ffffff")})
		"icon_inventory":
			pattern(ox, 0, [
				"................",
				".....DDDDDD.....",
				"....D......D....",
				"....D......D....",
				"..BBBBBBBBBBBB..",
				".BLLLLLLLLLLLLB.",
				".BLLLLLLLLLLLLB.",
				".BDDDDDYYDDDDDB.",
				".BMMMMMYYMMMMMB.",
				".BMMMMMMMMMMMMB.",
				".BMMMMMMMMMMMMB.",
				".BMMMMMMMMMMMMB.",
				".BDDDDDDDDDDDDB.",
				"..BBBBBBBBBBBB..",
			], {"B": Color("#5e3a20"), "L": Color("#b07d48"), "M": Color("#9c6b3c"), "D": Color("#7a4e26"), "Y": Color("#ffd447")})
		"item_thorn_draught", "item_bark_brew", "item_reach_tonic", "item_keen_elixir", "item_gale_brew":
			potion(ox, POTION_LIQUID[name.trim_prefix("item_")])
		"shroom_thorn_draught", "shroom_bark_brew", "shroom_reach_tonic", "shroom_keen_elixir", "shroom_gale_brew":
			shroom(ox, POTION_LIQUID[name.trim_prefix("shroom_")])
		"icon_menu":
			# Three rounded bars, white with a dark rim like the chevron, for green buttons.
			var bar = ".WWWWWWWWWWWW."
			pattern(ox + 1, 2, [bar, bar.replace(".", "W"), bar, "", "", bar, bar.replace(".", "W"), bar, "", "", bar, bar.replace(".", "W"), bar],
				{"W": Color.WHITE})
			for y in [3, 8, 13]:
				for x in range(3, 14):
					px(ox + x, y, Color("#e3eadb"))
			dark_rim(ox)
			return
		"handle_up":
			pattern(ox, 4, [
				"....W....",
				"...WWW...",
				"..WWWWW..",
				".WWW.WWW.",
				"WWW...WWW",
				"WW.....WW",
			], {"W": Color.WHITE})
			dark_rim(ox)
			return
	auto_outline(Rect2i(ox, 0, 16, 16))

# A one-pixel night-green rim around white shapes, so they read on any button.
func dark_rim(ox):
	var src = img.get_region(Rect2i(ox, 0, 16, 16))
	for y in 16:
		for x in 16:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 16 and q.y < 16 and src.get_pixel(q.x, q.y).a > 0.5:
					px(ox + x, y, Color("#14231a"))
					break

func run(api, image, project, params):
	img = Image.create(16 * ICONS.size(), 16, false, Image.FORMAT_RGBA8)
	for i in ICONS.size():
		icon(ICONS[i], i * 16)
	return img
