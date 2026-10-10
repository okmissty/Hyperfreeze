class_name Ticket
extends PanelContainer
## A paper order ticket, built entirely in code from an Order.
## Compact mode sits on the rail; full mode shows every detail in a station slot.
## Drag it anywhere that accepts tickets, or tap it to send it on.

signal tapped(ticket: Ticket)

const COMPACT_SIZE := Vector2(150, 212)
const FULL_WIDTH := 320.0
const INK := Color("2b2850")
const INK_2 := Color("7a7699")
const LINE := Color(0.17, 0.16, 0.31, 0.15)

var order: Order
var compact := true
var draggable := true

var _pressed := false
var _dragging := false
var _status: Label


## Builds a ready-to-add ticket.
static func create(for_order: Order, is_compact: bool) -> Ticket:
	var t := Ticket.new()
	t.order = for_order
	t.compact = is_compact
	return t


func _ready() -> void:
	theme_type_variation = &"TicketPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if compact:
		custom_minimum_size = COMPACT_SIZE
		size = COMPACT_SIZE
	else:
		custom_minimum_size = Vector2(FULL_WIDTH, 0)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pivot_offset = Vector2(custom_minimum_size.x / 2, 0)
	_build()
	var clip_tex := UiSkin.tex("ui_ticket_clip")
	if compact and clip_tex:
		var clip := TextureRect.new()
		clip.texture = clip_tex
		clip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.size = Vector2(52, 40)
		clip.position = Vector2((COMPACT_SIZE.x - 52.0) / 2.0, -22.0)
		# The panel lays out its children, so park the clip in a plain holder.
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(clip)
		add_child(holder)
	Events.cup_moved.connect(_on_cup_moved)


## Brief cyan outline so a freshly printed ticket stands out.
func flash_new() -> void:
	theme_type_variation = &"TicketPanelNew"
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(self):
			theme_type_variation = &"TicketPanel")


func wiggle() -> void:
	var tw := create_tween()
	for angle: float in [-6.0, 6.0, -4.0, 0.0]:
		tw.tween_property(self, "rotation_degrees", angle, 0.06)


# --- Input & drag -------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_pressed = true
		_dragging = false
	elif _pressed:
		_pressed = false
		if not _dragging:
			tapped.emit(self)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or order == null:
		return null
	_dragging = true
	modulate.a = 0.35
	var preview_root := Control.new()
	var preview := Ticket.create(order, true)
	preview.draggable = false
	preview.rotation_degrees = -5.0
	preview.position = -COMPACT_SIZE / 2.0
	preview_root.add_child(preview)
	set_drag_preview(preview_root)
	return {"kind": "ticket", "order": order}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragging = false
		_pressed = false
		modulate.a = 1.0


func _on_cup_moved(moved: Order, _from: StringName, _to: StringName) -> void:
	if moved == order:
		_update_status()


## Little stamp on compact tickets showing where the cup is.
func _update_status() -> void:
	if _status == null or order == null:
		return
	var loc: StringName = order.cup.location if order.cup else &""
	var text_out := ""
	var col := Color("7a7699")
	match StationIds.station_for_cup(loc):
		StationIds.BUILD:
			text_out = "BUILD"
		StationIds.ZAP:
			text_out = "ZAP"
			col = Color("1f9aa3")
		StationIds.TOP:
			text_out = "TOP"
			col = Color("c2507f")
		StationIds.READY:
			text_out = "READY"
			col = Color("2e9e57")
	_status.text = text_out
	_status.add_theme_color_override("font_color", col)


## True if drag data coming from a Ticket.
static func is_ticket_data(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "ticket" and data.get("order") is Order


# --- Building the paper -------------------------------------------------------

func _build() -> void:
	for child in get_children():
		child.queue_free()
	if order == null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	if compact:
		_build_compact(box)
	else:
		_build_full(box)
	_ignore_mouse_recursive(box)


func _build_compact(box: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label("#%d" % order.ticket_number, &"TicketHeader"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if order.customer and order.customer.is_critic:
		header.add_child(_critic_tag())
	header.add_child(_label(Order.size_letter(order.size), &"TicketHeader"))

	var who_row := HBoxContainer.new()
	box.add_child(who_row)
	var who := _label(order.customer.display_name if order.customer else "", &"TicketCaption")
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_row.add_child(who)
	_status = _label("", &"TicketCaption")
	who_row.add_child(_status)
	_update_status()

	var icon := CupIcon.new()
	icon.custom_minimum_size = Vector2(0, 104)
	icon.order = order
	box.add_child(icon)

	box.add_child(_zap_meter())


func _build_full(box: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label("#%d" % order.ticket_number, &"TicketHeader"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if order.customer and order.customer.is_critic:
		header.add_child(_critic_tag())
	header.add_child(_label(order.customer.display_name if order.customer else "", &"TicketCaption"))

	var title := _label(order.display_name(), &"TicketBody")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", INK_2)
	box.add_child(title)

	var icon := CupIcon.new()
	icon.custom_minimum_size = Vector2(0, 92)
	icon.order = order
	box.add_child(icon)

	box.add_child(_rule())
	box.add_child(_row("CUP", [_label("%s cup" % Order.size_name(order.size), &"TicketBody")]))
	box.add_child(_row("BASE", _ingredient_line(order.base_id)))

	var mix_box := VBoxContainer.new()
	mix_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix_box.add_theme_constant_override("separation", 2)
	if order.mixin_ids.is_empty():
		mix_box.add_child(_label("None", &"TicketBody"))
	for mix_id: StringName in order.mixin_ids:
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 6)
		for n in _ingredient_line(mix_id):
			line.add_child(n)
		mix_box.add_child(line)
	box.add_child(_row("MIX-INS", [mix_box]))

	box.add_child(_row("ZAP", [_label("%s (%s)" % [Order.zap_name(order.zap_level), Order.zap_description(order.zap_level)], &"TicketBody")]))
	box.add_child(_rule())
	box.add_child(_row("CREAM", [_label("Nebula Cream" if order.wants_cream else "No cream", &"TicketBody")]))
	box.add_child(_row("SAUCE", _ingredient_line(order.sauce_id, "No sauce")))
	box.add_child(_row("SPRINKLES", _ingredient_line(order.sprinkle_id, "None")))
	box.add_child(_rule())
	box.add_child(_label("TOPPERS", &"TicketCaption"))
	box.add_child(_topper_grid())


func _row(caption: String, value_nodes: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := _label(caption, &"TicketCaption")
	cap.custom_minimum_size = Vector2(88, 0)
	row.add_child(cap)
	var value := HBoxContainer.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_constant_override("separation", 6)
	for n: Control in value_nodes:
		value.add_child(n)
	row.add_child(value)
	return row


## [swatch, name] for an ingredient, or a dash label if empty.
func _ingredient_line(id: StringName, empty_text: String = "—") -> Array:
	var ing := GameState.catalog.ingredient(id) if id != &"" else null
	if ing == null:
		return [_label(empty_text, &"TicketBody")]
	var name_label := _label(ing.display_name, &"TicketBody")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return [Swatch.make(ing.color, 16.0, Art.ingredient(ing.id)), name_label]


func _topper_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for i in Order.TOPPER_SLOTS:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		var ing := GameState.catalog.ingredient(order.toppers[i]) if order.toppers[i] != &"" else null
		if ing:
			cell.add_child(Swatch.make(ing.color, 14.0, Art.ingredient(ing.id)))
			var l := _label(ing.display_name, &"TicketBody")
			l.add_theme_font_size_override("font_size", 16)
			cell.add_child(l)
		else:
			var empty := _label("·  empty", &"TicketBody")
			empty.add_theme_font_size_override("font_size", 16)
			empty.add_theme_color_override("font_color", INK_2)
			cell.add_child(empty)
		grid.add_child(cell)
	return grid


func _zap_meter() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_label("ZAP", &"TicketCaption"))
	for i in 3:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(22, 10)
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seg.color = Color("3ee6f0").darkened(0.25) if i == order.zap_level else LINE
		row.add_child(seg)
	return row


func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 2)
	r.color = LINE
	return r


## Pink "CRITIC" stamp so a critic's ticket stands out on the rail.
func _critic_tag() -> Label:
	var tag := Label.new()
	tag.text = "CRITIC"
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("c2185b")
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	tag.add_theme_stylebox_override("normal", sb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tag


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


## A small ingredient icon, or a round colour chip when there's no art yet.
class Swatch extends Control:
	var color := Color.WHITE
	var tex: Texture2D

	static func make(c: Color, diameter: float, icon: Texture2D = null) -> Swatch:
		var s := Swatch.new()
		s.color = c
		s.tex = icon
		if icon:
			diameter *= 1.6
		s.custom_minimum_size = Vector2(diameter, diameter)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return s

	func _draw() -> void:
		if tex:
			Art.draw_fit(self, tex, Rect2(Vector2.ZERO, size))
			return
		var r := minf(size.x, size.y) / 2
		draw_circle(size / 2, r, color)
		draw_arc(size / 2, r, 0, TAU, 20, Color(0.17, 0.16, 0.31, 0.6), 1.5, true)
