class_name Scorer
extends RefCounted
## Grades a served order: compares what was made (CupState) with what was
## asked for (Order) at each station, then works out the tip and XP.
## Pure logic, no scenes, so it is easy to tune and test.

## Food is expected to take longer than ordering: the lobby patience window
## is the customer's counter patience times this.
const FOOD_PATIENCE_MULT := 3.0
## Fill within this of the line is perfect.
const FILL_GRACE := 0.03
## Points lost per unit of fill error beyond the grace (0.1 off ≈ -17).
const FILL_PENALTY := 250.0


class Result extends RefCounted:
	var wait := 0
	var build := 0
	var zap := 0
	var top := 0
	var total := 0
	var tip_cents := 0
	var xp := 0
	var rating := ""
	## The customer earned their gold star on this visit.
	var gold_star_earned := false
	## Food critics only: 1-5 stars, the quote and the paper it ran in.
	var review_stars := 0
	var review_quote := ""
	var review_paper := ""


static func grade(order: Order, cup: CupState, patience_mult: float = 1.0) -> Result:
	var r := Result.new()
	r.wait = wait_score(order, patience_mult)
	r.build = build_score(order, cup)
	r.zap = zap_score(order, cup)
	r.top = top_score(order, cup)
	var w := order.customer.top_weight if order.customer else 1.0
	r.total = clampi(roundi((r.wait + r.build + r.zap + r.top * w) / (3.0 + w)), 0, 100)
	r.rating = rating_for(r.total)
	r.xp = r.total
	var base_tip := order.customer.base_tip_cents if order.customer else 300
	r.tip_cents = roundi(base_tip * pow(r.total / 100.0, 2.0))
	return r


## Two waits, each 100 inside the patience window, falling to 0 at twice it.
static func wait_score(order: Order, patience_mult: float = 1.0) -> int:
	var patience := (order.customer.patience_seconds if order.customer else 40.0) * patience_mult
	var to_order := _wait_part(order.taken_at - order.arrived_at, patience)
	var served := order.served_at if order.served_at >= 0.0 else order.taken_at
	var to_serve := _wait_part(served - order.taken_at, patience * FOOD_PATIENCE_MULT)
	return roundi((to_order + to_serve) / 2.0)


static func _wait_part(elapsed: float, window: float) -> float:
	if elapsed <= window:
		return 100.0
	return maxf(0.0, 100.0 - (elapsed - window) / window * 100.0)


static func build_score(order: Order, cup: CupState) -> int:
	var s := 100.0
	if cup.size != order.size:
		s -= 30.0
	if cup.base_id != order.base_id:
		s -= 40.0
	if cup.mixed_bases:
		s -= 15.0
	var err := absf(cup.fill_amount - CupState.TARGET_FILL)
	if err > FILL_GRACE:
		s -= (err - FILL_GRACE) * FILL_PENALTY
	for id: StringName in order.mixin_ids:
		if id not in cup.mixin_ids:
			s -= 20.0
	for id: StringName in cup.mixin_ids:
		if id not in order.mixin_ids:
			s -= 15.0
	return clampi(roundi(s), 0, 100)


static func zap_score(order: Order, cup: CupState) -> int:
	if not cup.zapped:
		return 0
	return ZapBands.grade(order.zap_level, cup.zap_level, cup.zap_value)


## Cream 30 + sauce 15 + sprinkles 15 + toppers 40 (10 per slot, empty matches empty).
static func top_score(order: Order, cup: CupState) -> int:
	var s := 0.0
	var coverage := cup.cream_coverage()
	s += 30.0 * (coverage if order.wants_cream else 1.0 - coverage)
	if cup.sauce_id == order.sauce_id:
		s += 15.0
	if cup.sprinkle_id == order.sprinkle_id:
		s += 15.0
	for i in Order.TOPPER_SLOTS:
		if cup.toppers[i] == order.toppers[i]:
			s += 10.0
	return clampi(roundi(s), 0, 100)


static func rating_for(total: int) -> String:
	if total >= 90:
		return "Out of this world!"
	if total >= 75:
		return "Stellar"
	if total >= 55:
		return "Pretty good"
	if total >= 35:
		return "Meh..."
	return "Lost in space"
