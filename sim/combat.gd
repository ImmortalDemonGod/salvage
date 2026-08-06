# Pure combat simulation. RefCounted, no Node, no scene, no timers.
# If a bot cannot run this headless with no scene instantiated, the split
# has already leaked. See SPEC.md 4.3 (G14 harness fidelity).
class_name Combat
extends RefCounted

const FRONT := 0
const FLANK := 1
const UNDER := 2
const REAR := 3
const BACKLINE := 4
const STATION_NAMES := ["FRONT", "FLANK", "UNDER", "REAR", "BACKLINE"]

const Encounters := preload("res://content/encounters.gd")

# Per-encounter, derived from the encounter's limb list so the two can
# never disagree. Fight one runs on FOUR stations: the histogram showed
# UNDER at 0.0 percent, and the cause was not that safety is worthless, it
# was that BACKLINE is ALSO safe with no downside, so UNDER was dominated
# by a duplicate. BACKLINE arrives in fight two with the scanner that makes
# standing there worth it.
var STATION_LIMB: Array = []
var OPEN_STATIONS: Array = []
var LIMB_NAMES: Array = []
var enc_id := "crab"
var enc: Dictionary = {}

const AIR_PER_TURN := 4   # see TUNE.air; this is the ceiling for clamping
const MOVE_COST := 1
const OVERDRAFT_HP := 2

class Diver extends RefCounted:
	var id: int
	var dname: String
	var cost: int
	var disables: bool = false
	var max_hp: int
	var hp: int
	var dmg: int
	var station: int
	var down: bool = false
	func _init(i: int, n: String, c: int, h: int, d: int, s: int) -> void:
		id = i; dname = n; cost = c; max_hp = h; hp = h; dmg = d; station = s

# Tunables in one place so the sweep can vary them and the bands can be
# measured rather than argued. Defaults are the day-zero values.
static var TUNE := {
	# Chosen by tools/sweep.gd, not by argument. Eight configurations land
	# G3 in band; this is the one with the smallest numbers, per
	# Glass_Goat's directive that results stay countable like chess.
	# Measured at these values: casual 73.0%, greedy 7.0 turns, 22.0 HP lost.
	# Re-swept after G-TEACH forced fight one down to two divers. Of 48
	# cells only ONE lands G3 in band, which is worth knowing: the
	# two-diver fight is a narrow design space and the next content change
	# will likely knock it out. Measured here: casual 66.3%, greedy 6.0
	# turns (floor 6.0), 10.0 squad HP lost (floor 8.0).
	"diver_hp": [8, 14, 16],
	"diver_dmg": [2, 2, 5],
	"air": 4,
}

var divers: Array = []
var limb_hp: Array = []
var limb_broken: Array = []
var air := AIR_PER_TURN
var air_penalty := 0          # umbilicals cut last turn
var turn := 1
var outcome := "ongoing"      # ongoing | victory | defeat
var log_lines: Array = []
var _rotation := 0            # deterministic enemy cycle
var overdrafted := false      # the valve opens once per turn, not endlessly
# STUN: a limb that is stunned does not attack on its next turn. Chosen
# because it is deterministic (Q1 forbids hidden rolls) and because it makes
# the telegraph ACTIONABLE: you see the jaw winding up and you shut it. That
# is the counterplay the whole information design was missing.
var limb_stun: Array = []

func _init(encounter := "crab") -> void:
	enc_id = encounter
	enc = (Encounters.ALL[encounter] as Dictionary)
	STATION_LIMB = Encounters.station_limb(enc)
	OPEN_STATIONS = (enc.open_stations as Array).duplicate()
	LIMB_NAMES = []
	limb_hp = []
	limb_broken = []
	limb_stun = []
	for l in enc.limbs:
		LIMB_NAMES.append(String(l.name))
		limb_hp.append(int(l.hp))
		limb_broken.append(false)
		limb_stun.append(0)
	var hp: Array = TUNE.diver_hp
	var dm: Array = TUNE.diver_dmg
	var roster := [["Scuba", 1, false], ["Prototype1", 2, true], ["Proto5", 3, false]]
	var starts: Array = enc.get("starts", [])
	divers = []
	var n: int = min(int(enc.party), roster.size())
	for i in range(n):
		var start: int = int(starts[i]) if i < starts.size() else int(OPEN_STATIONS[i % OPEN_STATIONS.size()])
		var dv := Diver.new(i, String(roster[i][0]), int(roster[i][1]), int(hp[i]), int(dm[i]), start)
		dv.disables = bool(roster[i][2])
		divers.append(dv)
	air = int(TUNE.air)

# ---- enemy anatomy: fight one, the hunter crab -------------------------
# Three limbs. UNDER is deliberately empty, which is what proves the
# geometry is real: it is a place you can stand that does nothing
# offensively, and the jaw cannot reach it. Safety is a reason to move.
func attacks() -> Array:
	return enc.attacks

func live_attacks() -> Array:
	var out: Array = []
	for a in attacks():
		if not limb_broken[a.limb] and int(limb_stun[a.limb]) <= 0:
			out.append(a)
	return out

# The telegraph. Deterministic, shown at the START of the player's turn,
# and it is exactly what will happen (SPEC 2.11).
func intent() -> Dictionary:
	var live := live_attacks()
	if live.is_empty():
		return {}
	return live[_rotation % live.size()]

func air_this_turn() -> int:
	return max(0, int(TUNE.air) - air_penalty)

# ---- player actions ----------------------------------------------------
func alive() -> Array:
	var out: Array = []
	for d in divers:
		if not d.down:
			out.append(d)
	return out

func can_attack(d) -> bool:
	return STATION_LIMB[d.station] >= 0 and not limb_broken[STATION_LIMB[d.station]]

func afford(cost: int) -> bool:
	return air >= cost

func act_attack(i: int) -> bool:
	if i < 0 or i >= divers.size():
		return false
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(d.cost) or not can_attack(d):
		return false
	air -= d.cost
	var limb: int = STATION_LIMB[d.station]
	limb_hp[limb] -= d.dmg
	log_lines.append("%s hits the %s for %d" % [d.dname, LIMB_NAMES[limb], d.dmg])
	# SPEC 2.9 gives Prototype1 the verb *disable*. Until it had one it was
	# strictly worse than Scuba at attacking and G4 reported it dominated.
	if d.disables and not limb_broken[limb]:
		limb_stun[limb] = 2
		log_lines.append("the %s is shut down" % LIMB_NAMES[limb])
	if limb_hp[limb] <= 0:
		limb_hp[limb] = 0
		limb_broken[limb] = true
		log_lines.append("the %s BREAKS" % LIMB_NAMES[limb])
		_check_victory()
	return true

func station_open(station: int) -> bool:
	return station in OPEN_STATIONS

func act_move(i: int, station: int) -> bool:
	# Validate BEFORE spending anything. The fuzz bot proved act_move(0, 5)
	# put a diver on station 5, off a five-station board, and that a caller
	# could not tell refusal from corruption.
	if i < 0 or i >= divers.size() or station < 0 or station >= STATION_NAMES.size():
		return false
	if not station_open(station):
		return false
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(MOVE_COST) or d.station == station:
		return false
	air -= MOVE_COST
	d.station = station
	log_lines.append("%s moves to %s" % [d.dname, STATION_NAMES[station]])
	return true

# Glass_Goat's desperation valve, kept as one rule rather than a system.
func act_overdraft(i: int) -> bool:
	# ONCE per turn. The fuzz bot stacked it to air 8 against a bound of 5,
	# which is unlimited actions for HP: a dominant strategy, not a valve.
	if i < 0 or i >= divers.size():
		return false
	var d = divers[i]
	if outcome != "ongoing" or overdrafted or d.down or d.hp <= OVERDRAFT_HP:
		return false
	overdrafted = true
	d.hp -= OVERDRAFT_HP
	air += 1
	log_lines.append("%s burns %d HP for 1 Air" % [d.dname, OVERDRAFT_HP])
	return true

func _check_victory() -> void:
	for b in limb_broken:
		if not b:
			return
	outcome = "victory"
	log_lines.append("the crab is disabled")

# ---- enemy turn --------------------------------------------------------
func end_turn() -> void:
	if outcome != "ongoing":
		return
	var a := intent()
	air_penalty = 0
	if not a.is_empty():
		var hit := false
		for d in divers:
			if d.down:
				continue
			if d.station in a.stations:
				hit = true
				d.hp -= a.dmg
				log_lines.append("the %s %s %s for %d" % [LIMB_NAMES[a.limb], a.name, d.dname, a.dmg])
				if d.hp <= 0:
					d.hp = 0
					d.down = true
					log_lines.append("%s is down" % d.dname)
		# The vacate rule. Without this, three divers can empty every
		# targeted station for 3 of 4 Air every turn and the enemy never
		# connects: a dominant strategy of exactly the class G4 exists to
		# catch. A strike into empty water cuts the umbilicals instead.
		if not hit:
			air_penalty = 1
			log_lines.append("the %s hits empty water and cuts an air line" % LIMB_NAMES[a.limb])
		_rotation += 1
	if alive().is_empty():
		outcome = "defeat"
		log_lines.append("the squad is lost")
	for i in range(limb_stun.size()):
		if int(limb_stun[i]) > 0:
			limb_stun[i] = int(limb_stun[i]) - 1
	turn += 1
	overdrafted = false
	air = air_this_turn()

# Deep-set rollouts need to try an action and unwind. Cloning keeps the sim
# pure: no undo stack, no hidden state to get out of sync.
func clone() -> Combat:
	var c := Combat.new(enc_id)
	for i in range(divers.size()):
		var a = divers[i]
		var b = c.divers[i]
		b.hp = a.hp; b.station = a.station; b.down = a.down
	c.limb_hp = limb_hp.duplicate()
	c.limb_broken = limb_broken.duplicate()
	c.limb_stun = limb_stun.duplicate()
	c.air = air; c.air_penalty = air_penalty; c.turn = turn; c.overdrafted = overdrafted
	c.outcome = outcome; c._rotation = _rotation
	return c
