class_name Upgrades
extends RefCounted
## Everything the shop sells, plus the badge-only rewards.
## Effects are read through GameState helpers (patience_mult, pour_mult,
## zap_rate_mult, zap_band_mult, tip_mult, traffic_mult, cream_spread).

# --- Gameplay upgrades ---------------------------------------------------------
const COMFY_PODS := "comfy_pods"
const COMFY_PODS_2 := "comfy_pods_2"
const TURBO_TAPS := "turbo_taps"
const HYPER_MOTOR := "hyper_motor"
const STEADY_GAUGE := "steady_gauge"
const WHIP_CANNON := "whip_cannon"
const TIP_JAR := "tip_jar"
const NEON_BILLBOARD := "neon_billboard"
## Retired: zapping is hold-to-blend, so a second machine never helped.
## Saves that owned it are refunded on load.
const SECOND_BLENDER := "second_blender"
const SECOND_BLENDER_REFUND := 4500

const THEME_SUNBURST := "theme_sunburst"
const THEME_AURORA := "theme_aurora"
# Badge-only themes (never sold).
const THEME_MIDNIGHT := "theme_midnight"
const THEME_CANDY := "theme_candy"
const THEME_SILVER := "theme_silver"

## "requires" = another upgrade that must be owned first.
const LIST: Array[Dictionary] = [
	{"id": COMFY_PODS, "name": "Comfy Lobby Pods", "price": 2500,
		"text": "Customers wait 25% longer before their patience starts slipping."},
	{"id": TURBO_TAPS, "name": "Turbo Taps", "price": 3000,
		"text": "Base taps pour 40% faster."},
	{"id": WHIP_CANNON, "name": "Whip Cannon", "price": 3500,
		"text": "Each cream sweep covers three strips of the dome at once."},
	{"id": HYPER_MOTOR, "name": "Hyper Motor", "price": 4000,
		"text": "The Hyperfreeze zaps 25% faster."},
	{"id": TIP_JAR, "name": "Cosmic Tip Jar", "price": 5000,
		"text": "Every customer tips 10% more."},
	{"id": STEADY_GAUGE, "name": "Steady Gauge", "price": 5500,
		"text": "Zap target bands are 30% wider."},
	{"id": COMFY_PODS_2, "name": "Deluxe Lobby Pods", "price": 6000, "requires": COMFY_PODS,
		"text": "Even comfier: patience lasts 20% longer again."},
	{"id": NEON_BILLBOARD, "name": "Neon Billboard", "price": 9000,
		"text": "A sign out in the space lane: more customers every day."},
	{"id": THEME_SUNBURST, "name": "Sunburst Café Theme", "price": 1500, "theme": true,
		"text": "Bathes the whole café in warm golden light."},
	{"id": THEME_AURORA, "name": "Aurora Café Theme", "price": 1500, "theme": true,
		"text": "A cool teal-green glow across the whole café."},
]

# --- Lobby decor ----------------------------------------------------------------
## One item per slot is on display; each displayed item adds waiting
## patience. "badge" items are only unlocked by badges, never sold.
## Slots: wall (poster spot), corner (left of the lobby), floor (by the
## counter), counter (on the counter top).
const SLOTS: Array[String] = ["wall", "corner", "floor", "counter"]
const SLOT_NAMES := {"wall": "Wall", "corner": "Corner", "floor": "Floor", "counter": "Counter"}
## Patience bonus per displayed item (badge items give a little more).
const DECOR_PATIENCE := 0.04
const BADGE_DECOR_PATIENCE := 0.06
const JUKEBOX := "decor_jukebox"

const DECOR: Array[Dictionary] = [
	{"id": "decor_nebula_poster", "name": "Nebula Poster", "slot": "wall", "price": 2000,
		"text": "A swirly purple nebula print."},
	{"id": "decor_rocket_poster", "name": "Retro Rocket Poster", "slot": "wall", "price": 2500,
		"text": "Vintage travel art: 'Visit the Rings!'"},
	{"id": "decor_moon_fern", "name": "Moon Fern", "slot": "corner", "price": 2000,
		"text": "A leafy fern that glows faintly at night."},
	{"id": "decor_crystal_cactus", "name": "Crystal Cactus", "slot": "corner", "price": 3000,
		"text": "Prickly, sparkly, never needs water."},
	{"id": "decor_jelly_tank", "name": "Space Jelly Tank", "slot": "floor", "price": 4500,
		"text": "Three floaty jellies bob in a glowing tank."},
	{"id": "decor_arcade", "name": "Arcade Cabinet", "slot": "floor", "price": 5500,
		"text": "Asteroid Blaster: high score 999,999."},
	{"id": JUKEBOX, "name": "Jukebox", "slot": "floor", "price": 6000,
		"text": "Adds a second café song. Tap the jukebox to switch tracks."},
	{"id": "decor_lava_lamp", "name": "Lava Lamp", "slot": "counter", "price": 2500,
		"text": "Slow blobs of plasma, very relaxing."},
	# Badge-only
	{"id": "decor_golden_cone", "name": "Golden Cone Trophy", "slot": "counter", "badge": true,
		"text": "Awarded for serving 100 treats."},
	{"id": "decor_critic_plaque", "name": "Critic's Plaque", "slot": "wall", "badge": true,
		"text": "A framed five-star review."},
	{"id": "decor_captain_statue", "name": "Star Captain Statue", "slot": "corner", "badge": true,
		"text": "A tiny bronze explorer, for true cosmic tycoons."},
	{"id": "decor_disco_orb", "name": "Disco Orb", "slot": "floor", "badge": true,
		"text": "A spinning orb that throws stars around the lobby."},
]

## Look of each café theme: the sky outside (style + colours), star tint
## and the café floor colour.
##   style "clouds"  soft nebula clouds
##   style "sun"     a big glowing sun with slow rays and a warm haze
##   style "ribbons" waving aurora bands
const THEMES := {
	"nebula": {
		"style": "clouds", "bg": Color("0b0d2a"), "star": Color(1, 1, 1),
		"clouds": [Color("6b3fa0"), Color("ff7eb6"), Color("3ee6f0")],
		"floor": Color(0.098, 0.078, 0.247, 0.94),
		# tint = colour grade on the painted café; accent = UI frames; glow = light wash over the café
		"tint": Color(1, 1, 1), "accent": Color(1, 1, 1), "glow": Color(0, 0, 0, 0),
	},
	THEME_SUNBURST: {
		"style": "sun", "bg": Color("2a1030"), "star": Color("ffe3a3"),
		"clouds": [Color("ff9f43"), Color("ffd95a"), Color("ff5c7a")],
		"floor": Color(0.22, 0.09, 0.16, 0.95),
		"tint": Color(1.0, 0.84, 0.64), "accent": Color(1.0, 0.82, 0.55), "glow": Color(1.0, 0.55, 0.12, 0.12),
	},
	THEME_AURORA: {
		"style": "ribbons", "bg": Color("03141f"), "star": Color("c8fff4"),
		"clouds": [Color("3ee6a0"), Color("2bb5ae"), Color("9b6fd1")],
		"floor": Color(0.04, 0.13, 0.17, 0.95),
		"tint": Color(0.68, 1.0, 0.88), "accent": Color(0.62, 1.0, 0.84), "glow": Color(0.05, 0.85, 0.6, 0.1),
	},
	THEME_MIDNIGHT: {
		"style": "clouds", "bg": Color("05061a"), "star": Color("aab8ff"),
		"clouds": [Color("23307a"), Color("4a3fa0"), Color("1d6fa0")],
		"floor": Color(0.03, 0.04, 0.14, 0.96),
		"tint": Color(0.62, 0.68, 1.0), "accent": Color(0.6, 0.66, 1.0), "glow": Color(0.05, 0.08, 0.45, 0.18),
	},
	THEME_CANDY: {
		"style": "clouds", "bg": Color("2a0f26"), "star": Color("ffd1ec"),
		"clouds": [Color("ff7eb6"), Color("ffb3d9"), Color("b39dff")],
		"floor": Color(0.2, 0.07, 0.17, 0.95),
		"tint": Color(1.0, 0.8, 0.92), "accent": Color(1.0, 0.72, 0.88), "glow": Color(1.0, 0.45, 0.75, 0.1),
	},
	THEME_SILVER: {
		"style": "clouds", "bg": Color("0e1016"), "star": Color(1, 1, 1),
		"clouds": [Color("8c93a8"), Color("c7cbe0"), Color("6e7690")],
		"floor": Color(0.08, 0.09, 0.12, 0.95),
		"tint": Color(0.86, 0.9, 1.0), "accent": Color(0.85, 0.88, 0.95), "glow": Color(0.85, 0.9, 1.0, 0.08),
	},
}

## Badge-only themes: id -> name and description for the shop's Themes tab.
const BADGE_THEMES := {
	THEME_MIDNIGHT: {"name": "Midnight Café Theme", "text": "Deep indigo after-hours glow."},
	THEME_CANDY: {"name": "Cotton Candy Theme", "text": "Soft pink sugar-cloud light."},
	THEME_SILVER: {"name": "Starlight Silver Theme", "text": "Cool chrome shine for legends."},
}


static func find(id: String) -> Dictionary:
	for u: Dictionary in LIST:
		if u.id == id:
			return u
	return {}


static func find_decor(id: String) -> Dictionary:
	for d: Dictionary in DECOR:
		if d.id == id:
			return d
	return {}


## Display name for any unlockable id (decor, theme, upgrade).
static func display_name(id: String) -> String:
	var d := find_decor(id)
	if not d.is_empty():
		return d.name
	if BADGE_THEMES.has(id):
		return BADGE_THEMES[id].name
	var u := find(id)
	return u.get("name", id)
