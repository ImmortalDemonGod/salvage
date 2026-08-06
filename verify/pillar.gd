# G13 PILLAR: "every mechanic should appear throughout the game in
# increasingly interesting ways" (Marc's proposal). Generated from content
# data, not audited by hand at the end, which is how the last project found
# four violations at hour eighteen.
#
# A mechanic passes if it appears in more than one beat AND something about
# it differs between appearances. Flat is allowed but must be DECLARED, so
# "this is a constant the others vary against" is a decision on the record
# rather than an oversight.
extends SceneTree

const Beats := preload("res://content/beats.gd")
const Encounters := preload("res://content/encounters.gd")
const Puzzle := preload("res://sim/puzzle.gd")

var findings: Array = []

# mechanics that are deliberately constant: the rules the others vary against
const DECLARED_FLAT := ["goal", "combat_frame", "air", "overdraft"]

func _init() -> void:
	var rows: Array = []
	# how each combat beat expresses the shared mechanics
	var seen: Dictionary = {}
	for b in Beats.LADDER:
		if not b.get("built", false):
			continue
		if String(b.get("kind", "scene")) != "combat":
			continue
		var enc: Dictionary = Encounters.ALL[String(b.encounter)]
		var shape := "%d stations, %d limbs, %d attacks, widest hits %d, drum %s" % [
			(enc.open_stations as Array).size(),
			(enc.limbs as Array).size(),
			(enc.attacks as Array).size(),
			_widest(enc),
			"yes" if bool(enc.get("drum", false)) else "no",
		]
		rows.append("%-9s %s" % [String(b.id), shape])
		for m in b.uses:
			if not seen.has(m):
				seen[m] = []
			(seen[m] as Array).append(String(b.id) + ":" + shape)

	var last_combat := ""
	for b2 in Beats.LADDER:
		if b2.get("built", false) and String(b2.get("kind", "scene")) == "combat":
			last_combat = String(b2.id)
	# Puzzles escalate too, and until this ran the second lock's "harder"
	# was an author's claim rather than a measurement.
	var locks: Array = []
	for b3 in Beats.LADDER:
		if b3.get("built", false) and String(b3.get("kind", "scene")) == "puzzle":
			var st: int = int(b3.get("stage", 1))
			var pz := Puzzle.new()
			pz.stage = st
			locks.append({"id": String(b3.id), "stage": st, "valves": pz.valves(), "gated": _gated(pz)})
	if locks.size() >= 2:
		var shapes: Dictionary = {}
		for l in locks:
			shapes["%d/%d" % [int(l.valves), int(l.gated)]] = true
		if shapes.size() <= 1:
			findings.append("FLAT LOCK: every puzzle beat has the same shape (%d valves, %d gated), so water_level recurs without escalating" % [int(locks[0].valves), int(locks[0].gated)])
	elif locks.size() == 1:
		findings.append("APPEARS ONCE: the lock grammar is used in exactly one beat, so it never escalates")
	for l in locks:
		print("  lock %-9s stage %d, %d valves, %d gated behind a water level" % [String(l.id), int(l.stage), int(l.valves), int(l.gated)])

	print("pillar     %d combat beats, last is %s" % [rows.size(), last_combat])
	for r in rows:
		print("  " + r)

	for m in Beats.MECHANICS:
		var apps: Array = seen.get(m, [])
		if m in DECLARED_FLAT:
			continue
		if apps.size() == 0:
			continue   # taught in a scene or puzzle beat; not a combat mechanic
		if apps.size() == 1:
			var only := String(apps[0]).split(":")[0]
			if only == last_combat:
				print("  NOTE: '%s' is introduced in the final combat beat (%s), so it cannot escalate inside a slice this short. Ruled, not deferred." % [m, only])
				continue
			findings.append("APPEARS ONCE: '%s' is used in exactly one combat beat, so it never escalates" % m)
			continue
		var shapes: Dictionary = {}
		for a in apps:
			shapes[String(a).split(":")[1]] = true
		if shapes.size() <= 1:
			findings.append("FLAT: '%s' appears in %d beats but every one is identical in shape, and it is not on the declared-flat list" % [m, apps.size()])

	for f in findings:
		print("FINDING  " + f)
	print("G13: clean" if findings.is_empty() else "G13: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return

# How many valves can be locked out by what you do to the chamber. The
# first version probed only the start and the all-open state, and the
# interlock bites in NEITHER: it reported 0 gated for a lock whose entire
# point is that you can strand yourself.
func _gated(pz) -> int:
	var n := 0
	for i in range(pz.valves()):
		var probe = Puzzle.new()
		probe.stage = pz.stage
		for j in range(probe.valves()):
			probe.valve[j] = (j != i)
		if not probe.reachable(i):
			n += 1
	return n

func _widest(enc: Dictionary) -> int:
	var w := 0
	for a in enc.attacks:
		w = max(w, (a.stations as Array).size())
	return w
