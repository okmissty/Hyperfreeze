extends Control
## Root of the game. Owns which station is visible and starts the day.
##
## Keys: 1–4 switch stations. Debug builds only: F2 brings in a customer
## now, F3 toggles 4× speed.

const STATION_KEYS := {
	KEY_1: StationIds.ORDER,
	KEY_2: StationIds.BUILD,
	KEY_3: StationIds.ZAP,
	KEY_4: StationIds.TOP,
}

var current_station: StringName = &""
var _stations: Dictionary = {}  # StringName -> BaseStation

@onready var _station_root: Control = %Stations
@onready var _banner: Label = %Banner
@onready var _banner_sub: Label = %BannerSub
@onready var _toast: Label = %Toast
var _toast_tween: Tween
var _pending_tips: Dictionary = {}  # Order -> tip cents, paid out as flying coins


func _ready() -> void:
	for child in _station_root.get_children():
		var station := child as BaseStation
		if station:
			_stations[station.station_id] = station
			station.visible = false
	Events.request_station.connect(show_station)
	Events.day_started.connect(_show_day_banner)
	Events.toast.connect(show_toast)
	Events.shop_closed.connect(func() -> void: show_toast("6 PM - closed! Serve the customers still inside"))
	Events.rank_changed.connect(func(rank: int) -> void: show_toast("Rank up! You're now rank %d" % rank))
	show_station(StationIds.ORDER)
	AudioManager.play_music(GameState.cafe_music())
	DayManager.start_day()
	var fade: ColorRect = %Fade
	fade.create_tween().tween_property(fade, "modulate:a", 0.0, 0.5)
	(%DayEndScreen as DayEndScreen).shop_requested.connect((%ShopPanel as ShopPanel).open)
	Events.shop_requested.connect((%ShopPanel as ShopPanel).open)
	Events.order_served.connect(func(order: Order, result: RefCounted) -> void:
		_pending_tips[order] = (result as Scorer.Result).tip_cents)
	Events.score_card_closed.connect(_on_score_card_closed)
	add_child(BadgePopup.new())
	if GameState.pending_notice != "":
		show_toast.call_deferred(GameState.pending_notice)
		GameState.pending_notice = ""


func show_station(station_id: StringName) -> void:
	if station_id == current_station or not _stations.has(station_id):
		return
	if _stations.has(current_station):
		var old: BaseStation = _stations[current_station]
		old.on_exit()
		old.visible = false
	current_station = station_id
	var station: BaseStation = _stations[station_id]
	station.visible = true
	station.on_enter()
	Events.station_changed.emit(station_id)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if STATION_KEYS.has(key.keycode):
		show_station(STATION_KEYS[key.keycode])
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and key.keycode == KEY_F2:
		DayManager.spawn_customer_now()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and key.keycode == KEY_F3:
		Engine.time_scale = 1.0 if Engine.time_scale > 1.0 else 4.0
		get_viewport().set_input_as_handled()


func _show_day_banner(day: int) -> void:
	_banner.text = "Day %d" % day
	_banner_sub.text = "Hyperfreeze is open  ·  9 AM - 6 PM"
	for label: Label in [_banner, _banner_sub]:
		label.visible = true
		label.modulate.a = 0.0
		var tw := label.create_tween()
		tw.tween_property(label, "modulate:a", 1.0, 0.3)
		tw.tween_interval(1.6)
		tw.tween_property(label, "modulate:a", 0.0, 0.5)
		tw.tween_callback(label.hide)


## Brief hint near the top of the play area.
func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = _toast.create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


## Coins fly from the middle of the screen to the tips counter.
func _on_score_card_closed(order: Order) -> void:
	var tip: int = _pending_tips.get(order, 0)
	_pending_tips.erase(order)
	if tip <= 0:
		return
	var fx: Control = get_tree().get_first_node_in_group(&"fx_layer")
	var target: Control = get_node("TopBar/HUD").get_node("%MoneyValue")
	var goal := target.global_position + target.size / 2.0
	var count := clampi(tip / 60 + 3, 3, 9)
	for i in count:
		var coin := Coin.new()
		fx.add_child(coin)
		coin.global_position = size / 2.0 + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		var tw := coin.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(coin, "global_position", goal, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(coin.queue_free)
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		AudioManager.play("coins")
		target.pivot_offset = target.size / 2.0
		var pulse := target.create_tween()
		pulse.tween_property(target, "scale", Vector2(1.25, 1.25), 0.1)
		pulse.tween_property(target, "scale", Vector2.ONE, 0.2))


class Coin extends Control:
	var _frames: Array[Texture2D] = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 4:
			var f := UiSkin.tex("ui_coin_%02d" % (i + 1))
			if f:
				_frames.append(f)

	func _process(delta: float) -> void:
		_t += delta
		if not _frames.is_empty():
			queue_redraw()

	func _draw() -> void:
		if not _frames.is_empty():
			var f := _frames[int(_t * 14.0) % _frames.size()]
			Art.draw_fit(self, f, Rect2(Vector2(-20, -20), Vector2(40, 40)))
			return
		draw_circle(Vector2.ZERO, 14, Color("ffd95a"))
		draw_arc(Vector2.ZERO, 14, 0, TAU, 20, Color("c99a1e"), 3.0, true)
		draw_circle(Vector2(-4, -4), 4, Color(1, 1, 1, 0.6))
