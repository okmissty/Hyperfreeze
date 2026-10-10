class_name RankTable
extends Resource
## XP needed to reach each rank. Index 0 = rank 1.

@export var xp_thresholds: PackedInt32Array = PackedInt32Array([0, 150, 400, 750, 1200, 1800, 2500, 3300, 4200, 5200])


func rank_for_xp(xp: int) -> int:
	var rank := 1
	for i in xp_thresholds.size():
		if xp >= xp_thresholds[i]:
			rank = i + 1
	return rank


## XP needed for the next rank, or -1 at max rank.
func xp_for_next_rank(xp: int) -> int:
	var next_index := rank_for_xp(xp)
	if next_index >= xp_thresholds.size():
		return -1
	return xp_thresholds[next_index]
