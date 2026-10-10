class_name UiSkin
extends RefCounted
## Ty's UI kit (assets/art/ui/) applied to the project theme at startup.
## Every piece is optional: anything not drawn keeps the flat placeholder style.
##
## Buttons, tabs and tool buttons use blank versions of the sheet art (the
## mock PLAY / OK / ORDERS text was painted out) so the game's own labels sit
## on top. Panels use a "dark glass" version of the frame so light text stays
## readable; ui_panel_light / ui_modal_light keep the original look.

const DIR := "res://assets/art/ui/"
const WHITE := Color("f4f1ff")
const INK := Color("2b2850")
const PINK_INK := Color("c2185b")
const GREY_INK := Color("8c89b0")

static var _scaled := {}


static func clear() -> void:
	_scaled.clear()
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
		Input.set_custom_mouse_cursor(null, shape)


static func tex(file: String) -> Texture2D:
	return Art.load_tex(DIR + file + ".png")


## A resized copy of a UI texture (9-slice corners draw at texture size, so
## bars and small widgets need art at roughly their on-screen size).
static func scaled(file: String, factor: float) -> Texture2D:
	var key := "%s@%.3f" % [file, factor]
	if _scaled.has(key):
		return _scaled[key]
	var base := tex(file)
	var out: Texture2D = null
	if base:
		# Prefer the 4x upscaled copy (ui/hires/) and shrink it to size: sharper
		# than enlarging the small original.
		var target := base.get_size() * factor
		var src := Art.load_tex(DIR + "hires/" + file + ".png")
		if src == null:
			src = base
		var img := src.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			img.resize(maxi(1, roundi(target.x)), maxi(1, roundi(target.y)), Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(img)
	_scaled[key] = out
	return out


## 9-slice stylebox. margins = (left, top, right, bottom) in texture pixels;
## content = padding for what goes inside (-1 keeps the margins).
static func box(t: Texture2D, margins: Vector4, content: Vector4 = Vector4(-1, -1, -1, -1), expand: float = 0.0) -> StyleBoxTexture:
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margins.x + expand
	sb.texture_margin_top = margins.y + expand
	sb.texture_margin_right = margins.z + expand
	sb.texture_margin_bottom = margins.w + expand
	sb.expand_margin_left = expand
	sb.expand_margin_top = expand
	sb.expand_margin_right = expand
	sb.expand_margin_bottom = expand
	if content.x >= 0:
		sb.content_margin_left = content.x
		sb.content_margin_top = content.y
		sb.content_margin_right = content.z
		sb.content_margin_bottom = content.w
	return sb


## Keeps a node's own colour (self_modulate) in step with the café theme.
## key = "accent" (UI frames) or "tint" (painted café).
static func follow_theme(ci: CanvasItem, key: String = "accent", use_self := true) -> void:
	var paint := func() -> void:
		if is_instance_valid(ci):
			var c: Color = GameState.theme_colors().get(key, Color.WHITE)
			if use_self:
				ci.self_modulate = c
			else:
				ci.modulate = c
	paint.call()
	Events.theme_changed.connect(func(_id: String) -> void: paint.call())


static func apply() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	_buttons(theme)
	_panels(theme)
	_controls(theme)
	_cursor()


# --- Buttons ------------------------------------------------------------------

## Sets normal/hover/pressed/disabled from ui_btn_<kind>_<state>. Glowing
## states are bigger than the normal art; the glow spills outside the button.
static func _button_set(theme: Theme, type: String, kind: String, margins: Vector4, content: Vector4, pressed_state := "pressed") -> bool:
	var normal := scaled("ui_btn_%s_normal" % kind, 1.0)
	if normal == null:
		return false
	var states := {"normal": "normal", "hover": "hover", "pressed": pressed_state, "hover_pressed": pressed_state, "disabled": "disabled"}
	for style: String in states:
		var t := scaled("ui_btn_%s_%s" % [kind, states[style]], 1.0)
		if t == null:
			t = normal
		var pad := maxf(0.0, (t.get_height() - normal.get_height()) / 2.0)
		theme.set_stylebox(style, type, box(t, margins, content, pad))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	return true


static func _font_colors(theme: Theme, type: String, normal: Color, active: Color, disabled: Color) -> void:
	for c in ["font_color", "font_focus_color", "font_hover_color"]:
		theme.set_color(c, type, normal)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(c, type, active)
	theme.set_color("font_disabled_color", type, disabled)


static func _buttons(theme: Theme) -> void:
	if _button_set(theme, "Button", "primary", Vector4(26, 18, 26, 18), Vector4(28, 14, 28, 14)):
		_font_colors(theme, "Button", WHITE, WHITE, Color(1, 1, 1, 0.85))
	_button_set(theme, "BigButton", "big", Vector4(28, 20, 28, 20), Vector4(40, 18, 40, 18))
	if _button_set(theme, "SecondaryButton", "secondary", Vector4(26, 18, 26, 18), Vector4(24, 14, 24, 14)):
		_font_colors(theme, "SecondaryButton", PINK_INK, WHITE, Color(1, 1, 1, 0.85))
		theme.set_color("font_hover_color", "SecondaryButton", WHITE)
	if _tab_set(theme):
		_font_colors(theme, "TabButton", INK, WHITE, GREY_INK)
	if _button_set(theme, "ToolButton", "tool", Vector4(20, 20, 20, 20), Vector4(66, 10, 14, 10), "selected"):
		_font_colors(theme, "ToolButton", INK, INK, Color(INK, 0.55))
		# Disabled = the normal button faded, not the flat grey art (reads as broken).
		var faded := box(scaled("ui_btn_tool_normal", 1.0), Vector4(20, 20, 20, 20), Vector4(66, 10, 14, 10))
		faded.modulate_color = Color(1, 1, 1, 0.5)
		theme.set_stylebox("disabled", "ToolButton", faded)


static func _tab_set(theme: Theme) -> bool:
	var normal := scaled("ui_tab_normal", 1.0)
	if normal == null:
		return false
	var m := Vector4(30, 24, 30, 24)
	var c := Vector4(24, 10, 24, 10)
	for pair: Array in [["normal", "normal"], ["hover", "hover"], ["pressed", "active"], ["hover_pressed", "active"], ["disabled", "normal"]]:
		var t := scaled("ui_tab_%s" % pair[1], 1.0)
		if t == null:
			t = normal
		var pad := maxf(0.0, (t.get_height() - normal.get_height()) / 2.0)
		theme.set_stylebox(pair[0], "TabButton", box(t, m, c, pad))
	theme.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	return true


# --- Panels -------------------------------------------------------------------

static func _panels(theme: Theme) -> void:
	# Modals get their own type so they can use the modal frame.
	theme.set_type_variation("ModalPanel", "PanelContainer")
	var work := theme.get_stylebox("panel", "WorkPanel")
	theme.set_stylebox("panel", "ModalPanel", work)
	var panel := scaled("ui_panel", 1.5)
	if panel:
		theme.set_stylebox("panel", "WorkPanel", box(panel, Vector4(36, 36, 36, 36), Vector4(30, 26, 30, 26)))
	var modal := scaled("ui_modal", 1.5)
	if modal:
		theme.set_stylebox("panel", "ModalPanel", box(modal, Vector4(40, 40, 40, 40), Vector4(40, 34, 40, 34)))
	# Rail, HUD and tab bar get the same dark-glass frame as the work panels.
	theme.set_type_variation("HudPanel", "PanelContainer")
	theme.set_stylebox("panel", "HudPanel", theme.get_stylebox("panel", "PanelContainer"))
	if panel:
		var frame := box(panel, Vector4(36, 36, 36, 36), Vector4(24, 16, 24, 16))
		for type in ["RailPanel", "HudPanel"]:
			theme.set_stylebox("panel", type, frame)
		theme.set_stylebox("panel", "TabsPanel", box(panel, Vector4(36, 36, 36, 36), Vector4(24, 14, 24, 10)))
	var toast := scaled("ui_toast", 0.45)
	if toast:
		theme.set_stylebox("normal", "ToastLabel", box(toast, Vector4(28, 22, 28, 22), Vector4(40, 14, 40, 14)))
		theme.set_color("font_color", "ToastLabel", WHITE)


## Frame for the ticket holders at Build, Zap and Top.
static func ticket_slot_box(highlighted: bool) -> StyleBox:
	var t := scaled("ui_ticket_slot_highlighted" if highlighted else "ui_ticket_slot", 1.6)
	return box(t, Vector4(34, 34, 34, 34))


# --- Small controls -------------------------------------------------------------

static func _controls(theme: Theme) -> void:
	var on := tex("ui_toggle_on")
	var off := tex("ui_toggle_off")
	if on and off:
		for n in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
			theme.set_icon(n, "CheckButton", on)
		for n in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
			theme.set_icon(n, "CheckButton", off)
	var track := scaled("ui_slider_track", 0.42)
	var fill := scaled("ui_slider_fill", 0.42)
	if track and fill:
		theme.set_stylebox("slider", "HSlider", box(track, Vector4(14, 9, 14, 9), Vector4(0, 6, 0, 6)))
		var f := box(fill, Vector4(8, 5, 8, 5), Vector4(0, 6, 0, 6))
		f.expand_margin_top = -6
		f.expand_margin_bottom = -6
		theme.set_stylebox("grabber_area", "HSlider", f)
		theme.set_stylebox("grabber_area_highlight", "HSlider", f)
	var grab := tex("ui_slider_grabber")
	if grab:
		theme.set_icon("grabber", "HSlider", grab)
		theme.set_icon("grabber_disabled", "HSlider", grab)
		var hover := tex("ui_slider_grabber_hover")
		theme.set_icon("grabber_highlight", "HSlider", hover if hover else grab)


## Track + fill for a progress bar drawn in code. `knob` = whether the art has
## a round knob on the left (it does on the score and shift bars).
## Returns [track_box, fill_box] or [] when not drawn.
static func bar_boxes(kind: String, height: float) -> Array:
	var sheet := tex("ui_%s_track" % kind)
	if sheet == null or tex("ui_%s_fill" % kind) == null:
		return []
	var f := height / sheet.get_height()
	var track := scaled("ui_%s_track" % kind, f)
	var fill := scaled("ui_%s_fill" % kind, f)
	var t := box(track, Vector4(track.get_height() * 0.98, track.get_height() * 0.3, track.get_height() * 0.3, track.get_height() * 0.3))
	var fl := box(fill, Vector4(fill.get_height() * 0.5, 2, fill.get_height() * 0.5, 2))
	return [t, fl]


## Where the fill goes inside a knobbed track drawn in `r`.
static func bar_groove(r: Rect2) -> Rect2:
	var left := r.size.y * 1.0
	return Rect2(r.position + Vector2(left, r.size.y * 0.3), Vector2(maxf(r.size.x - left - r.size.y * 0.32, 1.0), r.size.y * 0.4))


static func draw_bar(ci: CanvasItem, kind: String, r: Rect2, value: float, tint: Color = Color.WHITE) -> bool:
	var boxes := bar_boxes(kind, r.size.y)
	if boxes.is_empty():
		return false
	ci.draw_style_box(boxes[0], r)
	if value > 0.0:
		var g := bar_groove(r)
		var w := maxf(g.size.y * 1.2, g.size.x * clampf(value, 0.0, 1.0))
		var fill: StyleBoxTexture = boxes[1]
		fill.modulate_color = tint
		ci.draw_style_box(fill, Rect2(g.position, Vector2(w, g.size.y)))
	return true


static func _cursor() -> void:
	var arrow := tex("ui_cursor")
	if arrow:
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(4, 3))
	var hand := tex("ui_cursor_grab")
	if hand:
		var hot := Vector2(hand.get_width() * 0.42, 3)
		for shape in [Input.CURSOR_POINTING_HAND, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
			Input.set_custom_mouse_cursor(hand, shape, hot)
