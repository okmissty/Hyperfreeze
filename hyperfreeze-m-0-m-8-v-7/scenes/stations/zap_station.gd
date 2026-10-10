extends BaseStation
## M4 — Zap Station. Cups sent from Build wait on the shelf; tap one to load
## a Hyperfreeze Blender, pick the zap level from the ticket, hold to blend
## and release inside the band. Finished cups go to the Top Station shelf.

var _blenders: Array[Blender] = []

@onready var _slot: TicketSlot = %TicketSlot
@onready var _shelf: VBoxContainer = %Shelf
@onready var _empty_shelf: Label = %EmptyShelf
@onready var _blender_row: HBoxContainer = %Blenders


func _ready() -> void:
	add_backdrop("zap")
	_slot.station_id = station_id
	_slot.refresh()
	Events.cup_moved.connect(_on_cup_moved)
	Events.day_started.connect(_on_day_started)
	Events.upgrades_changed.connect(_sync_blender_count)
	_build_blenders()
	_refresh_shelf()


func on_exit() -> void:
	for b: Blender in _blenders:
		b.cancel_hold()


func _build_blenders() -> void:
	for child in _blender_row.get_children():
		child.queue_free()
	_blenders.clear()
	for i in GameState.blender_count:
		var b := Blender.new()
		b.index = i
		b.became_free.connect(_on_blender_free)
		_blender_row.add_child(b)
		_blenders.append(b)


func _on_day_started(_day: int) -> void:
	if _blenders.size() != GameState.blender_count:
		_build_blenders()  # a second blender was bought in the shop
	for b: Blender in _blenders:
		b.reset()
	_refresh_shelf()


func _on_cup_moved(order: Order, from_location: StringName, to_location: StringName) -> void:
	if from_location == StationIds.ZAP_SHELF or to_location == StationIds.ZAP_SHELF or from_location == &"" or to_location == &"":
		_refresh_shelf()
	if to_location == StationIds.ZAP_SHELF and GameState.get_setting("follow_cup"):
		_auto_load.call_deferred(order)


## Follow the cup: a newly arrived cup goes straight into a free blender.
func _auto_load(order: Order) -> void:
	if order.cup and order.cup.location == StationIds.ZAP_SHELF:
		_on_cup_picked(order)


## A second blender bought mid-shift: rebuild once both machines are idle,
## so a cup that's blending never gets interrupted.
func _sync_blender_count() -> void:
	if _blenders.size() == GameState.blender_count:
		return
	for b: Blender in _blenders:
		if not b.is_free():
			return  # tried again when that blender frees up
	_build_blenders()
	_refresh_shelf()


func _on_blender_free(_b: Blender) -> void:
	_sync_blender_count.call_deferred()
	if GameState.get_setting("follow_cup"):
		var waiting := DayManager.cups_at(StationIds.ZAP_SHELF)
		if not waiting.is_empty():
			_auto_load.call_deferred(waiting[0])


func _refresh_shelf() -> void:
	for child in _shelf.get_children():
		child.queue_free()
	var waiting := DayManager.cups_at(StationIds.ZAP_SHELF)
	for order: Order in waiting:
		var item := ShelfCup.make(order)
		item.picked.connect(_on_cup_picked)
		_shelf.add_child(item)
	_empty_shelf.visible = waiting.is_empty()


func _on_cup_picked(order: Order) -> void:
	for b: Blender in _blenders:
		if b.is_free():
			b.load_cup(order)
			return
