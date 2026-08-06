# Encounters as DATA. Every beat after fight one needs a different anatomy,
# and "the enemy is the board" (SPEC 2.4) means an enemy IS a level: its
# limbs, which stations expose them, and what it does on its turn.
#
# The station-to-limb map lives here ONCE and is read by the sim and the
# presentation both, so the contract can never be two lists that agree
# (SPEC 4.2.3, the bug that made the gullet seal silent last project).
class_name Encounters
extends RefCounted

const FRONT := 0
const FLANK := 1
const UNDER := 2
const REAR := 3
const BACKLINE := 4

static var ALL := {
	# Beat `descent`. One diver, one limb, NO station choice: it teaches
	# that a turn is a budget and the enemy announces itself, before
	# geography exists to complicate either (SPEC 2.7, one idea per beat).
	"descent": {
		"title": "something in the dark",
		# TEACHING BEAT, exempt from the difficulty bands and from the
		# dominant-station check by declaration, not by a silent special
		# case. Its job is to establish that a turn is a budget and the
		# enemy announces itself; it is meant to be trivially winnable and
		# to have exactly one place to stand.
		"teaching": true,
		"party": 1,
		"open_stations": [FRONT],
		"starts": [FRONT],
		"limbs": [{"name": "maw", "hp": 6, "station": FRONT}],
		"attacks": [{"limb": 0, "stations": [FRONT], "dmg": 2, "name": "snaps at"}],
	},
	# Beat `fight1`. Three limbs, four stations, UNDER deliberately empty.
	"crab": {
		"title": "the hunter crab",
		"party": 2,
		"open_stations": [FRONT, FLANK, UNDER, REAR],
		# the opening tableau is content: Scuba in the jaw's face, Prototype1
		# under the belly. It decides what the first turn looks like and it
		# moves the bands, so it is declared rather than falling out of a loop.
		"starts": [FRONT, UNDER],
		"limbs": [
			# Re-swept after the claw gained an attack, which made breaking
			# it a strong play and shortened the fight below the teaching
			# floor. Measured at these values: casual 69.7%, greedy 8.0
			# turns, 8.0 squad HP lost.
			{"name": "jaw", "hp": 18, "station": FRONT},
			{"name": "claw", "hp": 12, "station": FLANK},
			{"name": "tail", "hp": 12, "station": REAR},
		],
		# EVERY limb must DO something or breaking it accomplishes nothing.
		# The claw had no attack, so FLANK was a station with no reason to
		# be stood in and the dominance search called it dead. The claw now
		# guards the head, which makes a real chain: break the claw from
		# FLANK to make FRONT survivable, then break the jaw.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 2, "name": "snaps at"},
			{"limb": 1, "stations": [FRONT], "dmg": 2, "name": "guards with"},
			{"limb": 2, "stations": [REAR, FLANK], "dmg": 2, "name": "sweeps"},
		],
	},
	# Beat `fight2`. A DIFFERENT anatomy, which is the question the whole
	# station design rests on: does the geometry survive a different body?
	# It inverts fight one deliberately. There, UNDER was the empty station
	# and REAR was swept; here UNDER holds a limb and REAR is the empty one,
	# so a player who learned "UNDER is safe" has to look again. Every close
	# station is threatened, which is what finally gives BACKLINE a reason
	# to exist and what makes the disabler's shutdown the answer.
	"spitter": {
		"title": "the vent worm",
		"party": 3,
		# REAR is not open here. It held no limb AND the maw reached it, so
		# it was strictly dominated and the histogram called it dead. The
		# inversion is sharper without it: in fight one UNDER was the safe
		# empty station, here UNDER holds a limb and BACKLINE is the safe
		# one, so a player who learned "UNDER is safe" must look again.
		"open_stations": [FRONT, FLANK, UNDER, BACKLINE],
		"starts": [FRONT, BACKLINE, FLANK],
		"limbs": [
			{"name": "maw", "hp": 16, "station": FRONT},
			{"name": "vent", "hp": 12, "station": FLANK},
			{"name": "gut", "hp": 12, "station": UNDER},
		],
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 3, "name": "lunges at"},
			{"limb": 1, "stations": [FLANK, UNDER], "dmg": 3, "name": "sprays"},
		],
	},
}

# The station-to-limb table, derived from the limb list so it can never
# disagree with it.
static func station_limb(enc: Dictionary) -> Array:
	var out := [-1, -1, -1, -1, -1]
	var limbs: Array = enc.limbs
	for i in range(limbs.size()):
		out[int(limbs[i].station)] = i
	return out
