extends Node
## Global signal bus (autoload "Events").
##
## Scenes emit and listen here instead of holding references to each other.
## Rule of thumb: state lives in GameState / DayManager, these signals only
## announce that it changed.

# --- Day & clock -------------------------------------------------------------
@warning_ignore("unused_signal")
signal day_started(day: int)
## Emitted whenever the in-game clock reaches a new minute (minutes since midnight).
@warning_ignore("unused_signal")
signal clock_changed(minutes: int)
## The café stops letting new customers in (clock hit closing time).
@warning_ignore("unused_signal")
signal shop_closed()

# --- Customers ---------------------------------------------------------------
@warning_ignore("unused_signal")
signal customer_arrived(customer: CustomerData)
## Number of customers waiting at the counter to order changed.
@warning_ignore("unused_signal")
signal queue_changed(waiting_count: int)

# --- Orders & tickets --------------------------------------------------------
## A new order was created (its ticket is still printing).
@warning_ignore("unused_signal")
signal order_taken(order: Order)
## A ticket moved between the rail, the printer and station slots.
@warning_ignore("unused_signal")
signal ticket_moved(order: Order, from_location: StringName, to_location: StringName)

# --- Cups --------------------------------------------------------------------
## A cup was started, moved between stations, or trashed (to_location = &"").
@warning_ignore("unused_signal")
signal cup_moved(order: Order, from_location: StringName, to_location: StringName)
## Something on a cup changed (poured, zapped, topped) without moving it.
@warning_ignore("unused_signal")
signal cup_changed(order: Order)

# --- Serving & days ----------------------------------------------------------
## Ask the Order Station to serve a ready order (rail tap, drag, follow-the-cup).
@warning_ignore("unused_signal")
signal serve_requested(order: Order)
## An order was handed over and graded (result is a Scorer.Result).
@warning_ignore("unused_signal")
signal order_served(order: Order, result: RefCounted)
## The player dismissed the score card; the customer can leave.
@warning_ignore("unused_signal")
signal score_card_closed(order: Order)
## The shift is over: closed and the café is empty.
@warning_ignore("unused_signal")
signal day_ended(summary: Dictionary)

# --- Stations ----------------------------------------------------------------
## Ask Main to show a station (tabs, number keys, spring-loaded drags).
@warning_ignore("unused_signal")
signal request_station(station_id: StringName)
## Main switched the visible station.
@warning_ignore("unused_signal")
signal station_changed(station_id: StringName)

# --- UI ----------------------------------------------------------------------
## Show a short hint message near the top of the screen.
@warning_ignore("unused_signal")
signal toast(text: String)
@warning_ignore("unused_signal")
signal settings_changed(key: String, value: Variant)
## Open the pause menu (HUD button, Esc).
@warning_ignore("unused_signal")
signal pause_requested()

# --- Economy -----------------------------------------------------------------
@warning_ignore("unused_signal")
signal money_changed(cents: int)
@warning_ignore("unused_signal")
signal rank_changed(rank: int)
@warning_ignore("unused_signal")
signal upgrades_changed()
@warning_ignore("unused_signal")
signal theme_changed(theme_id: String)
## Open the upgrade shop (HUD button, pause menu, or the day-end screen).
signal shop_requested()
## A badge was just earned (badge = its Badges.LIST entry).
signal badge_earned(badge: Dictionary)
## Lobby decor bought or rearranged.
signal decor_changed()
## A critic's review came in (stars 1-5); the café rating may have moved.
signal review_posted(stars: int, rating: float)
