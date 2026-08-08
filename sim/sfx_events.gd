# Pure classifier from sim log lines to audio events. No Node, no
# AudioServer, so G7's wiring is machine-verifiable: every named event must
# classify from a REAL log line the sim actually produced, not from a
# hand-written string pretending to be one.
#
# This is the shape that worked last project: classification IS the wiring,
# so a test can prove the pipe is connected without listening to anything.
class_name SfxEvents
extends RefCounted

enum Kind { NONE, HIT, BREAK, SHUTDOWN, TAKE, DOWN, WIN, LOSE, MOVE, REFUSE, VALVE, LOCK, CUT, PAYOFF, READ, RAMP, STRAIN }

static func classify(line: String) -> int:
	# the trait payoffs, and the reading that unlocks them
	if line.find("the pressure blows out") >= 0 or line.find("vents back into the tank") >= 0:
		return Kind.PAYOFF
	if line.find(" reads the ") >= 0:
		return Kind.READ
	if line.find("cuts an air line") >= 0:
		return Kind.CUT
	if line.find("runs hotter") >= 0:
		return Kind.RAMP
	if line.find("wound back") >= 0:
		return Kind.VALVE
	# the pipe lock's turn is the same hand-on-metal event as a valve
	if line.find(" wheels around") >= 0:
		return Kind.VALVE
	if line.find("knocked around") >= 0:
		return Kind.SHUTDOWN
	if line.find("salvage crate for") >= 0 or line.find("salvage is crushed") >= 0:
		return Kind.CUT
	if line.find("BREAKS") >= 0:
		return Kind.BREAK
	if line.find("is shut down") >= 0:
		return Kind.SHUTDOWN
	if line.find("is disabled") >= 0:
		return Kind.WIN
	if line.find("squad is lost") >= 0:
		return Kind.LOSE
	if line.find("is down") >= 0:
		return Kind.DOWN
	if line.find("the way out lifts open") >= 0:
		return Kind.LOCK
	# REFUSE must be tested BEFORE VALVE: the refusal line contains the word
	# "valve", so the broader rule swallowed it and the event never fired.
	# Classifier order is a contract, not a formatting detail.
	if line.find("under water; drain") >= 0:
		return Kind.REFUSE
	if line.find("valve") >= 0:
		return Kind.VALVE
	if line.find(" moves to ") >= 0:
		return Kind.MOVE
	# player-caused lines that also say " for ": both fell through to the
	# enemy-hit TAKE rule, so attacking sounded like being hit and a
	# desperate swing drew the monster's bolt (Aug 8 audit). Order matters:
	# these must run BEFORE the " for " fallback.
	if line.find("spills onto the") >= 0:
		return Kind.HIT
	if line.find("pushes past the empty tank") >= 0:
		return Kind.STRAIN
	# an enemy line names its limb and a target; a player line says "hits the"
	if line.find(" hits the ") >= 0:
		return Kind.HIT
	if line.find(" for ") >= 0:
		return Kind.TAKE
	return Kind.NONE

static func name_of(k: int) -> String:
	return ["none", "hit", "break", "shutdown", "take", "down", "win", "lose", "move", "refuse", "valve", "lock", "cut", "payoff", "read", "ramp", "strain"][k]
