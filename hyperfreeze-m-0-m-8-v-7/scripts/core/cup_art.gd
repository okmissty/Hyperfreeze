class_name CupArt
extends RefCounted
## The drawn cup (assets/art/cups/). When all five layers exist, CupPainter
## draws with them; otherwise it keeps the code-drawn cup.
## Shapes are read from the art itself, so a redrawn cup just works:
##   cup_fill_mask    white where ice cream can show (the inside of the bowl)
##   cup_cream        its outline gives the dome's height for toppers/sauce
## back, front and mask share one canvas size.

const DIR := "res://assets/art/cups/"
## Cream width relative to the cup canvas, and how far it sinks into the rim
## (as a fraction of the cream's height).
const CREAM_WIDTH := 1.1
const CREAM_SINK := 0.08
const PROFILE_COLUMNS := 64

static var _loaded := false
static var _art: CupArt = null

var back: Texture2D
var front: Texture2D
var fill: Texture2D
var cream: Texture2D
var size := Vector2.ZERO
## Inside of the bowl, one sample per mask row (canvas px).
var bowl_y := PackedFloat32Array()
var bowl_left := PackedFloat32Array()
var bowl_right := PackedFloat32Array()
var bowl_top := 0.0
var bowl_bottom := 0.0
var bowl_x0 := 0.0
var bowl_x1 := 0.0
## Height of the cream's top edge per column, 0-1 of the cream image height.
var cream_profile := PackedFloat32Array()


## The loaded cup art, or null when any layer is missing.
static func get_art() -> CupArt:
	if not _loaded:
		_loaded = true
		_art = _build()
	return _art


static func clear() -> void:
	_art = null
	_loaded = false


static func _build() -> CupArt:
	var a := CupArt.new()
	a.back = Art.load_tex(DIR + "cup_back.png")
	a.front = Art.load_tex(DIR + "cup_front.png")
	a.fill = Art.load_tex(DIR + "cup_fill_texture.png")
	a.cream = Art.load_tex(DIR + "cup_cream.png")
	var mask_tex := Art.load_tex(DIR + "cup_fill_mask.png")
	if a.back == null or a.front == null or a.fill == null or a.cream == null or mask_tex == null:
		return null
	a.size = a.back.get_size()
	var mask := _rgba(mask_tex)
	var cream_img := _rgba(a.cream)
	if mask == null or cream_img == null:
		return null
	if not a._read_bowl(mask) or not a._read_cream(cream_img):
		return null
	return a


static func _rgba(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _read_bowl(mask: Image) -> bool:
	var w := mask.get_width()
	var h := mask.get_height()
	var data := mask.get_data()
	# Mask may be drawn at a different scale than the glass; map to glass px.
	var sx := size.x / w
	var sy := size.y / h
	bowl_x0 = INF
	bowl_x1 = -INF
	for y in h:
		var row := y * w * 4 + 3
		var left := -1
		for x in w:
			if data[row + x * 4] > 127:
				left = x
				break
		if left < 0:
			continue
		var right := left
		for x in range(w - 1, left, -1):
			if data[row + x * 4] > 127:
				right = x
				break
		bowl_y.append(y * sy)
		bowl_left.append(left * sx)
		bowl_right.append((right + 1) * sx)
		bowl_x0 = minf(bowl_x0, left * sx)
		bowl_x1 = maxf(bowl_x1, (right + 1) * sx)
	if bowl_y.size() < 4:
		return false
	bowl_top = bowl_y[0]
	bowl_bottom = bowl_y[bowl_y.size() - 1]
	return true


func _read_cream(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	for i in PROFILE_COLUMNS:
		var x := clampi(int((i + 0.5) / PROFILE_COLUMNS * w), 0, w - 1)
		var top := h
		for y in h:
			if data[(y * w + x) * 4 + 3] > 127:
				top = y
				break
		cream_profile.append(1.0 - float(top) / h)
	return true


## Cream top height (0-1 of the image) at horizontal position t (0-1).
func profile_at(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var f := t * PROFILE_COLUMNS - 0.5
	var i := clampi(int(floor(f)), 0, PROFILE_COLUMNS - 1)
	var j := mini(i + 1, PROFILE_COLUMNS - 1)
	return lerpf(cream_profile[i], cream_profile[j], clampf(f - i, 0.0, 1.0))


## Left and right edges of the bowl's inside at canvas height y.
func span_at(y: float) -> Vector2:
	var n := bowl_y.size()
	if y <= bowl_top:
		return Vector2(bowl_left[0], bowl_right[0])
	if y >= bowl_bottom:
		return Vector2(bowl_left[n - 1], bowl_right[n - 1])
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if bowl_y[mid] <= y:
			lo = mid
		else:
			hi = mid
	var t := (y - bowl_y[lo]) / maxf(bowl_y[hi] - bowl_y[lo], 0.001)
	return Vector2(lerpf(bowl_left[lo], bowl_left[hi], t), lerpf(bowl_right[lo], bowl_right[hi], t))


## Outline of the ice cream filled to `level` (0-1 of the bowl's height),
## in canvas px. Empty when there's nothing to draw.
func fill_polygon(level: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y_top := lerpf(bowl_bottom, bowl_top, clampf(level, 0.0, 1.0))
	if y_top >= bowl_bottom - 1.0:
		return pts
	var step := maxi(1, bowl_y.size() / 48)
	var first := span_at(y_top)
	pts.append(Vector2(first.y, y_top))
	var lefts := PackedVector2Array([Vector2(first.x, y_top)])
	for i in range(0, bowl_y.size(), step):
		if bowl_y[i] <= y_top + 0.5:
			continue
		pts.append(Vector2(bowl_right[i], bowl_y[i]))
		lefts.append(Vector2(bowl_left[i], bowl_y[i]))
	var last := bowl_y.size() - 1
	if bowl_y[last] > y_top + 0.5 and (last % step) != 0:
		pts.append(Vector2(bowl_right[last], bowl_y[last]))
		lefts.append(Vector2(bowl_left[last], bowl_y[last]))
	for i in range(lefts.size() - 1, -1, -1):
		pts.append(lefts[i])
	return pts


## Texture coordinate for a canvas point inside the bowl.
func fill_uv(p: Vector2) -> Vector2:
	return Vector2((p.x - bowl_x0) / maxf(bowl_x1 - bowl_x0, 1.0), (p.y - bowl_top) / maxf(bowl_bottom - bowl_top, 1.0))
