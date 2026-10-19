# Icons sheet (16x16 cells): resources, elements, inventory, potions, and the
# menu bars and pull-up chevron. Cell order is ICONS; the chevron (9x6) sits in the last cell.
var img: Image
const ICONS := ["icon_sunlight", "icon_sap", "icon_nature", "icon_water", "icon_fire", "icon_ice", "icon_dark",
	"icon_inventory", "item_thorn_draught", "item_bark_brew", "item_reach_tonic", "icon_menu", "handle_up"]

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

func flask(ox, liquid: Array, tall: bool):
	var glass = Color("#e8f4f0")
	var cork = [Color("#8a5530"), Color("#b07d48")]
	if tall:
		pattern(ox, 0, [
			"......cC........",
			"......cC........",
			".....gggg.......",
			"......gg........",
			"......gg........",
			".....gLLg.......",
			"....gLLLLg......",
			"...gLLLLLLg.....",
			"...gLLLLLLg.....",
			"...gLlLLLLg.....",
			"...gLlLLLLg.....",
			"...gLLLLLDg.....",
			"...gDDDDDDg.....",
			"....gggggg......",
		], {"c": cork[0], "C": cork[1], "g": glass, "L": liquid[1], "l": liquid[2], "D": liquid[0]})
	else:
		pattern(ox, 0, [
			"......cC........",
			"......cC........",
			".....gggg.......",
			"......gg........",
			"......gg........",
			"....gLLLLg......",
			"...gLLLLLLg.....",
			"..gLLlLLLLLg....",
			"..gLlLLLLLLg....",
			"..gLLLLLLLLg....",
			"..gLLLLLLLDg....",
			"...gDLLLLDg.....",
			"....gDDDDg......",
			".....gggg.......",
		], {"c": cork[0], "C": cork[1], "g": glass, "L": liquid[1], "l": liquid[2], "D": liquid[0]})

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
		"item_thorn_draught":
			flask(ox, [Color("#9e2a26"), Color("#d9534f"), Color("#ff9c8f")], true)
			px(ox + 2, 8, Color("#3f7a2a")); px(ox + 11, 10, Color("#3f7a2a")); px(ox + 2, 11, Color("#3f7a2a"))
		"item_bark_brew":
			flask(ox, [Color("#a8324a"), Color("#e8556d"), Color("#ffb3c1")], false)
		"item_reach_tonic":
			flask(ox, [Color("#2f6fa8"), Color("#5bb4e8"), Color("#bfe6ff")], true)
			# A small arrow flying up and out: troops strike from farther away.
			pattern(ox + 10, 1, [
				"..AAA",
				"...AA",
				"..A.A",
				".A...",
				"A....",
			], {"A": Color("#ffd447")})
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
