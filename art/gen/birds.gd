# Grove birds: one row per kind, six 12x10 frames each, facing right:
# 0-2 wing flap (up, level, down), 3 perched, 4 pecking, 5 hop (legs tucked).
var img: Image
const FW := 12
const FH := 10
const KINDS := ["bluebird", "robin", "sparrow", "cardinal", "goldfinch"]
# body, wing, belly, beak, eye
const PAL := {
	"bluebird": [Color("#3f7fd0"), Color("#2a5a9e"), Color("#f0a060"), Color("#f0c040"), Color("#101018")],
	"robin": [Color("#6b5a4a"), Color("#4f4236"), Color("#e0602a"), Color("#f0c040"), Color("#101018")],
	"sparrow": [Color("#a07850"), Color("#6b4a30"), Color("#e8dcc0"), Color("#3a2a20"), Color("#101018")],
	"cardinal": [Color("#d8302a"), Color("#a82020"), Color("#e8584a"), Color("#f0a020"), Color("#101018")],
	"goldfinch": [Color("#f0d030"), Color("#2e2e34"), Color("#fff0a0"), Color("#e0a060"), Color("#101018")],
}
const FRAMES := [
	[ # wings up
		"...W......",
		"...WW.....",
		"...WWW.BB.",
		"..BBBBBEBK",
		"BBBBBBLL..",
		"...LLLL...",
		"..........",
		"..........",
	],
	[ # wings level
		"..........",
		"..........",
		".......BB.",
		"..BBBBBEBK",
		"BWWWWWLL..",
		"..WWWLL...",
		"..........",
		"..........",
	],
	[ # wings down
		"..........",
		"..........",
		".......BB.",
		"..BBBBBEBK",
		"BBBBBBLL..",
		"...WWWL...",
		"...WWW....",
		"....W.....",
	],
	[ # perched
		"..........",
		"......BB..",
		".....BEBK.",
		"....BBBB..",
		".BBWWWLL..",
		"BBWWWWLL..",
		"..WWWLL...",
		"....k.k...",
	],
	[ # pecking
		"..........",
		"..........",
		"..........",
		"....BBB...",
		".BBWWWBB..",
		"BBWWWWLBE.",
		"..WWWLL.BK",
		"....k.k...",
	],
	[ # hop: perched, raised a pixel, legs tucked
		"......BB..",
		".....BEBK.",
		"....BBBB..",
		".BBWWWLL..",
		"BBWWWWLL..",
		"..WWWLL...",
		"..........",
		"..........",
	],
]

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func outline(r: Rect2i):
	var src = img.get_region(r)
	for y in r.size.y:
		for x in r.size.x:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < r.size.x and q.y < r.size.y and src.get_pixel(q.x, q.y).a > 0.5:
					var c = src.get_pixel(q.x, q.y).darkened(0.72)
					c.a = 1.0
					img.set_pixel(r.position.x + x, r.position.y + y, c)
					break

func run(api, image, project, params):
	img = Image.create(FW * FRAMES.size(), FH * KINDS.size(), false, Image.FORMAT_RGBA8)
	for k in KINDS.size():
		var p: Array = PAL[KINDS[k]]
		var cols = {"B": p[0], "W": p[1], "L": p[2], "K": p[3], "E": p[4], "k": p[3].darkened(0.3)}
		for f in FRAMES.size():
			var rows: Array = FRAMES[f]
			for y in rows.size():
				for x in rows[y].length():
					var ch = rows[y][x]
					if cols.has(ch):
						px(f * FW + 1 + x, k * FH + 1 + y, cols[ch])
			# a highlight on the head catches the light
			outline(Rect2i(f * FW, k * FH, FW, FH))
	return img
