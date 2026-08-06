# The nightly deep set. Allowed to take minutes; must not be run by hand.
# Its job is to make "done" an empirical property rather than a judgement:
# it writes a ledger of finding SIGNATURES, and a pass is DRY when it
# introduces nothing the ledger has not already seen. Three consecutive
# dry passes is the stop condition (PROGRESS.md).
#
# Usage: godot --headless --path ~/salvage --script verify/deep.gd -- <states>
extends SceneTree

const LEDGER := "res://verify/deep-ledger.json"

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
func check_dominance(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	var uniquely_best: Dictionary = {}
	var ever_legal: Dictionary = {}
	var sampled := 0
	for s in range(n):
		rng.seed = s
		var c := Combat.new()
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
			var t := c.clone()
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
			sig("DOMINATED: %s is never the unique optimal action in %d sampled states" % [k, sampled])
	print("dominance  %d states sampled | " % sampled + "  ".join(parts))

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

func _init() -> void:
	var n := 600
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = a.to_int()
	var t := Time.get_ticks_usec()
	check_dominance(n)
	check_taught(400)
	# bypass: honestly unverifiable with one beat, and a vacuous green is
	# worse than an honest red (PROGRESS gate rules)
	var unverified: Array = []
	unverified.append("bypass: the slice has one fight, so there is no route to skip yet")
	for u in unverified:
		print("UNVERIFIED " + u)

	var led := load_ledger()
	var seen: Array = led.seen
	var fresh: Array = []
	for s in sigs:
		if not (s in seen):
			fresh.append(s)
			seen.append(s)
	led.passes = int(led.passes) + 1
	# A pass with any UNVERIFIED check CANNOT be dry. Without this, a deep
	# set that checks two things and finds nothing counts as dry three times
	# and declares the run finished at SCAFFOLD. "Found nothing" only means
	# something when everything was actually looked at, which is the same
	# distinction (coverage, not volume) that this project keeps relearning.
	var complete: bool = unverified.is_empty()
	led.dry_streak = 0 if (fresh.size() > 0 or not complete) else int(led.dry_streak) + 1
	led.seen = seen
	var f := FileAccess.open(LEDGER, FileAccess.WRITE)
	f.store_string(JSON.stringify(led, "  "))
	f.close()

	print("ran in %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	for s in sigs:
		print("FINDING  " + s)
	print("DEEP pass %d: %d signature(s), %d NEW, %d UNVERIFIED  ->  dry streak %d of 3"
		% [led.passes, sigs.size(), fresh.size(), unverified.size(), led.dry_streak])
	if not complete:
		print("       not dry: a pass with UNVERIFIED checks can never count toward the streak")
	quit(0 if int(led.dry_streak) >= 3 else 1)
