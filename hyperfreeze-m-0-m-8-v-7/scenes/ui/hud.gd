extends PanelContainer
## Top-right readout: day, clock, tips, pause, and a shift bar showing how
## far through the day you are (9 AM to 6 PM) with real minutes left.

const BAR_BG := Color("0b0d2a")
const BAR_FILL := Color("3ee6f0")
const BAR_LATE := Color("ff9f43")
const BAR_CLOSED := Color("ff7eb6")

var _closed := false

@onready var _day_value: Label = %DayValue
@onready var _clock_value: Label = %ClockValue
@onready var _money_value: Label = %MoneyValue
@onready var _pause_button: Button = %PauseButton
@onready var _shift_bar: Control = %ShiftBar
@onready var _shift_note: Label = %ShiftNote


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	UiSkin.follow_theme(self)
	_pause_button.pressed.connect(func() -> void: Events.pause_requested.emit())
	_shift_bar.draw.connect(_draw_shift_bar)
	_apply_art()
	Events.day_started.connect(_on_day_started)
	Events.clock_changed.connect(_on_clock_changed)
	Events.money_changed.connect(func(cents: int) -> void:
		_money_value.text = GameState.format_money(cents))
	Events.shop_closed.connect(_on_shop_closed)
	Events.review_posted.connect(func(_s: int, _r: float) -> void: _update_note())
	_day_value.text = str(GameState.day)
	_clock_value.text = DayManager.format_clock(DayManager.OPEN_MINUTES)
	_money_value.text = GameState.format_money(GameState.money_cents)
	_update_note()


func _on_day_started(day: int) -> void:
	_closed = false
	_day_value.text = str(day)
	_clock_value.remove_theme_color_override("font_color")
	_update_note()
	_shift_bar.queue_redraw()


func _on_clock_changed(minutes: int) -> void:
	if not _closed:
		_clock_value.text = DayManager.format_clock(minutes)
	_update_note()
	_shift_bar.queue_redraw()


func _on_shop_closed() -> void:
	_closed = true
	_clock_value.text = "Closed"
	_clock_value.add_theme_color_override("font_color", BAR_CLOSED)
	_update_note()
	_shift_bar.queue_redraw()


func _update_note() -> void:
	var rating := "Rating %.1f / 5  ·  " % GameState.cafe_rating()
	if _closed:
		_shift_note.text = rating + "Closed - serve the last customers"
		return
	var secs := DayManager.seconds_until_close()
	if secs >= DayManager.day_length - 0.5:
		_shift_note.text = rating + "Open 9 AM - 6 PM"
		return
	var mins := ceili(secs / 60.0)
	_shift_note.text = rating + ("Closes at 6 PM  ·  %d min left" % mins if mins > 1 else "Closes at 6 PM  ·  under a minute left")


## Ty's HUD art: icons beside day / time / tips, a drawn pause button and
## the moon shift bar. Falls back to the plain look for anything missing.
func _apply_art() -> void:
	for pair: Array in [["Day", "icon_day"], ["Time", "icon_clock"], ["Tips", "icon_coin"]]:
		var col := get_node_or_null("Layout/Row/" + pair[0]) as Control
		var t := UiSkin.tex(pair[1])
		if col == null or t == null:
			continue
		var icon := TextureRect.new()
		icon.texture = t
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(38, 38)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.get_parent().add_child(icon)
		col.get_parent().move_child(icon, col.get_index())
	var normal := UiSkin.tex("ui_btn_pause_normal")
	if normal:
		var art := TextureButton.new()
		art.texture_normal = normal
		art.texture_hover = UiSkin.tex("ui_btn_pause_hover")
		art.texture_pressed = UiSkin.tex("ui_btn_pause_pressed")
		art.texture_disabled = UiSkin.tex("ui_btn_pause_disabled")
		art.ignore_texture_size = true
		art.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.focus_mode = Control.FOCUS_NONE
		art.tooltip_text = _pause_button.tooltip_text
		art.pressed.connect(func() -> void: Events.pause_requested.emit())
		_pause_button.text = ""
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			_pause_button.add_theme_stylebox_override(st, empty)
		_pause_button.add_child(art)
	# Shop is open all day (it pauses the café while you browse).
	var shop := Button.new()
	shop.text = "Shop"
	shop.theme_type_variation = &"SecondaryButton"
	shop.focus_mode = Control.FOCUS_NONE
	shop.tooltip_text = "Upgrades and café themes"
	shop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop.pressed.connect(func() -> void: Events.shop_requested.emit())
	_pause_button.get_parent().add_child(shop)
	_pause_button.get_parent().move_child(shop, _pause_button.get_index())
	if not UiSkin.bar_boxes("shift", 24.0).is_empty():
		_shift_bar.custom_minimum_size.y = 24.0


func _draw_shift_bar() -> void:
	var r := Rect2(Vector2.ZERO, _shift_bar.size)
	if not UiSkin.bar_boxes("shift", r.size.y).is_empty():
		var p0 := 1.0 if _closed else DayManager.day_progress()
		var tint := Color("ff9fc8") if _closed else (Color("ffc58a") if p0 >= 0.85 else Color.WHITE)
		UiSkin.draw_bar(_shift_bar, "shift", r, p0, tint)
		var g := UiSkin.bar_groove(r)
		for f: float in [0.3, 0.55]:
			var x := g.position.x + g.size.x * f
			_shift_bar.draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Color(1, 1, 1, 0.35), 2.0)
		return
	var radius := r.size.y / 2.0
	_shift_bar.draw_style_box(_box(BAR_BG, radius), r)
	var p := 1.0 if _closed else DayManager.day_progress()
	var col := BAR_CLOSED if _closed else (BAR_LATE if p >= 0.85 else BAR_FILL)
	if p > 0.0:
		_shift_bar.draw_style_box(_box(col, radius), Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * p), r.size.y)))
	# Lunch rush marker (busiest stretch of the day)
	for f: float in [0.3, 0.55]:
		var x := r.size.x * f
		_shift_bar.draw_line(Vector2(x, 2), Vector2(x, r.size.y - 2), Color(1, 1, 1, 0.25), 2.0)


static func _box(c: Color, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	return sb
