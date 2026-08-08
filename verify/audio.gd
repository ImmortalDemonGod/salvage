# G7: every named audio event is wired, proven from REAL sim output.
#
# The last project shipped a build where the entire combat log never reached
# the UI, so every sound was dead while the tests were green: the test
# asserted the disconnected side of the pipe. This drives real fights and a
# real puzzle, collects the lines the sim emitted, and requires each named
# event to appear among them.
extends SceneTree

const SfxEvents := preload("res://sim/sfx_events.gd")
const Puzzle := preload("res://sim/puzzle.gd")
const Encounters := preload("res://content/encounters.gd")

var findings: Array = []

func _init() -> void:
	var seen: Dictionary = {}
	var lines := 0
	# every encounter, played to a conclusion, both policies
	for key in Encounters.ALL.keys():
		for policy in ["greedy", "casual"]:
			for s in range(40):
				var c := Combat.new(String(key))
				var rng := RandomNumberGenerator.new()
				rng.seed = s
				var guard := 0
				while c.outcome == "ongoing" and guard < 200:
					guard += 1
					var a: Dictionary = Bots.greedy(c, rng) if policy == "greedy" else Bots.casual(c, rng)
					if a.is_empty() or not Bots.apply(c, a):
						c.end_turn()
				# overdraft is rare in bot play: exercise it explicitly
				c.act_overdraft(0)
				for l in c.log_lines:
					lines += 1
					var k: int = SfxEvents.classify(String(l))
					if k != SfxEvents.Kind.NONE:
						seen[k] = String(l)
	# desperation is a PLAYER choice the judges never make, so bot play
	# never emits its line. Provoke it with legal calls only: the Drum
	# shuts the tail, walks to the claw on a paid move, and pushes past
	# the empty tank (cost 2 against air 1 is the DESPERATE tier).
	var cd := Combat.new("crab")
	cd.act_move(1, Combat.REAR)
	cd.act_ability(1, 0)
	cd.act_move(1, Combat.FLANK)
	cd.act_ability(1, 0)
	for l in cd.log_lines:
		lines += 1
		var kd: int = SfxEvents.classify(String(l))
		if kd != SfxEvents.Kind.NONE:
			seen[kd] = String(l)

	# the lock, played to open
	# Provoke the refusal BEFORE solving: toggle() returns early once the
	# lock is open, so asking afterwards produced no line at all. The probe
	# was wrong, not the game.
	var p := Puzzle.new()
	p.toggle(0)
	p.toggle(1)
	p.toggle(p.SEIZED)   # now under water: refused
	var g2 := 0
	while not p.solved() and g2 < 40:
		g2 += 1
		var st: int = Bots.solve_step(p)
		if st < 0:
			break
		p.toggle(st)
	for l in p.log_lines:
		lines += 1
		var k2: int = SfxEvents.classify(String(l))
		if k2 != SfxEvents.Kind.NONE:
			seen[k2] = String(l)

	print("G7 audio   %d sim lines classified, %d of %d named events reached" % [lines, seen.size(), SfxEvents.Kind.size() - 1])
	for k in range(1, SfxEvents.Kind.size()):
		if seen.has(k):
			print("  %-9s <- %s" % [SfxEvents.name_of(k), String(seen[k]).substr(0, 58)])
		else:
			findings.append("EVENT NEVER FIRES: '%s' is named but no real sim line ever classifies as it" % SfxEvents.name_of(k))
	for f in findings:
		print("FINDING  " + f)
	print("G7: clean" if findings.is_empty() else "G7: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return
