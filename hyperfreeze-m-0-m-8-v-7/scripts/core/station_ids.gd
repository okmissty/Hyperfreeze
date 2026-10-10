class_name StationIds
extends RefCounted
## Shared names for stations and ticket locations, so nobody types raw strings.

const ORDER := &"order"
const BUILD := &"build"
const ZAP := &"zap"
const TOP := &"top"

## Ticket locations that are not stations.
const RAIL := &"rail"
const PRINTING := &"printing"

## Cup locations (a cup being built sits at BUILD).
const ZAP_SHELF := &"zap_shelf"
const TOP_SHELF := &"top_shelf"
const TOP_COUNTER := &"top_counter"
const READY := &"ready"
## Handed to the customer (tickets and cups both end here).
const SERVED := &"served"

## Stations in tab order.
const ALL: Array[StringName] = [ORDER, BUILD, ZAP, TOP]

## Stations that have a ticket slot (the Order Station does not).
const TICKET_STATIONS: Array[StringName] = [BUILD, ZAP, TOP]


static func accepts_tickets(station_id: StringName) -> bool:
	return station_id in TICKET_STATIONS


static func display_name(station_id: StringName) -> String:
	match station_id:
		ORDER: return "Order"
		BUILD: return "Build"
		ZAP: return "Zap"
		TOP: return "Top"
		RAIL: return "Rail"
	return String(station_id).capitalize()


static func blender(index: int) -> StringName:
	return StringName("blender_%d" % index)


static func is_blender(location: StringName) -> bool:
	return String(location).begins_with("blender_")


## Which station a cup location belongs to (for badges and ticket stamps).
static func station_for_cup(location: StringName) -> StringName:
	if location == BUILD:
		return BUILD
	if location == ZAP_SHELF or is_blender(location):
		return ZAP
	if location == TOP_SHELF or location == TOP_COUNTER:
		return TOP
	return location
