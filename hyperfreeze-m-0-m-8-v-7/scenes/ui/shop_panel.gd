class_name ShopPanel
extends Control
## The café shop, open any time (it pauses the café mid-shift).
## Three tabs: Upgrades (gameplay boosts), Decor (lobby items, each adds a
## little patience) and Themes. Badge-only rewards appear here once earned,
## and are shown locked with the badge that unlocks them until then.

const TABS: Array[String] = ["Upgrades", "Decor", "Themes"]

var _bank: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _tab := 0
var _tab_buttons: Array[Button] = []
var _unpause_on_close := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(1180, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Café Shop"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_bank = Label.new()
	_bank.theme_type_variation = &"HudValue"
	header.add_child(_bank)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var t := Button.new()
		t.text = TABS[i]
		t.toggle_mode = true
		t.button_group = group
		t.theme_type_variation = &"TabButton"
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(220, 64)
		t.button_pressed = i == 0
		t.pressed.connect(func() -> void:
			_tab = i
			_rebuild()
			_scroll.scroll_vertical = 0)
		tabs.add_child(t)
		_tab_buttons.append(t)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	var done := Button.new()
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	box.add_child(done)

	Events.upgrades_changed.connect(_rebuild)
	Events.decor_changed.connect(_rebuild)
	Events.badge_earned.connect(func(_b: Dictionary) -> void: _rebuild())
	Events.theme_changed.connect(func(_id: String) -> void: _rebuild())
	Events.money_changed.connect(func(_c: int) -> void: _rebuild())


## Opens the shop. Mid-shift it pauses the café until you close it.
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


func show_tab(index: int) -> void:
	_tab = clampi(index, 0, TABS.size() - 1)
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	_bank.text = "Bank: %s" % GameState.format_money(GameState.money_cents)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		0: _build_upgrades()
		1: _build_decor()
		2: _build_themes()


# --- Tabs -------------------------------------------------------------------------

func _build_upgrades() -> void:
	for u: Dictionary in Upgrades.LIST:
		if u.get("theme", false):
			continue
		var id := String(u.id)
		var b := _action_button()
		if GameState.owns(id):
			b.text = "Owned"
			b.disabled = true
			b.theme_type_variation = &"TabButton"
		elif u.get("requires", "") != "" and not GameState.owns(String(u.requires)):
			b.text = "Needs " + Upgrades.find(String(u.requires)).name
			b.disabled = true
			b.theme_type_variation = &"TabButton"
		else:
			b.text = "Buy  %s" % GameState.format_money(int(u.price))
			b.disabled = not GameState.can_buy(id)
			b.pressed.connect(func() -> void: GameState.buy_upgrade(id))
		_list.add_child(_row(_icon("icon_up_%s" % id), u.name, u.text, b))


func _build_decor() -> void:
	_list.add_child(_note("Each piece on display adds %d%% patience (badge pieces %d%%). One piece per spot." % [
		roundi(Upgrades.DECOR_PATIENCE * 100), roundi(Upgrades.BADGE_DECOR_PATIENCE * 100)]))
	for slot: String in Upgrades.SLOTS:
		_list.add_child(_section(Upgrades.SLOT_NAMES[slot].to_upper() + " SPOT"))
		for d: Dictionary in Upgrades.DECOR:
			if String(d.slot) != slot:
				continue
			var id := String(d.id)
			var b := _action_button()
			var badge_only: bool = d.get("badge", false)
			var desc := String(d.text)
			if GameState.owns_decor(id):
				if GameState.is_decor_placed(id):
					b.text = "Take down"
					b.theme_type_variation = &"SecondaryButton"
					b.pressed.connect(func() -> void: GameState.remove_decor(slot))
				else:
					b.text = "Display"
					b.pressed.connect(func() -> void: GameState.place_decor(id))
			elif badge_only:
				b.text = "Badge reward"
				b.disabled = true
				b.theme_type_variation = &"TabButton"
				desc += "  (Earn \"%s\")" % _badge_for(id)
			else:
				b.text = "Buy  %s" % GameState.format_money(int(d.price))
				b.disabled = GameState.money_cents < int(d.price)
				b.pressed.connect(func() -> void: GameState.buy_decor(id))
			var preview := DecorItem.new()
			preview.decor_id = id
			preview.custom_minimum_size = Vector2(96, 84)
			if badge_only and not GameState.owns_decor(id):
				preview.modulate = Color(0.2, 0.2, 0.3, 0.8)  # silhouette until earned
			_list.add_child(_row(preview, d.name + ("  ·  BADGE" if badge_only else ""), desc, b))


func _build_themes() -> void:
	var themes: Array[Dictionary] = [{"id": "nebula", "name": "Nebula Café Theme", "text": "The original lavender café."}]
	for u: Dictionary in Upgrades.LIST:
		if u.get("theme", false):
			themes.append(u)
	for id: String in Upgrades.BADGE_THEMES:
		var bt: Dictionary = Upgrades.BADGE_THEMES[id]
		themes.append({"id": id, "name": bt.name, "text": bt.text, "badge": true})
	for t: Dictionary in themes:
		var id := String(t.id)
		var b := _action_button()
		var desc := String(t.text)
		if GameState.owns_theme(id):
			var in_use := GameState.theme_id == id
			b.text = "In use" if in_use else "Use"
			b.disabled = in_use
			b.theme_type_variation = &"TabButton"
			b.pressed.connect(func() -> void: GameState.set_theme(id))
		elif t.get("badge", false):
			b.text = "Badge reward"
			b.disabled = true
			b.theme_type_variation = &"TabButton"
			desc += "  (Earn \"%s\")" % _badge_for(id)
		else:
			b.text = "Buy  %s" % GameState.format_money(int(t.price))
			b.disabled = not GameState.can_buy(id)
			b.pressed.connect(func() -> void: GameState.buy_upgrade(id))
		_list.add_child(_row(_theme_preview(id), String(t.name) + ("  ·  BADGE" if t.get("badge", false) else ""), desc, b))


# --- Building blocks ----------------------------------------------------------------

func _badge_for(unlock_id: String) -> String:
	for bd: Dictionary in Badges.LIST:
		if String(bd.unlock) == unlock_id:
			return String(bd.name)
	return "a badge"


func _action_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _icon(file: String) -> Control:
	var tex := UiSkin.tex(file)
	if tex == null:
		var ph := PlaceholderIcon.new()
		ph.letter = file.trim_prefix("icon_up_").left(1).to_upper()
		ph.custom_minimum_size = Vector2(96, 84)
		return ph
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(96, 84)
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return ic


## Stand-in upgrade icon until it's drawn: a glowing tile with an initial.
class PlaceholderIcon extends Control:
	var letter := "?"

	func _draw() -> void:
		var r := Rect2(Vector2((size.x - 72) / 2, (size.y - 72) / 2), Vector2(72, 72))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("6b3fa0")
		sb.border_color = Color("3ee6f0")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(18)
		draw_style_box(sb, r)
		var font := get_theme_default_font()
		draw_string(font, Vector2(r.position.x, r.get_center().y + 14), letter, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color("f4f1ff"))


func _row(art: Control, name_text: String, desc: String, button: Button) -> Control:
	var row := PanelContainer.new()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	row.add_child(hb)
	if art:
		hb.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(info)
	var n := Label.new()
	n.text = name_text
	n.theme_type_variation = &"StatusLabel"
	info.add_child(n)
	var d := Label.new()
	d.text = desc
	d.theme_type_variation = &"SlotHint"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	hb.add_child(button)
	return row


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SectionCaption"
	return l


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SlotHint"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A mini café in a theme's colours, inside the drawn theme frame.
func _theme_preview(theme_key: String) -> Control:
	var owned := GameState.owns_theme(theme_key)
	var frame_tex := UiSkin.tex("ui_theme_frame_owned" if owned else "ui_theme_frame_normal")
	var th: Dictionary = Upgrades.THEMES.get(theme_key, Upgrades.THEMES["nebula"])
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 120)
	var window := Rect2(Vector2(150 * 0.12, 120 * 0.29), Vector2(150 * 0.76, 120 * 0.56)) if frame_tex else Rect2(Vector2.ZERO, Vector2(150, 120))
	var cafe_tex := Art.station("st_order_bg")
	if cafe_tex:
		var cafe := TextureRect.new()
		cafe.texture = cafe_tex
		cafe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cafe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cafe.position = window.position
		cafe.size = window.size
		cafe.self_modulate = th.get("tint", Color.WHITE)
		cafe.clip_contents = true
		var wash := ColorRect.new()
		wash.color = th.get("glow", Color(0, 0, 0, 0))
		wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		cafe.add_child(wash)
		holder.add_child(cafe)
	else:
		var live := Starfield.new()
		live.preview_theme = theme_key
		live.star_count = 45
		live.seed_value = 3
		live.position = window.position
		live.size = window.size
		holder.add_child(live)
	if frame_tex:
		var over := TextureRect.new()
		over.texture = frame_tex
		over.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		over.stretch_mode = TextureRect.STRETCH_SCALE
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(over)
	return holder
