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
		"art": {"kind": "crab", "scale": 110.0, "pos": [880, 320], "tint": [0.32, 0.38, 0.44]},
		"places": {"0": [700, 386]},
		# TEACHING BEAT, exempt from the difficulty bands and from the
		# dominant-station check by declaration, not by a silent special
		# case. Its job is to establish that a turn is a budget and the
		# enemy announces itself; it is meant to be trivially winnable and
		# to have exactly one place to stand.
		"teaching": true,
		"party": 1,
		"drum": false,
		"open_stations": [FRONT],
		"starts": [FRONT],
		"limbs": [{"name": "maw", "hp": 6, "station": FRONT}],
		"attacks": [{"limb": 0, "stations": [FRONT], "dmg": 2, "name": "snaps at"}],
	},
	# Beat `fight1`. Three limbs, four stations, UNDER deliberately empty.
	"crab": {
		"title": "the hunter crab",
		"art": {"kind": "crab", "scale": 124.0, "pos": [878, 316], "tint": [1.0, 1.0, 1.0]},
		"places": {"0": [648, 386], "1": [752, 292], "2": [906, 424], "3": [1058, 322]},
		# TWO divers. One was tried and REFUTED by measurement: the crab
		# became unwinnable (G2 0/40), casual fell to 5.2 percent, and
		# UNDER went dead because a lone diver never has a reason to stand
		# somewhere safe. The stations design needs two bodies, because
		# "who is standing where when the jaw comes down" is the whole
		# tension. Prototype1 earns its place here as the body that can
		# hold FRONT at 14 HP where Scuba at 8 cannot; it gains the drum,
		# and its verb, at the boat.
		"party": 2,
		"drum": false,
		"open_stations": [FRONT, FLANK, UNDER, REAR],
		# the opening tableau is content: Scuba in the jaw's face, Prototype1
		# under the belly. It decides what the first turn looks like and it
		# moves the bands, so it is declared rather than falling out of a loop.
		"starts": [FRONT, UNDER],
		"limbs": [
			# Swept after every limb gained an attack. Measured: casual
			# 69.3%, greedy 6.0 turns, 10.0 squad HP lost.
			# swept after Proto5 became the efficient heavy (8 dmg for 3 Air)
			# and the overdraft was cut. All three encounters land at limbs
			# x1.45: crab 66.7% / 9.0 turns / 14.0 HP
			{"name": "jaw", "hp": 23, "station": FRONT},
			{"name": "claw", "hp": 19, "station": FLANK},
			{"name": "tail", "hp": 19, "station": REAR},
		],
		# SPEC 2.6 verbatim: "the jaw only reaches FRONT, and the tail sweeps
		# REAR and FLANK together. No conditions, no statuses, no special
		# rules." A third attack had crept in (the claw guarding the head),
		# which a fidelity review caught as a spec violation. The claw needs
		# no attack of its own to be worth breaking: the win condition is
		# breaking EVERY limb, so it is a target either way, and its station
		# is threatened by the tail so standing there still costs.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 2, "name": "snaps at"},
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
		# a LONGER, thinner body: the stations sit further apart along it,
		# so the board itself reads differently from the crab's
		"art": {"kind": "worm", "scale": 150.0, "pos": [900, 300], "tint": [0.55, 0.85, 0.70]},
		"places": {"0": [640, 366], "1": [858, 268], "2": [926, 424], "4": [300, 386]},
		"party": 2,
		# The drum is fitted before this fight, so it is declared HERE.
		# While gear was a global set by the run, the bands measured the
		# worm without the drum: a configuration no player ever meets.
		"drum": true,
		# REAR is not open here. It held no limb AND the maw reached it, so
		# it was strictly dominated and the histogram called it dead. The
		# inversion is sharper without it: in fight one UNDER was the safe
		# empty station, here UNDER holds a limb and BACKLINE is the safe
		# one, so a player who learned "UNDER is safe" must look again.
		"open_stations": [FRONT, FLANK, UNDER, BACKLINE],
		"starts": [FRONT, BACKLINE],
		"limbs": [
			# swept at the played configuration, drum fitted
			# swept: casual 60.0%, greedy 6.0 turns, 14.0 squad HP lost.
			# Chose the harder-hitting variant so damage CLIMBS across the
			# ladder (crab 2s, worm 5/5/3, dredge 4/3/4) rather than the
			# gentler one that would have made fight two easier than fight
			# one.
			{"name": "maw", "hp": 10, "station": FRONT},
			{"name": "vent", "hp": 7, "station": FLANK},
			{"name": "gut", "hp": 7, "station": UNDER},
		],
		# Every limb attacks, so every station is threatened by something and
		# breaking any of them changes the map. The gut had no attack, which
		# made BACKLINE free safety: the greedy bot simply parked both divers
		# there, stunned whatever was winding up, and finished the fight
		# without taking a scratch. Same defect as the crab's claw, found the
		# same way.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 5, "name": "lunges at"},
			{"limb": 1, "stations": [FLANK, UNDER], "dmg": 5, "name": "sprays"},
			{"limb": 2, "stations": [BACKLINE], "dmg": 3, "name": "vents over"},
			{"limb": 2, "stations": [UNDER], "dmg": 3, "name": "curls under"},
		],
	},
	# Beat `deep1`. A MACHINE, not a creature: SPEC 2.4 says a machine reads
	# as a puzzle box and should be earned after anatomy is taught, and by
	# now it has been, twice. Every station is open and every one is
	# threatened, so evading everything means moving the whole squad, which
	# is expensive with the big suit in the party. That is the beat where
	# the umbilical rule and the HP overdraft finally bite.
	"dredge": {
		"title": "the dredge",
		"art": {"kind": "dredge", "scale": 132.0, "pos": [890, 306], "tint": [0.72, 0.62, 0.42]},
		"places": {"0": [686, 400], "1": [820, 276], "3": [1064, 356], "4": [300, 400]},
		"party": 3,
		"drum": true,
		# UNDER is closed here. Every open station must either expose a limb
		# or be safe; UNDER would have been threatened and empty, which is
		# dead by construction. BACKLINE is the single safe place, and it
		# earns that because the drum reaches from it.
		"open_stations": [FRONT, FLANK, REAR, BACKLINE],
		"starts": [FRONT, BACKLINE, FLANK],
		"limbs": [
			# swept after the boiler widened to three stations. Measured:
			# casual 63.3%, greedy 7.0 turns, 8.0 squad HP lost.
			# re-swept after the limbs gained alternating arcs. Splitting the
			# boiler's three-station vent into two smaller ones bought the
			# player safe ground and handed back too much: casual 92.5%,
			# outside the pinned band. Paid for in limb HP and damage, not
			# by moving the band.
			{"name": "arm", "hp": 14, "station": FRONT},
			{"name": "boiler", "hp": 12, "station": FLANK},
			{"name": "winch", "hp": 12, "station": REAR},
		],
		"attacks": [
			{"limb": 0, "stations": [FRONT, FLANK], "dmg": 4, "name": "sweeps"},
			{"limb": 0, "stations": [FRONT], "dmg": 6, "name": "hammers"},
			{"limb": 1, "stations": [FLANK, REAR], "dmg": 4, "name": "vents over"},
			{"limb": 1, "stations": [BACKLINE], "dmg": 4, "name": "vents back over"},
			{"limb": 2, "stations": [REAR], "dmg": 5, "name": "lashes"},
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
