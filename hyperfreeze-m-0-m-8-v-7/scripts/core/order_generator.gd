class_name OrderGenerator
extends RefCounted
## Builds a customer's favourite order from what is unlocked at a rank,
## following that customer's habits. Pure logic: no scene, easy to test.


static func generate(customer: CustomerData, catalog: Catalog, rank: int, rng: RandomNumberGenerator) -> Order:
	var order := Order.new()

	# Cup size
	if customer.preferred_size >= 0:
		order.size = customer.preferred_size as Order.CupSize
	else:
		order.size = rng.randi_range(0, 2) as Order.CupSize

	# Base (always one)
	var bases := catalog.unlocked(IngredientData.Category.BASE, rank)
	if not bases.is_empty():
		order.base_id = _pick(bases, rng).id

	# Mix-ins: distinct, count from the customer's range
	var mixins := catalog.unlocked(IngredientData.Category.MIXIN, rank)
	var mixin_target := clampi(rng.randi_range(customer.mixin_count.x, customer.mixin_count.y), 0, mixins.size())
	for ing: IngredientData in _pick_distinct(mixins, mixin_target, rng):
		order.mixin_ids.append(ing.id)

	# Zap level
	if customer.preferred_zap >= 0:
		order.zap_level = customer.preferred_zap as Order.ZapLevel
	else:
		order.zap_level = rng.randi_range(0, 2) as Order.ZapLevel

	# Cream, sauce, sprinkles
	order.wants_cream = rng.randf() < customer.cream_chance
	var sauces := catalog.unlocked(IngredientData.Category.SAUCE, rank)
	if not sauces.is_empty() and rng.randf() < customer.sauce_chance:
		order.sauce_id = _pick(sauces, rng).id
	var sprinkles := catalog.unlocked(IngredientData.Category.SPRINKLES, rank)
	if not sprinkles.is_empty() and rng.randf() < customer.sprinkle_chance:
		order.sprinkle_id = _pick(sprinkles, rng).id

	# Toppers: random distinct slots, toppers may repeat
	var toppers := catalog.unlocked(IngredientData.Category.TOPPER, rank)
	order.toppers = [&"", &"", &"", &""]
	if not toppers.is_empty():
		var count := clampi(rng.randi_range(customer.topper_count.x, customer.topper_count.y), 0, Order.TOPPER_SLOTS)
		var slots: Array[int] = [0, 1, 2, 3]
		_shuffle(slots, rng)
		for i in count:
			order.toppers[slots[i]] = _pick(toppers, rng).id

	return order


## When a new ingredient unlocks, a regular may swap it into their favourite.
static func add_new_ingredient(order: Order, ing: IngredientData, rng: RandomNumberGenerator) -> void:
	match ing.category:
		IngredientData.Category.BASE:
			order.base_id = ing.id
		IngredientData.Category.MIXIN:
			if order.mixin_ids.is_empty():
				order.mixin_ids.append(ing.id)
			else:
				order.mixin_ids[rng.randi_range(0, order.mixin_ids.size() - 1)] = ing.id
		IngredientData.Category.SAUCE:
			order.sauce_id = ing.id
		IngredientData.Category.SPRINKLES:
			order.sprinkle_id = ing.id
		IngredientData.Category.TOPPER:
			order.toppers[rng.randi_range(0, Order.TOPPER_SLOTS - 1)] = ing.id


static func _pick(items: Array[IngredientData], rng: RandomNumberGenerator) -> IngredientData:
	return items[rng.randi_range(0, items.size() - 1)]


static func _pick_distinct(items: Array[IngredientData], count: int, rng: RandomNumberGenerator) -> Array[IngredientData]:
	var pool := items.duplicate()
	var out: Array[IngredientData] = []
	for i in count:
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx])
		pool.remove_at(idx)
	return out


## Fisher–Yates with our own RNG (Array.shuffle() uses the global one).
static func _shuffle(arr: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
