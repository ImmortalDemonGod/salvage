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
			{"role": "obstacle", "text": "(placeholder) Every diver wants the same thing: to come back up. In four days there will be nothing to come back up to. The pump on this rig dies then, the rig floods, and we are standing on it."},
			{"role": "who", "text": "(placeholder) There are three of us. Two borrowed suits, one set of scuba gear, and nobody left who is qualified."},
			{"role": "want", "text": "(placeholder) The part that fixes it is in the city underneath us. The city has been under water for eleven years, and whatever got there first is still down there.\n\nWe go down. We come back up. That is the whole plan."},
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
		"parts": ["air", "telegraph", "cost_tiers"],
		"uses": ["goal", "combat_frame", "air", "telegraph", "cost_tiers"],
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
		"parts": ["limbs", "analyze"],
		"uses": ["goal", "combat_frame", "stations", "air", "limbs", "telegraph", "cost_tiers"],
		"built": true,
		"expect": {"encounter": "crab", "divers": 2, "open_stations": 4, "limbs": 3},
	},
	{
		"id": "boat1",
		"kind": "scene",
		"title": "the drum fitted",
		"teaches": "conditions",
		"uses": ["goal", "stations", "air", "conditions"],
		# clearing the first fight pays for the second verb. The reward is
		# the teaching: one new idea per beat, and this beat's idea is that
		# what you already have can be spent a second way.
		"grants_ability": 2,
		"built": true,
		"lines": [
			{"role": "who", "text": "(placeholder) The crab is dealt with and everyone came back up. That bought us a night on deck, and we spent it fitting the drum to Prototype1's suit."},
			{"role": "want", "text": "(placeholder) Point the drum at whatever is winding up and it stops. It reaches from the back line, so you do not have to be in front of the thing to shut it."},
			{"role": "want", "text": "(placeholder) There was time to drill, too. Every diver now has a second use for what they already carry. The part is deeper than we got today, and the pump is not waiting. We go back down."},
			{"role": "controls", "text": "ENTER to descend"},
		],
	},
	{
		"id": "puzzle1",
		"kind": "puzzle",
		"title": "flood and drain",
		"teaches": "water_level",
		"uses": ["goal", "water_level"],
		"built": true,
	},
	{
		"id": "fight2",
		"kind": "combat",
		"encounter": "spitter",
		"title": "the vent worm",
		"teaches": "backline",
		"parts": ["hunts"],
		"uses": ["stations", "air", "limbs", "telegraph", "conditions", "backline"],
		"built": true,
		"expect": {"encounter": "spitter", "divers": 2, "open_stations": 4, "limbs": 3},
	},
	{
		"id": "puzzle2",
		"kind": "puzzle",
		"stage": 2,
		"title": "two chambers",
		"teaches": "",
		"uses": ["goal", "water_level"],
		"built": true,
		"note": "the same grammar, harder: A cannot fill itself, so the crossover is required, and the crossover is under B",
	},
	{
		"id": "boat2",
		"kind": "scene",
		"title": "the big suit",
		"teaches": "heavy_tier",
		"uses": ["goal", "stations", "air", "cost_tiers", "heavy_tier"],
		"built": true,
		"lines": [
			{"role": "who", "text": "(placeholder) The way to the part is open now, and it runs deep. What waits at the bottom is too big for the light gear alone. So today, for the first time, the big suit goes in the water."},
			{"role": "want", "text": "(placeholder) Every diver moves once a turn for free. Swinging is what costs air, and one swing of the big suit takes three of the four lines the pump sends down. Bring it and most of the turn belongs to one diver."},
			{"role": "controls", "text": "ENTER to descend"},
		],
	},
	{
		"id": "deep1",
		"kind": "combat",
		"encounter": "dredge",
		"title": "running on empty",
		"teaches": "umbilical",
		"parts": ["overdraft", "ramp", "salvage"],
		"uses": ["goal", "stations", "air", "limbs", "telegraph", "cost_tiers", "heavy_tier", "conditions", "backline", "umbilical", "overdraft"],
		"built": true,
		"expect": {"encounter": "dredge", "divers": 3, "open_stations": 4, "limbs": 3},
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
	"telegraph", "cost_tiers", "heavy_tier", "water_level", "conditions", "backline",
	"overdraft", "umbilical", "analyze", "hunts", "ramp", "salvage"]
