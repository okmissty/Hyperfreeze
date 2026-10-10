class_name BadgesPanel
extends Control
## Every badge in a scrolling grid: earned ones in colour, locked ones dimmed
## with progress ("37 / 50") and what they pay out. Opened from the pause
## menu and the title screen. Works while the game is paused.

var _summary: Label
var _grid: GridContainer
var _unpause_on_close := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(1500, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Badges"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_summary = Label.new()
	_summary.theme_type_variation = &"HudValue"
	header.add_child(_summary)

	var hint := Label.new()
	hint.text = "Badges pay coins, and the special ones unlock decor and themes you can't buy."
	hint.theme_type_variation = &"SlotHint"
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var done := Button.new()
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	box.add_child(done)


func open() -> void:
	_rebuild()
	visible = true
	_unpause_on_close = not get_tree().paused and DayManager.day_running
	if _unpause_on_close:
		get_tree().paused = true


func close() -> void:
	visible = false
	if _unpause_on_close:
		_unpause_on_close = false
		get_tree().paused = false


func _rebuild() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var earned := 0
	for b: Dictionary in Badges.LIST:
		if GameState.has_badge(String(b.id)):
			earned += 1
		var card := BadgeCard.new()
		card.badge = b
		card.custom_minimum_size = Vector2(474, 150)
		_grid.add_child(card)
	_summary.text = "%d / %d earned" % [earned, Badges.LIST.size()]


## One badge: medal on the left, name, what it takes, progress and reward.
class BadgeCard extends Control:
	var badge: Dictionary

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var earned := GameState.has_badge(String(badge.id))
		var col := Badges.group_color(String(badge.group))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.09, 0.24, 0.85) if earned else Color(0.05, 0.06, 0.16, 0.7)
		bg.border_color = Color(col, 0.9 if earned else 0.25)
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(14)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		BadgesPanel.BadgeMedal.draw_medal(self, badge, Vector2(54, size.y / 2), 40.0, earned)
		var font := get_theme_default_font()
		var x := 108.0
		var w := size.x - x - 12
		draw_string(font, Vector2(x, 32), String(badge.name), HORIZONTAL_ALIGNMENT_LEFT, w, 22, Color("f4f1ff") if earned else Color("b9b4e0"))
		draw_string(font, Vector2(x, 56), String(badge.group).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 13, col)
		draw_multiline_string(font, Vector2(x, 78), String(badge.text), HORIZONTAL_ALIGNMENT_LEFT, w, 16, 2, Color("d8d4f4"))
		var foot := ""
		if earned:
			foot = "Earned  ·  " + Badges.reward_text(badge)
		else:
			foot = "%d / %d  ·  %s" % [GameState.badge_progress(badge), int(badge.goal), Badges.reward_text(badge)]
			# progress bar along the bottom
			var p := float(GameState.badge_progress(badge)) / maxf(float(badge.goal), 1.0)
			draw_rect(Rect2(x, size.y - 13, w, 5), Color(1, 1, 1, 0.12))
			draw_rect(Rect2(x, size.y - 13, w * p, 5), col)
		if int(badge.goal) == 1 and not earned:
			foot = Badges.reward_text(badge)
		draw_string(font, Vector2(x, size.y - 22), foot, HORIZONTAL_ALIGNMENT_LEFT, w, 14, Color("ffd95a") if earned else Color("9e9ac8"))


## The medal for a badge: Ty's art (assets/art/ui/badges/badge_<id>.png) if
## drawn, otherwise a coloured placeholder medal.
class BadgeMedal:
	static func draw_medal(ci: CanvasItem, b: Dictionary, c: Vector2, r: float, earned: bool) -> void:
		var tex := Art.load_tex("res://assets/art/ui/badges/badge_%s.png" % b.id)
		if tex:
			Art.draw_fit(ci, tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), Color.WHITE if earned else Color(0.25, 0.25, 0.35, 0.8))
			return
		var col := Badges.group_color(String(b.group))
		if not earned:
			col = Color(0.35, 0.36, 0.5)
		ci.draw_circle(c, r, col.darkened(0.35))
		ci.draw_circle(c, r * 0.82, col)
		ci.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + i * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.5 if i % 2 == 0 else r * 0.22))
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.9) if earned else Color(1, 1, 1, 0.25))
