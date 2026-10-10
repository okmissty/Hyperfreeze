extends PanelContainer
## Bottom bar with the four station tabs and their badges.

var _buttons: Dictionary = {}  # StringName -> StationTabButton

@onready var _row: HBoxContainer = %Row


func _ready() -> void:
	UiSkin.follow_theme(self)
	var group := ButtonGroup.new()
	for child in _row.get_children():
		var tab := child as StationTabButton
		if tab:
			tab.button_group = group
			_buttons[tab.station_id] = tab
	Events.station_changed.connect(_on_station_changed)
	Events.queue_changed.connect(_on_queue_changed)
	Events.ticket_moved.connect(func(_o: Order, _f: StringName, _t: StringName) -> void: _refresh_ticket_badges())
	Events.day_started.connect(func(_d: int) -> void: _refresh_ticket_badges())
	Events.cup_moved.connect(func(_o: Order, _f: StringName, _t: StringName) -> void: _refresh_ticket_badges())


func _on_station_changed(station_id: StringName) -> void:
	for id: StringName in _buttons:
		(_buttons[id] as StationTabButton).set_pressed_no_signal(id == station_id)


func _on_queue_changed(waiting: int) -> void:
	var tab: StationTabButton = _buttons.get(StationIds.ORDER)
	if tab:
		tab.set_badge(str(waiting) if waiting > 0 else "")


## Build shows the clipped ticket; Zap and Top show how many cups wait there.
func _refresh_ticket_badges() -> void:
	var build_tab: StationTabButton = _buttons.get(StationIds.BUILD)
	if build_tab:
		var order := DayManager.ticket_at(StationIds.BUILD)
		build_tab.set_badge("#%d" % order.ticket_number if order else "")
	var zap_count := DayManager.cups_at(StationIds.ZAP_SHELF).size()
	for i in GameState.blender_count:
		zap_count += DayManager.cups_at(StationIds.blender(i)).size()
	var top_count := DayManager.cups_at(StationIds.TOP_SHELF).size() + DayManager.cups_at(StationIds.TOP_COUNTER).size()
	var zap_tab: StationTabButton = _buttons.get(StationIds.ZAP)
	if zap_tab:
		zap_tab.set_badge(str(zap_count) if zap_count > 0 else "")
	var top_tab: StationTabButton = _buttons.get(StationIds.TOP)
	if top_tab:
		top_tab.set_badge(str(top_count) if top_count > 0 else "")
