extends Node
## Sound and music (autoload "AudioManager"). Most sounds fire from Events,
## so gameplay code rarely needs to know about audio; stations call
## `play()` / `start_loop()` for the few hands-on sounds (pouring, blending,
## topping). Every button gets a click automatically.
##
## The placeholder sounds in res://assets/audio are synthesized; swap in
## your own files with the same names and nothing else changes.

const AUDIO_DIR := "res://assets/audio"
const SFX_NAMES: Array[String] = [
	"click", "bloop", "wrong", "airlock", "print", "clip", "pour_loop", "plunk", "trash",
	"whoosh_send", "blend_loop", "zap_ding", "cream", "sauce", "sprinkle", "plop",
	"serve", "coins", "rank_up", "day_end", "buy",
]
const POOL_SIZE := 10
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var _sfx: Dictionary = {}          # name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}        # name -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_name := ""
var _next_music: AudioStream
var _last_played: Dictionary = {}  # name -> msec, to stop rapid repeats stacking up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for n: String in SFX_NAMES:
		var path := "%s/%s.wav" % [AUDIO_DIR, n]
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	_apply_volumes()

	Events.settings_changed.connect(func(_k: String, _v: Variant) -> void: _apply_volumes())
	Events.customer_arrived.connect(func(_c: CustomerData) -> void: play("airlock"))
	Events.order_taken.connect(func(_o: Order) -> void: play("print"))
	Events.ticket_moved.connect(_on_ticket_moved)
	Events.cup_moved.connect(_on_cup_moved)
	Events.order_served.connect(func(_o: Order, _r: RefCounted) -> void: play("serve"))
	Events.rank_changed.connect(func(_r: int) -> void: play("rank_up"))
	Events.toast.connect(func(_t: String) -> void: play("wrong"))
	Events.day_ended.connect(func(_s: Dictionary) -> void: play("day_end"))
	Events.upgrades_changed.connect(func() -> void: play("buy"))
	get_tree().node_added.connect(_on_node_added)


func play(sfx_name: String, pitch_jitter: float = 0.04, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(sfx_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -1000)) < 40:
		return
	_last_played[sfx_name] = now
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = volume_db
			p.play()
			return


## Starts a looping sound (pour, blender) until stop_loop() is called.
func start_loop(sfx_name: String) -> void:
	if _loops.has(sfx_name) or not _sfx.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	p.bus = SFX_BUS
	p.stream = _sfx[sfx_name]
	p.finished.connect(p.play)
	add_child(p)
	p.play()
	_loops[sfx_name] = p


func stop_loop(sfx_name: String) -> void:
	var p: AudioStreamPlayer = _loops.get(sfx_name)
	if p:
		_loops.erase(sfx_name)
		p.queue_free()


func stop_all_loops() -> void:
	for n: String in _loops.keys():
		stop_loop(n)


## Plays a music track on loop ("music_cafe", "music_title"); fades between tracks.
func play_music(track: String) -> void:
	if track == _music_name and (_music.playing or _next_music != null):
		return  # already playing, or already fading in
	var path := "%s/%s.ogg" % [AUDIO_DIR, track]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_name = track
	_next_music = stream
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.4)
	tw.tween_callback(_swap_music)
	tw.tween_property(_music, "volume_db", 0.0, 0.8)


func _swap_music() -> void:
	if _next_music == null:
		return
	_music.stream = _next_music
	_next_music = null
	_music.volume_db = -40.0
	_music.play()


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
	_next_music = null


func _process(_delta: float) -> void:
	# Hands-on loops shouldn't keep running under a pause or score card.
	var paused := get_tree().paused
	for p: AudioStreamPlayer in _loops.values():
		p.stream_paused = paused


func _on_ticket_moved(_o: Order, _from: StringName, to_location: StringName) -> void:
	if StationIds.accepts_tickets(to_location):
		play("clip")


func _on_cup_moved(_o: Order, from_location: StringName, to_location: StringName) -> void:
	if to_location == &"":
		play("trash")
	elif from_location == &"":
		play("plunk")
	elif to_location == StationIds.ZAP_SHELF or to_location == StationIds.TOP_SHELF:
		play("whoosh_send")
	elif to_location == StationIds.READY:
		play("bloop")


func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b and not b.is_in_group(&"silent_button"):
		b.pressed.connect(func() -> void: play("click", 0.02, -6.0))


func _apply_volumes() -> void:
	_set_bus_volume(MUSIC_BUS, float(GameState.get_setting("music_volume")))
	_set_bus_volume(SFX_BUS, float(GameState.get_setting("sfx_volume")))


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
