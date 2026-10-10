class_name CupPainter
extends RefCounted
## Draws a CupState into any CanvasItem at any size: the tiny icons on
## tickets and the big cups at each station share this code.
## `geometry()` is public so stations can hit-test the dome and topper slots.

const GLASS := Color(1, 1, 1, 0.16)
const GLASS_EDGE := Color(1, 1, 1, 0.35)
const OUTLINE := Color("2b2850")
const CREAM := Color("f7f3ff")
const FILL_LINE := Color("ffd95a")
const SIZE_SCALE: Array[float] = [0.82, 0.91, 1.0]
## Line widths and dot sizes are authored for a 120 px tall rect.
const REFERENCE_HEIGHT := 120.0


## Cup shape inside `rect` for a cup size. Keys:
## k (line scale), s (size scale), cx, top_y, bottom_y, cup_h, top_w, bottom_w, dome_r, dome_h.
## fit_cup = size the glass to the rect with no room above it for cream.
static func geometry(rect: Rect2, cup_size: int, fit_cup: bool = false) -> Dictionary:
	var art := CupArt.get_art()
	if art:
		return _art_geometry(rect, cup_size, art, fit_cup)
	var s: float = SIZE_SCALE[clampi(cup_size, 0, 2)]
	var k := rect.size.y / REFERENCE_HEIGHT
	var cup_h := rect.size.y * 0.56 * s
	var top_w := minf(rect.size.x * 0.7 * s, cup_h * 1.1)
	var bottom_y := rect.end.y - 4.0 * k
	return {
		"k": k,
		"s": s,
		"cx": rect.position.x + rect.size.x * 0.5,
		"top_y": bottom_y - cup_h,
		"bottom_y": bottom_y,
		"cup_h": cup_h,
		"top_w": top_w,
		"bottom_w": top_w * 0.68,
		"dome_r": top_w * 0.5,
		"dome_h": top_w * 0.45,
	}


## Height of the cream dome at horizontal offset `dx` from the centre.
static func dome_height_at(geo: Dictionary, dx: float) -> float:
	if geo.get("art", false):
		var cr: Rect2 = geo.cream_rect
		var t := (float(geo.cx) + dx - cr.position.x) / cr.size.x
		var p := CupArt.get_art().profile_at(t)
		return maxf(0.0, float(geo.top_y) - (cr.end.y - p * cr.size.y))
	var r: float = geo.dome_r
	var t := clampf(dx / r, -1.0, 1.0)
	return float(geo.dome_h) * sqrt(1.0 - t * t)


## Where topper slot `i` sits (back-left, back-right, front-left, front-right).
## Toppers rest on the cream when the dome is mostly covered, otherwise on the rim.
static func topper_spot(geo: Dictionary, i: int, on_dome: bool) -> Vector2:
	var cx: float = geo.cx
	var r: float = geo.dome_r
	var xs: Array[float] = [-0.36, 0.36, -0.62, 0.62]
	if geo.get("art", false):
		var dx := xs[i] * r * 0.9
		var surface := dome_height_at(geo, dx) * (0.86 if i < 2 else 0.55)
		var h := surface if on_dome else 6.0 * float(geo.k)
		return Vector2(cx + dx, float(geo.top_y) - h)
	var lift: float = float(geo.dome_h) if on_dome else 6.0 * float(geo.k)
	var ys: Array[float] = [0.86, 0.86, 0.3, 0.3]
	return Vector2(cx + xs[i] * r, float(geo.top_y) - lift * ys[i])


static func topper_radius(geo: Dictionary, i: int) -> float:
	return (6.0 if i < 2 else 7.5) * float(geo.k) * float(geo.s)


## Options: fill_line (bool), slot_hints (bool), highlight_slot (int), empty_label (String).
static func draw_cup(ci: CanvasItem, rect: Rect2, cup: CupState, options: Dictionary = {}) -> void:
	if cup == null or cup.size < 0:
		return
	var geo := geometry(rect, cup.size, options.get("fit_cup", false))
	if geo.get("art", false):
		_draw_art_cup(ci, cup, geo, options)
		return
	var k: float = geo.k
	var s: float = geo.s
	var cx: float = geo.cx
	var top_y: float = geo.top_y
	var bottom_y: float = geo.bottom_y
	var top_w: float = geo.top_w
	var bottom_w: float = geo.bottom_w
	var dome_r: float = geo.dome_r

	var tl := Vector2(cx - top_w / 2, top_y)
	var tr := Vector2(cx + top_w / 2, top_y)
	var br := Vector2(cx + bottom_w / 2, bottom_y)
	var bl := Vector2(cx - bottom_w / 2, bottom_y)

	# Glass
	ci.draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), GLASS)

	# Base liquid up to the fill level
	var fill := clampf(cup.fill_amount, 0.0, 1.0)
	var base := _ingredient(cup.base_id)
	if fill > 0.0 and base:
		var fy := lerpf(bottom_y, top_y, fill)
		var fhalf := lerpf(bottom_w, top_w, fill) / 2
		var col := base.color
		if cup.zapped and cup.zap_level == Order.ZapLevel.SUPERNOVA:
			col = col.lightened(0.08)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - fhalf, fy), Vector2(cx + fhalf, fy), br, bl]), col)
		if cup.mixed_bases:
			ci.draw_line(Vector2(cx - fhalf * 0.8, lerpf(bottom_y, fy, 0.5)), Vector2(cx + fhalf * 0.8, lerpf(bottom_y, fy, 0.5)), Color(1, 1, 1, 0.5), 3.0 * k)

	# Mix-ins: big chunks settled at the bottom until zapped, then smaller and spread out
	if fill > 0.0:
		for mix_id: StringName in cup.mixin_ids:
			var ing := _ingredient(mix_id)
			if ing == null:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(mix_id)
			var count := 4
			var radius := 4.6
			var lo := 0.06
			var hi := minf(fill * 0.45, fill - 0.04)
			if cup.zapped:
				match cup.zap_level:
					Order.ZapLevel.ASTEROID:
						count = 6; radius = 4.0
					Order.ZapLevel.COMET:
						count = 9; radius = 3.0
					_:
						count = 14; radius = 1.8
				lo = 0.1
				hi = fill - 0.06
			for i in count:
				var fy2 := rng.randf_range(lo, maxf(hi, lo + 0.01))
				var y := lerpf(bottom_y, top_y, fy2)
				var half := lerpf(bottom_w, top_w, fy2) / 2 - 5.0 * k
				ci.draw_circle(Vector2(cx + rng.randf_range(-half, half), y), radius * k * s, ing.color)

	# Fill line (Build Station)
	if options.get("fill_line", false):
		var ly := lerpf(bottom_y, top_y, CupState.TARGET_FILL)
		var lhalf := lerpf(bottom_w, top_w, CupState.TARGET_FILL) / 2
		ci.draw_dashed_line(Vector2(cx - lhalf - 10 * k, ly), Vector2(cx + lhalf + 10 * k, ly), FILL_LINE, 2.0 * k, 8.0 * k)

	ci.draw_polyline(PackedVector2Array([tl, bl, br, tr]), OUTLINE, 2.5 * k, true)
	ci.draw_line(tl + Vector2(4 * k, 6 * k), bl + Vector2(5 * k, -6 * k), GLASS_EDGE, 2.0 * k, true)

	# Cream, column by column (partial sweeps show as partial domes)
	var coverage := cup.cream_coverage()
	var col_w := dome_r * 2.0 / CupState.CREAM_COLUMNS
	for i in CupState.CREAM_COLUMNS:
		if cup.cream_cols[i] == 0:
			continue
		var x0 := cx - dome_r + i * col_w
		var pts := PackedVector2Array([Vector2(x0, top_y)])
		for j in 4:
			var x := x0 + col_w * j / 3.0
			pts.append(Vector2(x, top_y - dome_height_at(geo, x - cx)))
		pts.append(Vector2(x0 + col_w, top_y))
		ci.draw_colored_polygon(pts, CREAM)
		var edge := PackedVector2Array()
		for j in range(1, 5):
			edge.append(pts[j])
		ci.draw_polyline(edge, OUTLINE, 1.5 * k, true)
	var on_dome := coverage >= 0.5

	# Sauce drizzle
	var sauce := _ingredient(cup.sauce_id)
	if sauce:
		var drizzle := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			var x := cx - dome_r * 0.8 + f * dome_r * 1.6
			var base_y := top_y - (dome_height_at(geo, x - cx) * 0.55 if on_dome else 2.0 * k)
			drizzle.append(Vector2(x, base_y + sin(f * TAU * 1.5) * 4.0 * k * s))
		ci.draw_polyline(drizzle, sauce.color, 4.0 * k * s, true)

	# Sprinkles
	var sprinkles := _ingredient(cup.sprinkle_id)
	if sprinkles:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = hash(cup.sprinkle_id) + 99
		for i in 12:
			var dx := rng2.randf_range(-0.85, 0.85) * dome_r
			var h := dome_height_at(geo, dx) if on_dome else 4.0 * k
			var p := Vector2(cx + dx, top_y - rng2.randf_range(0.2, 0.9) * h)
			ci.draw_circle(p, 1.8 * k * s, sprinkles.color.darkened(0.15) if i % 2 == 0 else Color.WHITE)

	# Toppers + optional slot hints
	var hints: bool = options.get("slot_hints", false)
	var highlight: int = options.get("highlight_slot", -1)
	for i in Order.TOPPER_SLOTS:
		var spot := topper_spot(geo, i, on_dome)
		var r := topper_radius(geo, i)
		var topper := _ingredient(cup.toppers[i])
		if topper:
			ci.draw_circle(spot, r, topper.color)
			ci.draw_arc(spot, r, 0, TAU, 20, OUTLINE, 1.5 * k, true)
			ci.draw_circle(spot + Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.6))
		if hints:
			var hint_col := Color("3ee6f0") if i == highlight else Color(1, 1, 1, 0.45)
			ci.draw_arc(spot, r * 1.3, 0, TAU, 24, hint_col, (3.0 if i == highlight else 1.5) + k * 0.3, true)


# --- Drawn art ------------------------------------------------------------------

static func _art_geometry(rect: Rect2, cup_size: int, art: CupArt, fit_cup: bool = false) -> Dictionary:
	var s: float = SIZE_SCALE[clampi(cup_size, 0, 2)]
	var k := rect.size.y / REFERENCE_HEIGHT
	var cream_w := art.size.x * CupArt.CREAM_WIDTH
	var cream_h := cream_w * art.cream.get_height() / float(art.cream.get_width())
	var cream_bottom := art.bowl_top + cream_h * CupArt.CREAM_SINK
	var stack_top := 0.0 if fit_cup else minf(0.0, cream_bottom - cream_h)
	var stack_h := art.size.y - stack_top
	var stack_w := art.size.x if fit_cup else maxf(cream_w, art.size.x)
	var sc := minf(rect.size.y * 0.98 / stack_h, rect.size.x * 0.98 / stack_w) * s
	var cx := rect.position.x + rect.size.x * 0.5
	var cup_rect := Rect2(Vector2(cx - art.size.x * sc * 0.5, rect.end.y - art.size.y * sc - 1.0 * k), art.size * sc)
	var cream_rect := Rect2(Vector2(cx - cream_w * sc * 0.5, cup_rect.position.y + (cream_bottom - cream_h) * sc), Vector2(cream_w, cream_h) * sc)
	var top_y := cup_rect.position.y + art.bowl_top * sc
	var bottom_y := cup_rect.position.y + art.bowl_bottom * sc
	var top_span := art.span_at(art.bowl_top)
	var bottom_span := art.span_at(art.bowl_bottom)
	var peak := 0.0
	for p in art.cream_profile:
		peak = maxf(peak, p)
	return {
		"art": true,
		"k": k,
		"s": s,
		"scale": sc,
		"cx": cx,
		"top_y": top_y,
		"bottom_y": bottom_y,
		"cup_h": bottom_y - top_y,
		"top_w": (top_span.y - top_span.x) * sc,
		"bottom_w": (bottom_span.y - bottom_span.x) * sc,
		"dome_r": cream_rect.size.x * 0.5,
		"dome_h": maxf(top_y - (cream_rect.end.y - peak * cream_rect.size.y), 1.0),
		"cup_rect": cup_rect,
		"cream_rect": cream_rect,
	}


## Screen-space left/right edges of the bowl's inside at screen height y.
static func _art_span(art: CupArt, geo: Dictionary, y: float) -> Vector2:
	var cr: Rect2 = geo.cup_rect
	var sc: float = geo.scale
	var sp := art.span_at((y - cr.position.y) / sc)
	return Vector2(cr.position.x + sp.x * sc, cr.position.x + sp.y * sc)


static func _draw_art_cup(ci: CanvasItem, cup: CupState, geo: Dictionary, options: Dictionary) -> void:
	var art := CupArt.get_art()
	var k: float = geo.k
	var s: float = geo.s
	var sc: float = geo.scale
	var cx: float = geo.cx
	var top_y: float = geo.top_y
	var bottom_y: float = geo.bottom_y
	var cup_rect: Rect2 = geo.cup_rect
	var cream_rect: Rect2 = geo.cream_rect
	var origin := cup_rect.position

	ci.draw_texture_rect(art.back, cup_rect, false)

	# Ice cream: the white swirl texture tinted to the base flavour.
	var fill := clampf(cup.fill_amount, 0.0, 1.0)
	var fill_y := lerpf(bottom_y, top_y, fill)
	var base := _ingredient(cup.base_id)
	if fill > 0.0 and base:
		var col := base.color
		if cup.zapped and cup.zap_level == Order.ZapLevel.SUPERNOVA:
			col = col.lightened(0.08)
		var poly := art.fill_polygon(fill)
		if poly.size() >= 3:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for p in poly:
				pts.append(origin + p * sc)
				uvs.append(art.fill_uv(p))
			if not Geometry2D.triangulate_polygon(pts).is_empty():
				ci.draw_polygon(pts, PackedColorArray([col]), uvs, art.fill)
		if cup.mixed_bases:
			var my := lerpf(bottom_y, fill_y, 0.5)
			var sp := _art_span(art, geo, my)
			ci.draw_line(Vector2(sp.x + 6 * k, my), Vector2(sp.y - 6 * k, my), Color(1, 1, 1, 0.5), 3.0 * k)

	# Mix-ins: big chunks settled at the bottom until zapped, then smaller and spread out
	if fill > 0.0:
		for mix_id: StringName in cup.mixin_ids:
			var ing := _ingredient(mix_id)
			if ing == null:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(mix_id)
			var count := 4
			var radius := 4.6
			var lo := 0.06
			var hi := minf(fill * 0.45, fill - 0.04)
			if cup.zapped:
				match cup.zap_level:
					Order.ZapLevel.ASTEROID:
						count = 6; radius = 4.0
					Order.ZapLevel.COMET:
						count = 9; radius = 3.0
					_:
						count = 14; radius = 1.8
				lo = 0.1
				hi = fill - 0.06
			var d := radius * k * s * 2.3
			for i in count:
				var fy2 := rng.randf_range(lo, maxf(hi, lo + 0.01))
				var y := lerpf(bottom_y, top_y, fy2)
				var sp := _art_span(art, geo, y)
				var x0 := sp.x + d * 0.5
				var x1 := maxf(sp.y - d * 0.5, x0)
				var pos := Vector2(rng.randf_range(x0, x1), y)
				var angle := rng.randf_range(-0.6, 0.6)
				var tex := Art.ingredient(mix_id, "piece_%02d" % (i % 3 + 1))
				if tex:
					ci.draw_set_transform(pos, angle, Vector2.ONE)
					Art.draw_fit(ci, tex, Rect2(Vector2(-d, -d) * 0.5, Vector2(d, d)))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					ci.draw_circle(pos, radius * k * s, ing.color)

	# Fill line (Build Station)
	if options.get("fill_line", false):
		var ly := lerpf(bottom_y, top_y, CupState.TARGET_FILL)
		var lsp := _art_span(art, geo, ly)
		ci.draw_dashed_line(Vector2(lsp.x - 12 * k, ly), Vector2(lsp.y + 12 * k, ly), FILL_LINE, 2.0 * k, 8.0 * k)

	ci.draw_texture_rect(art.front, cup_rect, false)

	# Cream, column by column (partial sweeps show as partial domes)
	var coverage := cup.cream_coverage()
	var tw := art.cream.get_width()
	var th := art.cream.get_height()
	for i in CupState.CREAM_COLUMNS:
		if cup.cream_cols[i] == 0:
			continue
		var f0 := float(i) / CupState.CREAM_COLUMNS
		var f1 := float(i + 1) / CupState.CREAM_COLUMNS
		var src := Rect2(f0 * tw, 0, (f1 - f0) * tw, th)
		var dst := Rect2(cream_rect.position.x + f0 * cream_rect.size.x, cream_rect.position.y, (f1 - f0) * cream_rect.size.x + 0.5, cream_rect.size.y)
		ci.draw_texture_rect_region(art.cream, dst, src)
	var on_dome := coverage >= 0.5

	# Sauce drizzle: across the cream, or across the ice cream without it
	var sauce := _ingredient(cup.sauce_id)
	if sauce:
		var drizzle := Art.ingredient(cup.sauce_id, "drizzle")
		var level := 0.0
		var x0 := 0.0
		var x1 := 0.0
		var y := fill_y
		if on_dome:
			level = float(geo.dome_h) * 0.4
			y = top_y - level
			x0 = INF
			x1 = -INF
			var r: float = geo.dome_r
			for j in 49:
				var dx := lerpf(-r, r, j / 48.0)
				if dome_height_at(geo, dx) >= level:
					x0 = minf(x0, cx + dx)
					x1 = maxf(x1, cx + dx)
			if x0 > x1:
				x0 = cx - r * 0.5
				x1 = cx + r * 0.5
		else:
			var sp := _art_span(art, geo, fill_y)
			x0 = sp.x
			x1 = sp.y
		var w := (x1 - x0) * 1.08
		if drizzle:
			var h := w * drizzle.get_height() / float(drizzle.get_width())
			ci.draw_texture_rect(drizzle, Rect2(Vector2((x0 + x1) * 0.5 - w * 0.5, y - h * 0.5), Vector2(w, h)), false)
		else:
			var line := PackedVector2Array()
			for j in 13:
				var f := j / 12.0
				line.append(Vector2(lerpf(x0, x1, f), y + sin(f * TAU * 1.5) * 4.0 * k * s))
			ci.draw_polyline(line, sauce.color, 4.0 * k * s, true)

	# Sprinkles: clipped to the cream's outline, or a band on the ice cream
	var sprinkles := _ingredient(cup.sprinkle_id)
	if sprinkles:
		var scatter := Art.ingredient(cup.sprinkle_id, "scatter")
		if scatter and on_dome:
			var top_pts := PackedVector2Array()
			for j in 33:
				var t := j / 32.0
				var x := cream_rect.position.x + t * cream_rect.size.x
				var sy := cream_rect.end.y - art.profile_at(t) * cream_rect.size.y
				if sy < top_y - 2.0:
					top_pts.append(Vector2(x, sy))
			if top_pts.size() >= 2:
				var pts := top_pts.duplicate()
				pts.append(Vector2(top_pts[top_pts.size() - 1].x, top_y))
				pts.append(Vector2(top_pts[0].x, top_y))
				var uvs := PackedVector2Array()
				var span := maxf(top_y - cream_rect.position.y, 1.0)
				for p in pts:
					uvs.append(Vector2((p.x - cream_rect.position.x) / cream_rect.size.x, (p.y - cream_rect.position.y) / span))
				if not Geometry2D.triangulate_polygon(pts).is_empty():
					ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, scatter)
		elif scatter:
			var sp := _art_span(art, geo, fill_y)
			var w := (sp.y - sp.x) * 0.9
			var h := w * 0.32
			ci.draw_texture_rect(scatter, Rect2(Vector2(cx - w * 0.5, fill_y - h * 0.6), Vector2(w, h)), false)
		else:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = hash(cup.sprinkle_id) + 99
			var r: float = geo.dome_r
			for i in 12:
				var dx := rng2.randf_range(-0.7, 0.7) * r
				var hgt := dome_height_at(geo, dx) if on_dome else 4.0 * k
				ci.draw_circle(Vector2(cx + dx, top_y - rng2.randf_range(0.2, 0.9) * hgt), 1.8 * k * s, sprinkles.color.darkened(0.15) if i % 2 == 0 else Color.WHITE)

	# Slot rings (under the toppers), then toppers
	var hints: bool = options.get("slot_hints", false)
	var highlight: int = options.get("highlight_slot", -1)
	if hints:
		for i in Order.TOPPER_SLOTS:
			_draw_slot_hint(ci, topper_spot(geo, i, on_dome), topper_radius(geo, i), i == highlight, k)
	for i in Order.TOPPER_SLOTS:
		var spot := topper_spot(geo, i, on_dome)
		var r := topper_radius(geo, i)
		var topper := _ingredient(cup.toppers[i])
		if topper:
			var tex := Art.ingredient(cup.toppers[i], "topper")
			if tex == null:
				tex = Art.ingredient(cup.toppers[i])
			if tex:
				var d := r * 2.1
				Art.draw_fit(ci, tex, Rect2(spot - Vector2(d, d) * 0.5, Vector2(d, d)))
			else:
				ci.draw_circle(spot, r, topper.color)
				ci.draw_arc(spot, r, 0, TAU, 20, OUTLINE, 1.5 * k, true)


## A topper slot marker: Ty's ring art if drawn, otherwise a simple circle.
static func _draw_slot_hint(ci: CanvasItem, spot: Vector2, r: float, lit: bool, k: float) -> void:
	var ring := Art.station("st_top_slot_hover" if lit else "st_top_slot")
	if ring:
		var w := r * (3.4 if lit else 2.6)
		var h := w * ring.get_height() / float(ring.get_width())
		ci.draw_texture_rect(ring, Rect2(spot + Vector2(-w * 0.5, r * 0.55 - h * 0.5), Vector2(w, h)), false, Color(1, 1, 1, 0.95 if lit else 0.75))
		return
	var hint_col := Color("3ee6f0") if lit else Color(1, 1, 1, 0.45)
	ci.draw_arc(spot, r * 1.3, 0, TAU, 24, hint_col, (3.0 if lit else 1.5) + k * 0.3, true)


static func _ingredient(id: StringName) -> IngredientData:
	if id == &"":
		return null
	return GameState.catalog.ingredient(id)
