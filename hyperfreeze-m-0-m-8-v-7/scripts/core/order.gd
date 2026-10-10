class_name Order
extends Resource
## What a ticket asks for. A customer's favourite is stored as an Order;
## each visit works on a copy made with `for_visit()`.

enum CupSize { SMALL, MEDIUM, LARGE }
enum ZapLevel { ASTEROID, COMET, SUPERNOVA }

const TOPPER_SLOTS := 4
## Slot order used everywhere: back-left, back-right, front-left, front-right.
const SLOT_NAMES: Array[String] = ["Back left", "Back right", "Front left", "Front right"]

# --- The recipe (exported, so favourites can be saved) ------------------------
@export var size: CupSize = CupSize.MEDIUM
@export var base_id: StringName
@export var mixin_ids: Array[StringName] = []
@export var zap_level: ZapLevel = ZapLevel.COMET
@export var wants_cream: bool = true
## Empty StringName = no sauce.
@export var sauce_id: StringName
## Empty StringName = no sprinkles.
@export var sprinkle_id: StringName
## Always TOPPER_SLOTS long; empty StringName = nothing in that slot.
@export var toppers: Array[StringName] = [&"", &"", &"", &""]

# --- This visit only (not exported, not copied by duplicate()) ---------------
var ticket_number: int = 0
var customer: CustomerData
## Where the ticket is: StationIds.PRINTING, StationIds.RAIL or a station id.
var location: StringName = StationIds.PRINTING
## Times are DayManager.time_elapsed seconds.
var arrived_at: float = 0.0
var taken_at: float = 0.0
var served_at: float = -1.0
## The cup being made for this order, or null before the Build Station starts one.
var cup: CupState


## A fresh copy of this recipe for one visit.
func for_visit(number: int, who: CustomerData, arrived: float, taken: float) -> Order:
	var copy: Order = duplicate(true)
	copy.ticket_number = number
	copy.customer = who
	copy.arrived_at = arrived
	copy.taken_at = taken
	copy.location = StationIds.PRINTING
	return copy


func topper_count() -> int:
	var n := 0
	for t: StringName in toppers:
		if t != &"":
			n += 1
	return n


func display_name() -> String:
	var base := GameState.catalog.ingredient(base_id)
	var base_name := base.display_name if base else "Mystery"
	return "%s %s Freeze" % [zap_name(zap_level), base_name]


static func size_name(s: CupSize) -> String:
	match s:
		CupSize.SMALL: return "Small"
		CupSize.MEDIUM: return "Medium"
		CupSize.LARGE: return "Large"
	return "?"


static func size_letter(s: CupSize) -> String:
	return size_name(s).left(1)


static func zap_name(z: ZapLevel) -> String:
	match z:
		ZapLevel.ASTEROID: return "Asteroid"
		ZapLevel.COMET: return "Comet"
		ZapLevel.SUPERNOVA: return "Supernova"
	return "?"


static func zap_description(z: ZapLevel) -> String:
	match z:
		ZapLevel.ASTEROID: return "chunky"
		ZapLevel.COMET: return "regular"
		ZapLevel.SUPERNOVA: return "smooth"
	return ""
