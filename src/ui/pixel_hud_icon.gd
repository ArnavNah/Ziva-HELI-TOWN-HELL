extends Control
@export_enum("clock", "coin", "skull", "trophy", "star") var icon_name: String = "clock"
const PATTERNS := {
	"clock": ["...11111...", "..1111111..", ".11..1..11.", "11...1...11", "11...1...11", "11...111.11", "11.......11", ".11.....11.", "..1111111..", "...11111..."],
	"coin": ["...11111...", "..1222221..", ".122112221.", "12221122221", "12211112221", "12221122221", "12221122221", ".122112221.", "..1222221..", "...11111..."],
	"skull": ["...11111...", "..1111111..", ".111111111.", ".11..1..11.", ".11..1..11.", ".111...111.", "..1111111..", "...11111...", "...1.1.1...", "...11111..."],
	"trophy": ["1111111111", "1222222221", ".12222221.", "1.122221.1", "1..1221..1", ".1..11..1.", "....11....", "...1221...", "..122221..", ".11111111."],
	"star": ["....11....", "....11....", "1111111111", ".12222221.", "..122221..", "..122221..", ".121..121.", "111....111", "11......11", ".........."]
}

func _ready() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rows: Array = PATTERNS.get(icon_name, PATTERNS["clock"])
	var foreground := Color("ffe276")
	var accent := Color("d29b28")
	if icon_name == "skull":
		foreground = Color("e4eae4")
		accent = Color("98a29e")
	elif icon_name == "clock":
		foreground = Color("e4eae4")
		accent = Color("98a29e")
	elif icon_name == "trophy":
		foreground = Color("ffd24d")
		accent = Color("f59e0b")
	elif icon_name == "star":
		foreground = Color("5ce6c6")
		accent = Color("bdfcf0")

	for y in rows.size():
		for x in rows[y].length():
			var cell: String = rows[y][x]
			if cell == ".":
				continue
			var color := accent if cell == "2" else foreground
			draw_rect(Rect2(Vector2(x, y) * 2 + Vector2(1, 1), Vector2(2, 2)), Color("182528"))
			draw_rect(Rect2(Vector2(x, y) * 2, Vector2(2, 2)), color)
