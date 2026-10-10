class_name TopWorkArea
extends Control
## The big cup on the Top Station counter. Applies the selected tool where
## the player touches:
##   cream     hold and sweep across the top (fills dome columns)
##   sauce     swipe across the top
##   sprinkles tap over the top
##   topper    tap a slot (or drag a topper button onto it)
##   no tool   tap a topper to take it off

signal cup_edited

const TOOL_NONE := &""
const TOOL_CREAM := &"cream"
const TOOL_SAUCE := &"sauce"
const TOOL_SPRINKLES := &"sprinkles"
const TOOL_TOPPER := &"topper"
## Swipe distance (px) before a sauce drizzle lands.
const SAUCE_SWIPE := 60.0

var cup: CupState:
	set(value):
		cup = value
		queue_redraw()
var tool_kind: StringName = TOOL_NONE:
	set(value):
		tool_kind = value
		queue_redraw()
var tool_id: StringName

var _pressing := false
var _swipe := 0.0
var _last := Vector2.ZERO
var _drop_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Square-ish area the cup is drawn in, centred.
func cup_rect() -> Rect2:
	var w := minf(size.x, size.y * 1.05)
	return Rect2(Vector2((size.x - w) / 2.0, 0), Vector2(w, size.y))


func _geo() -> Dictionary:
	return CupPainter.geometry(cup_rect(), cup.size)


# --- Input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if cup == null:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_swipe = 0.0
			_last = mb.position
			apply_at(mb.position, true)
		else:
			_pressing = false
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm and _pressing:
		_swipe += mm.position.distance_to(_last)
		_last = mm.position
		apply_at(mm.position, false)
		accept_event()


## Applies the current tool at a point (public so tests can drive it).
func apply_at(pos: Vector2, first_touch: bool) -> bool:
	if cup == null:
		return false
	var geo := _geo()
	var changed := false
	match tool_kind:
		TOOL_CREAM:
			if _over_top(pos, geo):
				var left: float = float(geo.cx) - float(geo.dome_r)
				var col := int(floor((pos.x - left) / (float(geo.dome_r) * 2.0) * CupState.CREAM_COLUMNS))
				changed = cup.add_cream_column(col)
				# Whip Cannon: each sweep also fills the strips either side.
				for s in range(1, GameState.cream_spread() + 1):
					changed = cup.add_cream_column(col - s) or changed
					changed = cup.add_cream_column(col + s) or changed
		TOOL_SAUCE:
			if _over_top(pos, geo) and _swipe >= SAUCE_SWIPE and cup.sauce_id != tool_id:
				cup.sauce_id = tool_id
				changed = true
		TOOL_SPRINKLES:
			if first_touch and _over_top(pos, geo) and cup.sprinkle_id != tool_id:
				cup.sprinkle_id = tool_id
				changed = true
		TOOL_TOPPER:
			if first_touch:
				var slot := slot_at(pos)
				if slot >= 0 and cup.toppers[slot] != tool_id:
					cup.set_topper(slot, tool_id)
					changed = true
		_:
			if first_touch:
				var slot := slot_at(pos)
				if slot >= 0 and cup.toppers[slot] != &"":
					cup.set_topper(slot, &"")
					changed = true
	if changed:
		queue_redraw()
		cup_edited.emit()
		match tool_kind:
			TOOL_CREAM: AudioManager.play("cream", 0.1)
			TOOL_SAUCE: AudioManager.play("sauce")
			TOOL_SPRINKLES: AudioManager.play("sprinkle")
			_: AudioManager.play("plop", 0.08)
			# (no tool = removing a topper)
		_pulse()
	return changed


## Tiny squash so each placement feels like it landed.
func _pulse() -> void:
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.03, 0.97), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Inside the band just above and below the rim, across the dome's width.
func _over_top(pos: Vector2, geo: Dictionary) -> bool:
	var cx: float = geo.cx
	var r: float = geo.dome_r
	var top_y: float = geo.top_y
	return absf(pos.x - cx) <= r * 1.05 and pos.y >= top_y - float(geo.dome_h) * 1.6 and pos.y <= top_y + float(geo.cup_h) * 0.25


## Nearest topper slot to a point, or -1 if none is close enough.
func slot_at(pos: Vector2) -> int:
	if cup == null:
		return -1
	var geo := _geo()
	var on_dome := cup.cream_coverage() >= 0.5
	var best := -1
	var best_d := INF
	for i in Order.TOPPER_SLOTS:
		var spot := CupPainter.topper_spot(geo, i, on_dome)
		var reach := maxf(CupPainter.topper_radius(geo, i) * 2.4, 46.0)
		var d := pos.distance_to(spot)
		if d <= reach and d < best_d:
			best = i
			best_d = d
	return best


## Screen position of a slot (used by tests and hints).
func slot_position(i: int) -> Vector2:
	return CupPainter.topper_spot(_geo(), i, cup.cream_coverage() >= 0.5)


# --- Topper drag-and-drop -----------------------------------------------------

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if cup == null or not (data is Dictionary) or data.get("kind") != "topper":
		return false
	var slot := slot_at(at_position)
	if slot != _drop_slot:
		_drop_slot = slot
		queue_redraw()
	return slot >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var slot := slot_at(at_position)
	_drop_slot = -1
	if slot >= 0:
		cup.set_topper(slot, data["id"])
		cup_edited.emit()
		AudioManager.play("plop", 0.08)
		_pulse()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _drop_slot != -1:
			_drop_slot = -1
			queue_redraw()


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if cup == null:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y / 2), "Tap a waiting cup to bring it to the counter", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color("b9b4e0"))
		return
	var hints := tool_kind == TOOL_TOPPER or _drop_slot >= 0
	CupPainter.draw_cup(self, cup_rect(), cup, {"slot_hints": hints, "highlight_slot": _drop_slot})
	if tool_kind == TOOL_CREAM and cup.cream_coverage() < 1.0:
		var geo := _geo()
		var y: float = float(geo.top_y) - float(geo.dome_h) * (0.55 if geo.get("art", false) else 1.25)
		var x0: float = float(geo.cx) - float(geo.dome_r)
		var x1: float = float(geo.cx) + float(geo.dome_r)
		draw_dashed_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.35), 3.0, 12.0)
		var font2 := get_theme_default_font()
		draw_string(font2, Vector2(x0, y - 14), "sweep across", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 20, Color(1, 1, 1, 0.5))
