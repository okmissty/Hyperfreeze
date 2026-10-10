class_name ShelfCup
extends Control
## A cup waiting on a station shelf. Tap it to bring it to the machine/counter.

signal picked(order: Order)

var order: Order
var _hover := false


static func make(for_order: Order) -> ShelfCup:
	var s := ShelfCup.new()
	s.order = for_order
	return s


func _ready() -> void:
	custom_minimum_size = Vector2(200, 132)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		picked.emit(order)
		accept_event()


func _draw() -> void:
	var bg := Color("2e3270") if _hover else Color("23265a")
	draw_style_box(_box(bg), Rect2(Vector2.ZERO, size))
	if order == null or order.cup == null:
		return
	CupPainter.draw_cup(self, Rect2(Vector2(6, 8), Vector2(96, size.y - 16)), order.cup)
	var font := get_theme_default_font()
	draw_string(font, Vector2(104, 52), "#%d" % order.ticket_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("ffd95a"))
	var who := order.customer.display_name if order.customer else ""
	draw_string(font, Vector2(104, 84), who, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 20, Color("b9b4e0"))
	draw_string(font, Vector2(104, 112), "Tap to load", HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 16, Color("3ee6f0", 0.8))


static func _box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(16)
	return sb
