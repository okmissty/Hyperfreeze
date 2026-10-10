class_name StationTabButton
extends Button
## One tab in the bottom bar. Hovering it while dragging a ticket switches
## to that station (spring-loaded), and dropping clips the ticket there.

@export var station_id: StringName = StationIds.ORDER

var _badge: Label


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = &"TabButton"
	text = StationIds.display_name(station_id)
	var tab_icon := UiSkin.tex("icon_tab_%s" % String(station_id).to_lower())
	if tab_icon:
		icon = tab_icon
		add_theme_constant_override("icon_max_width", 50)
		add_theme_constant_override("h_separation", 12)
	pressed.connect(func() -> void: Events.request_station.emit(station_id))

	_badge = Label.new()
	_badge.theme_type_variation = &"BadgeLabel"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.anchor_left = 1.0
	_badge.anchor_right = 1.0
	_badge.offset_left = -64.0
	_badge.offset_right = -8.0
	_badge.offset_top = -14.0
	_badge.offset_bottom = 16.0
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.visible = false
	add_child(_badge)


func set_badge(badge_text: String) -> void:
	_badge.text = badge_text
	_badge.visible = badge_text != ""


## Hovering a ticket over its own station's tab jumps there (spring-loaded).
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not Ticket.is_ticket_data(data):
		return false
	var order: Order = data["order"]
	if station_id == StationIds.ORDER and order.cup and order.cup.location == StationIds.READY:
		if not button_pressed:
			Events.request_station.emit(station_id)
		return true  # dropping a ready ticket on Order serves it
	if not StationIds.accepts_tickets(station_id):
		return false
	if not DayManager.can_clip(data["order"], station_id):
		return false
	if not button_pressed:
		Events.request_station.emit(station_id)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var order: Order = data["order"]
	if station_id == StationIds.ORDER:
		Events.serve_requested.emit(order)
	else:
		DayManager.move_ticket(order, station_id)
