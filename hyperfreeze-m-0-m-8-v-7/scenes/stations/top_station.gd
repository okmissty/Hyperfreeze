extends BaseStation
## M5 — Top Station. Zapped cups wait on the shelf; tap one to put it on
## the counter, pick a tool on the right and apply it to the cup, then
## Finish to set it aside as ready to serve (serving arrives in M6).

const CREAM_COLOR := Color("f7f3ff")

var _tool_group := ButtonGroup.new()

@onready var _slot: TicketSlot = %TicketSlot
@onready var _shelf: VBoxContainer = %Shelf
@onready var _empty_shelf: Label = %EmptyShelf
@onready var _work_area: TopWorkArea = %WorkArea
@onready var _tools: VBoxContainer = %Tools
@onready var _status: Label = %Status
@onready var _trash: Button = %Trash
@onready var _finish: Button = %Finish


func _ready() -> void:
	add_backdrop("top")
	_slot.station_id = station_id
	_slot.refresh()
	_tool_group.allow_unpress = true
	_trash.pressed.connect(_on_trash)
	_finish.pressed.connect(_on_finish)
	_work_area.cup_edited.connect(_on_cup_edited)
	Events.cup_moved.connect(_on_cup_moved)
	Events.day_started.connect(_on_day_started)
	Events.rank_changed.connect(_on_rank_changed)
	_build_tools()
	_refresh()


func counter_order() -> Order:
	var on_counter := DayManager.cups_at(StationIds.TOP_COUNTER)
	return on_counter[0] if not on_counter.is_empty() else null


# --- Tools --------------------------------------------------------------------

func _build_tools() -> void:
	for child in _tools.get_children():
		child.queue_free()
	var rank := GameState.get_rank()

	var cream := IngredientButton.new()
	cream.ingredient_id = &"nebula_cream"
	cream.swatch_color = CREAM_COLOR
	cream.icon_tex = Art.station("icon_tool_cream")
	if cream.icon_tex == null:
		cream.icon_tex = Art.load_tex(CupArt.DIR + "cup_cream.png")
	cream.text = "Nebula Cream"
	var cream_tools: Array[Control] = [_as_tool(cream, TopWorkArea.TOOL_CREAM)]
	_add_section("CREAM  ·  HOLD AND SWEEP", cream_tools)

	var sauces: Array[Control] = []
	for ing: IngredientData in GameState.catalog.unlocked(IngredientData.Category.SAUCE, rank):
		sauces.append(_as_tool(IngredientButton.make(ing), TopWorkArea.TOOL_SAUCE))
	_add_section("SAUCE  ·  SWIPE ACROSS", sauces)

	var sprinkles: Array[Control] = []
	for ing: IngredientData in GameState.catalog.unlocked(IngredientData.Category.SPRINKLES, rank):
		sprinkles.append(_as_tool(IngredientButton.make(ing), TopWorkArea.TOOL_SPRINKLES))
	_add_section("SPRINKLES  ·  TAP THE CUP", sprinkles)

	var toppers: Array[Control] = []
	for ing: IngredientData in GameState.catalog.unlocked(IngredientData.Category.TOPPER, rank):
		var b := _as_tool(IngredientButton.make(ing), TopWorkArea.TOOL_TOPPER)
		b.drag_kind = "topper"
		toppers.append(b)
	_add_section("TOPPERS  ·  TAP A SLOT OR DRAG", toppers)


func _as_tool(b: IngredientButton, kind: StringName) -> IngredientButton:
	b.toggle_mode = true
	b.button_group = _tool_group
	b.custom_minimum_size = Vector2(0, 48)
	b.set_meta(&"tool_kind", kind)
	b.toggled.connect(_on_tool_toggled.unbind(1))
	return b


## Tool art shown beside each section caption.
const SECTION_ICONS := {"CREAM": "icon_tool_cream", "SAUCE": "icon_tool_sauce", "SPRINKLES": "icon_tool_sprinkle", "TOPPERS": "icon_tool_topper"}


func _add_section(caption: String, buttons: Array[Control]) -> void:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"SectionCaption"
	var key := caption.get_slice(" ", 0)
	var tex: Texture2D = null
	if SECTION_ICONS.has(key):
		tex = Art.station(SECTION_ICONS[key])
	if tex:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		row.add_child(icon)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		_tools.add_child(row)
	else:
		_tools.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for b: Control in buttons:
		grid.add_child(b)
	_tools.add_child(grid)


func _on_tool_toggled() -> void:
	var pressed := _tool_group.get_pressed_button() as IngredientButton
	if pressed:
		_work_area.tool_kind = pressed.get_meta(&"tool_kind")
		_work_area.tool_id = pressed.ingredient_id
	else:
		_work_area.tool_kind = TopWorkArea.TOOL_NONE
		_work_area.tool_id = &""
	_update_status()


## Picks a tool by kind and id (tests and future keyboard shortcuts).
func select_tool(kind: StringName, id: StringName = &"") -> void:
	for b: BaseButton in _tool_group.get_buttons():
		var ib := b as IngredientButton
		if ib.get_meta(&"tool_kind") == kind and (id == &"" or ib.ingredient_id == id):
			ib.button_pressed = true
			return


# --- State --------------------------------------------------------------------

func _on_cup_moved(order: Order, from_location: StringName, to_location: StringName) -> void:
	var watched: Array[StringName] = [StationIds.TOP_SHELF, StationIds.TOP_COUNTER]
	if from_location in watched or to_location in watched:
		_refresh()
	if GameState.get_setting("follow_cup") and (to_location == StationIds.TOP_SHELF or from_location == StationIds.TOP_COUNTER):
		_auto_place.call_deferred()


## Follow the cup: if the counter is free, bring the oldest waiting cup over.
func _auto_place() -> void:
	if counter_order() != null:
		return
	var waiting := DayManager.cups_at(StationIds.TOP_SHELF)
	if not waiting.is_empty():
		DayManager.move_cup(waiting[0], StationIds.TOP_COUNTER)


func _on_day_started(_day: int) -> void:
	_refresh()


func _on_rank_changed(_rank: int) -> void:
	_build_tools()


func _refresh() -> void:
	for child in _shelf.get_children():
		child.queue_free()
	var waiting := DayManager.cups_at(StationIds.TOP_SHELF)
	for order: Order in waiting:
		var item := ShelfCup.make(order)
		item.picked.connect(_on_cup_picked)
		_shelf.add_child(item)
	_empty_shelf.visible = waiting.is_empty()

	var current := counter_order()
	_work_area.cup = current.cup if current else null
	_trash.disabled = current == null
	_finish.disabled = current == null
	for b: BaseButton in _tool_group.get_buttons():
		b.disabled = current == null
	_update_status()


func _update_status() -> void:
	var current := counter_order()
	if current == null:
		_status.text = "Zapped cups wait on the shelf" if DayManager.cups_at(StationIds.TOP_SHELF).is_empty() else "Tap a cup on the shelf"
		return
	var tip := ""
	match _work_area.tool_kind:
		TopWorkArea.TOOL_CREAM: tip = "hold and sweep across the top"
		TopWorkArea.TOOL_SAUCE: tip = "swipe across the top"
		TopWorkArea.TOOL_SPRINKLES: tip = "tap the cup"
		TopWorkArea.TOOL_TOPPER: tip = "tap a slot"
		_: tip = "pick a tool"
	_status.text = "#%d  ·  %s" % [current.ticket_number, tip]


func _on_cup_picked(order: Order) -> void:
	var current := counter_order()
	if current == order:
		return
	if current:
		DayManager.move_cup(current, StationIds.TOP_SHELF)
	DayManager.move_cup(order, StationIds.TOP_COUNTER)


func _on_cup_edited() -> void:
	var current := counter_order()
	if current:
		Events.cup_changed.emit(current)


func _on_trash() -> void:
	var current := counter_order()
	if current:
		DayManager.trash_cup(current)


func _on_finish() -> void:
	var current := counter_order()
	if current == null:
		return
	DayManager.move_cup(current, StationIds.READY)
	if current.location == station_id:
		DayManager.move_ticket(current, StationIds.RAIL)
	if GameState.get_setting("follow_cup"):
		Events.request_station.emit(StationIds.ORDER)
		(func() -> void: Events.serve_requested.emit(current)).call_deferred()
