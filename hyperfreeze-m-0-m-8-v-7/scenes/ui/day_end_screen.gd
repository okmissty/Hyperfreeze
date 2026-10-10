class_name DayEndScreen
extends Control
## The end-of-shift report: customers served, average score, tips, XP,
## rank progress and anything newly unlocked. Next Day saves and starts
## the next shift; Shop opens the upgrade shop (M8).

signal shop_requested

var _title: Label
var _stats: GridContainer
var _best: Label
var _rank: Label
var _rank_bar: ScoreCard.ScoreBar
var _unlocks: Label
var _bank: Label
var _shop_button: Button
var _next_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_title = _label("", &"TitleLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_stats = GridContainer.new()
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", 24)
	box.add_child(_stats)

	_best = _label("", &"SlotHint")
	box.add_child(_best)

	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 16)
	box.add_child(rank_row)
	var badge_tex := UiSkin.tex("ui_rank_badge")
	if badge_tex:
		var badge := TextureRect.new()
		badge.texture = badge_tex
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2(84, 76)
		rank_row.add_child(badge)
	_rank = _label("", &"StatusLabel")
	_rank.custom_minimum_size = Vector2(300, 0)
	_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(_rank)
	_rank_bar = ScoreCard.ScoreBar.new()
	_rank_bar.custom_minimum_size = Vector2(0, 30)
	_rank_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_row.add_child(_rank_bar)

	_unlocks = _label("", &"HudValue")
	_unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlocks.add_theme_color_override("font_color", Color("3ee6f0"))
	box.add_child(_unlocks)

	_bank = _label("", &"HudValue")
	box.add_child(_bank)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_shop_button = Button.new()
	_shop_button.text = "Shop"
	_shop_button.theme_type_variation = &"SecondaryButton"
	_shop_button.focus_mode = Control.FOCUS_NONE
	_shop_button.custom_minimum_size = Vector2(240, 0)
	_shop_button.pressed.connect(func() -> void: shop_requested.emit())
	buttons.add_child(_shop_button)
	_next_button = Button.new()
	_next_button.text = "Next Day"
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(next_day)
	buttons.add_child(_next_button)

	Events.day_ended.connect(open)
	Events.money_changed.connect(func(_c: int) -> void: _refresh_bank())


func open(summary: Dictionary) -> void:
	_title.text = "Day %d complete!" % int(summary.day)
	for child in _stats.get_children():
		child.queue_free()
	_stat("SERVED", str(summary.served))
	_stat("AVERAGE", str(summary.average) if int(summary.served) > 0 else "-")
	_stat("TIPS", GameState.format_money(int(summary.tips_cents)))
	_stat("XP", "+%d" % int(summary.xp))
	var best: Dictionary = summary.best
	_best.text = "Best order: #%d for %s, scored %d" % [int(best.ticket), best.customer, int(best.total)] if not best.is_empty() else "No orders served today."
	var rating_line := "Café rating: %.1f / 5" % float(summary.get("rating", 3.0))
	if int(summary.get("critic_stars", 0)) > 0:
		rating_line += "  ·  today's critic gave %d of 5 stars" % int(summary.critic_stars)
	_best.text += "\n" + rating_line
	var next_xp := GameState.rank_table.xp_for_next_rank(GameState.xp)
	_rank.text = "Rank %d  ·  %d XP" % [GameState.get_rank(), GameState.xp] + ("" if next_xp < 0 else " / %d" % next_xp)
	_rank_bar.value = GameState.rank_progress()
	var parts: Array[String] = []
	if not GameState.last_unlocks.is_empty():
		parts.append("New on the menu: %s." % ", ".join(GameState.last_unlocks))
	if not GameState.last_new_customers.is_empty():
		parts.append("New regulars: %s." % ", ".join(GameState.last_new_customers))
	_unlocks.text = "" if parts.is_empty() else "Rank up!  " + "  ".join(parts)
	_refresh_bank()
	visible = true
	get_tree().paused = true


func next_day() -> void:
	visible = false
	get_tree().paused = false
	GameState.last_unlocks.clear()
	GameState.last_new_customers.clear()
	GameState.advance_day()
	DayManager.start_day()


func _refresh_bank() -> void:
	if _bank:
		_bank.text = "Bank: %s" % GameState.format_money(GameState.money_cents)


func _stat(caption: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := _label(caption, &"SectionCaption")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(c)
	var v := _label(value, &"TitleLabel")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	_stats.add_child(col)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l
