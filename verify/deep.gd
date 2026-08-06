# The nightly deep set. Allowed to take minutes; must not be run by hand.
# Its job is to make "done" an empirical property rather than a judgement:
# it writes a ledger of finding SIGNATURES, and a pass is DRY when it
# introduces nothing the ledger has not already seen. Three consecutive
# dry passes is the stop condition (PROGRESS.md).
#
# Usage: godot --headless --path ~/salvage --script verify/deep.gd -- <states>
extends SceneTree

const LEDGER := "res://verify/deep-ledger.json"

# Signatures the human has ruled on. Adding a line here is a DECISION on the
# record, not a way to silence a detector; it needs a reason beside it.
const RULED: Array = []
const Encounters := preload("res://content/encounters.gd")
const Run := preload("res://sim/run.gd")

var sigs: Array = []

func sig(s: String) -> void:
	if not (s in sigs):
		sigs.append(s)

# ---- score a whole fight from a state, for dominance rollouts ----------
func rollout(c: Combat, rng: RandomNumberGenerator) -> float:
	var g := 0
	while c.outcome == "ongoing" and c.turn <= 40 and g < 400:
		g += 1
		var acted := false
		var inner := 0
		while inner < 12:
			inner += 1
			var a: Dictionary = Bots.greedy(c, rng)
			if a.is_empty() or not Bots.apply(c, a):
				break
			acted = true
			if c.outcome != "ongoing":
				break
		if c.outcome != "ongoing":
			break
		c.end_turn()
	var hp := 0
	for d in c.divers:
		hp += d.max_hp - d.hp
	var score := 0.0
	if c.outcome == "victory":
		score += 1000.0
	return score - float(hp) - float(c.turn)

func key(a: Dictionary) -> String:
	if a.kind == "move":
		return "move->%s" % Combat.STATION_NAMES[a.s]
	return "%s:%s" % [a.kind, ["Scuba", "Prototype1", "Proto5"][a.i]]

# ---- G4: is every action uniquely optimal somewhere? -------------------
# Depth-limited over SAMPLED reachable states, not a complete solve. That
# distinction is load bearing and was corrected once already.
func check_dominance(n: int, enc_id := "crab") -> void:
	var rng := RandomNumberGenerator.new()
	var uniquely_best: Dictionary = {}
	var ever_legal: Dictionary = {}
	var sampled := 0
	for s in range(n):
		rng.seed = s
		var c := Combat.new(enc_id)
		# walk to a random reachable state
		var steps := s % 9
		for _i in range(steps):
			var a: Dictionary = Bots.casual(c, rng)
			if a.is_empty() or not Bots.apply(c, a):
				c.end_turn()
			if c.outcome != "ongoing":
				break
		if c.outcome != "ongoing":
			continue
		sampled += 1
		var opts: Array = Bots.legal(c)
		var best := -1e18
		var best_key := ""
		var ties := 0
		for a in opts:
			ever_legal[key(a)] = true
			var t: Combat = c.clone()
			if not Bots.apply(t, a):
				continue
			var r2 := RandomNumberGenerator.new()
			r2.seed = s + 7717
			var v := rollout(t, r2)
			if v > best + 0.001:
				best = v
				best_key = key(a)
				ties = 1
			elif abs(v - best) <= 0.001:
				ties += 1
		if ties == 1 and best_key != "":
			uniquely_best[best_key] = int(uniquely_best.get(best_key, 0)) + 1
	var names: Array = ever_legal.keys()
	names.sort()
	var parts: Array = []
	for k in names:
		var hits: int = int(uniquely_best.get(k, 0))
		parts.append("%s %d" % [k, hits])
		if hits == 0:
			sig("DOMINATED in %s: %s is never the unique optimal action in %d sampled states" % [enc_id, k, sampled])
	print("dominance %-9s %d states | " % [enc_id, sampled] + "  ".join(parts))

# ---- G11: the taught line must beat naive play ------------------------
func naive(c: Combat, _rng: RandomNumberGenerator) -> Dictionary:
	for d in c.divers:
		if not d.down and c.afford(d.cost) and c.can_attack(d):
			return {"kind": "attack", "i": d.id}
	return {}

func play(c: Combat, policy: String, rng: RandomNumberGenerator) -> Dictionary:
	while c.outcome == "ongoing" and c.turn <= 40:
		var inner := 0
		while inner < 12:
			inner += 1
			var a: Dictionary = Bots.greedy(c, rng) if policy == "taught" else naive(c, rng)
			if a.is_empty() or not Bots.apply(c, a):
				break
			if c.outcome != "ongoing":
				break
		if c.outcome != "ongoing":
			break
		c.end_turn()
	var hp := 0
	for d in c.divers:
		hp += d.max_hp - d.hp
	return {"win": c.outcome == "victory", "hp": hp}

func check_taught(n: int) -> void:
	var tw := 0
	var nw := 0
	var th := 0
	var nh := 0
	for s in range(n):
		var r1 := RandomNumberGenerator.new(); r1.seed = s
		var r2 := RandomNumberGenerator.new(); r2.seed = s
		var t: Dictionary = play(Combat.new(), "taught", r1)
		var v: Dictionary = play(Combat.new(), "naive", r2)
		if t.win: tw += 1
		if v.win: nw += 1
		th += int(t.hp); nh += int(v.hp)
	var twr := 100.0 * tw / n
	var nwr := 100.0 * nw / n
	print("taught     taught win %.1f%% hp %.1f   naive win %.1f%% hp %.1f" % [twr, float(th) / n, nwr, float(nh) / n])
	if not (float(th) / n < float(nh) / n or twr > nwr + 2.0):
		sig("TEACHING LOSES: taught line takes %.1f HP, naive takes %.1f" % [float(th) / n, float(nh) / n])

# ---- ledger: makes "dry" computable -----------------------------------
func load_ledger() -> Dictionary:
	if not FileAccess.file_exists(LEDGER):
		return {"seen": [], "dry_streak": 0, "passes": 0}
	var f := FileAccess.open(LEDGER, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {"seen": [], "dry_streak": 0, "passes": 0}

# G12: "the maximum-skip route is a ruling, not a discovery." Walk the built
# ladder and ask whether any beat can be reached without completing the one
# before it. A linear ladder has no skips, and saying so with a measurement
# is a ruling; leaving it UNVERIFIED forever was just a stale note.
func check_bypass() -> void:
	# The old version wrote `for i in range(...)` and never used `i`, so it
	# probed beat 0 on a fresh Run every iteration. Beat 0 is a scene, so
	# the guard never fired and `skippable` was unconditionally empty: a
	# constant reported as a measurement.
	var beats := Run.new().built_beats()
	var skippable: Array = []
	for i in range(beats.size()):
		# a scene beat's completion condition IS pressing on: advancing
		# through one is the design, not a bypass. Only fights and locks
		# can be skipped in a way that matters.
		if String(beats[i].get("kind", "scene")) == "scene":
			continue
		var probe := Run.new()
		# walk to beat i by completing everything before it
		var hops := 0
		while probe.beat < i and hops < 40:
			hops += 1
			_force_complete(probe)
			if not probe.advance():
				break
		if probe.beat != i:
			continue
		# now try to leave WITHOUT completing it
		var before: int = probe.beat
		if probe.advance() and probe.beat != before:
			skippable.append(String(beats[i].id))
	print("bypass     %d built beats, %d skippable without completing them" % [beats.size(), skippable.size()])
	for b in skippable:
		sig("BYPASSABLE: beat '%s' can be left without completing it" % b)

func _force_complete(r) -> void:
	if r.combat != null:
		for lb in range(r.combat.limb_hp.size()):
			r.combat.limb_hp[lb] = 0
			r.combat.limb_broken[lb] = true
		r.combat.outcome = "victory"
	elif r.puzzle != null:
		for i in range(r.puzzle.VALVES):
			r.puzzle.valve[i] = true

func _init() -> void:
	var n := 600
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = a.to_int()
	var t0: int = Time.get_ticks_usec()
	for k in Encounters.ALL.keys():
		if bool((Encounters.ALL[k] as Dictionary).get("teaching", false)):
			continue
		check_dominance(n, String(k))
	check_taught(400)
	# bypass: honestly unverifiable with one beat, and a vacuous green is
	# worse than an honest red (PROGRESS gate rules)
	var unverified: Array = []
	check_bypass()
	for u in unverified:
		print("UNVERIFIED " + u)

	# A pass cannot be DRY while the fast set is red, or has not run on this
	# code at all. Finding nothing new in a build you already know is broken
	# is not evidence of anything.
	var fast_ok := false
	var fast_why := "verify/.fast-status missing: the fast set has not run"
	if FileAccess.file_exists("res://verify/.fast-status"):
		var raw: String = FileAccess.open("res://verify/.fast-status", FileAccess.READ).get_as_text().strip_edges()
		var bits: PackedStringArray = raw.split(" ")
		if bits.size() >= 3 and bits[0] == "0":
			if int(bits[2]) > 0:
				fast_why = "the fast set passed but %s file(s) have changed since" % bits[2]
			else:
				fast_ok = true
				fast_why = ""
		else:
			fast_why = "the fast set last reported findings"
	if not fast_ok:
		unverified.append("fast set: " + fast_why)

	var led := load_ledger()
	var seen: Array = led.seen
	var fresh: Array = []
	for s in sigs:
		if not (s in seen):
			fresh.append(s)
			seen.append(s)
	# A streak must mean three DISTINCT builds that each came back clean.
	# Counting repeat passes on one unchanged build is exactly the thing
	# the standing rule forbids: re-running a green suite is not work. The
	# streak reached 6 of 3 on a single commit before this was added, which
	# is the stop condition farming itself.
	var head := "unknown"
	if FileAccess.file_exists("res://verify/.fast-status"):
		var raw2: String = FileAccess.open("res://verify/.fast-status", FileAccess.READ).get_as_text().strip_edges()
		var bits2: PackedStringArray = raw2.split(" ")
		if bits2.size() >= 2:
			head = bits2[1]
	var counted: Array = led.get("counted_commits", [])
	var repeat: bool = head in counted
	led.passes = int(led.passes) + 1
	# A pass with any UNVERIFIED check CANNOT be dry. Without this, a deep
	# set that checks two things and finds nothing counts as dry three times
	# and declares the run finished at SCAFFOLD. "Found nothing" only means
	# something when everything was actually looked at, which is the same
	# distinction (coverage, not volume) that this project keeps relearning.
	# Rule 7 says a finding may be fixed, escalated, or ruled on, but never
	# just explained. Applied here: a signature that is still live and has
	# not been written into RULED blocks dryness, so a known defect cannot
	# quietly ride three passes to a stop.
	var unruled: Array = []
	for s2 in sigs:
		if not (s2 in RULED):
			unruled.append(s2)
	for u in unruled:
		print("UNRULED  " + u)
	var complete: bool = unverified.is_empty() and unruled.is_empty()
	if fresh.size() > 0 or not complete:
		led.dry_streak = 0
	elif repeat:
		pass   # clean, but this build was already counted: not new evidence
	else:
		led.dry_streak = int(led.dry_streak) + 1
		counted.append(head)
	led.counted_commits = counted
	led.seen = seen
	var f := FileAccess.open(LEDGER, FileAccess.WRITE)
	f.store_string(JSON.stringify(led, "  "))
	f.close()

	print("ran in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for s in sigs:
		print("FINDING  " + s)
	print("DEEP pass %d: %d signature(s), %d NEW, %d UNVERIFIED  ->  dry streak %d of 3"
		% [led.passes, sigs.size(), fresh.size(), unverified.size(), led.dry_streak])
	if not complete:
		print("       not dry: %d UNVERIFIED, %d UNRULED. A pass carrying either can never count toward the streak." % [unverified.size(), unruled.size()])
	elif repeat:
		print("       clean, but this commit was already counted. Build something, then run it again.")
	quit(0 if int(led.dry_streak) >= 3 else 1)
