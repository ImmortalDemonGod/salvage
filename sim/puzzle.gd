# The flood-and-drain lock. Pure, no Node.
#
# Chosen because of WHY the last project's puzzle failed: its entire state
# lived in the player's memory of a sequence and nothing on screen held it.
# Drawing the relationship between the objects did not fix it, because the
# relationship was never the missing part. Here the whole state is three
# valve positions and a water line, all of it readable from a still frame
# with no HUD, which is exactly what the blocking cold-read gate tests.
#
# The interlock is what makes it a puzzle rather than three switches: the
# third valve is below the waterline, so it can only be turned while the
# chamber is low. Open the easy two first and you have locked yourself out
# and must drain to recover. Nothing is remembered; the mistake is visible.
class_name Puzzle
extends RefCounted

# Two locks, same grammar, second one harder. SPEC 2.12 and the pillar both
# ask a mechanic to RECUR and change rather than appear once.
#
# Lock 1: one chamber, three valves, and the low valve is under water.
# Lock 2: TWO chambers joined by a crossover. Opening it equalises them, so
#         the answer is no longer "open everything": you have to fill one
#         side and keep the other dry, which means the crossover must be
#         shut at the end and open in the middle to move water at all.
var stage := 1

const VALVES := 3
const SEIZED := 2          # the one you have to get down to
const REACH_LEVEL := 1     # it is only reachable at or below this level
const TARGET := 3          # the way out opens when the chamber is full

var valve: Array = [false, false, false, false]
var log_lines: Array = []

# ---- lock 2: two chambers and a crossover ----------------------------
const B_VALVES := 4
const CROSS := 3          # the joining valve
const B_TARGET_A := 3     # the way out is above chamber A
const B_TARGET_B := 0     # and chamber B has to stay dry to hold the door

func valves() -> int:
	return B_VALVES if stage == 2 else VALVES

# chamber A rises with valves 0 and 1; chamber B rises with valve 2; the
# crossover drags them toward each other
# A's own inlets cannot fill it: two valves, one each, against a target of
# three. The third unit has to come across from B, which means the crossover
# must be OPEN. And the crossover sits at the bottom of B, so it can only be
# turned while B is dry. Fill B first and you have locked yourself out, which
# is lock 1's lesson escalated: the order now matters across two chambers.
func level_a() -> int:
	var n := 0
	if valve[0]: n += 1
	if valve[1]: n += 1
	if valve[CROSS] and valve[2]: n += 1
	return clampi(n, 0, 3)

func level_b() -> int:
	# with the crossover open B drains straight through into A
	if valve[2] and not valve[CROSS]:
		return 2
	return 0

func level() -> int:
	var n := 0
	for v in valve:
		if v:
			n += 1
	return clampi(n, 0, VALVES)

func reachable(i: int) -> bool:
	if i < 0 or i >= valves():
		return false
	if stage == 2:
		# the crossover sits at the bottom of chamber B: you can only reach
		# it while B is low, which is the same lesson as lock 1 wearing a
		# second chamber
		if i == CROSS and not valve[i] and level_b() > REACH_LEVEL:
			return false
		return true
	if i == SEIZED and not valve[i] and level() > REACH_LEVEL:
		return false
	return true

func toggle(i: int) -> bool:
	if solved():
		return false
	if not reachable(i):
		log_lines.append("the low valve is under water; drain the chamber to reach it")
		return false
	valve[i] = not valve[i]
	if stage == 2:
		log_lines.append("valve %d %s, chamber A at %d, chamber B at %d" % [i + 1, "opened" if valve[i] else "closed", level_a(), level_b()])
	else:
		log_lines.append("valve %d %s, water at %d of %d" % [i + 1, "opened" if valve[i] else "closed", level(), VALVES])
	if solved():
		log_lines.append("the chamber is full; the way out lifts open")
	return true

func solved() -> bool:
	if stage == 2:
		return level_a() >= B_TARGET_A and level_b() <= B_TARGET_B
	return level() >= TARGET

func state_text() -> String:
	if stage == 2:
		var b2: Array = []
		for i in range(B_VALVES):
			var nm := "crossover" if i == CROSS else "valve %d" % (i + 1)
			var tag := "OPEN" if valve[i] else "SHUT"
			if i == CROSS and not valve[i] and not reachable(i):
				tag += " (under water)"
			b2.append("%s %s" % [nm, tag])
		return "chamber A %d/3   chamber B %d/3   " % [level_a(), level_b()] + "   ".join(b2)
	var bits: Array = []
	for i in range(VALVES):
		var tag := "OPEN" if valve[i] else "SHUT"
		if i == SEIZED:
			tag += " (low)" if reachable(i) or valve[i] else " (under water)"
		bits.append("valve %d %s" % [i + 1, tag])
	return "water %d/%d   " % [level(), VALVES] + "   ".join(bits)
