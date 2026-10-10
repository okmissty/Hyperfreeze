class_name ZapBands
extends RefCounted
## Where each zap level sits on the blender meter (0 = bottom, 1 = top),
## and how a release is graded. Shared by the Zap Station and the Scorer.

const CENTERS: Array[float] = [0.26, 0.53, 0.80]   # Asteroid, Comet, Supernova
const HALF_WIDTH := 0.08                             # drawn band = centre ± this
const PERFECT := 0.02                                # within this of centre = 100
const MARGIN := 0.08                                 # grade reaches 0 this far past the band edge
const COLORS: Array[Color] = [Color("ff9f43"), Color("3ee6f0"), Color("ff7eb6")]


static func center(level: int) -> float:
	return CENTERS[clampi(level, 0, 2)]


## Band half-width, wider with the Steady Gauge upgrade.
static func half_width() -> float:
	return HALF_WIDTH * GameState.zap_band_mult()


static func band(level: int) -> Vector2:
	var c := center(level)
	var hw := half_width()
	return Vector2(c - hw, c + hw)


static func color(level: int) -> Color:
	return COLORS[clampi(level, 0, 2)]


## 0–100 for releasing at `value` with the blender set to `level_used`.
## Using the wrong level for the order scores 0.
static func grade(level_wanted: int, level_used: int, value: float) -> int:
	if level_wanted != level_used:
		return 0
	return accuracy(level_used, value)


## 0–100 for how close the release was to the centre of the chosen band.
static func accuracy(level: int, value: float) -> int:
	var d := absf(value - center(level))
	if d <= PERFECT:
		return 100
	var perfect := PERFECT * GameState.zap_band_mult()
	if d <= perfect:
		return 100
	var t := (d - perfect) / (half_width() + MARGIN - perfect)
	return clampi(roundi(100.0 * (1.0 - t)), 0, 100)


static func verdict(accuracy_score: int) -> String:
	if accuracy_score >= 90:
		return "Perfect zap!"
	if accuracy_score >= 70:
		return "Nice blend"
	if accuracy_score >= 40:
		return "A little off"
	return "Way off..."
