class_name Art
extends RefCounted
## Finds drawn sprites by file name, so new art shows up just by dropping a
## PNG with the right name into assets/art/. Returns null for anything not
## drawn yet, and callers fall back to the code-drawn placeholder.
##
##   ingredients/ing_<id>.png             button + ticket icon
##   ingredients/ing_<id>_piece_01..03    mix-in chunks in the cup
##   ingredients/ing_<id>_drizzle         sauce across the cream
##   ingredients/ing_<id>_scatter         sprinkles over the cream
##   ingredients/ing_<id>_topper          topper sitting on the cream

const INGREDIENTS := "res://assets/art/ingredients/"
const STATIONS := "res://assets/art/stations/"
const SKIES := "res://assets/art/skies/"

static var _cache := {}


## Loads a texture by its .png path; a .webp or .jpg with the same name works
## too (the big painted backgrounds ship as .webp to keep the download small).
static func load_tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	for candidate in [path, path.get_basename() + ".webp", path.get_basename() + ".jpg"]:
		if ResourceLoader.exists(candidate):
			tex = load(candidate) as Texture2D
			break
	_cache[path] = tex
	return tex


## Drops cached textures (called on quit so nothing is reported as leaked).
static func clear() -> void:
	_cache.clear()
	CupArt.clear()
	UiSkin.clear()


## Icon (part = "") or a named part ("drizzle", "piece_01", ...) for an ingredient.
static func ingredient(id: StringName, part: String = "") -> Texture2D:
	if id == &"":
		return null
	var file := "ing_%s" % id if part == "" else "ing_%s_%s" % [id, part]
	return load_tex(INGREDIENTS + file + ".png")


## Station sprite by file name, e.g. station("st_zap_jar_01").
static func station(file: String) -> Texture2D:
	return load_tex(STATIONS + file + ".png")


## Sky painting for a café theme id ("nebula", "theme_sunburst", "theme_aurora").
static func sky(theme_id: String) -> Texture2D:
	return load_tex(SKIES + "bg_sky_%s.png" % theme_id.trim_prefix("theme_"))


## Draws `tex` filling `box` completely, cropping the overflow (like CSS cover).
static func draw_cover(ci: CanvasItem, tex: Texture2D, box: Rect2, modulate: Color = Color.WHITE) -> void:
	var ts := tex.get_size()
	var f := maxf(box.size.x / ts.x, box.size.y / ts.y)
	var src_size := box.size / f
	var src := Rect2((ts - src_size) / 2.0, src_size)
	ci.draw_texture_rect_region(tex, box, src, modulate)


## Draws `tex` fitted inside `box`, keeping its aspect ratio.
static func draw_fit(ci: CanvasItem, tex: Texture2D, box: Rect2, modulate: Color = Color.WHITE) -> void:
	var ts := tex.get_size()
	var f := minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz := ts * f
	ci.draw_texture_rect(tex, Rect2(box.get_center() - sz / 2.0, sz), false, modulate)
