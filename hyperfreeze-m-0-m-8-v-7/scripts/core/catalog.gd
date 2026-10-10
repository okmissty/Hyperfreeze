class_name Catalog
extends RefCounted
## Loads every ingredient and customer .tres from the data folders and
## answers "what's unlocked at rank N?". Owned by GameState.

const INGREDIENT_DIR := "res://data/ingredients"
const CUSTOMER_DIR := "res://data/customers"

## StringName -> IngredientData
var ingredients: Dictionary = {}
var customers: Array[CustomerData] = []


func load_all() -> void:
	ingredients.clear()
	customers.clear()
	for res: Resource in _load_dir(INGREDIENT_DIR):
		var ing := res as IngredientData
		if ing == null:
			push_warning("Catalog: %s is not an IngredientData" % res.resource_path)
			continue
		if ingredients.has(ing.id):
			push_warning("Catalog: duplicate ingredient id '%s'" % ing.id)
		ingredients[ing.id] = ing
	for res: Resource in _load_dir(CUSTOMER_DIR):
		var cust := res as CustomerData
		if cust == null:
			push_warning("Catalog: %s is not a CustomerData" % res.resource_path)
			continue
		customers.append(cust)
	customers.sort_custom(func(a: CustomerData, b: CustomerData) -> bool:
		return a.unlock_rank < b.unlock_rank or (a.unlock_rank == b.unlock_rank and a.display_name < b.display_name))


func ingredient(id: StringName) -> IngredientData:
	return ingredients.get(id) as IngredientData


func unlocked(category: IngredientData.Category, rank: int) -> Array[IngredientData]:
	var out: Array[IngredientData] = []
	for key: StringName in ingredients:
		var ing: IngredientData = ingredients[key]
		if ing.category == category and ing.unlock_rank <= rank:
			out.append(ing)
	out.sort_custom(func(a: IngredientData, b: IngredientData) -> bool:
		return a.unlock_rank < b.unlock_rank or (a.unlock_rank == b.unlock_rank and a.display_name < b.display_name))
	return out


func customers_unlocked(rank: int) -> Array[CustomerData]:
	var out: Array[CustomerData] = []
	for c: CustomerData in customers:
		if c.unlock_rank <= rank:
			out.append(c)
	return out


## Lists a folder of resources. Exported builds rename text resources to
## "*.tres.remap", so the suffix is stripped before loading.
static func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Catalog: cannot open %s" % path)
		return out
	var files := dir.get_files()
	files.sort()
	for file_name: String in files:
		var clean := file_name.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res := load(path.path_join(clean))
		if res:
			out.append(res)
	return out
