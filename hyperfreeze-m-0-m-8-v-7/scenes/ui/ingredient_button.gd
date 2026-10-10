class_name IngredientButton
extends Button
## A station button for one ingredient: its icon (or a colour dot) plus its name.
## Used for base taps (hold), mix-in bins (toggle) and Top Station tools.
## Set `drag_kind` to let it be dragged (toppers use "topper").

var ingredient_id: StringName
var swatch_color := Color.WHITE
var icon_tex: Texture2D
## Optional round backdrop drawn behind the icon, by button state:
## Art.station("<prefix>_normal" / "_hover" / "_pressed" / "_disabled").
var backdrop_prefix := ""
## Icon in the middle (for icon-only buttons with no text).
var icon_centered := false
var drag_kind := ""


static func make(ing: IngredientData, as_toggle: bool = false) -> IngredientButton:
	var b := IngredientButton.new()
	b.ingredient_id = ing.id
	b.swatch_color = ing.color
	b.icon_tex = Art.ingredient(ing.id)
	b.text = ing.display_name
	b.tooltip_text = ing.display_name
	b.toggle_mode = as_toggle
	return b


func _ready() -> void:
	theme_type_variation = &"ToolButton"
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(250, 64)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var c := Vector2(size.x / 2 if icon_centered else 30.0, size.y / 2)
	var back := _backdrop()
	if back:
		var bd := minf(size.y - 4.0, 60.0)
		Art.draw_fit(self, back, Rect2(c - Vector2(bd, bd) / 2.0, Vector2(bd, bd)))
		if icon_tex:
			var id := bd * 0.62
			Art.draw_fit(self, icon_tex, Rect2(c - Vector2(id, id) / 2.0, Vector2(id, id)), Color(1, 1, 1, 0.5) if disabled else Color.WHITE)
			return
	if icon_tex:
		var d := minf(size.y - 8.0, 52.0)
		Art.draw_fit(self, icon_tex, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), Color(1, 1, 1, 0.45) if disabled else Color.WHITE)
		return
	draw_circle(c, 15, swatch_color)
	draw_arc(c, 15, 0, TAU, 24, Color(0.04, 0.05, 0.16, 0.8), 2.0, true)
	draw_circle(c + Vector2(-5, -5), 4, Color(1, 1, 1, 0.5))


func _backdrop() -> Texture2D:
	if backdrop_prefix == "":
		return null
	var state := "normal"
	if disabled:
		state = "disabled"
	elif button_pressed:
		state = "pressed"
	elif is_hovered():
		state = "hover"
	return Art.station("%s_%s" % [backdrop_prefix, state])


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_kind == "" or disabled:
		return null
	var preview := Dot.new()
	preview.color = swatch_color
	preview.tex = Art.ingredient(ingredient_id, "topper") if drag_kind == "topper" else null
	if preview.tex == null:
		preview.tex = icon_tex
	set_drag_preview(preview)
	return {"kind": drag_kind, "id": ingredient_id}


## The little blob that follows the finger while dragging a topper.
class Dot extends Control:
	var color := Color.WHITE
	var tex: Texture2D

	func _draw() -> void:
		if tex:
			Art.draw_fit(self, tex, Rect2(Vector2(-36, -36), Vector2(72, 72)))
			return
		draw_circle(Vector2.ZERO, 26, color)
		draw_arc(Vector2.ZERO, 26, 0, TAU, 28, Color("2b2850"), 3.0, true)
