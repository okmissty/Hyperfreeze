extends BaseStation
## The Order Station: customers line up at the counter, the player taps
## "Take Order", the customer says what they want, a ticket prints and
## flies up to the rail, and the customer moves to the lobby to wait.

const CUSTOMER_SCENE := preload("res://scenes/entities/customer.tscn")
const ORDER_TALK_SECONDS := 1.3
const QUEUE_SPACING := 175.0
const LOBBY_COLUMNS := 4
const LOBBY_SPACING := 175.0

var _queue: Array[Customer] = []   # front of the line first
var _lobby: Array[Customer] = []
var _taking_order := false
## Order -> Customer, for customers walking up to be served or waiting on the score card.
var _serving: Dictionary = {}
var _has_art := false
var _counter_art: TextureRect
var _sign_art: TextureRect
var _airlock_art: TextureRect
var _airlock_tween: Tween
## slot -> DecorItem on display in the lobby.
var _decor_items: Dictionary = {}

@onready var _customers: Control = %Customers
@onready var _counter: Panel = %Counter
@onready var _printer: Panel = %Printer
@onready var _take_order_button: Button = %TakeOrderButton
@onready var _idle_hint: Label = %IdleHint


func _ready() -> void:
	Events.customer_arrived.connect(_on_customer_arrived)
	Events.day_started.connect(_on_day_started)
	Events.serve_requested.connect(serve)
	Events.score_card_closed.connect(_on_score_card_closed)
	mouse_filter = Control.MOUSE_FILTER_PASS  # catches ready tickets dropped anywhere here
	_take_order_button.pressed.connect(_on_take_order_pressed)
	_setup_art()
	_setup_decor()
	resized.connect(_relayout)
	Events.theme_changed.connect(func(_id: String) -> void: _apply_theme())
	_apply_theme()
	_take_order_button.visible = false
	_update_hint()


# --- Layout helpers (all positions are feet positions in this station) --------

func _counter_top() -> float:
	return _counter.position.y


func _queue_spot(index: int) -> Vector2:
	return Vector2(_counter.position.x + _counter.size.x * 0.28 + index * QUEUE_SPACING, _counter_top() + 24.0)


## Where a customer steps up to collect their treat (left end of the counter).
func _serve_spot() -> Vector2:
	return Vector2(_counter.position.x - 175.0, size.y - 40.0)


func _door_spot() -> Vector2:
	return Vector2(size.x + 160.0, _counter_top() + 24.0)


@warning_ignore("integer_division")
func _lobby_spot(index: int) -> Vector2:
	var row := index / LOBBY_COLUMNS
	var col := index % LOBBY_COLUMNS
	var x := 150.0 + col * LOBBY_SPACING + (row % 2) * LOBBY_SPACING * 0.5
	var y := size.y - 28.0 - row * 120.0
	return Vector2(x, y)


## Snap everyone to their spots when the window size changes.
func _relayout() -> void:
	_layout_art()
	_layout_decor()
	for i in _queue.size():
		if _queue[i].state != Customer.State.ARRIVING:
			_queue[i].place_at(_queue_spot(i))
	for i in _lobby.size():
		_lobby[i].place_at(_lobby_spot(i))
	_place_take_order_button()
	_sort_by_depth()


func _place_take_order_button() -> void:
	var spot := _queue_spot(0)
	_take_order_button.reset_size()
	var bsize := _take_order_button.size
	_take_order_button.position = Vector2(spot.x - bsize.x / 2.0, _counter_top() + (_counter.size.y - bsize.y) / 2.0 + 30.0)


## Customers lower on screen draw in front.
func _sort_by_depth() -> void:
	var all: Array[Node] = _customers.get_children()
	all.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Customer).feet_position().y < (b as Customer).feet_position().y)
	for i in all.size():
		_customers.move_child(all[i], i)


# --- Arrivals & queue ---------------------------------------------------------

func _on_day_started(_day: int) -> void:
	for c in _customers.get_children():
		c.queue_free()
	_queue.clear()
	_lobby.clear()
	_serving.clear()
	_taking_order = false
	_take_order_button.visible = false
	_update_hint()


func _on_customer_arrived(data: CustomerData) -> void:
	var c: Customer = CUSTOMER_SCENE.instantiate()
	c.setup(data)
	c.arrived_at = DayManager.time_elapsed
	_customers.add_child(c)
	c.place_at(_door_spot())
	_queue.append(c)
	c.begin_waiting(Customer.State.ARRIVING, data.patience_seconds * GameState.patience_mult())
	c.reached_destination.connect(_on_customer_reached)
	c.walk_to(_queue_spot(_queue.size() - 1))
	_sort_by_depth()
	_update_hint()
	_cycle_airlock()


func _on_customer_reached(c: Customer) -> void:
	match c.state:
		Customer.State.ARRIVING:
			if c in _queue:
				# Patience started counting at the door; keep that start time.
				c.state = Customer.State.WAITING_TO_ORDER
		Customer.State.SERVING:
			_hand_over(c)
		Customer.State.LEAVING:
			var data := c.data
			c.queue_free()
			DayManager.customer_left(data)
	_update_take_order_button()


func _advance_queue() -> void:
	for i in _queue.size():
		_queue[i].walk_to(_queue_spot(i))


func _front_customer() -> Customer:
	return _queue[0] if not _queue.is_empty() else null


func _update_take_order_button() -> void:
	var front := _front_customer()
	var can_take := front != null and front.state == Customer.State.WAITING_TO_ORDER and not _taking_order
	if can_take and not _take_order_button.visible:
		_place_take_order_button()
		_take_order_button.visible = true
		_take_order_button.scale = Vector2(0.7, 0.7)
		_take_order_button.pivot_offset = _take_order_button.size / 2.0
		_take_order_button.create_tween().tween_property(_take_order_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not can_take:
		_take_order_button.visible = false


func _update_hint() -> void:
	_idle_hint.visible = _queue.is_empty()


# --- Taking an order ----------------------------------------------------------

func _on_take_order_pressed() -> void:
	var c := _front_customer()
	if c == null or c.state != Customer.State.WAITING_TO_ORDER or _taking_order:
		return
	_taking_order = true
	_take_order_button.visible = false

	# The customer tells you their order (bubble shows their favourite).
	c.show_order_bubble(GameState.get_favorite(c.data))
	await get_tree().create_timer(ORDER_TALK_SECONDS).timeout
	if not is_instance_valid(c) or c not in _queue:
		_taking_order = false
		return
	c.hide_order_bubble()

	var order := DayManager.create_order(c.data, c.arrived_at)
	c.order = order
	_queue.erase(c)
	_lobby.append(c)
	c.begin_waiting(Customer.State.WAITING_FOR_FOOD, c.data.patience_seconds * Scorer.FOOD_PATIENCE_MULT * GameState.patience_mult())
	c.walk_to(_lobby_spot(_lobby.size() - 1))
	_advance_queue()
	_sort_by_depth()
	_update_hint()
	_print_ticket(order)

	_taking_order = false
	_update_take_order_button()


## Ticket pops out of the printer, then flies up to the rail.
func _print_ticket(order: Order) -> void:
	var fx := get_tree().get_first_node_in_group(&"fx_layer") as Control
	var rail := get_tree().get_first_node_in_group(&"ticket_rail") as TicketRail
	if fx == null or rail == null:
		DayManager.move_ticket(order, StationIds.RAIL)
		return

	var t := Ticket.create(order, true)
	t.draggable = false
	fx.add_child(t)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var printer_top := _printer.global_position + Vector2(_printer.size.x / 2.0 - Ticket.COMPACT_SIZE.x / 2.0, 0)
	t.global_position = printer_top + Vector2(0, 20)
	t.modulate.a = 0.0

	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(t, "global_position", printer_top - Vector2(0, Ticket.COMPACT_SIZE.y + 10), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		var target := rail.next_slot_global_position()
		var fly := t.create_tween()
		fly.tween_property(t, "global_position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		fly.parallel().tween_property(t, "rotation_degrees", -8.0, 0.2)
		fly.tween_callback(func() -> void:
			t.queue_free()
			DayManager.move_ticket(order, StationIds.RAIL)))


# --- Serving ------------------------------------------------------------------

## Serves a ready order: its customer walks up to the counter, the treat is
## graded, and they leave once the score card is closed.
func serve(order: Order) -> void:
	if _serving.has(order) or order.cup == null or order.cup.location != StationIds.READY:
		return
	var c: Customer = null
	for lobby_customer: Customer in _lobby:
		if lobby_customer.order == order:
			c = lobby_customer
	if c == null:
		DayManager.serve_order(order)
		return
	_serving[order] = c
	_lobby.erase(c)
	for i in _lobby.size():
		_lobby[i].walk_to(_lobby_spot(i))
	c.state = Customer.State.SERVING
	c.walk_to(_serve_spot())
	_sort_by_depth()


func _hand_over(c: Customer) -> void:
	var result: Scorer.Result = DayManager.serve_order(c.order)
	if result:
		c.react(result.total, result.rating)


func _on_score_card_closed(order: Order) -> void:
	var c: Customer = _serving.get(order)
	if c == null:
		return
	_serving.erase(order)
	c.state = Customer.State.LEAVING
	c.walk_to(_door_spot())


## Drop a ready ticket anywhere on the Order Station to serve it.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return Ticket.is_ticket_data(data) and data["order"].cup != null and data["order"].cup.location == StationIds.READY


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	serve(data["order"])


## The floor takes the café theme's colour.
func _apply_theme() -> void:
	(get_node("Floor") as ColorRect).visible = not _has_art
	(get_node("Floor") as ColorRect).color = GameState.theme_colors().get("floor", Color(0.098, 0.078, 0.247, 0.94))


# --- Drawn art ------------------------------------------------------------------

## Swaps the placeholder panels for Ty's art when it exists: painted lounge,
## neon sign, airlock door, rug, counter and printer. Node positions stay
## the same, so customers and tickets still line up.
func _setup_art() -> void:
	_has_art = add_backdrop("order", false)
	if not _has_art:
		return
	var empty := StyleBoxEmpty.new()
	# Neon sign replaces the title text; it switches off at closing time.
	var sign_on := Art.station("st_order_sign_on")
	if sign_on:
		(get_node("Sign") as Label).visible = false
		(get_node("SignSub") as Label).visible = false
		_sign_art = _art_rect(sign_on, TextureRect.STRETCH_KEEP_ASPECT)
		_sign_art.position = Vector2(36, 8)
		_sign_art.size = Vector2(520, 190)
		add_child(_sign_art)
		move_child(_sign_art, backdrop.get_index() + 1)
		Events.shop_closed.connect(func() -> void: _set_sign(false))
		Events.day_started.connect(func(_d: int) -> void: _set_sign(true))
	var rug := Art.station("st_order_rug")
	var mat := get_node("LobbyMat") as Panel
	if rug:
		mat.add_theme_stylebox_override("panel", empty)
		var r := _art_rect(rug, TextureRect.STRETCH_SCALE)
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		mat.add_child(r)
		mat.move_child(r, 0)
	# Light painted floor: give the lobby caption an outline so it reads.
	# The rug says "lobby" on its own; the caption only collided with name tags.
	var lobby_label := mat.get_node_or_null("LobbyLabel") as Label
	if lobby_label:
		lobby_label.visible = false
	# Idle hint: above the counter, outlined so it reads on the light lounge.
	_idle_hint.add_theme_color_override("font_color", Color("f4f1ff"))
	_idle_hint.add_theme_color_override("font_outline_color", Color("0b0d2a"))
	_idle_hint.add_theme_constant_override("outline_size", 8)
	_idle_hint.offset_top = -420.0
	_idle_hint.offset_bottom = -350.0
	var door := Art.station("st_order_airlock_01")
	var airlock := get_node("Airlock") as Panel
	if door:
		airlock.add_theme_stylebox_override("panel", empty)
		_airlock_art = _art_rect(door, TextureRect.STRETCH_KEEP_ASPECT)
		_airlock_art.size = Vector2(250, 255)
		_airlock_art.position = Vector2(airlock.size.x - 16.0 - 250.0, airlock.size.y - 255.0)
		airlock.add_child(_airlock_art)
	var counter_tex := Art.station("st_order_counter_wide")
	if counter_tex:
		_counter.add_theme_stylebox_override("panel", empty)
		_counter_art = _art_rect(counter_tex, TextureRect.STRETCH_SCALE)
		_counter_art.flip_h = true  # monitor at the far end, printer at the near end
		_counter.add_child(_counter_art)
		_counter.move_child(_counter_art, 0)
	var printer_tex := Art.station("st_order_printer")
	if printer_tex:
		_printer.add_theme_stylebox_override("panel", empty)
		(_printer.get_node("PrinterLabel") as Label).visible = false
		var p := _art_rect(printer_tex, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		p.position = Vector2(20, -8)
		p.size = Vector2(130, 140)
		_printer.add_child(p)
	_apply_theme()
	_layout_art()


func _art_rect(tex: Texture2D, mode: TextureRect.StretchMode) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = mode
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The counter art is taller than the counter panel (its monitor pokes up).
func _layout_art() -> void:
	if _counter_art == null:
		return
	var tex_size := _counter_art.texture.get_size()
	var h := _counter.size.x * tex_size.y / tex_size.x
	_counter_art.position = Vector2(0, _counter.size.y - h)
	_counter_art.size = Vector2(_counter.size.x, h)


func _set_sign(lit: bool) -> void:
	var tex := Art.station("st_order_sign_on" if lit else "st_order_sign_off")
	if _sign_art and tex:
		_sign_art.texture = tex


## Door slides open for each arrival, then closes.
func _cycle_airlock() -> void:
	if _airlock_art == null:
		return
	var frames: Array[Texture2D] = []
	for i in 3:
		frames.append(Art.station("st_order_airlock_%02d" % (i + 1)))
	if frames.has(null):
		return
	if _airlock_tween:
		_airlock_tween.kill()
	_airlock_tween = create_tween()
	_airlock_tween.tween_callback(func() -> void: _airlock_art.texture = frames[1])
	_airlock_tween.tween_interval(0.12)
	_airlock_tween.tween_callback(func() -> void: _airlock_art.texture = frames[2])
	_airlock_tween.tween_interval(1.4)
	_airlock_tween.tween_callback(func() -> void: _airlock_art.texture = frames[1])
	_airlock_tween.tween_interval(0.12)
	_airlock_tween.tween_callback(func() -> void: _airlock_art.texture = frames[0])


# --- Lobby decor ------------------------------------------------------------------

## Where each decor spot sits (station coordinates; the counter spot is on
## the counter top, so it draws in front of the queue).
func _decor_rect(slot: String) -> Rect2:
	match slot:
		"wall": return Rect2(610, 60, 150, 190)
		"corner": return Rect2(24, 190, 160, 210)
		"floor": return Rect2(764, 200, 140, 200)
		"counter": return Rect2(190, -64, 80, 96)  # counter-local
	return Rect2()


func _setup_decor() -> void:
	for slot: String in Upgrades.SLOTS:
		var item := DecorItem.new()
		item.name = "Decor_" + slot
		if slot == "counter":
			_counter.add_child(item)
		else:
			add_child(item)
			move_child(item, _customers.get_index())  # behind the customers
		item.gui_input.connect(_on_decor_input.bind(slot))
		_decor_items[slot] = item
	Events.decor_changed.connect(_refresh_decor)
	_refresh_decor()


func _refresh_decor() -> void:
	for slot: String in _decor_items:
		var item: DecorItem = _decor_items[slot]
		var id := String(GameState.decor_placed.get(slot, ""))
		item.decor_id = id
		item.visible = id != ""
		var clickable := id == Upgrades.JUKEBOX
		item.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		item.tooltip_text = "Tap to switch the café music" if clickable else ""
	_layout_decor()
	AudioManager.play_music(GameState.cafe_music())


func _layout_decor() -> void:
	for slot: String in _decor_items:
		var item: DecorItem = _decor_items[slot]
		var r := _decor_rect(slot)
		item.position = r.position
		item.size = r.size


## The jukebox switches between the calm loop and its own track.
func _on_decor_input(event: InputEvent, slot: String) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and GameState.decor_placed.get(slot, "") == Upgrades.JUKEBOX:
		GameState.set_setting("cafe_track", 1 - int(GameState.get_setting("cafe_track")))
		AudioManager.play_music(GameState.cafe_music())
		Events.toast.emit("Jukebox: " + ("lo-fi jazz" if int(GameState.get_setting("cafe_track")) == 1 else "calm café"))
