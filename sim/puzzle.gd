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

const VALVES := 3
const SEIZED := 2          # the one you have to get down to
const REACH_LEVEL := 1     # it is only reachable at or below this level
const TARGET := 3          # the way out opens when the chamber is full

var valve: Array = [false, false, false]
var log_lines: Array = []

func level() -> int:
	var n := 0
	for v in valve:
		if v:
			n += 1
	return clampi(n, 0, VALVES)

func reachable(i: int) -> bool:
	if i < 0 or i >= VALVES:
		return false
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
	log_lines.append("valve %d %s, water at %d of %d" % [i + 1, "opened" if valve[i] else "closed", level(), VALVES])
	if solved():
		log_lines.append("the chamber is full; the way out lifts open")
	return true

func solved() -> bool:
	return level() >= TARGET

func state_text() -> String:
	var bits: Array = []
	for i in range(VALVES):
		var tag := "OPEN" if valve[i] else "SHUT"
		if i == SEIZED:
			tag += " (low)" if reachable(i) or valve[i] else " (under water)"
		bits.append("valve %d %s" % [i + 1, tag])
	return "water %d/%d   " % [level(), VALVES] + "   ".join(bits)
