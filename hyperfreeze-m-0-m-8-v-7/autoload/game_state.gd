extends Node
## Long-lived player progress (autoload "GameState"): money, XP, rank,
## the menu catalog, every regular's favourite order, loyalty, upgrades,
## settings, and saving all of it between sessions.

const RANK_TABLE_PATH := "res://data/ranks.tres"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
## Critic reviews averaged into the café rating.
const REVIEW_HISTORY := 5
## A zap scoring at least this counts toward the perfect-zap streak.
const PERFECT_ZAP := 95
const DEFAULT_SETTINGS := {
	## Jump to the next station and load the cup automatically when you send it on.
	"follow_cup": true,
	"fullscreen": false,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	## 0 = calm café loop, 1 = jukebox track (needs the Jukebox on display).
	"cafe_track": 0,
}
## Visits scoring at least this count toward a customer's gold star.
const GREAT_VISIT_SCORE := 90
const GREAT_VISITS_FOR_GOLD := 3
## Gold-star customers tip this much more.
const GOLD_TIP_BONUS := 0.25

var catalog := Catalog.new()
var rank_table: RankTable

var day: int = 1
var money_cents: int = 0
var xp: int = 0
## Rank can be pinned for testing; -1 means "use XP".
var debug_rank_override: int = -1

## customer id (StringName) -> Order (their favourite recipe)
var customer_favorites: Dictionary = {}
## customer id (StringName) -> {"great": int, "gold": bool}
var loyalty: Dictionary = {}
var owned_upgrades: Array[String] = []
var theme_id: String = "nebula"
## What the most recent rank-up unlocked (for the day-end report).
var last_unlocks: Array[String] = []
var last_new_customers: Array[String] = []

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()

## Running totals that badges read (see Badges for the keys).
var stats: Dictionary = {}
var badges_earned: Array[String] = []
## Badge-only rewards (decor and themes you can't buy).
var unlocks: Array[String] = []
var decor_owned: Array[String] = []
## slot -> decor id on display in the lobby.
var decor_placed: Dictionary = {}
## Recent critic reviews (1-5 stars), newest last.
var reviews: Array[int] = []
var last_critic_day := 0
## Reserved for the playable worker (look, outfit) coming later.
var worker: Dictionary = {}
## One-off message for the next shift (e.g. a refund note).
var pending_notice := ""

## Hyperfreeze Blenders in the café (always one: blending is hands-on).
var blender_count: int:
	get:
		return 1

var _rng := RandomNumberGenerator.new()


func _exit_tree() -> void:
	Art.clear()


func _ready() -> void:
	UiSkin.apply()
	process_mode = Node.PROCESS_MODE_ALWAYS  # F11 works while paused
	_rng.randomize()
	_load_settings()
	_apply_fullscreen()
	catalog.load_all()
	rank_table = load(RANK_TABLE_PATH) as RankTable
	if rank_table == null:
		push_warning("GameState: %s missing, using default rank table" % RANK_TABLE_PATH)
		rank_table = RankTable.new()


func get_rank() -> int:
	if debug_rank_override > 0:
		return debug_rank_override
	return rank_table.rank_for_xp(xp)


func add_money(cents: int) -> void:
	money_cents += cents
	Events.money_changed.emit(money_cents)


func add_xp(amount: int) -> void:
	var old_rank := get_rank()
	xp += amount
	var new_rank := get_rank()
	if new_rank > old_rank:
		_on_rank_up(old_rank, new_rank)
		Events.rank_changed.emit(new_rank)
		check_badges()


## Fraction of the way from this rank to the next (1.0 at max rank).
func rank_progress() -> float:
	var r := get_rank()
	var lo: int = rank_table.xp_thresholds[r - 1]
	var hi := rank_table.xp_for_next_rank(xp)
	if hi < 0:
		return 1.0
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)


## New ingredients and customers for the ranks just reached; a couple of
## regulars start ordering each new ingredient.
func _on_rank_up(old_rank: int, new_rank: int) -> void:
	for key: StringName in catalog.ingredients:
		var ing: IngredientData = catalog.ingredients[key]
		if ing.unlock_rank > old_rank and ing.unlock_rank <= new_rank:
			last_unlocks.append(ing.display_name)
			var regulars: Array = customer_favorites.keys()
			regulars.shuffle()
			for i in mini(2, regulars.size()):
				OrderGenerator.add_new_ingredient(customer_favorites[regulars[i]], ing, _rng)
	for c: CustomerData in catalog.customers:
		if c.unlock_rank > old_rank and c.unlock_rank <= new_rank:
			last_new_customers.append(c.display_name)


# --- Loyalty ------------------------------------------------------------------

## Records a visit; returns true if this visit earned the customer's gold star.
func record_visit(customer: CustomerData, total: int) -> bool:
	var entry: Dictionary = loyalty.get(customer.id, {"great": 0, "gold": false})
	var earned := false
	if total >= GREAT_VISIT_SCORE and not entry.gold:
		entry.great = int(entry.great) + 1
		if entry.great >= GREAT_VISITS_FOR_GOLD:
			entry.gold = true
			earned = true
	loyalty[customer.id] = entry
	return earned


func has_gold_star(customer: CustomerData) -> bool:
	return bool(loyalty.get(customer.id, {}).get("gold", false))


func great_visits(customer: CustomerData) -> int:
	return int(loyalty.get(customer.id, {}).get("great", 0))


# --- Upgrades -----------------------------------------------------------------

func owns(upgrade_id: String) -> bool:
	return upgrade_id in owned_upgrades


func can_buy(upgrade_id: String) -> bool:
	var u := Upgrades.find(upgrade_id)
	if u.is_empty() or owns(upgrade_id) or money_cents < int(u.price):
		return false
	return u.get("requires", "") == "" or owns(String(u.requires))


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	var u := Upgrades.find(upgrade_id)
	add_money(-int(u.price))
	owned_upgrades.append(upgrade_id)
	Events.upgrades_changed.emit()
	if u.get("theme", false):
		set_theme(upgrade_id)
	check_badges()
	return true


func owns_theme(id: String) -> bool:
	return id == "nebula" or owns(id) or id in unlocks


func set_theme(id: String) -> void:
	if not owns_theme(id):
		return
	theme_id = id
	Events.theme_changed.emit(id)


# --- Lobby decor ----------------------------------------------------------------

func owns_decor(id: String) -> bool:
	return id in decor_owned or id in unlocks


func buy_decor(id: String) -> bool:
	var d := Upgrades.find_decor(id)
	if d.is_empty() or d.get("badge", false) or owns_decor(id) or money_cents < int(d.price):
		return false
	add_money(-int(d.price))
	decor_owned.append(id)
	place_decor(id)
	check_badges()
	return true


## Puts an owned item on display in its slot (replacing what was there).
func place_decor(id: String) -> void:
	var d := Upgrades.find_decor(id)
	if d.is_empty() or not owns_decor(id):
		return
	decor_placed[String(d.slot)] = id
	Events.decor_changed.emit()


func remove_decor(slot: String) -> void:
	decor_placed.erase(slot)
	Events.decor_changed.emit()


func is_decor_placed(id: String) -> bool:
	return id in decor_placed.values()


# --- Café rating (critics) ----------------------------------------------------

func cafe_rating() -> float:
	if reviews.is_empty():
		return 3.0
	var total := 0
	for r in reviews:
		total += r
	return float(total) / reviews.size()


func record_review(stars: int) -> void:
	reviews.append(clampi(stars, 1, 5))
	while reviews.size() > REVIEW_HISTORY:
		reviews.pop_front()
	bump("critics_served")
	if stars >= 5:
		bump("critic_five_star")
	Events.review_posted.emit(stars, cafe_rating())
	check_badges()


# --- Badges -------------------------------------------------------------------

func stat(key: String) -> int:
	return int(stats.get(key, 0))


func bump(key: String, amount: int = 1) -> void:
	stats[key] = stat(key) + amount


## Updates stats from a served order, then awards any badges now earned.
func record_served(order: Order, result: Scorer.Result) -> void:
	bump("served")
	if result.total >= 100:
		bump("perfects")
	bump("tips_cents", result.tip_cents)
	if result.zap >= PERFECT_ZAP:
		bump("great_zap_streak")
		stats["great_zap_streak_best"] = maxi(stat("great_zap_streak_best"), stat("great_zap_streak"))
	else:
		stats["great_zap_streak"] = 0
	check_badges()


func record_day_end(summary: Dictionary) -> void:
	bump("days")
	var served := int(summary.get("served", 0))
	if served >= 4 and int(summary.get("min_total", 0)) >= 90:
		bump("flawless_days")
	if served >= 5 and int(summary.get("min_wait", 0)) >= 80:
		bump("patient_days")
	check_badges()


## Values for badges that are worked out rather than counted.
func _live_stat(key: String) -> int:
	match key:
		"rank":
			return get_rank()
		"decor_owned":
			return decor_owned.size()
		"upgrades_owned":
			var n := 0
			for u: Dictionary in Upgrades.LIST:
				if not u.get("theme", false) and owns(String(u.id)):
					n += 1
			return n
		"gold_stars":
			var g := 0
			for id: StringName in loyalty:
				if bool(loyalty[id].get("gold", false)):
					g += 1
			return g
		"top_rated":
			return 1 if reviews.size() >= 3 and cafe_rating() >= 4.5 else 0
	return stat(key)


func badge_progress(b: Dictionary) -> int:
	return mini(_live_stat(String(b.stat)), int(b.goal))


func has_badge(id: String) -> bool:
	return id in badges_earned


## Awards every badge whose goal is now met: coins, plus its exclusive unlock.
func check_badges() -> void:
	for b: Dictionary in Badges.LIST:
		if has_badge(String(b.id)) or _live_stat(String(b.stat)) < int(b.goal):
			continue
		badges_earned.append(String(b.id))
		add_money(int(b.reward))
		var unlock := String(b.unlock)
		if unlock != "" and unlock not in unlocks:
			unlocks.append(unlock)
		Events.badge_earned.emit(b)


func theme_colors() -> Dictionary:
	return Upgrades.THEMES.get(theme_id, Upgrades.THEMES["nebula"])


## Multiplier on every patience window (lobby pods + decor on display).
func patience_mult() -> float:
	var m := 1.0
	if owns(Upgrades.COMFY_PODS):
		m += 0.25
	if owns(Upgrades.COMFY_PODS_2):
		m += 0.2
	for id: String in decor_placed.values():
		var d := Upgrades.find_decor(id)
		m += Upgrades.BADGE_DECOR_PATIENCE if d.get("badge", false) else Upgrades.DECOR_PATIENCE
	return m


## Gameplay music: the jukebox track if it's on display and selected.
func cafe_music() -> String:
	if is_decor_placed(Upgrades.JUKEBOX) and int(get_setting("cafe_track")) == 1:
		return "music_cafe_2"
	return "music_cafe"


## Blender meter speed (Hyper Motor).
func zap_rate_mult() -> float:
	return 1.25 if owns(Upgrades.HYPER_MOTOR) else 1.0


## Width of the zap target bands (Steady Gauge).
func zap_band_mult() -> float:
	return 1.3 if owns(Upgrades.STEADY_GAUGE) else 1.0


## Tip multiplier: Tip Jar and the café rating (3 stars = neutral).
func tip_mult() -> float:
	var m := 1.0 + (cafe_rating() - 3.0) * 0.08
	if owns(Upgrades.TIP_JAR):
		m *= 1.1
	return m


## Multiplier on the time between arrivals (lower = busier):
## Neon Billboard and a good café rating bring people in.
func traffic_mult() -> float:
	var m := 1.0 - (cafe_rating() - 3.0) * 0.05
	if owns(Upgrades.NEON_BILLBOARD):
		m *= 0.85
	return m


## Extra cream strips filled on each side per sweep (Whip Cannon).
func cream_spread() -> int:
	return 1 if owns(Upgrades.WHIP_CANNON) else 0


## Multiplier on pour speed (Turbo Taps).
func pour_mult() -> float:
	return 1.4 if owns(Upgrades.TURBO_TAPS) else 1.0


## The customer's saved favourite, generating it on their first visit.
func get_favorite(customer: CustomerData) -> Order:
	if not customer_favorites.has(customer.id):
		customer_favorites[customer.id] = OrderGenerator.generate(customer, catalog, get_rank(), _rng)
	return customer_favorites[customer.id] as Order


@warning_ignore("integer_division")
static func format_money(cents: int) -> String:
	var sign_text := "-" if cents < 0 else ""
	var c := absi(cents)
	return "%s$%d.%02d" % [sign_text, c / 100, c % 100]


# --- Settings -----------------------------------------------------------------

func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_settings()
	if key == "fullscreen":
		_apply_fullscreen()
	Events.settings_changed.emit(key, value)


func toggle_fullscreen() -> void:
	set_setting("fullscreen", not bool(get_setting("fullscreen")))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Fullscreen goes through Godot (not the OS window button) so the game
## surface is resized with the window on every platform.
func _apply_fullscreen() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if bool(get_setting("fullscreen")):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key: String in DEFAULT_SETTINGS:
		settings[key] = cfg.get_value("settings", key, DEFAULT_SETTINGS[key])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


# --- Save / load --------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Wipes progress (settings are kept).
func new_game() -> void:
	day = 1
	money_cents = 0
	xp = 0
	customer_favorites.clear()
	loyalty.clear()
	owned_upgrades.clear()
	theme_id = "nebula"
	stats.clear()
	badges_earned.clear()
	unlocks.clear()
	decor_owned.clear()
	decor_placed.clear()
	reviews.clear()
	last_critic_day = 0
	worker.clear()
	last_unlocks.clear()
	last_new_customers.clear()
	Events.money_changed.emit(money_cents)


## Moves to the next day and saves (called from the day-end screen).
func advance_day() -> void:
	day += 1
	save_game()


func save_game() -> bool:
	var favs := {}
	for id: StringName in customer_favorites:
		favs[String(id)] = _order_to_dict(customer_favorites[id])
	var loy := {}
	for id: StringName in loyalty:
		loy[String(id)] = loyalty[id]
	var data := {
		"version": SAVE_VERSION,
		"day": day,
		"money_cents": money_cents,
		"xp": xp,
		"favorites": favs,
		"loyalty": loy,
		"upgrades": owned_upgrades,
		"theme": theme_id,
		"stats": stats,
		"badges": badges_earned,
		"unlocks": unlocks,
		"decor_owned": decor_owned,
		"decor_placed": decor_placed,
		"reviews": reviews,
		"last_critic_day": last_critic_day,
		"worker": worker,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("GameState: could not write %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("GameState: save file is damaged")
		return false
	new_game()
	day = int(data.get("day", 1))
	money_cents = int(data.get("money_cents", 0))
	xp = int(data.get("xp", 0))
	var favs: Dictionary = data.get("favorites", {})
	for id: String in favs:
		customer_favorites[StringName(id)] = _order_from_dict(favs[id])
	var loy: Dictionary = data.get("loyalty", {})
	for id: String in loy:
		var e: Dictionary = loy[id]
		loyalty[StringName(id)] = {"great": int(e.get("great", 0)), "gold": bool(e.get("gold", false))}
	for u: Variant in data.get("upgrades", []):
		owned_upgrades.append(String(u))
	# The second blender was retired: refund it.
	if Upgrades.SECOND_BLENDER in owned_upgrades:
		owned_upgrades.erase(Upgrades.SECOND_BLENDER)
		money_cents += Upgrades.SECOND_BLENDER_REFUND
		pending_notice = "The second blender was retired - refunded %s" % format_money(Upgrades.SECOND_BLENDER_REFUND)
	theme_id = String(data.get("theme", "nebula"))
	var st: Dictionary = data.get("stats", {})
	for k: String in st:
		stats[k] = int(st[k])
	for b: Variant in data.get("badges", []):
		badges_earned.append(String(b))
	for u2: Variant in data.get("unlocks", []):
		unlocks.append(String(u2))
	for d: Variant in data.get("decor_owned", []):
		decor_owned.append(String(d))
	var placed: Dictionary = data.get("decor_placed", {})
	for slot: String in placed:
		decor_placed[slot] = String(placed[slot])
	for r: Variant in data.get("reviews", []):
		reviews.append(int(r))
	last_critic_day = int(data.get("last_critic_day", 0))
	worker = data.get("worker", {})
	if not owns_theme(theme_id):
		theme_id = "nebula"
	Events.money_changed.emit(money_cents)
	return true


static func _order_to_dict(o: Order) -> Dictionary:
	var mix: Array[String] = []
	for m: StringName in o.mixin_ids:
		mix.append(String(m))
	var tops: Array[String] = []
	for t: StringName in o.toppers:
		tops.append(String(t))
	return {
		"size": o.size, "base": String(o.base_id), "mixins": mix, "zap": o.zap_level,
		"cream": o.wants_cream, "sauce": String(o.sauce_id), "sprinkles": String(o.sprinkle_id), "toppers": tops,
	}


static func _order_from_dict(d: Dictionary) -> Order:
	var o := Order.new()
	o.size = int(d.get("size", 1)) as Order.CupSize
	o.base_id = StringName(d.get("base", ""))
	for m: Variant in d.get("mixins", []):
		o.mixin_ids.append(StringName(m))
	o.zap_level = int(d.get("zap", 1)) as Order.ZapLevel
	o.wants_cream = bool(d.get("cream", true))
	o.sauce_id = StringName(d.get("sauce", ""))
	o.sprinkle_id = StringName(d.get("sprinkles", ""))
	var tops: Array = d.get("toppers", [])
	for i in mini(tops.size(), Order.TOPPER_SLOTS):
		o.toppers[i] = StringName(tops[i])
	return o
