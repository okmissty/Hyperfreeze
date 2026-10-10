class_name ScoreCard
extends Control
## The grade reveal after serving: what was ordered vs. what you made,
## four station scores filling in one by one, then the total, tip, XP and
## loyalty progress. Pauses the game while open; cards queue if several
## orders are served back to back.

const BAR_SECONDS := 0.35

var _queue: Array = []          # [Order, Scorer.Result] pairs waiting to show
var _order: Order
var _title: Label
var _rating: Label
var _stars: StarRow
var _ordered: CupIcon
var _made: CupView
var _bars: Array[ScoreBar] = []
var _numbers: Array[Label] = []
var _total: Label
var _tip: Label
var _loyalty: Label
var _continue: Button
var _burst: StarBurst
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_title = _label("", &"HudValue", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)

	var rating_holder := Control.new()
	rating_holder.custom_minimum_size = Vector2(0, 64)
	box.add_child(rating_holder)
	_burst = StarBurst.new()
	_burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	rating_holder.add_child(_burst)
	_rating = _label("", &"ResultLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_rating.set_anchors_preset(Control.PRESET_FULL_RECT)
	rating_holder.add_child(_rating)
	_stars = StarRow.new()
	_stars.custom_minimum_size = Vector2(0, 52)
	_stars.visible = UiSkin.tex("ui_star_full") != null
	box.add_child(_stars)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 36)
	box.add_child(body)

	var cups := HBoxContainer.new()
	cups.add_theme_constant_override("separation", 16)
	body.add_child(cups)
	_ordered = CupIcon.new()
	_made = CupView.new()
	for pair: Array in [["ORDERED", _ordered], ["YOU MADE", _made]]:
		var col := VBoxContainer.new()
		col.add_child(_label(pair[0], &"SectionCaption", HORIZONTAL_ALIGNMENT_CENTER))
		var art: Control = pair[1]
		art.custom_minimum_size = Vector2(170, 230)
		col.add_child(art)
		cups.add_child(col)

	var grades := VBoxContainer.new()
	grades.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grades.add_theme_constant_override("separation", 12)
	body.add_child(grades)
	for name_text: String in ["WAITING", "BUILD", "ZAP", "TOP"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var cap := _label(name_text, &"SectionCaption", HORIZONTAL_ALIGNMENT_LEFT)
		cap.custom_minimum_size = Vector2(110, 0)
		row.add_child(cap)
		var bar := ScoreBar.new()
		bar.custom_minimum_size = Vector2(0, 30)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_bars.append(bar)
		var num := _label("", &"StatusLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		num.custom_minimum_size = Vector2(64, 0)
		row.add_child(num)
		_numbers.append(num)
		grades.add_child(row)

	_total = _label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_LEFT)
	grades.add_child(_total)
	_tip = _label("", &"HudValue", HORIZONTAL_ALIGNMENT_LEFT)
	grades.add_child(_tip)
	_loyalty = _label("", &"SlotHint", HORIZONTAL_ALIGNMENT_LEFT)
	_loyalty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grades.add_child(_loyalty)

	_continue = Button.new()
	_continue.text = "Continue"
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.pressed.connect(close)
	box.add_child(_continue)

	Events.order_served.connect(_on_order_served)


func is_open() -> bool:
	return visible


func _on_order_served(order: Order, result: RefCounted) -> void:
	_queue.append([order, result])
	if not visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		return
	var pair: Array = _queue.pop_front()
	_order = pair[0]
	var r: Scorer.Result = pair[1]
	visible = true
	get_tree().paused = true

	_title.text = "#%d  ·  %s" % [_order.ticket_number, _order.customer.display_name]
	_rating.text = ""
	_stars.count = -1
	_ordered.order = _order
	_made.cup = _order.cup
	_total.text = ""
	_tip.text = ""
	_loyalty.text = ""
	_continue.disabled = true
	var scores: Array[int] = [r.wait, r.build, r.zap, r.top]
	for i in 4:
		_bars[i].value = 0.0
		_numbers[i].text = ""

	if _tween:
		_tween.kill()
	_tween = create_tween()
	for i in 4:
		_tween.tween_property(_bars[i], "value", scores[i] / 100.0, BAR_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(func() -> void: _numbers[i].text = str(scores[i]))
	_tween.tween_callback(func() -> void:
		_total.text = "Score %d" % r.total
		_rating.text = r.rating
		_stars.count = clampi(roundi(r.total / 20.0), 0, 5)
		_tip.text = "Tip +%s    ·    +%d XP" % [GameState.format_money(r.tip_cents), r.xp]
		_loyalty.text = _loyalty_text(r)
		_continue.disabled = false
		if r.total >= 90:
			_burst.play())


func _loyalty_text(r: Scorer.Result) -> String:
	var who := _order.customer
	if who.is_critic:
		return "CRITIC REVIEW  ·  %s gives it %d of 5 stars\n\"%s\"\nCafé rating is now %.1f / 5" % [r.review_paper, r.review_stars, r.review_quote, GameState.cafe_rating()]
	if r.gold_star_earned:
		return "Gold star earned! %s now tips %d%% more." % [who.display_name, roundi(GameState.GOLD_TIP_BONUS * 100)]
	if GameState.has_gold_star(who):
		return "Gold-star regular: tip bonus included."
	var great := GameState.great_visits(who)
	if great > 0:
		return "Great visits: %d of %d toward %s's gold star." % [great, GameState.GREAT_VISITS_FOR_GOLD, who.display_name]
	return "Score %d+ three times to earn %s's gold star." % [GameState.GREAT_VISIT_SCORE, who.display_name]


func close() -> void:
	if _tween and _tween.is_running():
		_tween.custom_step(10.0)  # first tap skips the animation
		return
	visible = false
	get_tree().paused = false
	var finished := _order
	_order = null
	Events.score_card_closed.emit(finished)
	if not _queue.is_empty():
		_show_next.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
		close()
		get_viewport().set_input_as_handled()


func _label(text: String, variation: StringName, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Rounded bar that fills to `value` (0–1), coloured by how good it is.
class ScoreBar extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := Color("ff5c7a")
		if value >= 0.85:
			col = Color("7be07b")
		elif value >= 0.6:
			col = Color("ffd95a")
		elif value >= 0.35:
			col = Color("ff9f43")
		# Drawn bar: gold fill tinted toward the grade colour.
		if UiSkin.draw_bar(self, "bar", r, value, Color.WHITE.lerp(col, 0.45)):
			return
		draw_style_box(_box(Color("0b0d2a")), r)
		if value <= 0.0:
			return
		draw_style_box(_box(col), Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * value), r.size.y)))

	static func _box(c: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(15)
		return sb


## Five rating stars (score / 20), drawn from ui_star_full / ui_star_empty.
class StarRow extends Control:
	var count := -1:
		set(v):
			count = v
			queue_redraw()

	func _draw() -> void:
		if count < 0:
			return
		var full := UiSkin.tex("ui_star_full")
		var empty := UiSkin.tex("ui_star_empty")
		if full == null or empty == null:
			return
		var d := size.y
		var gap := 8.0
		var x0 := (size.x - (d * 5 + gap * 4)) / 2.0
		for i in 5:
			Art.draw_fit(self, full if i < count else empty, Rect2(Vector2(x0 + i * (d + gap), 0), Vector2(d, d)))


## Little stars flying out behind a great rating.
class StarBurst extends Control:
	var _t := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func play() -> void:
		_t = 0.0

	func _process(delta: float) -> void:
		if _t < 0.0:
			return
		_t += delta
		if _t > 1.2:
			_t = -1.0
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var c := size / 2.0
		var fade := 1.0 - _t / 1.2
		for i in 14:
			var a := TAU * i / 14.0 + 0.3
			var d := 40.0 + _t * 360.0
			var p := c + Vector2(cos(a) * d * 1.6, sin(a) * d * 0.5)
			var col := Color("ffd95a") if i % 2 == 0 else Color("3ee6f0")
			_star(p, 9.0, Color(col, fade))

	func _star(center: Vector2, r: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + TAU * i / 10.0
			pts.append(center + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, color)
