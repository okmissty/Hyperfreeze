class_name CupView
extends Control
## Draws a live CupState large (the cup on a station counter).
## Call `queue_redraw()` after changing the cup.

var cup: CupState:
	set(value):
		cup = value
		queue_redraw()
var show_fill_line := false
## Size the cup to fill the view, without room above it for cream
## (Build and Zap, where there's no cream yet).
var fit_cup := false
var show_slot_hints := false
var highlight_slot := -1
## Shown in a dashed outline when there is no cup.
var empty_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The rect the cup is drawn into (kept narrower than wide controls).
func cup_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	if cup and cup.size >= 0:
		CupPainter.draw_cup(self, cup_rect(), cup, {
			"fill_line": show_fill_line,
			"fit_cup": fit_cup,
			"slot_hints": show_slot_hints,
			"highlight_slot": highlight_slot,
		})
	elif empty_text != "":
		var r := Rect2(size * Vector2(0.2, 0.25), size * Vector2(0.6, 0.65))
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(1, 1, 1, 0.3), 3.0, 14.0)
		var font := get_theme_default_font()
		draw_string(font, Vector2(r.position.x, r.get_center().y + 10), empty_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color("b9b4e0"))
