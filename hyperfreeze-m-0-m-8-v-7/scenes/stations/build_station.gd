extends BaseStation
## M3 — Build Station. With a ticket clipped here: pick a cup size, hold a
## base tap to pour up to the fill line, tap bins to add mix-ins, then send
## the cup to the Zap Station (the ticket follows it).

## Fraction of the cup filled per second while a tap is held (0.8 takes 2.5 s).
const POUR_RATE := 0.32
## How close to the fill line counts as "right on the line".
const FILL_TOLERANCE := 0.04

var _order: Order
var _pouring_base: StringName = &""

@onready var _slot: TicketSlot = %TicketSlot
@onready var _size_buttons: Array[SizeButton] = [%Small, %Medium, %Large]
@onready var _taps: GridContainer = %Taps
@onready var _mix_grid: GridContainer = %MixGrid
@onready var _cup_view: CupView = %CupView
@onready var _fill_label: Label = %FillLabel
@onready var _status: Label = %Status
@onready var _trash: Button = %Trash
@onready var _send: Button = %Send


func _ready() -> void:
	add_backdrop("build")
	_slot.station_id = station_id
	_slot.refresh()
	for i in _size_buttons.size():
		_size_buttons[i].pressed.connect(_on_size_picked.bind(i))
	_trash.pressed.connect(_on_trash)
	_send.pressed.connect(_on_send)
	_cup_view.show_fill_line = true
	_cup_view.fit_cup = true
	Events.ticket_moved.connect(_on_ticket_moved)
	Events.cup_moved.connect(_on_cup_moved)
	Events.day_started.connect(_on_day_started)
	Events.rank_changed.connect(_on_rank_changed)
	_build_ingredient_buttons()
	_refresh()


func on_exit() -> void:
	_stop_pour()


# --- Events -------------------------------------------------------------------

func _on_ticket_moved(_o: Order, from_location: StringName, to_location: StringName) -> void:
	if from_location == station_id or to_location == station_id:
		_refresh()


func _on_cup_moved(order: Order, _from: StringName, _to: StringName) -> void:
	if order == _order:
		_refresh()


func _on_day_started(_day: int) -> void:
	_refresh()


func _on_rank_changed(_rank: int) -> void:
	_build_ingredient_buttons()
	_refresh()


# --- Building the controls ----------------------------------------------------

func _build_ingredient_buttons() -> void:
	for child in _taps.get_children():
		child.queue_free()
	for child in _mix_grid.get_children():
		child.queue_free()
	var rank := GameState.get_rank()
	for base: IngredientData in GameState.catalog.unlocked(IngredientData.Category.BASE, rank):
		var tap := IngredientButton.make(base)
		tap.custom_minimum_size = Vector2(0, 56)
		tap.backdrop_prefix = "st_build_tap"
		tap.add_to_group(&"silent_button")
		tap.button_down.connect(_start_pour.bind(base.id))
		tap.button_up.connect(_stop_pour)
		_taps.add_child(tap)
	for mix: IngredientData in GameState.catalog.unlocked(IngredientData.Category.MIXIN, rank):
		var bin := IngredientButton.make(mix, true)
		bin.custom_minimum_size = Vector2(0, 56)
		bin.backdrop_prefix = "st_build_bin"
		bin.pressed.connect(_on_mixin.bind(mix.id))
		_mix_grid.add_child(bin)


## The cup on this counter: the clipped order's cup, if it is still here.
func _cup() -> CupState:
	if _order and _order.cup and _order.cup.location == StationIds.BUILD:
		return _order.cup
	return null


func _refresh() -> void:
	_stop_pour()
	_order = DayManager.ticket_at(station_id)
	var cup := _cup()
	var can_pick := _order != null and _order.cup == null
	for b: SizeButton in _size_buttons:
		b.disabled = not can_pick
		b.queue_redraw()
	for child in _taps.get_children():
		(child as Button).disabled = cup == null
	for child in _mix_grid.get_children():
		var bin := child as IngredientButton
		if bin == null:
			continue
		bin.disabled = cup == null
		bin.set_pressed_no_signal(cup != null and bin.ingredient_id in cup.mixin_ids)
	_trash.disabled = cup == null
	_send.disabled = cup == null or cup.fill_amount <= 0.0
	_cup_view.cup = cup
	_cup_view.empty_text = "" if cup else ("Pick a cup" if can_pick else "")
	_status.text = _status_text()
	_update_fill_label()


func _status_text() -> String:
	if _order == null:
		return "Clip a ticket from the rail to start a cup"
	var tag := "#%d" % _order.ticket_number
	if _order.cup == null:
		return "%s: pick a cup size" % tag
	match StationIds.station_for_cup(_order.cup.location):
		StationIds.BUILD:
			return "Building %s for %s" % [tag, _order.customer.display_name]
		StationIds.ZAP:
			return "%s is at the Zap Station" % tag
		StationIds.TOP:
			return "%s is at the Top Station" % tag
		StationIds.READY:
			return "%s is ready to serve" % tag
	return ""


func _update_fill_label() -> void:
	var cup := _cup()
	_fill_label.remove_theme_color_override("font_color")
	if cup == null:
		_fill_label.text = ""
		return
	var diff := cup.fill_amount - CupState.TARGET_FILL
	if cup.fill_amount <= 0.0:
		_fill_label.text = "Hold a tap to pour"
	elif diff < -FILL_TOLERANCE:
		_fill_label.text = "Keep pouring..."
	elif diff <= FILL_TOLERANCE:
		_fill_label.text = "Right on the line!"
		_fill_label.add_theme_color_override("font_color", Color("7be07b"))
	else:
		_fill_label.text = "Overfilled!"
		_fill_label.add_theme_color_override("font_color", Color("ff7eb6"))


# --- Actions ------------------------------------------------------------------

func _on_size_picked(cup_size: int) -> void:
	if _order and _order.cup == null:
		DayManager.start_cup(_order, cup_size)


func _start_pour(base_id: StringName) -> void:
	if _cup():
		_pouring_base = base_id
		AudioManager.start_loop("pour_loop")


func _stop_pour() -> void:
	if _pouring_base == &"":
		return
	_pouring_base = &""
	AudioManager.stop_loop("pour_loop")
	if _order:
		Events.cup_changed.emit(_order)


func _process(delta: float) -> void:
	if _pouring_base == &"":
		return
	var cup := _cup()
	if cup == null:
		_stop_pour()
		return
	cup.pour(_pouring_base, POUR_RATE * GameState.pour_mult() * delta)
	_cup_view.queue_redraw()
	_update_fill_label()
	_send.disabled = false
	if cup.fill_amount >= CupState.MAX_FILL:
		_stop_pour()


func _on_mixin(id: StringName) -> void:
	var cup := _cup()
	if cup == null:
		return
	cup.toggle_mixin(id)
	AudioManager.play("plunk")
	_cup_view.queue_redraw()
	Events.cup_changed.emit(_order)


func _on_trash() -> void:
	if _cup():
		DayManager.trash_cup(_order)


func _on_send() -> void:
	if _cup() == null:
		return
	var order := _order
	DayManager.move_cup(order, StationIds.ZAP_SHELF)
	DayManager.ticket_follow_cup(order, station_id, StationIds.ZAP)
	if GameState.get_setting("follow_cup"):
		Events.request_station.emit(StationIds.ZAP)
