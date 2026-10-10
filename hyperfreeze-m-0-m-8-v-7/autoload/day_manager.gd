extends Node
## Runs one shift (autoload "DayManager"): the clock, the customer rush
## curve, and every order/ticket for the day.
##
## All ticket moves go through `move_ticket()` so the rail and the station
## slots (which only *display* tickets) can never disagree.

const OPEN_MINUTES := 9 * 60        # 9:00 AM
const CLOSE_MINUTES := 18 * 60      # 6:00 PM
const COUNTER_QUEUE_CAP := 4

## Early days are gentler so players can learn the stations:
## longer shifts, fewer arrivals, and a cap on customers in the café at once.
## Index = day - 1; the last entry applies from then on.
const DAY_LENGTHS: Array[float] = [480.0, 465.0, 450.0, 420.0]
## When there's nothing to do (no one waiting, no unserved orders), the next
## customer arrives within this many seconds instead of leaving the player idle.
const IDLE_SPAWN_DELAY := 4.0
const SPAWN_SLOWDOWN: Array[float] = [2.2, 1.7, 1.3, 1.0]
const CUSTOMER_CAPS: Array[int] = [3, 4, 5, 99]

var day_running := false
var shop_open := false
var paused := false
## Active seconds since the day started. All order timing uses this clock.
var time_elapsed := 0.0
## Real seconds in today's shift (see DAY_LENGTHS).
var day_length := 420.0
var orders: Array[Order] = []
## One entry per served order today: ticket, customer, total, tip_cents, xp.
var served_results: Array[Dictionary] = []
var waiting_to_order := 0
## Customer ids currently inside the café (queue or lobby).
var present_customer_ids: Array[StringName] = []

## When today's food critic walks in (seconds into the shift), or -1.
var critic_at := -1.0

const CRITIC_NAMES: Array[String] = ["Orla Vex", "Bram Nebulon", "Sola Quill", "Dax Meridian", "Pim Starling"]
const CRITIC_PAPERS: Array[String] = ["Galactic Gazette", "The Orbit Times", "Nebula Weekly"]
const CRITIC_QUOTES := {
	5: ["Out of this world. I'd cross three galaxies for another.", "A flawless orbit of flavour."],
	4: ["Delightful - a few specks shy of stellar.", "Nearly perfect. The zap was a joy."],
	3: ["Perfectly fine. Unremarkable, but fine.", "Decent, if a little lopsided."],
	2: ["Messy and slow. The cream had given up.", "Not quite what I ordered."],
	1: ["A black hole of disappointment.", "I've had better treats from a vending probe."],
}

var _next_ticket := 1
var _spawn_timer := 0.0
var _last_minute := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func start_day() -> void:
	time_elapsed = 0.0
	orders.clear()
	served_results.clear()
	present_customer_ids.clear()
	waiting_to_order = 0
	_next_ticket = 1
	_spawn_timer = 3.0  # first customer shows up almost straight away
	day_length = _for_day(DAY_LENGTHS)
	_last_minute = -1
	_plan_critic()
	day_running = true
	shop_open = true
	paused = false
	Events.day_started.emit(GameState.day)
	Events.queue_changed.emit(waiting_to_order)
	_update_clock()


func _process(delta: float) -> void:
	if not day_running or paused:
		return
	time_elapsed += delta
	_update_clock()
	if shop_open:
		if not has_open_work():
			_spawn_timer = minf(_spawn_timer, IDLE_SPAWN_DELAY)
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_try_spawn_customer()
		if critic_at >= 0.0 and time_elapsed >= critic_at and waiting_to_order < COUNTER_QUEUE_CAP:
			spawn_critic_now()


# --- Clock --------------------------------------------------------------------

func day_progress() -> float:
	return clampf(time_elapsed / day_length, 0.0, 1.0)


func game_minutes() -> int:
	return OPEN_MINUTES + int(day_progress() * (CLOSE_MINUTES - OPEN_MINUTES))


@warning_ignore("integer_division")
static func format_clock(minutes: int) -> String:
	var h := (minutes / 60) % 24
	var m := minutes % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func _update_clock() -> void:
	var minutes := game_minutes()
	if minutes != _last_minute:
		_last_minute = minutes
		Events.clock_changed.emit(minutes)
	if shop_open and minutes >= CLOSE_MINUTES:
		shop_open = false
		Events.shop_closed.emit()
		_check_day_end()


# --- Customers ----------------------------------------------------------------

## Seconds until the next arrival: quiet morning, lunch rush, calmer evening.
func _spawn_interval() -> float:
	var p := day_progress()
	var base: float
	if p < 0.3:
		base = 32.0
	elif p < 0.55:
		base = 16.0
	elif p < 0.8:
		base = 24.0
	else:
		base = 30.0
	return base * float(_for_day(SPAWN_SLOWDOWN)) * GameState.traffic_mult() * _rng.randf_range(0.8, 1.2)


## Picks today's value from a per-day table (last entry repeats).
func _for_day(table: Array) -> Variant:
	return table[clampi(GameState.day - 1, 0, table.size() - 1)]


## True while anyone is waiting to order or any order is still unserved.
func has_open_work() -> bool:
	if waiting_to_order > 0:
		return true
	for o: Order in orders:
		if o.location != StationIds.SERVED:
			return true
	return false


## Real seconds until closing time (0 once closed).
func seconds_until_close() -> float:
	return maxf(day_length - time_elapsed, 0.0)


func customer_cap() -> int:
	return _for_day(CUSTOMER_CAPS)


func _try_spawn_customer() -> void:
	if waiting_to_order >= COUNTER_QUEUE_CAP or present_customer_ids.size() >= customer_cap():
		_spawn_timer = 3.0  # café full for today's pace, check again shortly
		return
	if not spawn_customer_now():
		_spawn_timer = 5.0  # everyone unlocked is already here
		return
	_spawn_timer = _spawn_interval()


## Brings in a random regular who isn't already here. Returns false if none.
func spawn_customer_now() -> bool:
	var candidates: Array[CustomerData] = []
	for c: CustomerData in GameState.catalog.customers_unlocked(GameState.get_rank()):
		if c.id not in present_customer_ids:
			candidates.append(c)
	if candidates.is_empty():
		return false
	var customer := candidates[_rng.randi_range(0, candidates.size() - 1)]
	present_customer_ids.append(customer.id)
	waiting_to_order += 1
	Events.customer_arrived.emit(customer)
	Events.queue_changed.emit(waiting_to_order)
	return true


# --- Food critics --------------------------------------------------------------

## From day 3 a critic visits now and then: always after 3 quiet days,
## otherwise a 35% chance, never twice in one day.
func _plan_critic() -> void:
	critic_at = -1.0
	var d := GameState.day
	if d < 3:
		return
	var since := d - GameState.last_critic_day
	if since >= 3 or (since >= 1 and _rng.randf() < 0.35):
		critic_at = day_length * _rng.randf_range(0.25, 0.65)


func make_critic() -> CustomerData:
	var c := CustomerData.new()
	c.id = &"critic"
	c.display_name = "Critic " + CRITIC_NAMES[_rng.randi_range(0, CRITIC_NAMES.size() - 1)]
	c.species = CustomerData.Species.CRITIC
	c.is_critic = true
	c.body_color = Color("e8e2ff")
	c.accent_color = Color("c2185b")
	c.patience_seconds = 32.0
	c.base_tip_cents = 600
	c.top_weight = 1.2
	c.mixin_count = Vector2i(2, 2)
	c.topper_count = Vector2i(3, 4)
	c.cream_chance = 1.0
	c.sauce_chance = 1.0
	c.sprinkle_chance = 1.0
	return c


## Brings today's critic in now (also used by tests).
func spawn_critic_now() -> bool:
	critic_at = -1.0
	if &"critic" in present_customer_ids:
		return false
	var critic := make_critic()
	GameState.last_critic_day = GameState.day
	present_customer_ids.append(critic.id)
	waiting_to_order += 1
	Events.customer_arrived.emit(critic)
	Events.queue_changed.emit(waiting_to_order)
	Events.toast.emit("A food critic just walked in!")
	return true


## Called when a served customer walks out the airlock.
func customer_left(customer: CustomerData) -> void:
	present_customer_ids.erase(customer.id)
	_check_day_end()


## The shift ends once the shop has closed and the last customer has left.
func _check_day_end() -> void:
	if day_running and not shop_open and present_customer_ids.is_empty():
		day_running = false
		var summary := day_summary()
		GameState.record_day_end(summary)
		Events.day_ended.emit(summary)


func day_summary() -> Dictionary:
	var tips := 0
	var xp_total := 0
	var score_sum := 0
	var best: Dictionary = {}
	var min_total := 100
	var min_wait := 100
	var critic_stars := 0
	for r: Dictionary in served_results:
		min_total = mini(min_total, int(r.total))
		min_wait = mini(min_wait, int(r.get("wait", 100)))
		if int(r.get("critic_stars", 0)) > 0:
			critic_stars = int(r.critic_stars)
		tips += int(r.tip_cents)
		xp_total += int(r.xp)
		score_sum += int(r.total)
		if best.is_empty() or int(r.total) > int(best.total):
			best = r
	return {
		"day": GameState.day,
		"served": served_results.size(),
		"tips_cents": tips,
		"xp": xp_total,
		"average": roundi(float(score_sum) / served_results.size()) if not served_results.is_empty() else 0,
		"best": best,
		"min_total": min_total if not served_results.is_empty() else 0,
		"min_wait": min_wait if not served_results.is_empty() else 0,
		"critic_stars": critic_stars,
		"rating": GameState.cafe_rating(),
	}


# --- Serving ------------------------------------------------------------------

## Hands a ready order to its customer: grades it, pays the tip and XP,
## and records loyalty. Returns null if the order isn't ready.
func serve_order(order: Order) -> Scorer.Result:
	if order.cup == null or order.cup.location != StationIds.READY:
		return null
	order.served_at = time_elapsed
	var result := Scorer.grade(order, order.cup, GameState.patience_mult())
	if GameState.has_gold_star(order.customer):
		result.tip_cents = roundi(result.tip_cents * (1.0 + GameState.GOLD_TIP_BONUS))
	result.tip_cents = roundi(result.tip_cents * GameState.tip_mult())
	if order.customer.is_critic:
		result.review_stars = clampi(roundi(result.total / 20.0), 1, 5)
		var quotes: Array = CRITIC_QUOTES[result.review_stars]
		result.review_quote = quotes[_rng.randi_range(0, quotes.size() - 1)]
		result.review_paper = CRITIC_PAPERS[_rng.randi_range(0, CRITIC_PAPERS.size() - 1)]
		GameState.record_review(result.review_stars)
	else:
		result.gold_star_earned = GameState.record_visit(order.customer, result.total)
	var from_ticket := order.location
	order.location = StationIds.SERVED
	Events.ticket_moved.emit(order, from_ticket, StationIds.SERVED)
	move_cup(order, StationIds.SERVED)
	GameState.add_money(result.tip_cents)
	GameState.add_xp(result.xp)
	served_results.append({
		"ticket": order.ticket_number,
		"customer": order.customer.display_name,
		"total": result.total,
		"tip_cents": result.tip_cents,
		"xp": result.xp,
		"wait": result.wait,
		"critic_stars": result.review_stars,
	})
	GameState.record_served(order, result)
	Events.order_served.emit(order, result)
	return result


# --- Orders & tickets ---------------------------------------------------------

## The Order Station calls this when the player takes an order.
## The new ticket starts at StationIds.PRINTING.
func create_order(customer: CustomerData, arrived_at: float) -> Order:
	# Critics order something new (and complicated) every visit.
	var favorite: Order = OrderGenerator.generate(customer, GameState.catalog, GameState.get_rank(), _rng) if customer.is_critic else GameState.get_favorite(customer)
	var order := favorite.for_visit(_next_ticket, customer, arrived_at, time_elapsed)
	_next_ticket += 1
	orders.append(order)
	waiting_to_order = maxi(waiting_to_order - 1, 0)
	Events.order_taken.emit(order)
	Events.queue_changed.emit(waiting_to_order)
	return order


## The station a ticket may be clipped at: wherever its cup is
## (Build before a cup exists). Ready orders belong on the rail only.
func station_for_order(order: Order) -> StringName:
	if order.cup == null:
		return StationIds.BUILD
	var station := StationIds.station_for_cup(order.cup.location)
	return station if StationIds.accepts_tickets(station) else &""


func can_clip(order: Order, location: StringName) -> bool:
	if location == StationIds.RAIL or location == StationIds.PRINTING:
		return true
	if not StationIds.accepts_tickets(location):
		return false  # e.g. the Order Station has no slot
	return station_for_order(order) == location


## Plain-words reason a ticket can't go to a station (for the hint toast).
func clip_refusal(order: Order, location: StringName) -> String:
	if not StationIds.accepts_tickets(location):
		return "Open Build, Zap or Top to clip a ticket"
	var home := station_for_order(order)
	if home == &"":
		return "#%d is ready to serve" % order.ticket_number
	return "#%d belongs at the %s Station" % [order.ticket_number, StationIds.display_name(home)]


## The single place a ticket changes location. A station slot holds one
## ticket; dropping a second one sends the first back to the rail.
## Tickets can only be clipped at the station their cup is at.
func move_ticket(order: Order, to_location: StringName) -> bool:
	var from_location := order.location
	if from_location == to_location:
		return true
	if not can_clip(order, to_location):
		return false
	if StationIds.accepts_tickets(to_location):
		var occupant := ticket_at(to_location)
		if occupant:
			occupant.location = StationIds.RAIL
			Events.ticket_moved.emit(occupant, to_location, StationIds.RAIL)
	order.location = to_location
	Events.ticket_moved.emit(order, from_location, to_location)
	return true


func ticket_at(location: StringName) -> Order:
	for o: Order in orders:
		if o.location == location:
			return o
	return null


func tickets_at(location: StringName) -> Array[Order]:
	var out: Array[Order] = []
	for o: Order in orders:
		if o.location == location:
			out.append(o)
	out.sort_custom(func(a: Order, b: Order) -> bool: return a.ticket_number < b.ticket_number)
	return out


# --- Cups ---------------------------------------------------------------------

## The Build Station starts a cup for the order clipped there.
func start_cup(order: Order, cup_size: int) -> CupState:
	if order.cup:
		return order.cup
	var cup := CupState.new()
	cup.size = cup_size
	cup.location = StationIds.BUILD
	order.cup = cup
	Events.cup_moved.emit(order, &"", StationIds.BUILD)
	return cup


## The single place a cup changes location.
func move_cup(order: Order, to_location: StringName) -> void:
	if order.cup == null or order.cup.location == to_location:
		return
	var from_location := order.cup.location
	order.cup.location = to_location
	if to_location == StationIds.ZAP_SHELF or to_location == StationIds.TOP_SHELF:
		order.cup.shelved_at = time_elapsed
	Events.cup_moved.emit(order, from_location, to_location)


func trash_cup(order: Order) -> void:
	if order.cup == null:
		return
	var from_location := order.cup.location
	order.cup = null
	Events.cup_moved.emit(order, from_location, &"")
	# The order starts over at Build, so its ticket can't stay further along.
	if StationIds.accepts_tickets(order.location) and order.location != StationIds.BUILD:
		if ticket_at(StationIds.BUILD) == null:
			move_ticket(order, StationIds.BUILD)
		else:
			move_ticket(order, StationIds.RAIL)


## Orders whose cup is at a location, oldest arrival on the shelf first.
func cups_at(location: StringName) -> Array[Order]:
	var out: Array[Order] = []
	for o: Order in orders:
		if o.cup and o.cup.location == location:
			out.append(o)
	out.sort_custom(func(a: Order, b: Order) -> bool:
		return a.cup.shelved_at < b.cup.shelved_at or (a.cup.shelved_at == b.cup.shelved_at and a.ticket_number < b.ticket_number))
	return out


## Moves the ticket to follow its cup when the ticket was clipped at the
## station the cup just left; goes to the rail if the next slot is taken.
func ticket_follow_cup(order: Order, from_station: StringName, to_station: StringName) -> void:
	if order.location != from_station:
		return
	if StationIds.accepts_tickets(to_station) and ticket_at(to_station) == null:
		move_ticket(order, to_station)
	else:
		move_ticket(order, StationIds.RAIL)
