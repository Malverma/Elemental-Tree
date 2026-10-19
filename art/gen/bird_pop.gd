# Bird pop: what's left of a tapped grove bird. One row per kind (same order as
# birds.gd), eight 16x16 frames each: 0-3 a puff of feathers bursting outward
# and fading, 4-7 a single feather tumbling down (the game drops 2-3 of them).
var img: Image
const FS := 16
const KINDS := ["bluebird", "robin", "sparrow", "cardinal", "goldfinch"]
# body, wing, belly (as in birds.gd)
const PAL := {
	"bluebird": [Color("#3f7fd0"), Color("#2a5a9e"), Color("#f0a060")],
	"robin": [Color("#6b5a4a"), Color("#4f4236"), Color("#e0602a")],
	"sparrow": [Color("#a07850"), Color("#6b4a30"), Color("#e8dcc0")],
	"cardinal": [Color("#d8302a"), Color("#a82020"), Color("#e8584a")],
	"goldfinch": [Color("#f0d030"), Color("#2e2e34"), Color("#fff0a0")],
}
const WHITE := Color("#fffbe8")

# Burst frames. B body, W wing, L belly, w white flash.
const BURST := [
	[ # 0: the bird puffs up in a flash
		"................",
		"................",
		"................",
		"................",
		"................",
		"......BBB.......",
		".....BwwwB......",
		"....BwwwwwL.....",
		"....BwwwwwL.....",
		"....BwwwwwW.....",
		".....LwwwW......",
		"......WWW.......",
		"................",
		"................",
		"................",
		"................",
	],
	[ # 1: it bursts: a ring of puffs, feathers flung out
		"................",
		"........B.......",
		"...W...........L",
		"....W..BBB..LL..",
		".....BBwwwBB....",
		"....BwwwwwwwL...",
		"...Bwww...wwwL..",
		"B..Bww.....wwL..",
		"...Bww.....wwW..",
		"...Bwww...wwwW..",
		"....LwwwwwwwW...",
		".....LLwwwWW....",
		"....W..LWW..B...",
		"...W.........B..",
		"........L.......",
		"................",
	],
	[ # 2: the ring spreads and thins
		".......B........",
		"..W.............",
		"................",
		"......B.B.L.....",
		"....B.......L...",
		"...w.........L.L",
		"..B...........w.",
		"B.w............L",
		"..B...........W.",
		"...w.........W..",
		"....L.......W...",
		"......L.W.W.....",
		"................",
		"..W..........B..",
		"................",
		"........L.......",
	],
	[ # 3: last wisps
		"................",
		"................",
		"................",
		"......w...w.....",
		"................",
		"..w...........w.",
		"................",
		"................",
		"................",
		"...w..........w.",
		"................",
		".......w..w.....",
		"................",
		"................",
		"................",
		"................",
	],
]

# Feather frames: s shaft (light), B vane, W vane tip, tumbling as it falls.
const FEATHER := [
	[ # flat, quill to the left
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		".......BBW......",
		"....sssssssW....",
		"......BBBW......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	[ # tilted down to the right
		"................",
		"................",
		"................",
		"................",
		"................",
		"......B.........",
		"......sB........",
		".......sBB......",
		".....B..sBW.....",
		"......BB.sW.....",
		"........B.W.....",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	[ # edge-on, nearly upright
		"................",
		"................",
		"................",
		"................",
		"................",
		".......W........",
		"......BWB.......",
		"......BsB.......",
		"......BsB.......",
		".......s........",
		".......s........",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	[ # tilted the other way
		"................",
		"................",
		"................",
		"................",
		"................",
		".........B......",
		"........Bs......",
		"......BBs.......",
		".....WBs..B.....",
		".....Ws.BB......",
		".....W.B........",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
]

func px(x, y, c):
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func draw(ox, oy, rows: Array, cols: Dictionary):
	for y in rows.size():
		for x in rows[y].length():
			var ch = rows[y][x]
			if cols.has(ch):
				px(ox + x, oy + y, cols[ch])

# A dark rim like the birds have, only around the feathers (the burst stays soft).
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
	img = Image.create(FS * (BURST.size() + FEATHER.size()), FS * KINDS.size(), false, Image.FORMAT_RGBA8)
	for k in KINDS.size():
		var p: Array = PAL[KINDS[k]]
		var oy = k * FS
		for f in BURST.size():
			draw(f * FS, oy, BURST[f], {"B": p[0], "W": p[1], "L": p[2], "w": WHITE})
		for f in FEATHER.size():
			var ox = (BURST.size() + f) * FS
			draw(ox, oy, FEATHER[f], {"B": p[0], "W": p[1], "s": p[2].lightened(0.35)})
			outline(Rect2i(ox, oy, FS, FS))
	return img
