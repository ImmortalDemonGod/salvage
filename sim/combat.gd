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

const JAW := 0
const CLAW := 1
const TAIL := 2
const LIMB_NAMES := ["jaw", "claw", "tail"]

# The limb IS the position. One table, read by sim and presentation both,
# so the contract can never be two lists that agree (SPEC 4.2.3).
const STATION_LIMB := [JAW, CLAW, -1, TAIL, -1]

const AIR_PER_TURN := 4
const MOVE_COST := 1
const OVERDRAFT_HP := 2

class Diver extends RefCounted:
	var id: int
	var dname: String
	var cost: int
	var max_hp: int
	var hp: int
	var dmg: int
	var station: int
	var down: bool = false
	func _init(i: int, n: String, c: int, h: int, d: int, s: int) -> void:
		id = i; dname = n; cost = c; max_hp = h; hp = h; dmg = d; station = s

var divers: Array = []
var limb_hp := [8, 6, 6]
var limb_broken := [false, false, false]
var air := AIR_PER_TURN
var air_penalty := 0          # umbilicals cut last turn
var turn := 1
var outcome := "ongoing"      # ongoing | victory | defeat
var log_lines: Array = []
var _rotation := 0            # deterministic enemy cycle

func _init() -> void:
	divers = [
		Diver.new(0, "Scuba", 1, 6, 2, FRONT),
		Diver.new(1, "Prototype1", 2, 10, 2, BACKLINE),
		Diver.new(2, "Proto5", 3, 16, 5, FLANK),
	]

# ---- enemy anatomy: fight one, the hunter crab -------------------------
# Three limbs. UNDER is deliberately empty, which is what proves the
# geometry is real: it is a place you can stand that does nothing
# offensively, and the jaw cannot reach it. Safety is a reason to move.
func attacks() -> Array:
	return [
		{"limb": JAW, "stations": [FRONT], "dmg": 4, "name": "snaps"},
		{"limb": TAIL, "stations": [REAR, FLANK], "dmg": 3, "name": "sweeps"},
	]

func live_attacks() -> Array:
	var out: Array = []
	for a in attacks():
		if not limb_broken[a.limb]:
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
	return max(0, AIR_PER_TURN - air_penalty)

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
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(d.cost) or not can_attack(d):
		return false
	air -= d.cost
	var limb: int = STATION_LIMB[d.station]
	limb_hp[limb] -= d.dmg
	log_lines.append("%s hits the %s for %d" % [d.dname, LIMB_NAMES[limb], d.dmg])
	if limb_hp[limb] <= 0:
		limb_hp[limb] = 0
		limb_broken[limb] = true
		log_lines.append("the %s BREAKS" % LIMB_NAMES[limb])
		_check_victory()
	return true

func act_move(i: int, station: int) -> bool:
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(MOVE_COST) or d.station == station:
		return false
	air -= MOVE_COST
	d.station = station
	log_lines.append("%s moves to %s" % [d.dname, STATION_NAMES[station]])
	return true

# Glass_Goat's desperation valve, kept as one rule rather than a system.
func act_overdraft(i: int) -> bool:
	var d = divers[i]
	if outcome != "ongoing" or d.down or d.hp <= OVERDRAFT_HP:
		return false
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
	turn += 1
	air = air_this_turn()
