# The pipe lock: JOE's ask (Aug 8), built so the team can judge it beside
# the valve lock rather than argue about it in the abstract. Same contract
# as sim/puzzle.gd: pure state, no Node, no timers, every change logged.
#
# A 5x2 grid of pipe segments. Clicking a segment turns it a quarter turn.
# Water enters at the left of the bottom row and must reach the drain at
# the right of the top row; the door opens when it does. Nothing here can
# lock itself out -- every turn is reversible -- so unlike the valve lock
# the difficulty is reading the route, not sequencing it. That contrast is
# the point: two small locks, two different muscles, and the team picks.
#
# The grid is CONTENT, declared with its solution, and verify/checks.gd
# floods the declared solution to prove the lock is solvable and floods
# the start state to prove it does not open pre-solved. Ten cells, not
# twelve, because Digit1..Digit9,Digit0 is the whole key map a puzzle
# gets (tools/keypath.gd) and a cell a key cannot reach is a G14 hole.
class_name Pipes
extends RefCounted

const COLS := 5
const ROWS := 2
# directions: 0 N, 1 E, 2 S, 3 W
const SOURCE_CELL := 5     # row 1, col 0: water enters from the WEST
const SOURCE_DIR := 3
const DRAIN_CELL := 4      # row 0, col 4: water leaves to the EAST
const DRAIN_DIR := 1

# shape "S": connects rot and rot+2 (a straight, period 2)
# shape "L": connects rot and rot+1 (an elbow)
# solution: the rot that carries the route; -1 marks a decoy
const CELLS := [
	{"shape": "L", "rot": 2, "solution": -1},
	{"shape": "L", "rot": 3, "solution": 1},
	{"shape": "S", "rot": 0, "solution": 1},
	{"shape": "S", "rot": 0, "solution": 1},
	{"shape": "S", "rot": 0, "solution": 1},
	{"shape": "S", "rot": 0, "solution": 1},
	{"shape": "L", "rot": 1, "solution": 3},
	{"shape": "L", "rot": 0, "solution": -1},
	{"shape": "S", "rot": 0, "solution": -1},
	{"shape": "L", "rot": 2, "solution": -1},
]

var cells: Array = []
var log_lines: Array = []

func _init() -> void:
	for c in CELLS:
		cells.append({"shape": String(c.shape), "rot": int(c.rot), "solution": int(c.solution)})

func valves() -> int:
	return cells.size()

# which directions a cell connects at a given rot
static func arms_of(shape: String, rot: int) -> Array:
	if shape == "S":
		return [rot % 4, (rot + 2) % 4]
	return [rot % 4, (rot + 1) % 4]

func arms(i: int) -> Array:
	return arms_of(String(cells[i].shape), int(cells[i].rot))

func toggle(i: int) -> bool:
	if i < 0 or i >= cells.size():
		return false
	if solved():
		return false
	cells[i].rot = (int(cells[i].rot) + 1) % 4
	log_lines.append("pipe %d wheels around" % (i + 1))
	if solved():
		log_lines.append("the water finds its way; the way out lifts open")
	return true

# every cell water reaches from the source through connected arms. Two
# cells join only when EACH aims an arm at the other across their shared
# edge -- one-sided arms leak into the wall and go nowhere.
func flooded() -> Dictionary:
	var wet: Dictionary = {}
	if not (SOURCE_DIR in arms(SOURCE_CELL)):
		return wet
	wet[SOURCE_CELL] = true
	var frontier: Array = [SOURCE_CELL]
	while not frontier.is_empty():
		var i: int = frontier.pop_back()
		for d in arms(i):
			var r := int(i / COLS)
			var c := int(i % COLS)
			match int(d):
				0: r -= 1
				1: c += 1
				2: r += 1
				3: c -= 1
			if r < 0 or r >= ROWS or c < 0 or c >= COLS:
				continue
			var j := r * COLS + c
			if wet.has(j):
				continue
			if not (((int(d) + 2) % 4) in arms(j)):
				continue
			wet[j] = true
			frontier.append(j)
	return wet

func solved() -> bool:
	var wet := flooded()
	return wet.has(DRAIN_CELL) and (DRAIN_DIR in arms(DRAIN_CELL))

# for the bots and keypath: the first cell not yet at its declared
# solution, -1 when the route is set. Straights have period 2, so either
# parity of the target counts as there.
func needs_turn() -> int:
	for i in range(cells.size()):
		var sol := int(cells[i].solution)
		if sol < 0:
			continue
		var rot := int(cells[i].rot)
		if String(cells[i].shape) == "S":
			if rot % 2 != sol % 2:
				return i
		elif rot != sol:
			return i
	return -1

# the cold-read surface, like puzzle.gd's
func state_text() -> String:
	var wet := flooded()
	return "pipes  %d of %d wet%s" % [wet.size(), cells.size(),
		"  ·  the way out is open" if solved() else ""]
