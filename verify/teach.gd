# G-TEACH. Generated, blocking, and cross-checked against the sim.
#
# Two failure modes it exists to catch:
#   1. Two new ideas in one beat, which is how a player ends up unable to
#      say what they are doing (the loudest finding of the last playtest).
#   2. The declared ladder drifting away from what the game actually does,
#      which is the document-agrees-with-itself trap.
#
# Usage: godot --headless --path ~/salvage --script verify/teach.gd
extends SceneTree

# preload rather than relying on the class_name cache, which is not built
# when a fresh script runs headless
const Beats := preload("res://content/beats.gd")

var findings: Array = []

func fail(s: String) -> void:
	if not (s in findings):
		findings.append(s)

func _init() -> void:
	var taught: Array = []
	var rows: Array = []

	for beat in Beats.LADDER:
		var t: String = beat.teaches
		var uses: Array = beat.uses
		var parts: Array = beat.get("parts", [])

		# 1. exactly one new IDEA per beat. Components of that idea are
		#    allowed but must be declared in `parts`, so smuggling a mechanic
		#    into a beat costs an explicit line rather than being free.
		var fresh: Array = []
		for m in uses:
			if not (m in taught) and m != t and not (m in parts):
				fresh.append(m)
		if fresh.size() > 0:
			fail("TWO NEW MECHANICS IN ONE BEAT: %s teaches '%s' but also introduces %s untaught" % [beat.id, t, str(fresh)])

		# 2. nothing is taught twice
		if t in taught:
			fail("TAUGHT TWICE: '%s' is introduced again in %s" % [t, beat.id])
		taught.append(t)
		for m in parts:
			if m in taught:
				fail("PART ALREADY TAUGHT: %s claims '%s' as part of '%s', but it was introduced earlier" % [beat.id, m, t])
			else:
				taught.append(m)
		for m in uses:
			if not (m in taught):
				taught.append(m)

		var pstr: String = ("  (parts: %s)" % str(parts)) if parts.size() > 0 else ""
		rows.append("%-9s teaches %-13s%s%s" % [beat.id, t, pstr, "" if beat.built else "   [UNBUILT]"])

	# 3a. the opening must deliver all four framing roles. "Nobody knew what
	#     they were supposed to be doing or why they were there" was the
	#     loudest finding of the last playtest, and it is checkable.
	for beat in Beats.LADDER:
		if String(beat.get("kind", "scene")) != "scene" or not beat.get("built", false):
			continue
		var lines: Array = beat.get("lines", [])
		if lines.is_empty():
			fail("SCENE WITH NO LINES: %s is built but says nothing" % beat.id)
			continue
		if beat.id == "opening":
			var roles: Array = []
			for l in lines:
				roles.append(String(l.role))
			for need in Beats.REQUIRED_OPENING_ROLES:
				if not (need in roles):
					fail("OPENING MISSING '%s': a player cannot say what they are doing without it" % need)

	# 3. every mechanic reaches the ladder somewhere
	for m in Beats.MECHANICS:
		if not (m in taught):
			fail("UNTAUGHT MECHANIC: '%s' exists but no beat introduces it" % m)

	# 4. THE CROSS-CHECK: the declaration must match what the sim exposes,
	#    or this is a document agreeing with itself.
	for beat in Beats.LADDER:
		if not beat.has("expect") or not beat.built:
			continue
		var e: Dictionary = beat.expect
		var c := Combat.new(String(e.get("encounter", "crab")))
		if int(e.divers) != c.divers.size():
			fail("LADDER DISAGREES WITH THE SIM: %s declares %d divers, the sim builds %d" % [beat.id, int(e.divers), c.divers.size()])
		if int(e.open_stations) != c.OPEN_STATIONS.size():
			fail("LADDER DISAGREES WITH THE SIM: %s declares %d open stations, the sim opens %d" % [beat.id, int(e.open_stations), c.OPEN_STATIONS.size()])
		if int(e.limbs) != c.limb_hp.size():
			fail("LADDER DISAGREES WITH THE SIM: %s declares %d limbs, the sim builds %d" % [beat.id, int(e.limbs), c.limb_hp.size()])

	var built := 0
	for beat in Beats.LADDER:
		if beat.built: built += 1
	print("teach ladder  %d beats, %d built, %d mechanics placed" % [Beats.LADDER.size(), built, taught.size()])
	for r in rows:
		print("  " + r)
	for f in findings:
		print("FINDING  " + f)
	print("G-TEACH: clean" if findings.is_empty() else "G-TEACH: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
