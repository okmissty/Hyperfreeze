class_name BaseStation
extends Control
## Shared base for the four stations. Main keeps all of them loaded and
## only toggles visibility, so work in progress survives a tab switch.

## How much the work stations dim their painted background so panels stay readable.
const BACKDROP_DIM := Color(0.04, 0.05, 0.16, 0.28)
## Work panel opacity over a painted background (1 = fully solid).
const PANEL_ALPHA := 0.74

@export var station_id: StringName = StationIds.ORDER

var backdrop: TextureRect


## Called by Main right after this station becomes visible.
func on_enter() -> void:
	pass


## Called by Main right before this station is hidden.
func on_exit() -> void:
	pass


## Puts the station's painted background (assets/art/stations/st_<key>_bg.png)
## behind everything, filling the whole screen, not just the station strip.
## Returns false when that painting doesn't exist yet.
func add_backdrop(key: String, dim: bool = true) -> bool:
	var tex := Art.station("st_%s_bg" % key)
	if tex == null:
		return false
	backdrop = TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = tex
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	var holder := get_parent() as Control
	if holder:
		# The stations sit in a strip between the rail and the tabs; reach past it.
		backdrop.offset_left = -holder.offset_left
		backdrop.offset_top = -holder.offset_top
		backdrop.offset_right = -holder.offset_right
		backdrop.offset_bottom = -holder.offset_bottom
	add_child(backdrop)
	move_child(backdrop, 0)
	# Café theme: colour grade on the painting plus a light wash of the theme colour.
	UiSkin.follow_theme(backdrop, "tint")
	var glow := ColorRect.new()
	glow.name = "ThemeGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = GameState.theme_colors().get("glow", Color(0, 0, 0, 0))
	backdrop.add_child(glow)
	Events.theme_changed.connect(func(_id: String) -> void:
		if is_instance_valid(glow):
			glow.color = GameState.theme_colors().get("glow", Color(0, 0, 0, 0)))
	if dim:
		var shade := ColorRect.new()
		shade.color = BACKDROP_DIM
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.add_child(shade)
	var panel := get_node_or_null("WorkPanel") as Control
	if panel:
		UiSkin.follow_theme(panel)
		var sb := panel.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var see_through := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			see_through.bg_color.a = minf(see_through.bg_color.a, PANEL_ALPHA)
			panel.add_theme_stylebox_override("panel", see_through)
	return true
