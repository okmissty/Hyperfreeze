class_name BadgePopup
extends Control
## "Badge earned!" banner that drops in at the top of the screen, one badge
## at a time. Runs while paused (badges often land under the score card).

const SHOW_SECONDS := 3.2

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	size = Vector2(760, 120)
	position = Vector2(0, -140)
	Events.badge_earned.connect(_on_badge)


func _on_badge(b: Dictionary) -> void:
	_queue.append(b)
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_current = _queue.pop_front()
	position.x = (get_viewport_rect().size.x - size.x) / 2.0
	queue_redraw()
	AudioManager.play("rank_up")
	var tw := create_tween()
	tw.tween_property(self, "position:y", 18.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_SECONDS)
	tw.tween_property(self, "position:y", -140.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next)


func _draw() -> void:
	if _current.is_empty():
		return
	var col := Badges.group_color(String(_current.group))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.2, 0.95)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	BadgesPanel.BadgeMedal.draw_medal(self, _current, Vector2(64, size.y / 2), 42.0, true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(124, 36), "BADGE EARNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	draw_string(font, Vector2(124, 70), String(_current.name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 140, 30, Color("f4f1ff"))
	draw_string(font, Vector2(124, 100), Badges.reward_text(_current), HORIZONTAL_ALIGNMENT_LEFT, size.x - 140, 17, Color("ffd95a"))
