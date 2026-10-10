extends Control
## Title screen: Continue (from the last saved day), New Game, Settings, Quit.

const GAME_SCENE := "res://scenes/main/main.tscn"
const CONFIRM_SECONDS := 3.0

var _confirming_new := false

@onready var _continue: Button = %Continue
@onready var _new_game: Button = %NewGame
@onready var _settings: Button = %Settings
@onready var _quit: Button = %Quit
@onready var _fade: ColorRect = %Fade
@onready var _parade: Control = %Parade
@onready var _settings_menu: PauseMenu = %SettingsMenu


func _ready() -> void:
	get_tree().paused = false
	_apply_art()
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_settings.pressed.connect(func() -> void: _settings_menu.open())
	# Badges, straight from the title screen.
	var badges_btn := Button.new()
	badges_btn.text = "Badges"
	badges_btn.focus_mode = Control.FOCUS_NONE
	badges_btn.custom_minimum_size = _settings.custom_minimum_size
	badges_btn.theme_type_variation = _settings.theme_type_variation
	_settings.get_parent().add_child(badges_btn)
	_settings.get_parent().move_child(badges_btn, _settings.get_index() + 1)
	var badges_panel := BadgesPanel.new()
	add_child(badges_panel)
	badges_btn.pressed.connect(badges_panel.open)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_quit.visible = not (OS.has_feature("mobile") or OS.has_feature("web"))
	_refresh_continue()
	# The code-drawn customer parade is off until the customers are drawn.
	# _spawn_parade()
	AudioManager.stop_all_loops()
	AudioManager.play_music("music_title")
	_fade.visible = true
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.5)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_continue() -> void:
	if GameState.has_save():
		var day := _saved_day()
		_continue.text = "Continue  ·  Day %d" % day
		_continue.disabled = false
	else:
		_continue.text = "Continue"
		_continue.disabled = true


func _saved_day() -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	return int(data.get("day", 1)) if data is Dictionary else 1


func _on_continue() -> void:
	if GameState.load_game():
		_start()


func _on_new_game() -> void:
	if GameState.has_save() and not _confirming_new:
		_confirming_new = true
		_new_game.text = "Tap again to start over"
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func() -> void:
			_confirming_new = false
			if is_instance_valid(_new_game):
				_new_game.text = "New Game")
		return
	GameState.new_game()
	GameState.save_game()
	_start()


func _start() -> void:
	for b: Button in [_continue, _new_game, _settings, _quit]:
		b.disabled = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


## A few regulars bobbing along the bottom of the screen.
func _spawn_parade() -> void:
	var scene := preload("res://scenes/entities/customer.tscn")
	var picks: Array[CustomerData] = []
	for c: CustomerData in GameState.catalog.customers:
		if c.species == CustomerData.Species.BLORB and picks.size() < 1:
			picks.append(c)
		elif c.species != CustomerData.Species.BLORB and picks.size() < 5:
			var dup := false
			for p: CustomerData in picks:
				if p.species == c.species:
					dup = true
			if not dup:
				picks.append(c)
	for i in picks.size():
		var cust: Customer = scene.instantiate()
		cust.setup(picks[i])
		cust.state = Customer.State.SERVED
		_parade.add_child(cust)
		cust.place_at(Vector2(260 + i * 350, _parade.size.y - 10))


## Ty's title painting behind everything. Its café sign is the logo, so the
## text title gives way to a spacer that keeps the menu below the sign.
## Without the painting, the drawn logo (ui_logo) replaces the text title.
func _apply_art() -> void:
	var title := get_node_or_null("Center/Box/Title") as Label
	var bg := UiSkin.tex("bg_title")
	if bg:
		var art := TextureRect.new()
		art.texture = bg
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		UiSkin.follow_theme(art, "tint")
		var shade := ColorRect.new()
		shade.color = Color(0.04, 0.05, 0.16, 0.3)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.add_child(shade)
		var star := get_node_or_null("Starfield")
		add_child(art)
		move_child(art, star.get_index() + 1 if star else 1)
		if title:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 340)
			title.get_parent().add_child(spacer)
			title.get_parent().move_child(spacer, title.get_index())
			title.visible = false
		return
	var logo_tex := UiSkin.tex("ui_logo")
	if logo_tex and title:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(720, 300)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.get_parent().add_child(logo)
		title.get_parent().move_child(logo, title.get_index())
		title.visible = false
