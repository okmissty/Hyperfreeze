class_name CupState
extends RefCounted
## What the player actually made, plus where the cup is right now.
## Stations change it through these methods; the Scorer (M6) compares it
## against the Order.

const TARGET_FILL := 0.8
const MAX_FILL := 1.0
const CREAM_COLUMNS := 12

## StationIds cup location: BUILD, ZAP_SHELF, blender_N, TOP_SHELF, TOP_COUNTER, READY.
var location: StringName = &""
## DayManager.time_elapsed when it last landed on a shelf (keeps shelves first-in, first-out).
var shelved_at := 0.0

var size: int = -1                       # Order.CupSize
var base_id: StringName
var mixed_bases := false                 # a second base was poured on top
var fill_amount := 0.0                   # 0–1, target TARGET_FILL
var mixin_ids: Array[StringName] = []
var zapped := false
var zap_level: int = -1                  # Order.ZapLevel the blender was set to
var zap_value := 0.0                     # meter position (0–1) on release
var cream_cols := PackedByteArray()      # 1 = that column of the dome has cream
var sauce_id: StringName
var sprinkle_id: StringName
var toppers: Array[StringName] = [&"", &"", &"", &""]


func _init() -> void:
	cream_cols.resize(CREAM_COLUMNS)


func has_cup() -> bool:
	return size >= 0


func pour(base: StringName, amount: float) -> void:
	if base_id != &"" and base_id != base:
		mixed_bases = true
	base_id = base
	fill_amount = minf(fill_amount + amount, MAX_FILL)


func toggle_mixin(id: StringName) -> void:
	if id in mixin_ids:
		mixin_ids.erase(id)
	else:
		mixin_ids.append(id)


func add_cream_column(column: int) -> bool:
	if column < 0 or column >= CREAM_COLUMNS or cream_cols[column] == 1:
		return false
	cream_cols[column] = 1
	return true


func cream_coverage() -> float:
	var n := 0
	for v in cream_cols:
		n += v
	return float(n) / CREAM_COLUMNS


func set_topper(slot: int, id: StringName) -> void:
	if slot >= 0 and slot < toppers.size():
		toppers[slot] = id


## The perfect cup for an order: used to draw ticket illustrations.
static func from_order(order: Order) -> CupState:
	var c := CupState.new()
	c.size = order.size
	c.base_id = order.base_id
	c.fill_amount = TARGET_FILL
	c.mixin_ids = order.mixin_ids.duplicate()
	c.zapped = true
	c.zap_level = order.zap_level
	c.zap_value = ZapBands.center(order.zap_level)
	if order.wants_cream:
		for i in CREAM_COLUMNS:
			c.cream_cols[i] = 1
	c.sauce_id = order.sauce_id
	c.sprinkle_id = order.sprinkle_id
	c.toppers = order.toppers.duplicate()
	return c
