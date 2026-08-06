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
		"title": "the rig",
		"teaches": "goal",
		"uses": ["goal"],
		"built": true,
		# The opening is a MECHANIC, not polish (SPEC 3.3). It must deliver
		# four things in under a minute and nothing else. Each line carries
		# the role it serves so verify/ can assert all four are present:
		# a scene that forgets to say what you want is the exact failure
		# the last prototype shipped.
		# ALL TEXT PLACEHOLDER, for Marc.
		"lines": [
			{"role": "who", "text": "(placeholder) Three of you. Two suits and a set of scuba gear, all of it borrowed."},
			{"role": "obstacle", "text": "(placeholder) The water never went down. Everything worth having is under it, and the things down there got there first."},
			{"role": "want", "text": "(placeholder) The pump is dying. What fixes it is down in the city. We go down."},
			# controls for THIS beat only. Combat keys are taught in `descent`,
			# which is the beat that teaches the combat frame: telling a player
			# how to end a turn before turns exist is the teach ladder broken
			# in the UI instead of the data.
			{"role": "controls", "text": "ENTER to descend"},
		],
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
		"title": "the drum fitted",
		"teaches": "conditions",
		"uses": ["goal", "stations", "air", "conditions"],
		"built": true,
		"lines": [
			{"role": "who", "text": "(placeholder) Prototype1 comes down with you now, and it brings the drum."},
			{"role": "want", "text": "(placeholder) Point the drum at whatever is winding up and it stops. It reaches from the back line, so you do not have to be in front of the thing to shut it."},
			{"role": "controls", "text": "ENTER to descend"},
		],
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
		"kind": "combat",
		"encounter": "spitter",
		"title": "the vent worm",
		"teaches": "backline",
		"uses": ["stations", "air", "limbs", "telegraph", "conditions", "backline"],
		"built": true,
		"expect": {"encounter": "spitter", "divers": 2, "open_stations": 4, "limbs": 3},
	},
	{
		"id": "boat2",
		"kind": "scene",
		"title": "the big suit",
		"teaches": "cost_tiers",
		"uses": ["goal", "stations", "air", "cost_tiers"],
		"built": false,
		"note": "Proto5 arrives: three lines of air to move or swing, which is the beat where the cost tiers finally matter",
	},
	{
		"id": "deep1",
		"title": "running on empty",
		"teaches": "umbilical",
		"parts": ["overdraft"],
		"uses": ["goal", "stations", "air", "umbilical", "overdraft"],
		"built": false,
		"note": "a strike into empty water cuts a line, and burning HP to buy one back is the same lesson from the other side: air is what you are short of",
	},
]

# Mechanics that exist in the sim but are not yet placed on the ladder.
# Anything here is a finding: an untaught mechanic is one the player meets
# without ever having been shown it alone.
# Every opening must answer these four, in this order, or a player cannot
# say what they are doing. Checked by verify/teach.gd.
static var REQUIRED_OPENING_ROLES := ["who", "obstacle", "want", "controls"]

static var MECHANICS := ["goal", "combat_frame", "stations", "air", "limbs",
	"telegraph", "cost_tiers", "water_level", "conditions", "backline",
	"overdraft", "umbilical"]
