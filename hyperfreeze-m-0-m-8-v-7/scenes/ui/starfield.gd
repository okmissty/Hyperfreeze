class_name Starfield
extends Control
## Placeholder space backdrop drawn in code, in the current café theme:
## Nebula (soft clouds), Sunburst (glowing sun and rays) or Aurora (waving
## ribbons). Set `preview_theme` to show a specific theme (shop previews).

@export var star_count: int = 170
@export var seed_value: int = 7
## Empty = follow GameState.theme_id.
@export var preview_theme: String = ""

var _stars: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in star_count:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.8, 2.6),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.6, 2.2),
		})
	for i in 5:
		_clouds.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.0, 0.7)),
			"radius": rng.randf_range(0.17, 0.35),  # fraction of the height
			"slot": i,
		})


func _process(_delta: float) -> void:
	queue_redraw()


func _theme_id() -> String:
	return preview_theme if preview_theme != "" else GameState.theme_id


func _theme() -> Dictionary:
	if preview_theme != "":
		return Upgrades.THEMES.get(preview_theme, Upgrades.THEMES["nebula"])
	return GameState.theme_colors()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var th := _theme()
	var palette: Array = th.clouds
	var star_col: Color = th.get("star", Color.WHITE)
	var k := size.y / 1080.0
	draw_rect(Rect2(Vector2.ZERO, size), th.bg)
	var sky := Art.sky(_theme_id())
	if sky:
		# Painted sky; a few code stars twinkle on top so it feels alive.
		Art.draw_cover(self, sky, Rect2(Vector2.ZERO, size))
		for i in range(0, _stars.size(), 3):
			var star: Dictionary = _stars[i]
			var tw := 0.5 + 0.5 * sin(t * float(star.speed) + float(star.phase))
			draw_circle(star.pos * size, maxf(float(star.radius) * maxf(k, 0.5), 0.6), Color(1, 1, 1, 0.7 * tw))
		return
	match String(th.get("style", "clouds")):
		"sun":
			_draw_sun(t, palette)
		"ribbons":
			_draw_ribbons(t, palette)
		_:
			_draw_clouds(palette, 0.035)
	for star: Dictionary in _stars:
		var twinkle := 0.55 + 0.45 * sin(t * float(star.speed) + float(star.phase))
		draw_circle(star.pos * size, maxf(float(star.radius) * maxf(k, 0.5), 0.6), Color(star_col, 0.85 * twinkle))


func _draw_clouds(palette: Array, alpha: float) -> void:
	for cloud: Dictionary in _clouds:
		var center: Vector2 = cloud.pos * size
		var r: float = float(cloud.radius) * size.y
		var col: Color = palette[int(cloud.slot) % palette.size()]
		for ring in 4:
			draw_circle(center, r * (1.0 - ring * 0.2), Color(col, alpha))


## Sunburst: warm haze rising from the bottom and a big sun with turning rays.
func _draw_sun(t: float, palette: Array) -> void:
	var warm: Color = palette[0]
	for band in 8:
		var h := size.y * (0.55 - band * 0.06)
		draw_rect(Rect2(0, size.y - h, size.x, h), Color(warm, 0.045))
	var c := Vector2(size.x * 0.78, size.y * 0.24)
	var r := size.y * 0.13
	var ray_col: Color = palette[1]
	for i in 16:
		var a := t * 0.05 + TAU * i / 16.0
		var inner := c + Vector2(cos(a), sin(a)) * r * 1.2
		var outer := c + Vector2(cos(a), sin(a)) * r * (3.2 if i % 2 == 0 else 2.4)
		draw_line(inner, outer, Color(ray_col, 0.10), maxf(r * 0.16, 2.0), true)
	for ring in 5:
		draw_circle(c, r * (2.2 - ring * 0.3), Color(palette[2], 0.05))
	draw_circle(c, r, Color(palette[1], 0.85))
	draw_circle(c, r * 0.82, Color(palette[1].lightened(0.25), 0.9))


## Aurora: three translucent ribbons drifting across the upper sky.
func _draw_ribbons(t: float, palette: Array) -> void:
	_draw_clouds(palette, 0.02)
	for band in 3:
		var col: Color = palette[band % palette.size()]
		var base_y := size.y * (0.16 + band * 0.11)
		var pts := PackedVector2Array()
		var steps := 48
		for i in steps + 1:
			var x := size.x * i / float(steps)
			var y := base_y + sin(x / size.x * TAU * 1.3 + t * 0.35 + band * 1.7) * size.y * 0.05 \
				+ sin(x / size.x * TAU * 3.1 - t * 0.2 + band) * size.y * 0.015
			pts.append(Vector2(x, y))
		var width := size.y * (0.07 - band * 0.012)
		for layer in 4:
			draw_polyline(pts, Color(col, 0.07), width * (1.0 - layer * 0.22), true)
		draw_polyline(pts, Color(col.lightened(0.3), 0.35), maxf(width * 0.08, 1.5), true)
