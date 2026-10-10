class_name CustomerData
extends Resource
## A named alien regular. Their species sets the look; the habit fields
## steer what OrderGenerator puts in their favourite order.

enum Species { BLORB, ZIP_ZAP, LUMEN, GRAVITON, CAPTAIN_NOVA, CRITIC }

@export var id: StringName
@export var display_name: String = ""
@export var species: Species = Species.BLORB
@export_range(1, 20) var unlock_rank: int = 1
## Food critics are made on the spot (not in data/) and leave a review.
@export var is_critic := false

@export_group("Look")
@export var body_color: Color = Color("7be0a5")
@export var accent_color: Color = Color("3d9970")

@export_group("Behaviour")
## Seconds at the counter before the patience bar is empty (wait score starts dropping).
@export var patience_seconds: float = 40.0
## Base tip in cents, scaled by score later (M6).
@export var base_tip_cents: int = 300
## Multiplier on the Top Station grade (Lumens care about topper placement).
@export var top_weight: float = 1.0

@export_group("Order habits")
## -1 = any size, otherwise an Order.CupSize value.
@export_range(-1, 2) var preferred_size: int = -1
## -1 = any level, otherwise an Order.ZapLevel value.
@export_range(-1, 2) var preferred_zap: int = -1
@export var mixin_count: Vector2i = Vector2i(1, 2)
@export var topper_count: Vector2i = Vector2i(1, 3)
@export_range(0.0, 1.0) var cream_chance: float = 0.8
@export_range(0.0, 1.0) var sauce_chance: float = 0.9
@export_range(0.0, 1.0) var sprinkle_chance: float = 0.6


static func species_name(s: Species) -> String:
	match s:
		Species.BLORB: return "Blorb"
		Species.ZIP_ZAP: return "Zip-Zap"
		Species.LUMEN: return "Lumen"
		Species.GRAVITON: return "Graviton"
		Species.CAPTAIN_NOVA: return "Captain Nova"
		Species.CRITIC: return "Critic"
	return "?"
