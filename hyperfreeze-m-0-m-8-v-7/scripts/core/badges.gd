class_name Badges
extends RefCounted
## Every badge: what it takes, what it pays, and what it unlocks.
## Progress comes from GameState.stats (counted as you play); GameState
## checks the list after each serve, day end, rank-up and purchase.
##
## stat keys:
##   served, perfects (score 100), great_zap_streak_best, tips_cents,
##   gold_stars, critics_served, critic_five_star, days, rank,
##   flawless_days, patient_days, decor_owned, upgrades_owned, top_rated

const GROUPS: Array[String] = ["Service", "Quality", "Zap", "Money", "Regulars", "Critics", "Progress", "Café"]

## unlock = a badge-only reward id ("" for coins only).
const LIST: Array[Dictionary] = [
	{"id": "first_scoop", "name": "First Scoop", "group": "Service", "stat": "served", "goal": 1, "reward": 200, "unlock": "",
		"text": "Serve your first treat."},
	{"id": "regular_server", "name": "Regular Server", "group": "Service", "stat": "served", "goal": 25, "reward": 1000, "unlock": "",
		"text": "Serve 25 treats."},
	{"id": "star_server", "name": "Star Server", "group": "Service", "stat": "served", "goal": 100, "reward": 2500, "unlock": "decor_golden_cone",
		"text": "Serve 100 treats."},
	{"id": "legend_server", "name": "Legend of the Lane", "group": "Service", "stat": "served", "goal": 250, "reward": 6000, "unlock": "theme_silver",
		"text": "Serve 250 treats."},
	{"id": "first_perfect", "name": "Out of This World", "group": "Quality", "stat": "perfects", "goal": 1, "reward": 500, "unlock": "",
		"text": "Score a perfect 100."},
	{"id": "perfectionist", "name": "Perfectionist", "group": "Quality", "stat": "perfects", "goal": 10, "reward": 2000, "unlock": "decor_disco_orb",
		"text": "Score 10 perfect treats."},
	{"id": "flawless_day", "name": "Flawless Shift", "group": "Quality", "stat": "flawless_days", "goal": 1, "reward": 2500, "unlock": "",
		"text": "Finish a day where every treat scored 90+ (at least 4 served)."},
	{"id": "zap_apprentice", "name": "Zap Apprentice", "group": "Zap", "stat": "great_zap_streak_best", "goal": 1, "reward": 300, "unlock": "",
		"text": "Land a perfect zap."},
	{"id": "zap_master", "name": "Zap Master", "group": "Zap", "stat": "great_zap_streak_best", "goal": 5, "reward": 1500, "unlock": "",
		"text": "Land 5 perfect zaps in a row."},
	{"id": "zap_legend", "name": "Zap Legend", "group": "Zap", "stat": "great_zap_streak_best", "goal": 15, "reward": 4000, "unlock": "theme_midnight",
		"text": "Land 15 perfect zaps in a row."},
	{"id": "pocket_change", "name": "Pocket Change", "group": "Money", "stat": "tips_cents", "goal": 2500, "reward": 500, "unlock": "",
		"text": "Earn $25 in tips."},
	{"id": "money_maker", "name": "Money Maker", "group": "Money", "stat": "tips_cents", "goal": 10000, "reward": 1000, "unlock": "",
		"text": "Earn $100 in tips."},
	{"id": "cosmic_tycoon", "name": "Cosmic Tycoon", "group": "Money", "stat": "tips_cents", "goal": 50000, "reward": 5000, "unlock": "decor_captain_statue",
		"text": "Earn $500 in tips."},
	{"id": "first_gold_star", "name": "Gold Standard", "group": "Regulars", "stat": "gold_stars", "goal": 1, "reward": 500, "unlock": "",
		"text": "Earn a regular's gold star."},
	{"id": "fan_club", "name": "Fan Club", "group": "Regulars", "stat": "gold_stars", "goal": 5, "reward": 2500, "unlock": "theme_candy",
		"text": "Earn 5 gold stars."},
	{"id": "first_review", "name": "Under Review", "group": "Critics", "stat": "critics_served", "goal": 1, "reward": 500, "unlock": "",
		"text": "Serve a food critic."},
	{"id": "five_star_review", "name": "Five Stars!", "group": "Critics", "stat": "critic_five_star", "goal": 1, "reward": 2000, "unlock": "decor_critic_plaque",
		"text": "Get a five-star critic review."},
	{"id": "top_rated", "name": "Top Rated", "group": "Critics", "stat": "top_rated", "goal": 1, "reward": 4000, "unlock": "",
		"text": "Reach a 4.5-star café rating (3+ reviews)."},
	{"id": "day_5", "name": "Settling In", "group": "Progress", "stat": "days", "goal": 5, "reward": 1000, "unlock": "",
		"text": "Complete 5 days."},
	{"id": "day_10", "name": "Local Favourite", "group": "Progress", "stat": "days", "goal": 10, "reward": 2500, "unlock": "",
		"text": "Complete 10 days."},
	{"id": "day_20", "name": "Galactic Landmark", "group": "Progress", "stat": "days", "goal": 20, "reward": 6000, "unlock": "",
		"text": "Complete 20 days."},
	{"id": "rank_5", "name": "Rising Star", "group": "Progress", "stat": "rank", "goal": 5, "reward": 1500, "unlock": "",
		"text": "Reach rank 5."},
	{"id": "rank_10", "name": "Café Captain", "group": "Progress", "stat": "rank", "goal": 10, "reward": 5000, "unlock": "",
		"text": "Reach rank 10."},
	{"id": "patience_pro", "name": "Patience Pro", "group": "Café", "stat": "patient_days", "goal": 1, "reward": 1500, "unlock": "",
		"text": "Finish a day where every wait grade was 80+ (at least 5 served)."},
	{"id": "decorator", "name": "Interior Designer", "group": "Café", "stat": "decor_owned", "goal": 4, "reward": 1500, "unlock": "",
		"text": "Own 4 pieces of lobby decor."},
	{"id": "fully_loaded", "name": "Fully Loaded", "group": "Café", "stat": "upgrades_owned", "goal": 8, "reward": 3000, "unlock": "",
		"text": "Own all 8 café upgrades."},
]


static func find(id: String) -> Dictionary:
	for b: Dictionary in LIST:
		if b.id == id:
			return b
	return {}


## Short reward line, e.g. "+$25.00 · unlocks Disco Orb".
static func reward_text(b: Dictionary) -> String:
	var parts: Array[String] = ["+" + GameState.format_money(int(b.reward))]
	if String(b.unlock) != "":
		parts.append("unlocks " + Upgrades.display_name(String(b.unlock)))
	return "  ·  ".join(parts)


## Placeholder badge colour by group (until badge art exists).
static func group_color(group: String) -> Color:
	match group:
		"Service": return Color("3ee6f0")
		"Quality": return Color("ffd95a")
		"Zap": return Color("ff7eb6")
		"Money": return Color("7be07b")
		"Regulars": return Color("ffb347")
		"Critics": return Color("c39bff")
		"Progress": return Color("8fb8ff")
	return Color("f4f1ff")
