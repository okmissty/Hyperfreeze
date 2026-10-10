class_name TicketRail
extends PanelContainer
## The ticket rail along the top of every station. It only *shows* the
## tickets DayManager says are on the rail; moving them goes through
## DayManager.move_ticket().

const SPACING := 16.0
const TOP_MARGIN := 2.0

var _views: Dictionary = {}  # Order -> Ticket
var _current_station: StringName = StationIds.ORDER
var _drop_hover := false

@onready var _track: Control = %Track
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	add_to_group(&"ticket_rail")
	UiSkin.follow_theme(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Events.ticket_moved.connect(_on_ticket_moved)
	Events.day_started.connect(func(_day: int) -> void: _rebuild())
	Events.station_changed.connect(func(id: StringName) -> void: _current_station = id)
	_track.resized.connect(_layout)
	_rebuild()


## Where the next printed ticket will land, for the fly-in animation.
func next_slot_global_position() -> Vector2:
	var count := DayManager.tickets_at(StationIds.RAIL).size()
	var x := minf(count * (Ticket.COMPACT_SIZE.x + SPACING), maxf(_track.size.x - Ticket.COMPACT_SIZE.x, 0.0))
	return _track.global_position + Vector2(x, TOP_MARGIN)


func _on_ticket_moved(order: Order, from_location: StringName, to_location: StringName) -> void:
	if from_location == StationIds.RAIL or to_location == StationIds.RAIL:
		_rebuild(order if (to_location == StationIds.RAIL and from_location == StationIds.PRINTING) else null)


func _rebuild(just_printed: Order = null) -> void:
	var on_rail := DayManager.tickets_at(StationIds.RAIL)
	for key: Order in _views.keys():
		if key not in on_rail:
			(_views[key] as Ticket).queue_free()
			_views.erase(key)
	for order: Order in on_rail:
		if _views.has(order):
			continue
		var t := Ticket.create(order, true)
		t.tapped.connect(_on_ticket_tapped)
		_track.add_child(t)
		_views[order] = t
		if order == just_printed:
			t.scale = Vector2(0.6, 0.6)
			t.create_tween().tween_property(t, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.flash_new()
	_empty_label.visible = on_rail.is_empty()
	_layout()


## Lays tickets left to right, overlapping them when the rail gets crowded.
func _layout() -> void:
	var on_rail := DayManager.tickets_at(StationIds.RAIL)
	var n := on_rail.size()
	var step := Ticket.COMPACT_SIZE.x + SPACING
	if n > 1:
		step = minf(step, maxf(_track.size.x - Ticket.COMPACT_SIZE.x, 0.0) / (n - 1))
	for i in n:
		var t: Ticket = _views.get(on_rail[i])
		if t == null:
			continue
		t.position = Vector2(i * step, TOP_MARGIN)
		t.rotation_degrees = float((on_rail[i].ticket_number * 37) % 5 - 2) * 0.8
		_track.move_child(t, i)


## Tap clips the ticket here if this is its stage; otherwise wiggle and say where it belongs.
func _on_ticket_tapped(ticket: Ticket) -> void:
	var order := ticket.order
	if order.cup and order.cup.location == StationIds.READY:
		if _current_station == StationIds.ORDER:
			Events.serve_requested.emit(order)
		else:
			ticket.wiggle()
			Events.toast.emit("Serve #%d at the Order Station" % order.ticket_number)
		return
	if StationIds.accepts_tickets(_current_station) and DayManager.move_ticket(order, _current_station):
		return
	ticket.wiggle()
	Events.toast.emit(DayManager.clip_refusal(ticket.order, _current_station))


# --- Drop target --------------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := Ticket.is_ticket_data(data)
	_set_drop_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	DayManager.move_ticket(data["order"], StationIds.RAIL)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_drop_hover(false)


func _set_drop_hover(on: bool) -> void:
	if _drop_hover == on:
		return
	_drop_hover = on
	self_modulate = Color(1.25, 1.25, 1.4) if on else Color.WHITE


func _draw() -> void:
	# The rail wire the tickets hang from.
	var y := 14.0
	var bar := UiSkin.scaled("ui_rail", 0.6)
	if bar:
		var sb := UiSkin.box(bar, Vector4(44, 18, 44, 18))
		draw_style_box(sb, Rect2(Vector2(4, y - 22), Vector2(size.x - 8, 50)))
		return
	draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color("ffd95a", 0.7), 4.0, true)
