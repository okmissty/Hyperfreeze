class_name Customer
extends Control
## An alien customer, drawn in code from their CustomerData (placeholder art).
## The Order Station tells them where to walk; they track their own patience.

signal reached_destination(customer: Customer)

enum State { ARRIVING, WAITING_TO_ORDER, ORDERING, WAITING_FOR_FOOD, SERVING, SERVED, LEAVING }

const BOX_SIZE := Vector2(220, 320)
## The point inside the box that touches the floor.
const FEET := Vector2(110, 300)
const WALK_SPEED := 460.0
const OUTLINE := Color("1a1238")
const PUPIL := Color("1a1238")

var data: CustomerData
var state: State = State.ARRIVING
var order: Order
## DayManager.time_elapsed when they walked in.
var arrived_at := 0.0
## Score they gave their treat (0–100), or -1 before being served.
var reaction_score := -1
var reaction_text := ""

var _wait_started := 0.0
var _patience_window := 40.0
var _walking := false
var _time := 0.0
var _blink_left := 0.0
var _next_blink := 2.0
var _tween: Tween
var _bubble_icon: CupIcon


func setup(customer_data: CustomerData) -> void:
	data = customer_data


func _ready() -> void:
	size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time = randf() * 10.0
	_next_blink = randf_range(1.5, 4.0)
	_bubble_icon = CupIcon.new()
	_bubble_icon.size = Vector2(110, 116)
	_bubble_icon.position = Vector2(FEET.x - 55, _head_top() - 152)
	_bubble_icon.visible = false
	add_child(_bubble_icon)


# --- Movement -----------------------------------------------------------------

func place_at(feet: Vector2) -> void:
	position = feet - FEET


func feet_position() -> Vector2:
	return position + FEET


func walk_to(feet: Vector2) -> void:
	if _tween:
		_tween.kill()
	var target := feet - FEET
	var duration := maxf(position.distance_to(target) / WALK_SPEED, 0.15)
	_walking = true
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(func() -> void:
		_walking = false
		reached_destination.emit(self))


# --- Patience -----------------------------------------------------------------

func begin_waiting(new_state: State, window_seconds: float) -> void:
	state = new_state
	_wait_started = DayManager.time_elapsed
	_patience_window = maxf(window_seconds, 1.0)


## 1 = perfectly happy, 0 = out of patience (they never leave; the wait grade drops).
func patience_ratio() -> float:
	return clampf(1.0 - (DayManager.time_elapsed - _wait_started) / _patience_window, 0.0, 1.0)


func show_order_bubble(favorite: Order) -> void:
	state = State.ORDERING
	_bubble_icon.order = favorite
	_bubble_icon.visible = true


func hide_order_bubble() -> void:
	_bubble_icon.visible = false


## Shows how they liked their treat (face + speech bubble).
func react(score: int, text: String) -> void:
	state = State.SERVED
	reaction_score = score
	reaction_text = text


# --- Drawing ------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _blink_left > 0.0:
		_blink_left -= delta
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = 0.12
			_next_blink = randf_range(2.0, 5.0)
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var bob := -absf(sin(_time * 11.0)) * 10.0 if _walking else sin(_time * 2.0) * 3.0
	_draw_ellipse(Vector2(FEET.x, FEET.y), Vector2(70, 12), Color(0, 0, 0, 0.28))
	match data.species:
		CustomerData.Species.BLORB: _draw_blorb(bob)
		CustomerData.Species.ZIP_ZAP: _draw_zip_zap(bob)
		CustomerData.Species.LUMEN: _draw_lumen(bob)
		CustomerData.Species.GRAVITON: _draw_graviton(bob)
		CustomerData.Species.CAPTAIN_NOVA: _draw_nova(bob)
		CustomerData.Species.CRITIC: _draw_critic(bob)
	_draw_overhead()


func _draw_blorb(bob: float) -> void:
	var wobble := sin(_time * 3.0) * 0.05
	var c := Vector2(FEET.x, FEET.y - 60 + bob)
	_draw_blob(c, Vector2(82 * (1 + wobble), 62 * (1 - wobble)))
	_draw_eye(c + Vector2(-26, -20), 13)
	_draw_eye(c + Vector2(26, -20), 13)
	_draw_mouth(c + Vector2(0, 8), 16)


func _draw_zip_zap(bob: float) -> void:
	var jitter := Vector2(sin(_time * 31.0), cos(_time * 27.0)) * 2.0
	var c := Vector2(FEET.x, FEET.y - 72 + bob) + jitter
	draw_line(c + Vector2(-18, 30), Vector2(FEET.x - 22, FEET.y), OUTLINE, 6.0, true)
	draw_line(c + Vector2(18, 30), Vector2(FEET.x + 22, FEET.y), OUTLINE, 6.0, true)
	draw_line(c + Vector2(-16, -40), c + Vector2(-30, -78), OUTLINE, 4.0, true)
	draw_line(c + Vector2(16, -40), c + Vector2(30, -78), OUTLINE, 4.0, true)
	draw_circle(c + Vector2(-30, -80), 7, data.accent_color)
	draw_circle(c + Vector2(30, -80), 7, data.accent_color)
	_draw_blob(c, Vector2(50, 50))
	_draw_eye(c + Vector2(-20, -14), 9)
	_draw_eye(c + Vector2(0, -24), 10)
	_draw_eye(c + Vector2(20, -14), 9)
	_draw_mouth(c + Vector2(0, 14), 11)


func _draw_lumen(bob: float) -> void:
	var c := Vector2(FEET.x, FEET.y - 95 + bob)
	var glow := 0.06 + 0.03 * sin(_time * 2.5)
	for k in 3:
		draw_circle(c, 105 - k * 15, Color(data.body_color, glow))
	_draw_blob(c, Vector2(55, 86))
	_draw_eye(c + Vector2(-20, -30), 12)
	_draw_eye(c + Vector2(20, -30), 12)
	_draw_mouth(c + Vector2(0, 0), 13)


func _draw_graviton(bob: float) -> void:
	var c := Vector2(FEET.x, FEET.y - 96 + bob * 0.5)
	_draw_blob(c + Vector2(-92, 20), Vector2(20, 34))
	_draw_blob(c + Vector2(92, 20), Vector2(20, 34))
	_draw_blob(c, Vector2(92, 96))
	_draw_eye(c + Vector2(-24, -44), 9)
	_draw_eye(c + Vector2(24, -44), 9)
	_draw_mouth(c + Vector2(0, -18), 14)


func _draw_nova(bob: float) -> void:
	var body := Vector2(FEET.x, FEET.y - 58 + bob)
	_draw_blob(body, Vector2(62, 60))
	_draw_star(body + Vector2(0, 8), 14, data.accent_color)
	var head := Vector2(FEET.x, FEET.y - 158 + bob)
	draw_circle(head, 42, Color("9fd8ff"))
	draw_arc(head, 42, 0, TAU, 32, OUTLINE, 3.0, true)
	_draw_eye(head + Vector2(-15, -6), 9)
	_draw_eye(head + Vector2(15, -6), 9)
	_draw_mouth(head + Vector2(0, 16), 10)
	# Helmet glass with a shine
	draw_circle(head, 58, Color(1, 1, 1, 0.18))
	draw_arc(head, 58, 0, TAU, 40, Color(1, 1, 1, 0.7), 3.0, true)
	draw_arc(head, 46, deg_to_rad(200), deg_to_rad(250), 10, Color(1, 1, 1, 0.8), 5.0, true)


## Food critic (placeholder until drawn): tall, beret, shades, notepad.
func _draw_critic(bob: float) -> void:
	var body := Vector2(FEET.x, FEET.y - 70 + bob)
	_draw_blob(body, Vector2(46, 70))
	# Scarf
	draw_rect(Rect2(body + Vector2(-40, -62), Vector2(80, 14)), data.accent_color)
	draw_rect(Rect2(body + Vector2(18, -54), Vector2(14, 40)), data.accent_color)
	var head := Vector2(FEET.x, FEET.y - 162 + bob)
	_draw_blob(head, Vector2(38, 36))
	# Sunglasses and a raised eyebrow
	draw_rect(Rect2(head + Vector2(-30, -12), Vector2(26, 14)), OUTLINE)
	draw_rect(Rect2(head + Vector2(4, -12), Vector2(26, 14)), OUTLINE)
	draw_line(head + Vector2(-4, -6), head + Vector2(4, -6), OUTLINE, 3.0)
	draw_line(head + Vector2(6, -20), head + Vector2(28, -26), OUTLINE, 3.0, true)
	_draw_mouth(head + Vector2(0, 18), 8)
	# Beret
	var beret := PackedVector2Array([head + Vector2(-40, -26), head + Vector2(-20, -50), head + Vector2(26, -52), head + Vector2(44, -30)])
	draw_colored_polygon(beret, Color("2b2850"))
	draw_circle(head + Vector2(6, -54), 5, Color("2b2850"))
	# Notepad and pen
	var pad := Rect2(body + Vector2(-58, -10), Vector2(30, 38))
	draw_rect(pad, Color("fff8e1"))
	draw_rect(pad, OUTLINE, false, 2.0)
	for i in 3:
		draw_line(pad.position + Vector2(5, 10 + i * 9), pad.position + Vector2(25, 10 + i * 9), Color("9e9ac8"), 1.5)
	draw_line(body + Vector2(-24, -6), body + Vector2(-6, -30), Color("ffd95a"), 4.0, true)


## Patience bar, name tag, ticket number and the ordering bubble.
func _draw_overhead() -> void:
	var top := _head_top()
	var font := get_theme_default_font()
	var tag := data.display_name
	if order:
		tag = "#%d  %s" % [order.ticket_number, data.display_name]
	var tag_pos := Vector2(0, top - 52)
	draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_CENTER, BOX_SIZE.x, 22, 6, Color("0b0d2a"))
	draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_CENTER, BOX_SIZE.x, 22, Color("f4f1ff"))
	if GameState.has_gold_star(data):
		var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_draw_star(Vector2(BOX_SIZE.x / 2 - w / 2 - 16, tag_pos.y - 8), 10, Color("ffd95a"))

	if state == State.SERVED or state == State.LEAVING:
		if reaction_text != "":
			var tw := font.get_string_size(reaction_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28
			var rb := Rect2(FEET.x - tw / 2, top - 118, tw, 46)
			var col := Color("7be07b") if reaction_score >= 75 else (Color("ffd95a") if reaction_score >= 45 else Color("ff7eb6"))
			draw_rect(rb.grow(3), OUTLINE)
			draw_rect(rb, col)
			draw_string(font, Vector2(rb.position.x, rb.position.y + 31), reaction_text, HORIZONTAL_ALIGNMENT_CENTER, rb.size.x, 22, OUTLINE)
		return

	if state == State.ORDERING:
		var bubble := Rect2(FEET.x - 66, top - 160, 132, 128)
		draw_rect(bubble.grow(3), OUTLINE)
		draw_rect(bubble, Color("fff8ec"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(FEET.x - 12, bubble.end.y), Vector2(FEET.x + 12, bubble.end.y), Vector2(FEET.x, bubble.end.y + 18)]), Color("fff8ec"))
	elif state == State.WAITING_TO_ORDER or state == State.WAITING_FOR_FOOD:
		var ratio := patience_ratio()
		var bar := Rect2(FEET.x - 55, top - 36, 110, 14)
		draw_rect(bar.grow(3), Color("0b0d2a"))
		var col := Color("ff5c7a").lerp(Color("ffd95a"), clampf(ratio * 2.0, 0, 1))
		if ratio > 0.5:
			col = Color("ffd95a").lerp(Color("7be07b"), (ratio - 0.5) * 2.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)


func _head_top() -> float:
	if data == null:
		return 120.0
	match data.species:
		CustomerData.Species.BLORB: return FEET.y - 122
		CustomerData.Species.ZIP_ZAP: return FEET.y - 160
		CustomerData.Species.LUMEN: return FEET.y - 182
		CustomerData.Species.GRAVITON: return FEET.y - 192
		CustomerData.Species.CAPTAIN_NOVA: return FEET.y - 216
		CustomerData.Species.CRITIC: return FEET.y - 214
	return 120.0


func _mood() -> float:
	if reaction_score >= 0:
		if reaction_score >= 75:
			return 1.0
		return 0.45 if reaction_score >= 45 else 0.1
	if state == State.WAITING_TO_ORDER or state == State.WAITING_FOR_FOOD:
		return patience_ratio()
	return 1.0


func _draw_blob(center: Vector2, radii: Vector2) -> void:
	var pts := _ellipse_points(center, radii, 36)
	draw_colored_polygon(pts, data.body_color)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE, 4.0, true)
	# soft highlight
	_draw_ellipse(center + Vector2(-radii.x * 0.35, -radii.y * 0.45), radii * Vector2(0.28, 0.18), Color(1, 1, 1, 0.35))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, radii, 28), color)


func _ellipse_points(center: Vector2, radii: Vector2, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


func _draw_eye(pos: Vector2, r: float) -> void:
	if _blink_left > 0.0:
		draw_line(pos + Vector2(-r, 0), pos + Vector2(r, 0), PUPIL, 3.0, true)
		return
	draw_circle(pos, r, Color.WHITE)
	draw_arc(pos, r, 0, TAU, 20, OUTLINE, 2.0, true)
	draw_circle(pos + Vector2(0, r * 0.15), r * 0.5, PUPIL)
	draw_circle(pos + Vector2(-r * 0.2, -r * 0.1), r * 0.18, Color.WHITE)


func _draw_mouth(pos: Vector2, w: float) -> void:
	var mood := _mood()
	if mood > 0.6:
		draw_arc(pos + Vector2(0, -w * 0.4), w, deg_to_rad(30), deg_to_rad(150), 12, OUTLINE, 3.5, true)
	elif mood > 0.3:
		draw_line(pos + Vector2(-w * 0.7, 0), pos + Vector2(w * 0.7, 0), OUTLINE, 3.5, true)
	else:
		draw_arc(pos + Vector2(0, w * 0.7), w, deg_to_rad(210), deg_to_rad(330), 12, OUTLINE, 3.5, true)


func _draw_star(center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)
