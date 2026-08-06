# G14: the judges must play the game the player plays.
#
# Path A drives the sim directly, the way the bots do. Path B drives the
# SCENE, through the same functions the keyboard handler calls. One
# scripted sequence, both paths, state compared after every step.
#
# The last project shipped a harness that stepped fights down a path
# where free actions did not exist, so a rule change moved no band at all.
# This is the guard against introducing that, and it belongs on every
# commit rather than in an investigation.
#
# Usage: godot --headless --path ~/salvage --script verify/differential.gd
extends SceneTree

var frames := 0
var findings: Array = []

# The script is DERIVED from whatever encounter the scene is actually on,
# not hardcoded. A fixed script assumed the crab and started failing the
# moment the run began on `descent` instead: the instrument was asserting
# a constant it could measure, which is standing rule 3 pointed at a
# test's inputs rather than its labels.
func build_script(c: Combat) -> Array:
	var out: Array = []
	var n: int = c.divers.size()
	var open: Array = c.OPEN_STATIONS
	for round_i in range(3):
		for i in range(n):
			var target: int = int(open[(i + round_i) % open.size()])
			if target != int(c.divers[i].station):
				out.append({"kind": "move", "i": i, "s": target})
			out.append({"kind": "attack", "i": i})
		out.append({"kind": "end", "i": 0, "s": 0})
	return out

var scene: Control

func _initialize() -> void:
	scene = load("res://game/main.tscn").instantiate()
	root.add_child(scene)

func snapshot(c: Combat) -> String:
	var parts: Array = []
	for d in c.divers:
		parts.append("%d/%d@%d%s" % [d.hp, d.max_hp, d.station, "x" if d.down else ""])
	parts.append("air=%d" % c.air)
	parts.append("pen=%d" % c.air_penalty)
	parts.append("turn=%d" % c.turn)
	parts.append("limbs=%s" % str(c.limb_hp))
	parts.append("broken=%s" % str(c.limb_broken))
	parts.append(c.outcome)
	return " ".join(parts)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:
		return false

	var b: Combat = scene.combat   # path B: what the keyboard drives
	if b == null:
		print("differential  scene has no combat on this beat; nothing to compare")
		quit(0)
		return true
	var a := Combat.new(b.enc_id)  # path A: what the bots drive, SAME encounter
	var steps := 0
	for step in build_script(b):
		var ra := false
		var rb := false
		match step.kind:
			"attack":
				ra = Bots.apply(a, {"kind": "attack", "i": step.i})
				scene.selected = int(step.i)
				rb = scene.player_attack()
			"move":
				ra = Bots.apply(a, {"kind": "move", "i": step.i, "s": step.s})
				scene.selected = int(step.i)
				rb = scene.player_move(int(step.s))
			"end":
				a.end_turn()
				scene.player_end_turn()
				ra = true
				rb = true
		steps += 1
		if ra != rb:
			findings.append("STEP %d %s: bot path returned %s, scene path returned %s" % [steps, step.kind, ra, rb])
			break
		var sa := snapshot(a)
		var sb := snapshot(b)
		if sa != sb:
			findings.append("DIVERGED at step %d (%s)\n         bot   : %s\n         scene : %s" % [steps, step.kind, sa, sb])
			break

	print("differential  %d scripted steps down both paths" % steps)
	for f in findings:
		print("FINDING  " + f)
	print("DIFFERENTIAL: the judges play the game the player plays" if findings.is_empty() else "DIFFERENTIAL: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
