class_name SizeButton
extends Button
## Pick-a-cup button at the Build Station: draws an empty cup of its size.

@export_range(0, 2) var cup_size: int = 0

var _empty := CupState.new()


func _ready() -> void:
	theme_type_variation = &"ToolButton"
	focus_mode = Control.FOCUS_NONE
	text = ""
	_empty.size = cup_size
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 150)


## Drawn cup-size cards (normal / hover / picked), or null if not drawn yet.
func _card() -> Texture2D:
	var key := ["s", "m", "l"][clampi(cup_size, 0, 2)] as String
	var state := "normal"
	if button_pressed:
		state = "picked"
	elif is_hovered() and not disabled:
		state = "hover"
	return Art.station("st_build_size_%s_%s" % [key, state])


func _draw() -> void:
	var card := _card()
	# Disabled cards fade out rather than getting a dark box over them.
	var fade := Color(1, 1, 1, 0.4) if disabled and not button_pressed else Color.WHITE
	if card:
		if not has_theme_stylebox_override("normal"):
			var empty := StyleBoxEmpty.new()
			for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
				add_theme_stylebox_override(st, empty)
		Art.draw_fit(self, card, Rect2(Vector2(0, 2), Vector2(size.x, size.y - 32)), fade)
	else:
		var art := Rect2(Vector2(20, 8), Vector2(size.x - 40, size.y - 44))
		CupPainter.draw_cup(self, art, _empty)
	var label := Order.size_name(cup_size as Order.CupSize)
	var font := get_theme_font("font")
	var col := Color("3ee6f0") if button_pressed else Color(0.956863, 0.945098, 1, fade.a)
	var at := Vector2(0, size.y - 8)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 6, Color(0.04, 0.05, 0.16, fade.a))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, col)
	if disabled and card == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.16, 0.55))
