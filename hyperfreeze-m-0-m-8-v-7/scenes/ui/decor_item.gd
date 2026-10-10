class_name DecorItem
extends Control
## One piece of lobby decor, drawn to fit this control. Uses Ty's art from
## assets/art/decor/<id>.png when it exists, otherwise a code-drawn placeholder.

const DIR := "res://assets/art/decor/"
const INK := Color("1a1238")

var decor_id := "":
	set(v):
		decor_id = v
		queue_redraw()
## Placeholders gently animate (jellies bob, lamp blobs drift, orb spins).
var animate := true
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	if decor_id == "":
		return
	var tex := Art.load_tex(DIR + decor_id + ".png")
	if tex:
		Art.draw_fit(self, tex, Rect2(Vector2.ZERO, size))
		return
	# Placeholders are drawn on a 100 x 100 canvas, scaled to fit.
	var s := minf(size.x, size.y) / 100.0
	draw_set_transform(Vector2((size.x - 100 * s) / 2, size.y - 100 * s), 0.0, Vector2(s, s))
	match decor_id:
		"decor_nebula_poster": _poster(Color("6b3fa0"), Color("ff7eb6"), false)
		"decor_rocket_poster": _poster(Color("1d4e89"), Color("ffd95a"), true)
		"decor_moon_fern": _plant(Color("4caf7a"), false)
		"decor_crystal_cactus": _plant(Color("8fe3ff"), true)
		"decor_jelly_tank": _tank()
		"decor_arcade": _arcade()
		"decor_jukebox": _jukebox()
		"decor_lava_lamp": _lamp()
		"decor_golden_cone": _trophy()
		"decor_critic_plaque": _plaque()
		"decor_captain_statue": _statue()
		"decor_disco_orb": _orb()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _box(r: Rect2, fill: Color, radius := 6) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.border_color = INK
	sb.set_border_width_all(3)
	draw_style_box(sb, r)


func _poster(bg: Color, accent: Color, rocket: bool) -> void:
	_box(Rect2(14, 4, 72, 92), Color("f4f1ff"), 4)
	draw_rect(Rect2(20, 10, 60, 80), bg)
	if rocket:
		draw_colored_polygon(PackedVector2Array([Vector2(50, 18), Vector2(60, 40), Vector2(60, 66), Vector2(40, 66), Vector2(40, 40)]), Color("f4f1ff"))
		draw_circle(Vector2(50, 44), 6, Color("3ee6f0"))
		draw_colored_polygon(PackedVector2Array([Vector2(44, 66), Vector2(56, 66), Vector2(50, 80 + sin(_t * 12) * 3)]), accent)
	else:
		for i in 3:
			draw_circle(Vector2(36 + i * 14, 40 + sin(i * 2.0) * 10), 16 - i * 3, Color(accent, 0.55))
		draw_circle(Vector2(58, 62), 8, Color("ffd95a"))
		draw_arc(Vector2(58, 62), 13, 0.3, 2.8, 12, Color("f4f1ff"), 2.0)


func _plant(leaf: Color, crystal: bool) -> void:
	_box(Rect2(30, 70, 40, 28), Color("b06a3b"), 6)
	if crystal:
		for i in 3:
			var x := 38.0 + i * 12
			var h := 44.0 + (i % 2) * 14
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 72), Vector2(x, 72 - h), Vector2(x + 6, 72)]), leaf)
			draw_line(Vector2(x, 72 - h), Vector2(x, 72), Color(1, 1, 1, 0.6), 2.0)
	else:
		for i in 5:
			var a := -2.4 + i * 0.45 + sin(_t * 1.5 + i) * 0.05
			var tip := Vector2(50, 72) + Vector2(cos(a), sin(a)) * 46
			draw_line(Vector2(50, 72), tip, leaf, 9.0, true)
			draw_circle(tip, 6, leaf.lightened(0.2))


func _tank() -> void:
	_box(Rect2(8, 22, 84, 66), Color(0.24, 0.9, 0.94, 0.35), 8)
	_box(Rect2(4, 86, 92, 12), Color("2b2850"), 4)
	for i in 3:
		var p := Vector2(26 + i * 24, 50 + sin(_t * 1.6 + i * 2.0) * 10)
		draw_circle(p, 9, Color("ff7eb6").lerp(Color("c39bff"), i / 2.0))
		for k in 3:
			draw_line(p + Vector2(-5 + k * 5, 6), p + Vector2(-5 + k * 5 + sin(_t * 3 + k) * 3, 20), Color("ff7eb6", 0.7), 2.0)


func _arcade() -> void:
	_box(Rect2(22, 6, 56, 92), Color("6b3fa0"), 6)
	draw_rect(Rect2(30, 16, 40, 30), Color("0b0d2a"))
	draw_circle(Vector2(38 + fmod(_t * 20, 24), 30), 3, Color("3ee6f0"))
	draw_circle(Vector2(60, 26), 4, Color("ff7eb6"))
	draw_rect(Rect2(28, 54, 44, 12), Color("2b2850"))
	draw_circle(Vector2(38, 60), 4, Color("ff5c7a"))
	draw_circle(Vector2(56, 60), 3, Color("ffd95a"))
	draw_circle(Vector2(64, 60), 3, Color("3ee6f0"))


func _jukebox() -> void:
	_box(Rect2(18, 18, 64, 80), Color("c2185b"), 30)
	draw_rect(Rect2(28, 40, 44, 26), Color("ffd95a"))
	for i in 5:
		var h := 6.0 + absf(sin(_t * 6 + i)) * 14
		draw_rect(Rect2(31 + i * 8, 64 - h, 5, h), Color("6b3fa0"))
	draw_circle(Vector2(50, 80), 6, Color("f4f1ff"))
	draw_arc(Vector2(50, 46), 26, PI, TAU, 20, Color("3ee6f0"), 3.0)


func _lamp() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(36, 96), Vector2(64, 96), Vector2(58, 78), Vector2(42, 78)]), Color("2b2850"))
	draw_colored_polygon(PackedVector2Array([Vector2(42, 78), Vector2(58, 78), Vector2(64, 30), Vector2(36, 30)]), Color(1.0, 0.5, 0.75, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(38, 30), Vector2(62, 30), Vector2(56, 16), Vector2(44, 16)]), Color("2b2850"))
	for i in 3:
		draw_circle(Vector2(50 + sin(_t + i) * 5, 70 - fmod(_t * 8 + i * 14, 36)), 6 - i, Color("ffd95a"))


func _trophy() -> void:
	draw_rect(Rect2(34, 84, 32, 12), Color("8a6d1e"))
	draw_rect(Rect2(46, 66, 8, 20), Color("ffd95a"))
	draw_colored_polygon(PackedVector2Array([Vector2(36, 34), Vector2(64, 34), Vector2(50, 68)]), Color("ffd95a"))
	draw_circle(Vector2(50, 28), 15, Color("ffe9a8"))
	draw_circle(Vector2(44, 22), 4, Color(1, 1, 1, 0.8))


func _plaque() -> void:
	_box(Rect2(10, 14, 80, 72), Color("8a5a2b"), 6)
	draw_rect(Rect2(20, 24, 60, 52), Color("fff8e1"))
	for i in 5:
		var c := Vector2(28 + i * 11, 40)
		draw_colored_polygon(_star_points(c, 5, 2.2), Color("ffd95a"))
	for i in 3:
		draw_line(Vector2(26, 54 + i * 7), Vector2(74, 54 + i * 7), Color("9e9ac8"), 2.0)


func _statue() -> void:
	draw_rect(Rect2(28, 82, 44, 16), Color("6d4c41"))
	draw_circle(Vector2(50, 40), 12, Color("c58a4a"))
	draw_circle(Vector2(50, 40), 16, Color(1, 1, 1, 0.25))
	draw_rect(Rect2(40, 52, 20, 30), Color("c58a4a"))
	draw_line(Vector2(60, 58), Vector2(74, 40), Color("c58a4a"), 6.0)
	draw_colored_polygon(_star_points(Vector2(76, 36), 7, 3.0), Color("ffd95a"))


func _orb() -> void:
	draw_line(Vector2(50, 0), Vector2(50, 24), INK, 3.0)
	var c := Vector2(50, 50)
	draw_circle(c, 26, Color("c7cbe0"))
	for i in 8:
		var a := _t * 1.5 + i * TAU / 8
		draw_circle(c + Vector2(cos(a) * 16, sin(a * 2) * 12), 4, Color(1, 1, 1, 0.7))
	for i in 5:
		var a2 := _t * 0.8 + i * TAU / 5
		draw_colored_polygon(_star_points(c + Vector2(cos(a2), sin(a2)) * 44, 4, 1.8), Color("ff7eb6", 0.8))


static func _star_points(c: Vector2, r: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else inner))
	return pts
