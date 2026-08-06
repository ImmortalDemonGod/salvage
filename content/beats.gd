# The teach ladder, as DATA so it can be checked instead of remembered.
#
# SPEC 2.7: every beat introduces exactly one new idea, and a mechanic must
# appear ALONE before it appears COMBINED. This file declares the ladder;
# verify/teach.gd checks the declaration against itself AND against what
# the sim actually exposes, so the document cannot quietly disagree with
# the game.
class_name Beats
extends RefCounted

# teaches: the ONE new idea this beat introduces.
# parts:   mechanics that ARE that idea rather than separate ideas. They must
#          be declared here, so hiding a mechanic inside a beat costs a line
#          someone can argue with. SPEC 2.3 is the precedent: "the limb IS
#          the position, there is no separate targeting step", so limbs and
#          stations are one idea with two names.
# uses:    every mechanic the beat leans on. All must be taught here or earlier.
static var LADDER := [
	{
		"id": "opening",
		"kind": "scene",
		"title": "the boat",
		"teaches": "goal",
		"uses": ["goal"],
		"built": false,
	},
	{
		"id": "descent",
		"kind": "combat",
		"encounter": "descent",
		"title": "the descent",
		"teaches": "combat_frame",
		"parts": ["air", "telegraph"],
		"uses": ["goal", "combat_frame", "air", "telegraph"],
		"built": true,
		"expect": {"encounter": "descent", "divers": 1, "open_stations": 1, "limbs": 1},
		"note": "one diver, one limb, no station choice: establishes that a turn is a budget and the enemy announces itself, BEFORE geography exists",
	},
	{
		"id": "fight1",
		"kind": "combat",
		"encounter": "crab",
		"title": "the hunter crab",
		"teaches": "stations",
		"parts": ["limbs"],
		"uses": ["goal", "combat_frame", "stations", "air", "limbs", "telegraph"],
		"built": true,
		"expect": {"encounter": "crab", "divers": 2, "open_stations": 4, "limbs": 3},
	},
	{
		"id": "boat1",
		"kind": "scene",
		"title": "Proto5 joins",
		"teaches": "cost_tiers",
		"uses": ["goal", "stations", "air", "cost_tiers"],
		"built": false,
	},
	{
		"id": "puzzle1",
		"title": "flood and drain",
		"teaches": "water_level",
		"uses": ["goal", "water_level"],
		"built": false,
	},
	{
		"id": "fight2",
		"title": "conditions, via the drum",
		"teaches": "backline",
		"uses": ["stations", "air", "limbs", "telegraph", "cost_tiers", "backline"],
		"built": false,
		"note": "the drum works from range, so the station that exists for it opens with it",
	},
	{
		"id": "fight3",
		"title": "the drum fitted",
		"teaches": "conditions",
		"uses": ["stations", "air", "limbs", "telegraph", "cost_tiers", "backline", "conditions"],
		"built": false,
	},
	{
		"id": "boat2",
		"title": "the failing pump",
		"teaches": "umbilical",
		"uses": ["goal", "stations", "air", "umbilical"],
		"built": false,
		"note": "a strike into empty water cuts an air line: taught when the player has a reason to dodge",
	},
	{
		"id": "deep1",
		"title": "running on empty",
		"teaches": "overdraft",
		"uses": ["goal", "stations", "air", "umbilical", "overdraft"],
		"built": false,
		"note": "spend HP to buy an Air, taught in the beat where Air first runs short",
	},
]

# Mechanics that exist in the sim but are not yet placed on the ladder.
# Anything here is a finding: an untaught mechanic is one the player meets
# without ever having been shown it alone.
static var MECHANICS := ["goal", "combat_frame", "stations", "air", "limbs",
	"telegraph", "cost_tiers", "water_level", "conditions", "backline",
	"overdraft", "umbilical"]
