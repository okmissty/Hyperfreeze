class_name CupIcon
extends Control
## Little illustration of an order (the perfect cup) for tickets and
## speech bubbles. Drawing is shared with the stations via CupPainter.

var order: Order:
	set(value):
		order = value
		_ideal = CupState.from_order(value) if value else null
		queue_redraw()

var _ideal: CupState


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	CupPainter.draw_cup(self, Rect2(Vector2.ZERO, size), _ideal)
