class_name PauseMenu
extends Control
## Pause overlay with game settings. Opening it pauses the whole game
## (clock, customers, blenders); Esc or Resume closes it.

const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"

## False on the title screen: no pausing, no "Quit to Title".
@export var in_game := true

var _follow: CheckButton
var _fullscreen: CheckButton
var _music: HSlider
var _sfx: HSlider
var _title: Label
var _quit_box: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "Paused" if in_game else "Settings"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_follow = CheckButton.new()
	_follow.text = "Follow the cup"
	_follow.focus_mode = Control.FOCUS_NONE
	_follow.toggled.connect(func(on: bool) -> void: GameState.set_setting("follow_cup", on))
	box.add_child(_follow)
	box.add_child(_hint("When you send a cup on, jump to the next station and load it into the free machine. Turn off to juggle stations yourself."))

	_fullscreen = CheckButton.new()
	_fullscreen.text = "Fullscreen  (F11)"
	_fullscreen.focus_mode = Control.FOCUS_NONE
	_fullscreen.toggled.connect(func(on: bool) -> void: GameState.set_setting("fullscreen", on))
	box.add_child(_fullscreen)
	if OS.has_feature("mobile"):
		_fullscreen.visible = false

	_music = _slider(box, "Music", "music_volume")
	_sfx = _slider(box, "Sound effects", "sfx_volume")

	var badges := Button.new()
	badges.text = "Badges"
	badges.theme_type_variation = &"SecondaryButton"
	badges.focus_mode = Control.FOCUS_NONE
	badges.pressed.connect(_open_badges)
	box.add_child(badges)

	var resume := Button.new()
	resume.text = "Resume" if in_game else "Done"
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(close)
	box.add_child(resume)

	var quit_box := VBoxContainer.new()
	quit_box.visible = in_game
	box.add_child(quit_box)
	var shop := Button.new()
	shop.text = "Shop"
	shop.focus_mode = Control.FOCUS_NONE
	shop.pressed.connect(func() -> void:
		close()
		Events.shop_requested.emit())
	quit_box.add_child(shop)
	var quit := Button.new()
	quit.text = "Quit to Title"
	quit.theme_type_variation = &"SecondaryButton"
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(quit_to_title)
	quit_box.add_child(quit)
	quit_box.add_child(_hint("Progress saves at the end of each day. Quitting now restarts today."))
	_quit_box = quit_box

	Events.pause_requested.connect(open)
	Events.settings_changed.connect(func(_k: String, _v: Variant) -> void: _sync())


var _badges_panel: BadgesPanel


## Badges open on top of this menu (and of the title screen).
func _open_badges() -> void:
	if _badges_panel == null:
		_badges_panel = BadgesPanel.new()
		get_parent().add_child(_badges_panel)
	_badges_panel.open()


func open() -> void:
	_sync()
	visible = true
	if in_game:
		get_tree().paused = true


func close() -> void:
	visible = false
	if in_game:
		get_tree().paused = false


func quit_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	DayManager.day_running = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _sync() -> void:
	_follow.set_pressed_no_signal(bool(GameState.get_setting("follow_cup")))
	_fullscreen.set_pressed_no_signal(bool(GameState.get_setting("fullscreen")))
	_music.set_value_no_signal(float(GameState.get_setting("music_volume")))
	_sfx.set_value_no_signal(float(GameState.get_setting("sfx_volume")))


func _slider(box: VBoxContainer, caption: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(260, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void: GameState.set_setting(key, v))
	row.add_child(slider)
	return slider


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not in_game and not visible:
		return
	if key and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_P):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SlotHint"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(680, 0)
	return l
