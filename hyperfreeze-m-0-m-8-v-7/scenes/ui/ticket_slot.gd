class_name TicketSlot
extends Control
## The ticket holder at Build, Zap and Top. Shows the full ticket for
## whatever order DayManager has clipped to this station.

@export var station_id: StringName = StationIds.BUILD

var _ticket: Ticket
var _drop_hover := false

@onready var _hint: Label = %Hint
@onready var _holder: MarginContainer = %Holder


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.add_theme_color_override("font_color", Color(0.956863, 0.945098, 1, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.16, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	Events.ticket_moved.connect(_on_ticket_moved)
	Events.day_started.connect(func(_day: int) -> void: refresh())
	refresh()


func current_order() -> Order:
	return DayManager.ticket_at(station_id)


func _on_ticket_moved(_order: Order, from_location: StringName, to_location: StringName) -> void:
	if from_location == station_id or to_location == station_id:
		refresh()


func refresh() -> void:
	var order := current_order()
	if _ticket and (order == null or _ticket.order != order):
		_ticket.queue_free()
		_ticket = null
	if order and _ticket == null:
		_ticket = Ticket.create(order, false)
		_ticket.tapped.connect(func(_t: Ticket) -> void: DayManager.move_ticket(order, StationIds.RAIL))
		_holder.add_child(_ticket)
	_hint.visible = order == null
	queue_redraw()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := Ticket.is_ticket_data(data) and DayManager.can_clip(data["order"], station_id)
	_set_drop_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	DayManager.move_ticket(data["order"], station_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_drop_hover(false)


func _set_drop_hover(on: bool) -> void:
	if _drop_hover != on:
		_drop_hover = on
		queue_redraw()


func _draw() -> void:
	var frame := UiSkin.ticket_slot_box(_drop_hover)
	if frame:
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		return
	if _ticket and not _drop_hover:
		return
	var col := Color("3ee6f0") if _drop_hover else Color("b9b4e0", 0.5)
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], col, 3.0, 14.0)
	if _drop_hover:
		draw_rect(r, Color(col, 0.08))
