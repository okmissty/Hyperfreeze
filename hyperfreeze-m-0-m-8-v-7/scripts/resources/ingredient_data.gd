class_name IngredientData
extends Resource
## One ingredient on the menu. Drop a new .tres in res://data/ingredients/
## and it shows up in the game once the player reaches its unlock rank.

enum Category { BASE, MIXIN, SAUCE, SPRINKLES, TOPPER }

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.BASE
## Placeholder colour used until real art exists (also tints sauces, cream, etc.).
@export var color: Color = Color.WHITE
@export_range(1, 20) var unlock_rank: int = 1
## Optional sprite. When empty, the game draws a coloured placeholder shape.
@export var icon: Texture2D


static func category_name(c: Category) -> String:
	match c:
		Category.BASE: return "Base"
		Category.MIXIN: return "Mix-in"
		Category.SAUCE: return "Sauce"
		Category.SPRINKLES: return "Sprinkles"
		Category.TOPPER: return "Topper"
	return "?"
