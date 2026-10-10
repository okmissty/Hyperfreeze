class_name Blender
extends VBoxContainer
## One Hyperfreeze Blender (built in code so the Zap Station can own one or
## two). Load a cup, pick a zap level, hold to blend, release inside the
## band. The cup then heads to the Top Station shelf.

signal became_free(blender: Blender)

## Meter fill per second while held (bottom to top in about 2.8 s).
const ZAP_RATE := 0.36
const RESULT_SECONDS := 1.1

var index := 0
var order: Order
var level := -1
var value := 0.0
var blending := false
var done := false

var _machine: MachineView
var _level_buttons: Array[IngredientButton] = []
var _zap_button: Button
var _result: Label
var _group := ButtonGroup.new()
var _time := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var narrow := GameState.blender_count > 1
	custom_minimum_size = Vector2(540 if narrow else 740, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_CENTER

	_machine = MachineView.new()
	_machine.blender = self
	_machine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_machine)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for lvl in 3:
		var b := IngredientButton.new()
		b.swatch_color = ZapBands.color(lvl)
		b.icon_tex = Art.station("icon_zap_%s" % Order.zap_name(lvl as Order.ZapLevel).to_lower())
		# Two blenders side by side: icon-only buttons (the name is in the tooltip).
		b.text = "" if narrow and b.icon_tex else Order.zap_name(lvl as Order.ZapLevel)
		b.icon_centered = b.text == ""
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s (%s)" % [Order.zap_name(lvl as Order.ZapLevel), Order.zap_description(lvl as Order.ZapLevel)]
		b.toggle_mode = true
		b.button_group = _group
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(_on_level_picked.bind(lvl))
		row.add_child(b)
		_level_buttons.append(b)

	_zap_button = Button.new()
	_zap_button.text = "Hold to Zap"
	_zap_button.custom_minimum_size = Vector2(0, 64)
	_zap_button.focus_mode = Control.FOCUS_NONE
	_zap_button.button_down.connect(_on_zap_down)
	_zap_button.button_up.connect(_on_zap_up)
	add_child(_zap_button)

	_result = Label.new()
	_result.theme_type_variation = &"ResultLabel"
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.custom_minimum_size = Vector2(0, 40)
	add_child(_result)
	_update_controls()


func is_free() -> bool:
	return order == null


func load_cup(o: Order) -> void:
	if order != null or o.cup == null:
		return
	order = o
	level = -1
	value = 0.0
	done = false
	blending = false
	_result.text = ""
	for b in _level_buttons:
		b.set_pressed_no_signal(false)
	DayManager.move_cup(o, StationIds.blender(index))
	_update_controls()


## Clears the blender without touching DayManager (used on a new day).
func reset() -> void:
	if blending:
		AudioManager.stop_loop("blend_loop")
	order = null
	level = -1
	value = 0.0
	blending = false
	done = false
	if _result:
		_result.text = ""
	for b in _level_buttons:
		b.set_pressed_no_signal(false)
	_update_controls()


## Called if the player leaves the station mid-hold.
func cancel_hold() -> void:
	if blending:
		_release()


func _on_level_picked(lvl: int) -> void:
	if order == null or done:
		return
	level = lvl
	_update_controls()


func _on_zap_down() -> void:
	if order and level >= 0 and not done:
		blending = true
		AudioManager.start_loop("blend_loop")


func _on_zap_up() -> void:
	if blending:
		_release()


func _process(delta: float) -> void:
	_time += delta
	if blending:
		value = minf(value + ZAP_RATE * GameState.zap_rate_mult() * delta, 1.0)
		if value >= 1.0:
			_release()
	if order or blending:
		_machine.queue_redraw()


func _release() -> void:
	blending = false
	done = true
	AudioManager.stop_loop("blend_loop")
	AudioManager.play("zap_ding", 0.0)
	var cup := order.cup
	cup.zapped = true
	cup.zap_level = level
	cup.zap_value = value
	Events.cup_changed.emit(order)
	_result.text = ZapBands.verdict(ZapBands.accuracy(level, value))
	_update_controls()
	_machine.queue_redraw()
	var finished := order
	await get_tree().create_timer(RESULT_SECONDS).timeout
	if order != finished or finished.cup == null:
		return
	order = null
	var watching := is_visible_in_tree()
	DayManager.move_cup(finished, StationIds.TOP_SHELF)
	DayManager.ticket_follow_cup(finished, StationIds.ZAP, StationIds.TOP)
	reset()
	if watching and GameState.get_setting("follow_cup"):
		Events.request_station.emit(StationIds.TOP)
	became_free.emit(self)


func _update_controls() -> void:
	if _zap_button == null:
		return
	var ready_to_pick := order != null and not done
	for b in _level_buttons:
		b.disabled = not ready_to_pick
	_zap_button.disabled = not (ready_to_pick and level >= 0)
	if order == null:
		_zap_button.text = "Hold to Zap"
	elif level < 0:
		_zap_button.text = "Pick a zap level"
	else:
		_zap_button.text = "Hold to Zap"


## The machine drawing: glass jar with the cup inside, and the zap meter.
class MachineView extends Control:
	var blender: Blender

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 280)

	func _draw() -> void:
		if Art.station("st_zap_jar_01") and Art.station("st_zap_base_off") and Art.station("st_zap_meter"):
			_draw_art()
			return
		var w := size.x
		var h := size.y
		var ink := Color("2b2850")
		# Body + base
		var base_rect := Rect2(w * 0.06, h - 64, w * 0.62, 56)
		draw_style_box(_box(Color("3b2f7a"), 18), base_rect)
		draw_circle(Vector2(base_rect.position.x + 34, base_rect.get_center().y), 9, Color("3ee6f0") if blender.blending else Color("5c5a8a"))
		var font := get_theme_default_font()
		draw_string(font, Vector2(base_rect.position.x + 56, base_rect.get_center().y + 8), "HYPERFREEZE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("b9b4e0"))
		# Jar
		var jar_top := 12.0
		var jar_bottom := h - 64
		var jl := w * 0.1
		var jr := w * 0.64
		var jar := PackedVector2Array([Vector2(jl, jar_top), Vector2(jr, jar_top), Vector2(jr - 26, jar_bottom), Vector2(jl + 26, jar_bottom)])
		draw_colored_polygon(jar, Color(1, 1, 1, 0.07))
		# Cup inside, shaking while blending
		if blender.order and blender.order.cup:
			var shake := Vector2.ZERO
			if blender.blending:
				shake = Vector2(sin(blender._time * 60.0), cos(blender._time * 47.0)) * 3.0
			var cup_rect := Rect2(Vector2(jl + 30, jar_top + 20) + shake, Vector2(jr - jl - 60, jar_bottom - jar_top - 24))
			CupPainter.draw_cup(self, cup_rect, blender.order.cup)
			if blender.blending:
				var c := cup_rect.get_center()
				for i in 3:
					var a := blender._time * 9.0 + i * TAU / 3.0
					draw_arc(c, 40 + i * 14, a, a + 1.6, 12, Color(1, 1, 1, 0.5), 3.0, true)
		else:
			draw_string(font, Vector2(jl, (jar_top + jar_bottom) / 2), "Empty", HORIZONTAL_ALIGNMENT_CENTER, jr - jl, 26, Color("b9b4e0", 0.7))
		jar.append(jar[0])
		draw_polyline(jar, Color(1, 1, 1, 0.55), 3.0, true)

		# Meter: 0 at the bottom, 1 at the top
		var mx := w * 0.74
		var mw := 54.0
		var my0 := 16.0
		var my1 := h - 20.0
		var meter := Rect2(mx, my0, mw, my1 - my0)
		draw_style_box(_box(Color("0b0d2a"), 14), meter.grow(4))
		for lvl in 3:
			var band := ZapBands.band(lvl)
			var y_hi := lerpf(my1, my0, band.y)
			var y_lo := lerpf(my1, my0, band.x)
			var col := ZapBands.color(lvl)
			var chosen := lvl == blender.level
			draw_rect(Rect2(mx, y_hi, mw, y_lo - y_hi), Color(col, 0.9 if chosen else 0.3))
			if chosen:
				draw_rect(Rect2(mx - 3, y_hi - 3, mw + 6, y_lo - y_hi + 6), Color.WHITE, false, 3.0)
			draw_string(font, Vector2(mx + mw + 12, (y_hi + y_lo) / 2 + 7), Order.zap_name(lvl as Order.ZapLevel), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col if chosen else Color(col, 0.7))
		# Needle
		if blender.blending or blender.done:
			var ny := lerpf(my1, my0, blender.value)
			draw_line(Vector2(mx - 10, ny), Vector2(mx + mw + 6, ny), Color.WHITE, 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 22, ny - 9), Vector2(mx - 6, ny), Vector2(mx - 22, ny + 9)]), Color.WHITE)
		draw_rect(meter, ink, false, 2.0)

	## Ty's blender: base, glass jar over the cup, framed meter, band cards, needle.
	func _draw_art() -> void:
		var w := size.x
		var h := size.y
		var font := get_theme_default_font()
		# Meter + legend on the right (names only when there's room), jar on the left.
		var meter_tex := Art.station("st_zap_meter")
		var mh := h - 8.0
		var mw := mh * meter_tex.get_width() / float(meter_tex.get_height())
		var with_names := w >= 600.0
		var legend_w := 150.0 if with_names else 44.0
		var frame := Rect2(Vector2(w - legend_w - mw, 4.0), Vector2(mw, mh))
		var cx := (frame.position.x - 12.0) * 0.5
		# Base (lights up while zapping)
		var base_tex := Art.station("st_zap_base_on" if blender.blending else "st_zap_base_off")
		if base_tex == null:
			base_tex = Art.station("st_zap_base_off")
		var hb := h * 0.3
		var base_rect := Rect2(Vector2(cx - hb * 0.55, h - hb), Vector2(hb * 1.1, hb))
		# Jar sits on the base
		var jar_tex := Art.station("st_zap_jar_01")
		var jar_bottom := h - hb * 0.74
		var hj := jar_bottom - 2.0
		var wj := hj * jar_tex.get_width() / float(jar_tex.get_height())
		var shake := Vector2.ZERO
		if blender.blending:
			shake = Vector2(sin(blender._time * 60.0), cos(blender._time * 47.0)) * 3.0
		var jar_rect := Rect2(Vector2(cx - wj * 0.42, 2.0) + shake, Vector2(wj, hj))
		Art.draw_fit(self, base_tex, base_rect)
		if blender.order and blender.order.cup:
			# Inside the glass body (the jar art has a lid on top and a handle on the right)
			var cup_rect := Rect2(jar_rect.position + Vector2(wj * 0.07, hj * 0.21), Vector2(wj * 0.72, hj * 0.62))
			CupPainter.draw_cup(self, cup_rect, blender.order.cup, {"fit_cup": true})
			if blender.blending:
				var swirl := Art.station("st_zap_jar_03")
				if swirl:
					jar_tex = swirl
		else:
			draw_string(font, Vector2(jar_rect.position.x, jar_rect.get_center().y + 10), "Empty", HORIZONTAL_ALIGNMENT_CENTER, wj * 0.8, 26, Color("6b5fa8", 0.8))
		draw_texture_rect(jar_tex, jar_rect, false)

		# Meter: the painted frame; bands sit in its glass window, 0 at the bottom.
		var win := Rect2(frame.position + Vector2(mw * 0.3, mh * 0.12), Vector2(mw * 0.4, mh * 0.76))
		draw_texture_rect(meter_tex, frame, false)
		var my0 := win.position.y
		var my1 := win.end.y
		for lvl in 3:
			var band := ZapBands.band(lvl)
			var y_hi := lerpf(my1, my0, band.y)
			var y_lo := lerpf(my1, my0, band.x)
			var col := ZapBands.color(lvl)
			var chosen := lvl == blender.level
			draw_rect(Rect2(win.position.x, y_hi, win.size.x, y_lo - y_hi), Color(col, 0.85 if chosen else 0.5))
			# Legend: the band's card art and name beside the meter
			var lvl_name := Order.zap_name(lvl as Order.ZapLevel)
			var card := Art.station("st_zap_band_%s" % lvl_name.to_lower())
			var lx := frame.end.x + 8.0
			var ch := maxf(y_lo - y_hi, 30.0) * 1.25
			if card:
				Art.draw_fit(self, card, Rect2(Vector2(lx, (y_hi + y_lo - ch) / 2.0), Vector2(ch * 0.7, ch)), Color(1, 1, 1, 1.0 if chosen else 0.55))
				lx += ch * 0.7 + 6.0
			if with_names:
				draw_string_outline(font, Vector2(lx, (y_hi + y_lo) / 2 + 7), lvl_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0.04, 0.05, 0.16, 0.9))
				draw_string(font, Vector2(lx, (y_hi + y_lo) / 2 + 7), lvl_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col if chosen else Color(col, 0.85))
			if chosen:
				draw_rect(Rect2(win.position.x - 2, y_hi - 2, win.size.x + 4, y_lo - y_hi + 4), Color.WHITE, false, 3.0)
		# Needle: tip touches the meter's left edge at the current value
		if blender.blending or blender.done:
			var ny := lerpf(my1, my0, blender.value)
			var needle := Art.station("st_zap_needle")
			if needle:
				var ts := needle.get_size()
				var sc := 78.0 / (132.0 * ts.x / 155.0)
				var tip := Vector2(0.026, 0.11) * ts
				draw_set_transform(Vector2(win.position.x - 2.0, ny), -0.405, Vector2(-sc, sc))
				draw_texture_rect(needle, Rect2(-tip, ts), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_line(Vector2(win.position.x - 10, ny), Vector2(win.end.x + 6, ny), Color.WHITE, 4.0)

	static func _box(color: Color, radius: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(radius)
		return sb
